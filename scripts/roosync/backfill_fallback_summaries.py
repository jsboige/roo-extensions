#!/usr/bin/env python3
"""backfill_fallback_summaries.py — #2719: re-resume les archives dashboard en fallback.

Contexte (PR #3031): ~11.6% des archives RooSync (537/4615) ont ete archivees en
"truncation fallback" sans resume LLM (le condenseur a echoue parce que le LLM
primaire ET le fallback cloud etaient tous les deux HS). Les fichiers d'archive
sont sur disque avec leur contenu verbatim intact ; seul le bloc de resume manque.

Ce script re-genere un resume pour ces archives en s'appuyant sur :
1. Un LLM optionnel via endpoint OpenAI-compatible (claudish, z.ai, OpenAI).
   Si configure et joignable, le LLM produit un vrai resume des messages.
2. Un resume HEURISTIQUE deterministe en fallback : extraction des premieres
   phrases par message, comptage par machine/workspace/themes, agregation.
   Toujours disponible (zero-dep, zero-reseau), moins riche mais correct.

Le script :
  - Scanne `<archive_dir>/*-fallback.md` et detecte `fallbackTruncation: true`
    dans le frontmatter (verifie via PyYAML, pas le nom de fichier seul — cf PR #3031 AC #1).
  - Skip si `backfilledAt` deja present (idempotent).
  - Skip si `archivedAt` > `--max-age-days` (par defaut 30j, cf PR #3031 note de perimetre).
  - Preserve verbatim le contenu des messages (cf PR #3031 AC #2).
  - Remplace le bloc `[FALLBACK TRUNCATION] ...` dans le header par le resume.
  - Met a jour le frontmatter : ajoute `backfilledAt`, `backfillModel`,
    `fallbackTruncation: false`, `llmGenerated: true`.
  - Arrete au premier echec LLM (cf PR #3031 "s'arreter au premier echec LLM").
  - Limite a `--limit N` archives par passe.
  - Dry-run par defaut (cf catalog-pr-hygiene : JAMAIS touche sans `--apply`).

Usage:
    # Dry-run (audit-only, zero modification)
    python scripts/roosync/backfill_fallback_summaries.py

    # Limite a 5 archives pour smoke-test
    python scripts/roosync/backfill_fallback_summaries.py --limit 5

    # Apply reel (modifie les fichiers)
    python scripts/roosync/backfill_fallback_summaries.py --apply --limit 5

    # Avec LLM (exemple claudish po-2023)
    LLM_BASE_URL=http://192.168.0.46:3000/v1 \\
    LLM_API_KEY=<key> \\
    LLM_MODEL=MiniMax-M3 \\
    python scripts/roosync/backfill_fallback_summaries.py --apply --limit 5

    # Cible un autre dossier d'archives (utile pour les tests)
    python scripts/roosync/backfill_fallback_summaries.py --archive-dir ./tests/data/fake-archives

Bornes (cf PR #3031 ACceptance) :
  - Backfill detecte via frontmatter (AC #1)
  - Contenu verbatim preserve (AC #2)
  - Idempotent (AC #3) — skip si `backfilledAt` deja la
  - N'impacte JAMAIS un `append` dashboard vivant (AC #4 — ce script ne touche
    qu'aux archives dans `.shared-state/dashboards/archive/`, pas aux fichiers
    `dashboard.md` principaux)
  - Compteur avant/apres reporte (AC #5 — sortie stdout structuree)

Voir aussi:
  - Issue #2719 (rattachement: condensation fallback) · PR #3031 (criteres d'acceptation)
  - dashboard.ts lignes 1990-2040 (pattern fallback original)
  - dashboard.ts lignes 2320-2360 (pattern archive normal — cible du frontmatter post-backfill)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML non installe. `pip install pyyaml`.", file=sys.stderr)
    sys.exit(2)

# Import openai en option (mode LLM)
try:
    import openai
    HAS_OPENAI = True
except ImportError:
    HAS_OPENAI = False


# --- Constantes -----------------------------------------------------------

DEFAULT_ARCHIVE_DIR = Path(
    "/g/Mon Drive/Synchronisation/RooSync/.shared-state/dashboards/archive"
)
DEFAULT_MAX_AGE_DAYS = 30
DEFAULT_LIMIT = 10  # passe bornée, jamais tout d'un coup

# Bornes du resume LLM (alignees avec dashboard.ts CONDENSE_LLM_MAX_TOKENS=7200,
# mais plus restrictives : un resume d'archive doit etre compact)
LLM_MAX_TOKENS = 1500
LLM_TIMEOUT_S = 120  # au-dela, on tombe en heuristique (cf AC "arret au 1er echec LLM")

# Pattern de detection du bloc [FALLBACK TRUNCATION] a remplacer dans le header.
# On veut remplacer UNIQUEMENT la ligne de fallback, pas les verbatims en aval
# (les messages peuvent contenir "[FALLBACK TRUNCATION]" si un user l'a cite).
FALLBACK_HEADER_RE = re.compile(
    r"^Method: Truncation fallback \(LLM unavailable\)\s*\n"
    r"\s*\n?"
    r"\[FALLBACK TRUNCATION\][^\n]*\n?",
    re.MULTILINE,
)


# --- Dataclasses ----------------------------------------------------------


@dataclass
class ArchiveFile:
    """Metadata + contenu parse d'une archive fallback candidate."""

    path: Path
    frontmatter: dict = field(default_factory=dict)
    raw_text: str = ""
    body_start: int = 0  # offset du body apres le frontmatter
    archived_at: datetime | None = None
    skipped_reason: str | None = None  # si non-None, on n'agit pas


@dataclass
class BackfillResult:
    """Resultat d'une passe pour une archive."""

    path: Path
    status: str  # "backfilled", "skipped", "error"
    mode: str | None = None  # "llm" ou "heuristic"
    reason: str | None = None
    elapsed_ms: int = 0
    summary_chars: int = 0


# --- Lecture archive ------------------------------------------------------


def parse_frontmatter(raw: str) -> tuple[dict, int]:
    """Parse le frontmatter YAML d'un fichier archive dashboard.

    Format connu (cf dashboard.ts:2333-2340 et 2004-2012) :
        ---
        type: archive
        originalKey: <key>
        archivedAt: '<iso8601>'
        messageCount: <n>
        llmGenerated: <bool>
        [fallbackTruncation: true]
        [circuitBreakerOpen: <bool>]
        [statusUpdated: <bool>]
        ---

    Returns (dict, offset_apres_frontmatter).
    Le dict peut etre vide si pas de frontmatter.
    """
    if not raw.startswith("---"):
        return {}, 0
    # Cherche le '---' fermant sur sa propre ligne
    match = re.search(r"\n---\s*(?:\n|$)", raw[3:])
    if match is None:
        return {}, 0
    fm_text = raw[3 : 3 + match.start()]
    body_start = 3 + match.end()
    try:
        return yaml.safe_load(fm_text) or {}, body_start
    except yaml.YAMLError:
        return {}, body_start


def is_fallback_candidate(archive: ArchiveFile) -> bool:
    """Verifie qu'une archive est candidate au backfill."""
    fm = archive.frontmatter
    if not fm:
        return False
    if fm.get("fallbackTruncation") is not True:
        return False
    return True


def is_already_backfilled(archive: ArchiveFile) -> bool:
    """Idempotence : skip si deja backfilled."""
    return "backfilledAt" in archive.frontmatter


def within_age_window(archive: ArchiveFile, max_age_days: int) -> bool:
    """Skip si plus vieux que max_age_days."""
    if archive.archived_at is None:
        return False
    cutoff = datetime.now(timezone.utc) - timedelta(days=max_age_days)
    return archive.archived_at >= cutoff


def load_archive(path: Path) -> ArchiveFile:
    """Charge une archive, parse le frontmatter, detecte les raisons de skip."""
    raw_bytes = path.read_bytes()
    raw = raw_bytes.decode("utf-8", errors="replace")
    fm, body_start = parse_frontmatter(raw)

    # Parse archivedAt (ISO 8601)
    archived_at = None
    if isinstance(fm.get("archivedAt"), str):
        try:
            # Supporte '2026-05-15T05:08:22.460Z'
            archived_at_str = fm["archivedAt"].replace("Z", "+00:00")
            archived_at = datetime.fromisoformat(archived_at_str)
        except ValueError:
            pass

    archive = ArchiveFile(
        path=path,
        frontmatter=fm,
        raw_text=raw,
        body_start=body_start,
        archived_at=archived_at,
    )

    # Detection des raisons de skip
    if not is_fallback_candidate(archive):
        archive.skipped_reason = "not-fallback"
    elif is_already_backfilled(archive):
        archive.skipped_reason = "already-backfilled"
    elif archived_at is None:
        archive.skipped_reason = "no-archived-at"
    return archive


# --- Resume LLM -----------------------------------------------------------


def build_summary_prompt(messages_text: str, message_count: int) -> str:
    """Construit le prompt de resume pour le LLM."""
    return (
        "Tu resumes des messages d'un dashboard de coordination multi-agent "
        "(RooSync). Les messages sont en francais ou en anglais. "
        f"Il y a {message_count} messages a condenser.\n\n"
        "Produis un resume structure en francais avec les sections suivantes :\n"
        "1. **Thematiques principales** (3-5 bullets)\n"
        "2. **Decisions/actions concretes** (bullets courts)\n"
        "3. **PRs/commits references** (numeros #N si presents)\n"
        "4. **Coordination cross-machine** (qui parle a qui)\n\n"
        "Le resume DOIT faire moins de 1500 tokens. Pas de preamble, pas de "
        "postscript, juste les 4 sections.\n\n"
        "===\n"
        f"{messages_text}\n"
        "==="
    )


def call_llm(base_url: str, api_key: str, model: str, prompt: str) -> str | None:
    """Appelle un LLM OpenAI-compatible. Retourne None si echec (AC : arret au 1er echec)."""
    if not HAS_OPENAI:
        return None
    if not api_key:
        return None
    client = openai.OpenAI(
        base_url=base_url,
        api_key=api_key,
        timeout=LLM_TIMEOUT_S,
    )
    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "Tu resumes des messages de dashboard."},
                {"role": "user", "content": prompt},
            ],
            max_tokens=LLM_MAX_TOKENS,
            temperature=0.2,
        )
        content = response.choices[0].message.content
        return content.strip() if content else None
    except Exception as e:
        # On retourne None pour que le caller bascule en heuristique
        # et stop la passe (cf AC "s'arreter au premier echec LLM")
        print(f"  WARN: LLM echec ({type(e).__name__}: {e})", file=sys.stderr)
        return None


# --- Resume heuristique (fallback deterministe) ---------------------------


def heuristic_summary(messages_text: str, message_count: int) -> str:
    """Resume heuristique sans LLM : extraction themes + comptage.

    Toujours disponible (zero-dep, zero-reseau). Moins riche qu'un LLM mais
    preferable a un stub `[FALLBACK TRUNCATION]` qui ne dit rien.
    """
    # Extrait les 5 premieres lignes non vides apres chaque timestamp
    msg_pattern = re.compile(
        r"###\s+\[([^\]]+)\]\s+([^\n]+)\n\n(.*?)(?=\n###\s|\Z)",
        re.DOTALL,
    )
    samples = []
    machine_counts: dict[str, int] = {}
    for m in msg_pattern.finditer(messages_text):
        ts, author, body = m.group(1), m.group(2), m.group(3)
        first_line = next(
            (line.strip() for line in body.split("\n") if line.strip() and not line.startswith("**")),
            "",
        )
        if first_line:
            samples.append((ts[:10], first_line[:120]))
        # Comptage par machine:workspace
        machine_counts[author] = machine_counts.get(author, 0) + 1

    # Top 3 contributeurs
    top_contributors = sorted(
        machine_counts.items(), key=lambda x: -x[1]
    )[:3]

    # Construit le resume
    lines = [
        "## Resume (heuristique deterministe)",
        "",
        f"**{message_count} messages** archives sans resume LLM (circuit breaker "
        "ouvert au moment de la condensation initiale).",
        "",
        "### Premiers messages (echantillon)",
    ]
    for ts, sample in samples[:5]:
        lines.append(f"- *{ts}* : {sample}")
    if len(samples) > 5:
        lines.append(f"- ... et {len(samples) - 5} autres messages")

    lines.extend([
        "",
        "### Contributeurs",
    ])
    for author, count in top_contributors:
        lines.append(f"- `{author}` : {count} messages")

    lines.extend([
        "",
        "*Resume heuristique genere par `backfill_fallback_summaries.py` "
        "(#2719). Remplaceable par un vrai resume LLM : relancer avec "
        "`LLM_API_KEY` configure.*",
    ])
    return "\n".join(lines)


# --- Construction du nouveau contenu ---------------------------------------


def build_backfilled_content(
    archive: ArchiveFile,
    new_summary: str,
    mode: str,
    model: str | None,
) -> str:
    """Construit le contenu archive post-backfill.

    Strategie de preservation verbatim (cf AC #2) :
    1. On garde TOUT le contenu existant sauf :
       - la ligne `Method: Truncation fallback (LLM unavailable)`
       - la ligne `[FALLBACK TRUNCATION] ...`
    2. On les remplace par `Method: Backfilled summary` + le resume (LLM ou
       heuristique).
    3. On ajoute un marqueur HTML discret pour tracer l'operation (commentaire
       qui n'affecte pas la lecture markdown).
    """
    raw = archive.raw_text

    # 1. Mise a jour du frontmatter
    fm = dict(archive.frontmatter)
    fm["llmGenerated"] = True
    fm["statusUpdated"] = True
    fm["fallbackTruncation"] = False
    fm["backfilledAt"] = datetime.now(timezone.utc).isoformat()
    fm["backfillMode"] = mode
    if model:
        fm["backfillModel"] = model
    # Retire circuitBreakerOpen (devient obsolete post-backfill)
    fm.pop("circuitBreakerOpen", None)

    new_fm_text = yaml.dump(fm, default_flow_style=False, sort_keys=False, allow_unicode=True).strip()

    # 2. Body : on remplace le bloc Method + [FALLBACK TRUNCATION] par le resume
    body = raw[archive.body_start:]
    # Trouve le marqueur `Method: Truncation fallback ...` jusqu'au prochain `\n---\n`
    # (le `\n---\n` est le separateur avant les messages verbatim).
    m = re.search(
        r"(.*?Method:\s+Truncation fallback[^\n]*\n)"
        r"(\s*\n?)"
        r"(\[FALLBACK TRUNCATION\][^\n]*\n?)"
        r"(\s*\n?)"
        r"(?=---)",
        body,
        re.DOTALL,
    )
    if m is None:
        # Secours : pas de pattern exact, on insere apres "# Archive (fallback): ..."
        # header. Plus risqué mais degrade gracefully.
        replacement = (
            "Method: Backfilled summary (#2719)\n\n"
            + new_summary
            + "\n"
        )
        body = re.sub(
            r"(# Archive \(fallback\):[^\n]*\n)",
            r"\1\n" + replacement,
            body,
            count=1,
        )
    else:
        # Cas nominal : on remplace EXACTEMENT les 3 lignes (Method + vide + FALLBACK TRUNCATION)
        # par un bloc propre.
        replacement = (
            f"Method: Backfilled summary (#2719, mode={mode})\n\n"
            + new_summary
            + "\n"
        )
        body = body[: m.start()] + replacement + body[m.end():]

    # 3. Re-assemble : frontmatter + body
    new_raw = "---\n" + new_fm_text + "\n---\n\n" + body

    # Verifie byte-identity sur le contenu des messages (AC #2)
    # Heuristique : les sections `### [...]` doivent etre en nombre egal.
    def count_msgs(text: str) -> int:
        return len(re.findall(r"^###\s+\[[^\]]+\]", text, re.MULTILINE))

    old_msg_count = count_msgs(raw)
    new_msg_count = count_msgs(new_raw)
    if old_msg_count != new_msg_count:
        raise RuntimeError(
            f"Refused: message count changed ({old_msg_count} -> {new_msg_count}). "
            "Verbatim preservation violated."
        )

    return new_raw


# --- Application ----------------------------------------------------------


def backfill_one(
    archive: ArchiveFile,
    llm_config: dict | None,
    dry_run: bool,
) -> BackfillResult:
    """Backfill une archive. Retourne le resultat (backfilled/skipped/error)."""
    import time

    start = time.monotonic()

    # Skip si deja candidat-skippe au chargement
    if archive.skipped_reason is not None:
        return BackfillResult(
            path=archive.path,
            status="skipped",
            reason=archive.skipped_reason,
        )

    # Extrait les messages verbatim (entre le frontmatter et la fin)
    body = archive.raw_text[archive.body_start:]
    messages_text = body  # tout le body, le LLM triera

    # Decide mode : LLM d'abord, heuristique en fallback
    summary: str | None = None
    mode: str = "heuristic"
    model: str | None = None

    if llm_config and llm_config.get("api_key"):
        prompt = build_summary_prompt(messages_text, archive.frontmatter.get("messageCount", 0))
        llm_result = call_llm(
            llm_config["base_url"],
            llm_config["api_key"],
            llm_config["model"],
            prompt,
        )
        if llm_result:
            summary = llm_result
            mode = "llm"
            model = llm_config["model"]
        else:
            # AC "s'arreter au premier echec LLM" : on retourne 'error'
            # mais on ne continue PAS sur les autres archives.
            return BackfillResult(
                path=archive.path,
                status="error",
                reason="llm-failed-stops-passe",
            )

    if summary is None:
        summary = heuristic_summary(messages_text, archive.frontmatter.get("messageCount", 0))

    # Construit le nouveau contenu
    try:
        new_raw = build_backfilled_content(archive, summary, mode, model)
    except RuntimeError as e:
        return BackfillResult(
            path=archive.path,
            status="error",
            reason=str(e),
        )

    elapsed_ms = int((time.monotonic() - start) * 1000)

    # Applique (ou pas, si dry-run)
    if not dry_run:
        # write_bytes pour preserver LF exactement (cf C978 L1 ★★)
        # YAML.dump + LF manuel -> concatenation garantie LF
        new_bytes = new_raw.encode("utf-8")
        # Verifie pas de CRLF dans le contenu (defense in depth)
        if b"\r\n" in new_bytes:
            new_bytes = new_bytes.replace(b"\r\n", b"\n")
        # Ecriture ATOMIQUE. Ces archives sont du patrimoine partage, sur un
        # repertoire GDrive synchronise par six machines. Une ecriture en place
        # laisse un fichier tronque si le process est tue ou si G: decroche en
        # plein write_bytes -- et le verbatim qu'on voulait preserver est perdu.
        # tmp + os.replace est atomique sur le meme volume : le lecteur voit
        # soit l'ancien contenu, soit le nouveau, jamais un fichier a moitie
        # ecrit. Le tmp est nettoye si l'ecriture echoue, pour ne pas laisser
        # de residus dans le partage.
        tmp_path = archive.path.with_suffix(archive.path.suffix + ".tmp")
        try:
            tmp_path.write_bytes(new_bytes)
            os.replace(tmp_path, archive.path)
        except BaseException:
            tmp_path.unlink(missing_ok=True)
            raise

    return BackfillResult(
        path=archive.path,
        status="backfilled",
        mode=mode,
        summary_chars=len(summary),
        elapsed_ms=elapsed_ms,
    )


# --- CLI ------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Backfill RooSync fallback archives with summaries (#2719)"
    )
    parser.add_argument(
        "--archive-dir",
        type=Path,
        default=Path(os.environ.get("ROOSYNC_ARCHIVE_DIR", str(DEFAULT_ARCHIVE_DIR))),
        help="Dossier contenant les archives dashboard (defaut: RooSync partage)",
    )
    parser.add_argument(
        "--max-age-days",
        type=int,
        default=int(os.environ.get("BACKFILL_MAX_AGE_DAYS", str(DEFAULT_MAX_AGE_DAYS))),
        help="Age maximum des archives a traiter (defaut: 30j)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=DEFAULT_LIMIT,
        help="Nombre max d'archives par passe (defaut: 10)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Applique reellement les modifications (defaut: dry-run)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Sortie JSON structuree pour audit/CI",
    )
    args = parser.parse_args(argv)

    # LLM config : via env seulement (pas d'argparse pour les secrets)
    llm_config = None
    if os.environ.get("LLM_API_KEY"):
        llm_config = {
            "base_url": os.environ.get("LLM_BASE_URL", "http://localhost:5002/v1"),
            "api_key": os.environ["LLM_API_KEY"],
            "model": os.environ.get("LLM_MODEL", "qwen3.6-35b-a3b"),
        }

    # Verifie le dossier d'archives
    if not args.archive_dir.is_dir():
        print(f"ERROR: archive dir introuvable: {args.archive_dir}", file=sys.stderr)
        return 2

    # Scan : ne garde que les -fallback.md
    fallback_files = sorted(args.archive_dir.glob("*-fallback.md"))
    if not fallback_files:
        print("Aucune archive fallback trouvee.", file=sys.stderr)
        return 0

    # Charge + classifie
    archives: list[ArchiveFile] = []
    skipped_at_load = 0
    for path in fallback_files:
        arch = load_archive(path)
        if arch.skipped_reason is not None:
            skipped_at_load += 1
        else:
            archives.append(arch)

    # Filtre par age
    before_age = len(archives)
    archives = [a for a in archives if within_age_window(a, args.max_age_days)]
    filtered_by_age = before_age - len(archives)

    # Filtre par limit
    if args.limit and len(archives) > args.limit:
        archives = archives[: args.limit]

    # Stats pre
    total_fallback = len(fallback_files)
    eligible_pre = len(archives)

    # Compteurs running
    counts = {
        "total_fallback_on_disk": total_fallback,
        "skipped_at_load": skipped_at_load,
        "skipped_by_age": filtered_by_age,
        "eligible_after_filter": eligible_pre,
        "backfilled_llm": 0,
        "backfilled_heuristic": 0,
        "skipped_idempotent": 0,
        "errors": 0,
    }

    results: list[BackfillResult] = []
    stop_passe = False
    for i, archive in enumerate(archives, start=1):
        result = backfill_one(archive, llm_config, dry_run=not args.apply)
        results.append(result)

        if result.status == "backfilled":
            if result.mode == "llm":
                counts["backfilled_llm"] += 1
            else:
                counts["backfilled_heuristic"] += 1
        elif result.status == "skipped":
            counts["skipped_idempotent"] += 1
        elif result.status == "error":
            counts["errors"] += 1
            if result.reason == "llm-failed-stops-passe":
                # AC : on s'arrete au premier echec LLM
                stop_passe = True

        # Log ligne par ligne
        mode_str = f"mode={result.mode}" if result.mode else ""
        reason_str = f"reason={result.reason}" if result.reason else ""
        # En dry-run rien n'a ete ecrit : afficher "backfilled" ferait conclure
        # l'inverse a qui parcourt le log rapidement.
        status_str = (
            "would-backfill"
            if (not args.apply and result.status == "backfilled")
            else result.status
        )
        print(
            f"[{i}/{len(archives)}] {status_str:14} {archive.path.name[:60]:60} "
            f"{mode_str} {reason_str}"
        )

        if stop_passe:
            print(f"  Passe stoppee au premier echec LLM (cf PR #3031 AC).", file=sys.stderr)
            break

    # Compteurs post (les archives traitees voient leur frontmatter change,
    # donc au prochain run elles tomberont dans skipped_idempotent)
    counts["remaining_fallback_after_passe"] = (
        counts["total_fallback_on_disk"] - counts["backfilled_llm"] - counts["backfilled_heuristic"]
    )

    # Sortie
    if args.json:
        output = {
            "counts": counts,
            "results": [
                {
                    "path": str(r.path),
                    "status": r.status,
                    "mode": r.mode,
                    "reason": r.reason,
                    "summary_chars": r.summary_chars,
                    "elapsed_ms": r.elapsed_ms,
                }
                for r in results
            ],
        }
        print(json.dumps(output, indent=2, ensure_ascii=False))
    else:
        print()
        print("=" * 60)
        print("BACKFILL SUMMARY (#2719)")
        print("=" * 60)
        for k, v in counts.items():
            print(f"  {k:30} = {v}")
        print()
        if not args.apply:
            print("DRY-RUN: aucune modification effectuee. Relancer avec --apply.")
        else:
            print(f"APPLIED: {counts['backfilled_llm'] + counts['backfilled_heuristic']} archives modifiees.")

    # Exit code
    if counts["errors"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
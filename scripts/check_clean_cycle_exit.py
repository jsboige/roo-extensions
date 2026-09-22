#!/usr/bin/env python3
"""
check_clean_cycle_exit.py — organe read-only pour la postcondition Git de fin de cycle (#3776).

Issue : #3776
Instance fondatrice : myia-po-2025:CoursIA-2 (clone 673 commits derriere origin/main,
31 chemins non suivis, 2 submodules en drift sur SHA detache malgre un tree interne propre).

Mission :
  Inspecter l'etat Git d'un clone et de ses sous-modules SANS MUTER. Emettre un verdict
  unique parmi les codes suivants, et signaler tous les signaux concernes :

    PASS             : HEAD sur la branche par defaut, upstream OK, HEAD == upstream,
                       aucun staged/unstaged/untracked, submodules au gitlink.
    WRONG_BRANCH     : la branche courante n'est pas la branche par defaut (typiquement main).
    DETACHED         : HEAD est detache.
    NO_UPSTREAM      : la branche courante n'a pas d'upstream configure.
    UNBORN           : la branche n'a pas encore de commit.
    BEHIND           : HEAD est en arriere de l'upstream (fast-forward possible).
    AHEAD            : HEAD est en avance de l'upstream (non pousse).
    DIVERGED         : HEAD et l'upstream ont diverge.
    DIRTY_TRACKED    : modifications staged ou unstaged dans le worktree.
    UNTRACKED        : chemins non suivis (contenu non expose).
    SUBMODULE_DRIFT  : un ou plusieurs submodules ne sont pas au gitlink declare.
    SUBMODULE_DIRTY  : un submodule est au bon gitlink mais a des modifs internes.
    NOT_REPOSITORY   : le chemin n'est pas un depot Git.

Le script N'APPELLE JAMAIS :
    - git clean
    - git reset --hard
    - git checkout -- <fichier>
    - git stash drop / git stash clear

Une remediation automatique est volontairement HORS SCOPE. Si necessaire, l'agent
doit suivre la procedure documentee dans docs/harness/reference/clean-cycle-exit.md
(archive hors depot, manifeste + SHA-256, puis seulement livraison en PR).

Usage :
    python scripts/check_clean_cycle_exit.py [--path PATH] [--json]
    python scripts/check_clean_cycle_exit.py --help

Sortie :
    Mode humain : verdict + ligne d'etat par categorie concernee, code retour == 0 si PASS, 1 sinon.
    Mode JSON    : objet structuré avec verdict, signals, submodules, ready_for_close.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

GIT_ENV = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}

VERDICTS_PASS = "PASS"
VERDICT_NOT_REPOSITORY = "NOT_REPOSITORY"
VERDICT_UNBORN = "UNBORN"
VERDICT_DETACHED = "DETACHED"
VERDICT_WRONG_BRANCH = "WRONG_BRANCH"
VERDICT_NO_UPSTREAM = "NO_UPSTREAM"
VERDICT_BEHIND = "BEHIND"
VERDICT_AHEAD = "AHEAD"
VERDICT_DIVERGED = "DIVERGED"
VERDICT_DIRTY_TRACKED = "DIRTY_TRACKED"
VERDICT_UNTRACKED = "UNTRACKED"
VERDICT_SUBMODULE_DRIFT = "SUBMODULE_DRIFT"
VERDICT_SUBMODULE_DIRTY = "SUBMODULE_DIRTY"

# Severite ascendante : plus la valeur est haute, plus le verdict est eloigne de PASS.
SEVERITY = {
    VERDICT_NOT_REPOSITORY: 100,
    VERDICT_UNBORN: 90,
    VERDICT_DETACHED: 80,
    VERDICT_WRONG_BRANCH: 70,
    VERDICT_NO_UPSTREAM: 65,
    VERDICT_DIVERGED: 60,
    VERDICT_BEHIND: 50,
    VERDICT_AHEAD: 45,
    VERDICT_DIRTY_TRACKED: 40,
    VERDICT_SUBMODULE_DIRTY: 35,
    VERDICT_SUBMODULE_DRIFT: 30,
    VERDICT_UNTRACKED: 20,
    VERDICTS_PASS: 0,
}


class GitError(RuntimeError):
    """Erreur d'instrument git. Le check doit reporter l'incident sans muter."""


def run_git(args: List[str], cwd: Optional[Path] = None) -> Tuple[int, str, str]:
    """Execute git en capturant stdout/stderr. Ne mute jamais."""
    proc = subprocess.run(
        ["git", *args],
        cwd=str(cwd) if cwd else None,
        env=GIT_ENV,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return proc.returncode, proc.stdout, proc.stderr


def is_repository(path: Path) -> bool:
    """Detecte si `path` est a l'interieur d'un working tree git."""
    rc, out, _ = run_git(["rev-parse", "--is-inside-work-tree"], cwd=path)
    if rc != 0:
        return False
    return out.strip() == "true"


def get_toplevel(path: Path) -> Optional[Path]:
    rc, out, _ = run_git(["rev-parse", "--show-toplevel"], cwd=path)
    if rc != 0:
        return None
    return Path(out.strip())


def get_default_branch(toplevel: Path) -> str:
    """Determine la branche par defaut du depot.

    Priorite :
      1. origin/HEAD -> origin/<branch> (git remote set-head)
      2. master si presente localement
      3. main si presente localement
      4. valeur par defaut : main
    """
    rc, out, _ = run_git(["symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"], cwd=toplevel)
    if rc == 0 and out.strip():
        ref = out.strip()  # refs/remotes/origin/main
        return ref.rsplit("/", 1)[-1]

    rc, _, _ = run_git(["show-ref", "--verify", "--quiet", "refs/heads/master"], cwd=toplevel)
    if rc == 0:
        return "master"

    return "main"


def collect_state(path: Path) -> Dict:
    """Collecte l'etat complet. Retourne un dict avec verdict + signaux.

    Ne mute JAMAIS le working tree. Toutes les commandes git sont read-only
    (status, rev-parse, ls-files, diff, submodule status).
    """
    if not is_repository(path):
        return {
            "verdict": VERDICT_NOT_REPOSITORY,
            "ready_for_close": False,
            "path": str(path),
            "signals": [],
            "submodules": [],
            "errors": [f"{path} n'est pas un depot git."],
        }

    toplevel = get_toplevel(path)
    if toplevel is None:
        return {
            "verdict": VERDICT_NOT_REPOSITORY,
            "ready_for_close": False,
            "path": str(path),
            "signals": [],
            "submodules": [],
            "errors": ["git rev-parse --show-toplevel a echoue."],
        }

    signals: List[Dict] = []
    submodules: List[Dict] = []
    errors: List[str] = []
    candidate_verdicts: List[str] = []

    # 0. UNBORN : aucun commit. Meme si HEAD est un symbolic-ref valide vers
    # refs/heads/main, un depot neuf n'a pas encore de commit. On teste
    # rev-parse --verify HEAD^{commit} qui reussit seulement si la ref existe.
    rc_verify, _, _ = run_git(["rev-parse", "--verify", "HEAD^{commit}"], cwd=toplevel)
    if rc_verify != 0:
        signals.append({"kind": "unborn", "message": "Aucune commit sur HEAD."})
        candidate_verdicts.append(VERDICT_UNBORN)
        return {
            "verdict": VERDICT_UNBORN,
            "ready_for_close": False,
            "path": str(toplevel),
            "branch": None,
            "default_branch": get_default_branch(toplevel),
            "signals": signals,
            "submodules": [],
            "errors": errors,
        }

    # 1. Branche courante / HEAD detached
    rc, head_out, _ = run_git(["symbolic-ref", "--quiet", "HEAD"], cwd=toplevel)
    if rc != 0:
        rc, head_sha, _ = run_git(["rev-parse", "HEAD"], cwd=toplevel)
        signals.append({"kind": "detached", "sha": head_sha.strip()})
        candidate_verdicts.append(VERDICT_DETACHED)
        current_branch = None
    else:
        # `refs/heads/feature/x` -> `feature/x` (et non pas `x`).
        full = head_out.strip()
        if full.startswith("refs/heads/"):
            current_branch = full[len("refs/heads/"):]
        else:
            current_branch = full.rsplit("/", 1)[-1]

    default_branch = get_default_branch(toplevel)

    # 2. Branche == branche par defaut ?
    if current_branch is not None and current_branch != default_branch:
        signals.append({
            "kind": "wrong_branch",
            "current": current_branch,
            "expected": default_branch,
        })
        candidate_verdicts.append(VERDICT_WRONG_BRANCH)

    # 3. Upstream et divergence
    upstream_state = "no_upstream"
    ahead = 0
    behind = 0
    if current_branch is not None:
        rc_up, upstream_out, _ = run_git(
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            cwd=toplevel,
        )
        if rc_up != 0:
            signals.append({"kind": "no_upstream", "branch": current_branch})
            candidate_verdicts.append(VERDICT_NO_UPSTREAM)
        else:
            upstream_state = "ok"
            rc_ahead, ahead_out, _ = run_git(
                ["rev-list", "--count", "@{u}..HEAD"], cwd=toplevel
            )
            rc_behind, behind_out, _ = run_git(
                ["rev-list", "--count", "HEAD..@{u}"], cwd=toplevel
            )
            try:
                ahead = int((ahead_out or "0").strip())
            except ValueError:
                ahead = 0
            try:
                behind = int((behind_out or "0").strip())
            except ValueError:
                behind = 0
            if ahead > 0 and behind > 0:
                signals.append({"kind": "diverged", "ahead": ahead, "behind": behind})
                candidate_verdicts.append(VERDICT_DIVERGED)
            elif behind > 0:
                signals.append({"kind": "behind", "count": behind})
                candidate_verdicts.append(VERDICT_BEHIND)
            elif ahead > 0:
                signals.append({"kind": "ahead", "count": ahead})
                candidate_verdicts.append(VERDICT_AHEAD)

    # 4. Submodules : gitlink vs HEAD, et etat interne.
    # On les detecte AVANT dirty_tracked pour pouvoir exclure proprement les
    # submodules des chemins dirty/untracked (git affiche ` M ext` quand le
    # contenu d'un submodule change, et il est redondant de le dire deux fois).
    sub_status = collect_submodule_state(toplevel)
    submodules.extend(sub_status)
    submodule_paths = {sub["path"] for sub in sub_status}
    for sub in sub_status:
        if sub.get("drift"):
            signals.append({
                "kind": "submodule_drift",
                "path": sub["path"],
                "gitlink": sub["gitlink"],
                "head": sub["head"],
            })
            candidate_verdicts.append(VERDICT_SUBMODULE_DRIFT)
        if sub.get("dirty"):
            signals.append({
                "kind": "submodule_dirty",
                "path": sub["path"],
            })
            candidate_verdicts.append(VERDICT_SUBMODULE_DIRTY)

    # 5. Dirty tracked (staged + unstaged). On exclut les chemins qui sont des
    # submodules (git affiche ` M ext` quand le contenu du submodule change) :
    # ces signaux sont portes par SUBMODULE_DIRTY/DRIFT, on dedouble pas.
    rc_status, status_out, _ = run_git(
        ["status", "--porcelain=v1", "-z", "--untracked-files=no"], cwd=toplevel
    )
    if rc_status == 0 and status_out:
        entries = parse_porcelain_z(status_out)
        # Filtrer les entries qui sont des submodules connus.
        # Format `XY<space><path>` : les 2 premiers chars sont le code d'etat,
        # le 3e caractere est un espace, et la suite est le chemin. On split
        # par espace AU BOUT DU 3e caractere pour preserver les espaces
        # internes (chemins avec espaces, ex. "mon capture.txt").
        filtered = []
        for e in entries:
            if len(e) < 4:
                # Pas le format attendu : on garde par securite.
                filtered.append(e)
                continue
            # e = "<XY> <path>" : e[:3] = code+espace, e[3:] = path
            path_part = e[3:]
            first_segment = path_part.split("/", 1)[0]
            if first_segment in submodule_paths:
                continue
            filtered.append(e)
        if filtered:
            signals.append({"kind": "dirty_tracked", "entries": filtered})
            candidate_verdicts.append(VERDICT_DIRTY_TRACKED)

    # 5. Untracked (avec chemins, sans contenu). Meme exclusion des submodules.
    rc_untracked, untracked_out, _ = run_git(
        ["status", "--porcelain=v1", "-z", "--ignored=no"], cwd=toplevel
    )
    if rc_untracked == 0 and untracked_out:
        untracked = []
        for raw in untracked_out.split("\x00"):
            if not raw:
                continue
            if raw.startswith("?? "):
                p = raw[3:]
            elif raw.startswith("??") and len(raw) >= 3 and raw[2] == " ":
                p = raw[3:]
            else:
                continue
            first_segment = p.split("/", 1)[0]
            if first_segment in submodule_paths:
                continue
            untracked.append(p)
        if untracked:
            signals.append({"kind": "untracked", "paths": untracked})
            candidate_verdicts.append(VERDICT_UNTRACKED)

    # 6. Synthese
    if candidate_verdicts:
        verdict = max(candidate_verdicts, key=lambda v: SEVERITY.get(v, 0))
    else:
        verdict = VERDICTS_PASS

    return {
        "verdict": verdict,
        "ready_for_close": verdict == VERDICTS_PASS,
        "path": str(toplevel),
        "branch": current_branch,
        "default_branch": default_branch,
        "upstream": upstream_state,
        "ahead": ahead,
        "behind": behind,
        "signals": signals,
        "submodules": submodules,
        "errors": errors,
    }


def parse_porcelain_z(output: str) -> List[str]:
    """Parse une sortie `git status --porcelain=v1 -z`.

    Format NUL-separe :
      - changement ordinaire : `XY<space>path\0` (le chunk inclut `XY ` + path).
      - rename/copy : `XY<space>oldpath\0newpath\0` (le chunk actuel contient
        le oldpath apres le code, et le chunk suivant est le newpath).
    On expose une liste de codes XY + nouveau chemin pour les renames.
    Aucun contenu de fichier n'est lu.
    """
    entries: List[str] = []
    chunks = output.split("\x00")
    i = 0
    while i < len(chunks):
        chunk = chunks[i]
        if not chunk:
            i += 1
            continue
        if len(chunk) >= 3:
            code = chunk[:2]
            # Renames et copies : chunk[3:] est l'ancien chemin, le chunk
            # suivant est le nouveau chemin.
            if code.startswith(("R", "C")) and i + 1 < len(chunks) and chunks[i + 1]:
                new_path = chunks[i + 1]
                entries.append(f"{code} {new_path}")
                i += 2
                continue
            entries.append(f"{code} {chunk[3:]}")
        i += 1
    return entries


def collect_submodule_state(toplevel: Path) -> List[Dict]:
    """Liste les submodules, leur gitlink, leur HEAD reel et leur etat interne.

    Pour chaque submodule :
      - drift : le commit HEAD du submodule != le gitlink declare dans le parent
      - dirty : des modifs internes non commitees (meme arbre propre)
      - unpopulated : le submodule n'est pas peuple (repertoire absent, ou
        vide — `git -C` remonte alors au parent). Ce n'est PAS un drift :
        c'est l'etat normal d'un clone partiel sans --recurse-submodules
        (review #3778 : le classer drift rendait SUBMODULE_DRIFT permanent
        sur toute machine qui ne peuple pas les externes).
    """
    rc, out, _ = run_git(["submodule", "foreach", "--quiet", "true"], cwd=toplevel)
    # foreach renvoie 0 meme si un submodule manque ; on continue.
    _ = rc

    rc, ls_out, _ = run_git(["ls-files", "--stage"], cwd=toplevel)
    if rc != 0:
        return []

    gitlinks: Dict[str, str] = {}  # path -> mode-gitsha
    for line in ls_out.splitlines():
        # 160000 <sha> 0\t<path>
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue
        meta = parts[0].split(" ")
        if len(meta) >= 3 and meta[0] == "160000":
            gitlinks[parts[1]] = meta[1]

    if not gitlinks:
        return []

    results: List[Dict] = []
    for sub_path, gitlink_sha in gitlinks.items():
        sub_abs = toplevel / sub_path
        if not sub_abs.exists():
            results.append({
                "path": sub_path,
                "gitlink": gitlink_sha,
                "head": None,
                "drift": False,
                "dirty": False,
                "unpopulated": True,
                "error": "submodule non peuple (repertoire absent)",
            })
            continue

        # #3454 (garde de MECANISME, review #3778) : sur un repertoire existant
        # mais VIDE, `git -C sub_abs` ne rend pas d'erreur — il remonte au repo
        # PARENT et repond en son nom, et son HEAD differe trivialement du
        # gitlink (faux SUBMODULE_DRIFT sur toute machine sans externes peuples).
        # On teste l'instrument AVANT toute lecture dependante de cwd.
        rc_top, top_out, _ = run_git(["rev-parse", "--show-toplevel"], cwd=sub_abs)
        if rc_top != 0 or Path(top_out.strip()).resolve() == toplevel.resolve():
            results.append({
                "path": sub_path,
                "gitlink": gitlink_sha,
                "head": None,
                "drift": False,
                "dirty": False,
                "unpopulated": True,
                "error": "submodule non peuple (repertoire vide, git -C remonte au parent)",
            })
            continue

        # Submodule peuplé : on lit son HEAD directement.
        rc_head, head_out, _ = run_git(["rev-parse", "HEAD"], cwd=sub_abs)
        sub_head = head_out.strip() if rc_head == 0 else None
        # Decode le mode gitlink : "160000 <sha> 0"
        drift = bool(sub_head and gitlink_sha and sub_head != gitlink_sha)

        # Test interne : porcelain status (sans untracked, qui n'est pas du drift de submodule).
        rc_status, status_out, _ = run_git(
            ["status", "--porcelain=v1", "-z", "--untracked-files=no"], cwd=sub_abs
        )
        dirty = bool(rc_status == 0 and status_out and status_out.strip())

        results.append({
            "path": sub_path,
            "gitlink": gitlink_sha,
            "head": sub_head,
            "drift": drift,
            "dirty": dirty,
        })

    return results


def render_human(state: Dict) -> str:
    """Format humain compact."""
    lines = []
    verdict = state["verdict"]
    if verdict == VERDICTS_PASS:
        lines.append("[PASS] Pret a cloturer le cycle.")
        lines.append(f"  path        : {state.get('path')}")
        lines.append(f"  branch      : {state.get('branch')} (default: {state.get('default_branch')})")
        lines.append(f"  upstream    : {state.get('upstream')} (ahead={state.get('ahead',0)} behind={state.get('behind',0)})")
        # Review #3778 : les submodules non peuples ne bloquent pas le verdict
        # (etat normal d'un clone partiel) mais restent visibles en info.
        unpop = [s for s in state.get("submodules", []) if s.get("unpopulated")]
        if unpop:
            sample = ", ".join(s["path"] for s in unpop[:5])
            extra = f" (+{len(unpop) - 5} autres)" if len(unpop) > 5 else ""
            lines.append(f"  submodules  : {len(unpop)} non peuple(s) (ignores, pas un drift) - {sample}{extra}")
        return "\n".join(lines)

    lines.append(f"[{verdict}] NON pret - signaux a traiter avant cloture :")
    for sig in state.get("signals", []):
        kind = sig.get("kind", "?")
        if kind == "dirty_tracked":
            entries = ", ".join(sig.get("entries", []))
            lines.append(f"  - dirty_tracked : {entries}")
        elif kind == "untracked":
            paths = sig.get("paths", [])
            sample = ", ".join(paths[:5])
            extra = f" (+{len(paths) - 5} autres)" if len(paths) > 5 else ""
            lines.append(f"  - untracked : {len(paths)} chemin(s) - {sample}{extra}")
        elif kind == "submodule_drift":
            lines.append(
                f"  - submodule_drift : {sig['path']} "
                f"(gitlink={sig['gitlink'][:8]} HEAD={sig.get('head','?')[:8] if sig.get('head') else '?'})"
            )
        elif kind == "submodule_dirty":
            lines.append(f"  - submodule_dirty : {sig['path']}")
        elif kind == "behind":
            lines.append(f"  - behind : HEAD est {sig['count']} commit(s) en arriere de l'upstream.")
        elif kind == "ahead":
            lines.append(f"  - ahead : HEAD est {sig['count']} commit(s) en avance (non pousse).")
        elif kind == "diverged":
            lines.append(
                f"  - diverged : ahead={sig['ahead']} behind={sig['behind']} (rebase ou merge requis)."
            )
        elif kind == "wrong_branch":
            lines.append(f"  - wrong_branch : sur '{sig['current']}', attendu '{sig['expected']}'.")
        elif kind == "no_upstream":
            lines.append(f"  - no_upstream : la branche '{sig['branch']}' n'a pas d'upstream.")
        elif kind == "detached":
            lines.append(f"  - detached : HEAD detache en {sig['sha'][:8]}.")
        elif kind == "unborn":
            lines.append("  - unborn : aucune commit sur HEAD.")
        else:
            lines.append(f"  - {kind} : {sig}")

    if state.get("errors"):
        lines.append("")
        lines.append("Erreurs instrument :")
        for err in state["errors"]:
            lines.append(f"  ! {err}")
    return "\n".join(lines)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="check_clean_cycle_exit",
        description="Verifie la postcondition Git de fin de cycle (read-only).",
    )
    parser.add_argument(
        "--path",
        default=".",
        help="Chemin du clone a inspecter (defaut : repertoire courant).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emission JSON structuree.",
    )
    args = parser.parse_args(argv)

    path = Path(args.path).resolve()
    state = collect_state(path)

    if args.json:
        print(json.dumps(state, indent=2, ensure_ascii=False))
    else:
        print(render_human(state))

    return 0 if state["verdict"] == VERDICTS_PASS else 1


if __name__ == "__main__":
    sys.exit(main())

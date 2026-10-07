#!/usr/bin/env python3
"""
pick_idle_grain.py - Picker 3 urnes ponderees pour le pool executor roo-extensions.

Issue : #3675 (Epic #3111 phase 2, candidat #2) ; rework #4103.
Inspiration : CoursIA `pick_idle_grain.py` (PR #3155, passe 2 audit filesystem).
Bugs locaux documentes : #2509 (`--limit 15` faux drain) ; #4103 (graine fixe :
toutes les lanes tiraient le meme grain a chaque cycle).

Le picker tire dans 3 urnes ponderees :
  - grain      : issues actionnables (labels `approved` / `bug` / `investigation`)
  - umbrella   : issues parentes/epics (label `epic`) - signal de coordination
  - delivered  : PRs ouvertes livrables (toutes ; une PR ouverte n'est pas
                 encore un grain transforme - pas de lecture de verrou ici)

#4103 - tirage par lane et par creneau :
  - La graine par defaut derive de la machine (COMPUTERNAME, sinon hostname,
    en minuscules) et du creneau horaire UTC :
    `int(sha256(machine)[:8], big) ^ slot` ou `slot = epoch_utc // 3600`.
    Deux lanes tirent des listes differentes sur le meme pool. Un `--seed N`
    explicite garde la reproductibilite (tests). Jamais `hash()` : le hash
    Python d'une chaine est sale par processus (PYTHONHASHSEED) et la graine
    changerait a chaque lancement (precisation sk-agent analyst, #4103).
  - `--top K` (defaut 5) : K candidats distincts, tires sans remise selon les
    poids des urnes. La lane parcourt la liste jusqu'au premier grain libre.
    Si les K sont tous pris, le tirage s'elargit au pool entier, dans l'ordre
    du tirage ; si rien n'est libre : verdict `ALL_CLAIMED` (exit 0) avec la
    liste des ecarts et leurs raisons - ni IDLE_REAL ni ERROR.
  - Saut des claims etrangers sur les candidats parcourus uniquement (appels
    API bornes) : logique REUTILISEE depuis `scripts/github/check_issue_claim.py`
    (ADR 017 : claim actif d'une autre machine, peremption 24 h).
  - Saut des issues portant une etiquette de lane (`myia-*`) autre que la
    notre - la regle s'applique a toute etiquette myia-* existante, sans
    liste codee en dur. Le prefixe de titre `[CLAUDE-<machine>]` n'est PAS
    consulte : il designe la machine qui a CREE l'issue, pas celle qui doit
    la porter.
  - Collecte REST UNE fois par depot (`gh api repos/{repo}/issues?state=open`,
    paginee) : le quota GraphQL, partage par toute la flotte, n'est plus
    consomme. La meme reponse sert les 3 urnes (les PRs y figurent avec la
    cle `pull_request`) et le compteur `unlabelled_open` (issues ouvertes non
    gatees, non epic, sans etiquette d'urne - le trou rendu visible).

Usage :
    python pick_idle_grain.py --dry-run                # Liste les candidats sans s'engager
    python pick_idle_grain.py --json                  # Sortie JSON pour orchestration
    python pick_idle_grain.py --top 8                 # Liste ordonnee de 8 candidats
    python pick_idle_grain.py --reroll                # Re-tirage (graine decalee, compat)
    python pick_idle_grain.py --seed 42 --top 5       # Tirage reproducible (tests)

Garde-fous (fail-closed, reviews #3681) :
  - Toute panne instrument (gh exit != 0, timeout, JSON invalide - sur la
    collecte OU sur une verification de claim) rend un verdict ERROR avec
    exit 2 - JAMAIS un verdict de fond. Un instrument muet ne peut pas
    declarer le pool vide, ni un claim illisible passer pour un grain libre.
  - Verdict IDLE_REAL UNIQUEMENT si les 3 urnes sont vides APRES collecte
    reussie sur les 2 depots.
  - Encodage : stdout gh decode en UTF-8 avec errors="replace" - les titres
    accentues ne crashent plus le reader sous Windows cp1252.
"""
import argparse
import hashlib
import json
import os
import random
import re
import socket
import subprocess
import sys
import time
from pathlib import Path

# Reutilisation de la logique de claim (ADR 017) - pas de reecriture (#4103).
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "github"))
import check_issue_claim  # noqa: E402

# Ponderations par defaut - modifiables via --weights "grain:7,umbrella:2,delivered:1"
DEFAULT_WEIGHTS = {"grain": 7, "umbrella": 2, "delivered": 1}

# Labels actionnables (grain) - EXCLURE needs-approval/deferred/blocked-on-gate/epic
GRAIN_LABELS = {"approved", "bug", "investigation"}
UMBRELLA_LABELS = {"epic"}
# Gel par decision (#3381) : hors de TOUTE urne, meme avec un label actionnable
FROZEN_LABELS = {"frozen"}
# Attente d'arbitrage ou de deblocage : hors de TOUTE urne, meme avec un label
# actionnable. L'exclusion implicite (absence de label actionnable) ne tient pas
# en cas de CO-OCCURRENCE - mesure 03/10 : #4038 (bug + needs-approval) pickee
# au 1er tirage, contrairement au contrat documente ci-dessus.
GATED_LABELS = {"needs-approval", "deferred", "blocked-on-gate"}

# Repos a scanner (anti-double-claim #3407 : 2 depots)
REPOS = ["jsboige/roo-extensions", "jsboige/jsboige-mcp-servers"]

# Etiquette de lane : toute etiquette `myia-*` posee sur une issue designe la
# lane qui la porte (#4103). Pas de liste codee en dur : la regle s'applique a
# toute etiquette matchant le motif, presente ou future.
MACHINE_LABEL_RE = re.compile(r"^myia-[a-z0-9-]+$")

# Peremption des claims etrangers : meme valeur que le guard check_issue_claim
# (ADR 017, --stale-threshold defaut 24). Un claim perime ne bloque pas - le
# nouveau claimant pose quand meme son propre [CLAIMED].
CLAIM_STALE_THRESHOLD_H = 24.0


class GhCommandError(RuntimeError):
    """Panne instrument gh : exit non-nul, timeout ou JSON invalide.

    Fail-closed : le picker ne doit JAMAIS convertir une panne en verdict
    de fond (IDLE_REAL sur un pool potentiellement non-vide, ou grain libre
    sur un claim illisible)."""

    def __init__(self, repo: str, reason: str):
        super().__init__(f"gh a echoue pour {repo}: {reason}")
        self.repo = repo
        self.reason = reason


def run_gh_text(cmd: list, repo: str, timeout: int = 60) -> str:
    """Execute gh, decode en UTF-8, retourne le stdout brut.

    Fail-closed : CalledProcessError / TimeoutExpired sont des pannes
    d'instrument, pas des pools vides (review #3681, bloquant 2).
    """
    try:
        result = subprocess.run(
            cmd, capture_output=True, check=True, timeout=timeout,
            encoding="utf-8", errors="replace",
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        stderr = (e.stderr or "").strip() if isinstance(e.stderr, str) else ""
        raise GhCommandError(repo, f"exit {e.returncode}: {stderr}") from e
    except subprocess.TimeoutExpired as e:
        raise GhCommandError(repo, f"timeout apres {timeout}s") from e


def run_gh_api_open_issues(repo: str, limit: int) -> list:
    """Collecte UNE fois les issues ET PRs ouvertes d'un depot, via REST pagine.

    `gh api .../issues?state=open` retourne issues et PRs (une PR y porte la
    cle `pull_request`) : la meme reponse alimente les 3 urnes et le compteur
    unlabelled_open, sans appel supplementaire (#4103). Le REST remplace
    `gh issue list` / `gh pr list` (GraphQL) : le quota GraphQL, partage par
    toute la flotte, n'est plus consomme par le picker.

    Avec `--paginate --jq '.[]'`, gh emet un objet JSON compact par ligne a
    travers toutes les pages ; le parsing est ligne a ligne. Toute ligne
    non-JSON est une panne d'instrument (fail-closed), pas un pool vide.
    """
    cmd = [
        "gh", "api", "--paginate", "--jq", ".[]",
        f"repos/{repo}/issues?state=open&per_page=100",
    ]
    stdout = run_gh_text(cmd, repo)
    items = []
    for line in stdout.splitlines():
        if not line.strip():
            continue
        try:
            items.append(json.loads(line))
        except json.JSONDecodeError as e:
            raise GhCommandError(repo, f"stdout non-JSON: {e}") from e
        if len(items) >= limit:
            break
    return items


def normalize_rest_item(raw: dict, repo: str) -> dict:
    """Mappe un item REST vers la forme interne (champs camelCase, is_pr, repo).

    Chaque item porte son repo : le numero seul n'identifie rien quand les
    deux depots l'utilisent (mesure po-2026 03/10, c.72 : #608 existe des
    deux cotes avec des contenus differents).
    """
    return {
        "number": raw.get("number"),
        "title": raw.get("title", ""),
        "labels": [{"name": l.get("name")} for l in raw.get("labels", [])],
        "assignees": raw.get("assignees", []),
        "createdAt": raw.get("created_at", ""),
        "updatedAt": raw.get("updated_at", ""),
        "is_pr": "pull_request" in raw,
        "repo": repo,
    }


def bucketize_items(items: list):
    """Repartit les items collectes dans les 3 urnes + compte le trou.

    Retourne (buckets, unlabelled_open, open_issues) :
      - buckets['delivered'] = PRs ouvertes (cle `pull_request` cote REST) ;
      - unlabelled_open = issues ouvertes NON gatees/frozen, NON epic, sans
        AUCUN label d'urne (grain|umbrella) : le trou du pool rendu visible
        (#4103) - coordinator relabellise ou arbitre, le picker ne devine pas.
      - open_issues = issues ouvertes hors PRs (backlog_total historique).
    """
    buckets = {"grain": [], "umbrella": [], "delivered": []}
    unlabelled_open = 0
    open_issues = 0
    for item in items:
        labels = {lbl.get("name") for lbl in item.get("labels", [])}
        if item.get("is_pr"):
            buckets["delivered"].append(item)
            continue
        open_issues += 1
        if labels & (FROZEN_LABELS | GATED_LABELS):
            continue
        if labels & UMBRELLA_LABELS:
            buckets["umbrella"].append(item)
        elif labels & GRAIN_LABELS:
            buckets["grain"].append(item)
        else:
            unlabelled_open += 1
    return buckets, unlabelled_open, open_issues


def own_machine_id() -> str:
    """Identite de lane : COMPUTERNAME, sinon hostname, en minuscules.

    La machine vient de l'environnement, jamais d'un flag CLI (ADR 016 :
    le filtre par machine a ete SUPPRIME ; #4103 reutilise des donnees qui
    existent - claims et etiquettes - sans le reintroduire).
    """
    name = os.environ.get("COMPUTERNAME") or socket.gethostname() or "unknown"
    return name.strip().lower()


def current_slot(now: float | None = None) -> int:
    """Creneau horaire UTC du tirage (epoch // 3600). Injectable pour les tests."""
    if now is None:
        now = time.time()
    return int(now // 3600)


def derive_seed(machine: str, slot: int) -> int:
    """Graine stable par lane et par creneau.

    sha256 plutot que hash() : le hash Python d'une chaine est sale par
    processus (PYTHONHASHSEED) - hash(machine) donnerait une graine differente
    a chaque lancement sur la MEME machine (precision analyst #4103).
    """
    digest = hashlib.sha256(machine.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big") ^ slot


def foreign_machine_labels(labels: set, own_machine: str) -> list:
    """Etiquettes de lane etrangeres portees par l'issue (triees).

    Toute etiquette `myia-*` qui n'est pas la notre designe une autre lane.
    La comparaison est en minuscules des deux cotes (les etiquettes du depot
    sont minuscules ; COMPUTERNAME arrive en majuscules).
    """
    own = (own_machine or "").lower()
    hits = {
        lbl for lbl in labels
        if isinstance(lbl, str) and MACHINE_LABEL_RE.match(lbl.lower()) and lbl.lower() != own
    }
    return sorted(hits)


def draw_candidates(buckets: dict, weights: dict, rng: random.Random, k, pool: dict = None) -> list:
    """Tire k candidats distincts SANS REMISE selon les poids des urnes.

    A chaque etape : une urne tiree selon les poids (parmi les non vides),
    puis un item au hasard dans l'urne, retire du pool. k=None etend le
    tirage au pool entier - c'est l'elargissement du verdict ALL_CLAIMED
    (#4103) : meme ordre, meme rng, continuite du tirage.

    `pool` (optionnel) : etat de tirage persistant. Passe par l'appelant, il
    relie les deux passes (K candidats, puis elargissement) sur le MEME pool
    ampute - sans lui, chaque passe repartirait des urnes intactes et
    reverifierait les candidats deja ecartes.
    """
    if pool is None:
        pool = {name: list(items) for name, items in buckets.items() if items}
    order = []
    while pool and (k is None or len(order) < k):
        names = [n for n in pool if pool[n]]
        if not names:
            break
        total = sum(weights.get(n, 0) for n in names)
        chosen = rng.choices(names, weights=[weights.get(n, 0) / total for n in names], k=1)[0]
        idx = rng.randrange(len(pool[chosen]))
        order.append((chosen, pool[chosen].pop(idx)))
        if not pool[chosen]:
            del pool[chosen]
    return order


def check_candidate(urn: str, item: dict, own_machine: str) -> tuple:
    """(skip, raison) pour un candidat. Leve GhCommandError sur panne instrument.

    - Urne delivered : jamais ecartee (ADR 016 : pas de lecture de verrou sur
      une PR ouverte - elle n'est pas encore un grain transforme ; la review
      cross-lane est le but de cette urne).
    - Etiquette de lane etrangere : ecarte sans appel API (donnee locale).
    - Claim etranger actif : REUTILISE check_issue_claim (ADR 017, peremption
      24 h) - fetch_issue + reduce_claims + classify, pas de reecriture.
      Une claim illisible est une panne d'instrument (fail-closed), jamais un
      grain libre : lever GhCommandError laisse le verdict ERROR tranche.
    """
    if urn == "delivered":
        return False, ""
    labels = {lbl.get("name") for lbl in item.get("labels", [])}
    foreign = foreign_machine_labels(labels, own_machine)
    if foreign:
        return True, "machine label " + ", ".join(foreign)
    try:
        issue = check_issue_claim.fetch_issue(str(item["number"]), item["repo"])
    except (RuntimeError, json.JSONDecodeError) as e:
        raise GhCommandError(item["repo"], f"claim check #{item['number']}: {e}") from e
    state = check_issue_claim.reduce_claims(issue.get("comments", []))
    blocking, _warnings, _notes = check_issue_claim.classify(
        state, own_machine, CLAIM_STALE_THRESHOLD_H
    )
    if blocking:
        who = ", ".join(sorted({m for m, _, _ in blocking}))
        return True, f"active claim by {who}"
    return False, ""


def emit_error(errors: list, as_json: bool) -> int:
    """Verdict ERROR fail-closed : exit 2, jamais un verdict de fond."""
    if as_json:
        print(json.dumps({
            "verdict": "ERROR",
            "errors": [str(e) for e in errors],
            "pick": None,
        }, indent=2))
    else:
        print("[ERROR] Instrument gh en panne - aucun verdict de fond rendu :")
        for e in errors:
            print(f"  - {e}")
        print("Reparer gh (auth, rate-limit, reseau) puis relancer le picker.")
    return 2


def _make_stdout_encoding_safe() -> None:
    """Ecrire sans jamais lever sur une console Windows cp1252 (#3675 suite).

    Mesure web2 04/10 (cycle c.24) : `--dry-run` sur une urne contenant un
    titre portant '→' (U+2192, absent de cp1252) -> UnicodeEncodeError a
    l'impression. Le mode qui sert a choisir quand le tirage rend un candidat
    deja pris etait donc inutilisable en texte ; seul `--json` survivait
    (json.dumps echappe le non-ASCII par defaut).

    #3675/#3681 avait corrige la LECTURE de stdout gh (UTF-8,
    errors='replace'). L'ECRITURE porte la meme politique : `errors='replace'`
    plutot qu'un forcage UTF-8, pour que la console garde son rendu actuel
    (les accents cp1252 continuent de s'afficher) et que seul l'incodable
    recule ('?') au lieu de lever.
    """
    try:
        sys.stdout.reconfigure(errors="replace")
    except (AttributeError, ValueError, OSError):
        # stdout sans reconfigure (StringIO de test, flux deja ferme) : ne pas
        # empecher le picker de rendre son verdict pour autant.
        pass


def _candidate_entry(urn: str, item: dict, skip: bool, reason: str) -> dict:
    return {
        "number": item["number"],
        "repo": item.get("repo", ""),
        "title": item["title"],
        "urn": urn,
        "skipped": skip,
        "reason": reason or None,
    }


def main() -> int:
    _make_stdout_encoding_safe()
    parser = argparse.ArgumentParser(
        description="Picker 3 urnes ponderees pour le pool executor roo-extensions (issue #3675, rework #4103).",
    )
    parser.add_argument("--dry-run", action="store_true", help="Affiche la liste des candidats sans s'engager.")
    parser.add_argument("--json", action="store_true", help="Sortie JSON machine-readable.")
    parser.add_argument("--reroll", action="store_true", help="Re-tirage avec graine decalee (compat).")
    parser.add_argument("--limit", type=int, default=300, help="Cap d'items collectes par depot (defaut 300, corrige #2509).")
    parser.add_argument("--seed", type=int, default=None,
                        help="Graine explicite reproductible (tests). Defaut : derivee de la machine et du creneau UTC (#4103).")
    parser.add_argument("--weights", type=str, default="", help="Ponderations custom (ex: 'grain:7,umbrella:2,delivered:1').")
    parser.add_argument("--top", type=int, default=5,
                        help="Nombre de candidats distincts tires sans remise (defaut 5) ; la lane parcourt la liste jusqu'au premier grain libre.")
    args = parser.parse_args()

    # Parse weights custom si fourni
    weights = DEFAULT_WEIGHTS.copy()
    if args.weights:
        for pair in args.weights.split(","):
            if ":" in pair:
                k, v = pair.split(":", 1)
                try:
                    weights[k.strip()] = int(v.strip())
                except ValueError:
                    pass

    # Graine : explicite (reproductibilite, tests) ou derivee machine+creneau
    machine = own_machine_id()
    slot = current_slot()
    seed = args.seed if args.seed is not None else derive_seed(machine, slot)
    if args.reroll:
        seed += 1
    rng = random.Random(seed)

    # Collecte - UNE requete REST par depot (issues+PRs ouvertes), fail-closed :
    # toute panne instrument arrete le picker AVANT tout verdict (review #3681).
    all_items = []
    errors = []
    for repo in REPOS:
        try:
            raw = run_gh_api_open_issues(repo, args.limit)
            all_items.extend(normalize_rest_item(r, repo) for r in raw)
        except GhCommandError as e:
            errors.append(e)
    if errors:
        return emit_error(errors, args.json)

    # Urnes + trous visibles
    buckets, unlabelled_open, total_backlog = bucketize_items(all_items)
    grain_count = len(buckets["grain"])
    umbrella_count = len(buckets["umbrella"])
    delivered_count = len(buckets["delivered"])
    actionnable_count = grain_count + umbrella_count + delivered_count

    trace = {"machine": machine, "seed": seed, "slot": slot}

    if actionnable_count == 0:
        # Verdict IDLE REEL : aucun grain actionnable - collecte reussie, urnes vides
        if args.json:
            print(json.dumps({
                "verdict": "IDLE_REAL",
                **trace,
                "backlog_total": total_backlog,
                "grain": grain_count,
                "umbrella": umbrella_count,
                "delivered": delivered_count,
                "unlabelled_open": unlabelled_open,
                "pick": None,
            }, indent=2))
        else:
            print(f"[IDLE-REAL] Backlog={total_backlog}, grain=0, umbrella=0, delivered=0, "
                  f"unlabelled_open={unlabelled_open}.")
            print("Le pool est REELLEMENT draine. Passer au catalogue idle I1-I8.")
        return 0

    # Tirage ordonne sans remise, puis parcours jusqu'au premier candidat libre.
    # Tous les K pris -> elargissement au pool entier dans l'ordre du tirage
    # (#4103) ; rien de libre -> ALL_CLAIMED (exit 0), ni IDLE_REAL ni ERROR.
    # Le pool persistant relie les deux passes : l'elargissement ne re-tire
    # jamais un candidat deja ecarte.
    draw_pool = {name: list(items) for name, items in buckets.items() if items}
    candidates = draw_candidates(buckets, weights, rng, args.top, pool=draw_pool)
    checked = []
    pick = None
    try:
        for urn, item in candidates:
            skip, reason = check_candidate(urn, item, machine)
            checked.append(_candidate_entry(urn, item, skip, reason))
            if not skip:
                pick = (urn, item)
                break
        if pick is None:
            for urn, item in draw_candidates(buckets, weights, rng, None, pool=draw_pool):
                skip, reason = check_candidate(urn, item, machine)
                checked.append(_candidate_entry(urn, item, skip, reason))
                if not skip:
                    pick = (urn, item)
                    break
    except GhCommandError as e:
        return emit_error([e], args.json)

    if args.json:
        if pick is None:
            output = {
                "verdict": "ALL_CLAIMED",
                **trace,
                "backlog_total": total_backlog,
                "grain": grain_count,
                "umbrella": umbrella_count,
                "delivered": delivered_count,
                "unlabelled_open": unlabelled_open,
                "candidates": checked,
                "pick": None,
            }
        else:
            urn, item = pick
            output = {
                "verdict": "PICK",
                **trace,
                "backlog_total": total_backlog,
                "grain": grain_count,
                "umbrella": umbrella_count,
                "delivered": delivered_count,
                "unlabelled_open": unlabelled_open,
                "candidates": checked,
                "urn": urn,
                "pick": {
                    "number": item["number"],
                    "repo": item.get("repo", ""),
                    "title": item["title"],
                    "updatedAt": item.get("updatedAt", ""),
                },
            }
        print(json.dumps(output, indent=2))
    else:
        seed_origin = "explicit" if args.seed is not None else "derived"
        print(f"[SEED] machine={machine}, slot={slot}, seed={seed} ({seed_origin})")
        print(f"[CANDIDATS] tirage sans remise (top {args.top} -> elargi si tous pris) :")
        for i, c in enumerate(checked, 1):
            status = f"SKIP ({c['reason']})" if c["skipped"] else "LIBRE"
            print(f"  {i}. {c['urn']} {c['repo']}#{c['number']}: {c['title'][:80]} — {status}")
        if pick is None:
            print(f"[ALL-CLAIMED] Tous les candidats du pool sont pris "
                  f"({len(checked)} ecartes) — claims actifs ou etiquettes de lane.")
            print("Le pool n'est PAS vide : reessayer plus tard, ou demander arbitrage coordinateur.")
        else:
            urn, item = pick
            print(f"[PICK] Urne={urn}, {item.get('repo', '?')}#{item['number']}: {item['title']}")
            print(f"        Backlog={total_backlog}, grain={grain_count}, "
                  f"umbrella={umbrella_count}, delivered={delivered_count}, "
                  f"unlabelled_open={unlabelled_open}")

            if args.dry_run:
                # Affiche aussi le top-N des candidats par urne pour visibilite
                for name in ("grain", "umbrella", "delivered"):
                    top_n = buckets[name][:args.top]
                    if top_n:
                        print(f"\n[TOP {args.top}] urne={name}:")
                        for it in top_n:
                            print(f"  {it.get('repo', '?')}#{it['number']}: {it['title'][:80]}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
pick_idle_grain.py - Picker 3 urnes ponderees pour le pool executor roo-extensions.

Issue : #3675 (Epic #3111 phase 2, candidat #2)
Inspiration : CoursIA `pick_idle_grain.py` (PR #3155, passe 2 audit filesystem).
Bug local documente : #2509 (`--limit 15` faux drain).

Le picker tire dans 3 urnes ponderees :
  - grain      : issues actionnables (labels `approved` / `bug` / `investigation`)
  - umbrella   : issues parentes/epics (label `epic`) - signal de coordination
  - delivered  : PRs ouvertes livrables (toutes ; une PR ouverte n'est pas
                 encore un grain transforme - pas de lecture de verrou ici)

Reproduction : seed deterministe + jitter --reroll. --limit 300 corrige #2509.

Usage :
    python pick_idle_grain.py --dry-run                # Affiche le top sans l'engager
    python pick_idle_grain.py --json                  # Sortie JSON pour orchestration
    python pick_idle_grain.py --reroll                # Re-tirage aleatoire (graine decalee)
    python pick_idle_grain.py --limit 300             # Override limit gh issue list

Garde-fous (fail-closed, reviews #3681) :
  - Toute panne instrument (gh exit != 0, timeout, JSON invalide) rend un
    verdict ERROR avec exit 2 - JAMAIS un verdict de fond. Un instrument
    muet ne peut pas declarer le pool vide.
  - Verdict IDLE_REAL UNIQUEMENT si les 3 urnes sont vides APRES collecte
    reussie (gh exit 0, JSON valide) sur les 2 depots.
  - Encodage : stdout gh decode en UTF-8 avec errors="replace" - les titres
    accentues ne crashent plus le reader sous Windows cp1252.
"""
import argparse
import json
import random
import subprocess
import sys

# Pondérations par défaut - modifiables via --weights "grain:7,umbrella:2,delivered:1"
DEFAULT_WEIGHTS = {"grain": 7, "umbrella": 2, "delivered": 1}

# Labels actionnables (grain) - EXCLURE needs-approval/deferred/blocked-on-gate/epic
GRAIN_LABELS = {"approved", "bug", "investigation"}
UMBRELLA_LABELS = {"epic"}
# Gel par decision (#3381) : hors de TOUTE urne, meme avec un label actionnable
FROZEN_LABELS = {"frozen"}

# Repos a scanner (anti-double-claim #3407 : 2 depots)
REPOS = ["jsboige/roo-extensions", "jsboige/jsboige-mcp-servers"]


class GhCommandError(RuntimeError):
    """Panne instrument gh : exit non-nul, timeout ou JSON invalide.

    Fail-closed : le picker ne doit JAMAIS convertir une panne en verdict
    de fond (IDLE_REAL sur un pool potentiellement non-vide)."""

    def __init__(self, repo: str, reason: str):
        super().__init__(f"gh a echoue pour {repo}: {reason}")
        self.repo = repo
        self.reason = reason


def run_gh_json(cmd: list, repo: str, timeout: int = 60) -> list:
    """Execute gh, decode en UTF-8, parse JSON. Leve GhCommandError sur panne.

    Fail-closed : CalledProcessError / TimeoutExpired / JSONDecodeError sont
    des pannes d'instrument, pas des pools vides (review #3681, bloquant 2).
    """
    try:
        result = subprocess.run(
            cmd, capture_output=True, check=True, timeout=timeout,
            encoding="utf-8", errors="replace",
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        stderr = (e.stderr or "").strip() if isinstance(e.stderr, str) else ""
        raise GhCommandError(repo, f"exit {e.returncode}: {stderr}") from e
    except subprocess.TimeoutExpired as e:
        raise GhCommandError(repo, f"timeout apres {timeout}s") from e
    except json.JSONDecodeError as e:
        raise GhCommandError(repo, f"stdout non-JSON: {e}") from e


def run_gh_issue_list(repo: str, limit: int) -> list:
    """Execute gh issue list et retourne la liste JSON des issues."""
    cmd = [
        "gh", "issue", "list",
        "--repo", repo,
        "--state", "open",
        "--limit", str(limit),
        "--json", "number,title,labels,assignees,createdAt,updatedAt",
    ]
    return run_gh_json(cmd, repo)


def run_gh_pr_list(repo: str, limit: int) -> list:
    """Execute gh pr list pour l'urne 'delivered' (PRs ouvertes livrables)."""
    cmd = [
        "gh", "pr", "list",
        "--repo", repo,
        "--state", "open",
        "--limit", str(limit),
        "--json", "number,title,labels,assignees,createdAt,updatedAt",
    ]
    return run_gh_json(cmd, repo)


def bucketize_issues(issues: list) -> dict:
    """Repartit les issues dans les 3 urnes selon leurs labels."""
    buckets = {"grain": [], "umbrella": [], "delivered": []}
    for issue in issues:
        labels = {lbl["name"] for lbl in issue.get("labels", [])}
        if labels & FROZEN_LABELS:
            continue
        if labels & UMBRELLA_LABELS:
            buckets["umbrella"].append(issue)
        elif labels & GRAIN_LABELS:
            buckets["grain"].append(issue)
        # Les issues sans label actionnable ou avec labels exclus
        # (needs-approval, deferred, blocked-on-gate) ne sont dans aucune urne.
    return buckets


def weighted_pick(buckets: dict, weights: dict, seed: int, reroll: bool) -> tuple:
    """
    Tire une urne selon les poids, puis une issue au hasard dans l'urne.

    Retourne (urne, issue) ou (None, None) si toutes les urnes sont vides.
    """
    rng = random.Random(seed + (1 if reroll else 0))

    # Construit la liste des urnes eligibles (non vides) avec leurs poids
    eligible = [(name, weights[name]) for name in weights if buckets.get(name)]
    if not eligible:
        return None, None

    names = [n for n, _ in eligible]
    probs = [w / sum(w for _, w in eligible) for _, w in eligible]

    chosen_urn = rng.choices(names, weights=probs, k=1)[0]
    chosen_issue = rng.choice(buckets[chosen_urn])
    return chosen_urn, chosen_issue


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


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Picker 3 urnes ponderees pour le pool executor roo-extensions (issue #3675).",
    )
    parser.add_argument("--dry-run", action="store_true", help="Affiche le top sans l'engager.")
    parser.add_argument("--json", action="store_true", help="Sortie JSON machine-readable.")
    parser.add_argument("--reroll", action="store_true", help="Re-tirage avec graine decalee.")
    parser.add_argument("--limit", type=int, default=300, help="Limit gh issue list (defaut 300, corrige #2509).")
    parser.add_argument("--seed", type=int, default=42, help="Graine deterministe (defaut 42).")
    parser.add_argument("--weights", type=str, default="", help="Ponderations custom (ex: 'grain:7,umbrella:2,delivered:1').")
    parser.add_argument("--top", type=int, default=5, help="Nombre de candidats affiches en dry-run.")
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

    # Collecte issues + PRs sur les 2 depots - fail-closed : toute panne
    # instrument arrete le picker AVANT tout verdict (review #3681).
    all_issues = []
    all_prs = []
    errors = []
    for repo in REPOS:
        try:
            issues = run_gh_issue_list(repo, args.limit)
            all_issues.extend(issues)
            prs = run_gh_pr_list(repo, args.limit)
            all_prs.extend(prs)
        except GhCommandError as e:
            errors.append(e)
    if errors:
        return emit_error(errors, args.json)

    # Bucketize
    buckets = bucketize_issues(all_issues)
    buckets["delivered"] = all_prs  # PRs ouvertes = urne "delivered"

    # Test de fin de cycle : si backlog global non-vide MAIS sous-ensemble grain vide
    # ET urne umbrella vide ET delivered vide, on est REELLEMENT idle.
    # Sinon, le picker DOIT retourner un candidat (meme umbrella/delivered).
    total_backlog = len(all_issues)
    grain_count = len(buckets["grain"])
    umbrella_count = len(buckets["umbrella"])
    delivered_count = len(buckets["delivered"])
    actionnable_count = grain_count + umbrella_count + delivered_count

    if actionnable_count == 0:
        # Verdict IDLE REEL : aucun grain actionnable - collecte reussie, urnes vides
        if args.json:
            print(json.dumps({
                "verdict": "IDLE_REAL",
                "backlog_total": total_backlog,
                "grain": grain_count,
                "umbrella": umbrella_count,
                "delivered": delivered_count,
                "pick": None,
            }, indent=2))
        else:
            print(f"[IDLE-REAL] Backlog={total_backlog}, grain=0, umbrella=0, delivered=0.")
            print("Le pool est REELLEMENT draine. Passer au catalogue idle I1-I8.")
        return 0

    # Sinon : tirer un candidat
    urn, issue = weighted_pick(buckets, weights, args.seed, args.reroll)

    if args.json:
        output = {
            "verdict": "PICK",
            "backlog_total": total_backlog,
            "grain": grain_count,
            "umbrella": umbrella_count,
            "delivered": delivered_count,
            "urn": urn,
            "pick": {
                "number": issue["number"],
                "title": issue["title"],
                "updatedAt": issue.get("updatedAt", ""),
            },
        }
        print(json.dumps(output, indent=2))
    else:
        print(f"[PICK] Urne={urn}, Issue/PR #{issue['number']}: {issue['title']}")
        print(f"        Backlog={total_backlog}, grain={grain_count}, "
              f"umbrella={umbrella_count}, delivered={delivered_count}")

        if args.dry_run:
            # Affiche aussi le top-N des autres candidats par urne pour visibilite
            for name in ("grain", "umbrella", "delivered"):
                top_n = buckets[name][:args.top]
                if top_n:
                    print(f"\n[TOP {args.top}] urne={name}:")
                    for it in top_n:
                        print(f"  #{it['number']}: {it['title'][:80]}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

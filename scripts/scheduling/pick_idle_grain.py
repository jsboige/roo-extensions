#!/usr/bin/env python3
"""
pick_idle_grain.py - Picker 3 urnes ponderees pour le pool executor roo-extensions.

Issue : #3675 (Epic #3111 phase 2, candidat #2)
Inspiration : CoursIA `pick_idle_grain.py` (PR #3155, passe 2 audit filesystem).
Bug local documente : #2509 (`--limit 15` faux drain).

Le picker tire dans 3 urnes ponderees :
  - grain      : issues actionnables (labels `approved` / `bug` / `investigation`)
  - umbrella   : issues parentes/epics (label `epic`) - signal de coordination
  - delivered  : PRs ouvertes livrables non-fermees (verrou == commentaire)

Reproduction : seed deterministe + jitter --reroll. --limit 300 corrige #2509.

Usage :
    python pick_idle_grain.py --dry-run                # Affiche le top sans l'engager
    python pick_idle_grain.py --json                  # Sortie JSON pour orchestration
    python pick_idle_grain.py --reroll                # Re-tirage aleatoire (graine decalee)
    python pick_idle_grain.py --machine myia-po-2025  # Filtre Machine assignee
    python pick_idle_grain.py --limit 300             # Override limit gh issue list

Garde-fous :
  - Si `gh issue list --limit 300` retourne 0 issue, on est REELLEMENT draine.
  - Si le sous-ensemble actionnable est vide MAIS le backlog global est non-vide,
    le test de fin de cycle ECHOUE (cf. executor SKILL.md Phase 2 test-resultat).
"""
import argparse
import json
import os
import random
import subprocess
import sys
from pathlib import Path

# Pondérations par défaut - modifiables via --weights "grain:7,umbrella:2,delivered:1"
DEFAULT_WEIGHTS = {"grain": 7, "umbrella": 2, "delivered": 1}

# Labels actionnables (grain) - EXCLURE needs-approval/deferred/blocked-on-gate/epic
GRAIN_LABELS = {"approved", "bug", "investigation"}
UMBRELLA_LABELS = {"epic"}

# Repos a scanner (anti-double-claim #3407 : 2 depots)
REPOS = ["jsboige/roo-extensions", "jsboige/jsboige-mcp-servers"]


def run_gh_issue_list(repo: str, limit: int) -> list:
    """Execute gh issue list et retourne la liste JSON des issues."""
    cmd = [
        "gh", "issue", "list",
        "--repo", repo,
        "--state", "open",
        "--limit", str(limit),
        "--json", "number,title,labels,assignees,createdAt,updatedAt",
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=60)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] gh issue list echoue pour {repo}: {e.stderr}", file=sys.stderr)
        return []
    except subprocess.TimeoutExpired:
        print(f"[ERROR] gh issue list timeout pour {repo}", file=sys.stderr)
        return []


def run_gh_pr_list(repo: str, limit: int) -> list:
    """Execute gh pr list pour l'urne 'delivered' (PRs ouvertes non-fermees)."""
    cmd = [
        "gh", "pr", "list",
        "--repo", repo,
        "--state", "open",
        "--limit", str(limit),
        "--json", "number,title,labels,assignees,createdAt,updatedAt",
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=60)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] gh pr list echoue pour {repo}: {e.stderr}", file=sys.stderr)
        return []
    except subprocess.TimeoutExpired:
        print(f"[ERROR] gh pr list timeout pour {repo}", file=sys.stderr)
        return []


def bucketize_issues(issues: list) -> dict:
    """Repartit les issues dans les 3 urnes selon leurs labels."""
    buckets = {"grain": [], "umbrella": [], "delivered": []}
    for issue in issues:
        labels = {lbl["name"] for lbl in issue.get("labels", [])}
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


def filter_by_machine(issues: list, machine: str) -> list:
    """Filtre les issues dont l'assignee ou un label matche la machine."""
    if not machine:
        return issues
    filtered = []
    for issue in issues:
        # Check Project #67 champ Machine (label custom `machine:{name}` ou assignee)
        assignees = {a.get("login", "") for a in issue.get("assignees", [])}
        labels = {lbl["name"] for lbl in issue.get("labels", [])}
        if machine in assignees or f"machine:{machine}" in labels:
            filtered.append(issue)
    return filtered


def main():
    parser = argparse.ArgumentParser(
        description="Picker 3 urnes ponderees pour le pool executor roo-extensions (issue #3675).",
    )
    parser.add_argument("--dry-run", action="store_true", help="Affiche le top sans l'engager.")
    parser.add_argument("--json", action="store_true", help="Sortie JSON machine-readable.")
    parser.add_argument("--reroll", action="store_true", help="Re-tirage avec graine decalee.")
    parser.add_argument("--machine", type=str, default="", help="Filtre Machine assignee (ex: myia-po-2025).")
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

    # Collecte issues + PRs sur les 2 depots
    all_issues = []
    all_prs = []
    for repo in REPOS:
        issues = run_gh_issue_list(repo, args.limit)
        all_issues.extend(issues)
        prs = run_gh_pr_list(repo, args.limit)
        all_prs.extend(prs)

    # Filtre par machine si specifie
    if args.machine:
        all_issues = filter_by_machine(all_issues, args.machine)
        all_prs = filter_by_machine(all_prs, args.machine)

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
        # Verdict IDLE REEL : aucun grain actionnable
        verdict = "IDLE_REAL"
        if args.json:
            print(json.dumps({
                "verdict": verdict,
                "backlog_total": total_backlog,
                "grain": grain_count,
                "umbrella": umbrella_count,
                "delivered": delivered_count,
                "pick": None,
            }, indent=2))
        else:
            print(f"[IDLE-REAL] Backlog={total_backlog}, grain=0, umbrella=0, delivered=0.")
            print("Le pool est REELLEMENT draine. Passer au catalogue idle I1-I8.")
        sys.exit(0)

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


if __name__ == "__main__":
    main()

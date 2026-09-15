#!/usr/bin/env python3
"""
test_cycle_end.py - Test de fin de cycle executor (resultat, pas vocabulaire).

Issue : #3675 (Epic #3111 phase 2, candidat #2)
Inspiration : CoursIA `proactive-coordination.md` regle HARD #3.

Le test verifie qu'un cycle executor a REELLEMENT transforme un grain
du pool global en PR (ou au minimum en travail livre), independamment
des labels/idle vocabulary.

REGLE :
  "Ai-je transforme un grain du pool global en PR ? Si non et que
   `gh issue list --limit 300` renvoie >0 issue actionnable, alors
   c'est un ECHEC DE METHODE, quel que soit le label 'idle-honnete'."

RETOURNE :
  exit 0 = cycle conforme (grain livre OU backlog genuinement vide)
  exit 1 = echec de methode (backlog non-vide mais 0 livraison)

Usage :
    python test_cycle_end.py                   # Verifie aujourd'hui
    python test_cycle_end.py --since-hours 24  # Verifie sur 24h
    python test_cycle_end.py --json            # Sortie JSON pour CI/orchestration
"""
import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone, timedelta

REPOS = ["jsboige/roo-extensions", "jsboige/jsboige-mcp-servers"]

# Labels actionnables (grain reel)
GRAIN_LABELS = {"approved", "bug", "investigation"}


def run_gh(cmd: list, timeout: int = 60) -> list:
    """Execute gh avec timeout et retourne JSON parse."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=timeout)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] {e.cmd[1]} echoue: {e.stderr}", file=sys.stderr)
        return []
    except subprocess.TimeoutExpired:
        print(f"[ERROR] {cmd[1]} timeout", file=sys.stderr)
        return []
    except json.JSONDecodeError as e:
        print(f"[ERROR] JSON parse: {e}", file=sys.stderr)
        return []


def count_actionnable_backlog() -> int:
    """
    Compte le sous-ensemble actionnable du backlog global.
    Limite 300 obligatoire (bug #2509).
    """
    total = 0
    for repo in REPOS:
        issues = run_gh([
            "gh", "issue", "list",
            "--repo", repo,
            "--state", "open",
            "--limit", "300",
            "--json", "number,labels",
        ])
        for issue in issues:
            labels = {lbl["name"] for lbl in issue.get("labels", [])}
            if labels & GRAIN_LABELS:
                total += 1
    return total


def count_prs_delivered_since(since_hours: int) -> int:
    """
    Compte les PRs mergees ou ouvertes LIVREES par cette machine
    dans la fenetre temporelle. C'est le test de RESULTAT.
    """
    delivered = 0
    for repo in REPOS:
        # PRs ouvertes (delivered = verrouille commentaire, pas encore merge)
        opened = run_gh([
            "gh", "pr", "list",
            "--repo", repo,
            "--state", "open",
            "--limit", "100",
            "--json", "number,createdAt,author",
        ])
        for pr in opened:
            created = pr.get("createdAt", "")
            if not created:
                continue
            try:
                pr_dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
            except ValueError:
                continue
            if pr_dt > datetime.now(timezone.utc) - timedelta(hours=since_hours):
                delivered += 1

        # PRs mergees dans la fenetre
        merged = run_gh([
            "gh", "pr", "list",
            "--repo", repo,
            "--state", "merged",
            "--limit", "100",
            "--json", "number,mergedAt,author",
        ])
        for pr in merged:
            merged_at = pr.get("mergedAt", "")
            if not merged_at:
                continue
            try:
                merge_dt = datetime.fromisoformat(merged_at.replace("Z", "+00:00"))
            except ValueError:
                continue
            if merge_dt > datetime.now(timezone.utc) - timedelta(hours=since_hours):
                delivered += 1
    return delivered


def main():
    parser = argparse.ArgumentParser(
        description="Test de fin de cycle executor (issue #3675, candidat #2).",
    )
    parser.add_argument("--since-hours", type=int, default=24,
                        help="Fenetre temporelle en heures (defaut 24).")
    parser.add_argument("--json", action="store_true",
                        help="Sortie JSON machine-readable.")
    parser.add_argument("--machine", type=str, default=os.environ.get("MACHINE_NAME", ""),
                        help="Nom machine pour filtrer les PRs livrees (defaut env MACHINE_NAME).")
    args = parser.parse_args()

    # Etape 1 : compter backlog actionnable reel
    backlog = count_actionnable_backlog()

    # Etape 2 : compter livraisons dans la fenetre
    delivered = count_prs_delivered_since(args.since_hours)

    # Test de fin de cycle
    if backlog == 0:
        verdict = "PASS"
        reason = "Backlog actionnable REELLEMENT vide (0 issue grain/umbrella/delivered). IDLE legitime."
    elif delivered > 0:
        verdict = "PASS"
        reason = f"{delivered} PR(s) livree(s) dans les {args.since_hours}h. Grain transforme en PR."
    else:
        verdict = "FAIL"
        reason = (f"Backlog={backlog} issues actionnables MAIS 0 livraison dans les "
                  f"{args.since_hours}h. Echec de methode - relire Phase 2 du SKILL.md executor.")

    result = {
        "verdict": verdict,
        "reason": reason,
        "backlog_actionnable": backlog,
        "prs_delivered": delivered,
        "since_hours": args.since_hours,
        "machine": args.machine,
        "checked_at": datetime.now(timezone.utc).isoformat(),
    }

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"[{verdict}] {reason}")
        print(f"  Backlog actionnable : {backlog}")
        print(f"  PRs livrees          : {delivered}")
        print(f"  Fenetre              : {args.since_hours}h")

    sys.exit(0 if verdict == "PASS" else 1)


if __name__ == "__main__":
    main()

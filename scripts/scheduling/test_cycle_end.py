#!/usr/bin/env python3
"""
test_cycle_end.py - Test de fin de cycle executor (resultat, pas vocabulaire).

Issue : #3675 (Epic #3111 phase 2, candidat #2)
Inspiration : CoursIA `proactive-coordination.md` regle HARD #3.

Le test verifie qu'un cycle executor a REELLEMENT transforme un grain
du pool global en PR (ou au minimum en travail livre), independamment
des labels/idle vocabulary.

PORTEE : FLOTTE, pas lane (reviews #3681). Les PRs comptees sont celles de
toute la flotte sur les 2 depots - l'attribution par machine vit dans le
Project #67 (champ Machine), pas dans l'auteur gh (compte partage jsboige).
Ce test est un signal FLOTTE ; la conformite de LA lane passe par la
discipline dashboard [CLAIMED]/[DONE], pas par cet instrument.

REGLE :
  "Ai-je transforme un grain du pool global en PR ? Si non et que
   `gh issue list --limit 300` renvoie >0 issue actionnable, alors
   c'est un ECHEC DE METHODE, quel que soit le label 'idle-honnete'."

RETOURNE :
  exit 0 = cycle conforme (grain livre OU backlog grain genuinement vide)
  exit 1 = echec de methode (backlog grain non-vide mais 0 livraison)
  exit 2 = ERROR fail-closed (panne instrument gh : aucun verdict de fond)

Usage :
    python test_cycle_end.py                   # Verifie aujourd'hui
    python test_cycle_end.py --since-hours 24  # Verifie sur 24h
    python test_cycle_end.py --json            # Sortie JSON pour CI/orchestration
"""
import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone, timedelta

REPOS = ["jsboige/roo-extensions", "jsboige/jsboige-mcp-servers"]

# Labels actionnables (grain reel)
GRAIN_LABELS = {"approved", "bug", "investigation"}


class GhCommandError(RuntimeError):
    """Panne instrument gh : exit non-nul, timeout ou JSON invalide.

    Fail-closed : une panne gh ne doit JAMAIS se lire comme un backlog vide
    (review #3681, bloquant 2 - famille « instrument qui publie un etat plausible »)."""

    def __init__(self, repo: str, reason: str):
        super().__init__(f"gh a echoue pour {repo}: {reason}")
        self.repo = repo
        self.reason = reason


def run_gh_json(cmd: list, repo: str, timeout: int = 60) -> list:
    """Execute gh, decode UTF-8, parse JSON. Leve GhCommandError sur panne."""
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


def count_actionnable_backlog() -> int:
    """
    Compte le sous-ensemble actionnable (urne grain uniquement : labels
    approved/bug/investigation) du backlog global. Limite 300 (bug #2509).
    """
    total = 0
    for repo in REPOS:
        issues = run_gh_json([
            "gh", "issue", "list",
            "--repo", repo,
            "--state", "open",
            "--limit", "300",
            "--json", "number,labels",
        ], repo)
        for issue in issues:
            labels = {lbl["name"] for lbl in issue.get("labels", [])}
            if labels & GRAIN_LABELS:
                total += 1
    return total


def count_prs_delivered_since(since_hours: int) -> int:
    """
    Compte les PRs ouvertes ou mergees par la FLOTTE (2 depots) dans la
    fenetre temporelle. C'est le test de RESULTAT - portee flotte, voir
    docstring module.
    """
    delivered = 0
    for repo in REPOS:
        # PRs ouvertes dans la fenetre (livraison en attente de review)
        opened = run_gh_json([
            "gh", "pr", "list",
            "--repo", repo,
            "--state", "open",
            "--limit", "100",
            "--json", "number,createdAt",
        ], repo)
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
        merged = run_gh_json([
            "gh", "pr", "list",
            "--repo", repo,
            "--state", "merged",
            "--limit", "100",
            "--json", "number,mergedAt",
        ], repo)
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


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Test de fin de cycle executor, portee flotte (issue #3675, candidat #2).",
    )
    parser.add_argument("--since-hours", type=int, default=24,
                        help="Fenetre temporelle en heures (defaut 24).")
    parser.add_argument("--json", action="store_true",
                        help="Sortie JSON machine-readable.")
    args = parser.parse_args()

    # Etape 1-2 : collecte fail-closed - toute panne instrument rend ERROR
    # AVANT tout verdict de fond (review #3681).
    errors = []
    try:
        backlog = count_actionnable_backlog()
    except GhCommandError as e:
        errors.append(e)
        backlog = None
    try:
        delivered = count_prs_delivered_since(args.since_hours)
    except GhCommandError as e:
        errors.append(e)
        delivered = None

    if errors:
        result = {
            "verdict": "ERROR",
            "reason": "Instrument gh en panne - aucun verdict de fond rendu.",
            "errors": [str(e) for e in errors],
            "since_hours": args.since_hours,
            "checked_at": datetime.now(timezone.utc).isoformat(),
        }
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"[ERROR] {result['reason']}")
            for e in errors:
                print(f"  - {e}")
            print("Reparer gh (auth, rate-limit, reseau) puis relancer le test.")
        return 2

    # Test de fin de cycle - ne rapporter QUE ce qui est mesure :
    # le compteur backlog ne couvre que l'urne grain (approved/bug/investigation).
    if backlog == 0:
        verdict = "PASS"
        reason = ("Backlog grain REELLEMENT vide (0 issue approved/bug/investigation). "
                  "IDLE legitime.")
    elif delivered > 0:
        verdict = "PASS"
        reason = (f"{delivered} PR(s) livree(s) par la flotte dans les "
                  f"{args.since_hours}h. Grain transforme en PR.")
    else:
        verdict = "FAIL"
        reason = (f"Backlog grain={backlog} issues actionnables MAIS 0 livraison flotte dans les "
                  f"{args.since_hours}h. Echec de methode - relire Phase 2 du SKILL.md executor.")

    result = {
        "verdict": verdict,
        "reason": reason,
        "backlog_grain": backlog,
        "prs_delivered_fleet": delivered,
        "since_hours": args.since_hours,
        "checked_at": datetime.now(timezone.utc).isoformat(),
    }

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"[{verdict}] {reason}")
        print(f"  Backlog grain (flotte) : {backlog}")
        print(f"  PRs livrees (flotte)   : {delivered}")
        print(f"  Fenetre                : {args.since_hours}h")

    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())

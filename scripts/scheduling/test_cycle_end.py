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
import re
import subprocess
import sys
from datetime import datetime, timezone, timedelta

REPOS = ["jsboige/roo-extensions", "jsboige/jsboige-mcp-servers"]

# Labels actionnables (grain reel)
GRAIN_LABELS = {"approved", "bug", "investigation"}

# Labels d'attente/gel : une issue qui en porte un n'est pas actionnable, meme
# si elle porte AUSSI un label grain (co-occurrence mesuree 03/10 : #4038,
# bug + needs-approval, comptait dans le backlog). Parite avec le picker ADR 016
# et avec la decision frozen #3381/#3809 : ne pas presser une lane vers un
# grain que l'arbitrage n'a pas debloque.
GATED_LABELS = {"needs-approval", "deferred", "blocked-on-gate", "frozen"}


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


def fetch_open_issues(repo: str) -> list:
    """Issues ouvertes d'un depot (limite 300, bug #2509), fail-closed."""
    return run_gh_json([
        "gh", "issue", "list",
        "--repo", repo,
        "--state", "open",
        "--limit", "300",
        "--json", "number,title,labels",
    ], repo)


def issue_labels(issue: dict) -> set:
    return {lbl["name"] for lbl in issue.get("labels", [])}


def count_actionnable_backlog(issues_by_repo: dict = None) -> int:
    """
    Compte le sous-ensemble actionnable (urne grain uniquement : labels
    approved/bug/investigation) du backlog global. Limite 300 (bug #2509).
    """
    if issues_by_repo is None:
        issues_by_repo = {repo: fetch_open_issues(repo) for repo in REPOS}
    total = 0
    for issues in issues_by_repo.values():
        for issue in issues:
            labels = issue_labels(issue)
            if labels & GRAIN_LABELS and not labels & GATED_LABELS:
                total += 1
    return total


def list_approved_without_pr(issues_by_repo: dict) -> list:
    """
    #3381 D3 : issues portant le label `approved` (ouvertes, non gatees)
    qu'aucune PR ouverte ne couvre, sur les 2 depots.

    Couverture = frontiere de mot sur le numero dans le titre de la PR
    (`#N([^0-9]|$)`) - le --search GitHub est flou (mesure 05/09) et la
    parite exacte avec la discipline anti-double-claim est requise.
    Vue deterministe destinee au statut du dashboard (les etats GitHub
    ne viennent JAMAIS de la condensation LLM, #3771).
    """
    covered = set()
    prs_by_repo = {}
    for repo in REPOS:
        prs = run_gh_json([
            "gh", "pr", "list",
            "--repo", repo,
            "--state", "open",
            "--limit", "100",
            "--json", "number,title",
        ], repo)
        prs_by_repo[repo] = prs
        for pr in prs:
            title = pr.get("title", "")
            for m in re.finditer(r"#(\d+)(?!\d)", title):
                covered.add((repo, int(m.group(1))))

    result = []
    for repo in REPOS:
        for issue in issues_by_repo.get(repo, []):
            labels = issue_labels(issue)
            if "approved" not in labels or labels & GATED_LABELS:
                continue
            number = issue.get("number")
            if (repo, number) in covered:
                continue
            result.append({
                "repo": repo,
                "number": number,
                "title": issue.get("title", ""),
            })
    result.sort(key=lambda i: (i["repo"], i["number"]))
    return result


# D4 - organe anti-endormissement (escalade user 19/10 23:34Z, Maintenance#121) :
# un chantier ouvert depuis >= 30 j doit porter une decision DATEE (GO date,
# obstacle nomme, abandon propose) et bouger. La mesure remplace un registre
# tenu a la main, qui s'endort comme ce qu'il surveille.
CHANTIER_LABELS = ("epic", "approved")
CHANTIER_MIN_AGE_DAYS = 30
DORMANT_DAYS = 14
COMMENTS_PAGE = 100  # plafond de commentaires par issue dans `gh issue list`
# Commentaires qui ne disent rien de l'avancement : verrous et rapports vides
# des workers (mesure #3151 : 30 des 82 commentaires).
_BOILERPLATE = re.compile(
    r"^\s*\[(CLAIMED|RELEASED)\]"
    r"|^\s*\[RESULT\][^\n]{0,120}(no actionable result|no code changes needed)",
    re.IGNORECASE)
_DECISION_MARK = re.compile(
    r"\[(D[ÉE]CISION|ARBITRAGE|GO)\b|D[ée]cision dat[ée]e|Arbitrage user",
    re.IGNORECASE)
_DATE = re.compile(r"\b\d{1,2}/\d{1,2}\b|\b\d{4}-\d{2}-\d{2}\b")


def _parse_ts(value: str):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def classify_chantier(issue: dict, now: datetime):
    """Rend la ligne D4 d'une issue, ou None si elle n'est pas un chantier >= 30 j."""
    created = _parse_ts(issue["createdAt"])
    age = (now - created).days
    if age < CHANTIER_MIN_AGE_DAYS:
        return None
    comments = issue.get("comments") or []
    substantive = [c for c in comments if not _BOILERPLATE.search(c.get("body", ""))]
    last = max((_parse_ts(c["createdAt"]) for c in substantive), default=created)
    decisions = [_parse_ts(c["createdAt"]) for c in comments
                 if _DECISION_MARK.search(c.get("body", "")) and _DATE.search(c.get("body", ""))]
    idle = (now - last).days
    flags = []
    if not decisions:
        flags.append("sans decision datee")
    if idle > DORMANT_DAYS:
        flags.append(f"dormant {idle} j")
    gate = sorted(issue_labels(issue) & GATED_LABELS)
    return {
        "number": issue["number"],
        "title": issue.get("title", ""),
        "age_days": age,
        "idle_days": idle,
        "last_decision": max(decisions).strftime("%Y-%m-%d") if decisions else None,
        "gate": gate,
        "flags": flags,
    }


def list_chantiers(repos=REPOS, now=None) -> list:
    """D4 : chantiers (labels epic/approved) ouverts depuis >= 30 j, signales d'abord."""
    now = now or datetime.now(timezone.utc)
    result = []
    for repo in repos:
        seen = {}
        for label in CHANTIER_LABELS:
            for issue in run_gh_json([
                "gh", "issue", "list", "--repo", repo, "--state", "open",
                "--label", label, "--limit", "200",
                "--json", "number,title,labels,createdAt,comments",
            ], repo, timeout=120):
                seen[issue["number"]] = issue
        for issue in seen.values():
            # `gh issue list` ne rend que les 100 premiers commentaires (mesure 20/10 :
            # #622 en a 694, dernier lu le 14/03 au lieu du 14/10) ; `gh issue view`
            # les rend tous.
            if len(issue.get("comments") or []) >= COMMENTS_PAGE:
                issue["comments"] = run_gh_json([
                    "gh", "issue", "view", str(issue["number"]), "--repo", repo,
                    "--json", "comments",
                ], repo, timeout=120)["comments"]
            row = classify_chantier(issue, now)
            if row:
                row["repo"] = repo
                result.append(row)
    result.sort(key=lambda r: (not r["flags"], -r["idle_days"], r["number"]))
    return result


def format_chantier_line(row: dict) -> str:
    repo_short = row["repo"].split("/")[-1]
    decision = row["last_decision"] or "aucune"
    marks = "".join(f" **[{f}]**" for f in row["flags"])
    gate = f" (gate: {','.join(row['gate'])})" if row["gate"] else ""
    return (f"- {repo_short}#{row['number']} — {row['age_days']} j, derniere activite il y a "
            f"{row['idle_days']} j, decision datee : {decision}{gate}{marks} — {row['title'][:70]}")


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
    parser.add_argument("--status-block", action="store_true",
                        help="#3381 D3 : emet en plus un bloc markdown pret a poster "
                             "dans la section status du dashboard (issues approved sans PR), "
                             "plus D4 : chantiers ouverts >= 30 j, signales sans decision "
                             "datee ou dormants > 14 j.")
    args = parser.parse_args()

    # Etape 1-2 : collecte fail-closed - toute panne instrument rend ERROR
    # AVANT tout verdict de fond (review #3681).
    errors = []
    approved_no_pr = None
    try:
        issues_by_repo = {repo: fetch_open_issues(repo) for repo in REPOS}
        backlog = count_actionnable_backlog(issues_by_repo)
        approved_no_pr = list_approved_without_pr(issues_by_repo)
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
        "approved_no_pr": approved_no_pr,
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
        if approved_no_pr is not None:
            print(f"  Approved sans PR (D3)  : {len(approved_no_pr)}")

    if args.status_block:
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        if approved_no_pr is None:
            print(f"### Issues approuvees sans PR (auto, {stamp})\n- donnees indisponibles (instrument gh en panne)")
        elif not approved_no_pr:
            print(f"### Issues approuvees sans PR (auto, {stamp})\n- aucune")
        else:
            lines = [f"### Issues approuvees sans PR (auto, {stamp}) — {len(approved_no_pr)}"]
            for item in approved_no_pr:
                repo_short = item["repo"].split("/")[-1]
                lines.append(f"- {repo_short}#{item['number']} — {item['title']}")
            print("\n".join(lines))
        # D4 : chaque ligne signalee recoit, dans le cycle, une ligne datee sur son
        # issue (GO date, obstacle avec preuve, ou abandon propose au user).
        try:
            chantiers = list_chantiers()
        except GhCommandError as e:
            print(f"### Chantiers ouverts >= {CHANTIER_MIN_AGE_DAYS} j (auto, {stamp})\n"
                  f"- donnees indisponibles ({e})")
        else:
            flagged = [r for r in chantiers if r["flags"]]
            calm = [r for r in chantiers if not r["flags"]]
            lines = [f"### Chantiers ouverts >= {CHANTIER_MIN_AGE_DAYS} j (auto, {stamp}) — "
                     f"{len(chantiers)}, dont {len(flagged)} signales"]
            lines += [format_chantier_line(r) for r in flagged]
            if calm:
                lines.append(f"- sans signal ({len(calm)}) : "
                             + ", ".join(f"{r['repo'].split('/')[-1]}#{r['number']}" for r in calm))
            if not chantiers:
                lines.append("- aucun")
            print("\n".join(lines))

    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())

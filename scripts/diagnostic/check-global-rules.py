#!/usr/bin/env python3
"""
check-global-rules.py — les regles globales sont-elles deployees, et SANS doublon (#2368 volet 2).

Pourquoi cet instrument existe
------------------------------
Les regles de `.claude/configs/rules/` sont la SEULE source : elles sont deployees
dans `~/.claude/rules/` par `Deploy-GlobalConfig.ps1 -Target rules`, ou elles se
chargent dans TOUS les workspaces du siege.

Jusqu'au 09/11/2026, deux d'entre elles vivaient AUSSI dans `.claude/rules/` comme
"copie pour les sieges ou la regle globale n'est pas deployee". Sur un siege
deploye, le meme sujet etait donc charge DEUX fois par session (mesure po-2027 :
`harnais-tightening` 14 l. projet + 32 l. global ; ai-01 : les deux regles en
double). Les copies projet sont supprimees (#2368 volet 2) — ce qui laisse un
trou : un siege qui n'a jamais lance le deploy perdrait la regle EN SILENCE.

Cet instrument ferme les deux bouts :
  1. DEPLOY  — chaque fichier source doit exister a l'identique dans le dossier global ;
  2. DOUBLON — aucun fichier source ne doit etre re-introduit dans `.claude/rules/`
     du depot (c'est exactement le doublon qu'on vient de retirer).

Sorties par fichier source :
    OK        deploye, contenu identique
    MISSING   absent du dossier global              -> finding (siege non deploye)
    STALE     present mais contenu different        -> finding (deploy perime)
    DUPLICATE present AUSSI dans .claude/rules/     -> finding (double chargement)

Usage:
    python check-global-rules.py                        # siege courant, depot deduit du script
    python check-global-rules.py --repo <chemin>        # autre checkout
    python check-global-rules.py --global-dir <chemin>  # autre dossier global (tests)
    python check-global-rules.py --json                 # machine-readable
    python check-global-rules.py --selftest             # fixtures synthetiques

Exit codes: 0 = rien a signaler, 2 = >=1 finding, 1 = erreur d'instrument.

Posture : lecture seule, aucune ecriture, aucun reseau. Le pre-vol executeur le
relaye en `[RULES-DEPLOY]` et le cycle continue (jamais bloquant).
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

EXIT_CLEAN = 0
EXIT_ERROR = 1
EXIT_FINDINGS = 2

SOURCE_REL = Path(".claude") / "configs" / "rules"
PROJECT_REL = Path(".claude") / "rules"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


def line_count(path):
    try:
        return len(path.read_text(encoding="utf-8", errors="replace").splitlines())
    except OSError:
        return 0


def run(repo, global_dir):
    """Retourne (findings, rows). Ne leve pas : l'appelant decide du code de sortie."""
    source_dir = repo / SOURCE_REL
    project_dir = repo / PROJECT_REL
    if not source_dir.is_dir():
        raise FileNotFoundError(f"source introuvable : {source_dir}")

    rows = []
    for src in sorted(source_dir.glob("*.md")):
        target = global_dir / src.name
        if target.is_file():
            deployed = "OK" if digest(target) == digest(src) else "STALE"
        else:
            deployed = "MISSING"
        # Un doublon ne doit pas MASQUER un deploiement absent : on garde l'etat
        # global dans le detail, sinon un siege non deploye qui a encore sa copie
        # projet lirait "DUPLICATE" et conclurait que la regle est servie.
        status = "DUPLICATE" if (project_dir / src.name).is_file() else deployed
        rows.append(
            {
                "file": src.name,
                "status": status,
                "global": deployed,
                "source_lines": line_count(src),
                "global_lines": line_count(target) if target.is_file() else 0,
                "global_dir": str(global_dir),
            }
        )
    return [r for r in rows if r["status"] != "OK"], rows


def selftest():
    import tempfile

    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        repo = root / "repo"
        (repo / SOURCE_REL).mkdir(parents=True)
        (repo / PROJECT_REL).mkdir(parents=True)
        gl = root / "global"
        gl.mkdir()

        (repo / SOURCE_REL / "deployed.md").write_text("# a\n", encoding="utf-8")
        (gl / "deployed.md").write_text("# a\n", encoding="utf-8")

        (repo / SOURCE_REL / "missing.md").write_text("# b\n", encoding="utf-8")

        (repo / SOURCE_REL / "stale.md").write_text("# c\n", encoding="utf-8")
        (gl / "stale.md").write_text("# c old\n", encoding="utf-8")

        (repo / SOURCE_REL / "dupe.md").write_text("# d\n", encoding="utf-8")
        (gl / "dupe.md").write_text("# d\n", encoding="utf-8")
        (repo / PROJECT_REL / "dupe.md").write_text("# d summary\n", encoding="utf-8")

        # Doublon SANS deploiement global : le pire cas (le doublon masquerait le trou).
        (repo / SOURCE_REL / "dupe-missing.md").write_text("# e\n", encoding="utf-8")
        (repo / PROJECT_REL / "dupe-missing.md").write_text("# e summary\n", encoding="utf-8")

        findings, rows = run(repo, gl)
        seen = {r["file"]: r["status"] for r in rows}
        expected = {
            "deployed.md": "OK",
            "missing.md": "MISSING",
            "stale.md": "STALE",
            "dupe.md": "DUPLICATE",
            "dupe-missing.md": "DUPLICATE",
        }
        for name, want in expected.items():
            got = seen.get(name)
            if got != want:
                failures.append(f"{name}: attendu {want}, mesure {got}")
        globals_seen = {r["file"]: r["global"] for r in rows}
        if globals_seen.get("dupe-missing.md") != "MISSING":
            failures.append(f"dupe-missing.md: etat global attendu MISSING, mesure {globals_seen.get('dupe-missing.md')}")
        if len(findings) != 4:
            failures.append(f"findings attendus 4, mesures {len(findings)}")

    for f in failures:
        print(f"SELFTEST FAIL {f}")
    print("SELFTEST " + ("PASS" if not failures else "FAIL"))
    return EXIT_CLEAN if not failures else EXIT_FINDINGS


def main(argv=None):
    parser = argparse.ArgumentParser(description="Regles globales deployees et sans doublon (#2368)")
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--global-dir", default=str(Path.home() / ".claude" / "rules"))
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args(argv)

    if args.selftest:
        return selftest()

    try:
        findings, rows = run(Path(args.repo), Path(args.global_dir))
    except OSError as exc:
        print(f"INSTRUMENT-ERROR {exc}")
        return EXIT_ERROR

    if args.json:
        print(json.dumps({"repo": args.repo, "globalDir": args.global_dir, "rows": rows}, indent=2))
    else:
        for r in rows:
            detail = ""
            if r["status"] == "STALE":
                detail = f" (source {r['source_lines']} l., global {r['global_lines']} l.)"
            elif r["status"] == "MISSING":
                detail = " (absent du dossier global)"
            elif r["status"] == "DUPLICATE":
                detail = (
                    f" (aussi dans .claude/rules/ du depot — double chargement ;"
                    f" deploye dans le dossier global : {r['global']})"
                )
            print(f"{r['status']:<10} {r['file']}{detail}")
        if findings:
            print(
                "\nReparer : pwsh -File .claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target rules"
                "\n(siege non deploye = regle absente de CE workspace ; doublon = deux chargements par session)"
            )

    return EXIT_FINDINGS if findings else EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())

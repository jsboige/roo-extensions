#!/usr/bin/env python3
"""
audit-stale-mcp-disables.py — Audit READ-ONLY des désactivations MCP fantômes de
~/.claude.json (volet 3, #4195).

L'emplacement 3 de l'état MCP (`projects[<workspace>].disabledMcpServers`, cf.
docs/harness/reference/tool-availability-detailed.md § #3137/#4195) est indexé par le
chemin ABSOLU du workspace : un déménagement (C:\\dev -> D:\\Dev) rend la désactivation
fantôme et réactive silencieusement le MCP (incident po-2024 09/10 : fenêtre OAuth
google-workspace ouverte sans demande, consigne user « svp ne faites pas ça. Demandez
moi avant »).

Ce scanner signale, sans jamais rien écrire :
    STALE-GHOST  — clé projects[chemin] dont le chemin n'existe PLUS et qui porte des
                   disabledMcpServers : le résidu invisible de l'intérieur d'une session
                   (la désactivation ne protège plus rien, le MCP est réactivé).
    ACTIVE       — clé de chemin EXISTANT portant des disabledMcpServers (état légitime,
                   informatif — contrôle gratuit d'ouverture de session, volet 1).

Usage:
    python audit-stale-mcp-disables.py                     # audite ~/.claude.json
    python audit-stale-mcp-disables.py --config <fichier> # autre config
    python audit-stale-mcp-disables.py --json             # sortie machine-readable
    python audit-stale-mcp-disables.py --selftest         # fixture synthétique

Exit codes: 0 = aucun STALE-GHOST, 2 = >=1 STALE-GHOST, 1 = erreur.
"""

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path

EXIT_CLEAN = 0
EXIT_ERROR = 1
EXIT_FINDINGS = 2

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")  # console cp1252 vs chemins UTF-8 (#4059)


def audit(config_path: str) -> dict:
    """Return {'stale': [...], 'active': [...], 'projects_count': int}. Read-only."""
    path = Path(config_path)
    if not path.is_file():
        raise FileNotFoundError(f"config not found: {config_path}")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    projects = data.get("projects") or {}
    stale, active = [], []
    for key, entry in projects.items():
        if not isinstance(entry, dict):
            continue
        disabled = entry.get("disabledMcpServers") or []
        disabled = [d for d in disabled if isinstance(d, str) and d]
        if not disabled:
            continue
        record = {"key": key, "disabledMcpServers": sorted(disabled)}
        # Windows: isdir est insensible a la casse et accepte / comme \\.
        if os.path.isdir(key):
            active.append(record)
        else:
            stale.append(record)
    return {
        "stale": stale,
        "active": active,
        "projects_count": len(projects),
    }


def selftest() -> int:
    """Synthetic fixture: one stale-ghost key, one active key, one empty key."""
    tmp = Path(tempfile.mkdtemp(prefix="audit-stale-mcp-selftest-"))
    live_dir = tmp / "live-ws"
    live_dir.mkdir()
    ghost = str(tmp / "moved-away" / "ws")  # jamais cree
    config = tmp / "claude.json"
    config.write_text(
        json.dumps(
            {
                "projects": {
                    ghost: {"disabledMcpServers": ["google-workspace", "sk-agent"]},
                    str(live_dir): {"disabledMcpServers": ["jupyter-papermill"]},
                    str(tmp / "empty-ws"): {"disabledMcpServers": []},
                    str(tmp / "no-field"): {"something": "else"},
                }
            }
        ),
        encoding="utf-8",
    )
    result = audit(str(config))
    assert len(result["stale"]) == 1, f"expected 1 stale, got {result['stale']}"
    assert result["stale"][0]["disabledMcpServers"] == ["google-workspace", "sk-agent"]
    assert len(result["active"]) == 1, f"expected 1 active, got {result['active']}"
    assert result["active"][0]["disabledMcpServers"] == ["jupyter-papermill"]
    assert result["projects_count"] == 4
    # Cleanup: fichiers nommes uniquement, jamais de rmtree sauvage.
    # (empty-ws et no-field n'existaient que comme cles JSON, jamais sur disque)
    config.unlink()
    live_dir.rmdir()
    try:
        tmp.rmdir()
    except OSError:
        pass
    print("[SELFTEST] PASS (1 stale-ghost, 1 active, empty/no-field ignores)")
    return EXIT_CLEAN


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit read-only des desactivations MCP fantomes (#4195)")
    parser.add_argument("--config", default=os.path.expanduser("~/.claude.json"), help="chemin de la config a auditer (defaut ~/.claude.json)")
    parser.add_argument("--json", action="store_true", help="sortie machine-readable")
    parser.add_argument("--selftest", action="store_true", help="validation sur fixture synthetique")
    args = parser.parse_args()

    if args.selftest:
        return selftest()

    try:
        result = audit(args.config)
    except Exception as exc:  # noqa: BLE001 - instrument fail-closed
        print(f"[ERROR] {exc}")
        return EXIT_ERROR

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"config: {args.config} ({result['projects_count']} cles projects)")
        if not result["stale"] and not result["active"]:
            print("[OK] aucune desactivation par chemin (map vide ou sans disabledMcpServers)")
        for rec in result["stale"]:
            names = ", ".join(rec["disabledMcpServers"])
            print(f"[STALE-GHOST] chemin inexistant: {rec['key']}  desactivations orphelines: {names}")
        for rec in result["active"]:
            names = ", ".join(rec["disabledMcpServers"])
            print(f"[ACTIVE] chemin existant: {rec['key']}  desactivations: {names}")

    if result["stale"]:
        print(f"[FINDINGS] {len(result['stale'])} cle(s) chemin-perimee(s) portent des disabledMcpServers")
        return EXIT_FINDINGS
    print("[CLEAN] 0 residu chemin-perime")
    return EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())

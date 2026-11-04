#!/usr/bin/env python3
"""Verifie, pour un siege, que chaque MCP repute fonctionnel est REELLEMENT la.

Motif (mandat user 2026-11-03) : « pas facile a voir de l'interieur quand ils ne
sont pas demarres ». Un serveur MCP peut etre declare et mourir au spawn sans
qu'aucune surface de configuration ne le dise : `.mcp.json`, `~/.claude.json`
`mcpServers` et `projects[<ws>].mcpServers` decrivent tous une INTENTION, jamais
un processus. Seul un handshake stdio reel prouve la presence.

Trois surfaces de declaration, resolues dans l'ordre canonique (meme ordre que
`check-deny-fallback.py`, pour que deux organes ne divergent pas) :

  1. `<workspace>/.mcp.json`                       (projet, versionne)
  2. `~/.claude.json projects[<ws>].mcpServers`    (projet, local)
  3. `~/.claude.json mcpServers`                   (global, toutes sessions)

Le seul emplacement qui DESACTIVE reellement un serveur sur un siege Claude Code
est `projects[<ws>].disabledMcpServers` ; un `"disabled": true` dans une entree
`.mcp.json` est **inerte** (mesure #4340).

Verdicts par serveur :

  LIVE      handshake `initialize` -> `tools/list` reussi, N outils
  DEAD      declare et actif, mais le handshake echoue (cause nommee)
  DISABLED  present dans `disabledMcpServers` du siege (l'intention est explicite)
  UNKNOWN   `--no-handshake` : declaration lue, presence non mesuree

Sortie (revue ai-01 04/11 — l'automate qui lit `$?` ne lit pas le docstring) :

  0  mesure reelle, tous LIVE/DISABLED (aucune erreur de lecture)
  2  au moins un DEAD — une absence MESUREE se signale, meme si une autre
     surface a echoue a se lire
  1  erreur d'instrument : au moins une surface n'a pas pu etre lue. JAMAIS 0
     dans ce cas — un tally partiel n'est pas un siege sain (un
     `~/.claude.json` corrompu porte `disabledMcpServers` ET la majorite des
     declarations)
  3  rien n'a ete mesure (`--no-handshake`) : declaration lue, presence non
     sondee — sain mais chemin non exerce (forme maison de
     `mcp-chain-slowcall-probe`)

Precedence : erreur de lecture (1/2) > non-mesure (3) > verdict de presence.
`STALE-DISABLE` sort 0 (une desactivation perimee n'est pas un serveur mort)
mais reste affiche comme « a purger ».

Ce que cet organe ne peut pas faire : mesurer un siege distant. Depuis un siege,
on ne prouve la presence que LOCALEMENT ; pour les autres postes, la seule
lecture disponible est declarative (RooSync `compare_config --granularity mcp`,
`audit-stale-mcp-disables.py`). Ce plafond se dit, il ne se maquille pas.
"""

import argparse
import importlib.util
import json
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _load_handshake():
    """Reutilise le handshake de check-deny-fallback.py (pas de second organe)."""
    path = HERE / "check-deny-fallback.py"
    spec = importlib.util.spec_from_file_location("deny_fallback", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.handshake


def load_json_or_none(path, errors):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        return None
    except Exception as exc:  # noqa: BLE001 - un fichier illisible se signale
        errors.append(f"{path}: {exc}")
        return None


def user_config_path():
    return Path(os.path.expanduser("~")) / ".claude.json"


def project_entry(user_config, workspace):
    """Entree `projects[<ws>]` du siege, insensible a la casse du chemin.

    Les cles de `~/.claude.json` sont des chaines litterales ; sous Windows le
    chemin d'un meme siege s'ecrit `d:/dev/CoursIA` ou `D:/dev/CoursIA` selon
    l'appelant. Une correspondance exacte rate alors `disabledMcpServers` et
    rend un serveur desactive comme s'il etait actif (faux positif mesure le
    2026-11-03 : `sk-agent` declare DISABLED sous `d:/...`, sonde sous `D:/...`).
    """
    projects = (user_config or {}).get("projects") or {}
    wanted = os.path.normcase(os.path.normpath(str(workspace)))
    for key, value in projects.items():
        if os.path.normcase(os.path.normpath(str(key))) == wanted:
            return value if isinstance(value, dict) else {}
    return {}


def normalize_entry(entry, workspace):
    """Rend l'entree lancable telle que Claude Code la lancerait.

    Deux ecarts mesures le 2026-11-03, tous deux imputables a la SONDE et non au
    siege -- ils fabriquaient 3 faux `DEAD` sur 4 :
      - `cwd` absent : un chemin relatif d'argument (`python scripts/x/server.py`)
        se resout contre le repertoire courant de la sonde, pas contre le
        workspace. Claude Code lance depuis le workspace.
      - `npx`/`uvx` sans extension : sous Windows ce sont des `.cmd`, que
        `subprocess` sans shell ne resout pas (WinError 2).
    """
    fixed = dict(entry)
    if not isinstance(fixed.get("cwd"), str):
        fixed["cwd"] = str(workspace)
    command = fixed.get("command")
    if isinstance(command, str) and command:
        resolved = shutil.which(command)
        if resolved is None:
            for suffix in (".cmd", ".exe", ".bat"):
                resolved = shutil.which(command + suffix)
                if resolved:
                    break
        if resolved:
            fixed["command"] = resolved
    return fixed


def collect(workspace, user_config, errors):
    """Retourne {server: {"entry", "sources", "disabled"}} pour le siege."""
    servers = {}

    def add(name, entry, source):
        if not isinstance(entry, dict):
            return
        slot = servers.setdefault(name, {"entry": None, "sources": [], "disabled": False})
        slot["sources"].append(source)
        slot["entry"] = entry  # ordre canonique : le dernier ecrit gagne

    global_servers = (user_config or {}).get("mcpServers") or {}
    for name, entry in global_servers.items():
        add(name, entry, "~/.claude.json mcpServers")

    project = project_entry(user_config, workspace)
    for name, entry in (project.get("mcpServers") or {}).items():
        add(name, entry, f"~/.claude.json projects[{workspace}].mcpServers")

    ws_mcp = load_json_or_none(Path(workspace) / ".mcp.json", errors)
    if isinstance(ws_mcp, dict):
        for name, entry in (ws_mcp.get("mcpServers") or {}).items():
            add(name, entry, ".mcp.json")

    disabled = [d for d in (project.get("disabledMcpServers") or []) if isinstance(d, str)]
    for name in disabled:
        slot = servers.setdefault(name, {"entry": None, "sources": [], "disabled": False})
        slot["disabled"] = True

    return servers, disabled


def probe(servers, timeout, do_handshake, workspace):
    handshake = _load_handshake() if do_handshake else None
    records = []
    for name in sorted(servers):
        slot = servers[name]
        entry = slot["entry"]
        record = {
            "server": name,
            "declared": entry is not None,
            "sources": slot["sources"],
            "disabled": slot["disabled"],
        }
        if slot["disabled"] and entry is None:
            record["verdict"] = "STALE-DISABLE"
            record["detail"] = "desactive mais declare nulle part (configuration perimee)"
        elif slot["disabled"]:
            record["verdict"] = "DISABLED"
            record["detail"] = "projects[].disabledMcpServers"
        elif not do_handshake:
            record["verdict"] = "UNKNOWN"
            record["detail"] = "declaration lue, presence non mesuree (--no-handshake)"
        else:
            ok, detail = handshake(normalize_entry(entry, workspace), timeout)
            record["verdict"] = "LIVE" if ok else "DEAD"
            record["detail"] = detail
        records.append(record)
    return records


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Presence reelle des MCP sur un siege (handshake stdio)."
    )
    parser.add_argument("--workspace", default=os.getcwd())
    parser.add_argument("--timeout", type=float, default=60.0,
                        help="budget par serveur (defaut 60 s : un `uvx` froid installe "
                             "son venv avant de repondre, mesure 2026-11-03)")
    parser.add_argument("--no-handshake", action="store_true",
                        help="lecture declarative seule (aucun spawn)")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--server", action="append", default=None,
                        help="restreint la sonde a ce serveur (repetable)")
    args = parser.parse_args(argv)

    workspace = str(Path(args.workspace).resolve())
    errors = []
    user_config = load_json_or_none(user_config_path(), errors)

    servers, disabled = collect(workspace, user_config, errors)
    if args.server:
        wanted = set(args.server)
        servers = {k: v for k, v in servers.items() if k in wanted}

    records = probe(servers, args.timeout, not args.no_handshake, workspace)

    stale = [r["server"] for r in records if r["verdict"] == "STALE-DISABLE"]
    dead = [r["server"] for r in records if r["verdict"] == "DEAD"]
    live = [r["server"] for r in records if r["verdict"] == "LIVE"]
    off = [r["server"] for r in records if r["verdict"] == "DISABLED"]

    if args.json:
        print(json.dumps({
            "workspace": workspace,
            "handshake": not args.no_handshake,
            "records": records,
            "live": live, "dead": dead, "disabled": off, "stale_disables": stale,
            "errors": errors,
        }, ensure_ascii=False, indent=2))
    else:
        print(f"SIEGE {workspace}")
        print(f"sonde : {'handshake stdio' if not args.no_handshake else 'declarative'}"
              f"  timeout={args.timeout:g}s")
        print("")
        width = max([len(r["server"]) for r in records] + [6])
        for r in records:
            print(f"  {r['verdict']:<12} {r['server']:<{width}}  {r['detail']}")
            if r["sources"]:
                print(f"  {'':<12} {'':<{width}}  declare: {', '.join(r['sources'])}")
        print("")
        print(f"LIVE={len(live)} DEAD={len(dead)} DISABLED={len(off)} STALE-DISABLE={len(stale)}")
        if stale:
            print(f"desactivations perimees (a purger) : {', '.join(stale)}")
        if errors:
            print(f"erreurs de lecture : {len(errors)}")
            for err in errors:
                print(f"  - {err}")

    # Precedence du contrat (revue ai-01 04/11) : une erreur de lecture n'est
    # JAMAIS un 0, et un DEAD mesure prime sur elle -- l'automate doit voir
    # l'absence meme quand une autre surface etait illisible.
    if errors:
        return 2 if dead else 1
    if args.no_handshake:
        return 3
    return 2 if dead else 0


if __name__ == "__main__":
    sys.exit(main())

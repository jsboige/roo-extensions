#!/usr/bin/env python3
"""
check-deny-fallback.py — Detection deny-sans-repli au demarrage (#4340).

Incident fondateur (po-2027/CoursIA, 24/10) : `NotebookEdit` deny + regle
designant le MCP `jupyter-papermill` comme repli canonique unique... qui
n'a jamais ete provisionne. Rien ne l'a detecte pendant des semaines ; la
lane a normalise un fallback interdit (bytesplice JSON du .ipynb). User
verbatim : « Pas d'excuse, pas de workaround. »

Ce qu'on verifie, pour chaque outil deny dont une regle designe un repli
canonique unique (DENY_FALLBACK_MAP ci-dessous) :

  1. l'outil est-il deny sur ce siege ? (union des scopes settings)
  2. si oui, le serveur repli est-il configure ? (.mcp.json du workspace,
     puis scopes local/user de ~/.claude.json)
  3. si oui, repond-il ? -> HANDSHAKE stdio reel (initialize puis
     tools/list). Jamais les drapeaux : `disabled: true` dans une entree
     .mcp.json est INERTE sur un siege Claude Code (drapeau VS Code/Roo,
     mesure po-2025 24/10 13:47Z) — seule l'emplacement 3
     (projects[<ws>].disabledMcpServers) desactive effectivement un
     serveur sur ce siege.

Sorties par entree mappee :
    INERT                   outil non deny sur ce siege (le workspace decide)
    OK                      deny + repli configure + handshake + >=1 outil
    DENY-WITHOUT-FALLBACK   deny + aucune config du serveur  -> incident po-2027
    FALLBACK-DISABLED-SEAT  deny + config mais disabledMcpServers du siege
    FALLBACK-DEAF           deny + config mais handshake muet/erreur/0 outil

Usage:
    python check-deny-fallback.py                              # siege courant
    python check-deny-fallback.py --workspace <chemin>         # autre workspace
    python check-deny-fallback.py --json                       # machine-readable
    python check-deny-fallback.py --timeout 60                 # handshake plus long
    python check-deny-fallback.py --selftest                   # fixture synthetique

Exit codes: 0 = rien a signaler, 2 = >=1 finding, 1 = erreur d'instrument.

Le timeout par defaut (30 s) delibere sur le CONNECT_TIMEOUT de l'hote
Claude Code : un serveur plus lent que le cutoff de l'hote est un repli
effectivement absent, pas un repli lent.
"""

import argparse
import json
import os
import queue
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

EXIT_CLEAN = 0
EXIT_ERROR = 1
EXIT_FINDINGS = 2

DEFAULT_TIMEOUT = 30.0

# Regle -> repli canonique unique. Une regle qui designe un repli sans
# verifier son provisioning reproduit l'incident po-2027 ; chaque entree
# ci-dessous est couverte par la sonde au demarrage.
DENY_FALLBACK_MAP = {
    "NotebookEdit": {
        "mcp_server": "jupyter-papermill",
        "rule": "harnais-tightening.md §2 (NotebookEdit deny → MCP maison, pas de fallback)",
    },
}

FINDING_STATUSES = {"missing-config", "disabled-seat", "deaf"}

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")  # console cp1252 vs chemins UTF-8 (#4059)


def load_json(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def load_json_or_none(path, errors):
    """None si absent ; erreur enregistree si present mais illisible."""
    p = Path(path)
    if not p.is_file():
        return None
    try:
        return load_json(p)
    except Exception as exc:  # noqa: BLE001 - instrument fail-closed
        errors.append(f"illisible: {path} ({exc})")
        return None


def settings_deny_entries(workspace):
    """Union des permissions.deny des scopes settings (user, projet, local).

    Claude Code unionne les regles de permission entre scopes et deny gagne :
    un deny dans N'IMPORTE QUEL scope active l'obligation de repli.
    Retourne (entries | None, errors) — None = aucun settings lisible.
    """
    candidates = [
        Path.home() / ".claude" / "settings.json",
        Path(workspace) / ".claude" / "settings.json",
        Path(workspace) / ".claude" / "settings.local.json",
    ]
    entries, errors, seen_any = [], [], False
    for path in candidates:
        data = load_json_or_none(path, errors)
        if data is None:
            continue
        seen_any = True
        perms = data.get("permissions") or {}
        deny = perms.get("deny") or []
        if isinstance(deny, list):
            entries.extend(d for d in deny if isinstance(d, str))
    return (entries if seen_any else None), errors


def tool_is_denied(entries, tool):
    """Match 'Tool', 'Tool(...)' — frontiere '(' pas '\\b' (cf. word-boundary #1798)."""
    for entry in entries:
        if entry == tool or entry.startswith(tool + "("):
            return True
    return False


def resolve_server(workspace, user_config, server_name, errors):
    """Resolution dans l'ordre canonique : .mcp.json projet > local > user.

    Retourne (entry | None, source | None). Les drapeaux de l'entree
    (disabled etc.) ne sont PAS lus ici : inertes sur siege Claude Code,
    seul le handshake decide (#4340 point 2).
    """
    ws_mcp = load_json_or_none(Path(workspace) / ".mcp.json", errors)
    if isinstance(ws_mcp, dict):
        entry = (ws_mcp.get("mcpServers") or {}).get(server_name)
        if isinstance(entry, dict):
            return entry, ".mcp.json"
    proj = (user_config or {}).get("projects", {}).get(str(workspace)) or {}
    entry = (proj.get("mcpServers") or {}).get(server_name)
    if isinstance(entry, dict):
        return entry, f"~/.claude.json projects[{workspace}].mcpServers"
    entry = ((user_config or {}).get("mcpServers") or {}).get(server_name)
    if isinstance(entry, dict):
        return entry, "~/.claude.json mcpServers"
    return None, None


def seat_disabled_servers(user_config, workspace):
    proj = (user_config or {}).get("projects", {}).get(str(workspace)) or {}
    disabled = proj.get("disabledMcpServers") or []
    return [d for d in disabled if isinstance(d, str)]


def _spawn_reader(proc, lines):
    """Thread lecteur stdout : pousse chaque ligne vers la file (drain oblige)."""
    try:
        for line in proc.stdout:
            lines.put(line)
    except Exception:
        pass
    lines.put(None)  # EOF


def handshake(entry, timeout):
    """Handshake MCP stdio reel : initialize -> notifications/initialized -> tools/list.

    Retourne (ok, detail) ; detail porte serverInfo et le compte d'outils.
    stdin reste OUVERT jusqu'a la fin de la sonde (un EOF declenche le
    watchdog stdin de certains serveurs avant leur reponse), stderr est
    derire vers fichier (un pipe plein gelerait le serveur).
    """
    command = entry.get("command")
    args = entry.get("args") or []
    if not isinstance(command, str) or not command:
        return False, "entree sans 'command'"
    cmd = [command] + [str(a) for a in args]

    env = dict(os.environ)
    extra_env = entry.get("env") or {}
    if isinstance(extra_env, dict):
        env.update({str(k): str(v) for k, v in extra_env.items()})
    cwd = entry.get("cwd") if isinstance(entry.get("cwd"), str) else None

    stderr_file = tempfile.TemporaryFile(mode="w+", encoding="utf-8", errors="replace")
    try:
        proc = subprocess.Popen(
            cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=stderr_file, env=env, cwd=cwd,
        )
    except Exception as exc:  # noqa: BLE001 - spawn rate = repli absent
        stderr_file.close()
        return False, f"spawn echoue: {exc}"

    lines = queue.Queue()
    threading.Thread(target=_spawn_reader, args=(proc, lines), daemon=True).start()

    def send(payload):
        try:
            proc.stdin.write((json.dumps(payload) + "\n").encode("utf-8"))
            proc.stdin.flush()
            return True
        except Exception:
            return False

    deadline = time.monotonic() + timeout

    def read_response(expect_id):
        """Attend la reponse JSON-RPC d'identifiant expect_id (notifications sautees)."""
        while time.monotonic() < deadline:
            remaining = max(0.0, deadline - time.monotonic())
            try:
                raw = lines.get(timeout=min(remaining, 1.0))
            except queue.Empty:
                if proc.poll() is not None:
                    return ("dead", None)
                continue
            if raw is None:
                return ("eof", None)
            try:
                msg = json.loads(raw)
            except ValueError:
                continue
            if not isinstance(msg, dict) or msg.get("id") != expect_id:
                continue
            if "error" in msg:
                return ("rpc-error", msg["error"])
            return ("ok", msg.get("result"))
        return ("timeout", None)

    def stderr_tail(max_chars=300):
        try:
            stderr_file.seek(0)
            text = (stderr_file.read() or "").strip()
        except Exception:
            text = ""
        return text[-max_chars:]

    init_req = {
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "check-deny-fallback", "version": "1.0.0"},
        },
    }
    try:
        if not send(init_req):
            return False, f"stdin ferme avant initialize ({stderr_tail()})"
        status, result = read_response(1)
        if status != "ok":
            return False, f"initialize: {status} ({stderr_tail()})"
        server_info = (result or {}).get("serverInfo") or {}
        send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        if not send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}):
            return False, f"stdin ferme avant tools/list ({stderr_tail()})"
        status, result = read_response(2)
        if status != "ok":
            return False, f"tools/list: {status} ({stderr_tail()})"
        tools = (result or {}).get("tools")
        if not isinstance(tools, list) or len(tools) == 0:
            return False, f"tools/list repond 0 outil ({stderr_tail()})"
        name = server_info.get("name", "?")
        return True, f"handshake OK — {name}, {len(tools)} outil(s)"
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=5)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
        stderr_file.close()


def run_check(workspace, timeout, settings_override=None, user_config_override=None):
    """Retourne (records, exit_code). Lecture seule hors handshake (spawn du repli)."""
    errors = []
    records = []

    if settings_override is not None:
        entries = settings_override
    else:
        entries, errs = settings_deny_entries(workspace)
        errors.extend(errs)

    user_config = None
    if user_config_override is not None:
        user_config = user_config_override
    else:
        user_config = load_json_or_none(Path.home() / ".claude.json", errors)
        if user_config is None:
            # absent = pas de config user ; seulement erreur si vraiment illisible
            user_config = {} if not errors else None

    if errors:
        for err in errors:
            print(f"[ERROR] settings/config: {err}")
        return records, EXIT_ERROR
    if entries is None:
        print("[ERROR] aucun settings lisible (~/.claude/settings.json absent ou illisible)")
        return records, EXIT_ERROR
    if not isinstance(user_config, dict):
        user_config = {}

    disabled_seat = seat_disabled_servers(user_config, workspace)

    for tool, spec in DENY_FALLBACK_MAP.items():
        server = spec["mcp_server"]
        record = {"tool": tool, "mcp_server": server, "rule": spec["rule"]}
        records.append(record)

        if not tool_is_denied(entries, tool):
            record["status"] = "inert"
            record["detail"] = "outil non deny sur ce siege — le workspace decide (#4340 point 4)"
            continue

        entry, source = resolve_server(workspace, user_config, server, errors)
        if errors:
            record["status"] = "error"
            record["detail"] = "; ".join(errors)
            continue
        if entry is None:
            record["status"] = "missing-config"
            record["detail"] = (
                f"'{server}' introuvable (.mcp.json du workspace, scopes local/user) — "
                f"incident po-2027 : le repli designe par la regle n'existe pas"
            )
            continue
        record["source"] = source
        if "disabled" in entry:
            record["flag_ignored"] = (
                "drapeau 'disabled' IGNORE : inert sur siege Claude Code "
                "(mesure po-2025 24/10, #4340 point 2) — le handshake decide"
            )
        if server in disabled_seat:
            record["status"] = "disabled-seat"
            record["detail"] = (
                f"'{server}' configure ({source}) mais liste dans disabledMcpServers "
                f"du siege — le serveur ne se chargera PAS en session"
            )
            continue

        ok, detail = handshake(entry, timeout)
        record["status"] = "ok" if ok else "deaf"
        record["detail"] = detail

    exit_code = EXIT_CLEAN
    if any(r.get("status") == "error" for r in records):
        exit_code = EXIT_ERROR
    elif any(r.get("status") in FINDING_STATUSES for r in records):
        exit_code = EXIT_FINDINGS
    return records, exit_code


STATUS_LABEL = {
    "inert": "INERT",
    "ok": "OK",
    "missing-config": "DENY-WITHOUT-FALLBACK",
    "disabled-seat": "FALLBACK-DISABLED-SEAT",
    "deaf": "FALLBACK-DEAF",
    "error": "UNRESOLVED",
}


def report(records, as_json):
    if as_json:
        print(json.dumps(records, ensure_ascii=False, indent=2))
        return
    for r in records:
        label = STATUS_LABEL.get(r["status"], r["status"].upper())
        print(f"[{label}] {r['tool']} deny -> {r['mcp_server']}: {r['detail']}")
        if r.get("source"):
            print(f"    source: {r['source']}")
        if r.get("flag_ignored"):
            print(f"    {r['flag_ignored']}")
    findings = [r for r in records if r.get("status") in FINDING_STATUSES]
    if findings:
        tools = ", ".join(f"{r['tool']} ({STATUS_LABEL[r['status']]})" for r in findings)
        print(f"[FINDINGS] {len(findings)} deny-sans-repli: {tools}")
        print("[ACTION] capacite BLOQUEE sur ce siege — jamais de workaround "
              "(bytesplice JSON, NotebookEdit). Provisionner le repli (decision "
              "par workspace, #4340 point 4) ouvrir une entree registre.")
    else:
        print("[CLEAN] aucun deny-sans-repli")


# --- Selftest : fixtures synthetiques, serveur MCP fake reel (handshake vrai) ---

FAKE_SERVER = """
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    msg = json.loads(line)
    if msg.get("method") == "initialize":
        print(json.dumps({"jsonrpc": "2.0", "id": msg["id"], "result": {
            "protocolVersion": "2024-11-05", "capabilities": {"tools": {}},
            "serverInfo": {"name": "fake-papermill", "version": "1.0"}}}), flush=True)
    elif msg.get("method") == "tools/list":
        print(json.dumps({"jsonrpc": "2.0", "id": msg["id"], "result": {
            "tools": [{"name": "execute_notebook"}, {"name": "read_notebook"}]}}), flush=True)
"""


def _write_settings(path, deny):
    path.write_text(json.dumps({"permissions": {"deny": deny}}), encoding="utf-8")


def selftest():
    tmp = Path(tempfile.mkdtemp(prefix="check-deny-fallback-selftest-"))
    ws = tmp / "ws"
    ws.mkdir()
    fake = tmp / "fake_mcp_server.py"
    fake.write_text(FAKE_SERVER, encoding="utf-8")
    dead = tmp / "dead_server.py"
    dead.write_text("import sys; sys.exit(3)\n", encoding="utf-8")
    sys_exec = sys.executable.replace("\\", "/")

    def mcp_entry(script, extra=None):
        entry = {"type": "stdio", "command": sys_exec, "args": [str(script).replace("\\", "/")]}
        if extra:
            entry.update(extra)
        return entry

    failures = []

    def expect(name, records, code, want_status):
        got = {r["tool"]: r["status"] for r in records}
        if got.get("NotebookEdit") != want_status or code != want_code(want_status):
            failures.append(f"{name}: status={got.get('NotebookEdit')} exit={code} (attendu {want_status}/{want_code(want_status)})")
        else:
            print(f"  [OK] {name}")

    def want_code(status):
        return {"inert": EXIT_CLEAN, "ok": EXIT_CLEAN}.get(status, EXIT_FINDINGS)

    # A. deny + .mcp.json canonique (sans drapeau) + serveur fake -> OK
    _write_settings(tmp / "stA.json", ["NotebookEdit"])
    (ws / ".mcp.json").write_text(json.dumps(
        {"mcpServers": {"jupyter-papermill": mcp_entry(fake)}}), encoding="utf-8")
    rec, code = run_check(str(ws), 15.0, settings_override=["NotebookEdit"], user_config_override={})
    expect("A deny+canonique+handshake", rec, code, "ok")
    rec_ok = [r for r in rec if r["tool"] == "NotebookEdit"][0]
    if "2 outil" not in rec_ok["detail"]:
        failures.append(f"A: compte d'outils absent du detail: {rec_ok['detail']}")

    # B. drapeau disabled:true dans l'entree -> IGNORE, handshake decide (po-2025 24/10)
    (ws / ".mcp.json").write_text(json.dumps(
        {"mcpServers": {"jupyter-papermill": mcp_entry(fake, {"disabled": True})}}), encoding="utf-8")
    rec, code = run_check(str(ws), 15.0, settings_override=["NotebookEdit"], user_config_override={})
    expect("B drapeau inert (disabled:true ignore)", rec, code, "ok")
    rec_b = [r for r in rec if r["tool"] == "NotebookEdit"][0]
    if not rec_b.get("flag_ignored"):
        failures.append("B: le drapeau disabled:true n'a pas ete signale comme ignore")

    # C. deny + aucune config -> DENY-WITHOUT-FALLBACK (incident po-2027)
    (ws / ".mcp.json").unlink()
    rec, code = run_check(str(ws), 15.0, settings_override=["NotebookEdit"], user_config_override={})
    expect("C deny sans config", rec, code, "missing-config")

    # C2. forme spec 'NotebookEdit(...)' matche aussi
    rec, code = run_check(str(ws), 15.0, settings_override=["NotebookEdit(spec)"], user_config_override={})
    expect("C2 deny forme spec", rec, code, "missing-config")

    # D. config user-scope mais disabledMcpServers du siege -> DISABLED-SEAT
    user_cfg = {
        "mcpServers": {"jupyter-papermill": mcp_entry(fake)},
        "projects": {str(ws): {"disabledMcpServers": ["jupyter-papermill"]}},
    }
    rec, code = run_check(str(ws), 15.0, settings_override=["NotebookEdit"], user_config_override=user_cfg)
    expect("D disabledMcpServers (emplacement 3)", rec, code, "disabled-seat")

    # E. pas de deny -> INERT
    rec, code = run_check(str(ws), 15.0, settings_override=[], user_config_override=user_cfg)
    expect("E non-deny inert", rec, code, "inert")

    # F. serveur qui meurt aussitot -> DEAF
    (ws / ".mcp.json").write_text(json.dumps(
        {"mcpServers": {"jupyter-papermill": mcp_entry(dead)}}), encoding="utf-8")
    rec, code = run_check(str(ws), 15.0, settings_override=["NotebookEdit"], user_config_override={})
    expect("F serveur mort", rec, code, "deaf")

    # G. deny dans la carte mais autre outil non-deny present -> inert quand meme
    rec, code = run_check(str(ws), 15.0, settings_override=["AskUserQuestion"], user_config_override={})
    expect("G autre deny seul", rec, code, "inert")

    # Cleanup : fichiers nommes, pas de rmtree sauvage.
    for name in ("stA.json", "fake_mcp_server.py", "dead_server.py"):
        (tmp / name).unlink(missing_ok=True)
    (ws / ".mcp.json").unlink(missing_ok=True)
    ws.rmdir()
    try:
        tmp.rmdir()
    except OSError:
        pass

    if failures:
        print("[SELFTEST] FAIL")
        for f in failures:
            print(f"  {f}")
        return EXIT_ERROR
    print("[SELFTEST] PASS (7 scenarios: ok/flag-ignore/missing/spec/disable-seat/inert/dead)")
    return EXIT_CLEAN


def main():
    parser = argparse.ArgumentParser(
        description="Detection deny-sans-repli au demarrage — handshake, pas drapeau (#4340)")
    parser.add_argument("--workspace", default=os.getcwd(),
                        help="chemin du workspace a sonder (defaut: cwd)")
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT,
                        help=f"deadline handshake en secondes (defaut {DEFAULT_TIMEOUT:.0f})")
    parser.add_argument("--json", action="store_true", help="sortie machine-readable")
    parser.add_argument("--selftest", action="store_true", help="validation sur fixtures synthetiques")
    args = parser.parse_args()

    if args.selftest:
        return selftest()

    try:
        records, exit_code = run_check(os.path.abspath(args.workspace), args.timeout)
    except Exception as exc:  # noqa: BLE001 - instrument fail-closed
        print(f"[ERROR] {exc}")
        return EXIT_ERROR

    report(records, args.json)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
probe-semantic-known-answer.py — Sonde a reponse connue pour la recherche semantique (#4352, critere 4).

Mandat (dispatch ai-01 27/10, c.6447704394) : « un script qui indexe une session
connue, puis verifie qu'un autre siege la retrouve via roosync_search(semantic),
avec un code de sortie. » Critere 4 de l'issue : une requete semantique sur une
phrase d'une session des dernieres 24 h classe cette session dans le top 5.

Deux phases, deux sieges :

  Phase INDEX (siege A, celui qui possede la session) :
    1. resout le task_id RSM de la session via conversation_browser(list)
       (fenetre : dernieres 24 h, taille 10 Ko-2 Mo — au-dela, l'indexation
       synchrone peut mourir au timeout outil 300 s, trou #4352 g3) ;
    2. extrait une PHRASE distinctives du contenu reel via conversation_browser(view)
       — jamais une lecture directe du JSONL (#1785) ;
    3. indexe la session via roosync_indexing(action:"index", task_id,
       source:"claude-code") — le defaut 'roo' resout un repertoire de tache et
       echoue sur un .jsonl ;
    4. affiche TASK_ID + PHRASE verbatim (a copier vers le siege B).

  Phase VERIFY (n'importe quel siege, typiquement B) :
    roosync_search(action:"semantic", search_query=<phrase>, max_results=5)
    -> PASS si le task_id figure dans les 5 premiers resultats.

Par defaut (aucun drapeau de phase) : INDEX puis VERIFY sur le meme siege
(auto-controle local) ; le controle cross-siege reste deux commandes.

Transport : spawn d'un enfant RSM en stdio (JSON-RPC MCP), entree pointee sur le
vintage arme (`build-current`), donc aucun etat de session hote n'est suppose.

Usage:
    python probe-semantic-known-answer.py                     # index + verify local
    python probe-semantic-known-answer.py --index             # phase A seule
    python probe-semantic-known-answer.py --verify \
        --task-id claude-c--dev-roo-extensions--<uuid> \
        --phrase "..."                                        # phase B, autre siege
    python probe-semantic-known-answer.py --task-id <id> --index   # session imposee
    python probe-semantic-known-answer.py --json              # sortie machine
    python probe-semantic-known-answer.py --selftest          # fixtures hors ligne

Exit codes: 0 = PASS (top 5 atteint) · 1 = FAIL (sonde saine, critere non tenu)
            2 = erreur d'instrument (enfant MCP, parsing, indexation en echec).

Limite mesuree (28/10, myia-web1) : le listing ne rend que les 50 sessions les
plus recemment actives, et l'indexation synchrone est bornee a 300 s par le
transport MCP. Sur ce siege la SEULE session des dernieres 24 h pese 547 Ko et
rend `-32603 « timed out after 300s »` (defaut g3, #4352) : la sonde le nomme
explicitement. Fixer alors `--task-id` sur une session plus petite pour prouver
la chaine — et dire que la fenetre 24 h reste bloquee par g3, pas la masquer.
"""

from __future__ import annotations

import argparse
import json
import queue
import re
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------

DEFAULT_RSM_DIR = (
    Path(__file__).resolve().parents[2] / "mcps" / "internal" / "servers" / "roo-state-manager"
)
SIZE_MIN_BYTES = 10_000          # fenetre connu-answer : eviter les fichiers triviaux
SIZE_MAX_BYTES = 2_000_000       # au-dela : risque de timeout d'indexation 300 s (g3)
RECENCY_HOURS = 24               # critere 4 : « session of the last 24 h »
MAX_RESULTS = 5                  # critere 4 : « ranks in the top 5 »
INDEX_ATTEMPTS = 3               # candidats tentes avant de declarer l'instrument en echec
PHRASE_MIN_CHARS = 60
PHRASE_MAX_CHARS = 240
SECRET_MARKERS = re.compile(
    r"(api[_-]?key|secret|token|password|passwd|bearer|sk-[a-zA-Z0-9]|ghp_[a-zA-Z0-9]"
    r"|BEGIN [A-Z ]+PRIVATE|AKIA[0-9A-Z]{16}|-----)",
    re.IGNORECASE,
)
INIT_TIMEOUT_S = 90
CALL_TIMEOUT_S = {"fast": 90, "index": 320, "search": 120}


# ---------------------------------------------------------------------------
# Enfant MCP stdio
# ---------------------------------------------------------------------------

class McpChild:
    """Client JSON-RPC minimaliste sur stdio vers un enfant RSM frais.

    L'I/O de l'enfant est lu par un thread dedie qui pousse les lignes dans une
    queue : un `readline()` bloquant sur un enfant muet ne rend jamais la main,
    donc un deadline verifie APRES le read ne peut pas se declencher (c'est ce
    qui a fige la premiere execution end-to-end pendant des heures).
    """

    def __init__(self, entry: Path, rsm_dir: Path, command: list[str] | None = None):
        self.proc = subprocess.Popen(
            command or ["node", str(entry)],
            cwd=str(rsm_dir),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        self._next_id = 1
        self._lines: queue.Queue = queue.Queue()
        self._stderr_tail: list[str] = []
        self._reader = threading.Thread(target=self._pump, daemon=True)
        self._reader.start()
        self._errreader = threading.Thread(target=self._pump_stderr, daemon=True)
        self._errreader.start()

    def _pump_stderr(self) -> None:
        try:
            for line in self.proc.stderr:
                self._stderr_tail.append(line.rstrip())
                del self._stderr_tail[:-10]  # garder les 10 dernieres lignes
        except (ValueError, OSError):
            pass

    def _pump(self) -> None:
        try:
            for line in self.proc.stdout:
                self._lines.put(line)
        finally:
            self._lines.put(None)  # sentinelle : flux ferme / enfant mort

    def _read_message(self, timeout_s: float) -> dict:
        try:
            line = self._lines.get(timeout=timeout_s)
        except queue.Empty:
            tail = " | ".join(self._stderr_tail[-3:]) if self._stderr_tail else "(stderr vide)"
            raise TimeoutError(f"enfant muet depuis {timeout_s}s — stderr: {tail}")
        if line is None:
            raise RuntimeError(f"enfant termine (code {self.proc.poll()}) avant reponse")
        return json.loads(line)

    def rpc(self, method: str, params: dict, timeout_s: float) -> dict:
        msg_id = self._next_id
        self._next_id += 1
        payload = json.dumps({"jsonrpc": "2.0", "id": msg_id, "method": method, "params": params})
        self.proc.stdin.write(payload + "\n")
        self.proc.stdin.flush()
        deadline = time.monotonic() + timeout_s
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(f"timeout {timeout_s}s sur {method}")
            msg = self._read_message(remaining)
            if msg.get("id") == msg_id:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {json.dumps(msg['error'])[:300]}")
                return msg["result"]

    def notify(self, method: str, params: dict) -> None:
        self.proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": method, "params": params}) + "\n")
        self.proc.stdin.flush()

    def call_tool(self, name: str, args: dict, timeout_s: float) -> str:
        result = self.rpc("tools/call", {"name": name, "arguments": args}, timeout_s)
        return "".join(c.get("text", "") for c in result.get("content", []))

    def close(self) -> None:
        try:
            self.proc.kill()
        except OSError:
            pass


def resolve_child(rsm_dir: Path) -> tuple[Path, Path]:
    """Pointe l'entree arme : build-current -> vintage, sinon build/index.js."""
    pointer = rsm_dir / "build-current"
    if pointer.is_file():
        vintage = pointer.read_text(encoding="utf-8", errors="replace").strip()
        entry = rsm_dir / vintage / "index.js"
        if entry.is_file():
            return entry, rsm_dir
    entry = rsm_dir / "build" / "index.js"
    if entry.is_file():
        return entry, rsm_dir
    raise FileNotFoundError(
        f"aucune entree enfant trouvable sous {rsm_dir} — preciser --rsm-dir sur un "
        "checkout RSM PEUPLE (dans un worktree du parent le submodule est vide : "
        "seul le gitlink existe)"
    )


def parse_embedded_json(text: str):
    """Les resultats d'outil embarquent un JSON pretty-printes dans content[0].text."""
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        return None
    try:
        return json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        return None


# ---------------------------------------------------------------------------
# Phase INDEX
# ---------------------------------------------------------------------------

def local_machine_id() -> str:
    """Nom de la machine locale, pour reconnaitre SES sessions au listing.

    Le listing `conversation_browser` est FLOTTE (5427 sessions vues depuis ce
    siege) : celles des autres machines ne sont pas dans le cache squelette
    local et l'indexation y repond « not found in cache ». Chaque entree porte
    `metadata.machineId` — c'est le signal reel, pas une deduction sur le task_id.
    """
    return socket.gethostname().casefold()


def candidate_sessions(child: McpChild, task_id: str | None) -> list[tuple[str, dict]]:
    """Resout les task_id RSM candidats (conversation_browser list, local au siege).

    Rend une LISTE ordonnee : une session peut figurer au listing sans etre
    chargee dans le cache local (c'est le cas des sessions d'une AUTRE machine,
    p.ex. `claude-D--...` vues depuis un siege C:) — l'indexation y repond
    « not found in cache » et le candidat suivant doit etre tente, pas la sonde
    declaree en panne.
    """
    raw = child.call_tool(
        "conversation_browser",
        {"action": "list", "limit": 50, "sortBy": "lastActivity", "sortOrder": "desc"},
        CALL_TIMEOUT_S["fast"],
    )
    payload = parse_embedded_json(raw)
    convs = (payload or {}).get("conversations") or []
    if not convs:
        raise RuntimeError("conversation_browser(list) n'a rendu aucune conversation")

    if task_id:
        for conv in convs:
            if conv.get("taskId") == task_id:
                return [(task_id, conv)]
        # impose par l'operateur : le listing est pagine (top 50 seulement), une
        # session ancienne n'y figure pas forcement — l'indexation tranchera.
        return [(task_id, {})]

    now = time.time()
    picked: list[tuple[str, dict]] = []
    for conv in convs:  # trie par activite decroissante
        meta = conv.get("metadata") or {}
        size = meta.get("totalSize") or 0
        if not (SIZE_MIN_BYTES <= size <= SIZE_MAX_BYTES):
            continue
        created = meta.get("createdAt") or ""
        ts = created and time.mktime(time.strptime(created[:19], "%Y-%m-%dT%H:%M:%S"))
        if ts and (now - ts) > RECENCY_HOURS * 3600:
            # plus de 24 h depuis la CREATION n'exclut pas une session active recemment,
            # mais le critere vise une session des dernieres 24 h : on filtre sur createdAt
            continue
        if conv.get("source") not in ("claude", "claude-code"):
            continue
        picked.append((conv["taskId"], conv))
    if not picked:
        raise RuntimeError(
            f"aucune session candidate (24 h, {SIZE_MIN_BYTES}-{SIZE_MAX_BYTES} octets) "
            "— preciser --task-id ou elargir la fenetre"
        )
    local = local_machine_id()
    picked.sort(key=lambda c: 0 if str((c[1].get("metadata") or {}).get("machineId", "")).casefold() == local else 1)
    return picked


def pick_phrase(text: str) -> str:
    """Phrase distinctive, balayee depuis la fin (contenu tardif = plus specifique).

    Regles : longueur PHRASE_MIN..PHRASE_MAX, pas de marqueur de secret, pas de
    ligne de commande/outil (bruit non semantique), pas de markdown lourd.
    """
    lines = [ln.strip() for ln in text.splitlines()]
    for ln in reversed(lines):
        if not (PHRASE_MIN_CHARS <= len(ln) <= PHRASE_MAX_CHARS):
            continue
        if SECRET_MARKERS.search(ln):
            continue
        if ln.startswith(("Tool call:", "[tool_result]", "```", "#", "|", "- [")):
            continue
        if ln.count('"') > 6 or ln.count("{") + ln.count("}") > 2:
            continue
        return ln
    raise RuntimeError("aucune phrase candidate extraite de la session (contenu trop pauvre)")


def index_source(conv: dict) -> str:
    """Source a declarer a l'indexeur.

    Le defaut du service est 'roo' : il resout `<location>/tasks/<id>` (un
    REPERTOIRE). Une session Claude Code est un `.jsonl` plat, resolu par la
    branche 'claude-code' -> sans ce champ l'indexation echoue a coup sur avec
    « Task directory for '...' not found in any storage location » (mesure 28/10,
    3 candidats, 2 formes d'erreur selon la branche empruntee).
    """
    return "roo" if str(conv.get("source") or "") == "roo" else "claude-code"


def phase_index(child: McpChild, task_id: str | None, out: dict) -> None:
    """Indexe le premier candidat indexable, puis extrait la phrase de son contenu.

    L'ordre compte : indexer AVANT d'extraire la phrase evite de payer un `view`
    par candidat, et un candidat non indexable (session d'une autre machine dans
    le listing, fichier disparu) laisse simplement la place au suivant.
    """
    attempts: list[dict] = []
    for cand_id, conv in candidate_sessions(child, task_id)[:INDEX_ATTEMPTS]:
        try:
            idx_raw = child.call_tool(
                "roosync_indexing",
                {"action": "index", "task_id": cand_id, "source": index_source(conv)},
                CALL_TIMEOUT_S["index"],
            )
        except RuntimeError as exc:
            # Reponse d'ERREUR JSON-RPC, pas un silence : p.ex. -32603, le
            # transport MCP coupe a 300 s AVANT la fin du travail serveur. C'est
            # un echec d'ESSAI (le candidat suivant reste tentable), pas une
            # panne de la sonde — mesure 28/10 : 30 Ko, 53 Ko et 560 Ko meurent
            # tous a la meme seconde, la taille n'est pas le discriminateur.
            err = str(exc)
            if "timed out after 300s" in err:
                err = f"{err} [g3: indexation SYNCHRONE bornee a 300 s — cf. #4352 g3]"
            attempts.append({"task_id": cand_id, "error": err})
            continue
        idx = parse_embedded_json(idx_raw)
        if idx is None or idx.get("success") is not True:
            # echec d'indexation : le service repond en MARKDOWN, pas en JSON
            error = (idx_raw or "")[:200].replace("\n", " ").strip()
            if "timed out after 300s" in (idx_raw or ""):
                # Borne dure du transport MCP, independante de notre deadline client
                # (320 s) : une session trop grosse meurt AVANT toute reponse
                # d'indexation. C'est le defaut g3 (#4352) — la sonde le nomme au
                # lieu de le rendre comme « instrument en panne ».
                error = (
                    f"{error} [g3: indexation SYNCHRONE bornee a 300 s — "
                    f"session trop grosse pour ce chemin, cf. #4352 g3]"
                )
            attempts.append({"task_id": cand_id, "error": error})
            continue

        view_raw = child.call_tool(
            "conversation_browser",
            {"action": "view", "task_id": cand_id, "detail_level": "Compact",
             "smart_truncation": True, "max_output_length": 30000},
            CALL_TIMEOUT_S["fast"],
        )
        view = parse_embedded_json(view_raw)
        body = json.dumps(view, ensure_ascii=False) if view else view_raw
        out["task_id"] = cand_id
        out["session"] = {
            "size": conv.get("metadata", {}).get("totalSize"),
            "created": conv.get("metadata", {}).get("createdAt"),
            "messages": conv.get("metadata", {}).get("messageCount"),
        }
        out["phrase"] = pick_phrase(body)
        out["index"] = idx
        out["index_attempts"] = attempts  # candidats ecartes avant celui-ci
        return
    raise RuntimeError(
        f"indexation en echec sur {len(attempts)} candidat(s) — dernier: "
        f"{attempts[-1]['error'] if attempts else 'aucun candidat'}"
    )


# ---------------------------------------------------------------------------
# Phase VERIFY
# ---------------------------------------------------------------------------

def phase_verify(child: McpChild, task_id: str, phrase: str, out: dict) -> bool:
    raw = child.call_tool(
        "roosync_search",
        {"action": "semantic", "search_query": phrase, "max_results": MAX_RESULTS},
        CALL_TIMEOUT_S["search"],
    )
    payload = parse_embedded_json(raw)
    if payload is None or not isinstance(payload.get("results"), list):
        out["search_raw_head"] = raw[:400]
        raise RuntimeError("reponse roosync_search(semantic) non parsable — voir search_raw_head")
    results = payload["results"]
    out["search"] = {
        "results_count": payload.get("current_machine", {}).get("results_count"),
        "unique_tasks": payload.get("current_machine", {}).get("unique_tasks"),
        "machines_found": payload.get("cross_machine_analysis", {}).get("machines_found"),
        "top": [
            {"rank": i + 1, "taskId": r.get("taskId"), "score": r.get("best_score")}
            for i, r in enumerate(results)
        ],
    }
    for i, r in enumerate(results):
        if r.get("taskId") == task_id:
            out["rank"] = i + 1
            return i + 1 <= MAX_RESULTS
    out["rank"] = None
    return False


# ---------------------------------------------------------------------------
# Selftest (hors ligne, fixtures embarquees)
# ---------------------------------------------------------------------------

def selftest() -> int:
    failures = []

    # pick_phrase : retenue / secrets / bruit / bornes
    body = "\n".join([
        "ligne trop courte",
        "Tool call: Bash with args {\"command\":\"echo dashpilot\"}",
        "Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre.",
        "API_KEY=sk-abcdef1234567890abcdef1234567890abcdef12 tres longue ligne de secret a ne jamais choisir",
        "x" * 300,
    ])
    got = pick_phrase(body)
    want = "Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre."
    if got != want:
        failures.append(f"pick_phrase: {got!r}")

    # parse_embedded_json : payload pretty-printe + trailers NOTIF/timing
    wrapped = (
        "bla\n{\n  \"success\": true,\n  \"results\": [\n    {\"taskId\": \"claude-x--u1\", \"best_score\": 0.7}\n  ]\n}\n"
        "[NOTIF] 2 nouveau(x) sur global\n[⏱ roosync_search 3.6s]"
    )
    parsed = parse_embedded_json(wrapped)
    if not parsed or parsed["success"] is not True or parsed["results"][0]["taskId"] != "claude-x--u1":
        failures.append(f"parse_embedded_json: {parsed}")

    # phase_verify : classement dans le top 5 / absent
    class FakeChild:
        def call_tool(self, name, args, timeout_s):
            return json.dumps({
                "current_machine": {"results_count": 2, "unique_tasks": 2},
                "cross_machine_analysis": {"machines_found": ["A", "B"]},
                "results": [
                    {"taskId": "claude-x--u1", "best_score": 0.8},
                    {"taskId": "claude-x--u2", "best_score": 0.7},
                ],
            }, indent=2)

    out = {}
    if not phase_verify(FakeChild(), "claude-x--u1", "peu importe", out) or out["rank"] != 1:
        failures.append(f"verify hit: rank={out.get('rank')}")
    out = {}
    if phase_verify(FakeChild(), "claude-x--absent", "peu importe", out) or out["rank"] is not None:
        failures.append(f"verify miss: rank={out.get('rank')}")

    # McpChild : un enfant MUET doit rendre la main dans le delai (regression du
    # 27/10 — un readline bloquant figeait la sonde pour toujours, deadline jamais
    # atteinte puisque le read ne rend jamais la main sur un flux silencieux).
    silent = McpChild(Path("<inutilise>"), Path("."),
                      command=[sys.executable, "-c", "import time; time.sleep(30)"])
    started = time.monotonic()
    try:
        silent._read_message(1.0)
        failures.append("McpChild muet : aucune TimeoutError levee")
    except TimeoutError:
        if time.monotonic() - started > 5:
            failures.append("McpChild muet : TimeoutError trop tardive")
    finally:
        silent.close()

    if failures:
        print("[SELFTEST] FAIL")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("[SELFTEST] PASS (phrase, parsing pretty-printe, rang top-5, timeout enfant muet)")
    return 0


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="Sonde a reponse connue — recherche semantique (#4352 critere 4)")
    here = Path(__file__).resolve().parent
    ap.add_argument("--index", action="store_true", help="phase A : resoudre + indexer + extraire la phrase")
    ap.add_argument("--verify", action="store_true", help="phase B : rechercher et classer (cross-siege possible)")
    ap.add_argument("--task-id", help="task_id RSM impose (defaut : auto parmi les sessions des 24 h)")
    ap.add_argument("--phrase", help="phrase de sonde (phase verify ; defaut : celle extraite en phase index)")
    ap.add_argument("--rsm-dir", type=Path, default=DEFAULT_RSM_DIR, help="racine du serveur RSM")
    ap.add_argument("--json", action="store_true", help="sortie machine-readable")
    ap.add_argument("--selftest", action="store_true", help="fixtures hors ligne, aucun reseau")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    out: dict = {"probe": "probe-semantic-known-answer", "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
    do_index = args.index or not args.verify
    do_verify = args.verify or not args.index

    entry, rsm_dir = resolve_child(args.rsm_dir)
    out["child"] = str(entry)
    child = None
    try:
        child = McpChild(entry, rsm_dir)
        child.rpc(
            "initialize",
            {"protocolVersion": "2024-11-05", "capabilities": {},
             "clientInfo": {"name": "probe-semantic-known-answer", "version": "1.0.0"}},
            INIT_TIMEOUT_S,
        )
        child.notify("notifications/initialized", {})

        phrase = args.phrase
        if do_index:
            phase_index(child, args.task_id, out)
            phrase = phrase or out.get("phrase")
        if do_verify:
            if not phrase or not (args.task_id or out.get("task_id")):
                raise RuntimeError("phase verify exige --phrase et --task-id (ou une phase index dans le meme run)")
            task_id = args.task_id or out["task_id"]
            out["pass"] = phase_verify(child, task_id, phrase, out)

        verdict = out.get("pass")
        out["verdict"] = "PASS" if verdict else "FAIL"
        if args.json:
            print(json.dumps(out, ensure_ascii=False, indent=2, default=str))
        else:
            print(f"[task_id] {out.get('task_id')}")
            if out.get("phrase"):
                print(f"[phrase] {out['phrase']}")
            if "rank" in out:
                print(f"[rank] {out['rank']} (top {MAX_RESULTS}) — machines vues : "
                      f"{out.get('search', {}).get('machines_found')}")
            print(f"[VERDICT] {out['verdict']}")
        return 0 if verdict else 1
    except (TimeoutError, RuntimeError, FileNotFoundError, OSError, json.JSONDecodeError) as exc:
        out["error"] = str(exc)
        out["verdict"] = "INSTRUMENT_ERROR"
        if args.json:
            print(json.dumps(out, ensure_ascii=False, indent=2, default=str))
        else:
            print(f"[ERROR] {exc}")
            if out.get("index_raw_head"):
                print(f"[index_raw_head] {out['index_raw_head']}")
        return 2
    finally:
        if child:
            child.close()


if __name__ == "__main__":
    sys.exit(main())

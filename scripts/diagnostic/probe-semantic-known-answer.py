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
       source:"claude-code", queued:false) — le defaut 'roo' resout un repertoire de
       tache et echoue sur un .jsonl ; et depuis g3 le defaut d'indexation MET EN
       FILE (rendre aussitot) : la sonde demande explicitement l'indexation EN
       LIGNE, parce qu'elle a besoin d'un index TERMINE avant d'extraire une phrase ;
    4. affiche TASK_ID + PHRASE verbatim (a copier vers le siege B).

  Phase VERIFY (n'importe quel siege, typiquement B) :
    roosync_search(action:"semantic", search_query=<phrase>, max_results=5)
    -> PASS si le task_id figure dans les 5 premiers resultats d'une recherche
       qui a REELLEMENT tourne en semantique. Si le backend est tombe, le service
       bascule en recherche TEXTUELLE et le dit (`semantic_degraded`,
       `actual_search_mode: "text"`) : ces lignes portent aussi un taskId, donc un
       PASS textuel certifierait le critere avec le mauvais backend — la sonde
       refuse (verdict DEGRADED, exit 2, mode dans le label).

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

Exit codes: 0 = PASS (top 5 atteint) ou INDEXED (phase --index seule reussie)
            1 = FAIL (sonde saine, critere non tenu — phase verify seule concernee)
            2 = erreur d'instrument (enfant MCP, parsing, indexation en echec) OU
                recherche servie par un mode non semantique (verdict DEGRADED).

Limite mesuree (28/10, myia-web1) : le listing ne rend que les 50 sessions les
plus recemment actives, et l'indexation synchrone est bornee a 300 s par le
transport MCP. Sur ce siege la SEULE session des dernieres 24 h pese 547 Ko et
rend `-32603 « timed out after 300s »` (defaut g3, #4352) : la sonde le nomme
explicitement. Fixer alors `--task-id` sur une session plus petite pour prouver
la chaine — et dire que la fenetre 24 h reste bloquee par g3, pas la masquer.
"""

from __future__ import annotations

import argparse
import calendar
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

# Vocabulaire de `view` : skeleton|summary|full SEULEMENT (conversation-browser.ts
# refuse toute autre valeur, garde #3187). "Compact" appartient au vocabulaire de
# `summarize` (detailLevel) — l'avoir envoye a `view` tuait la sonde au premier run
# ou l'indexation reussissait (review #4398, bloquant 1). Le selftest verifie le
# drift hors ligne.
VIEW_DETAIL_LEVELS = ("skeleton", "summary", "full")
VIEW_DETAIL_LEVEL = "summary"


class DegradedSearch(RuntimeError):
    """Recherche servie par un backend NON semantique (repli textuel).

    Ni PASS (le critere 4 porte sur la recherche SEMANTIQUE), ni FAIL (la sonde
    n'a rien prouve sur le backend), ni panne d'instrument : c'est le mode qu'il
    faut nommer (review #4398 r2, `roosync-search.tool.ts:289-316`).
    """


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
        self._noise_tail: list[str] = []
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
        deadline = time.monotonic() + timeout_s
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                tail = " | ".join(self._stderr_tail[-3:]) if self._stderr_tail else "(stderr vide)"
                raise TimeoutError(f"enfant muet depuis {timeout_s}s — stderr: {tail}")
            try:
                line = self._lines.get(timeout=remaining)
            except queue.Empty:
                tail = " | ".join(self._stderr_tail[-3:]) if self._stderr_tail else "(stderr vide)"
                raise TimeoutError(f"enfant muet depuis {timeout_s}s — stderr: {tail}")
            if line is None:
                raise RuntimeError(f"enfant termine (code {self.proc.poll()}) avant reponse")
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                # Le serveur ecrit AUSSI des lignes de log non-JSON sur stdout
                # (`[RSM-HEALTH]`, `[WARN]`…). Les parser comme du JSON tuait la
                # phase --verify des la premiere ligne de log — mesure 28/10, sur
                # le chemin meme que le controle croise doit emprunter. On les
                # ecarte en les gardant en queue pour le diagnostic.
                self._noise_tail.append(line.rstrip())
                del self._noise_tail[:-5]
                continue

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
        text = "".join(
            c.get("text", "") for c in result.get("content", []) if isinstance(c, dict)
        )
        if result.get("isError"):
            # Erreur serveur rendue en CONTENU, pas en erreur JSON-RPC (mesure
            # Hermes, review #4398) — et le drapeau vit sur le RESULTAT,
            # `{content: [...], isError: true}` (conversation-browser.ts:351/373/473,
            # index.ts:755), pas sur chaque bloc. Une garde par item ne se declenchait
            # jamais sur la forme reellement emise (review #4398 r2, releve ai-01) :
            # le texte d'erreur devenait une donnee de sonde — p.ex. la phrase de
            # VERIFY, exactement la classe masked-error que #4352 traque.
            raise RuntimeError(f"{name}: {text[:200]}")
        return text

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
        # `source: "all"` explicite : le defaut du service est 'roo', qui ne liste
        # PAS les sessions Claude Code — precisement nos candidates (review #4398 r3).
        {"action": "list", "limit": 50, "sortBy": "lastActivity", "sortOrder": "desc",
         "source": "all"},
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
        created = meta.get("createdAt")
        if not isinstance(created, str):
            # Date absente OU non-texte (entier JSON, null) : la ligne est ECARTEE.
            # Un createdAt non-texte levait un TypeError non rattrape (le except ne
            # couvrait que ValueError) et la sonde rendait FAIL/exit 1 au lieu de
            # l'ecarter proprement (review #4398 r3).
            continue
        try:
            # createdAt est un ISO **UTC** : timegm, jamais mktime, qui le lirait
            # comme de l'heure locale et decalerait la fenetre 24 h du fuseau
            # (review #4398 r2).
            ts = calendar.timegm(time.strptime(created[:19], "%Y-%m-%dT%H:%M:%S"))
        except ValueError:
            # Date absente ou illisible : la ligne est ECARTEE. Le critere porte sur
            # une session des dernieres 24 h — sans date, pas de preuve ; et la garder
            # la ferait passer le filtre de recence sans l'avoir franchi.
            continue
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


# Prefixe de rendu du `view` : chaque ligne de message est emise `<indent>    | <l>`
# (view-conversation-tree.ts:1245). Retire UNE fois pour retrouver le corps — sinon
# le filtre markdown "|" (juste par ailleurs) rejette TOUTE la prose reelle
# (review #4398 r3 : 3 candidats sur 3 chez ai-01 n'offraient que du renderer).
_RENDER_PREFIX = "| "

# Lignes produites par le RENDERER, pas par la session. Elles ne sont pas
# indexees telles quelles : un tool est stocke sous "Tool call: <name> with args …"
# (ChunkExtractor.ts:1031), le footer est un diagnostic (smart-truncation/engine.ts:234).
# En retenir une donne un FAIL garanti ou un PASS accidentel — la classe de verdict
# masque que la sonde existe pour attraper (review #4398 r3). Marqueurs donnes sans
# selecteur de variation (U+FE0F) : le prefixe matche les deux formes.
_RENDERER_LINE_MARKERS = (
    "[\U0001F6E0",  # [🛠️ <tool>] → success (hh:mm:ss)   (view-conversation-tree.ts:1249)
    "[⚙",      # [⚙️ <tool>] → …
    "[NOTIF]", "[⏱", "[... ",        # omission par troncature
    "• ",                             # diagnostics smart-truncation
    "▶", "====",                 # en-tete de tache / separateurs
)


def pick_phrase(text: str) -> str:
    """Phrase distinctive, balayee depuis la fin (contenu tardif = plus specifique).

    Regles : longueur PHRASE_MIN..PHRASE_MAX, pas de marqueur de secret, pas de
    ligne de commande/outil NI du renderer (bruit non semantique, absent de
    l'index tel quel), pas de markdown lourd. Le prefixe de rendu `| ` est retire
    AVANT les filtres : le `|` doit rejeter les tableaux markdown, pas la prose.
    """
    for raw in reversed(text.splitlines()):
        ln = raw.strip()
        if ln.startswith(_RENDER_PREFIX):
            ln = ln[len(_RENDER_PREFIX):]
        if not (PHRASE_MIN_CHARS <= len(ln) <= PHRASE_MAX_CHARS):
            continue
        if SECRET_MARKERS.search(ln):
            continue
        # Prefixes d'erreur serveur : un message d'erreur fait 60-240 caracteres et
        # passe toutes les autres bornes — il ne doit JAMAIS devenir la phrase de
        # sonde (durcissement Hermes, review #4398).
        if ln.startswith(("Tool call:", "[tool_result]", "```", "#", "|", "- [",
                          "Erreur:", "Erreur lors de", "Error:", "ERROR:")):
            continue
        if any(ln.startswith(m) for m in _RENDERER_LINE_MARKERS):
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
        # TOUT le corps du candidat est sous le meme `try` : un echec de `view` ou
        # d'extraction de phrase ne doit pas emporter les candidats SUIVANTS. Le
        # docstring le promettait deja, le code ne le faisait pas (review #4398 r2).
        try:
            idx_raw = child.call_tool(
                "roosync_indexing",
                # `queued: false` EXPLICITE (#4352 g3). Depuis ms#1543 le defaut est
                # de METTRE EN FILE et de rendre aussitot — « en file » n'est pas
                # « indexe », or la sonde doit extraire une phrase et verifier sur un
                # index TERMINE. Mesure 28/10 : dans un enfant spawne le defaut echoue
                # meme franchement (`isError: true`, « queued (defaut) exige le state
                # du processus hote (indexingState) — indisponible dans ce contexte.
                # Utilisez l'indexation en ligne (queued=false) »).
                {"action": "index", "task_id": cand_id, "source": index_source(conv),
                 "queued": False},
                CALL_TIMEOUT_S["index"],
            )
            idx = parse_embedded_json(idx_raw)
            if idx is None or idx.get("success") is not True:
                # echec d'indexation : le service repond en MARKDOWN, pas en JSON
                error = (idx_raw or "")[:200].replace("\n", " ").strip()
                if "timed out after 300s" in (idx_raw or ""):
                    # Borne dure du transport MCP, independante de notre deadline
                    # client (320 s) : une session trop grosse meurt AVANT toute
                    # reponse d'indexation. C'est le defaut g3 (#4352) — la sonde le
                    # nomme au lieu de le rendre comme « instrument en panne ».
                    error = (
                        f"{error} [g3: indexation SYNCHRONE bornee a 300 s — "
                        f"session trop grosse pour ce chemin, cf. #4352 g3]"
                    )
                raise RuntimeError(error)
            view_raw = child.call_tool(
                "conversation_browser",
                {"action": "view", "task_id": cand_id, "detail_level": VIEW_DETAIL_LEVEL,
                 "smart_truncation": True, "max_output_length": 30000},
                CALL_TIMEOUT_S["fast"],
            )
            # `view` rend un ARBRE TEXTE multi-lignes (markdown), pas un JSON
            # embarque : pick_phrase balaye les lignes du contenu reel. Un
            # json.dumps ferait UNE ligne unique, rejetee par les bornes par ligne
            # (note convergente ai-01 + Hermes, review #4398).
            phrase = pick_phrase(view_raw)
        except RuntimeError as exc:
            # Reponse d'ERREUR JSON-RPC, pas un silence : p.ex. -32603, le transport
            # MCP coupe a 300 s AVANT la fin du travail serveur. C'est un echec
            # d'ESSAI (le candidat suivant reste tentable), pas une panne de la
            # sonde — mesure 28/10 : 30 Ko, 53 Ko et 560 Ko meurent tous a la meme
            # seconde, la taille n'est pas le discriminateur.
            err = str(exc)
            if "timed out after 300s" in err and "[g3:" not in err:
                err = f"{err} [g3: indexation SYNCHRONE bornee a 300 s — cf. #4352 g3]"
            attempts.append({"task_id": cand_id, "error": err})
            continue

        out["task_id"] = cand_id
        out["session"] = {
            "size": conv.get("metadata", {}).get("totalSize"),
            "created": conv.get("metadata", {}).get("createdAt"),
            "messages": conv.get("metadata", {}).get("messageCount"),
        }
        out["phrase"] = phrase
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
    # #4287 : quand la recherche SEMANTIQUE echoue, roosync_search bascule en
    # recherche TEXTUELLE et le DIT dans le payload — bloc d'avertissement en tete
    # de contenu, puis `semantic_degraded: true`, `fallback_used: true`,
    # `actual_search_mode: "text"` (roosync-search.tool.ts:289-316). Les lignes
    # textuelles portent aussi `taskId` : une phrase verbatim peut donc ranker en
    # top 5 et la sonde certifierait le critere 4 par le MAUVAIS backend — la classe
    # de verdict masque que cette sonde existe pour attraper (review #4398 r2).
    mode = payload.get("actual_search_mode") or "semantic"
    degraded = (
        bool(payload.get("semantic_degraded"))
        or bool(payload.get("fallback_used"))
        or mode != "semantic"
    )
    out["search"]["mode"] = mode
    out["search"]["degraded"] = degraded
    if degraded:
        raise DegradedSearch(
            f"recherche servie en mode NON semantique (actual_search_mode={mode!r}, "
            f"semantic_degraded={payload.get('semantic_degraded')!r}, "
            f"fallback_used={payload.get('fallback_used')!r}) — un PASS textuel ne "
            "prouve pas le critere 4"
        )
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

    # pick_phrase : un TEXTE D'ERREUR serveur ne doit jamais devenir la phrase de
    # sonde — il fait 60-240 caracteres et passe toutes les autres bornes. Releve
    # Hermes (review #4398) : sans exclusion, la sonde continuait vers VERIFY avec
    # le message d'erreur comme requete semantique. Doit echouer bruyamment.
    err_view_raw = (
        'Erreur: Valeur invalide pour "detail_level" : "Compact". '
        "Valeurs acceptées : skeleton, summary, full."
    )
    try:
        pick_phrase(err_view_raw)
        failures.append("pick_phrase: un texte d'erreur a ete retenu comme phrase")
    except RuntimeError:
        pass

    # pick_phrase sur la forme REELLE du `view` summary : la prose arrive sous le
    # prefixe de rendu `    | ` (view-conversation-tree.ts:1245) et les lignes du
    # renderer arrivent APRES elle — le scan depuis la fin les voit EN PREMIER.
    # Sans retrait du prefixe, le filtre markdown "|" rejette toute la prose ;
    # sans exclusion renderer, le footer ou la ligne [🛠️ …] → success gagne
    # (bloquant r3 : ces lignes n'existent pas dans l'index tel quel).
    rendered = "\n".join([
        "==== session claude-x--u1 ====",
        "▶️ Task: claude-x--u1 (3 messages)",
        "  [user]:",
        "      | Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre.",
        "  [assistant]:",
        "      | Verification faite sur les 17 marqueurs PG ce matin, aucun repli observe sur la fenetre de 24 h.",
        "  [\U0001F6E0️ mcp__roo-state-manager__roosync_dashboard] → success (09:44:11)",
        "        {\"action\": \"append\"}",
        "• Taille totale: 19845 chars, Limite: 30000, Surplus: 0 (3 task(s))",
        "[NOTIF] 1 message(s) non lu(s)",
        "[⏱ conversation_browser 1.2s]",
    ])
    want_rendered = (
        "Verification faite sur les 17 marqueurs PG ce matin, aucun repli observe sur la fenetre de 24 h."
    )
    got = pick_phrase(rendered)
    if got != want_rendered:
        failures.append(f"pick_phrase renderer: {got!r}")
    # Anti-drift : quoi qu'il arrive, la phrase ne doit JAMAIS etre une ligne du
    # renderer (assertion directe demandee par la review r3).
    if "→" in got or got.startswith(("•", "[")):
        failures.append(f"pick_phrase renderer: ligne du renderer retenue: {got!r}")

    # Meme texte, SANS le renderer : la prose prefixee seule doit passer (le
    # retrait du prefixe ne depend pas de la presence des lignes exclues).
    if pick_phrase("\n".join(rendered.splitlines()[2:6])) != want_rendered:
        failures.append("pick_phrase: prose prefixee seule non extraite")

    # vocabulaire `view` : drift hors ligne (bloquant 1, review #4398 — "Compact"
    # appartient au vocabulaire de summarize, pas de view)
    if VIEW_DETAIL_LEVEL not in VIEW_DETAIL_LEVELS:
        failures.append(f"VIEW_DETAIL_LEVEL {VIEW_DETAIL_LEVEL!r} hors vocabulaire view {VIEW_DETAIL_LEVELS}")

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

    # phase_verify : un repli TEXTUEL ne doit JAMAIS donner PASS. Le fallback pose
    # `semantic_degraded`/`fallback_used`/`actual_search_mode:"text"` et ses lignes
    # portent un taskId : la session cherchee peut ranker en top 5 avec le mauvais
    # backend (roosync-search.tool.ts:289-316, review #4398 r2).
    class DegradedChild:
        def call_tool(self, name, args, timeout_s):
            return json.dumps({
                "semantic_degraded": True,
                "fallback_used": True,
                "original_search_mode": "semantic",
                "actual_search_mode": "text",
                "results": [{"taskId": "claude-x--u1", "best_score": 0.9}],
            }, indent=2)

    deg_out: dict = {}
    try:
        phase_verify(DegradedChild(), "claude-x--u1", "peu importe", deg_out)
        failures.append("phase_verify: un payload degrade a rendu un verdict")
    except DegradedSearch:
        if (deg_out.get("search") or {}).get("mode") != "text":
            failures.append(f"degraded: mode={(deg_out.get('search') or {}).get('mode')!r}")

    # ... et le seul mode suffit : un payload sans drapeau mais textuel tombe pareil
    class TextModeChild:
        def call_tool(self, name, args, timeout_s):
            return json.dumps({
                "actual_search_mode": "text",
                "results": [{"taskId": "claude-x--u1", "best_score": 0.9}],
            }, indent=2)

    try:
        phase_verify(TextModeChild(), "claude-x--u1", "peu importe", {})
        failures.append("phase_verify: actual_search_mode='text' seul n'a pas leve")
    except DegradedSearch:
        pass

    # phase_index end-to-end sur un enfant simule : le view doit porter le bon
    # detail_level (assertion sur les ARGUMENTS envoyes — bloquant 1, review #4398 :
    # le selftest ne couvrait pas cette ligne) et la phrase vient de l'arbre texte
    # multi-lignes du view, pas d'un dump mono-ligne.
    class IndexFakeChild:
        def __init__(self):
            self.calls: list[tuple[str, dict]] = []

        def call_tool(self, name, args, timeout_s):
            self.calls.append((name, args))
            if args.get("action") == "list":
                now = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime())
                # u2 porte un createdAt NON-TEXTE (entier JSON) : premier du listing,
                # il doit etre ecarte par la garde sans lever (TypeError non rattrape
                # = FAIL/exit 1 en production, review #4398 r3). u1 est le candidat.
                return json.dumps({"conversations": [
                    {"taskId": "claude-x--u2", "source": "claude",
                     "metadata": {"totalSize": 50000, "createdAt": 1761000000,
                                  "messageCount": 9, "machineId": socket.gethostname()}},
                    {"taskId": "claude-x--u1", "source": "claude",
                     "metadata": {"totalSize": 50000, "createdAt": now,
                                  "messageCount": 12, "machineId": socket.gethostname()}},
                ]}, indent=2)
            if name == "roosync_indexing":
                return json.dumps({"success": True, "points": 42}, indent=2)
            if args.get("action") == "view":
                # Forme REELLE du view summary : prose sous prefixe `    | `,
                # lignes renderer et footer APRES elle (capture de forme,
                # view-conversation-tree.ts:1245/1249 + engine.ts:234 — r3).
                return "\n".join([
                    "==== session claude-x--u1 ====",
                    "▶️ Task: claude-x--u1 (3 messages)",
                    "  [user]:",
                    "      | Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre.",
                    "  [assistant]:",
                    "      | Verification faite sur les 17 marqueurs PG ce matin, aucun repli observe sur la fenetre de 24 h.",
                    "  [\U0001F6E0️ mcp__roo-state-manager__roosync_dashboard] → success (09:44:11)",
                    "• Taille totale: 19845 chars, Limite: 30000, Surplus: 0 (3 task(s))",
                ])
            raise AssertionError(f"appel inattendu: {name} {args}")

    fake = IndexFakeChild()
    idx_out: dict = {}
    phase_index(fake, None, idx_out)
    list_args = [a for n, a in fake.calls if n == "conversation_browser" and a.get("action") == "list"]
    if not list_args or list_args[0].get("source") != "all":
        failures.append(f"phase_index: list source={list_args[0].get('source') if list_args else None!r} (attendu 'all')")
    view_args = [a for n, a in fake.calls if n == "conversation_browser" and a.get("action") == "view"]
    if not view_args:
        failures.append("phase_index: aucun view emis")
    else:
        va = view_args[0]
        if va.get("detail_level") != VIEW_DETAIL_LEVEL or va.get("detail_level") not in VIEW_DETAIL_LEVELS:
            failures.append(f"phase_index: view detail_level={va.get('detail_level')!r}")
        if va.get("task_id") != "claude-x--u1":
            failures.append(f"phase_index: view task_id={va.get('task_id')!r}")
    # u2 (createdAt non-texte) doit avoir ete ecarte SANS crash : le candidat retenu
    # est u1, preuve que la garde fonctionne.
    if idx_out.get("task_id") != "claude-x--u1":
        failures.append(f"phase_index: task_id={idx_out.get('task_id')!r} (createdAt non-texte non ecarte)")
    if idx_out.get("phrase") != want_rendered:
        failures.append(f"phase_index: phrase={idx_out.get('phrase')!r}")
    if (ph := idx_out.get("phrase")) and ("→" in ph or ph.startswith(("•", "["))):
        failures.append(f"phase_index: phrase = ligne du renderer: {ph!r}")
    if idx_out.get("index") is None or (idx_out.get("index") or {}).get("success") is not True:
        failures.append(f"phase_index: index={idx_out.get('index')!r}")
    index_args = [a for n, a in fake.calls if n == "roosync_indexing"]
    if not index_args:
        failures.append("phase_index: aucun appel roosync_indexing")
    elif index_args[0].get("queued") is not False:
        failures.append(f"phase_index: index queued={index_args[0].get('queued')!r} (attendu False — #4352 g3)")

    # call_tool : une erreur serveur rendue en CONTENU doit lever. La forme testee
    # est celle que le serveur EMET reellement — `isError` sur le RESULTAT, pas sur
    # le bloc de contenu (conversation-browser.ts:351/373/473, index.ts:755). La
    # fixture precedente placait le drapeau dans l'item : elle validait une forme que
    # le RSM n'envoie jamais (review #4398 r2).
    err_child = McpChild.__new__(McpChild)
    err_child._next_id = 1

    class _Stdin:
        def write(self, _s):
            pass

        def flush(self):
            pass

    class _Proc:
        stdin = _Stdin()

    err_child.proc = _Proc()
    err_child._read_message = lambda _t: {
        "id": 1,
        "result": {
            "content": [{
                "type": "text",
                "text": 'Erreur: Valeur invalide pour "detail_level" : "Compact". Valeurs acceptées : skeleton, summary, full.',
            }],
            "isError": True,
        },
    }
    try:
        err_child.call_tool("conversation_browser", {}, 5)
        failures.append("call_tool: contenu isError n'a pas leve RuntimeError")
    except RuntimeError:
        pass

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

    # _read_message : une ligne de LOG non-JSON sur stdout ne doit pas tuer la
    # lecture. Mesure 28/10 : la toute premiere phase --verify live est morte en
    # `Expecting value: line 1 column 2` — le serveur ecrit `[RSM-HEALTH]`/`[WARN]`
    # sur le meme flux que le JSON-RPC.
    noisy = McpChild.__new__(McpChild)
    noisy._lines = queue.Queue()
    noisy._stderr_tail = []
    noisy._noise_tail = []
    noisy._lines.put("[RSM-HEALTH] hosts=2 maxPrivMB=139 verdict=OK\n")
    noisy._lines.put(json.dumps({"id": 7, "result": {"ok": True}}) + "\n")
    noisy_msg = noisy._read_message(5)
    if (noisy_msg.get("result") or {}).get("ok") is not True:
        failures.append(f"_read_message: ligne de log non ignoree -> {noisy_msg!r}")
    if len(noisy._noise_tail) != 1:
        failures.append(f"_read_message: noise_tail={noisy._noise_tail!r}")

    if failures:
        print("[SELFTEST] FAIL")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("[SELFTEST] PASS (phrase, erreur-comme-phrase rejetee, prefixe de rendu | "
          "retire + lignes renderer exclues, vocabulaire view, args du view + list "
          "source=all, createdAt non-texte ecarte, parsing pretty-printe, rang top-5, "
          "repli textuel refuse (drapeau + mode seul), timeout enfant muet, ligne de "
          "log ignoree, index queued=false, isError au niveau resultat)")
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

        # Phase A seule : RIEN n'a ete verifie — l'indexation a reussi (sinon
        # exception => exit 2), le verdict est INDEXED et le code de sortie 0, pour
        # qu'un wrapper qui enchaine A puis B ne s'arrete pas apres A (bloquant 2,
        # review #4398 : un FAIL/exit 1 ici cassait la chaine cross-siege).
        if do_verify:
            out["verdict"] = "PASS" if out.get("pass") else "FAIL"
            exit_code = 0 if out.get("pass") else 1
        else:
            out["verdict"] = "INDEXED"
            exit_code = 0
        if args.json:
            if getattr(child, "_noise_tail", None):
                # Visibilite : des lignes de log ont ete ecartees du flux JSON-RPC.
                out["child_log_lines_skipped"] = len(child._noise_tail)
            print(json.dumps(out, ensure_ascii=False, indent=2, default=str))
        else:
            print(f"[task_id] {out.get('task_id')}")
            if out.get("phrase"):
                print(f"[phrase] {out['phrase']}")
            if "rank" in out:
                print(f"[rank] {out['rank']} (top {MAX_RESULTS}) — machines vues : "
                      f"{out.get('search', {}).get('machines_found')}")
            print(f"[VERDICT] {out['verdict']}")
        return exit_code
    except DegradedSearch as exc:
        # Verdict DEGRADE, PAS INSTRUMENT_ERROR : la sonde et son transport sont
        # sains, c'est le BACKEND qui n'a pas repondu en semantique. Exit 2 — rien
        # n'est prouve — et le mode est dans le label (review #4398 r2). Doit rester
        # AVANT le `except RuntimeError` ci-dessous, dont DegradedSearch herite.
        out["error"] = str(exc)
        out["verdict"] = "DEGRADED"
        if args.json:
            print(json.dumps(out, ensure_ascii=False, indent=2, default=str))
        else:
            print(f"[ERROR] {exc}")
        return 2
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

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
       — jamais une lecture directe du JSONL (#1785) ; la phrase refuse les
       sorties d'outil GENERIQUES (le succes standard d'un append de dashboard,
       les en-tetes gras) et doit etre RARE : un SCAN VERBATIM des transcripts
       locaux ne la retrouve que dans 1 session (la cible). Mesure ai-01 28/10 (file 20261028i) :
       un verify sur « Message ajouté au dashboard '…' » FAIL sans rien mesurer
       — cette ligne vit dans des centaines de sessions ;
    3. indexe la session via roosync_indexing(action:"index", task_id,
       source:"claude-code", queued:false) — le defaut 'roo' resout un repertoire de
       tache et echoue sur un .jsonl ; et depuis g3 le defaut d'indexation MET EN
       FILE (rendre aussitot) : la sonde demande explicitement l'indexation EN
       LIGNE, parce qu'elle a besoin d'un index TERMINE avant d'extraire une phrase ;
       le SUCCES est accepte sous ses DEUX formes — bloc JSON embarque (serveur
       ms>=1560) et Markdown seul (`# Indexation sémantique terminée` +
       `**Chunks indexés:** N`, forme anterieure) — et un succes a **0 chunk n'est
       pas un echec** : 0 veut souvent dire « deja indexee pour cette tache »
       (dedup ms#1557). C'est la phase VERIFY qui tranche, pas le compteur.
       (Mesure ai-01 28/10 : la forme Markdown seule etait lue comme une panne,
       exit 2 sans rien mesurer — verdict faux, mesure saine.) Quand les DEUX
       formes coexistent, le JSON embarque portant `success` FAIT FOI : un
       `success:false` prime sur l'en-tete Markdown (file 20261028i, suivi 1 —
       cas injoignable aujourd'hui, rendu impossible).
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
import itertools
import json
import queue
import re
import socket
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Sequence

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
# RARETE de la phrase (file 20261028i, ai-01 28/10) : le verify live a FAIL sur
# « Message ajouté au dashboard 'workspace-roo-extensions' » — la ligne de succes
# standard de CHAQUE append, presente dans des centaines de sessions. Un FAIL la-
# dessus ne mesure pas l'index. Une phrase retrouvee au-dela de
# MAX_PHRASE_SPREAD_SESSIONS n'est pas discriminante et est ecartee.
#
# La mesure est un SCAN VERBATIM LOCAL (ai-01 CHANGES #4412), pas une recherche
# texte distante : `roosync_search(action:"text")` decoupe la requete en jetons et
# matche sur N'IMPORTE LEQUEL (`search-fallback.tool.ts:76-79`), en rendant
# `totalFound = cleanResults.length` (`:247`) — un compte PLAFONNE de taches qui
# partagent au moins un mot commun. Une phrase presente dans sa seule session y
# « apparait » dans toutes celles qui contiennent « session » ou « dashboard » :
# le filtre s'effondrait a chaque fois, et le verify ne tournait jamais.
MAX_PHRASE_SPREAD_SESSIONS = 1
# MINIMUM 1, pas 0 : la phrase est EXTRAITE de la cible, donc un scan des
# transcripts du siege doit la retrouver au moins chez elle. 0 = corpus
# incomplet/illisible ou phrase manguee par le rendu — la regle precedente
# (« un spread de 0 reste accepte : l'indexation a pu echouer ») parlait de la
# recherche INDEXEE, ou l'absence pouvait signifier un index en panne. Un scan de
# FICHIERS n'a pas cette excuse : l'absence n'y prouve rien, donc on refuse
# (fail-closed) au lieu d'accepter en silence.
MIN_PHRASE_SPREAD_SESSIONS = 1
PHRASE_SPREAD_MAX_TRIES = 5          # candidates evaluees avant d'abandonner
# Bornes de LECTURE du scan verbatim (review ai-01 #4412, points 2 et 3).
# Le corpus d'un siege monte facilement a plusieurs centaines de Mo (535 Mo sur
# ai-01) : le lire en `read_text()` charge un fichier entier en memoire, et une
# seule session geante suffit a faire tomber le processus. La lecture est donc
# LINEAIRE (une ligne a la fois : la memoire est bornee par le plafond de LIGNE,
# jamais par la taille du fichier), avec un plafond par FICHIER et un plafond par
# LIGNE.
#
# Ce qu'un depassement NE fait PAS : il ne saute pas le fichier pour rendre PASS.
# Un fichier non lu est un trou dans la mesure, donc la sonde rend exit 2
# (INSTRUMENT) en nommant le compte et le volume des exclusions. La rectification
# ai-01 sur #4412 est explicite : « un fichier trop gros ne peut pas etre
# simplement saute puis produire PASS ».
# MESURE (web1, 29/10, tracemalloc) : sur un transcript synthetique de 315 Mo, la
# lecture lineaire plafonnee tient en ~0,04 Mo de pic, la lecture d'un bloc
# (`read_text`, l'ancien code) en 945 Mo — ~3x la taille du fichier, et un ratio
# de 21 000 entre les deux. Controle du cas pathologique : une UNIQUE ligne de
# 100 Mo picote a 67 Mo (bornee par le plafond de ligne) et leve
# `InstrumentLimit` — elle n'est jamais chargee entiere.
#
# Consequence sur le plafond fichier : le garder bas (100-256 Mo) alors que la
# memoire ne depend plus de lui rendrait la sonde inutilisable sur le siege qui a
# motive la review — ai-01 porte un transcript de 737 Mo, et un plafond a 256 Mo
# y rendrait un exit 2 a chaque run, sans rien mesurer. Il ne reste donc qu'un
# garde anti-derive (temps de balayage), place tres au-dessus de tout transcript
# reel (le plus gros observe : 737 Mo).
MAX_CORPUS_FILE_BYTES = 4 * 1024 * 1024 * 1024   # 4 Go par transcript (garde anti-derive)
MAX_CORPUS_LINE_BYTES = 32 * 1024 * 1024         # 32 Mo par ligne (sortie d'outil geante)
# NB : la borne de ligne est comparee a `len(chunk)`, c'est-a-dire en CARACTERES
# deja lus et non en octets du fichier. C'est la grandeur qui compte ici : c'est
# la memoire allouee qu'on borne (~1 a 4 octets par caractere selon le contenu).
# Corpus de reference du scan verbatim : les transcripts Claude Code du siege.
# `candidate_sessions` ne retient que `source in ("claude","claude-code")`, et
# l'indexeur lit ces memes fichiers — c'est donc exactement le corpus dans lequel
# la phrase doit etre rare. Un corpus absent ou vide est une ERREUR (fail-closed),
# jamais un spread de 0.
LOCAL_CORPUS_DEFAULT = Path.home() / ".claude" / "projects"
# Repertoire des transcripts de SOUS-AGENTS : ils appartiennent a la session
# parente (review ai-01 #4412, point 3). Les compter comme des sessions gonfle le
# spread d'une phrase presente chez la cible elle-meme — une phrase ecrite par le
# sous-agent du siege ferait echouer le critere « <= 1 session ».
SUBAGENT_DIR = "subagents"
# Dossiers dont les `.jsonl` ne sont PAS des sessions indexables (review ai-01
# r4, observation corpus) : `memory/user-words-journal.jsonl` et consorts sont
# des journaux, pas des transcripts de session. Les compter gonflerait le spread
# d'une phrase banale. Aucun fichier n'est supprime - ils sont seulement
# ECARTES de l'eligibilite.
NON_SESSION_DIRS = {"memory", SUBAGENT_DIR}
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


# Formes de SUCCES d'indexation (mesure ai-01, 28/10 ~13:50Z) :
#  - >= ms 1560 : Markdown + bloc JSON embarque (compteurs + raison) ;
#  - avant      : Markdown SEUL (`# Indexation sémantique terminée` + `**Chunks indexés:** N`,
#                 index-task.tool.ts:108). Un succes inline n'a JAMAIS porte de JSON,
#                 et la sonde le lisait donc comme un ECHEC -> exit 2 « instrument en
#                 panne » alors que l'indexation avait abouti. C'est la 3e variante de
#                 la classe « verdict masque » : le verdict etait faux, pas la mesure.
INDEX_MARKDOWN_HEADER = "# Indexation sémantique terminée"
INDEX_CHUNKS_RE = re.compile(r"\*\*Chunks indexés:\*\*\s*(\d+)")
INDEX_REASON_RE = re.compile(r"\*\*Raison:\*\*\s*(.+)")


def parse_index_result(text: str):
    """Normalise les deux formes de succes ; rend None si ce n'en est pas un.

    L'ECHEC a sa propre forme (`# Erreur d'indexation`, leve par `call_tool` via
    `isError`), donc l'absence des deux marqueurs de succes reste un echec : on
    n'accepte jamais « pas d'erreur connue » comme un succes.
    """
    payload = parse_embedded_json(text)
    if isinstance(payload, dict) and "success" in payload:
        # PRECEDENCE (file 20261028i, suivi 1) : un JSON embarque portant
        # `success` fait FOI sur l'en-tete Markdown qui l'entoure. Un
        # `success:false` derriere « # Indexation sémantique terminée » serait
        # sinon lu comme un succes par la branche Markdown ci-dessous. Cas
        # aujourd'hui injoignable (le serveur n'embarque un JSON que sur
        # succes) : on le rend IMPOSSIBLE plutot que d'attendre de le vivre.
        if payload.get("success") is not True:
            return None
        payload.setdefault("form", "json")
        # Clef normalisee, quelle que soit la forme : les consommateurs (et la
        # sortie `--json`) n'ont pas a connaitre deux orthographes.
        if "chunks_indexed" not in payload and "chunksIndexed" in payload:
            payload["chunks_indexed"] = payload["chunksIndexed"]
        return payload
    raw = text or ""
    match = INDEX_CHUNKS_RE.search(raw)
    if match and INDEX_MARKDOWN_HEADER in raw:
        parsed = {
            "success": True,
            "form": "markdown",
            "chunks_indexed": int(match.group(1)),
        }
        reason = INDEX_REASON_RE.search(raw)
        if reason:
            parsed["reason"] = reason.group(1).strip()
        return parsed
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

# Sorties d'OUTIL generiques : presentes dans presque toute session ayant appele
# l'outil (ligne de succes d'un append de dashboard, en-tetes de boite). Choisir
# une phrase la echoue le verify SANS mesurer l'index (mesure ai-01 28/10 : FAIL
# sur « Message ajouté au dashboard 'workspace-roo-extensions' », file 20261028i).
# La rarete mesuree (pick_rare_phrase) attrape le reste de la famille.
_GENERIC_TOOL_OUTPUT_MARKERS = (
    "Message ajouté au dashboard",                    # roosync_dashboard append
    "Message envoyé", "Réponse envoyée",              # roosync_messages send/reply
    "Message marqué comme lu",                        # roosync_messages mark_read
    "Actions disponibles", "Boîte de Réception",      # en-tetes de rendu inbox
)

# Decorations de presentation posees DEVANT une ligne de resultat : emoji de
# statut (le serveur prefixe ses succes d'un `✅`), tag crochet `[OK]`/`[DONE]`,
# gras `**`, `Succès :`. Un `startswith` nu les laisse toutes passer (review
# #4412 : Hermes 🟠 + ai-01 CHANGES — `✅ Message ajouté au dashboard …` etait
# retenue comme phrase). Les tests de marqueurs s'appliquent a la ligne NUE.
# Le tag crochet est limite aux MAJUSCULES : `[tool_result]` (lowercase) doit
# rester refuse par le tuple de prefixes, pas redevenir eligible apres retrait.
_DECOR_EMOJI = re.compile(r"^[℀-⯿️‍\U0001F000-\U0001FBFF]+")
_DECOR_TAG = re.compile(r"^\[[A-Z]{1,10}\]\s*")
_DECOR_SUCCES = re.compile(r"^Succès\s*:\s*")


def _strip_line_decorations(ln: str) -> str:
    """Ligne nue apres retrait des decorations (`✅`, `[OK]`, `**`, `Succès :`)
    — le support sur lequel les marqueurs generiques et d'erreur se testent."""
    prev = None
    while prev != ln:
        prev = ln
        ln = _DECOR_EMOJI.sub("", ln)
        ln = _DECOR_TAG.sub("", ln)
        ln = _DECOR_SUCCES.sub("", ln)
        ln = ln.lstrip("* ")
    return ln


def _phrase_candidates(text: str):
    """Lignes candidates de la phrase, de la FIN vers le debut (contenu tardif =
    plus specifique). Filtres de pick_phrase, en generateur pour que la rarete
    mesuree (pick_rare_phrase) puisse passer a la candidate suivante."""
    for raw in reversed(text.splitlines()):
        ln = raw.strip()
        if ln.startswith(_RENDER_PREFIX):
            ln = ln[len(_RENDER_PREFIX):]
        if not (PHRASE_MIN_CHARS <= len(ln) <= PHRASE_MAX_CHARS):
            continue
        if SECRET_MARKERS.search(ln):
            continue
        bare = _strip_line_decorations(ln)
        # Prefixes d'erreur serveur : un message d'erreur fait 60-240 caracteres et
        # passe toutes les autres bornes — il ne doit JAMAIS devenir la phrase de
        # sonde (durcissement Hermes, review #4398). Test sur la ligne NUE : la
        # forme decoree `✅ Erreur lors de…` passe le test brut (review #4412).
        if bare.startswith(("Tool call:", "[tool_result]", "```", "#", "|", "- [",
                            "Erreur:", "Erreur lors de", "Error:", "ERROR:")):
            continue
        if any(ln.startswith(m) for m in _RENDERER_LINE_MARKERS):
            continue
        # Sorties d'outil generiques + en-tetes gras (`**Tâche:**`, `**Status**`,
        # `**📋 Aperçu…`) : metadata de rendu, pas de la prose de session. Mesure
        # ai-01 28/10 (file 20261028i) : sans cela, le verify FAIL sur la ligne de
        # succes standard d'un append de dashboard — sans rien mesurer. Test sur
        # la ligne NUE : le serveur prefixe ses succes d'un `✅` et les deux
        # reviews ont mesure `✅ Message ajouté…` / `[OK] Message envoyé…` /
        # `Succès : Message ajouté…` retenues comme phrases (review #4412).
        if any(bare.startswith(m) for m in _GENERIC_TOOL_OUTPUT_MARKERS):
            continue
        if ln.startswith("**"):
            continue
        # Signature de LIGNE DE TABLEAU markdown : apres retrait du prefixe de
        # rendu `| `, le premier `|` d'une ligne prefixee a ete consomme et
        # `col1 | col2 |` echappe au filtre `|` ci-dessus (review #4412, Hermes
        # 🟡 : le commentaire promettait le rejet des tableaux, la forme
        # prefixee passait). Deux separateurs suffisent a signer la ligne.
        if ln.count("|") >= 2 and " | " in ln:
            continue
        if ln.count('"') > 6 or ln.count("{") + ln.count("}") > 2:
            continue
        yield ln


def pick_phrase(text: str) -> str:
    """Phrase distinctive, balayee depuis la fin (contenu tardif = plus specifique).

    Regles : longueur PHRASE_MIN..PHRASE_MAX, pas de marqueur de secret, pas de
    ligne de commande/outil, NI du renderer (bruit non semantique, absent de
    l'index tel quel), NI de sortie d'outil generique / en-tete gras, pas de
    markdown lourd. Le prefixe de rendu `| ` est retire AVANT les filtres : le
    `|` doit rejeter les tableaux markdown, pas la prose.
    """
    for ln in _phrase_candidates(text):
        return ln
    raise RuntimeError("aucune phrase candidate extraite de la session (contenu trop pauvre)")


class InstrumentLimit(RuntimeError):
    """Une borne de lecture empeche de mesurer le corpus ENTIER.

    Distincte d'une erreur generique de propos : ce n'est ni un PASS ni un FAIL de
    fond, c'est l'INSTRUMENT qui ne peut pas conclure (exit 2). Sauter le fichier
    hors bornes et rendre PASS serait un faux succes — exactement le defaut que la
    review ai-01 (#4412) a nomme.
    """


def corpus_files(root: Path) -> list[Path]:
    """Les transcripts `.jsonl` du corpus local — une liste VIDE est une ERREUR.

    Fail-closed (ai-01 CHANGES #4412, point 2) : un corpus absent ou vide ne rend
    pas « 0 session », il rend une erreur. Sans cette garde, un `--corpus-dir`
    mal pointe (ou un corpus deplace) ferait trouver TOUTES les phrases rares et
    ramenerait exactement le defaut mesure — une sonde qui accepte une phrase
    banale parce qu'elle n'a rien pu mesurer.

    UNE ENTREE = UNE SESSION (review ai-01 #4412, point 3). Les transcripts de
    sous-agents vivent sous `<session>/subagents/*.jsonl` : ce sont des morceaux
    de la MEME session, pas des sessions. Ils sont ECARTES et jamais LUS — leur
    contenu n'est ni balaye ni replie sur la session parente (le transcript de
    tete represente seul la session) ; seul leur NOMBRE est rapporte dans
    l'erreur de corpus vide. Les compter comme des sessions gonflerait le
    spread d'une phrase ecrite par le sous-agent de la cible, et l'arme
    « spread <= 1 » se declencherait sur une phrase qui n'existe que chez elle.

    ELIGIBILITE = LE LAYOUT REEL d'une session indexable (review ai-01 r4,
    observation corpus). Un transcript de session est un `.jsonl` pose
    DIRECTEMENT dans un repertoire de projet : `<projets>/<hash>/<uuid>.jsonl`
    (racine = le conteneur de projets, `LOCAL_CORPUS_DEFAULT`) ou
    `<hash>/<uuid>.jsonl` (racine = le repertoire projet lui-meme). Tout le reste
    est ECARTE et COMPTE : `memory/user-words-journal.jsonl` (un journal, pas une
    session), les sous-dossiers plus profonds, et les `.jsonl` hors layout. Le
    defaut nomme un fichier `memory/…` comme une session, ce qui gonfle le spread
    d'une phrase banale - exactement l'arme « spread <= 1 » qu'on veut ecarter.
    Aucun fichier n'est SUPPRIME : l'eligibilite est filtree, la donnee reste.
    """
    if not root.is_dir():
        raise RuntimeError(
            f"corpus local introuvable : {root} — la rarete VERBATIM n'est pas "
            "mesurable sans lui (fail-closed : « corpus absent » n'est pas "
            "« 0 session »)"
        )
    sessions: dict[str, Path] = {}
    subagent_files = 0
    non_session_files = 0
    for p in root.rglob("*.jsonl"):
        if not p.is_file():
            continue
        if SUBAGENT_DIR in {seg.lower() for seg in p.parts[:-1]}:
            subagent_files += 1
            continue
        try:
            rel_parts = p.relative_to(root).parts
        except ValueError:
            non_session_files += 1
            continue
        # Un dossier connu non-session ('memory', 'subagents') sur le chemin, ou
        # une profondeur hors layout : ce `.jsonl` n'est pas une session.
        if any(seg.lower() in NON_SESSION_DIRS for seg in rel_parts[:-1]) or len(rel_parts) not in (1, 2):
            non_session_files += 1
            continue
        # Cle de session : le basename du transcript de tete (`<uuid>.jsonl`).
        # `setdefault` : deux chemins qui resolvent la meme session ne comptent
        # qu'une fois, quel que soit l'ordre de parcours.
        sessions.setdefault(p.stem, p)
    if not sessions:
        raise RuntimeError(
            f"corpus local VIDE sous {root} (aucun transcript de session, "
            f"{subagent_files} fichier(s) de sous-agent ecarte(s), "
            f"{non_session_files} fichier(s) hors layout de session ecarte(s)) — "
            "spread non mesurable (fail-closed)"
        )
    return sorted(sessions.values())


def _phrase_needles(phrase: str) -> tuple[str, ...]:
    """Formes sous lesquelles la phrase peut apparaitre dans un transcript.

    Un `.jsonl` stocke le texte dans des chaines JSON : un guillemet ou un
    antislash y est echappe, et certaines sessions ecrivent l'ASCII etendu en
    `\\uXXXX`. Tester la seule forme brute SOUS-COMPTERAIT des sessions qui
    contiennent pourtant la phrase — or le sous-comptage est le sens DANGEREUX
    (une phrase banale passerait pour rare).
    """
    needles = [phrase]
    for ensure_ascii in (False, True):
        escaped = json.dumps(phrase, ensure_ascii=ensure_ascii)[1:-1]
        if escaped not in needles:
            needles.append(escaped)
    return tuple(needles)


def verbatim_spreads(files: Sequence[Path], phrases: Sequence[str]) -> dict[str, int]:
    """Nombre de SESSIONS dont le texte contient la phrase LITTERALEMENT.

    Instrument de rarete (ai-01 CHANGES #4412, point 1). Remplace la recherche
    texte distante, qui ne mesurait pas ce qu'elle annoncait : le handler
    tokenise en OR (« match ANY token », `search-fallback.tool.ts:76-79`) et rend
    `totalFound = cleanResults.length` (`:247`), un compte PLAFONNE de taches
    partageant au moins un mot. Deux consequences mesurees par ai-01 : une phrase
    presente dans sa seule session « apparait » partout ou « session » figure, et
    les 5 candidates s'epuisaient avant que le verify ne tourne.

    Une passe par ensemble de candidates (<= 5) de CHAQUE essai : la boucle
    d'indexation appelle cette fonction une fois par candidat tente (<=
    INDEX_ATTEMPTS), et chaque appel re-balaye le corpus. A l'INTERIEUR d'un
    essai, un seul passage couvre toutes les candidates — aucune passe par
    phrase. Chaque phrase est plafonnee a MAX + 1 des qu'elle depasse le seuil :
    au-dela, le detail ne sert plus a decider, seulement a nommer l'echec.

    Lecture LINEAIRE et bornee (review ai-01 #4412, point 2) : le transcript est
    parcouru ligne a ligne, donc la memoire est bornee par la plus grosse LIGNE et
    non par la taille du FICHIER. Un fichier ou une ligne au-dela des plafonds ne
    fait pas « sauter et continuer » : il est compte comme EXCLUSION et la mesure
    entiere leve `InstrumentLimit` (exit 2). Une exclusion silencieuse rendrait un
    PASS sur un corpus qu'on n'a pas lu — le faux succes que la review nomme.

    UNE SESSION = UN COMPTE (review ai-01 r4, blocage 1) : une phrase y compte
    AU PLUS UNE FOIS, meme si elle y apparait sur plusieurs lignes. Compter par
    LIGNE saturationait a tort le spread d'une phrase qui n'existe que chez elle
    — le cas reel d'une session qui cite sa propre reponse ou un echo d'outil
    (reproduction d'ai-01 : deux lignes, une session, `{phrase: 2}` au lieu de
    `{phrase: 1}`). Le contrat — `rarity.corpus_sessions`, le README et le nom de
    la mesure — parle de SESSIONS ; le code comptait des lignes.

    CANDIDATES REPETEES : dedupliquees en entree, pour que lister la meme phrase
    deux fois ne change pas la mesure (review ai-01 r4).
    """
    # Une candidate listee plusieurs fois reste UNE candidate : le compte est un
    # nombre de sessions, jamais un nombre d'occurrences dans la liste.
    phrases = list(dict.fromkeys(phrases))
    counts = {p: 0 for p in phrases}
    needles = {p: _phrase_needles(p) for p in phrases}
    saturated: set[str] = set()
    excluded: list[tuple[str, float, str]] = []
    for path in files:
        if len(saturated) == len(phrases):
            break
        try:
            size = path.stat().st_size
        except OSError as exc:
            raise RuntimeError(
                f"corpus local illisible ({path.name}) : {exc} — spread non mesurable "
                "(fail-closed)"
            ) from exc
        if size > MAX_CORPUS_FILE_BYTES:
            excluded.append((path.name, size / 1e6, "plafond fichier"))
            continue
        # Lecture LINEAIRE plafonnee. `for line in fh` ne suffit PAS : l'iterateur
        # alloue la ligne ENTIERE avant qu'on puisse mesurer sa taille, donc un
        # unique enregistrement de plusieurs Go coûterait plusieurs Go malgre la
        # « lecture ligne a ligne ». `readline(plafond + 1)` rend au plus
        # plafond+1 caracteres : au-dela, la ligne est DETECTEE sans etre chargee
        # (review ai-01 #4412, point 2).
        try:
            # Phrases vues dans CE fichier : une session = un compte, quel que
            # soit le nombre de lignes qui portent la phrase.
            seen: set[str] = set()
            file_excluded = False
            with path.open("r", encoding="utf-8", errors="replace") as fh:
                while True:
                    line = fh.readline(MAX_CORPUS_LINE_BYTES + 1)
                    if not line:
                        break
                    if len(line) > MAX_CORPUS_LINE_BYTES:
                        # Une ligne geante (sortie d'outil) ne peut pas etre
                        # comparee sans repayer le pic memoire qu'on vient
                        # d'eliminer : le fichier est une EXCLUSION, pas un 0.
                        excluded.append((path.name, len(line) / 1e6, "plafond ligne"))
                        file_excluded = True
                        break
                    for phrase in phrases:
                        if phrase in saturated:
                            continue
                        if any(n in line for n in needles[phrase]):
                            seen.add(phrase)
            if file_excluded:
                # Fichier exclu : aucune phrase n'y est comptee (l'exclusion
                # releve plus bas de toute facon — un PASS sur un corpus
                # partiellement lu serait un faux succes).
                continue
            for phrase in seen:
                counts[phrase] += 1
                if counts[phrase] > MAX_PHRASE_SPREAD_SESSIONS:
                    saturated.add(phrase)
        except OSError as exc:
            # Une session illisible = un trou dans le corpus : l'absence de la
            # phrase n'y est plus prouvable, donc on refuse de conclure.
            raise RuntimeError(
                f"corpus local illisible ({path.name}) : {exc} — spread non mesurable "
                "(fail-closed)"
            ) from exc
    if excluded:
        total_mb = sum(mb for _, mb, _ in excluded)
        detail = ", ".join(f"{name} ({mb:.0f} Mo, {why})" for name, mb, why in excluded[:3])
        raise InstrumentLimit(
            f"{len(excluded)} transcript(s) hors bornes de lecture ({total_mb:.0f} Mo; "
            f"plafond {MAX_CORPUS_FILE_BYTES / 1e6:.0f} Mo/fichier, "
            f"{MAX_CORPUS_LINE_BYTES / 1e6:.0f} Mo/ligne) : {detail}"
            f"{' …' if len(excluded) > 3 else ''} — la rarete n'a PAS ete mesuree sur le "
            "corpus entier : un transcript ecarte ne peut pas produire un PASS "
            "(rectification ai-01 : « un fichier trop gros ne peut pas etre simplement "
            "saute puis produire PASS »)"
        )
    return counts


def pick_rare_phrase(text: str, spread_fn) -> tuple[str, int]:
    """Premiere candidate retrouvee dans [MIN, MAX] session(s) VERBATIM.

    `spread_fn` rend le nombre de sessions contenant la phrase litteralement, ou
    `None` quand elle n'a pas ete mesuree. `None` LEVE (fail-closed, ai-01
    CHANGES #4412 point 2) : « pas de compte » n'est pas « aucun matching », et
    l'ancien `totalFound` absent lu comme 0 faisait accepter n'importe quoi.

    spread 0 est REFUSE aussi : la phrase vient de la cible, donc un scan de ses
    transcripts doit la retrouver au moins chez elle. 0 signifie corpus
    incomplet/illisible ou phrase manguee par le rendu — rien qui autorise a
    conclure « rare ».
    """
    tried = []
    for ln in _phrase_candidates(text):
        if len(tried) >= PHRASE_SPREAD_MAX_TRIES:
            break
        spread = spread_fn(ln)
        if spread is None:
            # Aucune mesure pour cette candidate : on ne peut ni l'accepter ni la
            # compter comme « non rare ». Lever est le seul verdict honnete.
            raise RuntimeError(
                f"spread VERBATIM non mesure pour une candidate ({ln[:60]}…) — "
                "fail-closed : un compte absent n'est pas un compte nul"
            )
        tried.append((ln, spread))
        if MIN_PHRASE_SPREAD_SESSIONS <= spread <= MAX_PHRASE_SPREAD_SESSIONS:
            return ln, spread
    if not tried:
        # Distinction exige par les deux reviews (ai-01 CHANGES :547, Hermes 🟡) :
        # « aucune candidate apres refus statique » n'est PAS un echec de rarete —
        # 0 recherche consommee, et le message doit le dire.
        raise RuntimeError(
            "aucune phrase candidate apres filtrage statique — toutes les lignes "
            "du view sont du bruit de rendu ou de sortie d'outil (refus statique, "
            "pas un echec de rarete)"
        )
    # Les deux familles de refus sont nommees SEPAREMENT : « trop banale » et
    # « absente du corpus local » demandent des gestes opposes (prendre une autre
    # phrase / verifier le corpus), et les confondre redonne exactement le message
    # trompeur que la review :547 avait fait retirer.
    absent = [ln for ln, spread in tried if spread < MIN_PHRASE_SPREAD_SESSIONS]
    common = [(ln, spread) for ln, spread in tried if spread > MAX_PHRASE_SPREAD_SESSIONS]
    # Un compte saturé vaut « au moins N », pas N (review ai-01 #4412, info) : le
    # scan s'arrete à MAX+1, donc l'afficher comme un compte exact ferait lire une
    # borne basse comme une mesure — c'est ce chiffre que l'opérateur utilise pour
    # décider de prendre une autre phrase.
    detail = "; ".join(
        f"{'≥ ' if spread > MAX_PHRASE_SPREAD_SESSIONS else ''}{spread} session(s) : {ln[:60]}…"
        for ln, spread in tried
    )
    raise RuntimeError(
        f"aucune phrase discriminante sur {len(tried)} candidate(s) — attendu "
        f"{MIN_PHRASE_SPREAD_SESSIONS}-{MAX_PHRASE_SPREAD_SESSIONS} session(s) "
        f"VERBATIM ; {len(common)} trop banale(s), {len(absent)} absente(s) du "
        f"corpus local — {detail}"
    )


def index_source(conv: dict) -> str:
    """Source a declarer a l'indexeur.

    Le defaut du service est 'roo' : il resout `<location>/tasks/<id>` (un
    REPERTOIRE). Une session Claude Code est un `.jsonl` plat, resolu par la
    branche 'claude-code' -> sans ce champ l'indexation echoue a coup sur avec
    « Task directory for '...' not found in any storage location » (mesure 28/10,
    3 candidats, 2 formes d'erreur selon la branche empruntee).
    """
    return "roo" if str(conv.get("source") or "") == "roo" else "claude-code"


def _short_index_error(err: str) -> str:
    """La ligne `**Erreur:**` d'une reponse d'echec, pas son en-tete.

    Le texte d'erreur du serveur commence par `# Erreur d'indexation` puis un
    task_id de 60+ caracteres : tronquer le texte BRUT coupait avant la seule
    partie informative (mesure 28/10). On extrait donc la raison, et on retombe
    sur le texte brut quand la forme ne la porte pas (erreur JSON-RPC, timeout).
    """
    match = re.search(r"\*\*Erreur:\*\*\s*(.+)", err or "")
    return (match.group(1) if match else (err or "")).replace("\n", " ").strip()


def phase_index(
    child: McpChild,
    task_id: str | None,
    out: dict,
    corpus_dir: Path = LOCAL_CORPUS_DEFAULT,
) -> None:
    """Indexe le premier candidat indexable, puis extrait la phrase de son contenu.

    L'ordre compte : indexer AVANT d'extraire la phrase evite de payer un `view`
    par candidat, et un candidat non indexable (session d'une autre machine dans
    le listing, fichier disparu) laisse simplement la place au suivant.
    """
    attempts: list[dict] = []
    # Chargé AVANT la boucle : un corpus absent ou vide n'est pas l'échec d'UN
    # candidat, c'est la sonde entière qui ne peut pas mesurer (fail-closed,
    # ai-01 CHANGES #4412 point 2). Le laisser dans le `try` par candidat ferait
    # rendre « indexation en échec sur 3 candidat(s) » — un faux diagnostic.
    corpus = corpus_files(corpus_dir)
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
            idx = parse_index_result(idx_raw)
            if idx is None:
                # Pas un succes : le service repond en MARKDOWN (`# Erreur d'indexation`)
                # ou en erreur JSON-RPC. La forme de SUCCES, elle, est normalisee par
                # parse_index_result (JSON embarque, ou Markdown seul sur un serveur
                # anterieur) — un succes n'est plus jamais lu comme une panne.
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
            # RARETE mesuree (file 20261028i) : une ligne generique (le succes
            # standard d'un append de dashboard) echoue le verify sans rien
            # mesurer — la phrase doit vivre dans <= 1 session, la cible.
            # RARETE VERBATIM (ai-01 CHANGES #4412) : une passe sur le corpus
            # local pour l'ensemble des <=5 candidates DE CET ESSAI (la boucle
            # appelle le scan une fois par candidat tente, <= INDEX_ATTEMPTS),
            # puis la premiere qui vit dans une seule session. Aucun appel
            # `roosync_search` ici : le mode texte tokenise en OR et rend un
            # compte plafonne, donc il ne mesurait pas la phrase (mesure ai-01
            # sur `search-fallback.tool.ts:76-79`/`:247`).
            candidates = list(
                itertools.islice(_phrase_candidates(view_raw), PHRASE_SPREAD_MAX_TRIES)
            )
            spreads = verbatim_spreads(corpus, candidates)
            phrase, spread = pick_rare_phrase(view_raw, spreads.get)
        except InstrumentLimit:
            # Une borne de lecture (fichier/ligne hors plafond) est un etat du
            # CORPUS, pas l'echec d'UN candidat : le candidat suivant re-balayerait
            # le meme corpus et re-payerait un appel d'index pour le meme verdict
            # (mandat ai-01 29/10 : abort immediat, UN seul scan, AUCUN appel
            # d'index suivant). Propagee vers le handler principal ->
            # INSTRUMENT_ERROR / exit 2.
            raise
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
        # Preuve de la mesure de rareté : sur QUEL corpus et avec quel spread la
        # phrase a été retenue. Sans ces deux nombres, un verdict live ne dit pas
        # si le filtre a travaillé ou s'il a laissé passer.
        # `corpus_sessions` : unites de compte REELLES (review ai-01 #4412 point 3).
        # Le nom `corpus_files` mentait depuis que le sous-agent est ecarte, pas
        # lu (une session = son transcript de tete seul), et la cle est nouvelle
        # (pas renommee) pour qu'un lecteur d'ancien
        # JSON ne prenne pas un compte de sessions pour un compte de fichiers.
        out["rarity"] = {"corpus_sessions": len(corpus), "spread": spread}
        out["index_attempts"] = attempts  # candidats ecartes avant celui-ci
        return
    raise RuntimeError(
        f"indexation en echec sur {len(attempts)} candidat(s) — dernier: "
        f"{attempts[-1]['error'] if attempts else 'aucun candidat'}"
        # Detail de CHAQUE essai : sans lui le rapport ne montrait que le dernier,
        # et « 3 candidats en echec » ne disait pas POURQUOI les deux premiers
        # l'etaient (mesure web1 28/10 : les 3 sont des sessions d'une AUTRE
        # machine, non indexables depuis ce siege — invisible dans l'ancien texte).
        + (
            " | essais: "
            + "; ".join(
                f"{a['task_id'].rsplit('--', 1)[-1][:8]}={_short_index_error(str(a['error']))[:90]}"
                for a in attempts
            )
            if attempts
            else ""
        )
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

    # pick_phrase : sorties d'outil GENERIQUES refusees (file 20261028i). Le FAIL
    # de production mesurait « Message ajouté au dashboard 'workspace-roo-extensions' »,
    # la ligne de succes standard de CHAQUE append : elle ne prouve rien sur
    # l'index. Les en-tetes gras (`**Tâche:**`) sont de la metadata de rendu.
    generic = "\n".join([
        "Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre.",
        "Message ajouté au dashboard 'workspace-roo-extensions' [split en 2 parts]",
        "**Tâche:** claude-x--u1 -- entete de resultat pas plus longue que ca pour rester dans les bornes.",
    ])
    got_generic = pick_phrase(generic)
    if got_generic != "Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre.":
        failures.append(f"pick_phrase generique: {got_generic!r}")

    # Decorations : le serveur prefixe ses lignes de succes d'un emoji, les
    # appelants de `[OK]`/`Succès :` — le refus statique doit voir DESSOUS
    # (review #4412 : Hermes 🟠 + ai-01 CHANGES ; les trois formes mesurees en
    # review doivent echouer, pas seulement la forme nue).
    decorated_generic = "\n".join([
        "Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre.",
        "✅ Message ajouté au dashboard 'workspace-roo-extensions' (id: msg-20261028T203330-vokt0i-0001)",
        "[OK] Message envoyé à myia-po-2025:roo-extensions (msg-20261028T214940-27is1d) priorite HIGH",
        "Succès : Message ajouté au dashboard 'workspace-hermes-agent' avec 3 tags et 1 mention",
        "**Message ajouté au dashboard 'workspace-roo-extensions'** en gras, meme combat de bord",
        "✅ Erreur lors de l'envoi du message: destinataire inconnu sur le canal roosync_messages",
    ])
    got_decorated = pick_phrase(decorated_generic)
    if got_decorated != "Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre.":
        failures.append(f"pick_phrase decore: {got_decorated!r}")
    # Vraie prose decoree : la normalisation ne doit pas la rendre ineligible —
    # sinon le filtre refuserait la moitie d'une session reelle d'execution.
    decorated_prose = "✅ Build vert sur po-2023 ce matin : 15907 tests passes, zero echec apres le bump submodule."
    if pick_phrase(decorated_prose) != decorated_prose:
        failures.append("pick_phrase decore: une vraie prose decoree a ete refusee")

    # Ligne de tableau dont le premier `|` a ete consomme comme prefixe de rendu :
    # deux separateurs ` | ` signent le tableau (review #4412, Hermes 🟡 — le
    # filtre `|` ne couvrait que la forme non prefixee).
    try:
        pick_phrase("Machine | Verdict | Mesure | Gain projeté pour le prochain tour de coordination flotte")
        failures.append("pick_phrase: une ligne de tableau depourvue de son premier | a ete retenue")
    except RuntimeError:
        pass

    # pick_rare_phrase : la rareté tranche là où les filtres statiques ne voient
    # rien. La ligne tardive (derniere => premiere scannée) n'est PAS statiquement
    # generique mais vit dans 3 sessions : ecartee. La prose plus ancienne, elle,
    # n'est que dans la cible : retenue.
    late_multi = "Total : 140 messages, 2 non lus, 138 lus — aucune action requise de ce cycle present."
    def _fake_spread(p: str):
        return 3 if p == late_multi else 1

    rare_body = "\n".join([
        "Verification faite sur les 17 marqueurs PG ce matin, aucun repli observe sur la fenetre de 24 h.",
        late_multi,
    ])
    got_rare, got_spread = pick_rare_phrase(rare_body, _fake_spread)
    if got_rare != "Verification faite sur les 17 marqueurs PG ce matin, aucun repli observe sur la fenetre de 24 h." or got_spread != 1:
        failures.append(f"pick_rare_phrase: {(got_rare, got_spread)!r}")
    # spread 0 est REFUSE (ai-01 CHANGES #4412 point 2). La phrase vient de la
    # CIBLE : un scan de ses transcripts doit la retrouver au moins chez elle.
    # 0 = corpus incomplet/illisible ou phrase manguee par le rendu. L'ancienne
    # regle « 0 accepte » venait de la recherche INDEXEE (0 pouvait y dire « index
    # en panne ») ; un scan de FICHIERS n'a pas cette excuse.
    try:
        pick_rare_phrase(rare_body, lambda p: 0)
        failures.append("pick_rare_phrase: spread 0 a ete accepte (fail-open)")
    except RuntimeError as exc:
        if "absente(s) du corpus local" not in str(exc):
            failures.append(f"pick_rare_phrase: refus a 0 mal nomme: {exc}")
    # Aucune mesure rendue (None) => LEVER. C'est le fail-open reproche : l'ancien
    # `totalFound` absent etait converti en 0, et 0 passait pour « rare ».
    try:
        pick_rare_phrase(rare_body, lambda p: None)
        failures.append("pick_rare_phrase: spread None a ete accepte (fail-open)")
    except RuntimeError as exc:
        if "non mesure" not in str(exc):
            failures.append(f"pick_rare_phrase: None mal nomme: {exc}")
    # Tout banale => echec BRUYANT qui dit les compteurs.
    try:
        pick_rare_phrase(late_multi, lambda p: 7)
        failures.append("pick_rare_phrase: une phrase a 7 sessions a ete retenue")
    except RuntimeError as exc:
        if "7 session(s)" not in str(exc):
            failures.append(f"pick_rare_phrase: compte absent du message: {exc}")
        # Un compte SATURE est imprime « ≥ N » (review ai-01 #4412, info) : le scan
        # s'arrete a MAX+1, donc N n'est qu'une borne basse. Sans le « ≥ », le
        # message presente une borne comme une mesure.
        if "≥ 7 session(s)" not in str(exc):
            failures.append(f"pick_rare_phrase: compte saturé non marqué « ≥ »: {exc}")

    # RARETE VERBATIM vs TOKENISATION OR (ai-01 CHANGES #4412 point 1). Le serveur
    # decoupe la requete et matche sur N'IMPORTE quel jeton
    # (`search-fallback.tool.ts:76-79`), en rendant un compte PLAFONNE
    # (`:247`) : une phrase presente dans SA SEULE session « apparait » dans
    # toutes celles qui partagent un mot. Le scan local doit dire 1, jamais 4.
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        target_phrase = (
            "Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre."
        )
        (root / "a-target.jsonl").write_text(
            json.dumps({"text": target_phrase}), encoding="utf-8")
        # Trois sessions qui partagent des MOTS de la phrase (relais, dashboards,
        # chaque siege, jalon...) mais aucune ne la contient : un compteur
        # tokenise les retiendrait toutes les trois.
        for i, jeton in enumerate((
            "relais dashboards deconnexion observee sur la fenetre nocturne du service",
            "chaque siege doit poser sa cle avant tout redemarrage du service audio",
            "le jalon du 27 octobre reste la cible de la migration flotte complete",
        )):
            (root / f"b-{i}.jsonl").write_text(json.dumps({"text": jeton}), encoding="utf-8")
        sp = verbatim_spreads(corpus_files(root), [target_phrase])
        if sp.get(target_phrase) != 1:
            failures.append(
                f"verbatim_spreads: {sp.get(target_phrase)!r} session(s) pour une phrase "
                "presente UNE fois — la tokenisation OR en donnerait 4"
            )
        # Guillemet : le transcript le stocke ECHAPPE. Tester la seule forme brute
        # sous-compterait — le sens dangereux (une phrase banale paraitrait rare).
        quoted = 'Le message "Message ajouté au dashboard" reste refuse statiquement par la sonde.'
        (root / "c-quote.jsonl").write_text(json.dumps({"text": quoted}), encoding="utf-8")
        sp_q = verbatim_spreads(corpus_files(root), [quoted])
        if sp_q.get(quoted) != 1:
            failures.append(f"verbatim_spreads: guillemet echappe non reconnu ({sp_q.get(quoted)!r})")
        # Fail-closed : corpus ABSENT et corpus VIDE levent, jamais un spread de 0.
        try:
            corpus_files(root / "absent")
            failures.append("corpus_files: un corpus ABSENT a ete accepte (fail-open)")
        except RuntimeError:
            pass
        with tempfile.TemporaryDirectory() as td_empty:
            try:
                corpus_files(Path(td_empty))
                failures.append("corpus_files: un corpus VIDE a ete accepte (fail-open)")
            except RuntimeError:
                pass

        # UNE ENTREE = UNE SESSION (review ai-01 #4412, point 3) : le transcript
        # de sous-agent vit sous `<session>/subagents/` et appartient a la session
        # parente. Compte comme une session, il ferait 2 pour la cible elle-meme
        # et l'arme « spread <= 1 » refuserait une phrase qui n'existe qu'ici.
        session_dir = root / "d-session"
        (session_dir / "subagents").mkdir(parents=True, exist_ok=True)
        sub_phrase = (
            "Le transcript d'un sous-agent rattache sa mesure a la session parente, "
            "jamais a un fichier separe."
        )
        (root / "d-session.jsonl").write_text(
            json.dumps({"text": sub_phrase}), encoding="utf-8")
        (session_dir / "subagents" / "agent-1.jsonl").write_text(
            json.dumps({"text": sub_phrase}), encoding="utf-8")
        files_after = corpus_files(root)
        if any(SUBAGENT_DIR in {seg.lower() for seg in p.parts[:-1]} for p in files_after):
            failures.append("corpus_files: un transcript de sous-agent est servi comme session")
        sp_sub = verbatim_spreads(files_after, [sub_phrase])
        # La phrase vit dans 2 FICHIERS (tete + sous-agent) mais UNE seule session :
        # le compte doit rester 1.
        if sp_sub.get(sub_phrase) != 1:
            failures.append(
                f"verbatim_spreads: {sp_sub.get(sub_phrase)!r} session(s) alors que le "
                "sous-agent compte dans la session parente (attendu 1)"
            )

        # REPETITION DANS UNE MEME SESSION (review ai-01 r4, blocage 1) : une
        # session qui se cite elle-meme (reponse + echo d'outil) porte la meme
        # phrase sur PLUSIEURS lignes. Le compte est par SESSION : 1, pas le
        # nombre de lignes. Le mutant « increment par ligne » fait ECHOUER ce
        # test (il rendrait 3).
        rep_phrase = (
            'Le transcript se cite "lui-meme" et repete la phrase mesuree dans la '
            "meme session."
        )
        (root / "f-repeat.jsonl").write_text(
            "\n".join([
                json.dumps({"text": rep_phrase}),
                json.dumps({"text": "une ligne sans rapport pour la mesure"}),
                json.dumps({"text": rep_phrase}),
                json.dumps({"text": rep_phrase}),
            ]) + "\n",
            encoding="utf-8",
        )
        sp_rep = verbatim_spreads(corpus_files(root), [rep_phrase])
        if sp_rep.get(rep_phrase) != 1:
            failures.append(
                f"verbatim_spreads: {sp_rep.get(rep_phrase)!r} session(s) pour une phrase "
                "repetee dans UNE SEULE session (attendu 1) — le compte est par session, "
                "pas par ligne"
            )
        # La meme phrase dans DEUX sessions distinctes reste SATUREE (>= 2) : le
        # correctif ne doit pas sous-compter au point d'accepter une phrase banale.
        two_phrase = "La meme phrase dans deux sessions distinctes doit rester refusee."
        (root / "g-two-1.jsonl").write_text(json.dumps({"text": two_phrase}), encoding="utf-8")
        (root / "g-two-2.jsonl").write_text(json.dumps({"text": two_phrase}), encoding="utf-8")
        sp_two = verbatim_spreads(corpus_files(root), [two_phrase])
        if (sp_two.get(two_phrase) or 0) < 2:
            failures.append(
                f"verbatim_spreads: {sp_two.get(two_phrase)!r} session(s) pour une phrase "
                "presente dans DEUX sessions distinctes (attendu >= 2)"
            )
        # Des CANDIDATES REPETEES ne changent pas la mesure.
        sp_dup = verbatim_spreads(corpus_files(root), [rep_phrase, rep_phrase, rep_phrase])
        if sp_dup.get(rep_phrase) != 1:
            failures.append(
                f"verbatim_spreads: {sp_dup.get(rep_phrase)!r} session(s) avec des candidates "
                "REPETEES (attendu 1, identique a la liste sans doublon)"
            )
        # ... et la deduplication RESTAURE l'arret precoce : une liste de
        # candidates dupliquee reste UNE candidate, donc la saturation
        # s'atteint et le scan s'arrete la. Sans deduplication, la condition
        # d'arret ne peut jamais etre vraie (une seule phrase ne peut pas
        # saturer trois entrees) et le scan parcourt le corpus en entier —
        # ici jusqu'au fichier hors bornes, qui declenche alors INSTRUMENT.
        early1 = root / "h-early-1.jsonl"
        early2 = root / "h-early-2.jsonl"
        early1.write_text(json.dumps({"text": two_phrase}), encoding="utf-8")
        early2.write_text(json.dumps({"text": two_phrase}), encoding="utf-8")
        big_early = root / "i-big-early.jsonl"
        big_early.write_text(json.dumps({"text": two_phrase * 200}), encoding="utf-8")
        saved_cap_early = globals()["MAX_CORPUS_FILE_BYTES"]
        try:
            globals()["MAX_CORPUS_FILE_BYTES"] = 1000
            sp_early = verbatim_spreads(
                [early1, early2, big_early], [two_phrase, two_phrase, two_phrase])
            if (sp_early.get(two_phrase) or 0) != 2:
                failures.append(
                    f"verbatim_spreads: {sp_early.get(two_phrase)!r} session(s) pour une phrase "
                    "saturee en 2 sessions (attendu 2)"
                )
        except InstrumentLimit as exc:
            failures.append(
                "verbatim_spreads: le scan ne s'est pas arrete apres saturation (fichier hors "
                f"bornes lu) — la deduplication des candidates ne fonctionne pas : {exc}"
            )
        finally:
            globals()["MAX_CORPUS_FILE_BYTES"] = saved_cap_early
        # ELIGIBILITE DU CORPUS (review ai-01 r4, observation) : un `.jsonl` hors
        # layout de session (`memory/…`) n'est pas une session. Aucun fichier
        # n'est supprime — il est seulement ecarte.
        mem_dir = root / "memory"
        mem_dir.mkdir(parents=True, exist_ok=True)
        mem_phrase = "Un journal utilisateur n'est pas une session et ne compte pas."
        (mem_dir / "user-words-journal.jsonl").write_text(
            json.dumps({"text": mem_phrase}), encoding="utf-8")
        sp_mem = verbatim_spreads(corpus_files(root), [mem_phrase])
        if (sp_mem.get(mem_phrase) or 0) != 0:
            failures.append(
                "corpus_files: un fichier hors layout de session est servi comme session "
                f"({sp_mem.get(mem_phrase)!r} session(s), attendu 0)"
            )

        # PLAFONDS DE LECTURE (review ai-01 #4412, point 2) : un fichier hors
        # bornes n'est ni saute ni rendu 0 — il leve InstrumentLimit, donc aucun
        # PASS ne peut sortir d'un corpus partiellement lu.
        big = root / "e-big.jsonl"
        big.write_text(json.dumps({"text": target_phrase}), encoding="utf-8")
        saved_file_cap = globals()["MAX_CORPUS_FILE_BYTES"]
        saved_line_cap = globals()["MAX_CORPUS_LINE_BYTES"]
        try:
            globals()["MAX_CORPUS_FILE_BYTES"] = 8
            try:
                verbatim_spreads([big], [target_phrase])
                failures.append("verbatim_spreads: un fichier hors plafond a ete ignore (faux PASS)")
            except InstrumentLimit as exc:
                if "plafond fichier" not in str(exc):
                    failures.append(f"verbatim_spreads: plafond fichier mal nomme: {exc}")
            globals()["MAX_CORPUS_FILE_BYTES"] = saved_file_cap
            globals()["MAX_CORPUS_LINE_BYTES"] = 8
            try:
                verbatim_spreads([big], [target_phrase])
                failures.append("verbatim_spreads: une LIGNE hors plafond a ete ignoree (faux PASS)")
            except InstrumentLimit as exc:
                if "plafond ligne" not in str(exc):
                    failures.append(f"verbatim_spreads: plafond ligne mal nomme: {exc}")
        finally:
            globals()["MAX_CORPUS_FILE_BYTES"] = saved_file_cap
            globals()["MAX_CORPUS_LINE_BYTES"] = saved_line_cap
        # ... et le meme corpus redevient mesurable une fois les bornes retablies.
        if verbatim_spreads([big], [target_phrase]).get(target_phrase) != 1:
            failures.append("verbatim_spreads: lecture cassee apres restauration des plafonds")
    # Toutes les lignes refusees STATIQUEMENT : le message doit nommer le refus
    # statique, pas un echec de rarete — 0 recherche consommee (ai-01 CHANGES
    # :547 : « 0 candidats a plus de 1 session(s) » etait trompeur).
    try:
        pick_rare_phrase(
            "Message ajouté au dashboard 'workspace-roo-extensions' (id: msg-x-0001) avec 2 tags INFO",
            lambda p: 0,
        )
        failures.append("pick_rare_phrase: une sortie generique unique a ete retenue")
    except RuntimeError as exc:
        if "filtrage statique" not in str(exc):
            failures.append(f"pick_rare_phrase: zero-candidat mal nomme: {exc}")

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
                # Forme REELLE rendue par le serveur apres ms#1560 : Markdown pour
                # l'humain + bloc JSON embarque pour les sondes. 0 chunk indexe avec
                # une RAISON — exactement la reponse qui a fait echouer la sonde en
                # production chez ai-01 (28/10). Elle doit etre un SUCCES ici, et la
                # phase doit continuer vers verify.
                return "\n".join([
                    "# Indexation sémantique terminée",
                    "",
                    "**Tâche:** claude-x--u1",
                    "**Source:** claude-code",
                    "**Chemin:** /tmp/projects/claude-x--u1.jsonl",
                    "**Chunks indexés:** 0",
                    "**Raison:** tout était déjà indexé pour cette tâche (dédup) : 30/30 sous-chunk(s) écarté(s) avant embedding",
                    "**Chunks extraits:** 12",
                    "**Sous-chunks construits:** 30",
                    "**Sous-chunks dédupliqués:** 30",
                    "",
                    "```json",
                    json.dumps({
                        "success": True,
                        "task_id": "claude-x--u1",
                        "source": "claude-code",
                        "chunksExtracted": 12,
                        "subChunksBuilt": 30,
                        "dedupSkipped": 30,
                        "chunksIndexed": 0,
                        "missingVectors": 0,
                        "reason": "tout était déjà indexé pour cette tâche (dédup) : 30/30",
                    }, ensure_ascii=False, indent=2),
                    "```",
                    "[⏱ roosync_indexing 471ms]",
                ])
            if args.get("action") == "view":
                # Forme REELLE du view summary : prose sous prefixe `    | `,
                # lignes renderer et footer APRES elle (capture de forme,
                # view-conversation-tree.ts:1245/1249 + engine.ts:234 — r3).
                # Puis DEUX lignes tardives generiques (file 20261028i) : le
                # succes standard d'un append de dashboard (refus STATIQUE) et
                # un en-tete de boite (refus par RARETE mesuree) — dans cet
                # ordre, le scan depuis la fin les rencontre AVANT la prose.
                return "\n".join([
                    "==== session claude-x--u1 ====",
                    "▶️ Task: claude-x--u1 (3 messages)",
                    "  [user]:",
                    "      | Le relais dashboards PG-only exige que chaque siege pose sa cle avant le jalon du 27 octobre.",
                    "  [assistant]:",
                    "      | Verification faite sur les 17 marqueurs PG ce matin, aucun repli observe sur la fenetre de 24 h.",
                    "  [\U0001F6E0️ mcp__roo-state-manager__roosync_dashboard] → success (09:44:11)",
                    "• Taille totale: 19845 chars, Limite: 30000, Surplus: 0 (3 task(s))",
                    "      | Message ajouté au dashboard 'workspace-roo-extensions' [split en 2 parts]",
                    "      | Total : 140 messages, 2 non lus, 138 lus — aucune action requise de ce cycle present.",
                ])
            if name == "roosync_search":
                # Spread de rarete (file 20261028i). Le plafonnement releve en
                # vrai est represente : la ligne generique rend 1 ligne mais
                # totalFound=3 — compter les seules lignes la croirait rare.
                q = str(args.get("search_query") or "")
                if q.startswith("Total :"):
                    return json.dumps({
                        "results": [{"taskId": "claude-x--u1"}],
                        "totalFound": 3,
                    }, indent=2)
                return json.dumps({
                    "results": [{"taskId": "claude-x--u1"}],
                    "totalFound": 1,
                }, indent=2)
            raise AssertionError(f"appel inattendu: {name} {args}")

    fake = IndexFakeChild()
    idx_out: dict = {}
    # Corpus local du test (le scan lit des FICHIERS, il n'y a plus de recherche) :
    # la prose ciblee dans UNE session, la ligne « Total : … » dans TROIS autres.
    with tempfile.TemporaryDirectory() as td_corpus:
        corpus_root = Path(td_corpus)
        (corpus_root / "target.jsonl").write_text(
            json.dumps({"text": want_rendered}), encoding="utf-8")
        for i in range(3):
            (corpus_root / f"multi-{i}.jsonl").write_text(
                json.dumps({"text": late_multi}), encoding="utf-8")
        phase_index(fake, None, idx_out, corpus_root)
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
    # Rareté e2e (ai-01 CHANGES #4412) : le spread est mesuré par le SCAN LOCAL,
    # donc AUCUN `roosync_search` ne doit partir pour le compte — le mode texte
    # tokenise en OR et rend un compte plafonné, c'est le défaut mesuré. La ligne
    # « Total : … » (3 sessions du corpus de test) est écartée, la prose ciblee
    # (1 session) retenue, et la mesure est rapportée dans `rarity`.
    spread_calls = [a for n, a in fake.calls if n == "roosync_search"]
    if spread_calls:
        failures.append(
            f"phase_index: {len(spread_calls)} appel(s) roosync_search pour le spread "
            "— la rareté doit être un scan VERBATIM local"
        )
    rarity = idx_out.get("rarity") or {}
    if rarity.get("spread") != 1:
        failures.append(f"phase_index: rarity={rarity!r} (spread attendu 1)")
    if rarity.get("corpus_sessions") != 4:
        failures.append(
            f"phase_index: rarity={rarity!r} (4 SESSIONS attendues dans le corpus de test — "
            "unite de compte depuis l'exclusion des sous-agents, non lus)"
        )
    if idx_out.get("index") is None or (idx_out.get("index") or {}).get("success") is not True:
        failures.append(f"phase_index: index={idx_out.get('index')!r}")
    # Un succes a 0 chunk n'est PAS un echec : il doit avoir ete accepte, et la phase
    # doit avoir CONTINUE jusqu'a extraire la phrase (assertion ci-dessus). Le champ
    # normalise `chunks_indexed` et la raison sont ce que la sonde rapporte.
    ix = idx_out.get("index") or {}
    if ix.get("form") != "json":
        failures.append(f"phase_index: forme d'index={ix.get('form')!r} (attendu 'json')")
    if ix.get("chunks_indexed") != 0:
        failures.append(f"phase_index: chunks_indexed={ix.get('chunks_indexed')!r} (attendu 0)")
    if not ix.get("reason"):
        failures.append("phase_index: raison d'indexation absente du JSON embarque")
    index_args = [a for n, a in fake.calls if n == "roosync_indexing"]
    if not index_args:
        failures.append("phase_index: aucun appel roosync_indexing")
    elif index_args[0].get("queued") is not False:
        failures.append(f"phase_index: index queued={index_args[0].get('queued')!r} (attendu False — #4352 g3)")

    # parse_index_result : les DEUX formes de succes, et le refus de l'echec.
    # Le Markdown SEUL est ce qu'un serveur anterieur a ms#1560 rendait — la forme
    # qui a fait echouer la sonde en production chez ai-01 le 28/10.
    legacy_markdown = "\n".join([
        "# Indexation sémantique terminée",
        "",
        "**Tâche:** claude-D--roo-extensions--claude-worktrees-wt-4394-abc",
        "**Source:** claude-code",
        "**Chunks indexés:** 0",
        "",
        "**Variables d'env:**",
        "- EMBEDDING_API_KEY: SET",
        "- QDRANT_URL: http://qdrant:6333",
        "[⏱ roosync_indexing 471ms]",
    ])
    legacy = parse_index_result(legacy_markdown)
    if not legacy or legacy.get("form") != "markdown" or legacy.get("success") is not True:
        failures.append(f"parse_index_result: Markdown seul non accepte -> {legacy!r}")
    elif legacy.get("chunks_indexed") != 0:
        failures.append(f"parse_index_result: chunks_indexed={legacy.get('chunks_indexed')!r}")

    if parse_index_result("# Erreur d'indexation\n\n**Tâche:** x\n**Erreur:** boom") is not None:
        failures.append("parse_index_result: une ERREUR a ete lue comme un succes")

    if parse_index_result("") is not None:
        failures.append("parse_index_result: une reponse vide a ete lue comme un succes")

    # Un JSON qui se declare en ECHEC ne doit pas passer : sans ce cas, retirer la
    # garde `is True` du chemin JSON laisserait le selftest vert (mutant survivant).
    if parse_index_result(json.dumps({"success": False, "error": "boom"})) is not None:
        failures.append("parse_index_result: un JSON success=false a ete lu comme un succes")

    # PRECEDENCE du JSON embarque (file 20261028i, suivi 1) : un success:false
    # en JSON doit PRIMER sur l'en-tete Markdown « terminée » qui l'entoure.
    # Cas aujourd'hui injoignable cote serveur — le rendant impossible ici, la
    # sonde ne le decouvrira pas en production. Sans la sortie anticipee, la
    # branche Markdown lit ce melange comme un succes.
    mixed = "\n".join([
        "# Indexation sémantique terminée",
        "",
        "**Tâche:** claude-x--u1",
        "**Chunks indexés:** 7",
        "",
        "```json",
        json.dumps({"success": False, "error": "embeddings en echec partiel"}),
        "```",
    ])
    if parse_index_result(mixed) is not None:
        failures.append("parse_index_result: un success:false JSON n'a pas prime sur l'en-tete Markdown")
    # Et le melange INVERSE reste un succes : en-tete Markdown + JSON success:true.
    mixed_ok = "\n".join([
        "# Indexation sémantique terminée",
        "**Chunks indexés:** 7",
        "```json",
        json.dumps({"success": True, "chunksIndexed": 7, "reason": "7 point(s) écrit(s)"}),
        "```",
    ])
    ok_parsed = parse_index_result(mixed_ok)
    if not ok_parsed or ok_parsed.get("form") != "json" or ok_parsed.get("chunks_indexed") != 7:
        failures.append(f"parse_index_result: Markdown + JSON success=true non accepte -> {ok_parsed!r}")
    # ...et un JSON embarque SANS clef `success` ne fait PAS foi : c'est du
    # contenu cite (apercu de resultat d'outil), pas le verdict d'indexation.
    # Sans cette borne, « le JSON prime » deviendrait « n'importe quel JSON
    # prime » et un succes Markdown portant un apercu JSON serait lu en echec.
    mixed_foreign = "\n".join([
        "# Indexation sémantique terminée",
        "**Chunks indexés:** 5",
        "```json",
        json.dumps({"action": "append", "written": True}),
        "```",
    ])
    foreign_parsed = parse_index_result(mixed_foreign)
    if not foreign_parsed or foreign_parsed.get("form") != "markdown" or foreign_parsed.get("chunks_indexed") != 5:
        failures.append(
            "parse_index_result: un JSON embarque sans clef success a fait foi sur l'en-tete Markdown "
            f"-> {foreign_parsed!r}")

    json_only = parse_index_result(json.dumps({"success": True, "points": 42}))
    if not json_only or json_only.get("form") != "json":
        failures.append(f"parse_index_result: forme JSON historique non acceptee -> {json_only!r}")

    # Echec TOTAL de la phase : le rapport doit detailler CHAQUE essai, pas
    # seulement le dernier. « 3 candidats en echec » sans le detail ne dit pas si
    # c'est une panne d'instrument ou trois sessions non indexables depuis ce siege.
    class FailFakeChild(IndexFakeChild):
        def call_tool(self, name, args, timeout_s):
            if name == "roosync_indexing":
                self.calls.append((name, args))
                return "# Erreur d'indexation\n\n**Tâche:** claude-x--u1\n**Erreur:** boom index"
            return super().call_tool(name, args, timeout_s)

    # Corpus explicite : sur un runner CI (ou tout siege vierge), le defaut
    # LOCAL_CORPUS_DEFAULT (~/.claude/projects) n'existe pas et corpus_files
    # leverait AVANT la boucle — l'echec d'essai teste ici ne serait jamais
    # atteint. Le selftest restait vert sur les sieges pourvus d'un corpus et
    # rouge ailleurs : dependance au siege revelee par le branchage CI du 29/10.
    with tempfile.TemporaryDirectory() as td_fail:
        fail_root = Path(td_fail)
        (fail_root / "session.jsonl").write_text("{}", encoding="utf-8")
        try:
            phase_index(FailFakeChild(), None, {}, fail_root)
            failures.append("phase_index: un echec d'indexation n'a pas leve")
        except RuntimeError as exc:
            if "essais:" not in str(exc):
                failures.append(f"phase_index: echec sans detail des essais -> {str(exc)[:120]!r}")
            # …et le detail doit porter la RAISON, pas l'en-tete tronque du serveur.
            if "boom index" not in str(exc):
                failures.append(f"phase_index: detail sans la raison de l'echec -> {str(exc)[:160]!r}")

    # InstrumentLimit = ABORT GLOBAL, pas un echec d'essai (mandat ai-01 29/10,
    # #4352). Une borne de lecture (fichier/ligne hors plafond) decrit le CORPUS,
    # pas le candidat : le bug etait que InstrumentLimit herite de RuntimeError,
    # donc le `except RuntimeError` par candidat l'avalait -> le candidat suivant
    # re-payait UN APPEL D'INDEX et UN SCAN COMPLET du corpus pour le meme
    # verdict. Assert : InstrumentLimit PROPAGEE hors de phase_index, UN seul
    # scan, AUCUN appel d'index suivant.
    class TwoCandidatesChild(IndexFakeChild):
        """Deux candidats indexables : sans l'abort, le 2e serait tente."""

        def call_tool(self, name, args, timeout_s):
            if args.get("action") == "list":
                now = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime())

                def conv(tid):
                    return {"taskId": tid, "source": "claude",
                            "metadata": {"totalSize": 50000, "createdAt": now,
                                         "messageCount": 12,
                                         "machineId": socket.gethostname()}}

                return json.dumps({"conversations": [
                    conv("claude-x--u1"), conv("claude-x--u3")]}, indent=2)
            return super().call_tool(name, args, timeout_s)

    limit_child = TwoCandidatesChild()
    real_spreads = verbatim_spreads
    scan_calls: list[list[str]] = []

    def counting_spreads(files, phrases):
        scan_calls.append(list(phrases))
        return real_spreads(files, phrases)

    globals()["verbatim_spreads"] = counting_spreads
    saved_cap_abort = globals()["MAX_CORPUS_FILE_BYTES"]
    try:
        with tempfile.TemporaryDirectory() as td_lim:
            lim_root = Path(td_lim)
            (lim_root / "big.jsonl").write_text(json.dumps({"text": "x" * 50}),
                                                encoding="utf-8")
            globals()["MAX_CORPUS_FILE_BYTES"] = 8
            try:
                phase_index(limit_child, None, {}, lim_root)
                failures.append(
                    "phase_index: InstrumentLimit avalee (aucune levee) — abort global attendu")
            except InstrumentLimit:
                pass  # comportement attendu : propagee, pas comptee comme un essai
            except RuntimeError as exc:
                failures.append(
                    "phase_index: InstrumentLimit traitee comme echec d'essai "
                    f"(RuntimeError: {str(exc)[:100]!r}) — abort global attendu")
            index_after = [a for n, a in limit_child.calls if n == "roosync_indexing"]
            if len(index_after) != 1:
                failures.append(
                    f"phase_index: {len(index_after)} appel(s) roosync_indexing autour de "
                    "l'InstrumentLimit (attendu 1 : AUCUN appel d'index apres l'abort)")
            if len(scan_calls) != 1:
                failures.append(
                    f"phase_index: {len(scan_calls)} scan(s) du corpus (attendu 1 : "
                    "la borne decrit le corpus, pas le candidat)")
    finally:
        globals()["verbatim_spreads"] = real_spreads
        globals()["MAX_CORPUS_FILE_BYTES"] = saved_cap_abort

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
          "retire + lignes renderer exclues, sorties d'outil generiques refusees + "
          "rarete VERBATIM mesuree (scan local, 1 session ; OR tokenise et corpus vide refuses), "
          "sous-agent compte dans SA session (1, pas 2), repetition dans UNE session "
          "comptee UNE fois (pas par ligne), deux sessions distinctes = sature, "
          "candidates repetees sans effet + arret precoce apres saturation, "
          "fichier hors layout de session ecarte du corpus, "
          "plafonds de lecture fichier/ligne => "
          "INSTRUMENT (jamais un faux PASS) ET abort global en phase d'index "
          "(propagee, 1 seul scan, aucun appel d'index suivant), compte sature marque "
          "« ≥ » et non presente comme une mesure, "
          "vocabulaire view, args du view + list "
          "source=all, createdAt non-texte ecarte, parsing pretty-printe, rang top-5, "
          "repli textuel refuse (drapeau + mode seul), timeout enfant muet, ligne de "
          "log ignoree, index queued=false, succes Markdown ET JSON embarque acceptes "
          "(0 chunk n'est pas un echec), erreur d'indexation refusee, JSON embarque "
          "fait foi (success:false prime sur l'en-tete Markdown), isError au "
          "niveau resultat)")
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
    ap.add_argument("--corpus-dir", type=Path, default=LOCAL_CORPUS_DEFAULT,
                    help="corpus local des transcripts ou la rarete de la phrase est mesuree VERBATIM "
                         "(defaut : ~/.claude/projects)")
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
            phase_index(child, args.task_id, out, args.corpus_dir)
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
            if out.get("index"):
                idx = out["index"]
                detail = f"[index] chunks_indexed={idx.get('chunks_indexed')} form={idx.get('form')}"
                if idx.get("reason"):
                    detail += f" — {idx['reason']}"
                print(detail)
                if idx.get("chunks_indexed") == 0:
                    # 0 n'est PAS un echec (mesure ai-01 28/10) : soit la tache etait
                    # deja indexee (dedup ms#1557), soit l'extraction n'a rien rendu.
                    # La phase verify tranche — c'est la recherche qui prouve.
                    print("[index] 0 chunk — la phase verify tranche (recherche, pas compteur)")
            if out.get("phrase"):
                print(f"[phrase] {out['phrase']}")
            if out.get("rarity"):
                r = out["rarity"]
                print(f"[rarity] spread={r['spread']} sur {r.get('corpus_sessions', r.get('corpus_files'))} session(s) locales")
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
    except MemoryError as exc:
        # INSTRUMENT, jamais FAIL (review ai-01 #4412, point 2). `MemoryError`
        # n'herite pas de RuntimeError : il traversait le handler, Python sortait
        # avec le code 1, et un wrapper lisait « 1 » comme un FAIL de fond — un
        # corpus trop gros devenait « la recherche a echoue ». La mesure n'a pas
        # eu lieu : c'est exit 2.
        out["error"] = (
            f"memoire insuffisante pendant la mesure ({exc or 'MemoryError'}) — "
            "corpus trop volumineux pour ce siege : la sonde n'a pas conclu"
        )
        out["verdict"] = "INSTRUMENT_ERROR"
        if args.json:
            print(json.dumps(out, ensure_ascii=False, indent=2, default=str))
        else:
            print(f"[ERROR] {out['error']}")
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

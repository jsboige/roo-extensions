#!/usr/bin/env python3
"""check-degraded-escalations.py — la sonnerie d'une escalade « environnement degrade » (#4517).

Le 2026-11-01 au 2026-11-03, une lane a contourne un MCP qu'elle croyait mort
pendant deux jours, et l'a presente comme un travail normal. Le MCP repondait en
1,18 s (sonde #4518) : la cause n'etait pas la panne, c'etait l'absence
d'instrument. La regle « reparer, jamais contourner » existait deja ; elle n'a
pas mordu parce que rien ne bornait le temps qu'une lane peut passer dans un
environnement degrade **en silence**.

Cet organe porte l'echeance a la place de la memoire de l'agent qui a poste
l'escalade. Il lit les dashboards, trouve les escalades `[DEGRADED]`, calcule
pour chacune une echeance (2 cycles par defaut), et dit si la sonnerie est due :

    [DEGRADED] poste a T  ->  echeance T + cycles * cycle_hours
    [REPAIRED] de la MEME lane apres T  ->  escalade close
    echeance passee sans [REPAIRED]     ->  SONNERIE DUE

Un `[DONE]` ne ferme jamais une escalade : c'est exactement la « sortie degradee
consacree » que le mandat interdit. Seul `[REPAIRED]` ferme.

Codes de sortie (un automate peut lire le code seul) :
    0   aucune escalade `[DEGRADED]` dans la fenetre lue
    3   escalade(s) ouverte(s), aucune echeance depassee  (mecanisme exerce, rien a sonner)
    2   au moins une echeance depassee sans `[REPAIRED]`  -> SONNERIE DUE
    1   erreur d'instrument (dashboards illisibles, miroir gele, ou --ring
        demande et non poste) ; AUSSI la mesure DEGRADEE : miroir lu comme
        source alors que PG etait configure (review #4519 point c)

Sources, dans l'ordre (review #4519 point c) :
    1. --dashboard-file    rejeu d'un fichier precis (forensic) — pas de plafond
    2. STORE PG            meme transport que la sonnerie (MCP_PROXY_BEARER),
                           fenetre des 200 dernieres entrees par dashboard
    3. miroir G:           repli seulement ; si PG etait configure, la mesure est
                           DEGRADEE (sortie 1) ; plafond de fraicheur : la plus
                           recente entree doit dater de moins d'un cycle

Usage :
    python check-degraded-escalations.py                       # lit le store ( bearer requis )
    python check-degraded-escalations.py --cycles 2 --cycle-hours 4
    python check-degraded-escalations.py --json
    python check-degraded-escalations.py --ring                # poste ASK-USER sur le dashboard global
    python check-degraded-escalations.py --dashboard-file <copie.md>   # rejeu hors store
    python check-degraded-escalations.py --selftest

Plafond dit explicitement : l'organe ne voit que les escalades **postees**. Une
lane qui n'escalade pas reste invisible — c'est pourquoi le mandat exige
l'escalade immediate, et pourquoi la sonde de siege (#4518) existe : elle rend
le degre de degradation visible sans attendre la bonne volonte de la lane.
La sonnerie, elle, n'est pas prouvee ici : l'append est best-effort, et un
`--ring` qui echoue sort en 1 plutot que de simuler un succes.
"""

import argparse
import hashlib
import importlib.util
import json
import os
import re
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEFAULT_SHARED = Path("G:/Mon Drive/Synchronisation/RooSync/.shared-state")
DEFAULT_CYCLES = 2
DEFAULT_CYCLE_HOURS = 4.0

# Entete d'un message intercom : `### [2026-11-03T12:51:09.673Z] myia-web1|roo-extensions`.
# Trois dieses + un horodatage ISO : la section Status utilise deux dieses et ne
# peut pas matcher.
ENTRY_RE = re.compile(r"^### \[(?P<ts>\d{4}-\d{2}-\d{2}T[^\]]+)\] (?P<lane>\S+)\s*$", re.M)
# Ligne `[tags: ...]` : ancree en debut de ligne, la fin n'est PAS exigee
# (review ai-01 04/11 — `\s*$` laissait passer une ligne suivie d'un
# commentaire ou d'un espace, et le tag disparaissait en silence).
TAGS_RE = re.compile(r"^\[tags:\s*(?P<tags>[^\]]*)\]", re.M)
# Metadonnees de tete qu'un dashboard serialise place AVANT le corps
# (`[msg: id]`, `[reply-to: ...]`, `[ack: ...]`, `[tags: ...]`).
META_LINE_RE = re.compile(r"^\[(?:msg|reply-to|ack|tags):[^\]]*\]$")
# Entete « proche » : seuls les crochets HORODATES comptent (review ai-01 04/11).
NEAR_HEADER_RE = re.compile(r"^\s{0,3}#{1,6}\s*\[\d{4}-\d{2}-\d{2}T[^\]\n]*\]\s*\S+\s*$")
# Frontiere de mot obligatoire : `[DEGRADED-FIXED]` n'est pas `[DEGRADED]`.
DEGRADED_RE = re.compile(r"\[DEGRADED\](?![A-Za-z0-9_-])")
REPAIRED_RE = re.compile(r"\[REPAIRED\](?![A-Za-z0-9_-])")
# Les deux tokens, pour l'assainissement du texte de la sonnerie (review
# #4519 point b : la sonnerie ne doit porter AUCUN token de declaration --
# sinon son propre post se lit comme la reparation de l'escalade qu'elle sonne).
DECLARATION_TOKEN_RE = re.compile(r"\[(DEGRADED|REPAIRED)\](?![A-Za-z0-9_-])")
# Tag porte par la sonnerie elle-meme (tags ASK-USER + DEGRADED-ESCALATION) :
# une entree qui le porte n'est jamais une declaration ni une reparation.
RING_TAG = "degraded-escalation"


def parse_ts(text):
    """ISO-8601 -> datetime UTC. Tolere le suffixe `Z` et les fractions."""
    cleaned = text.strip().replace("Z", "+00:00")
    stamp = datetime.fromisoformat(cleaned)
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=timezone.utc)
    return stamp.astimezone(timezone.utc)


def tags_from_text(text):
    """Tags portes par une ligne `[tags: ...]` du CORPS, en minuscules.

    Une seule definition, partagee par les deux chemins de lecture (miroir et
    store JSON). C'est l'invariant qui compte, et il est structurel : le MEME
    corps doit rendre les MEMES tags quelle que soit la surface qui l'a servi.
    Deux motifs divergents rouvriraient exactement le trou de SHOULD-2 -- une
    forme declaree sur un chemin et muette sur l'autre (review ai-01 04/11).
    """
    match = TAGS_RE.search(text or "")
    if not match:
        return set()
    return {t.strip().lower() for t in match.group("tags").split(",") if t.strip()}


def parse_entries(text):
    """Decoupe un dashboard en messages intercom, dans l'ordre du fichier.

    Chaque entree : {ts, lane, tags:set, body}. Un fichier sans aucun entete
    intercom rend une liste vide — l'appelant le signale comme une lecture
    sans matiere, jamais comme un « rien a signaler » silencieux.
    """
    entries = []
    cur = None
    for line in text.splitlines():
        match = ENTRY_RE.match(line)
        if match:
            if cur is not None:
                entries.append(cur)
            cur = {"ts": parse_ts(match.group("ts")),
                   "lane": match.group("lane"),
                   "lines": []}
            continue
        if cur is not None:
            cur["lines"].append(line)
    if cur is not None:
        entries.append(cur)

    for entry in entries:
        entry["body"] = "\n".join(entry.pop("lines"))
        entry["tags"] = tags_from_text(entry["body"])
    return entries


def declaration_text(body):
    """Corps prive des lignes de metadonnees de tete et des lignes vides.

    Le miroir serialise `[msg: id]` AVANT le corps (`dashboard.ts:2899`) : sans
    ce depouillement, une declaration posee en premier token (`[DEGRADED] mcp
    muet`) n'etait jamais vue par le chemin miroir (review ai-01 04/11, cas
    symetrique du MUST — meme cause, deux surfaces).
    """
    lines = body.splitlines()
    index = 0
    while index < len(lines):
        stripped = lines[index].strip()
        if stripped and not META_LINE_RE.match(stripped):
            break
        index += 1
    return "\n".join(lines[index:])


def is_declaration(entry, token_name, token_re):
    """Une DECLARATION, jamais une mention (review #4519 point a).

    Deux formes acceptees, toutes deux deliberées :
      - la ligne `[tags: ... token_name ...]` que les posts de production
        portent (TAGS_RE la parse deja) ;
      - le token en PREMIER token du corps (`[DEGRADED] mcp muet`) — premier
        token du corps UTILE, metadonnees de tete exclues.
    Un post qui CITE le token en plein prose -- la review qui le cite, le
    `[DONE]` qui l'explique -- n'est pas une declaration : detecter la mention
    ouvrait des escalades fantomes qui sonnaient le user pour rien (deux posts
    reels du 03/11, fixtures du selftest).
    """
    if RING_TAG in entry["tags"]:
        return False  # notre propre sonnerie n'est ni declaration ni reparation
    if token_name in entry["tags"]:
        return True
    return bool(token_re.match(declaration_text(entry["body"]).lstrip()))


def is_degraded(entry):
    return is_declaration(entry, "degraded", DEGRADED_RE)


def is_repaired(entry):
    return is_declaration(entry, "repaired", REPAIRED_RE)


def collect_escalations(entries, now, cycles=DEFAULT_CYCLES,
                        cycle_hours=DEFAULT_CYCLE_HOURS, excerpt_chars=160):
    """Liste les escalades et leur etat a `now`.

    Resolution : la PREMIERE entree de la meme lane, posterieure a l'escalade
    et portant `[REPAIRED]`. Une lane qui se declare reparee ferme toutes ses
    escalades anterieures — c'est une declaration de lane, pas d'incident, et
    exiger un identifiant d'incident rendrait le mecanisme inutilisable pour
    l'agent qui poste sous pression.
    """
    ordered = sorted(entries, key=lambda e: e["ts"])
    window = timedelta(hours=cycles * cycle_hours)
    found = []
    for index, entry in enumerate(ordered):
        if not is_degraded(entry):
            continue
        repaired_at = None
        for later in ordered[index + 1:]:
            if later["lane"] == entry["lane"] and is_repaired(later):
                repaired_at = later["ts"]
                break
        deadline = entry["ts"] + window
        if repaired_at is not None:
            status = "repaired"
        elif now > deadline:
            status = "overdue"
        else:
            status = "waiting"
        body = DEGRADED_RE.sub(" ", entry["body"], count=1).strip().replace("\n", " ")
        found.append({
            "lane": entry["lane"],
            "posted": entry["ts"].isoformat().replace("+00:00", "Z"),
            "deadline": deadline.isoformat().replace("+00:00", "Z"),
            "status": status,
            "repaired_at": (repaired_at.isoformat().replace("+00:00", "Z")
                            if repaired_at else None),
            "excerpt": " ".join(body.split())[:excerpt_chars],
        })
    return found


def load_entries(paths):
    """(entries, errors). Un fichier illisible ne masque pas les autres."""
    entries = []
    errors = []
    for path in paths:
        try:
            entries.extend(parse_entries(Path(path).read_text(encoding="utf-8", errors="replace")))
        except OSError as exc:
            errors.append(f"{path}: {exc}")
    return entries, errors


def default_dashboard_files(dashboard_dir):
    """Tous les dashboards de premier niveau.

    Les copies de conflit DriveFS (`workspace-x (1).md`) sont exclues : elles
    dupliquent des escalades deja lues et feraient compter deux fois la meme
    echeance (#4439, meme famille que le piege des jumeaux).
    """
    root = Path(dashboard_dir)
    return sorted(p for p in root.glob("*.md")
                  if " (" not in p.name and p.name != "mcp-dashboard.md")


# Chargeur du store, injectable pour les tests (aucun reseau en CI) :
# un test qui substitue cette globale voit le repli miroir sans lever un client.
_store_loader = None


def type_from_key(key):
    """global | machine | workspace — la cle du dashboard porte son type."""
    if key == "global":
        return "global"
    if key.startswith("machine-"):
        return "machine"
    return "workspace"


def read_arguments_for_key(key, intercom_limit):
    """Arguments `read` pour la cle — AVEC l'identifiant (review Hermes 04/11,
    trouve en implementant les reserves) : un `read` type=workspace sans
    `workspace` renvoie le dashboard DU SIEGE, pas celui de la cle — N
    dashboards workspace auraient lu N fois le meme, dupliquant chaque
    escalade. La cle porte l'id : `workspace-<id>` / `machine-<id>`.

    `format: json` (review ai-01 04/11, MUST) : le markdown derive par
    `buildMarkdownOutput` ne porte pas les tags, donc une declaration faite
    par l'API canonique disparaissait. Le JSON porte `tags` — on demande la
    source, pas son rendu.
    """
    arguments = {"action": "read", "section": "intercom",
                 "intercomLimit": intercom_limit, "format": "json"}
    if key == "global":
        arguments["type"] = "global"
    elif key.startswith("machine-"):
        arguments["type"] = "machine"
        arguments["machine"] = key[len("machine-"):]
    elif key.startswith("workspace-"):
        arguments["type"] = "workspace"
        arguments["workspace"] = key[len("workspace-"):]
    else:
        # Cle sans prefix connu : traitee comme workspace nu, id = cle entiere.
        arguments["type"] = "workspace"
        arguments["workspace"] = key
    return arguments


def unrecognized_headers(text):
    """Lignes qui RESSEMBLENT a un entete intercom sans matcher ENTRY_RE
    (review Hermes 04/11, reserve 2) : un `#### [ts] lane` ou un `### [x] y`
    d'un client au format derive est aujourd'hui silencieusement invisible --
    ni entree, ni erreur. Une ligne proche mais non reconnue est signalee :
    le contrat « un dashboard illisible n'est pas un dashboard propre »
    couvre le parse autant que l'IO.

    Deux limites, mesurees :
      - le motif ne vise qu'un crochet HORODATE : le motif large attrapait
        `## [WAKE-CLAUDE] myia-po-2023`, forme legitime du dashboard
        (wake-claude-routing.md autorise le tag en header markdown) -- chaque
        dashboard portant un WAKE aurait ete signale (review ai-01 04/11) ;
      - un bloc de code cloture n'est pas un entete : un exemple de format
        cite dans une review ou une doc etait compte comme entree invisible
        (review ai-01 04/11, note non bloquante). Les DEUX caracteres de
        cloture existent en Markdown (``` et ~~~) et un bloc ne se clot que
        par son caractere OUVRANT, seul sur la ligne (CommonMark) : suivre un
        seul toggle laissait les blocs ~~~ scans (faux positif) et un ```
        cite DANS un bloc ~~~ desynchronisait le suivi -- tout ce qui
        suivait etait laisse en « dans le bloc » (faux negatif).
    """
    hits = []
    fence = None  # caractere du bloc ouvert ('`' ou '~') ; None = hors bloc
    for line in text.splitlines():
        stripped = line.strip()
        if fence is None:
            if stripped.startswith("```"):
                fence = "`"
                continue
            if stripped.startswith("~~~"):
                fence = "~"
                continue
            if NEAR_HEADER_RE.match(line) and not ENTRY_RE.match(line):
                hits.append(line.strip())
        elif stripped and set(stripped) == {fence}:
            fence = None  # cloture : meme caractere que l'ouverture, seul
    return hits


def entries_from_store_json(text):
    """Entrees depuis l'enveloppe JSON d'un `read` store, ou None.

    Review ai-01 04/11 (MUST) : le `read` PG en markdown passe par
    `buildMarkdownOutput` (`dashboard.ts:7380`), qui emet l'entete et le corps
    mais **aucune ligne `[tags: ...]`**. Une lane qui declare par l'API
    canonique -- `append(tags=["DEGRADED"])`, corps en prose -- etait donc
    invisible : `tags=[]`, `is_degraded=False`, exit 0, silence. Or c'est la
    forme que le harnais documente ; l'organe lisait le RENDU en croyant lire
    la source.

    Le JSON porte `data.intercom.messages[].tags` (`dashboard-schemas.ts:61`),
    deja tronque a `intercomLimit` par le serveur (`dashboard.ts:7573`), donc
    la fenetre lue est celle que la couverture verifie. On lit la source.

    Review ai-01 04/11 (SHOULD-2) : le champ `tags` NE SUFFIT PAS. `append`
    ne derive pas les tags du contenu (`dashboard.ts:8194`), or `README.md:226`
    documente la declaration « par la ligne `[tags: ... DEGRADED ...]` » ecrite
    DANS le corps. Servie par le store, cette forme n'a donc aucun tag dans son
    champ : avant ce correctif elle declarait par le chemin markdown et se
    taisait par le chemin JSON -- une declaration qui produit le silence, dans
    la famille meme que ce module existe pour fermer. Les tags du corps sont
    donc UNIS a ceux du champ, par la fonction qui sert aussi le miroir : le
    meme corps doit rendre le meme verdict sur les deux surfaces.

    Rend None si le texte n'est pas du JSON du tout (hote ancien, `format`
    ignore) : la, et seulement la, le repli markdown est legitime -- une sonde
    ne suppose pas que son interlocuteur a la version qu'elle lit.

    Review ai-01 04/11 (SHOULD-1) : toute autre forme levee est une ERREUR
    D'INSTRUMENT, pas un repli. Une enveloppe `{"success": false}` est ce que
    rend `handleRead` quand le store est inaccessible (`dashboard.ts:7542`),
    quand le dashboard n'existe pas (`:7573`) ou quand la section est invalide
    (`:7602`) -- sans `isError`. La traiter comme « pas du JSON » la faisait
    relire en markdown, qui n'y trouve aucune entree : exit 0, « aucune
    escalade », sur une lecture qui n'a jamais eu lieu.
    """
    try:
        payload = json.loads(text)
    except (TypeError, ValueError):
        return None  # pas du JSON : hote ancien, le repli markdown est du
    if not isinstance(payload, dict):
        raise ValueError("enveloppe JSON sans objet racine")
    if payload.get("success") is False:
        detail = payload.get("error") or "sans motif"
        raise ValueError(f"enveloppe en echec ({detail})")
    data = payload.get("data")
    intercom = data.get("intercom") if isinstance(data, dict) else None
    messages = intercom.get("messages") if isinstance(intercom, dict) else None
    if not isinstance(messages, list):
        raise ValueError("enveloppe sans data.intercom.messages[]")
    entries = []
    for message in messages:
        if not isinstance(message, dict):
            raise ValueError("message store non objet")
        author = message.get("author") or {}
        machine = author.get("machineId") or ""
        workspace = author.get("workspace") or ""
        lane = "|".join(part for part in (machine, workspace) if part)
        raw_tags = message.get("tags") or []
        if not isinstance(raw_tags, list):
            raise ValueError("champ tags non liste")
        stamp = message.get("timestamp")
        if not isinstance(stamp, str) or not stamp:
            # Un horodatage non-chaine levait un AttributeError qui echappait
            # au `except ValueError` de l'appelant (review ai-01 04/11, NIT) :
            # il sortait en trace, sans le message d'erreur d'instrument.
            raise ValueError(f"horodatage absent ou non-chaine ({stamp!r})")
        content = message.get("content") or ""
        if not isinstance(content, str):
            raise ValueError("corps de message non-chaine")
        entries.append({
            "ts": parse_ts(stamp),
            "lane": lane,
            "body": content,
            # Union : le champ (API canonique) ET le corps (forme documentee).
            "tags": ({t.strip().lower() for t in raw_tags
                      if isinstance(t, str) and t.strip()}
                     | tags_from_text(content)),
        })
    return entries


def tool_result_text(result):
    """Texte du contenu d'un resultat MCP, ou None si inutilisable."""
    if not isinstance(result, dict):
        return None
    content = result.get("content")
    if isinstance(content, list) and content and isinstance(content[0], dict):
        return content[0].get("text")
    return None


def store_keys_from_listing(result):
    """Cles de dashboards depuis un `action: list`, ou None (fail-closed :
    une liste illisible ne se sert jamais comme « zero dashboard »)."""
    text = tool_result_text(result)
    if text is None:
        return None
    try:
        payload = json.loads(text)
    except ValueError:
        return None
    if not isinstance(payload, dict) or payload.get("success") is False:
        return None
    dashboards = payload.get("dashboards")
    if not isinstance(dashboards, list):
        return None
    keys = [d.get("key") for d in dashboards
            if isinstance(d, dict) and d.get("key")]
    return keys or None


def load_entries_from_store(url, bearer, timeout=10.0, intercom_limit=200,
                            now=None, window_hours=None):
    """Dashboards servis par le STORE (PG), meme transport que la sonnerie
    (review #4519 point c : les dashboards sont servis par PG ; le miroir G:
    gele apres le cut #4131 donnerait un faux « tout va bien » confiant).

    Rend (entries, errors) — la meme signature que load_entries — ou None si
    le store est injoignable en entree (list illisible) : l'appelant decide
    alors du repli miroir, qui DEGRADE le verdict quand PG etait configure.

    Fenetre : les `intercom_limit` dernieres entrees PAR dashboard, et la
    couverture est VERIFIEE, pas supposee (review Hermes 04/11, reserve 1) :
    si `now` et `window_hours` sont donnes et que la plus ancienne entree lue
    d'un dashboard est PLUS RECENTE que le debut de fenetre, le dashboard
    rend une erreur — une escalade anterieure serait invisible, et le silence
    est exactement ce que l'organe existe pour rompre. Defaut 200 : mesure
    Hermes 04/11 (debits reels/nuit : CoursIA 12,85/h, cluster 7,25/h,
    roo-extensions 3,9/h) -> 200 entrees couvrent > 8 h partout ; la verif
    de couverture rend la constante auto-prouvee, pas crue sur parole.
    Une escalade archivee par condensation AVANT son echeance reste le
    plafond connu (review NanoClaw 03/11) — le store a au moins le merite
    de ne pas geler.
    """
    call = _load_transport()
    keys = store_keys_from_listing(call({"action": "list"}, url, bearer,
                                        timeout=timeout))
    if keys is None:
        return None
    entries = []
    errors = []
    window_start = (now - timedelta(hours=window_hours)
                    if now is not None and window_hours else None)
    for key in keys:
        result = call(read_arguments_for_key(key, intercom_limit),
                      url, bearer, timeout=timeout)
        text = tool_result_text(result)
        if text is None:
            errors.append(f"{key}: lecture store sans contenu")
            continue
        try:
            structured = entries_from_store_json(text)
        except ValueError as exc:
            # Enveloppe JSON mais entree inexploitable (horodatage absent ou
            # malforme) : on ne retombe PAS sur le parse markdown -- il lirait
            # du JSON comme du markdown et rendrait un dashboard « propre ».
            errors.append(f"{key}: enveloppe store inexploitable ({exc})")
            continue
        if structured is not None:
            dash_entries = structured
        else:
            suspicious = unrecognized_headers(text)
            if suspicious:
                # Review Hermes 04/11, reserve 2 : proche-match d'entete =
                # entree potentiellement invisible. Le dashboard reste lu
                # (act-then-degrade), mais la mesure ne peut pas rendre un 0/2
                # confiant.
                errors.append(f"{key}: {len(suspicious)} entete(s) proche(s) "
                              f"non reconnu(s) — entrees potentiellement "
                              f"invisibles (ex: {suspicious[0][:80]})")
            dash_entries = parse_entries(text)
        entries.extend(dash_entries)
        # Seule une lecture TRONQUEE peut cacher une entree anterieure : un
        # dashboard calme ou fraichement condense a moins de `intercom_limit`
        # entrees est entierement couvert (review ai-01 04/11 — la garde nue
        # sonnait sur du contenu normal).
        if (window_start is not None
                and len(dash_entries) >= intercom_limit):
            oldest = min(e["ts"] for e in dash_entries)
            if oldest > window_start:
                errors.append(
                    f"{key}: fenetre non couverte — plus ancienne entree lue "
                    f"{oldest.isoformat()} > debut de fenetre "
                    f"{window_start.isoformat()} (intercom_limit="
                    f"{intercom_limit}) ; une escalade anterieure serait "
                    f"invisible")
    return entries, errors


def mirror_is_stale(entries, now, cycle_hours=DEFAULT_CYCLE_HOURS):
    """Vrai si la plus recente entree lue depasse un cycle (review #4519
    point c, plancher alternatif) : un miroir gele n'est pas une erreur de
    lecture, c'est pire — il repond un faux « rien a signaler » sur des
    donnees mortes. Un ensemble sans AUCUNE entree est stale par construction.
    """
    if not entries:
        return True
    newest = max(entry["ts"] for entry in entries)
    return now - newest > timedelta(hours=cycle_hours)


def strip_declaration_tokens(text):
    """Remplace tout token de declaration par son mot (review #4519 point b).

    Applique au texte de la sonnerie : un `[REPAIRED]` ou `[DEGRADED]` litteral
    dans le post de sonnerie serait lu par le prochain run comme la reparation
    de l'escalade qu'il sonne -- la sonnerie fermerait sa propre alarme.
    """
    # Le token est rendu adosse, pas traduit : « un `REPAIRED` de la lane »
    # reste lisible et ne peut pas deriver en « un reparation » (accord casse,
    # NIT review ai-01 04/11) — le mot est un token anglais, pas un nom francais.
    return DECLARATION_TOKEN_RE.sub(lambda m: f"`{m.group(1)}`", text)


def build_ring_content(overdue):
    lines = [f"[ASK-USER][DEGRADED-ESCALATION] {len(overdue)} escalade(s) "
             f"d'environnement degrade non reparee(s) dans les delais."]
    for item in overdue:
        lines.append(strip_declaration_tokens(
            f"- {item['lane']} — degrade depuis {item['posted']}, "
            f"echeance {item['deadline']} depassee : {item['excerpt'][:120]}"))
    lines.append("Le mecanisme porte l'echeance, pas la memoire de la lane : "
                 "un `REPAIRED` de la lane ferme l'escalade ; un bilan de "
                 "cycle ne ferme rien.")
    return "\n".join(lines)


def build_ring_id(overdue, now=None):
    """Cle d'idempotence (#3276) : hote + empreinte du lot + tranche de 24 h.

    Meme lot -> UNE sonnerie par jour, pas une par tick ; un lot qui change
    produit un id neuf ; le lendemain re-sonne tant que rien n'est repare.
    """
    now = now or time.time()
    payload = "|".join(f"{i['lane']}:{i['posted']}" for i in overdue)
    digest = hashlib.md5(payload.encode("utf-8")).hexdigest()[:12]
    host = os.environ.get("COMPUTERNAME") or os.environ.get("HOSTNAME") or "unknown-host"
    return f"degraded-escalation-{host}-{digest}-{int(now // 86400)}"


def _load_transport():
    """call_dashboard_tool() depuis detect-approval-stalls.py — un seul
    transport de dashboard pour la flotte, pour LIRE le store comme pour
    POSTER la sonnerie (review #4519 point c : la lecture prend le meme
    chemin que l'ecriture, jamais un second client). Meme motif que
    check-mcp-seats.py qui importe handshake(). Importlib : le nom de fichier
    porte un tiret, il n'est pas importable comme module."""
    here = Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location(
        "detect_approval_stalls", here / "detect-approval-stalls.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.call_dashboard_tool


def publish_ring(overdue, url, bearer, timeout=10.0, now=None):
    arguments = {
        "action": "append",
        "type": "global",
        "tags": ["ASK-USER", "DEGRADED-ESCALATION"],
        "content": build_ring_content(overdue),
        "messageId": build_ring_id(overdue, now=now),
    }
    return _load_transport()(arguments, url, bearer, timeout=timeout,
                             client="degraded-escalations") is not None


def verdict(escalations):
    """(exit_code, reason). Contrat de sortie, en un seul endroit."""
    overdue = [e for e in escalations if e["status"] == "overdue"]
    waiting = [e for e in escalations if e["status"] == "waiting"]
    if overdue:
        return 2, f"{len(overdue)} echeance(s) depassee(s) sans [REPAIRED]"
    if waiting:
        return 3, f"{len(waiting)} escalade(s) ouverte(s), dans les delais"
    return 0, "aucune escalade [DEGRADED]"


def report(escalations, code, reason, as_json, stream=sys.stdout):
    counts = {status: sum(1 for e in escalations if e["status"] == status)
              for status in ("overdue", "waiting", "repaired")}
    if as_json:
        print(json.dumps({"exit": code, "reason": reason, "totals": counts,
                          "escalations": escalations}, ensure_ascii=False, indent=2),
              file=stream)
        return
    for item in escalations:
        mark = {"overdue": "SONNERIE", "waiting": "ouverte", "repaired": "close "}[item["status"]]
        print(f"{mark:<8} {item['lane']:<38} postee {item['posted']} "
              f"echeance {item['deadline']}")
        print(f"         {item['excerpt'][:120]}")
    print(f"\n{reason} — overdue={counts['overdue']} waiting={counts['waiting']} "
          f"repaired={counts['repaired']}")


def selftest():
    """Fixtures locales : aucun acces G:, aucun reseau."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        cases = {
            "clean.md": """## Intercom (1 messages)

### [2026-11-03T10:00:00.000Z] myia-a|ws
[tags: DONE]

[DONE] cycle normal, rien de degrade
""",
            "waiting.md": """### [2026-11-03T10:00:00.000Z] myia-b|ws

[DEGRADED] jupyter-papermill muet, escalade immediate
""",
            "overdue.md": """### [2026-11-02T22:00:00.000Z] myia-c|ws
[tags: DEGRADED]

[DEGRADED] MCP sk-agent absent
""",
            "repaired.md": """### [2026-11-03T02:00:00.000Z] myia-d|ws

[DEGRADED] searxng muet

### [2026-11-03T03:00:00.000Z] myia-d|ws

[REPAIRED] searxng repond, 2 outils
""",
            "done-is-not-repair.md": """### [2026-11-02T22:00:00.000Z] myia-e|ws

[DEGRADED] playwright muet

### [2026-11-03T03:00:00.000Z] myia-e|ws

[DONE] cycle termine, 1 PR
""",
            "word-boundary.md": """### [2026-11-03T02:00:00.000Z] myia-f|ws

[DEGRADED-FIXED] une forme voisine ne doit pas compter
""",
            # Review #4519 point a — les deux posts REELS du 03/11 qui citaient
            # le tag en pleine prose : aucun des deux n'est une declaration.
            # Ce sont eux qui produisaient les escalades fantomes.
            "mention-done.md": """### [2026-11-03T02:00:00.000Z] myia-ai-01|roo-extensions
[tags: DONE]

[DONE] c.57 termine. Rappel : la lane po-2026 a poste `[DEGRADED]` mcp muet
sur son dashboard, l'echeance court.
""",
            "mention-review.md": """### [2026-11-03T02:30:00.000Z] myia-po-2026|nanoclaw
[tags: REPLY]

Review rendue : le tag `[DEGRADED]` du post de 16:53 est bien une escalade,
l'organe doit la compter.
""",
            # Point a, temoin positif : la ligne [tags:] SEULE declare, meme
            # sans token ouvrant le corps (forme de production des posts tagges).
            "declaration-tags.md": """### [2026-11-03T10:00:00.000Z] myia-g|ws
[tags: DEGRADED]

environnement degrade : jupyter-papermill muet depuis le preflight
""",
            # Point b — la sonnerie elle-meme (tags ASK-USER + DEGRADED-ESCALATION,
            # texte portant deliberement des tokens litteraux comme les anciennes
            # sonneries en contenaient) ne ferme PAS l'escalade de sa lane et
            # n'en OUVRE pas une nouvelle.
            "self-ring.md": """### [2026-11-02T22:00:00.000Z] myia-h|ws
[tags: DEGRADED]

[DEGRADED] sk-agent absent

### [2026-11-03T08:30:00.000Z] myia-h|ws
[tags: ASK-USER, DEGRADED-ESCALATION]

[ASK-USER][DEGRADED-ESCALATION] 1 escalade(s) non reparee(s). une declaration
[REPAIRED] par la lane fermerait l'escalade. Extrait : sk-agent absent.
""",
        }
        for name, text in cases.items():
            (root / name).write_text(text, encoding="utf-8")

        now = parse_ts("2026-11-03T09:00:00Z")

        def evaluate(name):
            entries, errors = load_entries([root / name])
            assert not errors, errors
            return verdict(collect_escalations(entries, now))

        assert evaluate("clean.md")[0] == 0, evaluate("clean.md")
        assert evaluate("waiting.md")[0] == 3, evaluate("waiting.md")
        assert evaluate("overdue.md")[0] == 2, evaluate("overdue.md")
        assert evaluate("repaired.md")[0] == 0, evaluate("repaired.md")
        # Le point du mandat : un [DONE] ne consacre pas une sortie degradee.
        assert evaluate("done-is-not-repair.md")[0] == 2, evaluate("done-is-not-repair.md")
        assert evaluate("word-boundary.md")[0] == 0, evaluate("word-boundary.md")
        # Review #4519 point a — les deux posts reels qui citaient le tag en
        # prose : PAS des declarations, PAS d'escalade fantome.
        assert evaluate("mention-done.md")[0] == 0, evaluate("mention-done.md")
        assert evaluate("mention-review.md")[0] == 0, evaluate("mention-review.md")
        # Point a, temoin positif : la ligne [tags:] seule declare.
        assert evaluate("declaration-tags.md")[0] == 3, evaluate("declaration-tags.md")
        # Point b — la sonnerie de sa propre lane ne ferme pas son alarme
        # (tokens litteraux dans le corps + tag DEGRADED-ESCALATION) et n'en
        # ouvre pas une nouvelle : exactement UNE escalade, toujours due.
        self_ring = collect_escalations(load_entries([root / "self-ring.md"])[0], now)
        assert len(self_ring) == 1 and self_ring[0]["status"] == "overdue", self_ring
        # Point b — le texte de la sonnerie ne porte AUCUN token de declaration,
        # meme quand l'extrait de l'escalade en cite (mention en pleine prose).
        noisy = collect_escalations(load_entries([root / "self-ring.md"])[0], now)
        noisy[0]["excerpt"] = "escalade `[DEGRADED]` citee puis `[REPAIRED]` en prose"
        assert not DECLARATION_TOKEN_RE.search(build_ring_content(noisy)), \
            build_ring_content(noisy)

        # L'echeance est derivee du poste, pas declaree par l'agent.
        entries, _ = load_entries([root / "overdue.md"])
        item = collect_escalations(entries, now)[0]
        assert item["deadline"] == "2026-11-03T06:00:00Z", item  # 02/11 22:00Z + 2 * 4 h
        early = collect_escalations(entries, parse_ts("2026-11-03T05:59:59Z"))[0]
        assert early["status"] == "waiting", early

        # Un dossier illisible est une erreur d'instrument, pas un « rien a signaler ».
        entries, errors = load_entries([root / "absent.md"])
        assert entries == [] and errors, (entries, errors)

        # Idempotence : meme lot -> meme id dans la meme journee, id neuf le lendemain.
        overdue = collect_escalations(entries=load_entries([root / "overdue.md"])[0],
                                      now=now)
        assert build_ring_id(overdue, now=1750000000) == build_ring_id(overdue, now=1750000100)
        assert build_ring_id(overdue, now=1750000000) != build_ring_id(overdue, now=1750100000)

    print("selftest OK: [DEGRADED] ouvert/depasse/repare, [DONE] ne ferme rien, "
          "forme voisine ignoree, echeance derivee du poste, erreur d'instrument "
          "non confondue avec 'rien a signaler', idempotence quotidienne, "
          "mentions en prose ignorees (posts reels du 03/11), declaration par "
          "[tags:] seule, sonnerie sans effet sur sa propre alarme et sans "
          "token de declaration.")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Sonde les escalades [DEGRADED] des dashboards et dit si la "
                    "sonnerie est due (#4517).")
    parser.add_argument("--dashboard-dir", default=None,
                        help="repertoire des dashboards (defaut : "
                             "$ROOSYNC_SHARED_PATH/dashboards)")
    parser.add_argument("--dashboard-file", action="append", default=None,
                        metavar="PATH", help="fichier precis (repetable) ; remplace --dashboard-dir")
    parser.add_argument("--cycles", type=float, default=DEFAULT_CYCLES,
                        help=f"nombre de cycles avant la sonnerie (defaut {DEFAULT_CYCLES})")
    parser.add_argument("--cycle-hours", type=float, default=DEFAULT_CYCLE_HOURS,
                        help=f"duree d'un cycle en heures (defaut {DEFAULT_CYCLE_HOURS}, "
                             "cadence des crons flotte `41 */4`)")
    parser.add_argument("--now", default=None, metavar="ISO8601",
                        help="instant de reference (rejeu) ; defaut : maintenant")
    parser.add_argument("--json", action="store_true", help="sortie machine")
    parser.add_argument("--ring", action="store_true",
                        help="poste la sonnerie ASK-USER sur le dashboard GLOBAL "
                             "(bearer : --ring-bearer ou MCP_PROXY_BEARER)")
    parser.add_argument("--ring-url", default=os.environ.get("MCP_PROXY_URL",
                                                            "https://mcp-tools.myia.io"),
                        help="base URL du mcp-proxy (defaut : MCP_PROXY_URL ou "
                             "https://mcp-tools.myia.io)")
    parser.add_argument("--ring-bearer", default=os.environ.get("MCP_PROXY_BEARER"),
                        help="bearer du mcp-proxy (defaut : env MCP_PROXY_BEARER)")
    parser.add_argument("--ring-timeout", type=float, default=10.0, metavar="SECONDS")
    parser.add_argument("--selftest", action="store_true", help="fixtures locales + sortie")
    args = parser.parse_args(argv)

    if args.selftest:
        selftest()
        return 0

    now = parse_ts(args.now) if args.now else datetime.now(timezone.utc)

    # Chaine de sources (review #4519 point c) : rejeu explicite -> fichiers ;
    # sinon STORE PG via le meme transport que la sonnerie ; sinon repli miroir
    # G:, qui DEGRADE la mesure quand PG etait configure (les dashboards sont
    # servis par PG depuis le cut #4131 — un G: gele repond un faux « tout va
    # bien » confiant sur des donnees mortes).
    source = "replay"
    degraded_source = False
    if args.dashboard_file:
        paths = [Path(p) for p in args.dashboard_file]
        entries, errors = load_entries(paths)
    else:
        loader = _store_loader or load_entries_from_store
        store = (loader(args.ring_url, args.ring_bearer,
                        timeout=args.ring_timeout, now=now,
                        window_hours=args.cycles * args.cycle_hours)
                 if args.ring_bearer else None)
        if store is not None:
            source = "store"
            paths = []
            entries, errors = store
        else:
            if args.ring_bearer:
                print("WARNING: store PG injoignable — repli miroir G:, la mesure "
                      "est DEGRADEE (sortie 1 quoi qu'il lise)", file=sys.stderr)
            source = "mirror"
            degraded_source = bool(args.ring_bearer)
            if args.dashboard_dir:
                dash_dir = Path(args.dashboard_dir)
            else:
                dash_dir = (Path(os.environ.get("ROOSYNC_SHARED_PATH") or DEFAULT_SHARED)
                            / "dashboards")
            paths = default_dashboard_files(dash_dir)
            entries, errors = load_entries(paths)

    for err in errors:
        print(f"WARNING: dashboard illisible — {err}", file=sys.stderr)

    escalations = collect_escalations(entries, now, cycles=args.cycles,
                                      cycle_hours=args.cycle_hours)
    code, reason = verdict(escalations)
    report(escalations, code, reason, args.json)

    if source == "mirror" and not paths:
        print("ERROR: aucun dashboard a lire — « rien a signaler » serait un mensonge "
              "sur une mesure absente", file=sys.stderr)
        return 1

    # Plafond de fraicheur du miroir : la plus recente entree doit dater de
    # moins d'un cycle. Un miroir gele ne renvoie pas une erreur de lecture —
    # il repond un « rien a signaler » sur des donnees mortes, ce qui est pire.
    # Pas de sonnerie sur des donnees mortes : faux positif garanti.
    if (source == "mirror"
            and mirror_is_stale(entries, now, cycle_hours=args.cycle_hours)):
        print("ERROR: miroir gele — entree la plus recente plus vieille qu'un cycle ; "
              "mesure non fiable, aucune sonnerie sur des donnees mortes",
              file=sys.stderr)
        return 1

    if code == 2 and args.ring:
        overdue = [e for e in escalations if e["status"] == "overdue"]
        if not args.ring_bearer:
            print("ERROR: --ring demande sans bearer (--ring-bearer ou MCP_PROXY_BEARER) "
                  "— la sonnerie N'EST PAS partie", file=sys.stderr)
            return 1
        if not publish_ring(overdue, args.ring_url, args.ring_bearer,
                            timeout=args.ring_timeout, now=now.timestamp()):
            print("ERROR: la sonnerie N'EST PAS partie (transport) — l'echeance "
                  "reste depassee, relancer au cycle suivant", file=sys.stderr)
            return 1
        print(f"ring: sonnerie ASK-USER postee sur le dashboard global "
              f"({len(overdue)} escalade(s))", file=sys.stderr)

    if errors:
        # Fail-closed : une moitie de dashboards illisible peut cacher une
        # escalade. Ce qui a ete mesure est agi (rapport + sonnerie ci-dessus),
        # mais l'instrument ne peut pas annoncer un 0 ou un 2 confiant.
        print(f"ERROR: {len(errors)} dashboard(s) illisible(s) sur {len(paths)} — "
              f"mesure partielle, codes 0/2/3 non fiables", file=sys.stderr)
        return 1

    if degraded_source:
        # Meme logique act-then-degrade : ce que le miroir a dit est rapporte
        # (et sonne) ci-dessus, mais la mesure est incomplete — le store PG
        # etait configure et n'a pas repondu (review #4519 point c).
        print("ERROR: source = miroir G: alors que PG est configure (store "
              "injoignable) — mesure incomplete, codes 0/2/3 non fiables",
              file=sys.stderr)
        return 1

    return code


if __name__ == "__main__":
    sys.exit(main())

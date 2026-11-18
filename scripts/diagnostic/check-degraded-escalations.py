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

#4746 : un `[REPAIRED]` peut NOMMER son escalade (messageId, reference
d'issue presente dans son corps, ou heure de pose `HH:MMZ`) — il ne ferme
alors QUE celle-la. Sans portee il reste une declaration de LANE et ferme
toutes les precedentes ; l'organe l'imprime quand c'est plus d'une.

Un `[DONE]` ne ferme jamais une escalade : c'est exactement la « sortie degradee
consacree » que le mandat interdit. Seul `[REPAIRED]` ferme.

Codes de sortie (un automate peut lire le code seul) :
    0   aucune escalade `[DEGRADED]` dans la fenetre lue
    3   escalade(s) ouverte(s), aucune echeance depassee  (mecanisme exerce, rien a sonner)
    2   au moins une echeance depassee sans `[REPAIRED]`  -> SONNERIE DUE
    1   erreur d'instrument (dashboards illisibles, miroir gele, ou --ring
        demande et non poste) ; AUSSI la mesure DEGRADEE : miroir lu comme
        source alors que PG etait configure (review #4519 point c), et —
        depuis #4650 — la lecture PAR DEFAUT sans bearer (le miroir implicite
        n'est plus ecrit depuis #4131 : l'organe dit qu'il ne sait pas au lieu
        de rendre un verdict sur une source morte)

Sources, dans l'ordre (review #4519 point c) :
    1. --dashboard-file    rejeu d'un fichier precis (forensic) — pas de plafond
    2. STORE PG            meme transport que la sonnerie (MCP_PROXY_BEARER),
                           fenetre des 200 dernieres entrees par dashboard,
                           PLUS les archives de condensation recentes (#4643,
                           --archive-window-hours, defaut 48 h) ; la passe
                           d'archives est bornee par --archive-time-budget
                           (defaut 900 s, #4661/#4643 — couvre la passe saine
                           mesuree a 669 s) : au-dela, archives restantes
                           sautees et signalees, sortie 1
    3. miroir G:           repli seulement, et seulement vers un repertoire
                           EXPLICITE (--dashboard-dir) ou avec bearer ; la
                           lecture par defaut sans bearer est DEGRADEE (sortie
                           1, #4650) car le miroir n'est plus ecrit depuis
                           #4131. Plafond de fraicheur : la plus recente entree
                           doit dater de moins d'un cycle

#4643 — la condensation ne doit plus aveugler l'organe. Elle retire les messages
du vif sur les DEUX surfaces (miroir G: vers dashboards/archive/, store PG :
compteur 47 -> 12 mesure le 11/11), ce qui jouait dans les deux sens : un
`[REPAIRED]` consomme par une condensation entre deux passages d'organe etait
definitivement invisible (sonnerie ASK-USER RECURRENTE apres une reparation
documentee — cas du 10/11 : [REPAIRED] 17:32Z archive a 21:00Z, sonnerie
23:54Z, 6 h 22 apres la reparation), et une ESCALADE archivee quittait le champ
sans jamais sonner (faux negatif — cas du 03/11). La condensation POSE une
archive des messages retires (`read_archive` la sert depuis les fichiers .md
ecrits sur l'hote RSM ; en PG, `archived_at` passe non-NULL) : le lecteur store
lit donc AUSSI les archives creees dans la fenetre. Un message crossPoste (global +
machine + workspace) porte le meme auteur et le meme horodatage partout : les
declarations se dedoublonnent sur (lane, poste).

Usage :
    python check-degraded-escalations.py                       # commande canonique : lit le store PG
                                                               # (bearer : --ring-bearer, MCP_PROXY_BEARER,
                                                               #  puis ~/.roo-state-manager/stall-detector.env)
    python check-degraded-escalations.py --cycles 2 --cycle-hours 4
    python check-degraded-escalations.py --json
    python check-degraded-escalations.py --ring                # poste ASK-USER sur le dashboard global
    python check-degraded-escalations.py --dashboard-file <copie.md>   # rejeu hors store
    python check-degraded-escalations.py --env-file <chemin>   # autre fichier CLE=valeur (vide = aucun)
    python check-degraded-escalations.py --selftest

Plafond dit explicitement : l'organe ne voit que les escalades **postees**. Une
lane qui n'escalade pas reste invisible — c'est pourquoi le mandat exige
l'escalade immediate, et pourquoi la sonde de siege (#4518) existe : elle rend
le degre de degradation visible sans attendre la bonne volonte de la lane.
La sonnerie, elle, n'est pas prouvee ici : l'append est best-effort, et un
`--ring` qui echoue sort en 1 plutot que de simuler un succes.
"""

import argparse
import contextlib
import hashlib
import importlib.util
import io
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
# #4643 : fenetre de lecture des archives de condensation (heures). 48 h
# couvre l'horizon reel d'une escalade saine (2 cycles d'echeance + la
# re-sonnerie quotidienne de build_ring_id) ; 0 desactive la lecture.
DEFAULT_ARCHIVE_WINDOW_HOURS = 48.0
# #4661 : budget de temps GLOBAL de la passe d'archives (secondes). Mesure
# motivante (ai-01, 12/11, G: gele en profondeur) : 929 s dont 68 timeouts
# read_archive de 10 s SEQUENTIELS — la passe n'etait pas bornee. Au-dela du
# budget, les archives restantes sont sautees et signalees (fenetre
# partiellement aveugle -> erreur d'instrument -> sortie 1 par le fail-closed
# existant) ; les lectures VIVANTES des dashboards restants continuent.
# 0 ou negatif = illimite (comportement d'avant #4661).
# #4643 (dispatch ai-01 12/11) : le defaut doit COUVRIR une passe saine
# mesuree — 669 s releves le 12/11. L'ancien 120 s epuisait le budget au
# bout de 3 min d'une passe SAINE : l'organe ne rendait jamais 0/2/3.
# 900 s = 669 s + la marge des relances de coques vides ci-dessous.
DEFAULT_ARCHIVE_TIME_BUDGET_S = 900.0
# #4643 -> #4729 : relance d'une lecture MUETTE (le transport rend None —
# timeout client sporadique ; 5 releves #4643 sur des archives saines de
# 32-39 Ko). #4729 generalise la relance a TOUTES les lectures du store :
# le listing initial et les lectures vivantes tombaient aussi sous charge
# flotte (ai-01 12:02Z 14/11 : « store PG injoignable — The read operation
# timed out » alors que le store repondait aux appends MCP de la meme
# fenetre — le defaut est la lecture, pas la source). Un rejet serveur
# isError ne se relance PAS : deterministe (7 ms mesures post-gel,
# c.6823202164 — les ~35 s venaient du gel de G:, pas du rejet).
STORE_READ_RETRY_TIMEOUT_S = 45.0
# #4729 (piste 2) : seuil SLOW de la telemetrie de lecture. Distinguer
# « store lent » de « store mort » par des CHIFFRES (p50/p95/max), pas
# seulement OK/FAILED : la lenteur est le signal precoce du timeout sous
# charge. 5 s = la moitie du timeout par defaut : au-dela, la lecture
# suivante peut echouer.
SLOW_READ_S = 5.0
# #4643 : signature du rejet d'une coque vide par read_archive (dashboard.ts,
# « Format archive invalide: frontmatter manquant dans ... ») — rejet isError
# dont le transport rend le texte (opt-in return_rejected_text). Une coque de
# 0 octet n'a jamais porte de messages (mesure ai-01 12/11 : 5 coques vides
# sur G: ; le writer corrige temp+rename n'en pose plus).
# #4796 : la premisse « coque vide » ne se prouve PAS depuis un siege — le
# meme rejet a servi une archive PLEINE de 18 messages mal hydratee par
# DriveFS (po-2024 16/11 : placeholder lu vide, exit 2 fantome sur deux runs
# propres ; la meme archive se lisait normalement depuis ai-01). Dans la
# fenetre lue, ce rejet vaut donc LECTURE PARTIELLE (erreur d'instrument,
# exit 1) ; il ne reste un WARN que hors fenetre (seconde passe), ou la
# coque ne peut plus masquer une fermeture de la fenetre.
ARCHIVE_HUSK_SIGNATURE = "frontmatter manquant"

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
# #4746 : portee OPTIONNELLE d'un `[REPAIRED]`. Elle ne se lit QUE sur une
# ligne de marqueur dediee du corps du `[REPAIRED]` — `scope: <valeur>` ou
# `portée: <valeur>` (review ai-01 15/11 : les `[REPAIRED]` reels citent
# presque toujours une heure ou une issue en PROSE ; les y lire re-scopait
# retroactivement des reparations deja fermees sous le contrat de lane —
# 27 escalades reversed repaired -> overdue sur le store live). Trois formes
# de valeur NOMMENT une escalade : une reference d'issue presente dans le
# corps de l'escalade (`#4741`), son heure de POSE `HH:MMZ`, ou son messageId
# (par correspondance avec l'id d'une escalade — voir `repair_names`). Sans
# marqueur : declaration de LANE, comportement d'origine. Indentation max
# 3 espaces : une ligne `scope:` dans un bloc indente n'est pas un marqueur.
SCOPE_MARKER_RE = re.compile(
    r"^\s{0,3}(?:scope|port(?:ée|ee))\s*:\s*(?P<value>[^\n]+?)\s*$",
    re.IGNORECASE | re.MULTILINE)
# Bornes de chiffres sur la reference : `#47410` n'est pas `#4741` (meme
# piege que `#109` / `#1091`). Le lookbehind du motif d'heure rejette les
# `HH:MMZ` qui sont en fait les SECONDES d'un horodatage ISO : `...T08:00:00Z`
# contient `00:00Z`, et sans lui une valeur de marqueur citant un ISO
# nommerait une escalade postee a 00:00 (mesure en ecrivant le test). Les
# deux motifs ne s'appliquent qu'a la VALEUR du marqueur, jamais a la prose.
ISSUE_REF_RE = re.compile(r"(?<![0-9])#[0-9]{2,}(?![0-9])")
SCOPE_TIME_RE = re.compile(
    r"(?<![0-9:])([01][0-9]|2[0-3]):([0-5][0-9])Z(?![0-9A-Za-z_:])")
# Un id de message plus court que cela n'est pas un marqueur de portee : le
# reconnaitre par sous-chaine ferait matcher du texte ordinaire.
SCOPED_ID_MIN_CHARS = 8
# Ligne `[msg: id]` posee en tete par le miroir (meme enveloppe que
# `META_LINE_RE`) : elle porte le messageId que la portee #4746 peut citer.
MSG_ID_RE = re.compile(r"^\[msg:\s*(?P<id>[^\]\n]+?)\s*\]$", re.M)
# Les deux tokens, pour l'assainissement du texte de la sonnerie (review
# #4519 point b : la sonnerie ne doit porter AUCUN token de declaration --
# sinon son propre post se lit comme la reparation de l'escalade qu'elle sonne).
DECLARATION_TOKEN_RE = re.compile(r"\[(DEGRADED|REPAIRED)\](?![A-Za-z0-9_-])")
# Tag porte par la sonnerie elle-meme (tags ASK-USER + DEGRADED-ESCALATION) :
# une entree qui le porte n'est jamais une declaration ni une reparation.
RING_TAG = "degraded-escalation"
# Nom d'un fichier d'archive de condensation (#4643) :
# `workspace-roo-extensions-2026-11-10T21-00-47.md` — l'horodatage du nom est
# l'instant de la condensation (les millisecondes ne sont pas ecrites).
# #4804 : la famille `-fallback` (dashboard.ts l.6864 ecrit
# `<key>-<dateStr>-fallback.md`, passe de secours de la condensation ;
# 38 archives en 14 jours, census c.5852733240) porte le MEME horodatage —
# le serveur la date deja (countRecentFallbackArchives, dashboard.ts
# l.6777). Non datee ici, une `-fallback` restait « de la fenetre » a vie
# (exit 1 a chaque passage sur un placeholder DriveFS) et la seconde passe
# l'ignorait : le suffixe fait donc partie du nom datable.
ARCHIVE_NAME_TS_RE = re.compile(
    r"-(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})(?:-fallback)?\.md$")
# #4730 (decision user 14/11/2026, RX160 (a)) : un defaut CONNU de l'hote --
# le harnais Claude Code lui-meme, pas un MCP d'une lane -- ne se repare par
# aucune lane. Il reste une escalade comme les autres (ouverte, due, jamais
# close sans `[REPAIRED]`) ; la sonnerie le range seulement A PART pour qu'il
# ne noie pas les pannes reparables. `markers` = groupes de vocables : un mot
# de CHAQUE groupe doit etre present pour reconnaitre le defaut decrit SANS
# son numero d'issue. Ajouter une entree exige une PR citant l'issue du defaut
# de l'hote.
KNOWN_HOST_DEFECTS = (
    {"ref": "#3345",
     "label": "defaut connu de Claude Code : worktree d'isolation des sous-agents refuse",
     "markers": (("worktree",), ("refus",),
                 ("isolation", "sous-agent", "subagent"))},
)


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
        # #4746 : le miroir serialise `[msg: id]` en tete — c'est le messageId
        # qu'une portee de `[REPAIRED]` peut citer.
        identifier = MSG_ID_RE.search(entry["body"])
        entry["id"] = identifier.group("id") if identifier else None
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


def classify_known_host_defect(text):
    """Ref du defaut connu de l'hote decrit par `text`, sinon None (#4730).

    Deux formes, larges sur le VOCABULAIRE et bornees sur ce qu'elles exigent :
      - la citation de l'issue, avec frontiere de chiffre (`#33450` n'est pas
        `#3345` -- meme piege que `#109` / `#1091`) ;
      - la conjonction des marqueurs du defaut : une lane sous pression
        n'ecrit pas toujours le numero d'issue. "worktree nettoye" ne matche
        pas : la conjonction exige aussi un refus et isolation/sous-agent.
        "agent" seul n'est PAS un marqueur : un worktree sale refuse par
        `git worktree remove` dans un post qui nomme "l'agent" est une panne
        reparable (review ai-01 14/11).
    Insensible a la casse. A appliquer au corps ENTIER, jamais a l'extrait
    tronque (les marqueurs peuvent tomber apres le 160e caractere).
    """
    lowered = (text or "").lower()
    for defect in KNOWN_HOST_DEFECTS:
        ref = defect["ref"]
        if re.search(r"(?<![0-9])" + re.escape(ref) + r"(?![0-9])", lowered):
            return ref
    for defect in KNOWN_HOST_DEFECTS:
        if all(any(word in lowered for word in group)
               for group in defect["markers"]):
            return defect["ref"]
    return None


def degraded_declarations(ordered):
    """Declarations `[DEGRADED]` dedoublonnees sur (lane, poste), avec leur
    index dans `ordered`.

    #4643 : une declaration crossPostee existe sur plusieurs dashboards (meme
    auteur, meme horodatage) et ne doit compter qu'une fois. #4746 : l'index
    permet de ne regarder que les `[REPAIRED]` POSTERIEURS a chaque poste.
    """
    declarations = []
    seen = set()
    for index, entry in enumerate(ordered):
        if not is_degraded(entry):
            continue
        marker = (entry["lane"], entry["ts"])
        if marker in seen:
            continue
        seen.add(marker)
        declarations.append((index, entry))
    return declarations


# #4779 (review ai-01 16/11) : un bloc de code fenced (``` ou ~~~, style
# Markdown) est un EXEMPLE, pas de la prose. On le retire avant le scan des
# marqueurs, sinon un `scope:` cite dans un exemple se lit comme une portee
# et re-scope silencieusement le post. Un bloc non ferme court jusqu'a la fin
# (comportement CommonMark).
FENCED_CODE_RE = re.compile(
    r"^[ \t]{0,3}(?P<fence>`{3,}|~{3,})[^\n]*\n"
    r"(?:.*?^[ \t]{0,3}(?P=fence)[ \t]*$|\Z)",
    re.MULTILINE | re.DOTALL)


def strip_fenced_code_blocks(body):
    """Corps sans ses blocs de code fenced (#4779)."""
    return FENCED_CODE_RE.sub("", body or "")


def scope_marker_text(body):
    """Concatenation des valeurs des lignes `scope:` / `portée:` du corps —
    la SEULE source de portee d'un `[REPAIRED]` (#4746, review ai-01 15/11).
    Les blocs de code fenced sont retires avant le scan (#4779, review ai-01
    16/11) : une ligne `scope:` collee DANS un exemple de code n'est pas une
    declaration de portee — seul l'extérieur des blocs fait foi.
    """
    return "\n".join(match.group("value")
                     for match in SCOPE_MARKER_RE.finditer(
                         strip_fenced_code_blocks(body)))


def repair_scope(repair):
    """(refs, heures, scoped) — ce que ce `[REPAIRED]` NOMME (#4746).

    Uniquement depuis la valeur des lignes de marqueur `scope:` / `portée:`
    du corps du `[REPAIRED]` : les references d'issue et heures de POSE
    `HH:MMZ` qui y sont ecrites. `scoped` faux = pas de marqueur :
    declaration de LANE, comportement d'origine (ferme tout ce qui precede).
    La prose du corps ne peut PAS scoper — c'est la correction de la review
    ai-01 du 15/11 (27 escalades reversed sur le store live).
    """
    marker_text = scope_marker_text(repair["body"])
    if not marker_text:
        return set(), set(), False
    refs = set(ISSUE_REF_RE.findall(marker_text))
    times = {(m.group(1), m.group(2))
             for m in SCOPE_TIME_RE.finditer(marker_text)}
    return refs, times, True


def repair_names(repair, refs, times, escalation):
    """Vrai si la portee du `[REPAIRED]` nomme CETTE escalade (#4746) :
    messageId, reference d'issue de son corps, ou heure de pose `HH:MMZ`.

    Les trois ne se lisent QUE dans la valeur du marqueur `scope:` /
    `portée:` du `[REPAIRED]` — un id ou une heure cites en prose ne nomment
    rien (review ai-01 15/11). Un id trop court n'est pas un marqueur : le
    reconnaitre par sous-chaine ferait matcher du texte ordinaire.
    """
    marker_text = scope_marker_text(repair["body"])
    identifier = escalation.get("id")
    if (isinstance(identifier, str)
            and len(identifier) >= SCOPED_ID_MIN_CHARS
            and identifier in marker_text):
        return True
    if refs.intersection(ISSUE_REF_RE.findall(escalation["body"])):
        return True
    return (escalation["ts"].strftime("%H"),
            escalation["ts"].strftime("%M")) in times


def repair_closes(repair, escalation):
    """Vrai si ce `[REPAIRED]` ferme cette escalade (#4746).

    Sans marqueur de portee : oui (declaration de lane). Avec : seulement si
    le marqueur la nomme. Une portee qui ne correspond a rien ne ferme donc
    RIEN — l'escalade reste due au cycle suivant. C'est le sens sur : « tout
    fermer » par defaut est exactement le defaut #4746.
    """
    refs, times, scoped = repair_scope(repair)
    return not scoped or repair_names(repair, refs, times, escalation)


def collect_escalations(entries, now, cycles=DEFAULT_CYCLES,
                        cycle_hours=DEFAULT_CYCLE_HOURS, excerpt_chars=160):
    """Liste les escalades et leur etat a `now`.

    Resolution : la PREMIERE entree de la meme lane, posterieure a l'escalade,
    portant `[REPAIRED]` et QUI LA FERME. Sans portee, un `[REPAIRED]` est une
    declaration de LANE et ferme toutes ses escalades anterieures — exiger un
    identifiant rendrait le mecanisme inutilisable pour l'agent qui poste sous
    pression. Depuis #4746, un `[REPAIRED]` peut NOMMER son escalade sur une
    ligne de marqueur dediee (`scope: <messageId | #NNNN | HH:MMZ>`, ou
    `portée:`) : il ne ferme alors QUE celle-la — la prose ne scope jamais
    (review ai-01 15/11).

    #4643 : un message crossPoste existe sous plusieurs dashboards avec le
    MEME auteur et le MEME horodatage — chaque copie ouvrait une escalade, la
    sonnerie comptait N fois la meme echeance. Les declarations se
    dedoublonnent sur (lane, poste) ; deux declarations d'une meme lane a deux
    instants differents restent deux escalades distinctes.

    #4730 : chaque item porte `known_defect` (ref du defaut connu de l'hote,
    sinon None). Le STATUT ne change pas -- un tel defaut reste ouvert et du,
    et seul un `[REPAIRED]` de la lane le ferme.

    #4746 : chaque item ferme porte `repaired_by` ({lane, posted, scoped}) —
    `repair_notices` s'en sert pour dire a la lane ce qu'un `[REPAIRED]` SANS
    portee vient de fermer.
    """
    ordered = sorted(entries, key=lambda e: e["ts"])
    declarations = degraded_declarations(ordered)
    window = timedelta(hours=cycles * cycle_hours)
    found = []
    for index, entry in declarations:
        repaired_at = None
        repaired_by = None
        repaired_scoped = False
        for later_index in range(index + 1, len(ordered)):
            later = ordered[later_index]
            if later["lane"] != entry["lane"] or not is_repaired(later):
                continue
            refs, times, scoped = repair_scope(later)
            if scoped and not repair_names(later, refs, times, entry):
                continue
            repaired_at = later["ts"]
            repaired_by = later
            repaired_scoped = scoped
            break
        deadline = entry["ts"] + window
        if repaired_at is not None:
            status = "repaired"
        elif now > deadline:
            status = "overdue"
        else:
            status = "waiting"
        body = DEGRADED_RE.sub(" ", entry["body"], count=1).strip().replace("\n", " ")
        prose = " ".join(body.split())
        found.append({
            "lane": entry["lane"],
            "posted": entry["ts"].isoformat().replace("+00:00", "Z"),
            "deadline": deadline.isoformat().replace("+00:00", "Z"),
            "status": status,
            "repaired_at": (repaired_at.isoformat().replace("+00:00", "Z")
                            if repaired_at else None),
            "repaired_by": ({"lane": repaired_by["lane"],
                             "posted": repaired_by["ts"].isoformat().replace(
                                 "+00:00", "Z"),
                             "scoped": repaired_scoped}
                            if repaired_by is not None else None),
            "excerpt": prose[:excerpt_chars],
            # #4730 : sur le corps ENTIER, jamais sur l'extrait tronque.
            "known_defect": classify_known_host_defect(prose),
        })
    return found


def repair_notices(escalations):
    """#4746 : lignes « REPAIRED <lane> <ts> a ferme N escalade(s) ».

    Un `[REPAIRED]` SANS portee garde le comportement d'origine — il ferme
    toutes les escalades anterieures de sa lane. Quand il en ferme PLUS
    D'UNE, l'organe le dit : la lane voit ce qu'elle vient de fermer, et une
    escalade sans rapport ne peut plus disparaitre en silence. Une fermeture
    unique n'est pas signalee (bruit).
    """
    groups = {}
    for item in escalations:
        by = item.get("repaired_by")
        if not by or by.get("scoped"):
            continue
        groups.setdefault((by["lane"], by["posted"]), []).append(item["posted"])
    notices = []
    for (lane, posted), closed in sorted(groups.items()):
        if len(closed) < 2:
            continue
        notices.append(
            f"REPAIRED {lane} {posted} a fermé {len(closed)} escalade(s) : "
            + ", ".join(sorted(closed)))
    return notices


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
        # #4517 (reouverte 11/11) : le parametre de l'outil est `machineId`.
        # `machine` est ignore -- le serveur lisait alors SON dashboard
        # machine pour chaque cle machine-* (sonde 11/11 : machine=po-2024
        # -> machine-myia-ai-01), et une escalade postee sur un autre
        # dashboard machine restait invisible.
        arguments["machineId"] = key[len("machine-"):]
    elif key.startswith("workspace-"):
        arguments["type"] = "workspace"
        arguments["workspace"] = key[len("workspace-"):]
    else:
        # Cle sans prefix connu : traitee comme workspace nu, id = cle entiere.
        arguments["type"] = "workspace"
        arguments["workspace"] = key
    return arguments


def read_archive_arguments_for_key(key, archive_file=None):
    """Arguments `read_archive` pour la cle (#4643). L'identification est
    CELLE du `read` vivant, par construction : la correction #4647 (`machineId`,
    pas `machine`) doit valoir pour les DEUX lecteurs — dupliquer le dispatch
    d'identite referait un jour la faute corrigee. On part donc des arguments
    du read et on ne change que l'action (et le fichier demande).
    """
    arguments = read_arguments_for_key(key, 0)
    arguments.pop("intercomLimit", None)
    arguments.pop("format", None)
    arguments.pop("section", None)
    arguments["action"] = "read_archive"
    if archive_file is not None:
        arguments["archiveFile"] = archive_file
    return arguments


def archive_name_stamp(name):
    """Horodatage porte par le NOM d'une archive, ou None s'il est illisible.

    Le nom est la seule datation disponible sans lire le fichier : c'est lui
    qui borne la fenetre (#4643). Un nom sans horodatage n'est jamais classe
    « vieux » ici — la fenetre le CONSERVE (impossible de prouver qu'il est
    vieux), la seconde passe l'IGNORE (il a deja ete lu par la fenetre).
    """
    match = ARCHIVE_NAME_TS_RE.search(name)
    if match is None:
        return None
    try:
        return datetime.strptime(match.group(1), "%Y-%m-%dT%H-%M-%S"
                                 ).replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def select_recent_archives(names, now, window_hours):
    """Noms d'archives crees dans la fenetre, par l'horodatage du NOM (#4643).

    Un nom sans horodatage parsable est CONSERVE : impossible de prouver qu'il
    est vieux, et une archive non lue est exactement l'angle mort que ce
    lecteur existe pour fermer.
    """
    if not window_hours:
        return list(names)
    cutoff = (now - timedelta(hours=window_hours)) if now is not None else None
    if cutoff is None:
        return list(names)
    kept = []
    for name in names:
        stamp = archive_name_stamp(name)
        if stamp is None or stamp >= cutoff:
            kept.append(name)
    return kept


def lane_workspace_keys(lane, keys):
    """Cles de dashboard candidates pour le workspace d'une lane (#4643).

    La fermeture non crossPostee vit sur le dashboard du workspace de la lane
    (« il suffit de lire le dashboard ou sa lane poste », ai-01 14/11). Le
    champ workspace d'une lane est tantot un nom court (`roo-extensions`),
    tantot un chemin (`d:/dev/roo-extensions`) : on essaie la forme brute puis
    son dernier segment. On ne rend QUE des cles reellement servies par le
    store : un dashboard absent du listing n'a pas d'archive a relire, et
    l'inventer ferait echouer la passe sur une cle fantome.
    """
    if "|" not in lane:
        return []
    workspace = lane.split("|", 1)[1].strip()
    if not workspace:
        return []
    candidates = [f"workspace-{workspace}"]
    leaf = workspace.replace("\\", "/").rstrip("/").split("/")[-1]
    if leaf and leaf != workspace:
        candidates.append(f"workspace-{leaf}")
    served = {key.lower(): key for key in keys}
    chosen = []
    for candidate in candidates:
        match = candidate if candidate in keys else served.get(candidate.lower())
        if match is not None and match not in chosen:
            chosen.append(match)
    return chosen


def second_pass_old_closures(entries, keys, archive_cutoff, call, url, bearer,
                             timeout, archive_deadline):
    """#4643 (rouverte 14/11) : relit les archives ANTERIEURES a la fenetre.

    Le defaut mesure par ai-01 le 14/11 : une escalade crossPostee survit dans
    le vif et dans les archives recentes des autres dashboards, alors que sa
    fermeture — postee seulement sur le dashboard de sa lane — a ete archivee
    plus tot et sort de la fenetre d'archives. La fenetre s'applique aux DEUX
    cotes, donc la fermeture disparait AVANT l'escalade : l'organe classe
    `overdue` une escalade fermee depuis deux jours, et sonne le user.

    Le declencheur est la coupure d'ARCHIVES (`archive_cutoff`), pas celle des
    echeances : une fermeture postee apres `archive_cutoff` vit dans une
    archive creee apres elle, donc dans la fenetre — seule une escalade
    anterieure a la coupure peut avoir une fermeture hors champ.

    Seconde passe, bornee par le MEME budget que la fenetre (#4661) : pour
    chaque escalade encore ouverte dont la pose precede `archive_cutoff`, on
    relit les archives du workspace de sa lane, de la plus recente a la plus
    ancienne, jusqu'a sa date de pose. On ne retient que les FERMETURES de ces
    archives : les `[DEGRADED]` qu'elles contiennent sont hors fenetre par
    construction et ne doivent pas ressusciter comme echeances.

    Rend (closures, errors). Un listing illisible ou un budget epuise rend une
    erreur d'instrument : l'appelant sort en 1 et la sonnerie est annulee
    (#4655 W3). Jamais un `overdue` rendu comme verdict sur une mesure
    partielle — `errors` force exit 1, et le code 2 n'est jamais atteint.
    """
    ordered = sorted(entries, key=lambda entry: entry["ts"])
    declarations = degraded_declarations(ordered)
    open_posts = []
    for index, entry in declarations:
        if entry["ts"] >= archive_cutoff:
            # Couverte par la fenetre vivante + archives recentes : rien a
            # ajouter, la premiere passe a fait le travail.
            continue
        if any(later["lane"] == entry["lane"] and is_repaired(later)
               and repair_closes(later, entry)
               for later in ordered[index + 1:]):
            continue
        open_posts.append(entry)
    if not open_posts:
        return [], []

    errors = []
    by_key = {}
    unresolved = set()
    for entry in open_posts:
        candidates = lane_workspace_keys(entry["lane"], keys)
        if not candidates:
            unresolved.add(entry["lane"])
            continue
        by_key.setdefault(candidates[0], []).append(entry)
    for lane in sorted(unresolved):
        print(f"WARNING: {lane}: dashboard workspace absent du store — "
              f"fermeture archivee au-dela de la fenetre non verifiable "
              f"(seconde passe) ; non bloquant", file=sys.stderr)

    live_closures = [entry for entry in ordered if is_repaired(entry)]
    closures = []
    for key, posts in sorted(by_key.items()):
        if archive_deadline is not None and time.monotonic() > archive_deadline:
            errors.append(
                f"{key}: budget d'archives epuise AVANT la seconde passe — "
                f"fermetures archivees au-dela de la fenetre non relues ; "
                f"mesure partielle")
            continue
        listing = call(read_archive_arguments_for_key(key), url, bearer,
                       timeout=timeout)
        names = archive_names_from_listing(listing)
        if names is None:
            errors.append(f"{key}: listing des archives illisible (seconde "
                          f"passe) — une fermeture archivee au-dela de la "
                          f"fenetre serait invisible")
            continue
        oldest_post = min(entry["ts"] for entry in posts)
        older = []
        for name in names:
            stamp = archive_name_stamp(name)
            if stamp is None:
                continue
            if oldest_post <= stamp < archive_cutoff:
                older.append((stamp, name))
        older.sort()
        remaining = list(posts)
        for _stamp, name in reversed(older):
            if not remaining:
                break
            if (archive_deadline is not None
                    and time.monotonic() > archive_deadline):
                errors.append(
                    f"{key}/{name}: budget d'archives epuise pendant la "
                    f"seconde passe — {len(remaining)} fermeture(s) archivee(s) "
                    f"non verifiee(s) ; mesure partielle")
                break
            # #4729 : la relance muette vit dans le `call` recu (read_store
            # de la passe principale) — meme contrat que la fenetre.
            archive_result = call(
                read_archive_arguments_for_key(key, archive_file=name),
                url, bearer, timeout=timeout, return_rejected_text=True)
            rejected = archive_rejected_text(archive_result)
            if rejected is not None:
                if ARCHIVE_HUSK_SIGNATURE in rejected.lower():
                    print(f"WARNING: {key}/{name}: coque d'archive vide "
                          f"ignoree (seconde passe) ({rejected[:120]}) — sans "
                          f"contenu, rien a lire : non bloquant",
                          file=sys.stderr)
                else:
                    errors.append(f"{key}/{name}: rejet serveur (seconde "
                                  f"passe) ({rejected[:120]})")
                continue
            archive_text = tool_result_text(archive_result)
            if archive_text is None:
                errors.append(f"{key}/{name}: lecture archive sans contenu "
                              f"(seconde passe, relance incluse)")
                continue
            try:
                archived = entries_from_archive_json(archive_text)
            except ValueError as exc:
                if ARCHIVE_HUSK_SIGNATURE in str(exc).lower():
                    print(f"WARNING: {key}/{name}: coque d'archive vide "
                          f"ignoree (seconde passe) ({exc}) — sans contenu, "
                          f"rien a lire : non bloquant", file=sys.stderr)
                    continue
                errors.append(f"{key}/{name}: enveloppe archive "
                              f"inexploitable (seconde passe) ({exc})")
                continue
            found = [entry for entry in archived if is_repaired(entry)]
            closures.extend(found)
            known = live_closures + closures
            # #4746 : une fermeture SCOPEE ne ferme que ce qu'elle nomme —
            # la seconde passe ne doit pas tenir un poste pour clos sur la
            # seule presence d'un `[REPAIRED]` de sa lane.
            remaining = [
                entry for entry in remaining
                if not any(closure["lane"] == entry["lane"]
                           and closure["ts"] > entry["ts"]
                           and repair_closes(closure, entry)
                           for closure in known)]
    return closures, errors


def archive_names_from_listing(result):
    """Noms de fichiers d'archives depuis un `read_archive` sans fichier, ou
    None si illisible (fail-closed #4643 : un listing illisible ne se sert
    JAMAIS comme « aucune archive » — ce serait rouvrir le faux negatif que
    ce lecteur ferme). Une liste VIDE est legitime (dashboard sans archive)
    et se distingue de None.
    """
    text = tool_result_text(result)
    if text is None:
        return None
    try:
        payload = leading_json(text)
    except ValueError:
        return None
    if not isinstance(payload, dict) or payload.get("success") is False:
        return None
    archives = payload.get("archives")
    if not isinstance(archives, list):
        return None
    return [a for a in archives if isinstance(a, str) and a]


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
      - une cloture plus COURTE que son ouverture n'en est pas une : apres
        #4556, la seule comparaison de caractere fermait un bloc ``` sur une
        ligne d'un ou deux backticks (donc sur du contenu legitime, une
        citation d'inline code par exemple). Tout ce qui suivait etait
        rescanne : un en-tete cite APRES cette fausse cloture produisait un
        faux positif, seul sens d'erreur possible ici (jamais un faux exit 0).
        CommonMark exige une cloture d'au moins la longueur de l'ouverture ;
        la longueur est donc memorisee a l'ouverture (grain #4517, ai-01
        05/11, spec c.6651348721).
    """
    hits = []
    fence = None  # caractere du bloc ouvert ('`' ou '~') ; None = hors bloc
    open_len = 0  # longueur du bloc ouvert : une cloture plus courte est du contenu
    for line in text.splitlines():
        stripped = line.strip()
        if fence is None:
            if stripped.startswith("```"):
                fence = "`"
                open_len = len(stripped) - len(stripped.lstrip("`"))
                continue
            if stripped.startswith("~~~"):
                fence = "~"
                open_len = len(stripped) - len(stripped.lstrip("~"))
                continue
            if NEAR_HEADER_RE.match(line) and not ENTRY_RE.match(line):
                hits.append(line.strip())
        elif (stripped and set(stripped) == {fence}
                and len(stripped) >= open_len):
            fence = None  # cloture : meme caractere, seul, au moins aussi longue
    return hits


_JSON_DECODER = json.JSONDecoder()


def leading_json(text):
    """La valeur JSON en TETE du texte d'outil ; leve ValueError/TypeError
    si le texte ne commence pas par du JSON.

    #4517 (reouverte 11/11) : l'hote RSM ajoute des pieds de page APRES
    l'enveloppe -- `[NOTIF] N message(s) non lu(s)...`, `[⏱ roosync_dashboard
    NNNms]`. Un `json.loads` du texte entier levait « Extra data » : listing
    illisible, store declare injoignable, repli miroir G: -- le miroir ne
    recoit plus les appends depuis le cut #4131, donc chaque [REPAIRED]
    poste depuis etait invisible et l'organe sonnait une escalade fermee.
    On lit la valeur de tete et on ignore la suite, quelle qu'elle soit.
    """
    if not isinstance(text, str):
        raise TypeError("texte d'outil non chaine")
    payload, _end = _JSON_DECODER.raw_decode(text.lstrip())
    return payload


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
        payload = leading_json(text)
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
    return entries_from_messages(messages)


def entries_from_messages(messages):
    """Entrees depuis une liste `messages[]` serveur — extraction PARTAGEE par
    le store vivant et les archives (#4643) : le meme corps doit rendre le
    meme verdict sur les TROIS surfaces (miroir, store, archive), sinon une
    forme declaree sur l'une serait muette sur l'autre — exactement la famille
    SHOULD-2 que l'union ci-dessous a fermee entre miroir et store.
    """
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
        identifier = message.get("id")
        entries.append({
            "ts": parse_ts(stamp),
            "lane": lane,
            "body": content,
            # #4746 : le messageId du store est un marqueur de portee possible.
            "id": identifier if isinstance(identifier, str) and identifier else None,
            # Union : le champ (API canonique) ET le corps (forme documentee).
            "tags": ({t.strip().lower() for t in raw_tags
                      if isinstance(t, str) and t.strip()}
                     | tags_from_text(content)),
        })
    return entries


def entries_from_archive_json(text):
    """Entrees depuis l'enveloppe JSON d'un `read_archive` fichier (#4643) —
    miroir exact d'`entries_from_store_json` pour la forme `archiveData` : le
    serveur sert les messages archives dans le MEME format IntercomMessage que
    le vivant, lus depuis le fichier .md pose par la condensation.

    Pas de repli markdown ici : `read_archive` n'a jamais servi de corps nu sur
    ce transport, une reponse non-JSON est une erreur d'instrument (levee),
    jamais un « dashboard propre ».

    Limite HERITEE, corrigee cote writer (#4643) : les archives ecrites
    AVANT le correctif ne serialisaient pas la ligne `[tags: ...]` — une
    declaration faite UNIQUEMENT par le parametre `tags` de l'API (sans token
    ni ligne `[tags:]` dans le corps) y perd son tag en etant archivee. Le
    writer corrige (`buildArchiveMessagesMarkdown`) EMET la ligne, et
    `read_archive` la remonte dans le champ `tags` en epurant le contenu ;
    l'union champ + tags du corps (entries_from_messages) rend ce lecteur
    robuste aux DEUX formes. Les archives legacy restent muettes pour les
    declarations API-seules : la fenetre vivante couvre les declarations
    fraiches ; l'echeance (2 cycles) reste bornee par elle.
    """
    try:
        payload = leading_json(text)
    except (TypeError, ValueError):
        raise ValueError("reponse archive non-JSON (pas de repli pour read_archive)")
    if not isinstance(payload, dict):
        raise ValueError("enveloppe archive sans objet racine")
    if payload.get("success") is False:
        detail = payload.get("error") or "sans motif"
        raise ValueError(f"enveloppe archive en echec ({detail})")
    archive_data = payload.get("archiveData")
    if not isinstance(archive_data, dict):
        raise ValueError("enveloppe sans archiveData")
    messages = archive_data.get("messages")
    if not isinstance(messages, list):
        raise ValueError("enveloppe sans archiveData.messages[]")
    return entries_from_messages(messages)


def tool_result_text(result):
    """Texte du contenu d'un resultat MCP, ou None si inutilisable."""
    if not isinstance(result, dict):
        return None
    content = result.get("content")
    if isinstance(content, list) and content and isinstance(content[0], dict):
        return content[0].get("text")
    return None


def archive_rejected_text(result):
    """Texte du rejet serveur (isError) rendu par le transport (#4643),
    ou None. Contrat : avec return_rejected_text=True, call_dashboard_tool
    rend une str SI ET SEULEMENT SI la lecture a ete rejettee en isError —
    le rejet deterministe ne se relance pas, il se classifie."""
    return result if isinstance(result, str) else None


def archive_window_husk_error(key, name, detail):
    """#4796 : erreur de mesure partielle pour une archive de la FENETRE
    rejetee « frontmatter manquant ».

    Depuis un siege, le vide n'est pas une preuve de coque : un fichier
    DriveFS encore en placeholder se rejette exactement comme une coque de
    0 octet (po-2024, 16/11 : archive de 18 messages, [REPAIRED] invisible,
    exit 2 fantome). L'instrument ne peut pas trancher : le rejet entre
    dans les erreurs, le fail-closed rend exit 1 et annule la sonnerie —
    jamais un verdict confiant sur une fenetre partiellement lue.

    #4804 : un nom que la regex ne date PAS n'est pas « de la fenetre » —
    il est conserve faute de preuve d'anciennete, c'est tout ce que
    l'instrument sait en dire. Le rapport le nomme « non datable » au lieu
    de pretendre une appartenance etablie ; le verdict ne change pas.
    """
    dated = archive_name_stamp(name) is not None
    window_label = ("archive de la fenetre" if dated else
                    "archive non datable (nom sans horodatage, conservee "
                    "faute de preuve d'anciennete, #4804)")
    return (f"{key}/{name}: {window_label} rejetee (frontmatter "
            f"manquant) ({detail[:120]}) — coque vide OU archive fraiche "
            f"mal hydratee (placeholder DriveFS, #4796) : un [REPAIRED] ou "
            f"une escalade archivee serait invisible ; mesure partielle")


def store_keys_from_listing(result):
    """Cles de dashboards depuis un `action: list`, ou None (fail-closed :
    une liste illisible ne se sert jamais comme « zero dashboard »)."""
    text = tool_result_text(result)
    if text is None:
        return None
    try:
        payload = leading_json(text)
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


class ReadTelemetry:
    """#4729 (piste 2) : latence et fiabilite de CHAQUE lecture du store.

    Distinction « store lent » / « store mort » par des chiffres : classes
    ok/slow (seuil SLOW_READ_S) /failed, relances posees et recuperees,
    p50/p95/max en millisecondes. Rendu dans la sortie JSON (read_telemetry)
    et en une ligne stderr : un exit 1 sous charge doit etre diagnosable
    par les nombres seuls, sans relire le code ni rejouer la passe.
    """

    def __init__(self, slow_s=SLOW_READ_S):
        self.slow_s = slow_s
        self.calls = 0
        self.failed = 0
        self.retried = 0
        self.recovered = 0
        self._latencies = []
        # #4729 recidive (18/11) : attribution par PHASE des lectures
        # muettes — le transport dit quelle phase MCP est morte ; l'agregat
        # rend le diagnostic sans rejouer la passe.
        self._muted_phases = {}       # phase -> nb de lectures muettes
        self._muted_phase_exc = {}    # "phase:Exception" -> nb
        self._muted_phase_max_ms = {}  # phase -> elapsed_ms max du defaut
        self._muted_no_phase = 0      # muettes sans telemetrie de phase

    def observe(self, seconds, result, telemetry=None):
        """Un appel transport termine : sa duree, et None s'il a echoue.

        #4729 recidive : la telemetrie du transport (si presente) dit
        QUELLE phase a muet l'appel — on l'agrege, un exit 1 sous charge
        se diagnostique par phase (establishment vs appel vs lecture)."""
        self.calls += 1
        if result is None:
            self.failed += 1
            failure = None
            if isinstance(telemetry, dict):
                failure = telemetry.get("failure")
            if isinstance(failure, dict) and failure.get("phase"):
                phase = str(failure["phase"])
                self._muted_phases[phase] = self._muted_phases.get(phase, 0) + 1
                exc_key = f"{phase}:{failure.get('exception') or 'unknown'}"
                self._muted_phase_exc[exc_key] = \
                    self._muted_phase_exc.get(exc_key, 0) + 1
                ms = failure.get("elapsed_ms")
                if isinstance(ms, (int, float)) and \
                        ms > self._muted_phase_max_ms.get(phase,
                                                          float("-inf")):
                    self._muted_phase_max_ms[phase] = ms
            else:
                self._muted_no_phase += 1
        self._latencies.append(seconds)

    def mark_retry(self):
        self.retried += 1

    def mark_recovered(self):
        self.recovered += 1

    def _pct_ms(self, p):
        if not self._latencies:
            return None
        lats = sorted(self._latencies)
        idx = min(len(lats) - 1, int(round(p * (len(lats) - 1))))
        return round(lats[idx] * 1000.0, 1)

    def snapshot(self):
        """Dict machine-readable rendu tel quel dans le JSON de sortie."""
        lats = sorted(self._latencies)
        return {
            "calls": self.calls,
            "ok": self.calls - self.failed,
            "slow": sum(1 for x in lats if x >= self.slow_s),
            "failed": self.failed,
            "retried": self.retried,
            "recovered": self.recovered,
            "slow_threshold_s": self.slow_s,
            "p50_ms": self._pct_ms(0.50),
            "p95_ms": self._pct_ms(0.95),
            "max_ms": round(lats[-1] * 1000.0, 1) if lats else None,
            # #4729 recidive : phase(s) des lectures muettes
            "muted_by_phase": dict(self._muted_phases),
            "muted_exceptions": dict(self._muted_phase_exc),
            "muted_phase_max_ms": {k: round(v, 1)
                                   for k, v in self._muted_phase_max_ms.items()},
            "muted_no_phase": self._muted_no_phase,
        }

    def render(self):
        """Une ligne stderr, pour le run texte comme pour le run --json."""
        s = self.snapshot()
        line = (f"telemetrie lectures store : {s['calls']} appel(s), "
                f"{s['ok']} ok dont {s['slow']} lent(s) >= {self.slow_s:g} s, "
                f"{s['failed']} muet(s) ; relances {s['retried']} "
                f"({s['recovered']} recuperee(s)) ; p50 {s['p50_ms']} ms, "
                f"p95 {s['p95_ms']} ms, max {s['max_ms']} ms")
        if s["muted_by_phase"]:
            detail = ", ".join(f"{p}x{n}"
                               for p, n in sorted(s["muted_by_phase"].items()))
            line += f" ; muets par phase : {detail}"
        return line


def load_entries_from_store(url, bearer, timeout=10.0, intercom_limit=200,
                            now=None, window_hours=None,
                            archive_window_hours=DEFAULT_ARCHIVE_WINDOW_HOURS,
                            archive_time_budget=DEFAULT_ARCHIVE_TIME_BUDGET_S,
                            telemetry=None):
    """Dashboards servis par le STORE (PG), meme transport que la sonnerie
    (review #4519 point c : les dashboards sont servis par PG ; le miroir G:
    gele apres le cut #4131 donnerait un faux « tout va bien » confiant).

    Rend (entries, errors, keys) — la meme signature que load_entries PLUS
    les cles lues (denominateur du rapport d'erreurs, #4643 : `paths`
    restait vide en source store et le message disait « sur 0 ») — ou None
    si le store est injoignable en entree (list illisible) : l'appelant
    decide alors du repli miroir, qui DEGRADE le verdict quand PG etait
    configure.

    Fenetre : les `intercom_limit` dernieres entrees PAR dashboard, et la
    couverture est VERIFIEE, pas supposee (review Hermes 04/11, reserve 1) :
    si `now` et `window_hours` sont donnes et que la plus ancienne entree lue
    d'un dashboard est PLUS RECENTE que le debut de fenetre, le dashboard
    rend une erreur — une escalade anterieure serait invisible, et le silence
    est exactement ce que l'organe existe pour rompre. Defaut 200 : mesure
    Hermes 04/11 (debits reels/nuit : CoursIA 12,85/h, cluster 7,25/h,
    roo-extensions 3,9/h) -> 200 entrees couvrent > 8 h partout ; la verif
    de couverture rend la constante auto-prouvee, pas crue sur parole.

    #4643 : la fenetre vivante ne suffit plus des qu'une condensation passe —
    elle retirait du vif un `[REPAIRED]` (sonnerie recurrente apres reparation
    documentee) ou l'escalade elle-meme (faux negatif). Chaque dashboard lit
    donc AUSSI ses archives de condensation creees dans
    `archive_window_hours` (defaut 48 h ; 0 desactive). Un listing d'archives
    illisible est une erreur d'instrument : « je ne vois pas les archives »
    est exactement l'angle mort, jamais un « aucune archive ». La symetrie de
    la fenetre etait le defaut (rouverte 14/11) : une escalade crossPostee
    survit plus longtemps que sa fermeture, qui sort de la fenetre avant elle.
    `second_pass_old_closures` relit donc les archives du workspace de la lane
    jusqu'a la date de pose de toute escalade encore ouverte et anterieure a
    la fenetre ; un budget epuise y est une erreur d'instrument (exit 1).

    #4661 : la passe d'archives est bornee par `archive_time_budget`
    (defaut 900 s — couvre la passe saine mesuree a 669 s, #4643 ;
    0/negatif = illimite). Le budget est GLOBAL a la passe,
    initialise au premier appel d'archive — les lectures vivantes ne le
    consomment pas. Au-dela, les archives restantes sont SAUTEES et la
    fenetre est declaree partiellement aveugle (erreur d'instrument, sortie 1
    par le fail-closed) : mieux vaut une mesure partielle rendue en temps
    borne qu'un organe muet pendant 15 minutes de lectures sequentielles
    (mesure motivante : 68 timeouts x 10 s sur un G: gele).

    #4643 (coques vides + timeouts clients) : une lecture d'archive MUETTE
    (transport None) est relancee UNE fois a timeout etendu — timeout client
    sporadique sur une archive saine (5 releves sur des fichiers de 32-39 Ko).
    Un rejet serveur isError ne se relance pas (deterministe, 7 ms mesures
    post-gel, c.6823202164) : son texte, rendu par le transport avec
    return_rejected_text, se classifie — signature coque sur une archive de
    la fenetre = lecture partielle #4796 (le vide ne prouve pas la coque
    depuis un siege : placeholder DriveFS), tout autre rejet = erreur
    d'instrument.

    #4729 : la relance muette est GENERALISEE a toutes les lectures (listing,
    vif, listings d'archives, fichiers d'archives, seconde passe) — sous
    charge flotte le chemin direct timeout sporadiquement, alors que le
    store repond (appends MCP de la meme fenetre). Chaque lecture est en
    plus MESUREE (ReadTelemetry) : l'appelant rend les chiffres, un exit 1
    sous charge se diagnostique sans rejouer la passe.
    """
    call = _load_transport()
    tel = telemetry if telemetry is not None else ReadTelemetry()

    # #4729 : TOUTES les lectures passent par la meme garde — mesure de
    # latence + relance UNE fois a timeout etendu sur echec MUET (transport
    # None). Signature celle du transport : la seconde passe recoit
    # `read_store` comme `call`, sans savoir qu'elle est gardee.
    def read_store(arguments, _url=None, _bearer=None, timeout_s=None,
                   return_rejected_text=False, **_ignored):
        first_s = timeout_s if timeout_s is not None else timeout
        call_telemetry = {}
        t0 = time.monotonic()
        result = call(arguments, url, bearer, timeout=first_s,
                      return_rejected_text=return_rejected_text,
                      telemetry=call_telemetry)
        tel.observe(time.monotonic() - t0, result, call_telemetry)
        if result is None:
            tel.mark_retry()
            call_telemetry = {}
            t0 = time.monotonic()
            result = call(arguments, url, bearer,
                          timeout=STORE_READ_RETRY_TIMEOUT_S,
                          return_rejected_text=return_rejected_text,
                          telemetry=call_telemetry)
            tel.observe(time.monotonic() - t0, result, call_telemetry)
            if result is not None:
                tel.mark_recovered()
        return result

    keys = store_keys_from_listing(read_store({"action": "list"}))
    if keys is None:
        return None
    entries = []
    errors = []
    window_start = (now - timedelta(hours=window_hours)
                    if now is not None and window_hours else None)
    # #4661 : echeance du budget d'archives, construite paresseusement au
    # premier appel d'archive (None = illimite ou passe non encore entamee).
    archive_deadline = None
    for key in keys:
        result = read_store(read_arguments_for_key(key, intercom_limit))
        text = tool_result_text(result)
        if text is None:
            errors.append(f"{key}: lecture store sans contenu (relance incluse)")
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
        # #4643 : le vif condense n'est qu'une PARTIE de la verite — les
        # archives recentes portent les declarations evacuees.
        # #4661 : la passe d'archives est BORNEE. Le budget est initialise au
        # PREMIER appel d'archive de la passe (pas a l'entree de la fonction) :
        # les lectures vivantes qui precedent ne le consomment pas, et une
        # execution sans archives ne construit aucun chronometre.
        if archive_window_hours:
            if archive_deadline is None:
                archive_deadline = (
                    time.monotonic() + archive_time_budget
                    if archive_time_budget and archive_time_budget > 0
                    else None)
            if (archive_deadline is not None
                    and time.monotonic() > archive_deadline):
                errors.append(
                    f"{key}: budget d'archives epuise "
                    f"({archive_time_budget:.0f} s) — archives sautees ; la "
                    f"fenetre d'archives est PARTIELLEMENT AVEUGLE, un "
                    f"[REPAIRED] ou une escalade archivee serait invisible")
                continue
            listing = read_store(read_archive_arguments_for_key(key))
            names = archive_names_from_listing(listing)
            if names is None:
                errors.append(f"{key}: listing des archives illisible — la "
                              f"fenetre d'archives est AVEUGLE, un [REPAIRED] "
                              f"ou une escalade archivee serait invisible")
                continue
            recent_archives = select_recent_archives(names, now,
                                                     archive_window_hours)
            for index, name in enumerate(recent_archives):
                if (archive_deadline is not None
                        and time.monotonic() > archive_deadline):
                    skipped = len(recent_archives) - index
                    errors.append(
                        f"{key}: budget d'archives epuise "
                        f"({archive_time_budget:.0f} s) — {skipped} archive(s) "
                        f"restante(s) sauteee(s) ; la fenetre d'archives est "
                        f"PARTIELLEMENT AVEUGLE, un [REPAIRED] ou une escalade "
                        f"archivee serait invisible")
                    break
                # #4643 -> #4729 : la relance muette vit dans read_store —
                # meme contrat (UNE relance a timeout etendu sur None, un
                # rejet serveur isError ne se relance pas : deterministe,
                # 7 ms mesures post-gel, c.6823202164).
                archive_result = read_store(
                    read_archive_arguments_for_key(key, archive_file=name),
                    return_rejected_text=True)
                rejected = archive_rejected_text(archive_result)
                if rejected is not None:
                    # #4643 : rejet serveur isError, texte rendu par le
                    # transport (opt-in). Tout rejet autre que la signature
                    # coque = erreur d'instrument.
                    # #4796 : la signature « frontmatter manquant » sur une
                    # archive de la FENETRE n'est plus un WARN — depuis un
                    # siege, le vide ne prouve pas la coque (placeholder
                    # DriveFS encore vide, mesure po-2024 16/11) : lecture
                    # partielle, comme un dashboard illisible.
                    if ARCHIVE_HUSK_SIGNATURE in rejected.lower():
                        errors.append(archive_window_husk_error(key, name,
                                                                rejected))
                    else:
                        errors.append(f"{key}/{name}: rejet serveur "
                                      f"({rejected[:120]})")
                    continue
                archive_text = tool_result_text(archive_result)
                if archive_text is None:
                    errors.append(f"{key}/{name}: lecture archive sans "
                                  f"contenu (relance incluse)")
                    continue
                try:
                    structured = entries_from_archive_json(archive_text)
                except ValueError as exc:
                    if ARCHIVE_HUSK_SIGNATURE in str(exc).lower():
                        # #4643 -> #4796, couche JSON : une enveloppe en
                        # echec portant la signature husk garde le meme
                        # traitement que la couche transport — dans la
                        # fenetre, lecture partielle, pas un WARN.
                        errors.append(archive_window_husk_error(key, name,
                                                                str(exc)))
                    else:
                        errors.append(f"{key}/{name}: enveloppe archive "
                                      f"inexploitable ({exc})")
                    continue
                entries.extend(structured)
    # #4643 (rouverte 14/11) : la fenetre d'archives est SYMETRIQUE, et c'est
    # le defaut — une escalade crossPostee survit plus longtemps que sa
    # fermeture, postee sur le seul dashboard de sa lane. Pour une escalade
    # encore ouverte et posee AVANT la coupure d'archives, une seconde passe
    # relit les archives du workspace de sa lane jusqu'a sa date de pose (meme
    # budget #4661). `now` absent = aucune datation possible : pas de passe.
    archive_cutoff = (now - timedelta(hours=archive_window_hours)
                      if now is not None and archive_window_hours else None)
    if archive_cutoff is not None:
        extra_closures, pass_errors = second_pass_old_closures(
            entries, keys, archive_cutoff, read_store, url, bearer, timeout,
            archive_deadline)
        entries.extend(extra_closures)
        errors.extend(pass_errors)
    return entries, errors, keys


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
    # #4730 : un defaut connu de l'hote reste une escalade due, mais aucune
    # lane ne peut le reparer : il est range A PART, apres les pannes
    # reparables, pour ne pas noyer celles-ci.
    repairable = [i for i in overdue if not i.get("known_defect")]
    host = [i for i in overdue if i.get("known_defect")]
    if repairable:
        headline = (f"[ASK-USER][DEGRADED-ESCALATION] {len(repairable)} "
                    f"escalade(s) d'environnement degrade non reparee(s) dans "
                    f"les delais")
        if host:
            headline += (f" ; {len(host)} autre(s) rangee(s) a part : defaut "
                         f"connu de l'hote, qu'aucune lane ne peut reparer.")
        else:
            headline += "."
        lines = [headline]
    else:
        lines = [f"[ASK-USER][DEGRADED-ESCALATION] aucune panne reparable en "
                 f"retard ; {len(host)} escalade(s) rangee(s) a part : defaut "
                 f"connu de l'hote."]
    for item in repairable:
        lines.append(strip_declaration_tokens(
            f"- {item['lane']} — degrade depuis {item['posted']}, "
            f"echeance {item['deadline']} depassee : {item['excerpt'][:120]}"))
    if host:
        lines.append("Rangees a part -- defaut connu de l'hote (toujours "
                     "ouvertes, rien n'est declare repare) :")
        for item in host:
            lines.append(strip_declaration_tokens(
                f"- {item['lane']} — degrade depuis {item['posted']}, "
                f"echeance {item['deadline']} depassee : "
                f"[{item['known_defect']}] {item['excerpt'][:120]}"))
    lines.append("Le mecanisme porte l'echeance, pas la memoire de la lane : "
                 "un `REPAIRED` de la lane ferme l'escalade ; un bilan de "
                 "cycle ne ferme rien.")
    return "\n".join(lines)


def build_ring_id(overdue, now=None):
    """Cle d'idempotence (#3276) : empreinte du lot + tranche de 24 h.

    Meme lot -> UNE sonnerie par jour, pas une par tick ; un lot qui change
    produit un id neuf ; le lendemain re-sonne tant que rien n'est repare.

    La cle ne porte PAS l'hote, et le lot est trie avant l'empreinte : deux
    sieges qui mesurent le meme lot le meme jour calculent le meme id, et
    l'append du dashboard ignore un id deja present. La regle demande a CHAQUE
    lane de sonner sur un exit 2 ; avec l'hote dans la cle, chaque siege
    postait sa propre entree (review #4677).

    #4730 : l'empreinte porte le lot REPARABLE des qu'il y en a un (sinon tout
    le lot). Un defaut connu de l'hote qui s'ajoute ne doit pas re-sonner le
    meme jour alors que le lot reparable n'a pas bouge -- sinon chaque nouvelle
    escalade d'un defaut qu'aucune lane ne peut reparer re-sonne le user sur
    des pannes deja rangees a part.
    """
    now = now or time.time()
    repairable = [i for i in overdue if not i.get("known_defect")]
    lot = repairable or overdue
    payload = "|".join(sorted(f"{i['lane']}:{i['posted']}" for i in lot))
    digest = hashlib.md5(payload.encode("utf-8")).hexdigest()[:12]
    return f"degraded-escalation-{digest}-{int(now // 86400)}"


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


# #4672 : le fichier d'environnement deploye par le lanceur compagnon
# (run-approval-stall-detector.ps1 / install-approval-stall-detector-task.ps1
# -BotEnvFile). L'organe le lit lui-meme : la commande canonique ne doit
# exiger aucun sourcing manuel du bearer.
ORGAN_ENV_FILE = Path.home() / ".roo-state-manager" / "stall-detector.env"

# Seules ces cles sont lues : un fichier d'environnement peut porter bien
# d'autres secrets, l'organe ne materialise jamais les valeurs inutilisees.
_ORGAN_ENV_KEYS = ("MCP_PROXY_BEARER", "MCP_PROXY_BASE_URL", "MCP_PROXY_URL")


def load_organ_env_file(path):
    """Lit le fichier d'environnement de l'organe — rend (values, warning).

    Analyse uniquement des lignes nommees `CLE=valeur` (guillemets optionnels),
    jamais de sourcing shell. Fichier absent : pas un echec (#4672 — ai-01 n'a
    pas ce fichier, son bearer vient de l'environnement de son lanceur) : dict
    vide, pas de warning. Fichier present mais illisible, mal decode ou porteur
    de lignes inexploitables : warning, pour que l'appelant ne rende pas un
    « sain » confiant sur une configuration qu'il n'a pas pu lire ; le
    fail-closed existant (sans bearer, pas de lecture store) reste la garantie.
    Aucune valeur — lue ou non — n'apparait dans le warning ni dans une
    exception.
    """
    if path is None or not str(path).strip():
        return {}, None
    p = Path(path)
    try:
        text = p.read_text(encoding="utf-8-sig")
    except FileNotFoundError:
        return {}, None
    except (OSError, UnicodeDecodeError) as exc:
        return {}, (f"fichier d'environnement illisible ({p}) : "
                    f"{type(exc).__name__} — aucun secret n'en a ete lu")
    values = {}
    malformed = 0
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$", line)
        if not m:
            if "=" in line:
                malformed += 1
            continue
        key, value = m.group(1), m.group(2).strip()
        if key not in _ORGAN_ENV_KEYS:
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        if not value:
            malformed += 1
            continue
        values.setdefault(key, value)
    if malformed:
        return values, (f"fichier d'environnement partiellement inexploitable "
                        f"({p}) : {malformed} ligne(s) sans CLE=valeur valide")
    return values, None


def resolve_proxy_config(cli_url, cli_bearer, file_values):
    """Resolution de la config proxy (#4672), precedence explicite :

        CLI > environnement du processus > fichier d'environnement > defaut

    Accepte `MCP_PROXY_URL` et `MCP_PROXY_BASE_URL` (l'un comme l'autre, dans
    cet ordre) a chaque etage ou la cle existe. Bearer et URL se resolvent
    independamment : un CLI partiel garde la provenance du reste de la chaine.

    Un `--ring-bearer ""` EXPLICITE veut dire « aucun bearer » : il masque
    l'environnement ET le fichier. Une chaine de `or` sautait la valeur vide et
    reprenait le bearer ambiant — une suite de tests lancee dans un shell qui
    exporte un vrai bearer pouvait alors publier pour de bon (review #4677).
    Seul l'argument ABSENT (None) laisse parler les etages suivants.
    """
    file_values = file_values or {}
    if cli_bearer is not None:
        bearer = cli_bearer or None
    else:
        bearer = (os.environ.get("MCP_PROXY_BEARER")
                  or file_values.get("MCP_PROXY_BEARER"))
    url = (cli_url
           or os.environ.get("MCP_PROXY_URL")
           or os.environ.get("MCP_PROXY_BASE_URL")
           or file_values.get("MCP_PROXY_URL")
           or file_values.get("MCP_PROXY_BASE_URL")
           or "https://mcp-tools.myia.io")
    return url, bearer


def publish_ring(overdue, url, bearer, timeout=10.0, now=None):
    """Poste la sonnerie. Rend `"posted"`, `"deduplicated"` ou None.

    `"deduplicated"` : le serveur a reconnu l'id (un autre passage, ou un autre
    siege, a deja sonne ce lot aujourd'hui) et n'a rien ecrit — la sonnerie
    EXISTE, c'est un succes. None : la sonnerie n'est pas partie.
    """
    arguments = {
        "action": "append",
        "type": "global",
        "tags": ["ASK-USER", "DEGRADED-ESCALATION"],
        "content": build_ring_content(overdue),
        "messageId": build_ring_id(overdue, now=now),
    }
    result = _load_transport()(arguments, url, bearer, timeout=timeout,
                               client="degraded-escalations")
    if result is None:
        return None
    try:
        envelope = leading_json(tool_result_text(result))
    except (TypeError, ValueError):
        return "posted"
    if isinstance(envelope, dict) and envelope.get("deduplicated") is True:
        return "deduplicated"
    return "posted"


def verdict(escalations):
    """(exit_code, reason). Contrat de sortie, en un seul endroit."""
    overdue = [e for e in escalations if e["status"] == "overdue"]
    waiting = [e for e in escalations if e["status"] == "waiting"]
    if overdue:
        # #4730 : le code ne change pas ; la raison dit seulement combien
        # d'echeances relevent d'un defaut que personne ne peut reparer.
        host = sum(1 for e in overdue if e.get("known_defect"))
        if host:
            return 2, (f"{len(overdue)} echeance(s) depassee(s) sans [REPAIRED], "
                       f"dont {host} sur defaut connu de l'hote")
        return 2, f"{len(overdue)} echeance(s) depassee(s) sans [REPAIRED]"
    if waiting:
        return 3, f"{len(waiting)} escalade(s) ouverte(s), dans les delais"
    return 0, "aucune escalade [DEGRADED]"


def report(escalations, code, reason, as_json, stream=None,
           read_telemetry=None):
    # stream resolu a l'APPEL, pas au def : un defaut `stream=sys.stdout` est
    # evalue au chargement du module — un test (ou un appelant) qui redirige
    # sys.stdout ecrirait quand meme dans le vrai stdout (#4729, trouve en
    # testant la telemetrie JSON).
    stream = sys.stdout if stream is None else stream
    counts = {status: sum(1 for e in escalations if e["status"] == status)
              for status in ("overdue", "waiting", "repaired")}
    if as_json:
        totals = dict(counts)
        # #4730 : sous-compte des defauts connus de l'hote -- une lecture
        # machine doit distinguer ce qu'aucune lane ne peut reparer.
        totals["overdue_known_defect"] = sum(
            1 for e in escalations
            if e["status"] == "overdue" and e.get("known_defect"))
        payload = {"exit": code, "reason": reason, "totals": totals,
                   "escalations": escalations,
                   # #4746 : ce qu'un [REPAIRED] sans portee a ferme.
                   "repair_notices": repair_notices(escalations)}
        if read_telemetry is not None:
            # #4729 (piste 2) : les chiffres de lecture dans le verdict
            # machine — « store lent » vs « store mort » se distingue en
            # lisant la sortie, pas en rejouant la passe.
            payload["read_telemetry"] = read_telemetry.snapshot()
        print(json.dumps(payload, ensure_ascii=False, indent=2), file=stream)
        return
    for item in escalations:
        mark = {"overdue": "SONNERIE", "waiting": "ouverte", "repaired": "close "}[item["status"]]
        suffix = ""
        if item["status"] == "overdue" and item.get("known_defect"):
            # #4730 : du, mais hors de portee de toute lane.
            mark = "A-PART"
            suffix = f" [defaut connu de l'hote {item['known_defect']}]"
        print(f"{mark:<8} {item['lane']:<38} postee {item['posted']} "
              f"echeance {item['deadline']}")
        print(f"         {item['excerpt'][:120]}{suffix}")
    # #4746 : la lane voit ce qu'un [REPAIRED] SANS portee vient de fermer
    # (N >= 2 seulement — une fermeture unique est le cas nominal).
    for notice in repair_notices(escalations):
        print(notice)
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
            # #4730 : escalade d'un defaut CONNU de l'hote (worktree
            # d'isolation des sous-agents refuse par le harnais, #3345),
            # paraphrasant un post reel. Due comme les autres, rangee a part.
            "host-defect.md": """### [2026-11-02T22:00:00.000Z] myia-i|ws

[DEGRADED] Isolation sous-agent : deux creations de worktree refusees par
le harnais au motif que Git resoudrait hors isolation
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

        # #4730 -- un defaut CONNU de l'hote (RX160 (a)) : reconnu a la citation
        # de l'issue ou a la conjonction worktree + refus + isolation/sous-agent,
        # jamais a "worktree" seul. Textes paraphrases des posts reels.
        for text in (
            "Comparatif thinking : creation de sous-agent isole refusee par le "
            "harnais (resolution git du worktree vers un chemin exterieur), "
            "deux tentatives",
            "Diagnostic isolation : git rev-parse depuis chacun des deux "
            "worktrees refuses rend son propre dossier comme top-level",
            "Isolation sous-agent : deux creations de worktree refusees par "
            "le harnais au motif que Git resoudrait hors isolation",
            "Delegation Agent avec isolation worktree refusee par la garde : "
            "core.worktree redirect, les commandes ecriraient hors du worktree",
            "defaut connu #3345, worktree refuse",
        ):
            assert classify_known_host_defect(text) == "#3345", text
        for text in (
            "inbox RooSync fail-closed pg-unavailable",
            "le MCP playwright n'est pas joignable",
            "D: mesure a 87,94 Gio libres",
            "worktree nettoye, cycle repris",
            "worktree refuse, sans responsable designe",
            "git worktree remove refuse : worktree sale, l'agent relance",
        ):
            assert classify_known_host_defect(text) is None, text
        # Frontiere de chiffre : `#33450` n'est pas `#3345`.
        assert classify_known_host_defect("#33450 autre defaut") is None
        assert classify_known_host_defect("") is None
        # Temoin negatif : une escalade ordinaire n'est pas classee.
        assert overdue[0]["known_defect"] is None, overdue[0]

        # Rien ne le declare repare : le defaut de l'hote reste une escalade DUE.
        host_items = collect_escalations(load_entries([root / "host-defect.md"])[0], now)
        assert len(host_items) == 1, host_items
        assert host_items[0]["known_defect"] == "#3345", host_items
        assert host_items[0]["status"] == "overdue", host_items
        assert verdict(host_items) == (
            2, "1 echeance(s) depassee(s) sans [REPAIRED], dont 1 sur defaut "
               "connu de l'hote"), verdict(host_items)
        # Lot mixte : le compte porte sur TOUTES les echeances, le "dont" sur
        # les seuls defauts de l'hote.
        mixed = overdue + host_items
        assert verdict(mixed) == (
            2, "2 echeance(s) depassee(s) sans [REPAIRED], dont 1 sur defaut "
               "connu de l'hote"), verdict(mixed)

        # #4730 -- la sonnerie range les defauts de l'hote APRES les pannes
        # reparables, sous une section nommee, et ne porte aucun token.
        host_line = ("Rangees a part -- defaut connu de l'hote (toujours "
                     "ouvertes, rien n'est declare repare) :")
        ring = build_ring_content(mixed)
        assert ring.index("myia-c|ws") < ring.index(host_line) < ring.index("myia-i|ws"), ring
        assert ("1 autre(s) rangee(s) a part : defaut connu de l'hote, "
                "qu'aucune lane ne peut reparer.") in ring, ring
        assert "[#3345]" in ring, ring
        assert not DECLARATION_TOKEN_RE.search(ring), ring
        # Lot SANS panne reparable : entete dediee, jamais un "0 escalade(s)"
        # qui laisserait croire a un lot propre.
        host_ring = build_ring_content(host_items)
        assert host_ring.startswith(
            "[ASK-USER][DEGRADED-ESCALATION] aucune panne reparable en retard "
            "; 1 escalade(s) rangee(s) a part : defaut connu de l'hote."), host_ring
        # Les tokens cites en prose restent assainis, section hote comprise.
        noisy_host = [dict(host_items[0],
                           excerpt="defaut `[DEGRADED]` puis `[REPAIRED]` en prose")]
        assert not DECLARATION_TOKEN_RE.search(build_ring_content(noisy_host)), \
            build_ring_content(noisy_host)

        # #4730 -- l'empreinte porte le lot REPARABLE : une escalade de defaut
        # connu qui s'ajoute ne re-sonne pas le meme jour...
        assert build_ring_id(overdue, now=1750000000) == \
            build_ring_id(mixed, now=1750000000)
        # ... et quand il n'y a QUE des defauts de l'hote, leur lot compte.
        assert build_ring_id(host_items, now=1750000000) != build_ring_id(
            [dict(host_items[0], posted="2026-11-02T23:00:00Z")], now=1750000000)

        # Sortie : la marque A-PART (texte) et le sous-compte (JSON).
        text_out = io.StringIO()
        with contextlib.redirect_stdout(text_out):
            report(mixed, *verdict(mixed), False)
        assert "A-PART" in text_out.getvalue(), text_out.getvalue()
        assert "[defaut connu de l'hote #3345]" in text_out.getvalue(), \
            text_out.getvalue()
        json_out = io.StringIO()
        report(mixed, *verdict(mixed), True, stream=json_out)
        totals = json.loads(json_out.getvalue())["totals"]
        assert totals["overdue_known_defect"] == 1, totals

        # #4643 — dedoublonnage crossPost : la MEME declaration (meme lane,
        # meme horodatage) servie par deux dashboards n'ouvre QU'UNE escalade.
        crossposted = (load_entries([root / "overdue.md"])[0]
                       + load_entries([root / "overdue.md"])[0])
        doubled = collect_escalations(crossposted, now)
        assert len(doubled) == 1, doubled
        # Et deux declarations d'une meme lane a deux instants differents
        # restent deux escalades distinctes (le dedup ne fusionne pas tout).
        twice = (load_entries([root / "overdue.md"])[0]
                 + load_entries([root / "waiting.md"])[0])
        assert len(collect_escalations(twice, now)) == 2

        # #4643 — enveloppe archive : la forme archiveData se parse comme le
        # vivant (champs + union des tags du corps), l'echec est fail-closed.
        archive_envelope = json.dumps({
            "success": True, "action": "read_archive",
            "archiveData": {"key": "workspace-x",
                            "archivedAt": "2026-11-03T04:00:00.001Z",
                            "messageCount": 1,
                            "messages": [{
                                "id": "m-1", "timestamp": "2026-11-03T02:00:00Z",
                                "author": {"machineId": "myia-a", "workspace": "ws"},
                                "content": "[REPAIRED] tout est revenu"}]}})
        archived = entries_from_archive_json(archive_envelope)
        assert len(archived) == 1 and is_repaired(archived[0]), archived
        try:
            entries_from_archive_json(
                json.dumps({"success": False, "error": "store inaccessible"}))
            raise AssertionError("enveloppe archive en echec doit lever")
        except ValueError:
            pass
        try:
            entries_from_archive_json("## Intercom (pas du JSON)")
            raise AssertionError("reponse archive non-JSON doit lever")
        except ValueError:
            pass

        # #4643 — listing d'archives : None (illisible) se distingue de []
        # (dashboard sans archive, legitime).
        listing = json.dumps({"success": True, "archives": [
            "workspace-x-2026-11-03T04-00-00.md",
            "workspace-x-2026-10-01T00-00-00.md"]})
        assert archive_names_from_listing(
            {"content": [{"type": "text", "text": listing}]}) == [
            "workspace-x-2026-11-03T04-00-00.md",
            "workspace-x-2026-10-01T00-00-00.md"]
        assert archive_names_from_listing(
            {"content": [{"type": "text", "text": json.dumps(
                {"success": True, "archives": []})}]}) == []
        assert archive_names_from_listing(None) is None

        # #4643 — fenetre d'archives : le nom horodate hors fenetre est
        # ecarte, le nom sans horodatage parsable reste lu (couverture
        # conservatrice), 0 desactive tout filtrage.
        names = ["workspace-x-2026-11-03T04-00-00.md",
                 "workspace-x-2026-10-01T00-00-00.md",
                 "workspace-x-sans-date.md"]
        assert select_recent_archives(names, now, 48.0) == [
            "workspace-x-2026-11-03T04-00-00.md",
            "workspace-x-sans-date.md"]
        assert select_recent_archives(names, now, 0) == names

        # #4643 — l'identification des lectures d'archives est CELLE du read
        # vivant : machineId pour machine-*, workspace pour workspace-*.
        assert read_archive_arguments_for_key("machine-myia-x") == {
            "action": "read_archive", "type": "machine", "machineId": "myia-x"}
        assert read_archive_arguments_for_key("global") == {
            "action": "read_archive", "type": "global"}
        assert read_archive_arguments_for_key(
            "workspace-y", archive_file="workspace-y-2026-11-03T04-00-00.md") == {
            "action": "read_archive", "type": "workspace", "workspace": "y",
            "archiveFile": "workspace-y-2026-11-03T04-00-00.md"}

        # #4661 — budget GLOBAL de la passe d'archives : un transport dont
        # chaque lecture d'archive depasse le budget laisse (a) les entrees
        # VIVANTES intactes, (b) une erreur nommant le budget (fenetre
        # partiellement aveugle), (c) moins d'appels d'archives que
        # d'archives disponibles. Le transport est injecte comme en
        # production (aucun reseau).
        live_envelope = json.dumps({
            "success": True,
            "data": {"intercom": {"messages": [{
                "id": "live-1", "timestamp": "2026-11-03T10:00:00Z",
                "author": {"machineId": "myia-a", "workspace": "ws"},
                "content": "[DONE] cycle normal", "tags": []}]}}})
        budget_names = [f"workspace-x-2026-11-03T04-0{i}-00.md"
                        for i in range(3)]
        budget_calls = {"archive_files": 0}

        def budget_fake_call(arguments, url, bearer, timeout=10.0,
                             client="x", return_rejected_text=False):
            action = arguments.get("action")
            if action == "list":
                return {"content": [{"type": "text", "text": json.dumps(
                    {"success": True,
                     "dashboards": [{"key": "workspace-x"}]})}]}
            if action == "read":
                return {"content": [{"type": "text", "text": live_envelope}]}
            if "archiveFile" not in arguments:
                return {"content": [{"type": "text", "text": json.dumps(
                    {"success": True, "archives": budget_names})}]}
            time.sleep(0.05)  # chaque lecture d'archive depasse le budget
            budget_calls["archive_files"] += 1
            return {"content": [{"type": "text", "text": json.dumps({
                "success": True, "archiveData": {"messages": []}})}]}

        saved_transport = _load_transport
        try:
            # Injecte la FABRIQUE (load_entries_from_store appelle
            # `_load_transport()` pour obtenir `call`), pas la fonction.
            globals()["_load_transport"] = lambda: budget_fake_call
            budget_entries, budget_errors, _ = load_entries_from_store(
                None, "bearer", timeout=1.0, now=now, window_hours=8.0,
                archive_window_hours=48.0, archive_time_budget=0.01)
        finally:
            globals()["_load_transport"] = saved_transport
        assert (len(budget_entries) == 1
                and budget_entries[0]["body"] == "[DONE] cycle normal"), \
            budget_entries
        assert any("budget d'archives" in err for err in budget_errors), \
            budget_errors
        assert budget_calls["archive_files"] < len(budget_names), \
            budget_calls

        # #4643 (c.6823202164) -> #4796 — rejet serveur isError VERBATIM,
        # texte rendu par le transport (opt-in return_rejected_text) au
        # PREMIER appel — deterministe (7 ms mesures post-gel), la relance
        # relirait le meme rejet. Depuis #4796, une archive FRAICHE (dans la
        # fenetre de 48 h) rejetee « frontmatter manquant » vaut LECTURE
        # PARTIELLE (erreur d'instrument) : depuis un siege, le vide ne
        # prouve pas la coque. Entrees vivantes intactes, AUCUNE relance.
        _spec = importlib.util.spec_from_file_location(
            "detect_approval_stalls_selftest",
            Path(__file__).resolve().parent / "detect-approval-stalls.py")
        transport_module = importlib.util.module_from_spec(_spec)
        _spec.loader.exec_module(transport_module)
        VERBATIM_HUSK_ENVELOPE = {
            "_meta": {"durationMs": 7, "toolName": "roosync_dashboard"},
            "content": [{"type": "text", "text":
                         "Error: Format archive invalide: frontmatter "
                         "manquant dans G:\\Mon Drive\\RooSync\\dashboards\\"
                         "archives\\workspace-x-2026-11-03T04-00-00.md"}],
            "isError": True,
        }
        # Le helper du transport rend bien le texte de l'enveloppe verbatim :
        # le selftest exerce la VRAIE extraction, pas une forme reinventee.
        verbatim_husk_text = transport_module.rejected_text_from_result(
            VERBATIM_HUSK_ENVELOPE)
        assert verbatim_husk_text is not None and \
            ARCHIVE_HUSK_SIGNATURE in verbatim_husk_text.lower(), \
            verbatim_husk_text
        husk_reads = []

        def husk_fake_call(arguments, url, bearer, timeout=10.0, client="x",
                           return_rejected_text=False):
            action = arguments.get("action")
            if action == "list":
                return {"content": [{"type": "text", "text": json.dumps(
                    {"success": True,
                     "dashboards": [{"key": "workspace-x"}]})}]}
            if action == "read":
                return {"content": [{"type": "text", "text": live_envelope}]}
            if "archiveFile" not in arguments:
                return {"content": [{"type": "text", "text": json.dumps(
                    {"success": True,
                     "archives": ["workspace-x-2026-11-03T04-00-00.md"]})}]}
            husk_reads.append((timeout, return_rejected_text))
            # Contrat transport #4643 : avec l'opt-in, un rejet isError rend
            # son TEXTE (str) — la forme exacte que le serveur produit.
            return verbatim_husk_text

        try:
            globals()["_load_transport"] = lambda: husk_fake_call
            husk_entries, husk_errors, husk_keys = load_entries_from_store(
                None, "bearer", timeout=1.0, now=now, window_hours=8.0)
        finally:
            globals()["_load_transport"] = saved_transport
        # #4796 : l'archive (04:00, dans la fenetre de 48 h) est FRAICHE —
        # son rejet « frontmatter manquant » vaut lecture partielle, pas une
        # coque prouvee : UNE erreur d'instrument nommant le fichier, les
        # entrees vivantes restant intactes.
        assert husk_keys == ["workspace-x"], husk_keys
        assert (len(husk_errors) == 1
                and "mesure partielle" in husk_errors[0]
                and "workspace-x-2026-11-03T04-00-00.md" in husk_errors[0]), \
            husk_errors
        assert (len(husk_entries) == 1
                and husk_entries[0]["body"] == "[DONE] cycle normal"), \
            husk_entries
        # UN SEUL appel, avec l'opt-in — le rejet deterministe ne se relance
        # PAS (mesure ai-01 : 7 ms, la relance relirait le meme rejet).
        assert husk_reads == [(1.0, True)], husk_reads

        # #4643 — tout AUTRE rejet isError reste une erreur d'instrument :
        # pas la signature coque -> « rejet serveur » dans les erreurs.
        def other_reject_fake_call(arguments, url, bearer, timeout=10.0,
                                   client="x", return_rejected_text=False):
            action = arguments.get("action")
            if action == "list":
                return {"content": [{"type": "text", "text": json.dumps(
                    {"success": True,
                     "dashboards": [{"key": "workspace-x"}]})}]}
            if action == "read":
                return {"content": [{"type": "text", "text": live_envelope}]}
            if "archiveFile" not in arguments:
                return {"content": [{"type": "text", "text": json.dumps(
                    {"success": True,
                     "archives": ["workspace-x-2026-11-03T04-00-00.md"]})}]}
            return "Error: something else entirely (EACCES)"

        try:
            globals()["_load_transport"] = lambda: other_reject_fake_call
            _o_entries, other_errors, _o_keys = load_entries_from_store(
                None, "bearer", timeout=1.0, now=now, window_hours=8.0)
        finally:
            globals()["_load_transport"] = saved_transport
        assert len(other_errors) == 1 and "rejet serveur" in other_errors[0], \
            other_errors

        # #4643 — timeout client sporadique sur archive SAINE : la relance
        # sert le contenu, l'entree archivee est vue (ici : [REPAIRED]).
        recover_reads = []

        def recover_fake_call(arguments, url, bearer, timeout=10.0,
                              client="x", return_rejected_text=False):
            action = arguments.get("action")
            if action == "list":
                return {"content": [{"type": "text", "text": json.dumps(
                    {"success": True,
                     "dashboards": [{"key": "workspace-x"}]})}]}
            if action == "read":
                return {"content": [{"type": "text", "text": live_envelope}]}
            if "archiveFile" not in arguments:
                return {"content": [{"type": "text", "text": json.dumps(
                    {"success": True,
                     "archives": ["workspace-x-2026-11-03T04-00-00.md"]})}]}
            recover_reads.append(timeout)
            if len(recover_reads) == 1:
                return None  # timeout client sporadique
            return {"content": [{"type": "text", "text": json.dumps({
                "success": True,
                "archiveData": {"messages": [{
                    "id": "r-1", "timestamp": "2026-11-03T03:00:00Z",
                    "author": {"machineId": "myia-a", "workspace": "ws"},
                    "content": "[REPAIRED] tout est revenu", "tags": []}]}})}]}

        try:
            globals()["_load_transport"] = lambda: recover_fake_call
            recover_entries, recover_errors, _ = load_entries_from_store(
                None, "bearer", timeout=1.0, now=now, window_hours=8.0)
        finally:
            globals()["_load_transport"] = saved_transport
        assert recover_errors == [], recover_errors
        repaired = [e for e in recover_entries if is_repaired(e)]
        assert len(repaired) == 1, recover_entries
        # Le defaut du budget couvre la passe saine mesuree (669 s, ai-01
        # 12/11) : l'ancien 120 s epuisait le budget sur une passe SAINE.
        assert DEFAULT_ARCHIVE_TIME_BUDGET_S >= 669.0

    print("selftest OK: [DEGRADED] ouvert/depasse/repare, [DONE] ne ferme rien, "
          "forme voisine ignoree, echeance derivee du poste, erreur d'instrument "
          "non confondue avec 'rien a signaler', idempotence quotidienne, "
          "mentions en prose ignorees (posts reels du 03/11), declaration par "
          "[tags:] seule, sonnerie sans effet sur sa propre alarme et sans "
          "token de declaration ; #4643 : crossPost dedoublonne sur (lane, poste), "
          "enveloppe archive archiveData parsee et fail-closed, listing "
          "d'archives None != [], fenetre 48 h par le nom, identification "
          "d'archive = celle du read vivant, rejet husk isError (enveloppe "
          "verbatim) classee lecture partielle sans relance (#4796), autre "
          "rejet isError = erreur, "
          "timeout client sporadique recouvre par la relance ; #4661 : "
          "budget d'archives global — saut signale, "
          "entrees vivantes intactes, appels bornes ; #4730 : defaut connu de "
          "l'hote classe A-PART (sonnerie separee, verdict explicite, "
          "idempotence sur le lot reparable, statut et sortie inchanges).")


def main(argv=None):
    # #4672 : la console Windows et les sorties redirigees sont en cp1252 par
    # defaut, et les extraits d'escalade portent des caracteres hors cp1252
    # (fleche U+2192 mesuree sur po-2028) : `report()` levait
    # UnicodeEncodeError et le crash rendait exit 1 a la place du verdict
    # semantique 2. Meme boucle que probe-semantic-known-answer.py et
    # g6-pass-bound.py ; errors="replace" pour ne jamais echouer sur une
    # sortie exotique.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

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
    parser.add_argument("--archive-window-hours", type=float,
                        default=DEFAULT_ARCHIVE_WINDOW_HOURS, metavar="HOURS",
                        help=f"fenetre de lecture des archives de condensation "
                             f"(#4643 : un [REPAIRED] ou une escalade archives "
                             f"reste visible ; defaut {DEFAULT_ARCHIVE_WINDOW_HOURS:g} h, "
                             f"0 desactive)")
    parser.add_argument("--archive-time-budget", type=float,
                        default=DEFAULT_ARCHIVE_TIME_BUDGET_S, metavar="SECONDS",
                        help=f"budget GLOBAL (s) de la passe d'archives : au-dela, "
                             f"les archives restantes sont sautees et signalees "
                             f"(fenetre partiellement aveugle, sortie 1) ; les "
                             f"lectures vivantes continuent. Defaut "
                             f"{DEFAULT_ARCHIVE_TIME_BUDGET_S:g} s, 0 = illimite (#4661)")
    parser.add_argument("--now", default=None, metavar="ISO8601",
                        help="instant de reference (rejeu) ; defaut : maintenant")
    parser.add_argument("--json", action="store_true", help="sortie machine")
    parser.add_argument("--ring", action="store_true",
                        help="poste la sonnerie ASK-USER sur le dashboard GLOBAL "
                             "(bearer : --ring-bearer, MCP_PROXY_BEARER, puis "
                             "fichier --env-file)")
    parser.add_argument("--ring-url", default=None,
                        help="base URL du mcp-proxy (defaut : MCP_PROXY_URL, "
                             "MCP_PROXY_BASE_URL, fichier --env-file, puis "
                             "https://mcp-tools.myia.io)")
    parser.add_argument("--ring-bearer", default=None,
                        help="bearer du mcp-proxy (defaut : MCP_PROXY_BEARER, "
                             "puis fichier --env-file ; une valeur vide "
                             "explicite = aucun bearer, sans repli)")
    parser.add_argument("--env-file", default=str(ORGAN_ENV_FILE), metavar="PATH",
                        help="fichier CLE=valeur lu pour MCP_PROXY_BEARER / "
                             "MCP_PROXY_BASE_URL (defaut : "
                             f"{ORGAN_ENV_FILE} ; valeur vide = aucun fichier)")
    parser.add_argument("--ring-timeout", type=float, default=10.0, metavar="SECONDS")
    parser.add_argument("--selftest", action="store_true", help="fixtures locales + sortie")
    args = parser.parse_args(argv)

    if args.selftest:
        selftest()
        return 0

    now = parse_ts(args.now) if args.now else datetime.now(timezone.utc)

    # #4672 : le fichier d'environnement deploye par le lanceur compagnon est
    # lu ici — la commande canonique ne demande aucun sourcing manuel.
    file_values, file_warning = load_organ_env_file(args.env_file)
    if file_warning:
        print(f"WARNING: {file_warning} — poursuite ; sans bearer lisible, la "
              f"mesure reste fail-closed (pas de lecture store)",
              file=sys.stderr)
    args.ring_url, args.ring_bearer = resolve_proxy_config(
        args.ring_url, args.ring_bearer, file_values)

    # Chaine de sources (review #4519 point c) : rejeu explicite -> fichiers ;
    # sinon STORE PG via le meme transport que la sonnerie ; sinon repli miroir
    # G:, qui DEGRADE la mesure quand PG etait configure (les dashboards sont
    # servis par PG depuis le cut #4131 — un G: gele repond un faux « tout va
    # bien » confiant sur des donnees mortes).
    source = "replay"
    degraded_source = False
    degraded_reason = None
    if args.dashboard_file:
        paths = [Path(p) for p in args.dashboard_file]
        entries, errors = load_entries(paths)
    else:
        loader = _store_loader or load_entries_from_store
        read_tel = ReadTelemetry()
        store = (loader(args.ring_url, args.ring_bearer,
                        timeout=args.ring_timeout, now=now,
                        window_hours=args.cycles * args.cycle_hours,
                        archive_window_hours=args.archive_window_hours,
                        archive_time_budget=args.archive_time_budget,
                        telemetry=read_tel)
                 if args.ring_bearer else None)
        if store is not None:
            source = "store"
            # #4643 : les cles lues deviennent le denominateur du rapport
            # d'erreurs (« N illisible(s) sur M ») — paths restait vide en
            # source store et le message disait « sur 0 ».
            entries, errors, store_keys = store
            paths = [f"store:{k}" for k in store_keys]
        else:
            source = "mirror"
            if args.ring_bearer:
                print("WARNING: store PG injoignable — repli miroir G:, la mesure "
                      "est DEGRADEE (sortie 1 quoi qu'il lise)", file=sys.stderr)
                degraded_source = True
                degraded_reason = ("source = miroir G: alors que PG est configure "
                                   "(store injoignable) — mesure incomplete, "
                                   "codes 0/2/3 non fiables")
            elif not args.dashboard_dir:
                # #4650 : sans bearer, le miroir IMPLICITE n'est plus ecrit
                # depuis #4131 (`gdriveSkipped` sur chaque append). Il peut
                # paraitre frais et avoir perdu les `[REPAIRED]` : un verdict
                # 0/2/3 porterait sur une source morte. Act-then-degrade : le
                # rapport reste affiche, mais le code de sortie dit « je ne
                # sais pas » — et une lane qui suit le mandat n'alerte pas le
                # user sur un 2 qu'elle n'a pas les moyens de mesurer.
                print("WARNING: MCP_PROXY_BEARER absent — le miroir G: n'est plus "
                      "ecrit depuis #4131 ; mesure DEGRADEE (sortie 1 quoi qu'il "
                      "lise). Rejeu explicite : --dashboard-dir ou --dashboard-file.",
                      file=sys.stderr)
                degraded_source = True
                degraded_reason = ("instrument incomplet : store PG non lu "
                                   "(MCP_PROXY_BEARER absent), le miroir G: n'est "
                                   "plus ecrit depuis #4131 — codes 0/2/3 non "
                                   "fiables")
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
    if source == "store":
        # #4729 : la ligne de telemetrie accompagne TOUT verdict store —
        # c'est elle qui distingue « store lent » de « store mort » quand
        # un exit 1 sous charge devra etre diagnostique apres coup.
        print(read_tel.render(), file=sys.stderr)
    report(escalations, code, reason, args.json,
           read_telemetry=read_tel if source == "store" else None)

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

    if errors:
        # Fail-closed : une moitie de dashboards illisible peut cacher une
        # escalade — ou le [REPAIRED] qui ferait taire celle mesuree. Ce qui a
        # ete mesure est rapporte ci-dessus, mais l'instrument ne peut pas
        # annoncer un 0 ou un 2 confiant.
        if code == 2 and args.ring:
            # W3 (review #4655) : la sonnerie est ANNULEE sur mesure partielle —
            # une fenetre aveugle peut cacher la clôture ; un faux reveil coute
            # une intervention humaine. Le cycle suivant re-sonnera sur une
            # lecture complete.
            print("ERROR: sonnerie ANNULEE — mesure partielle (dashboard(s) "
                  "illisible(s)) ; l'echeance mesuree reste due, relancer au "
                  "cycle suivant sur une lecture complete", file=sys.stderr)
        print(f"ERROR: {len(errors)} dashboard(s) illisible(s) sur {len(paths)} — "
              f"mesure partielle, codes 0/2/3 non fiables", file=sys.stderr)
        return 1

    if code == 2 and args.ring:
        overdue = [e for e in escalations if e["status"] == "overdue"]
        if not args.ring_bearer:
            print("ERROR: --ring demande sans bearer (--ring-bearer, MCP_PROXY_BEARER "
                  "ou fichier --env-file) — la sonnerie N'EST PAS partie",
                  file=sys.stderr)
            return 1
        outcome = publish_ring(overdue, args.ring_url, args.ring_bearer,
                               timeout=args.ring_timeout, now=now.timestamp())
        if not outcome:
            print("ERROR: la sonnerie N'EST PAS partie (transport) — l'echeance "
                  "reste depassee, relancer au cycle suivant", file=sys.stderr)
            return 1
        if outcome == "deduplicated":
            print(f"ring: sonnerie deja presente sur le dashboard global pour "
                  f"ce lot aujourd'hui ({len(overdue)} escalade(s)) — aucune "
                  f"nouvelle entree", file=sys.stderr)
        else:
            print(f"ring: sonnerie ASK-USER postee sur le dashboard global "
                  f"({len(overdue)} escalade(s))", file=sys.stderr)

    if degraded_source:
        # Meme logique act-then-degrade : ce que le miroir a dit est rapporte
        # (et sonne) ci-dessus, mais le code de sortie ne peut pas le
        # consacrer — la mesure ne portait pas sur la source de verite.
        print(f"ERROR: {degraded_reason}", file=sys.stderr)
        return 1

    return code


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
pick_idle_grain.py - Picker 3 urnes ponderees pour le pool executor roo-extensions.

Issue : #3675 (Epic #3111 phase 2, candidat #2) ; rework #4103.
Inspiration : CoursIA `pick_idle_grain.py` (PR #3155, passe 2 audit filesystem).
Bugs locaux documentes : #2509 (`--limit 15` faux drain) ; #4103 (graine fixe :
toutes les lanes tiraient le meme grain a chaque cycle).

Le picker tire dans 3 urnes ponderees :
  - grain      : issues actionnables (labels `approved` / `bug` / `investigation`)
  - umbrella   : issues parentes/epics (label `epic` OU marqueur de titre
                 borne, ex. suffixe parenthese « epic » accentue) - signal
                 de coordination
  - delivered  : PRs ouvertes (collectees pour la seule exclusion « issue deja
                 portee par une PR ouverte », JAMAIS servies comme candidat
                 libre : une PR n'est pas un grain - mesure c.309, ms#1538)

#4103 - tirage par lane et par creneau :
  - La graine par defaut derive de la machine (COMPUTERNAME, sinon hostname,
    en minuscules) et du creneau horaire UTC :
    `int(sha256(machine)[:8], big) ^ slot` ou `slot = epoch_utc // 3600`.
    Deux lanes tirent des listes differentes sur le meme pool. Un `--seed N`
    explicite garde la reproductibilite (tests). Jamais `hash()` : le hash
    Python d'une chaine est sale par processus (PYTHONHASHSEED) et la graine
    changerait a chaque lancement (precisation sk-agent analyst, #4103).
  - `--top K` (defaut 5) : K candidats distincts, tires sans remise selon les
    poids des urnes. La lane parcourt la liste jusqu'au premier grain libre.
    Si les K sont tous pris, le tirage s'elargit au pool entier, dans l'ordre
    du tirage ; si rien n'est libre : verdict `ALL_CLAIMED` (exit 0) avec la
    liste des ecarts et leurs raisons - ni IDLE_REAL ni ERROR.
  - Saut des claims etrangers sur les candidats parcourus uniquement (appels
    API bornes) : logique REUTILISEE depuis `scripts/github/check_issue_claim.py`
    (ADR 017 : claim actif d'une autre machine, peremption 24 h).
  - Saut des grains DEJA SERVIS par la lane elle-meme : dernier marqueur
    RESULT/RELEASED de MA lane sans commentaire d'un autre acteur depuis
    (friction OWN_CLAIM, dispatch ai01-c34) - relu sur le fetch_issue deja
    fait, sans appel API supplementaire.
  - Saut des issues portant une etiquette de lane (`myia-*`) autre que la
    notre - la regle s'applique a toute etiquette myia-* existante, sans
    liste codee en dur. Le prefixe de titre `[CLAUDE-<machine>]` n'est PAS
    consulte : il designe la machine qui a CREE l'issue, pas celle qui doit
    la porter.
  - Saut des issues DEJA PORTEES par une PR ouverte (decision ai-01 du
    25/10) : le picker resservait des grains dont le travail etait deja en
    review. Deux formes de citation comptent, et seulement deux - le numero
    dans le TITRE de la PR, ou une reference de FERMETURE explicite dans son
    corps (`Closes/Fixes/Resolves #N`). Une simple mention de corps ne compte
    PAS : mesure 25/10 sur le pool reel, la forme large ecartait #3962 et
    #2428, que le bump #4353 cite dans sa liste de commits sans les livrer,
    alors que la forme retenue ecarte exactement #4348 (PR #4350) et #4352
    (PR #4353) - zero faux positif mesure.
  - Collecte REST UNE fois par depot (`gh api repos/{repo}/issues?state=open`,
    paginee) : le quota GraphQL, partage par toute la flotte, n'est plus
    consomme. La meme reponse sert les 3 urnes (les PRs y figurent avec la
    cle `pull_request`) et le compteur `unlabelled_open` (issues ouvertes non
    gatees, non epic, sans etiquette d'urne - le trou rendu visible).

Usage :
    python pick_idle_grain.py --dry-run                # Liste les candidats sans s'engager
    python pick_idle_grain.py --json                  # Sortie JSON pour orchestration
    python pick_idle_grain.py --top 8                 # Liste ordonnee de 8 candidats
    python pick_idle_grain.py --reroll                # Re-tirage (graine decalee, compat)
    python pick_idle_grain.py --seed 42 --top 5       # Tirage reproducible (tests)

Garde-fous (fail-closed, reviews #3681) :
  - Toute panne instrument (gh exit != 0, timeout, JSON invalide - sur la
    collecte OU sur une verification de claim) rend un verdict ERROR avec
    exit 2 - JAMAIS un verdict de fond. Un instrument muet ne peut pas
    declarer le pool vide, ni un claim illisible passer pour un grain libre.
  - Verdict IDLE_REAL UNIQUEMENT si les 3 urnes sont vides APRES collecte
    reussie sur les 2 depots.
  - Encodage : stdout gh decode en UTF-8 avec errors="replace" - les titres
    accentues ne crashent plus le reader sous Windows cp1252.
"""
import argparse
import hashlib
import json
import os
import random
import re
import socket
import subprocess
import sys
import time
import unicodedata
from pathlib import Path

# Reutilisation de la logique de claim (ADR 017) - pas de reecriture (#4103).
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "github"))
import check_issue_claim  # noqa: E402

# Ponderations par defaut - modifiables via --weights "grain:7,umbrella:2,delivered:1"
DEFAULT_WEIGHTS = {"grain": 7, "umbrella": 2, "delivered": 1}

# Raison d'ecart d'une PR ouverte. ASCII pur : le texte est imprime sur la
# console Windows (cp1252) par la sortie humaine, et une raison accentuee y
# leverait UnicodeEncodeError (#3675 suite, mesure web2 04/10).
PR_SKIP_REASON = "open PR - review it explicitly, never claim it"

# Labels actionnables (grain) - EXCLURE needs-approval/deferred/blocked-on-gate/epic
GRAIN_LABELS = {"approved", "bug", "investigation"}
UMBRELLA_LABELS = {"epic"}
# Gel par decision (#3381) : hors de TOUTE urne, meme avec un label actionnable
FROZEN_LABELS = {"frozen"}
# Attente d'arbitrage ou de deblocage : hors de TOUTE urne, meme avec un label
# actionnable. L'exclusion implicite (absence de label actionnable) ne tient pas
# en cas de CO-OCCURRENCE - mesure 03/10 : #4038 (bug + needs-approval) pickee
# au 1er tirage, contrairement au contrat documente ci-dessus.
GATED_LABELS = {"needs-approval", "deferred", "blocked-on-gate"}

# #622 (decision ai-01, c.6554348206) : un grain `copilot-target` appartient au
# pont Copilot SEUL (start-copilot-dispatcher.ps1 lit exclusivement ce label,
# cadence PT12H). Les pickers de lane tirent plus vite : #4306 a ete reclamee
# par une lane 2 h apres sa creation, AVANT le premier tir du pont -- le pool
# s'est vide et l'AC0 du chantier est devenue non mesurable. L'exclusion vit
# dans les TROIS pickers (celui-ci, start-claude-worker.ps1, scheduler Zoo),
# toujours comme une garde au moment de tirer, jamais comme un retrait a la
# collecte : le pont et ce picker ne lisent pas la meme source.
COPILOT_TARGET_LABEL = "copilot-target"
COPILOT_SKIP_REASON = COPILOT_TARGET_LABEL + ": reserved to the Copilot bridge"

# Umbrella par TITRE en plus du label - friction web2 c.91 (30/10) : #3151
# porte un suffixe parenthese « (epic) » (e accentue) dans son titre SANS le
# label `epic` et a ete servie trois cycles de suite depuis l'urne grain.
# Motifs BORNES uniquement (prefixe `[EPIC]` / `Epic:` / `Epic -`, ou
# suffixe parenthese en fin de titre) : le mot nu dans une phrase
# (« epicenter ») reste un grain. Source ASCII pur : l'accent aigu du e du
# suffixe reel est retire a l'execution par normalisation NFKD - la
# convention cp1252 du fichier est preservee.
EPIC_TITLE_PREFIX_RE = re.compile(r"^\s*\[?\s*epic\b")
EPIC_TITLE_SUFFIX_RE = re.compile(r"\(\s*epic\s*\)\s*$")

# Repos a scanner (anti-double-claim #3407 : 2 depots)
REPOS = ["jsboige/roo-extensions", "jsboige/jsboige-mcp-servers"]

# Etiquette de lane : toute etiquette `myia-*` posee sur une issue designe la
# lane qui la porte (#4103). Pas de liste codee en dur : la regle s'applique a
# toute etiquette matchant le motif, presente ou future.
MACHINE_LABEL_RE = re.compile(r"^myia-[a-z0-9-]+$")

# Peremption des claims etrangers : meme valeur que le guard check_issue_claim
# (ADR 017, --stale-threshold defaut 24). Un claim perime ne bloque pas - le
# nouveau claimant pose quand meme son propre [CLAIMED].
CLAIM_STALE_THRESHOLD_H = 24.0

# Marqueurs de livraison de MA lane (dispatch ai01-c34, friction OWN_CLAIM) :
# RESULT = rapport de livraison, RELEASED = verrou leve apres merge. Le picker
# resservait a une lane son propre grain deja livre (2 lanes touchees le 21/10 :
# #2767/#4287 po-2027, #4286 po-2023).
OWN_SERVED_MARKERS = {"RESULT", "RELEASED", "DONE", "DELIVERED"}

# Issue deja portee par une PR ouverte (decision ai-01 du 25/10) : le numero
# cite dans le TITRE de la PR. Frontiere de mot obligatoire - `#(\d+)(?![0-9])` :
# `#435` ne doit pas matcher `#4352` (meme piege que le pre-claim #3407, ou
# `--search` ramenait des PRs sans rapport).
CITATION_IN_TITLE_RE = re.compile(r"#(\d+)(?![0-9])")

# Reference de FERMETURE explicite dans le corps de la PR (`Closes #4348`,
# `fixes: #4348`, `Resolved #4348`). Seule cette forme compte dans le corps :
# une mention nue ne dit pas que la PR livre l'issue - mesure 25/10, le bump
# #4353 cite #3962 et #2428 dans sa liste de commits sans les livrer.
CLOSING_REFERENCE_RE = re.compile(
    r"(?i)\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\b[ \t]*:?[ \t]*#(\d+)(?![0-9])"
)


class GhCommandError(RuntimeError):
    """Panne instrument gh : exit non-nul, timeout ou JSON invalide.

    Fail-closed : le picker ne doit JAMAIS convertir une panne en verdict
    de fond (IDLE_REAL sur un pool potentiellement non-vide, ou grain libre
    sur un claim illisible)."""

    def __init__(self, repo: str, reason: str):
        super().__init__(f"gh a echoue pour {repo}: {reason}")
        self.repo = repo
        self.reason = reason


def run_gh_text(cmd: list, repo: str, timeout: int = 60) -> str:
    """Execute gh, decode en UTF-8, retourne le stdout brut.

    Fail-closed : CalledProcessError / TimeoutExpired sont des pannes
    d'instrument, pas des pools vides (review #3681, bloquant 2).
    """
    try:
        result = subprocess.run(
            cmd, capture_output=True, check=True, timeout=timeout,
            encoding="utf-8", errors="replace",
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        stderr = (e.stderr or "").strip() if isinstance(e.stderr, str) else ""
        raise GhCommandError(repo, f"exit {e.returncode}: {stderr}") from e
    except subprocess.TimeoutExpired as e:
        raise GhCommandError(repo, f"timeout apres {timeout}s") from e


def run_gh_api_open_issues(repo: str, limit: int) -> list:
    """Collecte UNE fois les issues ET PRs ouvertes d'un depot, via REST pagine.

    `gh api .../issues?state=open` retourne issues et PRs (une PR y porte la
    cle `pull_request`) : la meme reponse alimente les 3 urnes et le compteur
    unlabelled_open, sans appel supplementaire (#4103). Le REST remplace
    `gh issue list` / `gh pr list` (GraphQL) : le quota GraphQL, partage par
    toute la flotte, n'est plus consomme par le picker.

    Avec `--paginate --jq '.[]'`, gh emet un objet JSON compact par ligne a
    travers toutes les pages ; le parsing est ligne a ligne. Toute ligne
    non-JSON est une panne d'instrument (fail-closed), pas un pool vide.
    """
    cmd = [
        "gh", "api", "--paginate", "--jq", ".[]",
        f"repos/{repo}/issues?state=open&per_page=100",
    ]
    stdout = run_gh_text(cmd, repo)
    items = []
    for line in stdout.splitlines():
        if not line.strip():
            continue
        try:
            items.append(json.loads(line))
        except json.JSONDecodeError as e:
            raise GhCommandError(repo, f"stdout non-JSON: {e}") from e
        if len(items) >= limit:
            break
    return items


def normalize_rest_item(raw: dict, repo: str) -> dict:
    """Mappe un item REST vers la forme interne (champs camelCase, is_pr, repo).

    Chaque item porte son repo : le numero seul n'identifie rien quand les
    deux depots l'utilisent (mesure po-2026 03/10, c.72 : #608 existe des
    deux cotes avec des contenus differents).
    """
    return {
        "number": raw.get("number"),
        "title": raw.get("title", ""),
        "body": raw.get("body") or "",
        "labels": [{"name": l.get("name")} for l in raw.get("labels", [])],
        "assignees": raw.get("assignees", []),
        "createdAt": raw.get("created_at", ""),
        "updatedAt": raw.get("updated_at", ""),
        "is_pr": "pull_request" in raw,
        "repo": repo,
    }


def _ascii_fold(text: str) -> str:
    """Minuscules + accents retires (NFKD, marques combinantes supprimees).

    La forme accentuee du marqueur epic (e accent aigu) devient « epic »
    sans que le SOURCE ne quitte l'ASCII : la convention cp1252 du fichier
    (impressions console, #3675) reste intacte.
    """
    decomposed = unicodedata.normalize("NFKD", (text or "").lower())
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch))


def _looks_like_epic_title(title: str) -> bool:
    """True si le TITRE porte un marqueur d'epic borne (prefixe ou suffixe).

    Filet complementaire au label `epic`, pas son remplacement - friction
    web2 c.91 : une epic non etiquetee (marqueur de titre accentue) sinon
    servie comme grain a une lane. Le coordinateur garde la main sur le
    relabel ; ce filet evite seulement de la classer actionnable.
    """
    folded = _ascii_fold(title)
    return bool(EPIC_TITLE_PREFIX_RE.search(folded)
                or EPIC_TITLE_SUFFIX_RE.search(folded))


def bucketize_items(items: list):
    """Repartit les items collectes dans les 3 urnes + compte le trou.

    Umbrella = label `epic` OU marqueur de titre borne (voir
    `_looks_like_epic_title`) - friction web2 c.91 : #3151 (suffixe
    parenthese epic accentue, sans label) etait servie depuis l'urne grain
    trois cycles de suite.

    Retourne (buckets, unlabelled_open, open_issues) :
      - buckets['delivered'] = PRs ouvertes (cle `pull_request` cote REST) ;
      - unlabelled_open = issues ouvertes NON gatees/frozen, NON epic, sans
        AUCUN label d'urne (grain|umbrella) : le trou du pool rendu visible
        (#4103) - coordinator relabellise ou arbitre, le picker ne devine pas.
      - open_issues = issues ouvertes hors PRs (backlog_total historique).
    """
    buckets = {"grain": [], "umbrella": [], "delivered": []}
    unlabelled_open = 0
    open_issues = 0
    for item in items:
        labels = {lbl.get("name") for lbl in item.get("labels", [])}
        if item.get("is_pr"):
            buckets["delivered"].append(item)
            continue
        open_issues += 1
        if labels & (FROZEN_LABELS | GATED_LABELS):
            continue
        if labels & UMBRELLA_LABELS or _looks_like_epic_title(item.get("title")):
            buckets["umbrella"].append(item)
        elif labels & GRAIN_LABELS:
            buckets["grain"].append(item)
        else:
            unlabelled_open += 1
    return buckets, unlabelled_open, open_issues


def cited_issues_by_open_prs(prs: list) -> dict:
    """{(repo, numero_issue): numero_de_la_PR} des issues portees par une PR ouverte.

    Decision ai-01 du 25/10 (statut dashboard) : le picker resservait des grains
    dont le travail etait deja en review - mesure du jour, un claim de lane a
    ete pose sur #4348 alors que la PR #4350 le livrait deja.

    La cle porte le DEPOT : le numero seul n'identifie rien quand les deux
    depots l'utilisent (meme regle que partout ailleurs dans le picker).
    Le premier citant gagne (`setdefault`) : l'ordre de collecte est stable et
    une seule PR nommee suffit a rendre l'ecart auditable dans `reason`.

    `delivered` fournit les PRs deja collectees - aucun appel API en plus.
    """
    cited = {}
    for pr in prs:
        repo = pr.get("repo", "")
        numbers = [int(n) for n in CITATION_IN_TITLE_RE.findall(pr.get("title") or "")]
        numbers += [int(n) for n in CLOSING_REFERENCE_RE.findall(pr.get("body") or "")]
        for number in numbers:
            cited.setdefault((repo, number), pr.get("number"))
    return cited


def own_machine_id() -> str:
    """Identite de MACHINE : COMPUTERNAME, sinon hostname, en minuscules.

    La machine vient de l'environnement, jamais d'un flag CLI (ADR 016 :
    le filtre par machine a ete SUPPRIME ; #4103 reutilise des donnees qui
    existent - claims et etiquettes - sans le reintroduire). Sert a la graine
    du tirage, aux etiquettes de lane et au champ `machine` de la sortie ;
    la comparaison de claims, elle, passe par own_lane_id() (#4114).
    """
    name = os.environ.get("COMPUTERNAME") or socket.gethostname() or "unknown"
    return name.strip().lower()


def own_lane_id() -> str:
    """Identite LANE pour la lecture de claims : machine[:workspace] (#4114).

    Le suffixe workspace vient de check_issue_claim.detect_workspace() (walk-up
    pur, sans subprocess) : deux workspaces partagent une machine, seul le
    workspace les distingue - un claim pose par l'AUTRE workspace de SA machine
    doit ecarter le grain. Sans toplevel detecte, on retombe sur la machine
    seule (le guard classera alors le claim etranger legacy ou foreign).
    """
    machine = own_machine_id()
    workspace = check_issue_claim.detect_workspace()
    return f"{machine}:{workspace}" if workspace else machine


def current_slot(now: float | None = None) -> int:
    """Creneau horaire UTC du tirage (epoch // 3600). Injectable pour les tests."""
    if now is None:
        now = time.time()
    return int(now // 3600)


def derive_seed(machine: str, slot: int) -> int:
    """Graine stable par lane et par creneau.

    sha256 plutot que hash() : le hash Python d'une chaine est sale par
    processus (PYTHONHASHSEED) - hash(machine) donnerait une graine differente
    a chaque lancement sur la MEME machine (precision analyst #4103).
    """
    digest = hashlib.sha256(machine.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big") ^ slot


def foreign_machine_labels(labels: set, own_machine: str) -> list:
    """Etiquettes de lane etrangeres portees par l'issue (triees).

    Toute etiquette `myia-*` qui n'est pas la notre designe une autre lane.
    La comparaison est en minuscules des deux cotes (les etiquettes du depot
    sont minuscules ; COMPUTERNAME arrive en majuscules).
    """
    own = (own_machine or "").lower()
    hits = {
        lbl for lbl in labels
        if isinstance(lbl, str) and MACHINE_LABEL_RE.match(lbl.lower()) and lbl.lower() != own
    }
    return sorted(hits)


def draw_candidates(buckets: dict, weights: dict, rng: random.Random, k, pool: dict = None) -> list:
    """Tire k candidats distincts SANS REMISE selon les poids des urnes.

    A chaque etape : une urne tiree selon les poids (parmi les non vides),
    puis un item au hasard dans l'urne, retire du pool. k=None etend le
    tirage au pool entier - c'est l'elargissement du verdict ALL_CLAIMED
    (#4103) : meme ordre, meme rng, continuite du tirage.

    `pool` (optionnel) : etat de tirage persistant. Passe par l'appelant, il
    relie les deux passes (K candidats, puis elargissement) sur le MEME pool
    ampute - sans lui, chaque passe repartirait des urnes intactes et
    reverifierait les candidats deja ecartes.
    """
    if pool is None:
        pool = {name: list(items) for name, items in buckets.items() if items}
    order = []
    while pool and (k is None or len(order) < k):
        names = [n for n in pool if pool[n]]
        if not names:
            break
        total = sum(weights.get(n, 0) for n in names)
        chosen = rng.choices(names, weights=[weights.get(n, 0) / total for n in names], k=1)[0]
        idx = rng.randrange(len(pool[chosen]))
        order.append((chosen, pool[chosen].pop(idx)))
        if not pool[chosen]:
            del pool[chosen]
    return order


def own_served_no_followup(comments: list, own_lane: str) -> bool:
    """MA lane a-t-elle livre ce grain sans qu'un autre acteur revienne depuis ?

    Friction OWN_CLAIM (dispatch ai01-c34) : le claim de SA lane ne bloque
    jamais (reprise legitime, #4114) - mais un grain dont le DERNIER evenement
    significatif est une livraison de MA lane est un grain DEJA SERVI par
    nous : le re-prendre refait le travail. Les commentaires viennent du
    fetch_issue DEJA fait par check_candidate (zero appel API supplementaire) ;
    la lecture reutilise scan_comment_events et _same_lane du guard
    (ADR 017, identite lane #4114).

    Fold chronologique ligne-par-ligne sur TOUS les marqueurs (review #4313) :
      - marqueur servi de MA lane (RESULT/RELEASED/DONE/DELIVERED) -> servi ;
      - [CLAIMED] de MA lane posterieur -> rouvre (re-prise legitime, y compris
        le hold du worker #4314 `[RESULT]...FAIL` + `[CLAIMED] -- held:` dans
        le MEME commentaire : le CLAIMED, plus bas dans le corps, gagne) ;
      - marqueur portant une AUTRE lane -> rouvre (quel que soit le marqueur :
        re-engagement exterieur, le signal qui rouvre le grain) ;
      - commentaire SANS marqueur, ou marqueur sans lane -> NEUTRE.

    TRADE-OFF (remede NanoClaw, fil #4286) : un addendum sans marqueur de la
    lane elle-meme ne rouvre plus ; un humain qui commente sans marqueur ne
    rouvre plus non plus - seul un marqueur d'une autre lane rouvre. L'ancien
    critere "tout commentaire sans notre lane = autre acteur" rendait LIBRE
    le fil #4286 termine par l'addendum de sa propre lane.
    """
    events = []  # (kind, lane) dans l'ordre chrono du fil, ligne par ligne
    for comment in sorted(comments, key=lambda c: c.get("createdAt", "")):
        for marker, lane, _line in check_issue_claim.scan_comment_events(
            comment.get("body", "")
        ):
            if lane is None:
                continue  # marqueur sans lane : ni servi ni rouvrant
            if marker in OWN_SERVED_MARKERS:
                events.append(("served", lane))
            elif marker == "CLAIMED":
                events.append(("claim", lane))
            else:
                events.append(("other", lane))
    served = False
    for kind, lane in events:
        if check_issue_claim._same_lane(lane, own_lane):
            if kind == "served":
                served = True  # notre livraison est le dernier evenement... pour l'instant
            elif kind == "claim":
                served = False  # notre re-claim rouvre (hold worker #4314)
            # nos autres marqueurs (ACK, INFO, ...) : neutres
        else:
            served = False  # marqueur d'une autre lane : re-engagement exterieur
    return served


def check_candidate(urn: str, item: dict, own_machine: str, own_lane: str = None,
                    cited_by: dict = None) -> tuple:
    """(skip, raison) pour un candidat. Leve GhCommandError sur panne instrument.

    - PR ouverte (urne delivered) : ECARTEE, sans appel API. Une PR n'est pas
      un grain : la servir « LIBRE » a fait poser un claim sur une PR prise
      pour une issue (mesure po-2024 c.309 : ms#1538 servie candidate, puis
      traitee comme un grain). La revue reste du travail legitime, mais elle
      se choisit explicitement (`/pr-review`), pas par un tirage qui la
      presente comme libre. Aucune lecture de verrou (ADR 016).
    - Issue deja portee par une PR ouverte (decision ai-01 du 25/10) : ecartee
      sur donnee LOCALE (aucun appel API), avant toute lecture de claim.
    - Label copilot-target (#622, decision ai-01 du 01/11) : reserve au pont
      Copilot, ecarte sur donnee LOCALE, sans appel API.
    - Etiquette de lane etrangere : ecarte sans appel API (donnee locale),
      comparee sur la MACHINE (les etiquettes du depot portent la machine).
    - Claim etranger actif : REUTILISE check_issue_claim (ADR 017, peremption
      24 h) - fetch_issue + reduce_claims + classify, pas de reecriture.
      classify recoit l'identite LANE (#4114 : machine[:workspace]) - le claim
      de l'AUTRE workspace de sa propre machine est un claim etranger.
      Une claim illisible est une panne d'instrument (fail-closed), jamais un
      grain libre : lever GhCommandError laisse le verdict ERROR tranche.
    - Grain deja servi par MA lane : own_served_no_followup, relu sur les
      commentaires du MEME fetch_issue (friction OWN_CLAIM, dispatch ai01-c34).
    """
    if item.get("is_pr"):
        return True, PR_SKIP_REASON
    if urn == "delivered":
        return True, PR_SKIP_REASON
    cited_pr = (cited_by or {}).get((item.get("repo", ""), item.get("number")))
    if cited_pr is not None:
        return True, f"cited by open PR #{cited_pr}"
    labels = {lbl.get("name") for lbl in item.get("labels", [])}
    if COPILOT_TARGET_LABEL in labels:
        # Donne LOCALE, aucun appel API : le label EST la reservation (voir la
        # constante ci-dessus pour la chronologie mesuree).
        return True, COPILOT_SKIP_REASON
    foreign = foreign_machine_labels(labels, own_machine)
    if foreign:
        return True, "machine label " + ", ".join(foreign)
    try:
        issue = check_issue_claim.fetch_issue(str(item["number"]), item["repo"])
    except (RuntimeError, json.JSONDecodeError) as e:
        raise GhCommandError(item["repo"], f"claim check #{item['number']}: {e}") from e
    state = check_issue_claim.reduce_claims(issue.get("comments", []))
    blocking, _warnings, _notes = check_issue_claim.classify(
        state, own_lane or own_machine, CLAIM_STALE_THRESHOLD_H
    )
    if blocking:
        who = ", ".join(sorted({m for m, _, _ in blocking}))
        return True, f"active claim by {who}"
    if own_served_no_followup(issue.get("comments", []), own_lane or own_machine):
        return True, "own served, awaiting other actor"
    return False, ""


def emit_error(errors: list, as_json: bool) -> int:
    """Verdict ERROR fail-closed : exit 2, jamais un verdict de fond."""
    if as_json:
        print(json.dumps({
            "verdict": "ERROR",
            "errors": [str(e) for e in errors],
            "pick": None,
        }, indent=2))
    else:
        print("[ERROR] Instrument gh en panne - aucun verdict de fond rendu :")
        for e in errors:
            print(f"  - {e}")
        print("Reparer gh (auth, rate-limit, reseau) puis relancer le picker.")
    return 2


def _make_stdout_encoding_safe() -> None:
    """Ecrire sans jamais lever sur une console Windows cp1252 (#3675 suite).

    Mesure web2 04/10 (cycle c.24) : `--dry-run` sur une urne contenant un
    titre portant '→' (U+2192, absent de cp1252) -> UnicodeEncodeError a
    l'impression. Le mode qui sert a choisir quand le tirage rend un candidat
    deja pris etait donc inutilisable en texte ; seul `--json` survivait
    (json.dumps echappe le non-ASCII par defaut).

    #3675/#3681 avait corrige la LECTURE de stdout gh (UTF-8,
    errors='replace'). L'ECRITURE porte la meme politique : `errors='replace'`
    plutot qu'un forcage UTF-8, pour que la console garde son rendu actuel
    (les accents cp1252 continuent de s'afficher) et que seul l'incodable
    recule ('?') au lieu de lever.
    """
    try:
        sys.stdout.reconfigure(errors="replace")
    except (AttributeError, ValueError, OSError):
        # stdout sans reconfigure (StringIO de test, flux deja ferme) : ne pas
        # empecher le picker de rendre son verdict pour autant.
        pass


def _candidate_entry(urn: str, item: dict, skip: bool, reason: str) -> dict:
    return {
        "number": item["number"],
        "repo": item.get("repo", ""),
        "title": item["title"],
        "urn": urn,
        "skipped": skip,
        "reason": reason or None,
    }


def main() -> int:
    _make_stdout_encoding_safe()
    parser = argparse.ArgumentParser(
        description="Picker 3 urnes ponderees pour le pool executor roo-extensions (issue #3675, rework #4103).",
    )
    parser.add_argument("--dry-run", action="store_true", help="Affiche la liste des candidats sans s'engager.")
    parser.add_argument("--json", action="store_true", help="Sortie JSON machine-readable.")
    parser.add_argument("--reroll", action="store_true", help="Re-tirage avec graine decalee (compat).")
    parser.add_argument("--limit", type=int, default=300, help="Cap d'items collectes par depot (defaut 300, corrige #2509).")
    parser.add_argument("--seed", type=int, default=None,
                        help="Graine explicite reproductible (tests). Defaut : derivee de la machine et du creneau UTC (#4103).")
    parser.add_argument("--weights", type=str, default="", help="Ponderations custom (ex: 'grain:7,umbrella:2,delivered:1').")
    parser.add_argument("--top", type=int, default=5,
                        help="Nombre de candidats distincts tires sans remise (defaut 5) ; la lane parcourt la liste jusqu'au premier grain libre.")
    args = parser.parse_args()

    # Parse weights custom si fourni
    weights = DEFAULT_WEIGHTS.copy()
    if args.weights:
        for pair in args.weights.split(","):
            if ":" in pair:
                k, v = pair.split(":", 1)
                try:
                    weights[k.strip()] = int(v.strip())
                except ValueError:
                    pass

    # Graine : explicite (reproductibilite, tests) ou derivee machine+creneau
    machine = own_machine_id()
    lane = own_lane_id()
    slot = current_slot()
    seed = args.seed if args.seed is not None else derive_seed(machine, slot)
    if args.reroll:
        seed += 1
    rng = random.Random(seed)

    # Collecte - UNE requete REST par depot (issues+PRs ouvertes), fail-closed :
    # toute panne instrument arrete le picker AVANT tout verdict (review #3681).
    all_items = []
    errors = []
    for repo in REPOS:
        try:
            raw = run_gh_api_open_issues(repo, args.limit)
            all_items.extend(normalize_rest_item(r, repo) for r in raw)
        except GhCommandError as e:
            errors.append(e)
    if errors:
        return emit_error(errors, args.json)

    # Urnes + trous visibles
    buckets, unlabelled_open, total_backlog = bucketize_items(all_items)
    # Issues deja portees par une PR ouverte (decision ai-01 du 25/10), lues sur
    # l'urne delivered DEJA collectee : aucun appel API supplementaire.
    cited_by = cited_issues_by_open_prs(buckets["delivered"])
    grain_count = len(buckets["grain"])
    umbrella_count = len(buckets["umbrella"])
    delivered_count = len(buckets["delivered"])
    actionnable_count = grain_count + umbrella_count + delivered_count

    trace = {"machine": machine, "seed": seed, "slot": slot}

    if actionnable_count == 0:
        # Verdict IDLE REEL : aucun grain actionnable - collecte reussie, urnes vides
        if args.json:
            print(json.dumps({
                "verdict": "IDLE_REAL",
                **trace,
                "backlog_total": total_backlog,
                "grain": grain_count,
                "umbrella": umbrella_count,
                "delivered": delivered_count,
                "unlabelled_open": unlabelled_open,
                "pick": None,
            }, indent=2))
        else:
            print(f"[IDLE-REAL] Backlog={total_backlog}, grain=0, umbrella=0, delivered=0, "
                  f"unlabelled_open={unlabelled_open}.")
            print("Le pool est REELLEMENT draine. Passer au catalogue idle I1-I8.")
        return 0

    # Tirage ordonne sans remise, puis parcours jusqu'au premier candidat libre.
    # Tous les K pris -> elargissement au pool entier dans l'ordre du tirage
    # (#4103) ; rien de libre -> ALL_CLAIMED (exit 0), ni IDLE_REAL ni ERROR.
    # Le pool persistant relie les deux passes : l'elargissement ne re-tire
    # jamais un candidat deja ecarte.
    draw_pool = {name: list(items) for name, items in buckets.items() if items}
    candidates = draw_candidates(buckets, weights, rng, args.top, pool=draw_pool)
    checked = []
    pick = None
    try:
        for urn, item in candidates:
            skip, reason = check_candidate(urn, item, machine, lane, cited_by)
            checked.append(_candidate_entry(urn, item, skip, reason))
            if not skip:
                pick = (urn, item)
                break
        if pick is None:
            for urn, item in draw_candidates(buckets, weights, rng, None, pool=draw_pool):
                skip, reason = check_candidate(urn, item, machine, lane, cited_by)
                checked.append(_candidate_entry(urn, item, skip, reason))
                if not skip:
                    pick = (urn, item)
                    break
    except GhCommandError as e:
        return emit_error([e], args.json)

    if args.json:
        if pick is None:
            output = {
                "verdict": "ALL_CLAIMED",
                **trace,
                "backlog_total": total_backlog,
                "grain": grain_count,
                "umbrella": umbrella_count,
                "delivered": delivered_count,
                "unlabelled_open": unlabelled_open,
                "candidates": checked,
                "pick": None,
            }
        else:
            urn, item = pick
            output = {
                "verdict": "PICK",
                **trace,
                "backlog_total": total_backlog,
                "grain": grain_count,
                "umbrella": umbrella_count,
                "delivered": delivered_count,
                "unlabelled_open": unlabelled_open,
                "candidates": checked,
                "urn": urn,
                "pick": {
                    "number": item["number"],
                    "repo": item.get("repo", ""),
                    "title": item["title"],
                    "updatedAt": item.get("updatedAt", ""),
                },
            }
        print(json.dumps(output, indent=2))
    else:
        seed_origin = "explicit" if args.seed is not None else "derived"
        print(f"[SEED] machine={machine}, slot={slot}, seed={seed} ({seed_origin})")
        print(f"[CANDIDATS] tirage sans remise (top {args.top} -> elargi si tous pris) :")
        for i, c in enumerate(checked, 1):
            status = f"SKIP ({c['reason']})" if c["skipped"] else "LIBRE"
            print(f"  {i}. {c['urn']} {c['repo']}#{c['number']}: {c['title'][:80]} — {status}")
        if pick is None:
            print(f"[ALL-CLAIMED] Tous les candidats du pool sont pris "
                  f"({len(checked)} ecartes) — claims actifs ou etiquettes de lane.")
            print("Le pool n'est PAS vide : reessayer plus tard, ou demander arbitrage coordinateur.")
        else:
            urn, item = pick
            print(f"[PICK] Urne={urn}, {item.get('repo', '?')}#{item['number']}: {item['title']}")
            print(f"        Backlog={total_backlog}, grain={grain_count}, "
                  f"umbrella={umbrella_count}, delivered={delivered_count}, "
                  f"unlabelled_open={unlabelled_open}")

            if args.dry_run:
                # Affiche aussi le top-N des candidats par urne pour visibilite
                for name in ("grain", "umbrella", "delivered"):
                    top_n = buckets[name][:args.top]
                    if top_n:
                        print(f"\n[TOP {args.top}] urne={name}:")
                        for it in top_n:
                            print(f"  {it.get('repo', '?')}#{it['number']}: {it['title'][:80]}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""collect_open_user_questions.py — organe « questions ouvertes flotte » (#4821, volet b).

Directive owner 17/11 : « Il faudrait que tout le monde puisse me présenter les
questions de tout le monde car mon attention sur les 40 fenêtres ouvertes est
une ressource rare. » La règle de consolidation (#4196) fait de l'entrée
ASK-USER sur le dashboard global une **VUE** du registre local de chaque lane ;
cet organe RECONSTRUIT cette vue depuis les dashboards servis par le **store
PG** (autorité depuis #4131 G-DASH), en lecture seule, sans muter quoi que ce
soit. Le miroir G: n'est qu'un export dérivé : il reste un canal de rejeu
**explicitement dégradé** (`--mirror`, ou repli automatique quand le store est
illisible — la sortie est alors étiquetée) :

  - **vue global** : pour chaque lane, la **dernière** entrée ASK-USER du
    dashboard global (une entrée plus ancienne de la même lane est remplacée
    par la plus récente — la vue est repostée à chaque fin de session), avec
    ses questions parsées et leur âge tel que la lane le porte ;
  - **hors global** : les entrées qui posent une question au user sur un
    dashboard machine/workspace **sans** entrée ASK-USER global au moins aussi
    récente de la même lane — le trou exact que la directive nomme (cas
    fondateur Q-P2023-9 : invisible tant qu'aucun relais manuel).

L'organe ne statue jamais : pas de seuil de vétusté, pas de fermeture, pas de
« devrait ». Il rend des faits datés (âge par question, lane porteuse, entrée
remplacée ou non). Le registre local reste l'unique état ; la sortie reste une
vue, jamais un second état.

Entrées reconnues comme « question au user » (les DEUX formes de déclaration,
cf. check-degraded-escalations #4517 — une mention en prose ne compte pas) :
  - tag `ask-user` dans la ligne `[tags: ...]` ;
  - premier token du corps utile : `[ASK-USER]` ou `[ASK USER]`.

    python collect_open_user_questions.py                 # bloc markdown
    python collect_open_user_questions.py --json          # même matière en JSON
    python collect_open_user_questions.py --dashboard-file f.md   # fixture/test
    python collect_open_user_questions.py --now 2026-11-18T06:00:00Z

Codes de sortie :
    0   bloc rendu (avec ou sans questions — un « zéro question » n'est rendu
        que si TOUS les dashboards ont été lus)
    2   instrument défaillant (dashboard illisible, source absente ou sans
        dashboard) — un fichier muet n'est jamais un « zéro question »
        (fail-closed)

Limite connue (vivant seulement) : seules les entrées intercom vivantes sont
lues. Une question dont le post a été condensé dans une archive disparaît de
la vue ; et une entrée global plus récente de la même lane est lue comme
couvrant les questions hors-global de cette lane sans preuve de contenu.
Le registre local reste la source de vérité.
"""

import argparse
import importlib.util
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_SHARED = Path("G:/Mon Drive/Synchronisation/RooSync/.shared-state")

_HERE = Path(__file__).resolve().parent


def _load_store_reader():
    """Primitives de lecture store du lecteur d'escalades (#4517/#4519) :
    transport MCP `call_dashboard_tool`, parse JSON `entries_from_store_json`,
    resolution bearer `resolve_env_file` + `resolve_proxy_config` +
    `load_organ_env_file`. Meme transport, meme precedence — la lecture prend
    le chemin de l'ecriture."""
    spec = importlib.util.spec_from_file_location(
        "check_degraded_escalations", _HERE / "check-degraded-escalations.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

# Mêmes primitives que check-degraded-escalations.py (l.154-195) : le format
# intercom du miroir est un contrat partagé, pas une coïncidence.
ENTRY_RE = re.compile(r"^### \[(?P<ts>\d{4}-\d{2}-\d{2}T[^\]]+)\] (?P<lane>\S+)\s*$", re.M)
TAGS_RE = re.compile(r"^\[tags:\s*(?P<tags>[^\]]*)\]", re.M)
META_LINE_RE = re.compile(r"^\[(?:msg|reply-to|ack|tags):[^\]]*\]$")

ASK_USER_TAG = "ask-user"
ASK_USER_HEADER_RE = re.compile(r"^\[\s*ASK[- ]USER\s*\]", re.I)

# Une ligne-question de l'entrée consolidée : `- **Q4** (26 j, EPIC …) — …`.
# Qid tolérant : Q4, Q-P2023-9, Q15b. L'âge vit dans la parenthèse liminaire.
QUESTION_LINE_RE = re.compile(
    r"^\s*(?:[-*]\s+)?\*{0,2}(?P<qid>Q[A-Za-z0-9_-]+)\*{0,2}\s*"
    r"\((?P<paren>[^)]*)\)\s*(?P<rest>.*)$")
AGE_RE = re.compile(r"^\s*(?P<n>\d+)\s*(?:j\b|d\b|jrs?\b|jours?\b|days?\b)", re.I)

EXCERPT_LEN = 90


def parse_ts(text):
    """ISO-8601 -> datetime UTC. Tolère le suffixe `Z` et les fractions."""
    cleaned = text.strip().replace("Z", "+00:00")
    stamp = datetime.fromisoformat(cleaned)
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=timezone.utc)
    return stamp.astimezone(timezone.utc)


def tags_from_text(text):
    """Tags portés par une ligne `[tags: ...]` du corps, en minuscules."""
    match = TAGS_RE.search(text or "")
    if not match:
        return set()
    return {t.strip().lower() for t in match.group("tags").split(",") if t.strip()}


def declaration_text(body):
    """Corps privé des lignes de métadonnées de tête (`[msg: …]`) et vides."""
    lines = body.splitlines()
    index = 0
    while index < len(lines):
        stripped = lines[index].strip()
        if stripped and not META_LINE_RE.match(stripped):
            break
        index += 1
    return "\n".join(lines[index:])


def parse_entries(text):
    """Découpe un dashboard en messages intercom, dans l'ordre du fichier.

    Chaque entrée : {ts, lane, tags:set, body}. Un fichier sans entête
    intercom rend une liste vide.
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


def is_user_question(entry):
    """Une DÉCLARATION de question au user, jamais une mention en prose.

    Deux formes (contrat partagé avec #4517) : le tag `ask-user`, ou le token
    `[ASK-USER]`/`[ASK USER]` en premier token du corps utile. Un `[DONE]`
    qui raconte une question passée, une review qui cite `ASK-USER` — pas
    des questions.
    """
    if ASK_USER_TAG in entry["tags"]:
        return True
    return bool(ASK_USER_HEADER_RE.match(declaration_text(entry["body"]).lstrip()))


def parse_age_days(paren):
    """`(26 j, EPIC #x)` -> 26. `(3 days)`, `(15d)` tolérés. Sinon None."""
    match = AGE_RE.match(paren or "")
    return int(match.group("n")) if match else None


def parse_questions(body):
    """Questions listées dans une entrée consolidée.

    Rend (questions, unparsed). `questions` : [{qid, age_days, excerpt}] pour
    les lignes au format `Qxx (…)` ; `unparsed` = True quand le corps porte du
    texte mais AUCUNE ligne ne matche — l'entrée reste visible (« format non
    parsé, voir l'entrée ») sans que l'organe n'invente une question.
    """
    questions = []
    saw_question_line = False
    saw_content = False
    for line in body.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        match = QUESTION_LINE_RE.match(stripped)
        if match:
            saw_question_line = True
            excerpt = (match.group("rest") or "").strip()
            questions.append({"qid": match.group("qid"),
                              "age_days": parse_age_days(match.group("paren")),
                              "excerpt": excerpt[:EXCERPT_LEN]})
        elif stripped and not META_LINE_RE.match(stripped):
            saw_content = True
    return questions, (saw_content and not saw_question_line)


def excerpt_of(entry):
    text = declaration_text(entry["body"]).strip().splitlines()
    first = next((l.strip() for l in text if l.strip()), "")
    return first[:EXCERPT_LEN]


def age_days_since(ts, now):
    delta = now - ts
    return max(0, delta.days)


def load_dashboards(paths):
    """(boards, errors). Un fichier illisible ne masque pas les autres —
    mais il est rapporté, et main() rend exit 2 (fail-closed)."""
    boards = []
    errors = []
    for path in paths:
        try:
            text = Path(path).read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            errors.append(f"{path}: {exc}")
            continue
        boards.append({"path": str(path), "type": type_from_name(Path(path).name),
                       "entries": parse_entries(text)})
    return boards, errors


def type_from_name(name):
    """global | machine | workspace — le nom de fichier porte le type."""
    stem = name[:-3] if name.endswith(".md") else name
    if stem == "global":
        return "global"
    if stem.startswith("machine-"):
        return "machine"
    return "workspace"


def default_dashboard_files(dashboard_dir):
    """Dashboards de premier niveau ; copies de conflit DriveFS exclues
    (`workspace-x (1).md` dupliquerait chaque question, #4439)."""
    root = Path(dashboard_dir)
    return sorted(p for p in root.glob("*.md")
                  if " (" not in p.name and p.name != "mcp-dashboard.md")


def load_dashboards_from_store(url, bearer, timeout=10.0, intercom_limit=500):
    """(boards, errors) — dashboards servis par le STORE (PG), autorite depuis
    #4131 G-DASH : le miroir G: est un export derive, repare toutes les 6 h,
    sans marqueur de vétusté ; une vue ASK-USER lue sur le miroir serait
    presentee comme fraiche alors qu'elle peut etre vide ou gelee.

    Lecture JSON (`entries_from_store_json`) : les tags du CHAMP sont unis a
    ceux du CORPS par cette primitive (review #4519 SHOULD-2) — une entree
    declaree par `[tags: ask-user]` dans le corps est reconnue sur les deux
    surfaces.

    Une lecture en echec ou un dashboard absent du listing est une erreur
    d'instrument : « je ne vois pas le dashboard » n'est jamais « zero
    question » (fail-closed)."""
    organ = _load_store_reader()
    call = organ._load_transport()
    boards, errors = [], []
    listing = call({"action": "list"}, url, bearer, timeout=timeout)
    if listing is None:
        return [], ["store injoignable (listing)"]
    keys = organ.store_keys_from_listing(listing)
    if not keys:
        return [], ["listing store vide ou illisible — aucun dashboard servi"]
    for key in keys:
        args = organ.read_arguments_for_key(key, intercom_limit)
        result = call(args, url, bearer, timeout=timeout)
        if result is None:
            errors.append(f"{key}: lecture store muette")
            continue
        text = organ.tool_result_text(result)
        try:
            entries = organ.entries_from_store_json(text)
        except Exception as exc:  # enveloppe inattendue = instrument, pas repli
            errors.append(f"{key}: {type(exc).__name__}: {exc}")
            continue
        if entries is None:  # hote ancien sans JSON — repli parse markdown
            entries = parse_entries(text)
        for entry in entries:
            if "tags" not in entry or entry["tags"] is None:
                entry["tags"] = set()
        boards.append({"path": key, "type": type_from_name(key),
                       "entries": entries})
    return boards, errors


def collect(boards, now):
    """La matière de la sortie. boards = sortie de load_dashboards()."""
    # 1. Vue global : dernière entrée ASK-USER par lane.
    views = {}
    superseded = 0
    for board in boards:
        if board["type"] != "global":
            continue
        for entry in board["entries"]:
            if not is_user_question(entry):
                continue
            lane = entry["lane"]
            if lane in views:
                if entry["ts"] >= views[lane]["ts"]:
                    superseded += 1
                    views[lane] = entry
                else:
                    superseded += 1
            else:
                views[lane] = entry
    lanes = []
    for lane in sorted(views):
        entry = views[lane]
        questions, unparsed = parse_questions(entry["body"])
        lanes.append({
            "lane": lane,
            "entry_ts": entry["ts"].isoformat(),
            "entry_age_days": age_days_since(entry["ts"], now),
            "questions": questions,
            "unparsed_format": unparsed,
            "excerpt": excerpt_of(entry),
        })

    # 2. Hors global : question au user sur machine/workspace, sans vue global
    #    de la même lane au moins aussi récente (= consolidée depuis).
    off_global = []
    for board in boards:
        if board["type"] == "global":
            continue
        for entry in board["entries"]:
            if not is_user_question(entry):
                continue
            view = views.get(entry["lane"])
            if view is not None and view["ts"] >= entry["ts"]:
                continue  # consolidée au global depuis
            off_global.append({
                "lane": entry["lane"],
                "dashboard": Path(board["path"]).name,
                "ts": entry["ts"].isoformat(),
                "age_days": age_days_since(entry["ts"], now),
                "excerpt": excerpt_of(entry),
            })
    off_global.sort(key=lambda q: q["ts"], reverse=True)
    return {"generated_at": now.isoformat(),
            "lanes": lanes, "superseded_entries": superseded,
            "off_global": off_global}


def render_markdown(data):
    total = sum(len(l["questions"]) for l in data["lanes"])
    lines = []
    if data.get("degraded_source"):
        # Règle 4 degraded-escalation (#4826) : une sortie dégradée ne se
        # rapporte jamais comme un résultat normal — le label vit dans le
        # bloc stdout lui-même, pas seulement en stderr/JSON.
        lines.append(f"**[SOURCE DÉGRADÉE : {data['degraded_source']}]**")
        lines.append("")
    lines += [
        "# Questions ouvertes flotte",
        f"(reconstruit {data['generated_at']} par collect_open_user_questions.py — "
        "lecture seule, source : dashboards ; le registre local de chaque lane "
        "reste l'état, ceci est une vue)",
        "",
        f"**{len(data['lanes'])} lane(s), {total} question(s) dans la vue global "
        f"consolidée** ; {len(data['off_global'])} question(s) vivant hors global.",
        "",
    ]
    if data["lanes"]:
        lines.append("## Vue global consolidée (dernière entrée ASK-USER par lane)")
        lines.append("")
        for lane in data["lanes"]:
            age = lane["entry_age_days"]
            suffix = f", entrée âgée de {age} j" if age else ""
            lines.append(f"### {lane['lane']} (entrée du {lane['entry_ts']}{suffix})")
            if lane["questions"]:
                for q in lane["questions"]:
                    qage = f"{q['age_days']} j" if q["age_days"] is not None else "âge non porté"
                    lines.append(f"- **{q['qid']}** — {qage} — {q['excerpt'] or '—'}")
            elif lane["unparsed_format"]:
                lines.append(f"- (format non parsé — voir l'entrée : {lane['excerpt']})")
            else:
                lines.append("- (entrée sans question listée)")
            lines.append("")
    else:
        lines.append("## Vue global consolidée")
        lines.append("")
        lines.append("(aucune entrée ASK-USER au global — rien consolidé)")
        lines.append("")

    lines.append("## Hors global (question au user sans entrée ASK-USER au moins aussi récente)")
    lines.append("")
    if data["off_global"]:
        for q in data["off_global"]:
            lines.append(f"- **{q['lane']}** — {q['dashboard']} — {q['ts']} "
                         f"({q['age_days']} j) : {q['excerpt']}")
    else:
        lines.append("(aucune)")
    lines.append("")
    if data["superseded_entries"]:
        lines.append(f"_Entrées remplacées par une plus récente de la même lane : "
                     f"{data['superseded_entries']}._")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Organe lecture seule « questions ouvertes flotte » (#4821).")
    parser.add_argument("--dashboards-dir", default=str(DEFAULT_SHARED / "dashboards"),
                        help="répertoire des dashboards (défaut : miroir G: RooSync)")
    parser.add_argument("--dashboard-file", action="append", default=None,
                        dest="dashboard_files", metavar="FILE",
                        help="dashboard explicite (répétable ; remplace --dashboards-dir) "
                             "— canal fixtures/tests, sans réseau")
    parser.add_argument("--mirror", action="store_true",
                        help="forcer la lecture du miroir G: au lieu du store PG — "
                             "canal de rejeu DEGRADE (export derive, sans marqueur de "
                             "vétusté) ; la sortie est etiquetee")
    parser.add_argument("--env-file", default=None,
                        help="fichier CLE=valeur lu pour le bearer "
                             "(defaut : la variable ORGAN_ENV_FILE, qui porte le "
                             "CHEMIN du fichier du siege, puis "
                             "~/.roo-state-manager/stall-detector.env ; "
                             "valeur vide = aucun fichier, le pointeur compris "
                             "— meme ordre que l'organe des escalades, #4901)")
    parser.add_argument("--now", default=None,
                        help="horloge (ISO-8601) — déterminisme des tests")
    parser.add_argument("--json", action="store_true", dest="as_json",
                        help="sortie JSON au lieu du bloc markdown")
    args = parser.parse_args(argv)

    now = parse_ts(args.now) if args.now else datetime.now(timezone.utc)

    degraded_source = None
    if args.dashboard_files:
        paths = [Path(p) for p in args.dashboard_files]
        if not paths:
            print("aucun dashboard source — aucun verdict de fond n'est rendu",
                  file=sys.stderr)
            return 2
        boards, errors = load_dashboards(paths)
    elif args.mirror:
        paths = default_dashboard_files(args.dashboards_dir)
        if not paths:
            print("source miroir absente ou sans dashboard — un repertoire vide "
                  "n'est pas un « zero question »", file=sys.stderr)
            return 2
        boards, errors = load_dashboards(paths)
        degraded_source = "miroir G: (export derive, peut etre stale/vide)"
    else:
        try:
            organ = _load_store_reader()
            # #4907 : MEME resolution que l'organe des escalades (#4901), sans
            # dupliquer l'ordre — --env-file > pointeur ORGAN_ENV_FILE > defaut.
            # Un --env-file "" explicite signifie « aucun fichier » et coupe
            # aussi le pointeur (un rejeu ne doit pas relire la config du siege).
            env_file, env_file_source = organ.resolve_env_file(args.env_file)
            file_values, env_warning = organ.load_organ_env_file(
                env_file, explicit=env_file_source == "pointer")
            if env_warning:
                print(f"env-file : {env_warning}", file=sys.stderr)
            url, bearer = organ.resolve_proxy_config(None, None, file_values)
            boards, errors = load_dashboards_from_store(url, bearer)
        except Exception as exc:
            # Exception d'import (lecteur store absent/cassé) ou de transport
            # (appel levé, pas retour None) : instrument cassé, pas une lecture
            # ratée — exit 1, distinct du 2 (review #4826).
            print(f"exception d'import ou de transport : "
                  f"{type(exc).__name__}: {exc}", file=sys.stderr)
            return 1
        if errors and not boards:
            print("store PG illisible — repli miroir G: DEGRADE", file=sys.stderr)
            for err in errors:
                print(f"erreur de lecture store : {err}", file=sys.stderr)
            paths = default_dashboard_files(args.dashboards_dir)
            if not paths:
                print("source miroir absente ou sans dashboard — aucun verdict "
                      "de fond n'est rendu (un dashboard muet n'est pas un "
                      "« zero question »)", file=sys.stderr)
                return 2
            boards, mirror_errors = load_dashboards(paths)
            if boards and not mirror_errors:
                # Repli miroir RÉUSSI : rendu 0 dégradé, label en tête du bloc
                # (review #4826) — la panne store est la RAISON du repli
                # (stderr ci-dessus), pas un échec de l'instrument (exit 2).
                errors = []
            else:
                errors = errors + mirror_errors
            degraded_source = "miroir G: (repli — store PG illisible)"

    if errors:
        for err in errors:
            print(f"erreur de lecture : {err}", file=sys.stderr)
        print("instrument défaillant — aucun verdict de fond n'est rendu "
              "(un dashboard muet n'est pas un « zéro question »)", file=sys.stderr)
        return 2

    data = collect(boards, now)
    if degraded_source:
        data["degraded_source"] = degraded_source
    if args.as_json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        if degraded_source:
            print(f"[SOURCE DEGRADEE : {degraded_source} — la vue peut etre "
                  "stale ou incomplete]", file=sys.stderr)
        print(render_markdown(data))
    return 0


if __name__ == "__main__":
    sys.exit(main())

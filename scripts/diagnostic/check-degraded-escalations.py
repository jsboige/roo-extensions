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
    1   erreur d'instrument (dashboards illisibles, ou --ring demande et non poste)

Usage :
    python check-degraded-escalations.py                       # lit $ROOSYNC_SHARED_PATH/dashboards
    python check-degraded-escalations.py --cycles 2 --cycle-hours 4
    python check-degraded-escalations.py --json
    python check-degraded-escalations.py --ring                # poste ASK-USER sur le dashboard global
    python check-degraded-escalations.py --dashboard-file <copie.md>   # rejeu hors G:
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
TAGS_RE = re.compile(r"^\[tags:\s*(?P<tags>[^\]]*)\]\s*$", re.M)
# Frontiere de mot obligatoire : `[DEGRADED-FIXED]` n'est pas `[DEGRADED]`.
DEGRADED_RE = re.compile(r"\[DEGRADED\](?![A-Za-z0-9_-])")
REPAIRED_RE = re.compile(r"\[REPAIRED\](?![A-Za-z0-9_-])")


def parse_ts(text):
    """ISO-8601 -> datetime UTC. Tolere le suffixe `Z` et les fractions."""
    cleaned = text.strip().replace("Z", "+00:00")
    stamp = datetime.fromisoformat(cleaned)
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=timezone.utc)
    return stamp.astimezone(timezone.utc)


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
        tags = TAGS_RE.search(entry["body"])
        entry["tags"] = ({t.strip().lower() for t in tags.group("tags").split(",") if t.strip()}
                         if tags else set())
    return entries


def is_degraded(entry):
    return "degraded" in entry["tags"] or bool(DEGRADED_RE.search(entry["body"]))


def is_repaired(entry):
    return "repaired" in entry["tags"] or bool(REPAIRED_RE.search(entry["body"]))


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


def build_ring_content(overdue):
    lines = [f"[ASK-USER][DEGRADED-ESCALATION] {len(overdue)} escalade(s) "
             f"d'environnement degrade non reparee(s) dans les delais."]
    for item in overdue:
        lines.append(f"- {item['lane']} — degrade depuis {item['posted']}, "
                     f"echeance {item['deadline']} depassee : {item['excerpt'][:120]}")
    lines.append("Le mecanisme porte l'echeance, pas la memoire de la lane : "
                 "un `[REPAIRED]` de la lane ferme l'escalade, un `[DONE]` non.")
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
    """append_dashboard() depuis detect-approval-stalls.py — un seul transport
    de dashboard pour la flotte (meme motif que check-mcp-seats.py qui importe
    handshake() au lieu d'en ecrire un second). Importlib : le nom de fichier
    porte un tiret, il n'est pas importable comme module."""
    here = Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location(
        "detect_approval_stalls", here / "detect-approval-stalls.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.append_dashboard


def publish_ring(overdue, url, bearer, timeout=10.0, now=None):
    arguments = {
        "action": "append",
        "type": "global",
        "tags": ["ASK-USER", "DEGRADED-ESCALATION"],
        "content": build_ring_content(overdue),
        "messageId": build_ring_id(overdue, now=now),
    }
    return _load_transport()(arguments, url, bearer, timeout=timeout,
                             client="degraded-escalations")


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
          "non confondue avec 'rien a signaler', idempotence quotidienne.")


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

    if args.dashboard_file:
        paths = [Path(p) for p in args.dashboard_file]
    else:
        shared = Path(os.environ.get("ROOSYNC_SHARED_PATH") or DEFAULT_SHARED)
        paths = default_dashboard_files(shared / "dashboards")

    entries, errors = load_entries(paths)
    for err in errors:
        print(f"WARNING: dashboard illisible — {err}", file=sys.stderr)

    now = parse_ts(args.now) if args.now else datetime.now(timezone.utc)
    escalations = collect_escalations(entries, now, cycles=args.cycles,
                                      cycle_hours=args.cycle_hours)
    code, reason = verdict(escalations)
    report(escalations, code, reason, args.json)

    if not paths:
        print("ERROR: aucun dashboard a lire — « rien a signaler » serait un mensonge "
              "sur une mesure absente", file=sys.stderr)
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

    return code


if __name__ == "__main__":
    sys.exit(main())

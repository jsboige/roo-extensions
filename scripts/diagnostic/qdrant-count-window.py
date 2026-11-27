#!/usr/bin/env python3
"""#4928 — Fenetre de mesure avant/apres du comptage de points par hote.

Le correctif ms#1933 (#4928) remplace UN scan exact par une estimation :
`countPointsByHostOs` passe de `exact: true` a `exact: false`. Il ne change ni
le nombre de comptages, ni les deux gardes qui restent exactes
(`resetCollection`, `cleanupOldVectors`). Mesurer « la charge en moins » se
fait donc en quatre axes, rendus ici sous une forme IDENTIQUE avant et apres
pour que l'effet du correctif ne se confonde pas avec un retablissement reseau :

  1. build servie      — vintage par hote VIVANT (ligne de commande) + SHA
                         source de la build sur disque (build-info.json) +
                         recensement des sites `exact:` du compile ;
  2. comptages         — lignes de controle de coherence (tentative, ignore,
                         resultat, timeout), si un canal stderr est persiste ;
                         a defaut, proxy = demarrages de serveur par jour ;
  3. gardes            — chaque site `exact:` est attribue a sa fonction ; les
                         deux gardes doivent rester exactes, la cible doit etre
                         estimee. Une garde introuvable n'est PAS un succes ;
  4. latence lecture   — aucune ligne de lecture Qdrant n'est persistee sur ce
                         siege (mesure du 26/11) : rendu NOT_OBSERVABLE, avec
                         le contexte du chemin d'ecriture (`qdrant_upsert_failed`)
                         qui sert de discriminateur du retablissement reseau.

Ce que la mesure du 26/11 (po-2028) a etabli, et qui justifie la forme :
  - `src/index.ts` redirige `console.log` vers stderr ; les lignes du controle
    de coherence ne passent PAS par le `logger` fichier — absentes des
    `roosync-*.log` (0 sur 123 fichiers) ;
  - les captures stderr MCP sont a 0 octet sur ce siege (VS Code) : l'axe 2 et
    la latence de comptage ne sont lisibles que la ou une capture est persistee ;
  - la vintage servie EST lisible par processus (`build-<16 hex>` dans la ligne
    de commande de l'enfant) ; `build-info.json` porte la SHA source ;
  - le build est adresse par contenu : une reecriture dans le meme dossier de
    vintage ne change PAS ce qui est servi — seul le nom de vintage compte.

Contrat de sortie :
    0 = fenetre rendue (quelle que soit la valeur des axes). Un journal ABSENT
        rend les series qui en dependent NOT_OBSERVABLE, dossier nomme : jamais
        `aucun`, qui se lit comme « zero defaut » ;
    2 = erreur d'instrument (build introuvable ou journal illisible)

Lecture seule. Stdlib uniquement. Aucun appel reseau, aucun `count`, aucune
charge sur Qdrant. Aucune ligne de commande de processus n'est imprimee : seuls
la vintage et l'instant de demarrage sortent de la requete de processus.
"""
import argparse
import datetime
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter

# Le build cible : la fonction dont le site `exact:` doit passer a false.
TARGET_FUNCTION = "countPointsByHostOs"
# Les deux gardes : un `exact: false` ici est un defaut, pas une optimisation.
GUARD_FUNCTIONS = ("resetCollection", "cleanupOldVectors")

VINTAGE_RE = re.compile(r"build-[0-9a-f]{16}")
EXACT_RE = re.compile(r"\bexact\s*:\s*(true|false)")
FUNC_RE = re.compile(
    r"^(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(", re.M)
# Horodatage du logger : `new Date().toISOString()` -> UTC, sans suffixe Z.
LINE_RE = re.compile(r"^\[(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})\]")

# Signatures emises par verifyQdrantConsistency (console.log -> stderr).
SIGNATURES = (
    ("attempt", "Vérification de la cohérence Qdrant vs Squelettes"),
    ("skipped", "Vérification Qdrant ignorée"),
    ("result", "Points Qdrant (machine"),
    ("timeout", "Qdrant count timeout after 10s"),
    ("error", "Could not count points for host_os="),
)
UPSERT_FAILED = "retry_fail [qdrant_upsert_failed]"
SERVER_STARTED = "Server started"

PS_QUERY = r"""
Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.CommandLine -match 'roo-state-manager' } |
  ForEach-Object {
    [pscustomobject]@{
      wrapper = [bool]($_.CommandLine -match 'mcp-wrapper\.cjs')
      vintage = $(if ($_.CommandLine -match 'build-[0-9a-f]{16}') { $Matches[0] } else { $null })
      started = $(if ($_.CreationDate) { $_.CreationDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } else { $null })
    }
  } | ConvertTo-Json -Compress
"""


class InstrumentError(RuntimeError):
    """Le lecteur ne peut pas conclure : jamais une valeur inventee."""


def strip_js_comments(src):
    """Retire commentaires et garde les numeros de ligne (compiles tsc : JSDoc garde)."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "*":
            end = src.find("*/", i + 2)
            end = n if end < 0 else end + 2
            out.append("\n" * src.count("\n", i, end))
            i = end
        elif c == "/" and nxt == "/":
            end = src.find("\n", i)
            end = n if end < 0 else end
            i = end
        elif c in "\"'`":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            out.append(src[i:j + 1])
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def census_exact_sites(compiled):
    """Chaque `exact: true|false` avec sa ligne et sa fonction englobante."""
    stripped = strip_js_comments(compiled)
    functions = [(m.start(), m.group(1)) for m in FUNC_RE.finditer(stripped)]
    sites = []
    for m in EXACT_RE.finditer(stripped):
        owner = None
        for pos, name in functions:
            if pos <= m.start():
                owner = name
            else:
                break
        sites.append({
            "line": stripped.count("\n", 0, m.start()) + 1,
            "value": m.group(1) == "true",
            "function": owner,
        })
    return sites


def verdicts(sites):
    """fix = la cible est-elle estimee ; guards = les gardes sont-elles exactes."""
    by_fn = {}
    for site in sites:
        by_fn.setdefault(site["function"], []).append(site["value"])
    target = by_fn.get(TARGET_FUNCTION)
    if not target:
        fix = "TARGET_UNKNOWN"
    elif all(v is False for v in target):
        fix = "FIX_PRESENT"
    else:
        fix = "FIX_ABSENT"
    guards = {}
    for name in GUARD_FUNCTIONS:
        values = by_fn.get(name)
        if not values:
            guards[name] = "UNKNOWN"
        elif all(values):
            guards[name] = "EXACT"
        else:
            guards[name] = "NOT_EXACT"
    overall = "GUARDS_EXACT" if all(
        v == "EXACT" for v in guards.values()) else "GUARDS_NOT_EXACT"
    return fix, overall, guards


def read_build(rsm_root, vintage=None):
    """Faits de la build sur disque : vintage, SHA source, sites exact."""
    if vintage is None:
        pointer = os.path.join(rsm_root, "build-current")
        if not os.path.isfile(pointer):
            raise InstrumentError("build-current absent sous " + rsm_root)
        with open(pointer, "r", encoding="utf-8") as handle:
            vintage = handle.read().strip()
    build_dir = os.path.join(rsm_root, vintage)
    compiled = os.path.join(build_dir, "services", "task-indexer", "VectorIndexer.js")
    if not os.path.isfile(compiled):
        raise InstrumentError(
            "compile introuvable : " + compiled + " (vintage perimee ?)")
    info = {}
    info_path = os.path.join(build_dir, "build-info.json")
    if os.path.isfile(info_path):
        with open(info_path, "r", encoding="utf-8") as handle:
            info = json.load(handle)
    with open(compiled, "r", encoding="utf-8", errors="replace") as handle:
        sites = census_exact_sites(handle.read())
    fix, guards, guard_map = verdicts(sites)
    return {
        "vintage": vintage,
        "sourceSha": info.get("shortSha"),
        "fullSha": info.get("sha"),
        "dirty": info.get("dirty"),
        "builtAt": info.get("builtAt"),
        "version": info.get("version"),
        "exact_true": sum(1 for s in sites if s["value"]),
        "exact_false": sum(1 for s in sites if not s["value"]),
        "fix": fix,
        "guards": guards,
        "guard_detail": guard_map,
        "sites": sites,
    }


def live_hosts():
    """Enfants serveur et vintage servie, par processus. None hors Windows."""
    if os.name != "nt":
        return {"supported": False,
                "reason": "process query is Windows-only (Win32_Process)"}
    try:
        proc = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", PS_QUERY],
            capture_output=True, text=True, timeout=90,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return {"supported": True, "error": type(exc).__name__}
    if proc.returncode != 0:
        return {"supported": True, "error": "powershell exit %d" % proc.returncode}
    raw = proc.stdout.strip()
    if not raw:
        return {"supported": True, "children": 0, "wrappers": 0, "vintages": {}}
    try:
        data = json.loads(raw)
    except ValueError:
        return {"supported": True, "error": "unparsable process query output"}
    if isinstance(data, dict):
        data = [data]
    children = [row for row in data if not row.get("wrapper")]
    vintages = Counter(row.get("vintage") or "(none in cmdline)" for row in children)
    starts = sorted(row["started"] for row in children if row.get("started"))
    return {
        "supported": True,
        "children": len(children),
        "wrappers": sum(1 for row in data if row.get("wrapper")),
        "vintages": dict(vintages),
        "oldestStart": starts[0] if starts else None,
        "newestStart": starts[-1] if starts else None,
    }


def log_window(log_dir, since, until):
    """Histogramme des journaux fichier dans [since, until] (jours UTC)."""
    if not os.path.isdir(log_dir):
        return {"available": False, "dir": log_dir, "files": 0,
                "server_started": Counter(), "upsert_failed": Counter(),
                "signatures": Counter()}
    result = {
        "available": True,
        "dir": log_dir,
        "files": 0,
        "dated_lines": 0,
        "server_started": Counter(),
        "upsert_failed": Counter(),
        "signatures": Counter(),
    }
    for path in sorted(glob.glob(os.path.join(log_dir, "roosync-*.log"))):
        result["files"] += 1
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                match = LINE_RE.match(line)
                if not match:
                    continue
                day = match.group(1)
                if not (since <= day <= until):
                    continue
                result["dated_lines"] += 1
                if SERVER_STARTED in line:
                    result["server_started"][day] += 1
                if UPSERT_FAILED in line:
                    result["upsert_failed"][day] += 1
                for key, signature in SIGNATURES:
                    if signature in line:
                        result["signatures"][key] += 1
    return result


def stderr_captures():
    """Captures stderr MCP persistees (VS Code). Aucune : l'axe 2 reste muet."""
    roots = []
    if os.environ.get("APPDATA"):
        roots.append(os.path.join(os.environ["APPDATA"], "Code", "logs"))
    roots.append(os.path.join(os.path.expanduser("~"), ".config", "Code", "logs"))
    files, non_empty, signatures = 0, 0, Counter()
    for root in roots:
        if not os.path.isdir(root):
            continue
        pattern = os.path.join(
            root, "*", "window*", "mcpServer.*roo-state-manager*.log")
        for path in glob.glob(pattern):
            files += 1
            if os.path.getsize(path) == 0:
                continue
            non_empty += 1
            try:
                with open(path, "r", encoding="utf-8", errors="replace") as handle:
                    text = handle.read()
            except OSError:
                continue
            for key, signature in SIGNATURES:
                signatures[key] += text.count(signature)
    return {"files": files, "nonEmpty": non_empty,
            "signatures": dict(signatures)}


def build_report(args):
    report = {"window": {"since": args.since, "until": args.until,
                         "logDir": args.log_dir, "rsmRoot": args.rsm_root}}
    build = read_build(args.rsm_root)
    hosts = None if args.no_hosts else live_hosts()
    if hosts and hosts.get("supported") and hosts.get("children"):
        cohorts = {}
        for vintage in hosts["vintages"]:
            if not VINTAGE_RE.fullmatch(vintage):
                cohorts[vintage] = {"fix": "UNKNOWN", "reason": "no vintage in cmdline"}
                continue
            try:
                facts = read_build(args.rsm_root, vintage)
                cohorts[vintage] = {
                    "fix": facts["fix"], "guards": facts["guards"],
                    "sourceSha": facts["sourceSha"], "builtAt": facts["builtAt"],
                    "exact_true": facts["exact_true"],
                    "exact_false": facts["exact_false"],
                }
            except (InstrumentError, OSError, ValueError) as exc:
                cohorts[vintage] = {"fix": "UNKNOWN", "reason": str(exc)}
        hosts["cohorts"] = cohorts
    logs = log_window(args.log_dir, args.since, args.until)
    report["axes"] = {
        "build": build,
        "hosts": hosts,
        "counts": {
            "observable_via": "stderr capture only",
            "capture": stderr_captures(),
            "fileSignatures": logs["signatures"],
            "serverStartsPerDay": logs["server_started"],
            "logFiles": logs["files"],
            "logDirPresent": logs["available"],
        },
        "readLatency": {
            "observable": False,
            "why": "no Qdrant read line is persisted; consistency lines go to "
                   "stderr (src/index.ts console.log -> console.error) and the "
                   "MCP stderr captures are not kept on this seat",
            "writePathContext": logs["upsert_failed"],
            "writePathObservable": logs["available"],
        },
    }
    return report


def render(report):
    build = report["axes"]["build"]
    hosts = report["axes"]["hosts"]
    counts = report["axes"]["counts"]
    latency = report["axes"]["readLatency"]
    window = report["window"]
    out = ["[qdrant-count-window] %s..%s (UTC days)" % (
        window["since"], window["until"])]
    out.append("AXE1 build servie  | disque %s sourceSha=%s builtAt=%s dirty=%s" % (
        build["vintage"], build["sourceSha"], build["builtAt"], build["dirty"]))
    out.append("                   | %s guards=%s exact_true=%d exact_false=%d" % (
        build["fix"], build["guards"], build["exact_true"], build["exact_false"]))
    for site in build["sites"]:
        out.append("                   |   L%-5d %-22s %s" % (
            site["line"], site["function"] or "(top-level)",
            "true" if site["value"] else "false"))
    if hosts is None:
        out.append("AXE1 vivants       | skipped (--no-hosts)")
    elif not hosts.get("supported"):
        out.append("AXE1 vivants       | NOT_OBSERVABLE (%s)" % hosts.get("reason"))
    elif hosts.get("error"):
        out.append("AXE1 vivants       | INSTRUMENT ERROR (%s)" % hosts["error"])
    else:
        out.append("AXE1 vivants       | enfants=%d wrappers=%d cohortes=%s" % (
            hosts["children"], hosts["wrappers"],
            ", ".join("%s x%d" % (v, n) for v, n in hosts["vintages"].items())))
        for vintage, facts in (hosts.get("cohorts") or {}).items():
            out.append("                   |   %s -> %s" % (vintage, facts["fix"]))
        if hosts.get("oldestStart"):
            out.append("                   | demarrages %s .. %s" % (
                hosts["oldestStart"], hosts["newestStart"]))
    capture = counts["capture"]
    out.append("AXE2 comptages     | capture stderr: fichiers=%d nonVides=%d %s" % (
        capture["files"], capture["nonEmpty"],
        " ".join("%s=%d" % (k, capture["signatures"].get(k, 0))
                 for k, _ in SIGNATURES)))
    if counts["logDirPresent"]:
        out.append("                   | en fichiers (%d): %s" % (
            counts["logFiles"],
            " ".join("%s=%d" % (k, counts["fileSignatures"].get(k, 0))
                     for k, _ in SIGNATURES)))
    else:
        out.append("                   | en fichiers: NOT_OBSERVABLE (journal absent)")
    if capture["nonEmpty"] == 0 and counts["logFiles"] == 0:
        out.append("                   | NOT_OBSERVABLE (ni capture stderr ni journal)")
    elif capture["nonEmpty"] == 0:
        out.append("                   | NOT_OBSERVABLE (capture stderr non persistee)")
    starts = counts["serverStartsPerDay"]
    if counts["logDirPresent"]:
        out.append("AXE2 proxy         | demarrages serveur/jour: %s" % (
            " ".join("%s:%d" % (d[5:], n) for d, n in sorted(starts.items())) or "aucun"))
    else:
        out.append("AXE2 proxy         | NOT_OBSERVABLE (journal absent : %s)" % (
            window["logDir"]))
    out.append("AXE4 latence lue   | NOT_OBSERVABLE (%s)" % latency["why"])
    writes = latency["writePathContext"]
    if latency["writePathObservable"]:
        out.append("AXE4 ecriture      | qdrant_upsert_failed/jour: %s" % (
            " ".join("%s:%d" % (d[5:], n) for d, n in sorted(writes.items())) or "aucun"))
    else:
        out.append("AXE4 ecriture      | NOT_OBSERVABLE (journal absent : %s)" % (
            window["logDir"]))
    return "\n".join(out)


SELFTEST_BEFORE = """
export async function resetCollection(options) {
  const existing = await qdrant.count(C, { exact: true });
}
export async function countPointsByHostOs(hostOs) {
  // commentaire: historiquement `exact: true` ici, voir #4928
  return await qdrant.count(C, {
    filter: f,
    exact: true
  });
}
export async function cleanupOldVectors(maxAgeDays = 90) {
  return await qdrant.count(C, { exact: true });
}
async function preflightDedupByChunkId(chunks) {
  return await qdrant.count(C, { exact: false });
}
"""

SELFTEST_AFTER = SELFTEST_BEFORE.replace(
    "    exact: true\n  });\n}\nexport async function cleanupOldVectors",
    "    exact: false\n  });\n}\nexport async function cleanupOldVectors")


def selftest():
    checks = 0

    def check(cond, label):
        nonlocal checks
        if not cond:
            raise AssertionError("SELFTEST FAILED: " + label)
        checks += 1

    before = census_exact_sites(SELFTEST_BEFORE)
    fix, guards, detail = verdicts(before)
    check(fix == "FIX_ABSENT", "before -> fix absent")
    check(guards == "GUARDS_EXACT", "before -> guards exact")
    check(sum(1 for s in before if s["value"]) == 3, "before -> 3 sites exacts")
    check(sum(1 for s in before if not s["value"]) == 1, "before -> 1 estimation")
    check(all(s["function"] for s in before), "before -> every site attributed")
    check(len(before) == 4, "comment site not counted (4 real sites)")
    check([s["line"] for s in before] == [3, 9, 13, 16], "before -> line numbers pinned")

    after = census_exact_sites(SELFTEST_AFTER)
    fix, guards, detail = verdicts(after)
    check(fix == "FIX_PRESENT", "after -> fix present")
    check(guards == "GUARDS_EXACT", "after -> guards still exact")
    check(sum(1 for s in after if s["value"]) == 2, "after -> 2 sites exacts")
    check(sum(1 for s in after if not s["value"]) == 2, "after -> 2 estimations")

    broken = SELFTEST_AFTER.replace(
        "  const existing = await qdrant.count(C, { exact: true });",
        "  const existing = await qdrant.count(C, { exact: false });")
    fix, guards, detail = verdicts(census_exact_sites(broken))
    check(guards == "GUARDS_NOT_EXACT", "mutant guard -> NOT exact")
    check(detail["resetCollection"] == "NOT_EXACT", "mutant names the guard")

    renamed = SELFTEST_AFTER.replace("resetCollection", "wipeEverything")
    fix, guards, detail = verdicts(census_exact_sites(renamed))
    check(guards == "GUARDS_NOT_EXACT", "renamed guard -> not a success")
    check(detail["resetCollection"] == "UNKNOWN", "renamed guard -> UNKNOWN")

    untargeted = SELFTEST_AFTER.replace("countPointsByHostOs", "countSomething")
    fix, guards, detail = verdicts(census_exact_sites(untargeted))
    check(fix == "TARGET_UNKNOWN", "renamed target -> TARGET_UNKNOWN")

    # Une fonction a PLUSIEURS sites : un site restant exact n'est pas un succes.
    # `all()` doit rester `all()`, pour la cible comme pour une garde.
    fix, _, _ = verdicts(census_exact_sites(
        "export async function countPointsByHostOs(h) {\n"
        "  a(C, { exact: true });\n"
        "  b(C, { exact: false });\n"
        "}\n"))
    check(fix == "FIX_ABSENT", "two-site target, one left exact -> FIX_ABSENT")
    _, _, detail = verdicts(census_exact_sites(
        "export async function resetCollection(o) {\n"
        "  a(C, { exact: true });\n"
        "  b(C, { exact: false });\n"
        "}\n"))
    check(detail["resetCollection"] == "NOT_EXACT",
          "two-site guard, one estimated -> NOT_EXACT")

    # Limites connues du retrait de commentaires, figees dans leur sens alerte
    # (jamais un faux succes). Le fichier reel n'en contient pas : 4 sites sur 4.
    _, _, detail = verdicts(census_exact_sites(
        "export async function resetCollection(o) {\n"
        "  a(C, { exact: true });\n"
        '  log("exact: false, cite dans un message");\n'
        "}\n"))
    check(detail["resetCollection"] == "NOT_EXACT",
          "quoted exact: false inside a guard -> NOT_EXACT")
    check(census_exact_sites(
        "export async function resetCollection(o) {\n"
        "  const u = /https?:\\/\\//; a(C, { exact: true });\n"
        "}\n") == [], "regex literal ending in \\/ -> site lost (alerting)")

    check(strip_js_comments('a//x\nexact: true').count("exact") == 1,
          "line comment removed, code kept")
    check(strip_js_comments('/* x */exact: true').startswith("exact"),
          "block comment removed")
    check("//" in strip_js_comments('u = "http://x"; v'),
          "string content kept (no false stripping)")

    print("[SELFTEST] PASS (%d checks)" % checks)


def main(argv=None):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    today = datetime.datetime.now(datetime.timezone.utc).date()
    default_since = (today - datetime.timedelta(days=7)).isoformat()

    parser = argparse.ArgumentParser(
        description="Avant/apres mesurable du comptage de points par hote (#4928).")
    parser.add_argument("--rsm-root", default=None,
                        help="racine du RSM (defaut : deduite du script)")
    parser.add_argument("--log-dir", default=os.path.join(
        tempfile.gettempdir(), "roo-state-manager-logs"),
                        help="dossier des journaux roosync-*.log")
    parser.add_argument("--since", default=default_since,
                        help="premier jour UTC inclus (YYYY-MM-DD)")
    parser.add_argument("--until", default=today.isoformat(),
                        help="dernier jour UTC inclus (YYYY-MM-DD)")
    parser.add_argument("--no-hosts", action="store_true",
                        help="ne pas interroger les processus vivants")
    parser.add_argument("--json", action="store_true", help="sortie JSON")
    parser.add_argument("--selftest", action="store_true",
                        help="verifie le recensement et les verdicts hors siege")
    args = parser.parse_args(argv)

    if args.selftest:
        selftest()
        return 0

    if args.rsm_root is None:
        here = os.path.dirname(os.path.abspath(__file__))
        args.rsm_root = os.path.normpath(os.path.join(
            here, "..", "..", "mcps", "internal", "servers", "roo-state-manager"))

    try:
        report = build_report(args)
    except (InstrumentError, OSError, ValueError) as exc:
        print("[qdrant-count-window] INSTRUMENT ERROR: %s" % exc, file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False, sort_keys=False))
    else:
        print(render(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())

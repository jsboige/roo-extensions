#!/usr/bin/env python3
"""test_check_degraded_escalations.py — le contrat de sortie de l'organe #4517.

L'escamotage qu'on teste ici est un escamotage de **code de sortie** : un
automatiseur qui sonne le user ne lit que `$?`. Les cas couvrent donc les
quatre valeurs, et surtout les trois facons de rendre un faux « tout va bien » :
une escalade `[DONE]`-e mais non `[REPAIRED]`, une forme voisine
(`[DEGRADED-FIXED]`), et un dashboard illisible.

Stdlib `unittest` seulement, sans G: ni reseau : `unittest discover -s
scripts/testing/python` tourne en CI sur ubuntu.
"""

import contextlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[2] / "diagnostic" / "check-degraded-escalations.py"


def _load():
    spec = importlib.util.spec_from_file_location("check_degraded_escalations", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cde = _load()
NOW = "2026-11-03T09:00:00Z"  # 8 h after a 01:00Z post == exactly 2 cycles


class EscalationContract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def dashboard(self, name, text):
        path = self.root / name
        path.write_text(text, encoding="utf-8")
        return path

    def run_main(self, *paths):
        argv = []
        for path in paths:
            argv += ["--dashboard-file", str(path)]
        return cde.main(argv + ["--now", NOW])

    def test_clean_dashboard_is_zero(self):
        path = self.dashboard("clean.md", """### [2026-11-03T08:00:00.000Z] a|ws
[tags: DONE]

[DONE] rien de degrade
""")
        self.assertEqual(self.run_main(path), 0)

    def test_open_within_deadline_is_three(self):
        path = self.dashboard("waiting.md", """### [2026-11-03T08:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        self.assertEqual(self.run_main(path), 3)

    def test_overdue_without_repair_is_two(self):
        path = self.dashboard("overdue.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        self.assertEqual(self.run_main(path), 2)

    def test_repaired_closes_the_escalation(self):
        path = self.dashboard("repaired.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet

### [2026-11-03T01:00:00.000Z] a|ws

[REPAIRED] mcp repond, 18 outils
""")
        self.assertEqual(self.run_main(path), 0)

    def test_a_done_never_consecrates_a_degraded_output(self):
        path = self.dashboard("done.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet

### [2026-11-03T01:00:00.000Z] a|ws

[DONE] cycle termine, travail rendu
""")
        self.assertEqual(self.run_main(path), 2)

    def test_repair_from_another_lane_does_not_close(self):
        path = self.dashboard("foreign.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet

### [2026-11-03T01:00:00.000Z] b|ws

[REPAIRED] mcp repond
""")
        self.assertEqual(self.run_main(path), 2)

    def test_near_miss_tag_is_ignored(self):
        path = self.dashboard("near.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED-FIXED] forme voisine, pas une escalade
""")
        self.assertEqual(self.run_main(path), 0)

    def test_unreadable_dashboard_is_an_instrument_error(self):
        # Un disque qui ne rend rien n'est pas un disque propre.
        self.assertEqual(self.run_main(self.root / "absent.md"), 1)

    def test_deadline_is_derived_from_the_post(self):
        path = self.dashboard("deadline.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        entries, errors = cde.load_entries([path])
        self.assertEqual(errors, [])
        item = cde.collect_escalations(entries, cde.parse_ts(NOW))[0]
        self.assertEqual(item["deadline"], "2026-11-03T08:00:00Z")

    def test_cycle_length_is_a_parameter(self):
        path = self.dashboard("cycles.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        entries, _ = cde.load_entries([path])
        item = cde.collect_escalations(entries, cde.parse_ts(NOW),
                                       cycles=1, cycle_hours=4.0)[0]
        self.assertEqual(item["status"], "overdue")

    def test_ring_without_bearer_fails_loudly(self):
        path = self.dashboard("ring.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        code = cde.main(["--dashboard-file", str(path), "--now", NOW, "--ring",
                         "--ring-bearer", ""])
        # La sonnerie n'est pas partie : 1, jamais un 2 qui laisserait croire
        # que le user a ete prevenu.
        self.assertEqual(code, 1)

    def test_transport_is_reused_not_copied(self):
        # Le transport vit dans detect-approval-stalls.py : un seul organe.
        self.assertTrue(callable(cde._load_transport()))

    # --- Review #4519 point a : declaration != mention --------------------

    def test_a_done_that_quotes_the_tag_in_prose_is_zero(self):
        # Post REEL du 03/11 (ai-01, [DONE] 16:53Z) : le tag est CITÉ en prose
        # — l'ancien detecteur en faisait une escalade fantome.
        path = self.dashboard("mention-done.md", """### [2026-11-03T00:00:00.000Z] myia-ai-01|roo-extensions
[tags: DONE]

[DONE] c.57 termine. Rappel : la lane po-2026 a poste `[DEGRADED]` mcp muet
sur son dashboard, l'echeance court.
""")
        self.assertEqual(self.run_main(path), 0)

    def test_a_review_that_quotes_the_tag_in_prose_is_zero(self):
        # Post REEL du 03/11 (NanoClaw, review 17:20Z) : meme citation, meme
        # non-escalade.
        path = self.dashboard("mention-review.md", """### [2026-11-03T00:00:00.000Z] myia-po-2026|nanoclaw
[tags: REPLY]

Review rendue : le tag `[DEGRADED]` du post de 16:53 est bien une escalade,
l'organe doit la compter.
""")
        self.assertEqual(self.run_main(path), 0)

    def test_a_tags_line_alone_declares(self):
        # Temoin positif du point a : la ligne [tags: DEGRADED] des posts de
        # production declare, meme sans token ouvrant le corps.
        path = self.dashboard("tags-declares.md", """### [2026-11-03T08:00:00.000Z] a|ws
[tags: DEGRADED]

environnement degrade : jupyter-papermill muet depuis le preflight
""")
        self.assertEqual(self.run_main(path), 3)

    # --- Review #4519 point b : la sonnerie ne ferme pas son alarme -------

    def test_self_ring_does_not_close_its_own_alarm(self):
        # Escalade overdue + le post de sonnerie de la MEME lane (tags
        # ASK-USER/DEGRADED-ESCALATION, tokens litteraux dans le corps comme
        # les anciennes sonneries en contenaient) : toujours SONNERIE DUE, et
        # exactement UNE escalade — le ring n'en ouvre pas une seconde.
        path = self.dashboard("self-ring.md", """### [2026-11-03T00:00:00.000Z] a|ws
[tags: DEGRADED]

[DEGRADED] sk-agent absent

### [2026-11-03T08:30:00.000Z] a|ws
[tags: ASK-USER, DEGRADED-ESCALATION]

[ASK-USER][DEGRADED-ESCALATION] 1 escalade(s) non reparee(s). une declaration
[REPAIRED] par la lane fermerait l'escalade. Extrait : sk-agent absent.
""")
        self.assertEqual(self.run_main(path), 2)
        entries, _ = cde.load_entries([path])
        escalations = cde.collect_escalations(entries, cde.parse_ts(NOW))
        self.assertEqual(len(escalations), 1)
        self.assertEqual(escalations[0]["status"], "overdue")

    def test_ring_content_carries_no_declaration_token(self):
        # L'extrait peut citer les tokens en prose ; le texte poste ne doit
        # porter AUCUN token litteral, sinon le prochain run lit la sonnerie
        # comme une reparation.
        item = {"lane": "a|ws", "posted": "2026-11-03T00:00:00Z",
                "deadline": "2026-11-03T08:00:00Z", "status": "overdue",
                "repaired_at": None,
                "excerpt": "escalade `[DEGRADED]` citee puis `[REPAIRED]` en prose"}
        content = cde.build_ring_content([item])
        self.assertIsNone(cde.DECLARATION_TOKEN_RE.search(content), content)

    # --- Review #4519 point c : store PG primaire, miroir degrade ---------

    def run_mirror_main(self, dashboard_dir, extra=()):
        return cde.main(["--dashboard-dir", str(dashboard_dir), "--now", NOW,
                         *extra])

    def test_mirror_source_degrades_exit_when_pg_is_configured(self):
        # Store configure (bearer) mais injoignable (loader -> None) : le
        # miroir est lu, son verdict rapporte — mais la mesure est INCOMPLETE,
        # jamais un 0 confiant.
        self.root.joinpath("dashboards").mkdir()
        self.dashboard("dashboards/clean.md", """### [2026-11-03T08:30:00.000Z] a|ws
[tags: DONE]

[DONE] rien de degrade
""")
        original = cde._store_loader
        cde._store_loader = lambda *a, **k: None
        self.addCleanup(setattr, cde, "_store_loader", original)
        code = self.run_mirror_main(self.root / "dashboards",
                                    extra=["--ring-bearer", "test-bearer"])
        self.assertEqual(code, 1)

    def test_stale_mirror_is_an_instrument_error(self):
        # Miroir frais d'aucune valeur : plus recente entree plus vieille qu'un
        # cycle (G: gele, cut #4131) -> erreur d'instrument, pas un 0.
        self.root.joinpath("dashboards").mkdir()
        self.dashboard("dashboards/old.md", """### [2026-11-03T03:00:00.000Z] a|ws
[tags: DONE]

[DONE] rien de degrade
""")
        code = self.run_mirror_main(self.root / "dashboards",
                                    extra=["--ring-bearer", ""])
        self.assertEqual(code, 1)

    def test_default_read_without_bearer_cannot_verdict_on_the_mirror(self):
        # #4650, le faux verdict du 11/11 : sans bearer, le miroir IMPLICITE
        # n'est plus ecrit depuis #4131 (`gdriveSkipped`). Ici il est FRAIS et
        # porte une escalade echue — un 2 ferait sonner le user sur une source
        # morte. L'instrument doit dire qu'il ne sait pas (1), pas verdict.
        self.root.joinpath("dashboards").mkdir()
        self.dashboard("dashboards/overdue.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet

### [2026-11-03T08:30:00.000Z] b|ws

[DONE] rien de degrade
""")
        with mock.patch.dict(os.environ, {"ROOSYNC_SHARED_PATH": str(self.root),
                                          "MCP_PROXY_BEARER": ""}):
            code = cde.main(["--now", NOW])
        # Tueur : sur 92688ada ce chemin rend 2 (verdict confiant sur le miroir).
        self.assertEqual(code, 1)

    def test_explicit_dashboard_dir_without_bearer_keeps_its_verdict(self):
        # Contre-temoin : seule la lecture IMPLICITE degrade (#4650). Un
        # --dashboard-dir explicite reste un rejeu lisible sans bearer, verdict
        # inchange — meme escalade echue, meme miroir frais -> 2.
        self.root.joinpath("dashboards").mkdir()
        self.dashboard("dashboards/overdue.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet

### [2026-11-03T08:30:00.000Z] b|ws

[DONE] rien de degrade
""")
        code = self.run_mirror_main(self.root / "dashboards",
                                    extra=["--ring-bearer", ""])
        self.assertEqual(code, 2)

    def test_replay_file_has_no_freshness_ceiling(self):
        # --dashboard-file = rejeu forensic : des donnees vieilles restent
        # lisibles, le plafond ne s'applique qu'au miroir.
        path = self.dashboard("old-replay.md", """### [2026-11-02T03:00:00.000Z] a|ws
[tags: DONE]

[DONE] rien de degrade
""")
        self.assertEqual(self.run_main(path), 0)

    def test_store_keys_are_parsed_fail_closed(self):
        # Un listing illisible ne se sert jamais comme « zero dashboard » :
        # fail-closed vers None (repli miroir), jamais vers une liste vide.
        self.assertIsNone(cde.store_keys_from_listing(None))
        self.assertIsNone(cde.store_keys_from_listing({"content": []}))
        self.assertIsNone(cde.store_keys_from_listing(
            {"content": [{"type": "text", "text": "not json"}]}))
        keys = cde.store_keys_from_listing(
            {"content": [{"type": "text", "text":
                          '{"success": true, "dashboards": [{"key": "global"}, '
                          '{"key": "machine-x"}, {"key": "workspace-y"}]}'}]})
        self.assertEqual(keys, ["global", "machine-x", "workspace-y"])
        self.assertEqual([cde.type_from_key(k) for k in keys],
                         ["global", "machine", "workspace"])

    # --- Review Hermes 04/11 : bornes de la lecture store ----------------

    # Pieds de page REELS que l'hote RSM ajoute apres l'enveloppe (releve
    # 11/11 ai-01, #4517 reouverte) : un `json.loads` du texte entier leve.
    RSM_TRAILERS = ("\n[NOTIF] 3 message(s) non lu(s) en inbox. myia-ai-01:roo-extensions. "
                    "Use roosync_messages action:\"inbox\".\n\n[⏱ roosync_dashboard 478ms]")
    HOST_MACHINE = "myia-host"

    def fake_store(self, dashboards, keys=None, structured=None, raw=None,
                   trailer="", archives=None, archive_files=None,
                   archive_raw=None, archive_listing_raw=None):
        """Transport store hors-ligne : {id: texte intercom}, `keys` = listing
        (cles PREFIXEES machine-/workspace-, comme le vrai store). Enregistre
        les arguments `read` dans self.reads pour les assertions par-cle.

        `structured` = {id: [messages]} : servi quand l'appelant demande
        `format: json`, comme le vrai store (#4517, review ai-01 04/11). Un
        dashboard present dans `dashboards` seulement est servi en markdown,
        ce qui exerce aussi le repli.

        `raw` = {id: texte} : servi TEL QUEL pour `format: json`, pour exercer
        une enveloppe en echec (`success: false`) ou une forme inattendue --
        le serveur reel les rend sans `isError` (review ai-01 04/11, SHOULD-1).

        #4643 : `archives` = {id: [noms]} (listing read_archive ; un dashboard
        absent est un dashboard SANS archive — reponse legitime `[]`, pas un
        echec) ; `archive_files` = {nom: [messages]} (fichier servi en
        enveloppe archiveData, comme le serveur reel) ; `archive_raw` =
        {nom: texte} servi tel quel (enveloppe en echec) ;
        `archive_listing_raw` = texte servi pour TOUT listing illisible.
        Les appels read_archive sont enregistres dans self.archive_reads.

        Fidele au serveur reel (#4517 reouverte 11/11) : un `read` machine lit
        `machineId` et, sans lui, sert le dashboard machine de l'HOTE
        (`args.machineId ?? getLocalMachineId()`, dashboard.ts) -- `machine`
        est ignore. `trailer` est ajoute apres CHAQUE reponse, comme les pieds
        de page `[NOTIF]`/`[⏱]` de l'hote.
        """
        if keys is None:
            keys = list(dashboards)
        self.reads = []
        self.archive_reads = []

        def call(arguments, url, bearer, timeout=10.0, client="x"):
            if arguments.get("action") == "list":
                body = json.dumps({"success": True,
                                   "dashboards": [{"key": k} for k in keys]})
            elif arguments.get("action") == "read_archive":
                self.archive_reads.append(arguments)
                if arguments.get("type") == "machine":
                    ident = arguments.get("machineId") or self.HOST_MACHINE
                else:
                    ident = arguments.get("workspace") or "global"
                name = arguments.get("archiveFile")
                if name is None:
                    if archive_listing_raw is not None:
                        body = archive_listing_raw
                    else:
                        body = json.dumps({
                            "success": True, "action": "read_archive",
                            "key": ident,
                            "archives": (archives or {}).get(ident, [])})
                elif archive_raw is not None and name in archive_raw:
                    body = archive_raw[name]
                else:
                    messages = (archive_files or {}).get(name, [])
                    body = json.dumps({
                        "success": True, "action": "read_archive",
                        "archiveData": {"key": ident,
                                        "archivedAt": "2026-11-03T04:00:00.001Z",
                                        "messageCount": len(messages),
                                        "messages": messages}})
            elif arguments.get("action") == "read":
                self.reads.append(arguments)
                if arguments.get("type") == "machine":
                    ident = arguments.get("machineId") or self.HOST_MACHINE
                else:
                    ident = arguments.get("workspace") or "global"
                if raw is not None and arguments.get("format") == "json" \
                        and ident in raw:
                    body = raw[ident]
                elif structured is not None and arguments.get("format") == "json":
                    body = json.dumps({
                        "success": True, "action": "read",
                        "data": {"intercom": {"messages": structured.get(ident, [])}},
                    })
                else:
                    body = dashboards.get(ident, "")
            else:
                return None
            return {"content": [{"type": "text", "text": body + trailer}]}

        original = cde._load_transport
        cde._load_transport = lambda: call
        self.addCleanup(setattr, cde, "_load_transport", original)

    def message(self, ts, tags=None, content="rien de degrade",
                lane=("a", "ws")):
        """Un message STORE tel que le sert `data.intercom.messages[]`."""
        return {"id": f"m-{ts}", "timestamp": ts,
                "author": {"machineId": lane[0], "workspace": lane[1]},
                "content": content, "tags": list(tags or [])}

    def run_store_main(self):
        return cde.main(["--now", NOW, "--ring-bearer", "test-bearer"])

    def entry(self, ts, lane="a|ws", body="[DONE] rien de degrade"):
        return f"### [{ts}] {lane}\n\n{body}\n"

    def test_store_read_addresses_each_dashboard_by_id(self):
        # Reserve Hermes (trouvee en implementant) : un read type=workspace
        # SANS `workspace` renvoie le dashboard du siege — N dashboards
        # workspace lisaient N fois le meme. Chaque cle doit porter son id.
        self.fake_store({
            "global": self.entry("2026-11-03T00:30:00.000Z", "g|ws"),
            "myia-x": self.entry("2026-11-03T00:40:00.000Z", "m|ws"),
            "y": self.entry("2026-11-03T00:50:00.000Z", "w|ws"),
        }, keys=["global", "machine-myia-x", "workspace-y"])
        code = self.run_store_main()
        self.assertEqual(code, 0)
        by_type = {(r.get("type"), r.get("machineId"), r.get("workspace"))
                   for r in self.reads}
        self.assertIn(("global", None, None), by_type)
        self.assertIn(("machine", "myia-x", None), by_type)
        self.assertIn(("workspace", None, "y"), by_type)

    def test_store_window_not_covered_fails_closed(self):
        # Review ai-01 04/11 : la garde ne vaut que pour une lecture TRONQUEE.
        # `intercom_limit` entrees lues, toutes posterieures au debut de
        # fenetre (01:00Z) -> la plus ancienne a pu etre coupee -> exit 1.
        crowded = "".join(
            self.entry(f"2026-11-03T0{8 - i // 60}:{i % 60:02d}:00.000Z")
            for i in range(200))
        self.fake_store({"y": crowded})
        code = self.run_store_main()
        self.assertEqual(code, 1)

    def test_sparse_dashboard_is_covered_not_flagged(self):
        # Le faux positif reproche par la review : 4 entrees recentes sur un
        # dashboard calme — rien n'a ete tronque, la mesure est complete -> 0.
        sparse = "".join(self.entry(f"2026-11-03T0{h}:30:00.000Z")
                         for h in (5, 6, 7, 8))
        self.fake_store({"y": sparse})
        code = self.run_store_main()
        self.assertEqual(code, 0)

    def test_unrecognized_header_is_surfaced_not_silent(self):
        # Reserve Hermes 2 : un entree au format derive (#### au lieu de ###)
        # etait invisible — ni entree, ni erreur. Elle est desormais signalee.
        self.fake_store({"y": self.entry("2026-11-03T00:30:00.000Z")
                         + "#### [2026-11-03T00:31:00.000Z] ghost|ws\n"})
        code = self.run_store_main()
        self.assertEqual(code, 1)

    def test_wake_claude_header_is_not_flagged(self):
        # Review ai-01 04/11 : `## [WAKE-CLAUDE] myia-po-2023` est une forme
        # LEGITIME du dashboard (wake-claude-routing.md) — pas un entete
        # d'entree derive. Le motif ne vise que les crochets horodates.
        self.fake_store({"y": self.entry("2026-11-03T00:30:00.000Z")
                         + "## [WAKE-CLAUDE] myia-po-2023\n"})
        code = self.run_store_main()
        self.assertEqual(code, 0)

    def test_store_clean_covered_dashboard_is_zero(self):
        # Temoin positif : store lu, fenetre couverte (entree plus vieille que
        # le debut de fenetre), contenu propre -> 0 par le chemin store.
        self.fake_store({"y": self.entry("2026-11-03T00:30:00.000Z")})
        code = self.run_store_main()
        self.assertEqual(code, 0)

    # --- Review ai-01 04/11 (MUST) : la declaration par l'API est vue ------

    def test_store_json_tags_declaration_is_flagged(self):
        # Critere de fermeture du MUST : un `append(tags=["DEGRADED"])`, corps
        # en prose, relu par le chemin store PAR DEFAUT, doit sonner. Avant,
        # le `read` markdown ne portait aucune ligne `[tags: ...]` -- exit 0,
        # silence, pour la forme que le harnais documente.
        self.fake_store({}, keys=["workspace-y"], structured={"y": [
            self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"])]})
        self.assertEqual(self.run_store_main(), 2)

    def test_store_json_repaired_tag_closes(self):
        self.fake_store({}, keys=["workspace-y"], structured={"y": [
            self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"]),
            self.message("2026-11-03T02:00:00.000Z", tags=["REPAIRED"])]})
        self.assertEqual(self.run_store_main(), 0)

    # --- #4517 reouverte 11/11 : pieds de page RSM et parametre machineId --

    def test_listing_behind_rsm_trailers_is_parsed(self):
        # Avant : `Extra data` -> None -> « store injoignable » -> miroir G:.
        listing = ('{"success": true, "dashboards": [{"key": "global"}, '
                   '{"key": "workspace-y"}]}' + self.RSM_TRAILERS)
        self.assertEqual(cde.store_keys_from_listing(
            {"content": [{"type": "text", "text": listing}]}),
            ["global", "workspace-y"])
        # Contre-temoin : un texte qui ne COMMENCE pas par du JSON reste
        # illisible (fail-closed), pieds de page ou non.
        self.assertIsNone(cde.store_keys_from_listing(
            {"content": [{"type": "text", "text": "## Intercom" + self.RSM_TRAILERS}]}))

    def test_store_json_behind_rsm_trailers_is_parsed(self):
        body = json.dumps({"success": True, "data": {"intercom": {"messages": [
            self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"])]}}})
        entries = cde.entries_from_store_json(body + self.RSM_TRAILERS)
        self.assertEqual(len(entries), 1)
        # Le markdown d'un hote ancien reste « pas du JSON » -> repli legitime.
        self.assertIsNone(cde.entries_from_store_json("## Intercom" + self.RSM_TRAILERS))

    def test_repaired_behind_rsm_trailers_closes_by_the_store(self):
        # Le cas mesure : [REPAIRED] present dans le store, pieds de page sur
        # chaque reponse. Avant : repli miroir, exit 1 (bearer configure) --
        # et exit 2 sans bearer, sur une escalade fermee.
        self.fake_store({}, keys=["workspace-y"], trailer=self.RSM_TRAILERS,
                        structured={"y": [
                            self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"]),
                            self.message("2026-11-03T02:00:00.000Z", tags=["REPAIRED"])]})
        self.assertEqual(self.run_store_main(), 0)

    def test_overdue_behind_rsm_trailers_still_rings(self):
        # Contre-temoin : lire a travers les pieds de page ne doit pas rendre
        # muet -- une escalade vraiment ouverte et echue sonne toujours.
        self.fake_store({}, keys=["workspace-y"], trailer=self.RSM_TRAILERS,
                        structured={"y": [
                            self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"])]})
        self.assertEqual(self.run_store_main(), 2)

    def test_repaired_on_another_machine_dashboard_closes(self):
        # `machine` etait ignore par le serveur : chaque cle machine-* relisait
        # le dashboard de l'HOTE, et un [REPAIRED] poste sur machine-myia-x
        # restait invisible -> exit 2 sur une escalade fermee.
        self.fake_store({}, keys=["global", "machine-myia-x"], structured={
            "global": [self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"])],
            "myia-x": [self.message("2026-11-03T02:00:00.000Z", tags=["REPAIRED"])],
            self.HOST_MACHINE: []})
        self.assertEqual(self.run_store_main(), 0)
        machine_reads = [r for r in self.reads if r.get("type") == "machine"]
        self.assertEqual([r.get("machineId") for r in machine_reads], ["myia-x"])
        self.assertNotIn("machine", machine_reads[0])

    def test_store_json_prose_without_tags_stays_clean(self):
        # Temoin NEGATIF : la meme prose sans le tag n'est pas une escalade.
        # Sans lui, « reparer le MUST » pourrait se satisfaire de tout sonner.
        self.fake_store({}, keys=["workspace-y"], structured={"y": [
            self.message("2026-11-03T00:30:00.000Z",
                         content="mcp muet, je regarde")]})
        self.assertEqual(self.run_store_main(), 0)

    def test_store_json_body_tags_line_still_declares(self):
        # Review ai-01 04/11 (SHOULD-2) : `scripts/diagnostic/README.md:226`
        # documente la declaration « par la ligne `[tags: ... DEGRADED ...]` »
        # ecrite DANS le corps. `append` ne derive pas les tags du contenu
        # (`dashboard.ts:8194`), donc cette forme n'a AUCUN tag dans son champ.
        # Avant ce correctif elle declarait par le miroir et se taisait par le
        # JSON -- une declaration qui produit le silence, sur le chemin devenu
        # le defaut. Corps repris mot pour mot de la review.
        self.fake_store({}, keys=["workspace-y"], structured={"y": [
            self.message("2026-11-03T00:30:00.000Z", tags=[],
                         content="[tags: DEGRADED]\n\nmcp muet, je regarde")]})
        self.assertEqual(self.run_store_main(), 2)

    def test_store_json_body_tags_line_with_other_tag_stays_clean(self):
        # Temoin NEGATIF de SHOULD-2 : lire aussi les tags du corps ne doit pas
        # transformer toute ligne `[tags: ...]` en escalade.
        self.fake_store({}, keys=["workspace-y"], structured={"y": [
            self.message("2026-11-03T00:30:00.000Z", tags=[],
                         content="[tags: DONE]\n\nrien de casse")]})
        self.assertEqual(self.run_store_main(), 0)

    def test_store_json_repaired_line_in_body_closes(self):
        # L'union vaut aussi pour la reparation : sans elle, la forme
        # documentee n'aurait regagne que la moitie de son sens -- elle
        # ouvrirait sans jamais pouvoir fermer.
        self.fake_store({}, keys=["workspace-y"], structured={"y": [
            self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"]),
            self.message("2026-11-03T02:00:00.000Z", tags=[],
                         content="[tags: REPAIRED]\n\ntout est revenu")]})
        self.assertEqual(self.run_store_main(), 0)

    def test_store_json_failed_envelope_is_an_instrument_error(self):
        # Review ai-01 04/11 (SHOULD-1) : `handleRead` rend `{success:false}`
        # SANS `isError` quand le store est inaccessible (`dashboard.ts:7542`),
        # le dashboard absent (`:7573`) ou la section invalide (`:7602`). Ce
        # n'est pas du markdown : exit 0 ferait dire « aucune escalade » a une
        # lecture qui n'a jamais eu lieu.
        self.fake_store({}, keys=["workspace-y"], raw={
            "y": json.dumps({"success": False, "error": "store inaccessible"})})
        self.assertEqual(self.run_store_main(), 1)

    def test_store_json_malformed_envelope_is_an_instrument_error(self):
        # Meme famille, forme inattendue : `data` sans `intercom` n'est pas une
        # reponse exploitable, donc pas un dashboard propre non plus.
        self.fake_store({}, keys=["workspace-y"], raw={
            "y": json.dumps({"success": True, "data": {}})})
        self.assertEqual(self.run_store_main(), 1)

    def test_store_json_bad_timestamp_is_an_instrument_error(self):
        # Review ai-01 04/11 (NIT) : un horodatage non-chaine levait un
        # AttributeError HORS du `except ValueError` de l'appelant -- une trace
        # au lieu du message d'erreur d'instrument.
        self.fake_store({}, keys=["workspace-y"], structured={"y": [
            dict(self.message("2026-11-03T00:30:00.000Z"), timestamp=17)]})
        self.assertEqual(self.run_store_main(), 1)

    def test_store_asks_for_the_json_source(self):
        # La source, pas son rendu : sans `format: json` le store repond le
        # markdown derive, qui ne porte pas les tags.
        self.fake_store({}, keys=["workspace-y"], structured={"y": []})
        self.run_store_main()
        self.assertTrue(self.reads)
        self.assertTrue(all(r.get("format") == "json" for r in self.reads))

    # --- Cas symetrique : miroir, corps precede de metadonnees ------------

    def test_first_token_after_meta_lines_is_seen(self):
        # Le miroir serialise `[msg: id]` AVANT le corps (dashboard.ts:2899) :
        # une declaration en premier token n'etait jamais vue par ce chemin.
        body = ("### [2026-11-03T00:30:00.000Z] a|ws\n"
                "[msg: m-1]\n[reply-to: m-0]\n\n[DEGRADED] mcp muet\n")
        entries = cde.parse_entries(body)
        self.assertTrue(cde.is_degraded(entries[0]))

    def test_tags_line_with_trailing_text_is_parsed(self):
        body = "### [2026-11-03T00:30:00.000Z] a|ws\n[tags: DEGRADED] (relu)\n"
        entries = cde.parse_entries(body)
        self.assertIn("degraded", entries[0]["tags"])

    def test_header_inside_fence_is_not_flagged(self):
        # Un exemple de format cite dans un bloc de code n'est pas une entree
        # invisible (revue ai-01 04/11, note non bloquante).
        text = ("### [2026-11-03T00:30:00.000Z] a|ws\n\n"
                "```\n#### [2026-11-03T00:31:00.000Z] ghost|ws\n```\n")
        self.assertEqual(cde.unrecognized_headers(text), [])

    def test_header_inside_tilde_fence_is_not_flagged(self):
        # Le NIT reste ouvert apres #4544 : seul ``` toggle le suivi de bloc.
        # Un exemple cite dans un bloc ~~~ etait scanne -> faux positif.
        text = ("### [2026-11-03T00:30:00.000Z] a|ws\n\n"
                "~~~\n#### [2026-11-03T00:31:00.000Z] ghost|ws\n~~~\n")
        self.assertEqual(cde.unrecognized_headers(text), [])

    def test_backtick_line_inside_tilde_block_does_not_desync(self):
        # CommonMark : un bloc ~~~ ne se clot pas par ```. L'ancien toggle
        # voyait ce ``` OUVRIR un bloc fantome -> le VRAI entete proche qui
        # suivait etait laisse en « dans le bloc » (faux negatif). Ici :
        # l'exemple cite reste invisible, le vrai entete est signale.
        text = ("### [2026-11-03T00:30:00.000Z] a|ws\n\n"
                "~~~\n```python\n#### [2026-11-03T00:31:00.000Z] cite|ws\n~~~\n"
                "#### [2026-11-03T00:32:00.000Z] ghost|ws\n")
        self.assertEqual(cde.unrecognized_headers(text),
                         ["#### [2026-11-03T00:32:00.000Z] ghost|ws"])

    def test_backtick_fence_still_closes_on_backtick(self):
        # Temoin de non-regression : le chemin ``` seul reste correct, y
        # compris avec une ligne ~~~ en contenu du bloc.
        text = ("### [2026-11-03T00:30:00.000Z] a|ws\n\n"
                "```\n~~~\n#### [2026-11-03T00:31:00.000Z] cite|ws\n```\n"
                "#### [2026-11-03T00:32:00.000Z] ghost|ws\n")
        self.assertEqual(cde.unrecognized_headers(text),
                         ["#### [2026-11-03T00:32:00.000Z] ghost|ws"])

    def test_short_backtick_line_does_not_close_a_triple_fence(self):
        # Grain #4517 (spec c.6651348721) : apres #4556, une ligne d'UN seul
        # backtick fermait un bloc ``` -- donc du CONTENU legitime (une
        # citation d'inline code) cloturait le bloc. Ce qui suivait etait
        # rescanne, et un en-tete cite produisait un faux positif. CommonMark :
        # la cloture doit etre au moins aussi longue que l'ouverture.
        # Tueur : sur main, `cite` est signale et `ghost` ne l'est pas.
        text = ("### [2026-11-03T00:30:00.000Z] a|ws\n\n"
                "```\n`\n#### [2026-11-03T00:31:00.000Z] cite|ws\n```\n"
                "#### [2026-11-03T00:32:00.000Z] ghost|ws\n")
        self.assertEqual(cde.unrecognized_headers(text),
                         ["#### [2026-11-03T00:32:00.000Z] ghost|ws"])

    def test_short_tilde_line_does_not_close_a_longer_tilde_fence(self):
        # Meme regle pour ~~~ : une ouverture de 4 tildes n'est pas fermee par
        # une ligne de 3. Le defaut n'etait pas propre au backtick.
        text = ("### [2026-11-03T00:30:00.000Z] a|ws\n\n"
                "~~~~\n~~~\n#### [2026-11-03T00:31:00.000Z] cite|ws\n~~~~\n"
                "#### [2026-11-03T00:32:00.000Z] ghost|ws\n")
        self.assertEqual(cde.unrecognized_headers(text),
                         ["#### [2026-11-03T00:32:00.000Z] ghost|ws"])

    def test_longer_closing_fence_still_closes(self):
        # Temoin de non-regression : le sens « plus longue » reste accepte,
        # sinon le correctif rendrait les blocs insortables et ferait
        # disparaitre de vrais en-tetes (faux negatif).
        text = ("### [2026-11-03T00:30:00.000Z] a|ws\n\n"
                "```\n#### [2026-11-03T00:31:00.000Z] cite|ws\n`````\n"
                "#### [2026-11-03T00:32:00.000Z] ghost|ws\n")
        self.assertEqual(cde.unrecognized_headers(text),
                         ["#### [2026-11-03T00:32:00.000Z] ghost|ws"])

    def test_ring_id_is_stable_within_a_day(self):
        item = {"lane": "a|ws", "posted": "2026-11-03T00:00:00Z"}
        self.assertEqual(cde.build_ring_id([item], now=1750000000),
                         cde.build_ring_id([item], now=1750000100))
        self.assertNotEqual(cde.build_ring_id([item], now=1750000000),
                            cde.build_ring_id([item], now=1750100000))

    # --- #4643 : la condensation ne doit plus aveugler l'organe -------------

    def test_archived_repaired_closes_the_live_escalation(self):
        # Le cas mesure du 10/11 : [REPAIRED] 17:32Z consomme par la
        # condensation de 21:00Z -- avant #4643, sonnerie 23:54Z sur une
        # escalade fermee depuis 6 h 22.
        self.fake_store(
            {}, keys=["workspace-y"],
            structured={"y": [self.message("2026-11-03T00:30:00.000Z",
                                           tags=["DEGRADED"])]},
            archives={"y": ["workspace-y-2026-11-03T04-00-00.md"]},
            archive_files={"workspace-y-2026-11-03T04-00-00.md": [
                self.message("2026-11-03T02:00:00.000Z",
                             content="[REPAIRED] tout est revenu")]})
        self.assertEqual(self.run_store_main(), 0)

    def test_archived_escalation_still_rings(self):
        # Sens symetrique (cas du 03/11) : l'ESCALADE archivee quitte le vif
        # -- elle doit continuer a sonner, pas disparaitre en faux negatif.
        self.fake_store(
            {}, keys=["workspace-y"], structured={"y": []},
            archives={"y": ["workspace-y-2026-11-03T04-00-00.md"]},
            archive_files={"workspace-y-2026-11-03T04-00-00.md": [
                self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"])]})
        self.assertEqual(self.run_store_main(), 2)

    def test_archive_listing_failure_is_an_instrument_error(self):
        # « Je ne vois pas les archives » EST l'angle mort : jamais servi comme
        # « aucune archive » (exit 0 confiant) ni comme sonnerie aveugle.
        self.fake_store({}, keys=["workspace-y"], structured={"y": []},
                        archive_listing_raw="## pas du json")
        self.assertEqual(self.run_store_main(), 1)

    def test_ring_cancelled_on_partial_measure(self):
        # W3 (review #4655) : un --ring du alors qu'un instrument est illisible
        # ne part PAS — la fenêtre aveugle peut cacher le [REPAIRED] qui
        # fermerait l'escalade mesurée ; un faux réveil coûte une intervention
        # humaine. Exit 1, le cycle suivant re-sonnera sur une lecture complète.
        # Preuve : publish_ring JAMAIS appelé (l'annulation précède le transport).
        self.fake_store({}, keys=["workspace-y"], structured={"y": [
            self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"])]},
                        archive_listing_raw="## pas du json")
        rings = []
        original = cde.publish_ring
        cde.publish_ring = lambda *a, **k: rings.append(a) or True
        self.addCleanup(setattr, cde, "publish_ring", original)
        with contextlib.redirect_stderr(io.StringIO()) as err:
            code = cde.main(["--now", NOW, "--ring",
                             "--ring-bearer", "test-bearer"])
        self.assertEqual(code, 1)
        self.assertEqual(rings, [])
        self.assertIn("ANNULEE", err.getvalue())

    def test_archive_file_failure_is_an_instrument_error(self):
        # Une archive de la fenetre ILLISIBLE n'est pas sautee en silence :
        # elle aurait pu porter le [REPAIRED] qui ferme l'escalade vivante.
        self.fake_store(
            {}, keys=["workspace-y"], structured={
                "y": [self.message("2026-11-03T00:30:00.000Z",
                                   tags=["DEGRADED"])]},
            archives={"y": ["workspace-y-2026-11-03T04-00-00.md"]},
            archive_raw={"workspace-y-2026-11-03T04-00-00.md":
                         json.dumps({"success": False,
                                     "error": "fichier absent"})})
        self.assertEqual(self.run_store_main(), 1)

    def test_crossposted_declaration_counts_once(self):
        # crossPost (global + machine + workspace) : meme auteur, meme
        # horodatage -- UNE escalade, pas trois (mesure 11/11 : la sonnerie
        # comptait chaque echeance N fois).
        msg = self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"])
        self.fake_store({}, keys=["global", "machine-m", "workspace-w"],
                        structured={"global": [msg], "m": [msg], "w": [msg]})
        self.assertEqual(self.run_store_main(), 2)
        entries, errors, keys = cde.load_entries_from_store(
            "http://x", "b", now=cde.parse_ts(NOW))
        self.assertEqual(errors, [])
        self.assertEqual(keys, ["global", "machine-m", "workspace-w"])
        escalations = cde.collect_escalations(entries, cde.parse_ts(NOW))
        self.assertEqual(len(escalations), 1, escalations)

    def test_old_archive_outside_window_is_not_read(self):
        # La fenetre (48 h par defaut) borne le cout : une archive d'un mois
        # n'est pas relue -- l'assertion porte sur les appels EMIS, la seule
        # preuve qu'elle n'a pas servie.
        self.fake_store(
            {}, keys=["workspace-y"], structured={"y": []},
            archives={"y": ["workspace-y-2026-11-03T04-00-00.md",
                            "workspace-y-2026-10-01T00-00-00.md"]},
            archive_files={"workspace-y-2026-10-01T00-00-00.md": [
                self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"])]})
        self.assertEqual(self.run_store_main(), 0)
        file_reads = [a["archiveFile"] for a in self.archive_reads
                      if a.get("archiveFile")]
        self.assertEqual(file_reads, ["workspace-y-2026-11-03T04-00-00.md"])

    def test_archive_window_zero_disables_archive_reads(self):
        self.fake_store({}, keys=["workspace-y"], structured={"y": []},
                        archives={"y": ["workspace-y-2026-11-03T04-00-00.md"]})
        code = cde.main(["--now", NOW, "--ring-bearer", "test-bearer",
                         "--archive-window-hours", "0"])
        self.assertEqual(code, 0)
        self.assertEqual(self.archive_reads, [])

    def test_undated_archive_name_is_still_read(self):
        # Impossible de prouver qu'un nom sans horodatage est vieux : il est
        # lu (couverture conservatrice -- l'angle mort est l'archive non lue).
        self.fake_store(
            {}, keys=["workspace-y"], structured={"y": []},
            archives={"y": ["workspace-y-sans-date.md"]},
            archive_files={"workspace-y-sans-date.md": [
                self.message("2026-11-03T00:30:00.000Z", tags=["DEGRADED"])]})
        self.assertEqual(self.run_store_main(), 2)

    def test_archive_read_addresses_machine_dashboards_by_machine_id(self):
        # #4647 vaut pour les DEUX lecteurs : un read_archive machine sans
        # machineId servirait le dashboard machine de l'HOTE.
        self.fake_store({}, keys=["machine-m"], structured={},
                        archives={"m": ["machine-m-2026-11-03T04-00-00.md"]})
        self.run_store_main()
        machine_calls = [a for a in self.archive_reads
                         if a.get("type") == "machine"]
        # Listing PUIS fichier : deux appels, tous deux adresses par machineId.
        self.assertEqual([a.get("machineId") for a in machine_calls],
                         ["m", "m"])
        for call in machine_calls:
            self.assertNotIn("machine", call)

    # --- #4643 (dispatch ai-01 12/11) : budget, coques vides, denominateur --

    def test_default_archive_budget_covers_measured_healthy_pass(self):
        # Item 1 du dispatch : 120 s epuisait le budget au bout de 3 min d'une
        # passe SAINE ; une passe complete mesuree prend 669 s. Le defaut doit
        # couvrir la mesure, sinon l'organe ne rend jamais 0/2/3.
        self.assertGreaterEqual(cde.DEFAULT_ARCHIVE_TIME_BUDGET_S, 669.0)

    def test_empty_husk_archive_is_not_an_instrument_error(self):
        # Item 2 : une coque de 0 octet est rejete par le serveur avec
        # « frontmatter manquant ». Elle n'a jamais porte de messages : WARN
        # non bloquant — PAS une erreur d'instrument (exit 0 sur live sain),
        # et le WARN est visible sur stderr.
        self.fake_store(
            {}, keys=["workspace-y"], structured={"y": []},
            archives={"y": ["workspace-y-2026-11-03T04-00-00.md"]},
            archive_raw={"workspace-y-2026-11-03T04-00-00.md": json.dumps({
                "success": False,
                "error": "Format archive invalide: frontmatter manquant "
                         "dans G:/Mon Drive/.../workspace-y-2026-11-03T04-00-00.md"})})
        with contextlib.redirect_stderr(io.StringIO()) as err:
            code = cde.main(["--now", NOW, "--ring-bearer", "test-bearer"])
        self.assertEqual(code, 0)
        self.assertIn("coque", err.getvalue())

    def test_muted_archive_read_recovers_on_retry(self):
        # Items 2+3 : lecture muette = timeout client sporadique (5 releves
        # sur des archives saines de 32-39 Ko) OU coque vide que le serveur
        # rejette en ~35 s — au-dela du timeout de 10 s. UNE relance a timeout
        # etendu tranche : ici l'archive SAINE servie a la relance porte le
        # [REPAIRED] qui ferme l'escalade vivante (exit 0, pas d'erreur).
        self.fake_store(
            {}, keys=["workspace-y"],
            structured={"y": [self.message("2026-11-03T00:30:00.000Z",
                                           tags=["DEGRADED"])]},
            archives={"y": ["workspace-y-2026-11-03T04-00-00.md"]},
            archive_files={"workspace-y-2026-11-03T04-00-00.md": [
                self.message("2026-11-03T03:00:00.000Z",
                             content="[REPAIRED] tout est revenu")]})
        inner = cde._load_transport()
        muted = set()
        archive_timeouts = []

        def call(arguments, url, bearer, timeout=10.0, client="x"):
            name = arguments.get("archiveFile")
            if name and name not in muted:
                muted.add(name)
                archive_timeouts.append(timeout)
                return None  # premier essai : timeout client
            if name:
                archive_timeouts.append(timeout)
            return inner(arguments, url, bearer, timeout=timeout,
                         client=client)

        cde._load_transport = lambda: call
        self.assertEqual(self.run_store_main(), 0)
        # Le premier essai au timeout client, la relance au timeout ETENDU
        # qui couvre le rejet de coque a ~35 s.
        self.assertEqual(archive_timeouts,
                         [10.0, cde.ARCHIVE_READ_RETRY_TIMEOUT_S])

    def test_store_error_denominator_counts_dashboards(self):
        # Item 3 : en source store, paths restait vide — le rapport disait
        # « 1 dashboard(s) illisible(s) sur 0 ». Le denominateur est le
        # nombre de dashboards lus (cles du listing).
        self.fake_store(
            {}, keys=["workspace-a", "workspace-b", "workspace-y"],
            structured={"a": [], "b": [], "y": []},
            archives={"y": ["workspace-y-2026-11-03T04-00-00.md"]},
            archive_raw={"workspace-y-2026-11-03T04-00-00.md": json.dumps({
                "success": False, "error": "fichier absent"})})
        with contextlib.redirect_stderr(io.StringIO()) as err:
            code = cde.main(["--now", NOW, "--ring-bearer", "test-bearer"])
        self.assertEqual(code, 1)
        self.assertIn("sur 3", err.getvalue())


if __name__ == "__main__":
    unittest.main()

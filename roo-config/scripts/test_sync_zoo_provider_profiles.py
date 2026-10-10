"""Unit tests for resolve_secret_placeholders — pure function, no crypto deps.

Run: python -m pytest roo-config/scripts/test_sync_zoo_provider_profiles.py -v
Covers the os.environ fallback added for #2543 (durable self-healing Zoo import must
read secrets from .env AND process environment, since the VS Code extension host inherits
Machine-scope env vars but not a repo .env).
"""
import importlib.util
import os

_HERE = os.path.dirname(__file__)


def _load():
    # Hyphenated filename isn't a legal module name — load by path.
    spec = importlib.util.spec_from_file_location(
        "sync_zoo_provider_profiles",
        os.path.join(_HERE, "sync-zoo-provider-profiles.py"),
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_resolve = _load().resolve_secret_placeholders


def test_resolves_from_env_dict():
    resolved, missing = _resolve("key={{SECRET:foo}}", {"foo": "val123"}, strict=False)
    assert resolved == "key=val123"
    assert missing == []


def test_falls_back_to_os_environ():
    os.environ["TEST_ZOO_SYNC_SECRET_A"] = "fromenv"
    try:
        # Absent from env dict, present in os.environ -> resolved via fallback.
        resolved, missing = _resolve("k={{SECRET:TEST_ZOO_SYNC_SECRET_A}}", {}, strict=False)
        assert resolved == "k=fromenv"
        assert missing == []
    finally:
        del os.environ["TEST_ZOO_SYNC_SECRET_A"]


def test_env_dict_takes_precedence_over_os_environ():
    os.environ["TEST_ZOO_SYNC_SECRET_B"] = "ambient"
    try:
        # Present in both -> explicit .env value wins.
        resolved, missing = _resolve(
            "k={{SECRET:TEST_ZOO_SYNC_SECRET_B}}",
            {"TEST_ZOO_SYNC_SECRET_B": "explicit"},
            strict=False,
        )
        assert resolved == "k=explicit"
        assert missing == []
    finally:
        del os.environ["TEST_ZOO_SYNC_SECRET_B"]


def test_empty_env_value_falls_back_to_os_environ():
    # An empty string in env dict is falsy -> should not short-circuit the fallback.
    os.environ["TEST_ZOO_SYNC_SECRET_C"] = "ambient"
    try:
        resolved, missing = _resolve(
            "k={{SECRET:TEST_ZOO_SYNC_SECRET_C}}",
            {"TEST_ZOO_SYNC_SECRET_C": ""},
            strict=False,
        )
        assert resolved == "k=ambient"
        assert missing == []
    finally:
        del os.environ["TEST_ZOO_SYNC_SECRET_C"]


def test_missing_recorded_when_nowhere():
    resolved, missing = _resolve("k={{SECRET:TEST_ZOO_NOPE_NEVER_SET}}", {}, strict=False)
    assert missing == ["TEST_ZOO_NOPE_NEVER_SET"]
    # Placeholder left intact when unresolved (never write a literal {{SECRET:...}} as a key).
    assert "{{SECRET:TEST_ZOO_NOPE_NEVER_SET}}" in resolved


def test_multiple_placeholders_mixed():
    os.environ["TEST_ZOO_SYNC_SECRET_D"] = "envval"
    try:
        resolved, missing = _resolve(
            "a={{SECRET:fromFile}} b={{SECRET:TEST_ZOO_SYNC_SECRET_D}} c={{SECRET:missing}}",
            {"fromFile": "fileval"},
            strict=False,
        )
        assert resolved == "a=fileval b=envval c={{SECRET:missing}}"
        assert missing == ["missing"]
    finally:
        del os.environ["TEST_ZOO_SYNC_SECRET_D"]


# --- resolve_profile_mode_map (#4115: --profile pilot lane) ---

_mod = _load()
_resolve_profile = _mod.resolve_profile_mode_map

_MC = {
    "profiles": [
        {"name": "Prod", "modeOverrides": {"code-simple": "simple"}},
        {"name": "Pilote", "levelOverrides": {"simple": "frognano", "complex": "swift"}},
        {
            "name": "Mixte",
            "modeOverrides": {"code-simple": "override-simple"},
            "levelOverrides": {"simple": "frognano", "complex": "swift"},
        },
    ]
}
_MC3 = {
    "profiles": [{"name": "P3", "levelOverrides": {"simple": "frognano", "medium": "swift", "complex": "default"}}],
}
_MODES2 = {
    "levels": [{"name": "simple"}, {"name": "complex"}],
    "families": {"code": {}, "debug": {}, "orchestrator": {}},
}
_MODES3 = {
    "levels": [{"name": "simple"}, {"name": "medium"}, {"name": "complex"}],
    "families": {"code": {}, "debug": {}},
}


def test_level_overrides_expand_to_all_families():
    got = _resolve_profile(_MC, "Pilote", _MODES2)
    assert got == {
        "code-simple": "frognano", "code-complex": "swift",
        "debug-simple": "frognano", "debug-complex": "swift",
        "orchestrator-simple": "frognano", "orchestrator-complex": "swift",
    }


def test_three_level_ladder_expands_all_rungs():
    got = _resolve_profile(_MC3, "P3", _MODES3)
    assert got["code-medium"] == "swift" and got["debug-medium"] == "swift"
    assert got["code-simple"] == "frognano" and got["debug-complex"] == "default"
    assert len(got) == 6  # 2 families x 3 levels


def test_mode_overrides_win_over_level_overrides():
    got = _resolve_profile(_MC, "Mixte", _MODES2)
    assert got["code-simple"] == "override-simple"  # per-mode escape hatch
    assert got["debug-simple"] == "frognano"  # level expansion elsewhere


def test_unknown_profile_lists_available():
    try:
        _resolve_profile(_MC, "N'existe pas", _MODES2)
        assert False, "must raise"
    except ValueError as e:
        assert "Prod" in str(e) and "Pilote" in str(e)


def test_level_key_must_be_declared():
    try:
        _resolve_profile({"profiles": [{"name": "X", "levelOverrides": {"oracle": "y"}}]}, "X", _MODES2)
        assert False, "must raise on undeclared level"
    except ValueError as e:
        assert "oracle" in str(e)


def test_slug_only_profile_without_modes_config():
    # No levelOverrides -> modes-config not consulted, modeOverrides pass through.
    got = _resolve_profile(_MC, "Prod", None)
    assert got == {"code-simple": "simple"}


# --- set_vscode_autoimport_setting: the TARGET is validated, not the key's presence (#4139) ---

import contextlib
import io
import json
import tempfile

_run_set = _mod.set_vscode_autoimport_setting
_portable = _mod._portable_setting_value  # noqa: SLF001 — expectation helper, see freeze test below


def _json_esc(p):
    """Escaped inner text of a JSON string literal (how settings.json stores a Windows path)."""
    return json.dumps(p)[1:-1]


def _write_settings(root, content):
    """Materialize <root>/Code/User/settings.json."""
    user_dir = os.path.join(root, "Code", "User")
    os.makedirs(user_dir, exist_ok=True)
    path = os.path.join(user_dir, "settings.json")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return path


def _call_with_appdata(root, target, home=None):
    """Run the setter with APPDATA redirected at `root`; return (stdout, settings_path).

    `home` additionally redirects the home dir (USERPROFILE+HOME) so the portable '~/' form is
    exercised hermetically — the tempdir may live under the REAL home on Windows, which would
    otherwise make the written spelling machine-dependent.
    """
    settings_path = os.path.join(root, "Code", "User", "settings.json")
    prev = {k: os.environ.get(k) for k in ("APPDATA", "USERPROFILE", "HOME")}
    os.environ["APPDATA"] = root
    if home is not None:
        os.environ["USERPROFILE"] = home
        os.environ["HOME"] = home
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            _run_set(target)
    finally:
        for k, v in prev.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
    return buf.getvalue(), settings_path


def test_autoimport_drift_is_reported_and_corrected():
    # The reported defect: the key was present with ANOTHER machine's path, so the emit claimed
    # success, the restart imported zero profiles, and no line ever said so. The stale value is
    # tempdir-local: a dead pointer must be hermetic, never "depends what exists on the seat".
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        stale = os.path.join(d, "stale-from-other-seat.json")  # never created
        _write_settings(d, '{\n    "zoo-code.autoImportSettingsPath": "' + _json_esc(stale) + '"\n}\n')
        out, settings = _call_with_appdata(d, emitted)
        assert "[WARN]" in out and stale in out and emitted in out
        got = json.load(open(settings, encoding="utf-8"))["zoo-code.autoImportSettingsPath"]
        assert got == _portable(emitted) and _mod._same_path(got, emitted)
        assert os.path.exists(settings + ".bak-autoimport")


def test_autoimport_written_value_is_portable_when_under_home():
    # #4139 review (bloquant): the key has NO machine scope, so Settings Sync replicates it to
    # every seat. A home-absolute path carries this seat's username; the written value must be
    # the '~/' spelling Zoo itself expands (autoImportSettings.ts:83-84). This FREEZES the form.
    with tempfile.TemporaryDirectory() as d:
        home = os.path.join(d, "fakehome")
        os.makedirs(home)
        emitted = os.path.join(home, ".zoo-provider-profiles.json")
        open(emitted, "w").close()
        settings = _write_settings(d, '{\n    "editor.fontSize": 14\n}\n')
        out, _ = _call_with_appdata(d, emitted, home=home)
        assert "[OK]" in out
        got = json.load(open(settings, encoding="utf-8"))["zoo-code.autoImportSettingsPath"]
        assert got == "~/.zoo-provider-profiles.json"


def test_autoimport_drift_correction_writes_portable_form():
    # Dead absolute pointer under the home dir: the correction lands in portable form, not the
    # absolute spelling that caused the fleet-wide drift in the first place.
    with tempfile.TemporaryDirectory() as d:
        home = os.path.join(d, "fakehome")
        os.makedirs(home)
        emitted = os.path.join(home, "emitted.json")
        open(emitted, "w").close()
        dead = os.path.join(home, "never-emitted.json")  # under home, never created
        _write_settings(d, '{\n    "zoo-code.autoImportSettingsPath": "' + _json_esc(dead) + '"\n}\n')
        out, settings = _call_with_appdata(d, emitted, home=home)
        assert "DOES NOT EXIST" in out and "[OK] corrected" in out
        got = json.load(open(settings, encoding="utf-8"))["zoo-code.autoImportSettingsPath"]
        assert got == "~/emitted.json"


def test_autoimport_dead_pointer_warns_even_when_the_value_matches():
    # Same path but the emitted file is gone: still a dead pointer, still must be loud.
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")  # never created
        _write_settings(d, '{\n    "zoo-code.autoImportSettingsPath": "' + _json_esc(emitted) + '"\n}\n')
        out, _ = _call_with_appdata(d, emitted)
        assert "[WARN]" in out and "DOES NOT EXIST" in out


def test_autoimport_live_foreign_pointer_is_warn_only():
    # #4139 review (bloquant): a pointer at a DIFFERENT file that EXISTS may be deliberate
    # (another lane's bootstrap, a manual import) — warn, never rewrite over a live target.
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        foreign = os.path.join(d, "other-profiles.json")
        open(foreign, "w").close()
        settings = _write_settings(
            d, '{\n    "zoo-code.autoImportSettingsPath": "' + _json_esc(foreign) + '"\n}\n'
        )
        before = open(settings, encoding="utf-8").read()
        out, _ = _call_with_appdata(d, emitted)
        assert "[WARN]" in out and foreign in out and "leaving untouched" in out
        assert open(settings, encoding="utf-8").read() == before
        assert not os.path.exists(settings + ".bak-autoimport")


def test_autoimport_idempotent_when_value_points_at_the_emitted_file():
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        settings = _write_settings(
            d, '{\n    "zoo-code.autoImportSettingsPath": "' + _json_esc(emitted) + '"\n}\n'
        )
        before = open(settings, encoding="utf-8").read()
        out, _ = _call_with_appdata(d, emitted)
        assert "leaving untouched" in out and "[WARN]" not in out
        assert open(settings, encoding="utf-8").read() == before
        assert not os.path.exists(settings + ".bak-autoimport")


def test_autoimport_idempotent_for_portable_form():
    # A pre-existing '~/' spelling pointing at the emitted file is ALREADY the desired end
    # state — the setter must recognize it, not "correct" it back to an absolute path.
    with tempfile.TemporaryDirectory() as d:
        home = os.path.join(d, "fakehome")
        os.makedirs(home)
        emitted = os.path.join(home, ".zoo-provider-profiles.json")
        open(emitted, "w").close()
        settings = _write_settings(
            d, '{\n    "zoo-code.autoImportSettingsPath": "~/.zoo-provider-profiles.json"\n}\n'
        )
        before = open(settings, encoding="utf-8").read()
        out, _ = _call_with_appdata(d, emitted, home=home)
        assert "leaving untouched" in out and "[WARN]" not in out
        assert open(settings, encoding="utf-8").read() == before


def test_autoimport_relative_value_resolves_from_home():
    # Zoo anchors RELATIVE values at the homedir (autoImportSettings.ts resolvePath), not at
    # the CWD: a bare ".zoo-provider-profiles.json" pointing at the emitted file is healthy.
    with tempfile.TemporaryDirectory() as d:
        home = os.path.join(d, "fakehome")
        os.makedirs(home)
        emitted = os.path.join(home, ".zoo-provider-profiles.json")
        open(emitted, "w").close()
        settings = _write_settings(
            d, '{\n    "zoo-code.autoImportSettingsPath": ".zoo-provider-profiles.json"\n}\n'
        )
        before = open(settings, encoding="utf-8").read()
        out, _ = _call_with_appdata(d, emitted, home=home)
        assert "leaving untouched" in out and "[WARN]" not in out
        assert open(settings, encoding="utf-8").read() == before


def test_autoimport_absent_key_is_still_inserted():
    # Regression: the plain "key not present" path is unchanged by the validation (and also
    # lands in portable form when the tempdir happens to sit under the real home).
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        settings = _write_settings(d, '{\n    "editor.fontSize": 14\n}\n')
        out, _ = _call_with_appdata(d, emitted)
        assert "[OK]" in out
        data = json.load(open(settings, encoding="utf-8"))
        assert data["zoo-code.autoImportSettingsPath"] == _portable(emitted)
        assert _mod._same_path(data["zoo-code.autoImportSettingsPath"], emitted)
        assert data["editor.fontSize"] == 14


def test_autoimport_commented_out_occurrence_counts_as_absent():
    # #4139 review: a JSONC line commenting the key out must not satisfy the presence check —
    # the old plain regex saw it, declared the pointer healthy, and the key stayed commented.
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        commented = '{\n    // "zoo-code.autoImportSettingsPath": "C:/old/seat.json"\n'
        settings = _write_settings(d, commented + '    "editor.fontSize": 14\n}\n')
        out, _ = _call_with_appdata(d, emitted)
        assert "[OK]" in out
        text = open(settings, encoding="utf-8").read()
        assert '// "zoo-code.autoImportSettingsPath"' in text  # comment survives
        assert _json_esc(_portable(emitted)) in text


def test_autoimport_sibling_slash_slash_on_same_line_is_not_a_comment():
    # A '//' inside a sibling string VALUE (e.g. a URL) sharing the line with the key must not
    # disqualify the hit — that would append a duplicate key. Only '//' before the first quote
    # of the line prefix is a JSONC comment (analyst pre-review, 10/10).
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        settings = _write_settings(
            d,
            '{\n    "repoUrl": "https://github.com/org/repo", '
            '"zoo-code.autoImportSettingsPath": "' + _json_esc(emitted) + '"\n}\n',
        )
        before = open(settings, encoding="utf-8").read()
        out, _ = _call_with_appdata(d, emitted)
        assert "leaving untouched" in out and "[WARN]" not in out
        assert open(settings, encoding="utf-8").read() == before  # no duplicate appended


def test_autoimport_relative_input_lands_under_home_portably():
    # A RELATIVE input anchors at the home dir (the rule Zoo applies when reading the value),
    # never at the process CWD: "cfg/zoo.json" must become "~/cfg/zoo.json" (analyst pre-review).
    with tempfile.TemporaryDirectory() as d:
        home = os.path.join(d, "fakehome")
        os.makedirs(os.path.join(home, "cfg"))
        emitted = os.path.join(home, "cfg", "zoo.json")
        open(emitted, "w").close()
        settings = _write_settings(d, '{\n    "editor.fontSize": 14\n}\n')
        prev_cwd = os.getcwd()
        os.chdir(d)  # a different CWD must not leak into the written value
        try:
            out, _ = _call_with_appdata(d, "cfg/zoo.json", home=home)
        finally:
            os.chdir(prev_cwd)
        assert "[OK]" in out
        got = json.load(open(settings, encoding="utf-8"))["zoo-code.autoImportSettingsPath"]
        assert got == "~/cfg/zoo.json"


def test_autoimport_jsonc_drift_preserves_comments():
    # settings.json is a hand-maintained file: a JSONC comment must survive the correction.
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        stale = os.path.join(d, "stale-from-other-seat.json")  # never created
        _write_settings(
            d,
            '{\n    // inherited from a synced profile\n'
            '    "zoo-code.autoImportSettingsPath": "' + _json_esc(stale) + '",\n'
            '    "editor.fontSize": 14,\n}\n',
        )
        out, settings = _call_with_appdata(d, emitted)
        text = open(settings, encoding="utf-8").read()
        assert "// inherited from a synced profile" in text
        assert _json_esc(_portable(emitted)) in text and _json_esc(stale) not in text
        assert "JSONC" in out

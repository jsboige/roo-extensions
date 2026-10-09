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

# Pinned by another machine's synced VS Code settings — the value measured in #4139.
_STALE_WIN = "C:\\Users\\jsboi\\.zoo-provider-profiles.json"


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


def _call_with_appdata(root, target):
    """Run the setter with APPDATA redirected at `root`; return (stdout, settings_path)."""
    settings_path = os.path.join(root, "Code", "User", "settings.json")
    prev = os.environ.get("APPDATA")
    os.environ["APPDATA"] = root
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            _run_set(target)
    finally:
        if prev is None:
            del os.environ["APPDATA"]
        else:
            os.environ["APPDATA"] = prev
    return buf.getvalue(), settings_path


def test_autoimport_drift_is_reported_and_corrected():
    # The reported defect: the key was present with ANOTHER machine's path, so the emit claimed
    # success, the restart imported zero profiles, and no line ever said so.
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        _write_settings(d, '{\n    "zoo-code.autoImportSettingsPath": "' + _json_esc(_STALE_WIN) + '"\n}\n')
        out, settings = _call_with_appdata(d, emitted)
        assert "[WARN]" in out and _STALE_WIN in out and emitted in out
        got = json.load(open(settings, encoding="utf-8"))["zoo-code.autoImportSettingsPath"]
        assert got == emitted
        assert os.path.exists(settings + ".bak-autoimport")


def test_autoimport_dead_pointer_warns_even_when_the_value_matches():
    # Same path but the emitted file is gone: still a dead pointer, still must be loud.
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")  # never created
        _write_settings(d, '{\n    "zoo-code.autoImportSettingsPath": "' + _json_esc(emitted) + '"\n}\n')
        out, _ = _call_with_appdata(d, emitted)
        assert "[WARN]" in out and "DOES NOT EXIST" in out


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


def test_autoimport_absent_key_is_still_inserted():
    # Regression: the plain "key not present" path is unchanged by the validation.
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        settings = _write_settings(d, '{\n    "editor.fontSize": 14\n}\n')
        out, _ = _call_with_appdata(d, emitted)
        assert "[OK]" in out
        data = json.load(open(settings, encoding="utf-8"))
        assert data["zoo-code.autoImportSettingsPath"] == emitted
        assert data["editor.fontSize"] == 14


def test_autoimport_jsonc_drift_preserves_comments():
    # settings.json is a hand-maintained file: a JSONC comment must survive the correction.
    with tempfile.TemporaryDirectory() as d:
        emitted = os.path.join(d, "emitted.json")
        open(emitted, "w").close()
        _write_settings(
            d,
            '{\n    // inherited from a synced profile\n'
            '    "zoo-code.autoImportSettingsPath": "' + _json_esc(_STALE_WIN) + '",\n'
            '    "editor.fontSize": 14,\n}\n',
        )
        out, settings = _call_with_appdata(d, emitted)
        text = open(settings, encoding="utf-8").read()
        assert "// inherited from a synced profile" in text
        assert _json_esc(emitted) in text and _json_esc(_STALE_WIN) not in text
        assert "JSONC" in out

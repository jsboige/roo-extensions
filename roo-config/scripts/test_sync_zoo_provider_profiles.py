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

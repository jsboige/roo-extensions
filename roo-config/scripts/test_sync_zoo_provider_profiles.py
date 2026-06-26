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

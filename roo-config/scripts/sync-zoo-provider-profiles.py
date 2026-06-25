#!/usr/bin/env python3
"""
sync-zoo-provider-profiles.py - Push model-configs.json provider profiles (with keys)
into Zoo/Roo Code SecretStorage (OSCrypt v10), as-code.

Replaces the manual "enter API key in UI per machine" step (#2543 Phase 2). Reads
roo-config/model-configs.json, resolves {{SECRET:xxx}} from .env, builds the
providerProfiles blob, encrypts it the way VS Code Electron safeStorage does
(v10 + AES-256-GCM, master key DPAPI-wrapped in Code/Local State), and writes it
into state.vscdb SecretStorage.

Why OSCrypt: Roo/Zoo persist the full provider config (ENDPOINTS + KEYS) in the
SecretStorage key `roo_cline_config_api_config` (see roo-code
ProviderSettingsManager.store, L669). That secret is Chromium OSCrypt-encrypted,
NOT plaintext vscdb — so the standard RSM writeToVscdb (metadata only, no keys)
cannot place the keys. This script writes the encrypted blob directly.

Safety: backup state.vscdb before write, verify-by-decrypt after write, auto-rollback
on mismatch. Refuses to run while VS Code holds the db lock.

Dependencies: pywin32 (DPAPI), cryptography (AES-GCM), sqlite3 (stdlib).
  pip install pywin32 cryptography

Usage:
  python sync-zoo-provider-profiles.py --verify          # read & decrypt current blob
  python sync-zoo-provider-profiles.py --dry-run         # show planned changes, no write
  python sync-zoo-provider-profiles.py --apply           # write (with backup + verify)
  python sync-zoo-provider-profiles.py --apply --target roo

Issue: #2543 (Phase 2 as-code), #2134, Epic #2639 WS3.
"""
import argparse
import base64
import json
import os
import re
import secrets
import sqlite3
import string
import sys

# --- crypto backends (imported lazily so --help works without them) ---
def _import_crypto():
    try:
        import win32crypt  # pywin32 — DPAPI
    except ImportError:
        sys.exit("[FATAL] pywin32 missing. pip install pywin32")
    try:
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    except ImportError:
        sys.exit("[FATAL] cryptography missing. pip install cryptography")
    return win32crypt, AESGCM


# --- extension identity (mirror scripts/common/extension-paths.ps1) ---
EXTENSIONS = {
    "zoo": {
        "id": "zoocodeorganization.zoo-code",
        "globalstorage": r"zoocodeorganization.zoo-code",
    },
    "roo": {
        "id": "rooveterinaryinc.roo-cline",
        "globalstorage": r"rooveterinaryinc.roo-cline",
    },
}

# SecretStorage key holding the full providerProfiles blob (with keys).
# Constant in roo-code: ProviderSettingsManager.SCOPE_PREFIX + "api_config"
SECRET_KEY_NAME = "roo_cline_config_api_config"

# OSCrypt v10 prefix (Chromium Electron safeStorage on Windows).
V10_PREFIX = b"v10"


def repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def env_paths(target, args):
    """Resolve Code state.vscdb + Local State paths."""
    appdata = os.environ.get("APPDATA", os.path.expanduser("~/AppData/Roaming"))
    # VS Code (default). Insiders/variants would differ; allow override.
    vscdb = args.vscdb or os.path.join(appdata, "Code", "User", "globalStorage", "state.vscdb")
    local_state = args.local_state or os.path.join(appdata, "Code", "Local State")
    return vscdb, local_state


def load_env(env_path):
    env = {}
    if not os.path.exists(env_path):
        return env
    with open(env_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def resolve_secret_placeholders(value, env, strict):
    """Resolve {{SECRET:varname}} from env. Mirrors sync-api-configs.js."""
    missing = []

    def repl(m):
        var = m.group(1)
        if var in env and env[var]:
            return env[var]
        missing.append(var)
        return m.group(0)

    resolved = re.sub(r"\{\{SECRET:(\w+)\}\}", repl, value or "")
    return resolved, missing


def gen_config_id():
    """Match roo-code generateId(): Math.random().toString(36).substring(2,15) — ~13 base36 chars."""
    alphabet = string.ascii_lowercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(13))


# --- OSCrypt v10 crypto ---
def get_master_key(local_state):
    """DPAPI-unprotect the Chromium OSCrypt master key from Code/Local State."""
    with open(local_state, encoding="utf-8") as f:
        ls = json.load(f)
    enc_key_b64 = ls.get("os_crypt", {}).get("encrypted_key")
    if not enc_key_b64:
        raise RuntimeError("os_crypt.encrypted_key missing in Local State")
    enc_key = base64.b64decode(enc_key_b64)
    prefix = enc_key[:5]
    if prefix != b"DPAPI":
        raise RuntimeError(f"Unexpected encrypted_key prefix (want DPAPI): {prefix!r}")
    win32crypt, _ = _import_crypto()
    # CryptUnprotectData(blob, None, None, None, 0) -> (desc, data)
    _, master = win32crypt.CryptUnprotectData(enc_key[5:], None, None, None, 0)
    return master  # 32 bytes for AES-256


def oscrypt_encrypt(plaintext_bytes, master_key):
    """v10 + nonce(12) + ciphertext + tag(16)."""
    _, AESGCM = _import_crypto()
    nonce = secrets.token_bytes(12)
    ct_and_tag = AESGCM(master_key).encrypt(nonce, plaintext_bytes, None)
    return V10_PREFIX + nonce + ct_and_tag


def oscrypt_decrypt(blob, master_key):
    """Inverse of oscrypt_encrypt. Returns plaintext bytes."""
    _, AESGCM = _import_crypto()
    if blob[:3] != V10_PREFIX:
        raise RuntimeError(f"Not a v10 blob: prefix={blob[:3]!r}")
    nonce = blob[3:15]
    ct_and_tag = blob[15:]
    return AESGCM(master_key).decrypt(nonce, ct_and_tag, None)


# --- state.vscdb SecretStorage I/O ---
SECRET_ROW_KEY_TEMPLATE = 'secret://{{"extensionId":"{ext_id}","key":"{secret_name}"}}'


def db_get_secret(con, ext_id, secret_name):
    key = SECRET_ROW_KEY_TEMPLATE.format(ext_id=ext_id, secret_name=secret_name)
    row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
    if not row:
        return None, key
    raw = row[0]
    # VS Code stores safeStorage values as a JSON {"type":"Buffer","data":[...]}.
    if isinstance(raw, (bytes, bytearray)):
        return bytes(raw), key
    try:
        decoded = json.loads(raw)
        if isinstance(decoded, dict) and decoded.get("type") == "Buffer":
            return bytes(decoded["data"]), key
    except (ValueError, TypeError):
        pass
    return None, key  # present but unparseable


def db_set_secret(con, ext_id, secret_name, blob_bytes):
    key = SECRET_ROW_KEY_TEMPLATE.format(ext_id=ext_id, secret_name=secret_name)
    value = json.dumps({"type": "Buffer", "data": list(blob_bytes)})
    con.execute(
        "INSERT INTO ItemTable (key, value) VALUES (?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        (key, value),
    )


def load_current_blob(vscdb, ext_id, master_key):
    """Read + decrypt current providerProfiles blob. Returns (dict or None, secret_row_key)."""
    con = sqlite3.connect(f"file:{vscdb}?mode=ro", uri=True)
    try:
        blob, skey = db_get_secret(con, ext_id, SECRET_KEY_NAME)
    finally:
        con.close()
    if blob is None:
        return None, skey
    plain = oscrypt_decrypt(blob, master_key)
    return json.loads(plain.decode("utf-8")), skey


# --- build new blob from model-configs.json ---
def build_new_blob(model_configs, env, current_blob, strict):
    """
    Build the providerProfiles blob from model-configs.json, resolving secrets from env.
    Preserves existing config `id`s (so existing modeApiConfigs refs stay valid) and the
    `migrations` block; generates new ids for new configs; rebuilds modeApiConfigs from
    model-configs (translating config NAME -> internal id).
    """
    api_configs_src = model_configs.get("apiConfigs", {})
    mode_api_src = model_configs.get("modeApiConfigs", {})

    # Preserve existing ids by config name; new ids generated.
    existing_ids = {}
    if current_blob and isinstance(current_blob.get("apiConfigs"), dict):
        for name, cfg in current_blob["apiConfigs"].items():
            if isinstance(cfg, dict) and cfg.get("id"):
                existing_ids[name] = cfg["id"]

    new_api_configs = {}
    name_to_id = {}
    skipped = []  # (config_name, [missing_vars])
    for name, cfg in api_configs_src.items():
        cfg = dict(cfg)  # shallow copy
        # resolve any {{SECRET:...}} anywhere in this config's string values
        resolved_cfg = {}
        missing_here = []
        for k, v in cfg.items():
            if isinstance(v, str):
                rv, missing = resolve_secret_placeholders(v, env, strict)
                missing_here.extend(missing)
                resolved_cfg[k] = rv
            elif isinstance(v, dict):
                # deep-resolve dicts (e.g. openAiCustomModelInfo has no secrets, but be safe)
                rj = json.dumps(v)
                rv, missing = resolve_secret_placeholders(rj, env, strict)
                missing_here.extend(missing)
                resolved_cfg[k] = json.loads(rv) if "{{SECRET:" in rj else v
            else:
                resolved_cfg[k] = v

        if missing_here:
            # --strict: abort entirely. Default: skip this config (never write a literal
            # {{SECRET:...}} placeholder as an API key) and warn.
            if strict:
                sys.exit(
                    f"[FATAL] Unresolved {{SECRET:...}} in config '{name}': "
                    + ", ".join(sorted(set(missing_here)))
                    + " (missing in .env)"
                )
            skipped.append((name, sorted(set(missing_here))))
            continue

        # internal id: preserve existing, else the config's own id, else generate
        cid = existing_ids.get(name) or resolved_cfg.get("id") or gen_config_id()
        resolved_cfg["id"] = cid
        new_api_configs[name] = resolved_cfg
        name_to_id[name] = cid

    if skipped:
        detail = "; ".join(f"{n} (need {','.join(m)})" for n, m in skipped)
        print(f"[WARN] Skipped {len(skipped)} config(s) with unresolved secrets: {detail}", file=sys.stderr)
        print("[WARN] Provide the missing .env vars or rerun with --strict to abort.", file=sys.stderr)

    # modeApiConfigs: model-configs uses config NAME as value -> translate to internal id
    new_mode_api = {}
    for mode, config_name in mode_api_src.items():
        cid = name_to_id.get(config_name)
        if cid is None:
            print(f"[WARN] mode '{mode}' references unknown config '{config_name}' — skipped", file=sys.stderr)
            continue
        new_mode_api[mode] = cid

    # currentApiConfigName: prefer model-configs apiConfigs 'default' or first
    current_name = "default" if "default" in new_api_configs else next(iter(new_api_configs), "default")

    # preserve migrations block from current blob (Zod will keep known keys)
    migrations = None
    if current_blob and isinstance(current_blob.get("migrations"), dict):
        migrations = current_blob["migrations"]

    blob = {
        "currentApiConfigName": current_name,
        "apiConfigs": new_api_configs,
        "modeApiConfigs": new_mode_api,
    }
    if migrations is not None:
        blob["migrations"] = migrations
    return blob


def mask(value):
    """Mask secret-like string values for safe logging."""
    if isinstance(value, str) and any(s in value.lower() for s in ("apikey", "token", "secret")) and len(value) > 8:
        return value[:4] + "…" + value[-3:] + f" ({len(value)} chars)"
    return value


# --- zoo-code autoImport (self-healing native import) ---
# Why this exists: a direct DB write (--apply) gets overwritten when Zoo, still running,
# flushes its in-memory state on exit. The autoImport path sidesteps that race: at extension
# activation Zoo ITSELF calls importSettingsFromPath -> providerSettingsManager.import ->
# writes SecretStorage with an in-memory-consistent state that survives the next flush.
# Run on every activation -> re-asserts the good config every restart. Issue #2543 durable fix.
def emit_import_file(path_str, new_blob, set_vscode_setting):
    """
    Write {providerProfiles, globalSettings} to `path_str` in the exact shape Zoo's
    importSettingsFromPath expects (mirrors exportSettings). Keys are RESOLVED (plaintext),
    so `path_str` MUST be outside the repo / gitignored (home dir recommended).
    """
    import_file = {"providerProfiles": new_blob, "globalSettings": {}}
    # Expand once (~ + relative) and use the EXPANDED path consistently: the file is written
    # there AND the same path goes into settings.json. roo-code's resolvePath() DOES expand
    # `~`, but we don't depend on that contract — an absolute path is unambiguous for both sides.
    out_path = os.path.abspath(os.path.expanduser(path_str))
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(import_file, f, indent=2, ensure_ascii=False)
    # Restrict permissions on the plaintext-key file (best-effort; on Windows chmod is advisory).
    try:
        os.chmod(out_path, 0o600)
    except OSError:
        pass
    print(f"\n[OK] autoImport file written: {out_path} (chmod 0600)")
    print("[!] Contains RESOLVED API keys (plaintext). Keep this file OUT of git "
          "(home dir recommended; the path below is outside the repo).")
    if set_vscode_setting:
        set_vscode_autoimport_setting(out_path)
    else:
        print("[i] Add to VS Code user settings.json, then restart VS Code:")
        print(f'    "zoo-code.autoImportSettingsPath": "{out_path}"')
    print("[i] On next VS Code restart, Zoo imports this file -> writes SecretStorage "
          "-> self-heals the provider config every restart.")


def set_vscode_autoimport_setting(path_str):
    """Set zoo-code.autoImportSettingsPath in VS Code user settings.json (comment-preserving when possible)."""
    appdata = os.environ.get("APPDATA", os.path.expanduser("~/AppData/Roaming"))
    settings_path = os.path.join(appdata, "Code", "User", "settings.json")
    if not os.path.exists(settings_path):
        print(f"[WARN] settings.json not found ({settings_path}) — set the key manually.")
        return
    raw = open(settings_path, encoding="utf-8").read()
    import re
    # Already present? Leave as-is (idempotent).
    if re.search(r'"zoo-code\.autoImportSettingsPath"\s*:', raw):
        print(f"[i] zoo-code.autoImportSettingsPath already present in settings.json — leaving untouched.")
        return
    try:
        # Clean JSON -> round-trip preserves structure (comments rare in this file).
        data = json.loads(raw)
    except json.JSONDecodeError:
        # JSONC (comments / trailing commas) -> regex insert before the final closing brace.
        # Best-effort; cannot fully parse JSONC without a dedicated lib.
        patched = re.sub(
            r"\}\s*$",
            f',\n  "zoo-code.autoImportSettingsPath": "{path_str}"\n}}',
            raw.rstrip(),
            count=1,
        )
        if patched == raw:
            print(f"[WARN] could not patch settings.json (JSONC) — set manually: "
                  f'"zoo-code.autoImportSettingsPath": "{path_str}"')
            return
        open(settings_path, "w", encoding="utf-8").write(patched)
        print(f"[OK] set zoo-code.autoImportSettingsPath = {path_str} in settings.json "
              "(JSONC best-effort insert — please verify in VS Code).")
        return
    data["zoo-code.autoImportSettingsPath"] = path_str
    open(settings_path, "w", encoding="utf-8").write(
        json.dumps(data, indent=4, ensure_ascii=False)
    )
    print(f"[OK] set zoo-code.autoImportSettingsPath = {path_str} in settings.json.")


def summarize(blob):
    if not blob:
        print("  (no current blob)")
        return
    print(f"  currentApiConfigName: {blob.get('currentApiConfigName')}")
    for name, cfg in blob.get("apiConfigs", {}).items():
        prov = cfg.get("apiProvider")
        model = cfg.get("openAiModelId") or cfg.get("apiModelId")
        base = cfg.get("openAiBaseUrl", "")
        key = mask(str(cfg.get("openAiApiKey", "")))
        print(f"  [{name}] id={cfg.get('id')} provider={prov} model={model}")
        print(f"        baseUrl={base}")
        print(f"        apiKey={key}")
    mac = blob.get("modeApiConfigs", {})
    if mac:
        # group by target id for readability
        by_id = {}
        for mode, cid in mac.items():
            by_id.setdefault(cid, []).append(mode)
        print("  modeApiConfigs (id -> modes):")
        for cid, modes in by_id.items():
            print(f"    {cid}: {', '.join(modes)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model-configs", default=os.path.join(repo_root(), "roo-config", "model-configs.json"))
    ap.add_argument("--env", default=os.path.join(repo_root(), ".env"))
    ap.add_argument("--target", choices=["zoo", "roo"], default="zoo")
    ap.add_argument("--vscdb", default=None)
    ap.add_argument("--local-state", default=None)
    ap.add_argument("--strict", action="store_true", help="abort on unresolved secrets (default: warn)")
    ap.add_argument("--set-vscode-setting", action="store_true",
        help="(with --emit-import) also set zoo-code.autoImportSettingsPath in VS Code settings.json")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--verify", action="store_true", help="read + decrypt current blob, print summary")
    mode.add_argument("--dry-run", action="store_true", help="build planned blob, print diff, no write")
    mode.add_argument("--apply", action="store_true", help="write the blob (backup + verify + rollback)")
    mode.add_argument("--emit-import", metavar="PATH",
        help="write resolved providerProfiles to PATH as a zoo-code autoImport file (self-healing: "
             "Zoo imports it at activation -> writes SecretStorage itself -> survives the in-memory flush)")
    args = ap.parse_args()

    ext = EXTENSIONS[args.target]
    vscdb, local_state = env_paths(args.target, args)

    for p in (vscdb, local_state):
        if not os.path.exists(p):
            sys.exit(f"[FATAL] path not found: {p}")
    print(f"[*] target={args.target} ({ext['id']})")
    print(f"[*] vscdb={vscdb}")
    print(f"[*] local_state={local_state}")

    win32crypt, AESGCM = _import_crypto()  # noqa: F841 — fail fast with a clear msg
    master = get_master_key(local_state)
    print(f"[*] master key OK ({len(master)} bytes)")

    current_blob, skey = load_current_blob(vscdb, ext["id"], master)

    if args.verify:
        print("\n=== CURRENT BLOB ===")
        summarize(current_blob)
        return

    with open(args.model_configs, encoding="utf-8") as f:
        model_configs = json.load(f)
    env = load_env(args.env)
    new_blob = build_new_blob(model_configs, env, current_blob, args.strict)

    print("\n=== PLANNED BLOB ===")
    summarize(new_blob)

    if args.emit_import:
        emit_import_file(args.emit_import, new_blob,
                         set_vscode_setting=args.set_vscode_setting)
        return

    if args.dry_run:
        print("\n[DRY-RUN] no write performed.")
        return

    # --- apply ---
    import time
    ts = time.strftime("%Y%m%d-%H%M%S")
    backup = f"{vscdb}.backup-zoo-profiles-{ts}"
    import shutil
    shutil.copy2(vscdb, backup)
    print(f"\n[*] backup: {backup}")

    plaintext = json.dumps(new_blob, indent=2).encode("utf-8")
    enc_blob = oscrypt_encrypt(plaintext, master)

    con = sqlite3.connect(vscdb)
    try:
        db_set_secret(con, ext["id"], SECRET_KEY_NAME, enc_blob)
        con.commit()
    finally:
        con.close()

    # verify-by-decrypt (read back, decrypt, compare)
    reread, _ = load_current_blob(vscdb, ext["id"], master)
    if reread != new_blob:
        shutil.copy2(backup, vscdb)
        sys.exit("[FATAL] verify-by-decrypt MISMATCH — rolled back from backup. Aborting.")
    print("[OK] verify-by-decrypt: blob matches. Write committed.")
    print("[*] Restart VS Code (Zoo) to load the new provider profiles.")


if __name__ == "__main__":
    main()

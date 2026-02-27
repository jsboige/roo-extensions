#!/usr/bin/env python3
"""
Roo Settings Manager - Read/Write Roo Code settings from state.vscdb

The Roo Code extension stores its settings in VS Code's global state SQLite database:
  %APPDATA%/Code/User/globalStorage/state.vscdb
  Key: 'RooVeterinaryInc.roo-cline' (JSON blob, ~5MB)

This script provides CLI operations:
  extract  - Export settings to a JSON file (filtering secrets)
  inject   - Import settings from a JSON file into state.vscdb
  get      - Get a specific setting value
  set      - Set a specific setting value
  diff     - Compare local settings with a reference JSON file

Usage:
  python roo-settings-manager.py extract [-o output.json] [--full]
  python roo-settings-manager.py inject -i settings.json [--dry-run] [--keys key1,key2]
  python roo-settings-manager.py get <key>
  python roo-settings-manager.py set <key> <value>
  python roo-settings-manager.py diff -r reference.json

Issue: #509 - RooSync deployment of condensation settings
"""

import argparse
import json
import os
import shutil
import sqlite3
import sys
import tempfile
from datetime import datetime
from pathlib import Path

# Constants
VSCDB_KEY = 'RooVeterinaryInc.roo-cline'
VSCDB_RELATIVE_PATH = r'Code\User\globalStorage\state.vscdb'

# Settings that should NEVER be exported/synced (machine-specific or sensitive)
EXCLUDED_KEYS = {
    'id',                          # Machine-specific UUID
    'taskHistory',                 # Large, machine-specific
    'taskHistoryMigratedToFiles',  # Internal migration flag
    'mcpHubInstanceId',            # Transient
    'clerk-auth-state',            # Auth token
    'lastShownAnnouncementId',     # UI state
    'hasOpenedModeSelector',       # UI state
    'dismissedUpsells',            # UI state
    'organization-settings',       # Account-specific
    'user-settings',               # Account-specific
}

# Settings safe to sync across machines (condensation, model config, behavior)
SYNC_SAFE_KEYS = {
    # Condensation (primary goal of #509)
    'autoCondenseContext',
    'autoCondenseContextPercent',
    'condensingApiConfigId',
    'customCondensingPrompt',
    'customSupportPrompts',
    # Model configuration
    'apiProvider',
    'openAiBaseUrl',
    'openAiModelId',
    'openAiLegacyFormat',
    'openAiCustomModelInfo',
    'openAiHeaders',
    'modelTemperature',
    'currentApiConfigName',
    'listApiConfigMeta',
    'profileThresholds',
    # Behavior settings
    'autoApprovalEnabled',
    'alwaysAllowReadOnly',
    'alwaysAllowReadOnlyOutsideWorkspace',
    'alwaysAllowWrite',
    'alwaysAllowWriteOutsideWorkspace',
    'alwaysAllowBrowser',
    'alwaysApproveResubmit',
    'alwaysAllowMcp',
    'alwaysAllowModeSwitch',
    'alwaysAllowSubtasks',
    'alwaysAllowExecute',
    'alwaysAllowUpdateTodoList',
    'alwaysAllowFollowupQuestions',
    'writeDelayMs',
    'requestDelaySeconds',
    'rateLimitSeconds',
    'allowedCommands',
    'deniedCommands',
    'allowedMaxRequests',
    'allowedMaxCost',
    'consecutiveMistakeLimit',
    'followupAutoApproveTimeoutMs',
    # UI/behavior
    'browserToolEnabled',
    'browserViewportSize',
    'enableCheckpoints',
    'checkpointTimeout',
    'enableMcpServerCreation',
    'enableReasoningEffort',
    'enableSubfolderRules',
    'diffEnabled',
    'language',
    'mode',
    'todoListEnabled',
    'soundEnabled',
    'soundVolume',
    'includeCurrentCost',
    'includeCurrentTime',
    'includeDiagnosticMessages',
    'maxDiagnosticMessages',
    # Terminal
    'terminalOutputCharacterLimit',
    'terminalOutputLineLimit',
    'terminalOutputPreviewSize',
    'terminalCompressProgressBar',
    'terminalPowershellCounter',
    'terminalCommandDelay',
    'terminalShellIntegrationTimeout',
    # Files
    'maxConcurrentFileReads',
    'maxReadFileLine',
    'maxWorkspaceFiles',
    'maxOpenTabsContext',
    'maxGitStatusFiles',
    'maxImageFileSize',
    'maxTotalImageSize',
    'fuzzyMatchThreshold',
    'showRooIgnoredFiles',
    # Custom modes and instructions
    'customInstructions',
    'customModes',
    'customModePrompts',
    # Codebase index
    'codebaseIndexConfig',
    'codebaseIndexModels',
    # MCP
    'mcpEnabled',
    # Telemetry
    'telemetrySetting',
    # Enter behavior
    'enterBehavior',
    # Screenshot
    'screenshotQuality',
    # Experiments
    'experiments',
}


def find_vscdb_path():
    """Find the state.vscdb file path."""
    appdata = os.environ.get('APPDATA')
    if not appdata:
        raise FileNotFoundError("APPDATA environment variable not set")

    db_path = os.path.join(appdata, VSCDB_RELATIVE_PATH)
    if not os.path.exists(db_path):
        raise FileNotFoundError(f"state.vscdb not found at: {db_path}")

    return db_path


def read_roo_settings(db_path=None):
    """Read Roo settings from state.vscdb. Returns dict."""
    if db_path is None:
        db_path = find_vscdb_path()

    # Copy DB to avoid locking issues with VS Code
    with tempfile.NamedTemporaryFile(suffix='.vscdb', delete=False) as tmp:
        tmp_path = tmp.name

    try:
        shutil.copy2(db_path, tmp_path)
        conn = sqlite3.connect(tmp_path)
        cur = conn.cursor()
        cur.execute("SELECT value FROM ItemTable WHERE key=?", (VSCDB_KEY,))
        row = cur.fetchone()
        conn.close()

        if not row:
            raise ValueError(f"Key '{VSCDB_KEY}' not found in state.vscdb")

        val = row[0]
        if isinstance(val, bytes):
            val = val.decode('utf-8')

        return json.loads(val)
    finally:
        os.unlink(tmp_path)


def write_roo_settings(settings, db_path=None, dry_run=False):
    """Write Roo settings back to state.vscdb."""
    if db_path is None:
        db_path = find_vscdb_path()

    if dry_run:
        print(f"[DRY-RUN] Would write {len(settings)} keys to {db_path}")
        return True

    # Backup first
    backup_path = db_path + f'.backup_{datetime.now().strftime("%Y%m%d_%H%M%S")}'
    shutil.copy2(db_path, backup_path)
    print(f"Backup created: {backup_path}")

    # Write to the actual DB
    val = json.dumps(settings, ensure_ascii=False)
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("UPDATE ItemTable SET value=? WHERE key=?", (val, VSCDB_KEY))
    conn.commit()
    conn.close()

    return True


def filter_settings(settings, mode='safe'):
    """Filter settings for export.
    mode='safe': Only include SYNC_SAFE_KEYS
    mode='full': Include everything except EXCLUDED_KEYS
    """
    if mode == 'full':
        return {k: v for k, v in settings.items() if k not in EXCLUDED_KEYS}
    else:
        return {k: v for k, v in settings.items() if k in SYNC_SAFE_KEYS}


def cmd_extract(args):
    """Extract settings to a JSON file."""
    settings = read_roo_settings()

    mode = 'full' if args.full else 'safe'
    filtered = filter_settings(settings, mode=mode)

    output = {
        'metadata': {
            'machine': os.environ.get('COMPUTERNAME', 'unknown'),
            'timestamp': datetime.now().isoformat(),
            'mode': mode,
            'keys_count': len(filtered),
            'total_keys': len(settings),
        },
        'settings': filtered,
    }

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
        print(f"Extracted {len(filtered)} settings to {args.output}")
    else:
        print(json.dumps(output, indent=2, ensure_ascii=False))


def cmd_inject(args):
    """Inject settings from a JSON file."""
    with open(args.input, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Support both raw dict and wrapped format
    if 'settings' in data:
        new_settings = data['settings']
    else:
        new_settings = data

    # Read current settings
    current = read_roo_settings()

    # Filter keys to inject
    if args.keys:
        allowed_keys = set(args.keys.split(','))
        new_settings = {k: v for k, v in new_settings.items() if k in allowed_keys}
    else:
        # Only inject sync-safe keys by default
        new_settings = {k: v for k, v in new_settings.items() if k in SYNC_SAFE_KEYS}

    # Show changes
    changes = []
    for key, new_val in new_settings.items():
        old_val = current.get(key)
        if old_val != new_val:
            changes.append((key, old_val, new_val))

    if not changes:
        print("No changes detected.")
        return

    print(f"\nChanges to apply ({len(changes)}):")
    for key, old_val, new_val in changes:
        old_str = str(old_val)[:80] if old_val is not None else '<not set>'
        new_str = str(new_val)[:80]
        print(f"  {key}: {old_str} -> {new_str}")

    if args.dry_run:
        print(f"\n[DRY-RUN] Would modify {len(changes)} settings")
        return

    # Apply changes
    for key, _, new_val in changes:
        current[key] = new_val

    write_roo_settings(current)
    print(f"\nApplied {len(changes)} changes. Restart VS Code to take effect.")


def cmd_get(args):
    """Get a specific setting value."""
    settings = read_roo_settings()
    key = args.key

    if key not in settings:
        print(f"Key '{key}' not found. Available keys ({len(settings)}):")
        for k in sorted(settings.keys()):
            print(f"  {k}")
        sys.exit(1)

    val = settings[key]
    if isinstance(val, (dict, list)):
        print(json.dumps(val, indent=2, ensure_ascii=False))
    else:
        print(val)


def cmd_set(args):
    """Set a specific setting value."""
    settings = read_roo_settings()
    key = args.key
    value_str = args.value

    # Try to parse as JSON (for dicts, lists, numbers, booleans)
    try:
        value = json.loads(value_str)
    except json.JSONDecodeError:
        value = value_str

    old_val = settings.get(key)
    if old_val == value:
        print(f"No change: {key} = {value}")
        return

    print(f"Setting {key}: {str(old_val)[:80]} -> {str(value)[:80]}")

    if args.dry_run:
        print("[DRY-RUN] No changes made")
        return

    settings[key] = value
    write_roo_settings(settings)
    print("Done. Restart VS Code to take effect.")


def cmd_diff(args):
    """Compare local settings with a reference file."""
    settings = read_roo_settings()

    with open(args.reference, 'r', encoding='utf-8') as f:
        ref_data = json.load(f)

    if 'settings' in ref_data:
        ref_settings = ref_data['settings']
    else:
        ref_settings = ref_data

    # Compare sync-safe keys only
    diffs = []
    for key in sorted(SYNC_SAFE_KEYS):
        local_val = settings.get(key)
        ref_val = ref_settings.get(key)

        if local_val != ref_val:
            if key in settings and key in ref_settings:
                diffs.append(('modified', key, local_val, ref_val))
            elif key in settings:
                diffs.append(('local_only', key, local_val, None))
            else:
                diffs.append(('ref_only', key, None, ref_val))

    if not diffs:
        print("No differences found (sync-safe keys only)")
        return

    print(f"Differences ({len(diffs)}):\n")
    for diff_type, key, local_val, ref_val in diffs:
        if diff_type == 'modified':
            print(f"  MODIFIED  {key}")
            print(f"    local: {str(local_val)[:100]}")
            print(f"    ref:   {str(ref_val)[:100]}")
        elif diff_type == 'local_only':
            print(f"  LOCAL     {key}: {str(local_val)[:100]}")
        elif diff_type == 'ref_only':
            print(f"  MISSING   {key}: {str(ref_val)[:100]}")
        print()


def main():
    parser = argparse.ArgumentParser(
        description='Roo Settings Manager - Read/Write Roo Code settings from state.vscdb'
    )
    subparsers = parser.add_subparsers(dest='command', required=True)

    # extract
    p_extract = subparsers.add_parser('extract', help='Export settings to JSON')
    p_extract.add_argument('-o', '--output', help='Output file path')
    p_extract.add_argument('--full', action='store_true',
                          help='Export all settings (not just sync-safe)')

    # inject
    p_inject = subparsers.add_parser('inject', help='Import settings from JSON')
    p_inject.add_argument('-i', '--input', required=True, help='Input JSON file')
    p_inject.add_argument('--dry-run', action='store_true', help='Simulate without changes')
    p_inject.add_argument('--keys', help='Comma-separated list of keys to inject')

    # get
    p_get = subparsers.add_parser('get', help='Get a specific setting')
    p_get.add_argument('key', help='Setting key name')

    # set
    p_set = subparsers.add_parser('set', help='Set a specific setting')
    p_set.add_argument('key', help='Setting key name')
    p_set.add_argument('value', help='New value (JSON-parseable)')
    p_set.add_argument('--dry-run', action='store_true', help='Simulate without changes')

    # diff
    p_diff = subparsers.add_parser('diff', help='Compare with reference file')
    p_diff.add_argument('-r', '--reference', required=True, help='Reference JSON file')

    args = parser.parse_args()

    try:
        if args.command == 'extract':
            cmd_extract(args)
        elif args.command == 'inject':
            cmd_inject(args)
        elif args.command == 'get':
            cmd_get(args)
        elif args.command == 'set':
            cmd_set(args)
        elif args.command == 'diff':
            cmd_diff(args)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

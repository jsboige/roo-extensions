# Qdrant Backup Layer 1 — Daily Snapshots to GDrive

**Status:** Approved 2026-05-18 (user mandate post data-loss incident 2026-05-16)
**Owner:** myia-ai-01 (primary), portable to po-2024 / po-2026 later
**Scope:** Single-collection snapshots pushed to `$ROOSYNC_SHARED_PATH/qdrant-snapshots/<machineId>/`

---

## Architecture

```
+--------------------+        snapshot         +--------------------------+
|  Qdrant local      |  ---------------->     |  Local fs (download)     |
|  http://localhost: |    POST/GET /snap..    |                          |
|  6333              |                         +-----------+--------------+
+--------------------+                                     |
                                                           | move + retention
                                                           v
                              $ROOSYNC_SHARED_PATH/qdrant-snapshots/
                                <machineId>/
                                  <collection>/
                                    YYYY-MM-DD/
                                      <auto-named>.snapshot
```

- One `.snapshot` file per day (binary, Qdrant native format).
- Retention: **7 daily** + **4 weekly Mondays** (max 11 directories per collection).
- Scheduled via Windows Task Scheduler, daily at **03:17 local** (off-peak, off-round-minute to avoid cron herd).

## Installation (3 commands)

```powershell
# 1. Pre-flight + register schtask (run from repo root)
pwsh -NoProfile -File scripts/qdrant/install-backup-schtask.ps1

# 2. Immediate dry-run to verify everything works
pwsh -NoProfile -File scripts/qdrant/backup-snapshot.ps1 -WhatIf

# 3. First real backup (optional — schtask will fire at next 03:17)
Start-ScheduledTask -TaskName Qdrant-Snapshot-Daily
```

The installer validates: Qdrant reachable, `$ROOSYNC_SHARED_PATH` set + writable, `backup-snapshot.ps1` present.

## Retention Rules

| Bucket | Count | Selection |
|--------|-------|-----------|
| Daily  | 7     | 7 most recent date-stamped directories |
| Weekly | 4     | 4 most recent Mondays |

Both buckets are unioned (a Monday in the last 7 days counts once). Anything outside the union is deleted.

### Manual prune (one-off cleanup)

```powershell
# List directories under one machine
Get-ChildItem "$env:ROOSYNC_SHARED_PATH/qdrant-snapshots/myia-ai-01/roo_tasks_semantic_index" -Directory

# Force a retention pass without creating a new snapshot
pwsh -NoProfile -File scripts/qdrant/backup-snapshot.ps1   # idempotent if today already exists
```

## Restore Procedure

Restore is **manual** by design (Layer 1 = backup-only, no auto-rollback).

### Example: restore yesterday's snapshot into the current collection

```powershell
$snap = Get-ChildItem "$env:ROOSYNC_SHARED_PATH/qdrant-snapshots/myia-ai-01/roo_tasks_semantic_index" -Recurse -Filter *.snapshot |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

pwsh -NoProfile -File scripts/qdrant/restore-snapshot.ps1 `
    -SnapshotPath $snap.FullName `
    -Collection roo_tasks_semantic_index
```

### Destructive recreate (full collection replace)

```powershell
pwsh -NoProfile -File scripts/qdrant/restore-snapshot.ps1 `
    -SnapshotPath $snap.FullName `
    -Collection roo_tasks_semantic_index `
    -RecreateCollection            # interactive DROP confirmation
    # Add -Force to skip the prompt (CI / scripted recovery only)
```

The restore script prints a `WARNING: THIS WILL DROP THE COLLECTION` block and requires typing `DROP` (or passing `-Force`) before proceeding.

## Monitoring

- **Logs:** `outputs/qdrant-backup/backup-YYYYMMDD.log` (UTF-8, one line per event)
- **Expected daily size:** snapshot of `roo_tasks_semantic_index` (~315K points, dim 2560) ~ a few GB. Verify against `Get-ChildItem` on the day directory.
- **Schtask history:** `Get-ScheduledTaskInfo -TaskName Qdrant-Snapshot-Daily` shows last result + next run.

Quick health check:

```powershell
$today = Get-Date -Format 'yyyy-MM-dd'
Get-ChildItem "$env:ROOSYNC_SHARED_PATH/qdrant-snapshots/$($env:COMPUTERNAME.ToLowerInvariant())/roo_tasks_semantic_index/$today" -ErrorAction SilentlyContinue
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `[FAIL] Qdrant unreachable` in install | Qdrant container down | `docker ps`, `docker start qdrant` |
| Snapshot creation 401 | Missing `QDRANT_API_KEY` | Set env var or rely on submodule `.env` fallback |
| GDrive write failure | Drive offline / full | `Test-Path $env:ROOSYNC_SHARED_PATH`, check GDrive client |
| Schtask result `0x1` | Script error | Check `outputs/qdrant-backup/backup-YYYYMMDD.log` first; then last-run event in Event Viewer |
| Snapshot file is 0 bytes | Download interrupted | Re-run manually; check Qdrant logs and disk space |
| Retention deletes too much | Clock skew or duplicate dirs | Inspect `Get-ChildItem`; rules expect `YYYY-MM-DD` only |

## What Layer 1 does NOT do

- No compression (snapshots are already compact)
- No off-site replication beyond GDrive (Layer 2 territory)
- No Postgres / metadata enrichment backup
- No automated restore validation (Layer 3)

These belong to subsequent layers and are out of scope per the user mandate.

## References

- Incident: 2026-05-16 ~05:25Z (~2M points lost, cause unclear)
- User decision: 2026-05-18 dashboard ("Couche 1 APPROUVÉ")
- Related: PR adjacency to #2264 (budget/safety theme)

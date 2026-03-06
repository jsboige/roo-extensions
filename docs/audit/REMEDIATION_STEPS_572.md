# Issue #572 - Remediation Steps

**Status:** Investigation Complete - Ready for Execution
**Priority:** CRITICAL
**Estimated time:** 30-60 minutes

---

## Summary of Issues Found

1. **Corrupted heartbeat file** (`test-machine.json`) - causing 1000+ error entries every 3h
2. **Corrupted presence files** (MyIA-Web1, myia-po-2024, myia-po-2023) - JSON syntax errors
3. **RooSync registry conflict** - stale machine ID from 2026-02-10
4. **Qdrant index gap** (5MB) - cache/embeddings mismatch
5. **VS Code extension failures** - 6 problematic extensions identified
6. **Infrastructure warnings** - mostly low priority

---

## PHASE 1: CRITICAL FIX (15 minutes)

### Step 1.1: Delete Corrupted Heartbeat File

**File to delete:**
```
G:/Mon Drive/Synchronisation/RooSync/.shared-state/heartbeats/test-machine.json
```

**Procedure:**
```powershell
# Verify file exists and is corrupted
$heartbeatPath = "G:\Mon Drive\Synchronisation\RooSync\.shared-state\heartbeats\test-machine.json"
if (Test-Path $heartbeatPath) {
    Write-Host "File found: $heartbeatPath"
    Get-Content $heartbeatPath | Out-Host

    # Backup before deletion
    Copy-Item $heartbeatPath "$heartbeatPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"

    # Delete
    Remove-Item $heartbeatPath -Force
    Write-Host "File deleted successfully"
} else {
    Write-Host "File not found (already deleted?)"
}
```

**Expected result:**
- File is deleted (or backed up)
- Next log entry should NOT contain "test-machine.json" errors

**Verification:**
```bash
# In VS Code, check Roo-Code Output channel
# Should NOT see: "[HeartbeatService] Erreur lecture fichier heartbeat test-machine.json"
# within next 30 seconds
```

---

### Step 1.2: Verify and Fix Presence Files

**Files to check:**
```
G:/Mon Drive/Synchronisation/RooSync/.shared-state/presence/MyIA-Web1.json
G:/Mon Drive/Synchronisation/RooSync/.shared-state/presence/myia-po-2024.json
G:/Mon Drive/Synchronisation/RooSync/.shared-state/presence/myia-po-2023.json
```

**Procedure:**
```powershell
$presencePath = "G:\Mon Drive\Synchronisation\RooSync\.shared-state\presence"

# List all presence files
Get-ChildItem $presencePath -Filter "*.json" | ForEach-Object {
    $file = $_.FullName
    Write-Host "Checking: $($_.Name)"

    try {
        $content = Get-Content $file -Raw
        $json = $content | ConvertFrom-Json
        Write-Host "  ✅ Valid JSON"
    } catch {
        Write-Host "  ❌ Invalid JSON: $_"
        Write-Host "  Action: Delete and regenerate"

        # Backup corrupted file
        Copy-Item $file "$file.corrupted.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Remove-Item $file -Force
    }
}
```

**Expected result:**
- All presence files are valid JSON
- Corrupted files are deleted and will be regenerated

---

### Step 1.3: Clean RooSync Registry

**File to update:**
```
G:/Mon Drive/Synchronisation/RooSync/.shared-state/registry/machines.json
```

**Procedure:**
```powershell
$registryPath = "G:\Mon Drive\Synchronisation\RooSync\.shared-state\registry\machines.json"

# Backup original
Copy-Item $registryPath "$registryPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"

# Read and validate
$registry = Get-Content $registryPath -Raw | ConvertFrom-Json

# Check for stale myia-ai-01 entry
$registry | Get-Member -Type NoteProperty | ForEach-Object {
    $machineId = $_.Name
    $entry = $registry.$machineId

    if ($machineId -eq "myia-ai-01") {
        Write-Host "Machine: $machineId"
        Write-Host "  First seen: $($entry.firstSeen)"
        Write-Host "  Last updated: $($entry.lastUpdated)"

        # If from 2026-02-10, it's stale
        if ($entry.firstSeen -like "2026-02-10*") {
            Write-Host "  ⚠️ STALE ENTRY from 2026-02-10"
            Write-Host "  Action: Removing stale entry"
            $registry | Add-Member -NotePropertyName $machineId -NotePropertyValue $null -Force
        }
    }
}

# Write cleaned registry
$registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath -Encoding UTF8
Write-Host "Registry updated"
```

**Expected result:**
- Stale `myia-ai-01` entry removed or updated
- RooSync identity conflict message should not appear on next startup

---

## PHASE 2: INDEX REBUILD (5 minutes)

### Step 2.1: Rebuild Qdrant Index

**Purpose:** Fix the 5MB gap between SQLite cache and Qdrant embeddings

**Procedure:**
```bash
# From Claude Code console or INTERCOM
roosync_indexing(action: "rebuild")
```

**Expected output:**
```
Rebuilding index cache...
Processing X conversations...
Syncing to Qdrant...
Index rebuild complete. Gap: 0 bytes
```

**Verification:**
```bash
# Check logs for:
# "⚠️ Incohérence détectée" should NOT appear
# If still present, run with force flag:
roosync_indexing(action: "rebuild", force_rebuild: true)
```

---

## PHASE 3: VS CODE EXTENSIONS (10 minutes)

### Step 3.1: Remove Problematic Extensions

**Extensions to uninstall:**
```
- ms-semantic-kernel.semantic-kernel (unnecessary, causes crashes)
- fernandoescolar.vscode-solution-explorer (stack overflow)
- vscjava.migrate-java-to-azure (missing files)
- prompt-flow.prompt-flow (not implemented methods)
```

**Procedure:**
```powershell
$extensionsToRemove = @(
    "ms-semantic-kernel.semantic-kernel",
    "fernandoescolar.vscode-solution-explorer",
    "vscjava.migrate-java-to-azure",
    "prompt-flow.prompt-flow"
)

$extensionsToRemove | ForEach-Object {
    Write-Host "Uninstalling: $_"
    code --uninstall-extension $_
}
```

**Verification:**
```bash
# Check VS Code extension list
code --list-extensions | grep -E "semantic-kernel|solution-explorer|migrate-java|prompt-flow"
# Should return nothing
```

---

### Step 3.2: Update Key Extensions

**Extensions to update:**
```
- eamodio.gitlens (Cannot read properties of undefined)
- GitHub.copilot-chat (Channel closed)
- ms-python.vscode-python-envs (Channel closed)
```

**Procedure:**
```powershell
code --install-extension eamodio.gitlens@latest
code --install-extension GitHub.copilot-chat@latest
code --install-extension ms-python.vscode-python-envs@latest
```

---

### Step 3.3: Suppress jinavigator Warning

**File:** `mcps/internal/servers/jinavigator-server/package.json`

**Change:**
```json
{
  ...
  "type": "module",
  ...
}
```

**Procedure:**
```bash
# Add "type": "module" to package.json if not present
# This suppresses MODULE_TYPELESS_PACKAGE_JSON warning
```

---

## PHASE 4: VERIFICATION (10 minutes)

### Step 4.1: Restart Services

```powershell
# Restart VS Code with extensions cleaned
code .

# Wait for all services to initialize (2-3 minutes)
# Check output channels:
#  - Roo-Code Output
#  - roo-state-manager
#  - Win-CLI
```

**Check for:**
```
❌ Should NOT see:
  - "test-machine.json" errors
  - "Machines offline" warnings
  - "PresenceManager" JSON errors
  - "Identity conflict" messages
  - "Maximum call stack exceeded"
  - "Module type not specified"

✅ Should see:
  - Normal heartbeat registrations
  - All 6 machines online
  - Services initialized successfully
```

---

### Step 4.2: Verify Roo Operations

```bash
# In INTERCOM, assign a simple task
[TASK] verify heartbeat is working

# Expected output in Roo logs:
# [HeartbeatService] Machine myia-ai-01 registered: 2026-03-06 18:40:00
# (no errors about test-machine)
```

---

### Step 4.3: Cross-Machine Validation

**For each remaining machine (5 others):**

1. SSH into the machine
2. Run: `roosync_heartbeat(action: "status", forceCheck: true)`
3. Verify machine appears ONLINE (not OFFLINE)
4. Verify presence file is valid JSON

---

## Rollback Procedure (if needed)

### If Phase 1 breaks something:

```powershell
# Restore heartbeat file
Copy-Item "G:\Mon Drive\Synchronisation\RooSync\.shared-state\heartbeats\test-machine.json.backup.*" `
          "G:\Mon Drive\Synchronisation\RooSync\.shared-state\heartbeats\test-machine.json"

# Restore presence files
Copy-Item "G:\Mon Drive\Synchronisation\RooSync\.shared-state\presence\*.corrupted.*" `
          "G:\Mon Drive\Synchronisation\RooSync\.shared-state\presence\"

# Restore registry
Copy-Item "G:\Mon Drive\Synchronisation\RooSync\.shared-state\registry\machines.json.backup.*" `
          "G:\Mon Drive\Synchronisation\RooSync\.shared-state\registry\machines.json"
```

---

## Timeline

| Phase | Task | Duration | Cumulative |
|-------|------|----------|------------|
| 1 | Delete test-machine.json | 3 min | 3 min |
| 1 | Fix presence files | 5 min | 8 min |
| 1 | Clean registry | 4 min | 12 min |
| 2 | Rebuild index | 5 min | 17 min |
| 3 | Remove extensions | 5 min | 22 min |
| 3 | Update extensions | 3 min | 25 min |
| 3 | Update package.json | 1 min | 26 min |
| 4 | Restart & verify | 10 min | 36 min |
| 4 | Cross-machine validation | 20 min | 56 min |

**Total estimated time:** 45-60 minutes (with cross-machine checks)

---

## Success Criteria

✅ **Phase 1 Complete When:**
- test-machine.json is deleted
- No more "test-machine" errors in logs
- All machines appear online in heartbeat service
- Registry has no stale entries

✅ **Phase 2 Complete When:**
- Qdrant index gap is 0
- No "Incohérence détectée" messages

✅ **Phase 3 Complete When:**
- 4 problematic extensions removed
- 3 extensions updated
- jinavigator warning suppressed

✅ **Phase 4 Complete When:**
- Services restart without errors
- All 6 machines show as ONLINE
- Roo tasks execute successfully
- No log pollution from extensions

---

## Post-Remediation Monitoring

After fixes, monitor:

1. **Heartbeat service:** Should register all 6 machines every 60 seconds
2. **PresenceManager:** Should read all presence files without errors
3. **VS Code output:** Should be clean (no extension errors)
4. **Roo scheduler:** Should execute tasks without service interruptions
5. **Log volume:** Should decrease significantly (fewer errors)

---

**Status:** Ready for execution
**Assigned to:** myia-ai-01 (Coordinateur)
**Next step:** Execute Phase 1 and report results in GitHub issue #572


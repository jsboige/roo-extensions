# VS Code Logs Audit Report - 2026-03-06

**Issue:** #572 - [INVESTIGATE] Audit et nettoyage des logs VS Code (Renderer, ExtHost, Roo) cross-machine

**Machine analyzed:** myia-ai-01 (Coordinateur Principal)
**Analysis date:** 2026-03-06 18:30 UTC
**Log period:** 2026-03-04 to 2026-03-06

---

## Executive Summary

The VS Code logs on myia-ai-01 reveal **4 major error categories** affecting operational stability:

1. **CRITICAL: roo-state-manager service errors** (HIGH PRIORITY)
2. **MAJOR: VS Code extension failures** (MEDIUM-HIGH PRIORITY)
3. **MINOR: Infrastructure warnings** (LOW PRIORITY)
4. **UNKNOWN: Roo Code Output channel** (REQUIRES VERIFICATION)

**Key Finding:** The heartbeat file `test-machine.json` is **corrupted** (SyntaxError: Unexpected end of JSON input), causing repeated warnings every 30 seconds. This is the **PRIMARY BLOCKER** and should be fixed immediately.

---

## Category 1: roo-state-manager Errors (CRITICAL)

### Error #1.1: Corrupted Heartbeat File - test-machine.json

**Severity:** 🔴 **CRITICAL**
**Frequency:** Every 30 seconds (recurring)
**Pattern:**
```
[WARN] [HeartbeatService] ⚠️ Erreur lecture fichier heartbeat test-machine.json
{
  "error": "SyntaxError: Unexpected end of JSON input"
}
```

**Impact:**
- Continuous log spam (1000+ entries over 3 hours)
- Service unable to register/validate heartbeat for `test-machine`
- All machines appear offline in the presence manager

**Root Cause:**
- File `test-machine.json` is an **artifact from testing** and contains corrupted JSON (incomplete file)
- The heartbeat service continuously tries to read and parse it every 30 seconds

**Actions Required:**
- [ ] **Immediate:** Delete/backup the corrupted heartbeat file: `G:/Mon Drive/Synchronisation/RooSync/.shared-state/heartbeats/test-machine.json`
- [ ] Verify that `test-machine` is not a real machine (it's a test artifact)
- [ ] Restart roo-state-manager service after cleanup

**Verification:**
```bash
# Before: Should show SyntaxError in logs every 30s
# After: No more test-machine heartbeat errors
```

---

### Error #1.2: Machine Offline Detection

**Severity:** 🟠 **HIGH**
**Pattern:**
```
[WARN] [HeartbeatService] ⚠️ Machines offline détectées:
  myia-ai-01, myia-po-2023, myia-web1, myia-po-2025, myia-po-2026, myia-po-2024
```

**Root Cause:**
- Consequence of Error #1.1 (test-machine corruption causing cascading failures)
- All 6 real machines appear offline because heartbeat service crashes

**Actions Required:**
- [ ] Fix Error #1.1 first (delete test-machine.json)
- [ ] Verify heartbeat files for all 6 machines are valid JSON
- [ ] Re-register heartbeats if needed

---

### Error #1.3: PresenceManager - Corrupted Presence Files

**Severity:** 🟠 **HIGH**
**Pattern:**
```
[PresenceManager] Erreur lecture présence pour MyIA-Web1:
  SyntaxError: Unexpected end of JSON input
```

**Affected Machines:**
- MyIA-Web1 (presence corrupted)
- myia-po-2024 (presence corrupted)
- myia-po-2023 (presence corrupted)

**Root Cause:**
- Similar to heartbeat issue: corrupted presence files on GDrive
- Possibly from interrupted writes or test artifacts

**Actions Required:**
- [ ] Check presence files: `G:/Mon Drive/Synchronisation/RooSync/.shared-state/presence/{machine-name}.json`
- [ ] Identify and remove corrupted entries
- [ ] Regenerate presence files if necessary

---

### Error #1.4: RooSync Service Identity Conflict

**Severity:** 🟠 **HIGH**
**Pattern:**
```
[RooSyncService] ⚠️ CONFLIT D'IDENTITÉ DÉTECTÉ AU DÉMARRAGE:
MachineId: myia-ai-01
Conflit avec: service (première vue: 2026-02-10T12:25:09.018Z)
```

**Root Cause:**
- Machine ID `myia-ai-01` already registered in the RooSync registry
- Registry entry from previous session (2026-02-10) not properly cleaned up
- Service continues but with **potential conflicts**

**Actions Required:**
- [ ] Check RooSync registry: `G:/Mon Drive/Synchronisation/RooSync/.shared-state/registry/machines.json`
- [ ] Remove stale entry for `myia-ai-01` from 2026-02-10
- [ ] Re-register current machine properly

---

### Error #1.5: BaselineManager Service Unavailable

**Severity:** 🟡 **MEDIUM**
**Pattern:**
```
[BaselineManager] NonNominativeBaselineService non disponible
```

**Root Cause:**
- BaselineManager is looking for a service that doesn't exist or isn't loaded
- Possibly a configuration issue or missing service registration

**Actions Required:**
- [ ] Check if `NonNominativeBaselineService` should be available
- [ ] If not needed, suppress the warning in the service initialization
- [ ] If needed, diagnose why service isn't available

---

### Error #1.6: Qdrant Index Inconsistency

**Severity:** 🟡 **MEDIUM**
**Pattern:**
```
⚠️ Incohérence détectée: écart de 5056822 entre squelettes et Qdrant
```

**Root Cause:**
- **5 million byte (5MB) gap** between:
  - SQLite skeleton cache (conversation index)
  - Qdrant vector database (embeddings index)
- Index is **stale or corrupted**

**Impact:**
- Semantic search (`codebase_search`, `roosync_search`) may return stale results
- Indexing pipeline needs rebuild

**Actions Required:**
- [ ] Check when last index rebuild occurred
- [ ] Run: `roosync_indexing(action: "rebuild")` to rebuild cache
- [ ] Verify gap disappears after rebuild

---

### Error #1.7: Conversation Analysis - No Files Found

**Severity:** 🟡 **MEDIUM**
**Pattern:**
```
⚠️ [analyzeConversation] Skipping .shared-state: NO FILES FOUND
```

**Root Cause:**
- `.shared-state` directory is empty or inaccessible
- Likely GDrive synchronization issue

**Actions Required:**
- [ ] Verify GDrive path is correctly mounted: `G:/Mon Drive/Synchronisation/RooSync/.shared-state/`
- [ ] Check if Google Drive sync is active
- [ ] List files in the directory to confirm content exists

---

### Error #1.8: ToolUsageInterceptor Init Logging via stderr

**Severity:** 🟢 **LOW**
**Pattern:**
```
🔧 [ToolUsageInterceptor] Initialized with config: {...}
```

**Root Cause:**
- Service initialization logs sent to stderr instead of proper logger
- Pollutes error logs with informational messages

**Actions Required:**
- [ ] Change logging in ToolUsageInterceptor: use logger instead of console.error
- [ ] File: `mcps/internal/servers/roo-state-manager/src/tools/ToolUsageInterceptor.ts`

---

## Category 2: VS Code Extensions (MEDIUM-HIGH PRIORITY)

### Error #2.1: Semantic Kernel Extension Failures

**Severity:** 🟠 **HIGH**
**Pattern:**
```
ms-semantic-kernel.semantic-kernel:
- bundle.l10n.fr.json (missing file)
- webviewPanel undefined (crash on deactivation)
```

**Root Cause:**
- Incomplete installation or corrupted files
- Extension UI framework (`webviewPanel`) not properly initialized

**Actions Required:**
- [ ] Uninstall: `ms-semantic-kernel.semantic-kernel` (likely unnecessary)
- [ ] Or update to latest version if needed
- [ ] Verify remaining extensions are functional

---

### Error #2.2: GitLens Extension Crash

**Severity:** 🟠 **HIGH**
**Pattern:**
```
eamodio.gitlens:
  Cannot read properties of undefined (reading 'dispose')
```

**Root Cause:**
- Cleanup code trying to dispose undefined object
- Version incompatibility with current VS Code version

**Actions Required:**
- [ ] Update GitLens to latest version: `code --install-extension eamodio.gitlens@latest`
- [ ] Or disable if not essential: `code --uninstall-extension eamodio.gitlens`

---

### Error #2.3: Solution Explorer Stack Overflow

**Severity:** 🟠 **HIGH**
**Pattern:**
```
fernandoescolar.vscode-solution-explorer:
  Maximum call stack size exceeded (at dispose)
```

**Root Cause:**
- Recursive cleanup causing stack overflow
- Extension likely has a bug in dispose method

**Actions Required:**
- [ ] Uninstall if not critical: `code --uninstall-extension fernandoescolar.vscode-solution-explorer`
- [ ] Check if issue persists after removal

---

### Error #2.4: Copilot Chat Channel Closed

**Severity:** 🟡 **MEDIUM**
**Pattern:**
```
GitHub.copilot-chat: Channel has been closed
ms-python.vscode-python-envs: Channel has been closed
```

**Root Cause:**
- Extensions trying to communicate on closed IPC channels
- Usually happens during shutdown or service restart

**Actions Required:**
- [ ] Check if extensions are properly shutting down
- [ ] Restart VS Code to reset channels
- [ ] Monitor if errors persist in new session

---

### Error #2.5: Prompt Flow - Method Not Implemented

**Severity:** 🟡 **MEDIUM**
**Pattern:**
```
prompt-flow.prompt-flow: Method not implemented
```

**Root Cause:**
- Extension references unimplemented VS Code API
- Likely outdated extension for current VS Code version

**Actions Required:**
- [ ] Uninstall if not essential: `code --uninstall-extension prompt-flow.prompt-flow`
- [ ] Check if project needs this extension

---

### Error #2.6: Java Extension Missing Files

**Severity:** 🟡 **MEDIUM**
**Pattern:**
```
vscjava.migrate-java-to-azure-1.13.0:
  agents/appmodassessment.agent.md (missing file)
```

**Root Cause:**
- Incomplete installation or missing agent files
- Extension files not fully downloaded

**Actions Required:**
- [ ] Uninstall if not needed: `code --uninstall-extension vscjava.migrate-java-to-azure`
- [ ] Or reinstall extension: `code --install-extension vscjava.migrate-java-to-azure@latest`

---

## Category 3: Infrastructure Warnings (LOW PRIORITY)

### Error #3.1: jinavigator - MODULE_TYPELESS_PACKAGE_JSON

**Severity:** 🟢 **LOW**
**Pattern:**
```
MODULE_TYPELESS_PACKAGE_JSON Warning: Module type not specified
  Add "type": "module" to package.json
```

**File:** `mcps/internal/servers/jinavigator-server/package.json`

**Actions Required:**
- [ ] Add to `package.json`: `"type": "module"`
- [ ] Eliminates performance overhead

---

### Error #3.2: markitdown - ffmpeg Missing

**Severity:** 🟢 **LOW**
**Pattern:**
```
Couldn't find ffmpeg or avconv - defaulting to ffmpeg
```

**Impact:**
- Audio conversion disabled (markitdown can't process audio)
- Text extraction still works

**Actions Required:**
- [ ] Install ffmpeg if audio support needed: `choco install ffmpeg`
- [ ] Or leave as-is if audio conversion not required

---

### Error #3.3: UriError - Scheme Contains Illegal Characters

**Severity:** 🟡 **MEDIUM**
**Pattern:**
```
[UriError]: Scheme contains illegal characters
```

**Root Cause:**
- Unknown MCP or extension creating invalid URIs
- Possibly from a broken path or file reference

**Actions Required:**
- [ ] Search logs for the context before error
- [ ] Identify which extension/MCP triggers this
- [ ] Review the URI generation code

---

### Error #3.4: deprecated punycode Warning

**Severity:** 🟢 **LOW**
**Pattern:**
```
(node:58324) [DEP0040]: punycode is deprecated
```

**Root Cause:**
- Node.js dependency using deprecated punycode module
- Will be removed in Node.js v20+

**Actions Required:**
- [ ] Update dependencies: `npm audit fix`
- [ ] Not urgent but should track for future updates

---

### Error #3.5: SQLite Experimental Feature

**Severity:** 🟢 **LOW**
**Pattern:**
```
SQLite experimental feature used
```

**Root Cause:**
- roo-state-manager uses SQLite for conversation indexing (experimental API)

**Actions Required:**
- [ ] Monitor for issues as SQLite API stabilizes
- [ ] No immediate action needed

---

## Category 4: Roo Code Output Channel (UNKNOWN)

**Status:** ❓ **REQUIRES INVESTIGATION**

**Findings:**
- No messages found in Roo Code Output channel
- Possibly:
  1. Channel not being captured in log collection
  2. Roo not outputting to this channel
  3. Channel output disabled in configuration

**Actions Required:**
- [ ] Verify Roo is configured to output to Output Channel
- [ ] Check VS Code Output panel manually during next Roo run
- [ ] Add explicit logging to roo-state-manager service

---

## Cross-Machine Validation Checklist

| Machine | Status | Actions Required |
|---------|--------|------------------|
| myia-ai-01 | 🔴 CRITICAL | Fix test-machine.json, PresenceManager, RooSync registry |
| myia-po-2023 | ⚠️ PENDING | Check presence file corruption |
| myia-po-2024 | ⚠️ PENDING | Check presence file corruption |
| myia-po-2025 | ⚠️ PENDING | Verify no log pollution |
| myia-po-2026 | ⚠️ PENDING | Verify no log pollution |
| myia-web1 | ⚠️ PENDING | Check presence file corruption |

---

## Remediation Plan (Priority Order)

### PHASE 1: CRITICAL (Today)
1. **Delete corrupted heartbeat file:**
   - Path: `G:/Mon Drive/Synchronisation/RooSync/.shared-state/heartbeats/test-machine.json`
   - Expected effect: Stops 1000+ log entries every 3 hours
   - Verification: Check logs for "test-machine" errors - should stop

2. **Verify presence files:**
   - Path: `G:/Mon Drive/Synchronisation/RooSync/.shared-state/presence/`
   - Files to check: MyIA-Web1.json, myia-po-2024.json, myia-po-2023.json
   - Action: Remove corrupted entries or regenerate

3. **Clean RooSync registry:**
   - Path: `G:/Mon Drive/Synchronisation/RooSync/.shared-state/registry/machines.json`
   - Action: Remove stale `myia-ai-01` entry from 2026-02-10

### PHASE 2: HIGH (Within 24h)
4. Rebuild Qdrant index: `roosync_indexing(action: "rebuild")`
5. Update VS Code extensions (GitLens, Copilot)
6. Uninstall unused extensions (Semantic Kernel, Solution Explorer, etc.)

### PHASE 3: MEDIUM (Within 1 week)
7. Add "type": "module" to jinavigator package.json
8. Investigate UriError source
9. Collect logs from all 5 other machines and validate

### PHASE 4: LOW (Nice-to-have)
10. Install ffmpeg if audio support is needed
11. Update npm dependencies to remove deprecated punycode

---

## Testing & Validation

**After fixes, verify:**
1. ✅ No more "test-machine.json" errors in logs
2. ✅ All 6 machines appear online in heartbeat service
3. ✅ PresenceManager can read all presence files
4. ✅ RooSync registry has no identity conflicts
5. ✅ Qdrant index gap is 0
6. ✅ VS Code extensions load without errors
7. ✅ Roo Code Output channel has content

---

## Files to Update

| File | Change | Reason |
|------|--------|--------|
| `mcps/internal/servers/jinavigator-server/package.json` | Add `"type": "module"` | Suppress MODULE_TYPELESS_PACKAGE_JSON warning |
| `mcps/internal/servers/roo-state-manager/src/tools/ToolUsageInterceptor.ts` | Use logger instead of stderr | Reduce log pollution |

---

## Notes

- This audit analyzed **myia-ai-01 only**. The same errors likely affect other machines.
- The **test-machine.json file is critical** - it's causing cascading failures (offline detection, heartbeat errors, etc.)
- **GDrive synchronization** appears healthy but contains corrupted files (presence, heartbeat)
- **VS Code extensions** are largely optional and can be uninstalled without impact
- The **Qdrant index inconsistency** (5MB gap) needs investigation - may indicate stale or corrupted data

---

**Report generated by:** Claude Code (myia-ai-01)
**Date:** 2026-03-06 18:30 UTC
**Next step:** Execute PHASE 1 remediation, then validate on all 6 machines.

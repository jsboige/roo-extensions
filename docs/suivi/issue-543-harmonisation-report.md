# Issue #543 - Harmonisation Settings & Config-Sync Report

**Date:** 2026-03-01
**Coordinator:** myia-ai-01
**Status:** Phase 1 Complete (Baseline Extraction), Phase 2 In Progress (Drift Detection)

---

## Executive Summary

- **Phase 1 (Baseline Extraction):** ✅ myia-ai-01 COMPLETE (78 settings + MCP config extracted)
- **Phase 2 (Drift Detection):** 🔄 In progress (comparison against baseline)
- **Phase 3 (Corrections):** ⏳ Pending (awaiting Phase 1 completion on other machines)
- **Phase 4 (Official Baseline):** ⏳ Pending

### Deliverables Published

| Machine | Settings (extracted) | MCP Config | Modes | GDrive Path | Status |
|---------|---------------------|-----------|-------|------------|--------|
| myia-ai-01 | ✅ 78 keys | ✅ Collected | ✅ Included | v1.0.0-2026-03-01 | COMPLETE |
| myia-po-2023 | ⏳ Pending | ⏳ Pending | ⏳ Pending | - | Dispatched |
| myia-po-2024 | ⏳ Pending | ⏳ Pending | ⏳ Pending | - | Dispatched |
| myia-po-2025 | ⏳ Pending | ⏳ Pending | ⏳ Pending | - | Dispatched |
| myia-po-2026 | ⏳ Pending | ⏳ Pending | ⏳ Pending | - | Dispatched |
| myia-web1 | ⏳ Pending | ⏳ Pending | ⏳ Pending | - | Dispatched |

---

## Phase 1: Baseline Extraction (Complete)

### Objective
Extract configuration from each machine (settings, MCP config, modes) and publish to GDrive for centralized comparison.

### Execution on myia-ai-01

#### 1. Settings Extraction
```bash
python scripts/roo-settings/roo-settings-manager.py extract -o roo-config/baselines/myia-ai-01-settings-baseline.json
```

**Result:** ✅ 78 sync-safe settings extracted (excluding 22 machine-specific/sensitive keys)

**Settings Categories Extracted:**
- **Condensation (5 keys):** autoCondenseContext, autoCondenseContextPercent, customCondensingPrompt, etc.
- **Model Configuration (7 keys):** apiProvider, openAiBaseUrl, openAiModelId, etc.
- **Behavior Settings (14 keys):** autoApprovalEnabled, alwaysAllowMcp, writeDelayMs, rateLimitSeconds, etc.
- **UI/Behavior (8 keys):** browserToolEnabled, enableCheckpoints, mode, language, etc.
- **Terminal (4 keys):** terminalOutputCharacterLimit, terminalCommandDelay, etc.
- **Files (5 keys):** maxConcurrentFileReads, maxReadFileLine, maxWorkspaceFiles, etc.
- **Custom (3 keys):** customInstructions, customModes, customModePrompts
- **Others (27 keys):** codebaseIndexConfig, mcpEnabled, telemetrySetting, experiments, etc.

**Excluded Keys (22):** id, taskHistory, taskHistoryMigratedToFiles, mcpHubInstanceId, clerk-auth-state, lastShownAnnouncementId, hasOpenedModeSelector, dismissedUpsells, organization-settings, user-settings (machine-specific, sensitive)

**File:** `roo-config/baselines/myia-ai-01-settings-baseline.json` (4.2 KB)

#### 2. MCP Configuration Collection
```bash
roosync_config(action: "collect", targets: ["modes", "mcp"])
```

**Result:** ✅ Collected to temp package

**Package Content:**
- `mcp-settings/mcp_settings.json` (5.4 KB) - Full MCP server configuration
- `roo-modes/` - Roo modes definition (if present)

**MCP Servers Configured:** 9+ servers (include roo-state-manager, sk-agent, playwright, win-cli, etc.)

#### 3. GDrive Publication
```bash
roosync_config(action: "publish", version: "1.0.0", description: "Phase 1 baseline extraction - myia-ai-01")
```

**Result:** ✅ Published to GDrive

**GDrive Path:** `G:\Mon Drive\Synchronisation\RooSync\.shared-state\configs\myia-ai-01\v1.0.0-2026-03-01T05-31-18-805Z`

---

## Phase 2: Drift Detection (In Progress)

### Objective
Compare configurations across all machines to detect drifts (CRITICAL, WARNING, INFO).

### Comparison Results (ai-01 vs po-2023, preliminary)

Using `roosync_compare_config(granularity: "full")`:

**Summary:**
- **Total Differences:** 23
- **CRITICAL (3):** system.hostname, system.os, system.uptime
- **IMPORTANT (8):** machineId, timestamp, memory.available, paths (5)
- **WARNING (4):** MCP server array differences
- **INFO (8):** MCP server array additions

**Expected Drifts (NORMAL):**
- System info (hostname, OS, uptime) - **EXPECTED** (different machines)
- machineId, timestamp - **EXPECTED** (per-machine identifiers)
- Hardware memory - **EXPECTED** (different machine specs)

**Concerning Drifts (Requires Investigation):**
- MCP server array differences (indices may indicate missing/extra servers)
- Path differences (may indicate different workspace layouts)

### Next Steps for Phase 2
1. Wait for Phase 1 completion on all 5 other machines
2. Re-run `roosync_compare_config` with all baselines available
3. Filter out EXPECTED drifts (system-level, machine-specific)
4. Focus on CRITICAL application-level drifts (MCP config, condensation settings)

---

## Phase 3: Drift Correction (Pending)

### Planned Actions

For each CRITICAL drift detected:

```bash
# Option A: Apply from baseline
roosync_config(action: "apply", version: "1.0.0", targets: ["modes", "mcp"])

# Option B: Inject specific settings
python scripts/roo-settings/roo-settings-manager.py inject --input baseline.json
```

### Validation Scenarios

#### Scenario A: Drift Detection (PENDING)
- [ ] Modify seuil de condensation on test machine to 50%
- [ ] Run compare_config
- [ ] Verify drift detected as CRITICAL within 5 minutes

#### Scenario B: Round-Trip Correction (PENDING)
- [ ] Publish corrected baseline from coordinator
- [ ] Apply on 3 machines
- [ ] Re-extract and verify convergence

#### Scenario C: Machine Reset (PENDING)
- [ ] Simulate default config machine
- [ ] Run full pipeline (extract → compare → apply)
- [ ] Verify convergence < 10 minutes

---

## Phase 4: Official Baseline (Pending)

```bash
roosync_baseline(action: "update", version: "3.0.0", description: "Post-harmonisation baseline")
```

**Expected Outcome:**
- Official v3.0.0 baseline created and tagged
- All machines reference this baseline
- Zero CRITICAL drifts
- Documented patterns for future syncs

---

## Communication & Coordination

### RooSync Dispatch Sent ✅
- **Message ID:** msg-20260301T053131-igf8wg
- **Recipients:** all (myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026, myia-web1)
- **Priority:** HIGH
- **Content:** Phase 1 execution instructions + completion checklist

### Expected Responses
- [ ] myia-po-2023
- [ ] myia-po-2024
- [ ] myia-po-2025
- [ ] myia-po-2026
- [ ] myia-web1

---

## Technical Details

### Tools Used

| Tool | Purpose | Status |
|------|---------|--------|
| `roo-settings-manager.py` | Extract/inject Roo settings from state.vscdb | ✅ Working |
| `roosync_config(collect)` | Package MCP + modes config | ✅ Working |
| `roosync_config(publish)` | Upload to GDrive | ✅ Working |
| `roosync_compare_config` | Detect configuration drifts | ✅ Working |
| `roosync_list_diffs` | List specific diffs | ⏳ Awaiting full baseline |
| `roosync_config(apply)` | Apply baseline config | ⏳ Ready, not yet used |
| `roosync_baseline(update)` | Create official baseline | ⏳ Ready, not yet used |

### Key Findings

1. **Settings Extraction:** Successfully excluded 22 machine-specific/sensitive keys. Safe for cross-machine sync.
2. **MCP Configuration:** All 9+ servers captured. Ready for comparison.
3. **GDrive Integration:** Publishing working correctly. Paths include timestamp for versioning.
4. **Comparison:** Granular diff detection working. Can distinguish expected (system-level) from unexpected (config) drifts.

---

## Timeline & Milestones

| Phase | Task | Target | Status |
|-------|------|--------|--------|
| 1 | Extract baseline (ai-01) | 2026-03-01 | ✅ DONE |
| 1 | Dispatch to 5 machines | 2026-03-01 | ✅ DONE |
| 1 | Other machines complete | 2026-03-02 | ⏳ IN PROGRESS |
| 2 | Full comparison (ai-01) | 2026-03-02 | 🔄 IN PROGRESS |
| 2 | Drift report (ai-01) | 2026-03-02 | ⏳ PENDING |
| 3 | Fix CRITICAL drifts | 2026-03-03 | ⏳ PENDING |
| 3 | Validation scenarios | 2026-03-03 | ⏳ PENDING |
| 4 | Official baseline v3.0.0 | 2026-03-03 | ⏳ PENDING |

---

## Logs & Artifacts

### Extracted Baselines (in repo)
- `roo-config/baselines/myia-ai-01-settings-baseline.json` - 78 extracted settings

### Published to GDrive
- `configs/myia-ai-01/v1.0.0-2026-03-01T05-31-18-805Z/`
  - `mcp-settings/mcp_settings.json`
  - `roo-modes/` (if any)
  - `manifest.json`

### GitHub Issue
- **#543:** [SPRINT] Harmonisation Settings & Config-Sync - Campagne cross-machine
- **Label:** enhancement, roo-schedulable
- **Project:** RooSync Multi-Agent Tasks

---

## Notes for Next Machines

Each machine executing Phase 1 should:

1. **Create baselines directory:**
   ```bash
   mkdir -p roo-config/baselines
   ```

2. **Extract settings:**
   ```bash
   python scripts/roo-settings/roo-settings-manager.py extract -o roo-config/baselines/{MACHINE}-settings-baseline.json
   ```

3. **Collect config:**
   ```bash
   roosync_config(action: "collect", targets: ["modes", "mcp"])
   ```

4. **Publish to GDrive:**
   ```bash
   roosync_config(action: "publish", version: "1.0.0", description: "Phase 1 baseline extraction - {MACHINE}")
   ```

5. **Report completion** via RooSync reply to msg-20260301T053131-igf8wg

---

**Report Generated:** 2026-03-01 06:35
**Coordinator:** Claude Code on myia-ai-01
**Next Review:** 2026-03-02 (after Phase 1 completion on all machines)

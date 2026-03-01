# Issue #543 - Validation Framework

**Date:** 2026-03-01
**Coordinator:** myia-ai-01
**Purpose:** Test harmonisation pipeline with demanding scenarios

---

## Overview

Three validation scenarios to ensure the harmonisation pipeline works correctly:

1. **Scenario A:** Drift Detection - Can the system detect intentional configuration changes?
2. **Scenario B:** Round-Trip Correction - Can config be synchronized back to multiple machines?
3. **Scenario C:** Machine Reset - Can a default machine converge to baseline quickly?

---

## Scenario A: Drift Detection (READY TO TEST)

### Objective
Verify that `roosync_compare_config` detects CRITICAL drifts when settings are intentionally modified.

### Setup

1. **Baseline:** Use myia-ai-01 extracted baseline (v1.0.0-2026-03-01)
   - Baseline condensation threshold: `autoCondenseContextPercent` (whatever current value is)

2. **Intentional Drift:** Modify a critical setting
   ```bash
   python scripts/roo-settings/roo-settings-manager.py set autoCondenseContextPercent 50
   ```
   (This is the "condensation threshold" mentioned in rules/condensation-thresholds.md as critical)

3. **Detection:** Run comparison
   ```bash
   roosync_compare_config(source: "myia-ai-01", target: "myia-ai-01", granularity: "full", force_refresh: true)
   ```

### Expected Result

- ✅ Drift detected for `autoCondenseContextPercent`
- ✅ Severity: **CRITICAL** (application-level config)
- ✅ Detection time: < 5 minutes

### Pass Criteria

```
Drift detected: autoCondenseContextPercent
  Before: 80 (from baseline)
  After: 50 (intentional modification)
  Severity: CRITICAL
  Category: roo_config (or similar)
```

### Test Execution Plan

```bash
# 1. Record current value
python scripts/roo-settings/roo-settings-manager.py get autoCondenseContextPercent
# Expected: 80 (based on condensation-thresholds.md)

# 2. Introduce drift
python scripts/roo-settings/roo-settings-manager.py set autoCondenseContextPercent 50

# 3. Verify drift was applied
python scripts/roo-settings/roo-settings-manager.py get autoCondenseContextPercent
# Expected: 50

# 4. Run comparison (force refresh to update inventory)
roosync_compare_config(force_refresh: true, granularity: "full")

# 5. Verify CRITICAL drift detected
# Expected output: CRITICAL drift on autoCondenseContextPercent

# 6. Restore baseline value
python scripts/roo-settings/roo-settings-manager.py set autoCondenseContextPercent 80
```

### Status
🟡 **READY TO EXECUTE** (awaiting validation sign-off)

---

## Scenario B: Round-Trip Correction

### Objective
Verify that configuration can be published from baseline and applied to multiple machines successfully.

### Prerequisites
- Phase 1 complete on at least 3 machines (need 3 targets for this scenario)
- All 3 machines have published baselines to GDrive

### Setup

1. **Publish Corrected Config** (from coordinator)
   ```bash
   roosync_config(action: "publish", version: "1.0.0-corrected", description: "Baseline with corrections", machineId: "coordinator")
   ```

2. **Apply on 3 Machines**
   ```bash
   # On each of 3 target machines:
   roosync_config(action: "apply", version: "1.0.0-corrected", targets: ["modes", "mcp"])
   ```

3. **Re-Extract and Compare**
   ```bash
   # On each of 3 machines:
   python scripts/roo-settings/roo-settings-manager.py extract -o roo-config/baselines/{MACHINE}-post-correction.json
   ```

4. **Verify Convergence**
   ```bash
   # On coordinator:
   # Compare the 3 post-correction files - they should be identical
   ```

### Expected Result

- ✅ Config applied successfully on 3 machines
- ✅ Re-extracted settings identical across 3 machines
- ✅ No drifts detected between them

### Pass Criteria

```
Machine A post-correction: 78 keys extracted
Machine B post-correction: 78 keys extracted
Machine C post-correction: 78 keys extracted

Diff A vs B: 0 differences
Diff B vs C: 0 differences
Diff A vs C: 0 differences
```

### Status
🔴 **BLOCKED** (awaiting Phase 1 completion on other machines)

---

## Scenario C: Machine Reset

### Objective
Verify that a machine with default/missing configuration converges to baseline quickly.

### Setup

1. **Simulate Reset** (on test machine)
   - Backup current settings
   - Create minimal default config

2. **Extract Default State**
   ```bash
   python scripts/roo-settings/roo-settings-manager.py extract -o default-state.json
   ```

3. **Apply Baseline**
   ```bash
   roosync_config(action: "apply", version: "1.0.0", targets: ["modes", "mcp"])
   python scripts/roo-settings/roo-settings-manager.py inject -i roo-config/baselines/myia-ai-01-settings-baseline.json
   ```

4. **Re-Extract and Verify**
   ```bash
   python scripts/roo-settings/roo-settings-manager.py extract -o post-apply-state.json
   ```

5. **Compare with Baseline**
   ```bash
   python scripts/roo-settings/roo-settings-manager.py diff -r roo-config/baselines/myia-ai-01-settings-baseline.json
   ```

### Expected Result

- ✅ Application completes within 10 minutes
- ✅ Post-apply state matches baseline
- ✅ Zero drifts detected

### Pass Criteria

```
Machine reset at T=00:00
Baseline applied at T=00:05
Comparison at T=00:10

Result: Convergence achieved
Remaining diffs: 0
Status: PASS
```

### Status
🟡 **READY TO DESIGN** (requires identifying test machine/environment)

---

## Test Execution Timeline

| Scenario | Status | Target Date | Blocker |
|----------|--------|-------------|---------|
| A: Drift Detection | 🟡 Ready | 2026-03-01 | None - can execute now |
| B: Round-Trip | 🔴 Blocked | 2026-03-02 | Phase 1 on 3+ machines |
| C: Machine Reset | 🟡 Ready | 2026-03-02 | Test environment |

---

## Validation Report Template

For each scenario, document:

```markdown
## Scenario [A/B/C] Validation Report

**Date:** YYYY-MM-DD
**Executor:** machine-name
**Status:** PASS / FAIL

### Setup
[Document what was configured]

### Execution
[Step-by-step what happened]

### Results
[Actual outcome vs expected]

### Evidence
[Logs, diffs, screenshots if applicable]

### Pass/Fail Rationale
[Why it passes or fails]

### Time Taken
[Duration of test]
```

---

## Regression Tests

Once Scenario A passes, establish baseline acceptance criteria:

1. **Settings Extraction Reliability**
   - Extract on same machine 5 times
   - Verify all 5 extractions are identical

2. **GDrive Round-Trip Reliability**
   - Publish to GDrive
   - Download from GDrive
   - Verify bitwise identical

3. **Comparison Consistency**
   - Compare same baselines 3 times
   - Verify same diffs detected each time (no false positives/negatives)

---

## Known Limitations

### Settings Extraction
- Excludes 22 machine-specific keys (expected)
- Does not capture keyboard shortcuts, custom rules, or workspace-specific settings
- Safe keys only (defined in roo-settings-manager.py)

### MCP Configuration
- Captures server definitions
- Does not capture transient state (instance IDs, task history)
- May have differences due to GDrive versioning

### Drift Detection
- System-level diffs (hostname, OS, uptime) are expected and normal
- Per-machine paths will differ (expected)
- Critical drifts are limited to application config (condensation, modes, MCP settings)

---

## Success Criteria (For Issue Closure)

- ✅ Phase 1: All 6 machines extract and publish baseline
- ✅ Phase 2: Full comparison shows only expected machine-level drifts
- ✅ Phase 3: All CRITICAL drifts fixed
- ✅ Phase 4: Official v3.0.0 baseline created
- ✅ Scenario A: Drift detection works (CRITICAL drifts detected within 5 min)
- ✅ Scenario B: Round-trip correction works (3 machines converge)
- ✅ Scenario C: Machine reset converges within 10 min

---

**Report Status:** In Progress
**Last Updated:** 2026-03-01
**Next Review:** 2026-03-02 (after Phase 1 completion on other machines)

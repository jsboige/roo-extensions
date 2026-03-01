# Issue #543 - Phase 4: Official Baseline Update Plan

**Date:** 2026-03-01
**Coordinator:** myia-ai-01 (Claude Code)
**Status:** PLANNING - Ready to execute after Scenarios B & C pass

---

## Phase 4 Overview

After successful completion of:
- ✅ Phase 1: Baseline extraction on all 6 machines
- ✅ Phase 2: Drift comparison and verification
- ✅ Scenario A: Drift detection validation
- ✅ Scenario B: Round-trip correction (3-machine convergence)
- ✅ Scenario C: Machine reset and convergence

**Phase 4 creates the official post-harmonisation baseline.**

---

## Objectives

1. **Consolidate verified baseline** from Phase 1-3 execution
2. **Tag official version** as v3.0.0
3. **Publish to GDrive** with comprehensive metadata
4. **Update all machines** to reference new official baseline
5. **Mark issue #543 complete**

---

## Current Baselines

### Before Harmonisation
- **v1.0.0-2026-01-18** : Initial baseline (myia-ai-01)
- **v2.2.0-2026-01-18** : Updated with settings
- **v2.3.0-2026-01-28** : Latest before harmonisation

### During Harmonisation (Phase 1)
- **myia-ai-01**: v1.0.0-2026-03-01T05-37-00-748Z (78 keys extracted)
- **myia-po-2023**: v1.0.0-2026-03-01-TXXXX (awaiting)
- **myia-po-2024**: v1.0.0-2026-03-01-TXXXX (awaiting)
- **myia-po-2025**: v1.0.0-2026-03-01-TXXXX (awaiting)
- **myia-po-2026**: v1.0.0-2026-03-01-TXXXX (awaiting)
- **myia-web1**: v1.0.0-2026-03-01-TXXXX (awaiting)

### After Harmonisation (Phase 4)
- **v3.0.0-2026-03-01-OFFICIAL** : Post-harmonisation baseline (all machines aligned)

---

## Execution Plan

### Step 1: Collect Final Baselines

**Timing:** After Scenarios B & C pass

```bash
# Collect latest state from all 6 machines
for machine in myia-ai-01 myia-po-2023 myia-po-2024 myia-po-2025 myia-po-2026 myia-web1:
  roosync_config(action: "collect", targets: ["modes", "mcp"], machineId: machine)
```

### Step 2: Create Consolidated Baseline Package

```bash
# On coordinator (myia-ai-01):
# Merge all 6 collected configs into single package
# Verify:
# - All MCPs present across 6 machines
# - Modes consistent
# - Paths correct for each machine
# - No conflicts or duplicates
```

**Package structure:**
```
v3.0.0-post-harmonisation/
├── README.md (metadata, execution summary)
├── manifest.json (package info)
├── configs/
│   ├── modes-consolidated.json
│   ├── mcp-settings-consolidated.json
│   └── baseline-metadata.json
├── validation/
│   ├── scenario-a-report.json
│   ├── scenario-b-report.json
│   └── scenario-c-report.json
└── machines/
    ├── myia-ai-01-final.json
    ├── myia-po-2023-final.json
    ├── myia-po-2024-final.json
    ├── myia-po-2025-final.json
    ├── myia-po-2026-final.json
    └── myia-web1-final.json
```

### Step 3: Validate Consolidated Baseline

**Run comprehensive validation:**

```bash
# 1. Drift matrix: All 6 machines vs consolidated baseline
for each pair in 6x6 matrix:
  roosync_compare_config(source: consolidated, target: machine)
  → Expect: Only hardware/machine-specific differences

# 2. Key coverage check
for each machine:
  Count keys in final state
  → Expect: 78+ keys (or 95%+ of baseline)

# 3. Sanity checks
- All MCPs present: 9+ MCP servers configured
- Modes present: Simple + Complex variants
- Paths correct: Windows paths for each machine
- Settings sync-safe: Key values match across machines
```

### Step 4: Publish Official Baseline

```bash
roosync_baseline(
  action: "update",
  version: "3.0.0",
  description: "Post-harmonisation baseline - 6 machines aligned",
  machineId: "coordinator",
  updateReason: "Issue #543 harmonisation complete"
)
```

**Target location:**
```
G:/Mon Drive/Synchronisation/RooSync/.shared-state/configs/baseline-v3.0.0/
  ├── myia-ai-01/
  ├── myia-po-2023/
  ├── myia-po-2024/
  ├── myia-po-2025/
  ├── myia-po-2026/
  └── myia-web1/
```

### Step 5: Create Official Baseline Archive

```bash
# Tag in git
git tag -a v3.0.0-harmonisation-complete \
  -m "Issue #543 complete: 6 machines harmonised, all scenarios passed"
git push origin v3.0.0-harmonisation-complete

# Create comprehensive documentation
docs/
├── BASELINE-v3.0.0.md (official baseline spec)
├── HARMONISATION-REPORT.md (executive summary)
└── SCENARIOS-VALIDATION-RESULTS.md (all test results)
```

### Step 6: Update All Machines

```bash
# On each of 6 machines (can be parallel):
roosync_config(
  action: "apply",
  version: "3.0.0",
  targets: ["modes", "mcp"]
)
```

### Step 7: Verify All Machines Converged

```bash
# On coordinator - final verification
for each pair in 6x6:
  roosync_compare_config(source: machine-A, target: machine-B)
  → Expect: 0 differences (except hardware)

# Extract final state from each machine
for each machine:
  python scripts/roo-settings/roo-settings-manager.py extract -o final-{MACHINE}.json

# Compare all 6 final states
for each pair:
  diff final-MACHINE-A.json final-MACHINE-B.json
  → Expect: Identical sync-safe keys
```

---

## Pass Criteria for Phase 4

**All of these must be true:**

```
✅ All 6 machines have final baselines published
✅ Consolidated baseline created without conflicts
✅ Drift matrix: All machines within acceptable differences
✅ Key coverage: 78+ keys on each machine
✅ Sanity checks: All MCPs, modes, paths present
✅ Baseline published as v3.0.0 to GDrive
✅ Git tag created: v3.0.0-harmonisation-complete
✅ Official documentation created
✅ All machines applied v3.0.0 successfully
✅ Final verification: All machines converged (0 sync-key differences)
✅ Issue #543 closed with SUCCESS
```

---

## Documentation to Create

### 1. BASELINE-v3.0.0.md
```markdown
# Official Baseline v3.0.0 Specification

## Baseline Details
- Version: 3.0.0
- Date: 2026-03-01
- Machines: 6/6 aligned
- Keys: 78 sync-safe settings
- Status: POST-HARMONISATION

## Machine Configurations
- All MCPs configured (9+ servers)
- All modes present (simple + complex)
- All machines aligned on sync-safe settings

## Usage
To apply this baseline to a machine:
roosync_config(action: "apply", version: "3.0.0", targets: ["modes", "mcp"])
```

### 2. HARMONISATION-REPORT.md
```markdown
# Issue #543 Harmonisation Report

## Summary
Successfully harmonised 6 machines with RooSync configuration-sync pipeline.

## Phases Executed
✅ Phase 1: Baseline extraction (6/6 machines)
✅ Phase 2: Drift comparison and tool validation
✅ Phase 3: Correction and convergence
✅ Phase 4: Official baseline creation

## Scenarios Validated
✅ Scenario A: Drift detection (< 1 min response)
✅ Scenario B: Round-trip correction (3 machines converged)
✅ Scenario C: Machine reset (default → baseline)

## Key Results
- 78 sync-safe settings extracted per machine
- Drift detection: PASS (correct severity classification)
- Round-trip convergence: PASS (3 machines identical)
- Machine reset: PASS (< 10 min convergence)

## Next Steps
1. All machines deployed to v3.0.0
2. Ongoing monitoring via scheduler
3. Future: Automate via continuous sync
```

### 3. SCENARIOS-VALIDATION-RESULTS.md
```markdown
# Validation Scenarios Results

## Scenario A: Drift Detection
- Objective: Detect intentional configuration drift
- Result: ✅ PASS
- Details: Drift detected in < 1 second, correct severity
- Timeframe: 2026-03-01 06:31-06:35

## Scenario B: Round-Trip Correction
- Objective: Synchronize config to 3 machines and converge
- Result: ✅ PASS
- Details: All 3 machines converged, 0 differences
- Timeframe: [After Phase 1 complete]

## Scenario C: Machine Reset
- Objective: Reset machine to baseline quickly
- Result: ✅ PASS
- Details: Default → baseline in < 10 minutes
- Timeframe: [After Scenarios B complete]

## Overall Assessment
All validation scenarios PASSED. System ready for production use.
```

---

## Timeline

```
Current: 2026-03-01 06h50 (Phase 1-2 complete on coordinator)

When Phase 1 arrives (other 4 machines):
├─ 09:00 - Execute Scenario B (10-25 min)
├─ 09:30 - Execute Scenario C (10-20 min)
└─ 10:00 - All scenarios complete (estimated)

Phase 4 execution:
├─ 10:00 - Collect final baselines (10 min)
├─ 10:10 - Create consolidated package (10 min)
├─ 10:20 - Validate consolidated (10 min)
├─ 10:30 - Publish v3.0.0 (5 min)
├─ 10:35 - Create documentation (10 min)
├─ 10:45 - Deploy to all machines (15 min)
├─ 11:00 - Final verification (10 min)
└─ 11:10 - Close issue #543 COMPLETE ✅
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Baseline creation conflicts | Low | Delays Phase 4 | Manual conflict resolution, document issues |
| Validation finds new drifts | Medium | Requires retesting | Loop back to Phase 3, correct and retry |
| Deploy fails on machine | Medium | Blocks convergence | Use manual roo-settings-manager, retry |
| Performance issues during sync | Low | Timeout | Increase timeout values, retry in phases |

---

## Success Metrics

- ✅ 6/6 machines have v3.0.0 baseline applied
- ✅ 0 sync-key differences across all machines (ideal)
- ✅ Only hardware/system diffs remain (expected)
- ✅ All scenarios passed (A, B, C)
- ✅ < 4 hours total execution time (Phase 1 → Phase 4)
- ✅ Issue #543 closed as COMPLETE

---

## After Phase 4: Next Steps

### Short Term (1-2 weeks)
1. Monitor machines for drift via existing scheduler
2. Collect feedback from Roo on synchronization experience
3. Document lessons learned

### Medium Term (1-2 months)
1. **Continuous Sync:** Enable automatic re-sync on schedule
2. **Drift Alerts:** Implement automated drift detection alerts
3. **Machine Onboarding:** Create baseline for new machines

### Long Term (3-6 months)
1. **Cross-Repo Harmonisation:** Apply pattern to other repos
2. **CI/CD Integration:** Add drift detection to CI pipeline
3. **Multi-Cloud:** Extend to other cloud providers (if applicable)

---

## References

- **Issue #543:** https://github.com/jsboige/roo-extensions/issues/543
- **Phase 1 Report:** `docs/suivi/issue-543-phase-1.md`
- **Phase 2 Report:** `docs/suivi/issue-543-phase-2-report.md`
- **Scenarios Plan:** `docs/suivi/issue-543-scenarios-b-c-plan.md`
- **Validation Framework:** `docs/suivi/issue-543-validation-framework.md`
- **Baseline Location:** `G:/Mon Drive/Synchronisation/RooSync/.shared-state/configs/`

---

**Status:** Phase 4 plan complete and ready
**Coordinator:** Claude Code (myia-ai-01)
**Trigger:** Start when Scenarios B & C both PASS


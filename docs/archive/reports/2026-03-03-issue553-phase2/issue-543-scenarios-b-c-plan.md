# Issue #543 - Scenarios B & C Execution Plan

**Date:** 2026-03-01
**Coordinator:** myia-ai-01 (Claude Code)
**Status:** PLANNING - Awaiting Phase 1 completion

---

## Current Status

- ✅ **Phase 1:** myia-ai-01 baseline extracted and published
- ✅ **Phase 2:** Drift comparison tool validated
- ✅ **Scenario A:** Drift detection working correctly
- ⏳ **Phase 1 (other machines):** Awaiting baselines from 4 machines
- 🔴 **Scenarios B & C:** Blocked until Phase 1 complete

---

## Scenario B: Round-Trip Correction Validation

### Objective
Verify that configuration can be synchronized from baseline to multiple machines and maintain convergence.

### Prerequisites Checklist
- [ ] Phase 1 complete on at least 3 machines
- [ ] All 3 target machines have published baselines to GDrive
- [ ] Machines can receive `roosync_config(action: "apply")`

### Execution Steps

#### Step 1: Prepare Corrected Baseline
```
# On coordinator (myia-ai-01):
1. Select source baseline: myia-ai-01 v1.0.0-2026-03-01T05-37-00-748Z
2. Create "corrected" version
3. Publish as v1.0.0-corrected
```

#### Step 2: Select 3 Target Machines
```
Target machines (as Phase 1 baselines arrive):
- Machine A: myia-po-2024 (first to respond)
- Machine B: myia-po-2025 (second to respond)
- Machine C: myia-po-2026 (third to respond)
```

#### Step 3: Apply Configuration on 3 Machines
```
# On each target machine:
roosync_config(action: "apply", version: "1.0.0-corrected", targets: ["modes", "mcp"])
```

#### Step 4: Re-Extract Settings
```
# On each target machine after apply:
python scripts/roo-settings/roo-settings-manager.py extract -o post-correction-{MACHINE}.json
```

#### Step 5: Verify Convergence
```
# On coordinator - run comparisons:
roosync_compare_config(source: "machine-A", target: "machine-B", granularity: "full")
roosync_compare_config(source: "machine-B", target: "machine-C", granularity: "full")
roosync_compare_config(source: "machine-A", target: "machine-C", granularity: "full")

# Expected: 0 differences in sync-safe keys
```

### Pass Criteria for Scenario B

**All of these must be true:**

```
✅ Apply succeeded on all 3 machines (no errors)
✅ Re-extraction completed on all 3 machines
✅ Settings extracted (78 keys each)
✅ Comparison A vs B: Only hardware differences (memory, uptime)
✅ Comparison B vs C: Only hardware differences
✅ Comparison A vs C: Only hardware differences
✅ All sync-safe settings identical across 3 machines
✅ Total time: < 15 minutes for full round-trip
```

### Contingency: If Apply Fails

**If `roosync_config(action: "apply")` fails on a machine:**
1. Check RooSync inbox for error details
2. Verify machines have sufficient disk space
3. Try manual correction using `roo-settings-manager.py set` for critical keys
4. Document failure and continue with remaining machines

---

## Scenario C: Machine Reset and Convergence

### Objective
Verify that a machine with default/minimal configuration can converge to baseline quickly.

### Prerequisites
- Phase 1 complete on at least 1 additional machine
- Baseline published for that machine

### Setup Phase

#### Step 1: Create Test Machine State
```
Option A (Simulator - Preferred):
- Create backup of current config
- Manually set 1-2 critical settings to defaults
- Simulate minimal state

Option B (Full Reset - If available):
- Use a fresh machine/VM
- Minimal OS setup only
- VS Code with Roo but no configuration
```

#### Step 2: Extract Default State
```
python scripts/roo-settings/roo-settings-manager.py extract -o default-state-{MACHINE}.json
```

**Expected result:**
- Much fewer keys (maybe 20-30 instead of 78)
- Minimal configuration

### Execution Phase

#### Step 3: Apply Baseline Configuration
```
roosync_config(action: "apply", version: "latest", targets: ["modes", "mcp"])
```

#### Step 4: Monitor Convergence
```
# Immediately after apply:
- Check that new files were created
- Check that paths are correctly populated
- Check that MCPs are configured

# After restart (if needed):
python scripts/roo-settings/roo-settings-manager.py extract -o post-convergence-{MACHINE}.json
```

#### Step 5: Verify Final State
```
# On coordinator:
roosync_compare_config(
  source: "baseline-machine",
  target: "reset-machine",
  granularity: "full"
)
```

### Pass Criteria for Scenario C

**All of these must be true:**

```
✅ Default state extracted (fewer keys, minimal config)
✅ Apply completed without errors
✅ Post-convergence state has 78 keys (or ~95% of baseline)
✅ Comparison shows only hardware differences
✅ All sync-safe settings match baseline
✅ Machine operational (Roo can start, modes available)
✅ Convergence time: < 10 minutes from default to production baseline
```

### Contingency: If Apply Creates Errors

**If new errors appear after apply:**
1. Compare default state vs baseline diff to identify missing values
2. Use `roo-settings-manager.py set` to manually populate critical keys
3. Verify Roo restarts successfully
4. Re-extract and compare again
5. Document which keys required manual intervention

---

## Timeline and Dependencies

```
NOW (2026-03-01 06h50)
├─ Phase 1 responses arriving (4 machines)
│
├─ WHEN: First 3 Phase 1 baselines arrive
│  └─ START: Scenario B execution
│     ├─ Step 1-2: 5 min (prepare + select machines)
│     ├─ Step 3: 10 min (apply across 3 machines)
│     ├─ Step 4: 5 min (re-extract)
│     └─ Step 5: 5 min (verification) = ~25 min total
│
├─ AFTER Scenario B PASS
│  └─ START: Scenario C execution
│     └─ Total time: ~10-20 minutes
│
└─ AFTER ALL SCENARIOS PASS
   └─ Phase 4: Update baseline v3.0.0
```

---

## Monitoring Strategy

### Real-time Monitoring
1. **Check RooSync inbox** every 5 minutes for:
   - Phase 1 completion messages from other machines
   - Any error reports

2. **Monitor GDrive** for:
   - New v1.0.0-2026-03-01* directories under each machine folder

3. **Watch git log** for:
   - Any new commits from other machines (Phase 1 results)

### Trigger Conditions for Scenario B
```
When BOTH conditions met:
✅ At least 3 Phase 1 baselines published to GDrive
✅ At least 3 RooSync confirmations received

→ Immediately start Scenario B
```

### Trigger Conditions for Scenario C
```
When ALL conditions met:
✅ Scenario B PASSED
✅ At least 1 additional Phase 1 baseline available
✅ Test machine/VM prepared

→ Immediately start Scenario C
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Apply fails on machine | Medium | Blocks round-trip | Manual correction via roo-settings-manager |
| Phase 1 baselines arrive slowly | Medium | Delays B&C | Continue monitoring, proceed when 3 available |
| Convergence incomplete | Low | Retry with debug | Compare diffs to identify missing keys |
| Hardware differences interfere | Low | False positive | Filter out system/hardware keys |

---

## Success Metrics

**Scenario B Success:**
- 3 machines converge to identical sync-safe settings
- 0 differences in application configuration
- < 15 minutes for full round-trip

**Scenario C Success:**
- Default machine reaches 95%+ of baseline key coverage
- Operational convergence in < 10 minutes
- No manual intervention required (ideal)

---

## Documentation Requirements

After each scenario completion:

1. **Execution Report**
   - Steps executed with timestamps
   - Results and pass/fail status
   - Any deviations from plan

2. **Lessons Learned**
   - What worked well
   - What needs improvement
   - Recommendations for Phase 4

3. **GitHub Update**
   - Comment on issue #543 with results
   - Update checklist in issue body

---

## Post-Scenario Actions

### If Both B & C PASS:
```
→ Phase 4 Execution
→ Update baseline to v3.0.0
→ Mark issue #543 as COMPLETE
```

### If Either B or C FAILS:
```
→ Root cause analysis
→ Fix identified issues
→ Retry failed scenario
→ Document findings
```

---

## References

- **Validation Framework:** `docs/suivi/issue-543-validation-framework.md`
- **Phase 2 Report:** `docs/suivi/issue-543-phase-2-report.md`
- **Scenario A Report:** `docs/suivi/issue-543-scenario-a-report.md`
- **Issue:** https://github.com/jsboige/roo-extensions/issues/543
- **GDrive Baselines:** `G:/Mon Drive/Synchronisation/RooSync/.shared-state/configs/`

---

**Status:** Planning complete, ready to execute when Phase 1 baselines arrive
**Coordinator:** Claude Code (myia-ai-01)
**Next Check:** Monitor RooSync inbox for Phase 1 responses


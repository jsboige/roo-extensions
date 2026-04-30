# Profile-to-Modes Workflow — Phase 1 Design

**Issue:** #537 (Phase 1)
**Author:** Claude Code (myia-po-2024)
**Date:** 2026-04-30
**Status:** Draft

---

## 1. Executive Summary

The profile-to-modes workflow allows propagating model configuration changes (e.g., vLLM migration, provider switch) across all 6 machines in the RooSync cluster. Investigation reveals that **the local pipeline is already fully implemented** in the TypeScript MCP tooling. The remaining gap is **cross-machine automation** — triggering profile application on all machines when a profile is updated on the coordinator.

### Key Finding

`roosync_config(action: "apply_profile")` already implements the complete local pipeline:
1. Load profile from `model-configs.json` (local or remote via GDrive)
2. Update `modeApiConfigs` in `model-configs.json`
3. Run `generate-modes.js --profile "..." --deploy` to regenerate `.roomodes`
4. JSON round-trip validation

**What's missing:** Automated cross-machine propagation + secret resolution + post-apply validation.

---

## 2. Current Architecture

### 2.1 Config Files

| File | Location | Purpose |
|------|----------|---------|
| `model-configs.json` | `roo-config/` | Profiles, apiConfigs, modeApiConfigs, thresholds |
| `modes-config.json` | `roo-config/modes/` | Mode families (code, debug, architect, ask, orchestrator) x 2 levels |
| `mode-instructions.md` | `roo-config/modes/templates/commons/` | Template with `{{VARS}}` for custom instructions |
| `.roomodes` | Project root | Generated output consumed by Roo Code |
| `roo-api-configs.json` | `roo-config/generated/` | VS Code import format for API configs |

### 2.2 Profile Structure (model-configs.json)

```json
{
  "profiles": [{
    "name": "Production (Qwen 3.5 local + GLM-5.1 cloud)",
    "description": "...",
    "modeOverrides": {
      "code-simple": "simple",
      "code-complex": "default",
      ...
    }
  }],
  "apiConfigs": {
    "simple": { "openAiBaseUrl": "...", "openAiModelId": "qwen3.6-35b-a3b", ... },
    "default": { "openAiBaseUrl": "...", "openAiModelId": "glm-5.1", ... },
    ...
  },
  "modeApiConfigs": { "code-simple": "simple", ... },
  "profileThresholds": { "simple": 80, "default": 80 }
}
```

**Note (skepticism correction):** The vLLM migration `glm-4.7-flash → qwen3.5-35b-a3b` cited in #537 body is obsolete. Cluster is already on `qwen3.6-35b-a3b` (verified in model-configs.json).

### 2.3 Pipeline Components

| Component | Type | Status |
|-----------|------|--------|
| `generate-modes.js --profile` | Node.js script | Working. Applies modeOverrides, generates .roomodes |
| `generate-modes.js --deploy` | Node.js script | Working. Copies output to project root .roomodes |
| `generate-modes.js --format yaml` | Node.js script | Working. For Roo 3.51.1+ global deploy |
| `ConfigSharingService.applyProfile()` | TS MCP service | Working. Full local pipeline |
| `roosync_config(action: "apply_profile")` | MCP tool | Working. Calls applyProfile() |
| `roosync_config(action: "apply_profile", sourceMachineId: "...")` | MCP tool | Working. Loads profile from remote machine's published config |
| `sync-api-configs.js` | Node.js script | Working. Generates VS Code import format |
| `Deploy-Modes.ps1 -ApiProfile -SyncApiConfigs` | PowerShell | Working. Local + global deployment |
| `Check-ModeApiConfigsDrift.ps1` | PowerShell | Working. Detects config drift |

### 2.4 Current Workflow (Manual)

```
1. [ai-01] Update model-configs.json with new model/profile
2. [ai-01] git add + commit + push
3. [each machine] git pull
4. [each machine] Run: roosync_config(action: "apply_profile", profileName: "Production...")
   OR: node roo-config/scripts/generate-modes.js --profile "Production..." --deploy
5. [each machine] Restart VS Code (for global modes) or reload workspace
```

Steps 3-5 must be repeated on EACH of the 6 machines manually.

---

## 3. Gap Analysis

### 3.1 Cross-Machine Propagation (CRITICAL)

**Problem:** No automated way to trigger `apply_profile` on all machines when a profile changes.

**Options:**

| Option | Pros | Cons |
|--------|------|------|
| **A. RooSync dispatch** | Reuses existing infrastructure | Requires coordinator scheduler tick |
| **B. GDrive watch + auto-apply** | Fully automatic | Complex, fragile |
| **C. Git hook (post-merge)** | Triggers on `git pull` | model-configs.json is in main repo, not submodule |

**Recommended: Option A** — Add a `deploy_profile` dispatch type to the coordinator scheduler. When the coordinator detects a profile change (via git diff or manual trigger), it sends a RooSync message to all machines with the profile name. Each machine's Roo scheduler picks up the message and runs `apply_profile`.

### 3.2 Secret Resolution (IMPORTANT)

**Problem:** `model-configs.json` contains `{{SECRET:openAiApiKey}}` tokens. The TS pipeline passes these through verbatim to `apiConfigs`. Roo Code resolves them at runtime from its own secret store. However, the `sync-api-configs.js` script replaces them with `{{YOUR_API_KEY_HERE}}` — requiring manual entry.

**Current behavior:**
- `generate-modes.js` → `.roomodes` → contains `apiConfigId: "simple"` (reference, not inline key)
- Roo Code resolves `apiConfigId` → reads the corresponding apiConfig from its settings → uses the stored key
- No secret is written to `.roomodes` (correct behavior)

**Gap:** When deploying to a NEW machine, the apiConfig with the API key must be imported into Roo Code settings. The `sync-api-configs.js` script generates the import file but replaces `{{SECRET:...}}` with a placeholder.

**Proposal:** Extend `roosync_config(action: "apply_profile")` to also invoke `Sync-ApiConfigs.ps1` or equivalent, which reads secrets from RooSync GDrive shared state and injects them into the Roo Code settings.

### 3.3 Validation Post-Apply (MODERATE)

**Problem:** After applying a profile, there's no automated verification that the modes are actually using the correct model.

**Proposal:** Add a `--validate` step to `applyProfile()`:
1. Read the deployed `.roomodes`
2. Check each mode's `apiConfigId` matches the profile's `modeOverrides`
3. Compare `currentApiConfigName` in Roo's `state.vscdb` against expected
4. Report any mismatches

### 3.4 Git Integration (MODERATE)

**Problem:** `model-configs.json` is tracked in git. Local profile application modifies it (adds a note with timestamp). This creates uncommitted changes on every machine.

**Proposal:** Either:
- A. Move the "applied on DATE" notes to a separate gitignored file
- B. Accept the local modification (already in .gitignore for `.roomodes`)
- C. Apply profiles without modifying the source config (only generate + deploy)

**Recommended: Option C** — `applyProfile()` should update the live Roo settings (via `state.vscdb` or equivalent) rather than modifying `model-configs.json`. The generated `.roomodes` is already gitignored.

---

## 4. Phase 1 Implementation Plan

### 4.1 Scope

Phase 1 focuses on **cross-machine automated propagation** — the single most impactful gap.

### 4.2 Components

#### 4.2.1 Profile Dispatch Message Format

```typescript
// RooSync message sent by coordinator
{
  action: "send",
  to: "all",
  subject: "[DEPLOY_PROFILE] Production (Qwen 3.5 local + GLM-5.1 cloud)",
  body: "Profile updated: qwen3.6-35b-a3b → qwen3.7-35b-a3b. Apply with: roosync_config(action='apply_profile', profileName='Production...')",
  priority: "HIGH",
  tags: ["DEPLOY_PROFILE", "config-change"]
}
```

#### 4.2.2 Scheduler Handler (Roo side)

Add to `.roo/schedules.json` a profile deployment handler:
1. Check RooSync inbox for `DEPLOY_PROFILE` messages
2. Run `roosync_config(action: "apply_profile", profileName: "...")`
3. Report success/failure on dashboard

#### 4.2.3 Coordinator Trigger (ai-01 side)

Add to the coordinator cycle:
1. `git diff HEAD~1 -- roo-config/model-configs.json` — detect profile changes
2. If changed, send `DEPLOY_PROFILE` message to all machines
3. Monitor dashboard for [DONE] confirmations

### 4.3 Files to Modify

| File | Change | Effort |
|------|--------|--------|
| `.roo/schedules.template.json` | Add profile deployment handler | 1h |
| `.roo/rules/` | Add rule for DEPLOY_PROFILE messages | 0.5h |
| `docs/harness/coordinator-specific/scheduled-coordinator.md` | Document profile dispatch step | 0.5h |
| `ConfigSharingService.applyProfile()` | Add `--validate` option | 1h |

### 4.4 Out of Scope (Later Phases)

- Secret resolution pipeline (Phase 2)
- Automated drift detection and correction (Phase 4)
- Health check monitoring (Phase 3)
- Cross-workspace deployment (Phase 5)

---

## 5. Existing Test Coverage

| Test File | Coverage |
|-----------|----------|
| `apply-profile.test.ts` | Schema validation, mock service calls |
| `config.integration.test.ts` | End-to-end collect/publish/apply cycle |
| `config.test.ts` | Schema validation for all actions |

**Gap:** No integration test for cross-machine `apply_profile` (loading from remote sourceMachineId and generating .roomodes).

---

## 6. Risks

| Risk | Mitigation |
|------|------------|
| Race condition: multiple machines applying profile simultaneously | Each machine applies independently to local config — no shared write target |
| Profile name mismatch between machines | `applyProfile()` validates profile exists before applying |
| generate-modes.js not found on some machines | Already handled — `applyProfile()` logs warning and continues |
| VS Code restart required after deployment | Document in handler instructions |

---

## 7. Acceptance Criteria

Phase 1 is complete when:
1. A coordinator dispatch can trigger `apply_profile` on all machines
2. Each machine applies the profile and generates `.roomodes` successfully
3. Dashboard reports confirm deployment on all 6 machines
4. Drift detection (`roosync_compare_config`) shows no config divergence

---

*Design by Claude Code (myia-po-2024), 2026-04-30. Issue #537 Phase 1.*

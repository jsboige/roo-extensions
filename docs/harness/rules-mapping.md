# Rules Mapping - Roo vs Claude Code Harness

**Version:** 2.0.0
**Created:** 2026-03-16
**Updated:** 2026-03-28
**Issue:** #721 - Ventilation correcte des règles entre harnais Roo et Claude, #922 - Fix phantom references

---

## Overview

This document maps the equivalence between Roo (`.roo/rules/`) and Claude Code (`.claude/rules/`) rules to ensure consistency across the dual-harness architecture.

**Key Principle:** Both harnesses serve the same project but have different capabilities and constraints. Rules should be aligned where possible, with harness-specific adaptations where needed.

---

## Direct Equivalences

**Note:** Verified against actual files in `.roo/rules/` and `.claude/rules/` + `.claude/docs/` (2026-03-28).

**Important:** Claude has 2 tiers of rules:
- **Auto-loaded** (`.claude/rules/`): 15 files, loaded every conversation
- **On-demand** (`.claude/docs/`): 17 files, consulted when relevant

| Roo Rule | Claude Equivalent | Location | Status | Notes |
|----------|-------------------|----------|--------|-------|
| `01-general.md` | (implicit in CLAUDE.md) | — | ✅ Aligned | General behavior guidelines |
| `02-intercom.md` | `intercom-protocol.md` | rules/ | ✅ Aligned | INTERCOM / dashboard protocol |
| `03-mcp-usage.md` | `mcp-discoverability.md` | docs/reference/ | ✅ Aligned | MCP usage & discoverability |
| `04-sddd-grounding.md` | `sddd-conversational-grounding.md` | rules/ | ✅ Aligned (Claude > Roo) | Triple grounding — Claude version more complete |
| `05-tool-availability.md` | `tool-availability.md` | rules/ | ✅ Aligned (Claude > Roo) | STOP & REPAIR protocol |
| `06-context-window.md` | `context-window.md` | rules/ | ✅ Aligned | GLM 80% threshold (auto-loaded rule) |
| `07-orchestrator-delegation.md` | (in CLAUDE.md sections) | — | ⚠️ Roo-specific | Claude has no orchestrator modes |
| `08-file-writing.md` | `file-writing.md` | rules/ | ⚠️ Different | Roo: write_to_file >200L; Claude: Edit/Write patterns |
| `09-github-checklists.md` | `github-checklists.md` | docs/ | ✅ Aligned | GitHub checklist discipline (on-demand) |
| `10-ci-guardrails.md` | `ci-guardrails.md` | rules/ | ✅ Aligned v2.0.0 | CI validation before push (#923) |
| `11-incident-history.md` | `incident-history.md` | docs/reference/ | ✅ Aligned | Incident documentation (on-demand) |
| `12-machine-constraints.md` | `myia-web1-constraints.md` | docs/machine-specific/ | ⚠️ Partial | Roo: all machines; Claude: web1 only (on-demand) |
| `13-test-success-rates.md` | `test-success-rates.md` | rules/ | ✅ Aligned | Expected test success rates (#720) |
| `14-tdd-recommended.md` | N/A | — | ❌ Roo-only | TDD-first approach specific to Roo |
| `15-coordinator-responsibilities.md` | `scheduled-coordinator.md` | docs/coordinator-specific/ | ✅ Aligned | Coordinator tier protocol (on-demand) |
| `16-no-tools-warnings.md` | N/A | — | ❌ Roo-only | Roo UI-specific |
| `17-friction-protocol.md` | `friction-protocol.md` | docs/ | ✅ Aligned | Friction reporting (on-demand) |
| `18-meta-analysis.md` | `meta-analysis.md` | docs/reference/ | ✅ Aligned | Meta-analyst tier (on-demand) |
| `19-github-cli.md` | `github-cli.md` | rules/ | ✅ Identical | GitHub CLI and GraphQL |
| `19-pr-mandatory.md` | `pr-mandatory.md` | rules/ | ✅ Aligned | PR mandatory workflow |
| `20-skepticism-protocol.md` | `skepticism-protocol.md` | rules/ | ✅ Aligned v2.0.0 | Anti-propagation (#924) |
| `21-validation.md` | `validation.md` | rules/ | ✅ Aligned | Validation rules |
| `22-no-deletion-without-proof.md` | `no-deletion-without-proof.md` | rules/ | ✅ Aligned | Anti-destruction rule |

---

## Claude-Only Rules & Docs (no Roo equivalent)

### Auto-loaded rules (`.claude/rules/`)

| Rule | Purpose | Reason |
|------|---------|--------|
| `agents-architecture.md` | Sub-agent definitions | Claude Code has native Agent tool |
| `delegation.md` | Sub-agent delegation rules | Claude-specific (sub-agent API) |
| `context-window.md` | GLM 80% condensation threshold | Auto-loaded (Roo equivalent: `06-context-window.md`) |
| `worktree-cleanup.md` | Git worktree cleanup protocol | Claude uses worktrees for PRs |

### On-demand docs (`.claude/docs/`)

| Doc | Purpose | Reason |
|-----|---------|--------|
| `condensation-thresholds.md` | Detailed condensation reference | Complements `context-window.md` rule |
| `escalation-protocol.md` | 5-level escalation ladder | Claude-specific escalation tiers |
| `feedback-process.md` | Improvement proposal workflow | Merged into Roo's general workflow |
| `reference/bash-fallback.md` | Bash tool failure mitigation | Roo uses win-cli MCP instead |
| `reference/roo-schedulable-criteria.md` | Label application criteria | Claude assigns tasks to Roo |
| `reference/scheduler-densification.md` | Scheduler cycle filling | Roo equivalent in workflow files |
| `reference/scheduler-system.md` | Roo scheduler architecture reference | Claude describes it, Roo IS it |
| `reference/stub-detection.md` | Anti-stub CI detection | Claude-specific CI gate |
| `coordinator-specific/pr-review-policy.md` | PR review workflow | Claude handles PRs, Roo delegates |
| `worktree-cleanup-protocol.md` | Worktree cleanup details | Complements `worktree-cleanup.md` rule |

---

## Roo-Only Rules (no Claude equivalent)

| Rule | Purpose | Reason |
|------|---------|--------|
| `01-general.md` | General Roo behavior | Claude equivalent implicit in CLAUDE.md |
| `03-mcp-usage.md` | MCP usage rules for Roo modes | Claude uses native MCP differently |
| `07-orchestrator-delegation.md` | Orchestrator mode constraints | Claude doesn't have orchestrator modes |
| `14-tdd-recommended.md` | TDD-first approach | Roo-specific task execution recommendation |
| `16-no-tools-warnings.md` | Tool availability warnings | Roo UI-specific behavior |

---

## Key Differences by Category

### 1. Communication

| Aspect | Roo | Claude |
|--------|-----|--------|
| **Local (INTERCOM)** | File-based via `apply_diff` or `Add-Content` | `Edit` tool with append |
| **Cross-machine (RooSync)** | File-based in `.shared-state/messages/` | MCP tools `roosync_send/read/manage` |
| **Meta-INTERCOM** | Separate file per machine | Same file, same protocol |

### 2. Shell Access

| Aspect | Roo | Claude |
|--------|-----|--------|
| **Modes -simple** | win-cli MCP only (no native terminal) | Native `Bash` tool always available |
| **Modes -complex** | Native terminal + win-cli | Native `Bash` tool |
| **Orchestrators** | No tools at all (`groups: []`) | N/A (no orchestrator modes) |

### 3. MCP Configuration

| Aspect | Roo | Claude |
|--------|-----|--------|
| **Config location** | `%APPDATA%/.../mcp_settings.json` (GLOBAL) | `~/.claude.json` section `mcpServers` |
| **Project overrides** | `.roo/mcp.json` | (same file as global) |
| **Critical MCPs** | win-cli (required for shell) | roo-state-manager (required for coordination) |

### 4. Scheduler Architecture

| Aspect | Roo | Claude |
|--------|-----|--------|
| **Extension** | `kylehoskins.roo-scheduler` | `schtasks` (Windows Task Scheduler) |
| **Config file** | `.roo/schedules.json` | Scripts in `scripts/scheduling/` |
| **Interval** | 3h (configurable) | 8h coordinator, 3h executor |
| **Escalation** | `orchestrator-simple` → `orchestrator-complex` | N/A |

### 5. Validation

| Aspect | Roo | Claude |
|--------|-----|--------|
| **Pre-commit** | Workflow checks | `validation.md` |
| **CI validation** | N/A (doesn't push) | `ci-guardrails.md` mandatory |
| **Test command** | `npx vitest run` | `npx vitest run` (same) |

---

## Alignment Recommendations

### High Priority

1. **INTERCOM Protocol** - Both harnesses use identical format and append-at-end rule
2. **Validation Checklist** - Critical for consolidation tasks, must be identical
3. **Testing Command** - `npx vitest run` mandatory for both
4. **SDDD Grounding** - Triple grounding methodology identical
5. **Friction Protocol** - Same reporting mechanism via RooSync

### Medium Priority

1. **Context Thresholds** - GLM 70% threshold applies to both
2. **Meta-Analysis** - Same 72h cycle, same META-INTERCOM protocol
3. **Coordinator Protocol** - Same responsibilities on ai-01
4. **Scheduler Densification** - Same sweet spot for escalation

### Low Priority (Harness-Specific)

1. **Tool Availability** - Different critical MCPs per harness
2. **Orchestrator Delegation** - Roo-only concept
3. **PR Review Policy** - Claude-only (Roo doesn't create PRs directly)
4. **Machine Constraints** - Different resource profiles

---

## Cross-Reference Table

### Communication Protocols

```
Roo INTERCOM          ←→  Claude intercom-protocol.md
Roo roosync-messaging ←→  Claude MCP roosync_* tools
Roo META-INTERCOM     ←→  Claude META-INTERCOM (same file)
```

### Validation & Testing

```
Roo testing.md        ←→  Claude test-success-rates.md (merged)
Roo validation-*.md   ←→  Claude validation*.md (identical)
Roo skepticism-*.md   ←→  Claude skepticism-protocol.md (identical)
```

### Scheduling & Coordination

```
Roo scheduler-system.md        ←→  Claude scheduler-system.md
Roo scheduler-densification.md ←→  Claude scheduler-densification.md
Roo scheduled-coordinator.md   ←→  Claude scheduled-coordinator.md
Roo meta-analysis.md           ←→  Claude meta-analysis.md
```

### GitHub Integration

```
Roo github-cli.md     ←→  Claude github-cli.md (identical)
(none)                ←→  Claude github-checklists.md (Claude-only)
(none)                ←→  Claude pr-review-policy.md (Claude-only)
```

---

## Maintenance Guidelines

### When Adding a New Rule

1. **Check both harnesses** - Does the rule apply to both?
2. **Create in both locations** - If applicable to both, create in `.roo/rules/` AND `.claude/rules/`
3. **Document differences** - If harness-specific, document why in this mapping
4. **Update this file** - Add entry to appropriate table above

### When Modifying an Existing Rule

1. **Sync both versions** - If rule exists in both, update both
2. **Preserve harness-specifics** - Keep differences (e.g., MCP config paths)
3. **Update mapping** - Note any status changes

### When Removing a Rule

1. **Check for dependencies** - Other rules may reference it
2. **Remove from both** - If exists in both, remove from both
3. **Update mapping** - Remove entry or mark as deprecated

---

## Statistics

| Category | Count |
|----------|-------|
| **Total Roo Rules** | 22 |
| **Total Claude Auto-loaded Rules** | 15 |
| **Total Claude On-demand Docs** | 17 |
| **Direct Equivalences** | 17 |
| **Claude-Only (rules + docs)** | 14 |
| **Roo-Only Rules** | 5 |
| **Alignment Rate** | 77% |

---

## References

- **Issue #721**: Ventilation correcte des règles entre harnais
- **Roo Rules**: `.roo/rules/`
- **Claude Rules**: `.claude/rules/`
- **Project Config**: `CLAUDE.md` (Claude), `.roomodes` + `modes-config.json` (Roo)

---

**Last Updated:** 2026-03-28
**Maintainer:** RooSync Multi-Agent System

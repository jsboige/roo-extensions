# Rules Mapping - Roo vs Claude Code Harness

**Version:** 1.2.0
**Created:** 2026-03-16
**Updated:** 2026-03-17
**Issue:** #721 - Ventilation correcte des règles entre harnais Roo et Claude

---

## Overview

This document maps the equivalence between Roo (`.roo/rules/`) and Claude Code (`.claude/rules/`) rules to ensure consistency across the dual-harness architecture.

**Key Principle:** Both harnesses serve the same project but have different capabilities and constraints. Rules should be aligned where possible, with harness-specific adaptations where needed.

---

## Direct Equivalences

**Note:** Verified against actual files in `.roo/rules/` and `.claude/rules/` (2026-03-17).

| Roo Rule | Claude Rule | Status | Notes |
|----------|-------------|--------|-------|
| `01-general.md` | (implicit in CLAUDE.md) | ✅ Aligned | General behavior guidelines |
| `02-intercom.md` | `intercom-protocol.md` | ✅ Aligned | INTERCOM protocol (local communication) |
| `03-mcp-usage.md` | `mcp-discoverability.md` | ✅ Aligned | MCP usage & discoverability rules |
| `04-sddd-grounding.md` | `sddd-conversational-grounding.md` | ✅ Aligned (Claude > Roo) | Triple grounding methodology — Claude version (381L) is more complete |
| `05-tool-availability.md` | `tool-availability.md` | ✅ Aligned (Claude > Roo) | STOP & REPAIR protocol — Claude version more complete |
| `06-context-window.md` | `condensation-thresholds.md` | ✅ Aligned | GLM 70% threshold guidance |
| `07-orchestrator-delegation.md` | (in CLAUDE.md sections) | ⚠️ Roo-specific | Claude has no orchestrator modes; delegation described differently |
| `08-file-writing.md` | N/A | ❌ Roo-only | Specific to Roo/Qwen `write_to_file` >200 lines limitation |
| `09-github-checklists.md` | `github-checklists.md` | ✅ Aligned | GitHub checklist discipline |
| `10-ci-guardrails.md` | `ci-guardrails.md` | ✅ Identical | CI validation before push |
| `11-incident-history.md` | `incident-history.md` | ✅ Aligned | Incident documentation |
| `12-machine-constraints.md` | `myia-web1-constraints.md` | ⚠️ Partial | Roo documents all machines; Claude only web1 |
| `13-test-success-rates.md` | `test-success-rates.md` | ✅ Aligned | Expected test success rates by machine (#720) |
| `14-tdd-recommended.md` | N/A | ❌ Roo-only | TDD-first approach specific to Roo task execution |
| `15-coordinator-responsibilities.md` | `scheduled-coordinator.md` | ✅ Aligned | Coordinator tier protocol |
| `16-no-tools-warnings.md` | N/A | ❌ Roo-only | Specific to Roo tool availability warnings in UI |
| `17-friction-protocol.md` | `friction-protocol.md` | ✅ Aligned | Friction reporting protocol |
| `18-meta-analysis.md` | `meta-analysis.md` | ✅ Aligned | Meta-analyst tier protocol |
| `github-cli.md` | `github-cli.md` | ✅ Identical | GitHub CLI commands and GraphQL |
| `skepticism-protocol.md` | `skepticism-protocol.md` | ✅ Identical | Anti-propagation of errors |
| `testing.md` | `test-success-rates.md` | ✅ Aligned | Test commands + success rates (Claude's `testing.md` merged into `test-success-rates.md`) |
| `validation.md` | `validation.md` | ✅ Aligned | Validation rules |

---

## Claude-Only Rules (no Roo equivalent)

| Rule | Purpose | Reason |
|------|---------|--------|
| `agents-architecture.md` | Sub-agent definitions | Claude Code has native Agent tool |
| `bash-fallback.md` | Bash tool failure mitigation | Roo uses win-cli MCP instead |
| `ci-guardrails.md` | CI validation before push | Roo schedulers don't push to submodule |
| `condensation-thresholds.md` | GLM context window thresholds | (Roo equivalent: `06-context-window.md`) |
| `delegation.md` | Sub-agent delegation rules | Claude-specific (sub-agent API) |
| `feedback-process.md` | Improvement proposal workflow | Merged into Roo's general workflow |
| `intercom-protocol.md` | INTERCOM append rules | (Roo equivalent: `02-intercom.md`) |
| `myia-web1-constraints.md` | Machine-specific RAM constraints | Roo's `12-machine-constraints.md` covers all machines |
| `pr-review-policy.md` | PR review workflow | Claude handles PRs, Roo delegates |
| `roo-schedulable-criteria.md` | Label application criteria | Claude assigns tasks to Roo |
| `scheduled-coordinator.md` | Coordinator tier protocol | (Roo equivalent: `15-coordinator-responsibilities.md`) |
| `scheduler-densification.md` | Scheduler cycle filling | (Roo equivalent in workflow files) |
| `scheduler-system.md` | Roo scheduler architecture reference | Claude describes it, Roo IS it |
| ~~`validation-checklist.md`~~ | ~~Merged into `validation.md`~~ | Deleted 2026-03-17 (superseded by `validation.md` #724) |

---

## Roo-Only Rules (no Claude equivalent)

| Rule | Purpose | Reason |
|------|---------|--------|
| `07-orchestrator-delegation.md` | Orchestrator mode constraints | Claude doesn't have orchestrator modes |
| `08-file-writing.md` | Roo `write_to_file` limitations (>200 lines) | Specific to Roo/Qwen write_to_file behavior |
| `14-tdd-recommended.md` | TDD-first approach in task execution | Roo-specific task execution recommendation |
| `16-no-tools-warnings.md` | Tool availability warnings in Roo UI | Roo UI-specific behavior |

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
| **Total Claude Rules** | 24 |
| **Direct Equivalences** | 18 |
| **Claude-Only Rules** | 7 |
| **Roo-Only Rules** | 3 |
| **Alignment Rate** | 82% |

---

## References

- **Issue #721**: Ventilation correcte des règles entre harnais
- **Roo Rules**: `.roo/rules/`
- **Claude Rules**: `.claude/rules/`
- **Project Config**: `CLAUDE.md` (Claude), `.roomodes` + `modes-config.json` (Roo)

---

**Last Updated:** 2026-03-17
**Maintainer:** RooSync Multi-Agent System

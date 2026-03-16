# Rules Mapping - Roo vs Claude Code Harness

**Version:** 1.0.0
**Created:** 2026-03-16
**Issue:** #721 - Ventilation correcte des règles entre harnais Roo et Claude

---

## Overview

This document maps the equivalence between Roo (`.roo/rules/`) and Claude Code (`.claude/rules/`) rules to ensure consistency across the dual-harness architecture.

**Key Principle:** Both harnesses serve the same project but have different capabilities and constraints. Rules should be aligned where possible, with harness-specific adaptations where needed.

---

## Direct Equivalences

| Roo Rule | Claude Rule | Status | Notes |
|----------|-------------|--------|-------|
| `01-general.md` | (implicit in CLAUDE.md) | ✅ Aligned | General behavior guidelines |
| `02-intercom.md` | `intercom-protocol.md` | ✅ Aligned | INTERCOM protocol (local communication) |
| `03-roosync-messaging.md` | (via MCP tools) | ⚠️ Different | Roo uses file-based, Claude uses MCP `roosync_*` |
| `04-delegation.md` | `delegation.md` | ✅ Aligned | Sub-agent delegation rules |
| `05-testing.md` | `testing.md` | ✅ Aligned | Test commands (`npx vitest run`) |
| `06-sddd-protocols.md` | `sddd-conversational-grounding.md` | ✅ Aligned | Triple grounding methodology |
| `07-orchestrator-delegation.md` | (in CLAUDE.md) | ⚠️ Partial | Claude doesn't have orchestrator modes |
| `08-context-window.md` | `condensation-thresholds.md` | ✅ Aligned | Context management thresholds |
| `09-validation-checklist.md` | `validation.md`, `validation-checklist.md` | ✅ Aligned | Mandatory validation checklist |
| `10-tool-discoverability.md` | `mcp-discoverability.md` | ✅ Aligned | MCP testing protocols |
| `11-incident-history.md` | `incident-history.md` | ✅ Aligned | Incident documentation |
| `12-feedback-process.md` | `feedback-process.md` | ✅ Aligned | Improvement proposal workflow |
| `13-scheduled-coordinator.md` | `scheduled-coordinator.md` | ✅ Aligned | Coordinator tier protocol |
| `14-meta-analysis.md` | `meta-analysis.md` | ✅ Aligned | Meta-analyst tier protocol |
| `15-scheduler-densification.md` | `scheduler-densification.md` | ✅ Aligned | Filling scheduler cycles |
| `16-scheduler-system.md` | `scheduler-system.md` | ✅ Aligned | Roo scheduler architecture |
| `17-friction-protocol.md` | `friction-protocol.md` | ✅ Aligned | Friction reporting protocol |
| `18-meta-analysis-actions.md` | (merged into meta-analysis.md) | ⚠️ Consolidated | Actions merged into main doc |
| `testing.md` | `testing.md` | ✅ Aligned | Identical content |
| `validation-checklist.md` | `validation-checklist.md` | ✅ Aligned | Identical content |
| `skepticism-protocol.md` | `skepticism-protocol.md` | ✅ Aligned | Identical content |
| `github-cli.md` | `github-cli.md` | ✅ Aligned | Identical content |
| `context-window.md` | `condensation-thresholds.md` | ✅ Aligned | Same GLM threshold guidance |

---

## Claude-Only Rules (no Roo equivalent)

| Rule | Purpose | Reason |
|------|---------|--------|
| `agents-architecture.md` | Sub-agent definitions | Claude Code has native Agent tool |
| `bash-fallback.md` | Bash tool failure mitigation | Roo uses win-cli MCP instead |
| `ci-guardrails.md` | CI validation before push | Roo schedulers don't push to submodule |
| `github-checklists.md` | GitHub issue checklists | Enhanced tracking for Claude sessions |
| `myia-web1-constraints.md` | Machine-specific RAM constraints | Claude has different resource profile |
| `pr-review-policy.md` | PR review workflow | Claude handles PRs, Roo delegates |
| `roo-schedulable-criteria.md` | Label application criteria | Claude assigns tasks to Roo |
| `tool-availability.md` | STOP & REPAIR protocol | Enhanced for Claude's MCP config separation |

---

## Roo-Only Rules (no Claude equivalent)

| Rule | Purpose | Reason |
|------|---------|--------|
| `03-roosync-messaging.md` | File-based RooSync messaging | Claude uses MCP tools directly |
| `07-orchestrator-delegation.md` | Orchestrator mode constraints | Claude doesn't have orchestrator modes |
| `18-meta-analysis-actions.md` | Meta-analysis action types | Merged into Claude's meta-analysis.md |

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
| **Pre-commit** | Workflow checks | `validation.md` + `validation-checklist.md` |
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
Roo testing.md        ←→  Claude testing.md (identical)
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
| **Total Claude Rules** | 23 |
| **Direct Equivalences** | 18 |
| **Claude-Only Rules** | 8 |
| **Roo-Only Rules** | 3 |
| **Alignment Rate** | 82% |

---

## References

- **Issue #721**: Ventilation correcte des règles entre harnais
- **Roo Rules**: `.roo/rules/`
- **Claude Rules**: `.claude/rules/`
- **Project Config**: `CLAUDE.md` (Claude), `.roomodes` + `modes-config.json` (Roo)

---

**Last Updated:** 2026-03-16
**Maintainer:** RooSync Multi-Agent System

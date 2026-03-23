# Condensation Thresholds - Context Management

**Version:** 1.0.0
**Created:** 2026-03-23
**Issues:** #502 (boucle) + #555 (saturation) + #736 (boucle po-2023) + #737 (instabilité)

---

## Context

This rule documents the critical **80% condensation threshold** for GLM-5 models via z.ai provider.

**IMPORTANT:** This threshold applies specifically when:
- Claude Code uses `/switch-provider` to use GLM-5 (z.ai)
- INTERCOM file is shared between Roo and Claude (threshold applies to both agents)

**Default Claude models (Opus/Sonnet)** have their own context management and are not affected by this rule.

---

## CRITICAL Configuration

### Condensation Threshold: 80% (NOT 50%, NOT 70%, NOT 90%)

| Threshold | Effect | Problem |
|-----------|--------|---------|
| 50% | Compaction to ~65k | **Too early** → infinite loop (#502) |
| 70% | Compaction to ~92k | Loop with heavy harness (#736) |
| **80%** | **Compaction to ~105k** | **Optimal** → 26k margin |
| 90% | Compaction to ~118k | Too late, saturation risk (#555) |

### GLM-5 Context Window: 131k tokens (NOT 200k)

The **actual GLM context window is 131k tokens**, NOT 200k.

The 200k advertised includes output tokens. Available input context is limited to ~131k.

---

## Why 80%? (Historical Incidents)

| Incident | Threshold | Problem | Resolution |
|----------|-----------|---------|------------|
| **#502** | 50% | Infinite condensation loop | Raised to 80% |
| **#736** | 70% | Loop on po-2023 with heavy harness | Raised to 80% |
| **#555** | 90%+ | Context saturation | Lowered to 80% |
| **#737** | Variable | Recurrent scheduler instability | Fixed at 80% |

**Evolution:** Threshold evolved from 70% → 80% after incident #736 (2026-03-18).
With reduced auto-loaded harness (24→10 rules, ~65K→~35K tokens), 80% provides optimal balance.

---

## Verification at Session Start

When starting a session, Claude Code should:

1. **Check INTERCOM size**: If INTERCOM > 600 lines (~12k tokens), condense FIRST before reading fully
2. **Verify threshold**: Ensure GLM-5 condensation threshold is at 80% (when using z.ai)
3. **Report loops**: If condensation loop occurs, report in INTERCOM immediately

---

## INTERCOM Condensation Protocol

### Threshold: 500 lines (not 600 for Roo)

Claude Code INTERCOM has a **500-line threshold** (lower than Roo's 600-line threshold).

### When to condense

- **IMMEDIATELY** when INTERCOM exceeds 500 lines
- Archive older messages (keep ~100 recent messages)
- Archive location: `.claude/local/archive/INTERCOM-{MACHINE}-archive-{DATE}.md`

### Condensation format

```markdown
## [YYYY-MM-DD HH:MM:SS] claude-code -> roo [CONDENSATION]

INTERCOM condensed: {X} → {Y} lines
Archived: {Z} lines ({date range})
Archive: {archive file path}

---
```

---

## Configuration GLM-5 (via /switch-provider)

When using `/switch-provider` to enable GLM-5 (z.ai):

**Required settings:**
- Condensation threshold: **80%**
- Context window size: **131072** (131k)
- Provider: z.ai

**Danger zones:**
- Threshold ≤ 50% with INTERCOM > 800 lines = **infinite loop**
- Threshold 70% with heavy harness (~65K tokens) = **loop**

---

## References

- **#502**: Infinite condensation loop (threshold too low = 50%)
- **#555**: GLM-5 context saturation (threshold too high = 90%+)
- **#736**: po-2023 condensation loop (70% insufficient with heavy harness)
- **#737**: Recurrent scheduler instability (root cause investigation)
- `.roo/rules/06-context-window.md`: Roo version (complete reference)
- Issue #806: This adaptation for Claude Code

---

**Last updated:** 2026-03-23

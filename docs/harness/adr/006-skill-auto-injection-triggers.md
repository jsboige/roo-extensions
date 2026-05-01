# ADR 006: Skill Auto-Injection with Triggers

**Status:** Proposed (Phase 1 design)
**Date:** 2026-04-30
**Issue:** #1854
**EPIC:** #1864 (Cycle 26 Harness Consolidation)
**Source pattern:** oh-my-claudecode evaluation (#1802)
**Deciders:** jsboige, myia-po-2026 (design)

---

## Context

Our RooSync skills system requires manual invocation via slash commands (`/git-sync`, `/validate`, `/sync-tour`). Users and agents must know the exact command name to invoke a skill. This creates friction:

- Users type natural language ("synchronise le repo") instead of slash commands
- Scheduled agents (executor cycle) waste time on manual skill detection
- Skills already embed "Phrase déclencheuse" in their descriptions, but Claude's matching is unreliable
- OMC (oh-my-claudecode) uses trigger-based auto-injection — a proven pattern (#1802 evaluation)

Claude Code provides `UserPromptSubmit` hooks that fire before processing user input. Hook output is injected into the conversation as additional context. This enables deterministic skill matching without modifying Claude Code itself.

## Decision

Add a `triggers` field to SKILL.md YAML frontmatter and implement auto-injection via a `UserPromptSubmit` hook.

### 1. Trigger Format

Extend SKILL.md frontmatter with a `triggers` object:

```yaml
---
name: git-sync
description: Synchronisation Git...
triggers:
  keywords:
    - "git sync"
    - "synchronise"
    - "pull"
    - "mets à jour le repo"
  priority: normal
---
```

**Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `keywords` | string[] | Yes | Phrases to match in user input (case-insensitive substring) |
| `priority` | enum | No | `high` (always suggest), `normal` (default), `low` (only if exact match) |

**Design choices:**

- **Keywords over regex:** Simpler to maintain, less error-prone, sufficient for natural language matching. Regex can be added in Phase 2 if needed.
- **Substring matching:** "synchronise" matches "synchronise le repo". More flexible than exact matching.
- **Case-insensitive:** User input varies in casing.
- **Priority field:** Allows fine-tuning which skills get suggested when multiple match. `high` = always surface (safety-critical like validate), `normal` = standard, `low` = only surface on near-exact match.

### 2. Detection Mechanism

A `UserPromptSubmit` hook runs a PowerShell script that:

1. Reads JSON input from stdin (`prompt` field = user's message)
2. Discovers all skill files (project `.claude/skills/` then global `~/.claude/skills/`)
3. Parses YAML frontmatter for `triggers.keywords`
4. Matches user prompt against keywords (case-insensitive substring)
5. Outputs matching skill names to stdout (injected as conversation context)

**Hook configuration** (`.claude/settings.json` project or `~/.claude/settings.json` global):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File scripts/claude/skill-trigger-detector.ps1",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Output format:**

If trigger matches:
```
[SKILL-TRIGGER] User input matches skill "git-sync". Invoke /git-sync for the relevant workflow.
```

If multiple matches:
```
[SKILL-TRIGGER] Multiple skills matched:
  - "git-sync" (keyword: "synchronise") → /git-sync
  - "validate" (keyword: "lance les tests") → /validate
```

If no match: no output (hook returns exit code 0 silently).

### 3. Priority & Override Rules

| Rule | Behavior |
|------|----------|
| **Project overrides global** | If both `~/.claude/skills/validate/SKILL.md` and `.claude/skills/validate/SKILL.md` have triggers, project wins |
| **First keyword match** | If multiple skills match, all are reported, sorted by `priority` (high > normal > low) |
| **Triggers are additive** | Skills without `triggers` field are ignored by the detector — manual `/skill-name` still works |
| **Non-blocking** | Hook output is a suggestion, not a command. Claude decides whether to invoke the skill |

### 4. Compatibility

| Scenario | Behavior |
|----------|----------|
| Skill without `triggers` | Ignored by detector, manual invocation works |
| Skill with empty `triggers.keywords` | Treated as no triggers |
| Hook not configured | System works exactly as before (no auto-injection) |
| Multiple keywords match same skill | Reported once |
| User types `/skill-name` directly | Skill invoked normally, hook does not interfere |

### 5. Scope by Phase

| Phase | Scope | Status |
|-------|-------|--------|
| **Phase 1** (this ADR) | Design + prototype 1 skill + detector script | Proposed |
| Phase 2 | Add triggers to all 9 project skills + 5 global skills | Future |
| Phase 3 | `/learner` skill for pattern extraction from conversations | Done (PR #1906) |

## Consequences

### Positive

- **Deterministic matching:** Hook-based detection is reliable (no LLM hallucination)
- **Low cost:** ~1s execution time, no API calls, pure string matching
- **Backward compatible:** No changes to existing skill format (additive field)
- **Observable:** Hook output visible in conversation for debugging
- **Extensible:** Priority field, regex patterns can be added later

### Negative

- **Configuration required:** Hook must be added to settings.json (deployment step)
- **Keyword maintenance:** Triggers must be kept in sync with skill descriptions
- **False positives:** Substring matching may trigger on unrelated input (e.g., "pull" in "pull request review")
- **No LLM understanding:** Cannot detect intent, only keywords. Regex helps but isn't semantic.

### Mitigations

- **False positives:** Multi-word keywords preferred over single words. `priority: low` for ambiguous triggers.
- **Deployment:** Script is self-contained, documented in hook config. Can be bundled into `roosync_config(action: "apply")`.
- **Maintenance:** Triggers live alongside skill content in the same file — natural co-location.

## Alternatives Considered

### A. MCP-based detection (roo-state-manager tool)

Add a `skill_match` tool to roo-state-manager that Claude calls at the start of each turn.

**Rejected:** Adds latency (MCP round-trip), requires Claude to remember to call the tool, couples skill system to MCP server.

### B. Skill frontmatter `auto` field with Claude-native matching

Rely entirely on Claude's built-in skill matching with improved descriptions.

**Rejected:** Unreliable. Claude's matching depends on model capability and context load. We already have "Phrase déclencheuse" in descriptions and it's insufficient.

### C. Regex-only triggers

Use regex patterns instead of keywords.

**Deferred to Phase 2:** Regex is more powerful but harder to maintain. Keywords cover 80% of use cases. Can be added as `triggers.patterns` field later.

## References

- Issue #1854 — Skill auto-injection
- Issue #1802 — OMC evaluation (source pattern)
- Issue #1368 — Claude Code skills analysis
- [oh-my-claudecode Skills](https://github.com/Yeachan-Heo/oh-my-claudecode#custom-skills)
- `.claude/skills/` — Existing skill definitions
- Claude Code hooks documentation — `UserPromptSubmit` hook type

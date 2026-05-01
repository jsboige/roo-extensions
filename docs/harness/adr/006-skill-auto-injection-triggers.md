# ADR 006: Skill Auto-Injection with Triggers

**Status:** Implemented (Phase 2 — extended trigger types)
**Date:** 2026-04-30 (Phase 1), 2026-05-01 (Phase 2 parser)
**Issue:** #1854
**EPIC:** #1864 (Cycle 26 Harness Consolidation)
**Source pattern:** oh-my-claudecode evaluation (#1802)
**Deciders:** jsboige, myia-po-2026 (design + implementation)

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

Extend SKILL.md frontmatter with a `triggers` object supporting 4 trigger types:

```yaml
---
name: validate
description: Valide que le code compile et que les tests passent.
triggers:
  keywords:
    - "valide"
    - "lance les tests"
    - "vérifie le build"
    - "CI local"
  exact:
    - "build"
    - "tests"
    - "vitest"
    - "tsc"
  patterns:
    - "(lance|run|exécute).{0,10}tests?"
    - "(build|compile).{0,10}(check|verify|valide)"
  context:
    - "executor"
  priority: high
---
```

**Trigger types:**

| Type | Field | Required | Matching | Example |
|------|-------|----------|----------|---------|
| **keywords** | `keywords: []` | No* | Case-insensitive substring | "valide" matches "valide le build" |
| **exact** | `exact: []` | No* | Case-insensitive whole-word | "build" matches "check the build" but not "buildbot" |
| **patterns** | `patterns: []` | No* | Regex (`.match()`) | `(lance\|run).{0,10}tests?` |
| **context** | `context: []` | No* | Session-context match | "executor" when `ROOSYNC_MACHINE_ID` set |

*At least one trigger type must be non-empty for the skill to be detected.

**Priority field:**

| Value | Behavior |
|-------|----------|
| `high` | Always surface (safety-critical: validate) |
| `normal` | Standard matching (default) |
| `low` | Only surface on near-exact match (pr-review, memory-inject) |

**Matching order:** keywords → exact → patterns → context. First match wins per skill.

### 2. Detection Mechanism

A `UserPromptSubmit` hook runs `skill-trigger-detector.ps1` that:

1. Reads JSON input from stdin (`prompt` field = user's message)
2. Discovers all skill files (project `.claude/skills/` then global `~/.claude/skills/`)
3. Parses YAML frontmatter for `triggers` section
4. Matches user prompt against each trigger type in order (keywords → exact → patterns → context)
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
            "command": "pwsh -ExecutionPolicy Bypass -File scripts/claude/skill-trigger-detector.ps1",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Output format:**

Single match:
```
[SKILL-TRIGGER] User input matches skill "validate" (keyword: "valide"). Invoke /validate for the relevant workflow.
```

Multiple matches:
```
[SKILL-TRIGGER] Multiple skills matched:
  - "validate" (keyword: "valide") -> /validate
  - "git-sync" (exact: "pull") -> /git-sync
```

### 3. Priority & Override Rules

| Rule | Behavior |
|------|----------|
| **Project overrides global** | If both `~/.claude/skills/validate/SKILL.md` and `.claude/skills/validate/SKILL.md` have triggers, project wins |
| **First match per skill** | Keywords tested first, then exact, patterns, context. First match reported |
| **Priority sorting** | When multiple skills match, sorted by `priority` (high > normal > low) |
| **Triggers are additive** | Skills without `triggers` field are ignored — manual `/skill-name` still works |
| **Non-blocking** | Hook output is a suggestion, not a command |

### 4. Compatibility

| Scenario | Behavior |
|----------|----------|
| Skill without `triggers` | Ignored by detector, manual invocation works |
| All trigger arrays empty | Treated as no triggers |
| Hook not configured | System works exactly as before |
| Multiple trigger types match same skill | First match type reported (keywords > exact > patterns > context) |
| User types `/skill-name` directly | Hook exits immediately (starts with `/`), skill invoked normally |
| Invalid regex in `patterns` | Skipped silently, other triggers still evaluated |

### 5. Scope by Phase

| Phase | Scope | Status |
|-------|-------|--------|
| **Phase 1** | Design + prototype 1 skill + detector script | Done (PR #1890) |
| **Phase 2** | Extended trigger types (exact/patterns/context) + all 9 skills + refactored parser | Done (this update) |
| Phase 3 | `/learner` pattern extraction from conversations | Done (PR #1906) |

### 6. Skills Coverage (Phase 2)

| Skill | Keywords | Exact | Patterns | Context | Priority |
|-------|----------|-------|----------|---------|----------|
| git-sync | 7 | 0 | 0 | 0 | normal |
| validate | 7 | 4 | 2 | 0 | high |
| sync-tour | 8 | 1 | 1 | 0 | normal |
| github-status | 8 | 1 | 1 | 0 | normal |
| debrief | 7 | 2 | 1 | 0 | normal |
| executor | 3 | 1 | 0 | 1 | normal |
| pr-review | 6 | 1 | 1 | 1 | low |
| memory-inject | 3 | 1 | 1 | 0 | low |
| redistribute-memory | 7 | 1 | 1 | 0 | low |

## Consequences

### Positive

- **Deterministic matching:** Hook-based detection is reliable (no LLM hallucination)
- **Low cost:** ~5ms execution time, no API calls, pure string matching
- **Backward compatible:** No changes to existing skill invocation (additive field)
- **Observable:** Hook output visible in conversation for debugging
- **4 trigger types:** Covers substring, whole-word, regex, and session-context matching
- **9/9 skills covered:** All project skills have structured triggers

### Negative

- **Configuration required:** Hook must be added to settings.json (deployment step)
- **Trigger maintenance:** Triggers must be kept in sync with skill descriptions
- **False positives:** Keywords substring may trigger on unrelated input (e.g., "pull" in "pull request review")
- **No semantic understanding:** Cannot detect intent. Patterns help but aren't semantic.

### Mitigations

- **False positives:** Multi-word keywords preferred. `priority: low` for ambiguous triggers. `exact` type for precise matching.
- **Deployment:** Script is self-contained. Can be bundled into `roosync_config(action: "apply")`.
- **Maintenance:** Triggers live alongside skill content — natural co-location.

## References

- Issue #1854 — Skill auto-injection
- Issue #1802 — OMC evaluation (source pattern)
- Issue #1368 — Claude Code skills analysis
- [oh-my-claudecode Skills](https://github.com/Yeachan-Heo/oh-my-claudecode#custom-skills)
- `scripts/claude/skill-trigger-detector.ps1` — Detector script
- `.claude/skills/*/SKILL.md` — Skill definitions with triggers

# Skill Auto-Injection — Implementation Design

**Status:** Draft
**Date:** 2026-05-01
**Issue:** #1854
**ADR:** 006 (`docs/harness/adr/006-skill-auto-injection-triggers.md`)
**EPIC:** #1864 (Cycle 26 Harness Consolidation)
**Author:** myia-po-2026 (design), jsboige (review)

---

## 1. Overview

This document specifies the implementation design for skill auto-injection. Architectural decisions are documented in [ADR 006](../adr/006-skill-auto-injection-triggers.md) and should be read first.

**What's implemented (Phase 1):**
- ADR 006 — UserPromptSubmit hook, keyword-based triggers, priority system
- `scripts/claude/skill-trigger-detector.ps1` — PowerShell detection script
- `git-sync` skill — 8 trigger keywords, `priority: normal`

**What this document covers:**
- Trigger pattern catalog for all 9 project skills
- Shared trigger format specification (skills + HUD statusline #1855)
- Comparison: manual vs auto invocation
- Risk analysis with quantitative thresholds
- Implementation roadmap (Phase 2 → Phase 3)

---

## 2. Trigger Pattern Catalog

### 2.1 Current Skills — Trigger Inventory

| Skill | Phase 1 Triggers | Proposed Keywords | Priority | Ambiguity Risk |
|-------|-----------------|-------------------|----------|----------------|
| **git-sync** | 8 keywords (done) | git sync, synchronise, pull, submodule update | normal | "pull" in "pull request" |
| **validate** | none | valide, lance les tests, vérifie le build, CI local | high | "valide" is common French word |
| **sync-tour** | none | tour de sync, faire le point, état coordination | normal | low |
| **debrief** | none | débrief, fin de session, documente ce qu'on a fait | normal | low |
| **pr-review** | none | review PRs, idle review, révise les PRs | normal | "review" very common |
| **github-status** | none | github status, état du projet, progression | low | "project" very common |
| **redistribute-memory** | none | redistribue mémoire, audite règles, nettoie CLAUDE.md | normal | low |
| **memory-inject** | auto-inject (no keywords) | — | — | N/A |
| **executor** | none | lance executor, mode executor | normal | low |

### 2.2 Trigger Patterns Analysis

**Pattern A — Direct Command (most reliable)**
Keywords that map 1:1 to a skill intent. Low false positive rate.

```
"lance les tests"     → validate
"tour de sync"        → sync-tour
"fin de session"      → debrief
```

**Pattern B — Intent Keywords (moderate reliability)**
Keywords expressing intent but potentially ambiguous. Require multi-word matching.

```
"vérifie le build"    → validate  (vs "vérifie le status" → github-status)
"synchronise"         → git-sync  (vs "synchronise dashboard" → unrelated)
"review"              → pr-review (vs "code review" → ambiguous)
```

**Pattern C — Contextual Triggers (Phase 3, not yet implemented)**
Triggers based on conversation context rather than keywords.

| Context Signal | Suggested Skill | Implementation |
|---------------|----------------|----------------|
| User just ran `git commit` | validate | `PostToolUse` hook on `Bash` tool |
| User opened `.ts` file | validate | File tracking in hook context |
| Session duration > 30 min | debrief | Time-based trigger in hook |
| Agent reports `[DONE]` | sync-tour | Dashboard event listener |
| User types in French | (all skills) | Language detection |

**Pattern D — Proactive Triggers (Phase 3, statusline integration)**
Triggers from HUD statusline state changes.

| Statusline Event | Suggested Skill | Condition |
|-----------------|----------------|-----------|
| Claims > 3 on machine | pr-review | Machine has capacity |
| Dashboard 80% full | redistribute-memory | Proactive maintenance |
| Agents offline > 2 | github-status | Coordination check |

### 2.3 Keyword Design Rules

1. **Multi-word preferred** — "git sync" over "git", "lance les tests" over "tests"
2. **Min 2 keywords per skill** — At least one unambiguous trigger
3. **Include French variants** — Our users speak French (see validate: "valide", "lance les tests")
4. **Exclude single common words** — "test", "review", "status" alone are too ambiguous
5. **Max 10 keywords per skill** — Beyond 10, false positive rate increases

---

## 3. Shared Trigger Format Specification

### 3.1 Unified YAML Frontmatter Structure

Both skill auto-injection (#1854) and HUD statusline (#1855) share a common trigger format:

```yaml
---
name: {skill_name}
description: {one-line description}
triggers:
  keywords:          # Phase 1 — string matching (skills)
    - "keyword 1"
    - "keyword 2"
  priority: normal   # high | normal | low
  conditions:        # Phase 2+ — state-based triggers (statusline)
    - field: agents_online
      operator: lt
      value: 3
      action: warn
    - field: dashboard_utilization
      operator: gt
      value: 80
      action: suggest
      suggest_skill: redistribute-memory
---
```

### 3.2 Format Versions

| Version | Fields | Consumers |
|---------|--------|-----------|
| v1 (Phase 1) | `keywords`, `priority` | skill-trigger-detector.ps1 |
| v2 (Phase 2) | + `conditions` | statusline harness, proactive triggers |
| v3 (Phase 3) | + `patterns` (regex), `context` | advanced detection |

### 3.3 Statusline Integration

The HUD statusline (#1855) consumes `roosync_get_status(detail: "full")` which returns `hudData`:

```json
{
  "hudData": {
    "activeClaims": [{ "issue": "#1854", "machine": "po-2026" }],
    "activeStages": [{ "stage": "team-exec", "machine": "po-2023" }],
    "onlineAgents": ["ai-01", "po-2023", "po-2024", "po-2026"],
    "statusFlags": { "healthy": true, "warnings": 1 }
  }
}
```

The statusline harness evaluates `conditions` from skill frontmatter against this `hudData` to trigger proactive skill suggestions:

```
if hudData.onlineAgents.length < 3 → suggest github-status
if hudData.activeClaims.length > 3  → suggest pr-review
```

This creates a feedback loop: skills define when they should be suggested, and the statusline evaluates these rules against live state.

---

## 4. Manual vs Auto Invocation Comparison

| Aspect | Manual (`/skill-name`) | Auto (trigger injection) |
|--------|----------------------|-------------------------|
| **Reliability** | 100% — user explicitly invokes | ~85% — depends on keyword matching |
| **Latency** | 0ms — immediate | ~1s — hook script execution |
| **Discoverability** | Requires knowing command | Suggested by context |
| **User control** | Full — user decides | Advisory — user can ignore |
| **Maintenance** | None — slash command is stable | Keywords must be kept in sync |
| **Scheduled agents** | Must hard-code skill names | Natural language triggers work |
| **Multi-language** | Slash command language-agnostic | Keywords must cover all languages |
| **False positives** | 0% | ~5-10% estimated (depends on keyword quality) |
| **Coverage** | All 9 skills | Phase 1: 1 skill, Phase 2: 8 skills |

### When to prefer manual invocation:
- User knows exactly what they want
- In scripts or scheduled tasks
- When precision matters over convenience

### When auto-injection adds value:
- Users typing natural language ("synchronise le repo" instead of `/git-sync`)
- Scheduled agents in executor mode (natural task descriptions)
- New users unfamiliar with available skills
- Multi-step workflows where skill suggestion reduces friction

---

## 5. Risk Analysis

### 5.1 False Positives

**Risk:** Keyword matches unintended input. "pull" triggers git-sync when user types "pull request review".

**Quantitative threshold:** False positive rate must stay below 5% of invocations.

**Mitigations:**
- Multi-word keywords preferred (Rule 2.3)
- `priority: low` for ambiguous skills (github-status, pr-review)
- Detector skips exact slash command input (`/` prefix)
- Users can ignore injected suggestions (non-blocking)

**Measurement:** Add opt-in telemetry to detector script: log keyword + matched skill + whether user invoked the skill. Review monthly.

### 5.2 Double Injection

**Risk:** User types "/git-sync" AND keyword "git sync" is in the prompt. Hook fires, Claude receives both manual and auto trigger.

**Mitigation:** Detector explicitly skips prompts starting with `/` (line 53 of detector script). This is already implemented.

**Edge case:** User types "run git sync for me" — not a slash command, keyword matches. Claude receives trigger suggestion AND may interpret the natural language command. This is acceptable because the suggestion is advisory.

### 5.3 Skill Conflicts

**Risk:** Multiple skills match the same prompt. "synchronise et valide" matches both git-sync and validate.

**Mitigation:** All matches are reported, sorted by priority. Claude decides which to invoke. This is by design — the hook provides context, not commands.

**Threshold:** If a prompt matches >3 skills, the output may be noisy. Add a `max_suggestions` parameter (default: 3) to the detector.

### 5.4 Performance Impact

**Risk:** Hook adds latency to every user prompt.

**Measurement:** Detector script benchmarks at ~5ms for 14 skills (Get-ChildItem + YAML parsing). Acceptable.

**Scaling concern:** If skill count grows to 50+, consider:
- Caching parsed frontmatter (watch skill dirs for changes)
- Pre-compiling keyword index at startup
- Target: <50ms for any skill count

### 5.5 Maintenance Burden

**Risk:** Keywords drift from actual skill behavior over time.

**Mitigation:** Keywords live in SKILL.md alongside the skill content. When a skill is updated, its author naturally sees and updates the keywords. This co-location is the primary maintenance strategy.

---

## 6. Implementation Roadmap

### Phase 1 — Complete (PR #1868 merged)

- [x] ADR 006 design document
- [x] Trigger format specification (YAML frontmatter)
- [x] `skill-trigger-detector.ps1` prototype
- [x] Triggers for git-sync (8 keywords)
- [x] Hook configuration documentation

### Phase 2 — Add Triggers to All Skills

**Scope:** Add `triggers` frontmatter to 7 remaining project skills.

| Skill | Keywords to Add | Priority |
|-------|----------------|----------|
| validate | "valide", "lance les tests", "vérifie le build", "CI local" | high |
| sync-tour | "tour de sync", "faire le point", "état coordination" | normal |
| debrief | "débrief", "fin de session", "documente la session" | normal |
| pr-review | "review PRs", "idle review", "révise les PRs" | low |
| github-status | "github status", "project status", "progression" | low |
| redistribute-memory | "redistribue mémoire", "audite règles", "nettoie CLAUDE.md" | normal |
| executor | "lance executor", "mode executor" | normal |

**Steps:**
1. Add `triggers` block to each SKILL.md frontmatter
2. Test detector with sample prompts for each skill
3. Deploy hook configuration to all executor machines
4. Monitor false positive rate for 1 week

**Estimated effort:** 2-3 hours

### Phase 3 — Advanced Triggers

**Scope:** Context-aware and statusline-driven triggers.

| Feature | Mechanism | Dependency |
|---------|-----------|------------|
| Regex patterns | `triggers.patterns` field in frontmatter | YAML parser upgrade |
| Context triggers | `PostToolUse` hook on Bash tool | Claude Code hooks API |
| Statusline triggers | `conditions` evaluated against `hudData` | #1855 Phase 2 complete |
| `/learner` skill | Pattern extraction from sessions | LLM integration |

**Estimated effort:** 4-6 hours

---

## 7. Testing Strategy

### Unit Tests

- **Detector script:** Test each keyword against sample prompts
- **Priority sorting:** Verify high > normal > low ordering
- **Edge cases:** Empty prompt, slash commands, special characters

### Integration Tests

- **Hook execution:** Configure hook in settings.json, type natural language, verify skill suggestion appears in conversation
- **Multi-skill matching:** Verify all matching skills are reported
- **Override rules:** Project skill triggers override global triggers

### Acceptance Criteria

- [ ] All 8 project skills (excluding memory-inject) have triggers
- [ ] Detector correctly matches ≥95% of test prompts
- [ ] False positive rate ≤5% on test corpus
- [ ] Hook adds <100ms latency to user prompts
- [ ] Works on all 6 machines (PowerShell 7+)

---

## 8. Configuration Template

### Hook Configuration (settings.json)

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

### Skill Frontmatter Template

```yaml
---
name: {skill-name}
description: {description with "Phrase déclencheuse" for manual matching}
triggers:
  keywords:
    - "{keyword 1}"
    - "{keyword 2}"
    - "{keyword 3}"
  priority: normal  # high | normal | low
metadata:
  author: "Roo Extensions Team"
  version: "X.Y.Z"
  compatibility:
    surfaces: ["claude-code", "claude.ai"]
---
```

---

## References

- [ADR 006](../adr/006-skill-auto-injection-triggers.md) — Architectural decisions
- [Issue #1854](https://github.com/jsboige/roo-extensions/issues/1854) — Skill auto-injection
- [Issue #1855](https://github.com/jsboige/roo-extensions/issues/1855) — HUD statusline (shared format)
- [Issue #1802](https://github.com/jsboige/roo-extensions/issues/1802) — OMC evaluation (source pattern)
- `scripts/claude/skill-trigger-detector.ps1` — Detector implementation
- `.claude/skills/` — Skill definitions

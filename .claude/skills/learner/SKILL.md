---
name: learner
description: Extract trigger patterns from conversation history and update SKILL.md files. Analyzes recent sessions to find new keywords that should activate existing skills.
triggers:
  keywords:
    - "apprendre les triggers"
    - "learner"
    - "extract patterns"
    - "analyse les conversations"
  exact:
    - "learn"
  patterns:
    - "(learn|extract|analyz).{0,10}(pattern|trigger|keyword)"
  priority: low
metadata:
  author: "Roo Extensions Team"
  version: "1.0.0"
  compatibility:
    surfaces: ["claude-code"]
    restrictions: "Read-only analysis. Changes require manual approval."
  issue: "#1854"
---

# Skill: Learner — Pattern Extraction from Conversations

**Version:** 1.0.0
**Created:** 2026-05-01
**Issue:** #1854 Phase 3
**ADR:** docs/harness/adr/006-skill-auto-injection-triggers.md

---

## Objective

Analyze recent conversation history to extract trigger patterns — user prompts that should have activated a skill but didn't because the trigger keywords are missing. Suggest additions to existing SKILL.md trigger lists.

**Principle:** The learner NEVER modifies files directly. It proposes changes for human review.

---

## Workflow

### Phase 1: Inventory Current Triggers

Read all SKILL.md files and catalog existing triggers:

```bash
# For each skill in .claude/skills/*/SKILL.md
# Extract: name, triggers.keywords, triggers.exact, triggers.patterns
# Build a map of skill → known triggers
```

Output: Table of all skills with their current trigger counts.

### Phase 2: Analyze Recent Conversations

Use `conversation_browser` to scan recent sessions for skill-invocation patterns:

```
conversation_browser(action: "list", limit: 20, source: "all")
```

For each session:
1. Check `firstUserMessage` for natural language that matches a skill intent
2. Identify sessions where a skill was eventually invoked (via `/skill-name`)
3. Note the original user prompt that preceded the skill invocation

**What to look for:**

| Pattern | Example | Should trigger |
|---------|---------|---------------|
| French commands | "synchronise le repo" | git-sync |
| Informal requests | "fais un tour" | sync-tour |
| Indirect mentions | "le build est cassé" | validate |
| Partial matches | "status des PRs" | github-status |
| Missing synonyms | "nettoyer la mémoire" | redistribute-memory |

### Phase 3: Gap Analysis

Compare user prompts against existing triggers:

1. For each prompt that led to a skill invocation, check if any existing trigger would have matched
2. If no trigger matched → **gap found**
3. Group gaps by skill
4. Score gaps by frequency

**Scoring:**

| Factor | Weight | Description |
|--------|--------|-------------|
| Frequency | 3.0 | How often this prompt pattern appears |
| Specificity | 2.0 | How uniquely it maps to one skill |
| Brevity | 1.0 | Shorter triggers are better (easier to match) |

### Phase 4: Generate Proposals

For each gap with score >= 2.0, propose a new trigger:

```yaml
# Proposed additions for skill "validate"
triggers:
  keywords:
    - "build cassé"      # Found 3 times in sessions #X, #Y, #Z
    - "marche plus"      # Found 2 times in sessions #A, #B
```

**Format per proposal:**

```
### [SKILL-NAME] — N new triggers proposed

| Trigger | Type | Score | Evidence (sessions) |
|---------|------|-------|---------------------|
| "build cassé" | keyword | 5.0 | #session1, #session2, #session3 |
| "marche plus" | keyword | 3.0 | #session3, #session5 |

**Recommendation:** Add as keywords (substring match). No false positives expected.
```

### Phase 5: Present for Approval

Output all proposals as a structured report. The user must approve each addition before any SKILL.md is modified.

```
## Learner Report — YYYY-MM-DD

**Sessions analyzed:** N
**Gaps found:** M
**Proposals:** K

[Proposals table]

To apply: `/learner --apply` or manually edit SKILL.md files.
```

---

## Rules

### Read-Only
- NEVER modify SKILL.md files directly
- NEVER modify any project file
- Output is a report only

### Evidence-Based
- Every proposed trigger MUST cite at least 1 conversation session as evidence
- Triggers without evidence are REJECTED

### No Speculation
- Only analyze REAL conversations from the last 30 days
- Do not invent hypothetical triggers
- Do not add triggers for skills that already have 10+ keywords (diminishing returns)

### Deduplication
- Before proposing, check if the trigger already exists (case-insensitive)
- Before proposing, check if an existing trigger already covers the pattern (substring check)

---

## Scope Limits

| Metric | Limit |
|--------|-------|
| Sessions analyzed | 20 max |
| Proposals per skill | 3 max |
| Total proposals | 10 max |
| Minimum evidence sessions | 1 |
| Maximum trigger length | 30 chars |

---

## Integration with Trigger Detector

Proposed triggers follow the same format as `scripts/claude/skill-trigger-detector.ps1` expects. Once approved and added to SKILL.md, they are automatically picked up by the detector on the next prompt.

---

## Invocation

```bash
# Analyze recent conversations
/learner

# Apply approved proposals (requires confirmation)
# (Future: not implemented in v1.0)
```

---

**Last updated:** 2026-05-01

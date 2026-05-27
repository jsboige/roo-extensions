# ADR 012: sk-agent Multi-Tier PR Reviews

**Date:** 2026-05-27
**Status:** Proposed
**Issue:** #1587
**Related:** ADR 009 (NanoClaw PR reviewer), #1748 (sk-agent calibration), #1853 (team pipeline stages)

## Context

The fleet has two PR review mechanisms:
1. **NanoClaw V2** (ADR 009): GitHub-based cron reviewer using jsboigeEPF identity. Good for mechanical reviews (trivial PRs, pointer bumps). Runs on ai-01.
2. **sk-agent PR conversations** (pr-review-tier1/2/3): Multi-agent conversations within sk-agent MCP. Can do deep analysis with context exploration.

### Problem

- **NanoClaw** lacks deep code understanding (no file reading, no context exploration). It reviews diffs only.
- **sk-agent** has 3 review tiers defined in config but no documented pipeline for when to use each tier.
- The `deep-reviewer` agent mentioned in #1587 is missing from config.
- No integration between NanoClaw (GitHub-native) and sk-agent (MCP-native) review workflows.

### Existing sk-agent Review Tiers

| Tier | Conversation | Agents | LOC Threshold | Description |
|------|-------------|--------|---------------|-------------|
| 1 | pr-review-tier1 | fast-reviewer, review-synthesizer | ≤50 | Fast diff-only review |
| 2 | pr-review-tier2 | integration-reviewer, context-explorer, review-synthesizer-t2 | 51-300 | Context-aware with file reading |
| 3 | pr-review-tier3 | integration-reviewer, context-explorer, regression-hunter, security-executor, review-synthesizer-t3 | >300 | Full deep review with security + regression |

### Missing Agent: deep-reviewer

Issue #1587 mentions a `deep-reviewer` agent that should exist but doesn't. This agent would bridge Tier 2 and Tier 3 for reviews that need deep context but not full security/regression analysis.

## Decision

### 1. Tier Selection Pipeline

```
PR created
  ↓
NanoClaw cron scans PR (every 3h)
  ↓
LOC ≤ 50 + CI green + trivial?
  ├─ YES → NanoClaw auto-approve (existing)
  └─ NO → Determine tier
       ├─ LOC ≤ 50 + non-trivial → sk-agent Tier 1
       ├─ LOC 51-300 → sk-agent Tier 2
       └─ LOC > 300 → sk-agent Tier 3
```

### 2. Tier Selection Criteria

| Criterion | Tier 1 | Tier 2 | Tier 3 |
|-----------|--------|--------|--------|
| LOC changed | ≤50 | 51-300 | >300 |
| Files changed | 1-3 | 3-10 | >10 |
| CI required | green | green | green |
| Security-sensitive? | skip to T3 | skip to T3 | always |
| Config-only? | always T1 | T1 | T1 |
| Submodule pointer? | always T1 | — | — |

### 3. Add `deep-reviewer` Agent

```json
{
  "id": "deep-reviewer",
  "description": "Comprehensive code reviewer combining integration tracing, regression analysis, and maintainability assessment. GLM-5.1 with GitHub tools.",
  "model": "glm-5.1",
  "system_prompt": "You are a comprehensive code reviewer with access to GitHub tools. Combine integration tracing (callers, consumers), regression risk assessment (git history), and maintainability analysis (SOLID, DRY, complexity). Output structured JSON: verdict, confidence, summary, findings[]. Each finding has: severity, category (correctness|security|regression|maintenance), file:line, description, suggestion.",
  "mcps": [],
  "memory": { "enabled": false },
  "parameters": {
    "github_tools": true,
    "github_default_repo": "jsboige/roo-extensions"
  }
}
```

### 4. Integration with NanoClaw

- **NanoClaw** handles GitHub mechanics: PR scanning, approval/comment API, scheduling
- **sk-agent** handles deep analysis: context exploration, regression hunting, security review
- **Bridge**: NanoClaw calls sk-agent via MCP `call_agent` tool when PR needs deep review
- **Fallback**: If sk-agent unavailable, NanoClaw proceeds with diff-only review

### 5. review_pr Implementation

The `review_pr` tool in sk-agent should:
1. Fetch PR diff and metadata via GitHub tools
2. Calculate tier (LOC, files, security flags)
3. Route to appropriate conversation (pr-review-tier1/2/3)
4. Return structured JSON verdict

This requires implementing `review_pr` as a sk-agent tool (currently defined in config but not in `sk_agent.py`).

## Implementation Plan

### Phase 1: Document + Config (this ADR)
- [ ] Add `deep-reviewer` agent to `sk_agent_config.template.json`
- [ ] Document tier selection criteria in pr-review-policy.md
- [ ] Add tier thresholds to config as tunable parameters

### Phase 2: review_pr Tool
- [ ] Implement `review_pr` tool in `sk_agent.py`
- [ ] Add tier selection logic (LOC + file count + security flags)
- [ ] Integrate with existing pr-review-tier1/2/3 conversations
- [ ] Add end-to-end test: mock PR → review_pr → structured output

### Phase 3: NanoClaw Integration
- [ ] Add `call_agent` bridge in NanoClaw config
- [ ] Implement fallback when sk-agent unavailable
- [ ] Track metrics: review quality, false positives, coverage

## Consequences

- **Structured review pipeline:** Clear criteria for when to use each tier
- **Missing agent added:** `deep-reviewer` fills gap between Tier 2 and Tier 3
- **NanoClaw + sk-agent synergy:** GitHub-native scheduling + MCP-native deep analysis
- **Tunable thresholds:** LOC/file count thresholds configurable per repo
- **Risk:** sk-agent review quality depends on model quality (GLM-5.1 vs Claude Opus). Monitor false negative rate.

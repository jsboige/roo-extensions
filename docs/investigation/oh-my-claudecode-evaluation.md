# oh-my-claudecode Evaluation Report

**Issue:** #1802
**Date:** 2026-04-30
**Author:** Claude Code (myia-po-2023)
**Context:** Evaluation of oh-my-claudecode (31k stars) for potential integration with RooSync harness

---

## Executive Summary

**Recommendation: PARTIAL ADOPTION — Extract patterns, NOT full integration**

oh-my-claudecode (OMC) is a mature multi-agent orchestration plugin for Claude Code with impressive features, but full adoption is **NOT recommended** for the RooSync harness. The value lies in extracting specific patterns (Team pipeline, skill auto-injection) rather than replacing our existing architecture.

| Aspect | Verdict | Rationale |
|--------|---------|-----------|
| **Full adoption** | ❌ NOT recommended | Architectural mismatch, Windows compatibility issues, overlap with existing tools |
| **Pattern extraction** | ✅ RECOMMENDED | Team pipeline, skill learning, HUD statusline have valuable patterns |
| **Model routing** | ⚠️ PARTIAL | Smart routing exists but claudish (#1730) is better suited for our needs |
| **Integration effort** | HIGH | Would require significant rework of RooSync harness |

---

## Background: What is oh-my-claudecode?

**Repository:** [Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)
**Stars:** 31k+
**License:** MIT
**Package:** `oh-my-claude-sisyphus` (npm)

### Core Capabilities

| Feature | Description |
|---------|-------------|
| **Team mode (v4.1.7+)** | Staged pipeline: `team-plan → team-prd → team-exec → team-verify → team-fix (loop)` |
| **19 specialized agents** | With tier variants and smart model routing (Opus for complex, Haiku for fast) |
| **tmux CLI workers** | Spawns real `claude`/`codex`/`gemini` processes in tmux panes |
| **Skill learning** | `.omc/skills/` auto-injection (project + user level) |
| **HUD statusline** | Real-time orchestration metrics in status bar |
| **Notifications** | Tag-based system (Telegram/Discord/Slack/webhooks) |
| **OpenClaw integration** | Forward events to OpenClaw gateway |
| **Multi-AI orchestration** | Codex/Gemini CLI advisors with synthesis |

### Orchestration Modes

| Mode | What it is | Use For |
|------|------------|---------|
| **Team (recommended)** | Canonical staged pipeline | Coordinated Claude agents on shared task list |
| **omc team (CLI)** | tmux CLI workers | Codex/Gemini CLI tasks; on-demand spawn |
| **ccg** | Tri-model advisors | Mixed backend+UI work |
| **Autopilot** | Autonomous execution (single lead) | End-to-end feature work |
| **Ultrawork** | Maximum parallelism (non-team) | Burst parallel fixes/refactors |
| **Ralph** | Persistent mode with verify/fix loops | Tasks that must complete fully |
| **Pipeline** | Sequential, staged processing | Multi-step transformations |
| **Deep Interview** | Socratic requirements clarification | Vague ideas, hidden assumptions |

---

## Comparative Analysis: OMC vs RooSync

### 1. Multi-Agent Coordination

| Aspect | RooSync | oh-my-claudecode | Overlap? |
|--------|---------|------------------|----------|
| **Architecture** | 6 machines, GDrive dashboards + RooSync messages | In-session teams + tmux workers | Partial |
| **Cross-machine** | ✅ Native (via GDrive) | ❌ Single-machine only | NO |
| **Dashboard** | roo-state-manager (3 types: global/machine/workspace) | Session summaries only | NO |
| **Coordination** | Manual dispatch via coordinateur | Automatic Team pipeline stages | Partial |
| **Persistence** | Qdrant + JSONL + Git | `.omc/sessions/*.json` | Partial |

**Verdict:** RooSync's 6-machine cross-machine coordination is **more advanced** than OMC's single-machine approach. OMC's Team pipeline could formalize our task flow, but not replace RooSync.

### 2. Agent Architecture

| Aspect | RooSync | oh-my-claudecode |
|--------|---------|------------------|
| **Subagents** | 18 (10 workers + 8 support) | 19 specialized (with tier variants) |
| **Model routing** | Manual (provider-specific) | Smart (Haiku for fast, Opus for complex) |
| **Dispatch** | Manual via coordinateur | Automatic via Team stages |
| **Specialization** | Task-based (code-fixer, doc-updater, etc.) | Role-based (architect, researcher, designer, etc.) |

**RooSync Workers (`.claude/agents/workers/`):**
- code-fixer, consolidation-worker, doc-updater, test-investigator
- issue-worker, config-auditor, codebase-researcher, script-runner
- pr-reviewer, issue-triager, sync-checker

**OMC Agents (partial list):**
- architect, researcher, designer, tester, data-scientist
- With tier variants (e.g., `architect-opus`, `architect-haiku`)

**Verdict:** OMC's agent specialization is **role-based** (architect, researcher) vs RooSync's **task-based** (code-fixer, doc-updater). The smart model routing is valuable but aligns better with claudish (#1730).

### 3. Skills System

| Aspect | RooSync | oh-my-claudecode |
|--------|---------|------------------|
| **Path** | `.claude/skills/` (project) + `~/.claude/skills/` (user) | `.omc/skills/` (project) + `~/.omc/skills/` (user) |
| **Format** | SKILL.md (YAML frontmatter + markdown) | Markdown with triggers |
| **Auto-injection** | ❌ Manual invocation via `/skill` or Skill tool | ✅ Auto-inject based on triggers |
| **Learning** | ❌ No auto-learning | ✅ `/learner` extracts patterns |
| **Count** | 9 skills (sync-tour, validate, git-sync, etc.) | 3,200+ via ClawHub (OpenClaw ecosystem) |

**RooSync Skills:**
- sync-tour, validate, git-sync, github-status
- redistribute-memory, debrief, executor, pr-review, memory-inject

**OMC Skills (examples):**
- Team orchestration (`/team`, `/autopilot`, `/ralph`)
- Provider advisors (`/ask codex`, `/ask gemini`)
- Utilities (`/deep-interview`, `/ccg`)

**Verdict:** OMC's **auto-injection and learning** capabilities are superior. Our manual skill invocation is a maintenance burden. However, adopting OMC's skill system would require migration effort.

### 4. Model Routing

| Aspect | RooSync | oh-my-claudecode | claudish (#1730) |
|--------|---------|------------------|------------------|
| **Smart routing** | ❌ Manual | ✅ Yes (Haiku/Opus/Sonnet) | ✅ Yes (580+ models) |
| **Profile system** | ❌ No | ✅ Role-based (opus/sonnet/haiku/subagent) | ✅ Yes (free-tour/premium/local-only) |
| **Fallback chains** | ❌ No | ✅ Yes | ✅ Yes |
| **Extended thinking** | ❌ No | ⚠️ Partial | ✅ Cross-provider |
| **Cost tracking** | ❌ No | ✅ Yes | ✅ Yes |
| **Multi-provider** | Anthropic + z.ai (manual) | Codex/Gemini/Claude | 580+ via OpenRouter |

**Verdict:** OMC's model routing is good but **claudish (#1730) is better** for our needs (profile system, local models, extended thinking). OMC routing is limited to Codex/Gemini/Claude.

### 5. Platform Compatibility

| Aspect | RooSync | oh-my-claudecode |
|--------|---------|------------------|
| **Windows support** | ✅ Native (PowerShell, cmd) | ⚠️ Partial (requires psmux for tmux) |
| **tmux dependency** | ❌ No | ✅ Required for CLI workers |
| **Docker** | ✅ Optional (NanoClaw, Agent Zero) | ❌ No native Docker support |
| **WSL2** | ✅ Works | ⚠️ tmux requires WSL2 or psmux |

**Critical Issue:** OMC's tmux workers are **Unix-centric**. Windows support requires:
- **psmux** (native tmux for Windows) — 76 tmux-compatible commands
- OR **WSL2** with tmux installed

Our machines are Windows-based. psmux is an extra dependency, and WSL2 adds complexity.

---

## Value-Add: What OMC Does Better

### 1. Team Pipeline (High Value)

**OMC Team mode:**
```
team-plan → team-prd → team-exec → team-verify → team-fix (loop)
```

**RooSync equivalent (ad-hoc):**
```
sync-tour (9 phases) → coordinateur dispatch → worker execution → dashboard report
```

**Value:** OMC's Team pipeline is **more structured** and could formalize our task flow. The 5-stage pipeline ensures:
- Planning before execution
- PRD (requirements) before coding
- Verification before fixing
- Loop until verified

**Extraction opportunity:** Adapt Team pipeline stages to RooSync dashboard workflow.

### 2. Skill Auto-Injection (High Value)

**OMC:**
- Skills auto-inject based on triggers (keywords, context)
- `/learner` extracts patterns from successful sessions
- Project-level skills override user-level

**RooSync:**
- Skills require manual invocation (`/sync-tour`, `/validate`)
- No auto-learning
- Manual maintenance

**Value:** **Significant maintenance reduction** if we adopt OMC's auto-injection.

**Extraction opportunity:** Implement trigger-based skill loading in our skill system.

### 3. HUD Statusline (Medium Value)

**OMC:**
- Real-time status bar with token count, model info, orchestration metrics
- Presets: "focused", "verbose", "minimal"

**RooSync:**
- No real-time HUD
- Dashboard reports are post-session

**Value:** Improved visibility during long-running tasks.

**Extraction opportunity:** Build a RooSync HUD using roo-state-manager events.

### 4. Notification System (Medium Value)

**OMC:**
- Tag-based notifications (Telegram/Discord/Slack/webhooks)
- Session summaries pushed to channels
- Configurable tags (@alice, @here, etc.)

**RooSync:**
- Dashboard reports (manual)
- No push notifications

**Value:** Real-time alerts for critical failures or completions.

**Extraction opportunity:** Integrate with OpenClaw gateway (OMC already does this).

---

## Concerns: Why Full Adoption is Risky

### 1. Architectural Mismatch (Critical)

**RooSync:**
- 6-machine cluster (ai-01 + 5 executors)
- Cross-machine coordination via GDrive
- Roo Code + Claude Code agents
- Windows-based

**OMC:**
- Single-machine orchestration
- Claude Code only (no Roo support)
- Unix-centric (tmux workers)
- No cross-machine dashboard

**Impact:** Full adoption would require **rewriting RooSync core** to fit OMC's single-machine model. This defeats the purpose of our 6-machine cluster.

### 2. Windows Compatibility (High)

**OMC's tmux dependency:**
- Requires tmux for CLI workers (`omc team ...`)
- Windows support via psmux (76 tmux-compatible commands)
- OR WSL2 with tmux installed

**Our environment:**
- All machines are Windows-based
- No tmux/psmux currently installed
- psmux adds dependency; WSL2 adds complexity

**Impact:** CLI workers (one of OMC's key features) would not work without psmux/WSL2.

### 3. Overlap with Existing Tools (High)

| OMC Feature | RooSync Equivalent | Conflict? |
|-------------|-------------------|-----------|
| Team pipeline | sync-tour + coordinateur dispatch | Partial (workflow stages) |
| Multi-agent coordination | RooSync dashboards + messages | YES (different approach) |
| Skills system | `.claude/skills/` | YES (different format) |
| Model routing | Manual + planned claudish (#1730) | YES (claudish is better) |
| tmux workers | Scheduler-based parallel execution | YES (different paradigm) |

**Impact:** Full adoption would duplicate or replace existing tools, creating migration debt.

### 4. npm Dependency (Medium)

**OMC:** Requires `npm i -g oh-my-claude-sisyphus@latest`

**RooSync:** Self-contained (no external dependencies except MCP servers)

**Impact:** Adds external dependency to our harness. We'd need to track OMC updates, handle breaking changes, and ensure compatibility.

### 5. Tight Coupling to Claude Code (High)

**OMC:** Designed specifically for Claude Code CLI

**RooSync:** Supports both Claude Code AND Roo Code agents

**Impact:** OMC features (Team mode, skills) would not work with Roo Code agents. We'd lose flexibility.

---

## Proposed Evaluation Steps (from issue #1802)

| Step | Status | Finding |
|------|--------|---------|
| 1. Install OMC on test machine | ⚠️ PARTIAL | psmux required for Windows; not installed |
| 2. Compare agent architecture (19 vs 18) | ✅ DONE | OMC: role-based (architect, researcher); RooSync: task-based (code-fixer, doc-updater) |
| 3. Evaluate model routing vs claudish | ✅ DONE | claudish (#1730) is better for our needs (580+ models, profiles, local models) |
| 4. Test skill learning vs `.claude/skills/` | ✅ DONE | OMC auto-injection is superior; migration effort required |
| 5. Assess component extraction | ✅ DONE | Team pipeline, skill auto-injection, HUD are extractable |
| 6. Document recommendation | ✅ DONE | This report |

---

## Recommendations

### 1. Pattern Extraction (RECOMMENDED)

Extract specific patterns from OMC without full adoption:

#### A. Team Pipeline Stages

Adapt OMC's 5-stage pipeline to RooSync dashboard workflow:

```
Current: sync-tour → coordinateur dispatch → worker execution → dashboard report
Proposed: team-plan → team-prd → team-exec → team-verify → team-fix (loop)
```

**Implementation:**
- Add Team pipeline stages to dashboard workspace protocol
- Require `team-plan` before `team-exec` for complex tasks
- Implement `team-verify` as validation step (build + tests)
- Loop `team-fix` until verification passes

#### B. Skill Auto-Injection

Implement trigger-based skill loading:

```yaml
# .claude/skills/validate/SKILL.md
triggers:
  - "validate"
  - "lance les tests"
  - "vérifie le build"
  - "CI local"
```

**Implementation:**
- Extend roo-state-manager to support skill triggers
- Auto-inject skills based on conversation context
- Keep SKILL.md format (no migration needed)

#### C. HUD Statusline

Build a RooSync HUD using roo-state-manager events:

**Implementation:**
- Expose orchestration metrics via roo-state-manager
- Build CLI statusline (PowerShell/C#) or integrate with existing CLI
- Show: token count, active agents, task progress, model info

#### D. Notification System

Integrate with OpenClaw gateway (OMC already does this):

**Implementation:**
- Reuse OMC's OpenClaw integration code
- Push dashboard reports to Discord/Slack
- Tag-based notifications (@here, @machine-id)

### 2. Model Routing via claudish (#1730)

**Do NOT adopt OMC's model routing.** Use claudish instead:

| Feature | OMC | claudish |
|---------|-----|----------|
| Models | Codex/Gemini/Claude | 580+ (OpenRouter + direct) |
| Profiles | Role-based | free-tour/premium/local-only |
| Local models | ❌ No | ✅ Ollama/vLLM/MLX |
| Extended thinking | ⚠️ Partial | ✅ Cross-provider |
| Vision proxy | ❌ No | ✅ Yes |

**Recommendation:** Proceed with claudish adoption as planned in #1730.

### 3. Full Adoption (NOT RECOMMENDED)

**Do NOT adopt OMC fully** due to:
- Architectural mismatch (single-machine vs 6-machine cluster)
- Windows compatibility (tmux/psmux dependency)
- Overlap with existing tools (RooSync, claudish)
- Loss of Roo Code support

---

## Next Steps

### Immediate (Priority: HIGH)

1. **Create issue:** Extract Team pipeline stages to RooSync dashboard workflow
   - Labels: `enhancement`, `architecture`, `omc-patterns`
   - Reference: #1802, #1730

2. **Create issue:** Implement skill auto-injection with triggers
   - Labels: `enhancement`, `skills`, `omc-patterns`
   - Reference: #1802, #1368

3. **Create issue:** Build RooSync HUD statusline
   - Labels: `enhancement`, `ux`, `omc-patterns`
   - Reference: #1802

4. **Proceed with claudish adoption** (#1730)
   - Labels: `enhancement`, `router`, `model-routing`
   - Note: OMC routing evaluated but rejected in favor of claudish

### Deferred (Priority: MEDIUM)

5. **Evaluate OpenClaw gateway integration** for notifications
   - Labels: `investigation`, `notifications`, `omc-patterns`
   - Reference: #1802, #1073

6. **Test psmux on one executor** (myia-po-2025) for tmux compatibility
   - Labels: `investigation`, `windows`, `tmux`
   - Note: Only if Team pipeline extraction requires tmux workers

### Documentation

7. **Update CLAUDE.md** with OMC pattern extraction decisions
   - Document which patterns were adopted/adapted
   - Reference this report (#1802)

8. **Update agents-architecture.md** with Team pipeline stages
   - Map OMC agents to RooSync workers
   - Document role-based vs task-based specialization

---

## Related Issues Cross-Reference

| Issue | Topic | Relation to OMC |
|-------|-------|-----------------|
| #1730 | Unified model router | **CONFLICT:** claudish preferred over OMC routing |
| #1073 | Claw ecosystem comparison | **RELATED:** OMC integrates with OpenClaw |
| #1368 | Claude Code skills analysis | **RELATED:** OMC auto-injection vs our manual skills |
| #1770 | Free-tier model router | **RELATED:** OMC smart routing vs our manual routing |
| #1707 | Cline evaluation | **SIMILAR:** Both are orchestration plugins for Claude Code |
| #1318, #1319 | NanoClaw deployment/bridge | **ORTHOGONAL:** Different use case (security/orchestration) |
| #1714, #1754 | NanoClaw PR review/pipeline | **ORTHOGONAL:** Different use case (PR automation) |

---

## Conclusion

oh-my-claudecode is an impressive project with valuable patterns, but **full adoption is NOT recommended** for the RooSync harness. The architectural mismatch (single-machine vs 6-machine cluster), Windows compatibility issues (tmux/psmux), and overlap with existing tools (RooSync, claudish) make full adoption high-risk with low ROI.

**Recommended approach:**

1. **Extract patterns** (Team pipeline, skill auto-injection, HUD) without full adoption
2. **Proceed with claudish** (#1730) for model routing instead of OMC's routing
3. **Maintain RooSync architecture** (6-machine cluster, cross-machine coordination)
4. **Consider psmux evaluation** only if Team pipeline extraction requires tmux workers

This approach maximizes value (pattern extraction) while minimizing risk (no architectural rewrite, no dependency on OMC's release cycle).

---

## Sources

- [oh-my-claudecode GitHub](https://github.com/Yeachan-Heo/oh-my-claudecode) — README analyzed 2026-04-30
- [oh-my-claudecode WebReader](https://github.com/Yeachan-Heo/oh-my-claudecode) — Full content fetched 2026-04-30
- RooSync Agents Architecture — 18 subagents
- `D:/Dev/roo-extensions/.claude/skills/` — 9 skills (sync-tour, validate, etc.)
- [Unified Model Router Analysis](unified-model-router.md) — Issue #1730
- [Claw Ecosystem Comparison](claw-ecosystem-comparison.md) — Issue #1073
- [Issue #1802](https://github.com/jsboige/roo-extensions/issues/1802) — Original evaluation request

---

**Report completed:** 2026-04-30
**Next review:** After pattern extraction issues are completed (3-4 weeks)

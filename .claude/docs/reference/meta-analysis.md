# Meta-Analysis Protocol - 3x2 Scheduler Architecture

**Version:** 1.2.0
**Created:** 2026-03-04
**Updated:** 2026-03-22
**Issue:** #551 (Meta-Analyst tier)

---

## Overview

The meta-analysis tier is part of the **3-tier scheduling architecture** (3 types x 2 agents = 6 schedulers):

| Tier | Frequency | Machines | Role |
|------|-----------|----------|------|
| **Meta-Analyst** | 72h | ALL | Observe, analyze, PROPOSE |
| Coordinator | 6-12h | ai-01 only | Triage, dispatch, track |
| Executor | 3h | ALL | Execute assigned tasks |

Each tier has 2 agents: one Roo scheduler + one Claude scheduler.

---

## Meta-Analyst Role

**Mission:** Independently analyze BOTH schedulers (Roo + Claude) on the local machine, then reconcile findings via META-INTERCOM.

### What Meta-Analysts Analyze

1. **Local Roo scheduler traces** (`%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks/`)
   - Success/failure rates per mode
   - Escalation patterns
   - Tool usage patterns
   - Delegation effectiveness

2. **Local Claude session transcripts** (`~/.claude/projects/*/`)
   - Worker execution logs
   - Error patterns
   - Model escalation frequency

3. **Both harnesses** (cross-analysis):
   - Roo analyzes `.claude/rules/`, `CLAUDE.md`, `.claude/commands/`, `.claude/skills/`
   - Claude analyzes `.roo/rules/`, `.roomodes`, `scheduler-workflow-*.md`, `modes-config.json`
   - Each is more free to critique the OTHER harness
   - **ALWAYS read `docs/harness/rules-mapping.md` first** — it maps equivalences between harnesses.
     A rule marked "✅ Aligned" exists in BOTH harnesses under different names. Do NOT create issues
     for "missing" rules that appear in this mapping table.

4. **Operational metrics**:
   - Issues created vs closed
   - Machine utilization
   - Guard rail violations

5. **Deep trace exploration via MCP (#807)** — Use conversation_browser and roosync_search for rich analysis:
   ```
   // Entry point: list recent tasks
   conversation_browser(action: "list", limit: 20, sortBy: "lastActivity", sortOrder: "desc")

   // Analyze top 5 tasks
   conversation_browser(action: "view", task_id: "{ID}", detail_level: "summary", smart_truncation: true)

   // Get stats
   conversation_browser(action: "summarize", summarize_type: "trace", taskId: "{ID}")

   // Quick overview of all dashboards
   roosync_dashboard(action: "read_overview")
   ```
   - Browse actual conversation content, not just file metadata
   - Identify error patterns, loops, and escalation triggers
   - Correlate tool failures with specific tasks and modes

6. **Semantic friction search (#637)** — Search for recent user frustrations using advanced filters:
   ```
   roosync_search(
     action: "semantic",
     search_query: "impossible bloque erreur echec fail permission",
     has_errors: true,
     start_date: "{72h ago}",
     max_results: 10
   )
   ```
   - Look for `has_errors: true` patterns in user messages
   - Identify recurring tool failures (`tool_name` filter)
   - Correlate with specific modes or models (`model` filter)
   - Report patterns with ≥ 2 occurrences as friction candidates

### What Meta-Analysts Produce

- **Analysis docs** on GDrive (structured, timestamped)
- **META-INTERCOM entries** (reconciliation)
- **GitHub issues with `needs-approval`** (proposed improvements)
- **GitHub issues with `needs-approval` + `harness-change`** (proposed harness modifications, BLOCKED until user approval)

---

## META-INTERCOM Protocol

**File:** `.claude/local/META-INTERCOM-{MACHINE}.md`

Dedicated channel for meta-analysis reconciliation. Same format as INTERCOM but SEPARATE from operational communication.

**Template:** `.claude/local/META-INTERCOM_TEMPLATE.md`

### Workflow

1. Agent A writes its analysis (self + cross) to META-INTERCOM
2. Agent B reads Agent A's analysis, writes its own + reconciliation notes
3. Both agents can comment on the other's findings
4. Actionable findings become GitHub issues with `needs-approval`

### Cross-Machine Consultation (after local reconciliation)

When both local meta-analysts (Roo + Claude) **agree** on a finding via META-INTERCOM, they MAY consult other machines' agents via RooSync to gather broader perspective before creating an issue.

**Conditions for cross-machine consultation:**
- Both local agents have written their analysis to META-INTERCOM
- The finding is **non-trivial** (not just "everything is fine")
- The finding affects multiple machines or is architectural

**Procedure:**
1. The Claude meta-analyst sends a RooSync message with tag `[META-CONSULT]`
   - Subject: `[META-CONSULT] {finding summary}`
   - Body: The reconciled finding + specific question for other machines
   - To: `all` or specific machines relevant to the finding
2. Responses are collected at the next meta-analysis cycle (24h)
3. If consensus is reached across machines → create issue with `needs-approval`
4. If disagreement → document in META-INTERCOM, escalate to coordinator

**Guard rail:** Cross-machine consultation is READ-ONLY. Meta-analysts still cannot dispatch, modify files, or close issues on other machines.

### Agentic Deliberation (sk-agent, experimental)

For complex or high-impact findings, meta-analysts MAY trigger an **agentic conversation** via `sk-agent` to get structured multi-perspective deliberation before proposing an action.

**Use cases:**
- Architectural decisions affecting the scheduling pipeline
- Conflicting findings between machines
- Trade-offs requiring structured debate (e.g., tool removal vs retention)

**Procedure:**
1. Prepare a concise brief with the finding, context, and options
2. Call `run_conversation(conversation: "deep-think")` or `call_agent(agent: "critic")` with the brief
3. Capture the deliberation output
4. Include the deliberation summary in the `needs-approval` issue body

**Status:** Experimental. See issue tracking sk-agent capabilities (code access, git context).
Requires validation before production use.

---

## Decision Chain

| Finding type | Action | Authority |
|-------------|--------|-----------|
| Informational (stats, rates) | Append to analysis doc + META-INTERCOM | Autonomous |
| Operational suggestion | Write to META-INTERCOM, coordinator picks up | Autonomous |
| Environment issue (missing .env, MCP down, service unreachable) | Write to META-INTERCOM + flag for coordinator | Autonomous (coordinator acts) |
| New issue (bug, friction) | Create with `needs-approval` label | Semi-autonomous |
| Harness change | Create with `needs-approval` + `harness-change` | **BLOCKED until user approval** |

**Environment issues are a priority escalation path.** Meta-analysts detect these in execution traces (failed tool calls, missing configs, service timeouts) and flag them in META-INTERCOM. The coordinator is responsible for sending corrective instructions to affected machines. See `.claude/docs/coordinator-specific/scheduled-coordinator.md` section 4.

---

## Santé Outillage (#761)

**Objectif :** Détecter les outils sous-utilisés, dégradés ou cassés AVANT qu'ils ne soient abandonnés silencieusement.

### Checks obligatoires (chaque cycle meta-analyse)

**1. Outils jamais appelés (>14 jours)**

Croiser les 34 outils déclarés dans `ListTools` avec les traces récentes :

```
roosync_search(
  action: "semantic",
  search_query: "{tool_name} result",
  start_date: "{14 jours avant}",
  max_results: 5
)
```

Lister les outils sans activité > 14 jours. Distinguer :
- **Intentionnel** : outil rarement utilisé par design (ex: `roosync_init`)
- **Suspect** : outil censé être utilisé régulièrement mais absent des traces
- **Cassé** : outil qui échoue systématiquement (corrélé avec bugs ouverts)

**2. Outils avec bugs ouverts > 14 jours**

```bash
gh issue list --repo jsboige/roo-extensions --label bug --state open --json number,title,createdAt
```

Cross-référencer les noms d'outils (`roosync_*`, `conversation_browser`, `codebase_search`, etc.) dans les titres et corps des issues bug. Alerter si un bug d'outil est ouvert > 14 jours.

**3. Workarounds non résolus**

Scanner MEMORY.md et PROJECT_MEMORY.md pour :
- Entrées contenant "workaround", "bug connu", "contournement", "ne pas utiliser"
- Si le workaround existe depuis > 14 jours sans issue corrective → créer une issue `needs-approval`

**4. Secrets exposés**

Vérifier :
- Aucun fichier `.env` commité (`git log --all -- "*.env"`)
- Aucune clé API dans les issues/commentaires récents
- `sk_agent_config.json` est bien gitignored
- Alertes GitHub secret scanning résolues

### Format de rapport

```markdown
## Santé Outillage (cycle {date})

| Métrique | Valeur | Tendance |
|----------|--------|----------|
| Outils actifs (14j) | X/34 | ↑↓→ |
| Bugs outils ouverts >14j | Y | |
| Workarounds non fixés | Z | |
| Secrets exposés | 0/N | |

**Score santé :** A (>90% actifs, 0 bugs critiques) / B (>75%) / C (>50%) / D (<50%)

### Outils inactifs
- `{outil}` : dernière utilisation {date}, raison probable : {intentionnel|suspect|cassé}

### Bugs outils ouverts
- #{num} `{outil}` — ouvert depuis {jours}j : {titre}

### Workarounds actifs
- {description} — depuis {date}, issue corrective : #{num} ou MANQUANTE
```

### Cycle de vie d'un outil dégradé

```
Fonctionnel → Bug signalé → Workaround documenté → Outil ignoré → "Dead code" → Supprimé
                                                     ↑
                            META-ANALYSTE INTERVIENT ICI (détection avant abandon)
```

**Référence :** Issue #757 (culture anti-entropie), #761 (cette check)

---

## Guard Rails (CRITICAL)

### Meta-analysts MUST NOT:
- Modify any file in `.roo/rules/`, `.claude/rules/`, `.claude/commands/`, `.claude/skills/`
- Modify `CLAUDE.md`, `.roomodes`, `modes-config.json`, `scheduler-workflow-*.md`
- Close, archive, or dispatch GitHub issues (that is the Coordinator's job)
- Force-push, rebase, or destructive git operations
- Create issues WITHOUT `needs-approval` label

### Meta-analysts CAN:
- Read all local traces (Roo tasks, Claude sessions)
- Read all harness files (both systems)
- Create issues with `needs-approval` (proposals, not decisions)
- Write to META-INTERCOM
- Write analysis docs to GDrive
- Comment on existing issues with analysis findings

---

## GDrive Storage

```
.shared-state/meta-analysis/
  +-- {machine}/
  |   +-- claude-analysis-{date}.md
  |   +-- roo-analysis-{date}.md
  +-- reconciliation/
      +-- {machine}-{date}.md
```

---

## References

- #551: Meta-Analyst tier (this protocol)
- #540: Coordinator tier — see `.claude/docs/coordinator-specific/scheduled-coordinator.md`
- `.claude/INTERCOM_PROTOCOL.md`: Operational INTERCOM (separate)
- `.claude/docs/condensation-thresholds.md`: GLM context limits

---

**Last updated:** 2026-03-22

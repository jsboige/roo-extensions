# Documentation On-Demand — Index

**Chemin :** `docs/harness/reference/` — Ces documents ne sont PAS auto-charges. Les consulter quand le sujet est pertinent.

## Protocoles et Processus

| Document | Essentiel | Chemin |
|----------|-----------|--------|
| **Condensation GLM** | Seuil 75% pour z.ai (131K reels). `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` | `condensation-thresholds.md` |
| **Checklists GitHub** | Ne JAMAIS fermer une issue avec tableau vide | `github-checklists.md` |
| **Feedback/Friction** | Signaler via RooSync `[FRICTION]` to:all | `feedback-process.md`, `friction-protocol.md` |
| **Escalade** | 5 niveaux (outils → sub-agent → sk-agent → SDDD → utilisateur) | `escalation-protocol.md` |
| **SDDD Grounding** | Triple grounding (semantique + conversationnel + technique) | `sddd-conversational-grounding.md` |
| **Delegation** | Deleguer aux sub-agents si autonome, parallelisable | `delegation.md` |
| **Harness Reduction** | Plan de reduction du harnais (audit tokens, strategie) | `harness-reduction-plan.md` |
| **SDDD Grounding (detailed)** | Multi-pass protocol, filtres roosync_search, workflow complet | `sddd-grounding-detailed.md` |
| **conversation_browser (detailed)** | detailLevel complet, summarize_type, anti-patterns | `conversation-browser-detailed.md` |
| **Friction Protocol (detailed)** | Quand/comment signaler, traitement, criteres approbation | `friction-protocol-detailed.md` |
| **Agent Claim Discipline (detailed)** | Incident classes, worker guards (detached HEAD), sanctions | `agent-claim-discipline-detailed.md` |
| **Tool Availability (detailed)** | Config win-cli canonique, sk-agent, STOP & REPAIR complet | `tool-availability-detailed.md` |
| **Issue Closure (detailed)** | Grille marqueurs, test bash, audit /coordinate, historique versions | `issue-closure-detailed.md` |
| **INTERCOM v3 Mentions** | Mentions structurees, crossPost, messageId v3, worktrees auto-detection | `intercom-v3-mentions.md` |
| **PR Trivial Merge Policy** | Patterns eligibles, diff constraints, procedure, garde-fous (#1582) | `pr-trivial-merge-policy.md` |

## Quality & CI

| Document | Essentiel | Chemin |
|----------|-----------|--------|
| **Test Success Rates** | 99.8% (ai-01), 99.6% (autres). Toujours `npx vitest run`. Tronquer output scheduler. | `test-success-rates.md` |
| **Worktree Cleanup** | Script cleanup orphelins + branches stale. Lifecycle complet | `worktree-cleanup.md`, `worktree-cleanup-protocol.md` |

## Coordination & Scheduler

| Document | Essentiel | Chemin |
|----------|-----------|--------|
| **Scheduler system** | 10 modes (5 familles x 2 niveaux). Orchestrateurs = 0 outils | `reference/scheduler-system.md` |
| **Scheduler densification** | Seuil : 1 echec en -simple → escalade IMMEDIATE vers -complex | `reference/scheduler-densification.md` |
| **Coordinator protocol** | Cycle 6-12h sur ai-01 | `coordinator-specific/scheduled-coordinator.md` |
| **Meta-analysis** | Cycle 72h. Triple grounding. Lecture seule | `reference/meta-analysis.md` |
| **PR review policy** | Agents → PR → Review coordinateur → Merge | `coordinator-specific/pr-review-policy.md` |
| **Meta-analyste (detailed)** | Workflow etapes 0-5, MCP snippets, HARD REJECT, differences Roo | `coordinator-specific/meta-analyst-detailed.md` |

## Reference Technique

| Document | Essentiel | Chemin |
|----------|-----------|--------|
| **GitHub CLI** | `gh` CLI, scope `project` requis. IDs fields Project #67 | `github-cli.md` |
| **Incidents** | Lecons cles : cross-machine check, STOP & REPAIR, CI avant push | `reference/incident-history.md` |
| **roo-schedulable** | Seulement taches subalternes | `reference/roo-schedulable-criteria.md` |
| **Bash fallback** | Outils natifs > MCP win-cli > degradation gracieuse | `reference/bash-fallback.md` |
| **MCP discoverability** | Tests decouverte en 3 phases | `reference/mcp-discoverability.md` |
| **Stub Detection** | CI gate pour stub exports | `reference/stub-detection.md` |
| **Web1 contraintes** | 16GB RAM, `--maxWorkers=1`, GDrive path different | `machine-specific/myia-web1-constraints.md` |
| **WSL/Docker Cascade** | Protocol investigation #1379 (myia-ai-01) | `wsl-docker-cascade-protocol.md` |

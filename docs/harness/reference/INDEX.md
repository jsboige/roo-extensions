# Documentation On-Demand — Index

**Chemin :** `docs/harness/reference/` — Ces documents ne sont PAS auto-charges. Les consulter quand le sujet est pertinent.

## Protocoles et Processus

| Document | Essentiel | Chemin |
|----------|-----------|--------|
| **Condensation GLM** | Seuil 80% pour z.ai (131K reels). `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80` | `condensation-thresholds.md` |
| **Checklists GitHub** | Ne JAMAIS fermer une issue avec tableau vide | `github-checklists.md` |
| **Feedback/Friction** | Signaler via RooSync `[FRICTION]` to:all | `feedback-process.md`, `friction-protocol.md` |
| **Escalade** | 5 niveaux (outils → sub-agent → sk-agent → SDDD → utilisateur) | `escalation-protocol.md` |
| **SDDD Grounding** | Triple grounding (semantique + conversationnel + technique) | `sddd-conversational-grounding.md` |
| **Delegation** | Deleguer aux sub-agents si autonome, parallelisable | `delegation.md` |
| **Harness Reduction** | Plan de reduction du harnais (audit tokens, strategie) | `harness-reduction-plan.md` |

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

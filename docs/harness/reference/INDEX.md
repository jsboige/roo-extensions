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
| **Pi Agent Comparative Study** | Pi / pi-subagents / devstack vs RooSync — adaptation opportunities (#2416) | `pi-agent-comparative-study.md` |
| **SDDD Grounding (detailed)** | Multi-pass protocol, filtres roosync_search, workflow complet | `sddd-grounding-detailed.md` |
| **conversation_browser (detailed)** | detailLevel complet, summarize_type, anti-patterns | `conversation-browser-detailed.md` |
| **Friction Protocol (detailed)** | Quand/comment signaler, traitement, criteres approbation | `friction-protocol-detailed.md` |
| **Agent Claim Discipline (detailed)** | Incident classes, worker guards (detached HEAD), sanctions | `agent-claim-discipline-detailed.md` |
| **Tool Availability (detailed)** | Config win-cli canonique, sk-agent, STOP & REPAIR complet | `tool-availability-detailed.md` |
| **Issue Closure (detailed)** | Grille marqueurs, test bash, audit /coordinate, historique versions | `issue-closure-detailed.md` |
| **INTERCOM v3 Mentions** | Mentions structurees, crossPost, messageId v3, worktrees auto-detection | `intercom-v3-mentions.md` |
| **PR Trivial Merge Policy** | Patterns eligibles, diff constraints, procedure, garde-fous (#1582) | `pr-trivial-merge-policy.md` |
| **MCP Diagnosis (procedure)** | Healthcheck, architecture chain, diagnostic par couche (procedure complete) | `mcp-diagnosis-procedure.md` |

## Quality & CI

| Document | Essentiel | Chemin |
|----------|-----------|--------|
| **Test Success Rates** | 99.8% (ai-01), 99.6% (autres). Toujours `npx vitest run`. Tronquer output scheduler. | `test-success-rates.md` |
| **Worktree Cleanup** | Script cleanup orphelins + branches stale. Lifecycle complet (v2.0 — v1.0 archivée) | `worktree-cleanup.md` |

## Coordination & Scheduler

| Document | Essentiel | Chemin |
|----------|-----------|--------|
| **Scheduler system** | 10 modes (5 familles x 2 niveaux). Orchestrateurs = 0 outils | `scheduler-system.md` |
| **Scheduler densification** | Seuil : 1 echec en -simple → escalade IMMEDIATE vers -complex | `scheduler-densification.md` |
| **Scheduler model defaults** | Worker (`start-claude-worker.ps1`) priority chain : Project field → -Model → labels → sonnet | `scheduler-model-defaults.md` |
| **Coordinator protocol** | Cycle 6-12h sur ai-01 | `../coordinator-specific/scheduled-coordinator.md` |
| **Meta-analysis** | Cycle 72h. Triple grounding. Lecture seule | `meta-analysis.md` |
| **PR review policy** | Agents → PR → Review coordinateur → Merge | `../coordinator-specific/pr-review-policy.md` |
| **Meta-analyste (rule)** | Rule slim (role, 7 analyses productives, HARD REJECT). Loaded par `start-meta-audit.ps1` | `../coordinator-specific/meta-analyst-rule.md` |
| **Meta-analyste (detailed)** | Workflow etapes 0-5, MCP snippets, HARD REJECT, differences Roo | `../coordinator-specific/meta-analyst-detailed.md` |
| **Agents inventory** | 18 subagents + 6 skills + 4 commands (Claude Code) | `agents-inventory.md` |
| **Bots directory** | Hermes (po-2026) + NanoClaw (ai-01), cron coverage 4×/hour, wake-on-demand | `bots-directory.md` |
| **conversation_browser (guide+detail)** | Point d'entree `list`, actions, detailLevel, summarize_type, anti-patterns | `conversation-browser-detailed.md` |
| **RooSync coordinator tools** | health_view, inventory, compare_config, dashboard — params, output, scenarios | `roosync-tools-guide.md` |

## Reference Technique

| Document | Essentiel | Chemin |
|----------|-----------|--------|
| **GitHub CLI** | `gh` CLI, scope `project` requis. IDs fields Project #67 | `github-cli.md` |
| **Incidents** | Lecons cles : cross-machine check, STOP & REPAIR, CI avant push | `incident-history.md` |
| **roo-schedulable** | Seulement taches subalternes | `roo-schedulable-criteria.md` |
| **Bash fallback** | Outils natifs > MCP win-cli > degradation gracieuse | `bash-fallback.md` |
| **MCP discoverability** | Tests decouverte en 3 phases | `mcp-discoverability.md` |
| **Stub Detection** | CI gate pour stub exports | `stub-detection.md` |
| **Web1 contraintes** | 16GB RAM, `--maxWorkers=1`, GDrive path different | `../machine-specific/myia-web1-constraints.md` |
| **WSL/Docker Cascade** | Protocol investigation #1379 (myia-ai-01) | `wsl-docker-cascade-protocol.md` |
| **Postmortem Template** | Structured template + investigation workflow for multi-agent incidents | `postmortem-template.md` |
| **Redistribute-Memory V2** | 5 tiers, 6 antipatterns, dry-run par defaut. Issue #2223 | `redistribute-memory-skill.md` |

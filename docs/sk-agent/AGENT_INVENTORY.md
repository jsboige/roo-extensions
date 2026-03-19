# SK-Agent Complete Agent Inventory

**Issue:** #645 - Phase 2: Document Complete Agent Inventory
**Date:** 2026-03-19
**machine:** myia-po-2026
**source:** mcps/internal/servers/sk-agent/sk_agent_config.json

---

## Summary

| Metric | Count |
|--------|-------|
| **Total Agents** | 18 |
| **Standalone Agents** | 18 |
| **Inline Agents** | 16 (conversation-scoped) |
| **Conversations** | 9 |
| **Models** | 8 |
| **MCP Plugins** | 2 |
---

## Agents by Category

### Category 1: Core Utility Agents (4 agents)

| ID | Model | Vision | Tools | Memory | Description |
|----|-------|--------|-------|--------|-------------|
| analyst | glm-5 | No | searxng, playwright | Yes | General analyst with web search and memory |
| vision-analyst | glm-4.6v | Yes | searxng | No | Image and document analysis specialist |
| vision-local | zwz-8b | Yes | - | No | Fast local fine-grained vision (135 tok/s) |
| fast | glm-4.7-flash-fast | No | - | No | Quick responses (1-5s), no tools |

### Category 2: Deep Search Agents (3 agents)
| ID | Model | Vision | Tools | Memory | Description |
|----|-------|--------|-------|--------|-------------|
| researcher | glm-5 | No | searxng, playwright | Yes | Investigative researcher with web search |
| synthesizer | glm-5 | No | - | No | Expert at turning findings into reports |
| critic | qwen3.5-35b-a3b | Yes | - | No | Rigorous quality reviewer |

### Category 3: Deep Think Agents (4 agents)
| ID | Model | Vision | Tools | Memory | Description |
|----|-------|--------|-------|--------|-------------|
| optimist | glm-5 | No | - | No | Strategic optimist for opportunities |
| devils-advocate | glm-5 | No | - | No | Relentless contrarian for risk testing |
| pragmatist | qwen3.5-35b-a3b | Yes | - | No | Implementation-focused realist |
| mediator | glm-5 | No | - | No | Diplomatic consensus builder |

### Category 4: Operational Agents (3 agents)
| ID | Model | Vision | Tools | Memory | Description |
|----|-------|--------|-------|--------|-------------|
| config-auditor | qwen3.5-35b-a3b | Yes | - | No | MCP and Roo configuration auditor |
| log-analyzer | qwen3.5-35b-a3b | Yes | - | No | Application logs analyzer |
| commit-reviewer | glm-5 | No | - | No | Specialized git diff reviewer |

### Category 5: Surveillance Agent (1 agent)
| ID | Model | Vision | Tools | Memory | Description |
|----|-------|--------|-------|--------|-------------|
| guardian-sentinel | qwen3.5-35b-a3b | Yes | - | Yes | Real-time system health surveillance |

### Category 6: OWUI-Backed Agents (3 agents)
| ID | Model | Vision | Tools | Memory | Description |
|----|-------|--------|-------|--------|-------------|
| owui-analyst | owui-expert-analyste | No | searxng | Yes | Expert analyst via OWUI |
| owui-writer | owui-redacteur-technique | No | - | No | Technical documentation writer |
| owui-vision | owui-vision-expert | Yes | - | No | Vision analysis expert via OWUI |

---

## Models Configuration

| ID | Provider | Context | Vision | Status | Description |
|----|----------|---------|--------|--------|-------------|
| glm-5 | z.ai Cloud | 200K | No | Enabled | GLM-5 reasoning via z.ai cloud |
| glm-4.6v | z.ai Cloud | 128K | Yes | Enabled | GLM-4.6V vision via z.ai cloud |
| zwz-8b | Local vLLM | 131K | Yes | Disabled | ZwZ-8B AWQ - 135 tok/s |
| qwen3.5-35b-a3b | Local vLLM | 262K | Yes | Disabled | Qwen3.5 35B MoE AWQ - 86 tok/s |
| glm-4.7-flash-fast | OWUI | 131K | No | Disabled | GLM-4.7-Flash AWQ via OWUI |
| owui-expert-analyste | OWUI | 131K | No | Disabled | OWUI custom model |
| owui-redacteur-technique | OWUI | 131K | No | Disabled | OWUI custom model |
| owui-vision-expert | OWUI | 131K | Yes | Disabled | OWUI custom model |

---

## Conversations
| ID | Type | Agents | Rounds | Description |
|----|------|--------|--------|-------------|
| deep-search | magentic | researcher, synthesizer, critic | 10 | Multi-agent deep research with search, synthesis, critical review |
| deep-think | group_chat | optimist, devils-advocate, pragmatist, mediator | 8 | Multi-perspective deliberation with diverse viewpoints |
| code-review | group_chat | (4 inline agents) | 6 | Multi-perspective code review with security, performance, maintainability |
| research-debate | sequential | (4 inline agents) | 4 | Research from opposing viewpoints then synthesize |
| config-harmonization | sequential | (4 inline agents) | 4 | Config drift deliberation |
| commit-review | sequential | commit-reviewer, devils-advocate, synthesizer | 3 | Structured git diff review |
| task-allocation | group_chat | analyst, pragmatist, critic | 4 | Task allocation for GitHub issues |
| intelligent-task-dispatch | sequential | researcher, pragmatist, critic, synthesizer | 5 | Multi-perspective task analysis |

---
## Inline Agents (Conversation-Scoped)
### code-review Conversation
| ID | Model | Description |
|----|-------|-------------|
| security-reviewer | glm-5 | Security-focused code reviewer |
| perf-reviewer | qwen3.5-35b-a3b | Performance-focused code reviewer |
| maintainability-reviewer | qwen3.5-35b-a3b | Maintainability and readability reviewer |
| code-synthesizer | glm-5 | Synthesizes review findings |

### research-debate Conversation
| ID | Model | Description |
|----|-------|-------------|
| proponent | glm-5 | Argues in favor of the proposition |
| opponent | glm-5 | Argues against the proposition |
| fact-checker | qwen3.5-35b-a3b | Verifies claims from both sides |
| debate-synthesizer | glm-5 | Produces balanced conclusion |
### config-harmonization Conversation
| ID | Model | Description |
|----|-------|-------------|
| config-detective | qwen3.5-35b-a3b | Identifies and classifies config differences |
| risk-assessor | glm-5 | Assesses risk of each config difference |
| resolution-planner | qwen3.5-35b-a3b | Plans concrete resolution steps |
| harmonization-synthesizer | glm-5 | Produces final harmonization report |

---
## MCP Plugins
| ID | Command | Description |
|----|---------|-------------|
| searxng | npx -y mcp-searxng | Web search via SearXNG |
| playwright | npx -y @playwright/mcp@latest | Browser automation and web scraping |

---
## Memory Collections
| Collection | Agent | Purpose |
|------------|-------|---------|
| analyst-memory | analyst | General analyst memory |
| research-memory | researcher | Research findings storage |
| guardian-sentinel-alerts | guardian-sentinel | Anomaly detection history |
| owui-analyst-memory | owui-analyst | OWUI analyst memory |

---
## Infrastructure Endpoints
| Service | URL |
|---------|-----|
| HTTP endpoint | https://skagents.myia.io/mcp |
| vLLM mini (zwz-8b) | https://api.mini.text-generation-webui.myia.io/v1 |
| vLLM medium (qwen3.5) | https://api.medium.text-generation-webui.myia.io/v1 |
| OWUI API | https://open-webui.myia.io/openai |
| Embeddings | https://embeddings.myia.io/v1 |
| Qdrant | https://qdrant.myia.io:443 |
| SearXNG | https://search.myia.io |

---
## Usage Examples
### Single Agent Call
call_agent(prompt: "Analyze this architecture", agent: "analyst")
call_agent(prompt: "Describe this diagram", agent: "vision-analyst", attachment: "/path/to/image.png")
call_agent(prompt: "Quick question", agent: "fast")

### Multi-Agent Conversation
run_conversation(prompt: "Research RAG architectures", conversation: "deep-search")
run_conversation(prompt: "Should we migrate to microservices?", conversation: "deep-think")
run_conversation(prompt: "Review this PR", conversation: "code-review")

---
## References
- Issue #645: Phase 2 - Document Complete Agent Inventory
- Issue #485: sk-agent exploitation and enhancement
- Issue #566: Enrich sub-agents
- Documentation: docs/sk-agent/EXPLOITATION_REPORT_485.md
- Documentation: docs/services/sk-agent-deployment.md

---
**Last Updated:** 2026-03-19
**Author:** Claude Code (myia-po-2026)

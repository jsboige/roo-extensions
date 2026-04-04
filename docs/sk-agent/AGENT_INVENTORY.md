# SK-Agent Complete Agent Inventory

**Issue:** #894 - Enrich sk_agent with OWUI models (thinking/non-thinking) and z.ai models
**Date:** 2026-04-03
**Machine:** myia-web1
**Source:** mcps/internal/servers/sk-agent/sk_agent_config.template.json

---

## Summary

| Metric | Count |
|--------|-------|
| **Total Agents** | 24 |
| **Standalone Agents** | 24 |
| **Inline Agents** | 16 (conversation-scoped) |
| **Conversations** | 8 |
| **Models** | 13 |
| **MCP Plugins** | 2 |

---

## Models Configuration

### z.ai Cloud Models (6)

| ID | Model ID | Vision | Thinking | Context | Description |
|----|----------|--------|----------|---------|-------------|
| glm-5.1 | glm-5.1 | No | No | 200K | GLM-5.1 reasoning via z.ai cloud (45.3/113 coding, +28% vs GLM-5) |
| glm-5.1-thinking | glm-5.1 | No | **Yes** | 200K | GLM-5.1 with extended thinking via z.ai cloud |
| glm-4.6v | glm-4.6v | Yes | No | 128K | GLM-4.6V vision via z.ai cloud |
| glm-4.6v-thinking | glm-4.6v | Yes | **Yes** | 128K | GLM-4.6V vision with extended thinking via z.ai cloud |
| glm-4.7-flash-fast | glm-4.7-flash-fast | No | No | 128K | GLM-4.7 Flash Fast — quick responses (1-5s) |
| glm-4.7-flash-thinking | glm-4.7-flash-fast | No | **Yes** | 128K | GLM-4.7 Flash with extended thinking |

### vLLM Local Models (4)

| ID | Model ID | Vision | Thinking | Context | Description |
|----|----------|--------|----------|---------|-------------|
| omnicoder-9b | omnicoder-9b | Yes | No | 32K | OmniCoder 9B local vLLM (port 5001, 135 tok/s) |
| omnicoder-9b-thinking | omnicoder-9b | Yes | **Yes** | 32K | OmniCoder 9B with extended thinking |
| qwen3.5-35b-a3b | Qwen3.5-35B-A3B | Yes | No | 32K | Qwen 3.5 35B local vLLM (port 5002) |
| qwen3.5-35b-a3b-thinking | Qwen3.5-35B-A3B | Yes | **Yes** | 32K | Qwen 3.5 35B with extended thinking |

### OWUI Proxy Models (3)

| ID | Model ID | Vision | Thinking | Context | Description |
|----|----------|--------|----------|---------|-------------|
| owui-expert-analyste | expert-analyste | No | No | 131K | OWUI Expert Analyst (requires OWUI API key) |
| owui-redacteur-technique | redacteur-technique | No | No | 131K | OWUI Technical Writer (requires OWUI API key) |
| owui-vision-expert | vision-expert | Yes | No | 131K | OWUI Vision Expert (requires OWUI API key) |

---

## Agents by Category

### Category 1: Core Utility Agents (4 + 4 thinking = 8 agents)

| ID | Model | Vision | Thinking | Tools | Memory | Description |
|----|-------|--------|----------|-------|--------|-------------|
| analyst | glm-5.1 | No | No | searxng, playwright | Yes | General analyst with web search and memory |
| analyst-thinking | glm-5.1-thinking | No | **Yes** | searxng, playwright | Yes | Analyst with extended thinking for complex analysis |
| vision-analyst | glm-4.6v | Yes | No | searxng | No | Image and document analysis specialist |
| vision-local | omnicoder-9b | Yes | No | - | No | Fast local fine-grained vision (135 tok/s) |
| vision-local-thinking | omnicoder-9b-thinking | Yes | **Yes** | - | No | Local vision with extended thinking for detailed analysis |
| coder | omnicoder-9b | Yes | No | - | No | Code generation and review specialist |
| coder-thinking | omnicoder-9b-thinking | Yes | **Yes** | - | No | Code specialist with extended thinking for complex tasks |
| fast | glm-4.7-flash-fast | No | No | - | No | Quick responses (1-5s), no tools |
| fast-thinking | glm-4.7-flash-thinking | No | **Yes** | - | No | Quick responses with extended thinking |

### Category 2: Deep Search Agents (3 + 1 thinking = 4 agents)

| ID | Model | Vision | Thinking | Tools | Memory | Description |
|----|-------|--------|----------|-------|--------|-------------|
| researcher | glm-5.1 | No | No | searxng, playwright | Yes | Investigative researcher with web search |
| researcher-thinking | glm-5.1-thinking | No | **Yes** | searxng, playwright | Yes | Researcher with extended thinking for deep investigation |
| synthesizer | glm-5.1 | No | No | - | No | Expert at turning findings into reports |
| critic | glm-5.1 | No | No | - | No | Rigorous quality reviewer |

### Category 3: Deep Think Agents (4 agents)

| ID | Model | Vision | Thinking | Tools | Memory | Description |
|----|-------|--------|----------|-------|--------|-------------|
| optimist | glm-5.1 | No | No | - | No | Strategic optimist for opportunities |
| devils-advocate | glm-5.1 | No | No | - | No | Critical pessimist for risk identification |
| pragmatist | glm-5.1 | No | No | - | No | Practical realist for feasibility |
| mediator | glm-5.1 | No | No | - | No | Balanced synthesizer of perspectives |

### Category 4: Operational Agents (3 agents)

| ID | Model | Vision | Thinking | Tools | Memory | Description |
|----|-------|--------|----------|-------|--------|-------------|
| config-auditor | glm-5.1 | No | No | - | No | Configuration drift auditor |
| log-analyzer | glm-5.1 | No | No | - | No | Log analysis specialist |
| commit-reviewer | glm-5.1 | No | No | - | No | Git commit review specialist |

### Category 5: Surveillance Agent (1 agent)

| ID | Model | Vision | Thinking | Tools | Memory | Description |
|----|-------|--------|----------|-------|--------|-------------|
| guardian-sentinel | glm-5.1 | No | No | - | No | Continuous system monitoring and alerting |

### Category 6: OWUI-Backed Agents (3 agents)

| ID | Model | Vision | Thinking | Tools | Memory | Description |
|----|-------|--------|----------|-------|--------|-------------|
| owui-analyst | owui-expert-analyste | No | No | - | No | OWUI Expert Analyst (requires OWUI API key) |
| owui-writer | owui-redacteur-technique | No | No | - | No | OWUI Technical Writer (requires OWUI API key) |
| owui-vision | owui-vision-expert | Yes | No | - | No | OWUI Vision Expert (requires OWUI API key) |

---

## Conversations

| ID | Type | Agents | Rounds | Description |
|----|------|--------|--------|-------------|
| deep-search | magentic | researcher, synthesizer, critic | 10 | Multi-agent deep research with search, synthesis, critical review |
| deep-think | group_chat | optimist, devils-advocate, pragmatist, mediator | 8 | Multi-perspective deliberation with diverse viewpoints |
| code-review | group_chat | (4 inline agents) | 6 | Multi-perspective code review with security, performance, maintainability |
| research-debate | sequential | (4 inline agents) | 4 | Research from opposing viewpoints then synthesize |
| config-harmonization | sequential | (4 inline agents) | 4 | Config drift deliberation |
| commit-review | sequential | commit-reviewer, devils-advocate, synthesizer | 3 | Structured code review in a git diff |
| task-allocation | group_chat | analyst, pragmatist, critic | 4 | Task allocation for GitHub issues |
| intelligent-task-dispatch | sequential | researcher, pragmatist, critic, synthesizer | 5 | Multi-perspective task analysis |

---

## MCP Plugins

| ID | Command | Description |
|----|---------|-------------|
| searxng | npx -y mcp-searxng | Web search via SearXNG |
| playwright | npx @anthropic/mcp-playwright | Browser automation and web scraping |

---

## Memory Collections

| Agent | Collection | Embeddings | Description |
|-------|-----------|------------|-------------|
| analyst | analyst-memory | qwen3-4b-awq-embedding | General analyst memory |
| researcher | researcher-memory | qwen3-4b-awq-embedding | Research findings memory |
| analyst-thinking | analyst-thinking-memory | qwen3-4b-awq-embedding | Thinking analyst memory |
| researcher-thinking | researcher-thinking-memory | qwen3-4b-awq-embedding | Thinking researcher memory |

---

## Infrastructure Endpoints

| Service | URL |
|---------|-----|
| z.ai Cloud API | https://api.z.ai/api/coding/paas/v4 |
| vLLM primary (OmniCoder) | http://myia-ai-01:5001/v1 |
| vLLM secondary (Qwen3.5) | http://myia-ai-01:5002/v1 |
| OWUI API | https://open-webui.myia.io/openai |
| Embeddings | https://embeddings.myia.io/v1 |
| Qdrant | https://qdrant.myia.io:443 |
| SearXNG | https://search.myia.io |

---

## Thinking Mode

**New in #894:** Models with `thinking: true` enable extended reasoning via `chat_template_kwargs: {"enable_thinking": true}` in the vLLM/z.ai request. This activates the model's internal chain-of-thought before producing the final response.

| Thinking Model | Base Model | Provider |
|---------------|------------|----------|
| glm-5.1-thinking | glm-5.1 | z.ai cloud |
| glm-4.6v-thinking | glm-4.6v | z.ai cloud |
| omnicoder-9b-thinking | omnicoder-9b | vLLM local |
| qwen3.5-35b-a3b-thinking | Qwen3.5-35B-A3B | vLLM local |
| glm-4.7-flash-thinking | glm-4.7-flash-fast | z.ai cloud |

---

## Usage Examples

### Single Agent Call
```
call_agent(prompt: "Analyze this architecture", agent: "analyst")
call_agent(prompt: "Describe this diagram", agent: "vision-analyst", attachment: "/path/to/image.png")
call_agent(prompt: "Quick question", agent: "fast")
call_agent(prompt: "Deep analysis needed", agent: "analyst-thinking")
call_agent(prompt: "Complex code review", agent: "coder-thinking")
```

### Multi-Agent Conversation
```
run_conversation(prompt: "Research RAG architectures", conversation: "deep-search")
run_conversation(prompt: "Should we migrate to microservices?", conversation: "deep-think")
run_conversation(prompt: "Review this PR", conversation: "code-review")
```

---

## References

- Issue #894: Enrich sk_agent with OWUI models (thinking/non-thinking) and z.ai models
- Issue #645: Phase 2 - Document Complete Agent Inventory
- Issue #485: sk-agent exploitation and enhancement
- Issue #566: Enrich sub-agents
- Documentation: docs/sk-agent/EXPLOITATION_REPORT_485.md
- Documentation: docs/services/sk-agent-deployment.md

---
**Last Updated:** 2026-04-03
**Author:** Roo Code (myia-web1)

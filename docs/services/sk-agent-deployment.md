# sk-agent Deployment Guide

**Owner:** roo-extensions workspace
**OWUI dependency:** 3 custom models (expert-analyste, redacteur-technique, vision-expert) managed by OWUI

## Architecture

- **stdio MCP** (Claude Code / Roo): Direct Python process via venv
- **HTTP container**: Docker on port 8100, reverse proxy `skagents.myia.io` (IIS, HTTPS)
- **Config**: `sk_agent_config.json` (gitignored, bind-mounted into container read-only)
- **Template**: `sk_agent_config.template.json` (git-tracked, placeholders)

## Quick Reference

| Component | Location |
|-----------|----------|
| Source code | `mcps/internal/servers/sk-agent/` |
| Config (live) | `mcps/internal/servers/sk-agent/sk_agent_config.json` |
| Config (template) | `mcps/internal/servers/sk-agent/sk_agent_config.template.json` |
| Dockerfile | `mcps/internal/servers/sk-agent/Dockerfile` |
| docker-compose | `mcps/internal/servers/sk-agent/docker-compose.sk-agent.yml` |
| venv (stdio) | `mcps/internal/servers/sk-agent/venv/` |
| Claude Code MCP | `.mcp.json` (project root) |
| Reverse proxy | IIS site `skagents.myia.io` -> `localhost:8100` |

## Agents (13)

| Agent | Model | Tools | Special |
|-------|-------|-------|---------|
| analyst | glm-4.7-flash | searxng | default, memory |
| vision-analyst | zwz-8b | - | vision, local |
| fast | glm-4.7-flash-fast | - | no thinking, 1-5s |
| researcher | glm-4.7-flash | searxng | memory |
| synthesizer | glm-4.7-flash | - | reports |
| critic | glm-4.7-flash | - | quality review |
| optimist | glm-4.7-flash | - | opportunities |
| devils-advocate | glm-4.7-flash | - | contrarian |
| pragmatist | glm-4.7-flash | - | implementation |
| mediator | glm-4.7-flash | - | consensus |
| owui-analyst | owui-expert-analyste | searxng | OWUI model, memory |
| owui-writer | owui-redacteur-technique | - | OWUI model |
| owui-vision | owui-vision-expert | - | OWUI model, vision |

## Multi-Agent Conversations (4)

| ID | Type | Agents | Rounds |
|----|------|--------|--------|
| deep-search | magentic | researcher -> synthesizer -> critic | 10 |
| deep-think | group_chat | optimist, devils-advocate, pragmatist, mediator | 8 |
| code-review | group_chat | 4 inline (security, perf, maintainability, synth) | 6 |
| research-debate | sequential | 4 inline (proponent, opponent, fact-checker, synth) | 4 |

## Operations

### Build Docker image

```bash
cd mcps/internal/servers/sk-agent
docker build -t sk-agent .
```

### Start/restart HTTP container

```bash
cd mcps/internal/servers/sk-agent
docker compose -f docker-compose.sk-agent.yml up -d --force-recreate
```

### Config change only (no code change)

```bash
cd mcps/internal/servers/sk-agent
docker compose -f docker-compose.sk-agent.yml up -d --force-recreate
```

### Check logs

```bash
docker logs sk-agent --tail 20
```

### Health check

```bash
curl -s -X POST https://skagents.myia.io/mcp \
  -H "Authorization: Bearer 181ecbaa03674f028e4dbb3c7efc8cb6" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

### Update venv (stdio mode)

```bash
cd mcps/internal/servers/sk-agent
venv/Scripts/pip install -r requirements.txt
```

## Environment

| Variable | Value | Source |
|----------|-------|--------|
| SK_AGENT_API_KEY | `181ecbaa03674f028e4dbb3c7efc8cb6` | docker-compose / myia.env |
| SK_AGENT_CONFIG | `/app/sk_agent_config.json` (container) | Dockerfile |
| SK_AGENT_PORT | `8100` | Dockerfile default |

## Infrastructure

| Service | URL | Port |
|---------|-----|------|
| HTTP endpoint | `https://skagents.myia.io/mcp` | 443 (IIS) -> 8100 |
| vLLM mini (zwz-8b) | `https://api.mini.text-generation-webui.myia.io/v1` | 5001 |
| vLLM medium (glm-4.7-flash) | `https://api.medium.text-generation-webui.myia.io/v1` | 5002 |
| OWUI API | `https://open-webui.myia.io/openai` | 2090 |
| Embeddings | `https://embeddings.myia.io/v1` | - |
| Qdrant | `https://qdrant.myia.io:443` | 6333 |
| SearXNG | `https://search.myia.io` | 8181 |

## OWUI Coordination

OWUI workspace (`D:\Open-WebUI\myia-open-webui\`) maintains:
- 3 custom OWUI models (expert-analyste, redacteur-technique, vision-expert)
- Tool Server registration in 7 OWUI tenants
- Entry in `docker-compose-myia.yaml` (references same container)
- `SK_AGENT_API_KEY` in `myia.env`

**Coordination channel:** RooSync cross-workspace (`myia-ai-01:roo-extensions` <-> `myia-ai-01:myia-open-webui`)

**Graceful degradation:** If OWUI models are unavailable, set `"enabled": false` on `owui-expert-analyste`, `owui-redacteur-technique`, `owui-vision-expert` in config. 10/13 agents remain functional.

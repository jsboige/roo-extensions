# sk-agent Deployment Guide

**Owner:** roo-extensions workspace
**Issue:** #3410 — counts derived from `sk_agent_config.template.json` (single source of truth)

> **Do not hand-edit counts.** Numbers below are auto-derived by
> `mcps/internal/servers/sk-agent/generate_inventory.py`. If you change the
> template config, regenerate. Drift is detected by `generate_inventory.py --check`
> and asserted by `test_inventory_validation.py`.

## Architecture

```text
                                          +---------------------+
                                          |  sk_agent_config    |
                                          |  .template.json     |
                                          |  (canonical source) |
                                          +----------+----------+
                                                     |
                                +--------------------+--------------------+
                                |                                         |
                          stdio transport                          HTTP transport
                                |                                         |
                       FastMCP server                              Docker container
                       (sk_agent.py)                              (port 8100, HTTPS
                       Python process                              via IIS proxy)
                                |                                         |
        +-----------------------+--------------------+      +--------------+--------------+
        |                       |                    |      |              |              |
   Claude Code             Roo Code             Open WebUI   Claude Code   Open WebUI  LivresAgités
   (stdin/stdout)          (stdio MCP)          (stdio MCP)   (streamable-   (streamable- (RESTE-DIRECT
                                                      +       http)         http)        AI-Engine Pro,
                                                  HTTP                             WP plugin, 88 outils)
                                                  transport
                                                       |
                                                myia-mcp-proxy
                                                (auth 401 <120ms)
```

- **stdio MCP** (Claude Code / Roo Code): direct Python process via venv
- **HTTP container**: Docker on port 8100, reverse proxy `skagents.myia.io` (IIS, HTTPS), served via streamable-http MCP transport
- **Config**: `sk_agent_config.json` (gitignored, bind-mounted into container read-only)
- **Template**: `sk_agent_config.template.json` (git-tracked, placeholders)

## Canonical counts (derived from template config)

Re-derived by `python mcps/internal/servers/sk-agent/generate_inventory.py`.
Verified by `test_inventory_validation.py::test_template_counts_match_expected_baseline`.

| Metric | Count | Notes |
|--------|-------|-------|
| **Models** | 16 | 12 enabled, 4 disabled (z.ai cloud 6, vLLM direct 3, OWUI proxy 4, OWUI custom 3) |
| **Top-level agents** | 32 | Across 5 functional groups (core, deep-search, deep-think, operational, PR-review, surveillance, OWUI) |
| **Inline agents** (conversation-scoped) | 15 | Defined inside `code-review`, `research-debate`, `config-harmonization`, `pr-review-tier1/2/3` |
| **Memory-enabled agents** | 5 | `analyst`, `analyst-glm5`, `researcher`, `guardian-sentinel`, `owui-analyst` |
| **MCP plugins** | 5 | `searxng`, `playwright`, `sk_agent` (self-inclusion), `open_terminal`, `markitdown` |
| **Conversations** | 11 | `magentic`: 1, `group_chat`: 5, `sequential`: 5 |

See `docs/sk-agent/AGENT_INVENTORY.md` for the full per-ID list.

## Transports

sk-agent exposes the same MCP tools over **two transports**. Pick the one that
matches your consumer.

### Transport 1 — stdio MCP (process-local)

The default for **Claude Code**, **Roo Code**, and **Open WebUI** when registered
as a stdio MCP server. No networking involved: the client spawns the Python
process, talks JSON-RPC over stdin/stdout.

| Property | Value |
|----------|-------|
| Protocol | MCP stdio (JSON-RPC over stdin/stdout) |
| Process | `python sk_agent.py` (from the venv) |
| Network | none |
| Auth | none (process-local) |
| Clients | Claude Code, Roo Code, Open WebUI (Tool Server entry) |
| Endpoint | n/a |

#### Consumer: Claude Code (user scope)

```json
// ~/.claude.json → mcpServers.sk-agent
{
  "command": "python",
  "args": ["D:/dev/roo-extensions/mcps/internal/servers/sk-agent/sk_agent.py"],
  "env": {
    "SK_AGENT_CONFIG": "D:/dev/roo-extensions/mcps/internal/servers/sk-agent/sk_agent_config.json"
  }
}
```

> **NEVER** register sk-agent at project scope (`.mcp.json`). User scope
> keeps the same config across all workspaces and avoids double-loading.

#### Consumer: Roo Code (stdio MCP)

```powershell
# In Roo MCP settings (mcp_settings.json)
{
  "sk-agent": {
    "command": "python",
    "args": ["D:/dev/roo-extensions/mcps/internal/servers/sk-agent/sk_agent.py"],
    "env": { "SK_AGENT_CONFIG": "D:/dev/roo-extensions/mcps/internal/servers/sk-agent/sk_agent_config.json" }
  }
}
```

### Transport 2 — streamable-http MCP (networked)

The default for **shared multi-machine access**. Runs in Docker, exposes the
MCP streamable-http endpoint on port 8100, fronted by IIS at `https://skagents.myia.io/mcp`.
Auth is enforced (`401` on unauthenticated probes — see matrix).

| Property | Value |
|----------|-------|
| Protocol | MCP streamable-http (JSON-RPC over HTTPS POST) |
| Container | `sk-agent` (Docker, port 8100) |
| Reverse proxy | IIS site `skagents.myia.io` → `localhost:8100` |
| Auth | Bearer token `SK_AGENT_API_KEY` (shared secret in `myia.env`) |
| Clients | Claude Code (streamable-http), Open WebUI (Tool Server), LivresAgités (RESTE-DIRECT), myia-mcp-proxy |

#### Consumer: Claude Code (streamable-http)

```json
// .mcp.json (project scope) — only if user-scope stdio not available
{
  "mcpServers": {
    "sk-agent": {
      "type": "streamable-http",
      "url": "https://skagents.myia.io/mcp",
      "headers": {
        "Authorization": "Bearer ${SK_AGENT_API_KEY}"
      }
    }
  }
}
```

#### Consumer: myia-mcp-proxy (gateway)

The `myia-mcp-proxy` container fronts multiple streamable-http MCP servers
(including sk-agent) behind a single auth-bearing endpoint. Probes from
all 7 machines return `401 <120 ms` — auth is enforced.

#### Health check (HTTP)

```bash
# Authenticated — returns the tool list as a 200 response
curl -s -X POST https://skagents.myia.io/mcp \
  -H "Authorization: Bearer $SK_AGENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

# Unauthenticated — returns 401
curl -i https://skagents.myia.io/mcp
```

## Recipes

> Every recipe below is **stand-alone** — copy/paste, swap API keys,
> run. Recipes are not tied to specific config versions.

### Recipe 1 — Lightweight agent (no tools, fastest responses)

Use case: quick classification, triage, "yes/no" routing. No MCP overhead.

```json
{
  "id": "triage",
  "description": "Fast yes/no classification — no tools, no thinking",
  "model": "qwen3.6-35b-no-thinking",
  "system_prompt": "Reply with one of: YES, NO, MAYBE, NEED_INFO. Be concise.",
  "mcps": [],
  "memory": { "enabled": false }
}
```

Invoke:

```text
call_agent(prompt: "Is this PR a bug fix or a feature?", agent: "triage")
```

### Recipe 2 — Research agent with web search + memory

Use case: investigative queries that benefit from persistence across calls.
Memory collection: `research-memory`.

```json
{
  "id": "researcher",
  "description": "Investigative researcher with web search and memory",
  "model": "glm-5.1",
  "system_prompt": "You are a meticulous investigator. Decompose queries, search each independently, cross-reference sources. Cite URLs.",
  "mcps": ["searxng", "playwright", "markitdown"],
  "memory": { "enabled": true, "collection": "research-memory" }
}
```

### Recipe 3 — Sandboxed coding agent (terminal access)

Use case: run shell commands inside an isolated environment. Uses the
`open_terminal` MCP (mounted volume, restricted scope).

```json
{
  "id": "coder",
  "description": "Agentic coding with terminal access",
  "model": "qwen3.6-35b-no-thinking",
  "system_prompt": "You are an agentic coding assistant. Plan, implement, verify. Use terminal to run commands.",
  "mcps": ["open_terminal", "searxng"],
  "memory": { "enabled": false }
}
```

### Recipe 4 — Custom conversation (à la carte multi-agent)

Use case: a one-off conversation pattern you don't want to keep.
Define inline agents in the conversation itself — no top-level pollution.

```json
{
  "id": "my-custom-review",
  "description": "Two-pass review: optimistic pass, then critical pass",
  "type": "sequential",
  "agents": ["optimistic-reviewer", "critical-reviewer"],
  "max_rounds": 2,
  "inline_agents": [
    {
      "id": "optimistic-reviewer",
      "description": "Looks for strengths first",
      "model": "glm-5.1-fast",
      "system_prompt": "You find strengths. Acknowledge what works."
    },
    {
      "id": "critical-reviewer",
      "description": "Then identifies risks",
      "model": "glm-5.1-fast",
      "system_prompt": "You find flaws, gaps, and risks."
    }
  ]
}
```

Invoke:

```text
run_conversation(prompt: "Review this PR", conversation: "my-custom-review")
```

### Recipe 5 — Switching from stdio to HTTP

If your client supports both, the **migration is config-only**:

| Client | stdio | HTTP (streamable) |
|--------|-------|-------------------|
| Claude Code | `~/.claude.json` mcpServers entry | `.mcp.json` (project) with `type: "streamable-http"` |
| Roo Code | `mcp_settings.json` `command`/`args` | not natively supported (use stdio) |
| Open WebUI | Tool Server (Process) | Tool Server (HTTP) |
| LivresAgités | n/a | AI-Engine Pro plugin (RESTE-DIRECT, not sk-agent) |

There is no behavioural difference: both transports expose the same 9 MCP
tools with the same JSON-RPC schema.

## Operations

### Config Sync (Issue #1416)

**IMPORTANT:** After any `git pull` that updates `sk_agent_config.template.json`, sync the active config:

```powershell
cd mcps\internal\servers\sk-agent
.\deploy-sk-agent.ps1 -UpdateFromTemplate
```

This preserves your API keys while merging in template changes. See `docs/roosync/deployment/sk-agent.md` for details.

### Build Docker image (HTTP transport)

```bash
cd mcps/internal/servers/sk-agent
docker build -t sk-agent .
```

### Start/restart HTTP container

```bash
cd mcps/internal/servers/sk-agent
docker compose -f docker-compose.sk-agent.yml up -d --force-recreate
```

> **Post-hardening:** after merging #3417 (submod bump for HTTP hardening
> #1085), the container **must** be `--force-recreate`d (not `restart`) so the
> new env-injected bearer key takes effect.

### Config change only (no code change)

```bash
cd mcps/internal/servers/sk-agent
docker compose -f docker-compose.sk-agent.yml up -d --force-recreate
```

### Check logs

```bash
docker logs sk-agent --tail 20
```

### Update venv (stdio mode)

```bash
cd mcps/internal/servers/sk-agent
venv/Scripts/pip install -r requirements.txt
```

## Environment

| Variable | Value | Source |
|----------|-------|--------|
| `SK_AGENT_API_KEY` | `<in myia.env, not committed>` | docker-compose / myia.env (HTTP transport only) |
| `SK_AGENT_CONFIG` | `/app/sk_agent_config.json` (container) or local path (stdio) | Dockerfile / MCP client config |
| `SK_AGENT_PORT` | `8100` | Dockerfile default |
| `ZAI_API_KEY` | `<in myia.env, not committed>` | z.ai cloud models |
| `EMBEDDINGS_API_KEY` | `<in myia.env, not committed>` | embeddings.myia.io |
| `OPEN_TERMINAL_API_KEY` | `<in myia.env, not committed>` | open-terminal-mcp sidecar |

## Infrastructure

| Service | URL | Port |
|---------|-----|------|
| HTTP endpoint (HTTPS) | `https://skagents.myia.io/mcp` | 443 (IIS) → 8100 (Docker) |
| LAN HTTP (no TLS) | `http://192.168.0.47:8100/mcp` | 8100 (Docker, fleet access) |
| myia-mcp-proxy | `http://192.168.0.47:9092` | 9092 (auth-bearing gateway) |
| vLLM mini (OmniCoder) | `https://api.mini.text-generation-webui.myia.io/v1` | 5001 |
| vLLM medium (Qwen3.6 35B) | `https://api.medium.text-generation-webui.myia.io/v1` | 5002 |
| OWUI API | `https://open-webui.myia.io/openai` | 2090 |
| Embeddings | `https://embeddings.myia.io/v1` | — |
| Qdrant | `https://qdrant.myia.io:443` | 6333 |
| SearXNG | `https://search.myia.io` | 8181 |

## OWUI Coordination

OWUI workspace (`D:\Open-WebUI\myia-open-webui\`) maintains:
- 3 custom OWUI models (`expert-analyste`, `redacteur-technique`, `vision-expert`)
- Tool Server registration across OWUI tenants
- Entry in `docker-compose-myia.yaml` (references same container)
- `SK_AGENT_API_KEY` in `myia.env`

**Coordination channel:** RooSync cross-workspace (`myia-ai-01:roo-extensions` ↔ `myia-ai-01:myia-open-webui`)

**Graceful degradation:** If OWUI models are unavailable, set `"enabled": false`
on `owui-expert-analyste`, `owui-redacteur-technique`, `owui-vision-expert`,
`owui-qwen3.6-35b`, `owui-omnicoder-9b`, `owui-glm-4.7-flash-fast`,
`owui-glm-4.7-flash-thinking` in config. **The 3 owui-* top-level agents
(`owui-analyst`, `owui-writer`, `owui-vision`) and `coder-local` /
`vision-local-owui` (which use `owui-qwen3.6-35b`) become non-functional —
that is 5 agents, not 3.** Verify enabled-only counts via
`python mcps/internal/servers/sk-agent/generate_inventory.py --json-out`.

## Related documentation

- `docs/sk-agent/AGENT_INVENTORY.md` — full per-ID agent/model/MCP/conversation list (auto-generated)
- `docs/services/sk-agent-streamable-http-rollout.md` — rollout plan for streamable-http transport (PR #3418)
- `mcps/internal/servers/sk-agent/README.md` — internal API and v2 config schema reference
- `mcps/internal/servers/sk-agent/sk_agent_config.py` — schema definition and validator
- `mcps/internal/servers/sk-agent/generate_inventory.py` — doc generator + drift checker
- `mcps/internal/servers/sk-agent/test_inventory_validation.py` — pytest assertions for inventory/template/README consistency

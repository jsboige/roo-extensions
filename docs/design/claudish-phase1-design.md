# Claudish Unified Model Router — Phase 1 Design

**Issue:** #1769
**Date:** 2026-05-11
**Author:** Claude Code (myia-po-2023, R27)
**Status:** Draft — needs approval

---

## Executive Summary

Deploy claudish as the unified model routing layer for the Myia cluster. **Key architectural correction:** claudish is a per-session CLI wrapper (not a persistent centralized proxy). The deployment model is **per-machine installation with shared configuration**, not a single centralized server.

---

## Architecture

### How Claudish Works

```
claudish --model zai@glm-5.1 "implement feature X"
  ↓
1. Parse args, resolve model routing
2. Start local Hono proxy on http://127.0.0.1:RANDOM_PORT
3. Spawn: claude --env ANTHROPIC_BASE_URL=http://127.0.0.1:RANDOM_PORT
4. Proxy translates: Anthropic API format ↔ Provider API format
5. Stream output in real-time
6. Cleanup proxy on exit
```

Each `claudish` invocation is isolated: unique port, own proxy instance, independent Claude Code process. The proxy dies when the session ends.

### Corrected Deployment Model

**Original #1769 assumption:** Centralized proxy on po-2023 via `models.myia.io` subdomain.
**Actual claudish design:** Per-machine CLI wrapper with shared profile definitions.

```
┌─────────────────────────────────────────────────┐
│ Per Machine (all 6 machines)                    │
│                                                  │
│  claudish binary (npm install -g)                │
│  ~/.claudish/config.json (shared profile defs)   │
│  Environment: ZAI_API_KEY, ZHIPU_API_KEY, etc.  │
│                                                  │
│  Usage:                                          │
│    claudish --model zai@GLM-5.1  (replaces claude)│
│    claudish --profile executor    (role-based)   │
└─────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
   z.ai API (GLM)     Anthropic API (Opus)
  (executor default)   (ai-01 default)
```

### Why Not Centralized Proxy

| Aspect | Centralized Proxy | Per-Machine CLI |
|--------|------------------|-----------------|
| Latency | +1 hop (client → proxy → provider) | Direct (client → provider) |
| SPOF | Yes (proxy down = fleet down) | No (isolated per machine) |
| Complexity | IIS reverse proxy + TLS + subdomain | `npm install -g` |
| Session isolation | Shared proxy = potential conflicts | Per-session port = isolated |
| Config management | Central (1 config to update) | Distributed (6 configs to sync) |
| Monitoring | Central (1 place for logs) | Per-machine (needs aggregation) |

**Recommendation:** Per-machine CLI deployment. Use RooSync config sync to distribute shared profile definitions. Reserve centralized proxy (IIS reverse proxy to a persistent claudish instance) as Phase 2 exploration if fleet-wide observability is needed.

---

## Profiles for Myia Cluster

### Profile: `executor` (po-2023/24/25/26, web1)

```json
{
  "name": "executor",
  "models": {
    "opus": "zai@GLM-5.1",
    "sonnet": "zai@GLM-4.7",
    "haiku": "zai@GLM-4.7-Flash",
    "subagent": "zai@GLM-4.5-Air"
  }
}
```

Maps Claude Code's role system (opus/sonnet/haiku/subagent) to z.ai GLM models. No credit pressure on z.ai paid plan.

### Profile: `coordinator` (ai-01)

```json
{
  "name": "coordinator",
  "models": {
    "opus": "anthropic@claude-opus-4-7",
    "sonnet": "anthropic@claude-sonnet-4-6",
    "haiku": "zai@GLM-4.7-Flash",
    "subagent": "zai@GLM-4.5-Air"
  }
}
```

ai-01 uses Anthropic for primary tasks, z.ai for haiku/subagent to optimize credits.

### Profile: `premium` (switching ai-01 to premium mode)

```json
{
  "name": "premium",
  "models": {
    "opus": "anthropic@claude-opus-4-7",
    "sonnet": "anthropic@claude-sonnet-4-6",
    "haiku": "anthropic@claude-haiku-4-5",
    "subagent": "anthropic@claude-haiku-4-5"
  }
}
```

### Profile: `local-only` (offline/fallback)

```json
{
  "name": "local-only",
  "models": {
    "opus": "ollama@qwen3-coder:32b",
    "sonnet": "ollama@qwen3-coder:14b",
    "haiku": "ollama@qwen3-coder:7b",
    "subagent": "ollama@qwen3-coder:7b"
  }
}
```

### Profile: `free-tour` (experimental, cost-free)

```json
{
  "name": "free-tour",
  "models": {
    "opus": "zen@glm-5",
    "sonnet": "oc@qwen3-next",
    "haiku": "google@gemini-2.0-flash",
    "subagent": "google@gemini-2.0-flash"
  }
}
```

Uses free-tier providers (OpenCode Zen, OllamaCloud, Google free tier).

---

## Integration Points

### Claude Code Integration

**Current:** `claude` CLI → Anthropic API directly
**With claudish:** `claudish --profile executor` → starts proxy → spawns claude → routes to z.ai

```bash
# Replace current invocation
# OLD: claude "implement feature X"
# NEW: claudish --profile executor "implement feature X"

# Or via environment (for scheduled workers)
export CLAUDISH_MODEL="zai@GLM-5.1"
export CLAUDE_CODE_SUBAGENT_MODEL="zai@GLM-4.5-Air"
claudish "implement feature X"
```

**For scheduled workers** (`start-claude-worker.ps1`):
- Add `--profile executor` flag to worker invocation
- Or set `CLAUDISH_MODEL` + `CLAUDISH_MODEL_SUBAGENT` env vars
- Worker script may need minor modification to use `claudish` instead of `claude`

### Roo Code Integration

Roo Code uses OpenAI-compatible format. claudish translates Anthropic → provider, but does NOT expose an OpenAI-compatible endpoint that Roo can connect to.

**Options for Roo:**
1. **Keep current setup** — Roo already connects to z.ai directly via `OPENAI_BASE_URL`. No change needed.
2. **Use claudish for cost tracking** — Run `claudish --monitor` alongside Roo to log traffic.
3. **Wait for claudish OpenAI endpoint** — Upstream feature request.

**Recommendation:** Keep Roo on direct z.ai connection. claudish adds no value for Roo's OpenAI-format usage.

### MCP Integration

claudish has `--mcp` mode to run as an MCP server. This could coexist with roo-state-manager but adds complexity with marginal benefit. **Out of scope for Phase 1.**

---

## Deployment Plan (Phase 1)

### Step 1: Install claudish on po-2023 (pilot machine)

```bash
npm install -g claudish
claudish --version  # Verify installation
```

**Prerequisites:** Node.js v25.2.1 (already installed), npm 11.6.0 (already installed).

### Step 2: Configure profiles

Create `~/.claudish/config.json`:

```json
{
  "version": "1.0.0",
  "defaultProfile": "executor",
  "profiles": {
    "executor": {
      "name": "executor",
      "models": {
        "opus": "zai@GLM-5.1",
        "sonnet": "zai@GLM-4.7",
        "haiku": "zai@GLM-4.7-Flash",
        "subagent": "zai@GLM-4.5-Air"
      }
    },
    "coordinator": {
      "name": "coordinator",
      "models": {
        "opus": "anthropic@claude-opus-4-7",
        "sonnet": "anthropic@claude-sonnet-4-6",
        "haiku": "zai@GLM-4.7-Flash",
        "subagent": "zai@GLM-4.5-Air"
      }
    }
  },
  "routing": {
    "glm-*": ["gc", "glm"],
    "*": ["zai"]
  }
}
```

### Step 3: Configure API keys

In `~/.claudish/.env` or system environment:

```bash
ZAI_API_KEY=<existing z.ai key>
ZHIPU_API_KEY=<existing Zhipu key>
ANTHROPIC_API_KEY=sk-ant-api03-placeholder  # Suppress login dialog
```

### Step 4: Validate

```bash
# Test basic routing
claudish --model zai@GLM-5.1 "echo hello world"

# Test profile
claudish --profile executor "list current directory"

# Test cost tracking
claudish --cost-tracker --profile executor "what is 2+2?"

# Benchmark latency
time claudish --profile executor --json "respond with OK" 2>&1 | jq '.duration_ms'
```

### Step 5: Fleet rollout (after pilot validation)

```bash
# On each machine:
npm install -g claudish

# Sync config via RooSync config management:
roosync_config(action: "collect", targets: ["claudish-config"])
roosync_config(action: "apply", targets: ["claudish-config"])
```

---

## Validation Criteria

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| Basic routing | GLM-5.1 responds via z.ai | `claudish --model zai@GLM-5.1 "test"` |
| Profile mapping | opus→GLM-5.1, haiku→GLM-4.7-Flash | `claudish --profile executor --json "test"` |
| Latency overhead | <100ms vs direct z.ai | Compare `time claudish` vs `time curl z.ai API` |
| Cost tracking | Shows $0.00+ per request | `--cost-tracker` flag |
| Streaming | Real-time output | Interactive session test |
| Fallback | Graceful degradation if primary down | Simulate provider failure |
| Claude Code compat | All features work (tools, agents, etc.) | Full executor session |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| claudish proxy crashes mid-session | Session lost | Claudish auto-cleanup; restart session |
| API key exposure | Security | Keys in env vars only, never in git |
| Provider-specific quirks | Compatibility | Test each profile before fleet rollout |
| Worker script integration | Breaking change | Phase 1: interactive only. Workers stay on direct API |
| Context window mismatch | Quality | claudish dual-accounting handles this automatically |
| z.ai rate limits through proxy | Throttling | Monitor mode + fallback chains |

---

## Out of Scope (Phase 1)

- Centralized IIS reverse proxy / subdomain (`models.myia.io`)
- Roo Code integration (keeps direct z.ai connection)
- MCP server mode
- Worker script modification (`start-claude-worker.ps1`)
- Free-tier rotation (custom routing rules, Phase 2)
- Fleet-wide cost aggregation dashboard
- Automatic profile switching for ai-01

---

## Sequence Diagram: Executor Session

```
User         Claude Code CLI    Claudish Proxy     z.ai API
 │                │                   │                │
 │ claudish       │                   │                │
 │ --profile      │                   │                │
 │ executor       │                   │                │
 │ "implement X"  │                   │                │
 │───────────────>│                   │                │
 │                │ Start proxy       │                │
 │                │ :RANDOM_PORT      │                │
 │                │──────────────────>│                │
 │                │                   │                │
 │                │ ANTHROPIC_BASE    │                │
 │                │ URL=localhost:PORT│                │
 │                │ Spawn claude CLI  │                │
 │                │<──────────────────│                │
 │                │                   │                │
 │                │ POST /v1/messages │                │
 │                │ (Anthropic format)│                │
 │                │──────────────────>│                │
 │                │                   │ Translate to   │
 │                │                   │ OpenAI format  │
 │                │                   │───────────────>│
 │                │                   │                │
 │                │                   │ SSE response   │
 │                │                   │<───────────────│
 │                │                   │                │
 │                │ SSE (Anthropic)   │ Translate      │
 │                │<──────────────────│ back           │
 │                │                   │                │
 │<───────────────│ Display output    │                │
 │                │                   │                │
 │                │ Cleanup proxy     │                │
 │                │──────────────────>│                │
```

---

## Next Steps (Phase 2, post-validation)

1. Centralized proxy exploration: persistent claudish instance + IIS reverse proxy
2. Worker script integration: `start-claude-worker.ps1` uses claudish
3. Free-tier rotation: custom routing rules for cost optimization
4. Fleet-wide cost dashboard: aggregate `--cost-tracker` data
5. Roo Code integration: if claudish adds OpenAI-compatible endpoint

---

**Sources:**
- [MadAppGang/claudish](https://github.com/MadAppGang/claudish) — README analyzed 2026-05-11
- [docs/investigation/unified-model-router.md](../investigation/unified-model-router.md) — Comparative analysis (2026-04-27)
- IIS reverse proxy patterns from existing po-2023 deployments (`qdrant.myia.io`, `mcp-tools.myia.io`)

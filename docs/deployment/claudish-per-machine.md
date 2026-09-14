# Claudish Fleet Deployment — Per-Machine Config

**Issue:** #1770, #1769
**Date:** 2026-05-14

## Base Config

> ⚠ **Superseded — this document is a 2026-05-14 plan, kept for history.** The profile names, providers and API keys below (free-tier gemini/groq/cerebras, `coordinator`, `GEMINI_API_KEY`…) are not what the fleet runs.
>
> `docs/deployment/claudish-fleet-config.json` is a snapshot of the same date (its only commit: `74371eb83`, 2026-05-14) and is **not** the live source. Measured on po-203, 2026-09-13: the live `~/.claudish/config.json` carries entirely different profiles (`default`, `ai-01`), a different `defaultProfile`, a different `routing` table, and provider keys this repo file does not hold. **Do not `cp` the snapshot over a live config** — the snapshot carries none of `apiKeys`, `customEndpoints`, `endpoints` or `providerConcurrency`, while the live config (measured on ai-01, 2026-09-13) carries all four families: copying it stomps active machine settings.
>
> The per-machine live config is the authority. Re-establishing a shared fleet config is open work, and it starts by reading each machine's current `~/.claudish/config.json` — a fleet-affecting change needs a measured per-consumer artifact before it is called done. On web1, `~/.claudish/` does not exist at all (measured 2026-09-14): the instruction would not even overwrite anything there, it would create a non-canonical copy next to that seat's actual claudish artifacts.

## Per-Machine Overrides

Each machine creates a `.claudish.json` (local) in the workspace directory to override `defaultProfile`.

### myia-ai-01 (Coordinator)

```json
{
  "defaultProfile": "coordinator"
}
```

**Why:** Coordinator stays on Anthropic for opus/sonnet. Uses z.ai for haiku/subagent to save credits.

### myia-po-2023 (Proxmox host, always on)

```json
{
  "defaultProfile": "free-tier"
}
```

**Why:** Always-on machine, primary free-tier guinea pig. Google AI Studio has highest daily limits (1,500 req/day).

### myia-po-2024 (Variety)

```json
{
  "defaultProfile": "free-tier"
}
```

**Why:** Different primary free provider (OpenRouter) for code review variety.

### myia-po-2025 (Speed)

```json
{
  "defaultProfile": "free-tier"
}
```

**Why:** Interactive dev — Groq's 300+ tok/s latency advantage for sonnet/haiku tasks.

### myia-po-2026 (Volume)

```json
{
  "defaultProfile": "free-tier"
}
```

**Why:** Scheduled workers — Cerebras' 1M tok/day volume for batch tasks.

### myia-web1 (Analysis)

```json
{
  "defaultProfile": "free-tier"
}
```

**Why:** Long-context analysis — Gemini 2.5 Pro's 1M context window for large codebases.

## API Keys Required

Each machine needs these env vars set (in `~/.claudish/.env` or system env):

| Key | Provider | Free Tier | Get At |
|-----|----------|-----------|--------|
| `GEMINI_API_KEY` | Google AI Studio | 1,500 req/day | https://aistudio.google.com/app/apikey |
| `OPENROUTER_API_KEY` | OpenRouter | 20 RPM free | https://openrouter.ai/keys |
| `GROQ_API_KEY` | Groq | 60 RPM, 1K req/day | https://console.groq.com |
| `OPENCODE_API_KEY` | OpenCode Zen | Optional (free models work without) | https://opencode.ai/ |
| `GLM_CODING_API_KEY` | GLM Coding Plan (z.ai) | Paid fallback | https://z.ai/subscribe |
| `ZAI_API_KEY` | Z.AI | Paid fallback | https://z.ai/ |

**Already provisioned on po-2023:** `ZAI_API_KEY`, `GLM_CODING_API_KEY`

**Needs user action:** `GEMINI_API_KEY`, `OPENROUTER_API_KEY`, `GROQ_API_KEY` — all free, no credit card required.

## Deployment Steps

### 1. Install claudish on each machine

```bash
npm install -g claudish
claudish --version  # Verify
```

### 2. ~~Deploy base config~~ — retired, do not run

The copy below **overwrites a machine's working config with a 2026-05-14 snapshot**. It is kept only so the old procedure is recognisable:

```bash
# RETIRED — would clobber the live config with a stale snapshot
# cp docs/deployment/claudish-fleet-config.json ~/.claudish/config.json

# What to do instead — read the machine's actual config:
cat ~/.claudish/config.json
```

### 3. Set API keys

Create `~/.claudish/.env`:

```
GEMINI_API_KEY=<from user>
OPENROUTER_API_KEY=<from user>
GROQ_API_KEY=<from user>
OPENCODE_API_KEY=<optional>
GLM_CODING_API_KEY=<existing>
ZAI_API_KEY=<existing>
```

### 4. Deploy per-machine local config

```bash
# In the workspace directory, create .claudish.json with profile override
echo '{"defaultProfile":"free-tier"}' > /path/to/workspace/.claudish.json
```

### 5. Validate

```bash
# Test free-tier routing
claudish --profile free-tier --cost-tracker "echo hello world"

# Test fallback
claudish --model google@gemini-2.5-pro "test"  # should route to Google
claudish --model groq@qwen3-32b "test"          # should route to Groq
claudish --profile executor "test"              # should route to z.ai GLM

# Check model resolution
claudish --models --free
```

## Routing Behavior

```
Request arrives with role (opus/sonnet/haiku/subagent)
  → Profile maps role to model (e.g., opus → google@gemini-2.5-pro)
  → Routing rules checked:
    gemini-2.5-pro → ["google", "openrouter@google/gemini-2.5-pro-preview-06-05"]
  → Try primary: Google API
    → 429/403? Try next: OpenRouter
    → All failed? Error with instructions
```

## Monitoring

```bash
# Cost tracking (tracks token usage per provider)
claudish --cost-tracker --profile free-tier "task"

# Audit costs
claudish --audit-costs

# List available models
claudish --models --free  # Only free models
claudish --top-models     # Curated recommendations
```

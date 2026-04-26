# Unified Model Router — Comparative Analysis

**Issue:** #1730
**Date:** 2026-04-27
**Author:** Claude Code (myia-po-2025)
**Context:** Multi-provider LLM routing for Claude Code CLI + Roo Code across 6 machines

---

## Executive Summary

Five candidates evaluated for a unified model router supporting Anthropic + z.ai + local models with profile-based routing, free-tier round-robin, fallback chains, and compatibility with both Claude Code CLI and Roo Code.

**Recommendation:** **claudish** (MadAppGang) as primary solution. **LiteLLM** (BerriAI) as enterprise alternative if Python dependency is acceptable.

| Candidate | Language | Verdict | Match Score |
|-----------|----------|---------|-------------|
| **claudish** | Node.js/Bun | **RECOMMENDED** — purpose-built for Claude Code, profiles, fallback chains, 580+ models | 9/10 |
| **LiteLLM** | Python | Strong alternative — enterprise-grade, 100+ providers, AI Gateway | 7/10 |
| **claude-code-router** | Node.js/Bun | Moderate — context-type routing, presets, but limited provider support | 5/10 |
| **LLMProxy** | C#/.NET 9 | Weak — no Anthropic passthrough, no profile system | 3/10 |
| **y-router** | Cloudflare Worker | **ARCHIVED** — too minimal, replaced by OpenRouter native | 1/10 |

---

## Requirements (from issue #1730)

| # | Requirement | Priority |
|---|-------------|----------|
| 1 | Multi-provider routing (Anthropic, z.ai, local models) | Critical |
| 2 | Profile system (free-tour, premium, local-only) mapping model roles to providers | Critical |
| 3 | Round-robin free-tier rotation across providers | High |
| 4 | Fallback chains (primary → fallback → emergency) | High |
| 5 | Claude Code CLI compatibility (Anthropic Messages API format) | Critical |
| 6 | Roo Code compatibility (OpenAI Chat Completions format) | Critical |
| 7 | API format translation (Anthropic ↔ OpenAI) | Critical |
| 8 | Cost tracking per provider/profile | Medium |
| 9 | Extended thinking parameter translation across providers | Medium |
| 10 | Vision proxy for non-vision models | Low |

---

## Detailed Candidate Analysis

### 1. claudish (MadAppGang) — RECOMMENDED

**Repo:** [MadAppGang/claudish](https://github.com/MadAppGang/claudish)
**License:** MIT | **Language:** Node.js/Bun | **Version:** v7.0+

#### Strengths

- **Purpose-built for Claude Code** — designed as a drop-in proxy replacing the Anthropic API endpoint
- **Profile system with role mapping** — maps `opus`/`sonnet`/`haiku`/`subagent` roles to specific provider+model combos. Directly supports our free-tour/premium/local-only profile concept
- **Routing syntax** — `provider@model[:concurrency]` with custom rules using glob patterns and fallback chains
- **580+ models** via OpenRouter + direct API access (Google, OpenAI, MiniMax, Kimi, GLM, Z.AI, OllamaCloud, local Ollama/LM Studio/vLLM/MLX)
- **Extended thinking translation** — maps Claude thinking budgets to provider-specific reasoning parameters (DeepSeek, GLM, Kimi, QwQ, etc.)
- **Vision proxy** — auto-describes images for non-vision models using vision-capable models
- **Context scaling** — dual-accounting for token counting to handle varying context window sizes across providers
- **Cost tracking** — per-request cost calculation with monitor mode
- **MCP server mode** — can run as an MCP server alongside other tools
- **Claude Code flag passthrough** — `--init` installs skills directly, JSON output mode, custom endpoints
- **Active development** — v7.0+ with regular updates

#### Gaps

- No built-in round-robin for free-tier rotation (would need custom routing rules)
- Admin UI is minimal (monitor mode only, no web dashboard)
- Documentation is in README only (no dedicated docs site)

#### Compatibility Matrix

| Requirement | Support |
|-------------|---------|
| Multi-provider routing | Full — 580+ models, direct + OpenRouter |
| Profile system | Full — role mapping (opus/sonnet/haiku/subagent) |
| Round-robin | Partial — achievable via custom routing rules |
| Fallback chains | Full — `provider@model` syntax with fallback |
| Claude Code CLI | Full — designed as drop-in Anthropic proxy |
| Roo Code | Full — OpenAI-compatible endpoint available |
| API translation | Full — Anthropic ↔ OpenAI bidirectional |
| Cost tracking | Full — per-request with monitor mode |
| Extended thinking | Full — cross-provider thinking budget mapping |
| Vision proxy | Full — auto-describe for non-vision models |

---

### 2. LiteLLM (BerriAI) — Enterprise Alternative

**Repo:** [BerriAI/litellm](https://github.com/BerriAI/litellm)
**License:** MIT | **Language:** Python | **Stars:** 20k+

#### Strengths

- **Enterprise-grade** — production-tested, 100+ LLM providers, extensive documentation
- **AI Gateway proxy server** — OpenAI-compatible endpoint with provider routing
- **Cost tracking** — detailed spend analytics, budget limits per team/key
- **Load balancing** — built-in round-robin, least-busy, latency-based routing
- **Virtual keys** — API key management, team budgets, rate limiting
- **Admin dashboard** — web UI for monitoring, analytics, configuration
- **Fallback chains** — model-level fallback with configurable retry logic
- **Streaming support** — full SSE streaming passthrough

#### Gaps

- **Python dependency** — adds a Python runtime requirement to our Node.js stack
- **Not Claude Code-specific** — generic LLM proxy, requires configuration for Claude Code protocol quirks
- **No profile system** — routing is model-level, not role-based. Would need custom abstraction layer
- **No extended thinking translation** — no cross-provider thinking budget mapping
- **No vision proxy** — no auto-describe for non-vision models
- **Heavy resource footprint** — designed for server deployment, not lightweight local proxy

#### Compatibility Matrix

| Requirement | Support |
|-------------|---------|
| Multi-provider routing | Full — 100+ providers |
| Profile system | None — would need custom abstraction |
| Round-robin | Full — built-in load balancing |
| Fallback chains | Full — configurable model fallbacks |
| Claude Code CLI | Partial — OpenAI endpoint works, Anthropic protocol needs config |
| Roo Code | Full — OpenAI-compatible endpoint |
| API translation | Full — unified OpenAI format |
| Cost tracking | Full — enterprise-grade analytics |
| Extended thinking | None — no cross-provider mapping |
| Vision proxy | None |

---

### 3. claude-code-router (musistudio) — Moderate

**Repo:** [musistudio/claude-code-router](https://github.com/musistudio/claude-code-router)
**License:** MIT | **Language:** Node.js/Bun

#### Strengths

- **Claude Code-specific** — routing by context type (default, background, think, longContext, webSearch, image)
- **Preset system** — define model assignments per context type
- **Subagent routing** — `<CCR-SUBAGENT-MODEL>` tag-based routing for subagents
- **Sponsored by Z.ai** — first-class z.ai integration

#### Gaps

- **No built-in fallback chains** — preset-based, no automatic failover
- **No profile system** — no concept of free-tour/premium/local-only profiles
- **No round-robin** — static routing per context type
- **Limited provider support** — primarily Z.ai, no local model support documented
- **No cost tracking**
- **No vision proxy**

---

### 4. LLMProxy (obirler) — Weak

**Repo:** [obirler/LLMProxy](https://github.com/obirler/LLMProxy)
**License:** MIT | **Language:** C#/.NET 9

#### Strengths

- **Routing modes** — failover, round-robin, weighted, Mixture-of-Agents
- **Web admin UI** — configuration dashboard with SQLite persistence
- **OpenAI-compatible endpoints** — standard API format

#### Gaps

- **C#/.NET dependency** — adds .NET 9 runtime to our Node.js stack
- **No Anthropic passthrough** — OpenAI format only, no Anthropic Messages API
- **No profile system**
- **No Claude Code-specific features**
- **No extended thinking or vision proxy**

---

### 5. y-router (luohy15) — ARCHIVED, Eliminated

**Repo:** [luohy15/y-router](https://github.com/luohy15/y-router)
**Status:** **ARCHIVED** — replaced by official OpenRouter integration

Simple Cloudflare Worker translating Anthropic API to OpenAI format for OpenRouter. Too minimal for our requirements — no profiles, no fallback chains, no routing logic, no cost tracking.

---

## Comparison Matrix

| Feature | claudish | LiteLLM | claude-code-router | LLMProxy | y-router |
|---------|----------|---------|-------------------|----------|----------|
| **Language** | Node.js/Bun | Python | Node.js/Bun | C#/.NET 9 | CF Worker |
| **Providers** | 580+ | 100+ | Z.ai primarily | OpenAI-format | OpenRouter |
| **Profile system** | Yes (roles) | No | Presets only | No | No |
| **Round-robin** | Via rules | Built-in | No | Built-in | No |
| **Fallback chains** | Yes | Yes | No | Failover | No |
| **Claude Code compat** | Native | Partial | Native | No | Partial |
| **Roo Code compat** | Yes | Yes | No | Yes | Yes |
| **API translation** | Bidirectional | OpenAI→all | Anthropic→Z.ai | OpenAI only | Anthropic→OR |
| **Extended thinking** | Cross-provider | No | No | No | No |
| **Vision proxy** | Yes | No | No | No | No |
| **Cost tracking** | Yes | Enterprise | No | No | No |
| **Local models** | Ollama/vLLM/MLX | Ollama/vLLM | No | No | No |
| **Admin UI** | Monitor mode | Full dashboard | None | Web admin | None |
| **Active dev** | Yes | Yes | Yes | Moderate | ARCHIVED |

---

## Implementation Recommendation for Myia Cluster

### Primary: claudish

**Deployment model:** Run claudish as a local proxy on each machine (lightweight Node.js process). Configure per-machine profiles matching the Myia cluster needs:

```
Profile "free-tour":
  opus    → z.ai:glm-5
  sonnet  → z.ai:glm-4.7
  haiku   → z.ai:glm-4.7-flash
  subagent→ z.ai:glm-4.5-air

Profile "premium":
  opus    → anthropic:claude-opus-4-7
  sonnet  → anthropic:claude-sonnet-4-6
  haiku   → anthropic:claude-haiku-4-5
  subagent→ z.ai:glm-4.7-flash

Profile "local-only":
  opus    → ollama:qwen3-32b
  sonnet  → ollama:qwen3-14b
  haiku   → ollama:qwen3-4b
  subagent→ ollama:qwen3-4b
```

**Routing rules for round-robin free-tier rotation:**
```
default → z.ai:glm-5 | z.ai:glm-4.7 (round-robin)
fallback → z.ai:glm-4.5-air
```

**Integration points:**
- Claude Code: point `ANTHROPIC_BASE_URL` to claudish proxy
- Roo Code: point `OPENAI_BASE_URL` to claudish OpenAI endpoint
- MCP: run claudish in MCP server mode alongside roo-state-manager

### Fallback: LiteLLM

If claudish proves insufficient at scale, LiteLLM provides the enterprise-grade alternative with proper admin dashboard, team budgets, and production load balancing. The tradeoff is the Python dependency and lack of Claude Code-specific features.

---

## Next Steps

1. **Prototype claudish** on one executor machine (e.g., po-2025)
2. Configure profiles matching the Myia cluster model assignments
3. Test Claude Code CLI + Roo Code compatibility
4. Benchmark latency overhead of the proxy layer
5. If successful, deploy across all 6 machines with per-machine profiles
6. Document the routing configuration in the cluster harness

---

## Sources

- [MadAppGang/claudish](https://github.com/MadAppGang/claudish) — README analyzed 2026-04-27
- [BerriAI/litellm](https://github.com/BerriAI/litellm) — README analyzed 2026-04-27
- [musistudio/claude-code-router](https://github.com/musistudio/claude-code-router) — README analyzed 2026-04-27
- [obirler/LLMProxy](https://github.com/obirler/LLMProxy) — README analyzed 2026-04-27
- [luohy15/y-router](https://github.com/luohy15/y-router) — README analyzed 2026-04-27 (archived)

# Free-Tier SOTA Model Audit — May 2026

**Issue:** #1770
**Date:** 2026-05-14
**Author:** Claude Code (myia-po-2025)
**Context:** Intelligent routing strategy to exhaust free credits before falling back to paid subscriptions

---

## Executive Summary

20+ providers offer genuinely free LLM API access in 2026. For the Myia cluster's workloads (code generation, review, coordination), **6 providers** are immediately actionable with claudish integration.

**Top recommendation:** Configure claudish profiles with Google AI Studio (Gemini 2.5 Pro) as primary free-tier provider, OpenRouter as secondary rotation, and DeepSeek as high-volume cheap fallback.

---

## Tier 1 — Truly Free, No Credit Card, No Expiry

### 1. Google AI Studio (BEST OVERALL)

| Aspect | Detail |
|--------|--------|
| **Models** | Gemini 2.5 Pro, 2.5 Flash, 2.5 Flash-Lite, Gemini 3 Flash |
| **Context** | 1M tokens (Pro), 250K TPM |
| **Rate Limits** | Pro: 5 RPM / 100 req/day · Flash: 10 RPM / 250 req/day · Flash-Lite: 15 RPM / 1K req/day |
| **API Format** | OpenAI-compatible |
| **Multimodal** | Yes (images, audio, video) |
| **Cost** | $0 |
| **Quality** | Gemini 2.5 Pro competitive with Claude Sonnet on coding benchmarks |

**Myia relevance:** Strong for code review, coordination, long-context tasks. 1M context window handles full codebases. RPM limits acceptable for interactive use but tight for scheduled workers.

**claudish config:** `google@gemini-2.5-pro` or `google@gemini-2.5-flash`

### 2. OpenRouter (BEST VARIETY)

| Aspect | Detail |
|--------|--------|
| **Free Models** | 30+ including DeepSeek R1/V3, Llama 3.3 70B, Llama 4, Qwen3 235B, GLM-4.5-air, GPT-OSS-120B |
| **Rate Limits** | 20 RPM, 50 req/day (1K/day with $10 balance) |
| **API Format** | OpenAI-compatible (drop-in) |
| **Cost** | $0 (with `:free` suffix models) |

**Myia relevance:** Unmatched model variety for A/B testing. GLM-4.5-air:free matches our current z.ai usage. DeepSeek R1:free strong for reasoning tasks. The 50 req/day limit is tight but can be spread across machines.

**claudish config:** `openrouter@deepseek/deepseek-r1:free`, `openrouter@meta-llama/llama-3.3-70b-instruct:free`

### 3. Groq (FASTEST)

| Aspect | Detail |
|--------|--------|
| **Models** | Llama 3.3 70B, Llama 4 Scout, Qwen3 32B, GPT-OSS-120B |
| **Speed** | 300+ tok/s (LPU hardware) |
| **Rate Limits** | 30 RPM, 1K req/day (70B), 14.4K/day (8B) |
| **API Format** | OpenAI-compatible |
| **Cost** | $0 |

**Myia relevance:** Speed advantage for interactive coding sessions. Llama 4 Scout + Qwen3 32B cover code generation well. RPM acceptable for dev/interactive use.

**claudish config:** `groq@llama-3.3-70b`, `groq@qwen3-32b`

### 4. Cerebras (FAST + GENEROUS)

| Aspect | Detail |
|--------|--------|
| **Models** | Llama 3.3 70B, Qwen3 32B, GPT-OSS-120B |
| **Speed** | 20x faster than GPU (wafer-scale engine) |
| **Rate Limits** | 30 RPM, 60K TPM, 1M tokens/day |
| **API Format** | OpenAI-compatible |
| **Cost** | $0 |

**Myia relevance:** Agentic workflows with many sequential LLM calls. 1M tokens/day generous for scheduled workers. Speed reduces wall-clock time for multi-step tasks.

**claudish config:** `cerebras@llama-3.3-70b`

### 5. Mistral / Codestral (CODE SPECIALIST)

| Aspect | Detail |
|--------|--------|
| **Models** | Codestral, Mistral Large, Mistral Small |
| **Rate Limits** | La Plateforme: 2 RPM, 1B tokens/month · Codestral: 30 RPM, 2K req/day |
| **API Format** | OpenAI-compatible |
| **Cost** | $0 |

**Myia relevance:** Codestral is purpose-built for code generation. 30 RPM / 2K req/day is generous. La Plateforme's 2 RPM too restrictive for production but 1B tokens/month is massive.

**claudish config:** `mistral@codestral-latest`

### 6. GitHub Models (CONVENIENCE)

| Aspect | Detail |
|--------|--------|
| **Models** | GPT-4o, o3, DeepSeek-R1, Grok-3, GPT-5, Llama 4, Qwen3 Coder |
| **Rate Limits** | 10-15 RPM, 50-150 req/day, 8K in/4K out per request |
| **API Format** | OpenAI-compatible |
| **Cost** | $0 |

**Myia relevance:** Convenient access to frontier models (GPT-5, o3) for comparison. Token limits per request are tight. Good for quick quality benchmarks.

---

## Tier 2 — Very Cheap / Trial Credits

### 7. DeepSeek (QUASI-FREE)

| Aspect | Detail |
|--------|--------|
| **Models** | DeepSeek V3, R1, V3.1 |
| **Pricing** | 5M free tokens on signup, then $0.14/$0.28 per M tokens (input/output) |
| **Rate Limits** | No hard limit |
| **Quality** | V3: 77.9% MMLU, competitive with Claude Sonnet on coding |

**Myia relevance:** Best cost/quality ratio in the market. At ~$0.20/M tokens, a few dollars covers months of active development. R1 strong for reasoning. No rate limits means suitable for scheduled workers.

**claudish config:** `deepseek@deepseek-chat`, `deepseek@deepseek-reasoner`

### 8. SambaNova

$5 trial + persistent free tier. Llama 3.3 70B, Llama 3.1 405B, Qwen 2.5 72B. 10-30 RPM.

### 9. NVIDIA NIM

1K free credits (+4K requestable). 40 RPM. DeepSeek R1, Llama variants, Kimi K2.5.

---

## Routing Strategy for Myia Cluster

### Profile Configuration (claudish)

```yaml
# Profile: free-tier (default for worker machines)
# Principle: never downgrade. Free alternatives must be equal or better.
opus:
  - google@gemini-2.5-pro          # Primary: 1M context, competitive quality
  - openrouter@deepseek/deepseek-r1:free  # Fallback: strong reasoning
  - z.ai@glm-5.1                   # Paid fallback (current)

sonnet:
  - google@gemini-2.5-flash        # Primary: fast, generous limits
  - groq@llama-3.3-70b             # Speed fallback
  - cerebras@llama-3.3-70b         # Volume fallback (1M tok/day)
  - z.ai@glm-5.1                   # Paid fallback

haiku:
  - groq@qwen3-32b                 # Primary: fast + good quality
  - cerebras@qwen3-32b             # Volume fallback
  - openrouter@z-ai/glm-4.5-air:free  # Free GLM fallback
  - z.ai@glm-4.7-flash             # Paid fallback
```

### Quota Management Approach

Since claudish doesn't have built-in round-robin for free tiers, the routing strategy uses **ordered fallback**:

1. Try free provider with best quality first
2. On rate limit error (429), automatically fall to next provider
3. Last resort: paid subscription (z.ai GLM or Anthropic Opus)

This is simpler than true round-robin and leverages claudish's existing fallback chain mechanism.

### Per-Machine Assignment

| Machine | Primary Free Provider | Paid Fallback | Rationale |
|---------|----------------------|---------------|-----------|
| po-2023 | Google AI Studio | z.ai GLM | Proxmox host, always on |
| po-2024 | OpenRouter | z.ai GLM | Variety for code review |
| po-2025 | Groq + Cerebras | z.ai GLM | Speed for interactive dev |
| po-2026 | Cerebras | z.ai GLM | Volume for scheduled workers |
| web1 | Google AI Studio | z.ai GLM | Long-context for analysis |
| ai-01 | — | Anthropic Opus | Coordinateur, stays on paid |

### Quality Gate

Before routing to a free provider for a given role, verify:
- **Coding benchmarks:** HumanEval, SWE-Bench comparable to GLM-5.1
- **Context handling:** Supports tool use, system prompts, multi-turn
- **Extended thinking:** claudish translates thinking budgets across providers
- **Latency:** < 5s first-token for interactive, < 30s for workers

---

## Action Items

1. **Create API keys** for Google AI Studio, OpenRouter, Groq, Cerebras, DeepSeek
2. **Configure claudish profiles** on po-2023 (central proxy) with free-tier routing
3. **Benchmark quality** — run SWE-Bench subset on free models vs GLM-5.1
4. **Deploy to 1 machine** as pilot (po-2025 recommended)
5. **Monitor quota usage** — track free vs paid request ratios
6. **Document results** — update this audit with real benchmark numbers

---

## Sources

- [Awesome Agents: Free AI APIs 2026](https://awesomeagents.ai/tools/free-ai-inference-providers-2026/) — Comprehensive comparison, updated April 2026
- [cheahjs/free-llm-api-resources](https://github.com/cheahjs/free-llm-api-resources) — Community-maintained list, 21.5k stars
- [TokenMix: Free LLM APIs 2026](https://tokenmix.ai/blog/free-llm-apis-2026-every-provider-free-tier-tested) — Tested limits
- [CostBench: Best Free LLM API](https://costbench.com/best/best-llm-api-with-free-tier/) — Ranked comparison
- [MadAppGang/claudish](https://github.com/MadAppGang/claudish) — Proxy configuration docs

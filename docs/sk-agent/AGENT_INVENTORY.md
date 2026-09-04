# SK-Agent Complete Agent Inventory

**Issue:** #3410 — generated from `sk_agent_config.template.json`
**Source:** `mcps/internal/servers/sk-agent/sk_agent_config.template.json`
**Generated:** 2026-09-04

> **Source of truth.** This file is generated. Do NOT edit by hand — edit the template config and re-run `python generate_inventory.py`.

---

## Summary

| Metric | Count |
|--------|-------|
| **Total models** | 16 (12 enabled, 4 disabled) |
| **Top-level agents** | 32 |
| **Inline agents** (conversation-scoped) | 15 |
| **Memory-enabled agents** | 5 |
| **MCP plugins** | 5 |
| **Conversations** | 11 (group_chat, magentic, sequential) |

---

## Models

| ID | Provider / Base URL | Context | Vision | Thinking | Enabled | Description |
|----|---------------------|---------|--------|----------|---------|-------------|
| `glm-5.1` | api.z.ai/api/coding/paas/v4 | 200000 | N | Y | Y | GLM-5.1 reasoning via z.ai cloud (200K context, 45.3/113 coding, +28% vs GLM-5) |
| `glm-5.1-fast` | api.z.ai/api/coding/paas/v4 | 200000 | N | N | Y | GLM-5.1 non-thinking via z.ai — faster responses, lower token usage, same model quality for non-reasoning tasks |
| `glm-5` | api.z.ai/api/coding/paas/v4 | 200000 | N | Y | Y | GLM-5 reasoning via z.ai cloud (200K context, strong coding and analysis) |
| `glm-5-fast` | api.z.ai/api/coding/paas/v4 | 200000 | N | N | Y | GLM-5 non-thinking via z.ai — faster responses for straightforward tasks |
| `glm-4.6v` | api.z.ai/api/coding/paas/v4 | 128000 | Y | N | Y | GLM-4.6V vision via z.ai cloud (128K context) |
| `glm-4.7-flash` | api.z.ai/api/coding/paas/v4 | 131072 | N | N | Y | GLM-4.7-Flash via z.ai cloud — fast responses, no thinking overhead |
| `omnicoder-9b` | api.mini.text-generation-webui.m... | 131072 | Y | Y | N | OmniCoder-9B — 96-107 tok/s, 131K ctx, thinking+vision, OCR 97.5%, MME 1258.5, tool call 1.09s. GPU 2 (port 5001). qwen3_coder parser. |
| `qwen3.6-35b-a3b` | api.medium.text-generation-webui... | 262144 | Y | Y | Y | Qwen3.6 35B MoE AWQ — 86 tok/s, 262K ctx, vision+thinking. Benchmarks: GSM8K 88%, IFEval 88.5%, MME 1294.7, SWE-bench 69.2%. GPU 0+1 |
| `qwen3.6-35b-no-thinking` | api.medium.text-generation-webui... | 262144 | N | N | Y | Qwen3.6 35B MoE AWQ — no-thinking mode. Faster inference for coding tasks that don't need chain-of-thought. Same hardware as qwen3.6-35b-a3b. |
| `owui-glm-4.7-flash-fast` | open-webui.myia.io/openai | 131072 | N | N | N | GLM-4.7-Flash AWQ via OWUI (no thinking). DISABLED: model deleted upstream (no more local GLM hosting) |
| `owui-glm-4.7-flash-thinking` | open-webui.myia.io/openai | 131072 | N | Y | N | GLM-4.7-Flash AWQ via OWUI (thinking ON). DISABLED: model deleted upstream. No equivalent thinking local/cloud — use Qwen_think wrappers or direct qwen3.6-35b-a3b |
| `owui-omnicoder-9b` | open-webui.myia.io/openai | 131072 | Y | Y | N | OmniCoder-9B via OWUI proxy (bénéficie des filters/pipelines OWUI, notamment detoxify). Fallback direct vLLM via id omnicoder-9b. |
| `owui-qwen3.6-35b` | open-webui.myia.io/openai | 262144 | Y | Y | Y | Qwen3.6 35B MoE via OWUI proxy (bénéficie des filters/pipelines OWUI). Renommé depuis qwen3.5 (OWUI commit 4b8d8d521). Fallback direct vLLM via id qwen3.6-35b-a3b. |
| `owui-expert-analyste` | open-webui.myia.io/openai | 131072 | N | Y | Y | OWUI Expert Analyste (wrapper qwen3.6-35b-a3b, thinking enabled). |
| `owui-redacteur-technique` | open-webui.myia.io/openai | 131072 | N | Y | Y | OWUI Rédacteur Technique (wrapper qwen3.6-35b-a3b, thinking enabled). |
| `owui-vision-expert` | open-webui.myia.io/openai | 131072 | Y | Y | Y | OWUI Expert Vision (wrapper qwen3.6-35b-a3b, vision+thinking). |

## Agents

| ID | Model | MCPs | Memory | Description |
|----|-------|------|--------|-------------|
| `analyst` | `glm-5.1` | searxng, playwright, markitdown | Y | General analyst with web search, document conversion, and memory. Local: Qwen3.6 35B MoE (86 tok/s, 262K ctx, GSM8K 88%, SWE-bench 69.2%). Cloud: GLM-5.1 (45.3/113 coding) |
| `vision-analyst` | `glm-4.6v` | searxng, playwright, markitdown | N | Image and document analysis specialist with web context and document conversion. Cloud: GLM-4.6V. Can browse web, search context, and convert PDF/DOCX/XLSX to markdown |
| `vision-local` | `qwen3.6-35b-a3b` | searxng, playwright, markitdown | N | Fast local vision+thinking with web context and document conversion (Qwen3.6 35B MoE — 86 tok/s, 262K ctx, vision+thinking, MME 1294.7). Best for OCR, spatial reasoning, detailed analysis |
| `coder` | `qwen3.6-35b-no-thinking` | open_terminal, searxng | N | Agentic coding assistant with terminal access and web search (Qwen3.6 35B MoE — 86 tok/s, 262K ctx, no-thinking mode). Can execute commands and search documentation |
| `fast` | `qwen3.6-35b-no-thinking` | — | N | Fast responses via local vLLM Qwen3.6 35B no-thinking (86 tok/s, 262K ctx). No tools, fastest reliable option (glm-4.7-flash deprecated: 60% rate-limit failures in benchmark) |
| `fast-local` | `qwen3.6-35b-no-thinking` | — | N | Quick local responses via direct vLLM Qwen3.6 35B no-thinking mode (86 tok/s, 262K ctx). No tools, no thinking overhead |
| `fast-local-thinking` | `qwen3.6-35b-a3b` | — | N | Local responses with thinking mode via direct vLLM Qwen3.6 35B (86 tok/s, 262K ctx, vision+thinking). Better reasoning, slightly slower |
| `analyst-glm5` | `glm-5` | searxng, playwright, markitdown | Y | General analyst using GLM-5 with web search, document conversion, and memory. Cloud: GLM-5 (200K ctx, thinking mode). Alternative to analyst (GLM-5.1) |
| `analyst-fast` | `glm-5.1-fast` | searxng | N | Fast analyst using GLM-5.1 non-thinking mode — lower latency for straightforward analysis and classification tasks |
| `fast-responder` | `glm-5-fast` | — | N | Fast responder using GLM-5 non-thinking mode — quick answers for simple queries and triage |
| `coder-local` | `owui-qwen3.6-35b` | — | N | Local coding via OWUI Qwen3.6 35B MoE proxy — vision+thinking+tool calling through OWUI |
| `vision-local-owui` | `owui-qwen3.6-35b` | — | N | Local vision via OWUI Qwen3.6 35B MoE proxy — highest quality local vision+thinking model |
| `qwen-local` | `qwen3.6-35b-a3b` | — | N | Direct vLLM access to Qwen3.6 35B MoE — 86 tok/s, 262K ctx, vision+thinking. Best local quality, no OWUI overhead |
| `researcher` | `glm-5.1` | searxng, playwright, open_terminal, markitdown | Y | Investigative researcher with web search, terminal access, document conversion, and memory. Local: Qwen3.6 35B MoE (IFEval 88.5%, 262K ctx). Cloud: GLM-5.1 (45.3/113 coding) |
| `synthesizer` | `glm-5.1-fast` | — | N | Expert at turning complex multi-source findings into clear, structured reports (non-thinking: synthesis = pattern matching, benchmark showed quality-neutral) |
| `critic` | `glm-5.1` | — | N | Rigorous quality reviewer who stress-tests reports for gaps and weak evidence |
| `optimist` | `glm-5.1` | — | N | Strategic optimist who identifies opportunities, upside potential, and best-case scenarios |
| `devils-advocate` | `glm-5.1` | — | N | Relentless contrarian who pressure-tests ideas by finding every flaw and risk |
| `pragmatist` | `glm-5.1` | — | N | Implementation-focused realist who bridges vision and execution with practical plans |
| `mediator` | `glm-5-fast` | — | N | Diplomatic synthesizer who builds consensus from competing perspectives (non-thinking: consensus building, benchmark showed quality-neutral) |
| `config-auditor` | `glm-5.1` | — | N | Audits MCP and Roo configuration for inconsistencies, drift, and security issues |
| `log-analyzer` | `glm-5.1` | — | N | Analyzes application logs to identify errors, patterns, and root causes |
| `commit-reviewer` | `glm-5.1` | — | N | Specialized code reviewer for git diffs with structured findings table |
| `guardian-sentinel` | `glm-5.1` | — | Y | Real-time surveillance agent for multi-machine system health and anomaly detection |
| `owui-analyst` | `owui-expert-analyste` | searxng | Y | Expert analyst via OWUI (enriched system prompt, structured French output) |
| `owui-writer` | `owui-redacteur-technique` | — | N | Technical documentation writer via OWUI (enriched system prompt) |
| `owui-vision` | `owui-qwen3.6-35b` | — | N | Vision analysis via OWUI Qwen3.6 35B MoE proxy (vision+thinking, enriched system prompt) |
| `fast-reviewer` | `glm-5-fast` | — | N | Tier 1 fast diff-only reviewer. GLM-5 non-thinking for speed + reliability (glm-4.7-flash had 60% rate-limit failures in benchmark). |
| `integration-reviewer` | `glm-5` | — | N | Tier 2 context-aware reviewer with GitHub tools for PR analysis. GLM-5 for more thorough reviews (benchmark: 3062 chars vs 1827 for glm-5.1). |
| `context-explorer` | `glm-5.1` | — | N | Explores code context around PR changes — reads files, searches callers, checks history. GLM-5.1. |
| `regression-hunter` | `glm-5.1` | — | N | Hunts for regression risks by analyzing git history, past incidents, and similar changes that caused issues. GLM-5.1 with GitHub tools. |
| `security-executor` | `glm-5.1` | — | N | Deep security analysis with code execution — dependency audit, OWASP scan, secret detection. GLM-5.1 with GitHub + terminal tools. |

## Inline Agents (conversation-scoped)

| Conversation | ID | Model | Description |
|--------------|----|-------|-------------|
| `code-review` | `security-reviewer` | `glm-5.1` | Security-focused code reviewer |
| `code-review` | `perf-reviewer` | `glm-5.1` | Performance-focused code reviewer |
| `code-review` | `maintainability-reviewer` | `glm-5.1` | Maintainability and readability reviewer |
| `code-review` | `code-synthesizer` | `glm-5.1` | Synthesizes review findings into actionable summary |
| `research-debate` | `proponent` | `glm-5.1` | Argues in favor of the proposition |
| `research-debate` | `opponent` | `glm-5.1` | Argues against the proposition |
| `research-debate` | `fact-checker` | `glm-5-fast` | Verifies claims from both sides |
| `research-debate` | `debate-synthesizer` | `glm-5-fast` | Produces balanced conclusion from the debate |
| `config-harmonization` | `config-detective` | `glm-5.1` | Identifies and classifies configuration differences |
| `config-harmonization` | `risk-assessor` | `glm-5-fast` | Assesses risk of each configuration difference |
| `config-harmonization` | `resolution-planner` | `glm-5.1` | Plans concrete resolution steps |
| `config-harmonization` | `harmonization-synthesizer` | `glm-5-fast` | Produces final harmonization report with decisions |
| `pr-review-tier1` | `review-synthesizer` | `qwen3.6-35b-no-thinking` | Formats review findings into structured JSON |
| `pr-review-tier2` | `review-synthesizer-t2` | `glm-5.1` | Aggregates Tier 2 review findings into final structured verdict |
| `pr-review-tier3` | `review-synthesizer-t3` | `glm-5.1` | Aggregates Tier 3 review findings from all specialists into final structured verdict |

## MCP Plugins

| ID | Command | Description |
|----|---------|-------------|
| `searxng` | `npx -y mcp-searxng` | Web search via SearXNG |
| `playwright` | `npx -y @playwright/mcp@latest` | Browser automation and web scraping |
| `sk_agent` | `VENV_PATH/Scripts/python.exe INSTALLATION_PATH/sk_agent.py` | Self-inclusion for recursive tool chaining |
| `open_terminal` | `python ../open-terminal-mcp/open_terminal_mcp.py` | Remote terminal access (shell commands, file operations, grep/glob) via Open Terminal API |
| `markitdown` | `markitdown-mcp ` | Document conversion (PDF/DOCX/XLSX/PPTX/HTML/images) to Markdown via Microsoft markitdown |

## Conversations

| ID | Type | Agents | Rounds | Description |
|----|------|--------|--------|-------------|
| `deep-search` | magentic | researcher, synthesizer, critic | 10 | Multi-agent deep research with search, synthesis, and critical review |
| `deep-think` | group_chat | optimist, devils-advocate, pragmatist, mediator | 8 | Multi-perspective deliberation with diverse viewpoints and synthesis |
| `code-review` | group_chat | security-reviewer, perf-reviewer, maintainability-reviewer, code-synthesizer | 6 | Multi-perspective code review with security, performance, and maintainability analysis |
| `research-debate` | sequential | proponent, opponent, fact-checker, debate-synthesizer | 4 | Research a topic from opposing viewpoints then synthesize a balanced conclusion |
| `config-harmonization` | sequential | config-detective, risk-assessor, resolution-planner, harmonization-synthesizer | 4 | Multi-agent deliberation on configuration drift resolution across machines |
| `commit-review` | sequential | commit-reviewer, devils-advocate, synthesizer | 3 | Structured code review of a git diff using commit-reviewer + critic + synthesizer |
| `task-allocation` | group_chat | analyst, pragmatist, critic | 4 | Intelligent task allocation and prioritization for GitHub issues across multi-machine team |
| `intelligent-task-dispatch` | sequential | researcher, pragmatist, critic, synthesizer | 5 | Multi-perspective task analysis for optimal machine and agent assignment in multi-machine workflows |
| `pr-review-tier1` | sequential | fast-reviewer, review-synthesizer | 2 | Fast diff-only code review for trivial PRs (pointer bumps, typos, small fixes) |
| `pr-review-tier2` | group_chat | integration-reviewer, context-explorer, review-synthesizer-t2 | 6 | Multi-perspective PR review with context exploration, integration tracing, and synthesis |
| `pr-review-tier3` | group_chat | integration-reviewer, context-explorer, regression-hunter, security-executor, review-synthesizer-t3 | 8 | Comprehensive PR review with integration tracing, security analysis, regression hunting, and synthesis. For large/complex PRs. |

---

## How to regenerate

```bash
cd mcps/internal/servers/sk-agent
python generate_inventory.py

# CI: fail if doc has drifted from config
python generate_inventory.py --check
```

See `docs/services/sk-agent-deployment.md` for the deployment and transport recipes.

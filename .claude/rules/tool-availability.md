# Inventaire des Outils et Protocole STOP & REPAIR

**Version:** 3.0.0 (sk-agent count + MCP remote Claude.ai section + web_reader requalifié)

---

## REGLE NON NEGOCIABLE

**Si un outil critique est absent, TOUT s'arrete.** STOP & REPAIR immediat.

## Inventaire MCP — Critiques

| Agent | MCP | Outils | Verification |
|-------|-----|--------|-------------|
| **Claude Code** | roo-state-manager | 15 | `conversation_browser(action: "current")` |
| **Roo Scheduler** | win-cli (fork local 0.2.0) | 9 | `execute_command(shell="powershell")` |

**Config separee :** Claude = `~/.claude.json`. Roo = `%APPDATA%\...\mcp_settings.json`.
**win-cli :** Critique UNIQUEMENT pour Roo. Claude utilise `Bash`. Jamais `npx @simonb97/...`.
**Timeout guard :** `scripts/infra/harmonize-win-cli-timeouts.ps1` vérifie les 2 niveaux (interne + transport). Intégré au pre-flight executor (v3.2.3+, #2333). Peut aussi être lancé en cron.

## Standards (non bloquants)

| MCP | Outils | Role |
|-----|--------|------|
| playwright | 23 | Automation web |
| sk-agent | 9 outils + agents dynamiques | Vision/multi-agent (`call_agent` dynamic descriptions). Outils = `call_agent`, `diagnostics`, `end_conversation`, `install_libreoffice`, `list_agents`, `list_conversations`, `list_tools`, `review_pr`, `run_conversation` |
| **searxng** | 2 | **Web canonique**: searxng_web_search + web_url_read. Markdown: prefix r.jina.ai (#2210) |

**Note:** markitdown (1 outil) est configure uniquement dans Roo `mcp_settings.json`, pas dans Claude Code `~/.claude.json`.

## MCP Remote Claude.ai (injectés, pas dans config locale)

Certains MCP apparaissent dans les sessions sans être dans `~/.claude.json` ni `.mcp.json`. Ils sont injectés par le **routeur Claudish distant** (`ANTHROPIC_BASE_URL`) ou par le hub Claude.ai (`claudeAiMcpEverConnected` dans `~/.claude.json`). Ne PAS les traiter comme des anomalies de config locale :

| MCP | Outil | Source | Note |
|-----|-------|--------|------|
| `4_5v_mcp` | `analyze_image` | Routeur Claudish / Claude.ai remote | Vision, non critique |
| `web_reader` | `webReader` | Routeur Claudish / Claude.ai remote | Retiré du fork claudish (#2210, commit `24ec4da`), peut encore être injecté par le routeur |

**Action si détecté dans un audit :** Documenter la source (remote MCP), NE PAS chercher dans les configs locales.

## Retires (NE DOIVENT PAS exister dans les configs locales)

desktop-commander, github-projects-mcp, quickfiles

## STOP & REPAIR

Declencher si : MCP critique absent, "tool not found", outil count diverge, MCP retire detecte.

- **Claude :** STOP → LOG dashboard → DIAG config → FIX → TEST → ESCAL si necessaire → RESUME
- **Roo :** STOP → WRITE [CRITICAL] → REPORT → WAIT

**Accommodation INTERDITE.** Ne PAS continuer en mode degrade.

---

**Config win-cli canonique, config sk-agent, validation auto, procedure detaillee :** [`docs/harness/reference/tool-availability-detailed.md`](docs/harness/reference/tool-availability-detailed.md)

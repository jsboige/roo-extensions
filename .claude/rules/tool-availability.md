# Inventaire des Outils et Protocole STOP & REPAIR

**Version:** 3.3.0 (note « code supprimé » quickfiles/github-projects-mcp, #3423)

---

## REGLE NON NEGOCIABLE

**Si un outil critique est absent, TOUT s'arrete.** STOP & REPAIR immediat.

## Inventaire MCP — Critiques

| Agent | MCP | Outils | Verification |
|-------|-----|--------|-------------|
| **Claude Code** | roo-state-manager | 16 | `conversation_browser(action: "current")` |
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

## MCP désactivés ≠ absents (#3137)

Des MCP dédiés sont **désactivés** pour réduire la surface exposée — pas désinstallés. Leur config reste sur disque. L'état se lit à **TROIS emplacements** (finding ai-01 23/08 + vérif live po-204 24/08, #3137) :

| # | Emplacement | Champ | Portée |
|---|---|---|---|
| 1 | `~/.claude.json` → `mcpServers` | `disabled` bool par serveur | machine |
| 2 | `<workspace>/.mcp.json` | `disabled` bool par serveur | workspace |
| 3 | `~/.claude.json` → `projects[<workspace>].disabledMcpServers` | **liste de noms** de serveurs | workspace, **prime sur l'activation user-scope** |

**Priorité vérifiée en session** : une entrée dans `disabledMcpServers` (emplacement 3) désactive le serveur dans CE workspace **même s'il est `disabled:false` en user-scope** — piège mesuré sur ai-01 et po-204 : lire les emplacements 1-2 seul conclut « activé » à tort. L'instrument qui ne ment pas : la **présence effective des outils `mcp__<serveur>__*` en session**.

**Avant de proposer d'installer un nouveau client** (playwright, sk-agent, jupyter-papermill…), vérifier si le MCP dédié n'est pas simplement désactivé :

1. Lire les **3 emplacements** ci-dessus pour le workspace courant.
2. Si désactivé → réactiver : `"disabled": false` (emplacements 1-2) **ou retirer le nom du tableau** `disabledMcpServers` (emplacement 3) ; puis **redémarrer la session** du workspace (scope MCP chargé au démarrage).
3. Vérifier que les outils `mcp__<serveur>__*` apparaissent.
4. Re-désactiver après usage si la réduction de surface doit être restaurée.

**Recensement flotte par machine/workspace :** issue #3137. Un MCP désactivé n'est PAS un MCP retiré (cf. section Retires) — la réactivation est locale et réversible, zéro installation.

## MCP Remote Claude.ai (injectés, pas dans config locale)

Certains MCP apparaissent dans les sessions sans être dans `~/.claude.json` ni `.mcp.json`. Ils sont injectés par le **routeur Claudish distant** (`ANTHROPIC_BASE_URL`) ou par le hub Claude.ai (`claudeAiMcpEverConnected` dans `~/.claude.json`). Ne PAS les traiter comme des anomalies de config locale :

| MCP | Outil | Source | Note |
|-----|-------|--------|------|
| `4_5v_mcp` | `analyze_image` | Routeur Claudish / Claude.ai remote | Vision, non critique |
| `web_reader` | `webReader` | Routeur Claudish / Claude.ai remote | Retiré du fork claudish (#2210, commit `24ec4da`), peut encore être injecté par le routeur |

**Action si détecté dans un audit :** Documenter la source (remote MCP), NE PAS chercher dans les configs locales.

## Retires (NE DOIVENT PAS exister dans les configs locales)

desktop-commander, github-projects-mcp, quickfiles

> **quickfiles + github-projects-mcp : code supprimé (2026-09)** — Epic #2639 tâche C (#3423, PR submod #1093) : les serveurs sont retirés de `servers/` du submod (quickfiles remplacé par les capacités natives Claude Code, github-projects-mcp par `gh` CLI). Les **noms** restent dans la garde `RETIRED_MCP_NAMES` du RSM — les tests qui les référencent testent le validateur, pas les serveurs. `desktop-commander` : retiré des configs, non concerné par la suppression de code.

## STOP & REPAIR

Declencher si : MCP critique absent, "tool not found", outil count diverge, MCP retire detecte.

- **Claude :** STOP → LOG dashboard → DIAG config → FIX → TEST → ESCAL si necessaire → RESUME
- **Roo :** STOP → WRITE [CRITICAL] → REPORT → WAIT

**Accommodation INTERDITE.** Ne PAS continuer en mode degrade.

---

**Config win-cli canonique, config sk-agent, validation auto, procedure detaillee :** [`docs/harness/reference/tool-availability-detailed.md`](../../docs/harness/reference/tool-availability-detailed.md)

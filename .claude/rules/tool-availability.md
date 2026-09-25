# Inventaire des Outils et Protocole STOP & REPAIR

**Version:** 3.4.0 (slim — #3137/remote/retires déportés vers le doc détaillé, #2368)

---

## REGLE NON NEGOCIABLE

**Si un outil critique est absent, TOUT s'arrete.** STOP & REPAIR immediat. Accommodation
INTERDITE — ne pas continuer en mode dégradé.

## Inventaire MCP — Critiques

| Agent | MCP | Outils | Verification |
|-------|-----|--------|-------------|
| **Claude Code** | roo-state-manager | 17 | `conversation_browser(action: "current")` |
| **Roo Scheduler** | win-cli (fork local 0.2.0) | 9 | `execute_command(shell="powershell")` |

Config séparée : Claude = `~/.claude.json`, Roo = `%APPDATA%\...\mcp_settings.json`. win-cli :
critique UNIQUEMENT pour Roo (Claude utilise `Bash`, jamais `npx @simonb97/...`). Timeout guard :
`scripts/infra/harmonize-win-cli-timeouts.ps1` (2 niveaux, #2333).

## Standards (non bloquants)

- **playwright** (25 outils) — automation web
- **sk-agent** (9 + agents dynamiques) — vision/multi-agent
- **searxng** (2 ou 4 selon version) — web canonique ; **drift #2224** : le compte d'outils se
  **mesure sur la session**, jamais ne se déduit du tableau — [détail](../../docs/harness/reference/tool-availability-detailed.md) § searxng
- markitdown (1 outil) : config Roo uniquement

## MCP désactivés ≠ absents (#3137)

Un MCP dédié désactivé n'est **pas** désinstallé : config sur disque, réactivation locale et
réversible. L'état se lit à **trois emplacements** — le 3e (`disabledMcpServers` par workspace)
**prime sur l'activation user-scope** ; l'instrument qui ne ment pas : la **présence effective
des outils `mcp__<serveur>__*` en session**. **Avant d'installer un nouveau client, vérifier les
trois emplacements et réactiver.** Table et procédure : [détail](../../docs/harness/reference/tool-availability-detailed.md) § #3137.

## MCP remote injectés (routeur Claudish / Claude.ai)

`4_5v_mcp` (`analyze_image`), `web_reader` (`webReader`) apparaissent sans être dans les configs
locales — injectés par le routeur/hub distant. Si détecté : documenter la source, ne PAS chercher
dans les configs locales. Table : [détail](../../docs/harness/reference/tool-availability-detailed.md).

## Retires (NE DOIVENT PAS exister dans les configs locales)

desktop-commander, github-projects-mcp, quickfiles (code supprimé 2026-09, #3423 — les noms
restent dans la garde `RETIRED_MCP_NAMES` du RSM).

## STOP & REPAIR

Déclencher si : MCP critique absent, "tool not found", compte d'outils diverge, MCP retiré détecté.

- **Claude :** STOP → LOG dashboard → DIAG config → FIX → TEST → ESCAL si nécessaire → RESUME
- **Roo :** STOP → WRITE [CRITICAL] → REPORT → WAIT

---

**Config win-cli canonique, config sk-agent, validation auto, table #3137, MCP remote, procédure
détaillée :** [`docs/harness/reference/tool-availability-detailed.md`](../../docs/harness/reference/tool-availability-detailed.md)

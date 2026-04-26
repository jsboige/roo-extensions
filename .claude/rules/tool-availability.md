# Inventaire des Outils et Protocole STOP & REPAIR

**Version:** 2.0.0 (slim)

---

## REGLE NON NEGOCIABLE

**Si un outil critique est absent, TOUT s'arrete.** STOP & REPAIR immediat.

## Inventaire MCP — Critiques

| Agent | MCP | Outils | Verification |
|-------|-----|--------|-------------|
| **Claude Code** | roo-state-manager | 34 | `conversation_browser(action: "current")` |
| **Roo Scheduler** | win-cli (fork local 0.2.0) | 9 | `execute_command(shell="powershell")` |

**Config separee :** Claude = `~/.claude.json`. Roo = `%APPDATA%\...\mcp_settings.json`.
**win-cli :** Critique UNIQUEMENT pour Roo. Claude utilise `Bash`. Jamais `npx @simonb97/...`.

## Standards (non bloquants)

| MCP | Outils | Role |
|-----|--------|------|
| playwright | 22 | Automation web |
| markitdown | 1 | Conversion documents |

## Retires (NE DOIVENT PAS exister)

desktop-commander, github-projects-mcp, quickfiles

## STOP & REPAIR

Declencher si : MCP critique absent, "tool not found", outil count diverge, MCP retire detecte.

- **Claude :** STOP → LOG dashboard → DIAG config → FIX → TEST → ESCAL si necessaire → RESUME
- **Roo :** STOP → WRITE [CRITICAL] → REPORT → WAIT

**Accommodation INTERDITE.** Ne PAS continuer en mode degrade.

---

**Config win-cli canonique, config sk-agent, validation auto, procedure detaillee :** [`docs/harness/reference/tool-availability-detailed.md`](docs/harness/reference/tool-availability-detailed.md)

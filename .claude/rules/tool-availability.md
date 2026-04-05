# Inventaire des Outils et Protocole STOP & REPAIR

**Version:** 2.0.0 (condensed from 1.6.0)
**MAJ:** 2026-04-05

---

## REGLE NON NEGOCIABLE

**Si un outil critique est absent, TOUT s'arrete.** Pas de mode degrade, pas de contournement.
**ON REPARE D'ABORD, ON TRAVAILLE ENSUITE.**

La perte d'un outil critique = INCIDENT MAJEUR → STOP & REPAIR immediat.

---

## Inventaire MCP

### Critiques

| Agent | MCP | Outils | Verification |
|-------|-----|--------|-------------|
| **Claude Code** | roo-state-manager | 34 | `conversation_browser(action: "current")` |
| **Roo Scheduler** | win-cli (fork local 0.2.0) | 9 | `execute_command(shell="powershell", command="echo OK")` |

**Config separee :** Claude Code = `C:\Users\{user}\.claude.json`. Roo = `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`.
Un MCP peut etre dispo pour un agent mais pas l'autre. Ajout critique = configurer LES DEUX.

**win-cli :** Critique UNIQUEMENT pour Roo (modes -simple n'ont pas le terminal natif). Claude Code utilise `Bash`.
**NE JAMAIS** `npx @anthropic/win-cli` (npm 0.2.1 casse). Utiliser le fork local uniquement.

### Standards (non bloquants)

| MCP | Outils | Role |
|-----|--------|------|
| playwright | 22 | Automation web |
| markitdown | 1 | Conversion documents |

### Retires (NE DOIVENT PAS exister)

desktop-commander (→ win-cli), github-projects-mcp (→ `gh` CLI), quickfiles (→ outils natifs)

---

## Protocole STOP & REPAIR

**Declencher IMMEDIATEMENT si :** MCP critique absent, "tool not found", outil count diverge, MCP retire detecte.

### Claude Code

```
1. STOP   : Arreter la tache
2. LOG    : Dashboard [CRITICAL]
3. DIAG   : roosync_mcp_management(action: "manage", subAction: "read")
4. FIX    : roosync_mcp_management(subAction: "update_server_field") ou modifier sources
5. TEST   : Appeler l'outil pour confirmer
6. ESCAL  : RooSync URGENT si non reparable
7. RESUME : Seulement aptes confirmation
```

### Roo Scheduler

```
1. STOP → 2. WRITE [CRITICAL] → 3. REPORT bilan → 4. WAIT prochain tick
```

### Pre-flight Scheduler (CRITIQUE)

**READ-ONLY.** Ne JAMAIS modifier config, redemarrer serveur, ou utiliser ask_followup_question en scheduler.
Si critique absent : signaler [CRITICAL], terminer proprement.

### Accommodation INTERDITE

Ne PAS continuer en mode degrade. Ne PAS contourner. Signaler et arreter.

---

## Verification Proactive (Coordinateur)

**OBLIGATION apres TOUT changement de config :**
1. Lister 6 machines
2. Verifier Claude (roo-state-manager 34 tools) + Roo (win-cli fork local) + pas de MCP retire
3. Si divergence → directive corrective URGENTE

---

**Historique incidents :** `docs/harness/reference/incident-history.md`

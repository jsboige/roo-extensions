# Inventaire Outils et Config — Reference Detaillee

**Source :** `.claude/rules/tool-availability.md` (version slim)

---

## Config canonique win-cli (#1666 Phase A3)

```json
"win-cli": {
  "command": "node",
  "args": ["d:/roo-extensions/mcps/external/win-cli/server/dist/index.js"],
  "transportType": "stdio",
  "disabled": false,
  "alwaysAllow": [ "execute_command", "get_active_terminal_cwd", ... ]
}
```

Tout autre chemin dans `args[0]` = **drift critique** (incident #1482 : agents reintroduisent `npx @simonb97/...` apres refactors config).

**Validation automatique :** `powershell -File scripts/validation/validate-wincli-config.ps1`
- Lit `%APPDATA%\...\mcp_settings.json`
- Detecte patterns `npx|@simonb97|@anthropic/win-cli|node_modules` dans `args[0]`
- Verifie binaire cible existe + `package.json` v0.2.0
- Exit 0 = OK, 1 = drift, 2 = config manquante

**Integration `/coordinate` :** le coordinateur DOIT faire tourner ce script en phase initiale et bloquer si drift.

## Config MCP sk-agent

**sk-agent DOIT etre dans `~/.claude.json` (global), JAMAIS dans `.mcp.json` (project root).**

Cause regression #1557 : `.mcp.json` project-level surcharge silencieusement la config globale.
**Verification :** `cat .mcp.json` a la racine ne doit PAS contenir `sk-agent`.

## Protocole STOP & REPAIR — Claude Code

```
1. STOP   : Arreter la tache
2. LOG    : Dashboard [CRITICAL]
3. DIAG   : roosync_mcp_management(action: "manage", subAction: "read")
4. FIX    : roosync_mcp_management(subAction: "update_server_field") ou modifier sources
5. TEST   : Appeler l'outil pour confirmer
6. ESCAL  : RooSync URGENT si non reparable
7. RESUME : Seulement apres confirmation
```

## Protocole STOP & REPAIR — Roo Scheduler

```
1. STOP → 2. WRITE [CRITICAL] → 3. REPORT bilan → 4. WAIT prochain tick
```

## Pre-flight Scheduler (CRITIQUE)

**READ-ONLY.** Ne JAMAIS modifier config, redemarrer serveur, ou utiliser ask_followup_question en scheduler.
Si critique absent : signaler [CRITICAL], terminer proprement.

## Verification Proactive (Coordinateur)

**OBLIGATION apres TOUT changement de config :**
1. Lister 6 machines
2. Verifier Claude (roo-state-manager 34 tools) + Roo (win-cli fork local) + pas de MCP retire
3. Si divergence → directive corrective URGENTE

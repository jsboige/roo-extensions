# Inventaire des Outils et Protocole STOP & REPAIR

**Version:** 1.0.0
**Cree:** 2026-02-21
**Contexte:** Incidents recurrents de perte d'outils non detectee (win-cli web1, condensation po-2023)

---

## Principe

**Si un outil critique est absent, TOUT s'arrete.** Pas de mode degrade, pas de contournement, pas d'accommodation. On repare d'abord, on travaille ensuite.

---

## Inventaire des MCPs Attendus

### MCPs CRITIQUES (toutes machines, scheduler bloque sans eux)

| MCP | Outils attendus | Verification | Role |
|-----|-----------------|-------------|------|
| **win-cli** | 9 (`execute_command`, `get_command_history`, `ssh_execute`, `ssh_disconnect`, `create_ssh_connection`, `read_ssh_connections`, `update_ssh_connection`, `delete_ssh_connection`, `get_current_directory`) | `execute_command(shell="powershell", command="echo OK")` | Toutes commandes shell (OBLIGATOIRE depuis b91a841c) |
| **roo-state-manager** | 36 (ListTools) | `conversation_browser(action: "current")` | Grounding conversationnel, coordination, monitoring |

**Config win-cli correcte (fork local 0.2.0) :**
```json
"win-cli": {
  "command": "node",
  "args": ["{CHEMIN_ROO_EXTENSIONS}/mcps/external/win-cli/server/dist/index.js"],
  "transportType": "stdio",
  "disabled": false
}
```

**NE JAMAIS utiliser** `npx @anthropic/win-cli` (npm 0.2.1 casse).

### MCPs STANDARDS (disponibles, pas bloquants si absents)

| MCP | Outils | Role |
|-----|--------|------|
| **playwright** | 22 | Automation web, screenshots |
| **markitdown** | 1 | Conversion documents |

### MCPs OPTIONNELS (machine-specifique)

| MCP | Machines | Note |
|-----|----------|------|
| **jupyter** | ai-01, po-2023, po-2025, po-2026 | DOIT etre `disabled: true` (152 tools = scheduler crash) |
| **sk-agent** | ai-01, po-2023 | Agents LLM multi-modeles |

### MCPs RETIRES (NE DOIVENT PAS etre presents)

| MCP | Remplace par | Depuis |
|-----|-------------|--------|
| **desktop-commander** | win-cli (fork 0.2.0) | #468 revert |
| **github-projects-mcp** | `gh` CLI natif | #368 |
| **quickfiles** | Outils natifs Read/Write | CONS-1 |

---

## Protocole STOP & REPAIR

### Quand declencher

**IMMEDIATEMENT** si l'une de ces conditions est detectee :

1. Un MCP CRITIQUE est absent des system-reminders (Claude Code)
2. Un appel a un outil critique retourne une erreur de type "tool not found" ou "server not available"
3. Le nombre d'outils ListTools diverge significativement de l'attendu (36 pour roo-state-manager)
4. Un MCP RETIRE est detecte comme actif (desktop-commander, quickfiles)

### Procedure (Claude Code)

```
1. STOP   : Arreter la tache en cours immediatement
2. LOG    : Documenter dans INTERCOM : [CRITICAL] Outil {nom} absent/defaillant
3. DIAG   : Verifier la config MCP :
            - roosync_mcp_management(action: "manage", subAction: "read")
            - Comparer avec cet inventaire
4. FIX    : Corriger la config si possible :
            - roosync_mcp_management(action: "manage", subAction: "update_server_field")
            - Si structural : modifier les sources + regenerer
5. TEST   : Verifier le fix :
            - Appeler l'outil pour confirmer qu'il repond
6. ESCAL  : Si non reparable :
            - RooSync message URGENT au coordinateur (si executeur)
            - Message INTERCOM [CRITICAL] pour Roo
            - Issue GitHub si nouveau probleme
7. RESUME : Reprendre le travail UNIQUEMENT apres confirmation de disponibilite
```

### Procedure (Roo Scheduler)

```
1. STOP   : Arreter la delegation de taches
2. WRITE  : Ecrire dans INTERCOM : [CRITICAL] MCP {nom} non disponible
3. REPORT : Rapporter l'echec dans le bilan scheduler (Etape 3)
4. WAIT   : NE PAS tenter de contournement. Attendre le prochain tick.
```

---

## Verification Proactive (Coordinateur)

### Apres TOUT changement de configuration

**OBLIGATION du coordinateur (myia-ai-01) apres :**
- Modification de `.roomodes` ou modes-config.json
- Modification des workflows scheduler
- Ajout/retrait/modification d'un MCP
- Toute modification qui affecte les capacites des agents

**Procedure :**
1. Lister TOUTES les machines (6)
2. Pour chaque machine, verifier via RooSync ou directement :
   - win-cli pointe vers le fork local (PAS npx)
   - roo-state-manager repond (36 tools)
   - Aucun MCP retire n'est actif
3. Si divergence detectee : envoyer directive corrective IMMEDIATE (priorite URGENT)
4. Suivre jusqu'a confirmation de correction

### Verification periodique (chaque tour de sync)

Au minimum a chaque `/sync-tour` ou `/coordinate` :
- Verifier les outils disponibles dans les system-reminders
- Si MCP absent : declencher STOP & REPAIR avant toute autre action

---

## Comptage de Reference

| MCP | Outils (count) | Derniere verification |
|-----|----------------|----------------------|
| roo-state-manager | 36 | 2026-02-21 |
| win-cli | 9 | 2026-02-21 |
| playwright | 22 | 2026-02-21 |
| markitdown | 1 | 2026-02-21 |
| jupyter | 22 (DISABLED) | 2026-02-21 |

**Note :** Le fichier `roo-config/mcp/reference-alwaysallow.json` liste les outils pour Roo alwaysAllow. Ce fichier-ci est le contrat de DISPONIBILITE, pas d'approbation.

---

## Historique des Incidents

| Date | Machine | Probleme | Impact | Root Cause |
|------|---------|----------|--------|------------|
| 2026-02-21 | myia-web1 | win-cli absent apres modes fix | Scheduler bloque | Pas de verification cross-machine apres b91a841c |
| 2026-02-21 | myia-ai-01 | Contexte explose (--coverage) | Scheduler bloque 5h | Output non limite, pas de garde-fou |
| 2026-02-21 | myia-po-2023 | Boucle condensation infinie | Scheduler bloque | Seuil condensation + INTERCOM sature |

---

**Derniere mise a jour :** 2026-02-21

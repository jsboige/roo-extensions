# Inventaire des Outils et Protocole STOP & REPAIR

**Version:** 2.0.0 (Roo)
**Cree:** 2026-02-21
**Mis à jour:** 2026-04-05
**Contexte:** Incidents recurrents de perte d'outils non detectee (win-cli web1, condensation po-2023, roo-state-manager Claude Code)
**Cleanup #658:** win-cli supprimé de la config Claude Code sur myia-po-2023 + myia-po-2024 (2026-03-14) - Roo uniquement maintenant
**Issue #708:** Ajout section dédiée "win-cli - Roo uniquement" pour clarifier que win-cli n'est critique que pour Roo
**Issue #791:** Harmonisation avec version Claude Code (+227% de contenu)

---

## ⛔ RÈGLE NON NÉGOCIABLE

**L'ENVIRONNEMENT EST NON NÉGOCIABLE.**

1. **Si un outil critique est absent, TOUT S'ARRÊTE.**
   - Pas de mode dégradé
   - Pas de contournement
   - Pas d'accommodation
   - **ON RÉPARE D'ABORD, ON TRAVAILLE ENSUITE**

2. **La perte d'un outil critique est un INCIDENT MAJEUR:**
   - Déclenche le protocole STOP & REPAIR immédiatement
   - Doit être documenté dans INTERCOM avec tag [CRITICAL]
   - Doit faire l'objet d'une investigation de root cause

3. **Aucune tâche ne peut progresser sans les outils critiques.**

4. **La complaisance est inacceptable.**

---

## Configuration Claude Code vs Roo (CRITIQUE)

**⚠️ Claude Code et Roo ont des configurations MCP SÉPARÉES.**

| Agent | Fichier de config | Chemin |
|-------|-------------------|--------|
| **Roo** | `mcp_settings.json` | `%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/` |
| **Claude Code** | UI VS Code ou `mcp.json` | À configurer via l'extension Claude Code |

**Conséquence**: Un MCP peut être disponible pour Roo mais PAS pour Claude Code (et inversement).

**OBLIGATION**: Quand on ajoute un MCP critique, il DOIT être configuré pour **LES DEUX** agents.

---

## Principe

**Si un outil critique est absent, TOUT s'arrete.** Pas de mode degrade, pas de contournement, pas d'accommodation. On repare d'abord, on travaille ensuite.

---

## Inventaire des MCPs Attendus

### MCPs CRITIQUES

**Pour Claude Code :**

| MCP | Outils attendus | Verification | Role |
|-----|-----------------|-------------|------|
| **roo-state-manager** | 34 (ListTools) | `conversation_browser(action: "current")` | Grounding conversationnel, coordination, monitoring |

**Pour Roo (scheduler bloque sans eux) :**

| MCP | Outils attendus | Verification | Role |
|-----|-----------------|-------------|------|
| **win-cli** | 9 (`execute_command`, `get_command_history`, `ssh_execute`, `ssh_disconnect`, `create_ssh_connection`, `read_ssh_connections`, `update_ssh_connection`, `delete_ssh_connection`, `get_current_directory`) | `execute_command(shell="powershell", command="echo OK")` | Toutes commandes shell (OBLIGATOIRE depuis b91a841c - modes n'ont plus le groupe `command`) |

**Note importante :** win-cli est critique pour **Roo uniquement**. Claude Code peut utiliser l'outil `Bash` natif pour les commandes shell.

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

### win-cli - Roo uniquement

**win-cli est critique UNIQUEMENT pour Roo Code**, pas pour Claude Code.

**Pourquoi ?** Les modes Roo `-simple` (code-simple, debug-simple, ask-simple) n'ont PAS accès au terminal natif (groupe `command`). Ils utilisent win-cli (groupe `mcp`) comme leur seul accès shell.

**Claude Code** a accès à l'outil `Bash` natif et n'a PAS besoin de win-cli pour les commandes shell.

**Conséquence :**
- **Roo** : win-cli est OBLIGATOIRE (dans `mcp_settings.json` global)
- **Claude Code** : win-cli est OPTIONNEL (peut être absent de `~/.claude.json`)

**Référence :** Issue #650 - Dual-harnais support (win-cli configuré pour Roo uniquement)

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
3. Le nombre d'outils ListTools diverge significativement de l'attendu (34 pour roo-state-manager)
4. Un MCP RETIRE est detecte comme actif (desktop-commander, quickfiles)

### Procedure (Roo Scheduler)

```
1. STOP   : Arreter la delegation de taches
2. WRITE  : Ecrire dans INTERCOM : [CRITICAL] MCP {nom} non disponible
3. REPORT : Rapporter l'echec dans le bilan scheduler (Etape 3)
4. WAIT   : NE PAS tenter de contournement. Attendre le prochain tick.
```

### Procedure (Claude Code)

```
1. STOP   : Arreter la tache
2. LOG    : Dashboard [CRITICAL]
3. DIAG   : roosync_mcp_management(action: "manage", subAction: "read")
4. FIX    : roosync_mcp_management(subAction: "update_server_field") ou modifier sources
5. TEST   : Appeler l'outil pour confirmer
6. ESCAL  : RooSync URGENT si non reparable
7. RESUME : Seulement apres confirmation
```

---

## Pre-flight Check (AVANT Etape 1)

A chaque execution scheduler, AVANT de commencer le workflow :

1. Verifier que `execute_command` est disponible (tenter `echo OK`)
2. Si echec : ecrire INTERCOM [CRITICAL] et terminer proprement
3. Si succes : continuer le workflow normal

## Pre-flight en mode Scheduler (CRITIQUE)

**Le pre-flight check est READ-ONLY.** En mode scheduler :
- NE JAMAIS tenter de modifier la config MCP (mcp_settings.json)
- NE JAMAIS tenter de redemarrer un serveur MCP
- NE JAMAIS utiliser ask_followup_question (interdit en scheduler)
- Si un outil critique est absent : ecrire INTERCOM [CRITICAL], terminer proprement

## Accommodation INTERDITE

**NE PAS :**
- Continuer en mode degrade si un outil critique manque
- Tenter des contournements (utiliser un autre outil a la place)
- Ignorer les erreurs de type "tool not found"
- Rapporter "partiellement OK" quand un outil critique est absent

**TOUJOURS :**
- Signaler immediatement via INTERCOM [CRITICAL]
- Arreter le workflow proprement
- Attendre le prochain tick ou intervention Claude Code

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
   - **Claude Code** : roo-state-manager repond (34 tools)
   - **Roo** : win-cli pointe vers le fork local (PAS npx)
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
| roo-state-manager | 34 | 2026-04-05 |
| win-cli | 9 | 2026-04-05 |
| playwright | 22 | 2026-04-05 |
| markitdown | 1 | 2026-04-05 |
| jupyter | 22 (DISABLED) | 2026-04-05 |

**Note :** Le fichier `roo-config/mcp/reference-alwaysallow.json` liste les outils pour Roo alwaysAllow. Ce fichier-ci est le contrat de DISPONIBILITE, pas d'approbation.

---

**Historique des Incidents :** Voir [`.claude/docs/reference/incident-history.md`](../docs/reference/incident-history.md) (liste complète des incidents et leçons apprises).

---

**Derniere mise a jour :** 2026-04-05

# Verification des Outils - STOP & REPAIR

## Regle

**Si un outil MCP critique est absent ou ne repond pas, ARRETER IMMEDIATEMENT tout travail et rapporter dans INTERCOM.**

## Outils Critiques (scheduler bloque sans eux)

### win-cli (OBLIGATOIRE depuis b91a841c)

Les modes `-simple` n'ont PAS acces au terminal natif. Sans win-cli, AUCUNE commande shell n'est possible.

**Test de verification :**
```
execute_command(shell="powershell", command="echo OK")
```

Si cet appel echoue ou si `execute_command` n'est pas disponible :
1. **STOP** : Ne PAS continuer le workflow
2. **INTERCOM** : Ecrire `[CRITICAL] MCP win-cli non disponible. Scheduler bloque.`
3. **Bilan** : Rapporter dans Etape 3 et terminer

**Config attendue :** Fork local `node mcps/external/win-cli/server/dist/index.js`
**JAMAIS** `npx @anthropic/win-cli` (npm 0.2.1 casse).

### roo-state-manager (grounding)

36 outils attendus. Verifie implicitement si `task_browse`, `read_file`, `write_to_file` sont accessibles.

## Outils Retires (NE DOIVENT PAS etre utilises)

| Ancien outil | Remplace par | Raison |
|-------------|-------------|--------|
| `desktop-commander` / `start_process` | `win-cli` / `execute_command` | desktop-commander retire |
| `quickfiles` / `read_multiple_files` | `read_file` (natif) | quickfiles retire (CONS-1) |
| `github-projects-mcp` | `gh` CLI via win-cli | MCP deprecie (#368) |

## Pre-flight Check (AVANT Etape 1)

A chaque execution scheduler, AVANT de commencer le workflow :

1. Verifier que `execute_command` est disponible (tenter `echo OK`)
2. Si echec : ecrire INTERCOM [CRITICAL] et terminer proprement
3. Si succes : continuer le workflow normal

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

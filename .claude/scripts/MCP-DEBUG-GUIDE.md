# Guide de Debug : Erreur "Tool names must be unique"

## Problème

Erreur dans l'extension VS Code Claude Code :
```
API Error: 400 {"type":"error","error":{"type":"invalid_request_error","message":"tools: Tool names must be unique."}}
```

## Cause Probable

Bug dans Claude Code qui duplique les outils MCP lors de l'initialisation des sous-agents dans l'extension VS Code (issues #10668, #10676).

## Processus de Debug

### Étape 1 : Test sans aucun MCP

```powershell
cd D:\Dev\roo-extensions\.claude\scripts
.\Switch-MCPConfig.ps1 -Config none
```

**Action :** Fermer complètement VS Code (Ctrl+Q), relancer, tester l'extension.

**Si ça fonctionne :** Le problème vient d'un MCP → passer à l'étape 2.
**Si ça ne fonctionne pas :** Problème ailleurs (agents, config VS Code).

### Étape 2 : Tester chaque MCP individuellement

```powershell
# Test Jupyter seul
.\Switch-MCPConfig.ps1 -Config jupyter
# → Redémarrer VS Code → Tester

# Test GitHub seul
.\Switch-MCPConfig.ps1 -Config github
# → Redémarrer VS Code → Tester

# Test RooSync seul
.\Switch-MCPConfig.ps1 -Config roo
# → Redémarrer VS Code → Tester
```

**Résultats attendus :** Identifier quel serveur cause l'erreur.

### Étape 3 : Tester les combinaisons

Si un seul MCP fonctionne, tester les paires :

```powershell
# Jupyter + GitHub
.\Switch-MCPConfig.ps1 -Config jupyter-github

# Jupyter + RooSync
.\Switch-MCPConfig.ps1 -Config jupyter-roo

# GitHub + RooSync
.\Switch-MCPConfig.ps1 -Config github-roo
```

### Étape 4 : Restaurer la config complète

```powershell
.\Switch-MCPConfig.ps1 -Config all
# OU
.\Switch-MCPConfig.ps1 -Config restore
```

## Fichiers de Sauvegarde

- **Original :** `~\.claude.json.backup` (créé automatiquement)
- **Actuel :** `~\.claude.json`

## Serveurs MCP Configurés

| Serveur | Outils | Suspicion |
|---------|--------|-----------|
| **jupyter** | ~50 outils Jupyter | Faible |
| **github-projects-mcp** | 30+ outils GitHub | Moyenne |
| **roo-state-manager** | 14 outils RooSync (filtrés) | Élevée ⚠️ |

### Suspicion élevée pour roo-state-manager

Le serveur `roo-state-manager` utilise un **wrapper** (`mcp-wrapper.cjs`) qui filtre les outils. Risque de conflit si :
- Le wrapper ne filtre pas correctement dans l'extension VS Code
- Les outils sont exposés deux fois (avant et après filtrage)

## Commandes Rapides

```powershell
# Désactiver tout
.\Switch-MCPConfig.ps1 -Config none

# Tester un seul serveur
.\Switch-MCPConfig.ps1 -Config roo

# Réactiver tout
.\Switch-MCPConfig.ps1 -Config all

# Restaurer backup
.\Switch-MCPConfig.ps1 -Config restore
```

## Après Identification

Une fois le serveur problématique identifié :

1. **Créer une issue GitHub** sur https://github.com/anthropics/claude-code/issues
2. **Documenter** : serveur MCP, version Claude Code, reproduction steps
3. **Workaround temporaire** : Désactiver ce serveur dans VS Code, utiliser le CLI pour ces outils

## Notes

- ⚠️ **Toujours redémarrer VS Code complètement** après chaque changement
- 💡 Le **CLI fonctionne** → utiliser `claude` en ligne de commande si besoin urgent
- 📋 Le problème est **spécifique à l'extension VS Code**, pas au CLI

---

**Dernière mise à jour :** 2026-01-21
**Version Claude Code :** 2.1.14
**Machine :** myia-po-2023

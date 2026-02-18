# DesktopCommanderMCP - Documentation de Déploiement

**Version:** v0.2.35
**Issue:** #468 - Migration win-cli vers DesktopCommanderMCP
**Statut:** Phase 3 COMPLETEE - Deploiement cross-machine

---

## Vue d'ensemble

**DesktopCommanderMCP** (DCMCP) est un serveur MCP pour Windows qui fournit 26 outils pour les operations systeme, fichiers, processus et recherche.

**Avantages vs win-cli :**
- 26 outils vs 9 (opérations fichier, recherche, processus, config)
- Operateurs shell (`&&`, `|`, `;`) fonctionnent **nativement** - pas de fork necessaire
- Configuration via fichier JSON (persistent)
- Shell configurable : PowerShell, CMD, Git Bash, WSL

---

## Installation

### 1. Installation du package npm

```powershell
npm install -g @wonderwhy-er/desktop-commander@latest
```

### 2. Deploiement de la configuration

```powershell
# Depuis le depot roo-extensions
cd mcps/external/desktop-commander
.\scripts\deploy-desktop-commander.ps1
```

Ce script :
1. Cree le repertoire `~/.claude-server-commander/` si necessaire
2. Copie `config/desktop-commander-config.json` vers `~/.claude-server-commander/config.json`
3. Configure Git Bash comme shell par defaut (pour compatibilite &&)

### 3. Configuration des auto-approbations Roo

```powershell
.\scripts\update-autoapprovals.ps1
```

Ce script met a jour `~/.claude-server-commander/config.json` pour ajouter les 26 outils dans `alwaysAllow`.

---

## Configuration

### Fichier de configuration

**Chemin :** `~/.claude-server-commander/config.json`

**Options principales :**

```json
{
  "shell": "gitbash",  // powershell | cmd | gitbash | wsl
  "shellLocation": "C:\\Program Files\\Git\\bin\\sh.exe",
  "workingDirectory": "C:\\dev"
}
```

### Shells disponibles

| Shell | Commande | Operateurs supportes |
|-------|----------|---------------------|
| PowerShell | `powershell` | `;` (pas `&&`) |
| CMD | `cmd` | `&&`, `\|`, `;` |
| Git Bash | `gitbash` | `&&`, `\|`, `;` |
| WSL | `wsl` | `&&`, `\|`, `;` |

**Recommandation :** Utiliser **Git Bash** pour la compatibilite avec les scripts existants (`&&`).

---

## Outils disponibles (26)

### Operations fichier

- `read_file` - Lire contenu fichier
- `write_file` - Ecrire contenu fichier
- `read_multiple_files` - Lire plusieurs fichiers
- `write_pdf` - Generer PDF
- `move_file` - Deplacer fichier
- `list_directory` - Lister repertoire
- `create_directory` - Creer repertoire
- `get_file_info` - Informations fichier

### Processus

- `start_process` - Lancer processus (asynchrone)
- `read_process_output` - Lire sortie processus (asynchrone)
- `interact_with_process` - Interagir avec processus (stdin/stdout)
- `list_processes` - Lister processus
- `kill_process` - Tuer processus
- `force_terminate` - Forcer termination
- `list_sessions` - Lister sessions actives

### Recherche

- `start_search` - Lancer recherche fichier (asynchrone, streaming)
- `get_more_search_results` - Pagination resultats recherche
- `stop_search` - Arrêter recherche
- `list_searches` - Lister recherches actives

### Configuration

- `get_config` - Lire configuration
- `set_config_value` - Modifier configuration
- `get_prompts` - Lister prompts disponibles

### Statistiques

- `get_usage_stats` - Statistiques utilisation
- `get_recent_tool_calls` - Appels recents
- `give_feedback_to_desktop_commander` - Feedback au developpeur

---

## Differences clés vs win-cli

| Aspect | win-cli | DesktopCommanderMCP |
|--------|---------|---------------------|
| **Nombre d'outils** | 9 | 26 |
| **Operateurs** | `&&` fork necessaire | Natifs (pas de fork) |
| **Asynchrone** | Non | Oui (`start_process`, `start_search`) |
| **Configuration** | CLI args | Fichier JSON persistent |
| **Auto-approbation** | Manuelle | Script automatise |
| **SSH** | Oui | Non |

**Note :** Si SSH est necessaire, conserver win-cli en parallele.

---

## Exemples d'utilisation

### Via Roo Code

```xml
<use_mcp_tool>
<server_name>desktop-commander</server_name>
<tool_name>start_process</tool_name>
<arguments>{"command": "git status && git pull", "shell": "gitbash"}</arguments>
</use_mcp_tool>
```

### Via sk-agent

```json
{
  "agent": "analyst",
  "prompt": "Execute 'git status' in c:\\dev\\roo-extensions"
}
```

---

## Dépannage

### Problème : Les outils ne sont pas auto-approuvés

**Solution :** Executer `update-autoapprovals.ps1` et redémarrer VS Code.

### Problème : `start_search` semble bloquer

**Solution :** `start_search` est asynchrone/streaming. Il faut utiliser `get_more_search_results` pour paginer et `stop_search` pour terminer.

### Problème : Shell PowerShell ne reconnaît pas `&&`

**Solution :** Utiliser Git Bash (`shell: "gitbash"`) ou remplacer `&&` par `;`.

### Problème : Config non persistée

**Solution :** Deployer le fichier config AVANT de lancer DCMCP pour la premiere fois. La config n'est lue qu'au démarrage.

---

## Statut de déploiement

| Machine | Statut | Date |
|---------|--------|------|
| myia-ai-01 | ✅ Déployé | 2026-02-17 |
| myia-po-2023 | ✅ Déployé | 2026-02-17 |
| myia-po-2024 | ✅ Déployé | 2026-02-17 |
| myia-po-2025 | ✅ Déployé | 2026-02-17 |
| myia-po-2026 | ✅ Déployé | 2026-02-17 |
| myia-web1 | ✅ Déployé | 2026-02-18 |

---

## Références

- **Package npm :** https://www.npmjs.com/package/@wonderwhy-er/desktop-commander
- **Issue #468 :** Migration win-cli vers DesktopCommanderMCP
- **Issue #473 :** Auto-approbations Roo - Agents schedulés bloqués
- **Scripts déploiement :** `mcps/external/desktop-commander/scripts/`

---

**Dernière mise à jour :** 2026-02-18
**Auteur :** Claude Code (myia-po-2026)

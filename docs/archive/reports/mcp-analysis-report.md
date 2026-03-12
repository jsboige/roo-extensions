# Analyse des MCPs Installés et de leur Utilisation

## Date d'analyse
2026-03-12

## Sources d'information
- Répertoires `mcps/external/` et `mcps/internal/servers/`
- Logs VS Code (Extension Host, Renderer, Roo-Code Output)
- Recherche sémantique dans les tâches Roo

---

## 1. MCPs Externes Installés

| MCP | Type | Statut Logs |
|-----|------|-------------|
| **desktop-commander** | Retiré | Non utilisé (retiré du système) |
| **docker** | Utilitaire | Non détecté dans logs |
| **git** | Outil Git | Non détecté dans logs |
| **github** | GitHub API | Non détecté dans logs |
| **jupyter** | Jupyter Notebook | Non détecté dans logs |
| **markitdown** | Conversion documents | ✅ Actif (démarré dans logs) |
| **mcp-server-ftp** | FTP | Non détecté dans logs |
| **Office-PowerPoint-MCP-Server** | PowerPoint | Non détecté dans logs |
| **playwright** | Automatisation web | ✅ Actif (démarré dans logs) |
| **searxng** | Moteur recherche | Non détecté dans logs |
| **win-cli** | CLI Windows | ✅ Actif (démarré dans logs) |

---

## 2. MCPs Internes Installés

| MCP | Type | Statut Logs |
|-----|------|-------------|
| **github-projects-mcp** | GitHub Projects | ❌ Déprécié (remplacé par `gh` CLI) |
| **jinavigator-server** | Navigation web | ❌ Erreur (module non trouvé) |
| **jupyter-mcp-server** | Jupyter | Non détecté dans logs |
| **jupyter-papermill-mcp-server** | Jupyter Papermill | Non détecté dans logs |
| **open-terminal-mcp** | Terminal | Non détecté dans logs |
| **quickfiles-server** | Fichiers rapides | Non détecté dans logs |
| **roo-state-manager** | Gestion Roo | ✅ Actif (avec erreurs d'indexation) |
| **sk-agent** | Semantic Kernel | Non détecté dans logs |

---

## 3. MCPs Actifs (détectés dans les logs)

### 3.1 win-cli
- **Statut**: ✅ Actif
- **Premier démarrage**: 2026-03-07 09:55:13
- **Logs**: `Loaded config from C:/dev/roo-extensions/mcps/external/win-cli/config/win_cli_config.json`
- **Utilisation**: Très fréquent (outil principal pour commandes shell)

### 3.2 playwright
- **Statut**: ✅ Actif
- **Premier démarrage**: 2026-03-07 09:55:17
- **Logs**: `MCP Server started`, `Port 5174 is in use, skipping web server`
- **Utilisation**: Modérée (automatisation web)

### 3.3 markitdown
- **Statut**: ✅ Actif
- **Premier démarrage**: 2026-03-07 09:55:18
- **Logs**: `Couldn't find ffmpeg or avconv - defaulting to ffmpeg, but may not work`
- **Utilisation**: Modérée (conversion documents)

### 3.4 roo-state-manager
- **Statut**: ⚠️ Actif avec erreurs
- **Premier démarrage**: 2026-03-07 09:55:21
- **Erreurs**:
  - Variables d'environnement manquantes (QDRANT_URL, QDRANT_API_KEY, etc.)
  - Erreurs d'indexation (AuthenticationError 401)
  - Circuit breaker activé (trop d'échecs)
  - Rate-limiting (100/100 opérations)
- **Utilisation**: Fréquente mais avec problèmes de configuration

---

## 4. MCPs Peu ou Pas Utilisés

### 4.1 MCPs avec erreurs de démarrage

| MCP | Erreur | Recommandation |
|-----|--------|----------------|
| **jinavigator-server** | Module non trouvé (`dist/index.js` manquant) | Rebuild ou désactiver |
| **github-projects-mcp** | Déprécié (remplacé par `gh` CLI) | Supprimer |

### 4.2 MCPs jamais détectés dans les logs

| MCP | Type | Recommandation |
|-----|------|----------------|
| **desktop-commander** | Retiré | Supprimer |
| **docker** | Utilitaire | Optionnel |
| **git** | Outil Git | Optionnel |
| **github** | GitHub API | Optionnel |
| **jupyter** | Jupyter Notebook | Optionnel |
| **mcp-server-ftp** | FTP | Optionnel |
| **Office-PowerPoint-MCP-Server** | PowerPoint | Optionnel |
| **searxng** | Moteur recherche | Optionnel |
| **jupyter-mcp-server** | Jupyter | Optionnel |
| **jupyter-papermill-mcp-server** | Jupyter Papermill | Optionnel |
| **open-terminal-mcp** | Terminal | Optionnel |
| **quickfiles-server** | Fichiers rapides | Optionnel |
| **sk-agent** | Semantic Kernel | Optionnel |

---

## 5. Recommandations

### 5.1 Actions prioritaires

1. **Supprimer MCPs dépréciés/retirés**:
   - `desktop-commander` (retiré du système)
   - `github-projects-mcp` (remplacé par `gh` CLI)

2. **Rebuild ou désactiver**:
   - `jinavigator-server` (module non compilé)

3. **Corriger configuration**:
   - `roo-state-manager` (variables d'environnement manquantes)

### 5.2 MCPs optionnels à évaluer

Les MCPs suivants n'ont jamais été détectés dans les logs. Évaluer leur utilité réelle:

- **docker**, **git**, **github**, **jupyter**: Utilitaires généraux
- **mcp-server-ftp**, **Office-PowerPoint-MCP-Server**, **searxng**: Outils spécialisés
- **jupyter-mcp-server**, **jupyter-papermill-mcp-server**, **open-terminal-mcp**: Alternatives à jupyter
- **quickfiles-server**, **sk-agent**: Outils spécifiques

### 5.3 MCPs actifs recommandés

Ces MCPs sont confirmés comme actifs et utiles:

- **win-cli**: Outil principal pour commandes shell (obligatoire en mode `-simple`)
- **playwright**: Automatisation web (utile pour tests et scraping)
- **markitdown**: Conversion documents (utile pour PDF, DOCX)

---

## 6. Conclusion

### 6.1 Statistiques

- **Total MCPs**: 19
- **Actifs**: 4 (win-cli, playwright, markitdown, roo-state-manager)
- **Peu utilisés**: 15
- **Dépréciés/Retirés**: 2 (desktop-commander, github-projects-mcp)
- **Avec erreurs**: 2 (jinavigator-server, roo-state-manager)

### 6.2 Exploration recommandée

Pour affiner cette analyse, explorer:
1. Les fichiers de configuration MCP (`mcp_settings.json`, `custom_modes.yaml`)
2. L'historique des tâches Roo pour voir quels MCPs sont invoqués
3. Les scripts de déploiement pour comprendre l'intention d'installation

---

*Document généré automatiquement par analyse des logs VS Code et répertoires MCP.*

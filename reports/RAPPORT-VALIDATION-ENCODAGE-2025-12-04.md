# Rapport de Diagnostic UTF-8 - Roo Extensions

**Date**: 2025-12-04 23:15:19  
**Genere par**: scripts/utf8/diagnostic.ps1  
**Version**: 3.0 Consolidee  

## [STATS] Resume Executif

**Score Global**: 40% - [FAIL] PROBLÉMATIQUE

| Composant | Score | État |
|-----------|-------|------|
| Systeme PowerShell | 0% | [FAIL] |
| Profil PowerShell | 0% | [FAIL] |
| Configuration Git | 50% | [WARNING] |
| Configuration VSCode | 100% | [OK] |
| Fichiers | 50% | [FAIL] |

## 🖥️ Configuration Systeme

**PowerShell**: 7.5.4 (Core)  
**OS**: Microsoft Windows NT 10.0.26200.0  
**Code Page**:  65001  
**Console Encoding**: Output=65001, Input=65001  

## [TOOL] Profil PowerShell

**Chemin**: $(System.Collections.Hashtable.PowerShellConfig.ProfilePath)  
**Existe**: [OK] OUI  
**Configuration UTF-8**: [FAIL] ABSENTE  
**Sauvegardes**: 1  

## 🔄 Configuration Git

**Installe**: [OK] OUI (git version 2.50.1.windows.1)  
**Configuration UTF-8**: [FAIL] INCORRECTE  

### Details Configuration Git
 - **core.quotepath**: $value   - **i18n.commitencoding**: $value   - **core.safecrlf**: $value   - **core.autocrlf**: $value   - **i18n.logoutputencoding**: $value   - **gui.encoding**: $value  

## 📝 Configuration VSCode

**Repertoire .vscode**: [OK] EXISTE  
**settings.json**: [OK] EXISTE  
**Configuration UTF-8**: [OK] CORRECTE  


## 📁 Problemes de Fichiers

[FAIL] **91 fichier(s) problematique(s)**:

| Fichier | BOM | CRLF | Valide |
|---------|-----|------|--------| | `.state\sync-config.ref.json` | [OK] | [FAIL] | [OK] | | `.vscode\settings.json` | [OK] | [FAIL] | [OK] | | `archive\docs-20251022\018-diagnostic-results.json` | [FAIL] UTF-8 | [OK] | [OK] | | `backups\terminal-config\settings-backup-20251126-224515.json` | [OK] | [FAIL] | [OK] | | `backups\vscode-config\vscode-settings-backup-20251126-103642.json` | [OK] | [FAIL] | [OK] | | `encoding-fix\.vscode\settings.json` | [OK] | [FAIL] | [OK] | | `exports\ui-snippets\index.json` | [FAIL] UTF-8 | [OK] | [OK] | | `mcps\backups\mcp_settings.backup.20250908-232811.metadata.json` | [OK] | [FAIL] | [OK] | | `mcps\external\markitdown\source\.devcontainer\devcontainer.json` | [OK] | [FAIL] | [OK] | | `mcps\external\markitdown\source\packages\markitdown\tests\test_files\test.json` | [OK] | [FAIL] | [OK] | | `mcps\external\mcp-server-ftp\package.json` | [OK] | [FAIL] | [OK] | | `mcps\external\mcp-server-ftp\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\external\mcp-server-ftp\node_modules\.package-lock.json` | [OK] | [FAIL] | [OK] | | `mcps\external\mcp-server-ftp\node_modules\typescript\lib\typesMap.json` | [OK] | [OK] | [FAIL] | | `mcps\external\Office-PowerPoint-MCP-Server\mcp_config_sample.json` | [OK] | [FAIL] | [OK] | | `mcps\external\Office-PowerPoint-MCP-Server\mcp-config.json` | [OK] | [FAIL] | [OK] | | `mcps\external\Office-PowerPoint-MCP-Server\slide_layout_templates.json` | [OK] | [FAIL] | [OK] | | `mcps\external\playwright\source\package-lock.json` | [OK] | [FAIL] | [FAIL] | | `mcps\external\playwright\source\package.json` | [OK] | [FAIL] | [OK] | | `mcps\external\playwright\source\.mcp\server.json` | [OK] | [FAIL] | [OK] | | `mcps\external\playwright\source\extension\manifest.json` | [OK] | [FAIL] | [OK] | | `mcps\external\playwright\source\extension\package-lock.json` | [OK] | [FAIL] | [FAIL] | | `mcps\external\playwright\source\extension\package.json` | [OK] | [FAIL] | [OK] | | `mcps\external\playwright\source\extension\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\external\playwright\source\extension\tsconfig.ui.json` | [OK] | [FAIL] | [OK] | | `mcps\external\playwright\source\extension\src\ui\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\external\playwright\source\node_modules\.package-lock.json` | [OK] | [FAIL] | [OK] | | `mcps\external\win-cli\server\config.sample.json` | [OK] | [FAIL] | [OK] | | `mcps\external\win-cli\server\package-lock.json` | [OK] | [FAIL] | [FAIL] | | `mcps\external\win-cli\server\package.json` | [OK] | [FAIL] | [OK] | | `mcps\external\win-cli\server\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\external\win-cli\server\node_modules\.package-lock.json` | [OK] | [FAIL] | [OK] | | `mcps\external\win-cli\server\node_modules\@sinclair\typebox\package.json` | [OK] | [FAIL] | [OK] | | `mcps\external\win-cli\server\node_modules\char-regex\package.json` | [OK] | [FAIL] | [OK] | | `mcps\external\win-cli\server\node_modules\cjs-module-lexer\package.json` | [OK] | [FAIL] | [OK] | | `mcps\external\win-cli\server\node_modules\color-name\package.json` | [OK] | [FAIL] | [OK] | | `mcps\external\win-cli\server\node_modules\globals\globals.json` | [OK] | [OK] | [FAIL] | | `mcps\external\win-cli\server\node_modules\typescript\lib\typesMap.json` | [OK] | [OK] | [FAIL] | | `mcps\forked\modelcontextprotocol-servers\package-lock.json` | [OK] | [FAIL] | [FAIL] | | `mcps\forked\modelcontextprotocol-servers\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\aws-kb-retrieval-server\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\aws-kb-retrieval-server\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\brave-search\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\brave-search\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\everart\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\everart\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\everything\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\everything\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\filesystem\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\filesystem\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\gdrive\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\gdrive\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\github\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\github\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\gitlab\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\gitlab\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\google-maps\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\google-maps\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\memory\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\memory\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\postgres\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\postgres\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\puppeteer\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\puppeteer\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\redis\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\redis\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\sequentialthinking\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\sequentialthinking\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\slack\package.json` | [OK] | [FAIL] | [OK] | | `mcps\forked\modelcontextprotocol-servers\src\slack\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\package.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\config\mcp_settings_example.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\github-projects-mcp\package-lock.json` | [OK] | [FAIL] | [FAIL] | | `mcps\internal\servers\github-projects-mcp\package.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\github-projects-mcp\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\github-projects-mcp\node_modules\.package-lock.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\github-projects-mcp\node_modules\@sinclair\typebox\package.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\github-projects-mcp\node_modules\char-regex\package.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\github-projects-mcp\node_modules\color-name\package.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\github-projects-mcp\node_modules\globals\globals.json` | [OK] | [OK] | [FAIL] | | `mcps\internal\servers\github-projects-mcp\node_modules\typescript\lib\typesMap.json` | [OK] | [OK] | [FAIL] | | `mcps\internal\servers\jinavigator-server\package-lock.json` | [OK] | [FAIL] | [FAIL] | | `mcps\internal\servers\jinavigator-server\package.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\jinavigator-server\tsconfig.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\jinavigator-server\node_modules\.package-lock.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\jinavigator-server\node_modules\@sinclair\typebox\package.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\jinavigator-server\node_modules\char-regex\package.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\jinavigator-server\node_modules\color-name\package.json` | [OK] | [FAIL] | [OK] | | `mcps\internal\servers\jinavigator-server\node_modules\globals\globals.json` | [OK] | [OK] | [FAIL] | | `mcps\internal\servers\jinavigator-server\node_modules\typescript\lib\typesMap.json` | [OK] | [OK] | [FAIL] |

## [TARGET] Recommandations

### 🟡 Medium Priority

**Probleme**: Parametres par defaut PowerShell non configures  
**Solution**: Definir $PSDefaultParameterValues pour Out-File et Set-Content

 ### 🟡 Medium Priority

**Probleme**: Configuration Git non optimale pour UTF-8  
**Solution**: Configurer Git avec scripts/utf8/setup.ps1

 ### 🟡 Medium Priority

**Probleme**: 91 fichier(s) avec problemes d'encodage  
**Solution**: Corriger avec scripts/utf8/repair.ps1

 ### 🔴 High Priority

**Probleme**: Configuration UTF-8 absente du profil  
**Solution**: Ajouter la configuration avec scripts/utf8/setup.ps1



## [ROCKET] Actions Recommandees

1. **Configuration Rapide**: Executez `scripts/utf8/setup.ps1` pour une configuration automatique
2. **Reparation Fichiers**: Utilisez `scripts/utf8/repair.ps1` pour corriger les fichiers problematiques
3. **Test Configuration**: Relancez `scripts/utf8/diagnostic.ps1` apres les corrections

---
*Rapport genere automatiquement par le systeme de diagnostic Roo Extensions*

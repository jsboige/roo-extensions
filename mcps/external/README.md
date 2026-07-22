# Serveurs MCP Externes

Ce répertoire contient la documentation et les configurations pour les serveurs MCP externes utilisés dans le projet.

## Organisation

Les serveurs MCP externes sont organisés dans les sous-répertoires suivants. Les serveurs **actifs** sont wirés dans `roo-config/settings/servers.json` :

- **docker/** - Documentation et scripts pour la conteneurisation des serveurs MCP
- **git/** - Serveur MCP Git
- **github/** - Serveur MCP GitHub
- **jupyter/** - Intégration Jupyter (lanceur VS Code `start-jupyter-mcp-vscode.bat`)
- **markitdown/** - Conversion PDF/DOCX → Markdown
- **Office-PowerPoint-MCP-Server/** - Génération et édition de présentations PowerPoint *(submodule)*
- **playwright/** - Automatisation web (Playwright)
- **mcp-server-ftp/** - Transferts FTP/SFTP *(submodule)*
- **searxng/** - Recherche web via SearXNG
- **win-cli/** - Exécution de commandes CLI sur Windows

> ❌ **Retirés** (présents pour l'historique, ne pas réinstaller) : `desktop-commander/` — remplacé par les outils natifs Read/Write/Edit (convention [`docs/mcps/INDEX.md`](../../docs/mcps/INDEX.md)).

## Installation

Chaque serveur MCP externe dispose de sa propre documentation d'installation dans son répertoire respectif.

## Configuration

Les configurations des serveurs MCP externes sont définies dans le fichier `roo-config/settings/servers.json`.

## Utilisation

Consultez les fichiers README.md et USAGE.md dans chaque sous-répertoire pour des instructions spécifiques sur l'utilisation de chaque serveur MCP.

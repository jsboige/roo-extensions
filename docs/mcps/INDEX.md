# Index des Serveurs MCP (Model Context Protocol)

**Dernière mise à jour :** 2026-03-15
**Version :** 1.0.0

---

## Vue d'ensemble

Ce document centralise la documentation de tous les serveurs MCP utilisés dans le projet Roo Extensions.

**Pourquoi utiliser les MCPs ?**
- Protocole standard pour l'intégration d'outils avec LLMs
- Communication structurée via JSON-RPC
- Gestion unifiée des ressources et outils

**Architecture des MCPs dans Roo Extensions :**

```
mcps/
├── external/          # Serveurs tiers (community, officiels)
│   ├── docker/        # Conteneurisation
│   ├── filesystem/    # Accès fichiers (npm)
│   ├── git/           # Opérations Git (npm)
│   ├── github/        # API GitHub (npm)
│   ├── jupyter/       # Notebooks Jupyter (community)
│   ├── markitdown/    # Conversion Markdown (community)
│   ├── playwright/    # Automatisation Web (npm)
│   ├── searxng/       # Recherche web (community)
│   ├── win-cli/       # Commandes Windows (fork local)
│   └── ...
└── internal/          # Serveurs développés en interne
    ├── roo-state-manager/  # Gestion état Roo (34 outils)
    ├── sk-agent/           # Multi-agent LLM
    ├── jinavigator-server/ # Web scraping
    ├── jupyter-papermill-mcp-server/
    └── ...
```

---

## Serveurs Internes (Roo Extensions)

Serveurs développés et maintenus par le projet.

### roo-state-manager

**Statut :** ✅ Actif - 37 outils
**Chemin :** `mcps/internal/servers/roo-state-manager/`
**Documentation :** [README complet](../../mcps/internal/servers/roo-state-manager/README.md)

**Description :** Serveur MCP unifié pour la gestion des conversations et configurations Roo. Fournit grounding conversationnel, coordination RooSync, monitoring système.

**Outils principaux (37) :**
- `conversation_browser` - Navigation dans les conversations
- `codebase_search` - Recherche sémantique dans le code
- `roosync_send`, `roosync_read`, `roosync_manage` - Communication RooSync
- `roosync_config`, `roosync_compare_config` - Gestion configuration
- `analyze_roosync_problems` - Diagnostic RooSync
- `conversation_browser`, `view_task_details` - Gestion des tâches

**Installation :**
```bash
cd mcps/internal/servers/roo-state-manager
npm install
npm run build
```

**Configuration :**
```json
{
  "mcpServers": {
    "roo-state-manager": {
      "command": "node",
      "args": ["D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/index.js"],
      "cwd": "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/",
      "env": {
        "WORKSPACE_PATH": "${workspaceFolder}",
        "QDRANT_URL": "https://qdrant.myia.io",
        "EMBEDDING_API_BASE_URL": "http://embeddings.myia.io:11436/v1"
      }
    }
  }
}
```

**Référence :** [CLAUDE.md - MCP roo-state-manager](../../CLAUDE.md#mcp-roo-state-manager)

---

### sk-agent

**Statut :** ✅ Actif (myia-ai-01, myia-po-2023)
**Chemin :** `mcps/internal/servers/sk-agent/`
**Documentation :** Voir fichier `run-sk-agent.ps1`

**Description :** Agent LLM multi-modèle pour conversations structurées (code-review, critic, optimist, etc.).

**Outils principaux (7) :**
- `run_conversation` - Lancer une conversation multi-agents
- `call_agent` - Appeler un agent spécifique
- `analyze_document` - Analyser un document
- `analyze_image`, `analyze_video` - Analyser des médias

**Installation :** Voir [`.claude/MCP_SETUP.md`](../../.claude/MCP_SETUP.md)

---

### jinavigator-server

**Statut :** ✅ Actif
**Chemin :** `mcps/internal/servers/jinavigator-server/`
**Documentation :** [README](../../mcps/internal/servers/jinavigator-server/README.md)

**Description :** Serveur MCP pour convertir des pages web en Markdown via API Jina.

**Outils (4) :**
- `convert_web_to_markdown` - Convertir une URL en Markdown
- `access_jina_resource` - Accéder aux ressources Jina
- `multi_convert` - Conversion multiple
- `health_check` - Vérifier la santé du serveur

---

### jupyter-papermill-mcp-server

**Statut :** ✅ Actif
**Chemin :** `mcps/internal/servers/jupyter-papermill-mcp-server/`
**Documentation :** Voir README dans le répertoire

**Description :** Serveur MCP Python pour opérations Jupyter Notebook avec environnement Conda isolé.

**Outils (21) :**
- `read_notebook`, `write_notebook` - Lire/écrire des notebooks
- `execute_notebook`, `execute_notebook_sync` - Exécuter des notebooks
- `start_kernel`, `stop_kernel` - Gérer les kernels
- `manage_async_job` - Gérer les tâches asynchrones

---

### github-projects-mcp

**Statut :** ⚠️ Déprécié - Utiliser `gh` CLI natif
**Chemin :** `mcps/internal/servers/github-projects-mcp/`

**Note :** Ce MCP a été remplacé par le CLI `gh` natif (voir [`.claude/rules/github-cli.md`](../../.claude/rules/github-cli.md)).

---

### quickfiles-server

**Statut :** ❌ Retiré (CONS-1)
**Remplacé par :** Outils natifs Read/Write/Glob

---

## Serveurs Externes

Serveurs tiers ou community maintenus.

### win-cli (fork local)

**Statut :** ✅ Actif - Fork local 0.2.0 (Roo uniquement)
**Chemin :** `mcps/external/win-cli/server/`
**Documentation :** [README complet](../../mcps/external/win-cli/server/README.md)

**Description :** MCP pour exécuter des commandes shell sur Windows (PowerShell, CMD, Git Bash). **OBLIGATOIRE pour Roo scheduler** depuis cleanup #658.

**⚠️ IMPORTANT :**
- Pour **Roo** : Configuré dans `%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`
- Pour **Claude Code** : Utiliser l'outil `Bash` natif (win-cli N'EST PAS configuré pour Claude)

**Outils (9) :**
- `execute_command` - Exécuter une commande shell
- `get_command_history` - Historique des commandes
- `ssh_execute`, `ssh_disconnect` - Exécution SSH
- `create_ssh_connection`, `read_ssh_connections` - Gestion SSH

**Configuration correcte (fork local 0.2.0) :**
```json
"win-cli": {
  "command": "node",
  "args": ["D:/Dev/roo-extensions/mcps/external/win-cli/server/dist/index.js"],
  "transportType": "stdio",
  "disabled": false
}
```

**NE PAS utiliser :** `npx @anthropic/win-cli` (version npm 0.2.1 cassée)

**Référence :** [`.claude/rules/tool-availability.md`](../../.claude/rules/tool-availability.md#win-cli)

---

### playwright

**Statut :** ✅ Actif
**Description :** MCP pour l'automatisation web avec Playwright (navigation, screenshots, interactions).

**Outils (22) :**
- `browser_navigate` - Naviguer vers une URL
- `browser_snapshot` - Capture d'écran accessible
- `browser_click` - Cliquer sur un élément
- `browser_type` - Taper du texte
- `browser_run_code` - Exécuter du code JavaScript

**Installation :**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp", "--browser", "firefox"]
    }
  }
}
```

---

### markitdown

**Statut :** ✅ Actif
**Description :** MCP pour convertir des fichiers en Markdown.

**Outils (1) :**
- `convert_to_markdown` - Convertir un fichier en Markdown

**Installation :**
```json
{
  "mcpServers": {
    "markitdown": {
      "command": "python",
      "args": ["-m", "markitdown_mcp"]
    }
  }
}
```

---

### searxng

**Statut :** ✅ Actif
**Description :** MCP pour la recherche web via SearXNG (moteur de recherche agrégé).

**Outils (2) :**
- `web_url_read` - Lire une page web
- `searxng_web_search` - Recherche web

**Configuration :**
```json
{
  "mcpServers": {
    "searxng": {
      "command": "npx",
      "args": ["-y", "mcp-searxng"],
      "env": {
        "SEARXNG_URL": "https://search.myia.io/"
      }
    }
  }
}
```

---

### jupyter-mcp (legacy)

**Statut :** ⚠️ DISABLED (152 tools = scheduler crash)
**Remplacé par :** jupyter-papermill-mcp-server

**Note :** Ce MCP a trop d'outils (152) et cause un crash du scheduler Roo. Utiliser jupyter-papermill-mcp-server à la place.

---

### desktop-commander

**Statut :** ❌ Retiré (CONS-1)
**Remplacé par :** win-cli (fork local)

**Note :** Retiré lors du cleanup #468 revert. Utiliser win-cli pour les commandes shell.

---

## Serveurs Externers Officiels (npm)

Serveurs officiels disponibles via npm mais non activés dans ce projet.

### filesystem
**Package :** `@modelcontextprotocol/server-filesystem`
**Description :** Accès au système de fichiers local.

### git
**Package :** `@modelcontextprotocol/server-git`
**Description :** Opérations Git (status, log, diff).

### github
**Package :** `@modelcontextprotocol/server-github`
**Description :** API GitHub (issues, PRs, commits).

**Note :** Préférer le CLI `gh` natif (voir [`.claude/rules/github-cli.md`](../../.claude/rules/github-cli.md)).

### fetch
**Package :** `@modelcontextprotocol/server-fetch`
**Description :** HTTP client pour faire des requêtes web.

### brave-search
**Package :** `@modelcontextprotocol/server-brave-search`
**Description :** Recherche web via Brave Search API.

---

## Configuration des MCPs

### Fichiers de Configuration

**Pour Roo :**
- `~/.claude.json` (config globale utilisateur)
- `.roo/mcp.json` (overrides projet)

**Pour Claude Code :**
- VS Code settings UI ou `~/.claude.json`

**Pour le scheduler Roo :**
- `%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

### Variables d'Environnement Requises

**Pour roo-state-manager (Qdrant + Embeddings) :**
```bash
QDRANT_URL=https://qdrant.myia.io
QDRANT_API_KEY=your-api-key
QDRANT_COLLECTION_NAME=roo_tasks_semantic_index
OPENAI_API_KEY=your-api-key
EMBEDDING_MODEL=Alibaba-NLP/gte-Qwen2-1.5B-instruct
EMBEDDING_API_BASE_URL=http://embeddings.myia.io:11436/v1
```

**Pour searxng :**
```bash
SEARXNG_URL=https://search.myia.io/
```

---

## Validation des MCPs

### Tester un MCP

Pour vérifier qu'un MCP fonctionne correctement :

```bash
# Vérifier la disponibilité des outils via roosync_mcp_management
roosync_mcp_management(action: "manage", subAction: "read")

# Ou appeler un outil spécifique
execute_command(shell="powershell", command="echo OK")
conversation_browser(action: "current")
```

### Protocole STOP & REPAIR

**CRITIQUE :** Si un MCP critique est absent, arrêter tout travail et réparer avant de continuer.

Voir [`.claude/rules/tool-availability.md`](../../.claude/rules/tool-availability.md) pour le protocole complet.

**MCPs Critiques :**
| MCP | Outils attendus | Vérification |
|-----|-----------------|-------------|
| roo-state-manager | 37 | `conversation_browser(action: "current")` |
| win-cli (Roo) | 9 | `execute_command(shell="powershell", command="echo OK")` |

---

## Dépannage

### MCP ne démarre pas

1. **Vérifier le chemin** vers le serveur
2. **Vérifier `node` / `python`** est dans le PATH
3. **Vérifier les dépendances** (`npm install` ou `pip install`)
4. **Vérifier la configuration** JSON (syntaxe, chemins)

### Outils non disponibles dans system-reminders

1. **Redémarrer VS Code** (souvent nécessaire après modification de config)
2. **Vérifier `disabled: false`** dans la config
3. **Vérifier `alwaysAllow`** contient les outils nécessaires

### Erreur "Server not available"

1. **Vérifier que le serveur tourne** (process en cours)
2. **Vérifier le timeout** (augmenter si nécessaire)
3. **Vérifier les logs** dans Output → "MCP Servers"

---

## Références

- [`.claude/MCP_SETUP.md`](../../.claude/MCP_SETUP.md) - Configuration détaillée
- [`.claude/rules/tool-availability.md`](../../.claude/rules/tool-availability.md) - Protocole STOP & REPAIR
- [`.claude/rules/github-cli.md`](../../.claude/rules/github-cli.md) - Migration vers gh CLI
- [`CLAUDE.md`](../../CLAUDE.md) - Guide principal pour agents

---

**Contributors :** Coordinateur RooSync (myia-ai-01)
**Mainteneurs :** Équipe Roo Extensions

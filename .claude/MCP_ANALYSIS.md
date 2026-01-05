# MCP Analysis - Roo vs Claude Code Coordination

**Date:** 2026-01-05
**Version:** 3.0 (Consolidée)
**Auteur:** Claude Code (myia-ai-01)

---

## 🎯 Questions Clés

### Q1: Claude Code a-t-il accès à ses propres conversations ?

**❌ NON**

**Explication:**
- Claude Code n'a PAS de mécanisme natif pour accéder à l'historique de ses propres conversations
- Chaque conversation est indépendante
- Pas d'équivalent à `view_conversation_tree` pour Claude Code

**Conséquence:**
- Les agents Claude Code ne peuvent pas se "souvenir" de ce qu'ils ont fait dans les conversations précédentes
- Ils doivent compter sur des artifices externes (GitHub Issues, fichiers de logs, etc.)

**Solution:** Utiliser GitHub Issues comme "mémoire externe" obligatoire (voir section Traçabilité)

### Q2: Claude Code peut-il utiliser les MCPs de Roo ?

**✅ OUI** - Sous conditions

**Explication:**
Les MCPs sont **par nature portables** car ils suivent le standard Model Context Protocol.

**Configuration actuelle (`roo-config/settings/servers.json`):**

Les MCPs critiques sont **déjà configurés** pour Roo :
- `roo-state-manager` - État + historique Roo + RooSync
- `github-projects-mcp` - GitHub Projects API

**Conclusion:** Si Claude Code a accès à cette configuration, il peut utiliser TOUS les MCPs configurés, y compris `roo-state-manager` et `github-projects-mcp`.

---

## 📊 Cartographie des MCPs Partageables

### MCPs Utilisables par Claude Code

**MCPs Internes (6 serveurs):**

| MCP | Description | Localisation | Outils principaux | Portabilité |
|-----|-------------|--------------|-------------------|-------------|
| **roo-state-manager** | État + historique Roo + RooSync | `mcps/internal/servers/roo-state-manager/` | `search_tasks_by_content`, `view_conversation_tree`, `get_conversation_synthesis`, `roosync_*` (50+ outils) | ✅ Interne - Configuré pour Roo |
| **github-projects-mcp** | GitHub Projects API | `mcps/internal/servers/github-projects-mcp/` | `list_projects`, `get_project_items`, `convert_draft_to_issue`, `update_project_item_field` | ✅ Interne - Configuré pour Roo |
| **jinavigator-server** | Web → Markdown (Jina API) | `mcps/internal/servers/jinavigator-server/` | Web to Markdown conversion | ✅ Interne - À configurer |
| **jupyter-papermill-mcp** | Jupyter Papermill | `mcps/internal/servers/jupyter-papermill-mcp-server/` | Notebook execution with parameters | ✅ Interne - À configurer |
| **quickfiles-server** | Multi-file operations | `mcps/internal/servers/quickfiles-server/` | Batch file operations | ✅ Interne - À configurer |
| **jupyter-mcp-server** | (legacy - use papermill) | `mcps/internal/servers/jupyter-mcp-server/` | *(should be archived)* | ⚠️ Obsolète |

**MCPs Externes (12 serveurs):**

| MCP | Description | Localisation | Type | Portabilité |
|-----|-------------|--------------|------|-------------|
| **filesystem** | File system operations | `mcps/external/filesystem/` | Local | ✅ Standard MCP |
| **git** | Git operations | `mcps/external/git/` | Local | ✅ Standard MCP |
| **github** | GitHub API | `mcps/external/github/` | Local | ✅ Standard MCP |
| **searxng** | Web search | `mcps/external/searxng/` | Local | ✅ Standard MCP |
| **docker** | Docker containers | `mcps/external/docker/` | Local | ✅ Standard MCP |
| **jupyter** | Jupyter notebooks | `mcps/external/jupyter/` | Local | ✅ Standard MCP |
| **markitdown** | Document conversion | `mcps/external/markitdown/` | Local | ✅ Standard MCP |
| **win-cli/server** | Windows CLI (git submodule) | `mcps/external/win-cli/server/` | Submodule | ✅ Standard MCP |
| **mcp-server-ftp** | FTP server | `mcps/external/mcp-server-ftp/` | Submodule | ✅ Standard MCP |
| **markitdown/source** | Microsoft Markitdown | `mcps/external/markitdown/source/` | Submodule | ✅ Standard MCP |
| **playwright/source** | Browser automation | `mcps/external/playwright/source/` | Submodule | ✅ Standard MCP |
| **Office-PowerPoint** | PowerPoint (Python) | `mcps/external/Office-PowerPoint-MCP-Server/` | Submodule | ✅ Python MCP |

**✅ BONNE NOUVELLE:** Les MCPs critiques sont **internes** et configurés pour Roo !

---

## 🔍 Mapping Précis : Roo ↔ Claude Code

### Grounding Sémantique

| Capability | Roo (natif) | Claude Code (via MCP Roo) | Claude Code (natif) |
|------------|-------------|---------------------------|---------------------|
| Recherche sémantique | ✅ `search_tasks_by_content` (Qdrant) | ✅ Via MCP roo-state-manager | ❌ Non disponible |
| Recherche textuelle | ✅ Via fallback | ✅ Via MCP | ✅ Grep/Glob |
| Lecture documentation | ✅ Via Read | ✅ Via Read | ✅ Via Read |
| Indexation | ✅ `index_task_semantic` | ❌ Via MCP | ❌ Non disponible |

**Conclusion:** Pour le grounding sémantique, les agents Claude Code **DOIVENT** utiliser `search_tasks_by_content` via MCP Roo.

### Grounding Conversationnel

| Capability | Roo (natif) | Claude Code (via MCP Roo) | Claude Code (natif) |
|------------|-------------|---------------------------|---------------------|
| Accès historique Roo | ✅ `view_conversation_tree` | ✅ Via MCP roo-state-manager | ❌ Non disponible |
| Synthèse conversation | ✅ `get_conversation_synthesis` | ✅ Via MCP | ❌ Non disponible |
| Liste conversations | ✅ `list_conversations` | ✅ Via MCP | ❌ Non disponible |
| Accès historique Claude Code | ❌ Non applicable | ❌ Non disponible | ❌ Non disponible |

**Conclusion:**
- Claude Code peut accéder à l'historique **Roo** via MCP
- Claude Code **N'A PAS** accès à son propre historique
- **Solution:** GitHub Issues comme mémoire externe

### Grounding Technique

| Capability | Roo (natif) | Claude Code (via MCP Roo) | Claude Code (natif) |
|------------|-------------|---------------------------|---------------------|
| Lecture code source | ✅ Via Read | ✅ Via Read | ✅ Via Read |
| Analyse dépôt Git | ✅ Via Bash | ✅ Via Bash/Grep | ✅ Via Bash/Grep |
| Tests comportement | ✅ Via scripts | ✅ Via Bash | ✅ Via Bash |
| Validation faisabilité | ✅ Via outils | ✅ Via analyse | ✅ Via analyse |

**Conclusion:** Parité, les deux peuvent faire du grounding technique.

---

## 🎯 Intégration GitHub Project (CRITIQUE)

### Situation Actuelle

**MCP disponible:** `github-projects-mcp` dans `mcps/internal/servers/github-projects-mcp/`

**Fonctionnalités:**
- `list_projects` - Lister les projets GitHub
- `get_project` - Obtenir détails projet
- `get_project_items` - Lister items (drafts/issues)
- `convert_draft_to_issue` - Convertir draft en issue
- `update_project_item_field` - Mettre à jour champ
- `add_issue_comment` - Ajouter commentaire issue

**Configuration:** Déjà dans `roo-config/settings/servers.json`

**INTÉGRATION NÉCESSAIRE:** Les agents Claude Code doivent avoir accès à ce MCP pour:
1. Créer des issues GitHub depuis les drafts
2. Suivi des tâches multi-agent
3. Traçabilité des décisions
4. **Mémoire externe** (car pas d'accès à leur propre historique)

---

## 🔄 Architecture de Coordination Proposée

### Double Couche Multi-Agent

```
┌─────────────────────────────────────────────────────────────────┐
│                    BASE DE CONNAISSANCE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │  Historique Roo  │         │ Mémoire Claude   │             │
│  │  (Qdrant + FS)   │         │ Code (GitHub)    │             │
│  │                  │         │                  │             │
│  │  • Conversations │         │  • Issues        │             │
│  │  • Tâches        │         │  • Commentaires  │             │
│  │  • Décisions     │         │  • Statuts       │             │
│  └──────────────────┘         └──────────────────┘             │
│           ↓                            ↓                        │
│  ┌──────────────────────────────────────────────────┐          │
│  │         MCPs INTERNES PARTAGÉS                   │          │
│  │  • roo-state-manager (50+ outils)               │          │
│  │  • github-projects-mcp (Projects API)            │          │
│  └──────────────────────────────────────────────────┘          │
│           ↓                            ↓                        │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │  Agent Roo       │         │ Agent Claude      │             │
│  │  (Accès direct)  │    ↔    │ Code (Via MCP)    │             │
│  └──────────────────┘         └──────────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

### Flux de Grounding

**Pour un Agent Claude Code:**

1. **Recherche dans l'historique Roo** (via MCP roo-state-manager)
   - `search_tasks_by_content` pour recherche sémantique
   - `view_conversation_tree` pour contexte Roo
   - `get_conversation_synthesis` pour synthèse

2. **Recherche dans sa propre trace** (via MCP github-projects-mcp)
   - Lister ses issues créées
   - Lire ses commentaires
   - Retrouver son historique de décisions

3. **Compléter avec l'analyse technique** (natif + MCPs)
   - Read pour code source
   - Git MCP pour état dépôt
   - Bash pour exécution

---

## 🚨 Problème Identifié: Historique Claude Code

### Le Problème

Les agents Claude Code **n'ont pas de mémoire** de leurs conversations précédentes.

**Conséquences:**
- ❌ Impossible de savoir ce qu'ils ont fait dans les conversations passées
- ❌ Impossible de retrouver les décisions prises
- ❌ Impossible d'apprendre de leurs expériences

### Solution Proposée: Traçabilité GitHub Obligatoire

**Principe:** FORCER les agents Claude Code à documenter TOUT dans GitHub Issues.

**Workflow:**

1. **Créer une issue pour chaque tâche**
   ```typescript
   convert_draft_to_issue({
     title: "[CLAUDE-myia-ai-01] Nettoyer documentation RooSync",
     labels: ["claude-code", "phase-2", "documentation"]
   })
   ```

2. **Documenter toutes les décisions**
   ```typescript
   add_issue_comment({
     issue_id: 123,
     body: "## Décision\nJ'ai fusionné X et Y parce que..."
   })
   ```

3. **Mettre à jour le statut**
   ```typescript
   update_project_item_field({
     item_id: 123,
     field_name: "status",
     value: "Done"
   })
   ```

4. **Pour retrouver l'historique:**
   ```typescript
   // Lister les issues de l'agent
   get_project_items({
     filters: { assignee: "claude-code-myia-ai-01" }
   })
   ```

**Avantages:**
- ✅ Traçabilité complète
- ✅ Historique persistant
- ✅ Partageable entre agents
- ✅ Accessible via MCP github-projects-mcp

---

## 🎯 Implications Pratiques pour le Grounding SDDD

### Ce que Claude Code PEUT réellement faire:

#### 1. Grounding Sémantique ✅

**Via MCP roo-state-manager:**

```typescript
// Recherche sémantique DANS LES CONVERSATIONS ROO
search_tasks_by_content({
  search_query: "dualité architecturale v2.1 v2.3",
  workspace: "d:/roo-extensions",
  max_results: 10
})
```

**Ce que cela donne:**
- ✅ Accès à l'historique complet des conversations **Roo**
- ✅ Recherche sémantique dans les tâches Roo indexées
- ❌ PAS d'accès aux conversations **Claude Code** précédentes

**Complément natif:**
```typescript
// Recherche textuelle dans les fichiers
Grep dans docs/, src/, etc.
Glob pour trouver des fichiers
Read pour lire le contenu
```

#### 2. Grounding Conversationnel ✅ (Partiel)

**Via MCP roo-state-manager:**

```typescript
// Accès à l'historique ROO
view_conversation_tree({ conversation_id: "ROO_CONVERSATION_ID" })
get_conversation_synthesis({ conversation_id: "ROO_CONVERSATION_ID" })
list_conversations({ workspace: "d:/roo-extensions" })
```

**Ce que cela donne:**
- ✅ Accès à l'historique des conversations **Roo**
- ✅ Synthèse LLM des conversations Roo
- ❌ PAS d'accès aux conversations **Claude Code** précédentes

**Complément via MCP github-projects-mcp:**
```typescript
// Lire les rapports écrits par les agents Claude Code
get_project_items({
  filters: { assignee: "claude-code-MACHINE_ID" }
})

// Lire les commentaires (décisions, raisonnements)
add_issue_comment({ ... })
```

#### 3. Grounding Technique ✅

**Via outils natifs + MCP:**

```typescript
// Natif Claude Code
Read pour lire le code source
Bash pour exécuter des commandes

// Via MCP git
git_log, git_status, git_diff

// Via MCP filesystem
filesystem_read, filesystem_write
```

**Ce que cela donne:**
- ✅ Lecture du code source
- ✅ Analyse Git
- ✅ Exécution de commandes
- ✅ Validation faisabilité

---

## 📋 Recommandations Finales

### Pour la Coordination Multi-Agent

1. **Utiliser les MCPs Roo comme base de connaissance**
   - ✅ `search_tasks_by_content` pour recherche sémantique
   - ✅ `view_conversation_tree` pour historique Roo
   - ✅ `get_conversation_synthesis` pour synthèse

2. **Créer une "mémoire externe" pour Claude Code**
   - ✅ GitHub Issues comme mémoire persistante
   - ✅ Chaque tâche = une issue
   - ✅ Chaque décision = un commentaire

3. **Protocole SDDD adapté**
   - ✅ Grounding sémantique: MCP roo-state-manager
   - ✅ Grounding conversationnel: MCP roo-state-manager (Roo) + GitHub (Claude Code)
   - ✅ Grounding technique: Natif Claude Code + MCPs

### Pour le Déploiement

1. **Vérifier la configuration MCP**
   - `roo-state-manager` est-il activé pour Claude Code ?
   - `github-projects-mcp` est-il accessible ?
   - Les variables d'environnement sont-elles correctes ?

2. **Tester les outils critiques**
   - `search_tasks_by_content` fonctionne-t-il ?
   - `view_conversation_tree` fonctionne-t-il ?
   - `convert_draft_to_issue` fonctionne-t-il ?

3. **Documenter le workflow**
   - Comment créer une issue ?
   - Comment rechercher dans l'historique Roo ?
   - Comment retrouver ses propres décisions ?

---

## 🎯 Résumé Exécutif

### Oui, Claude Code peut utiliser les MCPs Roo

**Condition:** Avoir accès à la configuration `roo-config/settings/servers.json`

**Outils disponibles:**
- ✅ Tous les outils de `roo-state-manager` (50+ outils)
- ✅ Tous les outils de `github-projects-mcp` (Projects API)
- ✅ Tous les autres MCPs configurés

### Non, Claude Code n'a pas accès à son propre historique

**Solution:**
- Utiliser GitHub Issues comme mémoire externe
- Documenter TOUT dans les issues
- Créer un système de traçabilité obligatoire

### Grounding SDDD adapté = MCPs Roo + GitHub + Natif

**Combiner:**
1. MCP roo-state-manager (historique Roo)
2. MCP github-projects-mcp (mémoire Claude Code)
3. Outils natifs (lecture, analyse, exécution)

---

**Version:** 3.0 (Consolidée)
**Date:** 2026-01-05
**Auteur:** Claude Code (myia-ai-01)

**Built with Claude Code 🤖**

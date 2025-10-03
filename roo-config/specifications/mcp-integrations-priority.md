# 🔌 Intégrations MCP Prioritaires - roo-state-manager & github-projects

**Version :** 2.0.0  
**Date :** 2 Octobre 2025  
**Architecture :** 2-Niveaux (Simple/Complex)  
**Statut :** Spécification consolidée - win-cli débridé intégré (FB-06)

---

## 🎯 Objectif des Intégrations MCP

Les MCPs (Model Context Protocols) étendent les capacités Roo avec :
1. **roo-state-manager** : Traçabilité et contexte conversationnel
2. **quickfiles** : Manipulation fichiers performante (batch, recherche)
3. **win-cli** : Commandes système Windows (PRIVILÉGIÉ pour modes non-orchestrateur)
4. **github-projects** : Synchronisation roadmap et collaboration équipe (future)
5. **Autres MCPs** : Capacités spécialisées (web, jupyter, etc.)

**Priorités d'intégration** :
- 🥇 **Tier 1** : MCPs Critiques (roo-state-manager, quickfiles, github-projects) - CONSERVER & PRIORISER
- 🥈 **Tier 2** : MCPs Privilégiés (win-cli, markitdown) - CONSERVER & OPTIMISER  
- 🥉 **Tier 3** : MCPs à Utiliser avec Précaution (github MCP) - Limites connues
- 🎯 **Tier 4** : Outils Spécialisés (jinavigator, searxng, playwright, jupyter) - Cas spécifiques

---
## 📊 Hiérarchisation Détaillée des MCPs

Cette section présente la hiérarchisation consolidée des MCPs selon leur criticité et leur rôle dans l'architecture SDDD.

### Tier 1 : MCPs Critiques 🎯

Ces MCPs sont **essentiels** à l'architecture SDDD et doivent être privilégiés dans tous les workflows.

#### roo-state-manager
- **Rôle** : Niveau 3 SDDD (Grounding Conversationnel)
- **Critique pour** : Accès contexte historique tâches, décisions architecturales
- **Statut** : ✅ Opérationnel et critique
- **Outil principal** : `search_tasks_semantic`
- **Référence** : [`sddd-protocol-4-niveaux.md#niveau-3`](sddd-protocol-4-niveaux.md#niveau-3)

#### quickfiles
- **Rôle** : Niveau 1 SDDD (File Grounding) - Fallback prioritaire
- **Critique pour** : Opérations batch sur fichiers, performance supérieure
- **Statut** : ✅ Opérationnel (binaire Rust compilé)
- **Avantages** : Performance batch, robustesse, pas de dépendances runtime Node.js
- **Référence** : [`sddd-protocol-4-niveaux.md#niveau-1`](sddd-protocol-4-niveaux.md#niveau-1)

#### github-projects
- **Rôle** : Niveau 4 SDDD (Project Grounding) - **FUTUR**
- **Critique pour** : Traçabilité tâches, métriques productivité, collaboration
- **Statut** : ⚠️ Non-opérationnel (problèmes configuration)
- **Roadmap** : Q4 2025 - Q2 2026 (voir section dédiée ci-dessous)
- **Référence** : [`sddd-protocol-4-niveaux.md#niveau-4`](sddd-protocol-4-niveaux.md#niveau-4)

---

### Tier 2 : MCPs Privilégiés ⚡

Ces MCPs apportent une **valeur ajoutée significative** et sont recommandés pour des cas d'usage spécifiques.

#### win-cli (Décision FB-06)
- **Rôle** : Exécution commandes système sécurisée pour modes non-orchestrateur
- **Privilégié pour** : Sécurité (sandbox), traçabilité (logs structurés), performance
- **Statut** : ✅ Opérationnel (fork jsboige débridé compilé)
- **Configuration** : Débridage validé FB-06 (restrictWorkingDirectory: false, tous opérateurs autorisés)
- **Économie** : ~18k tokens vs execute_command natif
- **Modes cibles** : code, debug, architect, ask (tous sauf orchestrator)
- **Référence** : Section FB-06 ci-dessous

> ⚠️ **NOTE IMPORTANTE** : L'énoncé initial Mission 3.2 mentionnait le remplacement 
> de win-cli par commandes natives. Cette recommandation était basée sur un audit 
> antérieur à la décision **FB-06 (02 Oct 2025)** qui a VALIDÉ win-cli débridé comme 
> solution privilégiée. La présente intégration **PRÉSERVE** la décision FB-06 tout en 
> documentant l'installation réussie (compilation TypeScript effectuée).

#### markitdown
- **Rôle** : Conversion documents (PDF, DOCX, etc.) vers Markdown
- **Privilégié pour** : Traitement documents dans workflows documentation
- **Statut** : ✅ Opérationnel (uv 0.8.22 installé, Python 3.13.7)
- **Installation** : Documentée dans [`mcps/INSTALLATION.md#markitdown`](../../mcps/INSTALLATION.md#markitdown)

---

### Tier 3 : MCPs à Utiliser avec Précaution ⚠️

Ces MCPs ont des limitations ou redondances avec d'autres outils.

#### github (MCP)
- **Rôle** : Opérations API GitHub simples
- **À utiliser pour** : Requêtes API basiques uniquement
- **À éviter pour** : Workflows complexes (préférer `gh` CLI natif)
- **Raison** : Redondance avec `gh` CLI plus flexible et puissant
- **Recommandation** : Conserver pour opérations atomiques simples

---

## 🗄️ MCP Tier 1 : roo-state-manager

### Vue d'Ensemble

**Serveur MCP** : `roo-state-manager`  
**Fonction principale** : Gestion état conversations Roo et traçabilité historique  
**Utilisation** : SYSTÉMATIQUE pour tâches complexes et orchestration

### Outils Principaux

#### 1. view_conversation_tree

**Usage** : Visualiser hiérarchie conversations et sous-tâches

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>
{
  "task_id": "uuid-tache-actuelle",
  "view_mode": "chain",
  "detail_level": "summary"
}
</arguments>
</use_mcp_tool>
```

**Paramètres** :
- `task_id` : ID tâche racine (optionnel si workspace fourni)
- `workspace` : Chemin workspace (alternatif à task_id)
- `view_mode` : 
  - `"single"` : Tâche seule
  - `"chain"` : Tâche + parents + enfants
  - `"cluster"` : Grappe complète de tâches liées
- `detail_level` :
  - `"skeleton"` : Métadonnées uniquement
  - `"summary"` : Résumé condensé
  - `"full"` : Contenu complet

**Cas d'usage** :
- ✅ Reprise tâche après interruption
- ✅ Compréhension décisions architecturales passées
- ✅ Navigation structure projet complexe
- ✅ Identification patterns récurrents

**Exemple sortie** :
```json
{
  "taskId": "abc123",
  "title": "Mission : Refactoring Architecture",
  "hierarchy": "1.0",
  "children": [
    {
      "taskId": "def456",
      "title": "Phase Analyse",
      "hierarchy": "1.1",
      "parentId": "abc123",
      "summary": "Analyse architecture existante complétée..."
    }
  ]
}
```

#### 2. search_tasks_semantic

**Usage** : Recherche sémantique dans conversations historiques

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>search_tasks_semantic</tool_name>
<arguments>
{
  "search_query": "architecture modes factorisation templates",
  "workspace": "c:/dev/roo-extensions",
  "max_results": 10
}
</arguments>
</use_mcp_tool>
```

**Paramètres** :
- `search_query` : Requête langage naturel (similaire codebase_search)
- `conversation_id` : Limiter recherche à conversation spécifique
- `workspace` : Filtrer par workspace
- `max_results` : Nombre maximum résultats (défaut: 20)

**Cas d'usage** :
- ✅ Retrouver décisions techniques passées
- ✅ Identifier solutions à problèmes récurrents
- ✅ Éviter duplication travail
- ✅ Apprentissage patterns projet

**Intégration SDDD** :
- Phase 3 : Grounding Conversationnel obligatoire
- Complète codebase_search pour contexte complet

#### 3. get_task_tree

**Usage** : Récupérer arbre hiérarchique complet

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>get_task_tree</tool_name>
<arguments>
{
  "conversation_id": "uuid-conversation",
  "max_depth": 3,
  "include_siblings": true
}
</arguments>
</use_mcp_tool>
```

**Paramètres** :
- `conversation_id` : ID conversation racine
- `max_depth` : Profondeur maximale (défaut: 10)
- `include_siblings` : Inclure tâches sœurs (défaut: false)

**Cas d'usage** :
- ✅ Génération diagrammes hiérarchie
- ✅ Analyse dépendances entre tâches
- ✅ Reporting avancement projet

#### 4. list_conversations

**Usage** : Lister conversations avec filtres

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>list_conversations</tool_name>
<arguments>
{
  "workspace": "c:/dev/roo-extensions",
  "sortBy": "lastActivity",
  "limit": 20
}
</arguments>
</use_mcp_tool>
```

**Paramètres** :
- `workspace` : Filtrer par workspace
- `sortBy` : `"lastActivity"`, `"messageCount"`, `"totalSize"`
- `sortOrder` : `"asc"` ou `"desc"`
- `limit` : Nombre maximum résultats

**Cas d'usage** :
- ✅ Vue d'ensemble projets récents
- ✅ Identification tâches abandonnées
- ✅ Métriques productivité

### Patterns d'Utilisation Recommandés

#### Pattern 1 : Grounding Début Tâche

```markdown
**Séquence obligatoire** :
1. codebase_search (grounding sémantique code)
2. roo-state-manager search_tasks_semantic (grounding conversationnel)
3. read_file ciblés basés sur résultats

**Bénéfices** :
- Contexte complet : code + décisions historiques
- Évite duplication efforts
- Cohérence architecturale maintenue
```

#### Pattern 2 : Orchestration Complexe

```markdown
**Avant décomposition en sous-tâches** :
1. view_conversation_tree (comprendre structure existante)
2. Concevoir hiérarchie numérotée cohérente
3. Créer new_task() avec contexte hérité

**Bénéfices** :
- Hiérarchie logique et tracée
- Pas de duplication sous-tâches
- Navigation facilitée
```

#### Pattern 3 : Checkpoint Régulier

```markdown
**Tous les 50k tokens** :
1. view_conversation_tree (vérifier position hiérarchie)
2. Résumé actions effectuées
3. Mise à jour todo list si nécessaire

**Bénéfices** :
- Traçabilité continue
- Reprise facilitée après interruption
- Métriques avancement précises
```

---

## 📁 MCP Tier 1 : quickfiles

### Vue d'Ensemble

**Serveur MCP** : `quickfiles`  
**Fonction principale** : Manipulation fichiers performante et batch  
**Utilisation** : PRIVILÉGIER sur outils natifs pour efficacité

### Outils Principaux

#### 1. read_multiple_files

**Usage** : Lecture batch ultra-performante

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": [
    "src/module-a.ts",
    "src/module-b.ts",
    "src/module-c.ts"
  ],
  "show_line_numbers": true,
  "max_lines_per_file": 500
}
</arguments>
</use_mcp_tool>
```

**Avantages vs read_file natif** :
- ⚡ 1 requête pour N fichiers (économie tokens)
- ⚡ Lecture partielle avec excerpts (efficacité)
- ⚡ Line numbers automatiques (référencement)
- ⚡ Limites configurables (contrôle ressources)

**Cas d'usage** :
- ✅ Lecture modules liés (imports/exports)
- ✅ Analyse patterns multi-fichiers
- ✅ Préparation refactoring batch

#### 2. search_in_files

**Usage** : Recherche regex multi-fichiers avec contexte

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["src", "tests"],
  "pattern": "function.*authenticate",
  "use_regex": true,
  "context_lines": 3,
  "recursive": true
}
</arguments>
</use_mcp_tool>
```

**Avantages vs search_files natif** :
- ⚡ Contexte lignes encadrant matches
- ⚡ Filtrage par pattern fichiers
- ⚡ Statistiques matches par fichier
- ⚡ Limites résultats configurables

**Cas d'usage** :
- ✅ Identification usages fonction/classe
- ✅ Recherche patterns spécifiques (regex)
- ✅ Audit sécurité (hardcoded credentials)

#### 3. edit_multiple_files

**Usage** : Édition batch avec diffs multiples

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>edit_multiple_files</tool_name>
<arguments>
{
  "files": [
    {
      "path": "src/module-a.ts",
      "diffs": [
        {
          "search": "old implementation",
          "replace": "new implementation",
          "start_line": 45
        }
      ]
    },
    {
      "path": "src/module-b.ts",
      "diffs": [
        {
          "search": "deprecated method",
          "replace": "new method",
          "start_line": 78
        }
      ]
    }
  ]
}
</arguments>
</use_mcp_tool>
```

**Avantages vs apply_diff natif** :
- ⚡ 1 requête pour N fichiers (économie)
- ⚡ Transactions atomiques (tout ou rien)
- ⚡ Validation automatique diffs

**Cas d'usage** :
- ✅ Refactoring coordonné multi-fichiers
- ✅ Mise à jour imports après déplacement
- ✅ Application patterns standards

#### 4. extract_markdown_structure

**Usage** : Extraction plan hiérarchique markdown

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>extract_markdown_structure</tool_name>
<arguments>
{
  "paths": [
    "docs/architecture.md",
    "docs/api.md"
  ],
  "max_depth": 3,
  "include_context": true
}
</arguments>
</use_mcp_tool>
```

**Cas d'usage** :
- ✅ Navigation documentation rapide
- ✅ Génération tables des matières
- ✅ Analyse structure documents

### Patterns d'Utilisation Recommandés

#### Pattern 1 : Exploration Rapide

```markdown
**Séquence optimale** :
1. codebase_search (découverte sémantique)
2. quickfiles read_multiple_files (lecture ciblée)
3. Analyse et décision

**vs Séquence inefficace** :
1. read_file (fichier 1)
2. read_file (fichier 2) 
3. read_file (fichier 3)
→ 3x plus de requêtes, 3x plus de tokens
```

#### Pattern 2 : Refactoring Batch

```markdown
**Séquence recommandée** :
1. search_in_files (identifier tous les usages)
2. Analyser impacts
3. edit_multiple_files (appliquer changements coordonnés)
4. Tests validation

**Bénéfices** :
- Atomicité modifications
- Pas d'états intermédiaires incohérents
- Rollback facile si erreur
```

---

## ⚙️ MCP Tier 2 : Opérations Système

### Vue d'Ensemble

**Fonction principale** : Exécution commandes système, scripts, opérations git  
**Stratégie** : **win-cli PRIVILÉGIÉ** pour modes non-orchestrateur

### win-cli : Commandes Système Windows (PRIVILÉGIÉ)

**Serveur MCP** : `win-cli`  
**Fonction** : Exécution commandes système sécurisées et tracées  
**Utilisation** : **PRÉFÉRER à execute_command** dans modes non-orchestrateur

#### Configuration Débridée Validée (FB-06)

**Décision Finale** : Le MCP `win-cli` a été débridé suite à investigation 3.1

**Conclusion investigation** :
1. ✅ **Faisabilité** : Débridage = état nominal du MCP
2. ✅ **Configuration** : Restaurée dans [`mcps/external/win-cli/server/config.json`](../../mcps/external/win-cli/server/config.json)
3. ✅ **Avantages** : Meilleure gestion sessions, logs structurés, sécurité renforcée

**Bénéfices vs execute_command** :
- 🔒 **Sécurité** : Sandbox configurable avec restrictions granulaires
- 📊 **Traçabilité** : Logs MCP structurés et queryables
- 🎯 **Fiabilité** : Gestion erreurs robuste, timeout configurables
- 🚀 **Performance** : Sessions réutilisables, cache résultats

#### Patterns d'Usage win-cli

##### Pattern 1 : Installation Dépendances

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "npm install",
  "working_directory": "./frontend"
}
</arguments>
</use_mcp_tool>
```

##### Pattern 2 : Build Projet

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "npm run build",
  "working_directory": "./backend",
  "shell": "powershell"
}
</arguments>
</use_mcp_tool>
```

##### Pattern 3 : Tests Unitaires

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "npm test -- --coverage",
  "working_directory": "./src"
}
</arguments>
</use_mcp_tool>
```

##### Pattern 4 : Opérations Git Standards

```xml
<!-- Vérification statut -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "git status --short",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>

<!-- Diff staged -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "git diff --staged",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>

<!-- Log compact -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "git log --oneline --graph --decorate -10",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>
```

##### Pattern 5 : Scripts PowerShell

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "pwsh -Command \"Get-ChildItem -Recurse -Filter '*.log' | Remove-Item\"",
  "working_directory": "./logs",
  "shell": "powershell"
}
</arguments>
</use_mcp_tool>
```

##### Pattern 6 : Gestion Environnement

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "node -v && npm -v && git --version",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>
```

##### Pattern 7 : Opérations Fichiers Batch

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "mkdir -p dist/output && cp -r src/assets dist/",
  "working_directory": ".",
  "shell": "bash"
}
</arguments>
</use_mcp_tool>
```

##### Pattern 8 : Linting et Formatting

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "npm run lint -- --fix",
  "working_directory": "./src"
}
</arguments>
</use_mcp_tool>
```

##### Pattern 9 : Génération Documentation

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "npx typedoc --out docs src",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>
```

##### Pattern 10 : Vérification Ports

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "netstat -ano | findstr :3000",
  "working_directory": ".",
  "shell": "cmd"
}
</arguments>
</use_mcp_tool>
```

#### Cas d'Usage Prioritaires win-cli

**Commandes système** :
- ✅ Installation dépendances (npm, yarn, pnpm)
- ✅ Scripts build/test/lint
- ✅ Commandes PowerShell/Bash
- ✅ Gestion environnement (PATH, variables)

**Opérations git standards** :
- ✅ `git status`, `git diff`
- ✅ `git log --graph`
- ✅ `git branch`, `git checkout`
- ✅ Opérations lecture seule git

**Opérations fichiers** :
- ✅ Copies/déplacements batch via cli
- ✅ Recherches fichiers (find, grep)
- ✅ Compressions/archives

**Gestion processus** :
- ✅ Vérification ports (netstat)
- ✅ Liste processus actifs
- ✅ Kill processus (si nécessaire)

### git : Opérations Git Avancées

**Serveur MCP** : `git` (si disponible)  
**Fonction** : Opérations git complexes non couvertes par win-cli  
**Utilisation** : Complément win-cli pour cas avancés

**Cas d'usage réservés** :
- 🔧 Opérations git interactives (rebase, merge complexe)
- 🔧 Manipulation historique (rebase -i, amend complexe)
- 🔧 Gestion branches avancée (workflows GitFlow)
- 🔧 Hooks git personnalisés

**Note** : Pour 90% des cas, **win-cli suffit** pour opérations git courantes.

---

## 🔄 Terminal Natif vs win-cli : Guide Complet

### Tableau Comparatif

| Critère | Terminal Natif (`execute_command`) | win-cli MCP |
|---------|-----------------------------------|-------------|
| **Modes autorisés** | Orchestrator uniquement | Tous modes (code, debug, architect, ask) |
| **Persistance session** | Session terminal VSCode | Commande atomique |
| **Interactivité** | ✅ Oui (prompts, watch modes) | ❌ Non (commandes atomiques) |
| **Durée maximale** | ⏱️ Illimitée | ⏱️ <30s recommandé |
| **Traçabilité** | Logs VSCode terminal | Logs MCP structurés JSON |
| **Sécurité** | Limitée (accès complet) | Sandbox configurable |
| **Gestion erreurs** | Manuelle | Robuste (timeout, retry) |
| **Cas d'usage** | Serveurs dev, watch modes | Scripts, builds, tests, git |
| **Économie contexte** | Coût élevé (logs verbeux) | Optimisé (sortie structurée) |

### Quand Utiliser Terminal Natif (execute_command)

**✅ Cas d'usage autorisés** :
1. **Mode Orchestrator UNIQUEMENT**
   - Orchestrator a accès natif aux commandes terminal
   - Autres modes (code, debug, etc.) n'ont PAS accès

2. **Commandes interactives longues**
   ```bash
   npm run dev  # Serveur de développement
   npm run watch  # Mode watch continu
   docker-compose up  # Services Docker
   ```

3. **Commandes nécessitant terminal persistant**
   ```bash
   ssh user@server  # Sessions SSH
   python -m http.server  # Serveurs HTTP simples
   tail -f logs/app.log  # Monitoring logs en temps réel
   ```

4. **Debugging interactif**
   ```bash
   node --inspect app.js  # Debugging Node.js
   python -m pdb script.py  # Debugging Python
   ```

### Quand Utiliser win-cli MCP

**✅ Cas d'usage privilégiés** :

1. **Modes non-orchestrateur (code, debug, architect, ask)**
   - win-cli = SEULE option disponible
   - Remplace execute_command intégralement

2. **Commandes atomiques courtes (<30s)**
   ```bash
   npm install  # Installation dépendances
   npm test  # Tests unitaires
   git status  # Vérification statut
   npm run build  # Build projet
   ```

3. **Scripts batch et builds**
   ```bash
   npm run lint && npm run build  # Pipeline CI/CD
   pwsh -c "dotnet restore && dotnet build"  # Build .NET
   ```

4. **Opérations git standards**
   ```bash
   git diff --staged
   git log --oneline -10
   git branch -a
   ```

5. **Installation et configuration**
   ```bash
   npm install -g typescript
   pip install -r requirements.txt
   composer install
   ```

### Matrice de Décision Rapide

```
┌─────────────────────────┐
│   Mode = orchestrator?  │
└───────┬─────────────────┘
        │
    ┌───┴───┐
    │       │
   OUI     NON
    │       │
    ↓       ↓
┌─────────┐ ┌──────────┐
│ Durée?  │ │ win-cli  │
└─┬───┬───┘ │OBLIGATOIRE│
  │   │     └──────────┘
 >30s <30s
  │   │
  ↓   ↓
┌────┐┌────┐
│exec││win-│
│_cmd││cli │
└────┘└────┘
```

### Exemples de Conversion

#### Avant (execute_command)
```xml
<execute_command>
<command>npm install</command>
</execute_command>
```

#### Après (win-cli)
```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "npm install",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>
```

#### Maintenir execute_command (long-running)
```xml
<!-- Serveur dev = garder execute_command -->
<execute_command>
<command>npm run dev</command>
</execute_command>
```

---

## 🔄 Migration execute_command → win-cli

### Stratégie de Migration pour Mainteneurs

#### Étape 1 : Audit Instructions Modes Existantes

**Identifier occurrences** :
```bash
# Rechercher instructions execute_command
grep -r "execute_command" roo-modes/*/instructions.md

# Identifier patterns à migrer
grep -r "When you need to run commands" roo-modes/*/instructions.md
```

#### Étape 2 : Mise à Jour Instructions Modes

**AVANT (ancienne instruction)** :
```markdown
## COMMAND EXECUTION

When you need to run commands, use the execute_command tool.
```

**APRÈS (nouvelle instruction)** :
```markdown
## COMMAND EXECUTION

When you need to run commands:
- **Non-orchestrator modes** : Use win-cli MCP (PREFERRED)
  * Atomic commands (<30s)
  * Scripts, builds, tests
  * Git operations
- **Orchestrator mode** : Use execute_command (native terminal)
  * Long-running processes (>30s)
  * Interactive sessions
  * Watch modes, dev servers
```

#### Étape 3 : Exemples de Conversion par Cas d'Usage

##### Cas 1 : Installation Dépendances
```markdown
<!-- AVANT -->
<execute_command>
<command>npm install</command>
</execute_command>

<!-- APRÈS -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "npm install",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>
```

##### Cas 2 : Vérification Git
```markdown
<!-- AVANT -->
<execute_command>
<command>git status</command>
</execute_command>

<!-- APRÈS -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "git status --short",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>
```

##### Cas 3 : Build Projet
```markdown
<!-- AVANT -->
<execute_command>
<command>npm run build</command>
</execute_command>

<!-- APRÈS -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "npm run build",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>
```

##### Cas 4 : Serveur Dev (GARDER execute_command)
```markdown
<!-- GARDER execute_command -->
<execute_command>
<command>npm run dev</command>
</execute_command>

<!-- Raison : Long-running, interactif -->
```

#### Étape 4 : Validation Migration

**Checklist validation** :
- [ ] Tous modes non-orchestrateur utilisent win-cli
- [ ] Mode orchestrator conserve execute_command pour long-running
- [ ] Exemples XML win-cli corrects (working_directory, shell)
- [ ] Documentation clarté win-cli vs execute_command
- [ ] Tests end-to-end sur modes migrés

---

## 🔜 MCP Tier 3 : github-projects (Future Phase 2.2+)

### Vue d'Ensemble

**Serveur MCP** : `github-projects-mcp`  
**Fonction principale** : Synchronisation GitHub Issues/Projects/PR  
**Utilisation** : OBLIGATOIRE à terme pour traçabilité externe

### Outils Principaux (Aperçu)

#### 1. create_issue

**Usage prévu** : Création issues avec lien projet

```xml
<use_mcp_tool>
<server_name>github-projects-mcp</server_name>
<tool_name>create_issue</tool_name>
<arguments>
{
  "repositoryName": "owner/repo",
  "title": "Feature: Refactoring Architecture Modes",
  "body": "## Contexte\n...\n## Solution\n...",
  "projectId": "project_id"
}
</arguments>
</use_mcp_tool>
```

#### 2. add_item_to_project

**Usage prévu** : Ajout tâches dans projets GitHub

```xml
<use_mcp_tool>
<server_name>github-projects-mcp</server_name>
<tool_name>add_item_to_project</tool_name>
<arguments>
{
  "owner": "username",
  "project_id": "PVT_xxx",
  "content_id": "issue_id"
}
</arguments>
</use_mcp_tool>
```

#### 3. update_project_item_field

**Usage prévu** : Mise à jour statuts dans projets

```xml
<use_mcp_tool>
<server_name>github-projects-mcp</server_name>
<tool_name>update_project_item_field</tool_name>
<arguments>
{
  "owner": "username",
  "project_id": "PVT_xxx",
  "item_id": "item_id",
  "field_id": "status_field",
  "field_type": "single_select",
  "option_id": "in_progress"
}
</arguments>
</use_mcp_tool>
```

### Intégration Future SDDD Phase 4

**Workflow cible** :
1. Début tâche → Création issue GitHub
2. Ajout issue dans projet approprié
3. Progression tâche → Mise à jour statuts
4. Fin tâche → Création PR liée issue
5. Validation → Clôture issue

**Bénéfices attendus** :
- Traçabilité complète externe
- Synchronisation équipe automatique
- Roadmap toujours à jour
- Métriques projet centralisées

---

## 🎯 MCP Tier 4 : Outils Spécialisés

### jinavigator

**Fonction** : Extraction contenu web en markdown  
**Usage** : Recherches documentation en ligne, veille technique

```xml
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>convert_web_to_markdown</tool_name>
<arguments>
{
  "url": "https://docs.example.com/api/reference",
  "start_line": 50,
  "end_line": 150
}
</arguments>
</use_mcp_tool>
```

### searxng

**Fonction** : Recherche web multi-moteurs  
**Usage** : Veille technique, recherche solutions

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "typescript advanced patterns",
  "time_range": "month"
}
</arguments>
</use_mcp_tool>
```

### playwright

**Fonction** : Automatisation browser  
**Usage** : Tests E2E, validation UI, scraping

```xml
<use_mcp_tool>
<server_name>playwright</server_name>
<tool_name>browser_navigate</tool_name>
<arguments>
{
  "url": "http://localhost:3000"
}
</arguments>
</use_mcp_tool>
```

### jupyter-mcp

**Fonction** : Gestion notebooks Jupyter  
**Usage** : Data science, analyse, documentation interactive

```xml
<use_mcp_tool>
<server_name>jupyter-mcp</server_name>
<tool_name>execute_notebook</tool_name>
<arguments>
{
  "path": "notebooks/analysis.ipynb",
  "kernel_id": "kernel-id"
}
</arguments>
</use_mcp_tool>
```

---

## 📋 Matrice Décision Utilisation MCP
## Remplacement MCPs Redondants par Outils Natifs 🔄

Cette section documente les MCPs à remplacer par des outils natifs pour améliorer stabilité et performance.

### git (MCP) → git CLI natif

**Décision** : Remplacer le MCP `git` par des commandes `git` CLI natives dans tous les modes.

**Justifications** :
- ✅ **Stabilité** : CLI git natif plus stable et mature
- ✅ **Performance** : Pas de couche d'abstraction MCP
- ✅ **Flexibilité** : Accès complet à toutes les fonctionnalités git
- ✅ **Élimination dépendance npx** : Pas de problèmes d'installation/démarrage

**Migration** :

| Opération MCP git | Équivalent CLI natif |
|-------------------|---------------------|
| `git.status()` | `pwsh -c "git status"` |
| `git.commit(message)` | `pwsh -c "git commit -m 'message'"` |
| `git.push()` | `pwsh -c "git push"` |
| `git.log()` | `pwsh -c "git log --oneline -10"` |

**Timeline Décommissionnement** :
- Q4 2025 : Documenter migration dans guides modes
- Q1 2026 : Retirer `git` MCP de configurations par défaut
- Q2 2026 : Dépréciation complète (avertissements si utilisé)

**Modes Impactés** : Tous modes (orchestrator, code, debug, architect, ask)

**Note** : Le MCP `github` (différent de `git`) est **CONSERVÉ** pour opérations API simples.

---

### ❌ MCPs NON Concernés par Remplacement

Les MCPs suivants sont **EXCLUS** de la stratégie de remplacement :

#### win-cli : PRÉSERVÉ (FB-06)
- ✅ **Décision FB-06 (02 Oct 2025)** : win-cli débridé = solution privilégiée
- ✅ **Raison** : Sécurité (sandbox), traçabilité (logs structurés), performance
- ✅ **Statut** : Opérationnel après compilation TypeScript
- ⚠️ **Clarification** : Audit initial suggérait remplacement, FB-06 a INVALIDÉ cette recommandation

#### markitdown : PRÉSERVÉ
- ✅ **Raison** : Pas d'équivalent natif robuste pour conversion multi-formats
- ✅ **Statut** : Opérationnel après installation uv (Python 3.13.7)

---

## Roadmap Intégration github-projects (Niveau 4 SDDD) 🎯

Le MCP **github-projects** est stratégique pour le futur de l'architecture SDDD, permettant de lier les tâches Roo au projet GitHub.

### Vision

Chaque **tâche complexe** dans Roo sera automatiquement liée à une **issue GitHub** pour :
- 📊 **Traçabilité** : Historique complet du travail effectué
- 🔗 **Contexte** : Lien discussions projet ↔ code modifié
- 📈 **Métriques** : Velocity, cycle time, productivité quantifiable
- 🤝 **Collaboration** : Contexte partagé entre humains et agents

### État Actuel (Oct 2025)

⚠️ **github-projects MCP : NON-OPÉRATIONNEL**

**Problèmes Identifiés** :
- Configuration GitHub PAT incorrecte ou scopes manquants
- Connexion repository échoue au démarrage MCP
- Outils MCP (`create_issue`, `add_item_to_project`) inaccessibles

**Action Prioritaire** : Mission dédiée résolution configuration (Q4 2025)

### Roadmap 3 Phases (Q4 2025 - Q2 2026)

#### Phase 1 : Configuration et Tests Unitaires (Q4 2025)

**Objectifs** :
- ✅ Résoudre problèmes configuration github-projects MCP
- ✅ Valider connexion repository avec GitHub PAT correct
- ✅ Tests unitaires sur tous les outils MCP disponibles
- ✅ Documentation setup GitHub PAT (scopes requis : `repo`, `project`)

**Livrables** :
- Guide configuration PAT GitHub pour github-projects
- Tests validation connexion automatisés
- Documentation troubleshooting configuration

**Référence** : [`sddd-protocol-4-niveaux.md#niveau-4`](sddd-protocol-4-niveaux.md#niveau-4)

---

#### Phase 2 : Intégration Modes architect/orchestrator (Q1 2026)

**Objectifs** :
- 🔧 Intégrer `create_issue` dans mode orchestrator
- 🔧 Workflow automatique : Tâche complexe détectée → Création issue GitHub
- 🔧 Intégrer `add_item_to_project` pour association project board
- 🔧 Documentation patterns d'utilisation dans guides modes

**Workflow Cible** :
```markdown
orchestrator (tâche complexe) 
  → Détection critères (>10k tokens ou >3 sous-tâches)
  → github-projects.create_issue({title, body, labels})
  → github-projects.add_item_to_project({issue_id, project_id})
  → Poursuite tâche avec issue liée
```

**Livrables** :
- Intégration `create_issue` dans orchestrator (automatique)
- Intégration `add_item_to_project` dans orchestrator
- Documentation patterns dans `roo-modes/orchestrator/README.md`
- Tests end-to-end workflows

**Critères Déclenchement Création Issue** :
- Tâche estimée >10k tokens de contexte
- Orchestration avec >3 sous-tâches
- Modifications multi-fichiers (>5 fichiers)
- Décision architecturale majeure

---

#### Phase 3 : Synchronisation État Complète (Q2 2026)

**Objectifs** :
- 🔧 Intégrer `update_project_item_field` dans tous modes
- 🔧 Synchronisation automatique : État tâche Roo ↔ Statut issue GitHub
- 🔧 Workflow : `attempt_completion` → Fermeture automatique issue
- 🔧 Métriques et rapports d'activité

**Workflow Cible** :
```markdown
Mode spécialisé (ex: code)
  → Travail sur tâche (issue liée)
  → Changements d'état synchronisés :
     - "In Progress" quand mode démarre
     - "In Review" si modifications substantielles
     - "Done" à attempt_completion

  → Fermeture issue + commentaire synthèse
```

**Livrables** :
- Synchronisation état dans tous modes (code, debug, architect, ask)
- Hook `attempt_completion` → Fermeture issue automatique
- Dashboard métriques productivité
- Rapports hebdomadaires automatisés

**Métriques Collectées** :
- Velocity (issues complétées / semaine)
- Cycle time (durée moyenne issue)
- Temps par type de tâche (refactoring, feature, bugfix)
- Ratio tâches avec/sans issues (compliance)

### Bénéfices Attendus Post-Q2 2026

- 🎯 **Traçabilité** : 100% tâches complexes liées à issues
- 📊 **Métriques** : Données productivité quantifiables
- 🤝 **Collaboration** : Contexte partagé équipe
- 🔍 **Audit** : Historique décisions projet complet
- 🚀 **Productivité** : Évite duplication (recherche issues existantes)

### Prochaines Actions

1. **Immédiat (Oct 2025)** : Mission dédiée résolution configuration github-projects
2. **Nov 2025** : Tests unitaires outils MCP validés
3. **Déc 2025** : Documentation setup PAT finalisée
4. **Jan 2026** : Début intégration orchestrator

**Référence Complète** : [`sddd-protocol-4-niveaux.md#niveau-4`](sddd-protocol-4-niveaux.md#niveau-4)

---

### Flowchart Sélection Outil

```
┌───────────────────┐
│ Besoin identifié  │
└────────┬──────────┘
         ↓
    ┌────────────┐
    │ Type tâche │
    └──┬─────┬───┘
       │     │
    Fichiers  État/Historique  Commandes
       │     │                    │
       ↓     ↓                    ↓
┌──────────┐ ┌──────────────┐ ┌────────────┐
│ Batch ?  │ │ Conversationnel?│ │ Mode ?   │
└─┬────┬───┘ └──┬───────────┘ └─┬──────┬───┘
  │    │        │               │      │
 OUI  NON      OUI         Orchestr  Autre
  │    │        │               │      │
  ↓    ↓        ↓               ↓      ↓
┌──────┐ ┌──────┐ ┌──────────────┐ ┌────┐ ┌────┐
│quickf│ │natif │ │roo-state-mgr │ │exec│ │win-│
└──────┘ └──────┘ └──────────────┘ │_cmd│ │cli │
                                    └────┘ └────┘
```

### Tableau Récapitulatif

| Besoin | Outil Recommandé | Alternative | Justification |
|--------|------------------|-------------|---------------|
| Lecture 3+ fichiers | quickfiles | read_file × N | Économie tokens |
| Recherche regex multi-fichiers | quickfiles | search_files | Contexte enrichi |
| Édition coordonnée | quickfiles | apply_diff × N | Atomicité |
| Contexte historique | roo-state-manager | Aucune | Seule source |
| Navigation hiérarchie | roo-state-manager | Manuelle | Automatisée |
| Recherche décisions passées | roo-state-manager | Grep | Sémantique |
| **Commandes système** | **win-cli** | execute_command | **Tous modes** |
| **Build/tests** | **win-cli** | execute_command | **Traçabilité** |
| **Opérations git** | **win-cli** | git MCP | **Standards** |
| Serveurs dev | execute_command | N/A | Long-running |
| Documentation web | jinavigator | browser | Markdown direct |
| Tests UI | playwright | Manuelle | Automatisation |
| Sync GitHub | github-projects | Manuelle | Traçabilité |

---

## 🎨 Templates Instructions Modes

### Template Utilisation MCP Systématique

```markdown
## INTÉGRATIONS MCP PRIORITAIRES

### Tier 1 : Utilisation Systématique

**roo-state-manager** :
- Grounding conversationnel OBLIGATOIRE (Phase 3 SDDD)
- Navigation hiérarchie pour orchestration complexe
- Recherche sémantique décisions historiques

**quickfiles** :
- PRIVILÉGIER pour lecture/édition batch (>2 fichiers)
- PRIVILÉGIER pour recherches multi-fichiers
- Économie tokens et efficacité maximale

### Tier 2 : Opérations Système

**win-cli** : (PRIVILÉGIÉ pour modes non-orchestrateur)
- Commandes système Windows (PowerShell, cmd, bash)
- Scripts npm/yarn/pnpm, builds, tests
- Opérations git standards (status, diff, log)
- Gestion environnement et processus

**Quand utiliser** :
- ✅ Modes code/debug/architect/ask : win-cli OBLIGATOIRE
- ✅ Commandes atomiques (<30s)
- ✅ Scripts batch, CI/CD
- ❌ Long-running : execute_command (orchestrator)

### Tier 3 : Future Intégration

**github-projects** : (Phase 2.2+)
- Création issues pour tâches majeures
- Synchronisation roadmap équipe
- Traçabilité externe complète

### Tier 4 : Cas Spécifiques

- **jinavigator** : Documentation web
- **searxng** : Veille technique
- **playwright** : Tests UI automatisés
- **jupyter-mcp** : Notebooks analytiques

### Patterns Efficacité

**Exploration code** :
1. codebase_search (sémantique)
2. roo-state-manager search_tasks (historique)
3. quickfiles read_multiple_files (lecture ciblée)

**Build/Deploy** :
1. win-cli run_command (npm install)
2. win-cli run_command (npm run build)
3. win-cli run_command (git status --short)
4. Validation résultats

**Orchestration** :
1. roo-state-manager view_conversation_tree (structure)
2. Décomposition hiérarchie numérotée
3. new_task() avec contexte hérité
```

---

## 📊 Métriques et Monitoring

### Indicateurs Utilisation MCP

**Par mode** :
- Taux utilisation quickfiles vs outils natifs : >70% cible
- Taux grounding roo-state-manager : 100% tâches complexes
- Taux utilisation win-cli vs execute_command : >90% (hors orchestrator)
- Économie tokens via MCPs : >20k tokens/tâche

**Par tâche** :
```markdown
## Rapport Utilisation MCP - Tâche [ID]

### MCP Utilisés
- roo-state-manager : 5 requêtes
  - view_conversation_tree : 2
  - search_tasks_semantic : 3
- quickfiles : 8 requêtes
  - read_multiple_files : 4
  - edit_multiple_files : 2
  - search_in_files : 2
- win-cli : 6 requêtes
  - npm install : 1
  - npm run build : 1
  - git status : 2
  - npm test : 2

### Efficacité
- Tokens économisés : ~18k (vs outils natifs)
- Temps économisé : ~15 min (batch operations)
- Erreurs évitées : 3 (grounding historique)
- Sécurité renforcée : Sandbox win-cli actif
```

---

## ⚠️ Anti-Patterns à Éviter

### ❌ Multiplication Requêtes Natives
```xml
<!-- MAUVAIS : 5 read_file séparés -->
<read_file><path>file1.ts</path></read_file>
<read_file><path>file2.ts</path></read_file>
<read_file><path>file3.ts</path></read_file>
<read_file><path>file4.ts</path></read_file>
<read_file><path>file5.ts</path></read_file>
```

### ✅ Batch Efficace
```xml
<!-- BON : 1 requête quickfiles -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": ["file1.ts", "file2.ts", "file3.ts", "file4.ts", "file5.ts"]
}
</arguments>
</use_mcp_tool>
```

### ❌ Pas de Grounding Conversationnel
```markdown
Mode commence refactoring sans vérifier historique
→ Duplication efforts, incohérence avec décisions passées
```

### ✅ Grounding Complet
```markdown
1. codebase_search
2. roo-state-manager search_tasks_semantic
3. Analyse résultats combinés
4. Décision éclairée
```

### ❌ Utiliser execute_command en mode non-orchestrateur
```xml
<!-- MAUVAIS : execute_command en mode code -->
<execute_command>
<command>npm test</command>
</execute_command>

<!-- Erreur : execute_command non disponible -->
```

### ✅ Utiliser win-cli en mode non-orchestrateur
```xml
<!-- BON : win-cli en mode code -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>run_command</tool_name>
<arguments>
{
  "command": "npm test",
  "working_directory": "."
}
</arguments>
</use_mcp_tool>
```

---

## 🚀 Bénéfices des Intégrations MCP

1. **Efficacité** : -40% requêtes, -30% tokens via batch operations
2. **Traçabilité** : Contexte historique toujours accessible
3. **Qualité** : Décisions basées sur historique complet
4. **Collaboration** : Synchronisation équipe via GitHub (future)
5. **Performance** : Opérations optimisées pour volume
6. **Sécurité** : Sandbox win-cli pour commandes système (FB-06)
7. **Accessibilité** : Commandes disponibles dans tous modes (win-cli)
8. **Fiabilité** : Gestion erreurs robuste, logs structurés

---

## 📚 Références Croisées

### Documents Liés

- [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) : Intégration grounding conversationnel Phase 3
- [`context-economy-patterns.md`](context-economy-patterns.md) : Optimisation utilisation MCPs et win-cli batch
- [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) : win-cli disponible tous modes (désescalade économique)
- [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md) : Exemples win-cli dans sous-tâches

### Intégration win-cli dans Architecture

**Dans context-economy-patterns.md** :
- Pattern 4 : Batch operations → Utiliser win-cli pour commandes multiples
- Pattern 7 : Désescalade → win-cli évite escalade vers orchestrator

**Dans hierarchie-numerotee-subtasks.md** :
- Exemples sous-tâches techniques : Utiliser win-cli pour builds/tests
- Sous-tâche validation : win-cli pour vérifications git

**Dans escalade-mechanisms-revised.md** :
- Trigger escalade : Si win-cli échoue répétitivement → Escalade orchestrator
- Désescalade : win-cli permet résolution locale sans orchestration

---

## 🎯 Conclusion

**Version 2.0.0** intègre officiellement la **décision FB-06** : **win-cli débridé devient la solution PRIVILÉGIÉE** pour commandes système dans tous modes non-orchestrateur.

**Impacts majeurs** :
1. ✅ **Modes code/debug** : Accès complet commandes via win-cli
2. ✅ **Sécurité renforcée** : Sandbox configurable, logs structurés
3. ✅ **Traçabilité améliorée** : Historique MCP complet
4. ✅ **Architecture clarifiée** : win-cli = Tier 2 prioritaire
5. ✅ **Migration documentée** : Stratégie execute_command → win-cli

**Phase 3 P1 finalisée** : L'intégration win-cli complète l'architecture 2-niveaux optimisée avec MCPs Tier 1 (roo-state-manager, quickfiles) et Tier 2 (win-cli, git).

---

**Note :** Les MCPs sont des extensions puissantes de Roo qui, utilisées correctement, multiplient l'efficacité et la qualité du travail. Leur intégration systématique est un pilier de l'architecture 2-niveaux optimisée. **win-cli débridé (FB-06) finalise cette vision en donnant à tous les modes l'accès sécurisé aux commandes système.**
# Analyse des Patterns d'Utilisation des Outils MCP

**Issue:** #545
**Date:** 2026-02-27
**Auteur:** Roo Code (mode code-complex)
**Période analysée:** 18-23 février 2026
**Échantillon:** 10 tâches Roo récentes

---

## Résumé Exécutif

Cette analyse examine les patterns d'utilisation des outils MCP (Model Context Protocol) dans le workspace `roo-extensions`. L'objectif est d'identifier les outils les plus utilisés, les outils sous-utilisés, et les patterns d'appel récurrents pour optimiser les workflows futurs.

### Constats Clés

1. **Outils natifs dominants** : Les outils natifs (`read_file`, `updateTodoList`, `new_task`) sont utilisés dans 90-100% des tâches
2. **MCP win-cli critique** : Seul MCP shell actif, utilisé dans 30% des tâches pour les commandes système
3. **RooSync tools réservés** : Les outils `roosync_*` sont rarement utilisés par Roo (réservés à Claude Code)
4. **Pattern de délégation** : 60% des tâches délèguent des sous-tâches via `new_task`

---

## 1. Inventaire des Outils MCP Disponibles

### 1.1 Serveurs MCP Actifs

| Serveur | Outils | Statut | Usage Roo |
|---------|--------|--------|-----------|
| **roo-state-manager** | 36 | ✅ Actif | Limité (outils autorisés uniquement) |
| **win-cli** | 3 | ✅ Actif | Autorisé (shell unique) |
| **markitdown** | 1 | ✅ Actif | Occasionnel |
| **playwright** | ? | ✅ Actif | Rare (automatisation web) |
| **jinavigator** | 4 | ✅ Actif | Rare |
| **searxng** | 2 | ✅ Actif | Rare |

### 1.2 Outils roo-state-manager (36 outils)

#### Outils AUTORISÉS pour Roo (16 outils)

| Catégorie | Outil | Description |
|-----------|-------|-------------|
| **Navigation** | `conversation_browser` | Arbre tâches, vue conversation, résumé |
| **Navigation** | `view_task_details` | Détails techniques d'une tâche |
| **Navigation** | `get_raw_conversation` | Contenu brut JSON |
| **Navigation** | `task_export` | Export markdown/JSON/CSV |
| **Recherche** | `roosync_search` | Recherche textuelle/sémantique |
| **Recherche** | `codebase_search` | Recherche sémantique dans le code |
| **Diagnostic** | `read_vscode_logs` | Logs VS Code |
| **Diagnostic** | `roosync_diagnose` | Diagnostic environnement |
| **Stockage** | `storage_info` | Localiser stockage Roo |
| **Stockage** | `maintenance` | Cache rebuild, BOM repair |
| **MCP** | `manage_mcp_settings` | Lecture/écriture settings MCP |
| **MCP** | `rebuild_and_restart_mcp` | Rebuild + restart MCP |
| **MCP** | `get_mcp_best_practices` | Guide bonnes pratiques |
| **Export** | `export_data` | Export XML/JSON/CSV |
| **Export** | `export_config` | Configuration exports |
| **Analyse** | `analyze_roosync_problems` | Diagnostic roadmap |

#### Outils INTERDITS pour Roo (20 outils - réservés Claude Code)

| Catégorie | Outils |
|-----------|--------|
| **Messagerie** | `roosync_send`, `roosync_read`, `roosync_manage` |
| **Configuration** | `roosync_config`, `roosync_baseline`, `roosync_inventory` |
| **Monitoring** | `roosync_heartbeat`, `roosync_machines` |
| **Décisions** | `roosync_decision`, `roosync_decision_info` |
| **Comparaison** | `roosync_compare_config`, `roosync_list_diffs` |
| **Dashboard** | `roosync_refresh_dashboard` |
| **Coordination** | `roosync_get_status`, `roosync_init`, `roosync_mcp_management`, `roosync_storage_management` |
| **Indexation** | `roosync_indexing` |

### 1.3 Outils win-cli (3 outils)

| Outil | Description | Shells |
|-------|-------------|--------|
| `execute_command` | Exécute commande shell | powershell, cmd, gitbash |
| `get_command_history` | Historique des commandes | - |
| `ssh_*` | Connexions SSH | - |

---

## 2. Analyse des 10 Tâches Récentes

### 2.1 Liste des Tâches Analysées

| # | ID | Date | Type | Description |
|---|-----|------|------|-------------|
| 1 | `019c8acc` | 2026-02-23 | Scheduler | Workflow planificateur |
| 2 | `019c8ad9` | 2026-02-23 | Vérification | Inbox RooSync |
| 3 | `019c8ad3` | 2026-02-23 | Grounding | Qdrant/indexation |
| 4 | `019c7786` | 2026-02-19 | Build+Tests | Tâche par défaut #1 |
| 5 | `019c777c` | 2026-02-19 | Scheduler | Coordinateur |
| 6 | `019c758e` | 2026-02-19 | Scheduler | Coordinateur urgent |
| 7 | `019c73aa` | 2026-02-19 | Worktree | Context git |
| 8 | `019c73a0` | 2026-02-19 | Coordinateur | Worktree |
| 9 | `019c7309` | 2026-02-18 | GitHub | Issues listing |
| 10 | `019c72fb` | 2026-02-18 | Scheduler | Coordinateur |

### 2.2 Fréquence d'Utilisation des Outils MCP

#### Outils roo-state-manager

| Outil | Fréquence | Tâches | Commentaire |
|-------|-----------|--------|-------------|
| `conversation_browser` | 2 | #2, #7 | Vue squelette, résumé |
| `roosync_search` | 1 | #3 | Recherche textuelle |
| `task_export` | 1 | #7 | Export markdown |
| `roosync_read` | 3 | #4 | ⚠️ INTERDIT - utilisé par erreur |
| `roosync_manage` | 2 | #4 | ⚠️ INTERDIT - utilisé par erreur |

#### Outils win-cli

| Outil | Fréquence | Tâches | Commandes |
|-------|-----------|--------|-----------|
| `execute_command` | 3 | #1, #2, #3 | `echo OK`, `ls`, `git status` |

### 2.3 Fréquence d'Utilisation des Outils Natifs

| Outil | Fréquence | % | Usage principal |
|-------|-----------|---|-----------------|
| `updateTodoList` | 10/10 | 100% | Suivi progression |
| `read_file` | 9/10 | 90% | Lecture INTERCOM, workflow |
| `new_task` | 6/10 | 60% | Délégation code-simple |
| `execute_command` (natif) | 3/10 | 30% | npm run build, vitest, gh |
| `editedExistingFile` | 2/10 | 20% | Modification INTERCOM |
| `appliedDiff` | 1/10 | 10% | Patch INTERCOM |
| `search_files` | 1/10 | 10% | Recherche documentation |

---

## 3. Top 5 Outils les Plus Utilisés

### 3.1 Classement

| Rang | Outil | Type | Fréquence | Rôle |
|------|-------|------|-----------|------|
| 1 | `updateTodoList` | Natif | 100% | Tracking progression |
| 2 | `read_file` | Natif | 90% | Lecture fichiers, INTERCOM |
| 3 | `new_task` | Natif | 60% | Délégation sous-tâches |
| 4 | `execute_command` | MCP/Natif | 30% | Commandes shell |
| 5 | `conversation_browser` | MCP | 20% | Navigation tâches |

### 3.2 Analyse du Top 5

1. **updateTodoList** : Indispensable pour le suivi des tâches complexes. Présent dans toutes les tâches scheduler.
2. **read_file** : Utilisé principalement pour lire l'INTERCOM (`.claude/local/INTERCOM-*.md`) et les fichiers de workflow.
3. **new_task** : Pattern de délégation systématique du mode code-complex vers code-simple pour les sous-tâches.
4. **execute_command** : Mix d'usage MCP win-cli et terminal natif selon le mode.
5. **conversation_browser** : Outil MCP de grounding conversationnel, utilisé dans les phases d'investigation.

---

## 4. Outils Disponibles mais Non Utilisés

### 4.1 Outils MCP roo-state-manager non utilisés (sur 10 tâches)

| Outil | Raison probable |
|-------|-----------------|
| `codebase_search` | Recherche sémantique - utile pour grounding initial |
| `read_vscode_logs` | Diagnostic uniquement en cas d'erreur |
| `roosync_diagnose` | Diagnostic avancé - rarement nécessaire |
| `storage_info` | Maintenance uniquement |
| `maintenance` | Opérations de maintenance |
| `manage_mcp_settings` | Configuration MCP |
| `rebuild_and_restart_mcp` | Redémarrage MCP |
| `get_mcp_best_practices` | Documentation |
| `export_data` | Export de données |
| `export_config` | Configuration exports |
| `analyze_roosync_problems` | Diagnostic roadmap |
| `view_task_details` | Détails techniques |
| `get_raw_conversation` | Debug uniquement |

### 4.2 Outils MCP autres serveurs non utilisés

| Serveur | Outil | Raison |
|---------|-------|--------|
| markitdown | `convert_to_markdown` | Conversion documents |
| jinavigator | `convert_web_to_markdown` | Navigation web |
| jinavigator | `multi_convert` | Conversion multiple |
| jinavigator | `extract_markdown_outline` | Extraction plan |
| searxng | `searxng_web_search` | Recherche web |
| searxng | `web_url_read` | Lecture URL |

---

## 5. Patterns d'Appel Identifiés

### 5.1 Pattern Scheduler Coordinateur

```
1. read_file(scheduler-workflow.md)
2. read_file(INTERCOM-*.md)
3. updateTodoList
4. new_task(code-simple) → Git status
5. new_task(code-simple) → Build + Tests
6. new_task(code-simple) → Rapport INTERCOM
7. updateTodoList
```

**Fréquence:** 6/10 tâches
**Outils MCP:** Aucun (tout natif)

### 5.2 Pattern Grounding Conversationnel

```
1. roosync_search(text) ou conversation_browser(tree)
2. conversation_browser(view, skeleton)
3. conversation_browser(summarize, trace)
4. read_file(fichiers pertinents)
```

**Fréquence:** 2/10 tâches
**Outils MCP:** `roosync_search`, `conversation_browser`

### 5.3 Pattern Build + Tests

```
1. execute_command(npm run build)
2. execute_command(npx vitest run)
3. read_file(INTERCOM)
4. editedExistingFile(INTERCOM) → Rapport
```

**Fréquence:** 2/10 tâches
**Outils MCP:** Aucun (terminal natif)

### 5.4 Pattern Worktree Context

```
1. read_file(INTERCOM)
2. execute_command(git status)
3. execute_command(git pull)
4. appliedDiff ou editedExistingFile(INTERCOM)
5. task_export ou conversation_browser
```

**Fréquence:** 2/10 tâches
**Outils MCP:** `task_export`, `conversation_browser`

---

## 6. Catégories d'Outils par Famille

### 6.1 Famille Navigation (5 outils)

| Outil | Usage | Fréquence |
|-------|-------|-----------|
| `conversation_browser` | Vue tâches | 20% |
| `view_task_details` | Détails | 0% |
| `get_raw_conversation` | Debug | 0% |
| `task_export` | Export | 10% |
| `roosync_search` | Recherche | 10% |

**Total utilisation:** 40% (4/10 tâches)

### 6.2 Famille Diagnostic (2 outils)

| Outil | Usage | Fréquence |
|-------|-------|-----------|
| `read_vscode_logs` | Logs | 0% |
| `roosync_diagnose` | Diagnostic | 0% |

**Total utilisation:** 0%

### 6.3 Famille Stockage (2 outils)

| Outil | Usage | Fréquence |
|-------|-------|-----------|
| `storage_info` | Info stockage | 0% |
| `maintenance` | Maintenance | 0% |

**Total utilisation:** 0%

### 6.4 Famille MCP Management (3 outils)

| Outil | Usage | Fréquence |
|-------|-------|-----------|
| `manage_mcp_settings` | Config | 0% |
| `rebuild_and_restart_mcp` | Rebuild | 0% |
| `get_mcp_best_practices` | Docs | 0% |

**Total utilisation:** 0%

### 6.5 Famille Shell (win-cli)

| Outil | Usage | Fréquence |
|-------|-------|-----------|
| `execute_command` | Commandes | 30% |

**Total utilisation:** 30%

---

## 7. Anomalies et Recommandations

### 7.1 Anomalie Critique Détectée

⚠️ **Utilisation d'outils RooSync interdits (Tâche #4)**

Dans la tâche `019c7786` (Build + Tests), les outils suivants ont été utilisés:
- `roosync_read` (3 fois)
- `roosync_manage` (2 fois)

Ces outils sont **INTERDITS** pour Roo selon `.roo/rules/03-mcp-usage.md`:
> "RooSync (roosync_send, roosync_read, roosync_manage, etc.) est EXCLUSIVEMENT pour Claude Code"

**Recommandation:** Renforcer la validation des règles dans les modes pour éviter cette utilisation.

### 7.2 Recommandations d'Optimisation

1. **Utiliser `codebase_search` pour le grounding** : Cet outil sémantique est sous-utilisé et pourrait améliorer la phase de grounding initial.

2. **Documenter les patterns de délégation** : Le pattern `new_task` → code-simple est très fréquent (60%) mais pas formalisé.

3. **Consolider les outils de navigation** : `conversation_browser` remplace déjà plusieurs outils (tree, view, summarize). Envisager la dépréciation des outils redondants.

4. **Activer `read_vscode_logs` en cas d'erreur** : Intégrer automatiquement cet outil dans le workflow d'erreur.

5. **Évaluer la pertinence des MCPs secondaires** : `jinavigator` et `searxng` n'ont jamais été utilisés dans l'échantillon.

---

## 8. Conclusion

### 8.1 Synthèse

L'analyse révèle une utilisation **très concentrée** des outils:
- **3 outils natifs** couvrent 90%+ des besoins (`updateTodoList`, `read_file`, `new_task`)
- **1 outil MCP** est utilisé régulièrement (`execute_command` via win-cli)
- **16 outils MCP** disponibles pour Roo sont **rarement ou jamais utilisés**

### 8.2 Points d'Attention

1. **Respect des règles MCP** : L'anomalie détectée sur `roosync_read/manage` doit être corrigée
2. **Sous-utilisation du grounding sémantique** : `codebase_search` pourrait améliorer les workflows
3. **Délégation systématique** : Le pattern code-complex → code-simple est efficace mais mérite documentation

### 8.3 Prochaines Étapes

1. Corriger l'accès aux outils RooSync interdits
2. Documenter les patterns de délégation dans `.roo/rules/`
3. Évaluer la suppression des MCPs non utilisés (jinavigator, searxng)
4. Automatiser l'usage de `codebase_search` dans le grounding initial

---

## Annexes

### A. Fichiers de Référence

- `.roo/rules/03-mcp-usage.md` - Règles d'utilisation MCP
- `mcps/internal/servers/roo-state-manager/src/tools/roosync/index.ts` - Définition outils RooSync
- `mcps/internal/servers/roo-state-manager/src/tools/registry.ts` - Registre complet

### B. Méthodologie

1. **Grounding sémantique** : Recherche `roosyncTools` dans le codebase
2. **Grounding conversationnel** : `conversation_browser(tree)` + `view` sur 10 tâches
3. **Analyse manuelle** : Extraction des patterns depuis les squelettes de conversation

### C. Limitations

- Échantillon limité à 10 tâches récentes
- Période courte (5 jours)
- Pas d'analyse des tâches Claude Code (seulement Roo)

---

*Rapport généré par Roo Code - mode code-complex*
*Issue #545 - MCP Usage Pattern Analysis*

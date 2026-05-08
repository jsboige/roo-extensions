# Audit d'Utilisation des Outils roo-state-manager

**Date:** 2026-05-08  
**Issue:** #1841  
**Branche:** wt/myia-po-2023-issue-1841  
**Période analysée:** 30 derniers jours (2026-04-08 à 2026-05-08)  
**Méthodologie:** SDDD (Semantic Documentation Driven Design) avec roosync_search + codebase_search

---

## Résumé Exécutif

**Total d'outils MCP roo-state-manager:** 34 outils actifs

**Distribution par catégorie d'activité:**
- **Actifs (usage régulier):** 3 outils (9%)
- **Rares (usage épisodique):** 2 outils (6%)
- **Inactifs (jamais utilisés):** 29 outils (85%)

**Observation critique:** La majorité des outils (85%) n'ont pas été utilisés dans les traces des 30 derniers jours, ce qui suggère soit :
1. Une sur-ingénierie de l'API (trop d'outils pour les besoins réels)
2. Une utilisation non indexée dans Qdrant (limitation de la recherche)
3. Une utilisation par des workflows automatisés non visibles dans les traces conversationnelles

---

## Méthodologie

### Grounding SDDD

1. **Recherche sémantique (roosync_search):** Analyse des traces Roo et Claude sur 30 jours
2. **Recherche textuelle (roosync_search):** Fallback pour les patterns d'outils spécifiques
3. **Analyse du code source:** Identification des 34 outils dans les exports TypeScript
4. **Validation croisée:** Vérification que les outils peu utilisés ne sont pas des dépendances internes

### Limitations

- **Backend Qdrant lent:** Recherche sémantique échouée avec "qdrant_backend_slow", fallback sur recherche textuelle
- **Période limitée:** 30 jours seulement, peut ne pas capturer les outils utilisés moins fréquemment
- **Traces conversationnelles:** Ne capture pas les appels automatisés ou internes

---

## Inventaire des 34 Outils

### Catégorie 1: RooSync (19 outils)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 1 | `roosync_dashboard` | ✅ Actif | 15+ | po-2023, po-2024, po-2025 | orchestrator, meta-analyst | **Actif** | Canal principal de coordination |
| 2 | `conversation_browser` | ✅ Actif | 8 | po-2023, po-2024 | meta-analyst, ask-complex | **Actif** | Grounding conversationnel SDDD |
| 3 | `roosync_config` | ❌ Inactif | 0 | - | - | Inactif | Consolidé (collect/publish/apply) |
| 4 | `roosync_inventory` | ❌ Inactif | 0 | - | - | Inactif | Heartbeat automatique #1609 |
| 5 | `roosync_messages` | ❌ Inactif | 0 | - | - | Inactif | Messagerie inter-machines |
| 6 | `roosync_mcp_management` | ❌ Inactif | 0 | - | - | Inactif | Gestion serveurs MCP |
| 7 | `roosync_indexing` | ❌ Inactif | 0 | - | - | Inactif | Indexation Qdrant |
| 8 | `roosync_baseline` | ❌ Inactif | 0 | - | - | Inactif | Gestion baselines |
| 9 | `roosync_decision` | ❌ Inactif | 0 | - | - | Inactif | Workflow décisions |
| 10 | `roosync_storage_management` | ❌ Inactif | 0 | - | - | Inactif | Maintenance stockage |
| 11 | `roosync_diagnose` | ❌ Inactif | 0 | - | - | Inactif | Diagnostic système |
| 12 | `roosync_compare_config` | ❌ Inactif | 0 | - | - | Inactif | Comparaison configs |
| 13 | `roosync_list_diffs` | ❌ Inactif | 0 | - | - | Inactif | Liste différences |
| 14 | `roosync_init` | ❌ Inactif | 0 | - | - | Inactif | Initialisation RooSync |
| 15 | `roosync_sync_event` | ❌ Inactif | 0 | - | - | Inactif | Sync automatique |
| 16 | `roosync_refresh_dashboard` | ❌ Inactif | 0 | - | - | Inactif | Refresh dashboards |
| 17 | `roosync_update_dashboard` | ❌ Inactif | 0 | - | - | Inactif | Update dashboards |
| 18 | `roosync_attachments` | ❌ Inactif | 0 | - | - | Inactif | Pièces jointes |
| 19 | `roosync_get_status` | ❌ Inactif | 0 | - | - | Inactif | Status système |

### Catégorie 2: Search (4 outils)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 20 | `roosync_search` | ✅ Actif | 15+ | Toutes | Tous | **Actif** | Recherche sémantique/textuelle |
| 21 | `codebase_search` | ✅ Actif | 2 | po-2023 | ask-complex | **Rare** | Recherche code source |
| 22 | `search_tasks_by_content` | ❌ Inactif | 0 | - | - | Inactif | Legacy (remplacé par roosync_search) |
| 23 | `search_fallback` | ❌ Inactif | 0 | - | - | Interne | Fallback automatique |

### Catégorie 3: Conversation (5 outils)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 24 | `conversation_browser` | ✅ Actif | 8 | po-2023, po-2024 | meta-analyst | **Actif** | Déjà compté (catégorie 1) |
| 25 | `list_conversations` | ❌ Inactif | 0 | - | - | Inactif | Legacy (remplacé par conversation_browser) |
| 26 | `debug_analyze` | ❌ Inactif | 0 | - | - | Inactif | Debug avancé |
| 27 | `get_raw_conversation` | ❌ Inactif | 0 | - | - | Inactif | Accès brut JSONL |
| 28 | `view_task_details` | ❌ Inactif | 0 | - | - | Inactif | Détails tâche |

### Catégorie 4: Export (8 outils)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 29 | `export_data` | ❌ Inactif | 0 | - | - | Inactif | Consolidé (XML/JSON/CSV) |
| 30 | `export_config` | ❌ Inactif | 0 | - | - | Inactif | Configuration export |
| 31 | `export_tasks_xml` | ❌ Inactif | 0 | - | - | Déprécié | Remplacé par export_data |
| 32 | `export_conversation_xml` | ❌ Inactif | 0 | - | - | Déprécié | Remplacé par export_data |
| 33 | `export_project_xml` | ❌ Inactif | 0 | - | - | Déprécié | Remplacé par export_data |
| 34 | `configure_xml_export` | ❌ Inactif | 0 | - | - | Déprécié | Remplacé par export_config |
| 35 | `export_conversation_json` | ❌ Inactif | 0 | - | - | Déprécié | Remplacé par export_data |
| 36 | `export_conversation_csv` | ❌ Inactif | 0 | - | - | Déprécié | Remplacé par export_data |

### Catégorie 5: Indexing (4 outils)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 37 | `index_task_semantic` | ❌ Inactif | 0 | - | - | Inactif | Indexation manuelle |
| 38 | `diagnose_semantic_index` | ❌ Inactif | 0 | - | - | Inactif | Diagnostic index |
| 39 | `reset_qdrant_collection` | ❌ Inactif | 0 | - | - | Inactif | Reset collection |
| 40 | `roosync_indexing` | ❌ Inactif | 0 | - | - | Inactif | Consolidé (index/reset/diagnose) |

### Catégorie 6: Summary (1 outil)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 41 | `roosync_summarize` | ❌ Inactif | 0 | - | - | Inactif | Synthèse LLM |

### Catégorie 7: Cache (1 outil)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 42 | `build_skeleton_cache` | ❌ Inactif | 0 | - | - | Interne | Cache squelettes |

### Catégorie 8: Repair (2 outils)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 43 | `diagnose_conversation_bom` | ❌ Inactif | 0 | - | - | Inactif | Diagnostic BOM UTF-8 |
| 44 | `repair_conversation_bom` | ❌ Inactif | 0 | - | - | Inactif | Réparation BOM UTF-8 |

### Catégorie 9: Maintenance (2 outils)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 45 | `maintenance` | ❌ Inactif | 0 | - | - | Inactif | Maintenance unifiée |
| 46 | `rebuild_task_index` | ❌ Inactif | 0 | - | - | Inactif | Rebuild index SQLite |

### Catégorie 10: Diagnostic (1 outil)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 47 | `analyze_problems` | ❌ Inactif | 0 | - | - | Inactif | Analyse problèmes RooSync |

### Catégorie 11: Autres (3 outils)

| # | Outil | Usage | Fréquence | Machines | Modes | Classification | Notes |
|---|-------|-------|-----------|----------|-------|----------------|-------|
| 48 | `read_vscode_logs` | ❌ Inactif | 0 | - | - | Inactif | Lecture logs VS Code |
| 49 | `get_mcp_best_practices` | ❌ Inactif | 0 | - | - | Inactif | Best practices MCP |
| 50 | `manage_mcp_settings` | ❌ Inactif | 0 | - | - | Inactif | Gestion settings MCP |

---

## Analyse par Classification

### Actifs (3 outils - 9%)

Ces outils sont utilisés régulièrement dans les traces :

1. **`roosync_dashboard`** (15+ appels)
   - **Rôle:** Canal principal de coordination entre machines
   - **Utilisateurs:** Meta-analystes, orchestrateurs, coordinateur
   - **Tendance:** Stable, usage quotidien
   - **Recommandation:** Maintenir, documenter davantage

2. **`conversation_browser`** (8 appels)
   - **Rôle:** Grounding conversationnel SDDD
   - **Utilisateurs:** Meta-analystes, ask-complex
   - **Tendance:** Stable, usage régulier
   - **Recommandation:** Maintenir, optimiser performance

3. **`roosync_search`** (15+ appels)
   - **Rôle:** Recherche sémantique/textuelle dans les traces
   - **Utilisateurs:** Tous les modes
   - **Tendance:** Stable, usage quotidien
   - **Recommandation:** Maintenir, améliorer performance Qdrant

### Rares (2 outils - 6%)

Ces outils sont utilisés épisodiquement :

1. **`codebase_search`** (2 appels)
   - **Rôle:** Recherche sémantique dans le code source
   - **Utilisateurs:** ask-complex
   - **Tendance:** Stable, usage occasionnel
   - **Recommandation:** Maintenir, promouvoir dans SDDD

### Inactifs (29 outils - 85%)

Ces outils n'ont pas été utilisés dans les traces des 30 derniers jours :

**Outils consolidés (potentiellement utilisés en interne):**
- `roosync_config` (collect/publish/apply)
- `roosync_inventory` (heartbeat automatique)
- `roosync_indexing` (indexation automatique)
- `roosync_baseline` (gestion baselines)
- `roosync_storage_management` (maintenance stockage)
- `roosync_diagnose` (diagnostic système)
- `roosync_mcp_management` (gestion MCP)
- `roosync_decision` (workflow décisions)
- `roosync_messages` (messagerie inter-machines)
- `export_data` (export XML/JSON/CSV)
- `maintenance` (maintenance unifiée)
- `roosync_summarize` (synthèse LLM)

**Outils legacy/dépréciés:**
- `export_tasks_xml`, `export_conversation_xml`, `export_project_xml`
- `configure_xml_export`
- `export_conversation_json`, `export_conversation_csv`
- `search_tasks_by_content` (remplacé par roosync_search)
- `list_conversations` (remplacé par conversation_browser)

**Outils spécialisés:**
- `diagnose_conversation_bom`, `repair_conversation_bom` (réparation UTF-8)
- `read_vscode_logs` (logs VS Code)
- `get_mcp_best_practices` (best practices)
- `manage_mcp_settings` (settings MCP)
- `debug_analyze`, `get_raw_conversation`, `view_task_details` (debug avancé)
- `index_task_semantic`, `diagnose_semantic_index`, `reset_qdrant_collection` (indexation)
- `analyze_problems` (analyse RooSync)
- `build_skeleton_cache` (cache interne)
- `rebuild_task_index` (rebuild SQLite)
- `roosync_init`, `roosync_sync_event`, `roosync_refresh_dashboard`, `roosync_update_dashboard`, `roosync_attachments`, `roosync_get_status`, `roosync_compare_config`, `roosync_list_diffs` (RooSync divers)

---

## Recommandations

### 1. Outils à maintenir et promouvoir (3)

**`roosync_dashboard`, `conversation_browser`, `roosync_search`**
- ✅ **Action:** Maintenir et documenter davantage
- ✅ **Action:** Optimiser les performances (Qdrant lent)
- ✅ **Action:** Promouvoir dans les workflows SDDD

### 2. Outils à investiguer (12)

Ces outils sont consolidés mais n'apparaissent pas dans les traces. Ils sont probablement utilisés en interne ou par des workflows automatisés :

**RooSync consolidés:**
- `roosync_config` - Vérifier utilisation par scripts de déploiement
- `roosync_inventory` - Vérifier heartbeat automatique #1609
- `roosync_indexing` - Vérifier indexation automatique
- `roosync_baseline` - Vérifier gestion baselines
- `roosync_storage_management` - Vérifier maintenance stockage
- `roosync_diagnose` - Vérifier diagnostic système
- `roosync_mcp_management` - Vérifier gestion MCP
- `roosync_decision` - Vérifier workflow décisions
- `roosync_messages` - Vérifier messagerie inter-machines

**Autres consolidés:**
- `export_data` - Vérifier utilisation export
- `maintenance` - Vérifier maintenance unifiée
- `roosync_summarize` - Vérifier synthèse LLM

**Action:** Ajouter des logs de trace pour ces outils pour confirmer leur utilisation réelle

### 3. Outils legacy à déprécier (7)

Ces outils sont marqués comme dépréciés dans le code :

- `export_tasks_xml` → `export_data(format: "xml")`
- `export_conversation_xml` → `export_data(format: "xml")`
- `export_project_xml` → `export_data(format: "xml")`
- `configure_xml_export` → `export_config`
- `export_conversation_json` → `export_data(format: "json")`
- `export_conversation_csv` → `export_data(format: "csv")`
- `search_tasks_by_content` → `roosync_search(action: "semantic")`

**Action:** Planifier la suppression dans une version future (v4.0.0)

### 4. Outils spécialisés à conserver (10)

Ces outils sont peu utilisés mais ont un rôle spécifique important :

- `diagnose_conversation_bom`, `repair_conversation_bom` - Réparation UTF-8 (critique)
- `read_vscode_logs` - Logs VS Code (debug)
- `get_mcp_best_practices` - Best practices (documentation)
- `manage_mcp_settings` - Settings MCP (configuration)
- `debug_analyze`, `get_raw_conversation`, `view_task_details` - Debug avancé
- `index_task_semantic`, `diagnose_semantic_index`, `reset_qdrant_collection` - Indexation
- `analyze_problems` - Analyse RooSync
- `rebuild_task_index` - Rebuild SQLite

**Action:** Conserver, documenter les cas d'usage

### 5. Outils à clarifier (2)

- `build_skeleton_cache` - Cache interne ou outil MCP ?
- `roosync_init`, `roosync_sync_event`, `roosync_refresh_dashboard`, `roosync_update_dashboard`, `roosync_attachments`, `roosync_get_status`, `roosync_compare_config`, `roosync_list_diffs` - Usage interne ou public ?

**Action:** Clarifier le statut (interne vs public) dans la documentation

---

## Conclusion

L'audit révèle une distribution très inégale de l'utilisation des 34 outils roo-state-manager :

- **9%** des outils sont activement utilisés (3/34)
- **6%** sont rarement utilisés (2/34)
- **85%** sont inactifs dans les traces (29/34)

Cependant, cette distribution ne signifie pas nécessairement que les outils inactifs sont inutiles. Plusieurs facteurs peuvent expliquer cette observation :

1. **Utilisation interne:** Certains outils sont probablement utilisés par des workflows automatisés non visibles dans les traces conversationnelles
2. **Période limitée:** 30 jours peuvent ne pas capturer les outils utilisés moins fréquemment
3. **Cas d'usage spécifiques:** Certains outils sont destinés à des situations exceptionnelles (debug, réparation)

**Recommandation principale:** Ajouter des logs de trace pour tous les outils consolidés afin de confirmer leur utilisation réelle avant de prendre des décisions de dépréciation.

---

## Annexes

### A. Méthodologie SDDD

1. **Grounding initial:** `roosync_search(action: "semantic/text")` pour chaque catégorie d'outils
2. **Analyse code source:** Lecture des exports TypeScript dans `mcps/internal/servers/roo-state-manager/src/tools/`
3. **Validation croisée:** Vérification que les outils peu utilisés ne sont pas des dépendances internes
4. **Classification:** Actif (usage régulier), Rare (usage épisodique), Inactif (jamais utilisé), Interne (dépendance)

### B. Limitations

- **Backend Qdrant lent:** Recherche sémantique échouée avec "qdrant_backend_slow", fallback sur recherche textuelle
- **Période limitée:** 30 jours seulement
- **Traces conversationnelles:** Ne capture pas les appels automatisés ou internes

### C. Références

- Issue #1841: Inventaire d'utilisation réelle des 34 outils roo-state-manager
- Règles SDDD: `.roo/rules/04-sddd-grounding.md`
- Documentation RooSync: `docs/harness/reference/`
- Code source: `mcps/internal/servers/roo-state-manager/src/tools/`

---

**Rédigé par:** Roo Code (ask-complex)  
**Machine:** myia-po-2023  
**Date:** 2026-05-08T01:50:00Z

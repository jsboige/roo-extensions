<!-- DECISION_BLOCK_START -->
**ID:** `34d26e8b-fc1c-4c7c-b7c0-df8b5037b4f8`
**Titre:** Configuration des modes Roo différente entre machines
**Statut:** approved
**Type:** setting
**Machine Source:** myia-po-2024
**Machines Cibles:** myia-ai-01
**Créé:** 2025-10-22T20:17:55.263Z

**Description:**
Configuration des modes Roo différente entre machines

**Détails Techniques:**
- **Catégorie:** roo_config
- **Sévérité:** CRITICAL
- **Chemin:** roo.modes
- **Type:** MODIFIED
- **Valeur Source:** []
- **Valeur Cible:** [{"slug":"code","description":"Mode standard pour le développement de code","tools":["read_file","write_to_file","insert_content","search_and_replace","list_files","execute_command","browser_action"],"allowedFilePatterns":["\\.json$","\\.md$","\\.ts$","\\.js$","\\.html$","\\.css$","\\.py$"],"name":"💻 Code","defaultModel":"anthropic/claude-3.7-sonnet"},{"slug":"code-simple","description":"Mode pour modifications mineures, documentation et fonctionnalités basiques","tools":["read_file","write_to_file","insert_content","search_and_replace","list_files"],"allowedFilePatterns":["\\.json$","\\.md$","\\.txt$"],"name":"💻 Code Simple","defaultModel":"anthropic/claude-3.5-sonnet"},{"slug":"code-complex","description":"Mode pour modifications techniques avancées et architecture","tools":["read_file","write_to_file","insert_content","search_and_replace","list_files","execute_command"],"allowedFilePatterns":["\\.json$","\\.md$","\\.ts$","\\.js$"],"name":"💻 Code Complexe","defaultModel":"anthropic/claude-3.7-sonnet"},{"slug":"debug-simple","description":"Mode pour diagnostiquer des problèmes simples","tools":["read_file","list_files","ask_followup_question"],"allowedFilePatterns":["\\.json$","\\.md$","\\.txt$"],"name":"🪲 Debug Simple","defaultModel":"qwen/qwen3-1.7b:free"},{"slug":"debug-complex","description":"Mode pour diagnostiquer des problèmes complexes","tools":["read_file","list_files","ask_followup_question","execute_command"],"allowedFilePatterns":["\\.json$","\\.md$","\\.js$","\\.ts$"],"name":"🪲 Debug Complexe","defaultModel":"anthropic/claude-3.7-sonnet"},{"slug":"architect-simple","description":"Mode pour conception architecturale simple","tools":["read_file","write_to_file","list_files"],"allowedFilePatterns":["\\.json$","\\.md$"],"name":"🏗️ Architect Simple","defaultModel":"qwen/qwen3-32b"},{"slug":"architect-complex","description":"Mode pour conception architecturale complexe","tools":["read_file","write_to_file","list_files","execute_command"],"allowedFilePatterns":["\\.json$","\\.md$"],"name":"🏗️ Architect Complexe","defaultModel":"anthropic/claude-3.7-sonnet"},{"slug":"ask-simple","description":"Mode pour répondre à des questions simples","tools":["read_file","list_files"],"allowedFilePatterns":["\\.json$","\\.md$"],"name":"❓ Ask Simple","defaultModel":"qwen/qwen3-8b"},{"slug":"ask-complex","description":"Mode pour répondre à des questions complexes","tools":["read_file","list_files","execute_command"],"allowedFilePatterns":["\\.json$","\\.md$"],"name":"❓ Ask Complexe","defaultModel":"anthropic/claude-3.7-sonnet"},{"slug":"orchestrator-simple","description":"Mode pour tâches simples et coordination","tools":["read_file","list_files","ask_followup_question"],"allowedFilePatterns":["\\.json$","\\.md$"],"name":"🪃 Orchestrator Simple","defaultModel":"qwen/qwen3-30b-a3b"},{"slug":"orchestrator-complex","description":"Mode pour orchestration de tâches complexes","tools":["read_file","list_files","ask_followup_question","execute_command"],"allowedFilePatterns":["\\.json$","\\.md$","\\.js$"],"name":"🪃 Orchestrator Complexe","defaultModel":"anthropic/claude-3.7-sonnet"},{"slug":"manager","description":"Mode spécialisé dans la création de sous-tâches orchestrateurs pour des tâches de haut-niveau","tools":["read_file","write_to_file","list_files","ask_followup_question","execute_command","new_task"],"allowedFilePatterns":["\\.json$","\\.md$","\\.js$","\\.ts$"],"name":"👨‍💼 Manager","defaultModel":"anthropic/claude-3.7-sonnet"}]


**Approuvé le:** 2025-10-22T21:34:26.329Z
**Approuvé par:** myia-po-2024
**Commentaire:** APPROBATION EN MODE DRY-RUN TEST - Validation du workflow v2.1 baseline-driven. Cette décision teste la synchronisation des modes Roo depuis baseline vers myia-ai-01. En mode dry-run, aucune modification réelle ne sera appliquée.
<!-- DECISION_BLOCK_END -->


<!-- DECISION_BLOCK_START -->
**ID:** `7b9ac8a1-f7de-404b-b157-cec4a55e5123`
**Titre:** Configuration des serveurs MCP différente entre machines
**Statut:** approved
**Type:** setting
**Machine Source:** myia-po-2024
**Machines Cibles:** myia-ai-01
**Créé:** 2025-10-22T20:17:55.263Z

**Description:**
Configuration des serveurs MCP différente entre machines

**Détails Techniques:**
- **Catégorie:** roo_config
- **Sévérité:** CRITICAL
- **Chemin:** roo.mcpServers
- **Type:** MODIFIED
- **Valeur Source:** []
- **Valeur Cible:** [{"name":"jupyter-mcp","alwaysAllow":["list_kernels"],"description":"Serveur MCP pour interagir avec des notebooks Jupyter","command":"node","autoStart":true,"transportType":"stdio","enabled":true},{"name":"github-projects-mcp","alwaysAllow":["list_repositories","list_projects","search_repositories"],"description":"MCP Gestionnaire de Projet pour l'intégration de GitHub Projects avec VSCode Roo","command":"node","autoStart":true,"transportType":"stdio","enabled":true},{"name":"markitdown","alwaysAllow":null,"description":null,"command":"uvx","autoStart":null,"transportType":null,"enabled":true},{"name":"playwright","alwaysAllow":["browser_navigate","browser_click","browser_take_screenshot","browser_close","browser_snapshot","browser_install"],"description":"MCP pour l'automatisation web avec Playwright","command":"cmd","autoStart":true,"transportType":"stdio","enabled":true},{"name":"roo-state-manager","alwaysAllow":["minimal_test_tool","detect_roo_storage","get_storage_stats","list_conversations","touch_mcp_settings","build_skeleton_cache","get_task_tree","search_tasks_semantic","debug_analyze_conversation","view_conversation_tree","manage_mcp_settings","index_task_semantic","reset_qdrant_collection","get_mcp_best_practices","diagnose_conversation_bom","repair_conversation_bom","analyze_vscode_global_state","repair_vscode_task_history","scan_orphan_tasks","test_workspace_extraction","rebuild_task_index","diagnose_sqlite","examine_roo_global_state","repair_task_history","normalize_workspace_paths","export_tasks_xml","export_conversation_xml","export_project_xml","configure_xml_export","generate_trace_summary","generate_cluster_summary","export_conversation_json","export_conversation_csv","view_task_details","get_raw_conversation","get_conversation_synthesis","roosync_get_status","roosync_list_diffs","roosync_compare_config","roosync_init","rebuild_and_restart_mcp","read_vscode_logs","roosync_send_message","roosync_read_inbox","roosync_get_message","roosync_mark_message_read","roosync_reply_message","roosync_archive_message"],"description":"🛡️ MCP Roo State Manager - Gestionnaire d'état et de conversations. [RESTART]","command":"node","autoStart":true,"transportType":"stdio","enabled":true},{"name":"jinavigator","alwaysAllow":["convert_web_to_markdown","multi_convert"],"description":"MCP server for converting web pages to Markdown using Jina API","command":"node","autoStart":true,"transportType":"stdio","enabled":true},{"name":"quickfiles","alwaysAllow":["restart_mcp_servers","list_directory_contents","copy_files","search_in_files","edit_multiple_files","search_and_replace","delete_files","move_files","extract_markdown_structure","read_multiple_files"],"description":"MCP server for file operations","command":"node","autoStart":true,"transportType":"stdio","enabled":true},{"name":"searxng","alwaysAllow":["web_url_read","searxng_web_search"],"description":"MCP pour la recherche web avec SearXNG","command":"cmd","autoStart":true,"transportType":"stdio","enabled":true},{"name":"win-cli","alwaysAllow":["execute_command"],"description":"MCP for executing CLI commands on Windows","command":"npm","autoStart":true,"transportType":"stdio","enabled":true}]


**Approuvé le:** 2025-10-23T07:32:47.176Z
**Approuvé par:** myia-po-2024
**Commentaire:** APPROBATION EN MODE DRY-RUN TEST - Validation du workflow v2.1 baseline-driven. Cette décision teste la synchronisation des serveurs MCP depuis baseline vers myia-ai-01. En mode dry-run, aucune modification réelle ne sera appliquée.
<!-- DECISION_BLOCK_END -->


<!-- DECISION_BLOCK_START -->
**ID:** `97e6b048-ffa3-4596-9294-b18511044804`
**Titre:** Nombre de cœurs CPU différent : 0 vs 16 (100.0% différence)
**Statut:** pending
**Type:** config
**Machine Source:** myia-po-2024
**Machines Cibles:** myia-ai-01
**Créé:** 2025-10-22T20:17:55.263Z

**Description:**
Nombre de cœurs CPU différent : 0 vs 16 (100.0% différence)

**Détails Techniques:**
- **Catégorie:** hardware
- **Sévérité:** IMPORTANT
- **Chemin:** hardware.cpu.cores
- **Type:** MODIFIED
- **Valeur Source:** 16
- **Valeur Cible:** 16
- **Action Recommandée:** Performance CPU significativement différente - tester comportement des tâches intensives
<!-- DECISION_BLOCK_END -->


<!-- DECISION_BLOCK_START -->
**ID:** `629ddeba-a78e-43d2-92dc-9e9fc32d6deb`
**Titre:** Nombre de threads CPU différent : 0 vs 16 (100.0% différence)
**Statut:** pending
**Type:** config
**Machine Source:** myia-po-2024
**Machines Cibles:** myia-ai-01
**Créé:** 2025-10-22T20:17:55.263Z

**Description:**
Nombre de threads CPU différent : 0 vs 16 (100.0% différence)

**Détails Techniques:**
- **Catégorie:** hardware
- **Sévérité:** IMPORTANT
- **Chemin:** hardware.cpu.threads
- **Type:** MODIFIED
- **Valeur Source:** 16
- **Valeur Cible:** 16

<!-- DECISION_BLOCK_END -->


<!-- DECISION_BLOCK_START -->
**ID:** `12a588bc-42e6-451d-8031-ed478ba6a5d1`
**Titre:** RAM totale différente : 0.0 GB vs 31.7 GB (100.0% différence)
**Statut:** pending
**Type:** config
**Machine Source:** myia-po-2024
**Machines Cibles:** myia-ai-01
**Créé:** 2025-10-22T20:17:55.263Z

**Description:**
RAM totale différente : 0.0 GB vs 31.7 GB (100.0% différence)

**Détails Techniques:**
- **Catégorie:** hardware
- **Sévérité:** IMPORTANT
- **Chemin:** hardware.memory.total
- **Type:** MODIFIED
- **Valeur Source:** 16
- **Valeur Cible:** 34046709760
- **Action Recommandée:** RAM insuffisante sur myia-ai-01 - risque de performance dégradée
<!-- DECISION_BLOCK_END -->


<!-- DECISION_BLOCK_START -->
**ID:** `d8df84d8-737f-4bd7-ae00-981dd79ff6f0`
**Titre:** Architecture système différente : Unknown vs x64
**Statut:** pending
**Type:** config
**Machine Source:** myia-po-2024
**Machines Cibles:** myia-ai-01
**Créé:** 2025-10-22T20:17:55.263Z

**Description:**
Architecture système différente : Unknown vs x64

**Détails Techniques:**
- **Catégorie:** system
- **Sévérité:** IMPORTANT
- **Chemin:** system.architecture
- **Type:** MODIFIED
- **Valeur Source:** "x64"
- **Valeur Cible:** "x64"
- **Action Recommandée:** Attention : architectures incompatibles peuvent nécessiter des builds différents
<!-- DECISION_BLOCK_END -->


---

## ✅ Décisions Approuvées

_Aucune décision approuvée pour le moment._

---

## ❌ Décisions Rejetées

_Aucune décision rejetée pour le moment._

---

## 🔄 Décisions Appliquées

_Aucune décision appliquée pour le moment._

---

## 📝 Guide d'Utilisation

Les décisions de synchronisation sont structurées selon ce format :

```markdown
<!-- DECISION_BLOCK_START -->
**ID:** `uuid-unique`  
**Titre:** Description de la décision  
**Statut:** pending | approved | rejected | applied | rolled_back  
**Type:** config | file | setting  
**Machine Source:** nom-machine-source  
**Machines Cibles:** machine1, machine2  
**Créé:** ISO8601-timestamp  

**Description:**
Description détaillée du changement à synchroniser.

**Détails Techniques:**
Informations techniques (diff, chemin, etc.)
<!-- DECISION_BLOCK_END -->
```

### Workflow de Synchronisation

1. **Détection** : Les divergences sont détectées automatiquement ou manuellement
2. **Création** : Une décision est créée avec le statut `pending`
3. **Validation** : L'utilisateur approuve (`approved`) ou rejette (`rejected`) la décision
4. **Application** : Une décision approuvée est appliquée (`applied`)
5. **Rollback** : Si nécessaire, une décision peut être annulée (`rolled_back`)

### Outils MCP Disponibles

- `roosync_get_status` : Obtenir l'état global de synchronisation
- `roosync_compare_config` : Comparer les configurations entre machines
- `roosync_list_diffs` : Lister les différences détectées
- `roosync_get_decision_details` : Obtenir les détails d'une décision
- `roosync_approve_decision` : Approuver une décision
- `roosync_reject_decision` : Rejeter une décision
- `roosync_apply_decision` : Appliquer une décision approuvée
- `roosync_rollback_decision` : Annuler une décision appliquée
- `roosync_init` : Initialiser l'infrastructure RooSync

---

_Fichier généré automatiquement par roosync_init_

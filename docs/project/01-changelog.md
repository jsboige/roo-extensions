# CHANGELOG

Toutes les modifications notables de ce projet seront documentées dans ce fichier selon les standards [Keep a Changelog](https://keepachangelog.com/) et [SDDD](https://github.com/jsboige/roo-extensions/docs/).

## [v3.19.0] - 2025-09-15 🚀 **ÉVOLUTIONS ARCHITECTURALES MAJEURES**

### ✨ Added
- **jupyter-papermill-mcp-server** : Refonte Python complète avec API directe Papermill
- **roo-state-manager** : Architecture deux-niveaux avec services background asynchrones
- **Export Capacities** : Nouveaux formats CSV/JSON pour conversations Roo
- **Background Services** : Queue d'indexation Qdrant + services de nettoyage intelligent
- **Documentation SDDD** : Guides configuration Python complets (CONDA_ENVIRONMENT_SETUP.md)
- **Test Infrastructure** : Suites de tests E2E complètes pour jupyter-papermill

### 🔧 Changed
- **jupyter-papermill** : Architecture Node.js subprocess → Python API directe
- **roo-state-manager** : Monolithique → Architecture 2-niveaux avec qdrantIndexQueue
- **Performance** : Élimination timeouts 60s+ dans exécution notebooks Jupyter
- **Services Core** : +5 nouveaux services (Enhanced, Markdown, SmartCleaner, XmlParsing)

### 🐛 Fixed
- **Timeouts Jupyter** : Résolution complète timeouts via API directe (vs subprocess)
- **reset_qdrant_collection** : Tool critique réactivé pour maintenance indexation
- **Architecture Scalabilité** : Services background pour traitement asynchrone

### 🗑️ Removed
- **jupyter-papermill** : 7 anciennes implémentations main_*.py (nettoyage architectural)
- **Subprocess Calls** : Élimination complète appels subprocess conda run

### 🔒 Security
- **API Keys** : Suppression hardcoded tokens et clés API du code source

### 📚 Documentation
- **Mission Reports** : Rapport SDDD exhaustif synchronisation Git (48+ modifications)
- **Architecture Guides** : Documentation architecture 2-niveaux roo-state-manager
- **Migration Guides** : Guides migration Python pour jupyter-papermill

### ⚠️ Breaking Changes
- **jupyter-papermill-mcp-server** : APIs subprocess supprimées, migration vers API Python requise
- **roo-state-manager** : Nouveaux services background nécessitent configuration mise à jour

---

## [v3.18.1] - 27/05/2025

### 🐛 Fixed
- Correction de l'incohérence dans les règles de désescalade des modes complexes
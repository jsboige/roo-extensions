# INDEX CENTRALISÉ DE LA DOCUMENTATION

**Dernière mise à jour:** 2026-01-13  
**Version:** 3.0 (Index Organisé SDDD)  
**Responsable:** myia-po-2023 (Tâche T2.19 - RooSync v7.0)

---

## 📋 Table des Matières

- [Documentation RooSync](#documentation-roosync)
- [Guides Utilisateur](#guides-utilisateur)
- [Documentation Technique](#documentation-technique)
- [Suivi de Projet](#suivi-de-projet)
- [Documentation MCP](#documentation-mcp)
- [Documentation Roo Code](#documentation-roo-code)
- [Rapports et Analyses](#rapports-et-analyses)
- [Tests et Validation](#tests-et-validation)
- [Maintenance et Dépannage](#maintenance-et-depannage)
- [Archives et Historique](#archives-et-historique)

---

## 🔄 Documentation RooSync

### Guides Principaux
- [`README.md`](roosync/README.md) - Documentation principale RooSync
- [`GUIDE_UTILISATION_ROOSYNC.md`](roosync/GUIDE_UTILISATION_ROOSYNC.md) - Guide d'utilisation complet
- [`ARCHITECTURE_ROOSYNC.md`](roosync/ARCHITECTURE_ROOSYNC.md) - Architecture technique
- [`GESTION_MULTI_AGENT.md`](roosync/GESTION_MULTI_AGENT.md) - Gestion multi-agent

### Guides Techniques
- [`GUIDE-TECHNIQUE-v2.1.md`](roosync/GUIDE-TECHNIQUE-v2.1.md) - Guide technique v2.1
- [`GUIDE-TECHNIQUE-v2.3.md`](roosync/GUIDE-TECHNIQUE-v2.3.md) - Guide technique v2.3
- [`GUIDE-DEVELOPPEUR-v2.1.md`](roosync/GUIDE-DEVELOPPEUR-v2.1.md) - Guide développeur
- [`GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`](roosync/GUIDE-OPERATIONNEL-UNIFIE-v2.1.md) - Guide opérationnel

### Changelogs et Versions
- [`CHANGELOG-v2.2.md`](roosync/CHANGELOG-v2.2.md) - Changelog v2.2
- [`CHANGELOG-v2.3.md`](roosync/CHANGELOG-v2.3.md) - Changelog v2.3
- [`TRANSITIONS_VERSIONS_V2.1_V2.2_V2.3.md`](roosync/TRANSITIONS_VERSIONS_V2.1_V2.2_V2.3.md) - Transitions de versions
- [`TRANSITIONS_VERSIONS.md`](roosync/TRANSITIONS_VERSIONS.md) - Documentation des transitions

### Migration
- [`PLAN_MIGRATION_V2.1_V2.3.md`](roosync/PLAN_MIGRATION_V2.1_V2.3.md) - Plan de migration v2.1 → v2.3

### Méthodologie
- [`PROTOCOLE_SDDD.md`](roosync/PROTOCOLE_SDDD.md) - Protocole SDDD

---

## 📚 Guides Utilisateur

### Démarrage et Installation
- [`01-getting-started.md`](guides/01-getting-started.md) - Guide de démarrage
- [`installation-complete.md`](guides/installation-complete.md) - Installation complète
- [`ENVIRONMENT-SETUP-SYNTHESIS.md`](guides/ENVIRONMENT-SETUP-SYNTHESIS.md) - Configuration d'environnement

### Configuration et Déploiement
- [`guide-deploiement-configurations-roo.md`](guides/guide-deploiement-configurations-roo.md) - Déploiement des configurations
- [`guide-maintenance-configuration-roo.md`](guides/guide-maintenance-configuration-roo.md) - Maintenance des configurations
- [`documentation-structure-configuration-roo.md`](guides/documentation-structure-configuration-roo.md) - Structure de configuration

### Modes et Profils
- [`guide-complet-modes-roo.md`](guides/guide-complet-modes-roo.md) - Guide complet des modes
- [`guide-utilisation-profils-modes.md`](guides/guide-utilisation-profils-modes.md) - Utilisation des profils
- [`README-profile-modes.md`](guides/README-profile-modes.md) - Documentation des profils

### Encodage et Fichiers
- [`guide-encodage.md`](guides/guide-encodage.md) - Guide d'encodage
- [`guide-encodage-windows.md`](guides/guide-encodage-windows.md) - Encodage Windows
- [`RESOLUTION-ENCODAGE-UTF8.md`](guides/RESOLUTION-ENCODAGE-UTF8.md) - Résolution UTF-8

### Dépannage
- [`TROUBLESHOOTING-GUIDE.md`](guides/TROUBLESHOOTING-GUIDE.md) - Guide de dépannage
- [`MCPS-COMMON-ISSUES-GUIDE.md`](guides/MCPS-COMMON-ISSUES-GUIDE.md) - Problèmes MCP courants
- [`GUIDE-URGENCE-MCP.md`](guides/GUIDE-URGENCE-MCP.md) - Guide d'urgence MCP

### Autres Guides
- [`guide-escalade-desescalade.md`](guides/guide-escalade-desescalade.md) - Escalade et désescalade
- [`guide-synchronisation-submodules.md`](guides/guide-synchronisation-submodules.md) - Synchronisation des sous-modules
- [`procedures-maintenance.md`](guides/procedures-maintenance.md) - Procédures de maintenance
- [`consolidated-task-management-guide.md`](guides/consolidated-task-management-guide.md) - Gestion des tâches

---

## 🏗️ Documentation Technique

### Architecture Système
- [`01-main-architecture.md`](architecture/01-main-architecture.md) - Architecture principale
- [`architecture-orchestration-5-niveaux.md`](architecture/architecture-orchestration-5-niveaux.md) - Orchestration 5 niveaux
- [`ARCHITECTURE_GIT.md`](architecture/ARCHITECTURE_GIT.md) - Architecture Git
- [`repository-map.md`](architecture/repository-map.md) - Carte du dépôt

### Roo State Manager
- [`roo-state-manager-architecture.md`](architecture/roo-state-manager-architecture.md) - Architecture Roo State Manager
- [`roo-state-manager-parsing-refactoring.md`](architecture/roo-state-manager-parsing-refactoring.md) - Refactoring parsing

### RooSync
- [`roosync-real-diff-detection-design.md`](architecture/roosync-real-diff-detection-design.md) - Détection de différences
- [`roosync-real-methods-connection-design.md`](architecture/roosync-real-methods-connection-design.md) - Connexion des méthodes
- [`roosync-temporal-messages-architecture.md`](architecture/roosync-temporal-messages-architecture.md) - Messages temporels

### Autres
- [`message-to-skeleton-transformer.md`](architecture/message-to-skeleton-transformer.md) - Transformateur message→squelette
- [`conversation-discovery-architecture.md`](architecture/conversation-discovery-architecture.md) - Découverte de conversations
- [`specification-n-niveaux-complexite.md`](architecture/specification-n-niveaux-complexite.md) - Spécification complexité
- [`DATA_STORAGE_POLICY.md`](architecture/DATA_STORAGE_POLICY.md) - Politique de stockage

---

## 📊 Suivi de Projet

### RooSync Multi-Agent
- [`REPARTITION_TACHES_MULTI_AGENT.md`](suivi/RooSync/REPARTITION_TACHES_MULTI_AGENT.md) - Répartition des tâches
- [`SUIVI_ACTIF.md`](suivi/RooSync/SUIVI_ACTIF.md) - Suivi actif
- [`BUGS_TRACKING.md`](suivi/RooSync/BUGS_TRACKING.md) - Suivi des bugs
- [`RAPPORT_GOUVERNANCE_2026-01-13.md`](suivi/RooSync/RAPPORT_GOUVERNANCE_2026-01-13.md) - Rapport de gouvernance

### Rapports de Tâches
- [`TACHE_1_7_RAPPORT_CORRECTION_VULNERABILITES_NPM.md`](suivi/RooSync/TACHE_1_7_RAPPORT_CORRECTION_VULNERABILITES_NPM.md) - Correction vulnérabilités npm
- [`TACHE_1_11_RAPPORT_COLLECTE_INVENTAIRES.md`](suivi/RooSync/TACHE_1_11_RAPPORT_COLLECTE_INVENTAIRES.md) - Collecte d'inventaires
- [`TACHE_2_12_RAPPORT_RECOMPILATION_MCP.md`](suivi/RooSync/TACHE_2_12_RAPPORT_RECOMPILATION_MCP.md) - Recompilation MCP
- [`TACHE_2_18_PLANIFICATION_TRANSITIONS_VERSION.md`](suivi/RooSync/TACHE_2_18_PLANIFICATION_TRANSITIONS_VERSION.md) - Planification transitions
- [`TACHE_2_2_RAPPORT_MISE_A_JOUR_NODEJS.md`](suivi/RooSync/TACHE_2_2_RAPPORT_MISE_A_JOUR_NODEJS.md) - Mise à jour Node.js

### Phases RooSync
- [`PHASE1_DIAGNOSTIC_ET_STABILISATION.md`](suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md) - Phase 1
- [`PHASE2_CORRECTION_PROBLEMES_CRITIQUES.md`](suivi/RooSync/PHASE2_CORRECTION_PROBLEMES_CRITIQUES.md) - Phase 2

### Méthodologie SDDD
- [`METHODOLOGIE_SDDD_myia-po-2023.md`](suivi/RooSync/METHODOLOGIE_SDDD_myia-po-2023.md) - Méthodologie SDDD

### Autres Suivis
- [`INDEX.md`](suivi/RooSync/INDEX.md) - Index RooSync

---

## 🔌 Documentation MCP

### Installation et Configuration
- [`INSTALLATION.md`](../mcps/INSTALLATION.md) - Guide d'installation
- [`INDEX.md`](../mcps/INDEX.md) - Index MCP
- [`README.md`](../mcps/README.md) - Documentation principale
- [`GUIDE-DEMARRAGE-RAPIDE-MCP.md`](../mcps/GUIDE-DEMARRAGE-RAPIDE-MCP.md) - Démarrage rapide

### Guides d'Utilisation
- [`GUIDE-UTILISATION-MCP.md`](../mcps/GUIDE-UTILISATION-MCP.md) - Guide d'utilisation
- [`guide-configuration-securisee.md`](../mcps/guide-configuration-securisee.md) - Configuration sécurisée
- [`MCP-CONFIGURATION-SAFETY-GUIDE.md`](../mcps/MCP-CONFIGURATION-SAFETY-GUIDE.md) - Guide de sécurité

### Dépannage
- [`TROUBLESHOOTING.md`](../mcps/TROUBLESHOOTING.md) - Guide de dépannage
- [`mcp-troubleshooting.md`](mcp-troubleshooting.md) - Dépannage MCP

### Scripts et Outils
- [`gestion-securisee-mcp.ps1`](../mcps/gestion-securisee-mcp.ps1) - Script de gestion sécurisée
- [`mcp-manager.ps1`](../mcps/mcp-manager.ps1) - Gestionnaire MCP

### Documentation Guides
- [`MCPs-INSTALLATION-GUIDE.md`](guides/MCPs-INSTALLATION-GUIDE.md) - Guide d'installation MCPs
- [`guide-utilisation-mcps.md`](guides/guide-utilisation-mcps.md) - Utilisation des MCPs
- [`guide-utilisation-mcp-jupyter.md`](guides/guide-utilisation-mcp-jupyter.md) - MCP Jupyter

---

## 💻 Documentation Roo Code

### PR Tracking - Context Condensation
- [`000-documentation-index.md`](roo-code/pr-tracking/context-condensation/000-documentation-index.md) - Index de documentation
- [`001-current-system-analysis.md`](roo-code/pr-tracking/context-condensation/001-current-system-analysis.md) - Analyse système
- [`002-requirements-specification.md`](roo-code/pr-tracking/context-condensation/002-requirements-specification.md) - Spécifications
- [`003-provider-architecture.md`](roo-code/pr-tracking/context-condensation/003-provider-architecture.md) - Architecture providers
- [`004-all-providers-and-strategies.md`](roo-code/pr-tracking/context-condensation/004-all-providers-and-strategies.md) - Providers et stratégies
- [`005-implementation-roadmap.md`](roo-code/pr-tracking/context-condensation/005-implementation-roadmap.md) - Roadmap implémentation

### Architecture Roo Code
- [`context-condensation-system.md`](roo-code/architecture/context-condensation-system.md) - Système de condensation
- [`README.md`](roo-code/README.md) - Documentation Roo Code

### ADR (Architecture Decision Records)
- [`001-registry-pattern-over-plugin-system.md`](roo-code/adr/001-registry-pattern-over-plugin-system.md) - Pattern Registry
- [`002-singleton-pattern-for-manager-and-registry.md`](roo-code/adr/002-singleton-pattern-for-manager-and-registry.md) - Pattern Singleton
- [`003-backward-compatibility-strategy.md`](roo-code/adr/003-backward-compatibility-strategy.md) - Stratégie compatibilité

### Contributing
- [`add-condensation-provider.md`](roo-code/contributing/add-condensation-provider.md) - Ajouter un provider

---

## 📈 Rapports et Analyses

### Analyses
- [`competitive_analysis.md`](analyses/competitive_analysis.md) - Analyse compétitive
- [`Jupyter_MCP_Failure_Analysis.md`](analyses/Jupyter_MCP_Failure_Analysis.md) - Analyse échec Jupyter MCP

### Rapports
- [`README.md`](rapports/README.md) - Index des rapports
- [`README-AGENTS-EPITA.md`](rapports/README-AGENTS-EPITA.md) - Rapport agents EPITA
- [`readme-complet-original.md`](rapports/readme-complet-original.md) - README original

### Analyses Techniques
- [`architecture-consolidee-roo-state-manager.md`](rapports/analyses/architecture-consolidee-roo-state-manager.md) - Architecture Roo State Manager
- [`audit-inventaire-roo-state-manager-outils.md`](rapports/analyses/audit-inventaire-roo-state-manager-outils.md) - Audit des outils

### Autres
- [`COMPLEXITY-REFACTORING-REPORT.md`](COMPLEXITY-REFACTORING-REPORT.md) - Rapport refactoring complexité
- [`task-hierarchy-analysis-20251203.md`](task-hierarchy-analysis-20251203.md) - Analyse hiérarchie des tâches

---

## 🧪 Tests et Validation

### Tests et Validation
- [`README-campagne-tests-escalade.md`](tests/README-campagne-tests-escalade.md) - Campagne tests escalade

### Testing
- [`e2e-env-integration-plan.md`](testing/e2e-env-integration-plan.md) - Plan intégration E2E
- [`roosync-phase3-integration-report.md`](testing/roosync-phase3-integration-report.md) - Rapport intégration Phase 3
- [`PHASE2-RECOMMANDATIONS-FINALES.md`](testing/PHASE2-RECOMMANDATIONS-FINALES.md) - Recommandations Phase 2

### Rapports de Tests
- [`phase1-unitaires-20251016-0256-COMPLET.md`](testing/reports/phase1-unitaires-20251016-0256-COMPLET.md) - Tests unitaires Phase 1
- [`phase2-charge-2025-10-19T16-27.md`](testing/reports/phase2-charge-2025-10-19T16-27.md) - Tests de charge Phase 2

---

## 🔧 Maintenance et Dépannage

### Fixes et Corrections
- [`fix-jupyter-papermill-mcp-timeout-error.md`](fixes/fix-jupyter-papermill-mcp-timeout-error.md) - Correction timeout Jupyter
- [`fix-mcp-residual-issues-resolution.md`](fixes/fix-mcp-residual-issues-resolution.md) - Résolution problèmes MCP
- [`git-recovery-report-20250925.md`](fixes/git-recovery-report-20250925.md) - Récupération Git
- [`REPAIR-ROO-STATE-MANAGER-220GB-LEAK-FIX.md`](fixes/REPAIR-ROO-STATE-MANAGER-220GB-LEAK-FIX.md) - Correction fuite mémoire

### Debugging
- [`get_task_tree_bug_analysis.md`](debugging/get_task_tree_bug_analysis.md) - Analyse bug task tree
- [`mcp_settings_corruption_bug.md`](debugging/mcp_settings_corruption_bug.md) - Corruption mcp_settings
- [`task_hierarchy_complete.md`](debugging/task_hierarchy_complete.md) - Hiérarchie des tâches

### Incidents
- [`mcp_recovery_20250925.md`](incidents/mcp_recovery_20250925.md) - Récupération MCP 2025-09-25

### Maintenance
- [`GUIDE_HOOKS_GIT_RESOLUTION.md`](maintenance/GUIDE_HOOKS_GIT_RESOLUTION.md) - Résolution hooks Git

---

## 📦 Archives et Historique

### Archives
- [`refactoring-plan-2025-08-21.md`](archive/refactoring-plan-2025-08-21.md) - Plan refactoring
- [`stash-0-obsolete.md`](archive/stash-0-obsolete.md) - Stash obsolète

### Archives RooSync
- Voir [`docs/suivi/RooSync/Archives/`](suivi/RooSync/Archives/) pour les archives RooSync

### Archives Suivi
- Voir [`docs/suivi/Archives/`](suivi/Archives/) pour les archives de suivi

---

## 📚 Documentation Complémentaire

### Integration
- [`01-grounding-semantique-roo-state-manager.md`](integration/01-grounding-semantique-roo-state-manager.md) - Grounding sémantique
- [`02-points-integration-roosync.md`](integration/02-points-integration-roosync.md) - Points d'intégration
- [`03-architecture-integration-roosync.md`](integration/03-architecture-integration-roosync.md) - Architecture intégration
- [`18-guide-utilisateur-final-roosync.md`](integration/18-guide-utilisateur-final-roosync.md) - Guide utilisateur final

### Orchestration
- [`roosync-orchestration-synthesis-20251013.md`](orchestration/roosync-orchestration-synthesis-20251013.md) - Synthèse orchestration
- [`roosync-v2-evolution-synthesis-20251015.md`](orchestration/roosync-v2-evolution-synthesis-20251015.md) - Évolution v2

### Monitoring
- [`daily-monitoring-system.md`](monitoring/daily-monitoring-system.md) - Système de monitoring
- [`mcp-debug-logging-system.md`](monitoring/mcp-debug-logging-system.md) - Logging debug MCP

### Design
- [`01-sync-manager-specification.md`](design/01-sync-manager-specification.md) - Spécification Sync Manager
- [`02-sync-manager-architecture.md`](design/02-sync-manager-architecture.md) - Architecture Sync Manager

### Refactoring
- [`01-cleanup-plan.md`](refactoring/01-cleanup-plan.md) - Plan de nettoyage
- [`02-phase1-completion-report.md`](refactoring/02-phase1-completion-report.md) - Rapport Phase 1
- [`03-accessibility-plan.md`](refactoring/03-accessibility-plan.md) - Plan accessibilité

### Project
- [`01-changelog.md`](project/01-changelog.md) - Changelog projet
- [`project-status.md`](project/project-status.md) - Statut projet

### Planning
- Voir [`docs/planning/`](planning/) pour les documents de planification

---

## 🔗 Liens Externes

### Documentation Roo Modes
- [`README.md`](../roo-modes/README.md) - Documentation Roo Modes

### Documentation MCPs
- [`README.md`](../mcps/README.md) - Documentation MCPs principale

### Documentation Roo Config
- Voir [`roo-config/`](../roo-config/) pour la configuration Roo

---

## 📝 Notes

- Cet index est généré manuellement et maintenu par l'équipe RooSync
- Pour toute question ou suggestion d'amélioration, contacter myia-po-2023
- La structure de cet index suit les conventions SDDD (Semantic Documentation Driven Design)

---

**Index généré par:** myia-po-2023 (Tâche T2.19 - RooSync v7.0)  
**Date de création:** 2026-01-13  
**Version:** 3.0

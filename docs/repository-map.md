# Cartographie du Dépôt

Ce document cartographie la structure du dépôt et sert de guide de référence pour comprendre le rôle de chaque script et répertoire d'outillage.

## `/scripts` : Répertoire Central de l'Outillage

Le répertoire `/scripts` est l'unique source de vérité pour tous les scripts PowerShell du projet. L'arborescence a été standardisée par fonction pour clarifier les rôles et faciliter la maintenance.

---

### `/scripts/archive/`
Contient les scripts de migration à usage unique qui ne sont plus pertinents pour les opérations courantes mais sont conservés pour des raisons historiques.

*   `consolidate-configurations.ps1`, `daily-monitoring.ps1`, `maintenance-routine.ps1`, `migrate-to-profiles.ps1`, `sync_roo_environment.ps1`, `update-script-paths.ps1`, `validate-consolidation.ps1`: Scripts liés à des phases de refactorisation passées.

### `/scripts/audit/`
Héberge les outils d'audit et d'analyse spécifiques à l'écosystème Roo.

*   `audit-roo-tasks.ps1`: **Outil d'audit avancé pour les tâches Roo**. Il analyse le répertoire de stockage, identifie les tâches orphelines, valides ou en erreur (JSON manquant/corrompu). Le script est paramétrable, peut exporter des rapports et retourne des objets PowerShell pour une intégration en pipeline.

### `/scripts/demo-scripts/`
Regroupe les scripts utilisés pour préparer et nettoyer les environnements de démonstration.

*   `clean-workspaces.ps1`: Nettoie les workspaces après une démonstration.
*   `install-demo.ps1`: Script principal pour installer et configurer un environnement de démo.
*   `prepare-workspaces.ps1`: Prépare les workspaces avant une démonstration.

### `/scripts/deployment/`
Contient les outils pour le déploiement des configurations des Modes Roo.

*   `deploy-modes.ps1`: **Outil central et unifié** pour le déploiement des configurations de modes. Il peut déployer une configuration standard, générer une configuration depuis un profil, enrichir les modes avec des métadonnées, et cibler un déploiement global ou local.
*   `create-clean-modes.ps1`: Script de **réinitialisation** qui crée une configuration de modes minimale et propre. Utile pour une première installation ou pour repartir d'un état connu.
*   `deploy-correction-escalade.ps1`, `deploy-guide-interactif.ps1`, `deploy-orchestration-dynamique.ps1`, `force-deploy-with-encoding-fix.ps1`: Scripts spécialisés pour des scénarios de déploiement spécifiques.

### `/scripts/diagnostic/`
Fournit des outils pour le diagnostic technique de l'environnement et des fichiers de configuration.

*   `run-diagnostic.ps1`: **Outil de diagnostic technique complet**. Il analyse l'encodage des fichiers, valide la syntaxe JSON, détecte les anomalies de contenu (double encodage), et peut tenter de corriger automatiquement les problèmes.
*   `diag-mcps-global.ps1`: Script de diagnostic spécialisé pour les configurations globales des MCPs.

### `/scripts/encoding/`
Regroupe les scripts dédiés à la **correction du contenu** des fichiers affectés par des problèmes d'encodage.

*   `fix-file-encoding.ps1`: **Outil principal** pour réparer le contenu des fichiers corrompus par des problèmes d'encodage (mojibake). Il utilise une table de correspondance exhaustive pour remplacer les caractères erronés. Le script inclut des sécurités comme la création de sauvegardes et un mode de simulation.
*   Autres scripts (`fix-encoding-*.ps1`): Variantes plus anciennes ou plus spécifiques conservées pour des raisons de compatibilité ou pour des cas très particuliers.

### `/scripts/install/`
Contient les scripts pour l'installation des dépendances du projet.

*   `install-dependencies.ps1`: Script pour installer toutes les dépendances nécessaires au bon fonctionnement de l'outillage.

### `/scripts/maintenance/`
Héberge les outils de maintenance de haut niveau pour le workspace et le dépôt Git.

*   `maintenance-workflow.ps1`: **Orchestrateur interactif**. C'est le point d'entrée principal pour la maintenance manuelle. Il présente un menu qui guide l'opérateur et appelle les scripts spécialisés appropriés pour chaque tâche.
*   `Invoke-GitMaintenance.ps1`: Outil de nettoyage **spécifique à Git**. Il peut générer des rapports d'état, nettoyer les branches locales déjà fusionnées et supprimer les répertoires vides ou inutiles.
*   `Invoke-WorkspaceMaintenance.ps1`: Outil de maintenance **spécifique au système de fichiers**. Il nettoie les fichiers temporaires, organise les répertoires en déplaçant les fichiers mal placés, et peut générer de la documentation d'architecture.
*   `Update-ModeConfiguration.ps1`: Outil pour effectuer des mises à jour en masse sur les fichiers de configuration des modes.

### `/scripts/mcp/`
Contient les scripts pour la gestion des serveurs MCP (Multi-Context Platform).

*   `deploy-environment.ps1`: Déploie l'environnement nécessaire pour les serveurs MCP.
*   `start-jupyter-server.ps1`, `compile-mcp-servers.ps1`: Scripts pour démarrer et compiler les serveurs.
*   `utils/Convert-McpSettings.ps1`: Utilitaires pour la conversion des fichiers de configuration MCP.

### `/scripts/monitoring/`
Scripts dédiés à la surveillance de l'état de l'environnement.

*   `daily-monitoring.ps1`: Exécute une série de vérifications quotidiennes et génère un rapport.
*   `monitor-mcp-servers.ps1`: Surveille spécifiquement l'état des serveurs MCP.

### `/scripts/setup/`
Contient les scripts pour la configuration initiale de l'environnement d'un développeur.

*   `setup-encoding-workflow.ps1`: **Script essentiel pour les nouveaux contributeurs**. Configure l'environnement (PowerShell, Git, VSCode) pour prévenir les problèmes d'encodage.

### `/scripts/testing/`
Héberge les scripts liés à l'exécution des tests.

*   `run-tests.ps1`: Point d'entrée pour lancer la suite de tests du projet.
*   `unit/deploy-modes.Tests.ps1`: Tests unitaires pour le script de déploiement des modes.

### `/scripts/validation/`
Fournit des scripts pour la validation **métier et fonctionnelle** des configurations, par opposition au diagnostic technique.

*   `validate-deployed-modes.ps1`: Vérifie que les modes déployés respectent les règles métier (ex: transitions de familles, etc.).
*   `validate-mcp-config.ps1`: Valide la sémantique et la cohérence des fichiers de configuration MCP.
*   `validate-deployment.ps1`: Scripts de validation plus généraux.
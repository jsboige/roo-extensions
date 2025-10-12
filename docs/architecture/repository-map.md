# Cartographie du Dépôt

Ce document cartographie la structure du dépôt et sert de guide de référence pour comprendre le rôle de chaque répertoire.

## `/docs` : Documentation du Projet

Ce répertoire centralise toute la documentation du projet, incluant les spécifications architecturales, les guides d'utilisation, les rapports d'analyse et les plans de développement.

*   **`/architecture`**: Contient les documents décrivant l'architecture de haut niveau.
*   **`/guides`**: Héberge les guides pratiques pour les développeurs et les utilisateurs.
*   **`/rapports` & `/reports`**: Regroupent les analyses, audits, et comptes rendus.

## `/roo-config` : Configuration de l'Application

Ce répertoire est dédié à la configuration de l'environnement Roo. Il contient les paramètres, les modèles de configuration, et les sauvegardes.

*   **`/modes`**: Stocke les configurations de modes appliquées à l'environnement global.
*   **`/settings`**: Contient divers fichiers de configuration pour les MCPs et autres composants.
*   **`/config-templates`**: Modèles de configuration utilisés par les scripts de déploiement.
*   **`/scheduler`**: Configurations et métriques pour les tâches planifiées.

## `/roo-modes` : Sources des Architectures de Modes

Ce répertoire contient les *sources* des configurations pour les modes Roo. Il sert de laboratoire pour développer, tester et documenter différentes architectures de modes avant leur déploiement via les scripts.

*   **`/n5`**: Contient l'implémentation de l'architecture expérimentale à 5 niveaux de complexité.
*   **`/optimized`**: Héberge les modes optimisés pour des modèles de langage spécifiques (architecture à 2 niveaux, simple/complexe).
*   **`/custom`**: Modes spécifiques développés pour des besoins particuliers.
*   **`/configs`**: Fichiers de configuration sources et exemples.

## `/profiles` : Profils de Configuration des Modèles

Ce répertoire contient les profils de configuration qui définissent les paramètres optimaux (température, top_p, etc.) pour des familles de modèles de langage spécifiques. Ces profils permettent d'ajuster finement le comportement d'un modèle pour l'aligner sur une architecture de modes (comme l'architecture N5).

*   **`qwen3-parameters.json`**: Contient les profils recommandés pour les différents modèles de la famille Qwen 3.

## `/mcps` : Serveurs MCP (Model Context Protocol)

Ce répertoire contient les serveurs MCP qui étendent les capacités de Roo en lui permettant d'interagir avec des systèmes externes (fichiers, web, commandes CLI, etc.).

*   **`/internal`**: Serveurs MCP développés spécifiquement pour ce projet (ex: `QuickFiles`, `JinaNavigator`).
*   **`/external`**: Serveurs MCP intégrés depuis des sources externes (ex: `Filesystem`, `Git`, `SearXNG`).
*   **`/forked`**: Forks de serveurs MCP externes avec des modifications spécifiques au projet.

## `/roo-code` : Cœur de l'Extension VS Code

Ce répertoire contient le code source de l'agent de codage autonome "Roo Code". Il s'agit d'un monorepo TypeScript géré avec `pnpm` et `turbo`, structuré pour séparer les différentes parties de l'application.

*   **/apps**: Contient les applications finales, comme l'extension VS Code elle-même.
*   **/packages**: Héberge les bibliothèques et modules partagés utilisés à travers le monorepo.
*   **/src**: Code source principal de l'extension.
*   **/webview-ui**: Contient le code de l'interface utilisateur webview qui s'affiche dans VS Code.

## `/tests` : Validation et Qualité

Ce répertoire centralise tous les tests du projet. Il est organisé par catégories pour valider les différentes fonctionnalités, garantir la non-régression et assurer la robustesse de l'écosystème.

*   **/data**: Contient les jeux de données utilisés par les tests.
*   **/results**: Stocke les rapports et les résultats générés par l'exécution des suites de tests.
*   **/mcp-structure**, **`/mcp-win-cli`**, etc. : Sous-répertoires contenant des tests spécifiques pour les serveurs MCP et d'autres composants.

## `/RooSync` : Outil de Synchronisation

Ce répertoire contient un projet autonome, `RooSync` (ou RUSH-SYNC), conçu pour synchroniser l'environnement Roo en se basant sur des fichiers de configuration sources de vérité. Il est découplé du reste de l'environnement pour assurer sa portabilité.

*   **/src**: Code source de l'outil de synchronisation.
*   **/docs**: Documentation spécifique au projet RooSync.
*   **/.config**: Fichiers de configuration propres à RooSync.

## `/modules` : Composants Réutilisables

Ce répertoire héberge des modules et des composants autonomes conçus pour être réutilisables à travers le projet.

*   **Fichiers `.psm1`**: Modules PowerShell (ex: `Configuration.psm1`, `Dashboard.psm1`) qui encapsulent des logiques spécifiques.
*   **`/form-validator`**: Un exemple de composant web autonome (HTML/JS) pour la validation de formulaires.

## `/demo-roo-code` : Scénarios de Démonstration

Ce répertoire contient un parcours de découverte autonome pour les nouveaux utilisateurs de Roo. Il est structuré en scénarios thématiques et progressifs qui permettent d'explorer les différentes capacités de l'assistant.

*   **Répertoires `01` à `05`**: Scénarios de démonstration organisés par thème (découverte, orchestration, usage professionnel, etc.).
*   **Scripts `prepare-workspaces.ps1` et `clean-workspaces.ps1`**: Outils pour préparer et réinitialiser les environnements de démonstration.

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

### `/scripts/repair/`
Contient des outils conçus pour réparer des états corrompus ou désynchronisés de l'application.

*   `resync-task-history-index.ps1`: **Outil de réparation critique**. Il corrige la désynchronisation entre l'index global des tâches (`taskHistory` dans `state.vscdb`) et la source de vérité (`task_metadata.json`). Essentiel lorsque les tâches n'apparaissent pas dans l'UI après une maintenance.

### `/scripts/validation/`
Fournit des scripts pour la validation **métier et fonctionnelle** des configurations, par opposition au diagnostic technique.

*   `validate-deployed-modes.ps1`: Vérifie que les modes déployés respectent les règles métier (ex: transitions de familles, etc.).
*   `validate-mcp-config.ps1`: Valide la sémantique et la cohérence des fichiers de configuration MCP.
*   `validate-deployment.ps1`: Scripts de validation plus généraux.
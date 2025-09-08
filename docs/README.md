# Documentation du Projet Roo Extensions

## Table des matières

- [Documentation du Projet Roo Extensions](#documentation-du-projet-roo-extensions)
  - [Table des matières](#table-des-matières)
  - [Vue d'ensemble](#vue-densemble)
  - [Structure de la documentation](#structure-de-la-documentation)
    - [Répertoires principaux](#répertoires-principaux)
    - [Guides d'utilisation](#guides-dutilisation)
    - [Documentation technique](#documentation-technique)
    - [Rapports](#rapports)
    - [Tests](#tests)
  - [Organisation par composant](#organisation-par-composant)
    - [Architecture à 5 niveaux (n5)](#architecture-à-5-niveaux-n5)
    - [Modes Roo](#modes-roo)
    - [Configuration Roo](#configuration-roo)
    - [Serveurs MCP](#serveurs-mcp)
    - [Orchestration](#orchestration)
  - [Navigation rapide](#navigation-rapide)
    - [Documentation des composants principaux](#documentation-des-composants-principaux)
    - [Guides essentiels](#guides-essentiels)
  - [Comment utiliser cette documentation](#comment-utiliser-cette-documentation)
    - [Pour les nouveaux utilisateurs](#pour-les-nouveaux-utilisateurs)
    - [Pour configurer Roo](#pour-configurer-roo)
    - [Pour maintenir la configuration](#pour-maintenir-la-configuration)
    - [Pour comprendre l'architecture](#pour-comprendre-larchitecture)
  - [Contribution à la documentation](#contribution-à-la-documentation)
    - [Processus de contribution](#processus-de-contribution)
  - [Intégration](#intégration)
  - [Ressources supplémentaires](#ressources-supplémentaires)

## Vue d'ensemble

La documentation est structurée de manière à couvrir tous les aspects du projet Roo Extensions, un ensemble d'extensions, configurations et outils pour Roo, un assistant IA basé sur des modèles de langage avancés. Le projet se concentre sur :

- **Architecture à 5 niveaux (n5)** : Une approche qui organise les profils d'agent Roo en cinq niveaux de complexité
- **Modes personnalisés** : Des modes Roo optimisés pour différents modèles de langage et cas d'utilisation
- **Configuration Roo** : Des outils pour déployer et maintenir la configuration de Roo
- **Serveurs MCP** : Des serveurs Model Context Protocol qui étendent les capacités de Roo
- **Tests et validation** : Des tests pour vérifier le bon fonctionnement des différentes composantes

## Structure de la documentation

> **Note**: Le dépôt a été récemment réorganisé pour améliorer la maintenabilité et la cohérence de la structure. Cette section reflète la nouvelle organisation de la documentation.

### Répertoires principaux

- **[architecture/](architecture/)** : Documentation sur l'architecture du projet
  - Spécification des niveaux de complexité
  - Architecture d'orchestration à 5 niveaux
  - Concepts architecturaux

- **[guides/](guides/)** : Guides d'utilisation et tutoriels
  - Guides d'installation et de configuration
  - Guides d'utilisation des différentes fonctionnalités
  - Guides de résolution de problèmes

- **[rapports/](rapports/)** : Rapports d'analyse et de synthèse
  - Rapports de déploiement
  - Analyses de performance
  - Synthèses de fonctionnalités

- **[tests/](tests/)** : Documentation des tests
  - Rapports de tests d'escalade et désescalade
  - Rapports de tests MCP
  - Scénarios de test

### Guides d'utilisation

Ces documents fournissent des instructions pas à pas pour l'utilisation des différentes fonctionnalités du projet :

- [Guide complet des modes Roo](guide-complet-modes-roo.md) - Vue d'ensemble complète des modes Roo
- [Guide de configuration des MCPs](guide-configuration-mcps.md) - Instructions pour configurer les serveurs MCP
- [Guide de déploiement des configurations Roo](guides/guide-deploiement-configurations-roo.md) - Instructions pour déployer les configurations Roo
- [Guide d'encodage](guides/guide-encodage.md) - Instructions pour résoudre les problèmes d'encodage
- [Guide d'encodage pour Windows](guides/guide-encodage-windows.md) - Instructions spécifiques pour Windows
- [Guide d'escalade et désescalade](guides/guide-escalade-desescalade.md) - Explication des mécanismes d'escalade et désescalade
- [Guide du format des références aux modèles](guides/guide-format-references-modeles-roo.md) - Documentation du format des références aux modèles
- [Guide d'utilisation des MCPs](guides/guide-utilisation-mcps.md) - Instructions pour utiliser les serveurs MCP
- [Guide de maintenance de la configuration Roo](guides/guide-maintenance-configuration-roo.md) - Instructions pour maintenir la configuration Roo
- [Configuration Win-CLI pour les opérateurs](configuration-win-cli-operateurs.md) - Guide de configuration du MCP Win-CLI

### Documentation technique

Ces documents fournissent des détails techniques sur l'architecture et l'implémentation du projet :

- [Documentation de la structure de configuration Roo](guides/documentation-structure-configuration-roo.md) - Description détaillée de la structure de configuration
- [Spécification des niveaux de complexité](architecture/specification-n-niveaux-complexite.md) - Spécification de l'architecture à 5 niveaux
- [Architecture d'orchestration à 5 niveaux](architecture/architecture-orchestration-5-niveaux.md) - Description de l'architecture d'orchestration

### Rapports

Ces documents présentent des analyses, des synthèses et des résultats de tests :

- [Rapport d'état des MCPs](rapport-etat-mcps.md) - État actuel des serveurs MCP
- [Rapport de synthèse des modes Roo](rapport-synthese-modes-roo.md) - Synthèse des modes Roo disponibles
- [Rapport final de déploiement](rapports/rapport-final-deploiement.md) - Résultats du déploiement des configurations
- [Rapport d'intégration des MCP servers](rapports/rapport-integration-mcp-servers.md) - Résultats de l'intégration des serveurs MCP
- [Rapport de synthèse global](rapports/rapport-synthese-global.md) - Synthèse globale du projet
- [Analyse de performance des applications web](rapports/analyse-performance-app-web.md) - Analyse des performances des applications web
- [Comparaison MCP Win-CLI et terminal conventionnel](rapports/comparaison-mcp-win-cli-terminal-conventionnel.md) - Comparaison entre le MCP Win-CLI et le terminal conventionnel
- [Rapport final de déploiement des modes Windows](rapports/rapport-final-deploiement-modes-windows.md) - Résultats du déploiement des modes sur Windows
- [Correction de régression MCP searxng](debug-reports/searxng-mcp-regression-fix-2025-01.md) - Rapport détaillé de la correction du MCP searxng (janvier 2025)
- [Rapport de mise à jour de la configuration Roo](rapports/rapport-mise-a-jour-config-roo.md) - Rapport sur les mises à jour de la configuration Roo

### Tests

Ces documents décrivent les tests effectués et leurs résultats :

- [Rapport de test de désescalade](tests/rapport-test-desescalade.md) - Résultats des tests de désescalade
- [Rapport de test d'escalade](tests/rapport-test-escalade.md) - Résultats des tests d'escalade
- [Rapport de test MCP](tests/rapport-test-mcp.md) - Résultats des tests des serveurs MCP
- [Rapport de test orchestrateur](tests/rapport-test-orchestrateur.md) - Résultats des tests de l'orchestrateur
- [Scénario de test orchestrateur complex](tests/scenario-test-orchestrateur-complex.md) - Description des scénarios de test pour l'orchestrateur

## Organisation par composant

### Architecture à 5 niveaux (n5)

- [Spécification des niveaux de complexité](architecture/specification-n-niveaux-complexite.md) - Spécification détaillée de l'architecture à 5 niveaux
- [Architecture d'orchestration à 5 niveaux](architecture/architecture-orchestration-5-niveaux.md) - Description de l'architecture d'orchestration
- [Guide d'escalade et désescalade](guides/guide-escalade-desescalade.md) - Explication des mécanismes d'escalade et désescalade
- [Rapport de test d'escalade](tests/rapport-test-escalade.md) - Résultats des tests d'escalade
- [Rapport de test de désescalade](tests/rapport-test-desescalade.md) - Résultats des tests de désescalade

### Modes Roo

- [Guide complet des modes Roo](guide-complet-modes-roo.md) - Vue d'ensemble complète des modes Roo
- [Rapport de synthèse des modes Roo](rapport-synthese-modes-roo.md) - Synthèse des modes Roo disponibles
- [Rapport final de déploiement des modes Windows](rapports/rapport-final-deploiement-modes-windows.md) - Résultats du déploiement des modes sur Windows

### Configuration Roo

- [Documentation de la structure de configuration Roo](guides/documentation-structure-configuration-roo.md) - Description détaillée de la structure de configuration
- [Guide de déploiement des configurations Roo](guides/guide-deploiement-configurations-roo.md) - Instructions pour déployer les configurations Roo
- [Guide de maintenance de la configuration Roo](guides/guide-maintenance-configuration-roo.md) - Instructions pour maintenir la configuration Roo
- [Guide d'encodage](guides/guide-encodage.md) - Instructions pour résoudre les problèmes d'encodage
- [Guide d'encodage pour Windows](guides/guide-encodage-windows.md) - Instructions spécifiques pour Windows
- [Rapport de mise à jour de la configuration Roo](rapports/rapport-mise-a-jour-config-roo.md) - Rapport sur les mises à jour de la configuration Roo

### Serveurs MCP

- [Guide de configuration des MCPs](guide-configuration-mcps.md) - Instructions pour configurer les serveurs MCP
- [Guide d'utilisation des MCPs](guides/guide-utilisation-mcps.md) - Instructions pour utiliser les serveurs MCP
- [Rapport d'état des MCPs](rapport-etat-mcps.md) - État actuel des serveurs MCP
- [Rapport d'intégration des MCP servers](rapports/rapport-integration-mcp-servers.md) - Résultats de l'intégration des serveurs MCP
- [Rapport de test MCP](tests/rapport-test-mcp.md) - Résultats des tests des serveurs MCP
- [Configuration Win-CLI pour les opérateurs](configuration-win-cli-operateurs.md) - Guide de configuration du MCP Win-CLI
- [Comparaison MCP Win-CLI et terminal conventionnel](rapports/comparaison-mcp-win-cli-terminal-conventionnel.md) - Comparaison entre le MCP Win-CLI et le terminal conventionnel

### Orchestration

- [Rapport de test orchestrateur](tests/rapport-test-orchestrateur.md) - Résultats des tests de l'orchestrateur
- [Scénario de test orchestrateur complex](tests/scenario-test-orchestrateur-complex.md) - Description des scénarios de test pour l'orchestrateur

## Navigation rapide

### Documentation des composants principaux

- [README principal du projet](../README.md) - Vue d'ensemble du projet Roo Extensions
- [Documentation des modes Roo](../roo-modes/README.md) - Documentation des modes personnalisés
- [Documentation de la configuration Roo](../roo-config/README.md) - Documentation des outils de configuration
- [Documentation des MCPs](../mcps/README.md) - Documentation des serveurs MCP
- [Documentation des tests](../tests/README.md) - Documentation des tests du projet

### Guides essentiels

- [Guide complet des modes Roo](guide-complet-modes-roo.md) - Tout ce qu'il faut savoir sur les modes Roo
- [Guide d'utilisation des MCPs](guides/guide-utilisation-mcps.md) - Comment utiliser les serveurs MCP
- [Guide de maintenance de la configuration Roo](guides/guide-maintenance-configuration-roo.md) - Comment maintenir la configuration Roo
- [Guide d'escalade et désescalade](guides/guide-escalade-desescalade.md) - Comment fonctionnent les mécanismes d'escalade et désescalade

## Comment utiliser cette documentation

### Pour les nouveaux utilisateurs

1. **Commencez par le README principal** : Consultez le [README principal](../README.md) pour une vue d'ensemble du projet Roo Extensions.
2. **Comprenez l'architecture à 5 niveaux** : Lisez la [Spécification des niveaux de complexité](architecture/specification-n-niveaux-complexite.md) pour comprendre l'approche innovante du projet.
3. **Explorez les modes Roo** : Consultez le [Guide complet des modes Roo](guide-complet-modes-roo.md) pour comprendre les modes disponibles.
4. **Découvrez les serveurs MCP** : Lisez le [Guide d'utilisation des MCPs](guides/guide-utilisation-mcps.md) pour comprendre comment étendre les capacités de Roo.

### Pour configurer Roo

1. **Déployez les configurations** : Suivez le [Guide de déploiement des configurations Roo](guides/guide-deploiement-configurations-roo.md).
2. **Configurez les serveurs MCP** : Utilisez le [Guide de configuration des MCPs](guide-configuration-mcps.md).
3. **Résolvez les problèmes d'encodage** : Si nécessaire, consultez le [Guide d'encodage](guides/guide-encodage.md).

### Pour maintenir la configuration

1. **Maintenez la configuration** : Suivez le [Guide de maintenance de la configuration Roo](guides/guide-maintenance-configuration-roo.md).
2. **Mettez à jour les modes** : Consultez le [Rapport de mise à jour de la configuration Roo](rapports/rapport-mise-a-jour-config-roo.md).

### Pour comprendre l'architecture

1. **Architecture à 5 niveaux** : Lisez la [Spécification des niveaux de complexité](architecture/specification-n-niveaux-complexite.md).
2. **Orchestration** : Consultez l'[Architecture d'orchestration à 5 niveaux](architecture/architecture-orchestration-5-niveaux.md).
3. **Escalade et désescalade** : Comprenez le [Guide d'escalade et désescalade](guides/guide-escalade-desescalade.md).

## Contribution à la documentation

Si vous souhaitez contribuer à la documentation, veuillez suivre ces directives :

1. Utilisez le format Markdown pour tous les documents
2. Suivez la structure de répertoire existante
3. Incluez des liens vers les documents connexes
4. Ajoutez des exemples concrets lorsque c'est possible
5. Mettez à jour ce README lorsque vous ajoutez de nouveaux documents

### Processus de contribution

1. Créez une branche pour vos modifications
2. Effectuez vos modifications
3. Testez vos liens et vérifiez la mise en forme
4. Soumettez une pull request

## Intégration

La documentation s'intègre avec les autres composants du projet de plusieurs façons :

1. **Avec les modes Roo** : La documentation fournit des guides détaillés sur l'utilisation et la configuration des modes personnalisés, ainsi que sur les mécanismes d'escalade et de désescalade.

2. **Avec la configuration Roo** : Des guides complets expliquent comment déployer, configurer et maintenir les configurations Roo, ainsi que comment résoudre les problèmes d'encodage courants.

3. **Avec les serveurs MCP** : La documentation explique comment configurer et utiliser les différents serveurs MCP, ainsi que leurs capacités et limitations.

4. **Avec les tests** : Des rapports détaillés présentent les résultats des tests effectués sur les différentes composantes du projet, permettant de valider leur bon fonctionnement.

5. **Avec le système de profils** : Des guides expliquent comment utiliser le système de profils pour configurer les modes Roo en fonction des modèles de langage disponibles.

## Ressources supplémentaires

- [README principal du projet](../README.md) - Vue d'ensemble du projet Roo Extensions
- [Documentation des modes Roo](../roo-modes/README.md) - Documentation des modes personnalisés
- [Documentation de la configuration Roo](../roo-config/README.md) - Documentation des outils de configuration
- [Documentation des MCPs](../mcps/README.md) - Documentation des serveurs MCP
- [Documentation des tests](../tests/README.md) - Documentation des tests du projet
- [Rapport de synthèse global](rapports/rapport-synthese-global.md) - Synthèse globale du projet
# Roo Extensions

Ce dépôt contient des extensions, configurations et outils pour Roo, un assistant IA basé sur des modèles de langage avancés. Le projet se concentre sur l'optimisation des modes Roo, la configuration des serveurs MCP et la fourniture d'outils de maintenance.

## Vue d'ensemble du projet

Roo Extensions est un projet complet qui vise à étendre et améliorer les capacités de Roo à travers plusieurs composants clés :

1. **Architecture à 5 niveaux (n5)** : Une approche innovante qui organise les profils d'agent Roo en cinq niveaux de complexité pour optimiser les coûts et la qualité des résultats.
2. **Modes personnalisés** : Des modes Roo optimisés pour différents modèles de langage et cas d'utilisation.
3. **Configuration Roo** : Des outils pour déployer et maintenir la configuration de Roo, y compris la gestion des problèmes d'encodage.
4. **Serveurs MCP** : Des serveurs Model Context Protocol qui étendent les capacités de Roo avec des fonctionnalités comme la recherche web, l'exécution de commandes système, et plus encore.
5. **Documentation** : Une documentation complète couvrant tous les aspects du projet.

## Architecture à 5 Niveaux de Complexité (n5)

Le projet implémente une architecture innovante qui organise les profils d'agent Roo en cinq niveaux de complexité :

1. **MICRO** : Utilise des modèles légers pour les tâches très simples et rapides
   - Réponses courtes
   - Modifications minimes
   - Tâches très bien définies

2. **MINI** : Utilise des modèles économiques pour les tâches simples
   - Modifications de code mineures
   - Bugs simples
   - Documentation basique
   - Questions factuelles

3. **MEDIUM** : Utilise des modèles intermédiaires pour les tâches de complexité moyenne
   - Développement de fonctionnalités
   - Refactoring modéré
   - Analyse de code
   - Explications techniques

4. **LARGE** : Utilise des modèles avancés pour les tâches complexes
   - Architecture de systèmes
   - Refactoring majeur
   - Optimisation de performance
   - Analyses détaillées

5. **ORACLE** : Utilise les modèles les plus puissants pour les tâches très complexes
   - Conception de systèmes distribués
   - Optimisation avancée
   - Synthèse de recherche
   - Analyses multi-domaines

Cette approche permet d'optimiser les coûts d'utilisation tout en maintenant la qualité des résultats. Pour plus de détails, consultez la [documentation de l'architecture n5](roo-modes/n5/README.md).

## Structure du Projet

Le projet est organisé en plusieurs répertoires principaux, chacun avec un rôle spécifique :

### [roo-config/](roo-config/README.md)
Outils de déploiement et de configuration pour Roo, incluant :
- Scripts de déploiement des modes
- Scripts de correction d'encodage
- Scripts de diagnostic
- Modèles de configuration
- Paramètres et modes standards

### [roo-modes/](roo-modes/README.md)
Modes personnalisés pour Roo, incluant :
- Architecture à 5 niveaux (n5)
- Modes personnalisés spécifiques
- Modes optimisés pour différents modèles
- Documentation et guides d'utilisation
- Tests pour les mécanismes d'escalade et désescalade

### [mcps/](mcps/README.md)
Serveurs Model Context Protocol (MCP) qui étendent les capacités de Roo :
- SearXNG pour la recherche web
- Win-CLI pour les commandes système
- QuickFiles pour la manipulation de fichiers
- Jupyter pour les notebooks
- JinaNavigator pour la conversion web
- Git et GitHub pour les opérations Git
- Tests et documentation des MCPs

### [docs/](docs/README.md)
Documentation complète du projet :
- Guides d'utilisation
- Documentation technique
- Rapports de tests
- Spécifications d'architecture

### [tests/](tests/)
Tests et scénarios de test pour différentes parties du projet :
- Tests des MCPs
- Tests d'escalade et désescalade
- Tests d'orchestration

### [archive/](archive/)
Contenu obsolète ou archivé.

## Installation et utilisation

### Prérequis

- Roo installé et configuré
- Accès aux modèles Claude (3 Haiku, 3.5 Sonnet, 3.7 Sonnet, 3.7 Opus) ou Qwen 3
- Node.js pour les serveurs MCP
- PowerShell pour les scripts de déploiement

### Installation

1. Clonez ce dépôt :
   ```bash
   git clone https://github.com/votre-utilisateur/roo-extensions.git
   ```

2. Déployez les modes avec le script approprié :
   ```powershell
   # Pour l'architecture à 5 niveaux
   cd roo-config/deployment-scripts
   ./deploy-modes-simple-complex.ps1
   ```

3. Installez et configurez les serveurs MCP selon vos besoins (voir [Guide d'utilisation des MCPs](docs/guides/guide-utilisation-mcps.md))

4. Redémarrez Roo pour appliquer les nouveaux modes.

### Utilisation des modes

Les modes personnalisés apparaîtront dans l'interface de Roo et peuvent être sélectionnés comme n'importe quel autre mode.

- Pour les tâches très simples, sélectionnez un mode MICRO
- Pour les tâches simples, sélectionnez un mode MINI
- Pour les tâches standard, sélectionnez un mode MEDIUM
- Pour les tâches complexes, sélectionnez un mode LARGE
- Pour les tâches très complexes, sélectionnez un mode ORACLE
- L'Orchestrateur peut également router automatiquement les tâches vers le mode approprié

## Modèles Supportés

### Claude (par défaut)
- **MICRO** : Claude 3 Haiku
- **MINI** : Claude 3.5 Sonnet
- **MEDIUM** : Claude 3.5 Sonnet
- **LARGE** : Claude 3.7 Sonnet
- **ORACLE** : Claude 3.7 Opus

### Qwen 3 (configuration alternative)
- **MICRO** : Qwen3-0.6B
- **MINI** : Qwen3-4B
- **MEDIUM** : Qwen3-14B
- **LARGE** : Qwen3-32B ou Qwen3-30B-A3B (MoE)
- **ORACLE** : Qwen3-235B-A22B (MoE)

Pour utiliser les modèles Qwen 3, consultez la documentation dans [roo-config/qwen3-profiles/](roo-config/qwen3-profiles/README.md).

## MCPs Externes Disponibles

Le projet intègre plusieurs serveurs MCP (Model Context Protocol) externes pour étendre les capacités de Roo :

- **SearXNG** : Recherche web multi-moteurs
- **Win-CLI** : Exécution de commandes système
- **QuickFiles** : Manipulation rapide de fichiers multiples
- **Jupyter** : Interaction avec des notebooks Jupyter
- **JinaNavigator** : Conversion de pages web en Markdown
- **Git** : Opérations Git
- **GitHub** : Interaction avec l'API GitHub
- **Filesystem** : Interaction avec le système de fichiers

Pour plus d'informations sur l'utilisation des MCPs, consultez le [Guide d'utilisation des MCPs](docs/guides/guide-utilisation-mcps.md) et le [README des MCPs](mcps/README.md).

## Documentation

Le projet dispose d'une documentation détaillée répartie dans plusieurs fichiers README spécialisés :

- [**README principal**](README.md) : Vue d'ensemble du projet et de ses composants
- [**README de roo-config**](roo-config/README.md) : Documentation des outils de configuration Roo
- [**README de roo-modes**](roo-modes/README.md) : Documentation des modes personnalisés
- [**README des MCPs**](mcps/README.md) : Documentation des serveurs MCP
- [**README de la documentation**](docs/README.md) : Index de la documentation complète
- [**README des tests MCP**](mcps/tests/README.md) : Documentation des tests des serveurs MCP

Des guides spécifiques sont également disponibles :

- [Guide de déploiement des configurations Roo](docs/guides/guide-deploiement-configurations-roo.md)
- [Guide d'encodage](docs/guides/guide-encodage.md)
- [Guide d'escalade et désescalade](docs/guides/guide-escalade-desescalade.md)
- [Guide d'utilisation des MCPs](docs/guides/guide-utilisation-mcps.md)
- [Guide de maintenance de la configuration Roo](docs/guides/guide-maintenance-configuration-roo.md)

## Maintenance de la configuration Roo

Le projet inclut un ensemble complet d'outils pour maintenir et mettre à jour la configuration de Roo. Ces outils permettent de gérer les modes, corriger les problèmes d'encodage, déployer les configurations et diagnostiquer les problèmes courants.

### Workflows de maintenance

- **Mise à jour des commandes autorisées** : Modification et déploiement des commandes autorisées pour chaque mode
- **Ajout ou modification de modes personnalisés** : Création et déploiement de nouveaux modes ou modification des modes existants
- **Mise à jour des configurations d'API** : Modification des paramètres des serveurs MCP et autres API
- **Correction des problèmes d'encodage** : Diagnostic et correction des problèmes d'encodage dans les fichiers JSON
- **Déploiement des mises à jour** : Déploiement global ou local des configurations mises à jour

Pour des instructions détaillées sur ces workflows, consultez le [Guide de maintenance et mise à jour de la configuration Roo](docs/guides/guide-maintenance-configuration-roo.md).

### Note sur l'encodage des fichiers

**Attention** : Certains fichiers de configuration peuvent présenter des problèmes d'encodage des caractères spéciaux. Si vous rencontrez des problèmes, utilisez les scripts de diagnostic et de correction disponibles dans les dossiers `roo-config/diagnostic-scripts/` et `roo-config/encoding-scripts/`.

## Contribution

Les contributions sont les bienvenues ! Voici comment contribuer :

1. Forkez le dépôt
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/amazing-feature`)
3. Committez vos changements (`git commit -m 'Add some amazing feature'`)
4. Poussez vers la branche (`git push origin feature/amazing-feature`)
5. Ouvrez une Pull Request

## Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.
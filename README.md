# Roo Extensions

Ce dépôt contient des extensions, configurations et outils pour Roo, un assistant IA basé sur des modèles de langage avancés. Le projet se concentre sur l'optimisation des modes Roo, la configuration des serveurs MCP et la fourniture d'outils de maintenance.

## Vue d'ensemble du projet

Roo Extensions est un projet complet qui vise à étendre et améliorer les capacités de Roo à travers plusieurs composants clés :

1. **Modes personnalisés** : Des modes Roo optimisés pour différents modèles de langage et cas d'utilisation, organisés en suites de complexité variable.
2. **Configuration Roo** : Des outils pour déployer et maintenir la configuration de Roo, y compris la gestion des problèmes d'encodage.
3. **Serveurs MCP** : Des serveurs Model Context Protocol qui étendent les capacités de Roo avec des fonctionnalités comme la recherche web, l'exécution de commandes système, et plus encore.
4. **Documentation** : Une documentation complète couvrant tous les aspects du projet.
5. **Tests** : Des tests pour valider les fonctionnalités et les performances des différents composants.

## Suites de modes Roo

Le projet propose actuellement deux architectures principales pour les modes Roo :

### Architecture à 2 niveaux (Simple/Complexe)

Cette architecture, plus simple et actuellement en production, organise les modes en deux catégories :

1. **Modes Simples** : Pour les tâches courantes et de complexité modérée
   - Modèle envisagé : Qwen 3 32B
   - Optimisé pour un équilibre entre performance et coût

2. **Modes Complexes** : Pour les tâches avancées nécessitant plus de puissance
   - Modèles : Claude 3.7 Sonnet/Opus et équivalents
   - Optimisé pour les tâches complexes et les projets de grande envergure

Cette architecture est pleinement fonctionnelle et constitue la solution recommandée pour une utilisation quotidienne.

### Architecture à 5 niveaux (n5)

L'architecture à 5 niveaux (n5) est une approche innovante qui organise les modes Roo en cinq niveaux de complexité, permettant d'optimiser les coûts d'utilisation tout en maintenant la qualité des résultats :

1. **MICRO** : Pour les tâches très simples
   - Réponses courtes
   - Modifications minimes
   - Tâches très bien définies

2. **MINI** : Pour les tâches simples
   - Modifications de code mineures
   - Bugs simples
   - Documentation basique
   - Questions factuelles

3. **MEDIUM** : Pour les tâches de complexité moyenne
   - Développement de fonctionnalités
   - Refactoring modéré
   - Analyse de code
   - Explications techniques

4. **LARGE** : Pour les tâches complexes
   - Architecture de systèmes
   - Refactoring majeur
   - Optimisation de performance
   - Analyses détaillées

5. **ORACLE** : Pour les tâches très complexes
   - Conception de systèmes distribués
   - Optimisation avancée
   - Synthèse de recherche
   - Analyses multi-domaines

Cette architecture est en phase finale de développement et sera déployée après la validation complète de l'architecture à 2 niveaux. Elle implémente des mécanismes sophistiqués d'escalade et de désescalade qui permettent de passer automatiquement d'un niveau à l'autre en fonction de la complexité de la tâche.

Pour plus de détails sur cette architecture, consultez la [documentation de l'architecture n5](roo-modes/n5/README.md).

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
- Architecture à 2 niveaux (Simple/Complexe)
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

### [tests/](tests/README.md)
Tests et scénarios de test pour différentes parties du projet :
- Tests des MCPs
- Tests d'escalade et désescalade
- Tests d'orchestration

### [archive/](archive/)
Contenu obsolète ou archivé.

## Installation et utilisation

### Prérequis

- Roo installé et configuré
- Accès aux modèles de langage supportés
- Node.js pour les serveurs MCP
- PowerShell pour les scripts de déploiement

### Installation

1. Clonez ce dépôt :
   ```bash
   git clone https://github.com/votre-utilisateur/roo-extensions.git
   ```

2. Déployez les modes avec le script approprié :
   ```powershell
   # Pour l'architecture à 2 niveaux (Simple/Complexe)
   cd roo-config/deployment-scripts
   ./deploy-modes-simple-complex.ps1
   ```

3. Installez et configurez les serveurs MCP selon vos besoins (voir la documentation des MCPs)

4. Redémarrez Roo pour appliquer les nouveaux modes.

### Utilisation des modes

Les modes personnalisés apparaîtront dans l'interface de Roo et peuvent être sélectionnés comme n'importe quel autre mode.

#### Architecture à 2 niveaux
- Pour les tâches courantes : sélectionnez un mode Simple
- Pour les tâches complexes : sélectionnez un mode Complexe

#### Architecture à 5 niveaux (lorsque disponible)
- Pour les tâches très simples : sélectionnez un mode MICRO
- Pour les tâches simples : sélectionnez un mode MINI
- Pour les tâches standard : sélectionnez un mode MEDIUM
- Pour les tâches complexes : sélectionnez un mode LARGE
- Pour les tâches très complexes : sélectionnez un mode ORACLE
- L'Orchestrateur peut également router automatiquement les tâches vers le mode approprié

## Modèles Supportés

### Modèles actuellement testés et supportés

- **Claude 3.7 Sonnet** : Modèle principal pour les modes complexes dans l'architecture à 2 niveaux
- **Claude 3.7 Opus** : Modèle pour les tâches très complexes (niveau ORACLE dans l'architecture n5)
- **Gemini 2.5 Pro** : Alternative pour les modes complexes
- **Deepseek r1** : Alternative pour les modes complexes

### Architecture à 5 niveaux (n5) - Configuration Claude

- **MICRO** : Modèles légers (à déterminer)
- **MINI** : Claude 3.5 Sonnet
- **MEDIUM** : Claude 3.5 Sonnet
- **LARGE** : Claude 3.7 Sonnet
- **ORACLE** : Claude 3.7 Opus

### Architecture à 5 niveaux (n5) - Configuration Qwen 3

- **MICRO** : Qwen3-0.6B
- **MINI** : Qwen3-4B
- **MEDIUM** : Qwen3-14B
- **LARGE** : Qwen3-32B ou Qwen3-30B-A3B (MoE)
- **ORACLE** : Qwen3-235B-A22B (MoE)

Pour utiliser les modèles Qwen 3, consultez la documentation dans [roo-config/qwen3-profiles/](roo-config/qwen3-profiles/README.md).

## MCPs Disponibles

Le projet intègre plusieurs serveurs MCP (Model Context Protocol) pour étendre les capacités de Roo :

### MCPs internes

- **QuickFiles** : Manipulation rapide de fichiers multiples
- **JinaNavigator** : Conversion de pages web en Markdown
- **Jupyter** : Interaction avec des notebooks Jupyter

### MCPs externes

- **SearXNG** : Recherche web multi-moteurs
- **Win-CLI** : Exécution de commandes système Windows
- **Filesystem** : Interaction avec le système de fichiers
- **Git** : Opérations Git
- **GitHub** : Interaction avec l'API GitHub
- **Docker** : Gestion de conteneurs Docker

Pour plus d'informations sur l'utilisation des MCPs, consultez le [README des MCPs](mcps/README.md).

## Documentation

Le projet dispose d'une documentation détaillée répartie dans plusieurs fichiers README spécialisés :

- [**README principal**](README.md) : Vue d'ensemble du projet et de ses composants
- [**README de roo-config**](roo-config/README.md) : Documentation des outils de configuration Roo
- [**README de roo-modes**](roo-modes/README.md) : Documentation des modes personnalisés
- [**README des MCPs**](mcps/README.md) : Documentation des serveurs MCP
- [**README de la documentation**](docs/README.md) : Index de la documentation complète

Pour une documentation plus détaillée, consultez le [répertoire docs](docs/README.md) qui contient des guides d'utilisation, des rapports et des spécifications techniques.

## Maintenance de la configuration Roo

Le projet inclut un ensemble complet d'outils pour maintenir et mettre à jour la configuration de Roo. Ces outils permettent de gérer les modes, corriger les problèmes d'encodage, déployer les configurations et diagnostiquer les problèmes courants.

### Workflows de maintenance

- **Mise à jour des commandes autorisées** : Modification et déploiement des commandes autorisées pour chaque mode
- **Ajout ou modification de modes personnalisés** : Création et déploiement de nouveaux modes ou modification des modes existants
- **Mise à jour des configurations d'API** : Modification des paramètres des serveurs MCP et autres API
- **Correction des problèmes d'encodage** : Diagnostic et correction des problèmes d'encodage dans les fichiers JSON
- **Déploiement des mises à jour** : Déploiement global ou local des configurations mises à jour

Pour des instructions détaillées sur ces workflows, consultez le [README de roo-config](roo-config/README.md).

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
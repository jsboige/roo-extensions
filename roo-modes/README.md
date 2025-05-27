# Modes Roo

## Table des matières

1. [Introduction](#introduction)
2. [Qu'est-ce qu'un mode Roo ?](#quest-ce-quun-mode-roo-)
3. [Architectures disponibles](#architectures-de-modes-disponibles)
   - [Architecture à 2 niveaux](#architecture-à-2-niveaux-simplecomplex)
   - [Architecture à 5 niveaux (n5)](#architecture-à-5-niveaux-n5)
4. [Types de modes disponibles](#types-de-modes-disponibles)
5. [Orchestration dynamique bidirectionnelle](#orchestration-dynamique-bidirectionnelle)
6. [Structure](#structure-du-répertoire)
7. [Installation et utilisation](#installation-et-utilisation)
8. [Création de modes personnalisés](#création-de-modes-personnalisés)
9. [Tests et validation](#tests-et-validation)
10. [État actuel du développement](#état-actuel-du-développement)
11. [Intégration](#intégration)
12. [Ressources supplémentaires](#ressources-supplémentaires)

## Introduction

Ce répertoire contient l'ensemble des modes personnalisés pour Roo, organisés selon différentes architectures et optimisations pour divers modèles de langage. Ces modes permettent d'adapter le comportement de Roo à différents types de tâches et niveaux de complexité.

## Qu'est-ce qu'un mode Roo ?

Un mode Roo est une configuration spécifique qui définit le comportement, les capacités et les limitations d'un agent Roo. Chaque mode est conçu pour un type de tâche particulier (code, debug, architect, ask, orchestrator, etc.) et peut être optimisé pour différents modèles de langage et niveaux de complexité.

## Architectures de modes disponibles

Le projet propose actuellement deux architectures principales pour les modes Roo :

### Architecture à 2 niveaux (Simple/Complex)

Cette architecture, plus simple et actuellement en production, organise les modes en deux catégories :

1. **Modes Simples** : Pour les tâches courantes et de complexité modérée
   - Modèle envisagé : Qwen 3 32B
   - Optimisé pour un équilibre entre performance et coût

2. **Modes Complexes** : Pour les tâches avancées nécessitant plus de puissance
   - Modèles : Claude 3.7 Sonnet/Opus et équivalents
   - Optimisé pour les tâches complexes et les projets de grande envergure

Cette architecture est pleinement fonctionnelle et constitue la solution recommandée pour une utilisation quotidienne.

### Architecture à 5 niveaux (n5)

L'architecture à 5 niveaux (n5) organise les modes Roo en cinq niveaux de complexité, permettant d'optimiser les coûts d'utilisation tout en maintenant la qualité des résultats :

1. **MICRO** : Pour les tâches très simples
2. **MINI** : Pour les tâches simples
3. **MEDIUM** : Pour les tâches standard
4. **LARGE** : Pour les tâches complexes
5. **ORACLE** : Pour les tâches très complexes

Pour une description détaillée de cette architecture, consultez le [README principal](../README.md#architecture-à-5-niveaux-n5) et le [README spécifique de l'architecture n5](n5/README.md).

## Types de modes disponibles

Les deux architectures proposent plusieurs types de modes, chacun optimisé pour un type de tâche spécifique :

| Type | Description |
|------|-------------|
| **Code** | Modes pour le développement de code, du simple bug à la conception de systèmes complexes |
| **Debug** | Modes pour le débogage, de l'erreur simple aux problèmes systémiques |
| **Architect** | Modes pour la conception d'architecture, des suggestions rapides à la conception distribuée |
| **Ask** | Modes pour répondre aux questions, des réponses courtes aux synthèses complexes |
| **Orchestrator** | Modes pour l'orchestration de tâches, de la délégation simple à l'orchestration complexe |
| **Manager** | Mode spécialisé dans la décomposition de tâches complexes en sous-tâches orchestrées |

## Orchestration dynamique bidirectionnelle

Les deux architectures implémentent une orchestration dynamique bidirectionnelle qui permet :

### Mécanismes de délégation
- **Délégation par sous-tâches** : Création de nouvelles tâches spécialisées avec l'outil `new_task`
- **Basculement de mode** : Changement direct de mode avec l'outil `switch_mode`
- **Orchestration par modes simples** : Les modes simples peuvent coordonner des workflows complexes

### Mécanismes d'escalade et désescalade
- **Escalade** : Passage à un niveau supérieur lorsque la tâche est trop complexe pour le niveau actuel
- **Désescalade** : Passage à un niveau inférieur lorsque la tâche peut être résolue efficacement avec un modèle moins puissant

Ces mécanismes sont testés et validés par des scripts de test spécifiques disponibles dans le répertoire `n5/tests/`.

### Capacités d'orchestration des modes simples

Les modes simples ne sont pas limités aux tâches légères. Ils peuvent :

- **Orchestrer des workflows complexes** : Décomposer des tâches complexes en sous-tâches spécialisées
- **Finaliser le travail complexe** : Nettoyer, documenter et déployer après développement complexe
- **Coordonner plusieurs modes** : Gérer des séquences de tâches impliquant différents modes
- **Optimiser les ressources** : Basculer vers des modes plus puissants uniquement quand nécessaire

#### Exemples d'orchestration par modes simples :
- `code-simple` : Finalise les développements complexes (tests, commits, déploiement)
- `architect-simple` : Orchestre la documentation après conception complexe
- `orchestrator-simple` : Coordonne des workflows multi-modes

## Structure du répertoire

### Répertoires principaux

- **[configs/](configs/)** : Fichiers de configuration généraux pour les modes
  - `standard-modes.json` : Configuration des modes standards
  - `standard-modes.json.original` : Configuration originale des modes standards
  - `vscode-custom-modes.json` : Configuration pour VSCode

- **[n5/](n5/)** : Implémentation de l'architecture à 5 niveaux de complexité
  - `configs/` : Configurations des modes pour chaque niveau
  - `docs/` : Documentation et guides
  - `tests/` : Tests pour les mécanismes d'escalade et désescalade
  - Note : Les résultats des tests sont maintenant stockés dans `tests/results/n5/`

- **[custom/](custom/)** : Modes personnalisés spécifiques
  - `docs/` : Documentation technique pour les modes personnalisés

- **[optimized/](optimized/)** : Modes optimisés pour différents modèles
  - `docs/` : Documentation sur l'optimisation des modes

- **[docs/](docs/)** : Documentation sur les modes
  - `criteres-decision/` : Critères de décision pour la sélection des modes
  - `implementation/` : Guides d'implémentation et de déploiement

- **[tests/](tests/)** : Tests pour les modes personnalisés
  - `test-escalade.js` : Tests pour le mécanisme d'escalade
  - `test-desescalade.js` : Tests pour le mécanisme de désescalade

### Fichiers importants

- **[docs/implementation/guide-installation-modes-personnalises.md](docs/implementation/guide-installation-modes-personnalises.md)** : Guide détaillé pour l'installation et la configuration des modes personnalisés
- **[docs/guide-verrouillage-famille-modes.md](docs/guide-verrouillage-famille-modes.md)** : Guide sur le verrouillage des familles de modes
- **[docs/guide-import-export.md](docs/guide-import-export.md)** : Guide pour l'import et l'export des configurations de modes
- **[docs/guide-integration-modes-custom.md](docs/guide-integration-modes-custom.md)** : Guide d'intégration des modes personnalisés

## Installation et utilisation

### Installation des modes

Pour installer des modes personnalisés, vous pouvez utiliser les scripts de déploiement disponibles dans le répertoire `roo-config/deployment-scripts/` :

```powershell
# Déploiement avec le système de profils (recommandé)
cd ../roo-config
./deploy-profile-modes.ps1 -ProfileName "standard" -DeploymentType global

# Déploiement simple des modes
cd ../roo-config/deployment-scripts
./simple-deploy.ps1

# Déploiement avec options avancées
./deploy-modes-simple-complex.ps1
```

### Utilisation des modes

Une fois installés, les modes personnalisés apparaissent dans l'interface de Roo et peuvent être sélectionnés comme n'importe quel autre mode. Vous pouvez également utiliser l'Orchestrateur pour router automatiquement les tâches vers le mode le plus approprié.

## Création de modes personnalisés

Pour créer vos propres modes personnalisés, suivez les étapes décrites dans le [guide d'installation des modes personnalisés](docs/implementation/guide-installation-modes-personnalises.md).

Le processus général comprend :

1. Créer un fichier JSON de configuration du mode
2. Définir les paramètres du mode (nom, description, modèle, etc.)
3. Configurer les capacités et limitations du mode
4. Déployer le mode avec les scripts appropriés

## Tests et validation

Les modes personnalisés sont testés et validés à l'aide de scripts de test spécifiques :

- Tests d'escalade : `tests/test-escalade.js`
- Tests de désescalade : `tests/test-desescalade.js`

Ces tests vérifient que les mécanismes d'escalade et de désescalade fonctionnent correctement et que les modes répondent aux critères de qualité définis.

Pour exécuter les tests :

```powershell
cd tests
node test-escalade.js
node test-desescalade.js
```

Les résultats des tests sont stockés dans le répertoire `tests/results/n5/`.

## État actuel du développement

### Architecture à 2 niveaux (Simple/Complexe)

Cette architecture est actuellement en production et pleinement fonctionnelle. Elle est recommandée pour une utilisation quotidienne.

### Architecture à 5 niveaux (n5)

L'architecture n5 est en phase finale de développement. Les tests d'escalade ont été complétés avec succès, mais certains mécanismes de désescalade nécessitent encore des ajustements, notamment pour les niveaux Mini, Medium et Large. Cette architecture sera déployée après la validation complète de l'architecture à 2 niveaux.

## Intégration

Les modes Roo s'intègrent avec les autres composants du projet de plusieurs façons :

1. **Avec les serveurs MCP** : Les modes peuvent utiliser les capacités des serveurs MCP pour effectuer des tâches spécifiques. Par exemple, le mode Architect peut utiliser le serveur JinaNavigator pour rechercher des informations techniques.

2. **Avec le système de profils** : Le système de profils permet de configurer facilement quels modèles utiliser pour chaque mode, offrant une flexibilité maximale pour s'adapter aux besoins spécifiques.

3. **Avec les tests automatisés** : Les tests d'escalade et de désescalade permettent de valider le bon fonctionnement des modes dans différents scénarios.

4. **Avec la configuration Roo** : Les modes sont configurés via les fichiers de configuration centralisés dans le répertoire `roo-config`.

## Ressources supplémentaires

- [README principal](../README.md)
- [Documentation de la configuration Roo](../roo-config/README.md)
- [Documentation des MCPs](../mcps/README.md)
- [Documentation des tests](../tests/README.md)
- [Guide d'installation des modes personnalisés](docs/implementation/guide-installation-modes-personnalises.md)
- [Guide de verrouillage des familles de modes](docs/guide-verrouillage-famille-modes.md)
- [Guide d'import et d'export des configurations](docs/guide-import-export.md)

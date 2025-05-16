# Guide du système de verrouillage de famille pour les modes Roo

## Table des matières

1. [Introduction](#introduction)
2. [Problématique](#problématique)
3. [Solution technique](#solution-technique)
4. [Architecture du système](#architecture-du-système)
5. [Installation et configuration](#installation-et-configuration)
6. [Fonctionnement détaillé](#fonctionnement-détaillé)
7. [Maintenance et dépannage](#maintenance-et-dépannage)
8. [Évolution future](#évolution-future)

## Introduction

Ce document présente le système de verrouillage de famille pour les modes Roo, une solution technique conçue pour empêcher le basculement inapproprié des modes simples/complexes vers les modes standard. Ce système garantit que les modes restent dans leur "famille" respective, préservant ainsi leur bon fonctionnement et leur cohérence.

## Problématique

### Contexte

Le système Roo utilise différents modes spécialisés pour traiter des tâches de complexité variable. Ces modes sont organisés en deux familles principales :

1. **Famille "simple"** : Modes optimisés pour les tâches simples, généralement associés à des modèles plus légers via des profils (comme Claude 3.5 Sonnet)
2. **Famille "complex"** : Modes optimisés pour les tâches complexes, généralement associés à des modèles plus puissants via des profils (comme Claude 3.7 Sonnet)

> **Note**: Avec l'architecture basée sur les profils, les modèles spécifiques utilisés par chaque famille peuvent être facilement modifiés en changeant de profil, sans altérer la structure des familles.

### Problème identifié

Un problème critique a été identifié : les modes simples/complexes basculent fréquemment vers des modes standard, ce qui rompt leur bon fonctionnement. Ce basculement inapproprié se produit car :

1. Les configurations actuelles ne contiennent pas de mécanisme explicite pour maintenir un mode dans sa famille
2. Les formats d'escalade/désescalade ne spécifient pas explicitement la famille de modes à cibler
3. L'outil `switch_mode` est utilisé sans restriction de famille
4. Les configurations des modes ne contiennent pas d'information explicite sur leur appartenance à une famille
5. Il existe une incohérence entre l'architecture à 2 niveaux (SIMPLE, COMPLEX) et l'architecture à 5 niveaux (MICRO, MINI, MEDIUM, LARGE, ORACLE)

### Impact

Ce problème a plusieurs conséquences négatives :

- Rupture de la cohérence des conversations
- Utilisation inefficace des ressources (modèles inappropriés pour certaines tâches)
- Confusion pour l'utilisateur
- Comportements imprévisibles des modes

## Solution technique

La solution mise en place repose sur quatre composants principaux :

1. **Système de verrouillage de famille** : Ajout d'un mécanisme qui vérifie et garantit que les transitions de mode se font uniquement au sein de la même famille
2. **Métadonnées de famille** : Ajout d'informations explicites sur l'appartenance à une famille dans les configurations des modes
3. **Validation des transitions** : Implémentation d'un système qui valide les transitions de mode avant de les autoriser
4. **Instructions personnalisées renforcées** : Modification des instructions personnalisées pour renforcer l'identité des modes et leur appartenance à une famille

## Architecture du système

Le système de verrouillage de famille est composé de plusieurs scripts et configurations :

### 1. Configuration des modes

Le fichier `standard-modes.json` a été modifié pour inclure :

- Un validateur de famille (`mode-family-validator`)
- Des métadonnées de famille pour chaque mode (`family` et `allowedFamilyTransitions`)

```json
{
  "customModes": [
    {
      "slug": "mode-family-validator",
      "name": "Mode Family Validator",
      "description": "Système de validation des transitions entre familles de modes",
      "version": "1.0.0",
      "enabled": true,
      "familyDefinitions": {
        "simple": ["code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple"],
        "complex": ["code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex", "manager"]
      }
    },
    {
      "slug": "code-simple",
      "family": "simple",
      "allowedFamilyTransitions": ["simple"],
      // ...
    }
  ]
}
```

### 2. Scripts de validation et d'interception

Trois scripts principaux ont été créés :

- **validate-mode-transitions.js** : Valide les transitions entre modes
- **mode-transition-interceptor.js** : Intercepte les demandes de transition de mode
- **update-mode-instructions.js** : Met à jour les instructions personnalisées des modes

### 3. Instructions personnalisées

Les instructions personnalisées des modes ont été enrichies avec :

- Une section d'identité de mode et de famille
- Des mécanismes d'escalade/désescalade renforcés
- Des restrictions explicites sur les transitions de mode

## Installation et configuration

### Prérequis

- Node.js
- Accès aux fichiers de configuration de Roo

### Procédure d'installation

1. Exécuter le script d'installation :

```bash
node roo-modes/scripts/install-family-lock.js
```

Ce script :
- Vérifie les prérequis
- Met à jour les instructions personnalisées des modes
- Crée un fichier de configuration pour le système de verrouillage
- Crée un fichier README explicatif

### Configuration

Le système peut être configuré via le fichier `family-lock.json` :

```json
{
  "enabled": true,
  "version": "1.0.0",
  "timestamp": "2025-05-06T16:50:00.000Z",
  "families": {
    "simple": ["code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple"],
    "complex": ["code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex", "manager"]
  }
}
```

## Fonctionnement détaillé

### Processus de validation des transitions

1. L'utilisateur demande une transition de mode via l'outil `switch_mode`
2. Le script `mode-transition-interceptor.js` intercepte cette demande
3. Le script `validate-mode-transitions.js` valide la transition en vérifiant :
   - Si le mode actuel et le mode cible existent dans la configuration
   - Si le mode cible appartient à la même famille que le mode actuel
   - Si la transition est autorisée par les règles de transition du mode actuel
4. Si la validation échoue, un message d'erreur est affiché et la transition est refusée
5. Si la validation réussit, la transition est autorisée

### Mécanismes d'escalade et de désescalade

#### Pour les modes simples (escalade)

```
IMPORTANT: Lors de l'utilisation de l'outil switch_mode, vous DEVEZ UNIQUEMENT spécifier un mode_slug appartenant à la même famille que votre mode actuel. Pour le mode [MODE_ACTUEL] qui appartient à la famille "simple", vous ne pouvez escalader que vers les modes suivants: [LISTE_MODES_FAMILLE_SIMPLE].
```

#### Pour les modes complexes (désescalade)

```
IMPORTANT: Lors de l'utilisation de l'outil switch_mode, vous DEVEZ UNIQUEMENT spécifier un mode_slug appartenant à la même famille que votre mode actuel. Pour le mode [MODE_ACTUEL] qui appartient à la famille "complex", vous ne pouvez désescalader que vers les modes suivants: [LISTE_MODES_FAMILLE_COMPLEX].
```

### Journalisation

Toutes les transitions de mode sont journalisées dans le répertoire `logs` :

- Date et heure de la transition
- Mode actuel et mode cible
- Résultat de la validation (autorisée ou refusée)
- Raison du refus le cas échéant

## Maintenance et dépannage

### Journaux

Les journaux de transition se trouvent dans le répertoire `logs` et peuvent être consultés pour diagnostiquer les problèmes.

### Problèmes courants

1. **Transition refusée** : Vérifier que le mode cible appartient à la même famille que le mode actuel
2. **Mode non trouvé** : Vérifier que le mode existe dans la configuration
3. **Instructions personnalisées non mises à jour** : Exécuter à nouveau le script `update-mode-instructions.js`

### Mise à jour du système

Pour mettre à jour le système :

1. Modifier les fichiers de configuration si nécessaire
2. Exécuter le script `update-mode-instructions.js` pour mettre à jour les instructions personnalisées
3. Redémarrer les services Roo si nécessaire

## Évolution future

### Intégration avec l'architecture à 5 niveaux et les profils

Le système de verrouillage de famille est conçu pour être compatible avec l'architecture à 5 niveaux (MICRO, MINI, MEDIUM, LARGE, ORACLE) et avec le système de profils. Pour l'intégrer :

1. Définir des familles pour chaque niveau de complexité
2. Mettre à jour les métadonnées de famille dans les configurations des modes
3. Adapter les règles de transition pour permettre des transitions entre niveaux de complexité au sein de la même famille
4. Créer des profils adaptés à chaque niveau de complexité, comme le profil "n5" qui définit des modèles spécifiques pour chaque niveau

```json
{
  "name": "n5",
  "description": "Profil pour la famille de modes n5",
  "defaultModel": "anthropic/claude-3.5-sonnet",
  "modeOverrides": {
    "code-micro": "anthropic/claude-3-haiku",
    "code-mini": "anthropic/claude-3.5-sonnet",
    "code-medium": "anthropic/claude-3.5-sonnet",
    "code-large": "anthropic/claude-3.7-sonnet",
    "code-oracle": "anthropic/claude-3.7-opus"
  }
}
```

### Améliorations possibles

1. **Interface utilisateur** : Développer une interface pour visualiser et gérer les familles de modes
2. **Analyse des transitions** : Implémenter des outils d'analyse pour identifier les patterns de transition et optimiser les familles
3. **Apprentissage automatique** : Utiliser l'apprentissage automatique pour suggérer des transitions optimales en fonction du contexte

### Compatibilité avec les futures versions de Roo

Le système est conçu pour être évolutif et compatible avec les futures versions de Roo. Pour maintenir cette compatibilité :

1. Suivre les mises à jour de Roo et adapter les scripts si nécessaire
2. Maintenir une documentation à jour
3. Effectuer des tests réguliers pour vérifier le bon fonctionnement du système
4. Mettre à jour les profils pour prendre en charge les nouveaux modèles de langage

## Intégration avec le système de profils

Le système de verrouillage de famille fonctionne en tandem avec le système de profils pour offrir une solution complète et flexible :

1. **Familles de modes** : Définissent les groupes logiques de modes et les transitions autorisées
2. **Profils** : Définissent les modèles de langage à utiliser pour chaque mode

Cette séparation des préoccupations permet :
- De modifier les modèles utilisés sans affecter la structure des familles
- De faire évoluer les familles sans modifier les associations aux modèles
- D'adapter rapidement la configuration à différents contextes (économique, haute performance, etc.)

Pour plus d'informations sur le système de profils, consultez le [Guide d'utilisation des profils](../../docs/guide-utilisation-profils-modes.md).
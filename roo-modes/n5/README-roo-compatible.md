# Architecture à 5 niveaux compatible avec Roo-Code

## Table des matières

1. [Introduction](#introduction)
2. [Fichiers créés](#fichiers-créés)
3. [Modifications apportées](#modifications-apportées)
4. [Guide d'utilisation](#guide-dutilisation)
5. [Déploiement](#déploiement)
6. [Tests](#tests)
7. [Commit et push](#commit-et-push)
8. [Résolution de problèmes](#résolution-de-problèmes)

## Introduction

Ce projet adapte notre architecture à 5 niveaux de complexité pour assurer sa compatibilité avec la dernière version de Roo-Code. Cette adaptation permet de conserver notre système avancé tout en respectant la structure attendue par Roo-Code.

L'architecture à 5 niveaux offre une granularité plus fine dans l'allocation des ressources et une meilleure adaptation aux besoins spécifiques des tâches, avec les niveaux suivants :

1. **MICRO (niveau 1)** : Pour les tâches très simples (< 10 lignes de code)
2. **MINI (niveau 2)** : Pour les tâches simples (< 50 lignes de code)
3. **MEDIUM (niveau 3)** : Pour les tâches de complexité moyenne (50-200 lignes de code)
4. **LARGE (niveau 4)** : Pour les tâches complexes (> 200 lignes de code)
5. **ORACLE (niveau 5)** : Pour les tâches hautement spécialisées (systèmes entiers)

## Fichiers créés

Les fichiers suivants ont été créés pour assurer la compatibilité avec Roo-Code :

1. **`roo-modes/n5/configs/n5-modes-roo-compatible.json`** : Configuration des modes compatible avec Roo-Code
2. **`roo-modes/n5/scripts/deploy-roo-compatible.ps1`** : Script de déploiement adapté
3. **`roo-modes/n5/docs/guide-migration-roo-compatible.md`** : Guide de migration détaillé
4. **`roo-modes/n5/scripts/test-roo-compatible-transitions.js`** : Script de test des transitions
5. **`roo-modes/n5/scripts/commit-roo-compatible.ps1`** : Script pour commiter et pusher les modifications
6. **`roo-modes/n5/README-roo-compatible.md`** : Ce fichier README

## Modifications apportées

Les principales modifications sont les suivantes :

1. **Structure des modes** : Adaptation de notre structure avec `complexityLevel` et `customModes` vers la structure attendue par Roo-Code avec uniquement `customModes`.
2. **Système de verrouillage de famille** : Déplacement des métadonnées de famille depuis `complexityLevel` vers chaque mode individuel.
3. **Mécanismes d'escalade et de désescalade** : Adaptation pour utiliser l'outil `switch_mode` tout en conservant nos formats standardisés.
4. **Utilisation des MCPs** : Optimisation de notre stratégie d'utilisation des MCPs selon les recommandations de Roo-Code.

## Guide d'utilisation

Pour une documentation détaillée sur l'utilisation de l'architecture à 5 niveaux compatible avec Roo-Code, consultez le [guide de migration](./docs/guide-migration-roo-compatible.md).

### Principales fonctionnalités

1. **Escalade progressive** : Passage fluide d'un niveau à un niveau supérieur en fonction de la complexité de la tâche.
2. **Désescalade graduelle** : Passage d'un niveau supérieur à un niveau inférieur lorsque la tâche s'avère plus simple que prévu.
3. **Verrouillage de famille** : Restriction des transitions entre modes pour maintenir la cohérence du système.
4. **Utilisation optimisée des MCPs** : Stratégies pour utiliser efficacement les Model Context Protocol servers.

### Exemples d'utilisation

#### Escalade

```xml
<switch_mode>
<mode_slug>code-large</mode_slug>
<reason>Cette tâche nécessite le niveau LARGE car: elle implique une refactorisation majeure du système d'authentification</reason>
</switch_mode>
```

#### Désescalade

```xml
<switch_mode>
<mode_slug>code-mini</mode_slug>
<reason>Cette tâche peut être traitée au niveau MINI car: le problème identifié est simplement un index manquant dans la base de données</reason>
</switch_mode>
```

## Déploiement

Pour déployer l'architecture à 5 niveaux compatible avec Roo-Code, utilisez le script `deploy-roo-compatible.ps1` :

### Déploiement global (pour toutes les instances de VS Code)

```powershell
.\roo-modes/n5\scripts\deploy-roo-compatible.ps1
```

### Déploiement local (pour le projet courant uniquement)

```powershell
.\roo-modes/n5\scripts\deploy-roo-compatible.ps1 -DeploymentType local
```

### Options supplémentaires

- `-Force` : Écrase les fichiers existants sans demander de confirmation
- `-SkipBackup` : Ne crée pas de sauvegarde des fichiers existants
- `-ConfigFile <chemin>` : Spécifie un fichier de configuration alternatif

## Tests

Pour tester les transitions entre modes, utilisez le script `test-roo-compatible-transitions.js` :

```powershell
node .\roo-modes/n5\scripts\test-roo-compatible-transitions.js
```

Ce script vérifie :
- Les transitions entre modes
- Les niveaux de complexité
- Les mécanismes d'escalade et de désescalade
- L'utilisation des MCPs

## Commit et push

Pour commiter et pusher les modifications, utilisez le script `commit-roo-compatible.ps1` :

```powershell
.\roo-modes/n5\scripts\commit-roo-compatible.ps1
```

### Options

- `-CommitMessage <message>` : Spécifie un message de commit personnalisé
- `-NoPush` : Ne pousse pas les modifications vers le dépôt distant

## Résolution de problèmes

### Problème : Les transitions entre modes ne fonctionnent pas

**Cause possible** : Le mode cible n'appartient pas à la même famille que le mode actuel.

**Solution** : Vérifiez que vous utilisez uniquement des modes de la même famille (n5) dans les transitions.

### Problème : Les instructions personnalisées ne sont pas appliquées

**Cause possible** : Le fichier de configuration n'a pas été correctement déployé ou VS Code n'a pas été redémarré.

**Solution** : Redéployez la configuration et redémarrez VS Code.

### Problème : Les mécanismes d'escalade/désescalade ne fonctionnent pas

**Cause possible** : L'outil `switch_mode` n'est pas utilisé correctement.

**Solution** : Vérifiez que vous utilisez le format correct pour l'outil `switch_mode` et que le mode cible existe.

### Problème : Les MCPs ne fonctionnent pas comme prévu

**Cause possible** : Les serveurs MCP ne sont pas démarrés ou les paramètres sont incorrects.

**Solution** : Vérifiez que les serveurs MCP sont en cours d'exécution et que vous utilisez les bons paramètres.

---

Pour toute question ou problème, veuillez consulter la [documentation complète](./docs/guide-migration-roo-compatible.md) ou ouvrir une issue sur le dépôt GitHub.
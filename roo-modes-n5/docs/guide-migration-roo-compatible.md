# Guide de migration vers l'architecture à 5 niveaux compatible avec Roo-Code

## Table des matières

1. [Introduction](#introduction)
2. [Changements apportés](#changements-apportés)
3. [Structure des modes](#structure-des-modes)
4. [Système de verrouillage de famille](#système-de-verrouillage-de-famille)
5. [Mécanismes d'escalade et de désescalade](#mécanismes-descalade-et-de-désescalade)
6. [Utilisation des MCPs](#utilisation-des-mcps)
7. [Déploiement](#déploiement)
8. [Résolution de problèmes](#résolution-de-problèmes)

## Introduction

Ce document explique les modifications apportées à notre architecture à 5 niveaux pour assurer sa compatibilité avec la dernière version de Roo-Code. Ces ajustements permettent de conserver notre système avancé tout en respectant la structure attendue par Roo-Code.

## Changements apportés

Les principaux changements sont les suivants :

1. **Structure des modes** : Adaptation de notre structure avec `complexityLevel` et `customModes` vers la structure attendue par Roo-Code avec uniquement `customModes`.
2. **Système de verrouillage de famille** : Déplacement des métadonnées de famille depuis `complexityLevel` vers chaque mode individuel.
3. **Mécanismes d'escalade et de désescalade** : Adaptation pour utiliser l'outil `switch_mode` tout en conservant nos formats standardisés.
4. **Utilisation des MCPs** : Optimisation de notre stratégie d'utilisation des MCPs selon les recommandations de Roo-Code.

## Structure des modes

### Ancienne structure

```json
{
  "complexityLevel": {
    "level": 3,
    "name": "MEDIUM",
    "slug": "medium",
    "referenceModel": "anthropic/claude-3.5-sonnet",
    "contextSize": 100000,
    "deployment": "cloud",
    "metrics": { ... },
    "escalationThresholds": { ... },
    "nextLevel": "large",
    "previousLevel": "mini",
    "family": "n5",
    "allowedFamilyTransitions": ["n5"]
  },
  "customModes": [
    {
      "slug": "code-medium",
      "name": "💻 Code Medium",
      "model": "anthropic/claude-3.5-sonnet",
      "roleDefinition": "...",
      "groups": ["read", "edit", "browser", "command", "mcp"],
      "customInstructions": "..."
    }
  ]
}
```

### Nouvelle structure compatible avec Roo-Code

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
        "n5": ["code-micro", "code-mini", "code-medium", "code-large", "code-oracle", ...]
      }
    },
    {
      "slug": "code-medium",
      "family": "n5",
      "allowedFamilyTransitions": ["n5"],
      "name": "💻 Code Medium",
      "model": "anthropic/claude-3.5-sonnet",
      "roleDefinition": "...",
      "groups": ["read", "edit", "browser", "command", "mcp"],
      "customInstructions": "..."
    }
  ]
}
```

Les principales différences sont :

- Suppression de la section `complexityLevel` séparée
- Ajout d'un mode spécial `mode-family-validator` pour la validation des transitions
- Intégration des métadonnées de famille (`family` et `allowedFamilyTransitions`) directement dans chaque mode
- Conservation des informations de niveau dans les instructions personnalisées

## Système de verrouillage de famille

Le système de verrouillage de famille a été adapté pour fonctionner avec la structure de Roo-Code :

1. **Définition des familles** : Les familles sont définies dans le mode spécial `mode-family-validator`.
2. **Métadonnées de famille** : Chaque mode inclut maintenant les propriétés `family` et `allowedFamilyTransitions`.
3. **Instructions de verrouillage** : Les instructions de verrouillage sont conservées dans les instructions personnalisées de chaque mode.

Exemple d'instructions de verrouillage :

```
/* VERROUILLAGE DE FAMILLE */
// Cette section définit les restrictions de transition entre modes
// Famille actuelle: n5 (architecture à 5 niveaux)

IMPORTANT: Lors de l'utilisation de l'outil switch_mode, vous DEVEZ UNIQUEMENT spécifier un mode_slug appartenant à la même famille que votre mode actuel. Pour le mode code-medium qui appartient à la famille "n5", vous ne pouvez escalader que vers les modes suivants: code-large, debug-large, architect-large, ask-large, orchestrator-large. Vous pouvez également désescalader vers: code-mini, debug-mini, architect-mini, ask-mini, orchestrator-mini.

Vous ne devez JAMAIS tenter de basculer vers des modes natifs ou des modes d'autres familles. Cela provoquerait une rupture de cohérence dans le système.
```

## Mécanismes d'escalade et de désescalade

Les mécanismes d'escalade et de désescalade ont été adaptés pour utiliser l'outil `switch_mode` de Roo-Code :

### Escalade

```xml
<switch_mode>
<mode_slug>code-large</mode_slug>
<reason>Cette tâche nécessite le niveau LARGE car: [RAISON]</reason>
</switch_mode>
```

### Désescalade

```xml
<switch_mode>
<mode_slug>code-mini</mode_slug>
<reason>Cette tâche peut être traitée au niveau MINI car: [RAISON]</reason>
</switch_mode>
```

Les formats standardisés pour les messages d'escalade et de désescalade sont conservés dans les instructions personnalisées pour maintenir la cohérence de notre système.

## Utilisation des MCPs

La stratégie d'utilisation des MCPs a été optimisée selon les recommandations de Roo-Code :

1. **Priorité aux MCPs** : Privilégier systématiquement l'utilisation des MCPs par rapport aux outils standards nécessitant une validation humaine.
2. **Regroupement des opérations** : Regrouper les opérations similaires en une seule commande MCP.
3. **Filtrage à la source** : Filtrer les données à la source plutôt que de tout lire puis filtrer.
4. **Limitation des résultats** : Limiter l'affichage des résultats volumineux en utilisant les paramètres de pagination.

Exemples d'utilisation des MCPs inclus dans les instructions personnalisées :

```
/* UTILISATION OPTIMISÉE DES MCPs */
// Privilégier l'utilisation des MCPs pour les opérations complexes
// Pour les manipulations de fichiers multiples, utiliser le MCP quickfiles
// Pour l'extraction d'informations web, utiliser le MCP jinavigator
// Pour les recherches web, utiliser le MCP searxng
// Pour les commandes système, utiliser le MCP win-cli
```

## Déploiement

Pour déployer l'architecture à 5 niveaux compatible avec Roo-Code, utilisez le script `deploy-roo-compatible.ps1` :

### Déploiement global (pour toutes les instances de VS Code)

```powershell
.\roo-modes-n5\scripts\deploy-roo-compatible.ps1
```

### Déploiement local (pour le projet courant uniquement)

```powershell
.\roo-modes-n5\scripts\deploy-roo-compatible.ps1 -DeploymentType local
```

### Options supplémentaires

- `-Force` : Écrase les fichiers existants sans demander de confirmation
- `-SkipBackup` : Ne crée pas de sauvegarde des fichiers existants
- `-ConfigFile <chemin>` : Spécifie un fichier de configuration alternatif

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
# Guide d'utilisation des profils dans le système de modes personnalisés

## Table des matières

1. [Introduction](#introduction)
2. [Architecture basée sur les profils](#architecture-basée-sur-les-profils)
3. [Avantages de l'approche par profils](#avantages-de-lapproche-par-profils)
4. [Structure des profils](#structure-des-profils)
5. [Création et gestion des profils](#création-et-gestion-des-profils)
6. [Déploiement des profils](#déploiement-des-profils)
7. [Exemples d'utilisation](#exemples-dutilisation)
8. [Migration depuis l'ancienne architecture](#migration-depuis-lancienne-architecture)
9. [Dépannage](#dépannage)
10. [Références](#références)

## Introduction

Ce document présente l'architecture basée sur les profils pour le système de modes personnalisés Roo. Cette nouvelle approche remplace l'ancienne méthode d'association directe des modes aux modèles de langage, offrant une plus grande flexibilité et une gestion centralisée des configurations.

## Architecture basée sur les profils

### Qu'est-ce qu'un profil?

Un profil est une configuration qui définit quels modèles de langage utiliser pour chaque mode personnalisé. Il permet de:

- Définir un modèle par défaut pour tous les modes
- Spécifier des surcharges pour certains modes spécifiques
- Faciliter le passage d'une configuration à une autre

### Composants du système

L'architecture basée sur les profils comprend plusieurs composants:

1. **Fichier de configuration des profils** (`model-configs.json`): Stocke les définitions des profils
2. **Scripts de gestion des profils**:
   - `create-profile.ps1`: Crée un nouveau profil
   - `deploy-profile-modes.ps1`: Déploie une configuration basée sur un profil
   - `deploy-modes-enhanced.ps1`: Version améliorée du script de déploiement avec support des profils
3. **Intégration avec le système de modes**: Les modes utilisent les profils pour déterminer quel modèle de langage utiliser

### Flux de travail

1. Création d'un profil définissant les modèles à utiliser pour chaque mode
2. Déploiement du profil pour générer une configuration de modes
3. Utilisation des modes avec les modèles définis par le profil
4. Possibilité de basculer facilement entre différents profils selon les besoins

## Avantages de l'approche par profils

L'architecture basée sur les profils présente plusieurs avantages par rapport à l'ancienne approche:

### 1. Gestion centralisée des modèles

- **Avant**: Chaque mode spécifiait directement son modèle dans sa configuration
- **Maintenant**: Les modèles sont définis dans un profil centralisé, facilitant les mises à jour globales

### 2. Flexibilité accrue

- **Avant**: Changer les modèles nécessitait de modifier chaque configuration de mode individuellement
- **Maintenant**: Il suffit de basculer vers un autre profil ou de modifier un profil existant

### 3. Cohérence des configurations

- **Avant**: Risque d'incohérences entre les différentes configurations de modes
- **Maintenant**: Garantie de cohérence grâce à la gestion centralisée des profils

### 4. Adaptation aux différents contextes

- **Avant**: Configuration fixe pour tous les contextes
- **Maintenant**: Possibilité de créer des profils adaptés à différents contextes (économique, haute performance, local, etc.)

### 5. Facilité de maintenance

- **Avant**: Modifications complexes nécessitant des interventions sur plusieurs fichiers
- **Maintenant**: Modifications simplifiées grâce à la centralisation des configurations

## Structure des profils

Les profils sont définis dans le fichier `model-configs.json` avec la structure suivante:

```json
{
  "profiles": [
    {
      "name": "standard",
      "description": "Profil standard avec Claude 3.5 Sonnet pour les modes simples et Claude 3.7 Sonnet pour les modes complexes",
      "defaultModel": "anthropic/claude-3.5-sonnet",
      "modeOverrides": {
        "code": "anthropic/claude-3.7-sonnet",
        "code-complex": "anthropic/claude-3.7-sonnet",
        "debug-complex": "anthropic/claude-3.7-sonnet",
        "architect-complex": "anthropic/claude-3.7-sonnet",
        "ask-complex": "anthropic/claude-3.7-sonnet",
        "orchestrator-complex": "anthropic/claude-3.7-sonnet"
      }
    }
  ],
  "activeProfile": "standard"
}
```

### Propriétés d'un profil

- `name`: Nom unique du profil
- `description`: Description du profil et de son utilisation prévue
- `defaultModel`: Modèle par défaut utilisé pour tous les modes sans surcharge spécifique
- `modeOverrides`: Objet définissant des surcharges de modèle pour des modes spécifiques
- `activeProfile`: Indique le profil actuellement actif dans le système

## Création et gestion des profils

### Création d'un nouveau profil

Le script `create-profile.ps1` permet de créer un nouveau profil:

```powershell
# Syntaxe de base
.\create-profile.ps1 -ProfileName "nom_du_profil" -Description "description_du_profil" -DefaultModel "modèle_par_défaut"

# Exemple avec surcharges de modes spécifiées en ligne de commande
.\create-profile.ps1 -ProfileName "économique" -Description "Profil économique avec Claude 3 Haiku" -DefaultModel "anthropic/claude-3-haiku" -ModeOverridesJson '{"code-complex":"anthropic/claude-3.5-sonnet","debug-complex":"anthropic/claude-3.5-sonnet"}'

# Exemple avec surcharges de modes interactives
.\create-profile.ps1 -ProfileName "mixte" -Description "Profil mixte avec différents modèles" -DefaultModel "anthropic/claude-3.5-sonnet"
```

#### Paramètres

- `-ProfileName` (obligatoire): Nom du profil à créer
- `-Description` (obligatoire): Description du profil
- `-DefaultModel` (obligatoire): Modèle par défaut à utiliser pour tous les modes
- `-ConfigFile` (optionnel): Chemin du fichier de configuration des profils (par défaut: "model-configs.json")
- `-Force` (optionnel): Remplacer le profil s'il existe déjà sans demander de confirmation
- `-ModeOverridesJson` (optionnel): JSON contenant les surcharges de modes au format `{"mode1":"modèle1","mode2":"modèle2"}`

### Modification d'un profil existant

Pour modifier un profil existant, utilisez le script `create-profile.ps1` avec l'option `-Force`:

```powershell
.\create-profile.ps1 -ProfileName "standard" -Description "Profil standard mis à jour" -DefaultModel "anthropic/claude-3.5-sonnet" -ModeOverridesJson '{"code":"anthropic/claude-3.7-sonnet","code-complex":"anthropic/claude-3.7-sonnet"}' -Force
```

### Suppression d'un profil

Pour supprimer un profil, vous devez modifier manuellement le fichier `model-configs.json` et retirer l'entrée correspondante.

## Déploiement des profils

### Déploiement basé sur un profil

Le script `deploy-profile-modes.ps1` permet de déployer une configuration de modes basée sur un profil:

```powershell
# Syntaxe de base
.\deploy-profile-modes.ps1 -ProfileName "nom_du_profil" -DeploymentType "global|local"

# Exemple de déploiement global
.\deploy-profile-modes.ps1 -ProfileName "standard" -DeploymentType "global"

# Exemple de déploiement local avec force
.\deploy-profile-modes.ps1 -ProfileName "économique" -DeploymentType "local" -Force
```

#### Paramètres

- `-ProfileName` (obligatoire): Nom du profil à déployer
- `-DeploymentType` (optionnel): Type de déploiement, "global" ou "local" (par défaut: "global")
- `-Force` (optionnel): Remplacer la configuration existante sans demander de confirmation
- `-ConfigFile` (optionnel): Chemin du fichier de configuration des profils (par défaut: "model-configs.json")
- `-OutputFile` (optionnel): Chemin du fichier de sortie généré (par défaut: "modes/generated-profile-modes.json")

### Utilisation du script de déploiement amélioré

Le script `deploy-modes-enhanced.ps1` est une version améliorée du script `deploy-modes.ps1` qui prend en compte les profils:

```powershell
# Syntaxe de base (déploiement standard)
.\deploy-modes-enhanced.ps1 -ConfigFile "modes/standard-modes.json" -DeploymentType "global|local"

# Exemple de déploiement basé sur un profil
.\deploy-modes-enhanced.ps1 -ProfileName "standard" -DeploymentType "global"
```

#### Paramètres

- `-ConfigFile` (optionnel): Chemin du fichier de configuration des modes (par défaut: "modes/standard-modes.json")
- `-DeploymentType` (optionnel): Type de déploiement, "global" ou "local" (par défaut: "global")
- `-Force` (optionnel): Remplacer la configuration existante sans demander de confirmation
- `-ProfileName` (optionnel): Nom du profil à déployer (si spécifié, le script utilisera `deploy-profile-modes.ps1`)
- `-ProfileConfigFile` (optionnel): Chemin du fichier de configuration des profils (par défaut: "model-configs.json")

## Exemples d'utilisation

### Scénario 1: Création et déploiement d'un profil économique

Ce scénario montre comment créer un profil économique utilisant principalement Claude 3 Haiku, puis le déployer:

```powershell
# Créer un profil économique
.\create-profile.ps1 -ProfileName "économique" -Description "Profil économique avec Claude 3 Haiku" -DefaultModel "anthropic/claude-3-haiku" -ModeOverridesJson '{
  "code-complex": "anthropic/claude-3.5-sonnet",
  "debug-complex": "anthropic/claude-3.5-sonnet",
  "architect-complex": "anthropic/claude-3.5-sonnet"
}'

# Déployer le profil globalement
.\deploy-profile-modes.ps1 -ProfileName "économique" -DeploymentType "global"
```

### Scénario 2: Basculement entre profils pour différents contextes

Ce scénario montre comment basculer entre différents profils selon le contexte:

```powershell
# Déployer le profil standard pour le développement quotidien
.\deploy-modes-enhanced.ps1 -ProfileName "standard" -DeploymentType "global"

# Plus tard, basculer vers le profil économique pour réduire les coûts
.\deploy-modes-enhanced.ps1 -ProfileName "économique" -DeploymentType "global"

# Pour un projet spécifique, basculer vers un profil haute performance
.\deploy-modes-enhanced.ps1 -ProfileName "performance" -DeploymentType "local"
```

### Scénario 3: Profil pour environnement mixte (local et cloud)

Ce scénario montre comment créer un profil pour un environnement mixte utilisant des modèles locaux et cloud:

```powershell
# Créer un profil mixte
.\create-profile.ps1 -ProfileName "mixte" -Description "Profil mixte avec modèles locaux et cloud" -DefaultModel "local/llama-3-70b" -ModeOverridesJson '{
  "code": "local/llama-3-70b",
  "code-complex": "anthropic/claude-3.7-sonnet",
  "debug": "local/llama-3-70b",
  "debug-complex": "anthropic/claude-3.7-sonnet",
  "architect-complex": "anthropic/claude-3.7-opus"
}'

# Déployer le profil localement pour un projet spécifique
.\deploy-profile-modes.ps1 -ProfileName "mixte" -DeploymentType "local"
```

### Scénario 4: Profil pour la famille de modes n5

Ce scénario montre comment créer un profil pour la famille de modes n5 avec différents niveaux de complexité:

```powershell
# Créer un profil n5
.\create-profile.ps1 -ProfileName "n5" -Description "Profil pour la famille de modes n5" -DefaultModel "anthropic/claude-3.5-sonnet" -ModeOverridesJson '{
  "code-micro": "anthropic/claude-3-haiku",
  "code-mini": "anthropic/claude-3.5-sonnet",
  "code-medium": "anthropic/claude-3.5-sonnet",
  "code-large": "anthropic/claude-3.7-sonnet",
  "code-oracle": "anthropic/claude-3.7-opus"
}'

# Déployer le profil
.\deploy-profile-modes.ps1 -ProfileName "n5" -DeploymentType "global"
```

## Migration depuis l'ancienne architecture

Pour migrer depuis l'ancienne architecture (association directe des modes aux modèles), utilisez le script `migrate-to-profiles.ps1`:

```powershell
# Syntaxe de base
.\migrate-to-profiles.ps1 -ConfigFile "chemin/vers/modes.json" -OutputProfileName "nom_du_profil_généré"

# Exemple
.\migrate-to-profiles.ps1 -ConfigFile "roo-modes/configs/standard-modes.json" -OutputProfileName "migré"
```

Ce script:
1. Analyse la configuration existante
2. Extrait les modèles utilisés par chaque mode
3. Crée un nouveau profil avec ces informations
4. Sauvegarde l'ancienne configuration

## Dépannage

### Problème: Le profil n'existe pas

Si vous obtenez une erreur indiquant que le profil n'existe pas:

1. Vérifiez que le nom du profil est correctement orthographié
2. Vérifiez que le fichier `model-configs.json` existe et contient le profil
3. Vérifiez que vous utilisez le bon chemin pour le fichier de configuration des profils

### Problème: Les modes ne sont pas mis à jour

Si les modes ne sont pas mis à jour après le déploiement:

1. Assurez-vous d'avoir redémarré VS Code
2. Vérifiez que le fichier de destination a été correctement créé
3. Vérifiez que le profil contient les bonnes surcharges de modes

### Problème: Erreurs lors de la création du profil

Si vous rencontrez des erreurs lors de la création du profil:

1. Assurez-vous que le format JSON des surcharges est valide
2. Vérifiez que vous avez les droits d'écriture sur le fichier `model-configs.json`
3. Essayez d'utiliser le paramètre `-Force` pour remplacer un profil existant

## Références

- [README des profils pour les modes personnalisés](../roo-config/README-profile-modes.md)
- [Guide d'intégration des modes personnalisés](../roo-modes/docs/guide-integration-modes-custom.md)
- [Guide du système de verrouillage de famille](../roo-modes/docs/guide-verrouillage-famille-modes.md)
- [Script de création de profil](../roo-config/create-profile.ps1)
- [Script de déploiement de profil](../roo-config/deploy-profile-modes.ps1)
- [Script de déploiement amélioré](../roo-config/deploy-modes-enhanced.ps1)
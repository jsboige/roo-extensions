# Gestion des profils pour les modes personnalisés Roo

Ce document explique comment utiliser les scripts de gestion des profils pour les modes personnalisés Roo. Ces scripts permettent de créer, gérer et déployer des configurations de modes basées sur des profils.

## Qu'est-ce qu'un profil?

Un profil est une configuration qui définit quels modèles de langage utiliser pour chaque mode personnalisé. Il permet de:

- Définir un modèle par défaut pour tous les modes
- Spécifier des surcharges pour certains modes spécifiques
- Faciliter le passage d'une configuration à une autre

## Structure des fichiers

- `model-configs.json` - Fichier contenant les définitions des profils
- `deploy-profile-modes.ps1` - Script pour déployer une configuration basée sur un profil
- `create-profile.ps1` - Script pour créer un nouveau profil
- `deploy-modes-enhanced.ps1` - Version améliorée du script de déploiement avec support des profils

## Structure du fichier model-configs.json

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
    },
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
  ],
  "activeProfile": "standard"
}
```

## Utilisation des scripts

### Créer un nouveau profil

Le script `create-profile.ps1` permet de créer un nouveau profil avec un nom, une description et un modèle par défaut, ainsi que des surcharges pour certains modes spécifiques.

```powershell
# Syntaxe de base
.\create-profile.ps1 -ProfileName "nom_du_profil" -Description "description_du_profil" -DefaultModel "modèle_par_défaut"

# Exemple avec surcharges de modes spécifiées en ligne de commande
.\create-profile.ps1 -ProfileName "haiku" -Description "Profil économique avec Claude 3 Haiku" -DefaultModel "anthropic/claude-3-haiku" -ModeOverridesJson '{"code-complex":"anthropic/claude-3.5-sonnet","debug-complex":"anthropic/claude-3.5-sonnet"}'

# Exemple avec surcharges de modes interactives
.\create-profile.ps1 -ProfileName "mixte" -Description "Profil mixte avec différents modèles" -DefaultModel "anthropic/claude-3.5-sonnet"
```

#### Paramètres

- `-ProfileName` (obligatoire) : Nom du profil à créer
- `-Description` (obligatoire) : Description du profil
- `-DefaultModel` (obligatoire) : Modèle par défaut à utiliser pour tous les modes
- `-ConfigFile` (optionnel) : Chemin du fichier de configuration des profils (par défaut: "model-configs.json")
- `-Force` (optionnel) : Remplacer le profil s'il existe déjà sans demander de confirmation
- `-ModeOverridesJson` (optionnel) : JSON contenant les surcharges de modes au format `{"mode1":"modèle1","mode2":"modèle2"}`

Si `-ModeOverridesJson` n'est pas spécifié, le script demandera interactivement les surcharges pour les modes courants.

### Déployer une configuration basée sur un profil

Le script `deploy-profile-modes.ps1` permet de déployer une configuration de modes basée sur un profil spécifique.

```powershell
# Syntaxe de base
.\deploy-profile-modes.ps1 -ProfileName "nom_du_profil" -DeploymentType "global|local"

# Exemple de déploiement global
.\deploy-profile-modes.ps1 -ProfileName "standard" -DeploymentType "global"

# Exemple de déploiement local avec force
.\deploy-profile-modes.ps1 -ProfileName "n5" -DeploymentType "local" -Force
```

#### Paramètres

- `-ProfileName` (obligatoire) : Nom du profil à déployer
- `-DeploymentType` (optionnel) : Type de déploiement, "global" ou "local" (par défaut: "global")
- `-Force` (optionnel) : Remplacer la configuration existante sans demander de confirmation
- `-ConfigFile` (optionnel) : Chemin du fichier de configuration des profils (par défaut: "model-configs.json")
- `-OutputFile` (optionnel) : Chemin du fichier de sortie généré (par défaut: "modes/generated-profile-modes.json")

### Utiliser le script de déploiement amélioré

Le script `deploy-modes-enhanced.ps1` est une version améliorée du script `deploy-modes.ps1` qui prend en compte les profils.

```powershell
# Syntaxe de base (déploiement standard)
.\deploy-modes-enhanced.ps1 -ConfigFile "modes/standard-modes.json" -DeploymentType "global|local"

# Exemple de déploiement basé sur un profil
.\deploy-modes-enhanced.ps1 -ProfileName "standard" -DeploymentType "global"
```

#### Paramètres

- `-ConfigFile` (optionnel) : Chemin du fichier de configuration des modes (par défaut: "modes/standard-modes.json")
- `-DeploymentType` (optionnel) : Type de déploiement, "global" ou "local" (par défaut: "global")
- `-Force` (optionnel) : Remplacer la configuration existante sans demander de confirmation
- `-ProfileName` (optionnel) : Nom du profil à déployer (si spécifié, le script utilisera `deploy-profile-modes.ps1`)
- `-ProfileConfigFile` (optionnel) : Chemin du fichier de configuration des profils (par défaut: "model-configs.json")

## Exemples d'utilisation

### Scénario 1: Créer et déployer un nouveau profil

```powershell
# Créer un nouveau profil
.\create-profile.ps1 -ProfileName "économique" -Description "Profil économique avec Claude 3 Haiku" -DefaultModel "anthropic/claude-3-haiku"

# Déployer le profil globalement
.\deploy-profile-modes.ps1 -ProfileName "économique" -DeploymentType "global"
```

### Scénario 2: Basculer entre différents profils

```powershell
# Déployer le profil standard
.\deploy-modes-enhanced.ps1 -ProfileName "standard" -DeploymentType "global"

# Plus tard, basculer vers le profil n5
.\deploy-modes-enhanced.ps1 -ProfileName "n5" -DeploymentType "global"
```

### Scénario 3: Créer un profil avec des surcharges spécifiques

```powershell
# Créer un profil avec des surcharges spécifiques
.\create-profile.ps1 -ProfileName "hybride" -Description "Profil hybride avec différents modèles" -DefaultModel "anthropic/claude-3.5-sonnet" -ModeOverridesJson '{
  "code": "anthropic/claude-3.7-sonnet",
  "code-complex": "anthropic/claude-3.7-sonnet",
  "debug": "anthropic/claude-3-haiku",
  "debug-complex": "anthropic/claude-3.5-sonnet",
  "architect-complex": "anthropic/claude-3.7-opus"
}'

# Déployer le profil
.\deploy-profile-modes.ps1 -ProfileName "hybride" -DeploymentType "global"
```

## Notes importantes

1. Les profils sont stockés dans le fichier `model-configs.json`.
2. Le script `deploy-profile-modes.ps1` génère un fichier de configuration temporaire basé sur le profil spécifié.
3. Le déploiement global place la configuration dans le répertoire de VS Code, tandis que le déploiement local crée un fichier `.roomodes` dans le répertoire du projet.
4. Après le déploiement, vous devez redémarrer VS Code pour que les changements prennent effet.

## Dépannage

### Le profil n'existe pas

Si vous obtenez une erreur indiquant que le profil n'existe pas, vérifiez:
- Que le nom du profil est correctement orthographié
- Que le fichier `model-configs.json` existe et contient le profil
- Que vous utilisez le bon chemin pour le fichier de configuration des profils

### Les modes ne sont pas mis à jour

Si les modes ne sont pas mis à jour après le déploiement:
- Assurez-vous d'avoir redémarré VS Code
- Vérifiez que le fichier de destination a été correctement créé
- Vérifiez que le profil contient les bonnes surcharges de modes

### Erreurs lors de la création du profil

Si vous rencontrez des erreurs lors de la création du profil:
- Assurez-vous que le format JSON des surcharges est valide
- Vérifiez que vous avez les droits d'écriture sur le fichier `model-configs.json`
- Essayez d'utiliser le paramètre `-Force` pour remplacer un profil existant
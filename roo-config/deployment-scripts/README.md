# Scripts de déploiement des modes Roo

Ce dossier contient des scripts PowerShell pour déployer les modes Roo (simple et complex) sur Windows.

## Fonctionnalités

Ces scripts permettent de déployer les modes Roo de différentes manières :
- Déploiement global (pour toutes les instances de VS Code)
- Déploiement local (pour un projet spécifique)
- Déploiement avec correction automatique d'encodage
- Déploiement interactif guidé

## Scripts disponibles

### Scripts principaux

- **`simple-deploy.ps1`** - Script simplifié pour déployer les modes avec l'option force
- **`deploy-modes-simple-complex.ps1`** - Script principal de déploiement avec gestion améliorée de l'encodage
- **`deploy-guide-interactif.ps1`** - Guide interactif pour le déploiement des modes

### Scripts spécialisés

- **`deploy-modes-enhanced.ps1`** - Version améliorée du script de déploiement avec options supplémentaires
- **`force-deploy-with-encoding-fix.ps1`** - Script qui force le déploiement avec correction d'encodage intégrée
- **`create-clean-modes.ps1`** - Script pour créer des modes propres à partir des modèles

## Utilisation recommandée

### Déploiement simple

Pour un déploiement rapide des modes simple et complex :

```powershell
.\simple-deploy.ps1
```

### Déploiement avec options

Pour un déploiement avec plus d'options (global/local, force, test) :

```powershell
.\deploy-modes-simple-complex.ps1 -DeploymentType "global" -Force -TestAfterDeploy
```

### Déploiement guidé

Pour un déploiement guidé avec vérification d'encodage :

```powershell
.\deploy-guide-interactif.ps1
```

## Paramètres communs

- **`DeploymentType`** : Type de déploiement ("global" ou "local")
- **`Force`** : Force le remplacement des fichiers existants
- **`TestAfterDeploy`** : Exécute des tests après le déploiement
- **`DebugMode`** : Affiche des informations de débogage supplémentaires

## Remarques

- Le déploiement global installe les modes pour toutes les instances de VS Code
- Le déploiement local crée un fichier `.roomodes` dans le répertoire du projet
- Après le déploiement, il est recommandé de redémarrer VS Code
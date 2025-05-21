# Modèles de fichiers de configuration

Ce dossier contient des modèles de fichiers de configuration pour les modes Roo et d'autres paramètres associés.

## Fichiers disponibles

### Fichiers de configuration principaux

- **`config.json`** - Configuration générale de Roo
- **`modes.json`** - Configuration des modes Roo
- **`servers.json`** - Configuration des serveurs MCP

### Fichiers de modèles

- **`model-configs.json`** - Configuration des modèles de langage
- **`model-configs-fixed.json`** - Version corrigée de la configuration des modèles

## Utilisation

Ces fichiers servent de modèles pour configurer Roo. Ils peuvent être utilisés comme base pour créer vos propres configurations ou pour restaurer les configurations par défaut.

### Configuration des modes

Le fichier `modes.json` contient la configuration des différents modes Roo (Code, Debug, Architect, Ask, Orchestrator). Vous pouvez l'utiliser comme base pour créer vos propres modes personnalisés.

### Configuration des serveurs

Le fichier `servers.json` contient la configuration des serveurs MCP (Model Context Protocol) utilisés par Roo. Vous pouvez l'utiliser comme base pour configurer vos propres serveurs MCP.

### Configuration des modèles

Les fichiers `model-configs.json` et `model-configs-fixed.json` contiennent la configuration des modèles de langage utilisés par Roo. Le fichier `model-configs-fixed.json` est une version corrigée avec un encodage approprié.

## Déploiement

Pour déployer ces configurations, utilisez les scripts du dossier `deployment-scripts`. Par exemple :

```powershell
..\deployment-scripts\deploy-modes-simple-complex.ps1
```

## Remarques

- Ces fichiers sont des modèles et peuvent nécessiter des ajustements selon votre environnement
- Assurez-vous que les fichiers JSON sont valides avant de les déployer
- Utilisez les scripts de diagnostic pour vérifier l'encodage des fichiers avant déploiement
- Consultez le [guide d'import/export](../docs/guide-import-export.md) pour plus d'informations sur la gestion des configurations
# Guide de construction locale de l'image Docker MCP Server

Ce guide explique comment utiliser le script PowerShell fourni pour construire localement l'image Docker du MCP Server de ckreiling et l'intégrer à votre configuration Roo.

## Prérequis

Avant d'exécuter le script, assurez-vous que les éléments suivants sont installés et configurés sur votre système :

- **Docker** : Installé et en cours d'exécution
- **Git** : Installé et accessible depuis la ligne de commande
- **PowerShell** : Version 5.1 ou supérieure

## Fonctionnalités du script

Le script `build-mcp-server-docker.ps1` automatise les tâches suivantes :

1. **Vérification des prérequis** : S'assure que Docker et Git sont installés et que Docker est en cours d'exécution
2. **Clonage du dépôt** : Clone le dépôt GitHub de ckreiling/mcp-server-docker
3. **Construction de l'image Docker** : Construit l'image Docker localement
4. **Vérification de l'image** : S'assure que l'image a été correctement construite
5. **Mise à jour de la configuration MCP** : Met à jour votre configuration Roo pour utiliser cette image locale

## Utilisation du script

1. Ouvrez PowerShell en tant qu'administrateur
2. Naviguez vers le répertoire contenant le script
3. Exécutez le script :

```powershell
.\build-mcp-server-docker.ps1
```

4. Suivez les instructions à l'écran

## Configuration manuelle

Si vous préférez ne pas mettre à jour automatiquement votre configuration MCP, vous pouvez ajouter manuellement la configuration suivante à votre fichier `servers.json` :

```json
{
  "mcpServers": [
    {
      "name": "mcp-server-local",
      "type": "stdio",
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-v",
        "${workspaceFolder}:/workspace",
        "mcp-server-docker:latest"
      ]
    }
  ]
}
```

## Dépannage

### Erreur "Docker n'est pas en cours d'exécution"

**Solution** : Démarrez Docker Desktop ou le service Docker selon votre système d'exploitation.

### Erreur "Git n'est pas trouvé"

**Solution** : Installez Git et assurez-vous qu'il est dans votre PATH.

### Erreur de construction de l'image

**Solution** : Vérifiez votre connexion internet et les logs Docker pour plus de détails.

## Liens utiles

- [Dépôt original ckreiling/mcp-server-docker](https://github.com/ckreiling/mcp-server-docker)
- [Documentation Docker](https://docs.docker.com/)
- [Guide d'installation Docker](./INSTALLATION.md)
- [Guide de configuration](./CONFIGURATION.md)

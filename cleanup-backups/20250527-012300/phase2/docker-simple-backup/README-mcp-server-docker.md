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
        "/var/run/docker.sock:/var/run/docker.sock",
        "mcp-server:local"
      ],
      "enabled": true,
      "autoStart": true,
      "description": "Serveur MCP local construit à partir de mcp-server:local"
    }
  ]
}
```

Notez que la configuration de Roo utilise `mcpServers` comme clé principale au lieu de `servers` qui était utilisé par Claude.

## Personnalisation

Vous pouvez personnaliser le script en modifiant les variables suivantes au début de la fonction `Main` :

- `$repoUrl` : URL du dépôt GitHub à cloner
- `$repoPath` : Chemin local où cloner le dépôt
- `$imageName` : Nom de l'image Docker à construire
- `$imageTag` : Tag de l'image Docker
- `$serverName` : Nom du serveur MCP dans la configuration
- `$mcpConfigPath` : Chemin vers le fichier de configuration MCP

## Résolution des problèmes

Si vous rencontrez des problèmes lors de l'exécution du script, voici quelques solutions possibles :

- **Docker n'est pas en cours d'exécution** : Démarrez Docker Desktop ou le service Docker
- **Erreur de clonage du dépôt** : Vérifiez votre connexion Internet et que l'URL du dépôt est correcte
- **Erreur de construction de l'image** : Vérifiez que Docker a suffisamment de ressources (mémoire, espace disque)
- **Erreur de mise à jour de la configuration** : Vérifiez que le chemin vers le fichier de configuration MCP est correct

## Montage du socket Docker

Le MCP Server Docker de ckreiling nécessite l'accès au socket Docker de l'hôte pour fonctionner correctement. C'est pourquoi le script monte automatiquement le socket Docker (`/var/run/docker.sock`) dans le conteneur. Ce montage est essentiel car il permet au MCP Server de communiquer avec le démon Docker de l'hôte et d'exécuter des commandes Docker à l'intérieur du conteneur.

Sans ce montage, le MCP Server ne pourrait pas interagir avec Docker, ce qui limiterait considérablement ses fonctionnalités.

## Remarques importantes

- Le script crée une image Docker nommée `mcp-server:local` par défaut
- La configuration MCP est mise à jour uniquement si vous répondez "O" à la question correspondante
- Si le fichier de configuration MCP n'est pas trouvé à l'emplacement par défaut, le script vous demandera de spécifier son chemin
- Le script est configuré pour fonctionner avec Roo (utilisant `mcpServers` dans la configuration) au lieu de Claude

## Utilisation avancée

Pour utiliser l'image Docker manuellement, exécutez :

```powershell
docker run -i --rm -v /var/run/docker.sock:/var/run/docker.sock mcp-server:local
```

Pour reconstruire l'image après des modifications du dépôt, il suffit de réexécuter le script.
# Serveur MCP Jupyter

## Description

Jupyter MCP est un serveur MCP (Model Context Protocol) qui permet l'interaction avec des notebooks Jupyter. Il offre aux modèles de langage la capacité de créer, lire, modifier et exécuter des notebooks Jupyter, facilitant ainsi l'analyse de données et l'exécution de code Python.

## Fonctionnalités principales

- Lecture et écriture de notebooks Jupyter
- Création de nouveaux notebooks
- Ajout, suppression et modification de cellules
- Exécution de code dans des kernels Jupyter
- Gestion des kernels (démarrage, arrêt, redémarrage)

## Installation

Le serveur Jupyter MCP est intégré en tant que sous-module Git dans le projet roo-extensions. Cependant, pour l'utiliser pleinement, vous devez avoir Python et Jupyter installés sur votre système.

### Prérequis

1. Python 3.6 ou supérieur
2. Jupyter Notebook ou JupyterLab
3. Node.js 14.x ou supérieur

### Installation de Jupyter

Si vous n'avez pas encore Jupyter installé, vous pouvez l'installer avec pip:

```bash
pip install notebook
```

## Démarrage

Pour démarrer le serveur Jupyter MCP, exécutez le script batch suivant:

```batch
mcps/jupyter/run-jupyter.bat
```

Alternativement, le serveur peut être démarré via la configuration dans `roo-config/settings/servers.json`.

## Configuration

La configuration du serveur Jupyter MCP se fait dans le fichier `roo-config/settings/servers.json`. Voici un exemple de configuration:

```json
{
  "name": "jupyter",
  "type": "stdio",
  "command": "cmd /c node c:/dev/roo-extensions/mcps/mcp-servers/servers/jupyter-mcp-server/dist/index.js",
  "enabled": true,
  "autoStart": false,
  "description": "Serveur MCP pour interagir avec des notebooks Jupyter"
}
```

**Note**: L'option `autoStart` est définie sur `false` par défaut car ce serveur nécessite que Jupyter soit correctement installé et configuré sur le système.

## Utilisation

Le serveur Jupyter MCP expose plusieurs outils qui peuvent être utilisés par les modèles de langage:

### read_notebook

Lit un notebook Jupyter à partir d'un fichier.

### write_notebook

Écrit un notebook Jupyter dans un fichier.

### create_notebook

Crée un nouveau notebook vide avec un kernel spécifié.

### add_cell

Ajoute une cellule à un notebook existant.

### remove_cell

Supprime une cellule d'un notebook.

### update_cell

Modifie le contenu d'une cellule existante.

### list_kernels

Liste les kernels Jupyter disponibles et actifs.

### start_kernel

Démarre un nouveau kernel Jupyter.

### execute_cell

Exécute du code dans un kernel spécifique.

### execute_notebook

Exécute toutes les cellules de code d'un notebook.

## Dépannage

Si vous rencontrez des problèmes avec le serveur Jupyter MCP:

1. Vérifiez que Python et Jupyter sont correctement installés
2. Assurez-vous que le chemin dans le script de démarrage est correct
3. Vérifiez que les kernels Jupyter sont disponibles (`jupyter kernelspec list`)
4. Consultez les logs pour identifier d'éventuelles erreurs

## Limitations connues

- L'exécution de code peut prendre du temps, surtout pour des opérations complexes
- Certaines fonctionnalités interactives de Jupyter peuvent ne pas être disponibles
- Les widgets Jupyter ne sont pas entièrement supportés

## Ressources additionnelles

Pour plus d'informations sur l'utilisation des serveurs MCP, consultez le guide d'utilisation général des MCPs dans `docs/guide-utilisation-mcps.md`.

Pour la documentation de Jupyter, consultez [la documentation officielle de Jupyter](https://jupyter.org/documentation).
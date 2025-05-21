# MCP Jupyter pour Roo

Ce répertoire contient les scripts et la documentation pour l'intégration du MCP Jupyter avec Roo, avec un accent particulier sur l'intégration avec VSCode.

## Table des matières

- [MCP Jupyter pour Roo](#mcp-jupyter-pour-roo)
  - [Table des matières](#table-des-matières)
  - [Introduction](#introduction)
    - [Architecture](#architecture)
  - [Intégration avec VSCode](#intégration-avec-vscode)
    - [Comment fonctionne l'intégration VSCode](#comment-fonctionne-lintégration-vscode)
    - [Avantages de l'intégration VSCode](#avantages-de-lintégration-vscode)
    - [Prérequis pour l'intégration VSCode](#prérequis-pour-lintégration-vscode)
    - [Configuration de l'intégration VSCode](#configuration-de-lintégration-vscode)
  - [Configurations disponibles](#configurations-disponibles)
  - [Scripts disponibles](#scripts-disponibles)
    - [Scripts de démarrage](#scripts-de-démarrage)
    - [Scripts de configuration](#scripts-de-configuration)
  - [Tests](#tests)
    - [Exécution des tests](#exécution-des-tests)
  - [Problèmes connus et solutions](#problèmes-connus-et-solutions)
    - [Problème: Aucun kernel VSCode détecté](#problème-aucun-kernel-vscode-détecté)
    - [Problème: Erreurs de connexion au serveur Jupyter](#problème-erreurs-de-connexion-au-serveur-jupyter)
    - [Problème: Échec de l'exécution de code](#problème-échec-de-lexécution-de-code)
    - [Problème: Timeout lors du démarrage du serveur MCP Jupyter](#problème-timeout-lors-du-démarrage-du-serveur-mcp-jupyter)
  - [Ressources supplémentaires](#ressources-supplémentaires)

## Introduction

Le MCP Jupyter est un serveur qui implémente le protocole Model Context Protocol (MCP) pour permettre à Roo d'interagir avec Jupyter Notebook. Il sert d'intermédiaire entre Roo et un serveur Jupyter, traduisant les requêtes MCP en appels API Jupyter et vice versa.

### Architecture

```
┌─────────┐     ┌───────────────┐     ┌─────────────────┐
│   Roo   │◄────┤  MCP Jupyter  │◄────┤ Serveur Jupyter │
└─────────┘     └───────────────┘     └─────────────────┘
                       │
                       ▼
                ┌─────────────┐
                │ config.json │
                └─────────────┘
```

Le MCP Jupyter peut fonctionner dans différents modes:
- **Mode connecté**: Communique avec un serveur Jupyter existant
- **Mode hors ligne**: Fonctionne sans serveur Jupyter, avec des fonctionnalités limitées
- **Mode VSCode**: Utilise les kernels Jupyter intégrés à VSCode

## Intégration avec VSCode

L'intégration avec VSCode permet au MCP Jupyter d'utiliser les kernels Jupyter déjà installés et configurés dans VSCode, offrant une expérience plus fluide et évitant la nécessité de configurer manuellement un serveur Jupyter séparé.

### Comment fonctionne l'intégration VSCode

1. **Détection des kernels**: Le script d'intégration VSCode détecte automatiquement les kernels Jupyter disponibles dans les extensions VSCode (principalement les extensions Python et Jupyter).

2. **Configuration automatique**: Le script configure automatiquement le MCP Jupyter pour utiliser ces kernels, en générant un fichier de configuration approprié.

3. **Mode adaptatif**: Si des kernels VSCode sont détectés, le MCP Jupyter démarre en mode VSCode. Sinon, il démarre en mode hors ligne pour éviter les erreurs.

4. **Utilisation transparente**: Une fois configuré, le MCP Jupyter peut être utilisé normalement par Roo, sans que l'utilisateur ait besoin de connaître les détails de l'intégration.

### Avantages de l'intégration VSCode

- **Configuration simplifiée**: Pas besoin de configurer manuellement un serveur Jupyter
- **Réutilisation des environnements**: Utilise les environnements Python déjà configurés dans VSCode
- **Meilleure stabilité**: Évite les problèmes de connexion au démarrage
- **Expérience utilisateur améliorée**: Intégration transparente avec l'environnement de développement
- **Isolation des environnements**: Chaque kernel VSCode est isolé, ce qui évite les conflits entre les différents projets
- **Mise à jour automatique**: Les kernels sont automatiquement mis à jour lorsque vous mettez à jour vos extensions VSCode

### Prérequis pour l'intégration VSCode

Pour utiliser l'intégration VSCode avec le MCP Jupyter, vous devez avoir installé les extensions suivantes dans VSCode:

1. **Extension Python pour VSCode**: Cette extension est nécessaire pour la détection des environnements Python.
   - Installez-la depuis le marketplace VSCode: [Python Extension](https://marketplace.visualstudio.com/items?itemName=ms-python.python)

2. **Extension Jupyter pour VSCode**: Cette extension fournit les fonctionnalités Jupyter dans VSCode.
   - Installez-la depuis le marketplace VSCode: [Jupyter Extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter)

3. **Au moins un environnement Python configuré**: Vous devez avoir au moins un environnement Python configuré dans VSCode.
   - Utilisez la commande "Python: Select Interpreter" dans VSCode pour configurer un interpréteur Python

### Configuration de l'intégration VSCode

1. **Démarrage automatique**:
   - Utilisez le script `start-jupyter-mcp-vscode.bat` pour démarrer automatiquement le MCP Jupyter avec l'intégration VSCode.
   - Ce script détecte les kernels disponibles et configure le MCP Jupyter en conséquence.

2. **Configuration manuelle**:
   - Si vous préférez configurer manuellement l'intégration, vous pouvez modifier le fichier `config.json` dans le répertoire du MCP Jupyter.
   - Ajoutez les kernels VSCode que vous souhaitez utiliser dans la section `kernels` du fichier de configuration.

3. **Vérification de l'intégration**:
   - Pour vérifier que l'intégration fonctionne correctement, exécutez le script de test `test-jupyter-vscode-integration.js`.
   - Ce script teste la détection des kernels, la connexion du MCP Jupyter aux kernels VSCode et l'exécution de code simple.

## Configurations disponibles

Le MCP Jupyter peut être configuré de différentes manières pour s'adapter à différents cas d'utilisation. Pour une documentation détaillée des configurations disponibles, consultez le fichier [configurations-jupyter-mcp.md](./configurations-jupyter-mcp.md).

Les principales configurations sont:

1. **Mode hors ligne** (`offline: true`)
   - Fonctionne sans serveur Jupyter
   - Fonctionnalités limitées, mais démarrage stable

2. **Serveur local sur le port 8888**
   - Configuration standard pour Jupyter Notebook/JupyterLab
   - Compatible avec les installations par défaut

3. **Serveur local sur le port 8890**
   - Évite les conflits avec le port par défaut
   - Idéal pour les environnements multi-utilisateurs

4. **Serveur HTTP dédié sur le port 8891**
   - Isolation complète du serveur Jupyter
   - Personnalisation maximale

## Scripts disponibles

### Scripts de démarrage

- **[start-jupyter-mcp-vscode.bat](./start-jupyter-mcp-vscode.bat)**: Démarre le MCP Jupyter avec l'intégration VSCode
  - Détecte automatiquement les kernels VSCode
  - Configure le MCP Jupyter en conséquence
  - Démarre en mode hors ligne si aucun kernel n'est trouvé

- **[start-jupyter-mcp-offline.bat](../scripts/mcp-starters/start-jupyter-mcp-offline.bat)**: Démarre le MCP Jupyter en mode hors ligne
  - Aucune tentative de connexion à un serveur Jupyter
  - Fonctionnalités limitées, mais démarrage stable

### Scripts de configuration

- **[sync-mcp-config.ps1](../scripts/sync-mcp-config.ps1)**: Synchronise la configuration du MCP Jupyter avec d'autres configurations
  - Utile pour maintenir la cohérence entre différents environnements

## Tests

Plusieurs scripts de test sont disponibles pour vérifier le bon fonctionnement du MCP Jupyter:

- **[test-jupyter-vscode-integration.js](../../tests/mcp/test-jupyter-vscode-integration.js)**: Teste l'intégration avec VSCode
  - Détection des kernels VSCode
  - Connexion du MCP Jupyter aux kernels VSCode
  - Exécution de code simple via cette intégration

- **[test-jupyter-connection.js](../../tests/mcp/test-jupyter-connection.js)**: Teste la connexion au serveur Jupyter

- **[test-jupyter-mcp-offline.js](../../tests/mcp/test-jupyter-mcp-offline.js)**: Teste le mode hors ligne

- **[test-jupyter-mcp-switch-offline.js](../../tests/mcp/test-jupyter-mcp-switch-offline.js)**: Teste le passage entre les modes connecté et hors ligne

### Exécution des tests

Pour exécuter les tests, utilisez les commandes suivantes:

```bash
# Test de l'intégration VSCode
node tests/mcp/test-jupyter-vscode-integration.js

# Test de la connexion au serveur Jupyter
node tests/mcp/test-jupyter-connection.js

# Test du mode hors ligne
node tests/mcp/test-jupyter-mcp-offline.js

# Test du passage entre les modes
node tests/mcp/test-jupyter-mcp-switch-offline.js
```

## Problèmes connus et solutions

### Problème: Aucun kernel VSCode détecté

**Symptômes**: Le script d'intégration VSCode ne trouve aucun kernel.

**Solutions**:
1. Vérifiez que l'extension Python pour VSCode est installée
2. Vérifiez que l'extension Jupyter pour VSCode est installée
3. Créez au moins un environnement Python dans VSCode
4. Exécutez la commande "Python: Select Interpreter" dans VSCode pour configurer l'interpréteur
5. Vérifiez que les chemins d'accès aux extensions VSCode sont corrects dans le script `detect-vscode-kernels.ps1`
6. Redémarrez VSCode pour s'assurer que les extensions sont correctement chargées

### Problème: Erreurs de connexion au serveur Jupyter

**Symptômes**: Le MCP Jupyter ne parvient pas à se connecter au serveur Jupyter.

**Solutions**:
1. Vérifiez que le serveur Jupyter est en cours d'exécution sur le port configuré
2. Vérifiez que le token dans la configuration correspond au token du serveur Jupyter
3. Essayez d'utiliser le mode hors ligne pour isoler les problèmes
4. Vérifiez les pare-feu ou autres restrictions réseau
5. Si vous utilisez l'intégration VSCode, assurez-vous que les extensions VSCode sont correctement installées
6. Vérifiez les logs du serveur MCP Jupyter pour plus d'informations sur l'erreur

### Problème: Échec de l'exécution de code

**Symptômes**: L'exécution de code via le MCP Jupyter échoue.

**Solutions**:
1. Vérifiez que le kernel est correctement démarré
2. Vérifiez que les dépendances nécessaires sont installées dans l'environnement Python
3. Consultez les logs du serveur Jupyter pour plus d'informations
4. Essayez d'exécuter le même code directement dans Jupyter Notebook pour isoler le problème
5. Si vous utilisez l'intégration VSCode, vérifiez que le kernel VSCode fonctionne correctement dans VSCode
6. Essayez de redémarrer le serveur MCP Jupyter avec le script `start-jupyter-mcp-vscode.bat`

### Problème: Timeout lors du démarrage du serveur MCP Jupyter

**Symptômes**: Le script de test ou le démarrage du serveur MCP Jupyter échoue avec un timeout.

**Solutions**:
1. Augmentez la valeur du timeout dans le script de test ou de démarrage
2. Vérifiez que le serveur MCP Jupyter n'est pas déjà en cours d'exécution
3. Vérifiez les logs du serveur pour identifier d'éventuelles erreurs
4. Essayez de démarrer le serveur en mode hors ligne pour isoler les problèmes
5. Vérifiez que les ports utilisés ne sont pas déjà occupés par d'autres applications

## Ressources supplémentaires

- [Documentation principale du MCP Jupyter](../mcp-servers/README-JUPYTER-MCP.md)
- [Documentation du mode hors ligne](../mcp-servers/docs/jupyter-mcp-offline-mode.md)
- [Documentation des tests de connexion](../mcp-servers/docs/jupyter-mcp-connection-test.md)
- [Guide de dépannage](./troubleshooting.md)
- [Documentation des configurations](./configurations-jupyter-mcp.md)
- [Documentation de l'API Jupyter](https://jupyter-client.readthedocs.io/en/stable/api/index.html)
- [Documentation de l'extension Jupyter pour VSCode](https://code.visualstudio.com/docs/datascience/jupyter-notebooks)
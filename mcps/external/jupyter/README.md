# MCP Jupyter pour Roo

<!-- START_SECTION: introduction -->
## Introduction

Le MCP Jupyter permet à Roo d'interagir avec des notebooks Jupyter, offrant des fonctionnalités pour la lecture, la modification et l'exécution de notebooks via le protocole Model Context Protocol (MCP). Cette intégration permet à Roo d'analyser, de créer et d'exécuter du code dans divers langages de programmation supportés par Jupyter.

Ce MCP est particulièrement utile pour les utilisateurs qui travaillent avec des notebooks Jupyter pour l'analyse de données, la visualisation, le machine learning, et d'autres tâches de programmation interactive.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: features -->
## Fonctionnalités principales

- **Gestion des notebooks** :
  - Lecture de notebooks existants
  - Création de nouveaux notebooks
  - Modification de notebooks (ajout, suppression, mise à jour de cellules)
  - Sauvegarde de notebooks

- **Gestion des kernels** :
  - Démarrage de kernels dans différents langages (Python, R, Julia, etc.)
  - Arrêt et redémarrage de kernels
  - Interruption de l'exécution
  - Listing des kernels disponibles et actifs

- **Exécution de code** :
  - Exécution de cellules individuelles
  - Exécution de notebooks complets
  - Récupération des résultats d'exécution (texte, images, HTML, etc.)
  - Gestion des erreurs d'exécution

- **Support multi-langages** :
  - Python
  - R
  - Julia
  - JavaScript (via IJavaScript)
  - Et tous les autres langages supportés par Jupyter
<!-- END_SECTION: features -->

<!-- START_SECTION: tools -->
## Outils disponibles

Le MCP Jupyter expose les outils suivants:

| Outil | Description |
|-------|-------------|
| `read_notebook` | Lit un notebook Jupyter à partir d'un fichier |
| `write_notebook` | Écrit un notebook Jupyter dans un fichier |
| `create_notebook` | Crée un nouveau notebook vide |
| `add_cell` | Ajoute une cellule à un notebook |
| `remove_cell` | Supprime une cellule d'un notebook |
| `update_cell` | Modifie une cellule d'un notebook |
| `list_kernels` | Liste les kernels disponibles et actifs |
| `start_kernel` | Démarre un nouveau kernel |
| `stop_kernel` | Arrête un kernel actif |
| `interrupt_kernel` | Interrompt l'exécution d'un kernel |
| `restart_kernel` | Redémarre un kernel |
| `execute_cell` | Exécute du code dans un kernel spécifique |
| `execute_notebook` | Exécute toutes les cellules de code d'un notebook |
| `execute_notebook_cell` | Exécute une cellule spécifique d'un notebook |

Pour une description détaillée de chaque outil et des exemples d'utilisation, consultez le fichier [USAGE.md](./USAGE.md).
<!-- END_SECTION: tools -->

<!-- START_SECTION: structure -->
## Structure de la documentation

- [README.md](./README.md) - Ce fichier d'introduction
- [INSTALLATION.md](./INSTALLATION.md) - Guide d'installation du MCP Jupyter
- [CONFIGURATION.md](./CONFIGURATION.md) - Guide de configuration du MCP Jupyter
- [USAGE.md](./USAGE.md) - Exemples d'utilisation et bonnes pratiques
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Résolution des problèmes courants
<!-- END_SECTION: structure -->

<!-- START_SECTION: quick_start -->
## Démarrage rapide

1. **Prérequis** :
   - Node.js (v14 ou supérieur)
   - Python (v3.6 ou supérieur)
   - Jupyter Notebook ou JupyterLab

2. **Installation de Jupyter** :
   ```bash
   # Créer un environnement virtuel Python
   python -m venv jupyter-env
   
   # Activer l'environnement virtuel
   # Sur Windows
   jupyter-env\Scripts\activate
   # Sur macOS/Linux
   source jupyter-env/bin/activate
   
   # Installer Jupyter
   pip install jupyter
   ```

3. **Démarrage du serveur Jupyter** :
   ```bash
   # Sur Windows
   jupyter notebook --no-browser
   # Sur macOS/Linux
   jupyter notebook --no-browser
   ```

4. **Installation du MCP Jupyter** :
   ```bash
   # Via NPX (recommandé)
   npx -y @modelcontextprotocol/server-jupyter
   
   # Ou installation globale
   npm install -g @modelcontextprotocol/server-jupyter
   ```

5. **Configuration** :
   Ajoutez la configuration suivante à votre fichier `mcp_settings.json`:
   ```json
   {
     "mcpServers": {
       "jupyter": {
         "command": "cmd",
         "args": ["/c", "npx", "-y", "@modelcontextprotocol/server-jupyter"],
         "transportType": "stdio",
         "disabled": false
       }
     }
   }
   ```

6. **Utilisation** :
   Redémarrez VS Code et commencez à utiliser les outils Jupyter dans Roo.

Pour des instructions détaillées, consultez les fichiers [INSTALLATION.md](./INSTALLATION.md) et [CONFIGURATION.md](./CONFIGURATION.md).
<!-- END_SECTION: quick_start -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

Le MCP Jupyter est particulièrement utile pour:

- **Analyse de données** : Exécuter des analyses de données avec pandas, numpy, etc.
- **Visualisation** : Créer des visualisations avec matplotlib, seaborn, plotly, etc.
- **Machine Learning** : Développer et tester des modèles ML avec scikit-learn, TensorFlow, PyTorch, etc.
- **Éducation** : Créer et exécuter des notebooks éducatifs
- **Documentation interactive** : Créer des documents combinant code, texte et visualisations
- **Prototypage rapide** : Tester rapidement des idées et des algorithmes
- **Reporting automatisé** : Générer des rapports basés sur des données

Pour des exemples détaillés, consultez le fichier [USAGE.md](./USAGE.md#cas-dutilisation).
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: kernel_comparison -->
## Comparaison des kernels

Le MCP Jupyter prend en charge plusieurs kernels, chacun ayant ses propres avantages:

### Python

Python est recommandé pour:
- Analyse de données et science des données
- Machine learning et deep learning
- Visualisation de données
- Automatisation et scripting

Exemple:
```
Outil: execute_cell
Arguments:
{
  "kernel_id": "kernel-id-1",
  "code": "import pandas as pd\nimport matplotlib.pyplot as plt\n\ndf = pd.DataFrame({'x': range(10), 'y': [i**2 for i in range(10)]})\ndf.plot(x='x', y='y')\nplt.show()"
}
```

### R

R est recommandé pour:
- Statistiques avancées
- Visualisation de données avec ggplot2
- Analyse biostatistique
- Économétrie

Exemple:
```
Outil: execute_cell
Arguments:
{
  "kernel_id": "kernel-id-2",
  "code": "library(ggplot2)\ndf <- data.frame(x = 1:10, y = (1:10)^2)\nggplot(df, aes(x = x, y = y)) + geom_point() + geom_line()"
}
```

### Julia

Julia est recommandé pour:
- Calcul scientifique haute performance
- Algèbre linéaire
- Statistiques
- Machine learning

Exemple:
```
Outil: execute_cell
Arguments:
{
  "kernel_id": "kernel-id-3",
  "code": "using Plots\nx = 1:10\ny = x.^2\nplot(x, y, label=\"y = x²\", marker=:circle)"
}
```

### JavaScript (via IJavaScript)

JavaScript est recommandé pour:
- Visualisations web interactives
- Manipulation du DOM
- Intégration avec des APIs web
- Prototypage front-end

Exemple:
```
Outil: execute_cell
Arguments:
{
  "kernel_id": "kernel-id-4",
  "code": "const data = Array.from({length: 10}, (_, i) => ({x: i, y: i*i}));\nconsole.table(data);"
}
```
<!-- END_SECTION: kernel_comparison -->

<!-- START_SECTION: security -->
## Considérations de sécurité

L'utilisation du MCP Jupyter implique certains risques de sécurité qu'il est important de prendre en compte:

- **Exécution de code arbitraire** : Jupyter permet d'exécuter du code arbitraire, ce qui peut être dangereux si utilisé sans précaution
- **Accès aux ressources système** : Le code exécuté dans Jupyter a accès aux ressources système (fichiers, réseau, etc.)
- **Exposition de données sensibles** : Les notebooks peuvent contenir des données sensibles
- **Vulnérabilités des dépendances** : Les packages utilisés dans les notebooks peuvent contenir des vulnérabilités

Pour une utilisation sécurisée:
- Limitez les permissions du processus Jupyter
- Utilisez des environnements virtuels isolés
- Évitez d'exécuter des notebooks provenant de sources non fiables
- Maintenez à jour Jupyter et ses dépendances
- Utilisez des tokens d'authentification pour sécuriser l'accès au serveur Jupyter

Pour plus de détails sur la sécurité, consultez le fichier [SECURITY.md](./SECURITY.md).
<!-- END_SECTION: security -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

Si vous rencontrez des problèmes avec le MCP Jupyter:

- **Le serveur ne démarre pas** : Vérifiez l'installation de Node.js, Python et Jupyter
- **Erreurs de connexion au kernel** : Vérifiez que le serveur Jupyter est en cours d'exécution
- **Erreurs d'exécution de code** : Vérifiez la syntaxe et les dépendances requises
- **Problèmes de mémoire** : Limitez la taille des sorties et utilisez des techniques de streaming pour les données volumineuses
- **Timeouts** : Augmentez les valeurs de timeout pour les opérations longues

Pour une résolution plus détaillée des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: integration -->
## Intégration avec Roo

Le MCP Jupyter s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Crée un nouveau notebook Python pour analyser ce dataset"
- "Exécute cette cellule de code et montre-moi les résultats"
- "Ajoute une cellule qui génère un graphique de ces données"
- "Explique ce que fait ce code dans le notebook"
- "Modifie cette fonction pour améliorer ses performances"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP Jupyter.
<!-- END_SECTION: integration -->

<!-- START_SECTION: monitoring -->
## Surveillance et diagnostic

Le MCP Jupyter est intégré au système de surveillance des serveurs MCP, ce qui permet de:

- Détecter automatiquement les problèmes avec le serveur Jupyter
- Redémarrer automatiquement le serveur en cas de panne
- Collecter des métriques de performance
- Générer des alertes en cas de problèmes persistants

Pour surveiller le serveur MCP Jupyter:

```powershell
# Surveillance simple
.\mcps\monitoring\monitor-mcp-servers.ps1

# Surveillance avec redémarrage automatique
.\mcps\monitoring\monitor-mcp-servers.ps1 -RestartServers
```

Pour plus d'informations sur le système de surveillance, consultez la [documentation dédiée](../monitoring/README.md).
<!-- END_SECTION: monitoring -->

<!-- START_SECTION: links -->
## Liens utiles

- [Documentation officielle de Jupyter](https://jupyter.org/documentation)
- [Documentation de JupyterLab](https://jupyterlab.readthedocs.io/)
- [Documentation de nbformat](https://nbformat.readthedocs.io/)
- [Documentation de @jupyterlab/services](https://jupyterlab.github.io/jupyterlab/services/)
- [Documentation du protocole MCP](https://github.com/modelcontextprotocol/protocol)
<!-- END_SECTION: links -->
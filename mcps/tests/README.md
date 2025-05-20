# Tests des serveurs MCP

Ce répertoire contient des scripts de test pour vérifier le bon fonctionnement des serveurs MCP (Model Context Protocol) internes et externes.

## Structure des tests

- `test-quickfiles.js` : Tests pour le MCP QuickFiles
- `test-jinavigator.js` : Tests pour le MCP JinaNavigator
- `test-jupyter.js` : Tests pour le MCP Jupyter
- `test_mcp_jupyter.ipynb` : Notebook Jupyter pour tester le MCP Jupyter
- `run-all-tests.ps1` : Script PowerShell pour exécuter tous les tests
- `reports/` : Répertoire contenant les rapports de test générés (derniers rapports de mai 2025)

## Prérequis

- **Node.js** : Version 14.x ou supérieure
- **PowerShell** : Version 5.0 ou supérieure (pour exécuter le script `run-all-tests.ps1`)
- **Serveurs MCP** : Les serveurs MCP à tester doivent être installés et configurés
- **Jupyter** : Jupyter Notebook doit être installé pour les tests du MCP Jupyter

## Exécution des tests

### Tester un MCP spécifique

Pour tester un MCP spécifique, exécutez le script de test correspondant :

```bash
# Test du MCP QuickFiles
node test-quickfiles.js

# Test du MCP JinaNavigator
node test-jinavigator.js

# Test du MCP Jupyter
node test-jupyter.js
```

### Exécuter tous les tests

Pour exécuter tous les tests et générer un rapport global, utilisez le script PowerShell :

```powershell
.\run-all-tests.ps1
```

## Rapports de test

Chaque script de test génère un rapport au format Markdown dans le répertoire `reports/`. Le script `run-all-tests.ps1` génère également un rapport global qui résume les résultats de tous les tests.

Les rapports contiennent les informations suivantes :
- Date et heure d'exécution des tests
- Résumé des tests (nombre de tests réussis/échoués)
- Détails des tests exécutés
- Messages d'erreur éventuels
- Recommandations pour résoudre les problèmes identifiés

### Rapports récents

Les rapports de test les plus récents (mai 2025) sont disponibles dans le répertoire `reports/` :
- `quickfiles-test-report-2025-05-16T16-23-50.193Z.md`
- `jinavigator-test-report-2025-05-16T16-34-50.303Z.md`
- `jupyter-test-report-2025-05-16T16-24-05.138Z.md`

## Fonctionnalités testées

### MCP QuickFiles

- Installation et configuration
- Accès au serveur
- Lecture de fichiers multiples
- Listage de répertoires
- Édition de fichiers multiples
- Suppression de fichiers
- Extraction de structure Markdown
- Recherche dans les fichiers
- Recherche et remplacement
- Intégration avec Roo

### MCP JinaNavigator

- Installation et configuration
- Accès au serveur
- Conversion de pages web en Markdown
- Accès aux ressources Jina
- Conversion multiple de pages web
- Extraction de plans Markdown
- Gestion des erreurs et des timeouts
- Intégration avec Roo

### MCP Jupyter

- Installation et configuration
- Accès au serveur
- Création de notebooks
- Lecture de notebooks
- Ajout de cellules
- Mise à jour de cellules
- Suppression de cellules
- Exécution de cellules
- Gestion des kernels
- Intégration avec Roo

## Mode hors ligne

Les tests sont conçus pour fonctionner en mode hors ligne autant que possible, ce qui permet de les exécuter sans dépendances externes. Cependant, certains tests peuvent nécessiter une connexion Internet ou des services externes :

- Les tests JinaNavigator nécessitent un accès Internet pour convertir des pages web
- Les tests Jupyter nécessitent une installation locale de Jupyter Notebook

## Personnalisation des tests

Vous pouvez personnaliser les tests en modifiant les fichiers de test correspondants. Par exemple, vous pouvez :

- Modifier les chemins des serveurs MCP dans les variables de configuration
- Ajouter de nouveaux tests en suivant le modèle des tests existants
- Modifier les paramètres de test pour cibler des fonctionnalités spécifiques
- Ajuster les timeouts pour les environnements plus lents

## Dépannage

Si les tests échouent, vérifiez les points suivants :

1. Assurez-vous que les serveurs MCP sont correctement installés et configurés
2. Vérifiez que les serveurs MCP sont accessibles (ports ouverts, services démarrés)
3. Consultez les rapports de test pour plus de détails sur les erreurs spécifiques
4. Vérifiez les journaux des serveurs MCP pour détecter d'éventuelles erreurs
5. Assurez-vous que les dépendances requises sont installées et à jour
6. Vérifiez les problèmes d'encodage potentiels (voir [test-encodage.md](../../tests/test-encodage.md))

## Intégration avec les autres tests

Ces tests MCP sont complémentaires aux tests disponibles dans le répertoire principal [tests/](../../tests/). Ils se concentrent sur les fonctionnalités spécifiques de chaque serveur MCP, tandis que les tests dans le répertoire principal se concentrent sur la structure et la conformité des serveurs MCP.

Pour une vue d'ensemble complète des tests du projet, consultez le [README des tests](../../tests/README.md).

## Ajout de nouveaux tests

Pour ajouter un test pour un nouveau MCP, suivez ces étapes :

1. Créez un nouveau fichier de test en suivant le modèle des fichiers existants
2. Définissez les fonctionnalités à tester et les cas de test
3. Implémentez les tests avec des assertions claires
4. Ajoutez la génération de rapport au format Markdown
5. Ajoutez le nouveau test à la liste des scripts de test dans `run-all-tests.ps1`
6. Mettez à jour ce README.md pour documenter le nouveau MCP testé
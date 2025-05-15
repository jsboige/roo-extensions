# Tests des serveurs MCP

Ce répertoire contient des scripts de test pour vérifier le bon fonctionnement des serveurs MCP (Model Context Protocol) internes et externes.

## Structure des tests

- `test-quickfiles.js` : Tests pour le MCP QuickFiles
- `test-jinavigator.js` : Tests pour le MCP JinaNavigator
- `test-jupyter.js` : Tests pour le MCP Jupyter
- `run-all-tests.ps1` : Script PowerShell pour exécuter tous les tests
- `reports/` : Répertoire contenant les rapports de test générés

## Prérequis

- **Node.js** : Version 14.x ou supérieure
- **PowerShell** : Version 5.0 ou supérieure (pour exécuter le script `run-all-tests.ps1`)
- **Serveurs MCP** : Les serveurs MCP à tester doivent être installés

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

## Fonctionnalités testées

### MCP QuickFiles

- Installation et configuration
- Accès au serveur
- Lecture de fichiers multiples
- Listage de répertoires
- Édition de fichiers multiples
- Suppression de fichiers
- Intégration avec Roo

### MCP JinaNavigator

- Installation et configuration
- Accès au serveur
- Conversion de pages web en Markdown
- Accès aux ressources Jina
- Conversion multiple de pages web
- Extraction de plans Markdown
- Intégration avec Roo

### MCP Jupyter

- Installation et configuration
- Accès au serveur
- Création de notebooks
- Lecture de notebooks
- Ajout de cellules
- Mise à jour de cellules
- Suppression de cellules
- Intégration avec Roo

## Mode hors ligne

Les tests sont conçus pour fonctionner en mode hors ligne autant que possible, ce qui permet de les exécuter sans dépendances externes. Cependant, certains tests peuvent nécessiter une connexion Internet ou des services externes.

## Personnalisation des tests

Vous pouvez personnaliser les tests en modifiant les fichiers de test correspondants. Par exemple, vous pouvez :

- Modifier les chemins des serveurs MCP
- Ajouter de nouveaux tests
- Modifier les paramètres de test

## Dépannage

Si les tests échouent, vérifiez les points suivants :

1. Assurez-vous que les serveurs MCP sont correctement installés
2. Vérifiez que les serveurs MCP sont accessibles
3. Consultez les rapports de test pour plus de détails sur les erreurs
4. Vérifiez les journaux des serveurs MCP pour détecter d'éventuelles erreurs

## Ajout de nouveaux tests

Pour ajouter un test pour un nouveau MCP, créez un nouveau fichier de test en suivant le modèle des fichiers existants, puis ajoutez-le à la liste des scripts de test dans `run-all-tests.ps1`.
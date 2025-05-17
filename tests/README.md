# Tests du Projet Roo Extensions

Ce répertoire contient l'ensemble des tests pour le projet Roo Extensions, organisés par catégories pour faciliter la validation des différentes fonctionnalités du projet.

## Vue d'ensemble

Les tests sont essentiels pour garantir le bon fonctionnement des différentes composantes du projet Roo Extensions. Ils couvrent :

- Les tests de structure MCP
- Les tests des serveurs MCP spécifiques
- Les tests d'encodage
- Les tests d'escalade et désescalade
- Les tests d'orchestration

## Structure du répertoire

### [mcp-structure/](mcp-structure/)
Tests de la structure des serveurs MCP, incluant :
- Tests de configuration
- Tests de validation des schémas
- Tests de structure des données

### [mcp-win-cli/](mcp-win-cli/)
Tests spécifiques pour le MCP Windows CLI, incluant :
- Tests d'exécution de commandes
- Tests de connexion SSH
- Tests d'intégration avec Roo

### [scripts/](scripts/)
Scripts utilitaires pour l'exécution et l'analyse des tests, incluant :
- Scripts d'automatisation des tests
- Scripts de génération de rapports
- Scripts de validation

## Types de tests

### Tests de structure MCP

Ces tests vérifient que la structure des serveurs MCP est conforme aux spécifications du protocole MCP. Ils s'assurent que :
- Les schémas d'entrée et de sortie sont valides
- Les outils exposés fonctionnent correctement
- Les ressources sont accessibles

### Tests de serveurs MCP spécifiques

Ces tests vérifient le bon fonctionnement de chaque serveur MCP spécifique :
- QuickFiles
- JinaNavigator
- Jupyter
- SearXNG
- Win-CLI
- Git
- GitHub
- Filesystem

Pour les tests détaillés des serveurs MCP, consultez le [README des tests MCP](../mcps/tests/README.md).

### Tests d'encodage

Ces tests vérifient que les problèmes d'encodage sont correctement détectés et corrigés, notamment pour :
- Les caractères accentués
- Les emojis
- Les caractères spéciaux

Pour plus d'informations sur les tests d'encodage, consultez le [document de test d'encodage](test-encodage.md).

## Exécution des tests

Chaque catégorie de tests dispose de ses propres instructions d'exécution. Consultez les fichiers README.md dans chaque sous-dossier pour des instructions spécifiques.

### Tests MCP Structure

```powershell
cd mcp-structure
.\run-tests.ps1
```

### Tests MCP Win-CLI

```powershell
cd mcp-win-cli
.\run-tests.bat
```

## Rapports de test

Les tests génèrent des rapports détaillés qui sont stockés dans leurs répertoires respectifs. Ces rapports incluent :
- Le nombre de tests réussis et échoués
- Les erreurs rencontrées
- Les temps d'exécution
- Les recommandations pour résoudre les problèmes

## Intégration avec les autres composants

### Intégration avec les tests de roo-modes

Les tests de ce répertoire complètent les tests d'escalade et désescalade disponibles dans le répertoire [roo-modes/n5/tests/](../roo-modes/n5/tests/). Ensemble, ils fournissent une couverture complète des fonctionnalités du projet.

### Intégration avec les tests MCP

Les tests MCP de ce répertoire sont complémentaires aux tests disponibles dans le répertoire [mcps/tests/](../mcps/tests/). Ils se concentrent sur des aspects différents des serveurs MCP.

## Contribution aux tests

Si vous souhaitez contribuer aux tests, veuillez suivre ces directives :
1. Créez un nouveau répertoire pour votre catégorie de tests si nécessaire
2. Ajoutez un fichier README.md décrivant vos tests
3. Utilisez des scripts d'automatisation pour faciliter l'exécution des tests
4. Générez des rapports détaillés pour faciliter l'analyse des résultats

## Ressources supplémentaires

- [README principal du projet](../README.md)
- [Documentation des modes Roo](../roo-modes/README.md)
- [Documentation de la configuration Roo](../roo-config/README.md)
- [Documentation des MCPs](../mcps/README.md)
- [Documentation générale du projet](../docs/README.md)

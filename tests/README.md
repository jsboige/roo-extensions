# Tests du Projet Roo Extensions

Ce répertoire contient l'ensemble des tests pour le projet Roo Extensions, organisés par catégories pour faciliter la validation des différentes fonctionnalités du projet.

## Vue d'ensemble

Les tests sont essentiels pour garantir le bon fonctionnement des différentes composantes du projet Roo Extensions. Ils couvrent :

- Les tests de structure MCP
- Les tests des serveurs MCP spécifiques (QuickFiles, JinaNavigator, Jupyter)
- Les tests d'encodage
- Les tests d'escalade, désescalade et transition entre modes
- Les tests d'orchestration

## Structure du répertoire

### [mcp-structure/](mcp-structure/)
Tests de la structure des serveurs MCP, incluant :
- Tests de configuration (`config/settings.json`)
- Tests de validation des schémas
- Tests de structure des données (fichiers de test dans `data/`)
- Rapports de test générés dans `output/report.md`

### [mcp-win-cli/](mcp-win-cli/)
Tests spécifiques pour le MCP Windows CLI, incluant :
- Tests d'exécution de commandes (`test-win-cli-commands.ps1`)
- Tests d'opérateurs PowerShell (`test-win-cli-operators.ps1`)
- Tests d'intégration avec Roo (`test-win-cli-mcp.js`)
- Tests directs et réels (`test-win-cli-direct.js`, `test-win-cli-real.js`)
- Script d'exécution automatisée (`run-tests.bat`)
- Documentation détaillée dans `README.md` et `rapport-synthese.md`

## Types de tests

### Tests de structure MCP

Ces tests vérifient que la structure des serveurs MCP est conforme aux spécifications du protocole MCP. Ils s'assurent que :
- Les schémas d'entrée et de sortie sont valides
- Les outils exposés fonctionnent correctement
- Les ressources sont accessibles

### Tests de serveurs MCP spécifiques

Ces tests vérifient le bon fonctionnement de chaque serveur MCP spécifique. Les tests actuellement disponibles dans [mcps/tests/](../mcps/tests/) concernent :
- **QuickFiles** : Tests des opérations de fichiers multiples, listage de répertoires, édition et suppression
- **JinaNavigator** : Tests de conversion web vers Markdown, accès aux ressources et extraction de plans
- **Jupyter** : Tests de création, lecture, modification et exécution de notebooks

Les rapports de test récents (mai 2025) sont disponibles dans le répertoire [mcps/tests/reports/](../mcps/tests/reports/).

### Tests d'escalade et désescalade

Ces tests vérifient les mécanismes de transition entre les différents niveaux de complexité de l'architecture N5 :

- **Tests d'escalade** : Vérifient que le système passe correctement à un niveau de complexité supérieur lorsque nécessaire
- **Tests de désescalade** : Vérifient que le système revient à un niveau de complexité inférieur lorsque approprié
- **Tests de transition** : Vérifient les transitions fluides entre les différents modes et niveaux

Ces tests sont disponibles dans le répertoire [roo-modes/n5/tests/](../roo-modes/n5/tests/) et leurs résultats sont stockés dans [roo-modes/n5/test-results/](../roo-modes/n5/test-results/).

### Tests d'encodage

Ces tests vérifient que les problèmes d'encodage sont correctement détectés et corrigés, notamment pour :
- Les caractères accentués
- Les caractères spéciaux

Le fichier [test-encodage.md](test-encodage.md) contient des exemples de caractères accentués pour tester l'encodage.

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

### Tests des serveurs MCP spécifiques

```powershell
cd ../mcps/tests
.\run-all-tests.ps1
```

Ou pour tester un serveur MCP spécifique :

```bash
# Test du MCP QuickFiles
node test-quickfiles.js

# Test du MCP JinaNavigator
node test-jinavigator.js

# Test du MCP Jupyter
node test-jupyter.js
```

### Tests d'escalade et désescalade

```powershell
cd ../roo-modes/n5/tests
node test-escalade.js
node test-desescalade.js
```

## Rapports de test

Les tests génèrent des rapports détaillés qui sont stockés dans leurs répertoires respectifs :

- **Tests MCP** : Rapports au format Markdown dans `mcps/tests/reports/`
- **Tests d'escalade/désescalade** : Rapports au format JSON dans `roo-modes/n5/test-results/`
- **Tests MCP Win-CLI** : Rapport de synthèse dans `mcp-win-cli/rapport-synthese.md`

Ces rapports incluent :
- Date et heure d'exécution des tests
- Résumé des tests (nombre de tests réussis/échoués)
- Détails des tests exécutés
- Messages d'erreur éventuels
- Recommandations pour résoudre les problèmes

## Interprétation des résultats

### Tests MCP

Les rapports de test MCP utilisent les indicateurs suivants :
- ✅ **Réussi** : Le test a passé avec succès
- ❌ **Échec** : Le test a échoué, avec des détails sur la raison de l'échec
- ⚠️ **Avertissement** : Le test a réussi mais avec des avertissements à prendre en compte

### Tests d'escalade et désescalade

Les résultats des tests d'escalade et désescalade sont stockés dans des fichiers JSON avec les formats suivants :
- `escalation-test-results-[TIMESTAMP].json`
- `deescalation-test-results-[TIMESTAMP].json`
- `transition-test-results-[TIMESTAMP].json`

## Intégration avec les autres composants

### Intégration avec les tests de roo-modes

Les tests de ce répertoire complètent les tests d'escalade, désescalade et transition disponibles dans le répertoire [roo-modes/n5/tests/](../roo-modes/n5/tests/). Ensemble, ils fournissent une couverture complète des fonctionnalités du projet.

### Intégration avec les tests MCP

Les tests MCP de ce répertoire sont complémentaires aux tests disponibles dans le répertoire [mcps/tests/](../mcps/tests/). Ils se concentrent sur des aspects différents des serveurs MCP :
- Les tests dans `tests/mcp-structure/` se concentrent sur la structure et la conformité des serveurs MCP
- Les tests dans `tests/mcp-win-cli/` se concentrent spécifiquement sur le MCP Windows CLI
- Les tests dans `mcps/tests/` se concentrent sur les fonctionnalités spécifiques de chaque serveur MCP

## Contribution aux tests

Si vous souhaitez contribuer aux tests, veuillez suivre ces directives :
1. Créez un nouveau répertoire pour votre catégorie de tests si nécessaire
2. Ajoutez un fichier README.md décrivant vos tests
3. Utilisez des scripts d'automatisation pour faciliter l'exécution des tests
4. Générez des rapports détaillés pour faciliter l'analyse des résultats
5. Assurez-vous que vos tests sont compatibles avec les tests existants
6. Mettez à jour ce README.md pour refléter les nouveaux tests ajoutés

## Ressources supplémentaires

- [README principal du projet](../README.md)
- [Documentation des modes Roo](../roo-modes/README.md)
- [Documentation de la configuration Roo](../roo-config/README.md)
- [Documentation des MCPs](../mcps/README.md)
- [Documentation générale du projet](../docs/README.md)

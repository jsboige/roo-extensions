# Batterie de tests pour le MCP Win-CLI

Ce répertoire contient une batterie de tests automatisés pour évaluer les fonctionnalités du MCP Win-CLI et documenter ses capacités et limitations.

## Objectif

L'objectif de cette batterie de tests est de :

1. Vérifier le bon fonctionnement des différentes fonctionnalités du MCP Win-CLI
2. Documenter les commandes qui fonctionnent sans problème
3. Identifier les commandes qui nécessitent des autorisations supplémentaires
4. Repérer les commandes qui ne fonctionnent pas ou sont bloquées
5. Proposer des améliorations pour optimiser l'utilisation du MCP Win-CLI

## Structure du répertoire

- `test-win-cli.js` : Test simulé qui simule le comportement du MCP Win-CLI sans faire d'appels réels
- `test-win-cli-real.js` : Test semi-réel qui simule les appels à l'API MCP mais génère des résultats plus réalistes
- `test-win-cli-mcp.js` : Test avec API MCP qui utilise l'API MCP pour exécuter des commandes via Roo
- `test-win-cli-direct.js` : Test direct qui exécute directement des commandes sur le système via Node.js
- `rapport-synthese.md` : Rapport détaillé des résultats des tests et recommandations
- `run-tests.bat` : Script de lancement pour exécuter facilement les différents tests
- `results/` : Répertoire où sont stockés les résultats des tests (créé automatiquement)

## Prérequis

- Node.js (version 16 ou supérieure)
- MCP Win-CLI installé. La configuration est maintenant gérée par un fichier `win-cli-config.json` dédié.
- PowerShell (préinstallé sur Windows)
- CMD (préinstallé sur Windows)
- Git Bash (optionnel, pour tester les commandes Git Bash)

## Installation

1. Clonez ou téléchargez ce répertoire
2. Assurez-vous que Node.js est installé
3. Assurez-vous que le MCP Win-CLI est installé et configuré

## Utilisation

### Méthode 1 : Utilisation du script de lancement

1. Exécutez le script `run-tests.bat`
2. Choisissez le test à exécuter dans le menu
3. Suivez les instructions à l'écran

### Méthode 2 : Exécution directe des scripts

#### Test simulé

```bash
node test-win-cli.js
```

Ce test simule le comportement du MCP Win-CLI sans faire d'appels réels. Il est utile pour comprendre le fonctionnement attendu du MCP Win-CLI.

#### Test semi-réel

```bash
node test-win-cli-real.js
```

Ce test simule les appels à l'API MCP mais génère des résultats plus réalistes. Il crée également un rapport détaillé dans le répertoire `results/`.

#### Test direct

```bash
node test-win-cli-direct.js
```

Ce test exécute directement des commandes sur le système via Node.js. Il est utile pour comparer le comportement du MCP Win-CLI avec l'exécution directe des commandes.

#### Test avec API MCP

Pour exécuter ce test, vous devez utiliser Roo avec le MCP Win-CLI configuré :

```xml
<use_mcp_tool>
 <server_name>win-cli</server_name>
 <tool_name>execute_command</tool_name>
 <arguments>
 {
   "shell": "powershell",
   "command": "node test-win-cli-mcp.js",
   "workingDir": "chemin/vers/tests/mcp-win-cli"
 }
 </arguments>
</use_mcp_tool>
```

Remplacez `chemin/vers/tests/mcp-win-cli` par le chemin absolu vers le répertoire `tests/mcp-win-cli`.

## Configuration du MCP Win-CLI

La configuration du MCP Win-CLI est gérée par le fichier [`roo-config/settings/win-cli-config.json`](roo-config/settings/win-cli-config.json). Ce fichier permet de définir :

- **Timeout des commandes :** Le timeout par défaut est maintenant de 600 secondes (10 minutes). Ceci est configurable via la clé `commandTimeout` dans la section `security` et `defaultTimeout` dans la section `ssh`.
- **Configuration débridée :**
   - `blockedCommands`: Liste vide par défaut, aucune commande n'est bloquée.
   - `blockedArguments`: Liste vide par défaut, aucun argument n'est bloqué.
   - `allowedPaths`: Permet l'accès à `C:/`, `D:/`, `G:/`.
   - `restrictWorkingDirectory`: Mis à `false`, ne restreint pas le répertoire de travail aux `allowedPaths`.
   - `enableInjectionProtection`: Mis à `false`, autorise les opérateurs de chaînage de commandes comme `&&`, `||`, `;`.
   - `blockedOperators` pour chaque shell: Liste vide, tous les opérateurs sont autorisés.
- **Chemin de démarrage :** La commande de démarrage du serveur est configurée dans [`roo-config/settings/servers.json`](roo-config/settings/servers.json) et inclut maintenant l'argument `--config ./roo-config/settings/win-cli-config.json` pour charger cette configuration spécifique.

## Fonctionnalités testées

### 1. Exécution de commandes simples

Les tests vérifient l'exécution de commandes simples dans différents shells :

- PowerShell : `Get-Date`, `Write-Host "Hello"`, etc.
- CMD : `echo Hello`, `dir /b`, etc.
- Git Bash : `echo "Hello"`, `ls -la`, etc.

### 2. Exécution de commandes complexes

Les tests vérifient l'exécution de commandes complexes avec paramètres, pipes, etc. :

- PowerShell : `Get-Process | Select-Object -First 5`, etc.
- CMD : `dir /a /o:n`, `echo Premier & echo Second`, etc.
- Git Bash : `for i in {1..3}; do echo "Itération $i"; done`, etc.

### 3. Gestion des erreurs

Les tests vérifient la gestion des erreurs en exécutant des commandes inexistantes ou mal formées :

- PowerShell : `Get-NonExistentCmdlet`, etc.
- CMD : `unknown_command`, etc.
- Git Bash : `unknown_command`, etc.

### 4. Récupération de l'historique des commandes

Les tests vérifient la récupération de l'historique des commandes exécutées.

### 5. Récupération du répertoire de travail actuel

Les tests vérifient la récupération du répertoire de travail actuel.

## Résultats des tests

Les résultats détaillés des tests sont disponibles dans le rapport de synthèse (`rapport-synthese.md`). Ce rapport contient :

- La liste des commandes qui fonctionnent sans problème
- La liste des commandes qui nécessitent des autorisations supplémentaires
- La liste des commandes qui ne fonctionnent pas ou sont bloquées
- Des propositions d'améliorations pour optimiser l'utilisation du MCP Win-CLI

## Recommandations

Sur la base des résultats des tests, les recommandations suivantes sont formulées :

1. **Configuration optimale**
   - Autoriser uniquement le séparateur `;` pour le chaînage de commandes
   - Limiter les commandes autorisées aux commandes nécessaires
   - Activer la journalisation pour suivre l'utilisation

2. **Bonnes pratiques**
   - Utiliser le shell approprié pour chaque tâche
   - Spécifier un répertoire de travail pour éviter les problèmes de chemin relatif
   - Préférer les commandes idempotentes
   - Vérifier régulièrement l'historique des commandes

3. **Contournements pour les limitations**
   - Pour les commandes complexes nécessitant plusieurs séparateurs, utiliser des scripts PowerShell ou Batch
   - Pour les commandes nécessitant des privilèges élevés, utiliser des tâches planifiées ou des services
   - Pour les commandes bloquées, utiliser des alternatives ou des approches différentes

## Contribution

Pour contribuer à cette batterie de tests :

1. Ajoutez de nouveaux tests dans les fichiers existants ou créez de nouveaux fichiers de test
2. Mettez à jour le rapport de synthèse avec les nouveaux résultats
3. Mettez à jour ce README si nécessaire

## Licence

Ce projet est sous licence MIT.
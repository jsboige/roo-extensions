# Guide d'intégration des modes personnalisés dans Roo

Ce guide détaille la configuration et les étapes nécessaires pour intégrer des modes personnalisés dans l'extension Roo pour Visual Studio Code. Il est destiné aux administrateurs système et aux développeurs qui souhaitent configurer des modes personnalisés pour leur équipe ou leur organisation.

## Table des matières

1. [Architecture des modes personnalisés](#architecture-des-modes-personnalisés)
2. [Structure des fichiers de configuration](#structure-des-fichiers-de-configuration)
3. [Méthodes de déploiement](#méthodes-de-déploiement)
   - [Déploiement global](#déploiement-global)
   - [Déploiement local](#déploiement-local)
   - [Déploiement via Git](#déploiement-via-git)
4. [Configuration avancée](#configuration-avancée)
   - [Familles de modes](#familles-de-modes)
   - [Mécanismes d'escalade et de désescalade](#mécanismes-descalade-et-de-désescalade)
   - [Utilisation des MCPs](#utilisation-des-mcps)
   - [Gestion des tokens](#gestion-des-tokens)
5. [Problèmes courants et solutions](#problèmes-courants-et-solutions)
6. [Exemples de configuration](#exemples-de-configuration)
7. [Tests et validation](#tests-et-validation)
8. [Références](#références)

## Architecture des modes personnalisés

Les modes personnalisés dans Roo sont définis par des fichiers de configuration JSON qui spécifient le comportement, les capacités et les instructions système pour chaque mode. L'architecture comprend plusieurs composants clés :

### Emplacement des fichiers de configuration

- **Configuration globale** : `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`
- **Configuration locale** : Fichier `.roomodes` à la racine du projet

### Composants du système de modes

1. **Définition des modes** : Chaque mode est défini par un ensemble de propriétés dans un fichier JSON.
2. **Validateur de famille** : Un composant spécial qui gère les transitions entre les différentes familles de modes.
3. **Scripts de déploiement** : Des scripts PowerShell qui facilitent le déploiement des configurations de modes.

## Structure des fichiers de configuration

Les modes personnalisés sont définis dans un fichier JSON avec la structure suivante :

```json
{
  "customModes": [
    {
      "slug": "mode-family-validator",
      "name": "Mode Family Validator",
      "description": "Système de validation des transitions entre familles de modes",
      "version": "1.0.0",
      "enabled": true,
      "familyDefinitions": {
        "simple": ["code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple"],
        "complex": ["code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex", "manager"]
      }
    },
    {
      "slug": "nom-technique-du-mode",
      "family": "simple",
      "allowedFamilyTransitions": ["simple"],
      "name": "🔧 Nom Affiché du Mode",
      "roleDefinition": "Description concise du rôle du mode",
      "groups": ["read", "edit", "browser", "command", "mcp"],
      "customInstructions": "Instructions système détaillées pour le mode"
    }
  ]
}
```

### Propriétés obligatoires

- `slug` : Identifiant technique unique du mode (sans espaces ni caractères spéciaux)
- `name` : Nom affiché dans l'interface utilisateur (peut inclure des émojis)
- `roleDefinition` : Description concise du rôle et des capacités du mode
- `customInstructions` : Instructions système détaillées qui définissent le comportement du mode

> **Note**: Depuis la mise en place de l'architecture basée sur les profils, la propriété `model` n'est plus définie directement dans la configuration du mode. Les modèles sont maintenant gérés via des profils dans le fichier `model-configs.json`. Voir la section [Utilisation des profils](#utilisation-des-profils) pour plus de détails.

### Propriétés optionnelles

- `description` : Description détaillée du mode
- `family` : Famille à laquelle appartient le mode (ex: "simple", "complex")
- `allowedFamilyTransitions` : Liste des familles vers lesquelles ce mode peut transitionner
- `groups` : Liste des groupes d'outils auxquels le mode a accès
- `allowed_file_patterns` : Liste des patterns regex pour les fichiers que ce mode peut modifier
- `restricted_file_patterns` : Liste des patterns regex pour les fichiers que ce mode ne peut pas modifier

## Méthodes de déploiement

### Déploiement global

Le déploiement global installe les modes personnalisés pour tous les projets sur la machine de l'utilisateur.

1. Utilisez le script PowerShell `deploy-modes.ps1` ou `deploy-modes-enhanced.ps1` :

```powershell
.\roo-config\deploy-modes.ps1 -ConfigFile "modes/standard-modes.json" -DeploymentType global
```

2. Le script copie le fichier de configuration vers :
   `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`

### Déploiement local

Le déploiement local installe les modes personnalisés uniquement pour le projet en cours.

1. Utilisez le script PowerShell avec l'option `-DeploymentType local` :

```powershell
.\roo-config\deploy-modes.ps1 -ConfigFile "modes/standard-modes.json" -DeploymentType local
```

2. Le script crée un fichier `.roomodes` à la racine du projet.

### Déploiement via Git

Pour déployer les modes personnalisés sur plusieurs machines via Git :

1. Ajoutez les fichiers de configuration et les scripts de déploiement à votre dépôt Git.

2. Sur chaque machine cible, clonez ou mettez à jour le dépôt :

```bash
git clone <URL_DU_DEPOT> roo-extensions
cd roo-extensions
```

3. Exécutez le script de déploiement :

```powershell
cd roo-config
.\deploy-modes-enhanced.ps1 -DeploymentType global -Force
```

Le script `deploy-modes-enhanced.ps1` inclut des fonctionnalités supplémentaires comme :
- Gestion de l'encodage des fichiers (UTF-8 sans BOM)
- Tests automatiques après déploiement
- Génération d'instructions pour le déploiement via Git
- Support des profils pour la gestion des modèles

### Utilisation des profils

Depuis la mise à jour de l'architecture, les modèles de langage sont gérés via des profils plutôt que directement dans la configuration des modes. Cette approche offre plusieurs avantages:

1. **Gestion centralisée**: Les modèles sont définis dans un fichier central (`model-configs.json`)
2. **Flexibilité**: Possibilité de basculer facilement entre différentes configurations de modèles
3. **Cohérence**: Garantie que tous les modes utilisent les modèles appropriés

Pour déployer une configuration basée sur un profil:

```powershell
# Déploiement avec un profil spécifique
.\deploy-modes-enhanced.ps1 -ProfileName "standard" -DeploymentType global

# Ou avec le script dédié aux profils
.\deploy-profile-modes.ps1 -ProfileName "standard" -DeploymentType global
```

Pour plus d'informations sur les profils, consultez le [Guide d'utilisation des profils](../../docs/guide-utilisation-profils-modes.md).

## Configuration avancée

### Familles de modes

Les modes sont organisés en familles qui définissent les niveaux de complexité et les transitions autorisées entre modes.

```json
"mode-family-validator": {
  "slug": "mode-family-validator",
  "name": "Mode Family Validator",
  "description": "Système de validation des transitions entre familles de modes",
  "version": "1.0.0",
  "enabled": true,
  "familyDefinitions": {
    "simple": ["code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple"],
    "complex": ["code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex", "manager"]
  }
}
```

Cette configuration définit deux familles de modes :
- `simple` : Modes adaptés aux tâches simples et isolées
- `complex` : Modes adaptés aux tâches complexes et interdépendantes

### Mécanismes d'escalade et de désescalade

Les modes personnalisés incluent des mécanismes d'escalade et de désescalade qui permettent de passer d'un niveau de complexité à un autre en fonction des besoins.

#### Escalade

L'escalade permet de passer d'un mode simple à un mode complexe lorsque la tâche dépasse certains critères de complexité :

```
"[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]"
```

Critères d'escalade typiques :
- Modifications de plus de 50 lignes de code
- Refactorisations majeures
- Conception d'architecture
- Optimisations de performance
- Analyse approfondie
- Systèmes interdépendants

#### Désescalade

La désescalade permet de passer d'un mode complexe à un mode simple lorsque la tâche devient suffisamment simple :

```
"[DÉSESCALADE SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : [RAISON]"
```

### Utilisation des MCPs

Les modes personnalisés peuvent être configurés pour utiliser des serveurs MCP (Model Context Protocol) qui fournissent des fonctionnalités supplémentaires. Les MCPs permettent d'effectuer des opérations complexes sans validation humaine, ce qui améliore l'efficacité et réduit le nombre d'interactions nécessaires.

Voici comment configurer l'utilisation des MCPs dans les instructions personnalisées :

```json
"customInstructions": "UTILISATION DES MCPs:\n- PRIVILÉGIEZ SYSTÉMATIQUEMENT l'utilisation des MCPs par rapport aux outils standards nécessitant une validation humaine\n- Pour les manipulations de fichiers multiples ou volumineux, utilisez le MCP quickfiles:\n  * Exemple: Pour lire plusieurs fichiers en une seule opération:\n    ```\n    <use_mcp_tool>\n    <server_name>quickfiles</server_name>\n    <tool_name>read_multiple_files</tool_name>\n    <arguments>\n    {\n      \"paths\": [\"chemin/fichier1.js\", \"chemin/fichier2.js\"],\n      \"show_line_numbers\": true\n    }\n    </arguments>\n    </use_mcp_tool>\n    ```"
```

#### MCPs disponibles

Les MCPs couramment utilisés incluent :

1. **quickfiles** : Pour les opérations de fichiers multiples
   - `read_multiple_files` : Lecture de plusieurs fichiers en une seule opération
   - `edit_multiple_files` : Modification de plusieurs fichiers en une seule opération
   - `list_directory_contents` : Liste des fichiers dans un répertoire avec options avancées

2. **jinavigator** : Pour l'extraction d'informations de pages web
   - `convert_web_to_markdown` : Conversion d'une page web en Markdown
   - `multi_convert` : Conversion de plusieurs pages web en une seule opération
   - `extract_markdown_outline` : Extraction du plan d'une page web

3. **searxng** : Pour les recherches web
   - `searxng_web_search` : Recherche d'informations sur le web
   - `web_url_read` : Lecture du contenu d'une URL spécifique

### Gestion des tokens

Les modes personnalisés incluent des mécanismes de gestion des tokens pour éviter de dépasser les limites de contexte des modèles d'IA. Ces mécanismes sont particulièrement importants pour les conversations longues ou complexes.

```json
"customInstructions": "GESTION DES TOKENS:\n- Si la conversation dépasse 50 000 tokens, vous DEVEZ suggérer de passer en mode complexe avec le format:\n\"[LIMITE DE TOKENS] Cette conversation a dépassé 50 000 tokens. Je recommande de passer en mode complexe pour continuer.\"\n- Si la conversation dépasse 100 000 tokens, vous DEVEZ suggérer de passer en mode orchestration avec le format:\n\"[LIMITE DE TOKENS CRITIQUE] Cette conversation a dépassé 100 000 tokens. Je recommande de passer en mode orchestration pour diviser la tâche en sous-tâches.\""
```

#### Mécanisme d'escalade par approfondissement

Pour gérer efficacement les ressources, les modes incluent un mécanisme d'escalade par approfondissement qui crée des sous-tâches lorsque la conversation devient trop volumineuse :

```json
"customInstructions": "IMPORTANT: Vous DEVEZ implémenter l'escalade par approfondissement (création de sous-tâches) après:\n- 50000 tokens avec des commandes lourdes\n- Ou environ 15 messages de taille moyenne\n\nProcessus d'escalade par approfondissement:\n1. Identifiez le moment où la conversation devient trop volumineuse\n2. Suggérez la création d'une sous-tâche avec le format:\n\"[ESCALADE PAR APPROFONDISSEMENT] Je suggère de créer une sous-tâche pour continuer ce travail car : [RAISON]\"\n3. Proposez une description claire de la sous-tâche à créer"
```

## Problèmes courants et solutions

### Problème : Les modes personnalisés ne s'affichent pas dans Roo

**Solutions :**
1. Vérifiez que le fichier de configuration est correctement formaté (JSON valide)
   ```powershell
   Get-Content -Path "%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json" | ConvertFrom-Json
   ```

2. Assurez-vous que le fichier est encodé en UTF-8 sans BOM
   ```powershell
   # Vérifier l'encodage
   $bytes = [System.IO.File]::ReadAllBytes("%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json")
   if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
       Write-Host "Le fichier est encodé en UTF-8 avec BOM"
   } else {
       Write-Host "Le fichier est encodé en UTF-8 sans BOM ou un autre encodage"
   }
   
   # Corriger l'encodage si nécessaire
   $content = Get-Content -Path "%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json" -Raw
   [System.IO.File]::WriteAllText("%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json", $content, [System.Text.UTF8Encoding]::new($false))
   ```

3. Vérifiez l'emplacement du fichier :
   - Global : `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`
   - Local : `.roomodes` à la racine du projet

4. Redémarrez VS Code après le déploiement
   ```powershell
   # Fermer VS Code
   Stop-Process -Name "Code" -Force -ErrorAction SilentlyContinue
   # Attendre quelques secondes
   Start-Sleep -Seconds 2
   # Relancer VS Code
   Start-Process "code"
   ```

5. Vérifiez les journaux de l'extension Roo dans VS Code :
   - Ouvrez la palette de commandes (Ctrl+Shift+P)
   - Tapez "Developer: Open Extension Logs Folder"
   - Recherchez les fichiers de log liés à Roo

### Problème : Erreurs lors de l'exécution du script de déploiement

**Solutions :**
1. Exécutez PowerShell avec des droits d'administrateur
   ```powershell
   Start-Process powershell -Verb RunAs
   ```

2. Vérifiez que le chemin vers le fichier de configuration est correct
   ```powershell
   Test-Path -Path ".\roo-config\modes\standard-modes.json"
   ```

3. Utilisez l'option `-Force` pour remplacer les fichiers existants
   ```powershell
   .\roo-config\deploy-modes-enhanced.ps1 -ConfigFile "modes/standard-modes.json" -DeploymentType global -Force
   ```

4. Vérifiez les erreurs d'encodage et utilisez `deploy-modes-enhanced.ps1` qui gère mieux l'encodage
   ```powershell
   # Exécuter le script avec diagnostic d'encodage
   .\roo-config\encoding-diagnostic.ps1
   # Corriger l'encodage si nécessaire
   .\roo-config\fix-encoding.ps1
   ```

5. Vérifiez les permissions sur les répertoires de destination
   ```powershell
   # Vérifier les permissions
   Get-Acl -Path "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
   # Accorder les permissions si nécessaire
   $acl = Get-Acl -Path "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
   $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:USERNAME", "FullControl", "Allow")
   $acl.SetAccessRule($rule)
   Set-Acl -Path "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings" -AclObject $acl
   ```

### Problème : Les mécanismes d'escalade/désescalade ne fonctionnent pas correctement

**Solutions :**
1. Vérifiez que le validateur de famille est correctement configuré
   ```json
   {
     "slug": "mode-family-validator",
     "name": "Mode Family Validator",
     "description": "Système de validation des transitions entre familles de modes",
     "version": "1.0.0",
     "enabled": true,
     "familyDefinitions": {
       "simple": ["code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple"],
       "complex": ["code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex", "manager"]
     }
   }
   ```

2. Assurez-vous que les modes ont les propriétés `family` et `allowedFamilyTransitions` correctement définies
   ```json
   {
     "slug": "code-simple",
     "family": "simple",
     "allowedFamilyTransitions": ["simple"],
     "name": "💻 Code Simple",
     "model": "anthropic/claude-3.5-sonnet"
   }
   ```

3. Vérifiez que les instructions système incluent les sections sur l'escalade et la désescalade
   ```
   MÉCANISME D'ESCALADE:
   IMPORTANT: Vous DEVEZ escalader toute tâche qui correspond aux critères suivants:
   - Tâches nécessitant des modifications de plus de 50 lignes de code
   ```

4. Exécutez les tests après déploiement avec l'option `-TestAfterDeploy`
   ```powershell
   .\roo-config\deploy-modes-enhanced.ps1 -ConfigFile "modes/standard-modes.json" -DeploymentType global -Force -TestAfterDeploy
   ```

5. Vérifiez les résultats des tests d'escalade et de désescalade
   ```powershell
   # Exécuter les tests spécifiques
   node .\roo-modes\tests\test-escalade.js
   node .\roo-modes\tests\test-desescalade.js
   ```

### Problème : Conflits entre modes personnalisés et modes standard

**Solutions :**
1. Vérifiez qu'il n'y a pas de conflits de `slug` entre les modes personnalisés et les modes standard
   ```powershell
   # Extraire les slugs des modes standard
   $standardModes = Get-Content -Path ".\roo-config\modes\standard-modes.json" | ConvertFrom-Json
   $standardSlugs = $standardModes.customModes | Select-Object -ExpandProperty slug
   
   # Extraire les slugs des modes personnalisés
   $customModes = Get-Content -Path ".\roo-modes\configs\vscode-custom-modes.json" | ConvertFrom-Json
   $customSlugs = $customModes.customModes | Select-Object -ExpandProperty slug
   
   # Vérifier les conflits
   $conflicts = $standardSlugs | Where-Object { $customSlugs -contains $_ }
   if ($conflicts) {
       Write-Host "Conflits de slug détectés: $conflicts"
   } else {
       Write-Host "Aucun conflit de slug détecté"
   }
   ```

2. Utilisez l'option `-Merge` lors du déploiement pour fusionner les modes au lieu de les remplacer
   ```powershell
   .\roo-config\deploy-modes-enhanced.ps1 -ConfigFile "modes/standard-modes.json" -DeploymentType global -Merge
   ```

3. Renommez les slugs en conflit dans votre configuration personnalisée

## Exemples de configuration

### Exemple de mode simple

```json
{
  "slug": "code-simple",
  "family": "simple",
  "allowedFamilyTransitions": ["simple"],
  "name": "💻 Code Simple",
  "model": "anthropic/claude-3.5-sonnet",
  "roleDefinition": "You are Roo Code (version simple), specialized in minor code modifications, simple bug fixes, code formatting and documentation, and basic feature implementation.",
  "groups": ["read", "edit", "browser", "command", "mcp"],
  "customInstructions": "FOCUS AREAS:\n- Modifications de code < 50 lignes\n- Fonctions isolées\n- Bugs simples\n- Patterns standards\n- Documentation basique\n\nAPPROACH:\n1. Comprendre la demande spécifique\n2. Analyser les fichiers pertinents\n3. Effectuer des modifications ciblées\n4. Tester la solution\n\n/* NIVEAU DE COMPLEXITÉ */\n// Cette section définit le niveau de complexité actuel et peut être étendue à l'avenir pour supporter n-niveaux\n// Niveau actuel: SIMPLE (niveau 1 sur l'échelle de complexité)\n\nMÉCANISME D'ESCALADE:\n\nIMPORTANT: Vous DEVEZ escalader toute tâche qui correspond aux critères suivants:\n- Tâches nécessitant des modifications de plus de 50 lignes de code\n- Tâches impliquant des refactorisations majeures\n- Tâches nécessitant une conception d'architecture\n- Tâches impliquant des optimisations de performance\n- Tâches nécessitant une analyse approfondie\n- Tâches impliquant plusieurs systèmes ou composants interdépendants\n- Tâches nécessitant une compréhension approfondie de l'architecture globale"
}
```

### Exemple de mode complexe

```json
{
  "slug": "code-complex",
  "family": "complex",
  "allowedFamilyTransitions": ["complex"],
  "name": "💻 Code Complex",
  "model": "anthropic/claude-3.7-sonnet",
  "roleDefinition": "You are Roo, a highly skilled software engineer with extensive knowledge in many programming languages, frameworks, design patterns, and best practices.",
  "groups": ["read", "edit", "browser", "command", "mcp"],
  "customInstructions": "FOCUS AREAS:\n- Major refactoring\n- Architecture design\n- Performance optimization\n- Complex algorithms\n- System integration\n\n/* NIVEAU DE COMPLEXITÉ */\n// Cette section définit le niveau de complexité actuel et peut être étendue à l'avenir pour supporter n-niveaux\n// Niveau actuel: COMPLEX (niveau 2 sur l'échelle de complexité)\n// Des niveaux supplémentaires pourraient être ajoutés ici (EXPERT, SPECIALIST, etc.)\n\nMÉCANISME DE DÉSESCALADE:\n\nIMPORTANT: Vous DEVEZ évaluer systématiquement et continuellement la complexité de la tâche en cours. Si vous constatez que la tâche ou une partie de la tâche est suffisamment simple pour être traitée par la version simple de l'agent, vous DEVEZ suggérer à l'utilisateur de passer au mode simple correspondant."
}
```

## Tests et validation

Pour garantir le bon fonctionnement des modes personnalisés, il est recommandé d'effectuer des tests après le déploiement.

### Tests automatisés

Le script `deploy-modes-enhanced.ps1` inclut une option `-TestAfterDeploy` qui exécute automatiquement une série de tests :

```powershell
.\roo-config\deploy-modes-enhanced.ps1 -ConfigFile "modes/standard-modes.json" -DeploymentType global -Force -TestAfterDeploy
```

Ces tests vérifient :
- Le mécanisme d'escalade interne
- Le mécanisme d'escalade par approfondissement
- Le mécanisme de désescalade
- Le mécanisme de désescalade systématique
- L'utilisation des MCPs
- Le fonctionnement du mode Manager

### Tests manuels

Pour tester manuellement les modes personnalisés :

1. Redémarrez VS Code après le déploiement
2. Ouvrez la palette de commandes (Ctrl+Shift+P)
3. Tapez "Roo: Switch Mode" et sélectionnez un mode personnalisé
4. Testez les fonctionnalités spécifiques du mode :
   - Pour les modes simples : vérifiez qu'ils escaladent correctement les tâches complexes
   - Pour les modes complexes : vérifiez qu'ils désescaladent correctement les tâches simples
   - Pour le mode Manager : vérifiez qu'il peut créer des sous-tâches et gérer efficacement les ressources

### Journalisation des résultats de test

Les résultats des tests sont enregistrés dans le répertoire `roo-modes/n5/test-results/` :

```
roo-modes/n5/test-results/escalation-test-results-[TIMESTAMP].json
roo-modes/n5/test-results/deescalation-test-results-[TIMESTAMP].json
roo-modes/n5/test-results/transition-test-results-[TIMESTAMP].json
```

Ces fichiers contiennent des informations détaillées sur les tests effectués et leurs résultats, ce qui peut être utile pour diagnostiquer les problèmes.

## Références

- [Fichiers de configuration des modes](../configs/standard-modes.json)
- [Script de déploiement de base](../../roo-config/deploy-modes.ps1)
- [Script de déploiement amélioré](../../roo-config/deploy-modes-enhanced.ps1)
- [Script de déploiement basé sur les profils](../../roo-config/deploy-profile-modes.ps1)
- [Script de création de profil](../../roo-config/create-profile.ps1)
- [Guide d'utilisation des profils](../../docs/guide-utilisation-profils-modes.md)
- [Guide d'installation des modes personnalisés](implementation/guide-installation-modes-personnalises.md)
- [Guide de verrouillage des familles de modes](guide-verrouillage-famille-modes.md)
- [Guide d'import/export](guide-import-export.md)
- [Rapport d'implémentation](../n5/rapport-implementation.md)
- [Rapport final de déploiement](../n5/rapport-final-deploiement.md)
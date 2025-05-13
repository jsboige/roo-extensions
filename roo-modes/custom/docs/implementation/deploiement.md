# Guide de déploiement des modes personnalisés Roo

Ce document explique comment installer et synchroniser les modes personnalisés Roo sur une nouvelle machine.

## Prérequis

- Visual Studio Code installé
- Extension Roo installée et configurée
- PowerShell 5.1 ou supérieur
- Droits d'accès aux répertoires de configuration de VS Code

## Structure des fichiers de configuration

Les modes personnalisés Roo sont configurés dans deux fichiers principaux:

1. **Fichier local** (`.roomodes`): Situé à la racine du projet, ce fichier contient la configuration des modes personnalisés pour le projet en cours.

2. **Fichier global** (`custom_modes.json`): Situé dans le répertoire de configuration global de l'extension Roo, ce fichier contient la configuration des modes personnalisés pour toutes les instances de VS Code.

   Chemin: `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`

## Procédure d'installation

### 1. Installation manuelle

1. Cloner le dépôt contenant les modes personnalisés:
   ```powershell
   git clone <url-du-depot> <chemin-local>
   cd <chemin-local>
   ```

2. Copier le fichier `.roomodes` vers le fichier global:
   ```powershell
   Copy-Item -Path ".roomodes" -Destination "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json" -Force
   ```

3. Vérifier que les fichiers sont identiques:
   ```powershell
   Compare-Object -ReferenceObject (Get-Content ".roomodes") -DifferenceObject (Get-Content "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json")
   ```
   Si aucune sortie n'est affichée, les fichiers sont identiques.

### 2. Installation automatisée

1. Cloner le dépôt contenant les modes personnalisés:
   ```powershell
   git clone <url-du-depot> <chemin-local>
   cd <chemin-local>
   ```

2. Exécuter le script de déploiement:
   ```powershell
   .\roo-modes/custom\scripts\deploy.ps1
   ```

## Vérification de l'installation

1. Redémarrer VS Code pour que les changements prennent effet.

2. Ouvrir la palette de commandes (Ctrl+Shift+P) et taper "Roo: Switch Mode".

3. Vérifier que les modes personnalisés apparaissent dans la liste:
   - 💻 Code Simple
   - 💻 Code Complex
   - 🪲 Debug Simple
   - 🪲 Debug Complex
   - 🏗️ Architect Simple
   - 🏗️ Architect Complex
   - ❓ Ask Simple
   - ❓ Ask Complex
   - 🪃 Orchestrator Simple
   - 🪃 Orchestrator Complex

4. Sélectionner un mode personnalisé et vérifier qu'il fonctionne correctement.

## Mise à jour des modes personnalisés

Pour mettre à jour les modes personnalisés:

1. Mettre à jour le fichier `.roomodes` avec les nouvelles configurations.

2. Synchroniser le fichier global:
   ```powershell
   Copy-Item -Path ".roomodes" -Destination "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json" -Force
   ```

3. Vérifier que les fichiers sont identiques:
   ```powershell
   Compare-Object -ReferenceObject (Get-Content ".roomodes") -DifferenceObject (Get-Content "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json")
   ```

## Résolution des problèmes

### Les modes personnalisés n'apparaissent pas

1. Vérifier que le fichier global existe:
   ```powershell
   Test-Path "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"
   ```

2. Vérifier que le fichier global est accessible:
   ```powershell
   Get-Acl "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"
   ```

3. Vérifier que le fichier global contient les modes personnalisés:
   ```powershell
   Get-Content "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json" | Select-String "slug"
   ```

### Les modes personnalisés ne fonctionnent pas correctement

1. Vérifier que le fichier global est correctement formaté (JSON valide):
   ```powershell
   Get-Content "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json" | ConvertFrom-Json
   ```

2. Redémarrer VS Code et réessayer.

3. Réinstaller l'extension Roo si nécessaire.
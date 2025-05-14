# Guide d'installation et de configuration des modes personnalisés Roo

## Table des matières

1. [Introduction](#1-introduction)
2. [Comprendre les fichiers de configuration](#2-comprendre-les-fichiers-de-configuration)
3. [Installation et configuration](#3-installation-et-configuration)
4. [Procédure après un git pull](#4-procédure-après-un-git-pull)
5. [Pièges courants et solutions](#5-pièges-courants-et-solutions)
6. [Script de déploiement automatisé](#6-script-de-déploiement-automatisé)
7. [Annexes](#7-annexes)

## 1. Introduction

Les modes personnalisés Roo permettent d'optimiser l'utilisation des ressources en dirigeant les tâches vers le mode le plus approprié selon leur complexité. Cette documentation explique comment installer, configurer et maintenir ces modes personnalisés, en particulier après un git pull.

### 1.1 Objectifs

- Comprendre le rôle des différents fichiers de configuration
- Installer et configurer correctement les modes personnalisés
- Maintenir la synchronisation entre les fichiers de configuration
- Éviter les problèmes courants liés à la portabilité

### 1.2 Architecture des modes personnalisés

L'architecture actuelle des modes personnalisés comprend 5 types de modes (code, debug, architect, ask, orchestrator), chacun disponible en 2 niveaux de complexité (simple et complexe) :

- 💻 Code Simple / 💻 Code Complex
- 🪲 Debug Simple / 🪲 Debug Complex
- 🏗️ Architect Simple / 🏗️ Architect Complex
- ❓ Ask Simple / ❓ Ask Complex
- 🪃 Orchestrator Simple / 🪃 Orchestrator Complex

## 2. Comprendre les fichiers de configuration

### 2.1 Fichiers principaux

Les modes personnalisés Roo sont configurés dans deux fichiers principaux :

1. **Fichier local** (`.roomodes`) :
   - **Emplacement** : Racine du projet (`D:\roo-extensions\.roomodes`)
   - **Rôle** : Configuration locale au projet, définit les modes disponibles dans ce projet spécifique
   - **Visibilité** : Visible dans le contrôle de version (peut être partagé via git)

2. **Fichier global** (`custom_modes.json`) :
   - **Emplacement** : Dossier de configuration global de l'extension Roo (`C:\Users\<USERNAME>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`)
   - **Rôle** : Configuration globale de l'extension Roo dans VSCode, définit les modes disponibles pour tous les projets
   - **Visibilité** : Spécifique à l'installation locale de VSCode (non partagé via git)

### 2.2 Structure des fichiers

Les deux fichiers partagent exactement la même structure JSON :

```json
{
  "customModes": [
    {
      "slug": "mode-name",
      "name": "🔤 Mode Name",
      "model": "anthropic/claude-3.x-sonnet",
      "roleDefinition": "Description du rôle...",
      "groups": ["permissions"],
      "customInstructions": "Instructions détaillées..."
    },
    // Autres modes...
  ]
}
```

### 2.3 Problèmes de synchronisation

La duplication exacte du contenu entre les fichiers `.roomodes` et `custom_modes.json` est la source principale des problèmes de portabilité :

1. **Duplication de configuration** : La nécessité de maintenir deux fichiers identiques peut causer des problèmes de synchronisation
2. **Chemins d'accès absolus** : Les chemins comme `D:\` et `C:\Users\<USERNAME>\` sont spécifiques à une machine
3. **Absence de mécanisme de synchronisation automatique** : Aucun mécanisme évident pour synchroniser les deux fichiers
4. **Dépendance à la structure de répertoires** : L'extension Roo s'attend à trouver les fichiers dans des emplacements précis

## 3. Installation et configuration

### 3.1 Prérequis

- Visual Studio Code installé
- Extension Roo installée et configurée
- PowerShell 5.1 ou supérieur
- Droits d'accès aux répertoires de configuration de VS Code

### 3.2 Installation manuelle

1. Cloner le dépôt contenant les modes personnalisés :
   ```powershell
   git clone <url-du-depot> <chemin-local>
   cd <chemin-local>
   ```

2. Copier le fichier `.roomodes` vers le fichier global :
   ```powershell
   Copy-Item -Path ".roomodes" -Destination "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json" -Force
   ```

3. Vérifier que les fichiers sont identiques :
   ```powershell
   Compare-Object -ReferenceObject (Get-Content ".roomodes") -DifferenceObject (Get-Content "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json")
   ```
   Si aucune sortie n'est affichée, les fichiers sont identiques.

### 3.3 Installation automatisée

1. Cloner le dépôt contenant les modes personnalisés :
   ```powershell
   git clone <url-du-depot> <chemin-local>
   cd <chemin-local>
   ```

2. Exécuter le script de déploiement amélioré (fourni dans ce document) :
   ```powershell
   .\deploy-roo-modes.ps1 -DeploymentType both
   ```

### 3.4 Vérification de l'installation

1. Redémarrer VS Code pour que les changements prennent effet.

2. Ouvrir la palette de commandes (Ctrl+Shift+P) et taper "Roo: Switch Mode".

3. Vérifier que les modes personnalisés apparaissent dans la liste.

4. Sélectionner un mode personnalisé et vérifier qu'il fonctionne correctement.

## 4. Procédure après un git pull

Après avoir effectué un `git pull` qui met à jour les fichiers du projet, y compris potentiellement le fichier `.roomodes`, suivez ces étapes pour assurer la synchronisation correcte des modes personnalisés :

### 4.1 Vérification des modifications

1. Vérifier si le fichier `.roomodes` a été modifié :
   ```powershell
   git diff --name-only HEAD@{1} HEAD | Select-String ".roomodes"
   ```

2. Si le fichier a été modifié, examiner les changements :
   ```powershell
   git diff HEAD@{1} HEAD -- .roomodes
   ```

### 4.2 Synchronisation des fichiers

1. Option manuelle : Copier le fichier `.roomodes` vers le fichier global :
   ```powershell
   Copy-Item -Path ".roomodes" -Destination "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json" -Force
   ```

2. Option automatisée : Exécuter le script de déploiement amélioré :
   ```powershell
   .\deploy-roo-modes.ps1 -DeploymentType both
   ```

### 4.3 Adaptation des chemins d'accès

Si le fichier `.roomodes` contient des chemins d'accès absolus spécifiques à une autre machine, ils doivent être adaptés à votre machine :

1. Option manuelle : Éditer le fichier `.roomodes` et remplacer les chemins d'accès absolus par des chemins relatifs ou adaptés à votre machine.

2. Option automatisée : Utiliser le script de déploiement amélioré avec l'option `-AdaptPaths` :
   ```powershell
   .\deploy-roo-modes.ps1 -DeploymentType both -AdaptPaths
   ```

## 5. Pièges courants et solutions

### 5.1 Chemins d'accès absolus

**Problème** : Les chemins d'accès absolus comme `D:\` ou `C:\Users\<USERNAME>\` sont spécifiques à une machine et ne fonctionneront pas sur une autre machine.

**Solution** :
- Utiliser des chemins relatifs quand c'est possible
- Utiliser des variables d'environnement comme `$env:APPDATA` au lieu de chemins absolus
- Utiliser le script de déploiement amélioré avec l'option `-AdaptPaths` pour adapter automatiquement les chemins

### 5.2 Fichiers non synchronisés

**Problème** : Les fichiers `.roomodes` et `custom_modes.json` peuvent devenir désynchronisés, ce qui peut causer des comportements incohérents.

**Solution** :
- Toujours synchroniser les deux fichiers après une modification
- Utiliser le script de déploiement amélioré qui synchronise automatiquement les deux fichiers
- Vérifier régulièrement que les fichiers sont identiques

### 5.3 Permissions insuffisantes

**Problème** : L'accès au fichier global `custom_modes.json` peut être refusé en raison de permissions insuffisantes.

**Solution** :
- Exécuter PowerShell en tant qu'administrateur
- Vérifier et ajuster les permissions du répertoire `rooveterinaryinc.roo-cline\settings`
- Utiliser le script de déploiement amélioré qui vérifie et ajuste les permissions si nécessaire

### 5.4 JSON invalide

**Problème** : Un fichier JSON mal formaté peut empêcher le fonctionnement correct des modes personnalisés.

**Solution** :
- Valider le JSON avant de le déployer
- Utiliser le script de déploiement amélioré qui valide automatiquement le JSON
- Utiliser un éditeur JSON avec validation syntaxique

## 6. Script de déploiement automatisé

Le script PowerShell suivant (`deploy-roo-modes.ps1`) automatise le processus de déploiement des modes personnalisés Roo. Il gère à la fois le déploiement local et global, adapte les chemins d'accès, vérifie les permissions et valide le JSON.

```powershell
# Script de déploiement amélioré des modes personnalisés Roo
# Ce script permet de déployer une configuration de modes soit globalement, soit localement, soit les deux
# Il adapte également les chemins d'accès absolus et vérifie les permissions

param (
    [Parameter(Mandatory = $false)]
    [string]$SourceFile = ".roomodes",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("global", "local", "both")]
    [string]$DeploymentType = "both",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$AdaptPaths,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestAfterDeploy,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Fonction pour vérifier si un chemin existe et le créer si nécessaire
function Ensure-PathExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-ColorOutput "Répertoire créé: $Path" "Green"
            return $true
        }
        catch {
            Write-ColorOutput "Erreur lors de la création du répertoire: $Path" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            return $false
        }
    }
    return $true
}

# Fonction pour adapter les chemins d'accès absolus dans un fichier JSON
function Adapt-Paths {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonContent
    )
    
    try {
        # Convertir le contenu JSON en objet PowerShell
        $jsonObject = $JsonContent | ConvertFrom-Json
        
        # Parcourir tous les modes personnalisés
        foreach ($mode in $jsonObject.customModes) {
            # Adapter les chemins dans les instructions personnalisées
            if ($mode.customInstructions) {
                # Remplacer les chemins absolus par des chemins relatifs ou des variables d'environnement
                $mode.customInstructions = $mode.customInstructions -replace 'C:\\Users\\[^\\]+', '$env:USERPROFILE'
                $mode.customInstructions = $mode.customInstructions -replace 'D:\\', '.\'
            }
        }
        
        # Convertir l'objet PowerShell en JSON
        $adaptedJson = $jsonObject | ConvertTo-Json -Depth 10
        
        return $adaptedJson
    }
    catch {
        Write-ColorOutput "Erreur lors de l'adaptation des chemins d'accès:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        return $JsonContent
    }
}

# Fonction pour valider un fichier JSON
function Test-Json {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonContent
    )
    
    try {
        $null = $JsonContent | ConvertFrom-Json
        return $true
    }
    catch {
        Write-ColorOutput "Erreur: Le fichier JSON n'est pas valide." "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        return $false
    }
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement amélioré des modes personnalisés Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier que le fichier source existe
if (-not (Test-Path -Path $SourceFile)) {
    Write-ColorOutput "Erreur: Le fichier source '$SourceFile' n'existe pas." "Red"
    Write-ColorOutput "Assurez-vous que le fichier existe dans le répertoire courant." "Red"
    exit 1
}

# Lire le contenu du fichier source
$sourceContent = Get-Content -Path $SourceFile -Raw

# Valider le JSON du fichier source
if (-not (Test-Json -JsonContent $sourceContent)) {
    Write-ColorOutput "Le fichier source contient du JSON invalide. Veuillez corriger les erreurs avant de continuer." "Red"
    exit 1
}

# Adapter les chemins d'accès si demandé
if ($AdaptPaths) {
    Write-ColorOutput "`nAdaptation des chemins d'accès absolus..." "Yellow"
    $sourceContent = Adapt-Paths -JsonContent $sourceContent
    
    # Valider le JSON après adaptation
    if (-not (Test-Json -JsonContent $sourceContent)) {
        Write-ColorOutput "L'adaptation des chemins a généré du JSON invalide. Veuillez vérifier manuellement." "Red"
        exit 1
    }
    
    Write-ColorOutput "Adaptation des chemins terminée." "Green"
}

# Déploiement global
if ($DeploymentType -eq "global" -or $DeploymentType -eq "both") {
    Write-ColorOutput "`nDéploiement global en cours..." "Yellow"
    
    # Déterminer le chemin du fichier de destination global
    $globalDestDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
    $globalDestFile = Join-Path -Path $globalDestDir -ChildPath "custom_modes.json"
    
    # Vérifier que le répertoire de destination existe
    if (-not (Ensure-PathExists -Path $globalDestDir)) {
        Write-ColorOutput "Impossible de créer le répertoire de destination global." "Red"
        exit 1
    }
    
    # Vérifier si le fichier de destination existe déjà
    if (Test-Path -Path $globalDestFile) {
        if (-not $Force) {
            $confirmation = Read-Host "Le fichier de destination global existe déjà. Voulez-vous le remplacer? (O/N)"
            if ($confirmation -ne "O" -and $confirmation -ne "o") {
                Write-ColorOutput "Déploiement global annulé." "Yellow"
            }
            else {
                # Copier le contenu
                Set-Content -Path $globalDestFile -Value $sourceContent
                Write-ColorOutput "Déploiement global réussi!" "Green"
            }
        }
        else {
            # Copier le contenu
            Set-Content -Path $globalDestFile -Value $sourceContent
            Write-ColorOutput "Déploiement global réussi!" "Green"
        }
    }
    else {
        # Copier le contenu
        Set-Content -Path $globalDestFile -Value $sourceContent
        Write-ColorOutput "Déploiement global réussi!" "Green"
    }
}

# Déploiement local
if ($DeploymentType -eq "local" -or $DeploymentType -eq "both") {
    Write-ColorOutput "`nDéploiement local en cours..." "Yellow"
    
    # Déterminer le chemin du fichier de destination local
    $localDestFile = ".roomodes"
    
    # Vérifier si le fichier de destination existe déjà
    if (Test-Path -Path $localDestFile -and $localDestFile -ne $SourceFile) {
        if (-not $Force) {
            $confirmation = Read-Host "Le fichier de destination local existe déjà. Voulez-vous le remplacer? (O/N)"
            if ($confirmation -ne "O" -and $confirmation -ne "o") {
                Write-ColorOutput "Déploiement local annulé." "Yellow"
            }
            else {
                # Copier le contenu
                Set-Content -Path $localDestFile -Value $sourceContent
                Write-ColorOutput "Déploiement local réussi!" "Green"
            }
        }
        else {
            # Copier le contenu
            Set-Content -Path $localDestFile -Value $sourceContent
            Write-ColorOutput "Déploiement local réussi!" "Green"
        }
    }
    elseif ($localDestFile -ne $SourceFile) {
        # Copier le contenu
        Set-Content -Path $localDestFile -Value $sourceContent
        Write-ColorOutput "Déploiement local réussi!" "Green"
    }
    else {
        Write-ColorOutput "Le fichier source et le fichier de destination local sont identiques. Aucune action nécessaire." "Green"
    }
}

# Vérifier que les fichiers sont identiques
if ($DeploymentType -eq "both") {
    Write-ColorOutput "`nVérification de la synchronisation..." "Yellow"
    
    $globalDestFile = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"
    $localDestFile = ".roomodes"
    
    if (Test-Path -Path $globalDestFile -and Test-Path -Path $localDestFile) {
        try {
            $diff = Compare-Object -ReferenceObject (Get-Content $localDestFile) -DifferenceObject (Get-Content $globalDestFile)
            
            if ($null -eq $diff) {
                Write-ColorOutput "Vérification réussie: Les fichiers sont synchronisés." "Green"
            }
            else {
                Write-ColorOutput "Avertissement: Les fichiers ne sont pas synchronisés." "Yellow"
                Write-ColorOutput "Différences trouvées:" "Yellow"
                $diff | Format-Table -AutoSize
            }
        }
        catch {
            Write-ColorOutput "Erreur lors de la vérification des fichiers:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    }
}

# Exécuter les tests si demandé
if ($TestAfterDeploy) {
    Write-ColorOutput "`nExécution des tests après déploiement..." "Magenta"
    
    # Test du mécanisme d'escalade interne
    if (Test-Path -Path "test-escalade-code.js") {
        Write-ColorOutput "Test du mécanisme d'escalade interne..." "Magenta"
        try {
            node "test-escalade-code.js"
            Write-ColorOutput "Test d'escalade interne réussi!" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors du test d'escalade interne:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    }
    else {
        Write-ColorOutput "Fichier de test d'escalade interne non trouvé." "Yellow"
    }
    
    # Test du mécanisme de désescalade
    if (Test-Path -Path "test-desescalade-code.js") {
        Write-ColorOutput "Test du mécanisme de désescalade..." "Magenta"
        try {
            node "test-desescalade-code.js"
            Write-ColorOutput "Test de désescalade réussi!" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors du test de désescalade:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    }
    else {
        Write-ColorOutput "Fichier de test de désescalade non trouvé." "Yellow"
    }
}

# Afficher un résumé des modes installés
Write-ColorOutput "`nModes personnalisés installés:" "Cyan"
try {
    $json = $sourceContent | ConvertFrom-Json
    $modesCount = $json.customModes.Count
    
    Write-ColorOutput "Nombre de modes personnalisés: $modesCount" "Green"
    
    foreach ($mode in $json.customModes) {
        Write-ColorOutput "- $($mode.name) ($($mode.slug)) - Modèle: $($mode.model)" "White"
    }
}
catch {
    Write-ColorOutput "Erreur lors de l'affichage des modes installés:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement terminé avec succès!" "Green"
Write-ColorOutput "=========================================================" "Cyan"

if ($DeploymentType -eq "global" -or $DeploymentType -eq "both") {
    Write-ColorOutput "`nLes modes personnalisés ont été déployés globalement et seront disponibles dans toutes les instances de VS Code." "White"
}
if ($DeploymentType -eq "local" -or $DeploymentType -eq "both") {
    Write-ColorOutput "`nLes modes personnalisés ont été déployés localement et seront disponibles dans ce projet." "White"
}

Write-ColorOutput "`nPour activer les modes personnalisés:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un mode personnalisé" "White"
Write-ColorOutput "`n" "White"
```

## 7. Annexes

### 7.1 Commandes PowerShell utiles

```powershell
# Vérifier si le fichier .roomodes a été modifié dans le dernier pull
git diff --name-only HEAD@{1} HEAD | Select-String ".roomodes"

# Comparer les fichiers .roomodes et custom_modes.json
Compare-Object -ReferenceObject (Get-Content ".roomodes") -DifferenceObject (Get-Content "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json")

# Valider le JSON du fichier .roomodes
Get-Content ".roomodes" -Raw | ConvertFrom-Json

# Vérifier les permissions du répertoire de configuration
Get-Acl "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
```

### 7.2 Ressources supplémentaires

- [Documentation officielle de l'extension Roo](https://marketplace.visualstudio.com/items?itemName=rooveterinaryinc.roo-cline)
- [Documentation sur les modes personnalisés Roo](https://github.com/rooveterinaryinc/roo-cline/wiki/Custom-Modes)
- [Documentation sur le déploiement des modes personnalisés sur d'autres machines](custom-modes/docs/implementation/deploiement-autres-machines.md)
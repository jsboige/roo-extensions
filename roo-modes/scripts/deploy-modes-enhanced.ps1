# Script de déploiement amélioré des modes personnalisés Roo
# Ce script permet de déployer une configuration de modes soit globalement, soit localement
# Il prépare également les instructions pour le déploiement sur une autre machine via git

param (
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "../configs/standard-modes.json",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("global", "local")]
    [string]$DeploymentType = "global",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$PrepareGitInstructions,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestAfterDeploy
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

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement amélioré des modes personnalisés Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier que le fichier de configuration existe
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFilePath = Join-Path -Path $scriptDir -ChildPath $ConfigFile

if (-not (Test-Path -Path $configFilePath)) {
    Write-ColorOutput "Erreur: Le fichier de configuration '$ConfigFile' n'existe pas." "Red"
    Write-ColorOutput "Assurez-vous que le fichier existe dans le répertoire 'roo-modes/configs/'." "Red"
    exit 1
}

# Déterminer le chemin du fichier de destination
if ($DeploymentType -eq "global") {
    $destinationDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
    $destinationFile = Join-Path -Path $destinationDir -ChildPath "custom_modes.json"
    
    # Vérifier que le répertoire de destination existe
    if (-not (Test-Path -Path $destinationDir)) {
        try {
            New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
            Write-ColorOutput "Répertoire créé: $destinationDir" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors de la création du répertoire: $destinationDir" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            exit 1
        }
    }
} else {
    # Déploiement local (dans le répertoire du projet)
    $projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
    # Ajustement pour la nouvelle structure de répertoires (scripts est maintenant un sous-répertoire de roo-modes)
    $destinationFile = Join-Path -Path $projectRoot -ChildPath ".roomodes"
}

Write-ColorOutput "`nDéploiement de la configuration '$ConfigFile' en mode $DeploymentType..." "Yellow"
Write-ColorOutput "Destination: $destinationFile" "Yellow"

# Vérifier si le fichier de destination existe déjà
if (Test-Path -Path $destinationFile) {
    if (-not $Force) {
        $confirmation = Read-Host "Le fichier de destination existe déjà. Voulez-vous le remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-ColorOutput "Opération annulée." "Yellow"
            exit 0
        }
    }
}

# Copier le fichier
try {
    Copy-Item -Path $configFilePath -Destination $destinationFile -Force
    Write-ColorOutput "Déploiement réussi!" "Green"
} catch {
    Write-ColorOutput "Erreur lors du déploiement:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Vérifier que les fichiers sont identiques
try {
    $diff = Compare-Object -ReferenceObject (Get-Content $configFilePath) -DifferenceObject (Get-Content $destinationFile)
    
    if ($null -eq $diff) {
        Write-ColorOutput "Vérification réussie: Les fichiers sont identiques." "Green"
    } else {
        Write-ColorOutput "Avertissement: Les fichiers ne sont pas identiques." "Yellow"
        Write-ColorOutput "Différences trouvées:" "Yellow"
        $diff | Format-Table -AutoSize
    }
} catch {
    Write-ColorOutput "Erreur lors de la vérification des fichiers:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
}

# Exécuter les tests si demandé
if ($TestAfterDeploy) {
    Write-ColorOutput "`nExécution des tests après déploiement..." "Magenta"
    
    # Test du mécanisme d'escalade interne
    if (Test-Path -Path "$projectRoot/test-escalade-code.js") {
        Write-ColorOutput "Test du mécanisme d'escalade interne..." "Magenta"
        try {
            node "$projectRoot/test-escalade-code.js"
            Write-ColorOutput "Test d'escalade interne réussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test d'escalade interne:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test d'escalade interne non trouvé." "Yellow"
    }
    
    # Test du mécanisme d'escalade par approfondissement
    if (Test-Path -Path "$projectRoot/test-escalade-approfondissement.js") {
        Write-ColorOutput "Test du mécanisme d'escalade par approfondissement..." "Magenta"
        try {
            node "$projectRoot/test-escalade-approfondissement.js"
            Write-ColorOutput "Test d'escalade par approfondissement réussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test d'escalade par approfondissement:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test d'escalade par approfondissement non trouvé." "Yellow"
    }
    
    # Test du mécanisme de désescalade
    if (Test-Path -Path "$projectRoot/test-desescalade-code.js") {
        Write-ColorOutput "Test du mécanisme de désescalade..." "Magenta"
        try {
            node "$projectRoot/test-desescalade-code.js"
            Write-ColorOutput "Test de désescalade réussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test de désescalade:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test de désescalade non trouvé." "Yellow"
    }
    
    # Test du mécanisme de désescalade systématique
    if (Test-Path -Path "$projectRoot/test-desescalade-systematique.js") {
        Write-ColorOutput "Test du mécanisme de désescalade systématique..." "Magenta"
        try {
            node "$projectRoot/test-desescalade-systematique.js"
            Write-ColorOutput "Test de désescalade systématique réussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test de désescalade systématique:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test de désescalade systématique non trouvé." "Yellow"
    }
    
    # Test de l'utilisation des MCPs
    if (Test-Path -Path "$projectRoot/test-mcp.js") {
        Write-ColorOutput "Test de l'utilisation des MCPs..." "Magenta"
        try {
            node "$projectRoot/test-mcp.js"
            Write-ColorOutput "Test des MCPs réussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test des MCPs:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test des MCPs non trouvé." "Yellow"
    }
    
    # Test du mode Manager
    if (Test-Path -Path "$projectRoot/scenario-test-manager.js") {
        Write-ColorOutput "Test du mode Manager..." "Magenta"
        try {
            node "$projectRoot/scenario-test-manager.js"
            Write-ColorOutput "Test du mode Manager réussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test du mode Manager:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test du mode Manager non trouvé." "Yellow"
    }
}

# Préparer les instructions Git si demandé
if ($PrepareGitInstructions) {
    Write-ColorOutput "`nPréparation des instructions pour le déploiement via Git..." "Cyan"
    
    $gitInstructionsFile = Join-Path -Path $scriptDir -ChildPath "git-deployment-instructions.md"
    
    $gitInstructions = @"
# Instructions pour le déploiement des modes personnalisés via Git

Ce document fournit les instructions pour déployer les modes personnalisés Roo sur une autre machine en utilisant Git.

## Prérequis

- Git installé sur la machine cible
- Accès au dépôt Git contenant les modes personnalisés
- Visual Studio Code avec l'extension Roo installée

## Instructions de déploiement

1. Ouvrez un terminal sur la machine cible

2. Clonez le dépôt Git (si ce n'est pas déjà fait) :
   ```
   git clone <URL_DU_DEPOT> roo-extensions
   cd roo-extensions
   ```

3. Si le dépôt est déjà cloné, mettez-le à jour :
   ```
   cd roo-extensions
   git pull
   ```

4. Déployez les modes personnalisés :
   ```
   cd roo-modes/scripts
   ./deploy-modes-enhanced.ps1 -DeploymentType global -Force
   ```

5. Pour un déploiement local (spécifique au projet) :
   ```
   cd roo-modes/scripts
   ./deploy-modes-enhanced.ps1 -DeploymentType local -Force
   ```

6. Pour exécuter les tests après le déploiement :
   ```
   cd roo-modes/scripts
   ./deploy-modes-enhanced.ps1 -DeploymentType global -Force -TestAfterDeploy
   ```

7. Pour exécuter un test spécifique :
   ```
   node test-escalade-approfondissement.js
   node scenario-test-manager.js
   node test-desescalade-code.js
   node test-desescalade-systematique.js
   ```

## Vérification du déploiement

1. Redémarrez Visual Studio Code
2. Ouvrez la palette de commandes (Ctrl+Shift+P)
3. Tapez 'Roo: Switch Mode' et vérifiez que les modes personnalisés sont disponibles
4. Vérifiez spécifiquement que le nouveau mode "Manager" est disponible et fonctionne correctement

## Résolution des problèmes

Si les modes personnalisés ne sont pas disponibles après le déploiement :

1. Vérifiez que le fichier de configuration a été correctement copié :
   - Pour un déploiement global : `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`
   - Pour un déploiement local : `.roomodes` dans le répertoire du projet

2. Assurez-vous que le fichier JSON est valide en utilisant un validateur JSON

3. Redémarrez Visual Studio Code

4. Si le problème persiste, consultez les journaux de l'extension Roo

## Tests spécifiques au mode Manager

Pour tester spécifiquement le mode Manager après le déploiement :

1. Exécutez le script de test du mode Manager :
   ```
   node scenario-test-manager.js
   ```

2. Vérifiez que le mode Manager peut :
   - Créer des sous-tâches orchestrateurs pour des tâches de haut-niveau
   - Décomposer des tâches complexes en sous-tâches composites
   - Créer systématiquement des sous-tâches du niveau de complexité minimale nécessaire
"@
    
    Set-Content -Path $gitInstructionsFile -Value $gitInstructions
    Write-ColorOutput "Instructions Git générées: $gitInstructionsFile" "Green"
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement terminé avec succès!" "Green"
Write-ColorOutput "=========================================================" "Cyan"

if ($DeploymentType -eq "global") {
    Write-ColorOutput "`nLes modes personnalisés ont été déployés globalement et seront disponibles dans toutes les instances de VS Code." "White"
} else {
    Write-ColorOutput "`nLes modes personnalisés ont été déployés localement et seront disponibles uniquement dans ce projet." "White"
}

Write-ColorOutput "`nPour activer les modes personnalisés:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un mode personnalisé" "White"
Write-ColorOutput "`n" "White"

if ($PrepareGitInstructions) {
    Write-ColorOutput "Les instructions pour le déploiement via Git ont été générées dans:" "White"
    Write-ColorOutput "$gitInstructionsFile" "White"
    Write-ColorOutput "`n" "White"
}
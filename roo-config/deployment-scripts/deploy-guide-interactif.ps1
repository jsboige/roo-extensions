# Guide interactif pour le déploiement des modes simple et complex sur Windows
# Ce script guide l'utilisateur à travers les étapes de déploiement des modes
# en appliquant les recommandations du rapport final

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
Clear-Host
Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "   Guide interactif pour le déploiement des modes Roo" "Cyan"
Write-ColorOutput "   (Simple et Complex sur Windows)" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "`nCe guide vous accompagnera pas à pas dans le déploiement des modes simple et complex pour Roo.`n" "White"

# Vérifier que tous les scripts nécessaires existent
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$requiredScripts = @(
    "check-deployed-encoding.ps1",
    "fix-encoding-complete.ps1",
    "fix-encoding-final.ps1",
    "deploy-modes-simple-complex.ps1",
    "verify-deployed-modes.ps1",
    "force-deploy-with-encoding-fix.ps1"
)

$missingScripts = @()
foreach ($script in $requiredScripts) {
    $scriptPath = Join-Path -Path $scriptDir -ChildPath $script
    if (-not (Test-Path -Path $scriptPath)) {
        $missingScripts += $script
    }
}

if ($missingScripts.Count -gt 0) {
    Write-ColorOutput "Erreur: Les scripts suivants sont manquants:" "Red"
    foreach ($script in $missingScripts) {
        Write-ColorOutput "- $script" "Red"
    }
    Write-ColorOutput "Veuillez vous assurer que tous les scripts nécessaires sont présents dans le répertoire $scriptDir" "Red"
    exit 1
}

# Étape 1: Vérification de l'environnement
Write-ColorOutput "`n[Étape 1/5] Vérification de l'environnement" "Yellow"
Write-ColorOutput "-------------------------------------------" "Yellow"

# Vérifier si le fichier source existe
$sourceFilePath = Join-Path -Path $scriptDir -ChildPath "..\roo-modes\configs\standard-modes.json"
if (-not (Test-Path -Path $sourceFilePath)) {
    Write-ColorOutput "Erreur: Le fichier source 'standard-modes.json' n'existe pas." "Red"
    Write-ColorOutput "Chemin attendu: $sourceFilePath" "Red"
    
    $createEmptyFile = Read-Host "Voulez-vous créer un fichier vide à cet emplacement? (O/N)"
    if ($createEmptyFile -eq "O" -or $createEmptyFile -eq "o") {
        try {
            New-Item -Path $sourceFilePath -ItemType File -Force | Out-Null
            Write-ColorOutput "Fichier vide créé. Vous devrez y ajouter le contenu approprié avant de continuer." "Yellow"
            exit 0
        } catch {
            Write-ColorOutput "Erreur lors de la création du fichier: $_" "Red"
            exit 1
        }
    } else {
        Write-ColorOutput "Veuillez créer le fichier source avant de continuer." "Red"
        exit 1
    }
}

Write-ColorOutput "✓ Le fichier source existe." "Green"

# Vérifier le répertoire de destination
$destinationDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
if (-not (Test-Path -Path $destinationDir)) {
    Write-ColorOutput "Le répertoire de destination n'existe pas: $destinationDir" "Yellow"
    Write-ColorOutput "Il sera créé automatiquement lors du déploiement." "Yellow"
} else {
    Write-ColorOutput "✓ Le répertoire de destination existe." "Green"
    
    # Vérifier si le fichier de destination existe déjà
    $destinationFile = Join-Path -Path $destinationDir -ChildPath "custom_modes.json"
    if (Test-Path -Path $destinationFile) {
        Write-ColorOutput "✓ Le fichier de destination existe déjà." "Green"
        Write-ColorOutput "  Il sera remplacé lors du déploiement." "Yellow"
    }
}

# Étape 2: Vérification de l'encodage
Write-ColorOutput "`n[Étape 2/5] Vérification de l'encodage du fichier source" "Yellow"
Write-ColorOutput "---------------------------------------------------" "Yellow"

Write-ColorOutput "Exécution du script de vérification d'encodage..." "White"
$checkEncodingScript = Join-Path -Path $scriptDir -ChildPath "check-deployed-encoding.ps1"
& $checkEncodingScript

$fixEncoding = Read-Host "`nSouhaitez-vous corriger l'encodage du fichier source? (O/N)"
if ($fixEncoding -eq "O" -or $fixEncoding -eq "o") {
    Write-ColorOutput "`nSélectionnez la méthode de correction:" "White"
    Write-ColorOutput "1. Correction complète (recommandé)" "White"
    Write-ColorOutput "2. Correction avancée avec expressions régulières" "White"
    $correctionMethod = Read-Host "Votre choix (1 ou 2)"
    
    if ($correctionMethod -eq "1") {
        $fixEncodingScript = Join-Path -Path $scriptDir -ChildPath "fix-encoding-complete.ps1"
        Write-ColorOutput "Exécution du script de correction complète..." "White"
        & $fixEncodingScript
    } elseif ($correctionMethod -eq "2") {
        $fixEncodingScript = Join-Path -Path $scriptDir -ChildPath "fix-encoding-final.ps1"
        Write-ColorOutput "Exécution du script de correction avancée..." "White"
        & $fixEncodingScript
    } else {
        Write-ColorOutput "Choix invalide. Aucune correction appliquée." "Red"
    }
}

# Étape 3: Déploiement
Write-ColorOutput "`n[Étape 3/5] Déploiement des modes" "Yellow"
Write-ColorOutput "----------------------------" "Yellow"

Write-ColorOutput "Sélectionnez le type de déploiement:" "White"
Write-ColorOutput "1. Déploiement simple avec force (recommandé)" "White"
Write-ColorOutput "2. Déploiement avec options avancées" "White"
$deploymentMethod = Read-Host "Votre choix (1 ou 2)"

if ($deploymentMethod -eq "1") {
    $deployScript = Join-Path -Path $scriptDir -ChildPath "simple-deploy.ps1"
    Write-ColorOutput "Exécution du script de déploiement simple..." "White"
    & $deployScript
} elseif ($deploymentMethod -eq "2") {
    Write-ColorOutput "`nSélectionnez le type de déploiement:" "White"
    Write-ColorOutput "1. Déploiement global (pour tous les projets)" "White"
    Write-ColorOutput "2. Déploiement local (pour ce projet uniquement)" "White"
    $deploymentType = Read-Host "Votre choix (1 ou 2)"
    
    $deploymentTypeParam = if ($deploymentType -eq "1") { "global" } else { "local" }
    
    $forceDeployment = Read-Host "Forcer le déploiement? (O/N)"
    $forceParam = if ($forceDeployment -eq "O" -or $forceDeployment -eq "o") { "-Force" } else { "" }
    
    $testAfterDeploy = Read-Host "Exécuter les tests après le déploiement? (O/N)"
    $testParam = if ($testAfterDeploy -eq "O" -or $testAfterDeploy -eq "o") { "-TestAfterDeploy" } else { "" }
    
    $deployScript = Join-Path -Path $scriptDir -ChildPath "deploy-modes-simple-complex.ps1"
    $deployCommand = "$deployScript -DeploymentType $deploymentTypeParam $forceParam $testParam"
    
    Write-ColorOutput "Exécution de la commande: $deployCommand" "White"
    Invoke-Expression $deployCommand
} else {
    Write-ColorOutput "Choix invalide. Aucun déploiement effectué." "Red"
    exit 1
}

# Étape 4: Vérification du déploiement
Write-ColorOutput "`n[Étape 4/5] Vérification du déploiement" "Yellow"
Write-ColorOutput "-----------------------------------" "Yellow"

$verifyScript = Join-Path -Path $scriptDir -ChildPath "verify-deployed-modes.ps1"
Write-ColorOutput "Exécution du script de vérification..." "White"
& $verifyScript

$deploymentSuccessful = Read-Host "`nLe déploiement a-t-il réussi? (O/N)"
if ($deploymentSuccessful -ne "O" -and $deploymentSuccessful -ne "o") {
    Write-ColorOutput "`nRésolution des problèmes:" "Yellow"
    Write-ColorOutput "1. Forcer le déploiement avec correction d'encodage" "White"
    Write-ColorOutput "2. Quitter et résoudre manuellement" "White"
    $troubleshootOption = Read-Host "Votre choix (1 ou 2)"
    
    if ($troubleshootOption -eq "1") {
        $forceDeployScript = Join-Path -Path $scriptDir -ChildPath "force-deploy-with-encoding-fix.ps1"
        Write-ColorOutput "Exécution du script de déploiement forcé avec correction d'encodage..." "White"
        & $forceDeployScript
    } else {
        Write-ColorOutput "Veuillez consulter le rapport de déploiement pour plus d'informations sur la résolution des problèmes." "Yellow"
        $openReport = Read-Host "Voulez-vous ouvrir le rapport de déploiement? (O/N)"
        if ($openReport -eq "O" -or $openReport -eq "o") {
            $reportPath = Join-Path -Path $scriptDir -ChildPath "..\docs\rapports\rapport-final-deploiement-modes-windows.md"
            if (Test-Path $reportPath) {
                Start-Process $reportPath
            } else {
                Write-ColorOutput "Rapport non trouvé: $reportPath" "Red"
            }
        }
        exit 1
    }
}

# Étape 5: Instructions finales
Write-ColorOutput "`n[Étape 5/5] Instructions finales" "Yellow"
Write-ColorOutput "----------------------------" "Yellow"

Write-ColorOutput "Pour activer les modes déployés:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un des modes suivants:" "White"
Write-ColorOutput "   - 💻 Code Simple" "White"
Write-ColorOutput "   - 💻 Code Complex" "White"
Write-ColorOutput "   - 🪲 Debug Simple" "White"
Write-ColorOutput "   - 🪲 Debug Complex" "White"
Write-ColorOutput "   - 🏗️ Architect Simple" "White"
Write-ColorOutput "   - 🏗️ Architect Complex" "White"
Write-ColorOutput "   - ❓ Ask Simple" "White"
Write-ColorOutput "   - ❓ Ask Complex" "White"
Write-ColorOutput "   - 🪃 Orchestrator Simple" "White"
Write-ColorOutput "   - 🪃 Orchestrator Complex" "White"
Write-ColorOutput "   - 👨‍💼 Manager" "White"

# Conclusion
Write-ColorOutput "`n==========================================================" "Cyan"
Write-ColorOutput "   Déploiement terminé!" "Green"
Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "`nPour plus d'informations, consultez le rapport complet:" "White"
Write-ColorOutput "..\docs\rapports\rapport-final-deploiement-modes-windows.md" "White"
Write-ColorOutput "`nEn cas de problème persistant, consultez la section 'Résolution des problèmes persistants' du rapport." "White"
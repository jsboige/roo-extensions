# Script de vérification d'accessibilité à distance pour les modes personnalisés Roo
# Ce script vérifie que les fichiers nécessaires sont accessibles depuis une autre machine
# et que le script de déploiement pour les endpoints locaux est syntaxiquement correct.

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

# Fonction pour ajouter une entrée au rapport
function Add-ReportEntry {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Category,
        
        [Parameter(Mandatory = $true)]
        [string]$Status,
        
        [Parameter(Mandatory = $false)]
        [string]$Details = "",
        
        [Parameter(Mandatory = $false)]
        [string]$Recommendation = ""
    )
    
    $script:report += [PSCustomObject]@{
        Category = $Category
        Status = $Status
        Details = $Details
        Recommendation = $Recommendation
    }
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Vérification d'accessibilité à distance des modes Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Initialiser le rapport
$report = @()

# Déterminer le répertoire du projet
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Write-ColorOutput "`nRépertoire du projet: $projectRoot" "Yellow"

# 1. Vérifier que le dépôt Git peut être cloné ou mis à jour
Write-ColorOutput "`n[1/3] Vérification de l'accessibilité du dépôt Git..." "Yellow"

try {
    # Vérifier si le répertoire est un dépôt Git
    $gitStatus = git -C $projectRoot status 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Le répertoire est un dépôt Git valide." "Green"
        
        # Vérifier si le dépôt a une origine distante
        $remoteUrl = git -C $projectRoot remote get-url origin 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "URL du dépôt distant: $remoteUrl" "Green"
            
            # Tester l'accessibilité du dépôt distant
            $lsRemote = git -C $projectRoot ls-remote --heads $remoteUrl 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Le dépôt distant est accessible." "Green"
                Add-ReportEntry -Category "Dépôt Git" -Status "OK" -Details "Le dépôt Git est accessible à l'URL: $remoteUrl"
            } else {
                Write-ColorOutput "Le dépôt distant n'est pas accessible." "Red"
                Add-ReportEntry -Category "Dépôt Git" -Status "ERREUR" -Details "Le dépôt distant n'est pas accessible: $remoteUrl" -Recommendation "Vérifiez les permissions d'accès au dépôt et la connectivité réseau."
            }
        } else {
            Write-ColorOutput "Aucune origine distante configurée." "Yellow"
            Add-ReportEntry -Category "Dépôt Git" -Status "AVERTISSEMENT" -Details "Aucune origine distante configurée." -Recommendation "Configurez une origine distante avec 'git remote add origin <url>'"
        }
    } else {
        Write-ColorOutput "Le répertoire n'est pas un dépôt Git valide." "Red"
        Add-ReportEntry -Category "Dépôt Git" -Status "ERREUR" -Details "Le répertoire n'est pas un dépôt Git valide." -Recommendation "Initialisez un dépôt Git avec 'git init' ou clonez un dépôt existant."
    }
} catch {
    Write-ColorOutput "Erreur lors de la vérification du dépôt Git: $_" "Red"
    Add-ReportEntry -Category "Dépôt Git" -Status "ERREUR" -Details "Erreur lors de la vérification du dépôt Git: $_" -Recommendation "Assurez-vous que Git est installé et accessible dans le PATH."
}

# 2. Vérifier que les fichiers créés sont présents et lisibles
Write-ColorOutput "`n[2/3] Vérification de l'accessibilité des fichiers..." "Yellow"

$filesToCheck = @(
    ".roomodes",
    "custom-modes\scripts\deploy.ps1",
    "custom-modes\scripts\deploy-local-endpoints.ps1",
    "custom-modes\docs\implementation\deploiement-autres-machines.md",
    "custom-modes\docs\implementation\script-deploy-local-endpoints.md"
)

$missingFiles = @()
$inaccessibleFiles = @()

foreach ($file in $filesToCheck) {
    $filePath = Join-Path -Path $projectRoot -ChildPath $file
    
    if (Test-Path -Path $filePath) {
        try {
            $content = Get-Content -Path $filePath -ErrorAction Stop
            Write-ColorOutput "Fichier accessible: $file" "Green"
        } catch {
            Write-ColorOutput "Fichier inaccessible: $file" "Red"
            $inaccessibleFiles += $file
        }
    } else {
        Write-ColorOutput "Fichier manquant: $file" "Red"
        $missingFiles += $file
    }
}

if ($missingFiles.Count -eq 0 -and $inaccessibleFiles.Count -eq 0) {
    Add-ReportEntry -Category "Fichiers" -Status "OK" -Details "Tous les fichiers nécessaires sont présents et accessibles."
} else {
    $details = ""
    
    if ($missingFiles.Count -gt 0) {
        $details += "Fichiers manquants: $($missingFiles -join ', ')`n"
    }
    
    if ($inaccessibleFiles.Count -gt 0) {
        $details += "Fichiers inaccessibles: $($inaccessibleFiles -join ', ')"
    }
    
    Add-ReportEntry -Category "Fichiers" -Status "ERREUR" -Details $details.Trim() -Recommendation "Assurez-vous que tous les fichiers nécessaires sont présents et ont les permissions appropriées."
}

# 3. Tester le script de déploiement pour les endpoints locaux
Write-ColorOutput "`n[3/3] Vérification syntaxique du script de déploiement..." "Yellow"

$deployScriptPath = Join-Path -Path $projectRoot -ChildPath "custom-modes\scripts\deploy-local-endpoints.ps1"

if (Test-Path -Path $deployScriptPath) {
    try {
        # Vérifier la syntaxe du script sans l'exécuter
        $syntaxErrors = $null
        [System.Management.Automation.PSParser]::Tokenize((Get-Content -Path $deployScriptPath -Raw), [ref]$syntaxErrors)
        
        if ($syntaxErrors.Count -eq 0) {
            Write-ColorOutput "Le script de déploiement est syntaxiquement correct." "Green"
            Add-ReportEntry -Category "Script de déploiement" -Status "OK" -Details "Le script de déploiement est syntaxiquement correct."
            
            # Vérifier les chemins dans le script
            $scriptContent = Get-Content -Path $deployScriptPath -Raw
            
            # Vérifier les chemins absolus
            $absolutePaths = [regex]::Matches($scriptContent, '(?i)(C:\\|D:\\|E:\\|F:\\|G:\\|H:\\|I:\\|J:\\|K:\\|L:\\|M:\\|N:\\|O:\\|P:\\|Q:\\|R:\\|S:\\|T:\\|U:\\|V:\\|W:\\|X:\\|Y:\\|Z:\\)[^"'']*')
            
            if ($absolutePaths.Count -gt 0) {
                $pathsList = $absolutePaths.Value -join ', '
                Write-ColorOutput "Le script contient des chemins absolus: $pathsList" "Yellow"
                Add-ReportEntry -Category "Chemins absolus" -Status "AVERTISSEMENT" -Details "Le script contient des chemins absolus: $pathsList" -Recommendation "Remplacez les chemins absolus par des chemins relatifs ou des variables d'environnement pour améliorer la compatibilité entre machines."
            }
            
            # Vérifier les URLs codées en dur
            $hardcodedUrls = [regex]::Matches($scriptContent, 'http://localhost:[0-9]+')
            
            if ($hardcodedUrls.Count -gt 0) {
                $urlsList = $hardcodedUrls.Value -join ', '
                Write-ColorOutput "Le script contient des URLs codées en dur: $urlsList" "Yellow"
                Add-ReportEntry -Category "URLs codées en dur" -Status "AVERTISSEMENT" -Details "Le script contient des URLs codées en dur: $urlsList" -Recommendation "Paramétrez les URLs pour permettre leur configuration selon l'environnement."
            }
        } else {
            $errorMessages = $syntaxErrors | ForEach-Object { $_.Message }
            Write-ColorOutput "Le script de déploiement contient des erreurs de syntaxe:" "Red"
            $errorMessages | ForEach-Object { Write-ColorOutput "- $_" "Red" }
            
            Add-ReportEntry -Category "Script de déploiement" -Status "ERREUR" -Details "Le script contient des erreurs de syntaxe: $($errorMessages -join ', ')" -Recommendation "Corrigez les erreurs de syntaxe dans le script."
        }
    } catch {
        Write-ColorOutput "Erreur lors de la vérification du script: $_" "Red"
        Add-ReportEntry -Category "Script de déploiement" -Status "ERREUR" -Details "Erreur lors de la vérification du script: $_" -Recommendation "Vérifiez le contenu du script et assurez-vous qu'il est valide."
    }
} else {
    Write-ColorOutput "Le script de déploiement n'existe pas: $deployScriptPath" "Red"
    Add-ReportEntry -Category "Script de déploiement" -Status "ERREUR" -Details "Le script de déploiement n'existe pas: $deployScriptPath" -Recommendation "Créez le script de déploiement à partir du modèle dans 'custom-modes/docs/implementation/script-deploy-local-endpoints.md'."
}

# Vérifier les configurations des endpoints
Write-ColorOutput "`nVérification des configurations des endpoints..." "Yellow"

$roomodesPath = Join-Path -Path $projectRoot -ChildPath ".roomodes"
$roomodesLocalPath = Join-Path -Path $projectRoot -ChildPath ".roomodes-local"

if (Test-Path -Path $roomodesLocalPath) {
    try {
        $roomodesLocal = Get-Content -Path $roomodesLocalPath -Raw | ConvertFrom-Json
        $endpointModels = $roomodesLocal.customModes | ForEach-Object { $_.model } | Sort-Object -Unique
        
        Write-ColorOutput "Modèles configurés dans .roomodes-local: $($endpointModels -join ', ')" "Green"
        Add-ReportEntry -Category "Configuration des endpoints" -Status "OK" -Details "Modèles configurés: $($endpointModels -join ', ')"
    } catch {
        Write-ColorOutput "Erreur lors de la lecture de .roomodes-local: $_" "Red"
        Add-ReportEntry -Category "Configuration des endpoints" -Status "ERREUR" -Details "Erreur lors de la lecture de .roomodes-local: $_" -Recommendation "Vérifiez que le fichier .roomodes-local est un JSON valide."
    }
} elseif (Test-Path -Path $roomodesPath) {
    try {
        $roomodes = Get-Content -Path $roomodesPath -Raw | ConvertFrom-Json
        $endpointModels = $roomodes.customModes | ForEach-Object { $_.model } | Sort-Object -Unique
        
        Write-ColorOutput "Modèles configurés dans .roomodes: $($endpointModels -join ', ')" "Yellow"
        Add-ReportEntry -Category "Configuration des endpoints" -Status "AVERTISSEMENT" -Details "Fichier .roomodes-local non trouvé, mais .roomodes existe avec les modèles: $($endpointModels -join ', ')" -Recommendation "Créez un fichier .roomodes-local adapté aux endpoints locaux en exécutant le script deploy-local-endpoints.ps1."
    } catch {
        Write-ColorOutput "Erreur lors de la lecture de .roomodes: $_" "Red"
        Add-ReportEntry -Category "Configuration des endpoints" -Status "ERREUR" -Details "Erreur lors de la lecture de .roomodes: $_" -Recommendation "Vérifiez que le fichier .roomodes est un JSON valide."
    }
} else {
    Write-ColorOutput "Aucun fichier de configuration des modes trouvé (.roomodes ou .roomodes-local)" "Red"
    Add-ReportEntry -Category "Configuration des endpoints" -Status "ERREUR" -Details "Aucun fichier de configuration des modes trouvé (.roomodes ou .roomodes-local)" -Recommendation "Créez un fichier .roomodes avec la configuration des modes personnalisés."
}

# Générer le rapport
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Rapport de vérification d'accessibilité à distance" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

$report | Format-Table -AutoSize -Property Category, Status, Details, Recommendation

# Résumé
$okCount = ($report | Where-Object { $_.Status -eq "OK" }).Count
$warningCount = ($report | Where-Object { $_.Status -eq "AVERTISSEMENT" }).Count
$errorCount = ($report | Where-Object { $_.Status -eq "ERREUR" }).Count

Write-ColorOutput "`nRésumé:" "Cyan"
Write-ColorOutput "- $okCount vérifications réussies" "Green"
Write-ColorOutput "- $warningCount avertissements" "Yellow"
Write-ColorOutput "- $errorCount erreurs" "Red"

# Recommandations générales
Write-ColorOutput "`nRecommandations générales:" "Cyan"

if ($errorCount -gt 0) {
    Write-ColorOutput "- Corrigez les erreurs avant de déployer sur une autre machine." "Red"
}

if ($warningCount -gt 0) {
    Write-ColorOutput "- Examinez les avertissements pour améliorer la compatibilité entre machines." "Yellow"
}

Write-ColorOutput "- Assurez-vous que les endpoints locaux sont correctement configurés sur la machine cible." "White"
Write-ColorOutput "- Vérifiez que les modèles locaux sont installés et fonctionnels sur la machine cible." "White"
Write-ColorOutput "- Testez le déploiement dans un environnement contrôlé avant de déployer en production." "White"

# Exporter le rapport dans un fichier
$reportPath = Join-Path -Path $projectRoot -ChildPath "remote-access-verification-report.md"
$reportContent = @"
# Rapport de vérification d'accessibilité à distance

Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Résumé

- $okCount vérifications réussies
- $warningCount avertissements
- $errorCount erreurs

## Détails

| Catégorie | Statut | Détails | Recommandation |
|-----------|--------|---------|----------------|
$(foreach ($entry in $report) {
    "| $($entry.Category) | $($entry.Status) | $($entry.Details) | $($entry.Recommendation) |"
})

## Recommandations générales

$(if ($errorCount -gt 0) {
    "- Corrigez les erreurs avant de déployer sur une autre machine."
})
$(if ($warningCount -gt 0) {
    "- Examinez les avertissements pour améliorer la compatibilité entre machines."
})
- Assurez-vous que les endpoints locaux sont correctement configurés sur la machine cible.
- Vérifiez que les modèles locaux sont installés et fonctionnels sur la machine cible.
- Testez le déploiement dans un environnement contrôlé avant de déployer en production.
"@

Set-Content -Path $reportPath -Value $reportContent
Write-ColorOutput "`nRapport exporté dans: $reportPath" "Green"

Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Vérification terminée!" "Green"
Write-ColorOutput "=========================================================" "Cyan"
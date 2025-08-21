# Script pour vérifier l'encodage et la structure du fichier de modes déployé
# Ce script vérifie spécifiquement la présence de la propriété familyDefinitions
# et l'encodage correct des emojis et caractères accentués

param (
    [Parameter(Mandatory=$false)]
    [string]$FilePath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"
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

Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "   Vérification du fichier de modes déployé" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

if (-not (Test-Path $FilePath)) {
    Write-ColorOutput "Erreur: Le fichier n'existe pas à l'emplacement : $FilePath" "Red"
    exit 1
}

Write-ColorOutput "Le fichier existe à l'emplacement : $FilePath" "Green"

# Vérifier l'encodage du fichier
$bytes = [System.IO.File]::ReadAllBytes($FilePath)
$hasBOM = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

if ($hasBOM) {
    Write-ColorOutput "Encodage du fichier : UTF-8 with BOM" "Yellow"
    Write-ColorOutput "Note: L'encodage UTF-8 avec BOM peut causer des problèmes avec certains parseurs JSON." "Yellow"
} else {
    Write-ColorOutput "Encodage du fichier : UTF-8 without BOM (ou autre encodage sans BOM)" "Green"
}

# Lire le contenu du fichier
$content = [System.IO.File]::ReadAllText($FilePath)

# Vérifier si le fichier contient du JSON valide
try {
    $json = ConvertFrom-Json $content
    Write-ColorOutput "Le fichier contient du JSON valide." "Green"
    
    # Vérifier les modes personnalisés
    if ($json.customModes) {
        Write-ColorOutput "Nombre de modes personnalisés : $($json.customModes.Count)" "Green"
        
        # Vérifier la présence de la propriété familyDefinitions
        $hasFamilyDefinitions = $false
        foreach ($mode in $json.customModes) {
            if ($mode.slug -eq "mode-family-validator" -and $mode.PSObject.Properties.Name -contains "familyDefinitions") {
                $hasFamilyDefinitions = $true
                Write-ColorOutput "La propriété 'familyDefinitions' a été trouvée dans le mode 'mode-family-validator'." "Green"
                
                # Vérifier le contenu de familyDefinitions
                if ($mode.familyDefinitions.PSObject.Properties.Name -contains "simple" -and 
                    $mode.familyDefinitions.PSObject.Properties.Name -contains "complex") {
                    Write-ColorOutput "Les familles 'simple' et 'complex' sont correctement définies." "Green"
                    
                    # Afficher les modes dans chaque famille
                    Write-ColorOutput "Modes dans la famille 'simple': $($mode.familyDefinitions.simple -join ', ')" "Cyan"
                    Write-ColorOutput "Modes dans la famille 'complex': $($mode.familyDefinitions.complex -join ', ')" "Cyan"
                } else {
                    Write-ColorOutput "Avertissement: Les familles 'simple' et/ou 'complex' ne sont pas correctement définies." "Yellow"
                }
                
                break
            }
        }
        
        if (-not $hasFamilyDefinitions) {
            Write-ColorOutput "Erreur: La propriété 'familyDefinitions' n'a pas été trouvée dans le mode 'mode-family-validator'." "Red"
            Write-ColorOutput "Cela peut causer des problèmes avec la visibilité des modes simple/complex dans VS Code." "Red"
        }
        
        # Vérifier les emojis dans les noms des modes
        $emojiIssues = @()
        foreach ($mode in $json.customModes) {
            if ($mode.name -notmatch "[^\u0000-\u007F]") {
                $emojiIssues += $mode.slug
            }
        }
        
        if ($emojiIssues.Count -gt 0) {
            Write-ColorOutput "Avertissement: Les modes suivants semblent avoir des problèmes d'encodage d'emojis:" "Yellow"
            foreach ($slug in $emojiIssues) {
                $mode = $json.customModes | Where-Object { $_.slug -eq $slug }
                Write-ColorOutput "  - $($mode.slug): '$($mode.name)'" "Yellow"
            }
        } else {
            Write-ColorOutput "Les emojis dans les noms des modes semblent correctement encodés." "Green"
        }
        
        # Vérifier les caractères accentués dans les instructions personnalisées
        $accentIssues = @()
        foreach ($mode in $json.customModes) {
            if ($mode.customInstructions -match "\u003c|\u0027") {
                $accentIssues += $mode.slug
            }
        }
        
        if ($accentIssues.Count -gt 0) {
            Write-ColorOutput "Avertissement: Les modes suivants semblent avoir des problèmes d'encodage de caractères accentués:" "Yellow"
            foreach ($slug in $accentIssues) {
                Write-ColorOutput "  - $slug" "Yellow"
            }
        } else {
            Write-ColorOutput "Les caractères accentués dans les instructions personnalisées semblent correctement encodés." "Green"
        }
    } else {
        Write-ColorOutput "Erreur: Aucun mode personnalisé n'a été trouvé dans le fichier." "Red"
    }
} catch {
    Write-ColorOutput "Erreur lors de la validation du JSON : $_" "Red"
}

Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "   Recommandations" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

if (-not $hasFamilyDefinitions) {
    Write-ColorOutput "1. Redéployez les modes en utilisant le script 'deploy-modes-solution.ps1' qui préserve la propriété 'familyDefinitions'." "White"
    Write-ColorOutput "2. Assurez-vous que le fichier source 'standard-modes.json' contient la propriété 'familyDefinitions'." "White"
}

if ($hasBOM) {
    Write-ColorOutput "3. Redéployez les modes en utilisant un encodage UTF-8 sans BOM pour une meilleure compatibilité." "White"
}

if ($emojiIssues.Count -gt 0 -or $accentIssues.Count -gt 0) {
    Write-ColorOutput "4. Redéployez les modes en utilisant un script qui préserve correctement l'encodage UTF-8 pour les emojis et caractères accentués." "White"
}

Write-ColorOutput "5. Après le déploiement, redémarrez Visual Studio Code et vérifiez que les modes sont correctement affichés dans la palette de commandes." "White"
Write-ColorOutput "==========================================================" "Cyan"
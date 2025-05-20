# =========================================================
# Script: diagnostic-rapide-encodage.ps1
# =========================================================
# Description:
#   Outil de diagnostic rapide pour détecter et corriger les problèmes d'encodage
#   dans les fichiers JSON. Ce script analyse un fichier JSON, identifie les
#   caractères mal encodés (accents, emojis) et propose des solutions.
#
# Fonctionnalités:
#   - Détection de l'encodage du fichier (UTF-8 avec/sans BOM)
#   - Validation du JSON
#   - Détection des caractères accentués mal encodés
#   - Détection des emojis mal encodés
#   - Correction automatique des problèmes détectés (avec l'option -Fix)
#   - Création automatique d'une sauvegarde avant correction
#   - Affichage d'exemples de problèmes avec contexte (avec l'option -Verbose)
#
# Paramètres:
#   -FilePath : Chemin du fichier à analyser (si vide, demande interactive)
#   -Fix      : Active la correction automatique des problèmes détectés
#   -Verbose  : Affiche des informations détaillées sur les problèmes
#
# Utilisation:
#   .\diagnostic-rapide-encodage.ps1
#   .\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json" -Fix
#   .\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json" -Verbose
#
# Auteur: Équipe Roo
# Date: Mai 2025
# =========================================================

param (
    [Parameter(Mandatory=$false)]
    [string]$FilePath = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Fix = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
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
Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "   Diagnostic rapide des problèmes d'encodage" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

# Si aucun chemin n'est fourni, demander à l'utilisateur
if ([string]::IsNullOrEmpty($FilePath)) {
    $FilePath = Read-Host "Entrez le chemin du fichier JSON à analyser"
}

# Vérifier si le fichier existe
if (-not (Test-Path -Path $FilePath)) {
    Write-ColorOutput "Erreur: Le fichier $FilePath n'existe pas." "Red"
    exit 1
}

Write-ColorOutput "Analyse du fichier: $FilePath" "Yellow"

# Vérifier l'extension du fichier
$extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
if ($extension -ne ".json") {
    Write-ColorOutput "Avertissement: Le fichier n'a pas l'extension .json. L'analyse pourrait ne pas être pertinente." "Yellow"
}

# Vérifier l'encodage du fichier
$bytes = [System.IO.File]::ReadAllBytes($FilePath)
$hasBOM = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

if ($hasBOM) {
    Write-ColorOutput "Encodage détecté: UTF-8 avec BOM" "Yellow"
    Write-ColorOutput "Recommandation: Pour les fichiers JSON, il est préférable d'utiliser UTF-8 sans BOM." "Yellow"
} else {
    Write-ColorOutput "Encodage détecté: UTF-8 sans BOM ou autre encodage" "Green"
}

# Lire le contenu du fichier
try {
    $content = [System.IO.File]::ReadAllText($FilePath)
    Write-ColorOutput "Lecture du fichier réussie." "Green"
} catch {
    Write-ColorOutput "Erreur lors de la lecture du fichier: $_" "Red"
    exit 1
}

# Vérifier si le contenu est du JSON valide
$isValidJson = $true
try {
    $null = $content | ConvertFrom-Json
    Write-ColorOutput "Validation JSON: Le fichier contient du JSON valide." "Green"
} catch {
    $isValidJson = $false
    Write-ColorOutput "Erreur: Le fichier ne contient pas du JSON valide: $_" "Red"
}

# Rechercher des motifs de caractères mal encodés
$encodingIssues = @{
    "é mal encodé (Ã©)" = $content -match "Ã©"
    "è mal encodé (Ã¨)" = $content -match "Ã¨"
    "à mal encodé (Ã )" = $content -match "Ã "
    "ç mal encodé (Ã§)" = $content -match "Ã§"
    "ê mal encodé (Ãª)" = $content -match "Ãª"
    "î mal encodé (Ã®)" = $content -match "Ã®"
    "ô mal encodé (Ã´)" = $content -match "Ã´"
    "û mal encodé (Ã»)" = $content -match "Ã»"
    "É mal encodé (Ã‰)" = $content -match "Ã‰"
    "emoji mal encodé" = $content -match "Ã°Å¸"
}

$hasEncodingIssues = $encodingIssues.Values -contains $true

if ($hasEncodingIssues) {
    Write-ColorOutput "`nProblèmes d'encodage détectés:" "Red"
    foreach ($issue in $encodingIssues.GetEnumerator()) {
        if ($issue.Value) {
            Write-ColorOutput "- $($issue.Key)" "Red"
        }
    }
    
    # Afficher des exemples de problèmes si demandé
    if ($Verbose) {
        Write-ColorOutput "`nExemples de problèmes trouvés:" "Yellow"
        
        # Rechercher et afficher des exemples de chaque problème
        $patterns = @{
            "Ã©" = "é mal encodé"
            "Ã¨" = "è mal encodé"
            "Ã " = "à mal encodé"
            "Ã§" = "ç mal encodé"
            "Ãª" = "ê mal encodé"
            "Ã®" = "î mal encodé"
            "Ã´" = "ô mal encodé"
            "Ã»" = "û mal encodé"
            "Ã‰" = "É mal encodé"
            "Ã°Å¸" = "emoji mal encodé"
        }
        
        foreach ($pattern in $patterns.GetEnumerator()) {
            if ($content -match $pattern.Key) {
                # Trouver le contexte autour du problème
                $index = $content.IndexOf($pattern.Key)
                $start = [Math]::Max(0, $index - 20)
                $length = [Math]::Min(50, $content.Length - $start)
                $context = $content.Substring($start, $length)
                
                Write-ColorOutput "- $($pattern.Value): ...${context}..." "Yellow"
            }
        }
    }
} else {
    Write-ColorOutput "`nAucun problème d'encodage courant n'a été détecté." "Green"
}

# Proposer des solutions
if ($hasEncodingIssues -or -not $isValidJson) {
    Write-ColorOutput "`nRecommandations:" "Yellow"
    
    if ($hasBOM) {
        Write-ColorOutput "1. Convertir le fichier en UTF-8 sans BOM" "White"
    }
    
    if ($hasEncodingIssues) {
        Write-ColorOutput "2. Corriger les problèmes d'encodage avec un des scripts suivants:" "White"
        Write-ColorOutput "   - fix-encoding-complete.ps1" "White"
        Write-ColorOutput "   - fix-encoding-final.ps1" "White"
    }
    
    if (-not $isValidJson) {
        Write-ColorOutput "3. Valider le JSON avec un outil comme JSONLint (https://jsonlint.com/)" "White"
    }
    
    # Proposer de corriger automatiquement
    if ($Fix) {
        Write-ColorOutput "`nTentative de correction automatique..." "Yellow"
        
        # Créer une sauvegarde
        $backupPath = "$FilePath.backup"
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-ColorOutput "Sauvegarde créée: $backupPath" "Green"
        
        # Corriger les problèmes d'encodage courants
        $correctedContent = $content
        
        # Correction pour les caractères accentués
        $correctedContent = $correctedContent -replace "Ã©", "é"
        $correctedContent = $correctedContent -replace "Ã¨", "è"
        $correctedContent = $correctedContent -replace "Ãª", "ê"
        $correctedContent = $correctedContent -replace "Ã ", "à"
        $correctedContent = $correctedContent -replace "Ã§", "ç"
        $correctedContent = $correctedContent -replace "Ã´", "ô"
        $correctedContent = $correctedContent -replace "Ã®", "î"
        $correctedContent = $correctedContent -replace "Ã»", "û"
        $correctedContent = $correctedContent -replace "Ã¹", "ù"
        $correctedContent = $correctedContent -replace "Ã¯", "ï"
        $correctedContent = $correctedContent -replace "Ã¼", "ü"
        $correctedContent = $correctedContent -replace "Ã«", "ë"
        $correctedContent = $correctedContent -replace "Ã‰", "É"
        $correctedContent = $correctedContent -replace "Ã", "È"
        $correctedContent = $correctedContent -replace "ÃŠ", "Ê"
        $correctedContent = $correctedContent -replace "Ã€", "À"
        $correctedContent = $correctedContent -replace "Ã‡", "Ç"
        
        # Correction pour les emojis
        $correctedContent = $correctedContent -replace "Ã°Å¸â€™Â»", "💻"  # Code
        $correctedContent = $correctedContent -replace "Ã°Å¸ÂªÂ²", "🪲"  # Debug
        $correctedContent = $correctedContent -replace "Ã°Å¸Ââ€"Ã¯Â¸Â", "🏗️"  # Architect
        $correctedContent = $correctedContent -replace "Ã¢Ââ€œ", "❓"  # Ask
        $correctedContent = $correctedContent -replace "Ã°Å¸ÂªÆ'", "🪃"  # Orchestrator
        $correctedContent = $correctedContent -replace "Ã°Å¸â€˜Â¨Ã¢â‚¬ÂÃ°Å¸â€™Â¼", "👨‍💼"  # Manager
        
        # Écrire le contenu corrigé en UTF-8 sans BOM
        try {
            [System.IO.File]::WriteAllText($FilePath, $correctedContent, [System.Text.UTF8Encoding]::new($false))
            Write-ColorOutput "Correction appliquée et fichier enregistré en UTF-8 sans BOM." "Green"
            
            # Vérifier si le JSON est maintenant valide
            try {
                $null = $correctedContent | ConvertFrom-Json
                Write-ColorOutput "Le fichier corrigé contient du JSON valide." "Green"
            } catch {
                Write-ColorOutput "Avertissement: Le fichier corrigé ne contient toujours pas du JSON valide." "Yellow"
                Write-ColorOutput "Une correction manuelle pourrait être nécessaire." "Yellow"
            }
        } catch {
            Write-ColorOutput "Erreur lors de l'écriture du fichier corrigé: $_" "Red"
        }
    } else {
        Write-ColorOutput "`nPour corriger automatiquement les problèmes, exécutez ce script avec le paramètre -Fix:" "Yellow"
        Write-ColorOutput ".\diagnostic-rapide-encodage.ps1 -FilePath `"$FilePath`" -Fix" "Yellow"
    }
} else {
    Write-ColorOutput "`nAucun problème détecté. Le fichier semble correctement encodé et contient du JSON valide." "Green"
}

# Taille du fichier
$fileInfo = Get-Item -Path $FilePath
$fileSize = $fileInfo.Length
Write-ColorOutput "`nTaille du fichier: $fileSize octets" "White"

# Date de dernière modification
$lastModified = $fileInfo.LastWriteTime
Write-ColorOutput "Dernière modification: $lastModified" "White"

Write-ColorOutput "`n==========================================================" "Cyan"
Write-ColorOutput "   Diagnostic terminé" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

Write-ColorOutput "`nPour plus d'informations sur les problèmes d'encodage, consultez:" "White"
Write-ColorOutput "../docs/guides/guide-encodage-windows.md" "White"
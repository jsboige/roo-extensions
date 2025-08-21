# Script pour corriger les problèmes d'encodage dans les fichiers JSON
param (
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "roo-modes/configs/standard-modes.json",
    
    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "roo-modes/configs/standard-modes.json.bak",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

function Fix-DoubleEncoding {
    param (
        [string]$text
    )
    
    # Table de correspondance pour les caractères spéciaux et emojis fréquemment utilisés
    $replacements = @{
        # Caractères accentués
        "Ã©" = "é"
        "Ã¨" = "è"
        "Ãª" = "ê"
        "Ã " = "à"
        "Ã§" = "ç"
        "Ã®" = "î"
        "Ã¯" = "ï"
        "Ã´" = "ô"
        "Ã¹" = "ù"
        "Ã»" = "û"
        "Ã¢" = "â"
        "Ã«" = "ë"
        "Ã¤" = "ä"
        "Ã¶" = "ö"
        "Ã¼" = "ü"
        "Ã±" = "ñ"
        
        # Emojis courants (version simple)
        "Ã°Å¸â€™Â»" = "💻"  # Ordinateur
        "Ã°Å¸ÂªÂ²" = "🪲"   # Bug
        "Ã°Å¸Ââ€"Ã¯Â¸Â" = "🏗️"  # Architecture
        "Ã¢Ââ€œ" = "❓"     # Question
        "Ã°Å¸ÂªÆ'" = "🪃"   # Orchestrateur
        "Ã°Å¸â€˜Â¨Ã¢â‚¬ÂÃ°Å¸â€™Â¼" = "👨‍💼"  # Manager
        
        # Emojis (version double encodée)
        "ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â»" = "💻"  # Ordinateur
        "ÃƒÂ°Ã…Â¸Ã‚ÂªÃ‚Â²" = "🪲"     # Bug
        "ÃƒÂ°Ã…Â¸Ã‚ÂÃ¢â‚¬â€ÃƒÂ¯Ã‚Â¸Ã‚Â" = "🏗️"  # Architecture
        "ÃƒÂ¢Ã‚ÂÃ¢â‚¬Å"" = "❓"       # Question
        "ÃƒÂ°Ã…Â¸Ã‚ÂªÃ†â€™" = "🪃"     # Orchestrateur
        "ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ‚Â¨ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â¼" = "👨‍💼"  # Manager
        
        # Caractères accentués (version double encodée)
        "ÃƒÂ©" = "é"
        "ÃƒÂ¨" = "è"
        "ÃƒÂª" = "ê"
        "ÃƒÂ " = "à"
        "ÃƒÂ§" = "ç"
        "ÃƒÂ®" = "î"
        "ÃƒÂ¯" = "ï"
        "ÃƒÂ´" = "ô"
        "ÃƒÂ¹" = "ù"
        "ÃƒÂ»" = "û"
        "ÃƒÂ¢" = "â"
        "ÃƒÂ«" = "ë"
        "ÃƒÂ¤" = "ä"
        "ÃƒÂ¶" = "ö"
        "ÃƒÂ¼" = "ü"
        "ÃƒÂ±" = "ñ"
        
        # Autres caractères spéciaux
        "Ãˆ" = "È"
        "Ã‰" = "É"
        "ÃŠ" = "Ê"
        "Ã€" = "À"
        "Ã‡" = "Ç"
        "ÃŽ" = "Î"
        "Ã" = "Ï"
        "Ã"" = "Ô"
        "Ã™" = "Ù"
        "Ã›" = "Û"
        "Ã‚" = "Â"
        "Ã‹" = "Ë"
        "Ã„" = "Ä"
        "Ã–" = "Ö"
        "Ãœ" = "Ü"
        "Ã'" = "Ñ"
    }
    
    # Appliquer les remplacements
    foreach ($key in $replacements.Keys) {
        $text = $text.Replace($key, $replacements[$key])
    }
    
    return $text
}

function Fix-TripleEncoding {
    param (
        [string]$text
    )
    
    # Première passe : corriger le double encodage
    $text = Fix-DoubleEncoding $text
    
    # Deuxième passe : corriger l'encodage simple
    $text = Fix-DoubleEncoding $text
    
    return $text
}

# Vérifier si le fichier source existe
if (-not (Test-Path $SourcePath)) {
    Write-Host "Erreur : Le fichier source $SourcePath n'existe pas."
    exit 1
}

# Créer une sauvegarde si elle n'existe pas déjà ou si -Force est spécifié
if ((Test-Path $BackupPath) -and -not $Force) {
    Write-Host "Une sauvegarde existe déjà à $BackupPath. Utilisez -Force pour écraser."
} else {
    Copy-Item -Path $SourcePath -Destination $BackupPath -Force
    Write-Host "Sauvegarde créée à $BackupPath"
}

# Lire le contenu du fichier
$content = Get-Content -Path $SourcePath -Raw -Encoding UTF8

# Vérifier si le fichier contient des caractères mal encodés
$containsDoubleEncoding = $content -match "Ã©|Ã¨|Ã°Å¸|ÃƒÂ°"
$originalContent = $content

if ($containsDoubleEncoding) {
    Write-Host "Le fichier contient des caractères mal encodés. Correction en cours..."
    
    # Appliquer la correction d'encodage
    $correctedContent = Fix-TripleEncoding $content
    
    # Écrire le contenu corrigé dans le fichier source
    [System.IO.File]::WriteAllText($SourcePath, $correctedContent, [System.Text.Encoding]::UTF8)
    
    Write-Host "Correction d'encodage terminée."
    
    # Vérifier si la correction a fonctionné
    $newContent = Get-Content -Path $SourcePath -Raw -Encoding UTF8
    $stillContainsDoubleEncoding = $newContent -match "Ã©|Ã¨|Ã°Å¸|ÃƒÂ°"
    
    if ($stillContainsDoubleEncoding) {
        Write-Host "Attention : Certains caractères mal encodés n'ont pas pu être corrigés."
    } else {
        Write-Host "Tous les caractères mal encodés ont été corrigés avec succès."
    }
    
    # Vérifier si le fichier est toujours du JSON valide
    try {
        $json = ConvertFrom-Json $newContent
        Write-Host "Le fichier corrigé contient du JSON valide."
    } catch {
        Write-Host "Erreur : Le fichier corrigé ne contient pas du JSON valide. Restauration de la sauvegarde..."
        Copy-Item -Path $BackupPath -Destination $SourcePath -Force
        Write-Host "Sauvegarde restaurée."
    }
} else {
    Write-Host "Le fichier ne contient pas de caractères mal encodés. Aucune correction nécessaire."
}

# Afficher un résumé des modifications
Write-Host "==========================================================="
Write-Host "   Résumé des modifications"
Write-Host "==========================================================="
Write-Host "Fichier source : $SourcePath"
Write-Host "Fichier de sauvegarde : $BackupPath"
if ($originalContent -ne $correctedContent) {
    Write-Host "Des modifications ont été apportées au fichier."
} else {
    Write-Host "Aucune modification n'a été apportée au fichier."
}
Write-Host "==========================================================="
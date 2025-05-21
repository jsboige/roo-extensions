# Script pour corriger directement les problèmes d'encodage dans le fichier JSON
param (
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "roo-modes/configs/standard-modes.json",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "roo-modes/configs/standard-modes-fixed.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

Write-Host "==========================================================="
Write-Host "   Correction directe des problèmes d'encodage"
Write-Host "==========================================================="

# Vérifier si le fichier source existe
if (-not (Test-Path $SourcePath)) {
    Write-Host "Erreur : Le fichier source $SourcePath n'existe pas."
    exit 1
}

# Vérifier si le fichier de sortie existe déjà
if ((Test-Path $OutputPath) -and -not $Force) {
    Write-Host "Le fichier de sortie $OutputPath existe déjà. Utilisez -Force pour écraser."
    exit 1
}

# Lire le contenu du fichier source
$content = Get-Content -Path $SourcePath -Raw -Encoding UTF8

# Remplacer les caractères problématiques
$replacements = @{
    # Emojis
    "Ã°Å¸â€™Â»" = "💻"  # Code
    "ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â»" = "💻"  # Code (double encodé)
    "Ã°Å¸ÂªÂ²" = "🪲"   # Debug
    "ÃƒÂ°Ã…Â¸Ã‚ÂªÃ‚Â²" = "🪲"   # Debug (double encodé)
    "Ã°Å¸Ââ€"Ã¯Â¸Â" = "🏗️"  # Architect
    "ÃƒÂ°Ã…Â¸Ã‚ÂÃ¢â‚¬â€ÃƒÂ¯Ã‚Â¸Ã‚Â" = "🏗️"  # Architect (double encodé)
    "Ã¢Ââ€œ" = "❓"     # Ask
    "ÃƒÂ¢Ã‚ÂÃ¢â‚¬Å"" = "❓"     # Ask (double encodé)
    "Ã°Å¸ÂªÆ'" = "🪃"   # Orchestrator
    "ÃƒÂ°Ã…Â¸Ã‚ÂªÃ†â€™" = "🪃"   # Orchestrator (double encodé)
    "Ã°Å¸â€˜Â¨Ã¢â‚¬ÂÃ°Å¸â€™Â¼" = "👨‍💼"  # Manager
    "ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ‚Â¨ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â¼" = "👨‍💼"  # Manager (double encodé)
    
    # Caractères accentués
    "Ã©" = "é"
    "ÃƒÂ©" = "é"
    "Ã¨" = "è"
    "ÃƒÂ¨" = "è"
    "Ãª" = "ê"
    "ÃƒÂª" = "ê"
    "Ã " = "à"
    "ÃƒÂ " = "à"
    "Ã§" = "ç"
    "ÃƒÂ§" = "ç"
    "Ã®" = "î"
    "ÃƒÂ®" = "î"
    "Ã¯" = "ï"
    "ÃƒÂ¯" = "ï"
    "Ã´" = "ô"
    "ÃƒÂ´" = "ô"
    "Ã¹" = "ù"
    "ÃƒÂ¹" = "ù"
    "Ã»" = "û"
    "ÃƒÂ»" = "û"
    "Ã¢" = "â"
    "ÃƒÂ¢" = "â"
    "Ã«" = "ë"
    "ÃƒÂ«" = "ë"
    "Ã¤" = "ä"
    "ÃƒÂ¤" = "ä"
    "Ã¶" = "ö"
    "ÃƒÂ¶" = "ö"
    "Ã¼" = "ü"
    "ÃƒÂ¼" = "ü"
    "Ã±" = "ñ"
    "ÃƒÂ±" = "ñ"
    
    # Caractères spéciaux
    "Ã‰" = "É"
    "ÃƒÂ‰" = "É"
    "Ãˆ" = "È"
    "ÃƒÂˆ" = "È"
    "ÃŠ" = "Ê"
    "ÃƒÂŠ" = "Ê"
    "Ã€" = "À"
    "ÃƒÂ€" = "À"
    "Ã‡" = "Ç"
    "ÃƒÂ‡" = "Ç"
    
    # Autres caractères problématiques
    "ÃˆÂ " = "à"
    "ÃˆÂ¢" = "â"
    "ÃˆÂ¹" = "ù"
}

# Appliquer les remplacements
$fixedContent = $content
foreach ($key in $replacements.Keys) {
    $fixedContent = $fixedContent.Replace($key, $replacements[$key])
}

# Écrire le contenu corrigé dans le fichier de sortie
[System.IO.File]::WriteAllText($OutputPath, $fixedContent, [System.Text.Encoding]::UTF8)

Write-Host "Le fichier corrigé a été enregistré à $OutputPath"

# Vérifier si le fichier corrigé contient toujours des problèmes d'encodage
$stillContainsEncodingIssues = $fixedContent -match "Ã©|Ã¨|Ã°Å¸|ÃƒÂ°"
if ($stillContainsEncodingIssues) {
    Write-Host "Attention : Le fichier corrigé contient toujours des problèmes d'encodage."
} else {
    Write-Host "Aucun problème d'encodage n'a été détecté dans le fichier corrigé."
}

# Vérifier si le fichier corrigé contient du JSON valide
try {
    $json = Get-Content -Path $OutputPath -Raw | ConvertFrom-Json
    Write-Host "Le fichier corrigé contient du JSON valide."
    
    # Afficher les noms des modes pour vérification
    if ($json.customModes) {
        Write-Host "Noms des modes dans le fichier corrigé :"
        foreach ($mode in $json.customModes) {
            Write-Host "- $($mode.name)"
        }
    }
} catch {
    Write-Host "Erreur : Le fichier corrigé ne contient pas du JSON valide : $_"
}

Write-Host "==========================================================="
Write-Host "   Instructions pour déployer le fichier corrigé"
Write-Host "==========================================================="
Write-Host "1. Vérifiez que le fichier corrigé ne contient plus de problèmes d'encodage"
Write-Host "2. Remplacez le fichier original par le fichier corrigé :"
Write-Host "   Copy-Item -Path $OutputPath -Destination $SourcePath -Force"
Write-Host "3. Exécutez le script de déploiement :"
Write-Host "   & '$PSScriptRoot\deploy-modes-simple-complex.ps1' -Force"
Write-Host "4. Redémarrez Visual Studio Code et vérifiez les modes"
Write-Host "==========================================================="
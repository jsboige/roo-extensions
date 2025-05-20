# Script pour corriger les problèmes d'encodage en utilisant des expressions régulières
param (
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "roo-modes/configs/standard-modes.json",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "roo-modes/configs/standard-modes-fixed.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

Write-Host "==========================================================="
Write-Host "   Correction des problèmes d'encodage avec regex"
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

# Créer une sauvegarde du contenu original
$originalContent = $content

# Remplacer les motifs d'encodage problématiques
# Nous utilisons des expressions régulières pour éviter d'avoir des caractères spéciaux dans le script

# Fonction pour remplacer un motif par un caractère spécifique
function Replace-Pattern {
    param (
        [string]$text,
        [string]$pattern,
        [string]$replacement
    )
    
    return $text -replace $pattern, $replacement
}

# Remplacer les emojis
$content = Replace-Pattern -text $content -pattern "Ã°Å¸â€™Â»|ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â»" -replacement "💻"  # Code
$content = Replace-Pattern -text $content -pattern "Ã°Å¸ÂªÂ²|ÃƒÂ°Ã…Â¸Ã‚ÂªÃ‚Â²" -replacement "🪲"  # Debug
$content = Replace-Pattern -text $content -pattern "Ã°Å¸Ââ€"Ã¯Â¸Â|ÃƒÂ°Ã…Â¸Ã‚ÂÃ¢â‚¬â€ÃƒÂ¯Ã‚Â¸Ã‚Â" -replacement "🏗️"  # Architect
$content = Replace-Pattern -text $content -pattern "Ã¢Ââ€œ|ÃƒÂ¢Ã‚ÂÃ¢â‚¬Å"" -replacement "❓"  # Ask
$content = Replace-Pattern -text $content -pattern "Ã°Å¸ÂªÆ'|ÃƒÂ°Ã…Â¸Ã‚ÂªÃ†â€™" -replacement "🪃"  # Orchestrator
$content = Replace-Pattern -text $content -pattern "Ã°Å¸â€˜Â¨Ã¢â‚¬ÂÃ°Å¸â€™Â¼|ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ‚Â¨ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â¼" -replacement "👨‍💼"  # Manager

# Remplacer les caractères accentués
$content = Replace-Pattern -text $content -pattern "Ã©|ÃƒÂ©" -replacement "é"
$content = Replace-Pattern -text $content -pattern "Ã¨|ÃƒÂ¨" -replacement "è"
$content = Replace-Pattern -text $content -pattern "Ãª|ÃƒÂª" -replacement "ê"
$content = Replace-Pattern -text $content -pattern "Ã |ÃƒÂ " -replacement "à"
$content = Replace-Pattern -text $content -pattern "Ã§|ÃƒÂ§" -replacement "ç"
$content = Replace-Pattern -text $content -pattern "Ã®|ÃƒÂ®" -replacement "î"
$content = Replace-Pattern -text $content -pattern "Ã¯|ÃƒÂ¯" -replacement "ï"
$content = Replace-Pattern -text $content -pattern "Ã´|ÃƒÂ´" -replacement "ô"
$content = Replace-Pattern -text $content -pattern "Ã¹|ÃƒÂ¹" -replacement "ù"
$content = Replace-Pattern -text $content -pattern "Ã»|ÃƒÂ»" -replacement "û"
$content = Replace-Pattern -text $content -pattern "Ã¢|ÃƒÂ¢" -replacement "â"
$content = Replace-Pattern -text $content -pattern "Ã«|ÃƒÂ«" -replacement "ë"
$content = Replace-Pattern -text $content -pattern "Ã¤|ÃƒÂ¤" -replacement "ä"
$content = Replace-Pattern -text $content -pattern "Ã¶|ÃƒÂ¶" -replacement "ö"
$content = Replace-Pattern -text $content -pattern "Ã¼|ÃƒÂ¼" -replacement "ü"
$content = Replace-Pattern -text $content -pattern "Ã±|ÃƒÂ±" -replacement "ñ"

# Remplacer les caractères spéciaux
$content = Replace-Pattern -text $content -pattern "Ã‰|ÃƒÂ‰" -replacement "É"
$content = Replace-Pattern -text $content -pattern "Ãˆ|ÃƒÂˆ" -replacement "È"
$content = Replace-Pattern -text $content -pattern "ÃŠ|ÃƒÂŠ" -replacement "Ê"
$content = Replace-Pattern -text $content -pattern "Ã€|ÃƒÂ€" -replacement "À"
$content = Replace-Pattern -text $content -pattern "Ã‡|ÃƒÂ‡" -replacement "Ç"

# Remplacer les autres caractères problématiques
$content = Replace-Pattern -text $content -pattern "ÃˆÂ " -replacement "à"
$content = Replace-Pattern -text $content -pattern "ÃˆÂ¢" -replacement "â"
$content = Replace-Pattern -text $content -pattern "ÃˆÂ¹" -replacement "ù"
$content = Replace-Pattern -text $content -pattern "COMPLEXITÃ‰" -replacement "COMPLEXITÉ"
$content = Replace-Pattern -text $content -pattern "tÃˆÂ¢ches" -replacement "tâches"
$content = Replace-Pattern -text $content -pattern "DÃ©" -replacement "Dé"
$content = Replace-Pattern -text $content -pattern "dÃ©" -replacement "dé"
$content = Replace-Pattern -text $content -pattern "Ãªtre" -replacement "être"
$content = Replace-Pattern -text $content -pattern "rÃ´le" -replacement "rôle"
$content = Replace-Pattern -text $content -pattern "spÃ©cialis" -replacement "spécialis"
$content = Replace-Pattern -text $content -pattern "crÃ©ation" -replacement "création"
$content = Replace-Pattern -text $content -pattern "dÃ©composition" -replacement "décomposition"
$content = Replace-Pattern -text $content -pattern "dÃ©finit" -replacement "définit"
$content = Replace-Pattern -text $content -pattern "Ã©tendue" -replacement "étendue"
$content = Replace-Pattern -text $content -pattern "Ã©chelle" -replacement "échelle"
$content = Replace-Pattern -text $content -pattern "dÃ©lÃ©gu" -replacement "délég"
$content = Replace-Pattern -text $content -pattern "nÃ©cessaire" -replacement "nécessaire"
$content = Replace-Pattern -text $content -pattern "pÃ©rim" -replacement "périm"
$content = Replace-Pattern -text $content -pattern "dÃ©claration" -replacement "déclaration"
$content = Replace-Pattern -text $content -pattern "rÃ©sum" -replacement "résum"
$content = Replace-Pattern -text $content -pattern "DÃ‰SESCALADE" -replacement "DÉSESCALADE"
$content = Replace-Pattern -text $content -pattern "Ã©valu" -replacement "évalu"
$content = Replace-Pattern -text $content -pattern "suggÃ©r" -replacement "suggér"
$content = Replace-Pattern -text $content -pattern "dÃ©pend" -replacement "dépend"
$content = Replace-Pattern -text $content -pattern "linÃ©aire" -replacement "linéaire"
$content = Replace-Pattern -text $content -pattern "prÃ©f" -replacement "préf"
$content = Replace-Pattern -text $content -pattern "considÃ©r" -replacement "considér"
$content = Replace-Pattern -text $content -pattern "SUGGÃ‰RÃ‰E" -replacement "SUGGÉRÉE"
$content = Replace-Pattern -text $content -pattern "traitÃ©e" -replacement "traitée"
$content = Replace-Pattern -text $content -pattern "PRIVILÃ‰GIEZ" -replacement "PRIVILÉGIEZ"
$content = Replace-Pattern -text $content -pattern "Ã©dit" -replacement "édit"
$content = Replace-Pattern -text $content -pattern "opÃ©ration" -replacement "opération"
$content = Replace-Pattern -text $content -pattern "Ã©conomiser" -replacement "économiser"
$content = Replace-Pattern -text $content -pattern "rÃ©duire" -replacement "réduire"

# Écrire le contenu corrigé dans le fichier de sortie
[System.IO.File]::WriteAllText($OutputPath, $content, [System.Text.Encoding]::UTF8)

Write-Host "Le fichier corrigé a été enregistré à $OutputPath"

# Vérifier si le fichier corrigé contient toujours des problèmes d'encodage
$stillContainsEncodingIssues = $content -match "Ã©|Ã¨|Ã°Å¸|ÃƒÂ°"
if ($stillContainsEncodingIssues) {
    Write-Host "Attention : Le fichier corrigé contient toujours des problèmes d'encodage."
} else {
    Write-Host "Aucun problème d'encodage n'a été détecté dans le fichier corrigé."
}

# Vérifier si le fichier corrigé contient du JSON valide
try {
    $json = Get-Content -Path $OutputPath -Raw | ConvertFrom-Json
    Write-Host "Le fichier corrigé contient du JSON valide."
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
# Script de correction d'encodage simplifié pour les fichiers JSON
# Cette version évite complètement l'utilisation de caractères spéciaux

param (
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Si aucun chemin de sortie n'est spécifié, utiliser le chemin source avec un suffixe
if ([string]::IsNullOrEmpty($OutputPath)) {
    $OutputPath = "$SourcePath.fixed"
}

# Vérifier si le fichier de sortie existe déjà
if (Test-Path -Path $OutputPath) {
    if (-not $Force) {
        $confirmation = Read-Host "Le fichier de sortie existe déjà. Voulez-vous le remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-Host "Opération annulée." -ForegroundColor Yellow
            exit 0
        }
    }
}

try {
    # Lire le contenu du fichier source
    Write-Host "Lecture du fichier source: $SourcePath" -ForegroundColor Cyan
    $content = [System.IO.File]::ReadAllText($SourcePath)
    
    # Créer une copie du contenu pour les corrections
    $correctedContent = $content
    
    # Remplacer les caractères spéciaux par leurs équivalents Unicode
    Write-Host "Application des corrections d'encodage..." -ForegroundColor Cyan
    
    # Code emoji (💻) - U+1F4BB
    $correctedContent = $correctedContent -replace "Ã°Å¸â€™Â»", [char]0x1F4BB
    
    # Debug emoji (🪲) - U+1FAB2
    $correctedContent = $correctedContent -replace "Ã°Å¸ÂªÂ²", [char]0x1FAB2
    
    # Architect emoji (🏗️) - U+1F3D7 U+FE0F
    $correctedContent = $correctedContent -replace "Ã°Å¸â€"Ã¯Â¸", ([char]0x1F3D7 + [char]0xFE0F)
    
    # Ask emoji (❓) - U+2753
    $correctedContent = $correctedContent -replace "Ã¢â€"", [char]0x2753
    
    # Orchestrator emoji (🪃) - U+1FA83
    $correctedContent = $correctedContent -replace "Ã°Å¸ÂªÆ'", [char]0x1FA83
    
    # Correction générique pour les caractères accentués
    $correctedContent = $correctedContent -replace "Ã©", "é"
    $correctedContent = $correctedContent -replace "Ã¨", "è"
    $correctedContent = $correctedContent -replace "Ãª", "ê"
    $correctedContent = $correctedContent -replace "Ã«", "ë"
    $correctedContent = $correctedContent -replace "Ã ", "à"
    $correctedContent = $correctedContent -replace "Ã¢", "â"
    $correctedContent = $correctedContent -replace "Ã®", "î"
    $correctedContent = $correctedContent -replace "Ã¯", "ï"
    $correctedContent = $correctedContent -replace "Ã´", "ô"
    $correctedContent = $correctedContent -replace "Ã¶", "ö"
    $correctedContent = $correctedContent -replace "Ã¹", "ù"
    $correctedContent = $correctedContent -replace "Ã»", "û"
    $correctedContent = $correctedContent -replace "Ã¼", "ü"
    $correctedContent = $correctedContent -replace "Ã§", "ç"
    
    # Vérifier que le JSON est valide
    try {
        $null = $correctedContent | ConvertFrom-Json
        Write-Host "Le JSON corrigé est valide." -ForegroundColor Green
    }
    catch {
        Write-Host "Avertissement: Le JSON corrigé n'est pas valide. Il pourrait y avoir des problèmes d'encodage non résolus." -ForegroundColor Yellow
    }
    
    # Écrire le contenu corrigé dans le fichier de sortie
    Write-Host "Écriture du fichier corrigé: $OutputPath" -ForegroundColor Cyan
    
    # Utiliser UTF-8 sans BOM pour une meilleure compatibilité
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($OutputPath, $correctedContent, $utf8NoBomEncoding)
    
    Write-Host "Correction d'encodage terminée avec succès!" -ForegroundColor Green
    
    # Retourner le chemin du fichier corrigé
    return $OutputPath
}
catch {
    Write-Host "Erreur lors de la correction d'encodage:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
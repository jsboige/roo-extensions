# Script de correction d'encodage extreme pour les fichiers JSON
# Cette version evite completement l'utilisation de caracteres speciaux

param (
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Si aucun chemin de sortie n'est specifie, utiliser le chemin source avec un suffixe
if ([string]::IsNullOrEmpty($OutputPath)) {
    $OutputPath = "$SourcePath.fixed"
}

# Verifier si le fichier de sortie existe deja
if (Test-Path -Path $OutputPath) {
    if (-not $Force) {
        $confirmation = Read-Host "Le fichier de sortie existe deja. Voulez-vous le remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-Host "Operation annulee." -ForegroundColor Yellow
            exit 0
        }
    }
}

try {
    # Lire le contenu du fichier source
    Write-Host "Lecture du fichier source: $SourcePath" -ForegroundColor Cyan
    
    # Lire le contenu en tant que bytes pour eviter les problemes d'encodage
    $bytes = [System.IO.File]::ReadAllBytes($SourcePath)
    
    # Verifier si le fichier commence par un BOM UTF-8
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    
    # Convertir les bytes en texte
    $encoding = [System.Text.Encoding]::UTF8
    if ($hasBom) {
        Write-Host "Le fichier source contient un BOM UTF-8" -ForegroundColor Yellow
        $content = $encoding.GetString($bytes, 3, $bytes.Length - 3)
    } else {
        $content = $encoding.GetString($bytes)
    }
    
    # Creer une copie du contenu pour les corrections
    $correctedContent = $content
    
    # Remplacer directement les emojis par leurs equivalents textuels
    Write-Host "Application des corrections d'encodage..." -ForegroundColor Cyan
    
    # Remplacer les emojis par du texte
    $correctedContent = $correctedContent -replace "\p{So}", "[emoji]"
    
    # Remplacer les caracteres accentues par leurs equivalents sans accent
    $correctedContent = $correctedContent -replace "[àáâãäå]", "a"
    $correctedContent = $correctedContent -replace "[èéêë]", "e"
    $correctedContent = $correctedContent -replace "[ìíîï]", "i"
    $correctedContent = $correctedContent -replace "[òóôõöø]", "o"
    $correctedContent = $correctedContent -replace "[ùúûü]", "u"
    $correctedContent = $correctedContent -replace "[ýÿ]", "y"
    $correctedContent = $correctedContent -replace "ñ", "n"
    $correctedContent = $correctedContent -replace "ç", "c"
    
    # Remplacer les caracteres speciaux par leurs equivalents ASCII
    $correctedContent = $correctedContent -replace "[^\x00-\x7F]", "?"
    
    # Verifier que le JSON est valide
    try {
        $null = $correctedContent | ConvertFrom-Json
        Write-Host "Le JSON corrige est valide." -ForegroundColor Green
    }
    catch {
        Write-Host "Avertissement: Le JSON corrige n'est pas valide. Il pourrait y avoir des problemes d'encodage non resolus." -ForegroundColor Yellow
    }
    
    # Ecrire le contenu corrige dans le fichier de sortie
    Write-Host "Ecriture du fichier corrige: $OutputPath" -ForegroundColor Cyan
    
    # Utiliser UTF-8 sans BOM pour une meilleure compatibilite
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($OutputPath, $correctedContent, $utf8NoBomEncoding)
    
    Write-Host "Correction d'encodage terminee avec succes!" -ForegroundColor Green
    
    # Retourner le chemin du fichier corrige
    return $OutputPath
}
catch {
    Write-Host "Erreur lors de la correction d'encodage:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
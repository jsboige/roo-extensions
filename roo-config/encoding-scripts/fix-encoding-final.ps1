# Script de correction d'encodage final pour les fichiers JSON
# Cette version utilise une approche plus precise pour remplacer les caracteres speciaux

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
    
    Write-Host "Application des corrections d'encodage..." -ForegroundColor Cyan
    
    # Tableau de correspondance pour les caracteres accentues
    $accentMap = @{
        'à' = 'a'; 'á' = 'a'; 'â' = 'a'; 'ã' = 'a'; 'ä' = 'a'; 'å' = 'a';
        'è' = 'e'; 'é' = 'e'; 'ê' = 'e'; 'ë' = 'e';
        'ì' = 'i'; 'í' = 'i'; 'î' = 'i'; 'ï' = 'i';
        'ò' = 'o'; 'ó' = 'o'; 'ô' = 'o'; 'õ' = 'o'; 'ö' = 'o'; 'ø' = 'o';
        'ù' = 'u'; 'ú' = 'u'; 'û' = 'u'; 'ü' = 'u';
        'ý' = 'y'; 'ÿ' = 'y';
        'ñ' = 'n';
        'ç' = 'c';
        'À' = 'A'; 'Á' = 'A'; 'Â' = 'A'; 'Ã' = 'A'; 'Ä' = 'A'; 'Å' = 'A';
        'È' = 'E'; 'É' = 'E'; 'Ê' = 'E'; 'Ë' = 'E';
        'Ì' = 'I'; 'Í' = 'I'; 'Î' = 'I'; 'Ï' = 'I';
        'Ò' = 'O'; 'Ó' = 'O'; 'Ô' = 'O'; 'Õ' = 'O'; 'Ö' = 'O'; 'Ø' = 'O';
        'Ù' = 'U'; 'Ú' = 'U'; 'Û' = 'U'; 'Ü' = 'U';
        'Ý' = 'Y';
        'Ñ' = 'N';
        'Ç' = 'C';
        'œ' = 'oe'; 'Œ' = 'OE';
        'æ' = 'ae'; 'Æ' = 'AE';
        '«' = '"'; '»' = '"';
        '–' = '-'; '—' = '-';
        ''' = "'"; ''' = "'";
        '"' = '"'; '"' = '"';
        '…' = '...';
        '€' = 'EUR'; '£' = 'GBP'; '¥' = 'JPY';
        '©' = '(c)'; '®' = '(r)'; '™' = '(tm)';
        '°' = 'deg';
        '±' = '+/-';
        '×' = 'x';
        '÷' = '/';
        '¼' = '1/4'; '½' = '1/2'; '¾' = '3/4';
        '¿' = '?'; '¡' = '!';
        'ß' = 'ss';
        'µ' = 'u'
    }
    
    # Remplacer les emojis par [emoji]
    $correctedContent = $correctedContent -replace "\p{So}", "[emoji]"
    
    # Remplacer les caracteres accentues par leurs equivalents ASCII
    foreach ($key in $accentMap.Keys) {
        $correctedContent = $correctedContent.Replace($key, $accentMap[$key])
    }
    
    # Remplacer tous les autres caracteres non-ASCII par un espace
    $correctedContent = $correctedContent -replace "[^\x00-\x7F]", " "
    
    # Verifier que le JSON est valide
    try {
        $null = $correctedContent | ConvertFrom-Json
        Write-Host "Le JSON corrige est valide." -ForegroundColor Green
    }
    catch {
        Write-Host "Avertissement: Le JSON corrige n'est pas valide. Il pourrait y avoir des problemes d'encodage non resolus." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
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
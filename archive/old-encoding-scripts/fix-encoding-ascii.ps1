# Script de correction d'encodage ASCII pour les fichiers JSON
# Cette version evite completement d'utiliser des caracteres speciaux dans le code source

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
    
    # Fonction pour remplacer les caracteres accentues par leurs equivalents ASCII
    function Replace-AccentedCharacters {
        param (
            [string]$text
        )
        
        # Remplacements pour les caracteres accentues courants
        $text = $text -replace [char]0x00E0, 'a'  # à
        $text = $text -replace [char]0x00E1, 'a'  # á
        $text = $text -replace [char]0x00E2, 'a'  # â
        $text = $text -replace [char]0x00E3, 'a'  # ã
        $text = $text -replace [char]0x00E4, 'a'  # ä
        $text = $text -replace [char]0x00E5, 'a'  # å
        
        $text = $text -replace [char]0x00E8, 'e'  # è
        $text = $text -replace [char]0x00E9, 'e'  # é
        $text = $text -replace [char]0x00EA, 'e'  # ê
        $text = $text -replace [char]0x00EB, 'e'  # ë
        
        $text = $text -replace [char]0x00EC, 'i'  # ì
        $text = $text -replace [char]0x00ED, 'i'  # í
        $text = $text -replace [char]0x00EE, 'i'  # î
        $text = $text -replace [char]0x00EF, 'i'  # ï
        
        $text = $text -replace [char]0x00F2, 'o'  # ò
        $text = $text -replace [char]0x00F3, 'o'  # ó
        $text = $text -replace [char]0x00F4, 'o'  # ô
        $text = $text -replace [char]0x00F5, 'o'  # õ
        $text = $text -replace [char]0x00F6, 'o'  # ö
        $text = $text -replace [char]0x00F8, 'o'  # ø
        
        $text = $text -replace [char]0x00F9, 'u'  # ù
        $text = $text -replace [char]0x00FA, 'u'  # ú
        $text = $text -replace [char]0x00FB, 'u'  # û
        $text = $text -replace [char]0x00FC, 'u'  # ü
        
        $text = $text -replace [char]0x00FD, 'y'  # ý
        $text = $text -replace [char]0x00FF, 'y'  # ÿ
        
        $text = $text -replace [char]0x00F1, 'n'  # ñ
        $text = $text -replace [char]0x00E7, 'c'  # ç
        
        $text = $text -replace [char]0x00C0, 'A'  # À
        $text = $text -replace [char]0x00C1, 'A'  # Á
        $text = $text -replace [char]0x00C2, 'A'  # Â
        $text = $text -replace [char]0x00C3, 'A'  # Ã
        $text = $text -replace [char]0x00C4, 'A'  # Ä
        $text = $text -replace [char]0x00C5, 'A'  # Å
        
        $text = $text -replace [char]0x00C8, 'E'  # È
        $text = $text -replace [char]0x00C9, 'E'  # É
        $text = $text -replace [char]0x00CA, 'E'  # Ê
        $text = $text -replace [char]0x00CB, 'E'  # Ë
        
        $text = $text -replace [char]0x00CC, 'I'  # Ì
        $text = $text -replace [char]0x00CD, 'I'  # Í
        $text = $text -replace [char]0x00CE, 'I'  # Î
        $text = $text -replace [char]0x00CF, 'I'  # Ï
        
        $text = $text -replace [char]0x00D2, 'O'  # Ò
        $text = $text -replace [char]0x00D3, 'O'  # Ó
        $text = $text -replace [char]0x00D4, 'O'  # Ô
        $text = $text -replace [char]0x00D5, 'O'  # Õ
        $text = $text -replace [char]0x00D6, 'O'  # Ö
        $text = $text -replace [char]0x00D8, 'O'  # Ø
        
        $text = $text -replace [char]0x00D9, 'U'  # Ù
        $text = $text -replace [char]0x00DA, 'U'  # Ú
        $text = $text -replace [char]0x00DB, 'U'  # Û
        $text = $text -replace [char]0x00DC, 'U'  # Ü
        
        $text = $text -replace [char]0x00DD, 'Y'  # Ý
        
        $text = $text -replace [char]0x00D1, 'N'  # Ñ
        $text = $text -replace [char]0x00C7, 'C'  # Ç
        
        $text = $text -replace [char]0x0153, 'oe'  # œ
        $text = $text -replace [char]0x0152, 'OE'  # Œ
        
        $text = $text -replace [char]0x00E6, 'ae'  # æ
        $text = $text -replace [char]0x00C6, 'AE'  # Æ
        
        $text = $text -replace [char]0x00AB, '"'  # «
        $text = $text -replace [char]0x00BB, '"'  # »
        
        $text = $text -replace [char]0x2013, '-'  # –
        $text = $text -replace [char]0x2014, '-'  # —
        
        $text = $text -replace [char]0x2018, "'"  # '
        $text = $text -replace [char]0x2019, "'"  # '
        
        $text = $text -replace [char]0x201C, '"'  # "
        $text = $text -replace [char]0x201D, '"'  # "
        
        $text = $text -replace [char]0x2026, '...'  # …
        
        $text = $text -replace [char]0x20AC, 'EUR'  # €
        $text = $text -replace [char]0x00A3, 'GBP'  # £
        $text = $text -replace [char]0x00A5, 'JPY'  # ¥
        
        $text = $text -replace [char]0x00A9, '(c)'  # ©
        $text = $text -replace [char]0x00AE, '(r)'  # ®
        $text = $text -replace [char]0x2122, '(tm)'  # ™
        
        $text = $text -replace [char]0x00B0, 'deg'  # °
        $text = $text -replace [char]0x00B1, '+/-'  # ±
        
        $text = $text -replace [char]0x00D7, 'x'  # ×
        $text = $text -replace [char]0x00F7, '/'  # ÷
        
        $text = $text -replace [char]0x00BC, '1/4'  # ¼
        $text = $text -replace [char]0x00BD, '1/2'  # ½
        $text = $text -replace [char]0x00BE, '3/4'  # ¾
        
        $text = $text -replace [char]0x00BF, '?'  # ¿
        $text = $text -replace [char]0x00A1, '!'  # ¡
        
        $text = $text -replace [char]0x00DF, 'ss'  # ß
        $text = $text -replace [char]0x00B5, 'u'  # µ
        
        return $text
    }
    
    # Remplacer les emojis par [emoji]
    $correctedContent = $correctedContent -replace "\p{So}", "[emoji]"
    
    # Remplacer les caracteres accentues par leurs equivalents ASCII
    $correctedContent = Replace-AccentedCharacters -text $correctedContent
    
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
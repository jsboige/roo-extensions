# Script de diagnostic des problèmes d'encodage
function Get-FileEncoding {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # Lire les premiers octets du fichier pour détecter l'encodage
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $encoding = $null

    # Détecter BOM (Byte Order Mark)
    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
        $encoding = "UTF-32 BE"
    }
    elseif ($bytes.Length -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
        $encoding = "UTF-32 LE"
    }
    elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = "UTF-8 with BOM"
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = "UTF-16 BE"
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = "UTF-16 LE"
    }
    else {
        # Essayer de détecter UTF-8 sans BOM
        $isUtf8 = $true
        $utf8Bytes = 0
        
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            # Vérifier les séquences UTF-8 valides
            if ($bytes[$i] -ge 0x80) {
                # Début d'une séquence multi-octets
                if ($bytes[$i] -ge 0xC0 -and $bytes[$i] -le 0xDF -and $i + 1 -lt $bytes.Length -and $bytes[$i + 1] -ge 0x80 -and $bytes[$i + 1] -le 0xBF) {
                    $i++
                    $utf8Bytes++
                }
                elseif ($bytes[$i] -ge 0xE0 -and $bytes[$i] -le 0xEF -and $i + 2 -lt $bytes.Length -and $bytes[$i + 1] -ge 0x80 -and $bytes[$i + 1] -le 0xBF -and $bytes[$i + 2] -ge 0x80 -and $bytes[$i + 2] -le 0xBF) {
                    $i += 2
                    $utf8Bytes++
                }
                elseif ($bytes[$i] -ge 0xF0 -and $bytes[$i] -le 0xF7 -and $i + 3 -lt $bytes.Length -and $bytes[$i + 1] -ge 0x80 -and $bytes[$i + 1] -le 0xBF -and $bytes[$i + 2] -ge 0x80 -and $bytes[$i + 2] -le 0xBF -and $bytes[$i + 3] -ge 0x80 -and $bytes[$i + 3] -le 0xBF) {
                    $i += 3
                    $utf8Bytes++
                }
                else {
                    $isUtf8 = $false
                    break
                }
            }
        }
        
        if ($isUtf8 -and $utf8Bytes -gt 0) {
            $encoding = "UTF-8 without BOM"
        }
        else {
            # Essayer de détecter si c'est ASCII ou une autre encodage
            $isAscii = $true
            foreach ($byte in $bytes) {
                if ($byte -gt 127) {
                    $isAscii = $false
                    break
                }
            }
            
            if ($isAscii) {
                $encoding = "ASCII"
            }
            else {
                $encoding = "Unknown (possibly Windows-1252 or another 8-bit encoding)"
            }
        }
    }

    # Analyser les problèmes potentiels d'encodage
    $content = [System.IO.File]::ReadAllText($FilePath)
    $problems = @()

    # Détecter les signes de double encodage UTF-8
    if ($content -match "Ã.") {
        $problems += "Possible double encodage UTF-8"
    }

    # Détecter les caractères de remplacement
    if ($content -match "ï¿½") {
        $problems += "Caractères de remplacement détectés (ï¿½)"
    }

    # Détecter les séquences d'échappement HTML pour les caractères accentués
    if ($content -match "&[aeiou](acute|grave|circ|uml);") {
        $problems += "Séquences d'échappement HTML détectées"
    }

    return @{
        Encoding = $encoding
        Problems = $problems
        HasProblems = ($problems.Count -gt 0)
    }
}

function Analyze-FileContent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = [System.IO.File]::ReadAllText($FilePath)
    
    # Échantillon de caractères problématiques à rechercher
    $problematicPatterns = @(
        @{ Pattern = "Ã©"; Description = "é encodé deux fois en UTF-8" },
        @{ Pattern = "Ã¨"; Description = "è encodé deux fois en UTF-8" },
        @{ Pattern = "Ã®"; Description = "î encodé deux fois en UTF-8" },
        @{ Pattern = "Ã´"; Description = "ô encodé deux fois en UTF-8" },
        @{ Pattern = "Ã»"; Description = "ù encodé deux fois en UTF-8" },
        @{ Pattern = "Ã§"; Description = "ç encodé deux fois en UTF-8" },
        @{ Pattern = "ÃƒÂ©"; Description = "é encodé trois fois en UTF-8" },
        @{ Pattern = "ÃƒÆ'Ã‚Â©"; Description = "é encodé plusieurs fois en UTF-8" },
        @{ Pattern = "ï¿½"; Description = "Caractère de remplacement" }
    )

    $detectedPatterns = @()
    foreach ($pattern in $problematicPatterns) {
        if ($content -match [regex]::Escape($pattern.Pattern)) {
            $detectedPatterns += "$($pattern.Pattern) (probablement $($pattern.Description))"
        }
    }

    return $detectedPatterns
}

# Fonction pour analyser un fichier
function Analyze-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Write-Host "`n=== Analyse du fichier: $FilePath ===" -ForegroundColor Cyan

    if (-not (Test-Path -Path $FilePath)) {
        Write-Host "Le fichier n'existe pas: $FilePath" -ForegroundColor Red
        return
    }

    try {
        $encodingInfo = Get-FileEncoding -FilePath $FilePath
        Write-Host "Encodage détecté: $($encodingInfo.Encoding)" -ForegroundColor Yellow
        
        if ($encodingInfo.HasProblems) {
            Write-Host "Problèmes détectés:" -ForegroundColor Red
            foreach ($problem in $encodingInfo.Problems) {
                Write-Host " - $problem" -ForegroundColor Red
            }
            
            $detailedPatterns = Analyze-FileContent -FilePath $FilePath
            if ($detailedPatterns.Count -gt 0) {
                Write-Host "Motifs problématiques détectés:" -ForegroundColor Red
                foreach ($pattern in $detailedPatterns) {
                    Write-Host " - $pattern" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "Aucun problème d'encodage détecté." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Erreur lors de l'analyse du fichier: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Fonction pour analyser l'environnement
function Analyze-Environment {
    Write-Host "`n=== Analyse de l'environnement ===" -ForegroundColor Cyan
    
    # Encodage par défaut du système
    $defaultEncoding = [System.Text.Encoding]::Default
    Write-Host "Encodage par défaut du système: $($defaultEncoding.WebName) (CodePage: $($defaultEncoding.CodePage))" -ForegroundColor Yellow
    
    # Configuration Git
    Write-Host "`nConfiguration Git:" -ForegroundColor Yellow
    try {
        $gitAutoCrlf = git config --get core.autocrlf
        Write-Host "core.autocrlf = $gitAutoCrlf"
    }
    catch {
        Write-Host "Impossible de récupérer la configuration Git core.autocrlf" -ForegroundColor Red
    }
    
    try {
        $gitCommitEncoding = git config --get i18n.commitencoding
        if ($gitCommitEncoding) {
            Write-Host "i18n.commitencoding = $gitCommitEncoding"
        }
        else {
            Write-Host "i18n.commitencoding non défini (utilise UTF-8 par défaut)"
        }
    }
    catch {
        Write-Host "Impossible de récupérer la configuration Git i18n.commitencoding" -ForegroundColor Red
    }
    
    try {
        $gitLogEncoding = git config --get i18n.logoutputencoding
        if ($gitLogEncoding) {
            Write-Host "i18n.logoutputencoding = $gitLogEncoding"
        }
        else {
            Write-Host "i18n.logoutputencoding non défini (utilise UTF-8 par défaut)"
        }
    }
    catch {
        Write-Host "Impossible de récupérer la configuration Git i18n.logoutputencoding" -ForegroundColor Red
    }
    
    # Configuration VSCode
    Write-Host "`nConfiguration VSCode:" -ForegroundColor Yellow
    $vscodePath = ".vscode/settings.json"
    if (Test-Path -Path $vscodePath) {
        try {
            $vscodeSettings = Get-Content -Path $vscodePath -Raw | ConvertFrom-Json
            
            if ($vscodeSettings.PSObject.Properties.Name -contains "files.encoding") {
                Write-Host "files.encoding = $($vscodeSettings.'files.encoding')"
            }
            else {
                Write-Host "files.encoding non défini dans .vscode/settings.json"
            }
            
            if ($vscodeSettings.PSObject.Properties.Name -contains "files.autoGuessEncoding") {
                Write-Host "files.autoGuessEncoding = $($vscodeSettings.'files.autoGuessEncoding')"
            }
            else {
                Write-Host "files.autoGuessEncoding non défini dans .vscode/settings.json"
            }
        }
        catch {
            Write-Host "Erreur lors de la lecture de .vscode/settings.json: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host ".vscode/settings.json non trouvé" -ForegroundColor Red
    }
}

# Liste des fichiers à analyser
$filesToAnalyze = @(
    ".roomodes",
    "roo-config/README.md",
    "roo-modes/README.md",
    "tests/README.md",
    "docs/guide-utilisation-mcps.md",
    "mcps/README.md"
)

# Analyser l'environnement
Analyze-Environment

# Analyser chaque fichier
foreach ($file in $filesToAnalyze) {
    Analyze-File -FilePath $file
}

Write-Host "`n=== Recommandations ===" -ForegroundColor Cyan
Write-Host "1. Configurez VSCode pour utiliser UTF-8 sans BOM par défaut:" -ForegroundColor Green
Write-Host "   - Ajoutez ces lignes à .vscode/settings.json:"
Write-Host '   "files.encoding": "utf8",'
Write-Host '   "files.autoGuessEncoding": true'

Write-Host "`n2. Configurez Git pour gérer correctement les encodages:" -ForegroundColor Green
Write-Host "   - Exécutez ces commandes:"
Write-Host "   git config --global core.autocrlf input"
Write-Host "   git config --global core.safecrlf warn"
Write-Host "   git config --global core.quotepath false"
Write-Host "   git config --global gui.encoding utf-8"

Write-Host "`n3. Utilisez le script fix-encoding-robust.ps1 pour corriger les problèmes d'encodage existants" -ForegroundColor Green
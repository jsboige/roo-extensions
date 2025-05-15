# Script de diagnostic d'encodage pour les fichiers de configuration Roo
# Ce script analyse les fichiers de configuration pour détecter les problèmes d'encodage

param (
    [Parameter(Mandatory = $false)]
    [string]$Path = ".",
    
    [Parameter(Mandatory = $false)]
    [switch]$Recursive,
    
    [Parameter(Mandatory = $false)]
    [string[]]$FilePatterns = @("*.json", "*.md", "*.txt"),
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
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

# Fonction pour vérifier l'encodage d'un fichier
function Test-FileEncoding {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $encoding = "Unknown"
        
        # Vérifier le BOM (Byte Order Mark)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
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
            $i = 0
            while ($i -lt $bytes.Length) {
                if ($bytes[$i] -ge 0x80) {
                    # Vérifier la séquence UTF-8
                    if ($bytes[$i] -ge 0xC0 -and $bytes[$i] -le 0xDF -and $i + 1 -lt $bytes.Length -and $bytes[$i + 1] -ge 0x80 -and $bytes[$i + 1] -le 0xBF) {
                        $i += 2
                    } 
                    elseif ($bytes[$i] -ge 0xE0 -and $bytes[$i] -le 0xEF -and $i + 2 -lt $bytes.Length -and $bytes[$i + 1] -ge 0x80 -and $bytes[$i + 1] -le 0xBF -and $bytes[$i + 2] -ge 0x80 -and $bytes[$i + 2] -le 0xBF) {
                        $i += 3
                    } 
                    elseif ($bytes[$i] -ge 0xF0 -and $bytes[$i] -le 0xF7 -and $i + 3 -lt $bytes.Length -and $bytes[$i + 1] -ge 0x80 -and $bytes[$i + 1] -le 0xBF -and $bytes[$i + 2] -ge 0x80 -and $bytes[$i + 2] -le 0xBF -and $bytes[$i + 3] -ge 0x80 -and $bytes[$i + 3] -le 0xBF) {
                        $i += 4
                    } 
                    else {
                        $isUtf8 = $false
                        break
                    }
                } 
                else {
                    $i++
                }
            }
            
            if ($isUtf8) {
                $encoding = "UTF-8 without BOM"
            } 
            else {
                $encoding = "ANSI/Windows-1252 or other"
            }
        }
        
        return $encoding
    } 
    catch {
        return "Error: $($_.Exception.Message)"
    }
}

# Fonction pour détecter les problèmes d'encodage courants
function Test-EncodingIssues {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        $content = Get-Content -Path $Path -Raw
        $issues = @()
        
        # Détecter le double encodage UTF-8 (é -> Ã©)
        if ($content -match "Ã©|Ã¨|Ã |Ã§|Ãª|Ã®|Ã´|Ã»|Ã¹|Ã¢|ÃŠ|ÃŽ|Ã"|Ã™") {
            $issues += "Double encodage UTF-8 détecté (caractères comme 'é' apparaissant sous la forme 'Ã©')"
        }
        
        # Détecter le triple encodage UTF-8 (é -> ÃƒÂ©)
        if ($content -match "ÃƒÂ©|ÃƒÂ¨|ÃƒÂ |ÃƒÂ§|ÃƒÂª|ÃƒÂ®|ÃƒÂ´|ÃƒÂ»|ÃƒÂ¹|ÃƒÂ¢") {
            $issues += "Triple encodage UTF-8 détecté (caractères comme 'é' apparaissant sous la forme 'ÃƒÂ©')"
        }
        
        # Détecter les caractères de remplacement
        if ($content -match "ï¿½") {
            $issues += "Caractères de remplacement détectés (ï¿½)"
        }
        
        # Détecter les problèmes avec les emojis
        if ($content -match "ð\S\S\S|ð\S\S") {
            $issues += "Problèmes d'encodage avec les emojis détectés"
        }
        
        return $issues
    } 
    catch {
        return @("Error: $($_.Exception.Message)")
    }
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Diagnostic d'encodage pour les fichiers de configuration Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Obtenir la liste des fichiers à analyser
$files = @()
if ($Recursive) {
    $files = Get-ChildItem -Path $Path -Recurse -File -Include $FilePatterns
} 
else {
    $files = Get-ChildItem -Path $Path -File -Include $FilePatterns
}

Write-ColorOutput "`nAnalyse de $($files.Count) fichiers..." "Yellow"

# Analyser chaque fichier
$problemFiles = @()
$encodingStats = @{}

foreach ($file in $files) {
    $encoding = Test-FileEncoding -Path $file.FullName
    
    # Mettre à jour les statistiques d'encodage
    if (-not $encodingStats.ContainsKey($encoding)) {
        $encodingStats[$encoding] = 0
    }
    $encodingStats[$encoding]++
    
    # Vérifier les problèmes d'encodage
    $issues = Test-EncodingIssues -Path $file.FullName
    
    if ($issues.Count -gt 0 -or $encoding -ne "UTF-8 without BOM" -or $Verbose) {
        $problemFiles += [PSCustomObject]@{
            File = $file.FullName
            Encoding = $encoding
            Issues = $issues
        }
        
        if ($issues.Count -gt 0 -or $encoding -ne "UTF-8 without BOM") {
            Write-ColorOutput "`nProblème détecté dans le fichier: $($file.FullName)" "Red"
            Write-ColorOutput "Encodage: $encoding" "Yellow"
            
            if ($issues.Count -gt 0) {
                Write-ColorOutput "Problèmes détectés:" "Red"
                foreach ($issue in $issues) {
                    Write-ColorOutput " - $issue" "Red"
                }
            }
        } 
        elseif ($Verbose) {
            Write-ColorOutput "`nFichier: $($file.FullName)" "Green"
            Write-ColorOutput "Encodage: $encoding" "Green"
        }
    }
}

# Afficher les statistiques d'encodage
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Statistiques d'encodage" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

foreach ($key in $encodingStats.Keys) {
    $color = if ($key -eq "UTF-8 without BOM") { "Green" } else { "Yellow" }
    Write-ColorOutput "$key : $($encodingStats[$key]) fichiers" $color
}

# Afficher le résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Résumé du diagnostic" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

$problemCount = ($problemFiles | Where-Object { $_.Issues.Count -gt 0 -or $_.Encoding -ne "UTF-8 without BOM" }).Count

if ($problemCount -eq 0) {
    Write-ColorOutput "`nAucun problème d'encodage détecté!" "Green"
} 
else {
    Write-ColorOutput "`n$problemCount fichiers présentent des problèmes d'encodage." "Red"
    Write-ColorOutput "Utilisez le script fix-encoding-robust.ps1 pour corriger ces problèmes." "Yellow"
}

# Afficher les recommandations
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Recommandations" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

Write-ColorOutput "`n1. Tous les fichiers de configuration devraient être encodés en UTF-8 sans BOM" "White"
Write-ColorOutput "2. Configurez votre éditeur pour utiliser UTF-8 par défaut" "White"
Write-ColorOutput "3. Utilisez des fins de ligne LF (style Unix) pour tous les fichiers texte" "White"
Write-ColorOutput "4. Évitez de mélanger les encodages dans un même projet" "White"
Write-ColorOutput "5. Vérifiez l'encodage avant de committer des fichiers" "White"

Write-ColorOutput "`nPour plus d'informations, consultez le fichier docs/guide-encodage.md" "White"
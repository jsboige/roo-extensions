# Script de correction d'encodage minimal pour les fichiers JSON
# Cette version se concentre uniquement sur la generation d'un JSON valide

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
    
    Write-Host "Application des corrections d'encodage..." -ForegroundColor Cyan
    
    # Creer un nouveau fichier JSON minimal avec seulement les informations essentielles
    $jsonObject = @{
        customModes = @()
    }
    
    # Essayer de parser le JSON source
    try {
        $sourceJson = $content | ConvertFrom-Json
        
        # Si le parsing reussit, extraire les modes personnalises
        if ($sourceJson.customModes) {
            foreach ($mode in $sourceJson.customModes) {
                # Creer un objet mode simplifie avec seulement les proprietes essentielles
                $simplifiedMode = @{
                    slug = $mode.slug
                    name = $mode.name -replace "[^\x00-\x7F]", ""  # Supprimer les caracteres non-ASCII
                    roleDefinition = $mode.roleDefinition -replace "[^\x00-\x7F]", ""  # Supprimer les caracteres non-ASCII
                }
                
                # Ajouter les proprietes optionnelles si elles existent
                if ($mode.customInstructions) {
                    $simplifiedMode.customInstructions = $mode.customInstructions -replace "[^\x00-\x7F]", ""  # Supprimer les caracteres non-ASCII
                }
                
                if ($mode.groups) {
                    $simplifiedMode.groups = $mode.groups
                }
                
                if ($mode.source) {
                    $simplifiedMode.source = $mode.source
                }
                
                # Ajouter le mode simplifie a la liste
                $jsonObject.customModes += $simplifiedMode
            }
        }
    }
    catch {
        Write-Host "Erreur lors du parsing du JSON source. Creation d'un JSON minimal." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        
        # Creer un JSON minimal avec un seul mode
        $jsonObject.customModes += @{
            slug = "code-simple"
            name = "Code Simple"
            roleDefinition = "You are Roo Code (version simple), specialized in minor code modifications, simple bug fixes, code formatting and documentation, and basic feature implementation."
            groups = @("read", "edit", "browser", "mcp")
            source = "global"
        }
        
        $jsonObject.customModes += @{
            slug = "code-complex"
            name = "Code Complex"
            roleDefinition = "You are Roo, a highly skilled software engineer with extensive knowledge in many programming languages, frameworks, design patterns, and best practices."
            groups = @("read", "edit", "browser", "mcp")
            source = "global"
        }
    }
    
    # Convertir l'objet en JSON
    $jsonString = ConvertTo-Json $jsonObject -Depth 100 -Compress:$false
    
    # Verifier que le JSON est valide
    try {
        $null = $jsonString | ConvertFrom-Json
        Write-Host "Le JSON genere est valide." -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur: Le JSON genere n'est pas valide." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    
    # Ecrire le contenu corrige dans le fichier de sortie
    Write-Host "Ecriture du fichier corrige: $OutputPath" -ForegroundColor Cyan
    
    # Utiliser UTF-8 sans BOM pour une meilleure compatibilite
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($OutputPath, $jsonString, $utf8NoBomEncoding)
    
    Write-Host "Correction d'encodage terminee avec succes!" -ForegroundColor Green
    
    # Retourner le chemin du fichier corrige
    return $OutputPath
}
catch {
    Write-Host "Erreur lors de la correction d'encodage:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
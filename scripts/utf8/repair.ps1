#Requires -Version 5.1
<#
.SYNOPSIS
    Script de réparation consolidé pour les problèmes d'encodage UTF-8

.DESCRIPTION
    Répare automatiquement les problèmes d'encodage dans les fichiers texte.
    Ce script consolidé remplace plusieurs scripts de réparation redondants.

.PARAMETER Path
    Chemin du répertoire à analyser (défaut: répertoire courant).

.PARAMETER FilePattern
    Pattern des fichiers à traiter (défaut: *.json,*.ps1,*.md,*.txt,*.js,*.ts).

.PARAMETER FixBOM
    Supprime les BOM UTF-8 des fichiers.

.PARAMETER FixCRLF
    Convertit les fins de ligne CRLF en LF.

.PARAMETER FixEncoding
    Corrige les caractères mal encodés.

.PARAMETER All
    Active toutes les réparations (FixBOM, FixCRLF, FixEncoding).

.PARAMETER Backup
    Crée des sauvegardes avant modification.

.PARAMETER Verbose
    Affichage détaillé des opérations.

.PARAMETER WhatIf
    Simulation sans modification des fichiers.

.EXAMPLE
    .\repair.ps1 -All
    Réparation complète avec toutes les options

.EXAMPLE
    .\repair.ps1 -Path "roo-modes" -FixBOM -Backup
    Supprime les BOM dans le dossier roo-modes avec sauvegarde

.NOTES
    Version: 3.0 Consolidée
    Date: 26/09/2025
    Auteur: Roo Extensions Team
    Remplace: fix-encoding-*.ps1, repair-encoding-*.ps1
#>

param(
    [string]$Path = ".",
    [string[]]$FilePattern = @('*.json', '*.ps1', '*.md', '*.txt', '*.js', '*.ts', '*.html', '*.css'),
    [switch]$FixBOM,
    [switch]$FixCRLF,
    [switch]$FixEncoding,
    [switch]$All,
    [switch]$Backup,
    [switch]$Verbose,
    [switch]$WhatIf
)

# Variables globales
$Script:Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Header = "Magenta"
    Default = "White"
}

$Script:RepairStats = @{
    FilesScanned = 0
    FilesModified = 0
    BOMsRemoved = 0
    CRLFsFixed = 0
    EncodingsCorrected = 0
    BackupsCreated = 0
    Errors = 0
}

# =================================================================================================
# FONCTIONS UTILITAIRES
# =================================================================================================

function Write-RepairOutput {
    param(
        [string]$Message,
        [string]$Type = "Info",
        [switch]$NoNewline
    )

    $color = $Script:Colors[$Type]
    if (-not $color) { $color = $Script:Colors.Default }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp]"

    if ($NoNewline) {
        Write-Host "$prefix $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

function Write-VerboseRepair {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    if ($Verbose) {
        Write-RepairOutput $Message $Type
    }
}

function New-BackupFile {
    param(
        [string]$FilePath
    )

    if (-not $Backup) { return $null }

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "$FilePath.backup-$timestamp"
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        $Script:RepairStats.BackupsCreated++
        Write-VerboseRepair "Sauvegarde créée: $backupPath" "Success"
        return $backupPath
    } catch {
        Write-RepairOutput "Erreur lors de la sauvegarde de $FilePath : $_" "Error"
        $Script:RepairStats.Errors++
        return $null
    }
}

function Test-FileHasBOM {
    param([string]$FilePath)

    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            return @{ HasBOM = $true; Type = "UTF-8" }
        } elseif ($bytes.Length -ge 2) {
            if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
                return @{ HasBOM = $true; Type = "UTF-16 LE" }
            } elseif ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
                return @{ HasBOM = $true; Type = "UTF-16 BE" }
            }
        }
        return @{ HasBOM = $false; Type = "" }
    } catch {
        return @{ HasBOM = $false; Type = "" }
    }
}

function Remove-FileBOM {
    param(
        [string]$FilePath,
        [string]$BOMType
    )

    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $bytesToRemove = 0

        switch ($BOMType) {
            "UTF-8" { $bytesToRemove = 3 }
            "UTF-16 LE" { $bytesToRemove = 2 }
            "UTF-16 BE" { $bytesToRemove = 2 }
        }

        if ($bytesToRemove -gt 0 -and $bytes.Length -ge $bytesToRemove) {
            $contentWithoutBOM = $bytes[$bytesToRemove..($bytes.Length - 1)]

            if (-not $WhatIf) {
                [System.IO.File]::WriteAllBytes($FilePath, $contentWithoutBOM)
            }

            $Script:RepairStats.BOMsRemoved++
            return $true
        }

        return $false
    } catch {
        Write-RepairOutput "Erreur lors de la suppression du BOM dans $FilePath : $_" "Error"
        $Script:RepairStats.Errors++
        return $false
    }
}

function Repair-FileCRLF {
    param([string]$FilePath)

    try {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue

        if ($content -match "\r\n") {
            $fixedContent = $content -replace "\r\n", "`n"

            if (-not $WhatIf) {
                # Écrire le contenu sans BOM UTF-8
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($FilePath, $fixedContent, $utf8NoBom)
            }

            $Script:RepairStats.CRLFsFixed++
            return $true
        }

        return $false
    } catch {
        Write-RepairOutput "Erreur lors de la correction CRLF dans $FilePath : $_" "Error"
        $Script:RepairStats.Errors++
        return $false
    }
}

function Repair-FileEncoding {
    param([string]$FilePath)

    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $originalContent = $content

        # Dictionnaire des corrections d'encodage communes
        $encodingFixes = @{
            # Caractères français mal encodés
            "Ã©" = "é"
            "Ã¨" = "è"
            "Ãª" = "ê"
            "Ã " = "à"
            "Ã§" = "ç"
            "Ã´" = "ô"
            "Ã®" = "î"
            "Ã¯" = "ï"
            "Ã¹" = "ù"
            "Ã»" = "û"
            "Ã¢" = "â"

            # Caractères majuscules
            "Ã‰" = "É"
            "Ãˆ" = "È"
            "ÃŠ" = "Ê"
            "Ã€" = "À"
            "Ã‡" = "Ç"
            # "Ã”" = "Ô" - Commenté pour éviter erreur parsing
            "ÃŽ" = "Î"
            "Ã™" = "Ù"
            "Ã›" = "Û"
            "Ã‚" = "Â"
        }

        $hasChanges = $false

        foreach ($wrong in $encodingFixes.Keys) {
            if ($content.Contains($wrong)) {
                $content = $content.Replace($wrong, $encodingFixes[$wrong])
                $hasChanges = $true
            }
        }

        # Corrections spéciales pour les emojis mal encodés
        $emojiPattern = "ðŸ.*?ðŸ"
        if ($content -match $emojiPattern) {
            # Pattern simple pour détecter les emojis cassés, sans correction automatique
            # car c'est plus complexe
            Write-RepairOutput "[WARNING] Emojis mal encodés détectés dans $FilePath - correction manuelle recommandée" "Warning"
        }

        if ($hasChanges) {
            if (-not $WhatIf) {
                # Écrire le contenu corrigé sans BOM UTF-8
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($FilePath, $content, $utf8NoBom)
            }

            $Script:RepairStats.EncodingsCorrected++
            return $true
        }

        return $false
    } catch {
        Write-RepairOutput "Erreur lors de la correction d'encodage dans $FilePath : $_" "Error"
        $Script:RepairStats.Errors++
        return $false
    }
}

function Repair-SingleFile {
    param([System.IO.FileInfo]$File)

    $relativePath = $File.FullName.Replace((Get-Location).Path, "").TrimStart('\', '/')
    $Script:RepairStats.FilesScanned++

    Write-VerboseRepair "Analyse de: $relativePath" "Info"

    $modifications = @()
    $needsBackup = $false

    # Vérifications préliminaires
    $bomInfo = Test-FileHasBOM -FilePath $File.FullName
    $content = Get-Content -Path $File.FullName -Raw -ErrorAction SilentlyContinue
    $hasCRLF = $content -match "\r\n"

    # Déterminer les actions nécessaires
    $actions = @()

    if (($All -or $FixBOM) -and $bomInfo.HasBOM) {
        $actions += "REMOVE_BOM"
        $modifications += "BOM $($bomInfo.Type)"
    }

    if (($All -or $FixCRLF) -and $hasCRLF) {
        $actions += "FIX_CRLF"
        $modifications += "CRLF→LF"
    }

    if (($All -or $FixEncoding)) {
        # Test rapide pour voir s'il y a des caractères mal encodés
        # Simplifié pour éviter les erreurs de parsing
        $hasEncodingIssues = $content -match "Ã[©¨ª]"
        if ($hasEncodingIssues) {
            $actions += "FIX_ENCODING"
            $modifications += "Caractères"
        }
    }

    if ($actions.Count -eq 0) {
        Write-VerboseRepair "  → Aucune modification nécessaire" "Success"
        return
    }

    # Afficher les modifications prévues
    $actionText = $modifications -join ", "
    if ($WhatIf) {
        Write-RepairOutput "SIMULATION → $relativePath : $actionText" "Warning"
        return
    } else {
        Write-RepairOutput "RÉPARATION → $relativePath : $actionText" "Info"
    }

    # Créer une sauvegarde si nécessaire
    $backupPath = New-BackupFile -FilePath $File.FullName

    $fileModified = $false

    # Appliquer les réparations
    foreach ($action in $actions) {
        switch ($action) {
            "REMOVE_BOM" {
                if (Remove-FileBOM -FilePath $File.FullName -BOMType $bomInfo.Type) {
                    Write-VerboseRepair "  → BOM $($bomInfo.Type) supprimé" "Success"
                    $fileModified = $true
                }
            }

            "FIX_CRLF" {
                if (Repair-FileCRLF -FilePath $File.FullName) {
                    Write-VerboseRepair "  → CRLF convertis en LF" "Success"
                    $fileModified = $true
                }
            }

            "FIX_ENCODING" {
                if (Repair-FileEncoding -FilePath $File.FullName) {
                    Write-VerboseRepair "  → Caractères mal encodés corrigés" "Success"
                    $fileModified = $true
                }
            }
        }
    }

    if ($fileModified) {
        $Script:RepairStats.FilesModified++
        Write-VerboseRepair "  ✅ Fichier réparé avec succès" "Success"
    } else {
        Write-VerboseRepair "  [WARNING] Aucune modification appliquée" "Warning"
    }
}

function Get-FilesToProcess {
    param(
        [string]$SearchPath,
        [string[]]$Patterns
    )

    $allFiles = @()

    try {
        foreach ($pattern in $Patterns) {
            $files = Get-ChildItem -Path $SearchPath -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue
            $allFiles += $files
        }

        # Supprimer les doublons par chemin complet
        $uniqueFiles = $allFiles | Sort-Object FullName -Unique

        return $uniqueFiles
    } catch {
        Write-RepairOutput "Erreur lors de la recherche de fichiers : $_" "Error"
        return @()
    }
}

# =================================================================================================
# PROGRAMME PRINCIPAL
# =================================================================================================

Write-Host ""
Write-RepairOutput "[TOOL] RÉPARATION UTF-8 CONSOLIDÉE - ROO EXTENSIONS" "Header"
Write-RepairOutput "Version 3.0 - Réparation automatique d'encodage" "Header"
Write-RepairOutput "═══════════════════════════════════════════════════" "Header"
Write-Host ""

# Validation des paramètres
if (-not ($All -or $FixBOM -or $FixCRLF -or $FixEncoding)) {
    Write-RepairOutput "[FAIL] Aucune action spécifiée. Utilisez -All ou spécifiez -FixBOM, -FixCRLF, ou -FixEncoding" "Error"
    Write-RepairOutput "Exemples:" "Info"
    Write-RepairOutput "  .\repair.ps1 -All                    # Toutes les réparations" "Info"
    Write-RepairOutput "  .\repair.ps1 -FixBOM -FixCRLF       # BOM et CRLF uniquement" "Info"
    Write-RepairOutput "  .\repair.ps1 -All -WhatIf           # Simulation" "Info"
    exit 1
}

if ($All) {
    $FixBOM = $true
    $FixCRLF = $true
    $FixEncoding = $true
}

# Vérifier le répertoire cible
if (-not (Test-Path $Path)) {
    Write-RepairOutput "[FAIL] Le chemin spécifié n'existe pas: $Path" "Error"
    exit 1
}

$absolutePath = Resolve-Path $Path
Write-RepairOutput "[FOLDER] Répertoire cible: $absolutePath" "Info"

# Configuration d'affichage
$actions = @()
if ($FixBOM) { $actions += "Suppression BOM" }
if ($FixCRLF) { $actions += "Correction CRLF→LF" }
if ($FixEncoding) { $actions += "Correction caractères" }

Write-RepairOutput "[TARGET] Actions configurées: $($actions -join ', ')" "Info"
Write-RepairOutput "📋 Patterns de fichiers: $($FilePattern -join ', ')" "Info"
Write-RepairOutput "[SAVE] Sauvegardes: $(if($Backup) { 'ACTIVÉES' } else { 'DÉSACTIVÉES' })" "Info"
Write-RepairOutput "[SEARCH] Mode: $(if($WhatIf) { 'SIMULATION' } else { 'RÉPARATION' })" $(if($WhatIf) { "Warning" } else { "Success" })

Write-Host ""

# Recherche des fichiers
Write-RepairOutput "[SEARCH] Recherche des fichiers à traiter..." "Info"
$filesToProcess = Get-FilesToProcess -SearchPath $Path -Patterns $FilePattern

if ($filesToProcess.Count -eq 0) {
    Write-RepairOutput "[WARNING] Aucun fichier trouvé correspondant aux critères." "Warning"
    exit 0
}

Write-RepairOutput "[STATS] Fichiers trouvés: $($filesToProcess.Count)" "Success"
Write-Host ""

# Traitement des fichiers
Write-RepairOutput "[TOOL] Début du traitement..." "Header"

foreach ($file in $filesToProcess) {
    try {
        Repair-SingleFile -File $file
    } catch {
        Write-RepairOutput "[FAIL] Erreur critique lors du traitement de $($file.Name): $_" "Error"
        $Script:RepairStats.Errors++
    }
}

# Statistiques finales
Write-Host ""
Write-RepairOutput "[STATS] STATISTIQUES FINALES" "Header"
Write-RepairOutput "═════════════════════════" "Header"

Write-RepairOutput "✓ Fichiers analysés: $($Script:RepairStats.FilesScanned)" "Info"
Write-RepairOutput "✓ Fichiers modifiés: $($Script:RepairStats.FilesModified)" "Success"
Write-RepairOutput "✓ BOMs supprimés: $($Script:RepairStats.BOMsRemoved)" "Success"
Write-RepairOutput "✓ CRLFs corrigés: $($Script:RepairStats.CRLFsFixed)" "Success"
Write-RepairOutput "✓ Encodages corrigés: $($Script:RepairStats.EncodingsCorrected)" "Success"
Write-RepairOutput "✓ Sauvegardes créées: $($Script:RepairStats.BackupsCreated)" "Info"
if ($Script:RepairStats.Errors -gt 0) {
    Write-RepairOutput "[WARNING] Erreurs rencontrées: $($Script:RepairStats.Errors)" "Warning"
}

Write-Host ""

# Résumé final
$totalIssuesFixed = $Script:RepairStats.BOMsRemoved + $Script:RepairStats.CRLFsFixed + $Script:RepairStats.EncodingsCorrected

if ($WhatIf) {
    Write-RepairOutput "🎭 SIMULATION TERMINÉE - Aucun fichier n'a été modifié" "Warning"
    if ($totalIssuesFixed -gt 0) {
        Write-RepairOutput "💡 $totalIssuesFixed problème(s) seraient corrigés en mode réel" "Info"
    }
} else {
    if ($totalIssuesFixed -gt 0) {
        Write-RepairOutput "[TARGET] RÉPARATION RÉUSSIE - $totalIssuesFixed problème(s) corrigé(s)" "Success"

        if ($Script:RepairStats.FilesModified -gt 0) {
            Write-RepairOutput "🔄 Redémarrez votre éditeur pour voir les changements" "Info"
        }
    } else {
        Write-RepairOutput "[SPARKLE] AUCUNE RÉPARATION NÉCESSAIRE - Tous les fichiers sont déjà corrects" "Success"
    }
}

if ($Script:RepairStats.Errors -gt 0) {
    Write-RepairOutput "[WARNING] Vérifiez les erreurs ci-dessus et relancez si nécessaire" "Warning"
}

Write-Host ""
Write-RepairOutput "🏁 Traitement terminé." "Success"

# Code de sortie
exit $(if($Script:RepairStats.Errors -eq 0) { 0 } else { 1 })
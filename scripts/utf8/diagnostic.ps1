#Requires -Version 5.1
<#
.SYNOPSIS
    Script de diagnostic complet pour les problemes d'encodage UTF-8

.DESCRIPTION
    Effectue un diagnostic approfondi de la configuration d'encodage du systeme.
    Ce script consolide remplace plusieurs scripts de diagnostic redondants.

.PARAMETER Verbose
    Affichage detaille des operations de diagnostic.

.PARAMETER ExportReport
    Exporte le rapport de diagnostic vers un fichier.

.PARAMETER CheckFiles
    Nombre maximum de fichiers a verifier (defaut: 20).

.PARAMETER ReportPath
    Chemin du fichier de rapport (defaut: rapport-diagnostic-utf8.md).

.EXAMPLE
    .\diagnostic.ps1
    Diagnostic standard

.EXAMPLE
    .\diagnostic.ps1 -Verbose -ExportReport
    Diagnostic detaille avec export du rapport

.NOTES
    Version: 3.0 Consolidee
    Date: 26/09/2025
    Auteur: Roo Extensions Team
    Remplace: diagnose-encoding-complete.ps1, diagnose-encoding-simple.ps1
#>

param(
    [switch]$Verbose,
    [switch]$ExportReport,
    [int]$CheckFiles = 20,
    [string]$ReportPath = "rapport-diagnostic-utf8.md"
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

$Script:DiagnosticResults = @{
    SystemInfo = @{}
    PowerShellConfig = @{}
    GitConfig = @{}
    VSCodeConfig = @{}
    FileIssues = @()
    Recommendations = @()
    Summary = @{}
}

# =================================================================================================
# FONCTIONS UTILITAIRES
# =================================================================================================

function Write-DiagnosticOutput {
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

function Add-DiagnosticRecommendation {
    param(
        [string]$Issue,
        [string]$Solution,
        [string]$Priority = "Medium"
    )
    
    $Script:DiagnosticResults.Recommendations += @{
        Issue = $Issue
        Solution = $Solution
        Priority = $Priority
        Timestamp = Get-Date
    }
}

# =================================================================================================
# FONCTIONS DE DIAGNOSTIC
# =================================================================================================

function Test-SystemConfiguration {
    Write-DiagnosticOutput "[SEARCH] DIAGNOSTIC SYSTÈME" "Header"
    Write-DiagnosticOutput "═══════════════════════" "Header"
    
    $systemInfo = @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition = $PSVersionTable.PSEdition
        OSVersion = [Environment]::OSVersion.ToString()
        CurrentCodePage = (cmd /c chcp 2>&1) -replace '.*:', ''
        ConsoleOutputEncoding = [Console]::OutputEncoding.CodePage
        ConsoleInputEncoding = [Console]::InputEncoding.CodePage
        OutputEncodingVariable = $OutputEncoding.CodePage
        DefaultFileEncoding = $PSDefaultParameterValues['Out-File:Encoding']
        DefaultSetContentEncoding = $PSDefaultParameterValues['Set-Content:Encoding']
    }
    
    $Script:DiagnosticResults.SystemInfo = $systemInfo
    
    Write-DiagnosticOutput "✓ Version PowerShell: $($systemInfo.PowerShellVersion) ($($systemInfo.PowerShellEdition))" "Info"
    Write-DiagnosticOutput "✓ Systeme d'exploitation: $($systemInfo.OSVersion)" "Info"
    
    # Verification code page
    $isUTF8CodePage = $systemInfo.CurrentCodePage -match "65001"
    Write-DiagnosticOutput "✓ Code page systeme: $($systemInfo.CurrentCodePage.Trim()) $(if($isUTF8CodePage) { "(UTF-8 [OK])" } else { "(PAS UTF-8 [FAIL])" })" $(if($isUTF8CodePage) { "Success" } else { "Error" })
    
    # Verification encodages console
    $isConsoleUTF8 = $systemInfo.ConsoleOutputEncoding -eq 65001 -and $systemInfo.ConsoleInputEncoding -eq 65001
    Write-DiagnosticOutput "✓ Console Output/Input: $($systemInfo.ConsoleOutputEncoding)/$($systemInfo.ConsoleInputEncoding) $(if($isConsoleUTF8) { "(UTF-8 [OK])" } else { "(PAS UTF-8 [FAIL])" })" $(if($isConsoleUTF8) { "Success" } else { "Error" })
    
    # Verification variable OutputEncoding
    $isOutputEncodingUTF8 = $systemInfo.OutputEncodingVariable -eq 65001
    Write-DiagnosticOutput "✓ Variable `$OutputEncoding: $($systemInfo.OutputEncodingVariable) $(if($isOutputEncodingUTF8) { "(UTF-8 [OK])" } else { "(PAS UTF-8 [FAIL])" })" $(if($isOutputEncodingUTF8) { "Success" } else { "Error" })
    
    # Verification parametres par defaut
    $hasDefaultEncodings = $systemInfo.DefaultFileEncoding -eq 'utf8NoBOM' -and $systemInfo.DefaultSetContentEncoding -eq 'utf8NoBOM'
    Write-DiagnosticOutput "✓ Encodages par defaut: Out-File=$($systemInfo.DefaultFileEncoding), Set-Content=$($systemInfo.DefaultSetContentEncoding) $(if($hasDefaultEncodings) { "([OK])" } else { "([FAIL])" })" $(if($hasDefaultEncodings) { "Success" } else { "Error" })
    
    # Recommandations systeme
    if (-not $isUTF8CodePage) {
        Add-DiagnosticRecommendation -Issue "Code page systeme n'est pas UTF-8" -Solution "Executer 'chcp 65001' ou utiliser scripts/utf8/setup.ps1" -Priority "High"
    }
    
    if (-not $isConsoleUTF8) {
        Add-DiagnosticRecommendation -Issue "Encodages console non configures en UTF-8" -Solution "Configurer [Console]::OutputEncoding et InputEncoding" -Priority "High"
    }
    
    if (-not $hasDefaultEncodings) {
        Add-DiagnosticRecommendation -Issue "Parametres par defaut PowerShell non configures" -Solution "Definir `$PSDefaultParameterValues pour Out-File et Set-Content" -Priority "Medium"
    }
    
    Write-Host ""
    return @{
        IsFullyConfigured = $isUTF8CodePage -and $isConsoleUTF8 -and $hasDefaultEncodings
        CodePageOK = $isUTF8CodePage
        ConsoleOK = $isConsoleUTF8
        DefaultsOK = $hasDefaultEncodings
    }
}

function Test-PowerShellProfile {
    Write-DiagnosticOutput "[SEARCH] DIAGNOSTIC PROFIL POWERSHELL" "Header"
    Write-DiagnosticOutput "════════════════════════════════" "Header"
    
    $profileInfo = @{
        ProfilePath = $PROFILE
        ProfileExists = Test-Path $PROFILE
        ProfileSize = 0
        HasEncodingConfig = $false
        EncodingLines = @()
        BackupsAvailable = 0
    }
    
    if ($profileInfo.ProfileExists) {
        $profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
        $profileInfo.ProfileSize = $profileContent.Length
        $profileInfo.HasEncodingConfig = $profileContent -match "Configuration d'encodage pour roo-extensions"
        
        # Extraire les lignes d'encodage
        $lines = Get-Content -Path $PROFILE -ErrorAction SilentlyContinue
        $profileInfo.EncodingLines = $lines | Where-Object { $_ -match "(Console|OutputEncoding|PSDefaultParameterValues|chcp)" }
        
        # Compter les sauvegardes
        $profileDir = Split-Path $PROFILE -Parent
        $profileName = Split-Path $PROFILE -Leaf
        if (Test-Path $profileDir) {
            $backups = Get-ChildItem -Path $profileDir -Filter "$profileName.backup-*" -ErrorAction SilentlyContinue
            $profileInfo.BackupsAvailable = $backups.Count
        }
    }
    
    $Script:DiagnosticResults.PowerShellConfig = $profileInfo
    
    Write-DiagnosticOutput "✓ Chemin du profil: $($profileInfo.ProfilePath)" "Info"
    Write-DiagnosticOutput "✓ Profil existe: $(if($profileInfo.ProfileExists) { "OUI [OK]" } else { "NON [FAIL]" })" $(if($profileInfo.ProfileExists) { "Success" } else { "Error" })
    
    if ($profileInfo.ProfileExists) {
        Write-DiagnosticOutput "✓ Taille du profil: $($profileInfo.ProfileSize) octets" "Info"
        Write-DiagnosticOutput "✓ Configuration encodage: $(if($profileInfo.HasEncodingConfig) { "PRÉSENTE [OK]" } else { "ABSENTE [FAIL]" })" $(if($profileInfo.HasEncodingConfig) { "Success" } else { "Error" })
        Write-DiagnosticOutput "✓ Sauvegardes disponibles: $($profileInfo.BackupsAvailable)" "Info"
        
        if ($Verbose -and $profileInfo.EncodingLines.Count -gt 0) {
            Write-DiagnosticOutput "✓ Lignes d'encodage detectees:" "Info"
            foreach ($line in $profileInfo.EncodingLines) {
                Write-DiagnosticOutput "  → $line" "Info"
            }
        }
    }
    
    # Recommandations profil
    if (-not $profileInfo.ProfileExists) {
        Add-DiagnosticRecommendation -Issue "Profil PowerShell n'existe pas" -Solution "Creer le profil avec scripts/utf8/setup.ps1" -Priority "Medium"
    } elseif (-not $profileInfo.HasEncodingConfig) {
        Add-DiagnosticRecommendation -Issue "Configuration UTF-8 absente du profil" -Solution "Ajouter la configuration avec scripts/utf8/setup.ps1" -Priority "High"
    }
    
    Write-Host ""
    return $profileInfo
}

function Test-GitConfiguration {
    Write-DiagnosticOutput "[SEARCH] DIAGNOSTIC CONFIGURATION GIT" "Header"
    Write-DiagnosticOutput "═════════════════════════════════" "Header"
    
    $gitInfo = @{
        GitInstalled = $false
        GitVersion = ""
        Configs = @{}
        IsProperlyConfigured = $false
    }
    
    try {
        $gitVersion = git --version 2>$null
        if ($?) {
            $gitInfo.GitInstalled = $true
            $gitInfo.GitVersion = $gitVersion
            
            # Verifier les configurations importantes
            $configs = @(
                'core.autocrlf',
                'core.safecrlf', 
                'i18n.commitencoding',
                'i18n.logoutputencoding',
                'core.quotepath',
                'gui.encoding'
            )
            
            foreach ($config in $configs) {
                $value = git config --global $config 2>$null
                $gitInfo.Configs[$config] = $value
            }
            
            # Verifier si la configuration est correcte
            $gitInfo.IsProperlyConfigured = (
                $gitInfo.Configs['core.autocrlf'] -eq 'input' -and
                $gitInfo.Configs['i18n.commitencoding'] -eq 'utf-8' -and
                $gitInfo.Configs['i18n.logoutputencoding'] -eq 'utf-8' -and
                $gitInfo.Configs['core.quotepath'] -eq 'false' -and
                $gitInfo.Configs['gui.encoding'] -eq 'utf-8'
            )
        }
    } catch {
        $gitInfo.GitInstalled = $false
    }
    
    $Script:DiagnosticResults.GitConfig = $gitInfo
    
    if ($gitInfo.GitInstalled) {
        Write-DiagnosticOutput "✓ Git installe: OUI [OK] ($($gitInfo.GitVersion))" "Success"
        Write-DiagnosticOutput "✓ Configuration UTF-8: $(if($gitInfo.IsProperlyConfigured) { "CORRECTE [OK]" } else { "INCORRECTE [FAIL]" })" $(if($gitInfo.IsProperlyConfigured) { "Success" } else { "Error" })
        
        if ($Verbose) {
            Write-DiagnosticOutput "✓ Details de configuration Git:" "Info"
            foreach ($config in $gitInfo.Configs.Keys) {
                $value = $gitInfo.Configs[$config]
                $status = switch ($config) {
                    'core.autocrlf' { if ($value -eq 'input') { "[OK]" } else { "[FAIL]" } }
                    'i18n.commitencoding' { if ($value -eq 'utf-8') { "[OK]" } else { "[FAIL]" } }
                    'i18n.logoutputencoding' { if ($value -eq 'utf-8') { "[OK]" } else { "[FAIL]" } }
                    'core.quotepath' { if ($value -eq 'false') { "[OK]" } else { "[FAIL]" } }
                    'gui.encoding' { if ($value -eq 'utf-8') { "[OK]" } else { "[FAIL]" } }
                    default { "ℹ️" }
                }
                Write-DiagnosticOutput "  → $config = $value $status" "Info"
            }
        }
    } else {
        Write-DiagnosticOutput "✓ Git installe: NON [FAIL]" "Error"
    }
    
    # Recommandations Git
    if (-not $gitInfo.GitInstalled) {
        Add-DiagnosticRecommendation -Issue "Git n'est pas installe" -Solution "Installer Git depuis https://git-scm.com/" -Priority "Medium"
    } elseif (-not $gitInfo.IsProperlyConfigured) {
        Add-DiagnosticRecommendation -Issue "Configuration Git non optimale pour UTF-8" -Solution "Configurer Git avec scripts/utf8/setup.ps1" -Priority "Medium"
    }
    
    Write-Host ""
    return $gitInfo
}

function Test-VSCodeConfiguration {
    Write-DiagnosticOutput "[SEARCH] DIAGNOSTIC CONFIGURATION VSCODE" "Header"
    Write-DiagnosticOutput "════════════════════════════════════" "Header"
    
    $vscodeInfo = @{
        VSCodeDirExists = $false
        SettingsFileExists = $false
        SettingsSize = 0
        HasEncodingConfig = $false
        EncodingSettings = @{}
        IsProperlyConfigured = $false
    }
    
    $vscodeDir = Join-Path -Path (Get-Location) -ChildPath ".vscode"
    $settingsPath = Join-Path -Path $vscodeDir -ChildPath "settings.json"
    
    $vscodeInfo.VSCodeDirExists = Test-Path $vscodeDir
    $vscodeInfo.SettingsFileExists = Test-Path $settingsPath
    
    if ($vscodeInfo.SettingsFileExists) {
        try {
            $content = Get-Content -Path $settingsPath -Raw
            $vscodeInfo.SettingsSize = $content.Length
            
            # Parser le JSON (supprimer les commentaires d'abord)
            $contentWithoutComments = $content -replace '(?s)/\*.*?\*/' -replace '//.*'
            $settings = $contentWithoutComments | ConvertFrom-Json -ErrorAction SilentlyContinue
            
            if ($settings) {
                # Verifier les parametres d'encodage importants
                $encodingKeys = @('files.encoding', 'files.autoGuessEncoding', 'files.eol')
                foreach ($key in $encodingKeys) {
                    if ($settings.PSObject.Properties[$key]) {
                        $vscodeInfo.EncodingSettings[$key] = $settings.$key
                    }
                }
                
                $vscodeInfo.HasEncodingConfig = $vscodeInfo.EncodingSettings.Count -gt 0
                $vscodeInfo.IsProperlyConfigured = (
                    $vscodeInfo.EncodingSettings['files.encoding'] -eq 'utf8' -and
                    $vscodeInfo.EncodingSettings['files.eol'] -eq "`n"
                )
            }
        } catch {
            Write-DiagnosticOutput "[WARNING] Erreur lors de la lecture de settings.json: $_" "Warning"
        }
    }
    
    $Script:DiagnosticResults.VSCodeConfig = $vscodeInfo
    
    Write-DiagnosticOutput "✓ Repertoire .vscode: $(if($vscodeInfo.VSCodeDirExists) { "EXISTE [OK]" } else { "ABSENT [FAIL]" })" $(if($vscodeInfo.VSCodeDirExists) { "Success" } else { "Warning" })
    Write-DiagnosticOutput "✓ Fichier settings.json: $(if($vscodeInfo.SettingsFileExists) { "EXISTE [OK]" } else { "ABSENT [FAIL]" })" $(if($vscodeInfo.SettingsFileExists) { "Success" } else { "Warning" })
    
    if ($vscodeInfo.SettingsFileExists) {
        Write-DiagnosticOutput "✓ Taille settings.json: $($vscodeInfo.SettingsSize) octets" "Info"
        Write-DiagnosticOutput "✓ Configuration encodage: $(if($vscodeInfo.IsProperlyConfigured) { "CORRECTE [OK]" } else { "INCORRECTE [FAIL]" })" $(if($vscodeInfo.IsProperlyConfigured) { "Success" } else { "Error" })
        
        if ($Verbose -and $vscodeInfo.EncodingSettings.Count -gt 0) {
            Write-DiagnosticOutput "✓ Parametres d'encodage detectes:" "Info"
            foreach ($key in $vscodeInfo.EncodingSettings.Keys) {
                $value = $vscodeInfo.EncodingSettings[$key]
                Write-DiagnosticOutput "  → $key = $value" "Info"
            }
        }
    }
    
    # Recommandations VSCode
    if (-not $vscodeInfo.VSCodeDirExists) {
        Add-DiagnosticRecommendation -Issue "Repertoire .vscode absent" -Solution "Creer la configuration VSCode avec scripts/utf8/setup.ps1" -Priority "Low"
    } elseif (-not $vscodeInfo.IsProperlyConfigured) {
        Add-DiagnosticRecommendation -Issue "Configuration VSCode non optimale pour UTF-8" -Solution "Configurer VSCode avec scripts/utf8/setup.ps1" -Priority "Low"
    }
    
    Write-Host ""
    return $vscodeInfo
}

function Test-FilesEncoding {
    Write-DiagnosticOutput "[SEARCH] DIAGNOSTIC FICHIERS ENCODAGE" "Header"
    Write-DiagnosticOutput "═════════════════════════════════" "Header"
    
    $fileIssues = @()
    
    try {
        # Rechercher les fichiers texte
        $extensions = @('*.json', '*.ps1', '*.md', '*.txt', '*.js', '*.ts', '*.html', '*.css')
        $allFiles = @()
        
        foreach ($ext in $extensions) {
            $files = Get-ChildItem -Path (Get-Location) -Filter $ext -Recurse -ErrorAction SilentlyContinue
            $allFiles += $files
        }
        
        $totalFiles = $allFiles.Count
        $filesToCheck = $allFiles | Select-Object -First $CheckFiles
        $checkedCount = $filesToCheck.Count
        
        Write-DiagnosticOutput "✓ Fichiers trouves: $totalFiles (verification des $checkedCount premiers)" "Info"
        
        foreach ($file in $filesToCheck) {
            try {
                $relativePath = $file.FullName.Replace((Get-Location).Path, "").TrimStart('\', '/')
                
                # Lire les premiers octets pour detecter BOM
                $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
                $hasBOM = $false
                $bomType = ""
                
                if ($bytes.Length -ge 3) {
                    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                        $hasBOM = $true
                        $bomType = "UTF-8"
                    }
                } elseif ($bytes.Length -ge 2) {
                    if (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF)) {
                        $hasBOM = $true
                        $bomType = "UTF-16"
                    }
                }
                
                # Verifier les fins de ligne
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                $hasCRLF = $content -match "\r\n"
                
                # Verifier la validite (pour JSON)
                $isValidContent = $true
                $contentError = ""
                if ($file.Extension -eq '.json') {
                    try {
                        $null = $content | ConvertFrom-Json
                    } catch {
                        $isValidContent = $false
                        $contentError = $_.Exception.Message
                    }
                }
                
                # Ajouter a la liste des problemes si necessaire
                if ($hasBOM -or $hasCRLF -or (-not $isValidContent)) {
                    $issue = @{
                        File = $relativePath
                        HasBOM = $hasBOM
                        BOMType = $bomType
                        HasCRLF = $hasCRLF
                        IsValidContent = $isValidContent
                        ContentError = $contentError
                        Size = $file.Length
                        Extension = $file.Extension
                    }
                    $fileIssues += $issue
                }
                
                if ($Verbose) {
                    $status = "[OK]"
                    if ($hasBOM -or $hasCRLF -or (-not $isValidContent)) { $status = "[FAIL]" }
                    Write-DiagnosticOutput "  → $relativePath $status" $(if($status -eq "[OK]") { "Success" } else { "Error" })
                }
                
            } catch {
                Write-DiagnosticOutput "[WARNING] Erreur lors de la verification de $($file.Name): $_" "Warning"
            }
        }
        
        $Script:DiagnosticResults.FileIssues = $fileIssues
        
        if ($fileIssues.Count -eq 0) {
            Write-DiagnosticOutput "[OK] Aucun probleme d'encodage detecte dans les fichiers verifies" "Success"
        } else {
            Write-DiagnosticOutput "[FAIL] Problemes detectes dans $($fileIssues.Count) fichier(s):" "Error"
            
            foreach ($issue in $fileIssues) {
                $problems = @()
                if ($issue.HasBOM) { $problems += "BOM $($issue.BOMType)" }
                if ($issue.HasCRLF) { $problems += "CRLF" }
                if (-not $issue.IsValidContent) { $problems += "CONTENU INVALIDE" }
                
                Write-DiagnosticOutput "  → $($issue.File): $($problems -join ', ')" "Error"
                
                if ($Verbose -and -not $issue.IsValidContent) {
                    Write-DiagnosticOutput "    Erreur: $($issue.ContentError)" "Error"
                }
            }
            
            Add-DiagnosticRecommendation -Issue "$($fileIssues.Count) fichier(s) avec problemes d'encodage" -Solution "Corriger avec scripts/utf8/repair.ps1" -Priority "Medium"
        }
        
    } catch {
        Write-DiagnosticOutput "[FAIL] Erreur lors de la verification des fichiers: $_" "Error"
    }
    
    Write-Host ""
    return $fileIssues
}

function Export-DiagnosticReport {
    param([string]$Path)
    
    $report = @"
# Rapport de Diagnostic UTF-8 - Roo Extensions

**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Genere par**: scripts/utf8/diagnostic.ps1  
**Version**: 3.0 Consolidee  

## [STATS] Resume Executif

"@

    # Calcul du score global
    $scores = @{
        System = if($Script:DiagnosticResults.Summary.SystemOK) { 100 } else { 0 }
        Profile = if($Script:DiagnosticResults.Summary.ProfileOK) { 100 } else { 0 }
        Git = if($Script:DiagnosticResults.Summary.GitOK) { 100 } else { 50 }
        VSCode = if($Script:DiagnosticResults.Summary.VSCodeOK) { 100 } else { 75 }
        Files = if($Script:DiagnosticResults.FileIssues.Count -eq 0) { 100 } else { 50 }
    }
    
    $globalScore = ($scores.Values | Measure-Object -Average).Average
    $status = if($globalScore -ge 90) { "[OK] EXCELLENT" } elseif($globalScore -ge 70) { "[WARNING] ACCEPTABLE" } else { "[FAIL] PROBLÉMATIQUE" }
    
    $report += @"

**Score Global**: $([math]::Round($globalScore, 1))% - $status

| Composant | Score | État |
|-----------|-------|------|
| Systeme PowerShell | $($scores.System)% | $(if($scores.System -eq 100) { "[OK]" } else { "[FAIL]" }) |
| Profil PowerShell | $($scores.Profile)% | $(if($scores.Profile -eq 100) { "[OK]" } else { "[FAIL]" }) |
| Configuration Git | $($scores.Git)% | $(if($scores.Git -eq 100) { "[OK]" } elseif($scores.Git -eq 50) { "[WARNING]" } else { "[FAIL]" }) |
| Configuration VSCode | $($scores.VSCode)% | $(if($scores.VSCode -eq 100) { "[OK]" } elseif($scores.VSCode -eq 75) { "[WARNING]" } else { "[FAIL]" }) |
| Fichiers | $($scores.Files)% | $(if($scores.Files -eq 100) { "[OK]" } else { "[FAIL]" }) |

## 🖥️ Configuration Systeme

**PowerShell**: $($Script:DiagnosticResults.SystemInfo.PowerShellVersion) ($($Script:DiagnosticResults.SystemInfo.PowerShellEdition))  
**OS**: $($Script:DiagnosticResults.SystemInfo.OSVersion)  
**Code Page**: $($Script:DiagnosticResults.SystemInfo.CurrentCodePage)  
**Console Encoding**: Output=$($Script:DiagnosticResults.SystemInfo.ConsoleOutputEncoding), Input=$($Script:DiagnosticResults.SystemInfo.ConsoleInputEncoding)  

## [TOOL] Profil PowerShell

**Chemin**: `$($Script:DiagnosticResults.PowerShellConfig.ProfilePath)`  
**Existe**: $(if($Script:DiagnosticResults.PowerShellConfig.ProfileExists) { "[OK] OUI" } else { "[FAIL] NON" })  
**Configuration UTF-8**: $(if($Script:DiagnosticResults.PowerShellConfig.HasEncodingConfig) { "[OK] PRÉSENTE" } else { "[FAIL] ABSENTE" })  
**Sauvegardes**: $($Script:DiagnosticResults.PowerShellConfig.BackupsAvailable)  

## 🔄 Configuration Git

**Installe**: $(if($Script:DiagnosticResults.GitConfig.GitInstalled) { "[OK] OUI ($($Script:DiagnosticResults.GitConfig.GitVersion))" } else { "[FAIL] NON" })  
$(if($Script:DiagnosticResults.GitConfig.GitInstalled) {
"**Configuration UTF-8**: $(if($Script:DiagnosticResults.GitConfig.IsProperlyConfigured) { "[OK] CORRECTE" } else { "[FAIL] INCORRECTE" })  

### Details Configuration Git
"
foreach($config in $Script:DiagnosticResults.GitConfig.Configs.Keys) {
    $value = $Script:DiagnosticResults.GitConfig.Configs[$config]
    "- **$config**: `$value`  "
}
})

## 📝 Configuration VSCode

**Repertoire .vscode**: $(if($Script:DiagnosticResults.VSCodeConfig.VSCodeDirExists) { "[OK] EXISTE" } else { "[FAIL] ABSENT" })  
**settings.json**: $(if($Script:DiagnosticResults.VSCodeConfig.SettingsFileExists) { "[OK] EXISTE" } else { "[FAIL] ABSENT" })  
$(if($Script:DiagnosticResults.VSCodeConfig.SettingsFileExists) {
"**Configuration UTF-8**: $(if($Script:DiagnosticResults.VSCodeConfig.IsProperlyConfigured) { "[OK] CORRECTE" } else { "[FAIL] INCORRECTE" })  
"})

## 📁 Problemes de Fichiers

$(if($Script:DiagnosticResults.FileIssues.Count -eq 0) {
"[OK] **Aucun probleme detecte** dans les fichiers verifies."
} else {
"[FAIL] **$($Script:DiagnosticResults.FileIssues.Count) fichier(s) problematique(s)**:

| Fichier | BOM | CRLF | Valide |
|---------|-----|------|--------|"
foreach($issue in $Script:DiagnosticResults.FileIssues) {
    "| ``$($issue.File)`` | $(if($issue.HasBOM) { "[FAIL] $($issue.BOMType)" } else { "[OK]" }) | $(if($issue.HasCRLF) { "[FAIL]" } else { "[OK]" }) | $(if($issue.IsValidContent) { "[OK]" } else { "[FAIL]" }) |"
}
})

## [TARGET] Recommandations

$(if($Script:DiagnosticResults.Recommendations.Count -eq 0) {
"[OK] **Aucune recommandation** - Votre configuration est optimale!"
} else {
foreach($rec in ($Script:DiagnosticResults.Recommendations | Sort-Object Priority -Descending)) {
    $priorityIcon = switch($rec.Priority) {
        'High' { '🔴' }
        'Medium' { '🟡' }
        'Low' { '🟢' }
        default { '⚪' }
    }
    
    "### $priorityIcon $($rec.Priority) Priority

**Probleme**: $($rec.Issue)  
**Solution**: $($rec.Solution)

"
}
})

## [ROCKET] Actions Recommandees

1. **Configuration Rapide**: Executez ``scripts/utf8/setup.ps1`` pour une configuration automatique
2. **Reparation Fichiers**: Utilisez ``scripts/utf8/repair.ps1`` pour corriger les fichiers problematiques
3. **Test Configuration**: Relancez ``scripts/utf8/diagnostic.ps1`` apres les corrections

---
*Rapport genere automatiquement par le systeme de diagnostic Roo Extensions*
"@

    try {
        Set-Content -Path $Path -Value $report -Encoding UTF8
        Write-DiagnosticOutput "[FILE] Rapport exporte vers: $Path" "Success"
        return $true
    } catch {
        Write-DiagnosticOutput "[FAIL] Erreur lors de l'export: $_" "Error"
        return $false
    }
}

# =================================================================================================
# PROGRAMME PRINCIPAL
# =================================================================================================

Write-Host ""
Write-DiagnosticOutput "[SEARCH] DIAGNOSTIC UTF-8 CONSOLIDÉ - ROO EXTENSIONS" "Header"
Write-DiagnosticOutput "Version 3.0 - Diagnostic complet d'encodage" "Header"
Write-DiagnosticOutput "═════════════════════════════════════════════════" "Header"
Write-Host ""

# Effectuer tous les diagnostics
$systemResult = Test-SystemConfiguration
$profileResult = Test-PowerShellProfile
$gitResult = Test-GitConfiguration
$vscodeResult = Test-VSCodeConfiguration
$fileIssues = Test-FilesEncoding

# Calculer le resume
$Script:DiagnosticResults.Summary = @{
    SystemOK = $systemResult.IsFullyConfigured
    ProfileOK = $profileResult.ProfileExists -and $profileResult.HasEncodingConfig
    GitOK = $gitResult.GitInstalled -and $gitResult.IsProperlyConfigured
    VSCodeOK = $vscodeResult.IsProperlyConfigured -or (-not $vscodeResult.SettingsFileExists)
    FilesOK = $fileIssues.Count -eq 0
    TotalRecommendations = $Script:DiagnosticResults.Recommendations.Count
}

# Resume final
Write-DiagnosticOutput "[LIST] RÉSUMÉ FINAL" "Header"
Write-DiagnosticOutput "═══════════════" "Header"

$allOK = $Script:DiagnosticResults.Summary.SystemOK -and $Script:DiagnosticResults.Summary.ProfileOK -and $Script:DiagnosticResults.Summary.FilesOK

Write-DiagnosticOutput "✓ Systeme PowerShell: $(if($Script:DiagnosticResults.Summary.SystemOK) { "[OK] OK" } else { "[FAIL] PROBLÈME" })" $(if($Script:DiagnosticResults.Summary.SystemOK) { "Success" } else { "Error" })
Write-DiagnosticOutput "✓ Profil PowerShell: $(if($Script:DiagnosticResults.Summary.ProfileOK) { "[OK] OK" } else { "[FAIL] PROBLÈME" })" $(if($Script:DiagnosticResults.Summary.ProfileOK) { "Success" } else { "Error" })
Write-DiagnosticOutput "✓ Configuration Git: $(if($Script:DiagnosticResults.Summary.GitOK) { "[OK] OK" } else { "[WARNING] ATTENTION" })" $(if($Script:DiagnosticResults.Summary.GitOK) { "Success" } else { "Warning" })
Write-DiagnosticOutput "✓ Configuration VSCode: $(if($Script:DiagnosticResults.Summary.VSCodeOK) { "[OK] OK" } else { "[WARNING] ATTENTION" })" $(if($Script:DiagnosticResults.Summary.VSCodeOK) { "Success" } else { "Warning" })
Write-DiagnosticOutput "✓ Fichiers: $(if($Script:DiagnosticResults.Summary.FilesOK) { "[OK] OK" } else { "[FAIL] PROBLÈMES" })" $(if($Script:DiagnosticResults.Summary.FilesOK) { "Success" } else { "Error" })

Write-Host ""
Write-DiagnosticOutput "[TARGET] STATUT GLOBAL: $(if($allOK) { "[OK] CONFIGURATION OPTIMALE" } else { "[WARNING] AMÉLIORATIONS NÉCESSAIRES" })" $(if($allOK) { "Success" } else { "Warning" })
Write-DiagnosticOutput "📝 Recommandations: $($Script:DiagnosticResults.Summary.TotalRecommendations)" "Info"

if ($Script:DiagnosticResults.Summary.TotalRecommendations -gt 0) {
    Write-Host ""
    Write-DiagnosticOutput "[TOOL] ACTIONS RECOMMANDÉES:" "Header"
    foreach ($rec in ($Script:DiagnosticResults.Recommendations | Sort-Object Priority -Descending)) {
        $priorityIcon = switch ($rec.Priority) {
            'High' { '🔴' }
            'Medium' { '🟡' }
            'Low' { '🟢' }
            default { '⚪' }
        }
        Write-DiagnosticOutput "$priorityIcon [$($rec.Priority)] $($rec.Issue)" "Warning"
        Write-DiagnosticOutput "   → $($rec.Solution)" "Info"
    }
    
    Write-Host ""
    Write-DiagnosticOutput "⚡ SOLUTION RAPIDE:" "Header"
    Write-DiagnosticOutput "   scripts/utf8/setup.ps1  # Configuration automatique" "Info"
    Write-DiagnosticOutput "   scripts/utf8/repair.ps1 # Reparation des fichiers" "Info"
}

# Export du rapport si demande
if ($ExportReport) {
    Write-Host ""
    Export-DiagnosticReport -Path $ReportPath
}

Write-Host ""
Write-DiagnosticOutput "[FINISH] Diagnostic termine." "Success"

# Code de sortie
exit $(if($allOK) { 0 } else { 1 })
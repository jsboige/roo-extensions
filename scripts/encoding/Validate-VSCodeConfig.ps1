<#
.SYNOPSIS
    Valide la configuration VSCode pour le support UTF-8.
.DESCRIPTION
    Ce script vérifie que la configuration VSCode (settings.json) respecte les standards d'encodage définis :
    - files.encoding = "utf8"
    - files.autoGuessEncoding = false
    - files.eol = "\n"
    - Profil terminal par défaut = "PowerShell UTF-8"
    - Profil "PowerShell UTF-8" existe et contient "chcp 65001"
.EXAMPLE
    .\Validate-VSCodeConfig.ps1
.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
    ID Tâche: SDDD-T002b
#>

[CmdletBinding()]
param(
    [string]$SettingsPath = ".vscode/settings.json"
)

# Configuration
$LogFile = "logs\Validate-VSCodeConfig-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } default { "Cyan" } })
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Test-JsonSetting {
    param(
        [PSCustomObject]$Settings,
        [string]$PropertyPath,
        [object]$ExpectedValue,
        [string]$Description
    )

    $current = $Settings
    $pathParts = $PropertyPath -split '\.'
    
    foreach ($part in $pathParts) {
        if ($current -eq $null) { break }
        # Gestion des propriétés avec des points dans le nom (ex: terminal.integrated.profiles.windows)
        # Si la propriété n'existe pas directement, on essaie de voir si c'est une propriété imbriquée
        if ($current.PSObject.Properties[$part]) {
             $current = $current.$part
        } else {
             # Fallback pour les objets PSCustomObject qui pourraient ne pas exposer les propriétés dynamiques de la même manière
             $current = $current | Select-Object -ExpandProperty $part -ErrorAction SilentlyContinue
        }
    }

    if ($current -eq $ExpectedValue) {
        Write-Log "✅ $Description : OK ($current)" "SUCCESS"
        return $true
    } else {
        Write-Log "❌ $Description : ÉCHEC (Attendu: $ExpectedValue, Trouvé: $current)" "ERROR"
        return $false
    }
}

try {
    Write-Log "Début de la validation de la configuration VSCode..." "INFO"

    if (!(Test-Path $SettingsPath)) {
        Write-Log "Fichier de configuration non trouvé: $SettingsPath" "ERROR"
        exit 1
    }

    Write-Log "Lecture du fichier: $SettingsPath" "INFO"
    $jsonContent = Get-Content -Path $SettingsPath -Raw -Encoding UTF8
    
    # Nettoyage basique des commentaires JSONC pour le parsing
    $jsonClean = $jsonContent -replace "(?m)^\s*//.*$",""
    
    try {
        $settings = $jsonClean | ConvertFrom-Json
    } catch {
        Write-Log "Erreur de parsing JSON: $($_.Exception.Message)" "ERROR"
        exit 1
    }

    $allTestsPassed = $true

    # 1. Encodage des fichiers
    # Note: ConvertFrom-Json peut ne pas parser les clés avec des points comme des objets imbriqués.
    # On vérifie d'abord l'accès direct par clé littérale.
    
    $filesEncoding = $settings.'files.encoding'
    if ($filesEncoding -eq "utf8") {
        Write-Log "✅ files.encoding : OK ($filesEncoding)" "SUCCESS"
    } else {
        Write-Log "❌ files.encoding : ÉCHEC (Attendu: utf8, Trouvé: $filesEncoding)" "ERROR"
        $allTestsPassed = $false
    }
    
    # 2. Auto-guess encoding
    $autoGuess = $settings.'files.autoGuessEncoding'
    if ($autoGuess -eq $false) {
        Write-Log "✅ files.autoGuessEncoding : OK ($autoGuess)" "SUCCESS"
    } else {
        Write-Log "❌ files.autoGuessEncoding : ÉCHEC (Attendu: False, Trouvé: $autoGuess)" "ERROR"
        $allTestsPassed = $false
    }
    
    # 3. Fins de ligne
    $eol = $settings.'files.eol'
    if ($eol -eq "`n") {
        Write-Log "✅ files.eol : OK (\n)" "SUCCESS"
    } else {
        Write-Log "❌ files.eol : ÉCHEC (Attendu: \n, Trouvé: $eol)" "ERROR"
        $allTestsPassed = $false
    }
    
    # 4. Profil par défaut
    # Note: ConvertFrom-Json peut créer des objets imbriqués ou des propriétés avec des points selon la structure.
    # Ici, on accède directement aux propriétés car la structure JSON est plate pour les clés avec des points dans VSCode settings.json
    # MAIS ConvertFrom-Json ne gère pas les clés avec des points comme des objets imbriqués par défaut, il les garde comme des clés littérales.
    
    $defaultProfile = $settings.'terminal.integrated.defaultProfile.windows'
    if ($defaultProfile -eq "PowerShell UTF-8") {
        Write-Log "✅ Profil terminal par défaut : OK ($defaultProfile)" "SUCCESS"
    } else {
        Write-Log "❌ Profil terminal par défaut : ÉCHEC (Attendu: PowerShell UTF-8, Trouvé: $defaultProfile)" "ERROR"
        $allTestsPassed = $false
    }

    # 5. Configuration du profil PowerShell UTF-8
    $profileName = "PowerShell UTF-8"
    $profiles = $settings.'terminal.integrated.profiles.windows'
    
    if ($profiles.$profileName) {
        Write-Log "✅ Profil '$profileName' existe" "SUCCESS"
        
        $profileArgs = $profiles.$profileName.args
        if ($profileArgs -contains "chcp 65001") {
            Write-Log "✅ Argument 'chcp 65001' présent dans le profil" "SUCCESS"
        } else {
            Write-Log "❌ Argument 'chcp 65001' MANQUANT dans le profil" "ERROR"
            $allTestsPassed = $false
        }
    } else {
        Write-Log "❌ Profil '$profileName' MANQUANT" "ERROR"
        $allTestsPassed = $false
    }

    # Résultat final
    if ($allTestsPassed) {
        Write-Log "Validation terminée avec SUCCÈS. La configuration est conforme." "SUCCESS"
        exit 0
    } else {
        Write-Log "Validation terminée avec des ERREURS. Veuillez corriger la configuration." "ERROR"
        exit 1
    }

} catch {
    Write-Log "Erreur inattendue: $($_.Exception.Message)" "ERROR"
    exit 1
}
<#
.SYNOPSIS
    Teste l'intégration cross-composants de l'encodage UTF-8.
.DESCRIPTION
    Ce script valide que les différents composants (PowerShell, Node.js, Python)
    interagissent correctement en utilisant l'encodage UTF-8.
    Il teste :
    1. Création de fichier avec emojis via PowerShell -> Lecture via Node.js
    2. Exécution de script Python avec emojis -> Capture via PowerShell
.EXAMPLE
    .\Test-CrossComponentIntegration.ps1
.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
    ID Tâche: SDDD-T002c
#>

[CmdletBinding()]
param()

# Configuration
$LogFile = "logs\Test-CrossComponentIntegration-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$TestDir = "temp\cross-component-tests"
$AssetsDir = "tests\integration-assets"

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } default { "Cyan" } })
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

# Initialisation
Write-Log "Début des tests d'intégration cross-composants..." "INFO"

if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

$allTestsPassed = $true

# --- Test 1: PowerShell -> Node.js ---
Write-Log "--- Test 1: PowerShell (Write) -> Node.js (Read) ---" "INFO"
$testFile = Join-Path $TestDir "ps-to-node.txt"
$content = "Test UTF-8: 🚀 Fusée, ✨ Étincelles, é à è"

try {
    # Écriture via PowerShell (UTF-8 par défaut avec nos profils, mais on force pour être sûr du test)
    $content | Out-File -FilePath $testFile -Encoding UTF8
    
    # Lecture via Node.js
    $nodeScript = Join-Path $AssetsDir "read-file.js"
    if (!(Test-Path $nodeScript)) { throw "Script Node.js introuvable: $nodeScript" }
    
    $nodeOutput = node $nodeScript $testFile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Erreur lors de l'exécution de Node.js" "ERROR"
        $allTestsPassed = $false
    } elseif ($nodeOutput.Trim() -eq $content) {
        Write-Log "✅ Node.js a lu correctement le fichier généré par PowerShell" "SUCCESS"
    } else {
        Write-Log "❌ Contenu incorrect lu par Node.js" "ERROR"
        Write-Log "Attendu: $content" "ERROR"
        Write-Log "Reçu   : $($nodeOutput.Trim())" "ERROR"
        $allTestsPassed = $false
    }
} catch {
    Write-Log "Exception Test 1: $($_.Exception.Message)" "ERROR"
    $allTestsPassed = $false
}

# --- Test 2: Python (Print) -> PowerShell (Capture) ---
Write-Log "--- Test 2: Python (Print) -> PowerShell (Capture) ---" "INFO"
$pythonScript = Join-Path $AssetsDir "print-emoji.py"

try {
    if (!(Test-Path $pythonScript)) { throw "Script Python introuvable: $pythonScript" }
    
    # Exécution Python et capture
    # Note: On s'attend à ce que PYTHONUTF8=1 soit défini dans l'environnement
    $pythonOutput = python $pythonScript 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Erreur lors de l'exécution de Python" "ERROR"
        $allTestsPassed = $false
    } else {
        # Vérification des emojis dans la sortie capturée par PowerShell
        $outputString = $pythonOutput -join "`n"
        
        if ($outputString -match "🚀" -and $outputString -match "✅") {
            Write-Log "✅ PowerShell a capturé correctement les emojis de Python" "SUCCESS"
        } else {
            Write-Log "❌ Emojis manquants ou corrompus dans la capture PowerShell" "ERROR"
            Write-Log "Sortie brute: $outputString" "ERROR"
            
            # Diagnostic encodage console
            Write-Log "Console OutputEncoding: $([Console]::OutputEncoding.EncodingName)" "WARN"
            $allTestsPassed = $false
        }
    }
} catch {
    Write-Log "Exception Test 2: $($_.Exception.Message)" "ERROR"
    $allTestsPassed = $false
}

# Nettoyage
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }

# Résultat final
if ($allTestsPassed) {
    Write-Log "Tous les tests d'intégration cross-composants ont réussi." "SUCCESS"
    exit 0
} else {
    Write-Log "Certains tests d'intégration ont échoué." "ERROR"
    exit 1
}
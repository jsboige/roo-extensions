# Script de validation complète pour le serveur jupyter-papermill-mcp-server consolidé
# Mission : Validation critique post-consolidation

param(
    [string]$ServerPath = "D:\dev\roo-extensions\mcps\internal\servers\jupyter-papermill-mcp-server",
    [string]$CondaEnv = "mcp-jupyter-py310",
    [switch]$Verbose
)

# --- Configuration et logging ---
$ErrorActionPreference = "Continue"
$ValidationResults = @()

function Write-ValidationLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    # Ajouter au rapport
    $global:ValidationResults += ,@{
        Timestamp = $timestamp
        Level = $Level
        Message = $Message
    }
}

function Test-PythonImport {
    param([string]$ImportStatement, [string]$Description)
    
    Write-ValidationLog "Test d'import: $Description"
    
    $testScript = @"
try:
    $ImportStatement
    print("SUCCESS: $Description")
except Exception as e:
    print(f"ERROR: {e}")
    exit(1)
"@
    
    $tempFile = New-TemporaryFile
    $testScript | Out-File -FilePath $tempFile.FullName -Encoding UTF8
    
    try {
        & $pythonExe $tempFile.FullName
        if ($LASTEXITCODE -eq 0) {
            Write-ValidationLog "$Description - [REUSSI]" "SUCCESS"
            return $true
        } else {
            Write-ValidationLog "$Description - [ECHEC]" "ERROR"
            return $false
        }
    } finally {
        Remove-Item $tempFile.FullName -ErrorAction SilentlyContinue
    }
}

# --- DÉBUT DE LA VALIDATION ---
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "[VALIDATION CRITIQUE] SERVEUR JUPYTER-PAPERMILL CONSOLIDE" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan

# 1. Vérification de l'environnement
Write-ValidationLog "Vérification de l'environnement conda : $CondaEnv"

$condaPath = "C:\ProgramData\miniconda3\condabin\conda.exe"
$pythonExe = "C:\Users\$env:USERNAME\.conda\envs\$CondaEnv\python.exe"

if (-not (Test-Path $pythonExe)) {
    Write-ValidationLog "Python introuvable dans l'environnement $CondaEnv" "ERROR"
    Write-ValidationLog "Tentative d'activation de l'environnement..."
    & $condaPath activate $CondaEnv
    if (-not (Test-Path $pythonExe)) {
        Write-ValidationLog "Impossible d'activer l'environnement conda" "ERROR"
        exit 1
    }
}

Write-ValidationLog "Python trouvé : $pythonExe" "SUCCESS"

# 2. Vérification du répertoire serveur
if (-not (Test-Path $ServerPath)) {
    Write-ValidationLog "Répertoire serveur introuvable : $ServerPath" "ERROR"
    exit 1
}

Write-ValidationLog "Répertoire serveur validé : $ServerPath" "SUCCESS"
Set-Location $ServerPath

# 3. Tests d'importation critique
Write-ValidationLog "=== PHASE 1: TESTS D'IMPORTATION ===" "INFO"

$importTests = @(
    @{ Import = "from papermill_mcp.main import JupyterPapermillMCPServer"; Description = "Classe principale JupyterPapermillMCPServer" }
    @{ Import = "from papermill_mcp.config import get_config"; Description = "Module de configuration" }
    @{ Import = "from papermill_mcp.tools.notebook_tools import register_notebook_tools"; Description = "Outils notebook" }
    @{ Import = "from papermill_mcp.tools.kernel_tools import register_kernel_tools"; Description = "Outils kernel" }
    @{ Import = "from papermill_mcp.tools.execution_tools import register_execution_tools"; Description = "Outils d'exécution" }
    @{ Import = "from papermill_mcp.core.papermill_executor import PapermillExecutor"; Description = "Exécuteur Papermill" }
    @{ Import = "from papermill_mcp.services.notebook_service import NotebookService"; Description = "Service notebook" }
)

$importSuccessCount = 0
foreach ($test in $importTests) {
    if (Test-PythonImport -ImportStatement $test.Import -Description $test.Description) {
        $importSuccessCount++
    }
}

Write-ValidationLog "Tests d'importation: $importSuccessCount/$($importTests.Count) réussis"

# 4. Test d'initialisation du serveur
Write-ValidationLog "=== PHASE 2: TEST D'INITIALISATION ===" "INFO"

$initScript = @"
try:
    from papermill_mcp.main import JupyterPapermillMCPServer
    from papermill_mcp.config import get_config
    
    print("Chargement de la configuration...")
    config = get_config()
    
    print("Création du serveur consolidé...")
    server = JupyterPapermillMCPServer(config)
    
    print("Initialisation du serveur...")
    server.initialize()
    
    print("SUCCESS: Serveur initialisé avec succès")
    print(f"Nombre d'outils enregistrés: {len(server.app.list_tools())}")
    
    # Liste des outils
    tools = server.app.list_tools()
    print("Outils disponibles:")
    for tool in tools:
        print(f"  - {tool.name}")
        
except Exception as e:
    print(f"ERROR: Échec d'initialisation - {e}")
    import traceback
    traceback.print_exc()
    exit(1)
"@

$tempFile = New-TemporaryFile
$initScript | Out-File -FilePath $tempFile.FullName -Encoding UTF8

Write-ValidationLog "Exécution du test d'initialisation..."
try {
    $initOutput = & $pythonExe $tempFile.FullName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ValidationLog "Initialisation du serveur - [REUSSI]" "SUCCESS"
        Write-ValidationLog "Sortie d'initialisation:" "INFO"
        $initOutput | ForEach-Object { Write-ValidationLog "  $_" "INFO" }
    } else {
        Write-ValidationLog "Initialisation du serveur - [ECHEC]" "ERROR"
        $initOutput | ForEach-Object { Write-ValidationLog "  $_" "ERROR" }
    }
} finally {
    Remove-Item $tempFile.FullName -ErrorAction SilentlyContinue
}

# 5. Test des dépendances critiques
Write-ValidationLog "=== PHASE 3: VALIDATION DES DÉPENDANCES ===" "INFO"

$depTests = @(
    "import papermill; print(f'Papermill: {papermill.__version__}')",
    "import nbformat; print(f'nbformat: {nbformat.__version__}')",
    "import jupyter_client; print(f'jupyter_client: {jupyter_client.__version__}')",
    "import fastmcp; print(f'FastMCP: {fastmcp.__version__}')"
)

foreach ($dep in $depTests) {
    Test-PythonImport -ImportStatement $dep -Description "Dépendance: $dep"
}

# 6. Test de script de consolidation existant
Write-ValidationLog "=== PHASE 4: EXÉCUTION DU SCRIPT DE CONSOLIDATION ===" "INFO"

if (Test-Path "test_consolidation.py") {
    Write-ValidationLog "Exécution de test_consolidation.py..."
    try {
        $consolidationOutput = & $pythonExe "test_consolidation.py" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ValidationLog "test_consolidation.py - [REUSSI]" "SUCCESS"
            $consolidationOutput | ForEach-Object { Write-ValidationLog "  $_" "INFO" }
        } else {
            Write-ValidationLog "test_consolidation.py - [ECHEC]" "ERROR"
            $consolidationOutput | ForEach-Object { Write-ValidationLog "  $_" "ERROR" }
        }
    } catch {
        Write-ValidationLog "Erreur lors de l'exécution de test_consolidation.py: $($_.Exception.Message)" "ERROR"
    }
} else {
    Write-ValidationLog "test_consolidation.py non trouvé" "WARNING"
}

# 7. Génération du rapport final
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "[RAPPORT] VALIDATION FINAL" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan

$successCount = ($ValidationResults | Where-Object { $_.Level -eq "SUCCESS" }).Count
$errorCount = ($ValidationResults | Where-Object { $_.Level -eq "ERROR" }).Count
$warningCount = ($ValidationResults | Where-Object { $_.Level -eq "WARNING" }).Count

Write-Host "[SUCCESS] Succes: $successCount" -ForegroundColor Green
Write-Host "[ERROR] Erreurs: $errorCount" -ForegroundColor Red
Write-Host "[WARNING] Avertissements: $warningCount" -ForegroundColor Yellow

# Écriture du rapport détaillé
$reportPath = "validation_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$ValidationResults | ForEach-Object { "[$($_.Timestamp)] [$($_.Level)] $($_.Message)" } | Out-File -FilePath $reportPath

Write-ValidationLog "Rapport détaillé sauvegardé: $reportPath" "INFO"

# Conclusion
if ($errorCount -eq 0) {
    Write-Host "[SUCCESS] VALIDATION REUSSIE - Serveur consolide operationnel" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[ERROR] VALIDATION ECHOUE - $errorCount erreur(s) detectee(s)" -ForegroundColor Red
    exit 1
}
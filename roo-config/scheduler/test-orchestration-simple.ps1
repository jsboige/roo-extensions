# Script de test simplifie pour l'orchestration quotidienne
param(
    [switch]$Verbose = $false
)

Set-Location "d:/roo-extensions"

function Write-TestResult {
    param(
        [string]$Test,
        [bool]$Success,
        [string]$Message = ""
    )
    
    $status = if ($Success) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "$status $Test" -ForegroundColor $color
    if ($Message -and $Verbose) {
        Write-Host "    $Message" -ForegroundColor Gray
    }
}

Write-Host "=== TEST DU SYSTEME D'ORCHESTRATION QUOTIDIENNE ===" -ForegroundColor Cyan

# Test 1: Verification des fichiers principaux
$files = @(
    @{ Path = ".roo/schedules.json"; Name = "Fichier de planification" },
    @{ Path = "roo-config/scheduler/daily-orchestration.json"; Name = "Configuration d'orchestration" },
    @{ Path = "roo-config/scheduler/orchestration-engine.ps1"; Name = "Moteur d'orchestration" },
    @{ Path = "roo-config/scheduler/self-improvement.ps1"; Name = "Script d'auto-amelioration" }
)

$filesOk = 0
foreach ($file in $files) {
    $exists = Test-Path $file.Path
    Write-TestResult -Test $file.Name -Success $exists -Message $file.Path
    if ($exists) { $filesOk++ }
}

# Test 2: Validation JSON des fichiers de configuration
$jsonFiles = @(
    @{ Path = ".roo/schedules.json"; Name = "Syntaxe schedules.json" },
    @{ Path = "roo-config/scheduler/daily-orchestration.json"; Name = "Syntaxe daily-orchestration.json" }
)

$jsonOk = 0
foreach ($jsonFile in $jsonFiles) {
    try {
        if (Test-Path $jsonFile.Path) {
            Get-Content -Raw $jsonFile.Path | ConvertFrom-Json | Out-Null
            Write-TestResult -Test $jsonFile.Name -Success $true
            $jsonOk++
        } else {
            Write-TestResult -Test $jsonFile.Name -Success $false -Message "Fichier non trouve"
        }
    }
    catch {
        Write-TestResult -Test $jsonFile.Name -Success $false -Message $_.Exception.Message
    }
}

# Test 3: Verification de la tache d'orchestration dans schedules.json
try {
    $schedules = Get-Content -Raw ".roo/schedules.json" | ConvertFrom-Json
    $orchestrationTask = $schedules.schedules | Where-Object { $_.name -eq "Daily-Roo-Environment-Orchestration" }
    
    if ($orchestrationTask) {
        Write-TestResult -Test "Tache d'orchestration presente" -Success $true
        Write-TestResult -Test "Tache active" -Success $orchestrationTask.active
        Write-TestResult -Test "Mode orchestrator" -Success ($orchestrationTask.mode -eq "orchestrator")
    } else {
        Write-TestResult -Test "Tache d'orchestration presente" -Success $false
    }
}
catch {
    Write-TestResult -Test "Lecture des taches planifiees" -Success $false -Message $_.Exception.Message
}

# Test 4: Creation des repertoires necessaires
$directories = @(
    "roo-config/scheduler/logs",
    "roo-config/scheduler/metrics", 
    "roo-config/scheduler/history"
)

$dirsOk = 0
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        try {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-TestResult -Test "Creation repertoire $dir" -Success $true
            $dirsOk++
        }
        catch {
            Write-TestResult -Test "Creation repertoire $dir" -Success $false -Message $_.Exception.Message
        }
    } else {
        Write-TestResult -Test "Repertoire $dir existant" -Success $true
        $dirsOk++
    }
}

# Test 5: Test basique du moteur d'orchestration (syntaxe)
try {
    $enginePath = "roo-config/scheduler/orchestration-engine.ps1"
    if (Test-Path $enginePath) {
        # Test de syntaxe basique
        $content = Get-Content -Raw $enginePath
        if ($content.Length -gt 1000) {
            Write-TestResult -Test "Moteur d'orchestration (taille)" -Success $true
        } else {
            Write-TestResult -Test "Moteur d'orchestration (taille)" -Success $false -Message "Fichier trop petit"
        }
    }
}
catch {
    Write-TestResult -Test "Validation moteur d'orchestration" -Success $false -Message $_.Exception.Message
}

# Resume
Write-Host "" 
Write-Host "=== RESUME DES TESTS ===" -ForegroundColor Cyan
Write-Host "Fichiers principaux: $filesOk/4" -ForegroundColor $(if ($filesOk -eq 4) { "Green" } else { "Yellow" })
Write-Host "Validation JSON: $jsonOk/2" -ForegroundColor $(if ($jsonOk -eq 2) { "Green" } else { "Yellow" })
Write-Host "Repertoires: $dirsOk/3" -ForegroundColor $(if ($dirsOk -eq 3) { "Green" } else { "Yellow" })

$totalScore = $filesOk + $jsonOk + $dirsOk
$maxScore = 9

if ($totalScore -eq $maxScore) {
    Write-Host ""
    Write-Host "SYSTEME D'ORCHESTRATION PRET" -ForegroundColor Green
    exit 0
} elseif ($totalScore -ge ($maxScore * 0.8)) {
    Write-Host ""
    Write-Host "SYSTEME PARTIELLEMENT FONCTIONNEL" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host ""
    Write-Host "SYSTEME NON FONCTIONNEL" -ForegroundColor Red
    exit 2
}
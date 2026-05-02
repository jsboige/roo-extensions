<#
.SYNOPSIS
    Idle Patrol Script for Roo Scheduler - Active Veille pendant les periodes idle.
.DESCRIPTION
    Implémente l'Étape 2c-style patrol du scheduler Roo (recommendation #1886).
    Pendant les periodes idle, execute des checks proactifs pour detecter les
    regressions silencieuses avant qu'elles ne se propagent.
    
    Actions patrol (ordre de priorite):
    1. Scan tests vitest → si echec, ouvrir issue
    2. Check git status uncommitted files → si >7 jours, signaler
    3. Grep dead imports (exports jamais importes)
    4. Verifier .roo/schedules.json sync avec sources
    
    Limite: Max 1 patrol/heure (eviter spam).
.EXAMPLE
    .\scripts\maintenance\roo-idle-patrol.ps1
.EXAMPLE
    .\scripts\maintenance\roo-idle-patrol.ps1 -FullScan
#>

param(
    [switch]$FullScan,
    [string]$Workspace,
    [int]$MaxAgeDays = 7,
    [string]$DashboardTag = "PATROL"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Configuration ---
$PatrolStateFile = Join-Path $env:TEMP "roo-idle-patrol-last-run.json"
$PatrolIntervalMinutes = 60  # Max 1 patrol/heure

if (-not $Workspace) {
    $Workspace = Join-Path $PSScriptRoot ".."
}
$RepoRoot = (Get-Item $Workspace).Parent.FullName
$InternalMcpPath = Join-Path $RepoRoot "mcps\internal\servers\roo-state-manager"

# --- Fonctions utilitaires ---

function Write-PatrolLog {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Test-PatrolCooldown {
    if (Test-Path $PatrolStateFile) {
        $lastRun = Get-Content $PatrolStateFile | ConvertFrom-Json
        $lastTime = [DateTimeOffset]::Parse($lastRun.lastRun).UtcDateTime
        $elapsed = (Get-Date -Utc) - $lastTime
        if ($elapsed.TotalMinutes -lt $PatrolIntervalMinutes) {
            Write-PatrolLog "SKIP" "Patrol ignore: dernier run il y a $($elapsed.TotalMinutes.ToString('0.0')) min (seuil: $PatrolIntervalMinutes min)"
            return $false
        }
    }
    return $true
}

function Update-PatrolState {
    $utcNow = [DateTimeOffset]::UtcNow.ToString("o")
    @{ lastRun = $utcNow } | ConvertTo-Json | Set-Content $PatrolStateFile -Encoding UTF8
}

# --- Check 1: Build + Tests vitest ---

function Invoke-BuildAndTestScan {
    Write-PatrolLog "INFO" "Check 1: Build + Scan tests vitest..."
    
    if (-not (Test-Path $InternalMcpPath)) {
        Write-PatrolLog "WARN" "Repertoire mcps/internal non trouve, skip build+tests"
        return @{ status = "skipped"; reason = "mcps/internal not found" }
    }
    
    try {
        Push-Location $InternalMcpPath
        
        # Etape 1a: Build
        Write-PatrolLog "INFO" "  1a: npm run build..."
        $buildOutput = npm run build 2>&1 | Select-Object -Last 20
        $buildExit = $LASTEXITCODE
        
        if ($buildExit -ne 0) {
            Write-PatrolLog "ERROR" "Build echoue (exit $buildExit)"
            $buildStr = if ($buildOutput) { $buildOutput -join "`n" } else { "no output" }
            return @{ status = "build_failed"; exitCode = $buildExit; output = $buildStr }
        }
        Write-PatrolLog "INFO" "  1a: Build OK"
        
        # Etape 1b: Tests
        Write-PatrolLog "INFO" "  1b: npx vitest run..."
        $env:CI = "true"
        $output = npx vitest run 2>&1 | Select-Object -Last 50
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -ne 0) {
            Write-PatrolLog "ERROR" "Tests vitest echoues (exit $exitCode)"
            $outputStr = if ($output) { $output -join "`n" } else { "no output" }
            Write-PatrolLog "ERROR" "Output: $outputStr"
            return @{ status = "failed"; exitCode = $exitCode; output = $outputStr }
        }
        
        Write-PatrolLog "INFO" "Check 1: Build + Tests PASS"
        return @{ status = "passed" }
    }
    catch {
        Write-PatrolLog "ERROR" "Erreur execution build+tests: $_"
        return @{ status = "error"; message = $_.Exception.Message }
    }
    finally {
        $env:CI = $null
        Pop-Location
    }
}

# --- Check 2: Git status uncommitted files ---

function Invoke-GitStatusCheck {
    Write-PatrolLog "INFO" "Check 2: Check git status uncommitted files (seuil: $MaxAgeDays jours)..."
    
    try {
        $statusOutput = git -C $RepoRoot status --porcelain 2>&1
        $stagedFiles = git -C $RepoRoot diff --cached --name-only 2>&1
        $unstagedFiles = git -C $RepoRoot diff --name-only 2>&1
        
        $allFiles = @()
        if ($stagedFiles) { $allFiles += $stagedFiles -split "`n" | Where-Object { $_ } }
        if ($unstagedFiles) { $allFiles += $unstagedFiles -split "`n" | Where-Object { $_ } }
        
        $fileCount = 0
        if ($allFiles) { $fileCount = $allFiles.Count }
        
        if ($fileCount -eq 0) {
            Write-PatrolLog "INFO" "Git status: propre (aucun fichier modifie)"
            return @{ status = "clean"; modifiedFiles = 0 }
        }
        
        # Calculer l'age des fichiers modifies
        $oldFiles = @()
        foreach ($file in $allFiles) {
            $fullPath = Join-Path $RepoRoot $file
            if (Test-Path $fullPath) {
                $age = (Get-Item $fullPath).LastWriteTime
                $daysOld = ((Get-Date) - $age).Days
                if ($daysOld -gt $MaxAgeDays) {
                    $oldFiles += @{ file = $file; daysOld = $daysOld }
                }
            }
        }
        
        $oldCount = 0
        if ($oldFiles) { $oldCount = $oldFiles.Count }
        
        if ($oldCount -gt 0) {
            Write-PatrolLog "WARN" "Fichiers modifies anciens (>${MaxAgeDays} jours):"
            foreach ($f in $oldFiles) {
                Write-PatrolLog "WARN" "  - $($f.file) ( $($f.daysOld) jours)"
            }
            return @{ status = "old_uncommitted"; modifiedFiles = $fileCount; oldFiles = $oldFiles }
        }
        
        Write-PatrolLog "INFO" "Git status: $fileCount fichiers modifies (tous < $MaxAgeDays jours)"
        return @{ status = "recent_uncommitted"; modifiedFiles = $fileCount }
    }
    catch {
        Write-PatrolLog "ERROR" "Erreur git status: $_"
        return @{ status = "error"; message = $_.Exception.Message }
    }
}

# --- Check 3: Dead imports detection ---

function Invoke-DeadImportScan {
    Write-PatrolLog "INFO" "Check 3: Scan dead imports (exports jamais importes)..."
    
    if (-not $FullScan) {
        Write-PatrolLog "INFO" "Scan complet non demande (-FullScan), skip dead imports"
        return @{ status = "skipped"; reason = "not full scan" }
    }
    
    try {
        $deadImports = @()
        
        # Chercher les exports dans les fichiers .ts du service roo-state-manager
        $srcPath = Join-Path $InternalMcpPath "src"
        if (Test-Path $srcPath) {
            # Trouver les exports barrel (index.ts)
            $barrelFiles = Get-ChildItem -Path $srcPath -Recurse -Filter "index.ts" | Where-Object { $_.FullName -notlike "*node_modules*" }
            
            foreach ($barrel in $barrelFiles) {
                $content = Get-Content $barrel.FullName -Raw
                # Extraire les noms exportes
                $exports = [regex]::Matches($content, 'export\s+(?:default\s+)?(?:class|function|const|interface|type|enum|let|var)\s+(\w+)') | ForEach-Object { $_.Groups[1].Value }
                
                foreach ($export in $exports) {
                    # Chercher si ce nom est importe ailleurs (Get-ChildItem requis, Select-String n'accepte pas les repertoires)
                    $tsFiles = Get-ChildItem -Path $srcPath -Recurse -Filter "*.ts" | Where-Object { $_.FullName -notlike "*node_modules*" -and $_.FullName -ne $barrel.FullName }
                    $importCount = ($tsFiles | Select-String -Pattern "\b$([regex]::Escape($export))\b" -ErrorAction SilentlyContinue | Measure-Object).Count
                    if ($importCount -eq 0) {
                        $deadImports += @{ name = $export; file = $barrel.FullName; barrel = $barrel.Name }
                    }
                }
            }
        }
        
        if ($deadImports.Count -gt 0) {
            Write-PatrolLog "WARN" "Dead imports potentiels detects:"
            foreach ($d in $deadImports) {
                Write-PatrolLog "WARN" "  - $($d.name) dans $($d.barrel)"
            }
            return @{ status = "dead_imports_found"; count = $deadImports.Count; items = $deadImports }
        }
        
        Write-PatrolLog "INFO" "Dead imports scan: aucun dead import detecte"
        return @{ status = "clean"; count = 0 }
    }
    catch {
        Write-PatrolLog "ERROR" "Erreur dead import scan: $_"
        return @{ status = "error"; message = $_.Exception.Message }
    }
}

# --- Check 4: Schedules sync verification ---

function Invoke-ScheduleSyncCheck {
    Write-PatrolLog "INFO" "Check 4: Verification sync .roo/schedules.json..."
    
    $schedulesFile = Join-Path $RepoRoot ".roo\schedules.json"
    if (-not (Test-Path $schedulesFile)) {
        Write-PatrolLog "WARN" "Fichier .roo/schedules.json non trouve, skip"
        return @{ status = "skipped"; reason = "schedules.json not found" }
    }
    
    try {
        $schedulesContent = Get-Content $schedulesFile -Raw | ConvertFrom-Json
        
        if (-not $schedulesContent.schedules) {
            Write-PatrolLog "WARN" "schedules.json: pas de propriete 'schedules'"
            return @{ status = "invalid_format" }
        }
        
        $activeSchedules = $schedulesContent.schedules | Where-Object { $_.active }
        $inactiveSchedules = $schedulesContent.schedules | Where-Object { -not $_.active }
        
        Write-PatrolLog "INFO" "Schedules: $($activeSchedules.Count) actifs, $($inactiveSchedules.Count) inactifs"
        
        # Verifier les schedules sans nextExecutionTime
        $missingNextExec = $activeSchedules | Where-Object { -not $_.nextExecutionTime }
        $missingCount = 0
        if ($missingNextExec) { $missingCount = ($missingNextExec | Measure-Object).Count }
        
        if ($missingCount -gt 0) {
            Write-PatrolLog "WARN" "Schedules actifs sans nextExecutionTime:"
            foreach ($s in $missingNextExec) {
                Write-PatrolLog "WARN" "  - $($s.name) (id: $($s.id))"
            }
            $activeCount = 0; if ($activeSchedules) { $activeCount = ($activeSchedules | Measure-Object).Count }
            $inactiveCount = 0; if ($inactiveSchedules) { $inactiveCount = ($inactiveSchedules | Measure-Object).Count }
            return @{ status = "missing_next_execution"; active = $activeCount; inactive = $inactiveCount; missingNextExec = $missingCount }
        }
        
        # Verifier les schedules avec lastExecutionTime > 2x intervalle
        $staleSchedules = @()
        $utcNow = [DateTimeOffset]::UtcNow
        foreach ($s in $activeSchedules) {
            if ($s.lastExecutionTime -and $s.timeInterval) {
                try {
                    $lastExec = [DateTimeOffset]::Parse($s.lastExecutionTime).UtcDateTime
                    $expectedNext = $lastExec.AddMinutes($s.timeInterval)
                    if ($utcNow.DateTime -gt $expectedNext.AddHours(2)) {
                        $staleSchedules += @{ name = $s.name; lastExec = $s.lastExecutionTime; interval = $s.timeInterval }
                    }
                }
                catch {
                    Write-PatrolLog "WARN" "Impossible de parser lastExecutionTime pour $($s.name): $_"
                }
            }
        }
        
        $staleCount = 0
        if ($staleSchedules) { $staleCount = ($staleSchedules | Measure-Object).Count }
        
        if ($staleCount -gt 0) {
            Write-PatrolLog "WARN" "Schedules potentiellement inactifs (dernier run > 2x intervalle):"
            foreach ($s in $staleSchedules) {
                Write-PatrolLog "WARN" "  - $($s.name) (last: $($s.lastExec), interval: $($s.interval)min)"
            }
            $activeCount = 0; if ($activeSchedules) { $activeCount = ($activeSchedules | Measure-Object).Count }
            $inactiveCount = 0; if ($inactiveSchedules) { $inactiveCount = ($inactiveSchedules | Measure-Object).Count }
            return @{ status = "stale_schedules"; active = $activeCount; inactive = $inactiveCount; stale = $staleCount; items = $staleSchedules }
        }
        
        Write-PatrolLog "INFO" "Schedules sync: OK (tous les schedules actifs ont une nextExecutionTime)"
        $activeCount = 0; if ($activeSchedules) { $activeCount = ($activeSchedules | Measure-Object).Count }
        $inactiveCount = 0; if ($inactiveSchedules) { $inactiveCount = ($inactiveSchedules | Measure-Object).Count }
        return @{ status = "sync_ok"; active = $activeCount; inactive = $inactiveCount }
    }
    catch {
        Write-PatrolLog "ERROR" "Erreur verification schedules: $_"
        return @{ status = "error"; message = $_.Exception.Message }
    }
}

# --- Rapport final ---

function New-PatrolReport {
    param(
        [object]$VitessResult,
        [object]$GitResult,
        [object]$DeadImportsResult,
        [object]$ScheduleResult
    )
    
    # Helper pour valeurs par defaut
    function Get-OrDefault {
        param([object]$Obj, [string]$Prop, [string]$Default = "")
        if ($null -eq $Obj) { return $Default }
        try {
            $val = $Obj.$Prop
            if ($null -eq $val) { return $Default }
            return $val
        }
        catch { return $Default }
    }
    
    $vitessReason = Get-OrDefault $VitessResult "reason" ""
    if (-not $vitessReason) { $vitessReason = Get-OrDefault $VitessResult "output" "" }
    if (-not $vitessReason) { $vitessReason = "no details" }
    
    $gitFiles = Get-OrDefault $GitResult "modifiedFiles" "0"
    if (-not $gitFiles) { $gitFiles = "0" }
    
    $deadCount = Get-OrDefault $DeadImportsResult "count" "0"
    if (-not $deadCount) { $deadCount = "0" }
    
    $schedActive = Get-OrDefault $ScheduleResult "active" "0"
    $schedInactive = Get-OrDefault $ScheduleResult "inactive" "0"
    if (-not $schedActive) { $schedActive = "0" }
    if (-not $schedInactive) { $schedInactive = "0" }
    
    $report = @"
## [PATROL] Rapport de veille active - myia-po-2025
**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm UTC")
**Machine:** myia-po-2025
**Scan:** $($FullScan.ToString().ToUpper())

### Resume

| Check | Statut | Details |
|-------|--------|---------|
| Tests vitest | $($VitessResult.status) | $vitessReason |
| Git status | $($GitResult.status) | $gitFiles fichiers modifies |
| Dead imports | $($DeadImportsResult.status) | $deadCount dead imports |
| Schedules sync | $($ScheduleResult.status) | $schedActive actifs, $schedInactive inactifs |

### Actions recommande

"@
    
    $actions = @()
    if ($VitessResult.status -eq "build_failed") {
        $actions += "- **URGENT**: Build echoue -> ouvrir issue GitHub"
    }
    if ($VitessResult.status -eq "failed") {
        $actions += "- **URGENT**: Tests vitest echoues -> ouvrir issue GitHub"
    }
    if ($GitResult.status -eq "old_uncommitted") {
        $actions += "- **WARN**: Fichiers modifies anciens -> signaler sur dashboard"
    }
    if ($DeadImportsResult.status -eq "dead_imports_found") {
        $actions += "- **INFO**: Dead imports detects -> nettoyer barrel exports"
    }
    if ($ScheduleResult.status -eq "stale_schedules") {
        $actions += "- **WARN**: Schedules inactifs -> verifier scheduler VS Code"
    }
    
    if ($actions.Count -eq 0) {
        $report += "Aucune action requise. Tous les checks sont verts."
    } else {
        $report += $actions -join "`n"
    }
    
    return $report
}

# --- Execution principale ---

Write-PatrolLog "INFO" "=== Idle Patrol Roo - Demarrage ==="
Write-PatrolLog "INFO" "Workspace: $RepoRoot"
Write-PatrolLog "INFO" "Mode: $($FullScan.ToString().ToUpper())"

# Verifier cooldown
if (-not (Test-PatrolCooldown)) {
    Write-PatrolLog "INFO" "Patrol termine (cooldown actif)"
    exit 0
}

# Executer les checks
$vitessResult = Invoke-BuildAndTestScan
$gitResult = Invoke-GitStatusCheck
$deadImportsResult = Invoke-DeadImportScan
$scheduleResult = Invoke-ScheduleSyncCheck

# Mettre a jour l'etat
Update-PatrolState

# Generer rapport
$report = New-PatrolReport $vitessResult $gitResult $deadImportsResult $scheduleResult

Write-PatrolLog "INFO" "=== Rapport Patrol ==="
Write-Host $report

Write-PatrolLog "INFO" "=== Idle Patrol Roo - Termine ==="

# Retourner le code de sortie
if ($vitessResult.status -in @("failed", "build_failed") -or $gitResult.status -eq "old_uncommitted") {
    exit 1
}
exit 0

<#
.SYNOPSIS
    Déploie les tâches Windows Task Scheduler pour Claude Worker sur toutes les machines exécutrices.

.DESCRIPTION
    Ce script déploie les tâches worker et meta-audit sur les machines :
    - myia-po-2023
    - myia-po-2024
    - myia-po-2025
    - myia-po-2026
    - myia-web1

    Prérequis :
    - Les connexions SSH doivent être configurées dans win_cli_config.json
    - Les machines doivent avoir claude CLI installé
    - Les machines doivent avoir gh CLI authentifié avec scope project
    - Le repo roo-extensions doit être cloné et à jour

.PARAMETER Machines
    Liste des machines cibles (défaut: toutes les machines exécutrices)

.PARAMETER TaskTypes
    Types de tâches à déployer: worker, meta-audit, ou all (défaut: all)

.PARAMETER DryRun
    Mode simulation sans exécution réelle

.EXAMPLE
    .\deploy-schedulers.ps1
    Déploie worker et meta-audit sur toutes les machines

.EXAMPLE
    .\deploy-schedulers.ps1 -Machines myia-po-2023,myia-po-2024 -TaskTypes worker
    Déploie uniquement worker sur myia-po-2023 et myia-po-2024

.EXAMPLE
    .\deploy-schedulers.ps1 -DryRun
    Simule le déploiement sans exécuter
#>

param(
    [string[]]$Machines = @('myia-po-2023', 'myia-po-2024', 'myia-po-2025', 'myia-po-2026', 'myia-web1'),
    [ValidateSet('worker', 'meta-audit', 'all')]
    [string]$TaskTypes = 'all',
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- Config ---
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$setupScript = Join-Path $scriptDir "setup-scheduler.ps1"

# --- Fonctions ---
function Test-SSHConnection {
    param([string]$Machine)
    
    Write-Host "Test connexion SSH vers $Machine..." -ForegroundColor Cyan
    
    try {
        $result = ssh jsboi@$Machine.local "hostname" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Connexion SSH OK vers $Machine" -ForegroundColor Green
            return $true
        } else {
            Write-Host "✗ Connexion SSH échouée vers $Machine" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "✗ Erreur de connexion SSH vers ${Machine}: ${_}" -ForegroundColor Red
        return $false
    }
}

function Deploy-Task {
    param(
        [string]$Machine,
        [string]$TaskType
    )
    
    Write-Host "`nDéploiement $TaskType sur $Machine..." -ForegroundColor Cyan
    
    $command = "cd D:\\Dev\\roo-extensions ; git pull ; powershell -ExecutionPolicy Bypass -File scripts\\scheduling\\setup-scheduler.ps1 -Action install -TaskType $TaskType"
    
    if ($DryRun) {
        Write-Host "[DRYRUN] Exécuterait sur ${Machine}:" -ForegroundColor Yellow
        Write-Host "  $command"
        return $true
    }
    
    try {
        $output = ssh jsboi@$Machine.local $command 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ $TaskType installé sur $Machine" -ForegroundColor Green
            return $true
        } else {
            Write-Host "✗ Erreur installation ${TaskType} sur ${Machine}:" -ForegroundColor Red
            Write-Host $output
            return $false
        }
    } catch {
        Write-Host "✗ Erreur déploiement ${TaskType} sur ${Machine}: ${_}" -ForegroundColor Red
        return $false
    }
}

function Verify-Task {
    param(
        [string]$Machine,
        [string]$TaskType
    )
    
    Write-Host "`nVérification $TaskType sur $Machine..." -ForegroundColor Cyan
    
    $command = "cd D:\\Dev\\roo-extensions ; powershell -ExecutionPolicy Bypass -File scripts\\scheduling\\setup-scheduler.ps1 -Action list -TaskType $TaskType"
    
    if ($DryRun) {
        Write-Host "[DRYRUN] Vérifierait sur ${Machine}:" -ForegroundColor Yellow
        Write-Host "  $command"
        return $true
    }
    
    try {
        $output = ssh jsboi@$Machine.local $command 2>&1
        Write-Host $output
        return $LASTEXITCODE -eq 0
    } catch {
        Write-Host "✗ Erreur vérification ${TaskType} sur ${Machine}: ${_}" -ForegroundColor Red
        return $false
    }
}

# --- Main ---
Write-Host "`n=== Déploiement des schedulers Claude Worker ===" -ForegroundColor Magenta
Write-Host "Machines cibles: $($Machines -join ', ')" -ForegroundColor White
Write-Host "Types de tâches: $TaskTypes" -ForegroundColor White
if ($DryRun) {
    Write-Host "MODE: DRYRUN (pas d'exécution réelle)" -ForegroundColor Yellow
}
Write-Host ""

# Déterminer les types de tâches à déployer
$taskTypesToDeploy = @()
if ($TaskTypes -eq 'all') {
    $taskTypesToDeploy = @('worker', 'meta-audit')
} else {
    $taskTypesToDeploy = @($TaskTypes)
}

# Résultats
$results = @()

foreach ($machine in $Machines) {
    Write-Host "`n--- Machine: $machine ---" -ForegroundColor Magenta
    
    # Test connexion SSH
    if (-not (Test-SSHConnection -Machine $machine)) {
        $results += [PSCustomObject]@{
            Machine = $machine
            Worker = "FAIL (SSH)"
            MetaAudit = "FAIL (SSH)"
        }
        continue
    }
    
    # Déploiement des tâches
    $workerResult = "N/A"
    $metaAuditResult = "N/A"
    
    foreach ($taskType in $taskTypesToDeploy) {
        if (Deploy-Task -Machine $machine -TaskType $taskType) {
            if (Verify-Task -Machine $machine -TaskType $taskType) {
                if ($taskType -eq 'worker') {
                    $workerResult = "PASS"
                } else {
                    $metaAuditResult = "PASS"
                }
            } else {
                if ($taskType -eq 'worker') {
                    $workerResult = "FAIL (Verify)"
                } else {
                    $metaAuditResult = "FAIL (Verify)"
                }
            }
        } else {
            if ($taskType -eq 'worker') {
                $workerResult = "FAIL (Deploy)"
            } else {
                $metaAuditResult = "FAIL (Deploy)"
            }
        }
    }
    
    $results += [PSCustomObject]@{
        Machine = $machine
        Worker = $workerResult
        MetaAudit = $metaAuditResult
    }
}

# --- Rapport ---
Write-Host "`n=== Rapport de déploiement ===" -ForegroundColor Magenta
$results | Format-Table -AutoSize

# Compter les succès
$workerSuccess = ($results | Where-Object { $_.Worker -eq 'PASS' }).Count
$metaAuditSuccess = ($results | Where-Object { $_.MetaAudit -eq 'PASS' }).Count
$totalMachines = $Machines.Count

Write-Host "`nRésumé:" -ForegroundColor Cyan
Write-Host "  Worker: $workerSuccess/$totalMachines machines" -ForegroundColor $(if ($workerSuccess -eq $totalMachines) { 'Green' } else { 'Yellow' })
Write-Host "  Meta-Audit: $metaAuditSuccess/$totalMachines machines" -ForegroundColor $(if ($metaAuditSuccess -eq $totalMachines) { 'Green' } else { 'Yellow' })

if ($DryRun) {
    Write-Host "`n[DRYRUN] Aucune modification effectuée" -ForegroundColor Yellow
} else {
    if ($workerSuccess -eq $totalMachines -and $metaAuditSuccess -eq $totalMachines) {
        Write-Host "`n✓ Déploiement terminé avec succès sur toutes les machines" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n✗ Déploiement terminé avec des erreurs" -ForegroundColor Red
        exit 1
    }
}

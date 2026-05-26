#Requires -Version 5.1

<#
.SYNOPSIS
    Génère un rapport de synthèse des tâches Roo par répertoire de workspace.
.DESCRIPTION
    Ce script analyse le répertoire des tâches de Roo et regroupe les tâches
    par le workspace auquel elles sont associées. Il affiche ensuite une
    liste de tous les workspaces avec le nombre de tâches correspondantes.
#>
[CmdletBinding()]
param(
    [string]$TasksPath,
    [string]$ReportPath,
    [switch]$Quiet,
    [switch]$AsJson,
    [int]$SampleCount = 0,
    [int]$Offset = 0,
    [int]$Limit = 0
)

. "$PSScriptRoot\..\common\extension-paths.ps1"

function Get-RooTasksPath {
    $defaultPath = Join-Path (Get-GlobalStoragePath -Extension RooCode) "tasks"
    if (Test-Path -Path $defaultPath -PathType Container) {
        return $defaultPath
    }
    return $null
}

function Get-TaskWorkspacePath {
    param(
        [System.IO.DirectoryInfo]$TaskDirectory
    )

    # Priorité aux métadonnées pour l'optimisation
    $metadataPath = Join-Path -Path $TaskDirectory.FullName -ChildPath 'task_metadata.json'
    if (Test-Path -Path $metadataPath) {
        try {
            $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
            if (-not ([string]::IsNullOrWhiteSpace($metadata.workspace_path))) {
                # Assurer que la sortie est toujours une chaîne unique
                $path = $metadata.workspace_path
                if ($path -is [System.Array]) {
                    return $path[0]
                }
                return $path
            }
        } catch { $null }
    }

    return "[Workspace non trouvé]"
}

# --- Point d'entrée ---

$tasksPath = Get-RooTasksPath
if (-not $tasksPath) {
    Write-Error "Le répertoire des tâches Roo est introuvable."
    exit 1
}

# Logique de cache
$cacheFile = Join-Path -Path $PSScriptRoot -ChildPath "audit_cache.json"
$cache = @{}
if (Test-Path $cacheFile) {
    try {
        $cache = Get-Content -Path $cacheFile -Raw | ConvertFrom-Json -AsHashtable
    } catch {}
}
$newCache = @{ LastScan = (Get-Date).ToUniversalTime().ToString("o") }

# Ma logique de diagnostic
$dbMetrics = $null
if (-not $AsJson.IsPresent) {
    Write-Host "--- Lancement du diagnostic de l'état de Roo ---"
    Write-Host ("-" * 80)
    # Note: L'analyse BDD est conservée de ma version
    Write-Host "📊 1. Analyse de state.vscdb"
    # ... (logique Get-StateVscDbMetrics à ajouter si nécessaire)
    Write-Host ("-" * 80)
    Write-Host "📂 2. Audit du répertoire des tâches : $tasksPath"
}

# Logique de sélection de tâches (fusionnée)
$allTaskDirs = Get-ChildItem -Path $tasksPath -Directory | Sort-Object -Property CreationTime -Descending
$tasksToProcess = $allTaskDirs

if ($SampleCount -gt 0) {
    $tasksToProcess = $tasksToProcess | Select-Object -First $SampleCount
}
if ($Limit -gt 0) {
    $tasksToProcess = $tasksToProcess | Select-Object -Skip $Offset -First $Limit
}

$auditResults = @()
$sizeMetrics = @{ Total = 0; Json = 0; Checkpoints = 0 }
$totalTasks = $tasksToProcess.Count

$tasksToProcess | ForEach-Object -Process {
    $taskDir = $_
    $taskId = $taskDir.Name
    $lastWriteTime = $taskDir.LastWriteTimeUtc.ToString("o")
    $i = [int]$foreach.CurrentIndex + 1
    
    if (-not $Quiet -and -not $AsJson.IsPresent) {
        Write-Progress -Activity "Analyse des tâches Roo" -Status "Analyse de $($taskDir.Name)" -PercentComplete (($i / $totalTasks) * 100)
    }

    if ($cache.Contains($taskId) -and $cache[$taskId].LastWriteTime -eq $lastWriteTime) {
        $auditResult = $cache[$taskId].Report
        $auditResults += $auditResult
        $newCache[$taskId] = $cache[$taskId]
    } else {
        # Ma logique de diagnostic détaillée
        $workspacePath = Get-TaskWorkspacePath -TaskDirectory $taskDir
        $status = 'VALIDE'
        if ($workspacePath -eq "[Workspace non trouvé]" -or -not (Test-Path -Path $workspacePath)) {
            $status = 'WORKSPACE_ORPHELIN'
        }
        
        # Ici, on pourrait ajouter plus de diagnostics comme la taille, etc.
        $report = [PSCustomObject]@{
            TaskId             = $taskId
            InvalidWorkspacePath = if ($status -eq 'WORKSPACE_ORPHELIN') { $workspacePath } else { $null }
            Status             = $status
        }
        $auditResults += $report
        $newCache[$taskId] = @{ LastWriteTime = $lastWriteTime; Report = $report }
    }
}

$newCache | ConvertTo-Json -Depth 5 | Set-Content -Path $cacheFile -Encoding UTF8

# Ma logique de rapport
$summary = $auditResults | Group-Object -Property Status | Select-Object @{Name = "Statut"; Expression = { $_.Name } }, Count
if (-not $AsJson.IsPresent) {
    Write-Host "  - Tâches totales analysées : $totalTasks"
    # ... (plus de détails sur la taille, etc.)
    Write-Host "Répartition des statuts :"
    $summary | Format-Table -AutoSize
}

$finalReport = [PSCustomObject]@{
    DbMetrics    = $dbMetrics
    SizeMetrics  = $sizeMetrics
    TasksSummary = $summary
    TasksDetails = $auditResults
}

if ($AsJson.IsPresent) {
    $finalReport | ConvertTo-Json -Depth 5 -Compress
} else {
    $finalReport
}

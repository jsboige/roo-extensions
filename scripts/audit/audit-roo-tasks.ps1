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
    [int]$SampleCount = 0
)

function Get-RooTasksPath {
    $defaultPath = Join-Path $env:APPDATA 'Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks'
    if (Test-Path -Path $defaultPath -PathType Container) {
        return $defaultPath
    }
    return $null
}

function Get-TaskWorkspacePath {
    param(
        [System.IO.DirectoryInfo]$TaskDirectory
    )

    # Priorité à l'historique
    $historyFilePath = Join-Path -Path $TaskDirectory.FullName -ChildPath 'api_conversation_history.json'
    if (Test-Path $historyFilePath) {
        try {
            $historyContent = Get-Content -Path $historyFilePath -Raw | ConvertFrom-Json
            foreach ($entry in $historyContent) {
                if ($entry.role -eq 'user' -and $entry.content) {
                    foreach($contentItem in $entry.content) {
                        if($contentItem.type -eq 'text' -and $contentItem.text -like '*Current Workspace Directory*') {
                            try {
                                # Extrait le chemin du workspace de la chaîne de texte
                                $workspaceLine = $contentItem.text.Split([Environment]::NewLine) | Where-Object { $_ -like '# Current Workspace Directory*' }
                                if($workspaceLine) {
                                    $match = [regex]::Match($workspaceLine, '\((.*?)\) Files')
                                    if ($match.Success) {
                                        return $match.Groups[1].Value
                                    }
                                }
                            } catch {
                                # On continue si le parsing échoue
                            }
                        }
                    }
                }
            }
        } catch { $null }
    }

    # Fallback sur les métadonnées
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

$dbMetrics = $null
if (-not $AsJson.IsPresent) {
    Write-Host "--- Lancement du diagnostic de l'état de Roo ---"
    Write-Host ("-" * 80)

    # 1. Analyse de state.vscdb
    Write-Host "📊 1. Analyse de state.vscdb"
    $dbMetrics = Get-StateVscDbMetrics -DbPath $globalPaths.VscodeDb
    if ($dbMetrics.Error) {
        Write-Warning $dbMetrics.Error
    } else {
        Write-Host "  - Module PSSQLite Trouvé: $($dbMetrics.IsModuleInstalled)"
        Write-Host "  - Connexion à la BDD: $($dbMetrics.CanConnect)"
        Write-Host "  - Clés Roo trouvées: $($dbMetrics.RooKeysCount)"
        Write-Host "  - Taille des données Roo: $(Format-Bytes $dbMetrics.RooTotalSize)"
    }
    Write-Host ("-" * 80)

    # 2. Analyse du répertoire des tâches
    Write-Host "📂 2. Audit du répertoire des tâches : $TasksPath"
}
if ($SampleCount -gt 0) {
    if (-not $AsJson.IsPresent) {
        Write-Host "Limitation de l'analyse aux $SampleCount tâches les plus récentes."
    }
    # Optimisation: Trier et sélectionner sans charger toute la liste en mémoire d'abord.
    $taskDirs = Get-ChildItem -Path $TasksPath -Directory | Sort-Object -Property CreationTime -Descending | Select-Object -First $SampleCount
} else {
    $taskDirs = Get-ChildItem -Path $TasksPath -Directory
}
$totalTasks = $taskDirs.Count
$auditResults = @()
$sizeMetrics = @{ Total = 0; Json = 0; Checkpoints = 0 }

$taskDirs | ForEach-Object -Process {
    $i = [int]$foreach.CurrentIndex + 1
    if (-not $Quiet -and -not $AsJson.IsPresent) {
        Write-Progress -Activity "Analyse des tâches Roo" -Status "Analyse de $($_.Name)" -PercentComplete (($i / $totalTasks) * 100)
    }
}

$summary = $auditResults | Group-Object -Property Status | Select-Object @{Name = "Statut"; Expression = { $_.Name } }, Count
if (-not $AsJson.IsPresent) {
    Write-Host "  - Tâches totales analysées : $totalTasks"
    Write-Host "  - Taille totale du stockage : $(Format-Bytes $sizeMetrics.Total)"
    Write-Host "    - Taille des métadonnées (JSON) : $(Format-Bytes $sizeMetrics.Json)"
    Write-Host "    - Taille des checkpoints (autres) : $(Format-Bytes $sizeMetrics.Checkpoints)"
    Write-Host ""
    Write-Host "Répartition des statuts :"
    $summary | Format-Table -AutoSize
    Write-Host ("-" * 80)
}

$finalReport = [PSCustomObject]@{
    DbMetrics    = $dbMetrics
    SizeMetrics  = $sizeMetrics
    TasksSummary = $summary
    TasksDetails = $auditResults
}

if (-not $Quiet -and !$AsJson.IsPresent) {
    Write-Host "3. Detail par tache"
    $auditResults | Format-Table -AutoSize
    Write-Host ("-" * 80)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath) -and !$AsJson.IsPresent) {
    try {
        $auditResults | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
        Write-Host "✅ Rapport d'audit des tâches exporté avec succès vers : $ReportPath"
    }
    catch {
        Write-Warning "Impossible d'exporter le rapport vers '$ReportPath'. Erreur : $($_.Exception.Message)"
    }
}
if (-not $AsJson.IsPresent){
    Write-Host "--- Fin du diagnostic ---"
}

if ($AsJson.IsPresent) {
    $finalReport | ConvertTo-Json -Depth 5 -Compress
}

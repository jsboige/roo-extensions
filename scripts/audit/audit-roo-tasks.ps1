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
    [switch]$AsJson,
    [int]$Offset = 0,
    [int]$Limit = 0
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

$cacheFile = Join-Path -Path $PSScriptRoot -ChildPath "audit_cache.json"
$cache = @{}
if (Test-Path $cacheFile) {
    try {
        $cache = Get-Content -Path $cacheFile -Raw | ConvertFrom-Json -AsHashtable
    } catch {}
}

$allTaskDirs = Get-ChildItem -Path $tasksPath -Directory
$tasksToProcess = $allTaskDirs

if ($Limit -gt 0) {
    $tasksToProcess = $allTaskDirs | Select-Object -Skip $Offset -First $Limit
}

$tasksList = [System.Collections.Generic.List[PSObject]]::new()
$newCache = @{ LastScan = (Get-Date).ToUniversalTime().ToString("o") }

foreach ($taskDir in $tasksToProcess) {
    $taskId = $taskDir.Name
    $lastWriteTime = $taskDir.LastWriteTimeUtc.ToString("o")
    
    if ($cache.Contains($taskId) -and $cache[$taskId].LastWriteTime -eq $lastWriteTime) {
        $tasksList.Add($cache[$taskId].Report)
        $newCache[$taskId] = $cache[$taskId]
    } else {
        # La fonction Get-TaskWorkspacePath n'est pas adaptée pour un rapport complet,
        # nous allons simplifier et appeler une fonction de diagnostic plus complète si elle existait.
        # Pour l'instant, nous gardons la logique simple.
        $workspacePath = Get-TaskWorkspacePath -TaskDirectory $taskDir
        $status = 'VALIDE'
        if ($workspacePath -eq "[Workspace non trouvé]" -or -not (Test-Path -Path $workspacePath)) {
            $status = 'WORKSPACE_ORPHELIN'
        }
        $report = [PSCustomObject]@{
            TaskId             = $taskDir.Name
            InvalidWorkspacePath = if ($status -eq 'WORKSPACE_ORPHELIN') { $workspacePath } else { $null }
            Status             = $status
        }
        $tasksList.Add($report)
        $newCache[$taskId] = @{ LastWriteTime = $lastWriteTime; Report = $report }
    }
}

$newCache | ConvertTo-Json -Depth 5 | Set-Content -Path $cacheFile -Encoding UTF8

# Retourne un objet final qui contient la liste des tâches
$finalOutput = [PSCustomObject]@{
    Tasks = $tasksList
}

if ($AsJson) {
    return $finalOutput | ConvertTo-Json -Depth 5
} else {
    return $finalOutput
}

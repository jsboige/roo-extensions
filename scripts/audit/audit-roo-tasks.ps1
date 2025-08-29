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

$taskDirs = Get-ChildItem -Path $tasksPath -Directory
$tasksList = [System.Collections.Generic.List[PSObject]]::new()

foreach ($taskDir in $taskDirs) {
    $workspacePath = Get-TaskWorkspacePath -TaskDirectory $taskDir
    $status = 'VALIDE'
    
    if ($workspacePath -eq "[Workspace non trouvé]" -or -not (Test-Path -Path $workspacePath)) {
        $status = 'WORKSPACE_ORPHELIN'
    }

    $taskObject = [PSCustomObject]@{
        TaskId             = $taskDir.Name
        InvalidWorkspacePath = if ($status -eq 'WORKSPACE_ORPHELIN') { $workspacePath } else { $null }
        Status             = $status
    }
    $tasksList.Add($taskObject)
}

# Retourne un objet final qui contient la liste des tâches
return [PSCustomObject]@{
    Tasks = $tasksList
}

[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string]$TasksPath = "D:\Dev\roo-extensions\cleanup-backups\20250527-012300\phase5\encoding-fix-backup\local-state\tasks"
)

# Fonction de simulation pour trouver les tâches saines
function Find-HealthyTaskPath {
    param([string]$Path)
    # Simulation: on considère une tâche saine si elle contient un fichier 'task.json'
    if (Test-Path -Path (Join-Path -Path $Path -ChildPath "task.json")) {
        return $Path
    }
    return $null
}

# Fonction de simulation pour trouver les tâches orphelines
function Find-OrphanTaskPath {
    param([string]$Path)
    # Simulation: on considère une tâche orpheline si elle ne contient PAS de 'task.json'
    if (-not (Test-Path -Path (Join-Path -Path $Path -ChildPath "task.json"))) {
        return $Path
    }
    return $null
}

Get-ChildItem -Path $TasksPath -Directory | ForEach-Object {
    $taskDir = $_.FullName
    $healthyTaskPath = Find-HealthyTaskPath -Path $taskDir
    $orphanTaskPath = Find-OrphanTaskPath -Path $taskDir

    if ($healthyTaskPath) {
        Write-Verbose "Tâche saine trouvée : $healthyTaskPath"
        $taskJsonPath = Join-Path -Path $healthyTaskPath -ChildPath "task.json"
        
        if (Test-Path $taskJsonPath) {
            try {
                $content = Get-Content -Path $taskJsonPath -Raw -ErrorAction Stop
                $taskData = $content | ConvertFrom-Json -ErrorAction Stop
                Write-Verbose "JSON valide dans : $taskJsonPath"
            } catch {
                Write-Warning "Erreur de parsing JSON dans '$taskJsonPath': $_"
            }
        }
    }

    if ($orphanTaskPath) {
        Write-Warning "Tâche orpheline trouvée : $orphanTaskPath"
    }
}
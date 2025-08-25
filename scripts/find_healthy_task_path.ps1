function Find-HealthyTaskPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$TaskPath
    )
    # Simulation: on considère une tâche saine si elle contient un fichier 'task.json'
    if (Test-Path -Path (Join-Path -Path $TaskPath -ChildPath "task.json")) {
        return $TaskPath
    }
    return $null
}
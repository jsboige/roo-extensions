function Find-OrphanTaskPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$TaskPath
    )
    # Simulation: on considère une tâche orpheline si elle ne contient PAS de 'task.json'
    if (-not (Test-Path -Path (Join-Path -Path $TaskPath -ChildPath "task.json"))) {
        return $TaskPath
    }
    return $null
}
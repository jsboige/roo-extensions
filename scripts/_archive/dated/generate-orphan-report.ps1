<#
.SYNOPSIS
Génère un rapport synthétique des répertoires de workspaces orphelins et du nombre de tâches associées.
#>

# Chemin vers le script d'audit
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$auditScriptPath = Join-Path $scriptDir "audit-roo-tasks.ps1"

# 1. Exécution du script d'audit
$auditResult = & $auditScriptPath

# 2. Filtrage des tâches orphelines
$orphanTasks = $auditResult.Tasks | Where-Object { $_.Status -eq 'WORKSPACE_ORPHELIN' }

# 3. Formatage de la sortie en synthèse (méthode manuelle)
if ($null -ne $orphanTasks -and $orphanTasks.Count -gt 0) {
    Write-Host "--- Synthèse des Workspaces Orphelins ---"
    
    $workspaceCounts = @{}
    foreach ($task in $orphanTasks) {
        $path = $task.InvalidWorkspacePath
        if ($null -ne $path) {
            if ($workspaceCounts.ContainsKey($path)) {
                $workspaceCounts[$path]++
            } else {
                $workspaceCounts[$path] = 1
            }
        }
    }

    $workspaceCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
        "  - Path: $($_.Name)"
        "    Tâches associées: $($_.Value)"
    }

} else {
    "Aucune tâche orpheline n'a été trouvée."
}
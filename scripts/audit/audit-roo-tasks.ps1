#Requires -Version 5.1

<#
.SYNOPSIS
    Analyse le répertoire de stockage des tâches Roo pour identifier et rapporter les tâches orphelines.
.DESCRIPTION
    Ce script audite le répertoire où l'extension Roo stocke ses données de tâches.
    Pour chaque tâche, il vérifie si le workspace d'origine associé existe toujours sur le disque.

    Il classifie les tâches en plusieurs catégories :
    - VALIDE : Le workspace associé a été trouvé.
    - ORPHELIN : Le workspace associé n'existe plus.
    - ERREUR_HISTOIRE_MANQUANT : Le fichier 'api_conversation_history.json' est introuvable.
    - ERREUR_PARSING_JSON : Le contenu JSON est invalide ou la structure est inattendue.

    Le script retourne un objet PowerShell pour chaque tâche analysée, permettant une intégration facile avec d'autres outils en pipeline.
.PARAMETER TasksPath
    Spécifie le chemin vers le répertoire 'tasks' de Roo. S'il n'est pas fourni, le script tente de le détecter automatiquement.
.PARAMETER ReportPath
    Si spécifié, exporte les résultats détaillés de l'audit dans un fichier CSV à l'emplacement indiqué.
.PARAMETER Quiet
    Si présent, supprime la sortie détaillée en temps réel et n'affiche que le résumé final.
.EXAMPLE
    .\audit-roo-tasks.ps1
    Lance un audit avec détection automatique du chemin et affiche les résultats dans la console.
.EXAMPLE
    .\audit-roo-tasks.ps1 -TasksPath "C:\path\to\tasks" -ReportPath "C:\audits\report.csv"
    Lance un audit sur un chemin spécifique et exporte les résultats dans un fichier CSV.
.EXAMPLE
    .\audit-roo-tasks.ps1 | Where-Object { $_.Status -eq 'ORPHELIN' }
    Retourne uniquement les tâches identifiées comme orphelines.
.OUTPUTS
    [PSCustomObject]
    Un objet pour chaque tâche, contenant TaskId, Status, WorkspacePath et Details.
#>
[CmdletBinding()]
param(
    [string]$TasksPath,
    [string]$ReportPath,
    [switch]$Quiet
)

function Get-RooTaskStoragePath {
    $defaultPath = Join-Path $env:APPDATA 'Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks'
    if (Test-Path -Path $defaultPath -PathType Container) {
        return $defaultPath
    }
    return $null
}

function Test-RooTaskState {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$TaskDirectory
    )

    $historyFilePath = Join-Path -Path $TaskDirectory.FullName -ChildPath 'api_conversation_history.json'
    $taskId = $TaskDirectory.Name

    if (-not (Test-Path -Path $historyFilePath -PathType Leaf)) {
        return [PSCustomObject]@{
            TaskId        = $taskId
            Status        = "ERREUR_HISTOIRE_MANQUANT"
            WorkspacePath = "[N/A]"
            Details       = "Le fichier api_conversation_history.json est introuvable."
        }
    }

    try {
        $historyContent = Get-Content -Path $historyFilePath -Raw | ConvertFrom-Json
        $firstEntry = $historyContent | Select-Object -First 1

        if ($null -eq $firstEntry -or -not $firstEntry.PSObject.Properties.Name -contains 'requestBody' -or [string]::IsNullOrWhiteSpace($firstEntry.requestBody)) {
            return [PSCustomObject]@{
                TaskId        = $taskId
                Status        = "ERREUR_PARSING_JSON"
                WorkspacePath = "[N/A]"
                Details       = "La première entrée de l'historique est vide ou 'requestBody' est manquant."
            }
        }
        
        $initialMessage = $firstEntry.requestBody | ConvertFrom-Json
        $workspacePath = $initialMessage.workspace

        if ([string]::IsNullOrWhiteSpace($workspacePath)) {
             return [PSCustomObject]@{
                TaskId        = $taskId
                Status        = "ERREUR_PARSING_JSON"
                WorkspacePath = "[N/A]"
                Details       = "Le chemin du workspace est vide dans la première requête."
            }
        }

        if (Test-Path -Path $workspacePath) {
            return [PSCustomObject]@{
                TaskId        = $taskId
                Status        = "VALIDE"
                WorkspacePath = $workspacePath
                Details       = "Le répertoire du workspace existe."
            }
        } else {
            return [PSCustomObject]@{
                TaskId        = $taskId
                Status        = "ORPHELIN"
                WorkspacePath = $workspacePath
                Details       = "Le répertoire du workspace est introuvable."
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            TaskId        = $taskId
            Status        = "ERREUR_PARSING_JSON"
            WorkspacePath = "[N/A]"
            Details       = "Impossible d'analyser le fichier JSON : $($_.Exception.Message)"
        }
    }
}

# --- Point d'entrée du Script ---

$OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($TasksPath)) {
    $TasksPath = Get-RooTaskStoragePath
    if (-not $TasksPath) {
        Write-Error "Impossible de trouver le répertoire des tâches Roo. Veuillez spécifier le chemin avec le paramètre -TasksPath."
        exit 1
    }
}

if (-not (Test-Path -Path $TasksPath -PathType Container)) {
    Write-Error "Le répertoire spécifié n'existe pas : $TasksPath"
    exit 1
}

if (-not $Quiet) {
    Write-Host "🔍 Audit des tâches Roo dans le répertoire : $TasksPath"
    Write-Host ("-" * 80)
}

$taskDirs = Get-ChildItem -Path $TasksPath -Directory
$totalTasks = $taskDirs.Count
$auditResults = @()

$taskDirs | ForEach-Object -Process {
    $i = [int]$foreach.CurrentIndex + 1
    if (-not $Quiet) {
        Write-Progress -Activity "Analyse des tâches Roo" -Status "Analyse de $($_.Name)" -PercentComplete (($i / $totalTasks) * 100)
    }
    
    $result = Test-RooTaskState -TaskDirectory $_
    
    if (-not $Quiet) {
        $statusColor = switch ($result.Status) {
            "VALIDE"   { "Green" }
            "ORPHELIN" { "Yellow" }
            default    { "Red" }
        }
        Write-Host -NoNewline "Tâche [$($result.TaskId)]: "
        Write-Host -NoNewline -ForegroundColor $statusColor $result.Status.PadRight(25)
        Write-Host "- $($result.WorkspacePath)"
    }
    
    $auditResults += $result
}

# --- Résumé et Export ---

if ($auditResults.Count -gt 0) {
    $summary = $auditResults | Group-Object -Property Status | Select-Object @{Name = "Statut"; Expression = { $_.Name } }, Count

    Write-Host ("-" * 80)
    Write-Host "📊 Résumé de l'audit :"
    $summary | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "  - Tâches totales analysées : $totalTasks"
    Write-Host ("-" * 80)

    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
        try {
            $auditResults | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
            Write-Host "✅ Rapport d'audit exporté avec succès vers : $ReportPath"
        }
        catch {
            Write-Warning "Impossible d'exporter le rapport vers '$ReportPath'. Erreur : $($_.Exception.Message)"
        }
    }
} else {
    Write-Host "Aucune tâche trouvée à analyser dans le répertoire '$TasksPath'."
}

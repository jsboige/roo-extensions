#Requires -Version 5.1

# Correction de l'encodage pour la console PowerShell
$OutputEncoding = [System.Text.Encoding]::UTF8

# Définir le chemin du répertoire des tâches Roo
$tasksPath = Join-Path $env:APPDATA 'Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks'

# Initialiser les compteurs pour le résumé
$counters = @{
    total = 0
    valide = 0
    orphelin = 0
    ignore = 0
    manquant = 0
    erreur = 0
}

# Vérifier si le répertoire des tâches existe
if (-not (Test-Path -Path $tasksPath -PathType Container)) {
    Write-Error "Le répertoire des tâches Roo n'a pas été trouvé à l'emplacement suivant : $tasksPath"
    exit 1
}

Write-Host "Audit des tâches Roo dans le répertoire : $tasksPath"
Write-Host ("-" * 80)

# Parcourir chaque sous-répertoire (chaque <taskId>)
try {
    Get-ChildItem -Path $tasksPath -Directory | ForEach-Object {
        $counters.total++
        $taskDir = $_
        $taskId = $taskDir.Name
        $historyFilePath = Join-Path -Path $taskDir.FullName -ChildPath 'api_conversation_history.json'

        if (-not (Test-Path -Path $historyFilePath -PathType Leaf)) {
            $counters.manquant++
            $counters.ignore++
            return
        }

        try {
            $historyContent = Get-Content -Path $historyFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            
            $firstEntry = $historyContent | Select-Object -First 1

            if ($null -eq $firstEntry -or [string]::IsNullOrWhiteSpace($firstEntry.requestBody)) {
                $counters.ignore++
                return
            }
            
            $initialMessage = $firstEntry.requestBody | ConvertFrom-Json
            
            $originalTaskId = $initialMessage.taskId
            $workspacePath = $initialMessage.workspace

            $workspaceExists = Test-Path -Path $workspacePath
            if ($workspaceExists) {
                $counters.valide++
                $status = "VALIDE"
                $statusColor = "Green"
            } else {
                $counters.orphelin++
                $status = "ORPHELIN"
                $statusColor = "Yellow"
            }

            $line = "Tâche [$originalTaskId]: "
            Write-Host -NoNewline $line
            Write-Host -NoNewline -ForegroundColor $statusColor $status.PadRight(10)
            Write-Host "- $workspacePath"
        }
        catch {
            $counters.erreur++
            # Décommentez la ligne ci-dessous pour un débogage détaillé des erreurs
            # Write-Warning "Tâche [$taskId]: Erreur de traitement. Détails : $($_.Exception.Message)"
        }
    }
}
finally {
    # Afficher le résumé
    Write-Host ("-" * 80)
    Write-Host "Résumé de l'audit :"
    Write-Host "  - Tâches totales analysées : $($counters.total)"
    Write-Host "  - Workspaces VALIDES       : $($counters.valide)"
    Write-Host "  - Workspaces ORPHELINS     : $($counters.orphelin)"
    Write-Host "  - Tâches ignorées          : $($counters.ignore) (historique vide, 'requestBody' manquant, etc.)"
    Write-Host "      dont 'history.json' manquant : $($counters.manquant)"
    Write-Host "  - Tâches en erreur         : $($counters.erreur)"
    Write-Host ("-" * 80)
}
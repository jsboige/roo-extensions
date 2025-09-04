#Requires -Version 5.1

<#
.SYNOPSIS
    Fournit un bilan de santé complet de l'état de Roo, en s'inspirant de l'outil `diagnose_roo_state`.
.DESCRIPTION
    Ce script audite le répertoire où l'extension Roo stocke ses données de tâches.
    Il effectue les vérifications suivantes :
    - Valide l'existence et l'accès au répertoire de stockage des tâches.
    - Mesure la taille totale du stockage, en distinguant les métadonnées JSON des checkpoints.
    - Pour chaque tâche, vérifie si le workspace associé (défini dans task_metadata.json) existe.
    - Tente d'interroger la base de données state.vscdb pour y lire des métriques sur Roo.

    Il classifie les tâches en plusieurs catégories :
    - VALIDE : Le workspace associé a été trouvé.
    - WORKSPACE_ORPHELIN : Le workspace associé n'existe plus.
    - METADATA_MANQUANTE : Le fichier 'task_metadata.json' est introuvable.
    - ERREUR_PARSING_JSON : Le contenu JSON est invalide ou la structure est inattendue.

.PARAMETER TasksPath
    Spécifie le chemin vers le répertoire 'tasks' de Roo. S'il n'est pas fourni, le script tente de le détecter automatiquement.
.PARAMETER ReportPath
    Si spécifié, exporte les résultats détaillés de l'audit des tâches dans un fichier CSV à l'emplacement indiqué.
.PARAMETER Quiet
    Si présent, supprime la sortie détaillée en temps réel et n'affiche que le résumé final.
.EXAMPLE
    .\audit-roo-tasks.ps1
    Lance un audit complet et affiche un rapport détaillé dans la console.
.EXAMPLE
    .\audit-roo-tasks.ps1 -ReportPath "C:\audits\report.csv"
    Exécute l'audit et exporte la liste des tâches et leur état dans un fichier CSV.
.OUTPUTS
    [PSCustomObject]
    Un objet de rapport contenant le résumé de l'audit et la liste détaillée des tâches.
#>
[CmdletBinding()]
param(
    [string]$TasksPath,
    [string]$ReportPath,
    [switch]$Quiet,
    [switch]$AsJson,
    [int]$SampleCount = 0
)

# --- Fonctions de Support ---

function Get-PathInfos {
    $paths = @{
        Tasks = $null
        VscodeDb = $null
    }
    
    # Chemin des tâches
    $defaultTasksPath = Join-Path $env:APPDATA 'Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks'
    if (Test-Path -Path $defaultTasksPath -PathType Container) {
        $paths.Tasks = $defaultTasksPath
    }

    # Chemin de la BDD VSCode
    $vscodeDbPath = Join-Path $env:APPDATA "Code\User\globalStorage\state.vscdb"
    if (Test-Path -Path $vscodeDbPath -PathType Leaf) {
        $paths.VscodeDb = $vscodeDbPath
    }

    return $paths
}

function Get-DirectorySize {
    param(
        [string]$Path
    )
    $size = (Get-ChildItem $Path -Recurse -Force | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    return $size
}

function Format-Bytes {
    param ($bytes)
    $units = "B", "KB", "MB", "GB", "TB", "PB"
    $i = 0
    while ($bytes -ge 1024 -and $i -lt ($units.Length - 1)) {
        $bytes /= 1024
        $i++
    }
    "{0:N2} {1}" -f $bytes, $units[$i]
}

function Get-StateVscDbMetrics {
    param(
        [string]$DbPath
    )
    $report = @{
        IsModuleInstalled = $false
        CanConnect = $false
        RooKeysCount = 0
        RooTotalSize = 0
        Error = ""
    }

    if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
        $report.Error = "Module PSSQLite non trouvé. Pour une analyse complète, installez-le avec : Install-Module -Name PSSQLite -Scope CurrentUser"
        return $report
    }
    $report.IsModuleInstalled = $true
    
    try {
        Import-Module PSSQLite
        $query = "SELECT key, value FROM ItemTable WHERE key LIKE 'rooveterinaryinc.roo-cline%'"
        $results = Invoke-SqliteQuery -DataSource $DbPath -Query $query -ErrorAction Stop
        
        $report.CanConnect = $true
        $report.RooKeysCount = $results.Count
        foreach ($row in $results) {
            $report.RooTotalSize += [System.Text.Encoding]::UTF8.GetByteCount($row.value)
        }
    }
    catch {
        $report.Error = "Impossible d'interroger la base state.vscdb. Elle est probablement verrouillée par VSCode. Fermez VSCode pour une analyse complète. Erreur: $($_.Exception.Message)"
    }
    return $report
}


function Test-RooTaskState {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$TaskDirectory,
        [ref]$SizeMetrics
    )

    $metadataPath = Join-Path -Path $TaskDirectory.FullName -ChildPath 'task_metadata.json'
    $taskId = $TaskDirectory.Name

    $taskFiles = Get-ChildItem -Path $TaskDirectory.FullName -File -Recurse
    $totalTaskSize = ($taskFiles | Measure-Object -Property Length -Sum).Sum
    $jsonSize = ($taskFiles | Where-Object { $_.Extension -eq '.json' } | Measure-Object -Property Length -Sum).Sum
    
    $SizeMetrics.Value.Total += $totalTaskSize
    $SizeMetrics.Value.Json += $jsonSize
    $SizeMetrics.Value.Checkpoints += ($totalTaskSize - $jsonSize)

    if (-not (Test-Path -Path $metadataPath -PathType Leaf)) {
        return [PSCustomObject]@{
            TaskId        = $taskId
            Status        = "METADATA_MANQUANTE"
            WorkspacePath = "[N/A]"
            Details       = "Le fichier task_metadata.json est introuvable."
        }
    }

    try {
        $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
        $workspacePath = $metadata.workspace_path

        if ([string]::IsNullOrWhiteSpace($workspacePath)) {
            # Si workspace_path est absent, on tente de le trouver dans la première requête de l'historique
            $historyFilePath = Join-Path -Path $TaskDirectory.FullName -ChildPath 'api_conversation_history.json'
            if (Test-Path $historyFilePath) {
                $historyContent = Get-Content -Path $historyFilePath -Raw | ConvertFrom-Json
                $firstEntry = $historyContent | Select-Object -First 1
                if ($null -ne $firstEntry -and $firstEntry.PSObject.Properties.Name -contains 'requestBody') {
                    $initialMessage = $firstEntry.requestBody | ConvertFrom-Json
                    $workspacePath = $initialMessage.workspace
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($workspacePath)) {
             return [PSCustomObject]@{
                TaskId        = $taskId
                Status        = "ERREUR_PARSING_JSON"
                WorkspacePath = "[N/A]"
                Details       = "Le chemin du workspace est introuvable dans task_metadata.json et dans l'historique."
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
                Status        = "WORKSPACE_ORPHELIN"
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
$globalPaths = Get-PathInfos

if ([string]::IsNullOrWhiteSpace($TasksPath)) {
    $TasksPath = $globalPaths.Tasks
    if (-not $TasksPath) {
        Write-Error "Impossible de trouver le répertoire des tâches Roo. Veuillez spécifier le chemin avec le paramètre -TasksPath."
        exit 1
    }
}

if (-not (Test-Path -Path $TasksPath -PathType Container)) {
    Write-Error "Le répertoire spécifié n'existe pas : $TasksPath"
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
    $result = Test-RooTaskState -TaskDirectory $_ -SizeMetrics ([ref]$sizeMetrics)
    $auditResults += $result
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

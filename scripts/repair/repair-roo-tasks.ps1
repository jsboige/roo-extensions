#Requires -Version 5.1

<#
.SYNOPSIS
    Répare les tâches Roo dont les chemins de workspace sont devenus invalides suite à un déplacement.
.DESCRIPTION
    Ce script identifie d'abord les tâches dont le workspace est introuvable (statut 'WORKSPACE_ORPHELIN').
    Pour chaque chemin racine unique et invalide, il demande à l'utilisateur de fournir un nouveau chemin de base.
    
    Une fois les mappings de chemins fournis, le script met à jour le fichier `task_metadata.json` de chaque
    tâche orpheline concernée avec le nouveau chemin de workspace corrigé.

    Le script supporte pleinement le mode simulation (`-WhatIf`) pour prévisualiser les changements sans
    modifier aucun fichier.
.PARAMETER TasksPath
    Spécifie le chemin vers le répertoire 'tasks' de Roo. S'il n'est pas fourni, le script tente de le détecter automatiquement.
.PARAMETER AuditReport
    Prend en entrée le résultat d'un audit préalable (généré par `audit-roo-tasks.ps1`) pour éviter de refaire l'analyse.
    Ce paramètre attend une collection d'objets [PSCustomObject].
.EXAMPLE
    .\repair-roo-tasks.ps1
    Lance une analyse, puis guide l'utilisateur pour réparer les chemins de workspace des tâches orphelines.
.EXAMPLE
    .\repair-roo-tasks.ps1 -WhatIf
    Simule le processus de réparation, affichant les changements qui seraient effectués sans les appliquer.
.EXAMPLE
    $report = .\audit-roo-tasks.ps1 -Quiet
    .\repair-roo-tasks.ps1 -AuditReport $report.DetailedTaskReport
    Exécute la réparation en se basant sur un audit préalable, ce qui est plus rapide.
.OUTPUTS
    [PSCustomObject]
    Un objet pour chaque tâche qui a été réparée (ou qui le serait en mode -WhatIf).
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$TasksPath,
    [object[]]$AuditReport
)

# --- Fonctions de Support (Partagées avec le script d'audit) ---

function Get-RooTaskStoragePath {
    $defaultPath = Join-Path $env:APPDATA 'Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks'
    if (Test-Path -Path $defaultPath -PathType Container) {
        return $defaultPath
    }
    return $null
}

function Test-RooTaskState {
    # Version simplifiée pour ce script, car nous n'avons besoin que du statut et du chemin.
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$TaskDirectory
    )

    $metadataPath = Join-Path -Path $TaskDirectory.FullName -ChildPath 'task_metadata.json'
    $taskId = $TaskDirectory.Name

    if (-not (Test-Path -Path $metadataPath -PathType Leaf)) {
        return [PSCustomObject]@{ TaskId = $taskId; Status = "METADATA_MANQUANTE"; WorkspacePath = "[N/A]" }
    }

    try {
        $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
        $workspacePath = $metadata.workspace_path

        if ([string]::IsNullOrWhiteSpace($workspacePath)) {
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
            return [PSCustomObject]@{ TaskId = $taskId; Status = "CHEMIN_VIDE"; WorkspacePath = "[N/A]" }
        }

        $status = if (Test-Path -Path $workspacePath) { "VALIDE" } else { "WORKSPACE_ORPHELIN" }
        return [PSCustomObject]@{ TaskId = $taskId; Status = $status; WorkspacePath = $workspacePath }
    }
    catch {
        return [PSCustomObject]@{ TaskId = $taskId; Status = "ERREUR_PARSING_JSON"; WorkspacePath = "[N/A]" }
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

# 1. Obtenir la liste des tâches et leur statut
if ($null -eq $AuditReport) {
    Write-Host "🔍 Aucun rapport d'audit fourni. Lancement de l'analyse des tâches..."
    $taskDirs = Get-ChildItem -Path $TasksPath -Directory
    $totalTasks = $taskDirs.Count
    $AuditReport = @()
    $taskDirs | ForEach-Object -Process {
        Write-Progress -Activity "Analyse des tâches" -Status "Analyse de $($_.Name)" -PercentComplete (([int]$foreach.CurrentIndex + 1 / $totalTasks) * 100)
        $AuditReport += Test-RooTaskState -TaskDirectory $_
    }
    Write-Host "✅ Analyse terminée."
}

$orphanTasks = $AuditReport | Where-Object { $_.Status -eq 'WORKSPACE_ORPHELIN' }

if ($orphanTasks.Count -eq 0) {
    Write-Host -ForegroundColor Green "🎉 Aucune tâche avec un workspace orphelin n'a été trouvée. Aucune réparation nécessaire."
    exit 0
}

Write-Host -ForegroundColor Yellow "⚠️ $($orphanTasks.Count) tâche(s) avec un workspace orphelin ont été trouvées."
Write-Host ("-" * 80)

# 2. Identifier les chemins de base invalides et demander des remplacements
$rootPathMappings = @{}
$uniqueInvalidRootPaths = $orphanTasks | ForEach-Object {
    $path = $_.WorkspacePath
    while ($path -and -not (Test-Path $path)) {
        $parent = Split-Path -Path $path -Parent
        if ($parent -eq $path) { break } # Atteint la racine (par ex. C:\)
        $path = $parent
    }
    if ($path) { Split-Path -Path $path -Parent } # Retourne le premier parent qui n'existe PAS
} | Where-Object { $_ -ne $null -and $_ -ne "" } | Sort-Object -Unique

Write-Host " interactive pour mapper les anciens chemins de base aux nouveaux."
Write-Host "Laissez la réponse vide pour ignorer la réparation d'un chemin."

foreach ($invalidRoot in $uniqueInvalidRootPaths) {
    if (-not $invalidRoot) { continue }
    $newRoot = Read-Host "  -> Le chemin de base '$invalidRoot' est introuvable. Entrez le nouveau chemin équivalent"
    if (-not [string]::IsNullOrWhiteSpace($newRoot)) {
        if (-not (Test-Path -Path $newRoot -PathType Container)) {
            Write-Warning "Le chemin '$newRoot' n'existe pas. Il sera utilisé quand même, mais pourrait créer des chemins invalides."
        }
        $rootPathMappings[$invalidRoot] = $newRoot
    }
}

if ($rootPathMappings.Count -eq 0) {
    Write-Host "Aucun mapping de chemin fourni. Aucune réparation ne sera effectuée."
    exit 0
}

Write-Host ("-" * 80)
Write-Host "🔧 Application des réparations..."

# 3. Appliquer les réparations
$repairedTasksCount = 0
foreach ($task in $orphanTasks) {
    $metadataPath = Join-Path -Path $TasksPath -ChildPath $task.TaskId -ChildPath 'task_metadata.json'
    
    # Trouver le mapping applicable
    $applicableMapping = $null
    foreach ($oldRoot in $rootPathMappings.Keys) {
        if ($task.WorkspacePath.StartsWith($oldRoot, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            $applicableMapping = @{ Old = $oldRoot; New = $rootPathMappings[$oldRoot] }
            break
        }
    }

    if ($null -eq $applicableMapping) {
        continue # Pas de mapping pour cette tâche
    }

    # Construire le nouveau chemin
    $relativePath = $task.WorkspacePath.Substring($applicableMapping.Old.Length)
    $newWorkspacePath = Join-Path -Path $applicableMapping.New -ChildPath $relativePath

    $target = "task_metadata.json pour la tâche $($task.TaskId)"
    $action = "Mettre à jour le workspace de '$($task.WorkspacePath)' vers '$newWorkspacePath'"

    if ($PSCmdlet.ShouldProcess($target, $action)) {
        try {
            # Lire, modifier, écrire
            $metadataFile = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
            
            # Mettre à jour la bonne propriété
            if ($metadataFile.PSObject.Properties.Name -contains 'workspace_path') {
                $metadataFile.workspace_path = $newWorkspacePath
            } elseif ($metadataFile.PSObject.Properties.Name -contains 'workspace') { # Fallback
                $metadataFile.workspace = $newWorkspacePath
            } else {
                 Write-Warning "La tâche $($task.TaskId) n'a pas de propriété 'workspace_path' ou 'workspace' dans ses métadonnées."
                 continue
            }
            
            $metadataFile | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataPath -Encoding UTF8 -Force
            Write-Host -ForegroundColor Green "✅ Tâche $($task.TaskId) réparée."
            $repairedTasksCount++
        }
        catch {
             Write-Error "Impossible de réparer la tâche $($task.TaskId). Erreur : $($_.Exception.Message)"
        }
    }
}

Write-Host ("-" * 80)
Write-Host "🎉 Réparation terminée."
Write-Host "  - Tâches réparées : $repairedTasksCount"
Write-Host ("-" * 80)
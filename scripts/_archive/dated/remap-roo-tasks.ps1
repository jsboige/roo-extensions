<#
.SYNOPSIS
Remappe les chemins de workspace des tâches Roo en se basant sur un fichier de configuration JSON.

.DESCRIPTION
Ce script parcourt toutes les tâches Roo, identifie celles dont le chemin du workspace est obsolète
et le met à jour en se basant sur les règles de mappage définies dans 'workspace-mappings.json'.

Il peut fonctionner en mode simulation (DryRun) pour prévisualiser les changements avant de les appliquer.

.PARAMETER DryRun
Si spécifié, le script affichera les changements qu'il aurait faits sans modifier aucun fichier.

.EXAMPLE
PS > ./remap-roo-tasks.ps1 -DryRun
Affiche toutes les tâches qui seraient remappées.

.EXAMPLE
PS > ./remap-roo-tasks.ps1
Applique le remappage à toutes les tâches correspondantes.
#>
param(
    [Switch]$DryRun
)

# Configuration de l'encodage et du chemin de base
$InitialOutputEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BaseDir = Resolve-Path (Join-Path $ScriptDir "..")

# Fonction pour trouver le chemin du workspace (identique à audit-roo-tasks.ps1)
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
                                $workspaceLine = $contentItem.text.Split([Environment]::NewLine) | Where-Object { $_ -like '# Current Workspace Directory*' }
                                if($workspaceLine) {
                                    $match = [regex]::Match($workspaceLine, '\((.*?)\) Files')
                                    if ($match.Success) {
                                        return $match.Groups[1].Value
                                    }
                                }
                            } catch {}
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
                return $metadata.workspace_path | Select-Object -First 1
            }
        } catch { $null }
    }

    return "[Workspace non trouvé]"
}


# Fonction pour mettre à jour le workspace path dans TOUS les fichiers pertinents
function Set-TaskWorkspacePath {
    param(
        [System.IO.DirectoryInfo]$TaskDirectory,
        [string]$OldPath,
        [string]$NewPath,
        [bool]$IsDryRun
    )

    Write-Host "  -> Remappage de '$OldPath' vers '$NewPath'..." -ForegroundColor Green

    # 1. Mise à jour de task_metadata.json
    $metadataPath = Join-Path -Path $TaskDirectory.FullName -ChildPath 'task_metadata.json'
    if (Test-Path -Path $metadataPath) {
        try {
            $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
            if ($metadata.workspace_path -eq $OldPath) {
                Write-Host "     - Modification de task_metadata.json"
                if (-not $IsDryRun) {
                    $metadata.workspace_path = $NewPath
                    $metadata | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataPath -Encoding UTF8
                }
            }
        } catch {
            Write-Warning "     - Impossible de mettre à jour task_metadata.json pour $($TaskDirectory.Name)"
        }
    }

    # 2. Mise à jour de api_conversation_history.json
    $historyFilePath = Join-Path -Path $TaskDirectory.FullName -ChildPath 'api_conversation_history.json'
    if (Test-Path $historyFilePath) {
        try {
            $historyContent = Get-Content -Path $historyFilePath -Raw
            # On cible la chaîne de caractères exacte pour éviter les remplacements accidentels
            $stringToFind = "# Current Workspace Directory ({0})" -f $OldPath
            if ($historyContent -like "*$stringToFind*") {
                Write-Host "     - Modification de api_conversation_history.json"
                if (-not $IsDryRun) {
                    $stringToReplace = "# Current Workspace Directory ({0})" -f $NewPath
                    $newContent = $historyContent.Replace($stringToFind, $stringToReplace)
                    Set-Content -Path $historyFilePath -Value $newContent -Encoding UTF8
                }
            }
        } catch {
            Write-Warning "     - Impossible de mettre à jour api_conversation_history.json pour $($TaskDirectory.Name)"
        }
    }
}


# --- Point d'entrée du script ---

$IsWindows = ($env:OS -eq 'Windows_NT')

if ($DryRun) {
    Write-Host "--- Lancement en mode simulation (DryRun) ---" -ForegroundColor Yellow
} else {
    Write-Host "--- Lancement en mode application ---" -ForegroundColor Cyan
}

# Chemin vers le fichier de mapping
$mappingFilePath = Join-Path -Path $ScriptDir -ChildPath "workspace-mappings.json"
if (-not(Test-Path $mappingFilePath)) {
    Write-Error "Le fichier de mapping '$mappingFilePath' est introuvable."
    exit 1
}

# Charger et combiner les mappings
$mappingsConfig = Get-Content $mappingFilePath -Raw | ConvertFrom-Json
$allMappings = $mappingsConfig.localMappings + $mappingsConfig.cloudMappings + $mappingsConfig.unconfirmedMappings
$mappingLut = @{}
foreach($mapping in $allMappings) {
    if ($mapping.newPath -ne "[NOUVEAU CHEMIN]") {
        $mappingLut[$mapping.oldPath] = $mapping.newPath
    }
}

# Trouver le répertoire des tâches Roo
$tasksDir = ""
if ($IsWindows) {
    $tasksDir = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"
} else {
    # Ajouter le chemin pour Linux/macOS si nécessaire
    Write-Error "Système d'exploitation non supporté pour le moment."
    exit 1
}

if (-not (Test-Path $tasksDir)) {
    Write-Error "Le répertoire des tâches Roo n'a pas été trouvé à l'emplacement attendu."
    exit 1
}

Write-Host "Analyse des tâches dans : $tasksDir"
$taskDirectories = Get-ChildItem -Path $tasksDir -Directory

$remappedCount = 0

foreach ($taskDir in $taskDirectories) {
    $currentWorkspace = Get-TaskWorkspacePath -TaskDirectory $taskDir
    
    if ($mappingLut.ContainsKey($currentWorkspace)) {
        $newWorkspace = $mappingLut[$currentWorkspace]
        Write-Host "Tâche trouvée avec chemin obsolète : $($taskDir.Name)"
        Set-TaskWorkspacePath -TaskDirectory $taskDir -OldPath $currentWorkspace -NewPath $newWorkspace -IsDryRun $DryRun
        $remappedCount++
    }
}

Write-Host "-------------------------------------------"
if ($DryRun) {
    Write-Host "$remappedCount tâches seraient remappées." -ForegroundColor Yellow
} else {
    Write-Host "$remappedCount tâches ont été remappées." -ForegroundColor Cyan
}

[Console]::OutputEncoding = $InitialOutputEncoding
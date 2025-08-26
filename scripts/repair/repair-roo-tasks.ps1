[CmdletBinding(SupportsShouldProcess = $true)]
param()

# --- CONFIGURATION ---
$baseTasksPath = "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"

# --- INITIALISATION ---
$repairedTasksCount = 0
$whatIfPreference = if ($PSCmdlet.ShouldProcess("Système de fichiers", "Appliquer les réparations")) { $false } else { $true }

Write-Host "--- Début du script de réparation des tâches orphelines ---"
Write-Host "Mode de simulation (-WhatIf): $whatIfPreference"
Write-Host "Chemin des tâches: $baseTasksPath"
Write-Host ""

# --- 1. NETTOYAGE DU RÉPERTOIRE .SKELETONS ---
$skeletonsPath = Join-Path -Path $baseTasksPath -ChildPath ".skeletons"

if (Test-Path -Path $skeletonsPath) {
    Write-Host "Nettoyage du répertoire .skeletons..."
    $jsonFilesInSkeletons = Get-ChildItem -Path $skeletonsPath -Filter "*.json" -File
    
    if ($jsonFilesInSkeletons) {
        Write-Host "Trouvé $($jsonFilesInSkeletons.Count) fichier(s) .json à supprimer."
        foreach ($file in $jsonFilesInSkeletons) {
            if ($PSCmdlet.ShouldProcess($file.FullName, "Supprimer le fichier JSON du squelette")) {
                Remove-Item -Path $file.FullName -Force
            }
        }
    } else {
        Write-Host "Aucun fichier .json trouvé dans .skeletons."
    }
} else {
    Write-Warning "Le répertoire .skeletons n'a pas été trouvé. Le nettoyage est ignoré."
}
Write-Host ""

# --- 2. IDENTIFICATION ET RÉPARATION DES TÂCHES ORPHELINES ---
Write-Host "--- Recherche et réparation des tâches orphelines ---"

$taskDirectories = Get-ChildItem -Path $baseTasksPath -Directory | Where-Object { $_.Name -ne ".skeletons" }

foreach ($taskDir in $taskDirectories) {
    $taskDirPath = $taskDir.FullName
    $taskMetadataPath = Join-Path -Path $taskDirPath -ChildPath "task_metadata.json"
    $apiHistoryPath = Join-Path -Path $taskDirPath -ChildPath "api_conversation_history.json"

    $isOrphan = (-not (Test-Path -Path $taskMetadataPath)) -and (Test-Path -Path $apiHistoryPath)

    if ($isOrphan) {
        Write-Host "Tâche orpheline détectée: $($taskDir.Name)"
        
        try {
            # a. Lire et analyser l'historique de conversation
            $historyContent = Get-Content -Path $apiHistoryPath -Raw | ConvertFrom-Json
            
            # b. Extraire les chemins de fichiers uniques
            $filePaths = @() # Initialiser une liste pour stocker les chemins

            if ($null -ne $historyContent.sequence) {
                foreach ($turn in $historyContent.sequence) {
                    if ($turn.content -is [string] -and $turn.content.Length -gt 0) {
                        # Regex pour trouver toutes les occurrences de <path>...</path>
                        $matches = [regex]::Matches($turn.content, '<path>(.*?)</path>')
                        
                        foreach ($match in $matches) {
                            if ($match.Groups.Count -gt 1) {
                                $pathValue = $match.Groups[1].Value.Trim()
                                if (-not [string]::IsNullOrEmpty($pathValue)) {
                                    $filePaths += $pathValue
                                }
                            }
                        }
                    }
                }
            }
            
            $uniqueFilePaths = $filePaths | Where-Object { $_ -ne $null -and $_.Trim() -ne "" } | Sort-Object -Unique

            if ($uniqueFilePaths.Count -eq 0) {
                 Write-Warning "Aucun chemin de fichier trouvé dans l'historique de la tâche $($taskDir.Name). Le fichier de métadonnées sera créé vide."
            }

            # c. Construire la structure JSON pour les métadonnées
            $filesInContext = foreach ($path in $uniqueFilePaths) {
                [PSCustomObject]@{
                    path           = $path
                    record_state   = "active"
                    record_source  = "reconstructed"
                    roo_read_date  = [long](([datetime]::UtcNow).Subtract([datetime]"1970-01-01")).TotalMilliseconds
                    roo_edit_date  = $null
                    user_edit_date = $null
                }
            }

            # d. Envelopper dans l'objet racine
            $metadataObject = @{
                files_in_context = $filesInContext
            }

            # e. Écrire le nouveau task_metadata.json
            $jsonOutput = $metadataObject | ConvertTo-Json -Depth 5
            
            if ($PSCmdlet.ShouldProcess($taskMetadataPath, "Créer le fichier de métadonnées reconstruit")) {
                Set-Content -Path $taskMetadataPath -Value $jsonOutput -Encoding UTF8
                Write-Host " -> Réparation effectuée : task_metadata.json créé pour $($taskDir.Name) avec $($uniqueFilePaths.Count) chemin(s)."
                $repairedTasksCount++
            } else {
                 Write-Host " -> Simulation: La création de task_metadata.json pour $($taskDir.Name) serait effectuée."
            }

        } catch {
            Write-Error "Échec de la réparation de la tâche $($taskDir.Name): $_"
        }
    } else {
        Write-Host "Tâche ignorée (non orpheline): $($taskDir.Name)"
    }
    Write-Host ""
}

# --- 3. RAPPORT FINAL ---
Write-Host "--------------------------------------------------"
Write-Host "Opération terminée."
Write-Host "Nombre total de tâches réparées: $repairedTasksCount"
Write-Host "--------------------------------------------------"
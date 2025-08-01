# modules/Actions.psm1
# Pour le moment, pas besoin d'importer d'autres modules ici

function Invoke-SyncStatusAction {
    [CmdletBinding()]
    param(
        [psobject]$Configuration,
        [hashtable]$Parameters
    )
    
    Write-Host "--- Début de l'action Status ---"
    
    $dashboard = Get-SyncDashboard
    if ($null -eq $dashboard) {
        Write-Host "Le dashboard est actuellement vide ou introuvable."
    } else {
        Write-Host "État du dashboard (version $($dashboard.version)):"
        $dashboard.environments | Format-Table -AutoSize
    }

    Write-Host "--- Fin de l'action Status ---"
}


function Compare-Config {
    [CmdletBinding()]
    param(
        [psobject]$Configuration
    )

    Write-Host "--- Début de l'action Compare-Config ---"

    $sharedPath = [System.Environment]::ExpandEnvironmentVariables($Configuration.sharedStatePath)
    if (-not (Test-Path $sharedPath -PathType Container)) {
        Write-Host "Vérification du dossier partagé : $sharedPath"
        if (-not (Test-Path $sharedPath)) {
            Write-Host "Le dossier n'existe pas, tentative de création..."
            New-Item -Path $sharedPath -ItemType Directory -Force
        }
    }

    $roadmapPath = Join-Path -Path $sharedPath -ChildPath "sync-roadmap.md"
    if (-not (Test-Path $roadmapPath)) {
        Write-Host "Création de la feuille de route : $roadmapPath"
        $roadmapHeader = "# 🗺️ Feuille de Route de Synchronisation - RUSH-SYNC`n`n**Dernière mise à jour :** $(Get-Date -Format 'u')`n**Statut global :** `0` décision(s) en attente.`n`n---`n`n## 📥 Actions en Attente`n"
        Set-Content -Path $roadmapPath -Value $roadmapHeader
    }

    $localConfigPath = 'config/sync-config.json'
    $refConfigPath = Join-Path -Path $sharedPath -ChildPath "sync-config.ref.json"

    if (-not (Test-Path $refConfigPath)) {
        Write-Host "Aucune configuration de référence trouvée. La configuration locale devient la référence : $refConfigPath"
        Copy-Item -Path $localConfigPath -Destination $refConfigPath -Force
    }

    $refObject = Get-Content $refConfigPath | ConvertFrom-Json
    $diffObject = Get-Content $localConfigPath | ConvertFrom-Json

    # Résoudre les variables d'environnement avant la comparaison
    $refObject.sharedStatePath = [System.Environment]::ExpandEnvironmentVariables($refObject.sharedStatePath)
    $diffObject.sharedStatePath = [System.Environment]::ExpandEnvironmentVariables($diffObject.sharedStatePath)

    $diff = Compare-Object -ReferenceObject ($refObject | ConvertTo-Json -Depth 100) -DifferenceObject ($diffObject | ConvertTo-Json -Depth 100)

    if ($diff) {
        $timestamp = Get-Date -Format 'u'
        $machineName = $env:COMPUTERNAME
        $diffBlock = @"

### <!-- DECISION_BLOCK_START ID=config-sync-$($timestamp) -->
**Objet :** Différence de configuration détectée
**Détecté par :** `$machineName`
**Date :** `$timestamp`

**Résumé :** Une différence a été détectée entre la configuration locale et la configuration de référence.

**Différences :**
```diff
$($diff | ConvertTo-Json -Depth 100)
```

**Actions Proposées :**
- `[ ]` **Approuver & Fusionner :** Mettre à jour la configuration de référence avec les changements locaux.
### <!-- DECISION_BLOCK_END -->
"@
        Add-Content -Path $roadmapPath -Value $diffBlock
        Write-Host "Différence de configuration consignée dans la feuille de route."
    } else {
        Write-Host "Les configurations sont identiques. Aucune action requise."
    }

    Write-Host "--- Fin de l'action Compare-Config ---"
}

function Apply-Decisions {
    [CmdletBinding()]
    param(
        [psobject]$Configuration
    )

    Write-Host "--- Début de l'action Apply-Decisions ---"

    $sharedPath = [System.Environment]::ExpandEnvironmentVariables($Configuration.sharedStatePath)
    $roadmapPath = Join-Path -Path $sharedPath -ChildPath "sync-roadmap.md"

    if (-not (Test-Path $roadmapPath)) {
        Write-Error "La feuille de route 'sync-roadmap.md' est introuvable."
        return
    }

    $roadmapContent = Get-Content -Path $roadmapPath -Raw

    $decisionBlockRegex = '(?s)<!--\s*DECISION_BLOCK_START\s*ID=(?<ID>.*?)SAPERLIPOPETTE(?<BlockContent>.*?)- \[x\] \*\*Approuver & Fusionner\*\*.*?)<!--\s*DECISION_BLOCK_END\s*-->'
    $decisionBlockRegex = '(?s)<!--\s*DECISION_BLOCK_START(?<BlockContent>.*?- \[x\] \*\*Approuver & Fusionner\*\*.*?)<!--\s*DECISION_BLOCK_END\s*-->'
    
    $decisionBlockRegex = '(?s)(<!--\s*DECISION_BLOCK_START.*?-->)(.*?\[x\].*?Approuver & Fusionner.*?)(<!--\s*DECISION_BLOCK_END\s*-->)'


    $match = [regex]::Match($roadmapContent, $decisionBlockRegex)

    if ($match.Success) {
        Write-Host "Décision approuvée trouvée. Application en cours..."

        $localConfigPath = 'config/sync-config.json'
        $refConfigPath = Join-Path -Path $sharedPath -ChildPath "sync-config.ref.json"

        try {
            Copy-Item -Path $localConfigPath -Destination $refConfigPath -Force -ErrorAction Stop
            Write-Host "Configuration de référence mise à jour avec succès."

            $updatedBlock = $match.Groups[1].Value.Replace("DECISION_BLOCK_START", "DECISION_BLOCK_ARCHIVED")
            $newRoadmapContent = $roadmapContent.Replace($match.Groups[1].Value, $updatedBlock)

            Set-Content -Path $roadmapPath -Value $newRoadmapContent -Force
            Write-Host "La feuille de route a été mise à jour et la décision a été archivée."

        } catch {
            Write-Error "Échec de l'application de la décision : $_"
        }
    } else {
        Write-Host "Aucune décision approuvée à appliquer."
    }

    Write-Host "--- Fin de l'action Apply-Decisions ---"
}

function Initialize-Workspace {
    [CmdletBinding()]
    param(
        [psobject]$config
    )

    Write-Host "--- Début de l'action Initialize-Workspace ---"

    $sharedPath = $config.sharedStatePath
    Write-Host "Initialisation de l'espace de travail partagé : $sharedPath"

    if (-not (Test-Path $sharedPath -PathType Container)) {
        Write-Host "Le dossier partagé n'existe pas, création en cours..."
        try {
            New-Item -Path $sharedPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Host "Dossier partagé créé avec succès."
        } catch {
            Write-Error "Impossible de créer le dossier partagé à l'emplacement : $sharedPath. Vérifiez les permissions."
            return
        }
    }

    # Fichiers à créer
    $filesToCreate = @{
        "sync-config.ref.json" = { Copy-Item -Path 'config/sync-config.json' -Destination (Join-Path $sharedPath "sync-config.ref.json") -Force };
        "sync-roadmap.md"      = { Set-Content -Path (Join-Path $sharedPath "sync-roadmap.md") -Value "# Roadmap de Synchronisation RUSH-SYNC" };
        "sync-dashboard.json"  = { Set-Content -Path (Join-Path $sharedPath "sync-dashboard.json") -Value '{ "lastSync": null, "status": "uninitialized" }' };
        "sync-report.md"       = { Set-Content -Path (Join-Path $sharedPath "sync-report.md") -Value "# Rapport de Synchronisation RUSH-SYNC" };
    }

    foreach ($file in $filesToCreate.GetEnumerator()) {
        $filePath = Join-Path $sharedPath $file.Name
        if (-not (Test-Path $filePath)) {
            Write-Host "Création du fichier manquant : $($file.Name)"
            try {
                & $file.Value
            } catch {
                Write-Error "Erreur lors de la création du fichier $($file.Name) : $_"
            }
        } else {
            Write-Host "Le fichier $($file.Name) existe déjà."
        }
    }

    Write-Host "--- Fin de l'action Initialize-Workspace ---"
}
Export-ModuleMember -Function Invoke-SyncStatusAction, Compare-Config, Initialize-Workspace, Apply-Decisions
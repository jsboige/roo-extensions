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

    $sharedPath = $Configuration.sharedStatePath
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

    $diff = Compare-Object -ReferenceObject (Get-Content $refConfigPath | ConvertFrom-Json) -DifferenceObject (Get-Content $localConfigPath | ConvertFrom-Json) | ConvertTo-Json

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
$diff
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
Export-ModuleMember -Function Invoke-SyncStatusAction, Compare-Config
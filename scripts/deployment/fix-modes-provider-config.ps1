# Script pour corriger la configuration des providers dans les modes
# Corrige le champ "model" pour utiliser les bons providers:
# - complex → "default" (Z.AI souscription, GLM-4.7)
# - simple → "simple" (provider maison xx.myia.io, GLM-4.7 Flash)

param(
    [Parameter(Mandatory=$false)]
    [string]$CustomModesPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json",

    [Parameter(Mandatory=$false)]
    [switch]$Backup = $true,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Correction de la configuration des providers modes" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fichier cible: $CustomModesPath" -ForegroundColor Yellow
Write-Host ""

# Vérifier que le fichier existe
if (-not (Test-Path $CustomModesPath)) {
    Write-Host "ERREUR: Le fichier $CustomModesPath n'existe pas." -ForegroundColor Red
    exit 1
}

# Backup si demandé
if ($Backup -and -not $WhatIf) {
    $backupPath = "$CustomModesPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $CustomModesPath $backupPath -Force
    Write-Host "✓ Backup créé: $backupPath" -ForegroundColor Green
    Write-Host ""
}

# Lire le fichier JSON
try {
    $jsonContent = Get-Content $CustomModesPath -Raw -Encoding UTF8
    $modesData = ConvertFrom-Json $jsonContent
} catch {
    Write-Host "ERREUR: Impossible de lire le fichier JSON: $_" -ForegroundColor Red
    exit 1
}

if (-not $modesData.customModes) {
    Write-Host "ERREUR: Le fichier ne contient pas de propriété 'customModes'" -ForegroundColor Red
    exit 1
}

Write-Host "Modes trouvés: $($modesData.customModes.Count)" -ForegroundColor Cyan
Write-Host ""

# Compteurs
$changedComplex = 0
$changedSimple = 0
$unchanged = 0

# Parcourir tous les modes et corriger les providers
foreach ($mode in $modesData.customModes) {
    $slug = $mode.slug
    $currentModel = $mode.model

    # Déterminer le nouveau provider selon le slug
    $newModel = $null
    if ($slug -match '-complex$') {
        # Modes complex → provider "default"
        $newModel = "default"
    } elseif ($slug -match '-simple$') {
        # Modes simple → provider "simple"
        $newModel = "simple"
    }

    # Appliquer le changement si nécessaire
    if ($newModel -and $currentModel -ne $newModel) {
        Write-Host "[$slug]" -ForegroundColor Yellow
        Write-Host "  Ancien: $currentModel" -ForegroundColor Red
        Write-Host "  Nouveau: $newModel" -ForegroundColor Green

        if (-not $WhatIf) {
            $mode.model = $newModel
        }

        if ($newModel -eq "default") {
            $changedComplex++
        } else {
            $changedSimple++
        }
    } elseif ($newModel) {
        $unchanged++
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Résumé des modifications:" -ForegroundColor Cyan
Write-Host "  - Modes complex → 'default': $changedComplex" -ForegroundColor $(if ($changedComplex -gt 0) { "Green" } else { "Gray" })
Write-Host "  - Modes simple → 'simple': $changedSimple" -ForegroundColor $(if ($changedSimple -gt 0) { "Green" } else { "Gray" })
Write-Host "  - Inchangés: $unchanged" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Sauvegarder le fichier modifié
if (-not $WhatIf) {
    if ($changedComplex -gt 0 -or $changedSimple -gt 0) {
        try {
            # Convertir en JSON et sauvegarder avec encodage UTF-8 sans BOM
            $jsonOutput = ConvertTo-Json -InputObject $modesData -Depth 100
            [System.IO.File]::WriteAllText($CustomModesPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))

            Write-Host "✓ Fichier sauvegardé avec succès" -ForegroundColor Green
            Write-Host ""
            Write-Host "IMPORTANT: Redémarrez Visual Studio Code pour appliquer les changements." -ForegroundColor Yellow
        } catch {
            Write-Host "ERREUR: Impossible de sauvegarder le fichier: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Aucune modification nécessaire." -ForegroundColor Gray
    }
} else {
    Write-Host "Mode WhatIf: Aucune modification appliquée." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan

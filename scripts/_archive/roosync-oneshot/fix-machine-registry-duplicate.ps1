<#
.SYNOPSIS
    Corrige le doublon case-sensitive MyIA-Web1 vs myia-web1 dans le registre machine

.DESCRIPTION
    Script pour résoudre l'issue #460 - Doublon case-sensitive dans .machine-registry.json
    Supprime l'entrée "MyIA-Web1" et garde "myia-web1"

.NOTES
    Issue: #460
    Date: 2026-02-12
    Author: Claude Code (myia-po-2024)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Chemin du registre machine
$registryPath = "G:/Mon Drive/Synchronisation/RooSync/.shared-state/.machine-registry.json"

Write-Host "🔧 Fix doublon MyIA-Web1 vs myia-web1" -ForegroundColor Cyan
Write-Host ""

# Vérifier que le fichier existe
if (-not (Test-Path $registryPath)) {
    Write-Error "Fichier non trouvé : $registryPath"
    exit 1
}

# Backup du fichier original
$backupPath = "$registryPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $registryPath $backupPath
Write-Host "✅ Backup créé : $backupPath" -ForegroundColor Green

# Charger le JSON en texte brut
$jsonText = Get-Content $registryPath -Raw

# Compter les occurrences de machine IDs
$machineIds = @()
if ($jsonText -match '"machines":\s*\{([^}]+)\}') {
    $machinesSection = $matches[1]
    $machineIds = [regex]::Matches($machinesSection, '"([^"]+)":\s*\{') | ForEach-Object { $_.Groups[1].Value }
}

$beforeCount = $machineIds.Count
Write-Host "📊 Machines avant : $beforeCount"

# Afficher les machines avec leur casse
Write-Host ""
Write-Host "Machines actuelles :"
foreach ($machineId in $machineIds) {
    $isTarget = $machineId -eq "MyIA-Web1"
    $color = if ($isTarget) { "Yellow" } else { "Gray" }
    $marker = if ($isTarget) { " ← À SUPPRIMER" } else { "" }
    Write-Host "  - $machineId$marker" -ForegroundColor $color
}

# Vérifier si MyIA-Web1 existe
if ($machineIds -contains "MyIA-Web1") {
    # Extraire l'entrée complète MyIA-Web1 (avec son contenu entre accolades)
    $pattern = '"MyIA-Web1":\s*\{[^}]+\},?\s*'

    if ($jsonText -match $pattern) {
        $entryToRemove = $matches[0]
        Write-Host ""
        Write-Host "Entrée à supprimer :" -ForegroundColor Yellow
        Write-Host $entryToRemove -ForegroundColor Gray

        # Supprimer l'entrée
        $jsonText = $jsonText -replace $pattern, ''

        # Nettoyer les doubles virgules qui pourraient rester
        $jsonText = $jsonText -replace ',\s*,', ','
        $jsonText = $jsonText -replace ',(\s*\})', '$1'

        Write-Host ""
        Write-Host "✅ Entrée 'MyIA-Web1' supprimée" -ForegroundColor Green
    } else {
        Write-Warning "⚠️  Pattern non trouvé pour MyIA-Web1"
    }
} else {
    Write-Host ""
    Write-Warning "⚠️  'MyIA-Web1' non trouvée dans le registre"
}

# Mettre à jour lastUpdated
$now = (Get-Date).ToUniversalTime().ToString("o")
$jsonText = $jsonText -replace '"lastUpdated":\s*"[^"]+"', "`"lastUpdated`": `"$now`""

# Compter les machines après
$machineIdsAfter = @()
if ($jsonText -match '"machines":\s*\{([^}]+)\}') {
    $machinesSection = $matches[1]
    $machineIdsAfter = [regex]::Matches($machinesSection, '"([^"]+)":\s*\{') | ForEach-Object { $_.Groups[1].Value }
}
$afterCount = $machineIdsAfter.Count
Write-Host "📊 Machines après : $afterCount"

# Sauvegarder
Set-Content $registryPath -Value $jsonText -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "✅ Registre mis à jour : $afterCount machines (attendu: 6)" -ForegroundColor Green
Write-Host "📁 Fichier : $registryPath"
Write-Host ""

# Validation
if ($afterCount -eq 6) {
    Write-Host "✅ SUCCÈS : 6 machines dans le registre" -ForegroundColor Green
    exit 0
} else {
    Write-Warning "⚠️  Attention : $afterCount machines au lieu de 6 attendues"
    exit 1
}

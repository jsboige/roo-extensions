<#
.SYNOPSIS
    Script d'organisation des rapports RooSync SDDD
.DESCRIPTION
    Organise les rapports RooSync dans les répertoires structurés selon les principes SDDD
.PARAMETER Force
    Force la réorganisation même si les fichiers existent déjà
.EXAMPLE
    .\organize-roosync-reports.ps1
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

Write-Host "🔄 Organisation des rapports RooSync SDDD" -ForegroundColor Cyan

# Chemins des répertoires
$ReportsSource = "docs/roosync"
$ReportsDest = "docs/roosync/reports-sddd"
$TransientsDest = "scripts/transients"

# Créer les répertoires de destination s'ils n'existent pas
if (-not (Test-Path $ReportsDest)) {
    New-Item -ItemType Directory -Path $ReportsDest -Force | Out-Null
    Write-Host "✅ Créé: $ReportsDest" -ForegroundColor Green
}

if (-not (Test-Path $TransientsDest)) {
    New-Item -ItemType Directory -Path $TransientsDest -Force | Out-Null
    Write-Host "✅ Créé: $TransientsDest" -ForegroundColor Green
}

# Mapping des rapports SDDD à organiser
$SddReports = @{
    "rapport-mission-sddd-pull-rebuild-complet-20251026.md" = "04-pull-rebuild-complet-20251026.md"
    "rapport-terminaison-sddd-ultime-roosync-v2.1-20251102.md" = "05-terminaison-ultime-20251102.md"
    "rapport-validation-sddd-roosync-v2.1-20251102.md" = "06-validation-roosync-v2.1-20251102.md"
}

# Organiser les rapports SDDD
Write-Host "`n📁 Organisation des rapports SDDD..." -ForegroundColor Yellow
foreach ($report in $SddReports.GetEnumerator()) {
    $sourcePath = Join-Path $ReportsSource $report.Key
    $destPath = Join-Path $ReportsDest $report.Value
    
    if (Test-Path $sourcePath) {
        if ((Test-Path $destPath) -and -not $Force) {
            Write-Host "⚠️  Existe déjà: $($report.Value)" -ForegroundColor Yellow
        } else {
            Move-Item $sourcePath $destPath -Force
            Write-Host "✅ Déplacé: $($report.Key) → $($report.Value)" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Non trouvé: $($report.Key)" -ForegroundColor Red
    }
}

# Scripts transients à organiser
$TransientScripts = @{
    "scripts/roosync/22B-execute-mcp-cleanup-20251024.ps1" = "mcp-cleanup-20251024.ps1"
    "scripts/roosync/22B-inventory-mcp-cleanup-20251024.ps1" = "inventory-mcp-cleanup-20251024.ps1"
    "scripts/roosync/22B-mcp-cleanup-report-20251024.md" = "mcp-cleanup-report-20251024.md"
}

# Organiser les scripts transients
Write-Host "`n📁 Organisation des scripts transients..." -ForegroundColor Yellow
foreach ($script in $TransientScripts.GetEnumerator()) {
    $sourcePath = $script.Key
    $destPath = Join-Path $TransientsDest $script.Value
    
    if (Test-Path $sourcePath) {
        if ((Test-Path $destPath) -and -not $Force) {
            Write-Host "⚠️  Existe déjà: $($script.Value)" -ForegroundColor Yellow
        } else {
            Move-Item $sourcePath $destPath -Force
            Write-Host "✅ Déplacé: $($script.Key) → $($script.Value)" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Non trouvé: $($script.Key)" -ForegroundColor Red
    }
}

Write-Host "`n📊 Résumé de l'organisation:" -ForegroundColor Cyan
Write-Host "  - Rapports SDDD organisés: $($SddReports.Count)" -ForegroundColor White
Write-Host "  - Scripts transients organisés: $($TransientScripts.Count)" -ForegroundColor White
Write-Host "  - Répertoire rapports: $ReportsDest" -ForegroundColor White
Write-Host "  - Répertoire transients: $TransientsDest" -ForegroundColor White

Write-Host "`n✅ Organisation terminée !" -ForegroundColor Green
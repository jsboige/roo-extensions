# scripts/roosync/production-tests/compare-test-results.ps1
# Comparaison des résultats de tests (JSON/XML) pour validation de non-régression

param(
    [Parameter(Mandatory=$true)]
    [string]$ReferenceFile,

    [Parameter(Mandatory=$true)]
    [string]$TargetFile,

    [string]$OutputReport = "comparison-report.md"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor ($Level -eq "ERROR" ? "Red" : ($Level -eq "WARNING" ? "Yellow" : "Cyan"))
}

Write-Log "Comparaison des résultats: $ReferenceFile vs $TargetFile"

if (-not (Test-Path $ReferenceFile) -or -not (Test-Path $TargetFile)) {
    Write-Log "Fichier(s) introuvable(s)." "ERROR"
    exit 1
}

try {
    $refData = Get-Content $ReferenceFile | ConvertFrom-Json
    $targetData = Get-Content $TargetFile | ConvertFrom-Json
} catch {
    Write-Log "Erreur lors du parsing JSON: $_" "ERROR"
    exit 1
}

# Comparaison basique
$diffs = Compare-Object -ReferenceObject $refData -DifferenceObject $targetData -Property Status, TotalOperations, SuccessCount, ConflictCount -PassThru

$reportContent = @"
# Rapport de Comparaison de Tests

**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Référence:** $ReferenceFile
**Cible:** $TargetFile

## Résumé

"@

if ($null -eq $diffs) {
    $reportContent += "`n✅ **Aucune différence significative détectée.** Les résultats sont identiques."
    Write-Log "Aucune différence détectée."
} else {
    $reportContent += "`n⚠️ **Différences détectées:**`n"
    foreach ($diff in $diffs) {
        $side = if ($diff.SideIndicator -eq "<=") { "Référence" } else { "Cible" }
        $reportContent += "- **$side**: Status=$($diff.Status), Total=$($diff.TotalOperations), Success=$($diff.SuccessCount), Conflicts=$($diff.ConflictCount)`n"
    }
    Write-Log "Différences détectées. Voir rapport." "WARNING"
}

$reportContent | Set-Content $OutputReport -Encoding Utf8
Write-Log "Rapport généré: $OutputReport"
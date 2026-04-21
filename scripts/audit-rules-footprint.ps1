# Script d'audit de la footprint des règles auto-chargées
# Usage: powershell -ExecutionPolicy Bypass -File scripts/audit-rules-footprint.ps1

param (
    [switch]$Quick = $false
)

# Calculer la taille totale des règles
$rulesDir = ".claude/rules"
$files = Get-ChildItem -Path $rulesDir -Filter "*.md" | Where-Object { $_.Name -notin @("MEMORY.md", "CLAUDE.md") }

$totalBytes = 0
$totalLines = 0
$filesInfo = @()

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    $bytes = [System.Text.Encoding]::UTF8.GetByteCount($content)
    $lines = $content.Split("`n").Count

    $totalBytes += $bytes
    $totalLines += $lines

    $filesInfo += [PSCustomObject]@{
        Name = $file.Name
        Bytes = $bytes
        Lines = $lines
        SizeKB = [math]::Round($bytes / 1KB, 2)
        AvgTokenRate = if ($lines -gt 0) { [math]::Round($bytes / $lines, 2) } else { 0 }
    }
}

# Estimation tokens (approximation: 1 token = 4 bytes)
$estimatedTokens = [math]::Round($totalBytes / 4, 0)

# Afficher les résultats
Write-Host "`n=== Audit des règles auto-chargées .claude/rules/ ===" -ForegroundColor Green
Write-Host "Fichiers analysés: $($files.Count)"
Write-Host "Taille totale: $totalBytes bytes (~$([math]::Round($totalBytes / 1KB, 1)) KB)"
Write-Host "Lignes totales: $totalLines"
Write-Host "Tokens estimés: ~$estimatedTokens"

# Statistiques
$largeFiles = $filesInfo | Where-Object { $_.Bytes -gt 1024 * 80 } # > 80KB
$mediumFiles = $filesInfo | Where-Object { $_.Bytes -gt 1024 * 30 -and $_.Bytes -le 1024 * 80 } # 30-80KB
$smallFiles = $filesInfo | Where-Object { $_.Bytes -le 1024 * 30 } # < 30KB

Write-Host "`nDistribution par taille:" -ForegroundColor Yellow
if ($largeFiles.Count -gt 0) {
    Write-Host "  Fichiers >80KB: $($largeFiles.Count) files"
    $largeFiles | ForEach-Object { Write-Host "    - $($_.Name): $($_.SizeKB)KB" }
}
if ($mediumFiles.Count -gt 0) {
    Write-Host "  Fichiers 30-80KB: $($mediumFiles.Count) files"
    $mediumFiles | ForEach-Object { Write-Host "    - $($_.Name): $($_.SizeKB)KB" }
}
Write-Host "  Fichiers <30KB: $($smallFiles.Count) files"

# Files sorted by size (descending)
Write-Host "`nFichiers triés par taille (décroissant):" -ForegroundColor Yellow
$filesInfo | Sort-Object -Property Bytes -Descending | ForEach-Object {
    Write-Host "  - $($_.Name): $($_.SizeKB)KB ($($_.Lines) lignes)"
}

# Recommendations
Write-Host "`nRecommandations:" -ForegroundColor Cyan
if ($totalBytes -gt 1024 * 50) {
    Write-Host "  [!] La totalité dépasse 50KB - consolidation recommandée"
}
if ($largeFiles.Count -gt 0) {
    Write-Host "  [!] Plusieurs fichiers >80KB - envisager une fusion ou déplacement"
}

if (-not $Quick) {
    # Rapport détaillé
    Write-Host "`n=== Rapport détaillé ===" -ForegroundColor Green
    $filesInfo | Format-Table -AutoSize | Out-Host
}

# Générer un résumé pour docs/harness/reference/rules-footprint.md
$summary = @"
# Audit des règles auto-chargées

**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Audit par:** audit-rules-footprint.ps1

## Metrics actuelles

| Métrique | Valeur |
|---|---|
| Fichiers auto-chargés | $($files.Count) |
| Taille totale | $totalBytes bytes (~$([math]::Round($totalBytes / 1KB, 1)) KB) |
| Lignes totales | $totalLines |
| Tokens estimés (boot) | ~$estimatedTokens |

## Files distribution

| Taille | Nombre | |
|---|---|---|
| >80KB | $($largeFiles.Count) | $(if ($largeFiles.Count -gt 0) { "$(($largeFiles | Measure-Object -Property Sum -Sum).Sum / 1KB)KB total" }) |
| 30-80KB | $($mediumFiles.Count) | $(if ($mediumFiles.Count -gt 0) { "$(($mediumFiles | Measure-Object -Property Sum -Sum).Sum / 1KB)KB total" }) |
| <30KB | $($smallFiles.Count) | $(if ($smallFiles.Count -gt 0) { "$(($smallFiles | Measure-Object -Property Sum -Sum).Sum / 1KB)KB total" }) |

## Top files par taille

$(($filesInfo | Sort-Object -Property Bytes -Descending | Select-Object -First 5) | ForEach-Object { " - $($_.Name): $($_.SizeKB)KB" } -join "`n")

## Phase 2 - Proposed consolidations

1. **skepticism-protocol.md** (41L) + **agent-claim-discipline.md** (108L) → **verification-discipline.md** (~80L)
2. **no-deletion-without-proof.md** (37L) + **validation.md** (34L) → **change-safety.md** (~50L)
3. **intercom-protocol.md** (132L) + **friction-protocol.md** (67L) → **dashboard-protocol.md** (~100L)

**Gains estimés:** -286 lignes (~12KB)

---
"@

# Sauvegarder le rapport
$summary | Out-File -FilePath "docs/harness/reference/rules-footprint.md" -Encoding UTF8NoBOM
Write-Host "`nRapport sauvegardé dans: docs/harness/reference/rules-footprint.md" -ForegroundColor Green
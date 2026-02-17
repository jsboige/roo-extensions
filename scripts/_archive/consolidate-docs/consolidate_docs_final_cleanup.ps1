$ErrorActionPreference = "Stop"
$destBase = "docs/suivi/Mission_Legacy_Rapports"

Write-Host "Moving remaining files from docs/rapports..."

# Déplacement récursif du reste de docs/rapports
Get-ChildItem "docs/rapports" -Recurse | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
    # Calcul du chemin relatif
    $relativePath = $_.FullName.Substring((Get-Item "docs/rapports").FullName.Length + 1)
    $destPath = Join-Path $destBase $relativePath
    $destDir = Split-Path $destPath -Parent

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    if (-not (Test-Path $destPath)) {
        Move-Item -Path $_.FullName -Destination $destPath
        Write-Host "Moved $relativePath"
    } else {
        Write-Warning "File exists: $destPath. Renaming source..."
        $newName = $_.BaseName + "_legacy_" + (Get-Date -Format "yyyyMMddHHmmss") + $_.Extension
        $destPathRenamed = Join-Path $destDir $newName
        Move-Item -Path $_.FullName -Destination $destPathRenamed
        Write-Host "Moved $relativePath to $newName"
    }
}

# Suppression finale de docs/rapports
Remove-Item "docs/rapports" -Recurse -Force -ErrorAction SilentlyContinue
if (-not (Test-Path "docs/rapports")) {
    Write-Host "docs/rapports removed successfully."
} else {
    Write-Warning "docs/rapports could not be fully removed."
}
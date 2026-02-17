$ErrorActionPreference = "Stop"
$destBase = "docs/suivi"

# Création des dossiers supplémentaires
$folders = @(
    "Mission_Guides",
    "Mission_Tasks_HighLevel",
    "Mission_Legacy_Archives"
)
foreach ($f in $folders) {
    $path = Join-Path $destBase $f
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

# Fonction Move-Doc simplifiée
function Move-Item-Safe {
    param($Source, $Dest)
    if (Test-Path $Source) {
        if (-not (Test-Path $Dest)) {
            Move-Item -Path $Source -Destination $Dest
            Write-Host "Moved $Source to $Dest"
        } else {
            Write-Warning "Destination exists: $Dest. Skipping $Source"
        }
    }
}

Write-Host "Cleaning sddd-tracking/scripts-transient..."
if (-not (Test-Path "archive/scripts-transient")) { New-Item -ItemType Directory -Path "archive/scripts-transient" -Force | Out-Null }
Get-ChildItem "sddd-tracking/scripts-transient/*" | ForEach-Object {
    Move-Item-Safe $_.FullName ("archive/scripts-transient/" + $_.Name)
}

Write-Host "Cleaning sddd-tracking/synthesis-docs..."
Get-ChildItem "sddd-tracking/synthesis-docs/*.md" | ForEach-Object {
    Move-Item-Safe $_.FullName ("docs/suivi/Mission_Guides/" + $_.Name)
}

Write-Host "Cleaning sddd-tracking/tasks-high-level..."
# On déplace les fichiers à la racine de tasks-high-level
Get-ChildItem "sddd-tracking/tasks-high-level/*.md" | ForEach-Object {
    Move-Item-Safe $_.FullName ("docs/suivi/Mission_Tasks_HighLevel/" + $_.Name)
}
# Et les sous-dossiers
Get-ChildItem "sddd-tracking/tasks-high-level/*" | Where-Object { $_.PSIsContainer } | ForEach-Object {
    $destPath = "docs/suivi/Mission_Tasks_HighLevel/" + $_.Name
    if (-not (Test-Path $destPath)) {
        Move-Item -Path $_.FullName -Destination $destPath
        Write-Host "Moved directory $($_.Name) to $destPath"
    } else {
        Write-Warning "Directory exists: $destPath. Skipping $($_.FullName)"
    }
}

Write-Host "Cleaning reports/archive..."
Get-ChildItem "reports/archive/*.md" | ForEach-Object {
    Move-Item-Safe $_.FullName ("docs/suivi/Mission_Legacy_Archives/" + $_.Name)
}

Write-Host "Cleaning reports/roo-state-manager-repair..."
if (-not (Test-Path "archive/scripts-repair-2025-11-04")) { New-Item -ItemType Directory -Path "archive/scripts-repair-2025-11-04" -Force | Out-Null }
Get-ChildItem "reports/roo-state-manager-repair-2025-11-04/*" | ForEach-Object {
    Move-Item-Safe $_.FullName ("archive/scripts-repair-2025-11-04/" + $_.Name)
}

Write-Host "Removing empty directories..."
Remove-Item "sddd-tracking" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "reports" -Recurse -Force -ErrorAction SilentlyContinue
# docs/rapports devrait être vide maintenant, sauf s'il y avait des fichiers non-md
if (Test-Path "docs/rapports") {
    $remaining = Get-ChildItem "docs/rapports" -Recurse
    if ($remaining.Count -eq 0) {
        Remove-Item "docs/rapports" -Recurse -Force
        Write-Host "Removed docs/rapports"
    } else {
        Write-Warning "docs/rapports is not empty:"
        $remaining | Select-Object FullName
    }
}

Write-Host "Cleanup complete."
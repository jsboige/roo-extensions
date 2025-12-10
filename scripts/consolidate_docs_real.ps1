$ErrorActionPreference = "Stop"

# Création des dossiers cibles
$destBase = "docs/suivi"
$folders = @(
    "Mission_Anomalies_2025-10",
    "Mission_Git_Cleanup_2025-10",
    "Mission_RooSync_Init_2025-11",
    "Mission_RooStateManager_2025-11",
    "Mission_Web_2025-12",
    "Mission_Reports_Consolidated",
    "Mission_Docs_Root",
    "Mission_RooSync_Operations",
    "Mission_Tests_Results",
    "Mission_Legacy_Rapports"
)

foreach ($f in $folders) {
    $path = Join-Path $destBase $f
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "Created $path"
    }
}

# Fonction de déplacement sécurisé avec renommage automatique si date présente
function Move-Doc {
    param($Source, $DestFolder)
    if (Test-Path $Source) {
        $file = Get-Item $Source
        $destPath = Join-Path $destBase $DestFolder

        # Tentative de normalisation du nom
        $newName = $file.Name
        if ($file.Name -match "^(\d{2})-(.+)-(\d{4}-\d{2}-\d{2})\.md$") {
            # Format: 04-MISSION-REPORT...-2025-10-26.md -> 2025-10-26_004_MISSION-REPORT...md
            $id = $matches[1]
            $desc = $matches[2]
            $date = $matches[3]
            $newName = "${date}_${id}_${desc}.md"
        } elseif ($file.Name -match "^(.+)-(\d{4}-\d{2}-\d{2})\.md$") {
             # Format: ...-2025-10-26.md -> 2025-10-26_000_...md
             $desc = $matches[1]
             $date = $matches[2]
             $newName = "${date}_000_${desc}.md"
        }

        $destFile = Join-Path $destPath $newName

        if (-not (Test-Path $destFile)) {
            Move-Item -Path $Source -Destination $destFile
            Write-Host "Moved $($file.Name) to $destFolder\$newName"
        } else {
            Write-Warning "File exists: $destFile. Skipping $Source"
        }
    }
}

Write-Host "Processing sddd-tracking..."
Get-ChildItem "sddd-tracking/*.md" | Where-Object { $_.Name -ne "README.md" } | ForEach-Object {
    Move-Doc $_.FullName "Mission_Reports_Consolidated"
}

Write-Host "Processing reports..."
Get-ChildItem "reports/*.md" | ForEach-Object {
    Move-Doc $_.FullName "Mission_Reports_Consolidated"
}

Write-Host "Processing docs/ root..."
Get-ChildItem "docs/*.md" | Where-Object { $_.Name -match "\d{4}-\d{2}-\d{2}" } | ForEach-Object {
    Move-Doc $_.FullName "Mission_Docs_Root"
}

Write-Host "Processing RooSync/..."
Get-ChildItem "RooSync/*.md" | Where-Object { $_.Name -match "\d{4}-\d{2}-\d{2}" } | ForEach-Object {
    Move-Doc $_.FullName "Mission_RooSync_Operations"
}

Write-Host "Processing tests/results/..."
Get-ChildItem "tests/results/*.md" | Where-Object { $_.Name -match "\d{4}-\d{2}-\d{2}" } | ForEach-Object {
    Move-Doc $_.FullName "Mission_Tests_Results"
}

Write-Host "Processing docs/rapports/..."
Get-ChildItem "docs/rapports/*.md" -Recurse | ForEach-Object {
    Move-Doc $_.FullName "Mission_Legacy_Rapports"
}

Write-Host "Consolidation complete."
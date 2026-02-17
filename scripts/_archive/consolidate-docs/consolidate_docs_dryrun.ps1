# Script de simulation de consolidation documentaire
# Auteur: Roo Architect
# Date: 2025-12-09

$sourceDirs = @("docs", "reports", "sddd-tracking", "mcps")
$targetBase = "docs/suivi"
$reportFile = "consolidation_plan.csv"

# Regex patterns
$dateRegex = "(202[3-5])[-_](0[1-9]|1[0-2])[-_](0[1-9]|[12][0-9]|3[01])"
$filesToProcess = @()

# 1. Collect files
Write-Host "Collecte des fichiers..."
foreach ($dir in $sourceDirs) {
    if (Test-Path $dir) {
        $files = Get-ChildItem -Path $dir -Recurse -Filter "*.md" -File
        foreach ($file in $files) {
            # Exclusions (docs pérennes)
            if ($file.FullName -match "\\docs\\architecture\\" -or
                $file.FullName -match "\\docs\\specifications\\" -or
                $file.FullName -match "\\docs\\guides\\" -or
                $file.FullName -match "\\docs\\templates\\") {
                continue
            }

            # On ne traite que ce qui ressemble à un rapport/suivi
            if ($file.FullName -match "\\docs\\suivi\\") { continue } # Déjà traité ?

            $filesToProcess += $file
        }
    }
}

$analyzedFiles = @()

Write-Host "Analyse de $($filesToProcess.Count) fichiers..."

foreach ($file in $filesToProcess) {
    $content = Get-Content -Path $file.FullName -TotalCount 50 -Raw

    # --- Extraction Date ---
    $date = "Unknown"
    # 1. From filename
    if ($file.Name -match $dateRegex) {
        $date = "$($matches[1])-$($matches[2])-$($matches[3])"
    }
    # 2. From content metadata (**Date :** ...)
    elseif ($content -match "\*\*Date.*?\*\*.*?(202[3-5][-/.](0[1-9]|1[0-2])[-/.](0[1-9]|[12][0-9]|3[01]))") {
        $date = $matches[1].Replace("/", "-").Replace(".", "-")
    }
    # 3. From content H1 (# ... 2025-...)
    elseif ($content -match "^#.*?(202[3-5][-/.](0[1-9]|1[0-2])[-/.](0[1-9]|[12][0-9]|3[01]))") {
        $date = $matches[1].Replace("/", "-").Replace(".", "-")
    }
    # 4. Fallback: File Creation Time (moins fiable mais utile)
    else {
        $date = $file.CreationTime.ToString("yyyy-MM-dd")
    }

    # --- Extraction Titre Court ---
    $title = $file.BaseName
    # Nettoyage du titre (retirer date, extension, caractères spéciaux)
    $title = $title -replace $dateRegex, ""
    $title = $title -replace "^[0-9]+[-_]", "" # Remove leading numbers
    $title = $title -replace "[-_]+", " "
    $title = $title.Trim()
    if ($title.Length -eq 0) { $title = "Rapport" }

    # --- Machine (Placeholder) ---
    $machine = "Unknown"
    if ($content -match "Machine.*?:.*?([a-zA-Z0-9-]+)") {
        $machine = $matches[1].Trim()
    }

    $analyzedFiles += [PSCustomObject]@{
        File = $file
        Date = $date
        Title = $title
        Machine = $machine
    }
}

# 2. Sort by Date
$sortedFiles = $analyzedFiles | Where-Object { $_.Date -ne "Unknown" } | Sort-Object Date

# 3. Group into Missions (Heuristic: Time gap > 3 days OR Major Subject Change)
$missions = @()
$currentMission = @{
    StartDate = $null
    Files = @()
    Keywords = @{}
}

foreach ($file in $sortedFiles) {
    $fileDate = [DateTime]::Parse($file.Date)

    # Extract keywords from title for subject detection
    $titleWords = $file.Title.Split(" ") | Where-Object { $_.Length -gt 3 }

    $isNewMission = $false

    if ($currentMission.Files.Count -eq 0) {
        $isNewMission = $true
    } else {
        $lastDate = [DateTime]::Parse($currentMission.Files[-1].Date)
        $daysDiff = ($fileDate - $lastDate).Days

        # Break if gap > 3 days
        if ($daysDiff -gt 3) {
            $isNewMission = $true
        }
    }

    if ($isNewMission) {
        # Save previous mission if exists
        if ($currentMission.Files.Count -gt 0) {
            $missions += $currentMission
        }
        # Start new mission
        $currentMission = @{
            StartDate = $file.Date
            Files = @(@($file))
            Keywords = @{}
        }
    } else {
        $currentMission.Files += $file
    }

    # Accumulate keywords
    foreach ($word in $titleWords) {
        $w = $word.ToLower()
        if (-not $currentMission.Keywords.ContainsKey($w)) { $currentMission.Keywords[$w] = 0 }
        $currentMission.Keywords[$w]++
    }
}
# Add last mission
if ($currentMission.Files.Count -gt 0) {
    $missions += $currentMission
}

# 4. Generate Plan
$results = @()

foreach ($m in $missions) {
    # Determine Subject: Most frequent keyword
    $subject = "Mission"
    if ($m.Keywords.Count -gt 0) {
        $topWord = $m.Keywords.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        $subject = (Get-Culture).TextInfo.ToTitleCase($topWord.Key)
    }

    # Clean subject
    $subject = $subject -replace "[^a-zA-Z0-9]", ""
    $missionFolder = "$($m.StartDate)_Mission_$subject"

    $counter = 1
    foreach ($item in $m.Files) {
        $num = "{0:D3}" -f $counter
        $titleSlug = $item.Title -replace "[^a-zA-Z0-9]", "-"
        $titleSlug = $titleSlug -replace "-+", "-"
        $titleSlug = $titleSlug.Trim("-")

        $newFileName = "$($item.Date)_${num}_$($item.Machine)_${titleSlug}.md"
        $newPath = Join-Path $targetBase $missionFolder
        $newFullPath = Join-Path $newPath $newFileName

        $results += [PSCustomObject]@{
            OriginalPath = $item.File.FullName
            NewPath = $newFullPath
            MissionFolder = $missionFolder
            Date = $item.Date
            Title = $item.Title
        }
        $counter++
    }
}

# Export CSV
$results | Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8
Write-Host "Plan de consolidation généré : $reportFile"
Write-Host "Total fichiers analysés : $($results.Count)"

# Aperçu
$results | Select-Object -First 10 | Format-Table -AutoSize

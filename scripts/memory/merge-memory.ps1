<#
.SYNOPSIS
    Merge intelligent d'une memoire partagee avec la memoire locale.

.DESCRIPTION
    Apres un git pull, PROJECT_MEMORY.md peut contenir de nouvelles sections
    partagees par d'autres machines. Ce script :
    1. Detecte les nouvelles sections dans PROJECT_MEMORY.md
    2. Les propose pour integration dans MEMORY.md locale
    3. Merge intelligemment sans dupliquer

    Peut aussi recevoir un payload RooSync contenant des memoires a merger.

.PARAMETER ProjectMemoryPath
    Chemin vers PROJECT_MEMORY.md (defaut: .claude/memory/PROJECT_MEMORY.md)

.PARAMETER MemoryPath
    Chemin vers MEMORY.md locale (auto-detecte si omis)

.PARAMETER AutoMerge
    Merger automatiquement sans confirmation (defaut: false)

.PARAMETER DryRun
    Afficher ce qui serait merge sans modifier

.EXAMPLE
    .\merge-memory.ps1
    .\merge-memory.ps1 -AutoMerge
    .\merge-memory.ps1 -DryRun
#>

param(
    [string]$ProjectMemoryPath = "",
    [string]$MemoryPath = "",
    [switch]$AutoMerge,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Detecter le repo racine
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Pas dans un depot Git."
    exit 1
}

Write-Host "=== Memory Merger ===" -ForegroundColor Cyan

# 1. Trouver PROJECT_MEMORY.md
if (-not $ProjectMemoryPath) {
    $ProjectMemoryPath = Join-Path $RepoRoot ".claude" "memory" "PROJECT_MEMORY.md"
}
if (-not (Test-Path $ProjectMemoryPath)) {
    Write-Error "PROJECT_MEMORY.md introuvable: $ProjectMemoryPath"
    exit 1
}

# 2. Trouver MEMORY.md locale
if (-not $MemoryPath) {
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    $claudeProjectsDir = Join-Path $homeDir ".claude" "projects"

    if (Test-Path $claudeProjectsDir) {
        $candidates = Get-ChildItem $claudeProjectsDir -Directory |
            Where-Object { $_.Name -like "*roo-extensions*" }

        foreach ($candidate in $candidates) {
            $memFile = Join-Path $candidate.FullName "memory" "MEMORY.md"
            if (Test-Path $memFile) {
                $MemoryPath = $memFile
                break
            }
        }
    }

    if (-not $MemoryPath) {
        Write-Warning "MEMORY.md locale non trouvee."
        Write-Host "Specifiez avec -MemoryPath"
        exit 0
    }
}

Write-Host "Source partagee: $ProjectMemoryPath"
Write-Host "Cible locale:   $MemoryPath"
Write-Host ""

# 3. Lire les deux fichiers
$projectContent = Get-Content $ProjectMemoryPath -Raw -Encoding UTF8
$localContent = Get-Content $MemoryPath -Raw -Encoding UTF8

# 4. Extraire les sections de PROJECT_MEMORY qui sont dans "Known Bugs / Gotchas" et "Decisions & Patterns"
# Ces sections contiennent des apprentissages partageables

$sectionsToCheck = @()

# Extraire sous-sections ### de PROJECT_MEMORY
$lines = $projectContent -split "`n"
$currentH3 = $null
$currentH3Content = @()
$parentH2 = ""

foreach ($line in $lines) {
    if ($line -match '^##\s+(.+)') {
        # Sauvegarder la section precedente
        if ($currentH3) {
            $sectionsToCheck += @{
                Title = $currentH3
                Content = ($currentH3Content -join "`n").Trim()
                Parent = $parentH2
            }
        }
        $parentH2 = $Matches[1].Trim()
        $currentH3 = $null
        $currentH3Content = @()
    }
    elseif ($line -match '^###\s+(.+)') {
        if ($currentH3) {
            $sectionsToCheck += @{
                Title = $currentH3
                Content = ($currentH3Content -join "`n").Trim()
                Parent = $parentH2
            }
        }
        $currentH3 = $Matches[1].Trim()
        $currentH3Content = @($line)
    }
    elseif ($currentH3) {
        $currentH3Content += $line
    }
}
if ($currentH3) {
    $sectionsToCheck += @{
        Title = $currentH3
        Content = ($currentH3Content -join "`n").Trim()
        Parent = $parentH2
    }
}

# 5. Filtrer les sections deja presentes dans MEMORY.md
$newForLocal = @()
foreach ($s in $sectionsToCheck) {
    # Sauter les sections d'architecture (trop specifiques)
    if ($s.Parent -match 'Architecture|Consolidation|Current State') { continue }

    # Verifier si le titre est deja dans MEMORY.md
    $titleEscaped = [regex]::Escape($s.Title)
    if ($localContent -notmatch $titleEscaped) {
        $newForLocal += $s
    }
}

if ($newForLocal.Count -eq 0) {
    Write-Host "MEMORY.md locale est deja a jour." -ForegroundColor Green
    Write-Host "Aucune nouvelle section a merger."
    exit 0
}

Write-Host "Sections disponibles pour merge:" -ForegroundColor Yellow
for ($i = 0; $i -lt $newForLocal.Count; $i++) {
    Write-Host "  [$i] $($newForLocal[$i].Title) (de: $($newForLocal[$i].Parent))" -ForegroundColor Cyan
}
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Contenu qui serait ajoute a MEMORY.md:" -ForegroundColor Yellow
    foreach ($s in $newForLocal) {
        Write-Host ""
        Write-Host "--- $($s.Title) ---" -ForegroundColor DarkGray
        Write-Host $s.Content
    }
    exit 0
}

# 6. Merger
$sectionsToMerge = @()

if ($AutoMerge) {
    $sectionsToMerge = $newForLocal
    Write-Host "Auto-merge: $($sectionsToMerge.Count) section(s)" -ForegroundColor Yellow
} else {
    Write-Host "Selectionner les sections a merger (numeros separes par virgule, 'all', ou 'none'):" -ForegroundColor Yellow
    $input = Read-Host "Choix"

    if ($input -eq 'all') {
        $sectionsToMerge = $newForLocal
    } elseif ($input -eq 'none') {
        Write-Host "Aucun merge effectue." -ForegroundColor DarkGray
        exit 0
    } else {
        $indices = $input -split ',' | ForEach-Object { [int]$_.Trim() }
        foreach ($idx in $indices) {
            if ($idx -ge 0 -and $idx -lt $newForLocal.Count) {
                $sectionsToMerge += $newForLocal[$idx]
            }
        }
    }
}

if ($sectionsToMerge.Count -eq 0) {
    Write-Host "Aucune section selectionnee."
    exit 0
}

# 7. Ajouter a MEMORY.md
$additions = "`n"
foreach ($s in $sectionsToMerge) {
    $additions += "`n$($s.Content)`n"
}

$localContent += $additions
Set-Content -Path $MemoryPath -Value $localContent -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "=== Merge termine ===" -ForegroundColor Green
Write-Host "$($sectionsToMerge.Count) section(s) ajoutee(s) a MEMORY.md"
Write-Host ""
Write-Host "Sections mergees:" -ForegroundColor Cyan
foreach ($s in $sectionsToMerge) {
    Write-Host "  + $($s.Title)"
}

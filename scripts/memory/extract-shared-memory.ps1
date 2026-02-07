<#
.SYNOPSIS
    Extrait les sections universelles de MEMORY.md pour les partager entre machines.

.DESCRIPTION
    MEMORY.md (~/.claude/projects/...) contient des apprentissages de session.
    Certaines sections sont universelles (build commands, common mistakes, patterns).
    Ce script extrait ces sections et les prepare pour propagation via git ou RooSync.

    Workflow :
    1. Lit la MEMORY.md locale de la session
    2. Identifie les sections universelles (marquees ## ou avec tags)
    3. Les copie dans PROJECT_MEMORY.md (partage via git)
    4. Optionnellement envoie un message RooSync pour notifier

.PARAMETER MemoryPath
    Chemin vers MEMORY.md locale (auto-detecte si omis)

.PARAMETER ProjectMemoryPath
    Chemin vers PROJECT_MEMORY.md partagee (defaut: .claude/memory/PROJECT_MEMORY.md)

.PARAMETER DryRun
    Afficher ce qui serait extrait sans modifier les fichiers

.EXAMPLE
    .\extract-shared-memory.ps1
    .\extract-shared-memory.ps1 -DryRun
#>

param(
    [string]$MemoryPath = "",
    [string]$ProjectMemoryPath = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Detecter le repo racine
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Pas dans un depot Git. Executez depuis roo-extensions."
    exit 1
}

Write-Host "=== Memory Extractor ===" -ForegroundColor Cyan

# 1. Trouver la MEMORY.md locale
if (-not $MemoryPath) {
    # Chercher dans le dossier standard Claude Code
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    $claudeProjectsDir = Join-Path $homeDir ".claude" "projects"

    # Encoder le chemin du repo pour le dossier Claude
    $repoPathEncoded = ($RepoRoot -replace '[/\\]', '-' -replace ':', '-').TrimStart('-').ToLower()

    # Chercher les dossiers qui correspondent
    $candidates = @()
    if (Test-Path $claudeProjectsDir) {
        $candidates = Get-ChildItem $claudeProjectsDir -Directory |
            Where-Object { $_.Name -like "*roo-extensions*" -or $_.Name -like "*$repoPathEncoded*" }
    }

    foreach ($candidate in $candidates) {
        $memFile = Join-Path $candidate.FullName "memory" "MEMORY.md"
        if (Test-Path $memFile) {
            $MemoryPath = $memFile
            break
        }
    }

    if (-not $MemoryPath) {
        Write-Warning "MEMORY.md locale non trouvee. Chemin attendu: ~/.claude/projects/.../memory/MEMORY.md"
        Write-Host "Specifiez le chemin avec -MemoryPath"
        exit 0
    }
}

if (-not (Test-Path $MemoryPath)) {
    Write-Error "MEMORY.md introuvable: $MemoryPath"
    exit 1
}

Write-Host "Source:  $MemoryPath"

# 2. PROJECT_MEMORY.md
if (-not $ProjectMemoryPath) {
    $ProjectMemoryPath = Join-Path $RepoRoot ".claude" "memory" "PROJECT_MEMORY.md"
}
Write-Host "Cible:   $ProjectMemoryPath"
Write-Host ""

# 3. Lire et parser MEMORY.md
$memoryContent = Get-Content $MemoryPath -Raw -Encoding UTF8

# Extraire les sections de niveau 2 (##) et 3 (###)
$sections = @()
$currentSection = $null
$currentContent = @()

foreach ($line in ($memoryContent -split "`n")) {
    if ($line -match '^##\s+(.+)') {
        if ($currentSection) {
            $sections += @{
                Title = $currentSection
                Content = ($currentContent -join "`n").Trim()
                Level = 2
            }
        }
        $currentSection = $Matches[1].Trim()
        $currentContent = @($line)
    } elseif ($currentSection) {
        $currentContent += $line
    }
}
# Derniere section
if ($currentSection) {
    $sections += @{
        Title = $currentSection
        Content = ($currentContent -join "`n").Trim()
        Level = 2
    }
}

Write-Host "Sections trouvees dans MEMORY.md:" -ForegroundColor Yellow
foreach ($s in $sections) {
    Write-Host "  - $($s.Title)"
}
Write-Host ""

# 4. Classifier les sections (universelles vs specifiques)
# Sections universelles = patterns, conventions, bugs, commands
$universalKeywords = @(
    'Pattern', 'Convention', 'Command', 'Bug', 'Fix', 'Gotcha',
    'Test', 'Build', 'Location', 'Mock', 'Tip', 'Warning',
    'Architecture', 'Workflow', 'Hierarchy'
)

$universalSections = @()
$specificSections = @()

foreach ($s in $sections) {
    $isUniversal = $false
    foreach ($kw in $universalKeywords) {
        if ($s.Title -match $kw) {
            $isUniversal = $true
            break
        }
    }
    if ($isUniversal) {
        $universalSections += $s
    } else {
        $specificSections += $s
    }
}

Write-Host "Sections universelles (a partager):" -ForegroundColor Green
foreach ($s in $universalSections) {
    Write-Host "  + $($s.Title)"
}
Write-Host ""

if ($specificSections.Count -gt 0) {
    Write-Host "Sections specifiques (non partagees):" -ForegroundColor DarkGray
    foreach ($s in $specificSections) {
        Write-Host "  - $($s.Title)"
    }
    Write-Host ""
}

# 5. Lire PROJECT_MEMORY.md existante
$projectMemory = ""
if (Test-Path $ProjectMemoryPath) {
    $projectMemory = Get-Content $ProjectMemoryPath -Raw -Encoding UTF8
}

# 6. Verifier quelles sections sont nouvelles
$newSections = @()
foreach ($s in $universalSections) {
    # Extraire les sous-sections (###) pour une comparaison plus fine
    $subSections = $s.Content -split '(?=^###\s)' | Where-Object { $_ -match '###' }
    if ($subSections.Count -eq 0) { $subSections = @($s.Content) }

    foreach ($sub in $subSections) {
        $subTitle = if ($sub -match '###\s+(.+)') { $Matches[1].Trim() } else { $s.Title }
        # Verifier si deja present dans PROJECT_MEMORY.md
        if ($projectMemory -notmatch [regex]::Escape($subTitle)) {
            $newSections += @{
                Title = $subTitle
                Content = $sub.Trim()
                ParentTitle = $s.Title
            }
        }
    }
}

if ($newSections.Count -eq 0) {
    Write-Host "Aucune nouvelle section a ajouter." -ForegroundColor Green
    Write-Host "PROJECT_MEMORY.md est deja a jour."
    exit 0
}

Write-Host "Nouvelles sections a ajouter:" -ForegroundColor Cyan
foreach ($s in $newSections) {
    Write-Host "  NEW: $($s.Title)"
}
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Contenu qui serait ajoute:" -ForegroundColor Yellow
    foreach ($s in $newSections) {
        Write-Host "---"
        Write-Host $s.Content
    }
    exit 0
}

# 7. Ajouter a PROJECT_MEMORY.md
$machineName = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd"

$additions = "`n`n## Shared from $machineName ($timestamp)`n"
foreach ($s in $newSections) {
    $additions += "`n$($s.Content)`n"
}

# Ajouter avant la derniere ligne ou a la fin
$projectMemory += $additions

Set-Content -Path $ProjectMemoryPath -Value $projectMemory -Encoding UTF8 -NoNewline

Write-Host "=== Extraction terminee ===" -ForegroundColor Green
Write-Host ""
Write-Host "$($newSections.Count) section(s) ajoutee(s) a PROJECT_MEMORY.md"
Write-Host ""
Write-Host "Prochaines etapes:" -ForegroundColor Cyan
Write-Host "  1. Verifier le contenu: cat $ProjectMemoryPath"
Write-Host "  2. Committer: git add .claude/memory/PROJECT_MEMORY.md && git commit -m 'docs(memory): Share learnings from $machineName'"
Write-Host "  3. Pousser: git push"

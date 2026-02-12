<#
.SYNOPSIS
    Diagnostic : identifie les sections de MEMORY.md qui pourraient etre partagees.

.DESCRIPTION
    MEMORY.md (~/.claude/projects/...) contient des apprentissages de session.
    Certaines sections sont universelles (build commands, common mistakes, patterns).

    Ce script PRESENTE les sections candidates au partage.
    L'agent ou l'utilisateur decide ensuite quoi consolider et ou.

    Par defaut : mode diagnostic (lecture seule, aucune modification).
    Avec -Apply : ecrit les sections selectionnees dans PROJECT_MEMORY.md.

    Workflow recommande :
    1. Lancer sans argument → lire le rapport diagnostic
    2. L'agent evalue avec jugement ce qui merite d'etre partage
    3. L'agent met a jour PROJECT_MEMORY.md manuellement (Edit/Write)
    4. Ou relancer avec -Apply pour ecriture automatique

.PARAMETER MemoryPath
    Chemin vers MEMORY.md locale (auto-detecte si omis)

.PARAMETER ProjectMemoryPath
    Chemin vers PROJECT_MEMORY.md partagee (defaut: .claude/memory/PROJECT_MEMORY.md)

.PARAMETER Apply
    Appliquer les modifications (ecrire dans PROJECT_MEMORY.md).
    Sans ce flag, le script est en mode diagnostic uniquement.

.EXAMPLE
    # Mode diagnostic (defaut) - presenter les candidats
    .\extract-shared-memory.ps1

    # Mode application - ecrire dans PROJECT_MEMORY.md
    .\extract-shared-memory.ps1 -Apply
#>

param(
    [string]$MemoryPath = "",
    [string]$ProjectMemoryPath = "",
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

# Detecter le repo racine
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Pas dans un depot Git. Executez depuis roo-extensions."
    exit 1
}

Write-Host "=== Memory Extractor (Diagnostic) ===" -ForegroundColor Cyan
if (-not $Apply) {
    Write-Host "Mode: DIAGNOSTIC (lecture seule)" -ForegroundColor DarkGray
    Write-Host "Utilisez -Apply pour ecrire les modifications." -ForegroundColor DarkGray
} else {
    Write-Host "Mode: APPLICATION (ecriture)" -ForegroundColor Yellow
}
Write-Host ""

# 1. Trouver la MEMORY.md locale
if (-not $MemoryPath) {
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    $claudeProjectsDir = Join-Path $homeDir ".claude" "projects"

    $candidates = @()
    if (Test-Path $claudeProjectsDir) {
        $candidates = Get-ChildItem $claudeProjectsDir -Directory |
            Where-Object { $_.Name -like "*roo-extensions*" }
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

Write-Host "Source (privee):  $MemoryPath"

# 2. PROJECT_MEMORY.md
if (-not $ProjectMemoryPath) {
    $ProjectMemoryPath = Join-Path $RepoRoot ".claude" "memory" "PROJECT_MEMORY.md"
}
Write-Host "Cible (partagee): $ProjectMemoryPath"
Write-Host ""

# 3. Lire et parser MEMORY.md
$memoryContent = Get-Content $MemoryPath -Raw -Encoding UTF8

# Extraire les sections de niveau 2 (##)
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
if ($currentSection) {
    $sections += @{
        Title = $currentSection
        Content = ($currentContent -join "`n").Trim()
        Level = 2
    }
}

Write-Host "--- Sections dans MEMORY.md ---" -ForegroundColor Yellow
foreach ($s in $sections) {
    $lineCount = ($s.Content -split "`n").Count
    Write-Host "  [$($lineCount) lignes] $($s.Title)"
}
Write-Host ""

# 4. Classifier les sections (universelles vs specifiques a la machine)
$universalKeywords = @(
    'Pattern', 'Convention', 'Command', 'Bug', 'Fix', 'Gotcha',
    'Test', 'Build', 'Location', 'Mock', 'Tip', 'Warning',
    'Architecture', 'Workflow', 'Hierarchy', 'Lesson', 'Decision'
)

$ephemeralKeywords = @(
    'Current State', 'Issue Tracker', 'Dashboard', 'Staggering',
    'Scheduler', 'Protocol', 'Embeddings', 'Key Files', 'Memory'
)

$universalSections = @()
$ephemeralSections = @()

foreach ($s in $sections) {
    $isEphemeral = $false
    foreach ($kw in $ephemeralKeywords) {
        if ($s.Title -match $kw) {
            $isEphemeral = $true
            break
        }
    }
    if ($isEphemeral) {
        $ephemeralSections += $s
        continue
    }

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
        $ephemeralSections += $s
    }
}

Write-Host "--- Classification ---" -ForegroundColor Cyan
Write-Host ""
Write-Host "Candidates au partage (universelles):" -ForegroundColor Green
if ($universalSections.Count -eq 0) {
    Write-Host "  (aucune)"
} else {
    foreach ($s in $universalSections) {
        Write-Host "  + $($s.Title)"
    }
}
Write-Host ""

Write-Host "Specifiques a cette machine (non partagees):" -ForegroundColor DarkGray
if ($ephemeralSections.Count -eq 0) {
    Write-Host "  (aucune)"
} else {
    foreach ($s in $ephemeralSections) {
        Write-Host "  - $($s.Title)"
    }
}
Write-Host ""

# 5. Lire PROJECT_MEMORY.md et detecter les nouvelles sections
$projectMemory = ""
if (Test-Path $ProjectMemoryPath) {
    $projectMemory = Get-Content $ProjectMemoryPath -Raw -Encoding UTF8
}

$newSections = @()
foreach ($s in $universalSections) {
    $subSections = $s.Content -split '(?=^###\s)' | Where-Object { $_ -match '###' }
    if ($subSections.Count -eq 0) { $subSections = @($s.Content) }

    foreach ($sub in $subSections) {
        $subTitle = if ($sub -match '###\s+(.+)') { $Matches[1].Trim() } else { $s.Title }
        if ($projectMemory -notmatch [regex]::Escape($subTitle)) {
            $newSections += @{
                Title = $subTitle
                Content = $sub.Trim()
                ParentTitle = $s.Title
            }
        }
    }
}

# 6. Rapport diagnostic
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RAPPORT DIAGNOSTIC" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($newSections.Count -eq 0) {
    Write-Host "Aucune nouvelle section a partager." -ForegroundColor Green
    Write-Host "PROJECT_MEMORY.md couvre deja toutes les sections universelles."
    Write-Host ""
    Write-Host "L'agent peut neanmoins mettre a jour manuellement des sections" -ForegroundColor DarkGray
    Write-Host "existantes si leur contenu a evolue." -ForegroundColor DarkGray
    exit 0
}

Write-Host "Sections NOUVELLES candidates au partage:" -ForegroundColor Yellow
Write-Host ""

for ($i = 0; $i -lt $newSections.Count; $i++) {
    $s = $newSections[$i]
    $preview = ($s.Content -split "`n" | Select-Object -First 5) -join "`n"
    $totalLines = ($s.Content -split "`n").Count

    Write-Host "[$i] $($s.Title)" -ForegroundColor Cyan
    Write-Host "    Parent: $($s.ParentTitle)" -ForegroundColor DarkGray
    Write-Host "    Lignes: $totalLines" -ForegroundColor DarkGray
    Write-Host "    Apercu:" -ForegroundColor DarkGray
    foreach ($previewLine in ($s.Content -split "`n" | Select-Object -First 5)) {
        Write-Host "      $previewLine"
    }
    if ($totalLines -gt 5) {
        Write-Host "      ... ($($totalLines - 5) lignes de plus)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $Apply) {
    Write-Host "Action recommandee:" -ForegroundColor Yellow
    Write-Host "  L'agent doit evaluer chaque section ci-dessus avec jugement :" -ForegroundColor DarkGray
    Write-Host "  - Est-ce vraiment universel (utile a toutes les machines) ?" -ForegroundColor DarkGray
    Write-Host "  - Le contenu est-il stable (pas ephemere) ?" -ForegroundColor DarkGray
    Write-Host "  - N'est-ce pas deja couvert autrement dans PROJECT_MEMORY.md ?" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Option 1: Mettre a jour PROJECT_MEMORY.md manuellement (recommande)" -ForegroundColor DarkGray
    Write-Host "  Option 2: Relancer avec -Apply pour ecriture automatique" -ForegroundColor DarkGray
    exit 0
}

# 7. Mode -Apply : ecrire dans PROJECT_MEMORY.md
Write-Host "Application des modifications..." -ForegroundColor Yellow

$machineName = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd"

$additions = "`n`n## Shared from $machineName ($timestamp)`n"
foreach ($s in $newSections) {
    $additions += "`n$($s.Content)`n"
}

$projectMemory += $additions
Set-Content -Path $ProjectMemoryPath -Value $projectMemory -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "=== Application terminee ===" -ForegroundColor Green
Write-Host "$($newSections.Count) section(s) ajoutee(s) a PROJECT_MEMORY.md"
Write-Host ""
Write-Host "Prochaines etapes:" -ForegroundColor Cyan
Write-Host "  1. Verifier le contenu: cat $ProjectMemoryPath"
Write-Host "  2. Committer: git add .claude/memory/PROJECT_MEMORY.md && git commit -m 'docs(memory): Share learnings from $machineName'"
Write-Host "  3. Pousser: git push"

<#
.SYNOPSIS
    Diagnostic : identifie les sections de PROJECT_MEMORY.md absentes de la memoire locale.

.DESCRIPTION
    Apres un git pull, PROJECT_MEMORY.md peut contenir de nouvelles sections
    partagees par d'autres machines. Ce script :
    1. Detecte les nouvelles sections dans PROJECT_MEMORY.md
    2. Les PRESENTE pour evaluation par l'agent
    3. L'agent decide quoi integrer dans MEMORY.md locale

    Par defaut : mode diagnostic (lecture seule, aucune modification).
    Avec -Apply : ecrit les sections dans MEMORY.md locale.

.PARAMETER ProjectMemoryPath
    Chemin vers PROJECT_MEMORY.md (defaut: .claude/memory/PROJECT_MEMORY.md)

.PARAMETER MemoryPath
    Chemin vers MEMORY.md locale (auto-detecte si omis)

.PARAMETER Apply
    Appliquer les modifications (ecrire dans MEMORY.md).
    Sans ce flag, le script est en mode diagnostic uniquement.

.EXAMPLE
    # Mode diagnostic (defaut) - presenter les candidats
    .\merge-memory.ps1

    # Mode application - ecrire dans MEMORY.md
    .\merge-memory.ps1 -Apply
#>

param(
    [string]$ProjectMemoryPath = "",
    [string]$MemoryPath = "",
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

# Detecter le repo racine
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Pas dans un depot Git."
    exit 1
}

Write-Host "=== Memory Merger (Diagnostic) ===" -ForegroundColor Cyan
if (-not $Apply) {
    Write-Host "Mode: DIAGNOSTIC (lecture seule)" -ForegroundColor DarkGray
    Write-Host "Utilisez -Apply pour ecrire les modifications." -ForegroundColor DarkGray
} else {
    Write-Host "Mode: APPLICATION (ecriture)" -ForegroundColor Yellow
}
Write-Host ""

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

Write-Host "Source (partagee): $ProjectMemoryPath"
Write-Host "Cible (locale):   $MemoryPath"
Write-Host ""

# 3. Lire les deux fichiers
$projectContent = Get-Content $ProjectMemoryPath -Raw -Encoding UTF8
$localContent = Get-Content $MemoryPath -Raw -Encoding UTF8

# 4. Extraire les sous-sections ### de PROJECT_MEMORY
$sectionsToCheck = @()
$lines = $projectContent -split "`n"
$currentH3 = $null
$currentH3Content = @()
$parentH2 = ""

foreach ($line in $lines) {
    if ($line -match '^##\s+(.+)') {
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
    # Sauter les sections d'architecture (trop specifiques au projet)
    if ($s.Parent -match 'Architecture|Consolidation|Current State') { continue }

    $titleEscaped = [regex]::Escape($s.Title)
    if ($localContent -notmatch $titleEscaped) {
        $newForLocal += $s
    }
}

# 6. Rapport diagnostic
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RAPPORT DIAGNOSTIC" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Sections dans PROJECT_MEMORY.md: $($sectionsToCheck.Count)" -ForegroundColor DarkGray
Write-Host "Sections deja dans MEMORY.md:    $($sectionsToCheck.Count - $newForLocal.Count)" -ForegroundColor DarkGray
Write-Host "Sections NOUVELLES:              $($newForLocal.Count)" -ForegroundColor Yellow
Write-Host ""

if ($newForLocal.Count -eq 0) {
    Write-Host "MEMORY.md locale est deja a jour." -ForegroundColor Green
    Write-Host "Aucune nouvelle section a integrer."
    exit 0
}

Write-Host "Sections candidates a l'integration:" -ForegroundColor Yellow
Write-Host ""

for ($i = 0; $i -lt $newForLocal.Count; $i++) {
    $s = $newForLocal[$i]
    $totalLines = ($s.Content -split "`n").Count

    Write-Host "[$i] $($s.Title)" -ForegroundColor Cyan
    Write-Host "    Source: $($s.Parent)" -ForegroundColor DarkGray
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
    Write-Host "  - Cette info est-elle pertinente pour CETTE machine ?" -ForegroundColor DarkGray
    Write-Host "  - N'est-elle pas deja connue sous un autre titre ?" -ForegroundColor DarkGray
    Write-Host "  - Faut-il l'adapter au contexte local ?" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Option 1: Mettre a jour MEMORY.md manuellement (recommande)" -ForegroundColor DarkGray
    Write-Host "  Option 2: Relancer avec -Apply pour ecriture automatique" -ForegroundColor DarkGray
    exit 0
}

# 7. Mode -Apply : ecrire dans MEMORY.md
Write-Host "Application des modifications..." -ForegroundColor Yellow

$additions = "`n"
foreach ($s in $newForLocal) {
    $additions += "`n$($s.Content)`n"
}

$localContent += $additions
Set-Content -Path $MemoryPath -Value $localContent -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "=== Merge termine ===" -ForegroundColor Green
Write-Host "$($newForLocal.Count) section(s) ajoutee(s) a MEMORY.md"
Write-Host ""
Write-Host "Sections integrees:" -ForegroundColor Cyan
foreach ($s in $newForLocal) {
    Write-Host "  + $($s.Title)"
}

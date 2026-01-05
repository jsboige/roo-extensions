# Script d'analyse des commits Git pour RooSync
# Analyse les 20 derniers commits du dépôt principal et du sous-module mcps/internal

$ErrorActionPreference = "Stop"

function Get-CommitDetails {
    param(
        [string]$Hash
    )

    $details = git show --stat $Hash --format="%H|%an|%ae|%ad|%s|%b" --date=iso 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Erreur lors de l'analyse du commit $Hash"
        return $null
    }

    $lines = $details -split "`n"
    $header = $lines[0] -split '\|'
    $fullHash = $header[0]
    $author = $header[1]
    $email = $header[2]
    $date = $header[3]
    $subject = $header[4]
    $body = if ($header.Length -gt 5) { $header[5] } else { "" }

    # Extraire les fichiers modifiés
    $files = @()
    $inFilesSection = $false
    foreach ($line in $lines) {
        if ($line -match '^\s+\d+ files? changed') {
            $inFilesSection = $true
            continue
        }
        if ($inFilesSection -and $line -match '^\s+(\d+)\s+([+-]+)\s+(.+)$') {
            $files += @{
                Path = $matches[3]
                Additions = [int]$matches[1]
                Deletions = [int]$matches[2].Length
            }
        }
    }

    return @{
        Hash = $fullHash
        ShortHash = $Hash.Substring(0, 7)
        Author = $author
        Email = $email
        Date = $date
        Subject = $subject
        Body = $body
        Files = $files
    }
}

function Analyze-Commits {
    param(
        [string]$RepoPath = ".",
        [int]$Count = 20
    )

    Push-Location $RepoPath

    try {
        Write-Host "=== Analyse des $Count derniers commits de $RepoPath ===" -ForegroundColor Cyan
        Write-Host ""

        $commits = git log --oneline -$Count 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Erreur lors de la récupération des commits: $commits"
            return @()
        }

        $results = @()
        foreach ($line in $commits) {
            $hash = ($line -split ' ')[0]
            $details = Get-CommitDetails -Hash $hash
            if ($details) {
                $results += $details
            }
        }

        return $results
    }
    finally {
        Pop-Location
    }
}

function Format-CommitTable {
    param(
        [array]$Commits
    )

    Write-Host "`n=== TABLEAU DES COMMITS ===" -ForegroundColor Green
    Write-Host ""

    $table = @()
    foreach ($commit in $Commits) {
        $table += [PSCustomObject]@{
            Hash = $commit.ShortHash
            Date = ($commit.Date -split 'T')[0]
            Author = $commit.Author
            Subject = $commit.Subject
            Files = $commit.Files.Count
        }
    }

    $table | Format-Table -AutoSize

    Write-Host "`n=== DÉTAILS DES COMMITS ===" -ForegroundColor Green
    Write-Host ""

    foreach ($commit in $Commits) {
        Write-Host "Commit: $($commit.ShortHash) ($($commit.Hash))" -ForegroundColor Yellow
        Write-Host "Auteur: $($commit.Author) <$($commit.Email)>"
        Write-Host "Date: $($commit.Date)"
        Write-Host "Sujet: $($commit.Subject)"
        if ($commit.Body) {
            Write-Host "Description: $($commit.Body)"
        }
        Write-Host "Fichiers modifiés ($($commit.Files.Count)):"
        foreach ($file in $commit.Files) {
            Write-Host "  - $($file.Path) (+$($file.Additions), -$($file.Deletions))"
        }
        Write-Host ""
    }
}

# Analyse du dépôt principal
$mainCommits = Analyze-Commits -RepoPath "." -Count 20
Format-CommitTable -Commits $mainCommits

# Analyse du sous-module mcps/internal
if (Test-Path "mcps/internal") {
    Write-Host "`n`n========================================`n" -ForegroundColor Magenta
    $submoduleCommits = Analyze-Commits -RepoPath "mcps/internal" -Count 20
    Format-CommitTable -Commits $submoduleCommits
} else {
    Write-Host "`n`nLe sous-module mcps/internal n'existe pas." -ForegroundColor Red
}

Write-Host "`n=== FIN DE L'ANALYSE ===" -ForegroundColor Green

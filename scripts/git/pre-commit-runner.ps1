#!/usr/bin/env pwsh

# scripts/git/pre-commit-runner.ps1
# Pre-commit validation runner - minimal version
# Validates basic file integrity for staged changes

Write-Host "🔍 [Pre-commit] Validation des fichiers stagés..." -ForegroundColor Cyan

$ErrorActionPreference = "Stop"
$ExitCode = 0

try {
    # Get staged files
    $StagedFiles = git diff --cached --name-only --diff-filter=ACM

    if (-not $StagedFiles) {
        Write-Host "✅ [Pre-commit] Aucun fichier stagé à valider." -ForegroundColor Green
        exit 0
    }

    Write-Host "   Fichiers à valider: $($StagedFiles.Count)" -ForegroundColor Cyan

    foreach ($File in $StagedFiles) {
        if (-not (Test-Path $File)) {
            Write-Host "   ⚠️ Ignoré (supprimé): $File" -ForegroundColor Yellow
            continue
        }

        Write-Host "   Validation: $File..." -NoNewline

        # Validate JSON files
        if ($File -match '\.json$') {
            try {
                $null = Get-Content $File -Raw | ConvertFrom-Json
                Write-Host " ✅" -ForegroundColor Green
            }
            catch {
                Write-Host " ❌ JSON invalide" -ForegroundColor Red
                Write-Host "      Erreur: $($_.Exception.Message)" -ForegroundColor Red
                $ExitCode = 1
            }
        }
        # Validate PowerShell files
        elseif ($File -match '\.ps1$') {
            try {
                $Errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $File -Raw), [ref]$Errors)
                if ($Errors.Count -gt 0) {
                    Write-Host " ❌ Erreurs de syntaxe" -ForegroundColor Red
                    $Errors | ForEach-Object {
                        Write-Host "      Ligne $($_.Token.StartLine): $($_.Message)" -ForegroundColor Red
                    }
                    $ExitCode = 1
                }
                else {
                    Write-Host " ✅" -ForegroundColor Green
                }
            }
            catch {
                Write-Host " ❌ Erreur de parsing" -ForegroundColor Red
                Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
                $ExitCode = 1
            }
        }
        # Other files: just check readability
        else {
            # Skip directories (submodule pointers appear as staged directories)
            if (Test-Path $File -PathType Container) {
                Write-Host " ⏭️ (submodule)" -ForegroundColor DarkGray
                continue
            }
            try {
                $null = Get-Content $File -TotalCount 1 -ErrorAction Stop
                Write-Host " ✅" -ForegroundColor Green
            }
            catch {
                Write-Host " ❌ Fichier illisible" -ForegroundColor Red
                $ExitCode = 1
            }
        }
    }

    Write-Host ""
    if ($ExitCode -eq 0) {
        Write-Host "✅ [Pre-commit] Validation réussie. Commit autorisé." -ForegroundColor Green
    }
    else {
        Write-Host "⛔ [Pre-commit] Validation échouée. Corrigez les erreurs ci-dessus." -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ [Pre-commit] Erreur fatale: $($_.Exception.Message)" -ForegroundColor Red
    $ExitCode = 1
}

exit $ExitCode

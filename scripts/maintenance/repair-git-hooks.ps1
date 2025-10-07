# Script de réparation des hooks git pre-commit
# Résout le problème "cannot spawn .git/hooks/pre-commit: No such file or directory"

param([switch]$Test = $false)

$gitRoot = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERREUR: Ce script doit être exécuté dans un répertoire git" -ForegroundColor Red
    exit 1
}

Write-Host "RÉPARATION DES HOOKS GIT PRE-COMMIT" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Diagnostic
Write-Host "Diagnostic..." -ForegroundColor Yellow
$hookPath = Join-Path $gitRoot ".git/hooks/pre-commit"
$hookPsPath = Join-Path $gitRoot ".git/hooks/pre-commit.ps1"

if (Test-Path $hookPath) {
    Write-Host "OK: Fichier pre-commit existe"
    
    # Vérification BOM
    $bytes = [System.IO.File]::ReadAllBytes($hookPath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Host "PROBLÈME: Fichier contient un BOM UTF-8" -ForegroundColor Red
    } else {
        Write-Host "OK: Pas de BOM détecté"
    }
    
    # Vérification contenu
    $content = Get-Content $hookPath -Raw -ErrorAction SilentlyContinue
    if ($content -match "#!/usr/bin/env pwsh") {
        Write-Host "PROBLÈME: Shebang PowerShell détecté (incompatible Windows)" -ForegroundColor Red
    } elseif ($content -match "@echo off") {
        Write-Host "OK: Format batch détecté"
    } else {
        Write-Host "Format non reconnu" -ForegroundColor Yellow
    }
} else {
    Write-Host "ERREUR: Fichier pre-commit MANQUANT" -ForegroundColor Red
}

if (Test-Path $hookPsPath) {
    Write-Host "OK: Script PowerShell pre-commit.ps1 existe"
} else {
    Write-Host "ERREUR: Script PowerShell pre-commit.ps1 MANQUANT" -ForegroundColor Red
}

Write-Host ""

# Réparation
if (-not $Test) {
    Write-Host "Réparation..." -ForegroundColor Yellow
    
    # Sauvegarde si le fichier existe et n'est pas déjà un wrapper
    if (Test-Path $hookPath) {
        $content = Get-Content $hookPath -Raw -ErrorAction SilentlyContinue
        if ($content -match "#!/usr/bin/env pwsh" -and -not (Test-Path $hookPsPath)) {
            Write-Host "Sauvegarde du script PowerShell original vers pre-commit.ps1"
            Copy-Item $hookPath $hookPsPath -Force
        }
    }
    
    # Vérification que le script PS existe
    if (-not (Test-Path $hookPsPath)) {
        Write-Host "ERREUR: Script PowerShell pre-commit.ps1 introuvable" -ForegroundColor Red
        Write-Host "Impossible de créer le wrapper sans le script original" -ForegroundColor Red
        exit 1
    }
    
    # Création du wrapper batch
    Write-Host "Création du wrapper batch..."
    $batchContent = "@echo off" + "`r`n" +
                   "REM Hook pre-commit wrapper pour Windows" + "`r`n" +
                   "REM Appelle le script PowerShell pour verifier l'encodage des fichiers" + "`r`n" +
                   "" + "`r`n" +
                   "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0pre-commit.ps1`"" + "`r`n" +
                   "exit /b %ERRORLEVEL%"
    
    # Écriture sans BOM
    [System.IO.File]::WriteAllText($hookPath, $batchContent, [System.Text.Encoding]::ASCII)
    Write-Host "SUCCESS: Hook pre-commit créé (format batch, sans BOM)" -ForegroundColor Green
    
    # Test
    Write-Host ""
    Write-Host "Test du hook..." -ForegroundColor Yellow
    
    # Créer un fichier temporaire pour tester
    $testFile = "test-hook-repair-temp.txt"
    "Test hook repair" | Out-File -FilePath $testFile -Encoding UTF8
    git add $testFile | Out-Null
    
    Write-Host "Tentative de commit test..."
    $commitOutput = git commit -m "Test hook repair" 2>&1
    $commitSuccess = $LASTEXITCODE -eq 0
    
    # Nettoyage
    git reset HEAD $testFile | Out-Null
    Remove-Item $testFile -ErrorAction SilentlyContinue
    
    if ($commitSuccess) {
        Write-Host "SUCCESS: Hook fonctionne correctement!" -ForegroundColor Green
        Write-Host "Vous pouvez maintenant faire des commits sans --no-verify" -ForegroundColor Green
    } else {
        Write-Host "ÉCHEC: Le hook ne fonctionne toujours pas" -ForegroundColor Red
        Write-Host "Sortie de git commit:" -ForegroundColor Red
        Write-Host $commitOutput -ForegroundColor Red
    }
} else {
    Write-Host "Mode test - aucune modification effectuée" -ForegroundColor Blue
}

Write-Host ""
Write-Host "Terminé!" -ForegroundColor Green
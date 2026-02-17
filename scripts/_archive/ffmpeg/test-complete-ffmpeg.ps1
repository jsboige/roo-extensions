# Script complet pour tester ffmpeg avec markitdown
# Combine le rafraichissement du PATH et les tests
# Date: 2025-01-25
# Version: 1.0.0

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "      TEST COMPLET FFMPEG POUR MARKITDOWN      " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# ETAPE 1: Rafraichir le PATH
Write-Host "[ETAPE 1] Rafraichissement du PATH..." -ForegroundColor Yellow

# Recuperer les PATH systeme et utilisateur
$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")

# Combiner les deux
$env:PATH = "$machinePath;$userPath"

# Rechercher ffmpeg dans WinGet packages
$wingetBase = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
if (Test-Path $wingetBase) {
    $ffmpegExes = Get-ChildItem -Path $wingetBase -Recurse -Filter "ffmpeg.exe" -ErrorAction SilentlyContinue
    if ($ffmpegExes) {
        foreach ($exe in $ffmpegExes) {
            $binPath = Split-Path $exe.FullName -Parent
            if ($env:PATH -notlike "*$binPath*") {
                $env:PATH = "$env:PATH;$binPath"
                Write-Host "  Ajoute au PATH: $binPath" -ForegroundColor Green
            }
        }
    }
}

Write-Host "  OK: PATH rafraichi pour cette session" -ForegroundColor Green
Write-Host ""

# ETAPE 2: Tester ffmpeg
Write-Host "[ETAPE 2] Test de ffmpeg..." -ForegroundColor Yellow
$ffmpegTest = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpegTest) {
    Write-Host "  OK: ffmpeg trouve" -ForegroundColor Green
    Write-Host "  Chemin: $($ffmpegTest.Source)" -ForegroundColor Gray
    $ffmpegOk = $true
} else {
    Write-Host "  ERREUR: ffmpeg non trouve" -ForegroundColor Red
    $ffmpegOk = $false
}
Write-Host ""

# ETAPE 3: Tester pydub
Write-Host "[ETAPE 3] Test de pydub avec Python..." -ForegroundColor Yellow

# Creer le script Python de test
$pythonTest = @'
import warnings
import sys
import os

# Afficher le PATH vu par Python
print(f"PATH Python: {os.environ.get('PATH', 'Non defini')[:200]}...")

try:
    with warnings.catch_warnings(record=True) as w:
        warnings.simplefilter("always")
        import pydub
        
        if w:
            print(f"ATTENTION: {len(w)} warning(s)")
            for warning in w:
                print(f"  - {warning.category.__name__}: {warning.message}")
            sys.exit(1)
        else:
            print("OK: pydub sans warning")
            sys.exit(0)
            
except ImportError as e:
    print(f"ERREUR: {e}")
    sys.exit(2)
'@

$testFile = "$env:TEMP\test_pydub_complete.py"
Set-Content -Path $testFile -Value $pythonTest -Encoding UTF8

# Executer le test Python avec le PATH modifie
$env:PYTHONIOENCODING = "utf-8"
$pythonOutput = & python $testFile 2>&1
$pythonExitCode = $LASTEXITCODE

# Afficher resultat
if ($pythonExitCode -eq 0) {
    Write-Host "  $pythonOutput" -ForegroundColor Green
    $pydubOk = $true
} elseif ($pythonExitCode -eq 1) {
    Write-Host "  $pythonOutput" -ForegroundColor Yellow
    $pydubOk = $false
} else {
    Write-Host "  $pythonOutput" -ForegroundColor Red
    $pydubOk = $false
}

Remove-Item $testFile -ErrorAction SilentlyContinue
Write-Host ""

# ETAPE 4: Rendre permanent si tout est OK
if ($ffmpegOk -and -not $pydubOk) {
    Write-Host "[ETAPE 4] Configuration permanente du PATH..." -ForegroundColor Yellow
    
    # Obtenir le chemin de ffmpeg
    $ffmpegPath = Split-Path $ffmpegTest.Source -Parent
    
    # Verifier le PATH utilisateur actuel
    $currentUserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    if ($currentUserPath -notlike "*$ffmpegPath*") {
        Write-Host "  Ajout de ffmpeg au PATH utilisateur permanent..." -ForegroundColor Cyan
        
        # Ajouter au PATH utilisateur
        $newUserPath = if ($currentUserPath) { "$currentUserPath;$ffmpegPath" } else { $ffmpegPath }
        [System.Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
        
        Write-Host "  OK: PATH utilisateur mis a jour" -ForegroundColor Green
        Write-Host ""
        Write-Host "  IMPORTANT: Relancez le script pour verifier" -ForegroundColor Yellow
    } else {
        Write-Host "  Le PATH utilisateur contient deja ffmpeg" -ForegroundColor Green
    }
    Write-Host ""
}

# RESUME FINAL
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "                    RESULTAT                    " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if ($ffmpegOk -and $pydubOk) {
    Write-Host "SUCCES COMPLET!" -ForegroundColor Green
    Write-Host "  - ffmpeg est installe et accessible" -ForegroundColor Green
    Write-Host "  - pydub fonctionne sans warning" -ForegroundColor Green
    Write-Host "  - markitdown peut transcoder l'audio" -ForegroundColor Green
    Write-Host ""
    Write-Host "Le probleme est completement resolu!" -ForegroundColor Green
    exit 0
} elseif ($ffmpegOk -and -not $pydubOk) {
    Write-Host "PROGRES: ffmpeg OK mais pydub a encore le warning" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  1. Le PATH a ete configure" -ForegroundColor Gray
    Write-Host "  2. Fermez et rouvrez votre terminal" -ForegroundColor White
    Write-Host "  3. Relancez ce script" -ForegroundColor White
    exit 1
} else {
    Write-Host "ECHEC: Problemes non resolus" -ForegroundColor Red
    if (-not $ffmpegOk) {
        Write-Host "  - ffmpeg non accessible" -ForegroundColor Red
    }
    if (-not $pydubOk) {
        Write-Host "  - pydub ne peut pas utiliser ffmpeg" -ForegroundColor Red
    }
    exit 2
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
# Script de test pour verifier que ffmpeg fonctionne avec markitdown
# Date: 2025-01-25
# Version: 1.0.0

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "        TEST FFMPEG POUR MARKITDOWN MCP        " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Verifier que ffmpeg est accessible
Write-Host "[1/3] Test de ffmpeg..." -ForegroundColor Yellow
$ffmpegTest = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpegTest) {
    Write-Host "  OK: ffmpeg trouve dans PATH" -ForegroundColor Green
    Write-Host "  Chemin: $($ffmpegTest.Source)" -ForegroundColor Gray
    
    # Afficher version
    $version = & ffmpeg -version 2>&1 | Select-Object -First 1
    Write-Host "  Version: $version" -ForegroundColor Gray
    $ffmpegOk = $true
} else {
    Write-Host "  ERREUR: ffmpeg non trouve dans PATH" -ForegroundColor Red
    $ffmpegOk = $false
}
Write-Host ""

# Test 2: Creer un fichier Python de test pour pydub
Write-Host "[2/3] Test de pydub avec Python..." -ForegroundColor Yellow

$pythonTestContent = @'
import warnings
import sys

print("Test de pydub...")

try:
    # Capturer tous les warnings
    with warnings.catch_warnings(record=True) as captured_warnings:
        warnings.simplefilter("always")
        
        # Importer pydub
        import pydub
        
        # Verifier les warnings
        if captured_warnings:
            print(f"ATTENTION: {len(captured_warnings)} warning(s) detecte(s):")
            for w in captured_warnings:
                print(f"  - {w.category.__name__}: {w.message}")
            sys.exit(1)
        else:
            print("OK: pydub fonctionne sans warning")
            sys.exit(0)
            
except ImportError as e:
    print(f"ERREUR: pydub non installe - {e}")
    sys.exit(2)
except Exception as e:
    print(f"ERREUR inattendue: {e}")
    sys.exit(3)
'@

# Sauvegarder le script de test
$testFile = "$env:TEMP\test_pydub_ffmpeg.py"
Set-Content -Path $testFile -Value $pythonTestContent -Encoding UTF8

# Executer le test Python
$pythonOutput = & python $testFile 2>&1
$pythonExitCode = $LASTEXITCODE

# Afficher le resultat
switch ($pythonExitCode) {
    0 {
        Write-Host "  $pythonOutput" -ForegroundColor Green
        $pydubOk = $true
    }
    1 {
        Write-Host "  $pythonOutput" -ForegroundColor Yellow
        $pydubOk = $false
    }
    2 {
        Write-Host "  $pythonOutput" -ForegroundColor Red
        Write-Host "  Solution: pip install pydub" -ForegroundColor Cyan
        $pydubOk = $false
    }
    default {
        Write-Host "  $pythonOutput" -ForegroundColor Red
        $pydubOk = $false
    }
}

# Nettoyer
Remove-Item $testFile -ErrorAction SilentlyContinue
Write-Host ""

# Test 3: Test rapide avec markitdown si possible
Write-Host "[3/3] Test de markitdown MCP..." -ForegroundColor Yellow

$markitdownTestContent = @'
try:
    # Essayer d'importer markitdown
    from markitdown_mcp import __version__
    print(f"OK: markitdown MCP version {__version__ if hasattr('__version__', '__version__') else 'inconnue'}")
except ImportError:
    print("ATTENTION: markitdown MCP non installe")
except Exception as e:
    print(f"ERREUR: {e}")
'@

$testFile2 = "$env:TEMP\test_markitdown.py"
Set-Content -Path $testFile2 -Value $markitdownTestContent -Encoding UTF8

$markitdownOutput = & python $testFile2 2>&1
Write-Host "  $markitdownOutput" -ForegroundColor Gray

Remove-Item $testFile2 -ErrorAction SilentlyContinue
Write-Host ""

# RESUME FINAL
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "                    RESULTAT                    " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if ($ffmpegOk -and $pydubOk) {
    Write-Host "SUCCES: Tout fonctionne correctement!" -ForegroundColor Green
    Write-Host "  - ffmpeg est installe et accessible" -ForegroundColor Green
    Write-Host "  - pydub peut utiliser ffmpeg sans warning" -ForegroundColor Green
    Write-Host "  - markitdown peut maintenant transcoder l'audio" -ForegroundColor Green
    exit 0
} elseif ($ffmpegOk -and -not $pydubOk) {
    Write-Host "PARTIEL: ffmpeg OK mais pydub a des problemes" -ForegroundColor Yellow
    Write-Host "  - Verifiez l'installation de pydub: pip install pydub" -ForegroundColor Yellow
    Write-Host "  - Redemarrez votre terminal si necessaire" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "ECHEC: Des problemes subsistent" -ForegroundColor Red
    if (-not $ffmpegOk) {
        Write-Host "  - ffmpeg n'est pas accessible" -ForegroundColor Red
        Write-Host "    Solution: .\scripts\install-ffmpeg-windows.ps1" -ForegroundColor Cyan
    }
    if (-not $pydubOk) {
        Write-Host "  - pydub a des problemes" -ForegroundColor Red
        Write-Host "    Solution: pip install pydub" -ForegroundColor Cyan
    }
    exit 2
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
# Script de diagnostic pour ffmpeg
# Utilisé par markitdown MCP pour la transcription audio
# Date: 2025-01-25
# Version: 1.1.0

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "     DIAGNOSTIC FFMPEG POUR MARKITDOWN MCP     " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Variables de diagnostic
$ffmpegInPath = $false
$ffmpegInstalled = $false
$ffmpegPath = $null

# Test 1: Vérifier si ffmpeg est dans le PATH
Write-Host "[1/5] Vérification de ffmpeg dans le PATH..." -ForegroundColor Yellow
$ffmpegCommand = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpegCommand) {
    Write-Host "  ✓ ffmpeg trouvé dans PATH: $($ffmpegCommand.Source)" -ForegroundColor Green
    $ffmpegInPath = $true
    $ffmpegPath = $ffmpegCommand.Source
} else {
    Write-Host "  ✗ ffmpeg n'est pas dans le PATH" -ForegroundColor Red
}
Write-Host ""

# Test 2: Rechercher ffmpeg sur le système
Write-Host "[2/5] Recherche de ffmpeg sur le système..." -ForegroundColor Yellow
$searchPaths = @(
    "C:\ffmpeg\bin\ffmpeg.exe",
    "C:\Program Files\ffmpeg\bin\ffmpeg.exe",
    "C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe",
    "C:\Tools\ffmpeg\bin\ffmpeg.exe",
    "$env:USERPROFILE\ffmpeg\bin\ffmpeg.exe",
    "$env:USERPROFILE\Downloads\ffmpeg\bin\ffmpeg.exe",
    "$env:ProgramData\chocolatey\bin\ffmpeg.exe"
)

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        Write-Host "  ✓ Trouvé: $path" -ForegroundColor Green
        $ffmpegInstalled = $true
        if (-not $ffmpegPath) {
            $ffmpegPath = $path
        }
    }
}

# Recherche dans WinGet packages
$wingetPaths = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "ffmpeg.exe" -ErrorAction SilentlyContinue
if ($wingetPaths) {
    foreach ($wp in $wingetPaths) {
        Write-Host "  ✓ Trouvé (winget): $($wp.FullName)" -ForegroundColor Green
        $ffmpegInstalled = $true
        if (-not $ffmpegPath) {
            $ffmpegPath = $wp.FullName
        }
    }
}

if (-not $ffmpegInstalled) {
    Write-Host "  ✗ ffmpeg n'est pas installé sur le système" -ForegroundColor Red
}
Write-Host ""

# Test 3: Vérifier les entrées PATH
Write-Host "[3/5] Analyse des variables PATH..." -ForegroundColor Yellow
$pathEntries = $env:PATH -split ';' | Where-Object { $_ -like '*ffmpeg*' }
if ($pathEntries) {
    Write-Host "  Entrées PATH contenant 'ffmpeg':" -ForegroundColor Green
    foreach ($entry in $pathEntries) {
        Write-Host "    - $entry" -ForegroundColor Gray
    }
} else {
    Write-Host "  ✗ Aucune entrée PATH ne contient 'ffmpeg'" -ForegroundColor Red
}
Write-Host ""

# Test 4: Vérifier les gestionnaires de paquets
Write-Host "[4/5] Vérification des gestionnaires de paquets..." -ForegroundColor Yellow

# Winget
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "  Winget disponible - recherche ffmpeg..." -ForegroundColor Gray
} else {
    Write-Host "  - Winget non disponible" -ForegroundColor Gray
}

# Chocolatey
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "  Chocolatey disponible - recherche ffmpeg..." -ForegroundColor Gray
} else {
    Write-Host "  - Chocolatey non disponible" -ForegroundColor Gray
}
Write-Host ""

# Test 5: Test Python pydub
Write-Host "[5/5] Test de pydub dans Python..." -ForegroundColor Yellow

# Créer un fichier de test Python
$pythonTest = @'
import warnings
import sys

try:
    # Capturer les warnings
    with warnings.catch_warnings(record=True) as w:
        warnings.simplefilter("always")
        import pydub
        
        # Vérifier s'il y a des warnings
        if w:
            for warning in w:
                print(f"WARNING: {warning.message}", file=sys.stderr)
            sys.exit(1)
        else:
            print("OK")
            sys.exit(0)
except ImportError as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(2)
'@

$tempFile = [System.IO.Path]::GetTempFileName() + ".py"
Set-Content -Path $tempFile -Value $pythonTest

# Exécuter le test
$result = & python $tempFile 2>&1
$exitCode = $LASTEXITCODE

# Analyser le résultat
if ($exitCode -eq 0) {
    Write-Host "  ✓ pydub fonctionne sans warning" -ForegroundColor Green
    $pydubOk = $true
} elseif ($exitCode -eq 1) {
    Write-Host "  ⚠ pydub génère un warning ffmpeg" -ForegroundColor Yellow
    $pydubOk = $false
} else {
    Write-Host "  ✗ pydub n'est pas installé" -ForegroundColor Red
    Write-Host "    $result" -ForegroundColor Gray
    $pydubOk = $false
}

# Nettoyer
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
Write-Host ""

# RÉSUMÉ ET RECOMMANDATIONS
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "                    RÉSUMÉ                     " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if ($ffmpegInPath) {
    Write-Host "✅ FFMPEG EST DANS LE PATH" -ForegroundColor Green
    Write-Host "   Chemin: $ffmpegPath" -ForegroundColor Gray
} elseif ($ffmpegInstalled) {
    Write-Host "⚠️  FFMPEG INSTALLÉ MAIS PAS DANS LE PATH" -ForegroundColor Yellow
    Write-Host "   Chemin trouvé: $ffmpegPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Solution:" -ForegroundColor Cyan
    Write-Host "   1. Exécuter: .\scripts\fix-ffmpeg-path.ps1" -ForegroundColor White
    Write-Host "   OU" -ForegroundColor Gray
    Write-Host "   2. Ajouter manuellement au PATH: $(Split-Path $ffmpegPath -Parent)" -ForegroundColor White
} else {
    Write-Host "❌ FFMPEG N'EST PAS INSTALLÉ" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Solution:" -ForegroundColor Cyan
    Write-Host "   Exécuter: .\scripts\install-ffmpeg-windows.ps1" -ForegroundColor White
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Retourner le code de sortie approprié
if ($ffmpegInPath -and $pydubOk) {
    exit 0  # Tout est OK
} elseif ($ffmpegInstalled) {
    exit 1  # Configuration nécessaire
} else {
    exit 2  # Installation nécessaire
}
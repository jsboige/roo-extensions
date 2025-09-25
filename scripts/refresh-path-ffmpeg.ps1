# Script pour rafraichir le PATH et detecter ffmpeg
# Date: 2025-01-25
# Version: 1.0.0

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "    RAFRAICHISSEMENT DU PATH POUR FFMPEG       " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Rafraichir le PATH avec les variables systeme et utilisateur
Write-Host "Rafraichissement du PATH..." -ForegroundColor Yellow

# Recuperer les PATH systeme et utilisateur
$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")

# Combiner les deux
$newPath = "$machinePath;$userPath"

# Mettre a jour le PATH de la session courante
$env:PATH = $newPath

Write-Host "  OK: PATH rafraichi" -ForegroundColor Green
Write-Host ""

# Rechercher ffmpeg dans les emplacements connus de WinGet
Write-Host "Recherche de ffmpeg installe par WinGet..." -ForegroundColor Yellow

$wingetPaths = @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.0-full_build\bin",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-7.1-full_build\bin",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-7.0-full_build\bin"
)

# Recherche plus generale dans WinGet packages
$wingetBase = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
if (Test-Path $wingetBase) {
    Write-Host "  Recherche dans: $wingetBase" -ForegroundColor Gray
    
    # Trouver tous les ffmpeg.exe
    $ffmpegExes = Get-ChildItem -Path $wingetBase -Recurse -Filter "ffmpeg.exe" -ErrorAction SilentlyContinue
    
    if ($ffmpegExes) {
        foreach ($exe in $ffmpegExes) {
            $binPath = Split-Path $exe.FullName -Parent
            Write-Host "  Trouve: $binPath" -ForegroundColor Green
            
            # Ajouter au PATH si pas deja present
            if ($env:PATH -notlike "*$binPath*") {
                $env:PATH = "$env:PATH;$binPath"
                Write-Host "    Ajoute au PATH de la session" -ForegroundColor Cyan
            }
        }
    }
}

Write-Host ""

# Tester si ffmpeg est maintenant accessible
Write-Host "Test de ffmpeg..." -ForegroundColor Yellow
$ffmpegTest = Get-Command ffmpeg -ErrorAction SilentlyContinue

if ($ffmpegTest) {
    Write-Host "  OK: ffmpeg est maintenant accessible!" -ForegroundColor Green
    Write-Host "  Chemin: $($ffmpegTest.Source)" -ForegroundColor Gray
    
    # Afficher version
    $version = & ffmpeg -version 2>&1 | Select-Object -First 1
    Write-Host "  Version: $version" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "SUCCES: ffmpeg est pret a l'emploi!" -ForegroundColor Green
    
    # Sauvegarder le PATH pour les futures sessions (optionnel)
    Write-Host ""
    Write-Host "Pour rendre ce changement permanent:" -ForegroundColor Cyan
    Write-Host "  Executez: .\scripts\fix-ffmpeg-path.ps1" -ForegroundColor White
    
    exit 0
} else {
    Write-Host "  ERREUR: ffmpeg toujours non accessible" -ForegroundColor Red
    Write-Host ""
    Write-Host "Solutions:" -ForegroundColor Yellow
    Write-Host "  1. Fermer et rouvrir votre terminal" -ForegroundColor White
    Write-Host "  2. Ou executer: .\scripts\fix-ffmpeg-path.ps1" -ForegroundColor White
    
    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
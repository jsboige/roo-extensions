# Script pour ajouter ffmpeg au PATH système
# Date: 2025-01-25
# Version: 1.0.0

# Fonction pour vérifier les privilèges administrateur
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "       AJOUT DE FFMPEG AU PATH WINDOWS         " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si ffmpeg est déjà dans le PATH
$ffmpegInPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpegInPath) {
    Write-Host "✓ ffmpeg est déjà dans le PATH" -ForegroundColor Green
    Write-Host "  Chemin: $($ffmpegInPath.Source)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Aucune action nécessaire." -ForegroundColor Green
    exit 0
}

# Rechercher ffmpeg sur le système
Write-Host "Recherche de ffmpeg sur le système..." -ForegroundColor Yellow
$searchPaths = @(
    "C:\ffmpeg\bin",
    "C:\Program Files\ffmpeg\bin",
    "C:\Program Files (x86)\ffmpeg\bin",
    "C:\Tools\ffmpeg\bin",
    "$env:USERPROFILE\ffmpeg\bin",
    "$env:USERPROFILE\Downloads\ffmpeg\bin",
    "$env:ProgramData\chocolatey\bin"
)

$ffmpegPath = $null
foreach ($path in $searchPaths) {
    $ffmpegExe = Join-Path $path "ffmpeg.exe"
    if (Test-Path $ffmpegExe) {
        Write-Host "  ✓ Trouvé: $ffmpegExe" -ForegroundColor Green
        $ffmpegPath = $path
        break
    }
}

# Recherche dans WinGet packages
if (-not $ffmpegPath) {
    $wingetSearch = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "ffmpeg.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wingetSearch) {
        $ffmpegPath = Split-Path $wingetSearch.FullName -Parent
        Write-Host "  ✓ Trouvé (winget): $($wingetSearch.FullName)" -ForegroundColor Green
    }
}

if (-not $ffmpegPath) {
    Write-Host "  ✗ ffmpeg n'a pas été trouvé sur le système" -ForegroundColor Red
    Write-Host ""
    Write-Host "Veuillez d'abord installer ffmpeg:" -ForegroundColor Yellow
    Write-Host "  Exécuter: .\scripts\install-ffmpeg-windows.ps1" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "ffmpeg trouvé dans: $ffmpegPath" -ForegroundColor Cyan
Write-Host ""

# Demander le type de PATH à modifier
Write-Host "Où voulez-vous ajouter ffmpeg au PATH?" -ForegroundColor Yellow
Write-Host "  1. PATH Utilisateur (recommandé)" -ForegroundColor White
Write-Host "  2. PATH Système (nécessite les droits administrateur)" -ForegroundColor White
Write-Host "  3. Session courante seulement (temporaire)" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Votre choix (1/2/3)"

switch ($choice) {
    "1" {
        # Ajouter au PATH utilisateur
        Write-Host "Ajout au PATH utilisateur..." -ForegroundColor Cyan
        
        $currentUserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Vérifier si le chemin n'est pas déjà présent
        if ($currentUserPath -notlike "*$ffmpegPath*") {
            # Ajouter le nouveau chemin
            $newUserPath = if ($currentUserPath) { "$currentUserPath;$ffmpegPath" } else { $ffmpegPath }
            
            [System.Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
            
            Write-Host "  ✓ ffmpeg ajouté au PATH utilisateur" -ForegroundColor Green
            
            # Mettre à jour la session courante
            $env:PATH = "$env:PATH;$ffmpegPath"
            
            Write-Host ""
            Write-Host "✅ Configuration terminée!" -ForegroundColor Green
            Write-Host ""
            Write-Host "IMPORTANT: Redémarrez votre terminal ou VS Code pour appliquer les changements" -ForegroundColor Yellow
        } else {
            Write-Host "  ⚠ Le chemin est déjà dans le PATH utilisateur" -ForegroundColor Yellow
        }
    }
    
    "2" {
        # Ajouter au PATH système (nécessite admin)
        if (-not (Test-Administrator)) {
            Write-Host "  ✗ Privilèges administrateur requis" -ForegroundColor Red
            Write-Host ""
            Write-Host "Relancez le script en tant qu'administrateur:" -ForegroundColor Yellow
            Write-Host "  1. Clic droit sur PowerShell" -ForegroundColor Gray
            Write-Host "  2. 'Exécuter en tant qu'administrateur'" -ForegroundColor Gray
            Write-Host "  3. Exécuter: .\scripts\fix-ffmpeg-path.ps1" -ForegroundColor Gray
            exit 1
        }
        
        Write-Host "Ajout au PATH système..." -ForegroundColor Cyan
        
        $currentSystemPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        
        # Vérifier si le chemin n'est pas déjà présent
        if ($currentSystemPath -notlike "*$ffmpegPath*") {
            # Ajouter le nouveau chemin
            $newSystemPath = "$currentSystemPath;$ffmpegPath"
            
            [System.Environment]::SetEnvironmentVariable("PATH", $newSystemPath, "Machine")
            
            Write-Host "  ✓ ffmpeg ajouté au PATH système" -ForegroundColor Green
            
            # Mettre à jour la session courante
            $env:PATH = "$env:PATH;$ffmpegPath"
            
            Write-Host ""
            Write-Host "✅ Configuration terminée!" -ForegroundColor Green
            Write-Host ""
            Write-Host "IMPORTANT: Redémarrez votre terminal ou VS Code pour appliquer les changements" -ForegroundColor Yellow
        } else {
            Write-Host "  ⚠ Le chemin est déjà dans le PATH système" -ForegroundColor Yellow
        }
    }
    
    "3" {
        # Session courante seulement
        Write-Host "Ajout au PATH de la session courante..." -ForegroundColor Cyan
        
        $env:PATH = "$env:PATH;$ffmpegPath"
        
        Write-Host "  ✓ ffmpeg ajouté temporairement au PATH" -ForegroundColor Green
        Write-Host ""
        Write-Host "⚠ Cette modification sera perdue à la fermeture du terminal" -ForegroundColor Yellow
    }
    
    default {
        Write-Host "  ✗ Choix invalide" -ForegroundColor Red
        exit 1
    }
}

# Vérifier que ffmpeg fonctionne maintenant
Write-Host ""
Write-Host "Test de ffmpeg..." -ForegroundColor Cyan
$testFfmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($testFfmpeg) {
    Write-Host "  ✓ ffmpeg est maintenant accessible!" -ForegroundColor Green
    $version = & ffmpeg -version 2>&1 | Select-Object -First 1
    Write-Host "  Version: $version" -ForegroundColor Gray
} else {
    Write-Host "  ⚠ ffmpeg n'est pas encore accessible dans cette session" -ForegroundColor Yellow
    Write-Host "  Redémarrez votre terminal pour appliquer les changements" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
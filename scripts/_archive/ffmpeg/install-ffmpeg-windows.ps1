# Script d'installation de ffmpeg pour Windows
# Utilise winget (Windows Package Manager) pour installer ffmpeg
# Date: 2025-01-25
# Version: 1.0.1

param(
    [switch]$ForceReinstall = $false
)

# Fonction pour verifier les privileges administrateur
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "       INSTALLATION DE FFMPEG POUR WINDOWS     " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Verifier si ffmpeg est deja installe
$ffmpegExists = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpegExists -and -not $ForceReinstall) {
    Write-Host "OK: ffmpeg est deja installe et disponible dans le PATH" -ForegroundColor Green
    Write-Host "  Version:" -ForegroundColor Gray
    & ffmpeg -version 2>&1 | Select-Object -First 1
    Write-Host ""
    Write-Host "Pour reinstaller, utilisez: .\install-ffmpeg-windows.ps1 -ForceReinstall" -ForegroundColor Yellow
    exit 0
}

# Methode 1: Installation via winget (recommande)
Write-Host "[1] Tentative d'installation via winget..." -ForegroundColor Yellow

$wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
if ($wingetAvailable) {
    Write-Host "  OK: winget detecte" -ForegroundColor Green
    
    # Rechercher ffmpeg dans winget
    Write-Host "  Recherche de ffmpeg dans les packages..." -ForegroundColor Gray
    $searchResult = winget search ffmpeg 2>&1
    
    # Installer ffmpeg via winget
    Write-Host "  Installation de ffmpeg..." -ForegroundColor Cyan
    $installResult = winget install Gyan.FFmpeg --accept-source-agreements --accept-package-agreements 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK: ffmpeg installe avec succes via winget" -ForegroundColor Green
        
        # Rafraichir le PATH dans la session courante
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Verifier si ffmpeg est maintenant accessible
        $ffmpegPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($ffmpegPath) {
            Write-Host "  OK: ffmpeg est maintenant dans le PATH" -ForegroundColor Green
            Write-Host "    Chemin: $($ffmpegPath.Source)" -ForegroundColor Gray
        } else {
            Write-Host "  ATTENTION: ffmpeg installe mais pas encore dans le PATH" -ForegroundColor Yellow
            Write-Host "    Redemarrez votre terminal ou votre ordinateur" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "OK: Installation terminee!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "  ERREUR: Echec de l'installation via winget" -ForegroundColor Red
    }
} else {
    Write-Host "  ERREUR: winget n'est pas disponible" -ForegroundColor Red
}

Write-Host ""

# Methode 2: Installation manuelle
Write-Host "[2] Installation manuelle de ffmpeg..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Etapes pour installer ffmpeg manuellement:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Telecharger ffmpeg depuis: https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor White
Write-Host "   - Cliquez sur 'release full' pour obtenir la version complete" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Extraire l'archive ZIP dans C:\ffmpeg" -ForegroundColor White
Write-Host "   - Le dossier devrait contenir: C:\ffmpeg\bin\ffmpeg.exe" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Ajouter ffmpeg au PATH systeme:" -ForegroundColor White
Write-Host "   a. Ouvrir les Parametres systeme avances (sysdm.cpl)" -ForegroundColor Gray
Write-Host "   b. Cliquer sur 'Variables d'environnement'" -ForegroundColor Gray
Write-Host "   c. Dans 'Variables systeme', selectionner 'Path' et cliquer 'Modifier'" -ForegroundColor Gray
Write-Host "   d. Ajouter: C:\ffmpeg\bin" -ForegroundColor Gray
Write-Host "   e. Cliquer OK sur toutes les fenetres" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Redemarrer votre terminal ou VS Code" -ForegroundColor White
Write-Host ""

# Alternative avec chocolatey
$chocoAvailable = Get-Command choco -ErrorAction SilentlyContinue
if ($chocoAvailable) {
    Write-Host "Alternative: Installation via Chocolatey" -ForegroundColor Cyan
    Write-Host "  Executer en tant qu'administrateur:" -ForegroundColor White
    Write-Host "  choco install ffmpeg" -ForegroundColor Yellow
    Write-Host ""
}

# Script automatique de telechargement
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "     TELECHARGEMENT AUTOMATIQUE (OPTIONNEL)    " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$response = Read-Host "Voulez-vous telecharger ffmpeg automatiquement? (O/N)"
if ($response -eq 'O' -or $response -eq 'o') {
    Write-Host "Telechargement de ffmpeg..." -ForegroundColor Cyan
    
    # URL de telechargement direct de ffmpeg (version stable)
    $ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    $downloadPath = "$env:TEMP\ffmpeg.zip"
    $extractPath = "C:\ffmpeg"
    
    try {
        # Telecharger ffmpeg
        Write-Host "  Telechargement en cours..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $ffmpegUrl -OutFile $downloadPath -UseBasicParsing
        
        # Verifier les privileges pour C:\
        if (-not (Test-Administrator)) {
            Write-Host "  ATTENTION: Privileges administrateur requis pour installer dans C:\" -ForegroundColor Yellow
            $extractPath = "$env:USERPROFILE\ffmpeg"
            Write-Host "  Installation dans: $extractPath" -ForegroundColor Gray
        }
        
        # Extraire l'archive
        Write-Host "  Extraction de l'archive..." -ForegroundColor Gray
        Expand-Archive -Path $downloadPath -DestinationPath $env:TEMP -Force
        
        # Trouver le dossier ffmpeg extrait
        $ffmpegFolder = Get-ChildItem -Path $env:TEMP -Filter "ffmpeg-*" | Select-Object -First 1
        
        if ($ffmpegFolder) {
            # Creer le dossier de destination
            if (-not (Test-Path $extractPath)) {
                New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
            }
            
            # Copier les fichiers
            Write-Host "  Installation dans $extractPath..." -ForegroundColor Gray
            Copy-Item -Path "$($ffmpegFolder.FullName)\*" -Destination $extractPath -Recurse -Force
            
            Write-Host "  OK: ffmpeg installe dans: $extractPath" -ForegroundColor Green
            Write-Host ""
            Write-Host "IMPORTANT: Vous devez maintenant ajouter manuellement au PATH:" -ForegroundColor Yellow
            Write-Host "  $extractPath\bin" -ForegroundColor White
            Write-Host ""
            Write-Host "Ou executer: .\scripts\fix-ffmpeg-path.ps1" -ForegroundColor Cyan
        } else {
            Write-Host "  ERREUR: Probleme lors de l'extraction" -ForegroundColor Red
        }
        
        # Nettoyer
        Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
        if ($ffmpegFolder) {
            Remove-Item $ffmpegFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        
    } catch {
        Write-Host "  ERREUR lors du telechargement: $_" -ForegroundColor Red
        Write-Host "  Veuillez telecharger manuellement depuis: https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
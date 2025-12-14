# Nettoyage Préventif Multi-Composants - Mission Critique
# Phase 2: Suppression sécurisée fichiers temporaires

$ErrorActionPreference = "Continue"
$originalLocation = Get-Location

Write-Host "NETTOYAGE PREVENTIF MULTI-COMPOSANTS" -ForegroundColor Yellow
Write-Host "=" * 50

# Patterns de fichiers temporaires sûrs à supprimer
$tempPatterns = @(
    "*.tmp", "*.temp", "*.log", "*.bak", "*.swp", "*.swo",
    ".DS_Store", "Thumbs.db", "desktop.ini",
    "*~", "#*#", ".#*",
    "*.orig", "*.rej"
)

# Répertoires temporaires sûrs (mais vérifier contenu)
$tempDirs = @(
    "node_modules/.cache", ".next", ".vscode/", "coverage/",
    "*.egg-info", "__pycache__", ".pytest_cache"
)

try {
    Set-Location "d:/dev/roo-extensions"
    
    # ============================================================================
    # NETTOYAGE DEPOT PRINCIPAL
    # ============================================================================
    
    Write-Host "`nNETTOYAGE DEPOT PRINCIPAL:" -ForegroundColor Cyan
    $cleanedFiles = @()
    
    foreach ($pattern in $tempPatterns) {
        $files = Get-ChildItem -Path "." -Name $pattern -Recurse -ErrorAction SilentlyContinue | 
                 Where-Object { -not (Test-Path $_ -PathType Container) }
        
        foreach ($file in $files) {
            try {
                Remove-Item $file -Force -ErrorAction SilentlyContinue
                $cleanedFiles += $file
                Write-Host "  Supprime: $file" -ForegroundColor Gray
            } catch {
                Write-Host "  Echec suppression: $file" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "Depot principal: $($cleanedFiles.Count) fichiers temporaires supprimes" -ForegroundColor Green
    
    # ============================================================================
    # NETTOYAGE COMPOSANTS GIT
    # ============================================================================
    
    # Lister tous les sous-modules et composants
    $gitComponents = @()
    
    # Sous-modules officiels
    if (Test-Path ".gitmodules") {
        $submodules = git config --file .gitmodules --get-regexp path | ForEach-Object { 
            ($_ -split " ")[1] 
        }
        $gitComponents += $submodules
    }
    
    # Répertoires git indépendants
    $independentGit = Get-ChildItem -Directory | Where-Object { 
        Test-Path (Join-Path $_.FullName '.git') 
    } | ForEach-Object { $_.Name }
    
    $gitComponents += $independentGit
    $gitComponents = $gitComponents | Sort-Object | Get-Unique
    
    Write-Host "`nNETTOYAGE COMPOSANTS GIT:" -ForegroundColor Cyan
    
    foreach ($component in $gitComponents) {
        if (-not (Test-Path $component)) {
            Write-Host "  Composant absent: $component" -ForegroundColor Yellow
            continue
        }
        
        Write-Host "`n  COMPOSANT: $component" -ForegroundColor Magenta
        Push-Location $component -ErrorAction SilentlyContinue
        
        if ($?) {
            $componentCleaned = @()
            
            # Vérifier état Git avant nettoyage
            $gitStatus = git status --porcelain 2>$null
            $hasChanges = $null -ne $gitStatus
            
            if ($hasChanges) {
                Write-Host "    Changements detectes - Nettoyage conservateur" -ForegroundColor Yellow
            }
            
            # Nettoyage fichiers temporaires
            foreach ($pattern in $tempPatterns) {
                $files = Get-ChildItem -Path "." -Name $pattern -Recurse -ErrorAction SilentlyContinue |
                         Where-Object { -not (Test-Path $_ -PathType Container) }
                
                foreach ($file in $files) {
                    # Vérifier que le fichier n'est pas dans Git
                    $gitTracked = git ls-files $file 2>$null
                    if (-not $gitTracked) {
                        try {
                            Remove-Item $file -Force -ErrorAction SilentlyContinue
                            $componentCleaned += $file
                            Write-Host "    Supprime: $file" -ForegroundColor Gray
                        } catch {
                            Write-Host "    Echec: $file" -ForegroundColor Yellow
                        }
                    }
                }
            }
            
            # Nettoyage répertoires temporaires (avec précaution)
            foreach ($dirPattern in $tempDirs) {
                $dirs = Get-ChildItem -Path "." -Name $dirPattern -Recurse -Directory -ErrorAction SilentlyContinue
                
                foreach ($dir in $dirs) {
                    # Vérifications sécurité avant suppression répertoire
                    $isGitIgnored = git check-ignore $dir 2>$null
                    $isEmpty = -not (Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue)
                    
                    if ($isGitIgnored -or $isEmpty) {
                        try {
                            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
                            $componentCleaned += $dir
                            Write-Host "    Supprime repertoire: $dir" -ForegroundColor Gray
                        } catch {
                            Write-Host "    Echec repertoire: $dir" -ForegroundColor Yellow
                        }
                    }
                }
            }
            
            Write-Host "    Nettoye: $($componentCleaned.Count) elements" -ForegroundColor Green
            
            # Vérifier que Git n'est pas affecté
            $gitStatusAfter = git status --porcelain 2>$null
            if ($gitStatusAfter -ne $gitStatus) {
                Write-Host "    ATTENTION: Etat Git modifie par nettoyage" -ForegroundColor Red
            }
            
        } else {
            Write-Host "    Erreur acces composant" -ForegroundColor Red
        }
        
        Pop-Location
    }
    
    # ============================================================================
    # VERIFICATION POST-NETTOYAGE
    # ============================================================================
    
    Write-Host "`nVERIFICATION POST-NETTOYAGE:" -ForegroundColor Yellow
    
    # Vérifier état Git global
    $finalStatus = git status --porcelain
    Write-Host "Etat Git final:" -ForegroundColor Cyan
    if ($finalStatus) {
        $finalStatus | ForEach-Object { Write-Host "  $_" }
        Write-Host "Total changements: $($finalStatus.Count)" -ForegroundColor $(if ($finalStatus.Count -le 3) { 'Green' } else { 'Yellow' })
    } else {
        Write-Host "  Aucun changement" -ForegroundColor Green
    }
    
    # Vérifier sous-modules
    Write-Host "`nEtat sous-modules:" -ForegroundColor Cyan
    git submodule status | ForEach-Object { 
        $status = if ($_ -match "^\+") { "MODIFIE" } elseif ($_ -match "^-") { "NON_INIT" } else { "SYNC" }
        Write-Host "  $status : $_" -ForegroundColor $(if ($status -eq "SYNC") { 'Green' } else { 'Yellow' })
    }
    
    Write-Host "`nNETTOYAGE PREVENTIF TERMINE" -ForegroundColor Green
    Write-Host "=" * 50
    
} catch {
    Write-Host "ERREUR NETTOYAGE: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Set-Location $originalLocation
}
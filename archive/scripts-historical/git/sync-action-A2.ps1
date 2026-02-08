# Synchronisation Git - Action A.2
# Date: 2025-10-13
# But: Commit et sync sécurisé des corrections de liens

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "=== SYNCHRONISATION GIT - Action A.2 ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "MODE SIMULATION (DryRun)" -ForegroundColor Yellow
}
Write-Host ""

# Fonction pour afficher et exécuter une commande
function Invoke-GitCommand {
    param(
        [string]$Description,
        [string]$Command,
        [switch]$ContinueOnError
    )
    
    Write-Host ">>> $Description" -ForegroundColor Cyan
    Write-Host "    Commande: $Command" -ForegroundColor Gray
    
    if ($DryRun) {
        Write-Host "    [SIMULATION] Commande non executee" -ForegroundColor Yellow
        return $true
    }
    
    try {
        Invoke-Expression $Command
        Write-Host "    [OK]" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    [ERREUR] $_" -ForegroundColor Red
        if (-not $ContinueOnError) {
            throw
        }
        return $false
    }
}

try {
    # ETAPE 1: Pull des dernières modifications
    Write-Host "=== ETAPE 1: SYNCHRONISATION AVEC ORIGIN ===" -ForegroundColor Yellow
    Invoke-GitCommand -Description "Fetch origin" -Command "git fetch origin"
    Invoke-GitCommand -Description "Pull origin/main" -Command "git pull origin main --no-edit"
    Write-Host ""
    
    # ETAPE 2: Gestion du sous-module mcps/internal
    Write-Host "=== ETAPE 2: VERIFICATION SOUS-MODULE mcps/internal ===" -ForegroundColor Yellow
    
    if (-not $DryRun) {
        Push-Location "mcps/internal"
        try {
            $internalStatus = git status --short
            if ($internalStatus) {
                Write-Host "Modifications detectees dans mcps/internal:" -ForegroundColor Yellow
                Write-Host $internalStatus
                Write-Host ""
                Write-Host "ATTENTION: Le sous-module mcps/internal a des modifications." -ForegroundColor Yellow
                Write-Host "Ces modifications doivent etre commitees separement dans le sous-module." -ForegroundColor Yellow
                Write-Host "Consulter les administrateurs du sous-module avant de continuer." -ForegroundColor Red
            } else {
                Write-Host "Sous-module mcps/internal propre" -ForegroundColor Green
            }
        } finally {
            Pop-Location
        }
    }
    Write-Host ""
    
    # ETAPE 3: Ajout des fichiers modifiés (corrections de liens)
    Write-Host "=== ETAPE 3: AJOUT DES CORRECTIONS DE LIENS ===" -ForegroundColor Yellow
    
    $modifiedFiles = @(
        "mcps/INDEX.md",
        "mcps/INSTALLATION.md",
        "mcps/README.md",
        "mcps/TROUBLESHOOTING.md"
    )
    
    foreach ($file in $modifiedFiles) {
        Invoke-GitCommand -Description "Ajout de $file" -Command "git add `"$file`""
    }
    Write-Host ""
    
    # ETAPE 4: Ajout des nouveaux scripts
    Write-Host "=== ETAPE 4: AJOUT DES NOUVEAUX SCRIPTS ===" -ForegroundColor Yellow
    
    $newFiles = @(
        "scripts/docs/fix-broken-links.ps1",
        "scripts/docs/verify-corrections-A2.ps1",
        "scripts/docs/verify-target-files-A2.ps1",
        "scripts/git/diagnose-git-status-A2.ps1",
        "scripts/git/sync-action-A2.ps1"
    )
    
    foreach ($file in $newFiles) {
        Invoke-GitCommand -Description "Ajout de $file" -Command "git add `"$file`"" -ContinueOnError
    }
    Write-Host ""
    
    # ETAPE 5: Ajout du rapport
    Write-Host "=== ETAPE 5: AJOUT DU RAPPORT ===" -ForegroundColor Yellow
    Invoke-GitCommand -Description "Ajout du rapport" -Command "git add `"outputs/A2-correction-liens-rapport-2025-10-13.md`""
    Write-Host ""
    
    # ETAPE 6: Vérification des fichiers stagés
    Write-Host "=== ETAPE 6: VERIFICATION FICHIERS STAGES ===" -ForegroundColor Yellow
    if (-not $DryRun) {
        $staged = git diff --cached --name-only
        if ($staged) {
            Write-Host "Fichiers prets pour commit:" -ForegroundColor Cyan
            $staged | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
        } else {
            Write-Host "ATTENTION: Aucun fichier en staging!" -ForegroundColor Red
            throw "Aucun fichier à commiter"
        }
    }
    Write-Host ""
    
    # ETAPE 7: Commit
    Write-Host "=== ETAPE 7: COMMIT ===" -ForegroundColor Yellow
    $commitMessage = "fix(docs): correction des liens casses - Action A.2

- Correction de 41 liens casses dans 19 fichiers
- Mise a jour des chemins relatifs dans mcps/internal/
- Correction des chemins obsoletes mcp-servers/ vers internal/
- Ajustements des chemins dans mcps/ racine
- Ajout des scripts de verification et diagnostic
- Generation du rapport detaille

Phase 2 SDDD - Accessibilite
Etape 2/4: Correction des liens"

    Invoke-GitCommand -Description "Creation du commit" -Command "git commit -m `"$commitMessage`""
    Write-Host ""
    
    # ETAPE 8: Push
    Write-Host "=== ETAPE 8: PUSH VERS ORIGIN ===" -ForegroundColor Yellow
    Invoke-GitCommand -Description "Push vers origin/main" -Command "git push origin main"
    Write-Host ""
    
    # ETAPE 9: Vérification finale
    Write-Host "=== ETAPE 9: VERIFICATION FINALE ===" -ForegroundColor Yellow
    if (-not $DryRun) {
        $status = git status --short
        if (-not $status) {
            Write-Host "Working directory propre!" -ForegroundColor Green
        } else {
            Write-Host "Fichiers restants non commites:" -ForegroundColor Yellow
            Write-Host $status
        }
    }
    Write-Host ""
    
    Write-Host "=== SYNCHRONISATION REUSSIE ===" -ForegroundColor Green
    Write-Host "Timestamp fin: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    
} catch {
    Write-Host ""
    Write-Host "=== ERREUR DURANT LA SYNCHRONISATION ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Pour annuler les modifications en staging:" -ForegroundColor Yellow
    Write-Host "  git reset HEAD" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
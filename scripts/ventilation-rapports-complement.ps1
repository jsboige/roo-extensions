# Script complémentaire de ventilation des rapports restants
# Date: 2025-12-10
# Mission: Finaliser la ventilation des rapports dans docs/suivi/

# Rapports Git restants
$gitReports = @(
    @{ Fichier="git-analysis-20250527-103329.md"; Date="2025-05-27"; Nom="git-analysis-103329" },
    @{ Fichier="git-analysis-20250527-103446.md"; Date="2025-05-27"; Nom="git-analysis-103446" },
    @{ Fichier="git-commits-inventory-fix-20251016.md"; Date="2025-10-16"; Nom="git-commits-inventory-fix" },
    @{ Fichier="git-safety-spec-creation-20251007.md"; Date="2025-10-07"; Nom="git-safety-spec-creation" },
    @{ Fichier="git-sync-v1.0.14-20251015.md"; Date="2025-10-15"; Nom="git-sync-v1.0.14" }
)

# Rapports RooSync restants
$roosyncReports = @(
    @{ Fichier="roosync-correction-baseline-sddd-phase6-20251102.md"; Date="2025-11-02"; Nom="roosync-correction-baseline-sddd-phase6" },
    @{ Fichier="roosync-decision-bug-fix-20251019.md"; Date="2025-10-19"; Nom="roosync-decision-bug-fix" },
    @{ Fichier="roosync-differential-analysis-20251014.md"; Date="2025-10-14"; Nom="roosync-differential-analysis" },
    @{ Fichier="roosync-differential-critical-analysis-20251013.md"; Date="2025-10-13"; Nom="roosync-differential-critical-analysis" },
    @{ Fichier="roosync-etat-systeme-complet-20251023.md"; Date="2025-10-23"; Nom="roosync-etat-systeme-complet" },
    @{ Fichier="roosync-init-e2e-test-report-20251014.md"; Date="2025-10-14"; Nom="roosync-init-e2e-test-report" },
    @{ Fichier="roosync-inventory-collector-fix-20251016.md"; Date="2025-10-16"; Nom="roosync-inventory-collector-fix" },
    @{ Fichier="roosync-message-annonce-myia-web-01-20251103.md"; Date="2025-11-03"; Nom="roosync-message-annonce-myia-web-01" },
    @{ Fichier="roosync-messaging-e2e-test-report-20251016.md"; Date="2025-10-16"; Nom="roosync-messaging-e2e-test-report" },
    @{ Fichier="roosync-messaging-mission-complete-20251016.md"; Date="2025-10-16"; Nom="roosync-messaging-mission-complete" },
    @{ Fichier="roosync-messaging-phase1-implementation-20251016.md"; Date="2025-10-16"; Nom="roosync-messaging-phase1-implementation" },
    @{ Fichier="roosync-mission-status-20251019.md"; Date="2025-10-19"; Nom="roosync-mission-status" },
    @{ Fichier="roosync-powershell-integration-poc-20251014.md"; Date="2025-10-14"; Nom="roosync-powershell-integration-poc" },
    @{ Fichier="roosync-pre-sync-summary-20251019.md"; Date="2025-10-19"; Nom="roosync-pre-sync-summary" },
    @{ Fichier="roosync-pre-synchronization-ready-20251020.md"; Date="2025-10-20"; Nom="roosync-pre-synchronization-ready" },
    @{ Fichier="roosync-synchronization-preparation-report-20251019.md"; Date="2025-10-19"; Nom="roosync-synchronization-preparation-report" },
    @{ Fichier="roosync-synchronization-test-report-20251019.md"; Date="2025-10-19"; Nom="roosync-synchronization-test-report" },
    @{ Fichier="roosync-v2-architecture-analysis-20251020.md"; Date="2025-10-20"; Nom="roosync-v2-architecture-analysis" },
    @{ Fichier="roosync-v2-baseline-driven-architecture-design-20251020.md"; Date="2025-10-20"; Nom="roosync-v2-baseline-driven-architecture-design" },
    @{ Fichier="roosync-v2-baseline-driven-synthesis-20251020.md"; Date="2025-10-20"; Nom="roosync-v2-baseline-driven-synthesis" },
    @{ Fichier="roosync-v2-e2e-test-report-20251016.md"; Date="2025-10-16"; Nom="roosync-v2-e2e-test-report" },
    @{ Fichier="roosync-v2-validation-20251016.md"; Date="2025-10-16"; Nom="roosync-v2-validation" },
    @{ Fichier="roosync-verification-complete-20251103.md"; Date="2025-11-03"; Nom="roosync-verification-complete" },
    @{ Fichier="sync-roosync-integration-20251013.md"; Date="2025-10-13"; Nom="sync-roosync-integration" }
)

# Rapport MCP restant
$mcpReports = @(
    @{ Fichier="Rapport-Final-Mission-MCP-Ecosysteme.md"; Date="2025-12-05"; Nom="Rapport-Final-Mission-MCP-Ecosysteme" }
)

# Compteurs pour chaque catégorie
$compteurs = @{
    "Git" = 17
    "RooSync" = 36
    "MCP" = 12
}

Write-Host "🚀 DÉBUT DE LA VENTILATION COMPLÉMENTAIRE DES RAPPORTS" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green

# Ventilation des rapports Git
Write-Host "📁 Ventilation des rapports Git:" -ForegroundColor Yellow
foreach ($rapport in $gitReports) {
    $fichierSource = "roo-config/reports/$($rapport.Fichier)"
    $repertoireCible = "docs/suivi/Git"
    $date = $rapport.Date
    $nom = $rapport.Nom
    $compteur = $compteurs["Git"]
    
    # Format du nom cible: YYYY-MM-DD_XXX_Nom-du-rapport.md
    $nomCible = "$($date)_$($compteur.ToString('000'))_$($nom).md"
    $fichierCible = "$repertoireCible/$nomCible"
    
    Write-Host "   → $($rapport.Fichier)" -ForegroundColor Cyan
    
    if (Test-Path $fichierSource) {
        Move-Item -Path $fichierSource -Destination $fichierCible -Force
        $compteurs["Git"] = $compteur + 1
    }
}

# Ventilation des rapports RooSync
Write-Host "📁 Ventilation des rapports RooSync:" -ForegroundColor Yellow
foreach ($rapport in $roosyncReports) {
    $fichierSource = "roo-config/reports/$($rapport.Fichier)"
    $repertoireCible = "docs/suivi/RooSync"
    $date = $rapport.Date
    $nom = $rapport.Nom
    $compteur = $compteurs["RooSync"]
    
    # Format du nom cible: YYYY-MM-DD_XXX_Nom-du-rapport.md
    $nomCible = "$($date)_$($compteur.ToString('000'))_$($nom).md"
    $fichierCible = "$repertoireCible/$nomCible"
    
    Write-Host "   → $($rapport.Fichier)" -ForegroundColor Cyan
    
    if (Test-Path $fichierSource) {
        Move-Item -Path $fichierSource -Destination $fichierCible -Force
        $compteurs["RooSync"] = $compteur + 1
    }
}

# Ventilation des rapports MCP
Write-Host "📁 Ventilation des rapports MCP:" -ForegroundColor Yellow
foreach ($rapport in $mcpReports) {
    $fichierSource = "roo-config/reports/$($rapport.Fichier)"
    $repertoireCible = "docs/suivi/MCPs"
    $date = $rapport.Date
    $nom = $rapport.Nom
    $compteur = $compteurs["MCP"]
    
    # Format du nom cible: YYYY-MM-DD_XXX_Nom-du-rapport.md
    $nomCible = "$($date)_$($compteur.ToString('000'))_$($nom).md"
    $fichierCible = "$repertoireCible/$nomCible"
    
    Write-Host "   → $($rapport.Fichier)" -ForegroundColor Cyan
    
    if (Test-Path $fichierSource) {
        Move-Item -Path $fichierSource -Destination $fichierCible -Force
        $compteurs["MCP"] = $compteur + 1
    }
}

Write-Host ""
Write-Host "🎉 VENTILATION COMPLÉMENTAIRE TERMINÉE" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Afficher le résumé des compteurs
Write-Host "📊 RÉSUMÉ DES COMPTEURS FINAUX:" -ForegroundColor Magenta
foreach ($categorie in $compteurs.Keys) {
    Write-Host "   $categorie`: $($compteurs[$categorie])" -ForegroundColor White
}
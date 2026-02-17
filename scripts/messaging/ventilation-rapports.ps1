# Script de ventilation des rapports selon la structure SDDD
# Date: 2025-12-10
# Mission: Réorganisation des rapports dans docs/suivi/

# Définition des catégories et leurs répertoires cibles
$categories = @{
    "Orchestration" = "docs/suivi/Orchestration"
    "MCP" = "docs/suivi/MCPs"
    "SDDD" = "docs/suivi/SDDD"
    "Encoding" = "docs/suivi/Encoding"
    "Archives" = "docs/suivi/Archives"
    "RooStateManager" = "docs/suivi/RooStateManager"
}

# Rapports à ventiler avec leur catégorie
$rapportsAVentiler = @(
    @{ Fichier="rapport-final-synchronisation-coordination-20251127.md"; Categorie="Orchestration"; Date="2025-11-27"; Nom="rapport-final-synchronisation-coordination" },
    @{ Fichier="rapport-synchronisation-coordination-20251127.md"; Categorie="Orchestration"; Date="2025-11-27"; Nom="rapport-synchronisation-coordination" },
    @{ Fichier="RAPPORT-FINAL-OPTIMISATION-MCP-SDDD-24092025.md"; Categorie="MCP"; Date="2025-09-20"; Nom="RAPPORT-FINAL-OPTIMISATION-MCP-SDDD" },
    @{ Fichier="Rapport-Mission-Finale-MCP.md"; Categorie="MCP"; Date="2025-12-05"; Nom="Rapport-Mission-Finale-MCP" },
    @{ Fichier="Rapport-Execution-Validation-MCP.md"; Categorie="MCP"; Date="2025-12-05"; Nom="Rapport-Execution-Validation-MCP" },
    @{ Fichier="Plan-Validation-Globale-MCP.md"; Categorie="MCP"; Date="2025-12-05"; Nom="Plan-Validation-Globale-MCP" },
    @{ Fichier="Bilan-Ecosysteme-MCP.md"; Categorie="MCP"; Date="2025-12-05"; Nom="Bilan-Ecosysteme-MCP" },
    @{ Fichier="RAPPORT-CORRECTIONS-ENCODAGE-FINAL.md"; Categorie="Encoding"; Date="2025-12-05"; Nom="RAPPORT-CORRECTIONS-ENCODAGE-FINAL" },
    @{ Fichier="RAPPORT-CORRECTIONS-SYNC-ROO.md"; Categorie="Encoding"; Date="2025-12-05"; Nom="RAPPORT-CORRECTIONS-SYNC-ROO" },
    @{ Fichier="RAPPORT-VALIDATION-BASELINE-V2.1-SDDD-2025-12-05.md"; Categorie="SDDD"; Date="2025-12-05"; Nom="RAPPORT-VALIDATION-BASELINE-V2.1-SDDD" },
    @{ Fichier="RAPPORT-FINAL-VALIDATION-BASELINE-V2.1-SYNCHRONISATION-ORCHESTRATEUR-2025-12-05.md"; Categorie="SDDD"; Date="2025-12-05"; Nom="RAPPORT-FINAL-VALIDATION-BASELINE-V2.1-SYNCHRONISATION-ORCHESTRATEUR" },
    @{ Fichier="RAPPORT-REPARATION-MOCKS-VITEST-2025-12-05.md"; Categorie="SDDD"; Date="2025-12-05"; Nom="RAPPORT-REPARATION-MOCKS-VITEST" },
    @{ Fichier="RAPPORT-FINAL-MISSION-REPARATION-MOCKS-VITEST-ORCHESTRATEUR-2025-12-05.md"; Categorie="SDDD"; Date="2025-12-05"; Nom="RAPPORT-FINAL-MISSION-REPARATION-MOCKS-VITEST-ORCHESTRATEUR" },
    @{ Fichier="RAPPORT-CORRECTION-LOT-1-CONFIGURATION-2025-12-05.md"; Categorie="SDDD"; Date="2025-12-05"; Nom="RAPPORT-CORRECTION-LOT-1-CONFIGURATION" },
    @{ Fichier="RAPPORT-ETAT-ROOSYNC-ORCHESTRATEUR-2025-12-05.md"; Categorie="SDDD"; Date="2025-12-05"; Nom="RAPPORT-ETAT-ROOSYNC-ORCHESTRATEUR" },
    @{ Fichier="RAPPORT-CONSOLIDATION.md"; Categorie="Archives"; Date="2025-12-05"; Nom="RAPPORT-CONSOLIDATION" },
    @{ Fichier="RAPPORT-DEPLOIEMENT-FINAL.md"; Categorie="Archives"; Date="2025-12-05"; Nom="RAPPORT-DEPLOIEMENT-FINAL" },
    @{ Fichier="RAPPORT-NETTOYAGE-DEPOT-20250528.md"; Categorie="Archives"; Date="2025-05-28"; Nom="RAPPORT-NETTOYAGE-DEPOT" },
    @{ Fichier="PHASE54-RAPPORT-FINAL.md"; Categorie="Archives"; Date="2025-12-05"; Nom="PHASE54-RAPPORT-FINAL" },
    @{ Fichier="CONSOLIDATION-PHASE5-RAPPORT.md"; Categorie="Archives"; Date="2025-12-05"; Nom="CONSOLIDATION-PHASE5-RAPPORT" },
    @{ Fichier="Deployment-Strategy-20250924.md"; Categorie="Archives"; Date="2025-09-24"; Nom="Deployment-Strategy" },
    @{ Fichier="Execution-Report-Deployment-20250925.md"; Categorie="Archives"; Date="2025-09-25"; Nom="Execution-Report-Deployment" },
    @{ Fichier="final-recovery-complete-analysis-20251008.md"; Categorie="Archives"; Date="2025-10-08"; Nom="final-recovery-complete-analysis" },
    @{ Fichier="multi-agent-integration-recommendations.md"; Categorie="Archives"; Date="2025-10-08"; Nom="multi-agent-integration-recommendations" },
    @{ Fichier="multi-agent-system-safety-creation-20251008.md"; Categorie="Archives"; Date="2025-10-08"; Nom="multi-agent-system-safety-creation" },
    @{ Fichier="quickfiles-recovery-report-20250930.md"; Categorie="Archives"; Date="2025-09-30"; Nom="quickfiles-recovery-report" },
    @{ Fichier="Rapport-Escalade-Playwright.md"; Categorie="RooStateManager"; Date="2025-12-05"; Nom="Rapport-Escalade-Playwright" },
    @{ Fichier="validation-report-20250526-170406.md"; Categorie="Archives"; Date="2025-05-26"; Nom="validation-report-20250526-170406" },
    @{ Fichier="validation-test.md"; Categorie="Archives"; Date="2025-12-05"; Nom="validation-test" },
    @{ Fichier="cleanup-fantomes-20250527.md"; Categorie="Archives"; Date="2025-05-27"; Nom="cleanup-fantomes" },
    @{ Fichier="cleanup-reorganisation-20250527.md"; Categorie="Archives"; Date="2025-05-27"; Nom="cleanup-reorganisation" },
    @{ Fichier="cleanup-residual-20250527-105236.md"; Categorie="Archives"; Date="2025-05-27"; Nom="cleanup-residual-105236" },
    @{ Fichier="cleanup-residual-20250527-105320.md"; Categorie="Archives"; Date="2025-05-27"; Nom="cleanup-residual-105320" },
    @{ Fichier="PHASE3A-CHECKPOINT1-REPORT-20251108-112808.md"; Categorie="Archives"; Date="2025-11-08"; Nom="PHASE3A-CHECKPOINT1-REPORT" },
    @{ Fichier="PHASE3B-BASELINE-ANALYSIS-20251108-230417.md"; Categorie="Archives"; Date="2025-11-08"; Nom="PHASE3B-BASELINE-ANALYSIS" },
    @{ Fichier="PHASE3B-CHECKPOINT2-REPORT-20251110-010947.md"; Categorie="Archives"; Date="2025-11-10"; Nom="PHASE3B-CHECKPOINT2-REPORT-010947" },
    @{ Fichier="PHASE3B-CHECKPOINT2-REPORT-20251110-011055.md"; Categorie="Archives"; Date="2025-11-10"; Nom="PHASE3B-CHECKPOINT2-REPORT-011055" },
    @{ Fichier="PHASE3B-CHECKPOINT3-PREPARATION-20251110-011214.md"; Categorie="Archives"; Date="2025-11-10"; Nom="PHASE3B-CHECKPOINT3-PREPARATION-011214" },
    @{ Fichier="PHASE3B-CHECKPOINT3-PREPARATION-20251110-011303.md"; Categorie="Archives"; Date="2025-11-10"; Nom="PHASE3B-CHECKPOINT3-PREPARATION-011303" },
    @{ Fichier="PHASE3B-DIFF-ANALYSIS-20251110-005359.md"; Categorie="Archives"; Date="2025-11-10"; Nom="PHASE3B-DIFF-ANALYSIS" },
    @{ Fichier="Analyse-Anomalie-TotalSize.md"; Categorie="Archives"; Date="2025-12-05"; Nom="Analyse-Anomalie-TotalSize" },
    @{ Fichier="Analyse-Large-Extension-State.md"; Categorie="Archives"; Date="2025-12-05"; Nom="Analyse-Large-Extension-State" },
    @{ Fichier="machine-inventory-myia-po-2024-20251014.json"; Categorie="Archives"; Date="2025-10-14"; Nom="machine-inventory-myia-po-2024" },
    @{ Fichier="machine-inventory-test-syntax-validation-20251014.json"; Categorie="Archives"; Date="2025-10-14"; Nom="machine-inventory-test-syntax-validation" }
)

# Compteurs pour chaque catégorie
$compteurs = @{
    "Orchestration" = 31
    "MCP" = 7
    "SDDD" = 8
    "Encoding" = 2
    "Archives" = 50
    "RooStateManager" = 9
}

Write-Host "🚀 DÉBUT DE LA VENTILATION DES RAPPORTS SDDD" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

foreach ($rapport in $rapportsAVentiler) {
    $fichierSource = "roo-config/reports/$($rapport.Fichier)"
    $categorie = $rapport.Categorie
    $repertoireCible = $categories[$categorie]
    $date = $rapport.Date
    $nom = $rapport.Nom
    $compteur = $compteurs[$categorie]
    
    # Format du nom cible: YYYY-MM-DD_XXX_Nom-du-rapport.md
    $nomCible = "$($date)_$($compteur.ToString('000'))_$($nom).md"
    $fichierCible = "$repertoireCible/$nomCible"
    
    Write-Host "📁 Ventilation: $($rapport.Fichier)" -ForegroundColor Yellow
    Write-Host "   → Catégorie: $categorie" -ForegroundColor Cyan
    Write-Host "   → Cible: $fichierCible" -ForegroundColor Cyan
    
    if (Test-Path $fichierSource) {
        # Vérifier si le répertoire cible existe
        if (!(Test-Path $repertoireCible)) {
            New-Item -ItemType Directory -Path $repertoireCible -Force | Out-Null
            Write-Host "   ✅ Création du répertoire: $repertoireCible" -ForegroundColor Green
        }
        
        # Déplacer le fichier
        Move-Item -Path $fichierSource -Destination $fichierCible -Force
        Write-Host "   ✅ Fichier déplacé avec succès" -ForegroundColor Green
        
        # Incrémenter le compteur
        $compteurs[$categorie] = $compteur + 1
    } else {
        Write-Host "   ❌ Fichier source non trouvé: $fichierSource" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "🎉 VENTILATION TERMINÉE" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green

# Afficher le résumé des compteurs
Write-Host "📊 RÉSUMÉ DES COMPTEURS FINAUX:" -ForegroundColor Magenta
foreach ($categorie in $compteurs.Keys) {
    Write-Host "   $categorie`: $($compteurs[$categorie])" -ForegroundColor White
}
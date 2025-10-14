# Script: fix-broken-links.ps1
# Description: Correction automatique des liens casses suite a reorganisation docs/
# Date: 2025-10-12
# Phase: SDDD Action A.2

param(
    [switch]$WhatIf = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

# Definition des corrections (ancien pattern -> nouveau pattern)
$linkCorrections = @{
    # Corrections mcps/README.md
    'mcps/README.md' = @(
        @{ Old = '\./docs/missions/2025-01-13-synthese-reparations-mcp-sddd\.md'; New = '../docs/missions/2025-01-13-synthese-reparations-mcp-sddd.md' }
        @{ Old = 'docs/INSTALLATION\.md'; New = './INSTALLATION.md' }
        @{ Old = '\./docs/configuration-mcp-roo\.md'; New = '../docs/configuration/configuration-mcp-roo.md' }
        @{ Old = 'docs/TROUBLESHOOTING\.md'; New = './TROUBLESHOOTING.md' }
        @{ Old = 'docs/configuration-mcp-roo\.md'; New = '../docs/configuration/configuration-mcp-roo.md' }
        @{ Old = 'docs/MANUAL_START\.md'; New = './MANUAL_START.md' }
        @{ Old = 'docs/OPTIMIZATIONS\.md'; New = './OPTIMIZATIONS.md' }
    )
    
    # Corrections mcps/INDEX.md
    'mcps/INDEX.md' = @(
        @{ Old = '\./mcp-servers/docs/architecture\.md'; New = './internal/docs/architecture.md' }
        @{ Old = '\./mcp-servers/CONTRIBUTING\.md'; New = './internal/CONTRIBUTING.md' }
    )
    
    # Corrections mcps/INSTALLATION.md
    'mcps/INSTALLATION.md' = @(
        @{ Old = '\./mcp-servers/docs/troubleshooting\.md'; New = './internal/docs/troubleshooting.md' }
        @{ Old = '\./mcp-servers/docs/jupyter-mcp-troubleshooting\.md'; New = './internal/docs/jupyter-mcp-troubleshooting.md' }
        @{ Old = '\./mcp-servers/docs/architecture\.md'; New = './internal/docs/architecture.md' }
    )
    
    # Corrections mcps/TROUBLESHOOTING.md
    'mcps/TROUBLESHOOTING.md' = @(
        @{ Old = '\./docs/missions/2025-01-13-synthese-reparations-mcp-sddd\.md'; New = '../docs/missions/2025-01-13-synthese-reparations-mcp-sddd.md' }
    )
    
    # Corrections mcps/internal/README.md
    'mcps/internal/README.md' = @(
        @{ Old = 'docs/jupyter-mcp-troubleshooting\.md'; New = './docs/jupyter-mcp-troubleshooting.md' }
        @{ Old = 'docs/getting-started\.md'; New = './docs/getting-started.md' }
        @{ Old = 'docs/architecture\.md'; New = './docs/architecture.md' }
        @{ Old = 'docs/troubleshooting\.md'; New = './docs/troubleshooting.md' }
    )
    
    # Corrections mcps/internal/INDEX.md
    'mcps/internal/INDEX.md' = @(
        @{ Old = 'docs/quickfiles-guide\.md'; New = './docs/quickfiles-guide.md' }
        @{ Old = 'docs/quickfiles-use-cases\.md'; New = './docs/quickfiles-use-cases.md' }
        @{ Old = 'docs/quickfiles-integration\.md'; New = './docs/quickfiles-integration.md' }
        @{ Old = 'docs/jupyter-mcp-troubleshooting\.md'; New = './docs/jupyter-mcp-troubleshooting.md' }
        @{ Old = 'docs/jupyter-mcp-offline-mode\.md'; New = './docs/jupyter-mcp-offline-mode.md' }
        @{ Old = 'docs/jupyter-mcp-connection-test\.md'; New = './docs/jupyter-mcp-connection-test.md' }
        @{ Old = 'docs/architecture\.md'; New = './docs/architecture.md' }
        @{ Old = 'docs/getting-started\.md'; New = './docs/getting-started.md' }
        @{ Old = 'docs/troubleshooting\.md'; New = './docs/troubleshooting.md' }
    )
    
    # Corrections serveurs internes (pattern repetitif)
    'mcps/internal/servers/quickfiles-server/INSTALLATION.md' = @(
        @{ Old = '\.\./docs/quickfiles-use-cases\.md'; New = '../../docs/quickfiles-use-cases.md' }
    )
    'mcps/internal/servers/quickfiles-server/CONFIGURATION.md' = @(
        @{ Old = '\.\./docs/quickfiles-use-cases\.md'; New = '../../docs/quickfiles-use-cases.md' }
    )
    'mcps/internal/servers/quickfiles-server/USAGE.md' = @(
        @{ Old = '\.\./docs/quickfiles-use-cases\.md'; New = '../../docs/quickfiles-use-cases.md' }
    )
    'mcps/internal/servers/quickfiles-server/TROUBLESHOOTING.md' = @(
        @{ Old = '\.\./docs/quickfiles-use-cases\.md'; New = '../../docs/quickfiles-use-cases.md' }
    )
    
    'mcps/internal/servers/jupyter-mcp-server/INSTALLATION.md' = @(
        @{ Old = '\.\./docs/jupyter-mcp-use-cases\.md'; New = '../../docs/jupyter-mcp-use-cases.md' }
    )
    'mcps/internal/servers/jupyter-mcp-server/CONFIGURATION.md' = @(
        @{ Old = '\.\./docs/jupyter-mcp-use-cases\.md'; New = '../../docs/jupyter-mcp-use-cases.md' }
    )
    'mcps/internal/servers/jupyter-mcp-server/USAGE.md' = @(
        @{ Old = '\.\./docs/jupyter-mcp-use-cases\.md'; New = '../../docs/jupyter-mcp-use-cases.md' }
    )
    'mcps/internal/servers/jupyter-mcp-server/TROUBLESHOOTING.md' = @(
        @{ Old = '\.\./docs/jupyter-mcp-use-cases\.md'; New = '../../docs/jupyter-mcp-use-cases.md' }
    )
    
    'mcps/internal/servers/jinavigator-server/INSTALLATION.md' = @(
        @{ Old = '\.\./docs/jinavigator-use-cases\.md'; New = '../../docs/jinavigator-use-cases.md' }
    )
    'mcps/internal/servers/jinavigator-server/CONFIGURATION.md' = @(
        @{ Old = '\.\./docs/jinavigator-use-cases\.md'; New = '../../docs/jinavigator-use-cases.md' }
    )
    'mcps/internal/servers/jinavigator-server/USAGE.md' = @(
        @{ Old = '\.\./docs/jinavigator-use-cases\.md'; New = '../../docs/jinavigator-use-cases.md' }
    )
    'mcps/internal/servers/jinavigator-server/TROUBLESHOOTING.md' = @(
        @{ Old = '\.\./docs/jinavigator-use-cases\.md'; New = '../../docs/jinavigator-use-cases.md' }
    )
    
    'mcps/internal/README-JUPYTER-MCP.md' = @(
        @{ Old = 'docs/jupyter-mcp-troubleshooting\.md'; New = './docs/jupyter-mcp-troubleshooting.md' }
        @{ Old = 'docs/jupyter-mcp-offline-mode\.md'; New = './docs/jupyter-mcp-offline-mode.md' }
        @{ Old = 'docs/jupyter-mcp-connection-test\.md'; New = './docs/jupyter-mcp-connection-test.md' }
    )
}

Write-Host "=== CORRECTION DES LIENS CASSES - Phase 2 SDDD ===" -ForegroundColor Cyan
Write-Host ""

$totalFiles = $linkCorrections.Keys.Count
$totalCorrections = ($linkCorrections.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
$processedFiles = 0
$appliedCorrections = 0
$errors = 0

Write-Host "Plan de correction:" -ForegroundColor Yellow
Write-Host "   - Fichiers a traiter: $totalFiles" -ForegroundColor Gray
Write-Host "   - Corrections prevues: $totalCorrections" -ForegroundColor Gray
Write-Host ""

if ($WhatIf) {
    Write-Host "MODE SIMULATION (WhatIf active)" -ForegroundColor Yellow
    Write-Host ""
}

# Traitement fichier par fichier
foreach ($file in $linkCorrections.Keys) {
    $filePath = $file
    $corrections = $linkCorrections[$file]
    
    Write-Host "Fichier: $file ($($corrections.Count) corrections)" -ForegroundColor Green
    
    if (-not (Test-Path $filePath)) {
        Write-Host "   ERREUR: Fichier introuvable" -ForegroundColor Red
        $errors++
        continue
    }
    
    try {
        $content = Get-Content $filePath -Raw -Encoding UTF8
        $originalContent = $content
        $fileModified = $false
        
        foreach ($correction in $corrections) {
            $oldPattern = $correction.Old
            $newValue = $correction.New
            
            if ($content -match $oldPattern) {
                if ($WhatIf) {
                    Write-Host "   [SIMULATION] Remplacerait: $oldPattern -> $newValue" -ForegroundColor DarkGray
                } else {
                    $content = $content -replace $oldPattern, $newValue
                    $fileModified = $true
                    Write-Host "   Corrige: $oldPattern" -ForegroundColor DarkGreen
                    $appliedCorrections++
                    
                    if ($Verbose) {
                        Write-Host "      -> $newValue" -ForegroundColor DarkGray
                    }
                }
            } else {
                if ($Verbose) {
                    Write-Host "   Pattern non trouve: $oldPattern" -ForegroundColor Yellow
                }
            }
        }
        
        # Sauvegarder si modifie
        if ($fileModified -and -not $WhatIf) {
            Set-Content -Path $filePath -Value $content -Encoding UTF8 -NoNewline
            Write-Host "   Fichier sauvegarde" -ForegroundColor DarkGreen
        }
        
        $processedFiles++
        
    } catch {
        Write-Host "   ERREUR: $($_.Exception.Message)" -ForegroundColor Red
        $errors++
    }
    
    Write-Host ""
}

# Rapport final
Write-Host "=== RAPPORT FINAL ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Statistiques:" -ForegroundColor Yellow
Write-Host "   - Fichiers traites: $processedFiles / $totalFiles" -ForegroundColor Gray
Write-Host "   - Corrections appliquees: $appliedCorrections / $totalCorrections" -ForegroundColor Gray
Write-Host "   - Erreurs: $errors" -ForegroundColor $(if ($errors -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($WhatIf) {
    Write-Host "Pour executer reellement, relancez sans -WhatIf" -ForegroundColor Yellow
} elseif ($errors -eq 0 -and $appliedCorrections -gt 0) {
    Write-Host "CORRECTION TERMINEE AVEC SUCCES" -ForegroundColor Green
} elseif ($appliedCorrections -eq 0) {
    Write-Host "AUCUNE CORRECTION APPLIQUEE (verifier les patterns)" -ForegroundColor Yellow
} else {
    Write-Host "CORRECTION TERMINEE AVEC ERREURS" -ForegroundColor Red
    exit 1
}
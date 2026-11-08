# Vérification des corrections appliquées - Action A.2 Étape 3/4
# Date: 2025-10-13
# But: Vérifier que les corrections de liens ont été appliquées correctement

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "=== VERIFICATION DES CORRECTIONS - Action A.2 ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp`n" -ForegroundColor Gray

# Échantillon de vérifications ciblées
$verifications = @(
    @{
        File = "mcps/README.md"
        Pattern = "docs/configuration"
        Expected = $false
        Description = "Ancien pattern 'docs/configuration' ne devrait plus être présent"
    },
    @{
        File = "mcps/README.md"
        Pattern = "../docs/configuration/configuration-mcp-roo.md"
        Expected = $true
        Description = "Nouveau chemin '../docs/configuration/configuration-mcp-roo.md' devrait être présent"
    },
    @{
        File = "mcps/INSTALLATION.md"
        Pattern = "internal/docs"
        Expected = $true
        Description = "Chemins 'internal/docs' devraient être présents"
    },
    @{
        File = "mcps/INSTALLATION.md"
        Pattern = "./mcp-servers/docs"
        Expected = $false
        Description = "Ancien pattern './mcp-servers/docs' ne devrait plus être présent"
    },
    @{
        File = "mcps/internal/INDEX.md"
        Pattern = "./docs/"
        Expected = $true
        Description = "Chemins relatifs './docs/' devraient être présents"
    },
    @{
        File = "mcps/internal/README.md"
        Pattern = "docs/jupyter-mcp-troubleshooting"
        Expected = $false
        Description = "Pattern sans './' au début ne devrait plus être présent"
    },
    @{
        File = "mcps/INDEX.md"
        Pattern = "./internal/docs/architecture.md"
        Expected = $true
        Description = "Chemin './internal/docs/architecture.md' devrait être présent"
    }
)

$passed = 0
$failed = 0

Write-Host "Vérification de $($verifications.Count) points de contrôle..." -ForegroundColor Yellow

foreach ($check in $verifications) {
    $file = Join-Path $PSScriptRoot "..\..\$($check.File)"
    
    if (-not (Test-Path $file)) {
        Write-Host "  [SKIP] Fichier non trouvé: $($check.File)" -ForegroundColor Gray
        continue
    }
    
    $content = Get-Content $file -Raw -Encoding UTF8
    $found = $content -match [regex]::Escape($check.Pattern)
    
    if ($found -eq $check.Expected) {
        Write-Host "  [OK] $($check.Description)" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  [ÉCHEC] $($check.Description)" -ForegroundColor Red
        Write-Host "         Fichier: $($check.File)" -ForegroundColor Yellow
        Write-Host "         Pattern: '$($check.Pattern)'" -ForegroundColor Yellow
        Write-Host "         Attendu: $($check.Expected), Trouvé: $found" -ForegroundColor Yellow
        $failed++
    }
}

Write-Host "`n=== RÉSUMÉ ===" -ForegroundColor Cyan
Write-Host "Tests réussis: $passed / $($verifications.Count)" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })

if ($failed -gt 0) {
    Write-Host "Tests échoués: $failed" -ForegroundColor Red
    Write-Host "`nATTENTION: Certaines corrections n'ont pas été appliquées correctement!" -ForegroundColor Yellow
} else {
    Write-Host "`nToutes les vérifications ont réussi!" -ForegroundColor Green
}

Write-Host "`nTimestamp fin: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
# Script de diagnostic des MCPs - Étape 1 : Vérification de compilation
# Date: 2025-10-29
# Objectif: Vérifier l'état de compilation des MCPs internes en erreur

Write-Host "=== DIAGNOSTIC DES MCPs INTERNES ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

$servers = @(
    "quickfiles-server",
    "jinavigator-server", 
    "github-projects-mcp",
    "roo-state-manager"
)

$mcpStatus = @{}

foreach ($server in $servers) {
    Write-Host "=== $server ===" -ForegroundColor Yellow
    
    $serverPath = "mcps/internal/servers/$server"
    $buildPath = "$serverPath/build"
    $distPath = "$serverPath/dist"
    
    $status = @{
        "server" = $server
        "buildExists" = $false
        "distExists" = $false
        "mainFile" = $null
        "packageJson" = $false
        "nodeModules" = $false
    }
    
    # Vérification des répertoires de compilation
    if (Test-Path $buildPath) {
        $status.buildExists = $true
        Write-Host "✅ Build directory exists" -ForegroundColor Green
        $buildFiles = Get-ChildItem $buildPath -Name
        Write-Host "   Files: $($buildFiles -join ', ')" -ForegroundColor Gray
        
        # Vérifier le fichier principal
        $mainFile = "$buildPath/index.js"
        if (Test-Path $mainFile) {
            $status.mainFile = $mainFile
            Write-Host "✅ Main file found: index.js" -ForegroundColor Green
        }
    }
    
    if (Test-Path $distPath) {
        $status.distExists = $true
        Write-Host "✅ Dist directory exists" -ForegroundColor Green
        $distFiles = Get-ChildItem $distPath -Name
        Write-Host "   Files: $($distFiles -join ', ')" -ForegroundColor Gray
        
        # Vérifier le fichier principal
        $mainFile = "$distPath/index.js"
        if (Test-Path $mainFile) {
            $status.mainFile = $mainFile
            Write-Host "✅ Main file found: index.js" -ForegroundColor Green
        }
    }
    
    if (-not $status.buildExists -and -not $status.distExists) {
        Write-Host "❌ No build or dist directory found" -ForegroundColor Red
    }
    
    # Vérification de package.json
    $packageJsonPath = "$serverPath/package.json"
    if (Test-Path $packageJsonPath) {
        $status.packageJson = $true
        Write-Host "✅ package.json exists" -ForegroundColor Green
    } else {
        Write-Host "❌ package.json missing" -ForegroundColor Red
    }
    
    # Vérification de node_modules
    $nodeModulesPath = "$serverPath/node_modules"
    if (Test-Path $nodeModulesPath) {
        $status.nodeModules = $true
        Write-Host "✅ node_modules exists" -ForegroundColor Green
    } else {
        Write-Host "❌ node_modules missing" -ForegroundColor Red
    }
    
    $mcpStatus[$server] = $status
    Write-Host ""
}

# Résumé du diagnostic
Write-Host "=== RÉSUMÉ DU DIAGNOSTIC ===" -ForegroundColor Cyan
Write-Host ""

foreach ($server in $servers) {
    $status = $mcpStatus[$server]
    $issues = @()
    
    if (-not $status.buildExists -and -not $status.distExists) {
        $issues += "Pas de compilation"
    }
    if (-not $status.mainFile) {
        $issues += "Fichier principal manquant"
    }
    if (-not $status.packageJson) {
        $issues += "package.json manquant"
    }
    if (-not $status.nodeModules) {
        $issues += "Dépendances non installées"
    }
    
    if ($issues.Count -eq 0) {
        Write-Host "✅ $($status.server): OK" -ForegroundColor Green
    } else {
        Write-Host "❌ $($status.server): $($issues -join ', ')" -ForegroundColor Red
    }
}

# Export du rapport
$reportPath = "scripts/mcp-diagnostic-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$mcpStatus | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath
Write-Host ""
Write-Host "Rapport détaillé exporté vers: $reportPath" -ForegroundColor Cyan
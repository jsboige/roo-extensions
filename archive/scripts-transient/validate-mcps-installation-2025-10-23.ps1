# Script de validation de l'installation des MCPs internes
# Date: 2025-10-23
# Objectif: Valider que tous les MCPs internes sont correctement configurés

Write-Host "=== VALIDATION DE L'INSTALLATION DES MCPs INTERNES ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host ""

# Chemin du fichier mcp_settings.json
$mcpSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

# Lire le fichier JSON
try {
    $mcpSettings = Get-Content $mcpSettingsPath -Raw | ConvertFrom-Json
    Write-Host "Fichier mcp_settings.json charge avec succes" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Impossible de lire le fichier mcp_settings.json" -ForegroundColor Red
    exit 1
}

# Liste des MCPs internes à valider
$internalMcpNames = @(
    "quickfiles-server",
    "jinavigator-server",
    "jupyter-mcp-server",
    "jupyter-papermill-mcp-server",
    "github-projects-mcp",
    "roo-state-manager"
)

$validationResults = @()

Write-Host "=== VALIDATION DES MCPs INTERNES ===" -ForegroundColor Cyan

foreach ($mcpName in $internalMcpNames) {
    Write-Host ""
    Write-Host "--- Validation de $mcpName ---" -ForegroundColor Yellow
    
    if ($mcpSettings.mcpServers.ContainsKey($mcpName)) {
        $mcpConfig = $mcpSettings.mcpServers[$mcpName]
        $isValid = $true
        $issues = @()
        
        # Vérifier la commande
        if (-not $mcpConfig.command) {
            $issues += "Commande manquante"
            $isValid = $false
        }
        
        # Vérifier les arguments
        if (-not $mcpConfig.args -or $mcpConfig.args.Count -eq 0) {
            $issues += "Arguments manquants"
            $isValid = $false
        } else {
            # Vérifier que le fichier exécutable existe
            $executablePath = $mcpConfig.args[0]
            if (Test-Path $executablePath) {
                Write-Host "  Fichier executable: OK ($executablePath)" -ForegroundColor Green
            } else {
                $issues += "Fichier executable non trouve: $executablePath"
                $isValid = $false
            }
        }
        
        # Vérifier le statut disabled
        if ($mcpConfig.disabled) {
            $issues += "MCP desactive"
            $isValid = $false
        }
        
        # Ajouter le résultat
        $validationResults += @{
            Name = $mcpName
            IsValid = $isValid
            Issues = $issues
            Config = $mcpConfig
        }
        
        if ($isValid) {
            Write-Host "  Statut: VALIDE" -ForegroundColor Green
        } else {
            Write-Host "  Statut: INVALIDE" -ForegroundColor Red
            $issues | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        }
    } else {
        Write-Host "  Statut: MANQUANT" -ForegroundColor Red
        $validationResults += @{
            Name = $mcpName
            IsValid = $false
            Issues = @("MCP non configure dans mcp_settings.json")
            Config = $null
        }
    }
}

# Resume de la validation
Write-Host ""
Write-Host "=== RESUME DE LA VALIDATION ===" -ForegroundColor Magenta

$validCount = ($validationResults | Where-Object { $_.IsValid -eq $true }).Count
$totalCount = $validationResults.Count

Write-Host "MCPs valides: $validCount/$totalCount" -ForegroundColor $(if($validCount -eq $totalCount) {"Green"} else {"Yellow"})

if ($validCount -eq $totalCount) {
    Write-Host "✅ Tous les MCPs internes sont valides" -ForegroundColor Green
} else {
    Write-Host "❌ Certains MCPs internes ont des problèmes" -ForegroundColor Red
    Write-Host ""
    Write-Host "MCPs avec des problèmes:" -ForegroundColor Yellow
    $validationResults | Where-Object { $_.IsValid -eq $false } | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.Issues -join ', ')" -ForegroundColor Red
    }
}

# Vérification des dépendances système
Write-Host ""
Write-Host "=== VERIFICATION DES DEPENDANCES SYSTEME ===" -ForegroundColor Cyan

# Vérifier Node.js
try {
    $nodeVersion = node --version 2>$null
    Write-Host "Node.js: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "Node.js: Non installe" -ForegroundColor Red
}

# Vérifier Python
try {
    $pythonVersion = python --version 2>$null
    Write-Host "Python: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "Python: Non installe" -ForegroundColor Red
}

# Vérifier npm
try {
    $npmVersion = npm --version 2>$null
    Write-Host "npm: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "npm: Non installe" -ForegroundColor Red
}

# Vérifier pip
try {
    $pipVersion = pip --version 2>$null
    Write-Host "pip: $pipVersion" -ForegroundColor Green
} catch {
    Write-Host "pip: Non installe" -ForegroundColor Red
}

# Test de connexion rapide pour un MCP
Write-Host ""
Write-Host "=== TEST DE CONNEXION RAPIDE ===" -ForegroundColor Cyan

# Tester quickfiles-server
$quickfilesPath = "C:\dev\roo-extensions\mcps\internal\servers\quickfiles-server\build\index.js"
if (Test-Path $quickfilesPath) {
    Write-Host "Test de quickfiles-server..." -ForegroundColor Gray
    try {
        $testResult = node $quickfilesPath --help 2>&1 | Select-Object -First 5
        if ($testResult) {
            Write-Host "quickfiles-server: Repond correctement" -ForegroundColor Green
        }
    } catch {
        Write-Host "quickfiles-server: Erreur de test" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== VALIDATION TERMINEE ===" -ForegroundColor Magenta
# Script de correction des MCPs - Étape 3 : Correction des problèmes identifiés
# Date: 2025-10-29
# Objectif: Corriger les problèmes spécifiques identifiés lors du diagnostic

Write-Host "=== CORRECTION DES MCPs ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Problème 1: markitdown - Chemin Python incorrect
Write-Host "=== CORRECTION 1: markitdown - Chemin Python ===" -ForegroundColor Yellow

# Rechercher l'installation Python correcte
$pythonPaths = @(
    "C:\Users\jsboi\AppData\Local\Programs\Python\Python310\python.exe",
    "C:\Users\jsboi\AppData\Local\Programs\Python\Python311\python.exe",
    "C:\Users\jsboi\AppData\Local\Programs\Python\Python312\python.exe",
    "C:\Python310\python.exe",
    "C:\Python311\python.exe",
    "C:\Python312\python.exe",
    "python.exe",
    "python3.exe"
)

$foundPython = $null
foreach ($path in $pythonPaths) {
    if (Test-Path $path) {
        $foundPython = $path
        Write-Host "✅ Python trouvé: $path" -ForegroundColor Green
        break
    }
}

if (-not $foundPython) {
    Write-Host "❌ Aucune installation Python trouvée" -ForegroundColor Red
    Write-Host "Tentative d'installation via winget..." -ForegroundColor Yellow
    try {
        winget install Python.Python.3.11 --silent
        Write-Host "✅ Python 3.11 installé via winget" -ForegroundColor Green
        $foundPython = "C:\Users\jsboi\AppData\Local\Programs\Python\Python311\python.exe"
    } catch {
        Write-Host "❌ Échec de l'installation Python: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Vérifier si markitdown_mcp est installé
if ($foundPython) {
    try {
        $result = & $foundPython -m pip list | Select-String "markitdown"
        if ($result) {
            Write-Host "✅ markitdown_mcp est déjà installé" -ForegroundColor Green
        } else {
            Write-Host "Installation de markitdown_mcp..." -ForegroundColor Yellow
            & $foundPython -m pip install markitdown-mcp
            Write-Host "✅ markitdown_mcp installé" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Erreur lors de la vérification/installation de markitdown_mcp: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Problème 2: playwright - Module manquant
Write-Host "=== CORRECTION 2: playwright - Module manquant ===" -ForegroundColor Yellow

try {
    Write-Host "Réinstallation de @playwright/mcp..." -ForegroundColor Yellow
    npm install -g @playwright/mcp
    Write-Host "✅ @playwright/mcp réinstallé" -ForegroundColor Green
    
    Write-Host "Installation des navigateurs Playwright..." -ForegroundColor Yellow
    npx playwright install chromium
    Write-Host "✅ Navigateurs Playwright installés" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur lors de l'installation de Playwright: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Problème 3: MCPs internes qui s'arrêtent immédiatement
Write-Host "=== CORRECTION 3: MCPs internes - Dépendances manquantes ===" -ForegroundColor Yellow

$internalMCPs = @(
    "quickfiles-server",
    "jinavigator-server", 
    "github-projects-mcp",
    "roo-state-manager"
)

foreach ($mcp in $internalMCPs) {
    Write-Host "Vérification des dépendances pour $mcp..." -ForegroundColor Gray
    
    $mcpPath = "mcps/internal/servers/$mcp"
    
    if (Test-Path "$mcpPath/package.json") {
        Set-Location $mcpPath
        
        try {
            Write-Host "Installation des dépendances pour $mcp..." -ForegroundColor Yellow
            npm install
            Write-Host "✅ Dépendances installées pour $mcp" -ForegroundColor Green
        } catch {
            Write-Host "❌ Erreur lors de l'installation des dépendances pour $mcp: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Recompilation si nécessaire
        if (Test-Path "$mcpPath/tsconfig.json") {
            try {
                Write-Host "Recompilation de $mcp..." -ForegroundColor Yellow
                npm run build
                Write-Host "✅ $mcp recompilé" -ForegroundColor Green
            } catch {
                Write-Host "❌ Erreur lors de la recompilation de $mcp: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Set-Location "C:/dev/roo-extensions"
    } else {
        Write-Host "❌ package.json non trouvé pour $mcp" -ForegroundColor Red
    }
}

Write-Host ""

# Problème 4: github-projects-mcp - Serveur HTTP non démarré
Write-Host "=== CORRECTION 4: github-projects-mcp - Démarrage serveur HTTP ===" -ForegroundColor Yellow

$githubMcpPath = "mcps/internal/servers/github-projects-mcp"
Set-Location $githubMcpPath

try {
    Write-Host "Démarrage du serveur HTTP pour github-projects-mcp..." -ForegroundColor Yellow
    
    # Vérifier si le script de démarrage existe
    if (Test-Path "package.json") {
        $packageJson = Get-Content "package.json" | ConvertFrom-Json
        if ($packageJson.scripts.start) {
            Write-Host "Démarrage via npm start..." -ForegroundColor Gray
            Start-Process -FilePath "npm" -ArgumentList "start" -WindowStyle Minimized
            Write-Host "✅ Serveur démarré en arrière-plan" -ForegroundColor Green
        } else {
            Write-Host "Démarrage direct du serveur..." -ForegroundColor Gray
            Start-Process -FilePath "node" -ArgumentList "dist/index.js" -WindowStyle Minimized
            Write-Host "✅ Serveur démarré en arrière-plan" -ForegroundColor Green
        }
    }
    
    # Attendre un peu que le serveur démarre
    Start-Sleep -Seconds 3
    
    # Test de connexion
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:3001/health" -TimeoutSec 5
        Write-Host "✅ Serveur HTTP répond correctement" -ForegroundColor Green
    } catch {
        Write-Host "❌ Le serveur ne répond pas encore: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Erreur lors du démarrage du serveur: $($_.Exception.Message)" -ForegroundColor Red
}

Set-Location "C:/dev/roo-extensions"

Write-Host ""

# Mise à jour du fichier mcp_settings.json si nécessaire
Write-Host "=== CORRECTION 5: Mise à jour mcp_settings.json ===" -ForegroundColor Yellow

if ($foundPython) {
    Write-Host "Mise à jour du chemin Python pour markitdown..." -ForegroundColor Gray
    
    $settingsPath = "../../Users/jsboi/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"
    
    if (Test-Path $settingsPath) {
        # Sauvegarde du fichier original
        $backupPath = "$settingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $settingsPath $backupPath
        Write-Host "✅ Sauvegarde créée: $backupPath" -ForegroundColor Green
        
        # Lecture et modification du fichier
        $settings = Get-Content $settingsPath | ConvertFrom-Json
        
        # Mise à jour du chemin Python pour markitdown
        if ($settings.mcpServers.markitdown) {
            $settings.mcpServers.markitdown.args[1] = $foundPython
            Write-Host "✅ Chemin Python mis à jour pour markitdown: $foundPython" -ForegroundColor Green
        }
        
        # Sauvegarde du fichier modifié
        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
        Write-Host "✅ mcp_settings.json mis à jour" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== FIN DES CORRECTIONS ===" -ForegroundColor Cyan
Write-Host "Redémarrez VS Code pour appliquer les modifications." -ForegroundColor Yellow
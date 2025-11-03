# Script de correction simple des MCPs
Write-Host "=== CORRECTION DES MCPs ===" -ForegroundColor Cyan

# 1. Recherche Python
Write-Host "Recherche de Python..." -ForegroundColor Yellow
$pythonPath = "python.exe"
if (Test-Path "C:\Users\jsboi\AppData\Local\Programs\Python\Python310\python.exe") {
    $pythonPath = "C:\Users\jsboi\AppData\Local\Programs\Python\Python310\python.exe"
    Write-Host "Python 3.10 trouvé" -ForegroundColor Green
} elseif (Test-Path "C:\Users\jsboi\AppData\Local\Programs\Python\Python311\python.exe") {
    $pythonPath = "C:\Users\jsboi\AppData\Local\Programs\Python\Python311\python.exe"
    Write-Host "Python 3.11 trouvé" -ForegroundColor Green
} else {
    Write-Host "Installation de Python..." -ForegroundColor Yellow
    winget install Python.Python.3.11 --silent
    $pythonPath = "C:\Users\jsboi\AppData\Local\Programs\Python\Python311\python.exe"
}

# 2. Installation markitdown
Write-Host "Installation de markitdown-mcp..." -ForegroundColor Yellow
try {
    & $pythonPath -m pip install markitdown-mcp
    Write-Host "markitdown-mcp installé" -ForegroundColor Green
} catch {
    Write-Host "Erreur installation markitdown-mcp" -ForegroundColor Red
}

# 3. Installation playwright
Write-Host "Installation de Playwright..." -ForegroundColor Yellow
try {
    npm install -g @playwright/mcp
    npx playwright install chromium
    Write-Host "Playwright installé" -ForegroundColor Green
} catch {
    Write-Host "Erreur installation Playwright" -ForegroundColor Red
}

# 4. Installation dépendances MCPs internes
$mcpList = @("quickfiles-server", "jinavigator-server", "github-projects-mcp", "roo-state-manager")

foreach ($mcp in $mcpList) {
    Write-Host "Installation dépendances $mcp..." -ForegroundColor Yellow
    Set-Location "mcps/internal/servers/$mcp"
    
    try {
        npm install
        Write-Host "Dépendances $mcp installées" -ForegroundColor Green
    } catch {
        Write-Host "Erreur dépendances $mcp" -ForegroundColor Red
    }
    
    if (Test-Path "tsconfig.json") {
        try {
            npm run build
            Write-Host "$mcp recompilé" -ForegroundColor Green
        } catch {
            Write-Host "Erreur compilation $mcp" -ForegroundColor Red
        }
    }
    
    Set-Location "C:/dev/roo-extensions"
}

# 5. Démarrage serveur github-projects-mcp
Write-Host "Démarrage serveur github-projects-mcp..." -ForegroundColor Yellow
Set-Location "mcps/internal/servers/github-projects-mcp"
try {
    Start-Process -FilePath "node" -ArgumentList "dist/index.js" -WindowStyle Minimized
    Write-Host "Serveur démarré" -ForegroundColor Green
} catch {
    Write-Host "Erreur démarrage serveur" -ForegroundColor Red
}
Set-Location "C:/dev/roo-extensions"

# 6. Mise à jour mcp_settings.json
Write-Host "Mise à jour mcp_settings.json..." -ForegroundColor Yellow
$settingsPath = "../../Users/jsboi/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"

if (Test-Path $settingsPath) {
    Copy-Item $settingsPath "$settingsPath.backup"
    $settings = Get-Content $settingsPath | ConvertFrom-Json
    $settings.mcpServers.markitdown.args[1] = $pythonPath
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
    Write-Host "mcp_settings.json mis à jour" -ForegroundColor Green
}

Write-Host "=== CORRECTIONS TERMINÉES ===" -ForegroundColor Cyan
Write-Host "Redémarrez VS Code" -ForegroundColor Yellow
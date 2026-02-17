# Script de diagnostic complet pour github-projects-mcp
# Analyse et réparation des problèmes de connexion

Write-Host "🔍 DIAGNOSTIC COMPLET DU MCP GITHUB-PROJECTS-MCP" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# 1. Vérification de l'état du serveur
Write-Host "📊 État actuel du serveur..." -ForegroundColor Yellow

$serverProcess = Get-Process | Where-Object { $_.Name -eq "node.exe" } | Select-Object -First 1
if ($serverProcess) {
    Write-Host "✅ Processus node.exe trouvé (PID: $($serverProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "❌ Aucun processus node.exe trouvé" -ForegroundColor Red
    exit 1
}

# 2. Test de connectivité HTTP
Write-Host "🌐 Test de connectivité HTTP sur le port 3001..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:3001/health" -TimeoutSec 5 -UseBasicParsing $false
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Serveur HTTP répond correctement" -ForegroundColor Green
    } else {
        Write-Host "❌ Serveur HTTP ne répond pas (Status: $($response.StatusCode))" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur de connexion HTTP: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Analyse des fichiers de configuration
Write-Host "📁 Analyse des fichiers de configuration..." -ForegroundColor Yellow

Write-Host "🔍 Fichier .env actuel :" -ForegroundColor Cyan
Get-Content "mcps/internal/servers/github-projects-mcp/.env" | Write-Host

Write-Host "`n🔍 Configuration mcp_settings.json pour github-projects-mcp :" -ForegroundColor Cyan
$config = Get-Content "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" | ConvertFrom-Json
$configMcp = $config.mcpServers."github-projects-mcp"
if ($configMcp) {
    Write-Host "✅ Configuration trouvée dans mcp_settings.json" -ForegroundColor Green
    Write-Host "  - URL: $($configMcp.http.url)" -ForegroundColor White
    Write-Host "  - Transport: $($configMcp.transportType)" -ForegroundColor White
    Write-Host "  - Env: $($configMcp.env.GITHUB_TOKEN)" -ForegroundColor White
} else {
    Write-Host "❌ Configuration non trouvée dans mcp_settings.json" -ForegroundColor Red
}

# 4. Identification des problèmes
Write-Host "🔍 PROBLÈMES IDENTIFIÉS :" -ForegroundColor Red

Write-Host "1. INCOMPATIBILITÉ CONFIGURATION COMPTE/JSON :" -ForegroundColor Yellow
Write-Host "   - Le code source attend le format indexé (GITHUB_OWNER_1, GITHUB_TOKEN_1)" -ForegroundColor White
Write-Host "   - La configuration utilise le format JSON (GITHUB_ACCOUNTS_JSON)" -ForegroundColor White
Write-Host "   - Les deux formats sont incompatibles" -ForegroundColor White

Write-Host "2. PROBLÈME DE RÉSOLUTION DE VARIABLES :" -ForegroundColor Yellow
Write-Host "   - La variable `${env:GITHUB_TOKEN}` n'est pas résolue par le système" -ForegroundColor White
Write-Host "   - Le serveur reçoit la chaîne littérale au lieu du token" -ForegroundColor White

Write-Host "3. PROBLÈME DE LOGGING :" -ForegroundColor Yellow
Write-Host "   - Le logger ne peut pas créer le dossier logs (caractères spéciaux)" -ForegroundColor White
Write-Host "   - Aucun log n'est généré pour le debugging" -ForegroundColor White

Write-Host "4. PROBLÈME DE DÉMARRAGE SERVEUR HTTP :" -ForegroundColor Yellow
Write-Host "   - Le serveur ne démarre pas ou ne répond pas" -ForegroundColor White

# 5. Solutions proposées
Write-Host "💡 SOLUTIONS À APPLIQUER :" -ForegroundColor Green

Write-Host "1. Corriger la compatibilité configuration :" -ForegroundColor Yellow
Write-Host "   - Modifier le code source pour supporter le format JSON" -ForegroundColor White

Write-Host "2. Corriger la résolution de variables :" -ForegroundColor Yellow
Write-Host "   - Implémenter une résolution robuste des variables d'environnement" -ForegroundColor White

Write-Host "3. Corriger le problème de logging :" -ForegroundColor Yellow
Write-Host "   - Utiliser un chemin de log sans caractères spéciaux" -ForegroundColor White

Write-Host "4. Tester avec configuration corrigée :" -ForegroundColor Yellow
Write-Host "   - Appliquer les corrections et retester la connexion" -ForegroundColor White

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Appuyez sur une touche pour continuer..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoKey,IncludeKeyDown")

Write-Host ""
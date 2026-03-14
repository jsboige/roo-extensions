# Script pour forcer la reconnexion du serveur MCP roo-state-manager
# Auteur: Roo AI
# Date: 2025-10-17

Write-Host "🔄 Forçage de la reconnexion MCP roo-state-manager" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Chemin du fichier de configuration MCP
$mcpSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

Write-Host "`n📁 Chemin des paramètres MCP: $mcpSettingsPath" -ForegroundColor Yellow

# Vérifier si le fichier existe
if (Test-Path $mcpSettingsPath) {
    Write-Host "✅ Fichier de configuration trouvé" -ForegroundColor Green
    
    # Lire la configuration actuelle
    $config = Get-Content $mcpSettingsPath -Raw | ConvertFrom-Json
    Write-Host "📖 Configuration actuelle lue" -ForegroundColor Green
    
    # Afficher les serveurs configurés
    Write-Host "`n🔧 Serveurs MCP configurés:" -ForegroundColor Yellow
    $config.PSObject.Properties | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor White
    }
    
    # Forcer la reconnexion en modifiant le fichier
    Write-Host "`n🔄 Forçage de la reconnexion..." -ForegroundColor Yellow
    
    # Ajouter un timestamp pour forcer la détection de changement
    $config | Add-Member -NotePropertyName "_reconnect_timestamp" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ss") -Force
    
    # Sauvegarder la configuration
    # NOTE: Use WriteAllText with UTF8Encoding($false) to avoid BOM (issue #664)
    $jsonContent = $config | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($mcpSettingsPath, $jsonContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "✅ Configuration mise à jour avec timestamp" -ForegroundColor Green

    # Attendre un peu
    Start-Sleep -Seconds 2

    # Supprimer le timestamp pour nettoyer
    $config.PSObject.Properties.Remove("_reconnect_timestamp")
    $jsonContent = $config | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($mcpSettingsPath, $jsonContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "✅ Configuration nettoyée" -ForegroundColor Green
    
} else {
    Write-Host "❌ Fichier de configuration non trouvé" -ForegroundColor Red
}

Write-Host "`n🏁 Opération terminée" -ForegroundColor Cyan
Write-Host "Le serveur MCP devrait se reconnecter dans quelques secondes..." -ForegroundColor White
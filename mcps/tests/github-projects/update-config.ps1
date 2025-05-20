# Script pour mettre à jour la configuration du MCP GitHub Projects
$settingsPath = "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

if (Test-Path $settingsPath) {
    Write-Host "Lecture du fichier de configuration..."
    $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
    
    Write-Host "Mise à jour de la configuration..."
    # Créer un nouvel objet pour l'environnement avec les deux variables
    $envObject = @{
        "GITHUB_TOKEN" = "PLACEHOLDER_GITHUB_TOKEN"
        "MCP_PORT" = "3002"
    }
    
    # Convertir l'objet en PSCustomObject pour qu'il soit correctement sérialisé
    $envPSObject = [PSCustomObject]$envObject
    
    # Remplacer l'objet env existant
    $settings.mcpServers.'github-projects'.env = $envPSObject
    
    Write-Host "Enregistrement des modifications..."
    $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath
    
    Write-Host "Configuration mise à jour avec succès."
} else {
    Write-Host "Le fichier de configuration n'existe pas: $settingsPath"
}
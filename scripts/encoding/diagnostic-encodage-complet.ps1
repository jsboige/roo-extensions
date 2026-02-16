# Script de diagnostic complet de l'encodage UTF-8
# Créé pour résolution définitive problèmes encodage

Write-Host "=== DIAGNOSTIC ENCODAGE UTF-8 ===" -ForegroundColor Cyan
Write-Host ""

# 1. Version PowerShell
Write-Host "1. Version PowerShell:" -ForegroundColor Yellow
Write-Host "   PSVersion: $($PSVersionTable.PSVersion)"
Write-Host "   PSEdition: $($PSVersionTable.PSEdition)"
Write-Host "   OS: $($PSVersionTable.OS)"
Write-Host ""

# 2. Chemin pwsh
Write-Host "2. Installation PowerShell 7:" -ForegroundColor Yellow
$pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshPath) {
    Write-Host "   pwsh trouve: $($pwshPath.Source)" -ForegroundColor Green
} else {
    Write-Host "   pwsh NON trouve" -ForegroundColor Red
}
Write-Host ""

# 3. Encodage Console
Write-Host "3. Encodage Console:" -ForegroundColor Yellow
Write-Host "   OutputEncoding: $([Console]::OutputEncoding.EncodingName)"
Write-Host "   CodePage: $([Console]::OutputEncoding.CodePage)"
Write-Host "   InputEncoding: $([Console]::InputEncoding.EncodingName)"
Write-Host ""

# 4. Encodage PowerShell
Write-Host "4. Encodage PowerShell:" -ForegroundColor Yellow
if ($OutputEncoding) {
    Write-Host "   OutputEncoding: $($OutputEncoding.EncodingName)"
} else {
    Write-Host "   OutputEncoding: NON DEFINI" -ForegroundColor Red
}
Write-Host ""

# 5. Test caracteres accentues
Write-Host "5. Test caracteres accentues:" -ForegroundColor Yellow
$testString = "Test: eaeu - trouve"
Write-Host "   $testString"
Write-Host ""

# 6. Profils PowerShell
Write-Host "6. Profils PowerShell:" -ForegroundColor Yellow
Write-Host "   Profil PS7: $PROFILE"
Write-Host "   Existe: $(Test-Path $PROFILE)"
Write-Host "   Profil PS5.1: $HOME\Documents\WindowsPowerShell\profile.ps1"
Write-Host "   Existe: $(Test-Path "$HOME\Documents\WindowsPowerShell\profile.ps1")"
Write-Host ""

# 7. Configuration MCP
Write-Host "7. Configuration MCP:" -ForegroundColor Yellow
$mcpSettings = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
if (Test-Path $mcpSettings) {
    Write-Host "   mcp_settings.json trouve" -ForegroundColor Green
    $mcpContent = Get-Content $mcpSettings -Raw | ConvertFrom-Json
    $rooStateManager = $mcpContent.mcpServers.'roo-state-manager'
    if ($rooStateManager) {
        Write-Host "   Commande: $($rooStateManager.command)"
    }
} else {
    Write-Host "   mcp_settings.json NON trouve" -ForegroundColor Red
}
Write-Host ""

# 8. VSCode settings
Write-Host "8. Configuration VSCode:" -ForegroundColor Yellow
$vscodeSettings = "$HOME\AppData\Roaming\Code\User\settings.json"
if (Test-Path $vscodeSettings) {
    Write-Host "   settings.json trouve" -ForegroundColor Green
    $settings = Get-Content $vscodeSettings -Raw | ConvertFrom-Json
    if ($settings.'terminal.integrated.defaultProfile.windows') {
        Write-Host "   Terminal par defaut: $($settings.'terminal.integrated.defaultProfile.windows')"
    }
} else {
    Write-Host "   settings.json NON trouve" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== FIN DIAGNOSTIC ===" -ForegroundColor Cyan
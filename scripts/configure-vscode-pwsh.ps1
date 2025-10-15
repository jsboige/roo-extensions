# Script pour configurer VSCode pour utiliser PowerShell 7 (pwsh) par défaut
# Créé pour résolution encodage UTF-8

$settingsPath = "$env:APPDATA\Code\User\settings.json"

Write-Host "Configuration de VSCode pour PowerShell 7..." -ForegroundColor Cyan

# Lire le fichier settings.json
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

# Créer une sauvegarde
$backupPath = "$settingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $settingsPath $backupPath
Write-Host "Sauvegarde créée: $backupPath" -ForegroundColor Green

# Vérifier si terminal.integrated.profiles.windows existe
if (-not $settings.'terminal.integrated.profiles.windows') {
    $settings | Add-Member -MemberType NoteProperty -Name 'terminal.integrated.profiles.windows' -Value ([PSCustomObject]@{}) -Force
}

# Ajouter le profil PowerShell 7 s'il n'existe pas
$profiles = $settings.'terminal.integrated.profiles.windows'
if (-not ($profiles.PSObject.Properties.Name -contains 'PowerShell 7 (pwsh)')) {
    $profiles | Add-Member -MemberType NoteProperty -Name 'PowerShell 7 (pwsh)' -Value ([PSCustomObject]@{
        path = "C:\Program Files\PowerShell\7\pwsh.exe"
        args = @("-NoLogo")
        icon = "terminal-powershell"
    }) -Force
    Write-Host "Profil 'PowerShell 7 (pwsh)' ajouté" -ForegroundColor Green
} else {
    Write-Host "Profil 'PowerShell 7 (pwsh)' déjà existant" -ForegroundColor Yellow
}

# Changer le terminal par défaut vers PowerShell 7
$settings.'terminal.integrated.defaultProfile.windows' = 'PowerShell 7 (pwsh)'
Write-Host "Terminal par défaut changé vers 'PowerShell 7 (pwsh)'" -ForegroundColor Green

# Sauvegarder les modifications
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8

Write-Host ""
Write-Host "Configuration VSCode terminée avec succès!" -ForegroundColor Green
Write-Host "Redémarrez VSCode pour appliquer les changements." -ForegroundColor Yellow
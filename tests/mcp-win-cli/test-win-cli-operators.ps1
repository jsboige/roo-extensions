# Test des opérateurs avec Win-CLI
Write-Host "Test des opérateurs avec Win-CLI"

# Chemin vers le fichier de configuration Win-CLI
$configPath = "$env:USERPROFILE\.win-cli-server\config.json"

# Vérifier si le fichier de configuration existe
if (Test-Path $configPath) {
    Write-Host "Fichier de configuration Win-CLI trouvé: $configPath"
    
    # Lire la configuration
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    
    # Afficher les opérateurs bloqués pour chaque shell
    Write-Host "`nOpérateurs bloqués pour PowerShell:"
    $config.shells.powershell.blockedOperators | ForEach-Object { Write-Host "- $_" }
    
    Write-Host "`nOpérateurs bloqués pour CMD:"
    $config.shells.cmd.blockedOperators | ForEach-Object { Write-Host "- $_" }
    
    Write-Host "`nOpérateurs bloqués pour Git Bash:"
    $config.shells.gitbash.blockedOperators | ForEach-Object { Write-Host "- $_" }
    
    # Vérifier si les opérateurs sont bloqués
    $powershellBlocked = $config.shells.powershell.blockedOperators.Count -gt 0
    $cmdBlocked = $config.shells.cmd.blockedOperators.Count -gt 0
    $gitbashBlocked = $config.shells.gitbash.blockedOperators.Count -gt 0
    
    if (-not $powershellBlocked -and -not $cmdBlocked -and -not $gitbashBlocked) {
        Write-Host "`nAucun opérateur n'est bloqué dans la configuration Win-CLI."
    } else {
        Write-Host "`nCertains opérateurs sont bloqués dans la configuration Win-CLI."
    }
} else {
    Write-Host "Fichier de configuration Win-CLI non trouvé: $configPath"
}

Write-Host "`nTests terminés"
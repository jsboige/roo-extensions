# Script de sauvegarde automatique de la configuration MCP
# Utilisation : .\backup-mcp-config.ps1 [restore]

param(
    [string]$Action = "backup"
)

$mcpConfigPath = "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$backupDir = "D:\roo-extensions\mcps\backups"
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Créer le répertoire de sauvegarde s'il n'existe pas
if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force
    Write-Host "Répertoire de sauvegarde créé : $backupDir" -ForegroundColor Green
}

function Backup-MCPConfig {
    if (Test-Path $mcpConfigPath) {
        $backupPath = "$backupDir\mcp_settings.backup.$timestamp.json"
        Copy-Item $mcpConfigPath $backupPath
        Write-Host "✅ Sauvegarde créée : $backupPath" -ForegroundColor Green
        
        # Valider le JSON
        try {
            Get-Content $mcpConfigPath | ConvertFrom-Json | Out-Null
            Write-Host "✅ Configuration JSON valide" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ ERREUR : Configuration JSON invalide !" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
        
        # Lister les serveurs configurés
        $config = Get-Content $mcpConfigPath | ConvertFrom-Json
        Write-Host "`n📋 Serveurs MCP configurés :" -ForegroundColor Cyan
        $config.mcpServers.PSObject.Properties | ForEach-Object {
            $status = if ($_.Value.disabled -eq $true) { "❌ DÉSACTIVÉ" } else { "✅ ACTIVÉ" }
            Write-Host "  - $($_.Name): $status" -ForegroundColor White
        }
        
        return $backupPath
    }
    else {
        Write-Host "❌ Fichier de configuration MCP introuvable : $mcpConfigPath" -ForegroundColor Red
        return $null
    }
}

function Restore-MCPConfig {
    # Lister les sauvegardes disponibles
    $backups = Get-ChildItem "$backupDir\mcp_settings.backup.*.json" | Sort-Object LastWriteTime -Descending
    
    if ($backups.Count -eq 0) {
        Write-Host "❌ Aucune sauvegarde trouvée dans $backupDir" -ForegroundColor Red
        return
    }
    
    Write-Host "`n📋 Sauvegardes disponibles :" -ForegroundColor Cyan
    for ($i = 0; $i -lt $backups.Count; $i++) {
        $backup = $backups[$i]
        Write-Host "  [$i] $($backup.Name) - $($backup.LastWriteTime)" -ForegroundColor White
    }
    
    $choice = Read-Host "`nChoisir une sauvegarde à restaurer (numéro)"
    
    if ($choice -match '^\d+$' -and [int]$choice -lt $backups.Count) {
        $selectedBackup = $backups[[int]$choice]
        
        # Créer une sauvegarde de l'état actuel avant restauration
        Write-Host "`n🔄 Sauvegarde de l'état actuel avant restauration..." -ForegroundColor Yellow
        Backup-MCPConfig | Out-Null
        
        # Restaurer
        Copy-Item $selectedBackup.FullName $mcpConfigPath -Force
        Write-Host "✅ Configuration restaurée depuis : $($selectedBackup.Name)" -ForegroundColor Green
        Write-Host "⚠️  Redémarrez VSCode pour appliquer les changements" -ForegroundColor Yellow
    }
    else {
        Write-Host "❌ Choix invalide" -ForegroundColor Red
    }
}

function Show-MCPStatus {
    if (Test-Path $mcpConfigPath) {
        try {
            $config = Get-Content $mcpConfigPath | ConvertFrom-Json
            Write-Host "`n📊 État des serveurs MCP :" -ForegroundColor Cyan
            
            $config.mcpServers.PSObject.Properties | ForEach-Object {
                $server = $_.Value
                $status = if ($server.disabled -eq $true) { "❌ DÉSACTIVÉ" } else { "✅ ACTIVÉ" }
                $command = "$($server.command) $($server.args -join ' ')"
                
                Write-Host "`n🔧 $($_.Name):" -ForegroundColor White
                Write-Host "   Status: $status" -ForegroundColor $(if ($server.disabled -eq $true) { "Red" } else { "Green" })
                Write-Host "   Command: $command" -ForegroundColor Gray
                
                if ($server.cwd) {
                    Write-Host "   Working Dir: $($server.cwd)" -ForegroundColor Gray
                }
                
                if ($server.alwaysAllow) {
                    Write-Host "   Tools: $($server.alwaysAllow.Count) autorisés" -ForegroundColor Gray
                }
            }
        }
        catch {
            Write-Host "❌ ERREUR : Impossible de lire la configuration MCP" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
    else {
        Write-Host "❌ Fichier de configuration MCP introuvable" -ForegroundColor Red
    }
}

# Exécution selon l'action demandée
switch ($Action.ToLower()) {
    "backup" {
        Write-Host "🔄 Sauvegarde de la configuration MCP..." -ForegroundColor Cyan
        Backup-MCPConfig
    }
    "restore" {
        Write-Host "🔄 Restauration de la configuration MCP..." -ForegroundColor Cyan
        Restore-MCPConfig
    }
    "status" {
        Show-MCPStatus
    }
    default {
        Write-Host @"
🛠️  Script de gestion des configurations MCP

Usage:
  .\backup-mcp-config.ps1 backup   - Créer une sauvegarde
  .\backup-mcp-config.ps1 restore  - Restaurer depuis une sauvegarde
  .\backup-mcp-config.ps1 status   - Afficher l'état des serveurs MCP

Exemples:
  .\backup-mcp-config.ps1           # Sauvegarde par défaut
  .\backup-mcp-config.ps1 restore   # Restauration interactive
  .\backup-mcp-config.ps1 status    # État des serveurs
"@ -ForegroundColor Yellow
    }
}
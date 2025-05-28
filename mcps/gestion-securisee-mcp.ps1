# Script de Gestion Sécurisée des Configurations MCP
# Version 1.0 - 28/05/2025
# Usage: .\gestion-securisee-mcp.ps1 [action] [options]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("backup", "restore", "status", "validate", "safe-edit", "emergency-restore")]
    [string]$Action,
    
    [string]$Reason = "",
    [string]$BackupName = "",
    [switch]$Force
)

# Configuration
$mcpConfigPath = "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$backupDir = "D:\roo-extensions\mcps\backups"
$logFile = "D:\roo-extensions\mcps\modification-log.txt"
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Couleurs pour l'affichage
$colors = @{
    Success = "Green"
    Warning = "Yellow" 
    Error = "Red"
    Info = "Cyan"
    Highlight = "White"
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    
    switch ($Level) {
        "SUCCESS" { Write-Host "✅ $Message" -ForegroundColor $colors.Success }
        "WARNING" { Write-Host "⚠️  $Message" -ForegroundColor $colors.Warning }
        "ERROR"   { Write-Host "❌ $Message" -ForegroundColor $colors.Error }
        "INFO"    { Write-Host "ℹ️  $Message" -ForegroundColor $colors.Info }
        default   { Write-Host "📝 $Message" -ForegroundColor $colors.Highlight }
    }
}

function Test-MCPConfigExists {
    if (!(Test-Path $mcpConfigPath)) {
        Write-Log "Fichier de configuration MCP introuvable : $mcpConfigPath" "ERROR"
        return $false
    }
    return $true
}

function Test-JSONValid {
    param([string]$FilePath)
    try {
        Get-Content $FilePath | ConvertFrom-Json | Out-Null
        return $true
    }
    catch {
        Write-Log "JSON invalide dans $FilePath : $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function New-MCPBackup {
    param([string]$Reason = "Sauvegarde automatique")
    
    if (!(Test-MCPConfigExists)) { return $null }
    
    # Créer le répertoire de sauvegarde si nécessaire
    if (!(Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Write-Log "Répertoire de sauvegarde créé : $backupDir" "SUCCESS"
    }
    
    # Valider le JSON avant sauvegarde
    if (!(Test-JSONValid $mcpConfigPath)) {
        Write-Log "Impossible de sauvegarder : JSON invalide dans le fichier source" "ERROR"
        return $null
    }
    
    $backupPath = "$backupDir\mcp_settings.backup.$timestamp.json"
    
    try {
        Copy-Item $mcpConfigPath $backupPath -Force
        Write-Log "Sauvegarde créée : $backupPath" "SUCCESS"
        Write-Log "Raison : $Reason" "INFO"
        
        # Ajouter métadonnées
        $metadata = @{
            timestamp = $timestamp
            reason = $Reason
            originalPath = $mcpConfigPath
            backupPath = $backupPath
        }
        
        $metadataPath = "$backupDir\mcp_settings.backup.$timestamp.metadata.json"
        $metadata | ConvertTo-Json | Set-Content $metadataPath
        
        return $backupPath
    }
    catch {
        Write-Log "Erreur lors de la sauvegarde : $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Get-MCPBackups {
    $backups = Get-ChildItem "$backupDir\mcp_settings.backup.*.json" | Sort-Object LastWriteTime -Descending
    
    if ($backups.Count -eq 0) {
        Write-Log "Aucune sauvegarde trouvée dans $backupDir" "WARNING"
        return @()
    }
    
    Write-Log "Sauvegardes disponibles :" "INFO"
    for ($i = 0; $i -lt $backups.Count; $i++) {
        $backup = $backups[$i]
        $metadataPath = $backup.FullName -replace '\.json$', '.metadata.json'
        $reason = "Raison non documentée"
        
        if (Test-Path $metadataPath) {
            try {
                $metadata = Get-Content $metadataPath | ConvertFrom-Json
                $reason = $metadata.reason
            }
            catch { }
        }
        
        Write-Host "  [$i] $($backup.Name) - $($backup.LastWriteTime) - $reason" -ForegroundColor $colors.Highlight
    }
    
    return $backups
}

function Restore-MCPConfig {
    $backups = Get-MCPBackups
    if ($backups.Count -eq 0) { return }
    
    $choice = Read-Host "`nChoisir une sauvegarde à restaurer (numéro ou 'q' pour quitter)"
    
    if ($choice -eq 'q') {
        Write-Log "Restauration annulée par l'utilisateur" "INFO"
        return
    }
    
    if ($choice -match '^\d+$' -and [int]$choice -lt $backups.Count) {
        $selectedBackup = $backups[[int]$choice]
        
        # Valider la sauvegarde avant restauration
        if (!(Test-JSONValid $selectedBackup.FullName)) {
            Write-Log "Sauvegarde corrompue, restauration annulée" "ERROR"
            return
        }
        
        # Créer une sauvegarde de l'état actuel
        Write-Log "Sauvegarde de l'état actuel avant restauration..." "INFO"
        $currentBackup = New-MCPBackup "Sauvegarde automatique avant restauration depuis $($selectedBackup.Name)"
        
        if ($currentBackup) {
            try {
                Copy-Item $selectedBackup.FullName $mcpConfigPath -Force
                Write-Log "Configuration restaurée depuis : $($selectedBackup.Name)" "SUCCESS"
                Write-Log "⚠️  REDÉMARREZ VSCode pour appliquer les changements" "WARNING"
                
                # Valider la restauration
                if (Test-JSONValid $mcpConfigPath) {
                    Write-Log "Restauration validée : JSON correct" "SUCCESS"
                } else {
                    Write-Log "ERREUR : Restauration corrompue, rollback nécessaire" "ERROR"
                }
            }
            catch {
                Write-Log "Erreur lors de la restauration : $($_.Exception.Message)" "ERROR"
            }
        }
    }
    else {
        Write-Log "Choix invalide" "ERROR"
    }
}

function Show-MCPStatus {
    if (!(Test-MCPConfigExists)) { return }
    
    if (!(Test-JSONValid $mcpConfigPath)) {
        Write-Log "CONFIGURATION CORROMPUE - Restauration nécessaire" "ERROR"
        return
    }
    
    try {
        $config = Get-Content $mcpConfigPath | ConvertFrom-Json
        Write-Log "État des serveurs MCP :" "INFO"
        
        $totalServers = 0
        $activeServers = 0
        $disabledServers = 0
        
        $config.mcpServers.PSObject.Properties | ForEach-Object {
            $server = $_.Value
            $totalServers++
            
            if ($server.disabled -eq $true) {
                $status = "❌ DÉSACTIVÉ"
                $disabledServers++
                $color = $colors.Error
            } else {
                $status = "✅ ACTIVÉ"
                $activeServers++
                $color = $colors.Success
            }
            
            Write-Host "`n🔧 $($_.Name):" -ForegroundColor $colors.Highlight
            Write-Host "   Status: $status" -ForegroundColor $color
            Write-Host "   Command: $($server.command) $($server.args -join ' ')" -ForegroundColor $colors.Info
            
            if ($server.cwd) {
                Write-Host "   Working Dir: $($server.cwd)" -ForegroundColor $colors.Info
            }
        }
        
        Write-Host "`n📊 Résumé :" -ForegroundColor $colors.Info
        Write-Host "   Total: $totalServers serveurs" -ForegroundColor $colors.Highlight
        Write-Host "   Actifs: $activeServers" -ForegroundColor $colors.Success
        Write-Host "   Désactivés: $disabledServers" -ForegroundColor $colors.Warning
        
        # Vérifier la section security
        if ($config.security) {
            Write-Host "`n🔒 Configuration sécurité :" -ForegroundColor $colors.Info
            Write-Host "   restrictWorkingDirectory: $($config.security.restrictWorkingDirectory)" -ForegroundColor $colors.Highlight
            Write-Host "   allowedPaths: $($config.security.allowedPaths.Count) chemins autorisés" -ForegroundColor $colors.Highlight
        }
        
    }
    catch {
        Write-Log "Erreur lors de la lecture de la configuration : $($_.Exception.Message)" "ERROR"
    }
}

function Start-SafeEdit {
    Write-Log "Démarrage de l'édition sécurisée..." "INFO"
    
    # Sauvegarde obligatoire
    $reason = if ($Reason) { $Reason } else { Read-Host "Raison de la modification" }
    $backup = New-MCPBackup $reason
    
    if (!$backup) {
        Write-Log "Impossible de créer une sauvegarde, édition annulée" "ERROR"
        return
    }
    
    Write-Log "Sauvegarde créée, vous pouvez maintenant modifier le fichier :" "SUCCESS"
    Write-Log $mcpConfigPath "HIGHLIGHT"
    Write-Log "`nAPRÈS MODIFICATION :" "WARNING"
    Write-Log "1. Exécutez : .\gestion-securisee-mcp.ps1 validate" "INFO"
    Write-Log "2. Redémarrez VSCode" "INFO"
    Write-Log "3. Exécutez : .\gestion-securisee-mcp.ps1 status" "INFO"
    Write-Log "`nEn cas de problème : .\gestion-securisee-mcp.ps1 emergency-restore" "WARNING"
}

function Test-Configuration {
    Write-Log "Validation de la configuration MCP..." "INFO"
    
    if (!(Test-MCPConfigExists)) { return }
    
    if (Test-JSONValid $mcpConfigPath) {
        Write-Log "✅ JSON valide" "SUCCESS"
        
        try {
            $config = Get-Content $mcpConfigPath | ConvertFrom-Json
            
            # Vérifications de base
            if (!$config.mcpServers) {
                Write-Log "⚠️  Section mcpServers manquante" "WARNING"
            }
            
            if (!$config.security) {
                Write-Log "⚠️  Section security manquante" "WARNING"
            }
            
            Write-Log "✅ Structure de configuration valide" "SUCCESS"
        }
        catch {
            Write-Log "❌ Erreur de structure : $($_.Exception.Message)" "ERROR"
        }
    }
}

function Start-EmergencyRestore {
    Write-Log "🚨 RESTAURATION D'URGENCE 🚨" "ERROR"
    
    $backups = Get-MCPBackups
    if ($backups.Count -eq 0) {
        Write-Log "Aucune sauvegarde disponible pour la restauration d'urgence" "ERROR"
        return
    }
    
    # Prendre automatiquement la sauvegarde la plus récente
    $latestBackup = $backups[0]
    
    if ($Force -or (Read-Host "Restaurer automatiquement depuis $($latestBackup.Name) ? (y/N)") -eq 'y') {
        try {
            Copy-Item $latestBackup.FullName $mcpConfigPath -Force
            Write-Log "Restauration d'urgence effectuée depuis : $($latestBackup.Name)" "SUCCESS"
            Write-Log "⚠️  REDÉMARREZ VSCode IMMÉDIATEMENT" "WARNING"
        }
        catch {
            Write-Log "Erreur lors de la restauration d'urgence : $($_.Exception.Message)" "ERROR"
        }
    }
}

# Exécution selon l'action demandée
switch ($Action) {
    "backup" {
        $reason = if ($Reason) { $Reason } else { "Sauvegarde manuelle" }
        New-MCPBackup $reason | Out-Null
    }
    "restore" {
        Restore-MCPConfig
    }
    "status" {
        Show-MCPStatus
    }
    "validate" {
        Test-Configuration
    }
    "safe-edit" {
        Start-SafeEdit
    }
    "emergency-restore" {
        Start-EmergencyRestore
    }
    default {
        Write-Host "🛠️  Script de Gestion Sécurisée MCP" -ForegroundColor $colors.Info
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor $colors.Info
        Write-Host "  .\gestion-securisee-mcp.ps1 backup [-Reason `"raison`"]" -ForegroundColor $colors.Highlight
        Write-Host "  .\gestion-securisee-mcp.ps1 restore" -ForegroundColor $colors.Highlight
        Write-Host "  .\gestion-securisee-mcp.ps1 status" -ForegroundColor $colors.Highlight
        Write-Host "  .\gestion-securisee-mcp.ps1 validate" -ForegroundColor $colors.Highlight
        Write-Host "  .\gestion-securisee-mcp.ps1 safe-edit [-Reason `"raison`"]" -ForegroundColor $colors.Highlight
        Write-Host "  .\gestion-securisee-mcp.ps1 emergency-restore [-Force]" -ForegroundColor $colors.Highlight
        Write-Host ""
        Write-Host "Actions:" -ForegroundColor $colors.Info
        Write-Host "  backup           - Créer une sauvegarde horodatée" -ForegroundColor $colors.Highlight
        Write-Host "  restore          - Restaurer depuis une sauvegarde (interactif)" -ForegroundColor $colors.Highlight
        Write-Host "  status           - Afficher l'état des serveurs MCP" -ForegroundColor $colors.Highlight
        Write-Host "  validate         - Valider la configuration JSON" -ForegroundColor $colors.Highlight
        Write-Host "  safe-edit        - Préparer une édition sécurisée" -ForegroundColor $colors.Highlight
        Write-Host "  emergency-restore - Restauration d'urgence (dernière sauvegarde)" -ForegroundColor $colors.Highlight
        Write-Host ""
        Write-Host "Exemples:" -ForegroundColor $colors.Info
        Write-Host "  .\gestion-securisee-mcp.ps1 backup -Reason `"Avant ajout semantic-fleet`"" -ForegroundColor $colors.Highlight
        Write-Host "  .\gestion-securisee-mcp.ps1 safe-edit -Reason `"Correction serveur win-cli`"" -ForegroundColor $colors.Highlight
        Write-Host "  .\gestion-securisee-mcp.ps1 emergency-restore -Force" -ForegroundColor $colors.Highlight
    }
}
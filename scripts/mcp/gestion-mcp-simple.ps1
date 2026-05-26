# Script de gestion sécurisée des configurations MCP - Version simplifiée
# Auteur: Assistant IA
# Date: 28/05/2025

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("backup", "restore", "status", "validate", "help")]
    [string]$Action,

    [string]$Reason = "Opération manuelle",
    [switch]$Force
)

. "$PSScriptRoot\..\common\extension-paths.ps1"

# Configuration
$ConfigPath = Get-McpSettingsPath -Extension RooCode
$BackupDir = "d:\roo-extensions\mcps\backups"
$LogFile = "d:\roo-extensions\mcps\mcp-operations.log"

# Couleurs pour l'affichage
$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Highlight = "White"
}

# Fonction de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logEntry
    
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor $Colors.Error }
        "WARNING" { Write-Host $Message -ForegroundColor $Colors.Warning }
        "SUCCESS" { Write-Host $Message -ForegroundColor $Colors.Success }
        "INFO" { Write-Host $Message -ForegroundColor $Colors.Info }
        default { Write-Host $Message }
    }
}

# Fonction de sauvegarde
function Backup-MCPConfig {
    try {
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }
        
        if (-not (Test-Path $ConfigPath)) {
            Write-Log "Fichier de configuration non trouvé : $ConfigPath" "ERROR"
            return $false
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFile = Join-Path $BackupDir "mcp_settings_$timestamp.json"
        
        Copy-Item -Path $ConfigPath -Destination $backupFile -Force
        
        # Créer un fichier de métadonnées
        $metadata = @{
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            reason = $Reason
            originalPath = $ConfigPath
            backupFile = $backupFile
        }
        
        $metadataFile = $backupFile -replace "\.json$", "_metadata.json"
        $metadata | ConvertTo-Json -Depth 3 | Set-Content -Path $metadataFile -Encoding UTF8
        
        Write-Log "Sauvegarde créée : $backupFile" "SUCCESS"
        Write-Log "Raison : $Reason" "INFO"
        return $true
    }
    catch {
        Write-Log "Erreur lors de la sauvegarde : $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Fonction de restauration
function Restore-MCPConfig {
    try {
        if (-not (Test-Path $BackupDir)) {
            Write-Log "Répertoire de sauvegarde non trouvé : $BackupDir" "ERROR"
            return $false
        }
        
        # Trouver la dernière sauvegarde
        $backupFiles = Get-ChildItem -Path $BackupDir -Filter "mcp_settings_*.json" | Sort-Object LastWriteTime -Descending
        
        if ($backupFiles.Count -eq 0) {
            Write-Log "Aucune sauvegarde trouvée dans $BackupDir" "ERROR"
            return $false
        }
        
        $latestBackup = $backupFiles[0]
        Write-Log "Restauration depuis : $($latestBackup.Name)" "INFO"
        
        if (-not $Force) {
            $response = Read-Host "Confirmer la restauration ? (o/N)"
            if ($response -ne "o" -and $response -ne "O") {
                Write-Log "Restauration annulée par l'utilisateur" "WARNING"
                return $false
            }
        }
        
        # Créer une sauvegarde de l'état actuel avant restauration
        Write-Log "Création d'une sauvegarde de sécurité avant restauration..." "INFO"
        $backupResult = Backup-MCPConfig
        if (-not $backupResult) {
            Write-Log "Impossible de créer une sauvegarde de sécurité" "ERROR"
            return $false
        }
        
        # Restaurer le fichier
        Copy-Item -Path $latestBackup.FullName -Destination $ConfigPath -Force
        Write-Log "Configuration restaurée avec succès" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Erreur lors de la restauration : $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Fonction de validation
function Test-MCPConfig {
    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-Log "Fichier de configuration non trouvé : $ConfigPath" "ERROR"
            return $false
        }
        
        $content = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $config = $content | ConvertFrom-Json
        
        Write-Log "✅ Fichier JSON valide" "SUCCESS"
        
        # Vérifications de base
        if (-not $config.mcpServers) {
            Write-Log "⚠️  Section mcpServers manquante" "WARNING"
        } else {
            $serverCount = ($config.mcpServers | Get-Member -MemberType NoteProperty).Count
            Write-Log "📊 Nombre de serveurs configurés : $serverCount" "INFO"
        }
        
        if ($config.security) {
            Write-Log "🔒 Configuration sécurité présente" "INFO"
            if ($config.security.allowedPaths) {
                Write-Log "   Chemins autorisés : $($config.security.allowedPaths.Count)" "INFO"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "❌ Erreur de validation JSON : $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Fonction de statut
function Show-MCPStatus {
    try {
        Write-Host "`n🔧 État de la configuration MCP" -ForegroundColor $Colors.Info
        Write-Host "=" * 50 -ForegroundColor $Colors.Info
        
        if (-not (Test-Path $ConfigPath)) {
            Write-Log "❌ Fichier de configuration non trouvé" "ERROR"
            return
        }
        
        Write-Log "📁 Fichier de configuration : $ConfigPath" "INFO"
        $fileInfo = Get-Item $ConfigPath
        Write-Log "📅 Dernière modification : $($fileInfo.LastWriteTime)" "INFO"
        Write-Log "📏 Taille : $([math]::Round($fileInfo.Length / 1KB, 2)) KB" "INFO"
        
        # Validation
        $isValid = Test-MCPConfig
        
        if ($isValid) {
            $content = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
            $config = $content | ConvertFrom-Json
            
            if ($config.mcpServers) {
                Write-Host "`n📋 Serveurs MCP configurés :" -ForegroundColor $Colors.Info
                $config.mcpServers | Get-Member -MemberType NoteProperty | ForEach-Object {
                    $serverName = $_.Name
                    $server = $config.mcpServers.$serverName
                    $status = if ($server.disabled) { "❌ Désactivé" } else { "✅ Actif" }
                    Write-Host "   $serverName : $status" -ForegroundColor $Colors.Highlight
                }
            }
        }
        
        # Informations sur les sauvegardes
        if (Test-Path $BackupDir) {
            $backupFiles = Get-ChildItem -Path $BackupDir -Filter "mcp_settings_*.json"
            Write-Host "`n💾 Sauvegardes disponibles : $($backupFiles.Count)" -ForegroundColor $Colors.Info
            if ($backupFiles.Count -gt 0) {
                $latest = $backupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Log "   Dernière sauvegarde : $($latest.Name) ($($latest.LastWriteTime))" "INFO"
            }
        }
    }
    catch {
        Write-Log "Erreur lors de l'affichage du statut : $($_.Exception.Message)" "ERROR"
    }
}
}

# Fonction d'aide
function Show-Help {
    Write-Host "`n🔧 Gestionnaire de configuration MCP - Version simplifiée" -ForegroundColor $Colors.Info
    Write-Host "=" * 60 -ForegroundColor $Colors.Info
    Write-Host ""
    Write-Host "UTILISATION :" -ForegroundColor $Colors.Highlight
    Write-Host "  .\gestion-mcp-simple.ps1 <action> [options]" -ForegroundColor $Colors.Info
    Write-Host ""
    Write-Host "ACTIONS :" -ForegroundColor $Colors.Highlight
    Write-Host "  backup     - Créer une sauvegarde de la configuration" -ForegroundColor $Colors.Info
    Write-Host "  restore    - Restaurer la dernière sauvegarde" -ForegroundColor $Colors.Info
    Write-Host "  status     - Afficher l'état de la configuration" -ForegroundColor $Colors.Info
    Write-Host "  validate   - Valider la syntaxe JSON" -ForegroundColor $Colors.Info
    Write-Host "  help       - Afficher cette aide" -ForegroundColor $Colors.Info
    Write-Host ""
    Write-Host "OPTIONS :" -ForegroundColor $Colors.Highlight
    Write-Host "  -Reason    - Raison de l'opération (pour backup)" -ForegroundColor $Colors.Info
    Write-Host "  -Force     - Forcer l'opération sans confirmation" -ForegroundColor $Colors.Info
    Write-Host ""
    Write-Host "EXEMPLES :" -ForegroundColor $Colors.Highlight
    Write-Host '  .\gestion-mcp-simple.ps1 backup -Reason "Avant modification"' -ForegroundColor $Colors.Info
    Write-Host "  .\gestion-mcp-simple.ps1 restore -Force" -ForegroundColor $Colors.Info
    Write-Host "  .\gestion-mcp-simple.ps1 status" -ForegroundColor $Colors.Info
}

# Exécution principale
try {
    # Créer le répertoire de logs si nécessaire
    $logDir = Split-Path $LogFile -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    Write-Log "=== Démarrage de l'opération : $Action ===" "INFO"
    
    switch ($Action) {
        "backup" {
            $result = Backup-MCPConfig
            if ($result) {
                Write-Log "Opération de sauvegarde terminée avec succès" "SUCCESS"
            } else {
                Write-Log "Échec de l'opération de sauvegarde" "ERROR"
                exit 1
            }
        }
        "restore" {
            $result = Restore-MCPConfig
            if ($result) {
                Write-Log "Opération de restauration terminée avec succès" "SUCCESS"
            } else {
                Write-Log "Échec de l'opération de restauration" "ERROR"
                exit 1
            }
        }
        "status" {
            Show-MCPStatus
        }
        "validate" {
            $result = Test-MCPConfig
            if ($result) {
                Write-Log "Validation terminée avec succès" "SUCCESS"
            } else {
                Write-Log "Échec de la validation" "ERROR"
                exit 1
            }
        }
        "help" {
            Show-Help
        }
    }
    
    Write-Log "=== Fin de l'opération : $Action ===" "INFO"
}
catch {
    Write-Log "Erreur critique : $($_.Exception.Message)" "ERROR"
    exit 1
}
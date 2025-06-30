# Gestionnaire MCP Simple
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("backup", "restore", "status", "help")]
    [string]$Action,
    
    [string]$Reason = "Operation manuelle"
)

$AppdataPath = [System.Environment]::GetFolderPath('ApplicationData')
$ConfigPath = Join-Path -Path $AppdataPath -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$BackupDir = "d:\roo-extensions\mcps\backups"

function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Create-Backup {
    try {
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }
        
        if (-not (Test-Path $ConfigPath)) {
            Write-ColorText "Erreur: Fichier de configuration non trouve" "Red"
            return $false
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFile = Join-Path $BackupDir "mcp_settings_$timestamp.json"
        
        Copy-Item -Path $ConfigPath -Destination $backupFile -Force
        Write-ColorText "Sauvegarde creee: $backupFile" "Green"
        return $true
    }
    catch {
        Write-ColorText "Erreur lors de la sauvegarde: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Restore-Config {
    try {
        if (-not (Test-Path $BackupDir)) {
            Write-ColorText "Repertoire de sauvegarde non trouve" "Red"
            return $false
        }
        
        $backupFiles = Get-ChildItem -Path $BackupDir -Filter "mcp_settings_*.json" | Sort-Object LastWriteTime -Descending
        
        if ($backupFiles.Count -eq 0) {
            Write-ColorText "Aucune sauvegarde trouvee" "Red"
            return $false
        }
        
        $latestBackup = $backupFiles[0]
        Write-ColorText "Restauration depuis: $($latestBackup.Name)" "Yellow"
        
        Copy-Item -Path $latestBackup.FullName -Destination $ConfigPath -Force
        Write-ColorText "Configuration restauree avec succes" "Green"
        return $true
    }
    catch {
        Write-ColorText "Erreur lors de la restauration: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Show-Status {
    Write-ColorText "`nEtat de la configuration MCP" "Cyan"
    Write-ColorText "=" * 40 "Cyan"
    
    if (Test-Path $ConfigPath) {
        $fileInfo = Get-Item $ConfigPath
        Write-ColorText "Fichier: $ConfigPath" "White"
        Write-ColorText "Derniere modification: $($fileInfo.LastWriteTime)" "White"
        Write-ColorText "Taille: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" "White"
        
        try {
            $content = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
            $config = $content | ConvertFrom-Json
            Write-ColorText "JSON valide: Oui" "Green"
            
            if ($config.mcpServers) {
                $serverCount = ($config.mcpServers | Get-Member -MemberType NoteProperty).Count
                Write-ColorText "Serveurs configures: $serverCount" "White"
            }
        }
        catch {
            Write-ColorText "JSON valide: Non - $($_.Exception.Message)" "Red"
        }
    }
    else {
        Write-ColorText "Fichier de configuration non trouve" "Red"
    }
    
    if (Test-Path $BackupDir) {
        $backupFiles = Get-ChildItem -Path $BackupDir -Filter "mcp_settings_*.json"
        Write-ColorText "Sauvegardes disponibles: $($backupFiles.Count)" "White"
    }
}

function Show-Help {
    Write-ColorText "`nGestionnaire MCP Simple" "Cyan"
    Write-ColorText "=" * 30 "Cyan"
    Write-ColorText "Usage: .\mcp-manager.ps1 <action>" "White"
    Write-ColorText ""
    Write-ColorText "Actions:" "Yellow"
    Write-ColorText "  backup  - Creer une sauvegarde" "White"
    Write-ColorText "  restore - Restaurer la derniere sauvegarde" "White"
    Write-ColorText "  status  - Afficher l'etat" "White"
    Write-ColorText "  help    - Afficher cette aide" "White"
}

# Execution principale
switch ($Action) {
    "backup" {
        $result = Create-Backup
        if (-not $result) { exit 1 }
    }
    "restore" {
        $result = Restore-Config
        if (-not $result) { exit 1 }
    }
    "status" {
        Show-Status
    }
    "help" {
        Show-Help
    }
}
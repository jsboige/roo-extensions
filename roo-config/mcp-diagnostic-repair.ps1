# Script de diagnostic et réparation MCP pour Roo
# Créé le 26/05/2025 suite à la panne critique des MCPs

param(
    [switch]$Repair,
    [switch]$Backup,
    [switch]$Validate
)

$mcpSettingsPath = "c:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

function Test-McpFile {
    Write-Host "=== DIAGNOSTIC MCP SETTINGS ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $mcpSettingsPath)) {
        Write-Host "X CRITIQUE: Fichier mcp_settings.json introuvable" -ForegroundColor Red
        return $false
    }
    
    # Vérifier l'encodage BOM
    $bytes = [System.IO.File]::ReadAllBytes($mcpSettingsPath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Host "X PROBLEME: BOM UTF-8 détecté (cause de corruption)" -ForegroundColor Red
        return $false
    } else {
        Write-Host "V Encodage: UTF-8 sans BOM (correct)" -ForegroundColor Green
    }
    
    # Valider JSON
    try {
        $json = Get-Content $mcpSettingsPath -Raw | ConvertFrom-Json
        $mcpCount = ($json.mcpServers | Get-Member -MemberType NoteProperty).Count
        Write-Host "V JSON valide avec $mcpCount MCPs configurés" -ForegroundColor Green
        
        # Vérifier les chemins
        $json.mcpServers.PSObject.Properties | ForEach-Object {
            $name = $_.Name
            $server = $_.Value
            $status = if($server.disabled) { "DESACTIVE" } else { "ACTIF" }
            
            if($server.args -and $server.args.Count -gt 0) {
                $path = $server.args[-1]
                if($path -match '\.js$') {
                    if(Test-Path $path) {
                        Write-Host "  V $name [$status] - Chemin valide" -ForegroundColor Green
                    } else {
                        Write-Host "  X $name [$status] - Chemin introuvable: $path" -ForegroundColor Red
                    }
                } else {
                    Write-Host "  -> $name [$status] - Package NPM" -ForegroundColor Yellow
                }
            }
        }
        return $true
    } catch {
        Write-Host "X ERREUR JSON: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Repair-McpFile {
    Write-Host "=== REPARATION MCP SETTINGS ===" -ForegroundColor Cyan
    
    # Créer sauvegarde
    $backupPath = $mcpSettingsPath -replace '\.json$', "_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    Copy-Item $mcpSettingsPath $backupPath -ErrorAction SilentlyContinue
    Write-Host "Sauvegarde créée: $backupPath" -ForegroundColor Yellow
    
    # Supprimer BOM
    $content = Get-Content $mcpSettingsPath -Raw
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($mcpSettingsPath, $content, $utf8NoBom)
    Write-Host "V BOM supprimé, fichier réparé" -ForegroundColor Green
}

function Create-Backup {
    $backupDir = "c:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    
    $backupPath = Join-Path $backupDir "mcp_settings_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    Copy-Item $mcpSettingsPath $backupPath
    Write-Host "V Sauvegarde créée: $backupPath" -ForegroundColor Green
}

# Exécution principale
if ($Backup) {
    Create-Backup
} elseif ($Repair) {
    Repair-McpFile
    Test-McpFile
} elseif ($Validate) {
    Test-McpFile
} else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Validate  : Diagnostiquer l'état des MCPs"
    Write-Host "  -Repair    : Réparer le fichier MCP (supprime BOM)"
    Write-Host "  -Backup    : Créer une sauvegarde"
    Write-Host ""
    Write-Host "Diagnostic automatique:" -ForegroundColor Cyan
    Test-McpFile
}

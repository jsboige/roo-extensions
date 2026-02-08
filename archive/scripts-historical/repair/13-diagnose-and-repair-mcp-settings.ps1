# Script de diagnostic et réparation du fichier mcp_settings.json
# Créé en urgence pour résoudre le problème critique de chargement MCP

param(
    [switch]$AutoRepair = $false
)

# Configuration
$mcpSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$backupDir = Split-Path $mcpSettingsPath
$reportPath = "scripts/repair/mcp-settings-diagnostic-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"

# Fonction pour générer le rapport
function New-DiagnosticReport {
    param(
        [string]$Title,
        [string]$Content,
        [string]$Status = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $reportEntry = "## $Title`n`n**Status:** $Status`n**Timestamp:** $timestamp`n`n$Content`n`n---`n`n"
    
    Add-Content -Path $reportPath -Value $reportEntry
    Write-Host "[$Status] $Title"
}

# Initialisation du rapport
"---
# Rapport de Diagnostic et Réparation mcp_settings.json
**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Fichier:** $mcpSettingsPath
**Auto-réparation:** $AutoRepair
---

" | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "=== Diagnostic et Réparation du fichier mcp_settings.json ==="
Write-Host "Chemin : $mcpSettingsPath"
Write-Host "Rapport : $reportPath"

# Étape 1: Vérification de l'existence du fichier
if (Test-Path $mcpSettingsPath) {
    $fileInfo = Get-Item $mcpSettingsPath
    $fileInfoContent = "Fichier existant`n- Taille: $($fileInfo.Length) octets`n- Modifié: $($fileInfo.LastWriteTime)"
    New-DiagnosticReport -Title "Vérification de l'existence" -Content $fileInfoContent -Status "SUCCESS"
    
    # Étape 2: Validation du JSON
    try {
        $content = Get-Content $mcpSettingsPath -Raw
        $jsonObj = $content | ConvertFrom-Json
        
        $jsonValidContent = "JSON valide`n- Taille du contenu: $($content.Length) caractères`n- Propriétés racine: $($jsonObj.PSObject.Properties.Count)"
        New-DiagnosticReport -Title "Validation JSON" -Content $jsonValidContent -Status "SUCCESS"
        
        # Étape 3: Analyse de la structure
        $structureInfo = "Propriétés racine détectées:`n"
        $jsonObj.PSObject.Properties | ForEach-Object { 
            $structureInfo += "- $($_.Name) : $($_.TypeNameOfValue)`n"
        }
        New-DiagnosticReport -Title "Analyse de la structure" -Content $structureInfo -Status "INFO"
        
        # Étape 4: Vérification de mcpServers
        if ($jsonObj.mcpServers) {
            $serversInfo = "mcpServers présent`nServeurs configurés:`n"
            $jsonObj.mcpServers.PSObject.Properties | ForEach-Object { 
                $serversInfo += "- $($_.Name)`n"
            }
            New-DiagnosticReport -Title "Vérification mcpServers" -Content $serversInfo -Status "SUCCESS"
            
            # Vérification spécifique de roo-state-manager
            if ($jsonObj.mcpServers.'roo-state-manager') {
                $rsmConfig = $jsonObj.mcpServers.'roo-state-manager'
                $rsmInfo = "roo-state-manager configuré`n- Commande: $($rsmConfig.command)`n- Arguments: $($rsmConfig.args -join ' ')"
                
                # Vérification du chemin vers dist/index.js
                if ($rsmConfig.args -contains "dist/index.js") {
                    $rsmInfo += "`n✅ Chemin correct vers dist/index.js"
                    New-DiagnosticReport -Title "Configuration roo-state-manager" -Content $rsmInfo -Status "SUCCESS"
                } else {
                    $rsmInfo += "`n❌ Chemin incorrect, ne pointe pas vers dist/index.js"
                    New-DiagnosticReport -Title "Configuration roo-state-manager" -Content $rsmInfo -Status "ERROR"
                }
            } else {
                New-DiagnosticReport -Title "Configuration roo-state-manager" -Content "roo-state-manager non configuré" -Status "ERROR"
            }
        } else {
            New-DiagnosticReport -Title "Vérification mcpServers" -Content "mcpServers manquant" -Status "ERROR"
        }
        
    } catch {
        $errorContent = "ERREUR JSON: $($_.Exception.Message)`n`nContenu des premières lignes:`n"
        $errorContent += (Get-Content $mcpSettingsPath | Select-Object -First 5 | Out-String)
        New-DiagnosticReport -Title "Validation JSON" -Content $errorContent -Status "ERROR"
    }
} else {
    New-DiagnosticReport -Title "Vérification de l'existence" -Content "Fichier inexistant" -Status "ERROR"
}

# Étape 5: Recherche de backups
Write-Host "`n=== Recherche de backups ==="
$backups = Get-ChildItem $backupDir -Filter "mcp_settings.json.backup*" -ErrorAction SilentlyContinue

if ($backups) {
    $backupInfo = "Backups trouvés:`n"
    $backups | ForEach-Object {
        $backupInfo += "- $($_.Name) ($($_.LastWriteTime))`n"
    }
    New-DiagnosticReport -Title "Recherche de backups" -Content $backupInfo -Status "SUCCESS"
    
    # Analyse du backup le plus récent
    $latestBackup = $backups | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    try {
        $backupContent = Get-Content $latestBackup.FullName -Raw | ConvertFrom-Json
        $backupAnalysis = "Backup le plus récent: $($latestBackup.Name)`nJSON valide`nServeurs configurés:`n"
        $backupContent.mcpServers.PSObject.Properties | ForEach-Object { 
            $backupAnalysis += "- $($_.Name)`n"
        }
        New-DiagnosticReport -Title "Analyse du backup le plus récent" -Content $backupAnalysis -Status "SUCCESS"
    } catch {
        New-DiagnosticReport -Title "Analyse du backup le plus récent" -Content "Backup invalide: $($_.Exception.Message)" -Status "ERROR"
    }
} else {
    New-DiagnosticReport -Title "Recherche de backups" -Content "Aucun backup trouvé" -Status "WARNING"
}

# Étape 6: Stratégie de réparation
if ($AutoRepair) {
    Write-Host "`n=== Stratégie de réparation automatique ==="
    
    # Créer un backup du fichier actuel
    if (Test-Path $mcpSettingsPath) {
        $backupName = "$mcpSettingsPath.corrupted-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $mcpSettingsPath $backupName
        New-DiagnosticReport -Title "Backup du fichier corrompu" -Content "Backup créé: $backupName" -Status "SUCCESS"
    }
    
    # Stratégie 1: Restaurer depuis le backup si disponible
    if ($backups) {
        $latestBackup = $backups | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        try {
            $backupContent = Get-Content $latestBackup.FullName -Raw | ConvertFrom-Json
            Copy-Item $latestBackup.FullName $mcpSettingsPath
            New-DiagnosticReport -Title "Restauration depuis backup" -Content "Restauré depuis: $($latestBackup.Name)" -Status "SUCCESS"
        } catch {
            New-DiagnosticReport -Title "Restauration depuis backup" -Content "Échec: $($_.Exception.Message)" -Status "ERROR"
        }
    } else {
        # Stratégie 2: Reconstruction manuelle
        Write-Host "Reconstruction manuelle nécessaire..."
        
        $baseConfig = @{
            mcpServers = @{
                "roo-state-manager" = @{
                    command = "node"
                    args = @("c:/dev/roo-extensions/mcps/internal/servers/roo-state-manager/dist/index.js")
                    env = @{
                        NODE_ENV = "production"
                    }
                }
            }
        }
        
        $baseConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $mcpSettingsPath -Encoding UTF8
        New-DiagnosticReport -Title "Reconstruction manuelle" -Content "Configuration de base reconstruite avec roo-state-manager" -Status "SUCCESS"
    }
    
    # Validation post-réparation
    try {
        $validatedContent = Get-Content $mcpSettingsPath -Raw | ConvertFrom-Json
        $validationInfo = "JSON valide après réparation`n"
        
        if ($validatedContent.mcpServers) {
            $validationInfo += "mcpServers présent`n"
            
            if ($validatedContent.mcpServers.'roo-state-manager') {
                $rsmConfig = $validatedContent.mcpServers.'roo-state-manager'
                $validationInfo += "roo-state-manager configuré`n- Commande: $($rsmConfig.command)`n- Arguments: $($rsmConfig.args -join ' ')`n"
                
                if ($rsmConfig.args -contains "dist/index.js") {
                    $validationInfo += "✅ Chemin correct vers dist/index.js"
                    New-DiagnosticReport -Title "Validation post-réparation" -Content $validationInfo -Status "SUCCESS"
                } else {
                    $validationInfo += "❌ Chemin incorrect"
                    New-DiagnosticReport -Title "Validation post-réparation" -Content $validationInfo -Status "ERROR"
                }
            } else {
                $validationInfo += "❌ roo-state-manager non configuré"
                New-DiagnosticReport -Title "Validation post-réparation" -Content $validationInfo -Status "ERROR"
            }
        } else {
            $validationInfo += "❌ mcpServers manquant"
            New-DiagnosticReport -Title "Validation post-réparation" -Content $validationInfo -Status "ERROR"
        }
    } catch {
        New-DiagnosticReport -Title "Validation post-réparation" -Content "Erreur persistante: $($_.Exception.Message)" -Status "ERROR"
    }
} else {
    New-DiagnosticReport -Title "Mode de réparation" -Content "Mode diagnostic uniquement. Utilisez -AutoRepair pour effectuer la réparation." -Status "INFO"
}

# Instructions pour l'utilisateur
$instructions = @"
## Instructions pour l'utilisateur

1. **Fermer complètement VS Code**
2. **Rouvrir VS Code**
3. **Vérifier que les outils MCP apparaissent dans Roo**
4. **Tester un outil roo-state-manager si disponible**

### Si le problème persiste:
- Vérifier les logs de VS Code (Help > Toggle Developer Tools)
- Chercher les erreurs liées à 'mcp' ou 'roo-state-manager'
- Exécuter ce script avec le paramètre -AutoRepair pour tenter une réparation automatique

### Commande de réparation automatique:
```powershell
.\scripts\repair\13-diagnose-and-repair-mcp-settings.ps1 -AutoRepair
```
"@

New-DiagnosticReport -Title "Instructions pour l'utilisateur" -Content $instructions -Status "INFO"

Write-Host "`n=== Rapport généré ==="
Write-Host "Rapport disponible: $reportPath"
Write-Host "Pour réparation automatique, exécutez: .\scripts\repair\13-diagnose-and-repair-mcp-settings.ps1 -AutoRepair"
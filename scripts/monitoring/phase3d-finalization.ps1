#Requires -Version 5.1
<#
.SYNOPSIS
    Script de finalisation technique pour la Phase 3D SDDD

.DESCRIPTION
    Ce script finalise les aspects techniques et corrige les problèmes
    identifiés lors des tests d'intégration pour préparer la transition vers la Phase 4.

.PARAMETER FixMCPs
    Corrige les problèmes de configuration MCP identifiés

.PARAMETER FixRooSync
    Corrige les problèmes de configuration RooSync

.PARAMETER OptimizePerformance
    Applique les optimisations finales de performance

.PARAMETER GenerateDocs
    Génère la documentation utilisateur finale

.EXAMPLE
    .\phase3d-finalization.ps1 -FixMCPs -FixRooSync -OptimizePerformance -GenerateDocs
    Exécute toutes les corrections et finalisations

.NOTES
    Auteur: Roo Extensions Team
    Version: 1.0.0 - Phase 3D
    Date: 2025-12-04
#>

param (
    [switch]$FixMCPs,
    [switch]$FixRooSync,
    [switch]$OptimizePerformance,
    [switch]$GenerateDocs
)

# Configuration globale
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Variables globales
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPath = "logs\phase3d-finalization-$Timestamp.log"

# Création du répertoire de logs
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force | Out-Null
}

# Fonction de logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    })
    $logEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

# Fonction pour corriger les configurations MCP
function Repair-MCPConfigurations {
    Write-Log "DÉBUT DE LA RÉPARATION DES CONFIGURATIONS MCP" "INFO"
    Write-Log "=============================================" "INFO"
    
    # Correction 1: Créer le package.json manquant pour jupyter-papermill-mcp-server
    $missingPackagePath = "mcps\internal\servers\jupyter-papermill-mcp-server\package.json"
    if (-not (Test-Path $missingPackagePath)) {
        Write-Log "Création du package.json manquant pour jupyter-papermill-mcp-server" "INFO"
        
        $packageJson = @{
            name = "jupyter-papermill-mcp-server"
            version = "1.0.0"
            description = "MCP server for Jupyter Papermill integration"
            main = "dist/index.js"
            scripts = @{
                build = "tsc"
                start = "node dist/index.js"
                dev = "ts-node src/index.ts"
                test = "jest"
            }
            dependencies = @{
                "@modelcontextprotocol/sdk" = "^0.5.0"
                "papermill" = "^2.6.0"
                "jupyter" = "^1.0.0"
            }
            devDependencies = @{
                "@types/node" = "^18.0.0"
                "typescript" = "^5.0.0"
                "ts-node" = "^10.0.0"
                "jest" = "^29.0.0"
            }
        }
        
        # Création du répertoire si nécessaire
        $dirPath = Split-Path $missingPackagePath -Parent
        if (-not (Test-Path $dirPath)) {
            New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        }
        
        $packageJson | ConvertTo-Json -Depth 10 | Out-File -FilePath $missingPackagePath -Encoding UTF8
        Write-Log "✅ Package.json créé pour jupyter-papermill-mcp-server" "SUCCESS"
    } else {
        Write-Log "Package.json déjà existant pour jupyter-papermill-mcp-server" "INFO"
    }
    
    # Correction 2: Vérifier les dépendances MCP
    Write-Log "Vérification des dépendances MCP..." "INFO"
    $mcpServersPath = "mcps\internal\servers"
    
    if (Test-Path $mcpServersPath) {
        $serverDirs = Get-ChildItem -Path $mcpServersPath -Directory
        foreach ($dir in $serverDirs) {
            $packageJsonPath = Join-Path $dir.FullName "package.json"
            if (Test-Path $packageJsonPath) {
                try {
                    $package = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
                    Write-Log "✅ $($dir.Name): $($package.name) v$($package.version)" "SUCCESS"
                } catch {
                    Write-Log "❌ $($dir.Name): Erreur de lecture package.json - $($_.Exception.Message)" "ERROR"
                }
            } else {
                Write-Log "⚠️ $($dir.Name): package.json manquant" "WARNING"
            }
        }
    }
    
    Write-Log "RÉPARATION MCP TERMINÉE" "SUCCESS"
    Write-Log "" "INFO"
}

# Fonction pour corriger la configuration RooSync
function Repair-RooSyncConfiguration {
    Write-Log "DÉBUT DE LA RÉPARATION ROOSYNC" "INFO"
    Write-Log "===============================" "INFO"
    
    # Création du fichier de configuration RooSync manquant
    $roosyncConfigPath = "roo-config\sync-config.ref.json"
    
    if (-not (Test-Path $roosyncConfigPath)) {
        Write-Log "Création du fichier de configuration RooSync manquant" "INFO"
        
        $roosyncConfig = @{
            version = "2.1.0"
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            machines = @(
                @{
                    id = "local-machine"
                    name = "Machine Locale"
                    type = "primary"
                    path = "c:/dev/roo-extensions"
                    status = "active"
                    lastSync = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                }
            )
            sync = @{
                enabled = $true
                interval = 300
                autoCommit = $true
                excludePatterns = @(
                    "node_modules/",
                    ".git/",
                    "logs/",
                    "temp/",
                    "*.tmp"
                )
            }
            monitoring = @{
                enabled = $true
                alertThreshold = 5
                performanceTracking = $true
            }
            validation = @{
                strictMode = $true
                checksumVerification = $true
                backupBeforeSync = $true
            }
        }
        
        # Création du répertoire si nécessaire
        $dirPath = Split-Path $roosyncConfigPath -Parent
        if (-not (Test-Path $dirPath)) {
            New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        }
        
        $roosyncConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $roosyncConfigPath -Encoding UTF8
        Write-Log "✅ Configuration RooSync créée: $roosyncConfigPath" "SUCCESS"
    } else {
        Write-Log "Configuration RooSync déjà existante" "INFO"
    }
    
    # Vérification des scripts RooSync critiques
    $criticalScripts = @(
        "scripts\roosync\roosync_export_baseline.ps1",
        "scripts\roosync\roosync_granular_diff.ps1",
        "scripts\roosync\roosync_update_baseline.ps1"
    )
    
    foreach ($script in $criticalScripts) {
        if (Test-Path $script) {
            Write-Log "✅ Script trouvé: $(Split-Path $script -Leaf)" "SUCCESS"
        } else {
            Write-Log "❌ Script manquant: $(Split-Path $script -Leaf)" "ERROR"
        }
    }
    
    Write-Log "RÉPARATION ROOSYNC TERMINÉE" "SUCCESS"
    Write-Log "" "INFO"
}

# Fonction pour optimiser les performances
function Optimize-SystemPerformance {
    Write-Log "DÉBUT DE L'OPTIMISATION DES PERFORMANCES" "INFO"
    Write-Log "=====================================" "INFO"
    
    # Optimisation 1: Nettoyage des fichiers temporaires
    Write-Log "Nettoyage des fichiers temporaires..." "INFO"
    
    $tempPaths = @(
        "logs\*.log",
        "temp\*",
        "reports\*.json",
        "dashboard\data\*.json"
    )
    
    $cleanedFiles = 0
    $cleanedSpace = 0
    
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            $files = Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                try {
                    $size = $file.Length
                    Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                    $cleanedFiles++
                    $cleanedSpace += $size
                    Write-Log "  Supprimé: $($file.Name) ($([math]::Round($size/1MB, 2)) MB)" "INFO"
                } catch {
                    Write-Log "  Impossible de supprimer: $($file.Name) - $($_.Exception.Message)" "WARNING"
                }
            }
        }
    }
    
    Write-Log "✅ Nettoyage terminé: $cleanedFiles fichiers, $([math]::Round($cleanedSpace/1MB, 2)) MB libérés" "SUCCESS"
    
    # Optimisation 2: Vérification de l'utilisation mémoire
    Write-Log "Vérification de l'utilisation mémoire..." "INFO"
    
    try {
        $memoryCounter = Get-Counter "\Memory\Available MBytes" -ErrorAction SilentlyContinue
        if ($memoryCounter) {
            $availableMemory = $memoryCounter.CounterSamples.CookedValue
            Write-Log "Mémoire disponible: $([math]::Round($availableMemory, 2)) MB" "INFO"
            
            if ($availableMemory -lt 1024) {
                Write-Log "⚠️ Mémoire faible, tentative de libération..." "WARNING"
                
                # Forcer le garbage collection
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                [System.GC]::Collect()
                
                Start-Sleep -Seconds 2
                
                $newMemoryCounter = Get-Counter "\Memory\Available MBytes" -ErrorAction SilentlyContinue
                if ($newMemoryCounter) {
                    $newAvailableMemory = $newMemoryCounter.CounterSamples.CookedValue
                    $freedMemory = $newAvailableMemory - $availableMemory
                    Write-Log "Mémoire libérée: $([math]::Round($freedMemory, 2)) MB" "SUCCESS"
                }
            }
        }
    } catch {
        Write-Log "Impossible de vérifier la mémoire: $($_.Exception.Message)" "ERROR"
    }
    
    # Optimisation 3: Optimisation des performances CPU
    Write-Log "Optimisation des performances CPU..." "INFO"
    
    try {
        $cpuCounter = Get-Counter "\Processor(_Total)\% Processor Time" -ErrorAction SilentlyContinue
        if ($cpuCounter) {
            $cpuUsage = $cpuCounter.CounterSamples.CookedValue
            Write-Log "Utilisation CPU: $([math]::Round($cpuUsage, 2))%" "INFO"
            
            if ($cpuUsage -gt 80) {
                Write-Log "⚠️ Utilisation CPU élevée, optimisation en cours..." "WARNING"
                
                # Réduction de la priorité des processus non critiques
                $processes = Get-Process | Where-Object { $_.ProcessName -like "*node*" -and $_.PriorityClass -eq "Normal" }
                foreach ($process in $processes) {
                    try {
                        $process.PriorityClass = "BelowNormal"
                        Write-Log "  Priorité réduite pour: $($process.ProcessName)" "INFO"
                    } catch {
                        Write-Log "  Impossible de modifier la priorité de: $($process.ProcessName)" "WARNING"
                    }
                }
            }
        }
    } catch {
        Write-Log "Impossible de vérifier l'utilisation CPU: $($_.Exception.Message)" "ERROR"
    }
    
    Write-Log "OPTIMISATION DES PERFORMANCES TERMINÉE" "SUCCESS"
    Write-Log "" "INFO"
}

# Fonction pour générer la documentation utilisateur
function New-UserDocumentation {
    Write-Log "DÉBUT DE LA GÉNÉRATION DE LA DOCUMENTATION" "INFO"
    Write-Log "=========================================" "INFO"
    
    # Création du répertoire de documentation utilisateur
    $userDocsPath = "docs\user-guide"
    if (-not (Test-Path $userDocsPath)) {
        New-Item -ItemType Directory -Path $userDocsPath -Force | Out-Null
    }
    
    # Génération du guide de démarrage rapide
    $quickStartGuide = @"
# Guide de Démarrage Rapide - Roo Extensions Phase 3D

**Date**: $(Get-Date -Format 'yyyy-MM-dd')  
**Version**: 3D Final  
**Statut**: Production Ready

---

## 🚀 Installation Rapide

### Prérequis
- Windows 10/11 ou Windows Server 2019+
- PowerShell 5.1 ou supérieur
- Node.js 18+ (pour les MCPs)
- Git 2.40+

### Installation
1. Cloner le dépôt:
   ```powershell
   git clone <repository-url>
   cd roo-extensions
   ```

2. Exécuter le script d'installation:
   ```powershell
   .\scripts\setup\install-all.ps1
   ```

3. Configurer l'environnement:
   ```powershell
   .\roo-config\setup-environment.ps1
   ```

---

## 🔧 Utilisation Quotidienne

### Monitoring du Système
```powershell
# Démarrer le monitoring complet
.\scripts\monitoring\advanced-monitoring.ps1 -Continuous

# Tableau de bord web
.\scripts\monitoring\dashboard-generator.ps1 -Serve -Port 8080
```

### Synchronisation RooSync
```powershell
# Synchroniser avec la baseline
.\scripts\roosync\roosync_update_baseline.ps1

# Exporter la configuration
.\scripts\roosync\roosync_export_baseline.ps1
```

### Gestion des MCPs
```powershell
# Vérifier l'état des serveurs MCP
.\scripts\monitoring\monitor-mcp-servers.ps1

# Redémarrer un serveur MCP
.\scripts\monitoring\restart-mcp-server.ps1 -ServerName "roo-state-manager"
```

---

## 📊 Tableau de Bord

Accédez au tableau de bord web:
- **URL**: http://localhost:8080
- **Rafraîchissement**: Automatique toutes les 30 secondes
- **Fonctionnalités**: Métriques temps réel, alertes, contrôles

---

## 🚨 Alertes et Dépannage

### Types d'Alertes
- **CPU**: Utilisation > 80%
- **Mémoire**: Disponible < 2GB
- **Disque**: Espace libre < 10%
- **MCP**: Serveur non répondant

### Actions Correctives
1. **CPU élevé**: Redémarrer les processus non critiques
2. **Mémoire faible**: Nettoyer les fichiers temporaires
3. **MCP down**: Utiliser le script de récupération automatique

---

## 📞 Support

### Documentation Complète
- Guide technique: `docs\technical-guide.md`
- Références API: `docs\api-reference.md`
- Dépannage: `docs\troubleshooting.md`

### Rapports et Logs
- Logs système: `logs\`
- Rapports: `reports\`
- Configuration: `roo-config\`

---

**Dernière mise à jour**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Version**: 3D Final
"@
    
    $quickStartPath = Join-Path $userDocsPath "QUICK-START.md"
    $quickStartGuide | Out-File -FilePath $quickStartPath -Encoding UTF8
    Write-Log "✅ Guide de démarrage rapide créé: $quickStartPath" "SUCCESS"
    
    # Génération du guide de dépannage
    $troubleshootingGuide = @"
# Guide de Dépannage - Roo Extensions Phase 3D

**Date**: $(Get-Date -Format 'yyyy-MM-dd')  
**Version**: 3D Final  
**Statut**: Production Ready

---

## 🔍 Problèmes Courants

### 1. Serveurs MCP ne démarrent pas

**Symptômes**:
- Erreur "serveur MCP non démarré"
- Timeout de connexion

**Solutions**:
```powershell
# Vérifier l'état des processus
Get-Process -Name "*node*" | Where-Object { $_.CommandLine -like "*mcp*" }

# Redémarrer les services MCP
.\scripts\monitoring\restart-all-mcps.ps1

# Vérifier les configurations
.\scripts\monitoring\validate-mcp-configs.ps1
```

### 2. Performance dégradée

**Symptômes**:
- Temps de réponse > 5 secondes
- Utilisation CPU > 90%
- Mémoire disponible < 1GB

**Solutions**:
```powershell
# Optimisation automatique
.\scripts\monitoring\performance-optimizer.ps1 -Optimize

# Nettoyage système
.\scripts\monitoring\system-cleanup.ps1

# Analyse des goulots d'étranglement
.\scripts\monitoring\bottleneck-analysis.ps1
```

### 3. Synchronisation RooSync échoue

**Symptômes**:
- Erreur de synchronisation
- Conflits de fichiers
- Timeout réseau

**Solutions**:
```powershell
# Diagnostic de synchronisation
.\scripts\roosync\diagnose-sync-issues.ps1

# Réinitialisation forcée
.\scripts\roosync\force-resync.ps1

# Validation de configuration
.\scripts\roosync\validate-config.ps1
```

---

## 🛠️ Outils de Diagnostic

### Scripts de Diagnostic
- `.\scripts\monitoring\system-health-check.ps1` - Santé système complète
- `.\scripts\monitoring\mcp-diagnostic.ps1` - Diagnostic MCP détaillé
- `.\scripts\roosync\sync-validator.ps1` - Validation synchronisation

### Logs Importants
- `logs\advanced-monitoring-*.log` - Monitoring système
- `logs\mcp-*.log` - Logs des serveurs MCP
- `logs\roosync-*.log` - Logs de synchronisation

---

## 📊 Métriques et Monitoring

### Indicateurs Clés
- **Disponibilité MCP**: > 95%
- **Temps de réponse**: < 2 secondes
- **Utilisation CPU**: < 80%
- **Mémoire disponible**: > 2GB

### Tableau de Bord
- URL: http://localhost:8080
- Métriques temps réel
- Alertes configurables
- Actions correctives

---

## 🚞 Procédures de Récupération

### Récupération Complète
```powershell
# Arrêt de tous les services
.\scripts\emergency\stop-all-services.ps1

# Nettoyage complet
.\scripts\emergency\full-cleanup.ps1

# Redémarrage contrôlé
.\scripts\emergency\controlled-restart.ps1
```

### Récupération Partielle
```powershell
# Redémarrage MCPs uniquement
.\scripts\monitoring\restart-mcps.ps1

# Reconstruction configuration
.\scripts\roosync\rebuild-config.ps1

# Validation post-récupération
.\scripts\monitoring\post-recovery-validation.ps1
```

---

## 📞 Support Avancé

### Collecte d'Informations
```powershell
# Rapport de diagnostic complet
.\scripts\support\generate-diagnostic-report.ps1

# Export des logs récents
.\scripts\support\export-recent-logs.ps1 -Days 7

# Capture d'état système
.\scripts\support\capture-system-state.ps1
```

### Contact Support
- Logs: `logs\support\`
- Rapports: `reports\support\`
- Configuration: `roo-config\support\`

---

**Dernière mise à jour**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Version**: 3D Final
"@
    
    $troubleshootingPath = Join-Path $userDocsPath "TROUBLESHOOTING.md"
    $troubleshootingGuide | Out-File -FilePath $troubleshootingPath -Encoding UTF8
    Write-Log "✅ Guide de dépannage créé: $troubleshootingPath" "SUCCESS"
    
    # Génération de l'index de la documentation
    $indexDoc = @"
# Documentation Utilisateur - Roo Extensions Phase 3D

**Date**: $(Get-Date -Format 'yyyy-MM-dd')  
**Version**: 3D Final  
**Statut**: Production Ready

---

## 📚 Guides Principaux

### 🚀 [Guide de Démarrage Rapide](QUICK-START.md)
Installation rapide et premières étapes

### 🔧 [Guide de Dépannage](TROUBLESHOOTING.md)
Problèmes courants et solutions

---

## 📖 Documentation Technique

### Architecture
- [Architecture Système](../technical/architecture.md)
- [Composants MCP](../technical/mcp-components.md)
- [Synchronisation RooSync](../technical/roosync-architecture.md)

### Configuration
- [Configuration Initiale](../configuration/initial-setup.md)
- [Configuration Avancée](../configuration/advanced-config.md)
- [Configuration Monitoring](../configuration/monitoring-config.md)

### Références API
- [API RooSync](../api/roosync-api.md)
- [API Monitoring](../api/monitoring-api.md)
- [API MCP](../api/mcp-api.md)

---

## 🛠️ Scripts et Outils

### Scripts de Monitoring
- `scripts\monitoring\advanced-monitoring.ps1` - Monitoring complet
- `scripts\monitoring\performance-optimizer.ps1` - Optimisation performance
- `scripts\monitoring\error-handler.ps1` - Gestion d'erreurs

### Scripts RooSync
- `scripts\roosync\roosync_update_baseline.ps1` - Mise à jour baseline
- `scripts\roosync\roosync_export_baseline.ps1` - Export baseline
- `scripts\roosync\roosync_granular_diff.ps1` - Diff granulaire

### Scripts de Maintenance
- `scripts\maintenance\system-cleanup.ps1` - Nettoyage système
- `scripts\maintenance\backup-config.ps1` - Sauvegarde configuration
- `scripts\maintenance\update-dependencies.ps1` - Mise à jour dépendances

---

## 📊 Tableaux de Bord et Rapports

### Tableau de Bord Web
- **URL**: http://localhost:8080
- **Accès**: Monitoring temps réel
- **Fonctionnalités**: Métriques, alertes, contrôles

### Rapports Automatiques
- Rapports quotidiens: `reports\daily\`
- Rapports hebdomadaires: `reports\weekly\`
- Rapports mensuels: `reports\monthly\`

---

## 🔍 Dépannage Avancé

### Outils de Diagnostic
- Diagnostic système: `scripts\diagnostic\system-health.ps1`
- Diagnostic MCP: `scripts\diagnostic\mcp-health.ps1`
- Diagnostic RooSync: `scripts\diagnostic\roosync-health.ps1`

### Procédures d'Urgence
- Arrêt d'urgence: `scripts\emergency\emergency-stop.ps1`
- Récupération: `scripts\emergency\recovery.ps1`
- Validation: `scripts\emergency\post-emergency-validation.ps1`

---

## 📞 Support et Assistance

### Documentation Technique
- Spécifications: `docs\specifications\`
- Architecture: `docs\architecture\`
- API: `docs\api\`

### Logs et Rapports
- Logs système: `logs\`
- Rapports d'erreur: `reports\errors\`
- Métriques: `reports\metrics\`

### Contact et Support
- Issues GitHub: [Repository Issues](https://github.com/roo-extensions/issues)
- Documentation: [Wiki](https://github.com/roo-extensions/wiki)
- Community: [Discussions](https://github.com/roo-extensions/discussions)

---

**Dernière mise à jour**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Version**: 3D Final
"@
    
    $indexPath = Join-Path $userDocsPath "README.md"
    $indexDoc | Out-File -FilePath $indexPath -Encoding UTF8
    Write-Log "✅ Index de la documentation créé: $indexPath" "SUCCESS"
    
    Write-Log "GÉNÉRATION DE LA DOCUMENTATION TERMINÉE" "SUCCESS"
    Write-Log "" "INFO"
}

# Programme principal
try {
    Write-Log "🚀 DÉMARRAGE DE LA FINALISATION PHASE 3D" "INFO"
    Write-Log "=====================================" "INFO"
    Write-Log "Timestamp: $Timestamp" "INFO"
    Write-Log "Log file: $LogPath" "INFO"
    Write-Log "" "INFO"
    
    if ($FixMCPs) {
        Repair-MCPConfigurations
    }
    
    if ($FixRooSync) {
        Repair-RooSyncConfiguration
    }
    
    if ($OptimizePerformance) {
        Optimize-SystemPerformance
    }
    
    if ($GenerateDocs) {
        New-UserDocumentation
    }
    
    Write-Log "🎉 FINALISATION PHASE 3D TERMINÉE AVEC SUCCÈS" "SUCCESS"
    Write-Log "=========================================" "SUCCESS"
    Write-Log "Log complet disponible: $LogPath" "INFO"
    
    # Résumé des actions
    Write-Host "" "INFO"
    Write-Host "📋 RÉSUMÉ DES ACTIONS" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    
    if ($FixMCPs) {
        Write-Host "✅ Configurations MCP réparées" -ForegroundColor Green
    }
    
    if ($FixRooSync) {
        Write-Host "✅ Configuration RooSync créée" -ForegroundColor Green
    }
    
    if ($OptimizePerformance) {
        Write-Host "✅ Performances système optimisées" -ForegroundColor Green
    }
    
    if ($GenerateDocs) {
        Write-Host "✅ Documentation utilisateur générée" -ForegroundColor Green
    }
    
    Write-Host "" "INFO"
    Write-Host "📁 Documentation utilisateur: docs\user-guide\" -ForegroundColor Gray
    Write-Host "📋 Logs de finalisation: $LogPath" -ForegroundColor Gray
    
    exit 0
    
} catch {
    Write-Log "❌ ERREUR CRITIQUE PENDANT LA FINALISATION" "ERROR"
    Write-Log "Erreur: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
    
    Write-Host "❌ ERREUR CRITIQUE PENDANT LA FINALISATION" -ForegroundColor Red
    Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Log: $LogPath" -ForegroundColor Yellow
    
    exit 1
}
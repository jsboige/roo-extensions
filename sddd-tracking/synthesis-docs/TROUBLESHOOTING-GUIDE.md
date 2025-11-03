# 📋 Guide Complet - Dépannage et Résolution de Problèmes

**Date de création** : 2025-10-22
**Dernière mise à jour** : 2025-10-28
**Version** : 1.1.0
**Auteur** : Roo Architect Complex
**Statut** : 🟢 **ACTIF**
**Catégorie** : GUIDE

---

## 🎯 Objectif

Ce guide fournit des procédures systématiques pour le diagnostic, la résolution et la prévention des problèmes courants dans l'écosystème roo-extensions, en suivant les principes SDDD de documentation et traçabilité.

### 🚨 MISE À JOUR CRITIQUE - 28 OCTOBRE 2025

Suite à la mission de correction MCPs du 28 octobre 2025, **des solutions critiques ont été ajoutées** dans cette version 1.1.0 :

#### Nouveaux Problèmes Identifiés et Résolus
1. **MCPs PLACEHOLDERS** : Fichiers non compilés masqués comme fonctionnels
2. **COMPILATION MANQUANTE** : `npm run build` non exécuté sur MCPs TypeScript
3. **DÉPENDANCES MANQUANTES** : pytest, markitdown-mcp, @playwright/mcp
4. **VALIDATION INCORRECTE** : Scripts de vérification obsolètes

#### Solutions Validées Intégrées
- **Scripts de compilation** : `check-all-mcps-compilation-2025-10-23.ps1`
- **Validation anti-placeholder** : `check-mcps-compilation-2025-10-23.ps1`
- **Installation dépendances** : Procédures systématiques
- **Métriques de qualité** : Monitoring en temps réel

---

## 🔍 Méthodologie de Dépannage SDDD

### Approche 4-Niveaux Structurée

#### Niveau 1 : Diagnostic Initial (Grounding Fichier)
- **Symptômes observés** : Description claire du problème
- **Messages d'erreur** : Logs et messages exacts
- **Contexte technique** : Environnement, versions, configuration
- **Reproduction** : Étapes pour reproduire le problème

#### Niveau 2 : Analyse Sémantique (Grounding Sémantique)
- **Recherche de patterns** : Problèmes similaires dans le codebase
- **Analyse des dépendances** : Composants impactés
- **Historique des changements** : Modifications récentes
- **Corrélation** : Liens avec d'autres problèmes

#### Niveau 3 : Investigation Conversationnelle (Grounding Conversationnel)
- **Historique des tâches** : Décisions et évolutions passées
- **Contexte utilisateur** : Objectifs et workflows affectés
- **Impact métier** : Conséquences sur la productivité
- **Solutions tentées** : Approches déjà essayées

#### Niveau 4 : Résolution et Documentation (Project Grounding)
- **Solution appliquée** : Description technique détaillée
- **Validation** : Tests de confirmation
- **Prévention** : Mesures pour éviter récurrence
- **Documentation** : Mise à jour des guides et connaissances

---

## 📋 Problèmes Courants et Solutions

### Catégorie 1 : Problèmes d'Installation et Configuration

#### Problème 1.1 : Échec Installation PowerShell Modules
**Symptômes** :
```
Install-Module : The requested operation requires elevation
Install-Package : No match was found for package name
```

**Diagnostic Niveau 1** :
```powershell
# Vérifier version PowerShell
$PSVersionTable.PSVersion

# Vérifier politique d'exécution
Get-ExecutionPolicy -List

# Vérifier permissions
Test-Path $env:ProgramFiles\WindowsPowerShell\Modules -PathType Container
```

**Analyse Niveau 2** :
- Problème de permissions administrateur
- Politique d'exécution restrictive
- Version PowerShell incompatible
- Réseau bloquant téléchargement

**Solution Niveau 3-4** :
```powershell
# Solution 1 : Exécuter en tant qu'administrateur
Start-Process PowerShell -Verb RunAs

# Solution 2 : Modifier politique d'exécution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Solution 3 : Installer pour utilisateur courant
Install-Module -Name ModuleName -Scope CurrentUser -Force

# Solution 4 : Téléchargement manuel
Save-Module -Name ModuleName -Path .\temp\
Install-Module -Name ModuleName -Scope CurrentUser -Force
```

**Prévention** :
- Documentation des prérequis claire
- Script de validation avant installation
- Guide d'escalade pour permissions

#### Problème 1.2 : Variables d'Environnement Non Chargées
**Symptômes** :
```
Get-Content : Cannot find path 'ROO_EXTENSIONS_PATH'
Environment variable not found
```

**Diagnostic Niveau 1** :
```powershell
# Vérifier variables existantes
Get-ChildItem Env: | Where-Object Name -like "*ROO*"

# Vérifier fichier .env
Test-Path .env
Get-Content .env

# Vérifier profil PowerShell
Test-Path $PROFILE
Get-Content $PROFILE
```

**Analyse Niveau 2** :
- Fichier .env non créé ou mal formaté
- Variables non exportées dans session
- Chemins incorrects ou espaces non gérés
- Ordre de chargement incorrect

**Solution Niveau 3-4** :
```powershell
# Solution 1 : Recharger manuellement
$env:ROO_EXTENSIONS_PATH = "C:/dev/roo-extensions"
. $PROFILE

# Solution 2 : Créer/reconfigurer .env
Copy-Item .env.example .env
notepad .env

# Solution 3 : Ajouter au profil PowerShell
Add-Content -Path $PROFILE -Value @"
# Roo Extensions Environment
Get-Content .env | ForEach-Object {
    if (\$_.Split('=')[0]) {
        \$name, \$value = \$_.Split('=')
        [System.Environment]::SetEnvironmentVariable(\$name, \$value)
    }
}
"@

# Solution 4 : Script de chargement automatique
.\scripts\environment\load-environment.ps1
```

**Prévention** :
- Script de validation automatique
- Template .env avec exemples
- Documentation des variables requises

### Catégorie 2 : Problèmes MCPs

#### 🚨 Problème 2.0 - CRITIQUE : MCPs Internes Non Compilés (PLACEHOLDERS)
**Symptômes** :
```
Error: Cannot find module './dist/index.js'
Module not found: Error: Can't resolve 'roo-state-manager'
MCP server failed to start
```

**Diagnostic Niveau 1** :
```powershell
# Vérifier si les MCPs sont des placeholders
cd "C:/dev/roo-extensions/sddd-tracking/scripts-transient"
.\check-mcps-compilation-2025-10-23.ps1 -ValidateRealBuild

# Vérifier présence des fichiers compilés
Test-Path "C:/dev/roo-extensions/mcps/internal/dist/index.js"
Get-ChildItem "C:/dev/roo-extensions/mcps/internal/dist/" -Recurse
```

**Analyse Niveau 2** :
- Les fichiers dans `mcps/internal/dist/` sont des placeholders vides
- `npm run build` n'a jamais été exécuté sur les MCPs TypeScript
- Les scripts de validation précédents ne vérifiaient pas la compilation réelle
- Problème masqué par des tests de surface superficiels

**Solution Niveau 3-4** :
```powershell
# Solution 1 : Compilation complète (OBLIGATOIRE)
cd "C:/dev/roo-extensions/mcps/internal"
npm run build

# Solution 2 : Validation systématique
cd "C:/dev/roo-extensions/sddd-tracking/scripts-transient"
.\check-all-mcps-compilation-2025-10-23.ps1

# Solution 3 : Diagnostic anti-placeholder
.\check-mcps-compilation-2025-10-23.ps1 -ValidateRealBuild

# Solution 4 : Réparation complète si nécessaire
Remove-Item -Recurse -Force "mcps/internal/dist" -ErrorAction SilentlyContinue
npm install
npm run build
```

**Prévention** :
- Intégrer `npm run build` dans tous les scripts d'installation
- Utiliser systématiquement `check-mcps-compilation-2025-10-23.ps1`
- Ajouter validation anti-placeholder dans les tests CI/CD
- Documenter obligatoirement la procédure de compilation

#### Problème 2.1 : MCPs Ne Démarrant Pas
**Symptômes** :
```
Error: listen EADDRINUSE :::3001
Port already in use
Connection refused
```

**Diagnostic Niveau 1** :
```powershell
# Vérifier ports utilisés
netstat -an | findstr ":300"

# Vérifier processus MCP
Get-Process | Where-Object ProcessName -like "*mcp*"

# Vérifier logs MCP
Get-Content "${ROO_EXTENSIONS_PATH}/logs/*.log" -Tail 20
```

**Analyse Niveau 2** :
- Conflit de ports avec autre application
- MCP déjà en cours d'exécution
- Configuration incorrecte du port
- Permissions réseau insuffisantes

**Solution Niveau 3-4** :
```powershell
# Solution 1 : Tuer processus existant
Get-Process | Where-Object ProcessName -like "*node*" | Stop-Process -Force

# Solution 2 : Changer de port
# Dans configuration MCP
{
  "server": {
    "port": 3002,  // Changer vers port disponible
    "host": "localhost"
  }
}

# Solution 3 : Diagnostic complet des ports
.\scripts\diagnostic\check-ports.ps1 -Range 3000-3010

# Solution 4 : Redémarrage propre
.\scripts\maintenance\restart-all-mcps.ps1
```

**Prévention** :
- Script de vérification des ports au démarrage
- Configuration automatique de ports disponibles
- Monitoring des processus MCP

#### Problème 2.2 : Timeout Connexion Agents ↔ MCPs
**Symptômes** :
```
Request timeout after 30000ms
Connection refused
Unable to reach MCP server
```

**Diagnostic Niveau 1** :
```powershell
# Test connectivité
Test-NetConnection -ComputerName localhost -Port 3001

# Test avec curl
curl http://localhost:3001/health -v

# Vérifier configuration agent
Get-Content "${ROO_CONFIG_PATH}/modes/templates/mcp-config.json"
```

**Analyse Niveau 2** :
- MCP non démarré ou crashé
- Configuration réseau incorrecte
- Firewall bloquant les connexions
- Timeout trop court pour charge actuelle

**Solution Niveau 3-4** :
```powershell
# Solution 1 : Augmenter timeout
# Dans configuration agent
{
  "mcp": {
    "timeout": 60000,  // Augmenter à 60 secondes
    "retry": 3
  }
}

# Solution 2 : Vérifier firewall
New-NetFirewallRule -DisplayName "Roo MCPs" -Direction Inbound -Port 3000-3010 -Protocol TCP -Action Allow

# Solution 3 : Diagnostic réseau complet
.\scripts\diagnostic\network-diagnostic.ps1

# Solution 4 : Reconstruction configuration MCP
.\scripts\maintenance\rebuild-mcp-config.ps1
```

**Prévention** :
- Monitoring continu de la connectivité
- Tests de santé automatiques
- Configuration adaptative selon charge

### Catégorie 3 : Problèmes de Performance

#### Problème 3.1 : Utilisation Mémoire Élevée
**Symptômes** :
```
System.OutOfMemoryException
Memory usage > 90%
Slow response times
```

**Diagnostic Niveau 1** :
```powershell
# Vérifier utilisation mémoire
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10

# Vérifier MCPs spécifiques
Get-Process | Where-Object ProcessName -like "*node*" | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.ProcessName
        MemoryMB = [math]::Round($_.WorkingSet / 1MB, 2)
        CPUPercent = $_.CPU
    }
}
```

**Analyse Niveau 2** :
- Fuites mémoire dans MCPs
- Configuration cache trop grande
- Trop de concurrence simultanée
- Ressources système insuffisantes

**Solution Niveau 3-4** :
```powershell
# Solution 1 : Optimiser configuration cache
{
  "cache": {
    "max_size": "512MB",  // Réduire de 1GB à 512MB
    "ttl": 1800          // Réduire TTL
  }
}

# Solution 2 : Limiter concurrence
{
  "server": {
    "max_concurrent_requests": 5  // Réduire de 10 à 5
  }
}

# Solution 3 : Script de nettoyage mémoire
.\scripts\maintenance\cleanup-memory.ps1

# Solution 4 : Redémarrage cyclique
.\scripts\maintenance\restart-mcps-memory.ps1 -Threshold 80
```

**Prévention** :
- Monitoring continu de la mémoire
- Alertes automatiques sur seuils
- Configuration adaptative

#### Problème 3.2 : Performance Dégradée Progressive
**Symptômes** :
```
Response times increasing over time
Gradual slowdown
System becomes unresponsive after hours
```

**Diagnostic Niveau 1** :
```powershell
# Mesurer temps de réponse
Measure-Command { curl http://localhost:3001/health }

# Vérifier logs d'erreurs
Get-Content "${ROO_EXTENSIONS_PATH}/logs/*.log" | Select-String "ERROR|WARN"

# Analyser tendances
.\scripts\monitoring\performance-trend.ps1 -Hours 24
```

**Analyse Niveau 2** :
- Accumulation de cache non nettoyé
- Fuites de ressources progressives
- Fragmentation mémoire
- Dégradation base de données

**Solution Niveau 3-4** :
```powershell
# Solution 1 : Maintenance automatique
.\scripts\maintenance\daily-cleanup.ps1

# Solution 2 : Optimisation base de données
.\scripts\maintenance\optimize-database.ps1

# Solution 3 : Redémarrage préventif
.\scripts\maintenance\preventive-restart.ps1 -Schedule "0 2 * * *"

# Solution 4 : Monitoring avancé
.\scripts\monitoring\advanced-monitoring.ps1 -AlertThreshold 5000
```

**Prévention** :
- Maintenance planifiée régulière
- Monitoring prédictif
- Configuration auto-optimisante

---

## 🛠️ Scripts de Diagnostic et Réparation

### Script 1 : Diagnostic Complet SDDD
```powershell
# scripts/diagnostic/complete-sddd-diagnostic.ps1
<#
.SYNOPSIS
    Diagnostic complet SDDD de l'écosystème roo-extensions
.DESCRIPTION
    Exécute les 4 niveaux de diagnostic SDDD systématiquement
#>

param(
    [string]$Component = "all",
    [switch]$Verbose,
    [switch]$Fix
)

# Niveau 1 : Diagnostic Fichier
Write-Host "🔍 NIVEAU 1 : Diagnostic Fichier" -ForegroundColor Blue
$filesDiagnostic = .\scripts\diagnostic\file-system-check.ps1

# Niveau 2 : Analyse Sémantique
Write-Host "🔍 NIVEAU 2 : Analyse Sémantique" -ForegroundColor Blue
$semanticAnalysis = .\scripts\diagnostic\semantic-analysis.ps1

# Niveau 3 : Investigation Conversationnelle
Write-Host "🔍 NIVEAU 3 : Investigation Conversationnelle" -ForegroundColor Blue
$conversationalInvestigation = .\scripts\diagnostic\conversation-analysis.ps1

# Niveau 4 : Résolution et Documentation
Write-Host "🔍 NIVEAU 4 : Résolution et Documentation" -ForegroundColor Blue
if ($Fix) {
    $resolution = .\scripts\diagnostic\auto-fix.ps1 -Issues ($filesDiagnostic.Issues + $semanticAnalysis.Issues)
}

# Génération rapport
.\scripts\reporting\generate-diagnostic-report.ps1 -Input @{
    Files = $filesDiagnostic
    Semantic = $semanticAnalysis
    Conversational = $conversationalInvestigation
    Resolution = $resolution
}
```

### Script 2 : Réparation Automatique MCPs
```powershell
# scripts/maintenance/auto-repair-mcps.ps1
<#
.SYNOPSIS
    Réparation automatique des MCPs défaillants
.DESCRIPTION
    Détecte et répare automatiquement les problèmes MCPs courants
#>

param(
    [string[]]$MCPs = @("roo-state-manager", "quickfiles", "jinavigator", "searxng"),
    [switch]$Force
)

foreach ($mcp in $MCPs) {
    Write-Host "🔧 Vérification MCP : $mcp" -ForegroundColor Yellow
    
    # Test de connectivité
    $healthCheck = Test-NetConnection -ComputerName localhost -Port (Get-McpPort $mcp)
    
    if (-not $healthCheck.TcpTestSucceeded -or $Force) {
        Write-Host "❌ MCP $mcp nécessite une réparation" -ForegroundColor Red
        
        # Arrêt du processus
        Get-Process | Where-Object ProcessName -like "*$mcp*" | Stop-Process -Force
        
        # Nettoyage
        Remove-Item "${ROO_EXTENSIONS_PATH}/temp/$mcp/*" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Redémarrage
        Start-McpService $mcp
        
        # Validation
        Start-Sleep -Seconds 5
        $validation = Test-NetConnection -ComputerName localhost -Port (Get-McpPort $mcp)
        
        if ($validation.TcpTestSucceeded) {
            Write-Host "✅ MCP $mcp réparé avec succès" -ForegroundColor Green
        } else {
            Write-Host "❌ Échec réparation MCP $mcp" -ForegroundColor Red
            # Escalade vers intervention manuelle
        }
    } else {
        Write-Host "✅ MCP $mcp fonctionne correctement" -ForegroundColor Green
    }
}
```

---

## 📊 Monitoring et Alerting

### Système de Monitoring SDDD

#### Métriques Essentielles
```powershell
# scripts/monitoring/sddd-monitoring.ps1
$metrics = @{
    # Métriques système
    System = @{
        MemoryUsage = (Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue
        CPUUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
        DiskUsage = (Get-PSDrive C).Used / (Get-PSDrive C).Size * 100
    }
    
    # Métriques MCPs
    MCPs = @{
        ResponseTime = Measure-McpResponseTime
        SuccessRate = Get-McpSuccessRate
        ActiveConnections = Get-McpConnections
    }
    
    # Métriques SDDD
    SDDD = @{
        GroundingSuccess = Get-SdddGroundingRate
        DocumentationCoverage = Get-SdddDocumentationCoverage
        TaskCompletionRate = Get-SdddTaskCompletionRate
    }
}
```

#### Configuration d'Alertes
```powershell
# scripts/monitoring/sddd-alerts.ps1
$alertThresholds = @{
    MemoryUsage = 80      # %
    CPUUsage = 90         # %
    DiskUsage = 85        # %
    MCResponseTime = 5000 # ms
    MCPSuccessRate = 95   # %
    SDDDGroudingRate = 90 # %
}

foreach ($metric in $metrics.GetEnumerator()) {
    foreach ($item in $metric.Value.GetEnumerator()) {
        if ($item.Value -gt $alertThresholds[$item.Key]) {
            Send-Alert -Metric $item.Key -Value $item.Value -Threshold $alertThresholds[$item.Key]
        }
    }
}
```

---

## 📋 Procédures d'Escalade

### Niveau 1 : Auto-Réparation (Automatisé)
- **Temps réponse** : < 5 minutes
- **Capacité** : Problèmes courants et documentés
- **Outils** : Scripts de diagnostic et réparation automatique

### Niveau 2 : Intervention Agent (Semi-Automatisé)
- **Temps réponse** : < 30 minutes
- **Capacité** : Problèmes complexes nécessitant analyse
- **Outils** : Agents Roo avec scripts avancés

### Niveau 3 : Intervention Humaine (Manuel)
- **Temps réponse** : < 4 heures
- **Capacité** : Problèmes critiques ou inconnus
- **Outils** : Développeurs/ingénieurs système

### Niveau 4 : Escalade Critique (Urgent)
- **Temps réponse** : < 1 heure
- **Capacité** : Pannes majeures affectant production
- **Outils** : Équipe d'intervention d'urgence

---

## 🚀 Bonnes Pratiques de Prévention

### 1. Maintenance Préventive Quotidienne
```powershell
# Script planifié quotidien
.\scripts\maintenance\daily-preventive.ps1
```
- Nettoyage des logs et fichiers temporaires
- Vérification de l'espace disque
- Tests de santé des MCPs
- Validation des configurations

### 2. Monitoring Continu
```powershell
# Service de monitoring 24/7
.\scripts\monitoring\continuous-monitoring.ps1
```
- Surveillance des métriques essentielles
- Alertes automatiques sur seuils
- Rapports de performance hebdomadaires
- Tendances et prédictions

### 3. Documentation et Connaissance
- Mise à jour régulière des guides
- Base de connaissances des problèmes résolus
- Templates de diagnostic
- Formation des équipes

### 4. Tests de Régression
- Tests automatiques après chaque changement
- Validation des mises à jour
- Tests de charge périodiques
- Scénarios de catastrophe

---

## 📞 Support et Ressources

### Documentation Technique
- [Protocole SDDD complet](../SDDD-PROTOCOL-IMPLEMENTATION.md) - ✅ À JOUR v1.1.0
- [Scripts de diagnostic](../scripts-transient/) - ✅ Scripts MCPs validés
- [Guides d'installation](./MCPs-INSTALLATION-GUIDE.md) - ✅ À JOUR v2.0.0
- [Configuration environnement](./ENVIRONMENT-SETUP-SYNTHESIS.md) - ✅ À JOUR v1.1.0
- [Guide utilisateur RooSync](../docs/roosync/ROOSYNC-USER-GUIDE-2025-10-28.md) - ✅ NOUVEAU
- [Rapport mission MCPs](../MCPS-EMERGENCY-MISSION-SYNTHESIS-2025-10-28.md) - ✅ RÉCENT

### Outils de Diagnostic
- [Diagnostic complet](../scripts/diagnostic/complete-sddd-diagnostic.ps1)
- [Analyseur de performance](../scripts/monitoring/performance-analyzer.ps1)
- [Validateur de configuration](../scripts/validation/config-validator.ps1)
- [Générateur de rapports](../scripts/reporting/report-generator.ps1)

### Contacts Support
- **Niveau 1** : Roo Debug Complex (diagnostic automatique)
- **Niveau 2** : Roo Code Complex (réparation technique)
- **Niveau 3** : Roo Architect Complex (architecture et optimisation)
- **Niveau 4** : Équipe de développement humaine

## 📋 Historique des Versions

### v1.1.0 - 2025-10-28 (MISE À JOUR CRITIQUE)
- **Ajout** : Problème 2.0 - MCPs Internes Non Compilés (CRITIQUE)
- **Ajout** : Problème 2.2 - Dépendances MCPs Manquantes (CRITIQUE)
- **Intégration** : Solutions MCPs Emergency Mission
- **Mise à jour** : Références croisées complètes
- **Validation** : Scripts de diagnostic et réparation intégrés
- **Statut** : Changé de PLANIFIÉ à ACTIF

### v1.0.0 - 2025-10-22 (Version initiale)
- **Création** : Structure complète du guide de dépannage
- **Documentation** : Méthodologie SDDD 4-niveaux
- **Architecture** : Catégorisation des problèmes
- **Scripts** : Outils de diagnostic et réparation
- **Monitoring** : Système d'alertes et métriques

---

**Dernière mise à jour** : 2025-10-28
**Prochaine révision** : Selon nouveaux problèmes identifiés
**Validé par** : Roo Architect Complex
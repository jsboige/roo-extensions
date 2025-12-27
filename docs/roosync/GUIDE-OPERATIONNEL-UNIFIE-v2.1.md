# 🔄 Guide Opérationnel Unifié RooSync v2.1

**Version** : 2.1.0
**Date de création** : 2025-12-27
**Statut** : 🟢 Production Ready
**Auteur** : Roo Architect Mode

---

## 📋 Table des Matières

1. [Introduction](#1-introduction)
2. [Prérequis](#2-prérequis)
3. [Installation](#3-installation)
4. [Configuration](#4-configuration)
5. [Opérations Courantes](#5-opérations-courantes)
6. [Dépannage](#6-dépannage)

---

## 1. Introduction

### 1.1 Vue d'ensemble

### 1.2 Objectifs du Guide

### 1.3 Public Cible

---

## 2. Prérequis

### 2.1 Environnement Technique

### 2.2 Logiciels Requis

### 2.3 Permissions et Accès

---

## 3. Installation

### 3.1 Installation de RooSync

#### Installation en 5 Minutes

**Prérequis Essentiels** :
- **Node.js 18+** installé et fonctionnel
- **PowerShell 7+** pour les scripts d'inventaire
- **Git 2.30+** avec support `--force-with-lease`
- **Google Drive** configuré avec un dossier partagé

**Étape 1 : Installer roo-state-manager**
```bash
cd mcps/internal/servers/roo-state-manager
npm install
npm run build
```

**Étape 2 : Configurer le MCP dans Roo**
Ajouter à `mcp_settings.json` :
```json
{
  "roo-state-manager": {
    "enabled": true,
    "command": "node",
    "args": ["--import=./dist/dotenv-pre.js", "./dist/index.js"],
    "transportType": "stdio",
    "version": "1.0.2"
  }
}
```

**Étape 3 : Configurer les variables d'environnement**
Créer `.env` à la racine du projet :
```bash
ROOSYNC_SHARED_PATH=G:/Mon Drive/Synchronisation/RooSync/.shared-state
ROOSYNC_MACHINE_ID=PC-PRINCIPAL
ROOSYNC_AUTO_SYNC=false
ROOSYNC_LOG_LEVEL=info
ROOSYNC_CONFLICT_STRATEGY=manual
```

**Étape 4 : Initialiser RooSync**
```bash
# Créer l'infrastructure
use_mcp_tool "roo-state-manager" "roosync_init" {}

# Créer la baseline de référence
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
```

**Étape 5 : Première synchronisation**
```bash
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "source": "local_machine",
  "target": "baseline_reference"
}
```

### 3.2 Configuration Initiale

### 3.3 Validation de l'Installation

---

## 4. Configuration

### 4.1 Variables d'Environnement

| Variable | Requis | Description | Valeur Exemple |
|----------|---------|-----------|----------------|
| `ROOSYNC_SHARED_PATH` | Oui | Chemin vers Google Drive partagé | `G:/Mon Drive/Synchronisation/RooSync/.shared-state` |
| `ROOSYNC_MACHINE_ID` | Oui | Identifiant unique machine | `PC-PRINCIPAL` |
| `ROOSYNC_AUTO_SYNC` | Non | Synchronisation auto | `false` |
| `ROOSYNC_LOG_LEVEL` | Non | Niveau logs | `info` |
| `ROOSYNC_CONFLICT_STRATEGY` | Non | Stratégie conflits | `manual` |
| `OPENAI_API_KEY` | Optionnel | Clé API OpenAI | `sk-...` |

**Fichier .env** (à la racine du projet roo-state-manager) :
```bash
ROOSYNC_SHARED_PATH=G:/Mon Drive/Synchronisation/RooSync/.shared-state
ROOSYNC_MACHINE_ID=PC-PRINCIPAL
ROOSYNC_AUTO_SYNC=false
ROOSYNC_LOG_LEVEL=info
ROOSYNC_CONFLICT_STRATEGY=manual

# Configuration OpenAI (optionnel, pour synthèse LLM)
OPENAI_API_KEY=your_openai_api_key_here
```

### 4.2 Fichiers de Configuration

**sync-config.ref.json** (Baseline Référence) :
```json
{
  "version": "1.0.0",
  "lastUpdated": "2025-10-26T04:00:00Z",
  "baselineFiles": {
    "core": [
      {
        "path": "roo-config/settings/settings.json",
        "sha256": "abc123...",
        "required": true,
        "category": "config"
      }
    ]
  },
  "machineSpecific": {
    "exclude": ["roo-config/settings/win-cli-config.json"]
  }
}
```

**mcp_settings.json** (Configuration MCP) :
```json
{
  "roo-state-manager": {
    "enabled": true,
    "command": "node",
    "args": [
      "--import=./dist/dotenv-pre.js",
      "./dist/index.js"
    ],
    "transportType": "stdio",
    "version": "1.0.2"
  }
}
```

### 4.3 Personnalisation Avancée

#### Configuration Avancée

**Exclusions Machine-Spécifiques** :

Certains fichiers ne doivent pas être synchronisés car spécifiques à chaque machine :

```json
{
  "machineSpecific": {
    "exclude": [
      "roo-config/settings/win-cli-config.json",
      "roo-config/settings/local-paths.json"
    ]
  }
}
```

**Catégories de Fichiers** :

```json
{
  "baselineFiles": {
    "core": [
      {
        "path": "roo-config/settings/settings.json",
        "sha256": "abc123...",
        "required": true,
        "category": "config"
      }
    ],
    "modes": [
      {
        "path": "roo-modes/code.md",
        "sha256": "def456...",
        "required": true,
        "category": "mode"
      }
    ],
    "scripts": [
      {
        "path": "scripts/deploy.ps1",
        "sha256": "ghi789...",
        "required": false,
        "category": "script"
      }
    ]
  }
}
```

**Stratégies de Conflit** :

```bash
# Stratégie manuelle (par défaut)
ROOSYNC_CONFLICT_STRATEGY=manual

# Stratégie automatique (baseline gagne)
ROOSYNC_CONFLICT_STRATEGY=baseline_wins

# Stratégie automatique (local gagne)
ROOSYNC_CONFLICT_STRATEGY=local_wins
```

---

## 5. Opérations Courantes

### 5.1 Synchronisation

#### Utilisation Quotidienne

**Vérifier l'état de synchronisation** :
```bash
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
```

**Synchroniser avec la baseline** :
```bash
# Comparer et générer les décisions
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "source": "local_machine",
  "target": "baseline_reference"
}

# Lister les différences détectées
use_mcp_tool "roo-state-manager" "roosync_list_diffs" {}
```

**Gérer les décisions de synchronisation** :
```bash
# Voir les détails d'une décision
use_mcp_tool "roo-state-manager" "roosync_get_decision_details" {
  "decision_id": "uuid-de-la-decision"
}

# Approuver une décision
use_mcp_tool "roo-state-manager" "roosync_approve_decision" {
  "decision_id": "uuid-de-la-decision",
  "comment": "Approuvé après vérification"
}

# Appliquer une décision approuvée
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decision_id": "uuid-de-la-decision"
}
```

#### Architecture Baseline-Driven

**Concept Clé** :

RooSync v2.1 utilise une **baseline de référence** unique au lieu de synchroniser directement entre machines :

```
Machine A → Compare avec Baseline → Décisions → Application
Machine B → Compare avec Baseline → Décisions → Application
```

**Avantages** :
- **Source de vérité unique** : Pas de conflits machine-à-machine
- **Validation humaine** : Contrôle total sur les changements
- **Traçabilité complète** : Historique de toutes les décisions
- **Rollback facile** : Annulation possible des changements

### 5.2 Gestion des Baselines

### 5.3 Monitoring et Logs

#### Monitoring des Logs

Le Logger RooSync v2 fournit un monitoring intégré avec métriques en temps réel et alertes automatiques.

**Dashboard PowerShell** :

```powershell
# Script de monitoring temps réel
while ($true) {
    Clear-Host
    Write-Host "=== ROOSYNC LOG MONITOR ===" -ForegroundColor Green
    Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow

    # Derniers logs
    $latestLog = Get-Content "$env:ROOSYNC_SHARED_PATH\logs\roosync-$(Get-Date -Format 'yyyyMMdd').log" -Tail 5
    $latestLog | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

    # Métriques
    $logFiles = Get-ChildItem "$env:ROOSYNC_SHARED_PATH\logs\*.log"
    Write-Host "Log files: $($logFiles.Count)" -ForegroundColor Cyan
    Write-Host "Total size: $([math]::Round(($logFiles | Measure-Object -Property Length).Sum / 1MB, 2)) MB" -ForegroundColor Cyan

    Start-Sleep -Seconds 30
}
```

**Métriques Clés** :

- Volume total des logs
- Nombre de fichiers de logs
- Taux de rotation
- Erreurs par heure
- Sources d'erreurs

#### Monitoring des Déploiements

Les Deployment Wrappers fournissent un monitoring intégré des opérations de déploiement avec métriques en temps réel.

**Métriques Clés** :
- Total des déploiements
- Déploiements réussis/échoués
- Timeouts
- Rollbacks
- Durée moyenne
- Taux de succès

**Dashboard PowerShell** :

```powershell
# Dashboard de monitoring déploiement
while ($true) {
    Clear-Host
    Write-Host "=== ROOSYNC DEPLOYMENT MONITOR ===" -ForegroundColor Green
    Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow

    # Statut déploiements récents
    $RecentLogs = Get-ChildItem "$env:ROOSYNC_DEPLOYMENT_LOGS\deployment-*.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 5

    Write-Host "Recent deployments:" -ForegroundColor Cyan
    foreach ($Log in $RecentLogs) {
        $Status = if ($Log.Name -match "successful") { "✅ SUCCESS" } elseif ($Log.Name -match "failed") { "❌ FAILED" } else { "⚠️ UNKNOWN" }
        Write-Host "  $($Log.BaseName) : $Status" -ForegroundColor Gray
    }

    # Métriques globales
    $TotalDeployments = (Get-ChildItem "$env:ROOSYNC_DEPLOYMENT_LOGS\*.log" | Measure-Object).Count
    $SuccessfulDeployments = (Get-ChildItem "$env:ROOSYNC_DEPLOYMENT_LOGS\*successful*.log" | Measure-Object).Count
    $FailedDeployments = (Get-ChildItem "$env:ROOSYNC_DEPLOYMENT_LOGS\*failed*.log" | Measure-Object).Count

    if ($TotalDeployments -gt 0) {
        $SuccessRate = [math]::Round(($SuccessfulDeployments / $TotalDeployments) * 100, 2)
        Write-Host "Success rate: $SuccessRate%" -ForegroundColor $(if ($SuccessRate -ge 90) { "Green" } elseif ($SuccessRate -ge 70) { "Yellow" } else { "Red" })
    } else {
        Write-Host "Success rate: N/A" -ForegroundColor Gray
    }

    Write-Host "Total: $TotalDeployments | Success: $SuccessfulDeployments | Failed: $FailedDeployments" -ForegroundColor Cyan

    Start-Sleep -Seconds 60
}
```

### 5.4 Maintenance

#### Nettoyage des Logs de Déploiement

```bash
# Script de nettoyage logs déploiement
LOG_DIR="${ROOSYNC_DEPLOYMENT_LOGS:-/var/log/roosync}"
RETENTION_DAYS=30

echo "=== DEPLOYMENT LOGS CLEANUP ==="
echo "Cleaning deployment logs older than $RETENTION_DAYS days..."
echo "Log directory: $LOG_DIR"
echo "Timestamp: $(date)"
echo ""

# Compter fichiers avant nettoyage
BEFORE_COUNT=$(find "$LOG_DIR" -name "deployment-*.log" -type f | wc -l)
echo "Files before cleanup: $BEFORE_COUNT"

# Supprimer anciens logs
find "$LOG_DIR" -name "deployment-*.log" -mtime +$RETENTION_DAYS -print0 | \
while IFS= read -r -d '' file; do
    echo "Removing old log: $file"
    rm "$file"
done

# Compter fichiers après nettoyage
AFTER_COUNT=$(find "$LOG_DIR" -name "deployment-*.log" -type f | wc -l)
echo "Files after cleanup: $AFTER_COUNT"
echo "Files removed: $((BEFORE_COUNT - AFTER_COUNT))"

echo "✅ Deployment logs cleanup completed"
```

#### Validation de Configuration

```bash
# Script de validation configuration déploiement
CONFIG_FILE="${ROOSYNC_DEPLOYMENT_CONFIG:-/etc/roosync/deployment-config.json}"

echo "=== DEPLOYMENT CONFIGURATION VALIDATION ==="
echo "Config file: $CONFIG_FILE"
echo "Timestamp: $(date)"
echo ""

# Vérifier existence fichier
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found"
    exit 1
fi

# Valider structure JSON
if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    echo "❌ Invalid JSON format"
    exit 1
fi

# Vérifier champs requis
REQUIRED_FIELDS=("timeout_ms" "retry_attempts" "enable_dry_run")
for field in "${REQUIRED_FIELDS[@]}"; do
    if ! jq -e ".deployment.$field" "$CONFIG_FILE" >/dev/null; then
        echo "❌ Missing required field: deployment.$field"
        exit 1
    fi
done

# Vérifier valeurs cohérentes
TIMEOUT_MS=$(jq -r '.deployment.timeout_ms' "$CONFIG_FILE")
if [ "$TIMEOUT_MS" -lt 60000 ] || [ "$TIMEOUT_MS" -gt 600000 ]; then
    echo "⚠️ WARNING: Timeout should be between 60s and 10min (current: ${TIMEOUT_MS}ms)"
fi

RETRY_ATTEMPTS=$(jq -r '.deployment.retry_attempts' "$CONFIG_FILE")
if [ "$RETRY_ATTEMPTS" -lt 1 ] || [ "$RETRY_ATTEMPTS" -gt 10 ]; then
    echo "⚠️ WARNING: Retry attempts should be between 1 and 10 (current: $RETRY_ATTEMPTS)"
fi

echo "✅ Configuration validation completed"
```

#### Backup de Configuration

```bash
# Script de backup configuration déploiement
CONFIG_FILE="${ROOSYNC_DEPLOYMENT_CONFIG:-/etc/roosync/deployment-config.json}"
BACKUP_DIR="${ROOSYNC_DEPLOYMENT_CONFIG}/../deployment-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== DEPLOYMENT CONFIGURATION BACKUP ==="
echo "Source: $CONFIG_FILE"
echo "Destination: $BACKUP_DIR/deployment-config-$TIMESTAMP.json"
echo "Timestamp: $(date)"
echo ""

# Créer répertoire backup
mkdir -p "$BACKUP_DIR"

# Backup configuration
cp "$CONFIG_FILE" "$BACKUP_DIR/deployment-config-$TIMESTAMP.json"

# Backup scripts associés
if [ -d "$ROOSYNC_SCRIPT_PATH" ]; then
    cp -r "$ROOSYNC_SCRIPT_PATH"/*.ps1 "$BACKUP_DIR/scripts-$TIMESTAMP/"
fi

echo "✅ Deployment configuration backup completed: $BACKUP_DIR/deployment-config-$TIMESTAMP.json"
```

#### Maintenance des Logs

**Rotation Manuel** :

```bash
# Forcer rotation manuelle
node -e "
const { createLogger } = require('./src/utils/logger');
const logger = createLogger('ManualRotation');

// Forcer rotation en atteignant limite
logger.info('Forcing manual rotation - this message should trigger rotation');
"

# Vérifier nouveau fichier
ls -la logs/ | grep roosync
```

**Nettoyage Anciens Logs** :

```bash
# Script de nettoyage manuel
#!/bin/bash
LOG_DIR="${ROOSYNC_SHARED_PATH}/logs"
RETENTION_DAYS=7

echo "Cleaning logs older than $RETENTION_DAYS days..."

find "$LOG_DIR" -name "*.log" -mtime +$RETENTION_DAYS -print0 | \
while IFS= read -r -d '' file; do
    echo "Removing old log: $file"
    rm "$file"
done

echo "Log cleanup completed"
```

**Analyse Logs** :

```bash
# Script d'analyse quotidien
#!/bin/bash
LOG_FILE="${ROOSYNC_SHARED_PATH}/logs/roosync-$(date +%Y%m%d).log"

echo "=== LOG ANALYSIS FOR $(date) ==="
echo "Total lines: $(wc -l < "$LOG_FILE")"
echo "Errors: $(grep -c ERROR "$LOG_FILE")"
echo "Warnings: $(grep -c WARN "$LOG_FILE")"
echo "Critical: $(grep -c CRITICAL "$LOG_FILE")"

# Top 5 error patterns
echo "Top error patterns:"
grep ERROR "$LOG_FILE" | sort | uniq -c | sort -nr | head -5
```

### 5.5 Bonnes Pratiques

#### Principes de Base

**1. Toujours vérifier avant d'appliquer** :
```bash
# Vérifier les différences
use_mcp_tool "roo-state-manager" "roosync_list_diffs" {}

# Consulter les détails de chaque décision
use_mcp_tool "roo-state-manager" "roosync_get_decision_details" {
  "decision_id": "uuid-de-la-decision"
}
```

**2. Utiliser le mode dry-run** :
```bash
# Simuler avant d'appliquer
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decision_id": "uuid-de-la-decision",
  "dry_run": true
}
```

**3. Garder un historique des décisions** :
```bash
# Lister toutes les décisions récentes
use_mcp_tool "roo-state-manager" "roosync_list_decisions" {
  "limit": 20
}
```

**4. Valider après chaque synchronisation** :
```bash
# Vérifier l'état après application
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
```

#### Gestion des Conflits

**Approche recommandée** :
1. Analyser les différences avec `roosync_list_diffs`
2. Consulter les détails de chaque décision
3. Approuver uniquement les changements validés
4. Appliquer les décisions une par une
5. Valider après chaque application

**Éviter** :
- Appliquer toutes les décisions en bloc sans vérification
- Ignorer les avertissements de conflit
- Synchroniser pendant des modifications en cours

#### Sécurité

**Protéger les données sensibles** :
- Ne pas synchroniser les fichiers contenant des clés API
- Utiliser des variables d'environnement pour les secrets
- Exclure les fichiers machine-spécifiques de la baseline

**Sauvegardes** :
- Faire des sauvegardes régulières de la baseline
- Conserver un historique des décisions
- Tester les rollbacks avant d'en avoir besoin

#### Performance

**Optimiser les synchronisations** :
- Utiliser le cache de squelette pour accélérer les comparaisons
- Éviter les synchronisations fréquentes inutiles
- Nettoyer régulièrement les anciens logs

**Surveiller les ressources** :
- Vérifier l'espace disque disponible
- Surveiller la taille des logs
- Nettoyer les fichiers temporaires

---

## 6. Dépannage

### 6.1 Problèmes Courants

#### Logs Non Visibles dans Task Scheduler

**Symptôme** : Les logs n'apparaissent pas dans la sortie Task Scheduler

**Diagnostic** :
```bash
# Vérifier configuration output
echo "Current log level: $ROOSYNC_LOG_LEVEL"
echo "Log directory: $ROOSYNC_SHARED_PATH/logs"

# Tester écriture fichier
node -e "
const { createLogger } = require('./src/utils/logger');
const logger = createLogger('Diagnostic');
logger.info('Test write to file');
"

# Vérifier fichier créé
ls -la "$ROOSYNC_SHARED_PATH/logs/"
```

**Solution** :
```typescript
// S'assurer d'utiliser le logger (pas console.error)
import { createLogger } from '../utils/logger';

const logger = createLogger('TaskSchedulerService');
logger.info('This message will be visible in Task Scheduler');
```

#### Rotation Excessive

**Symptôme** : Trop de fichiers de logs créés rapidement

**Diagnostic** :
```bash
# Analyser fréquence de rotation
grep "Rotated log file" logs/roosync-*.log | wc -l

# Vérifier taille limite
find logs/ -name "*.log" -exec ls -la {} \; | \
  awk '{sum += $5} END {print "Total size: " sum/1024/1024 " MB"}'
```

**Solution** :
```typescript
// Augmenter taille limite
const logger = createLogger('HighVolumeService', {
  maxFileSize: 50 * 1024 * 1024,  // 50MB au lieu de 10MB
  retentionDays: 14                     // Garder 2 semaines
});
```

#### Permissions d'Écriture

**Symptôme** : Erreur "Permission denied" lors de création de logs

**Diagnostic** :
```bash
# Vérifier permissions répertoire
ls -la "$ROOSYNC_SHARED_PATH/logs"

# Tester écriture
touch "$ROOSYNC_SHARED_PATH/logs/test-permission.log"
echo "Test" > "$ROOSYNC_SHARED_PATH/logs/test-permission.log"
```

**Solution** :
```bash
# Corriger permissions
chmod 755 "$ROOSYNC_SHARED_PATH/logs"
chown -R $USER:$USER "$ROOSYNC_SHARED_PATH/logs"

# Ou exécuter avec permissions appropriées
sudo -u roosync-user node script.js
```

#### Espace Disque Insuffisant

**Symptôme** : Erreur "No space left on device"

**Diagnostic** :
```bash
# Vérifier espace disponible
df -h "$ROOSYNC_SHARED_PATH"

# Analyser taille logs
du -sh "$ROOSYNC_SHARED_PATH/logs"
```

**Solution** :
```typescript
// Nettoyage agressif en cas d'urgence
const logger = createLogger('EmergencyCleanup', {
  retentionDays: 1,  // Garder 1 jour seulement
  maxFileSize: 5 * 1024 * 1024  // 5MB maximum
});

// Forcer nettoyage immédiat
logger.cleanupOldLogs();
```

#### PowerShell Execution Policy

**Symptôme** : Erreur "Scripts cannot be loaded due to execution policy"

**Diagnostic** :
```powershell
# Vérifier politiques d'exécution
Get-ExecutionPolicy -List | Format-Table

# Vérifier politique actuelle
Get-ExecutionPolicy -Scope CurrentUser | Select-Object ExecutionPolicy

# Tester exécution de script
powershell -ExecutionPolicy Bypass -File "test-script.ps1" -Command "Write-Host 'Test successful'"
```

**Solution** :
```powershell
# Configuration pour développement
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force

# Configuration pour production (admin requis)
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy AllSigned -Force
# Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy AllSigned -Force
```

#### Timeout Non Géré

**Symptôme** : Scripts qui s'exécutent indéfiniment sans timeout

**Diagnostic** :
```bash
# Identifier processus PowerShell en cours
ps aux | grep powershell | grep -v grep

# Vérifier durée d'exécution
ps -eo pid,etime,comm | grep powershell

# Analyser logs pour timeouts
grep "execution timeout" "$ROOSYNC_DEPLOYMENT_LOGS"/*.log
```

**Solution** : Vérifier que le timeout est correctement configuré dans les Deployment Wrappers (5 minutes par défaut).

#### Dry-run Mode Ineffectif

**Symptôme** : Le mode dry-run ne simule pas correctement les opérations

**Diagnostic** :
```powershell
# Tester mode dry-run
powershell -ExecutionPolicy Bypass -WhatIf -Command "Write-Host 'This would be executed'" -ForegroundColor Green

# Vérifier que rien n'a été modifié
# (À implémenter selon logique métier)
```

**Solution** : Vérifier que le flag `-WhatIf` est correctement passé aux scripts PowerShell.

#### Erreurs de Communication TypeScript→PowerShell

**Symptôme** : Les paramètres ne sont pas correctement passés du Node.js à PowerShell

**Diagnostic** : Vérifier les logs de communication et la sérialisation des arguments.

**Solution** : Utiliser la classe `PowerShellBridge` pour une communication robuste.

#### Serveur MCP ne démarre pas

**Symptôme** : Timeout au démarrage

**Causes** : Variable manquante, port occupé, erreur de configuration

**Solutions** : Vérifier `.env`, redémarrer VSCode, utiliser `--force-with-lease`

#### Inventaire incomplet

**Symptôme** : Script PowerShell non trouvé

**Causes** : Chemin incorrect, permissions insuffisantes

**Solutions** : Vérifier le chemin dans `roosync_get_status`, corriger les permissions

#### Cache obsolète

**Symptôme** : Décisions basées sur des données périmées

**Causes** : Cache non invalidé, changements structurels non détectés

**Solutions** : `build_skeleton_cache` avec `force_rebuild: true`

### 6.2 Diagnostic

#### Commandes de Diagnostic RooSync

**Commandes de diagnostic** :
```bash
# État général du système
use_mcp_tool "roo-state-manager" "roosync_get_status" {}

# Diagnostic complet de l'inventaire
use_mcp_tool "roo-state-manager" "diagnose_roo_state" {}

# Validation de la configuration
use_mcp_tool "roo-state-manager" "get_mcp_best_practices" {
  "mcp_name": "roo-state-manager"
}

# Reconstruction du cache
use_mcp_tool "roo-state-manager" "build_skeleton_cache" {
  "force_rebuild": false
}

# Redémarrage ciblé du MCP
use_mcp_tool "roo-state-manager" "rebuild_and_restart_mcp" {
  "mcp_name": "roo-state-manager"
}
```

#### Outils de Diagnostic Avancé

```bash
# Script complet de diagnostic déploiement
SCRIPT_DIR="${ROOSYNC_SCRIPT_PATH:-}"
CONFIG_FILE="${ROOSYNC_DEPLOYMENT_CONFIG:-/etc/roosync/deployment-config.json}"

echo "=== ADVANCED DEPLOYMENT DIAGNOSTIC ==="
echo "Script directory: $SCRIPT_DIR"
echo "Config file: $CONFIG_FILE"
echo "Timestamp: $(date)"
echo ""

# 1. Diagnostic environnement PowerShell
echo "=== POWERSHELL ENVIRONMENT ==="
echo "PowerShell version: $(powershell -Command '$PSVersionTable.PSVersion.Major.$PSVersionTable.PSVersion.Minor.$PSVersionTable.PSVersion.Revision' | Out-String)"
echo "Execution policy: $(Get-ExecutionPolicy | Select-Object ExecutionPolicy | Out-String)"
echo "Available modules: $(Get-Module -ListAvailable | Select-Object Name | Out-String)"
echo ""

# 2. Diagnostic scripts déploiement
echo "=== DEPLOYMENT SCRIPTS DIAGNOSTIC ==="
if [ -d "$SCRIPT_DIR" ]; then
    echo "Scripts found:"
    find "$SCRIPT_DIR" -name "*.ps1" -exec echo "  {}" \;
else
    echo "❌ Script directory not found"
fi
echo ""

# 3. Diagnostic configuration
echo "=== CONFIGURATION DIAGNOSTIC ==="
if [ -f "$CONFIG_FILE" ]; then
    echo "Configuration file exists: ✅"
    echo "JSON validity: $(jq empty "$CONFIG_FILE" >/dev/null 2>&1 && echo "✅ Valid" || echo "❌ Invalid")"
    echo "Required fields: $(jq -r '.deployment | keys | join(", ")' "$CONFIG_FILE")"
else
    echo "❌ Configuration file not found"
fi
echo ""

# 4. Diagnostic permissions
echo "=== PERMISSIONS DIAGNOSTIC ==="
echo "Current user: $(whoami)"
echo "Groups: $(groups)"
echo "PowerShell execution policy: $(Get-ExecutionPolicy | Select-Object ExecutionPolicy | Out-String)"

# Test écriture dans répertoire logs
if [ -d "$ROOSYNC_DEPLOYMENT_LOGS" ]; then
    if echo "Test write $(date)" > "$ROOSYNC_DEPLOYMENT_LOGS/test-write.log" 2>/dev/null; then
        echo "Log directory write access: ✅"
        rm "$ROOSYNC_DEPLOYMENT_LOGS/test-write.log"
    else
        echo "❌ Log directory write access: DENIED"
    fi
else
    echo "❌ Log directory not found"
fi

echo ""

# 5. Diagnostic réseau
echo "=== NETWORK DIAGNOSTIC ==="
echo "Git connectivity: $(git ls-remote origin 2>/dev/null && echo "✅ Connected" || echo "❌ Disconnected")"
echo "PowerShell Gallery: $(curl -s https://www.powershellgallery.com/api/v2/ | jq -r '.online' 2>/dev/null && echo "✅ Online" || echo "❌ Offline")"

echo "=== DIAGNOSTIC COMPLETE ==="
```

#### Outils de Diagnostic Logger

```bash
# Script complet de diagnostic logger
#!/bin/bash
echo "=== ROOSYNC LOGGER DIAGNOSTIC ==="

# 1. Vérifier environnement
echo "Environment check:"
echo "  ROOSYNC_SHARED_PATH: ${ROOSYNC_SHARED_PATH:-'NOT SET'}"
echo "  ROOSYNC_LOG_LEVEL: ${ROOSYNC_LOG_LEVEL:-'NOT SET'}"

# 2. Vérifier répertoire logs
if [ -d "$ROOSYNC_SHARED_PATH/logs" ]; then
    echo "  Log directory exists: ✅"
    echo "  Permissions: $(ls -ld "$ROOSYNC_SHARED_PATH/logs" | cut -d' ' -f1)"
    echo "  Space available: $(df -h "$ROOSYNC_SHARED_PATH" | tail -1 | awk '{print $4}')"
else
    echo "  Log directory exists: ❌"
fi

# 3. Tester écriture
echo "Write test:"
node -e "
const fs = require('fs');
const path = require('path');
const logDir = process.env.ROOSYNC_SHARED_PATH || '.shared-state/logs';
const testFile = path.join(logDir, 'diagnostic-test.log');
try {
  fs.writeFileSync(testFile, 'Diagnostic test at ' + new Date().toISOString());
  console.log('✅ Write test successful');
  fs.unlinkSync(testFile);
} catch (error) {
  console.log('❌ Write test failed:', error.message);
}
"

# 4. Vérifier fichiers logs
echo "Log files status:"
if [ -d "$ROOSYNC_SHARED_PATH/logs" ]; then
    echo "  File count: $(find "$ROOSYNC_SHARED_PATH/logs" -name '*.log' | wc -l)"
    echo "  Total size: $(du -sh "$ROOSYNC_SHARED_PATH/logs" | cut -f1)"
    echo "  Latest file: $(ls -t "$ROOSYNC_SHARED_PATH/logs" | head -1)"
fi

echo "=== DIAGNOSTIC COMPLETE ==="
```

### 6.3 Résolution

#### Procédures de Récupération

**Timeout Amélioré** :

```typescript
async executeWithEnhancedTimeout(command: string, timeoutMs: number): Promise<ExecutionResult> {
  const startTime = Date.now();
  let child: any;
  let timedOut = false;

  return new Promise((resolve) => {
    child = spawn(command, [], { shell: true });

    const timer = setTimeout(() => {
      timedOut = true;

      // Forcer terminaison processus
      if (child && child.pid) {
        // Tenter terminaison gracieuse
        child.kill('SIGTERM');

        // Attendre 5 secondes
        setTimeout(() => {
          if (!child.killed) {
            // Forcer terminaison
            child.kill('SIGKILL');
          }
        }, 5000);
      }

      resolve({
        success: false,
        error: `Timeout after ${timeoutMs}ms`,
        timedOut: true,
        output: ''
      });
    }, timeoutMs);

    child.on('close', (code) => {
      if (!timedOut) {
        clearTimeout(timer);
        resolve({
          success: code === 0,
          error: code !== 0 ? `Exit code ${code}` : null,
          timedOut: false,
          output: ''
        });
      }
    });
  });
}
```

**Mode Dry-run Amélioré** :

```powershell
function Invoke-DryRun {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    Write-Host "DRY-RUN MODE - Simulating execution..." -ForegroundColor Yellow
    Write-Host "Script: $ScriptPath" -ForegroundColor Gray
    Write-Host "Arguments: $($Arguments -join ', ')" -ForegroundColor Gray

    # Simulation des opérations
    Write-Host "Would execute: $ScriptPath $($Arguments -join ' ')" -ForegroundColor Green

    # Validation des prérequis
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "❌ ERROR: Script not found: $ScriptPath" -ForegroundColor Red
        return $false
    }

    # Simulation des modifications
    Write-Host "Would modify files:" -ForegroundColor Cyan
    Write-Host "  - Configuration files" -ForegroundColor Gray
    Write-Host "  - Log files" -ForegroundColor Gray
    Write-Host "  - Service status" -ForegroundColor Gray

    Write-Host "✅ DRY-RUN completed - no changes made" -ForegroundColor Green
    return $true
}
```

### 6.4 Support et Escalade

#### Procédures d'Escalade Déploiement

```typescript
export class DeploymentEscalationManager {
  private static escalationLevels = {
    DEPLOYMENT_FAILURE: { priority: 'CRITICAL', delay: 0 },      // Immédiat
    TIMEOUT_CRITICAL: { priority: 'CRITICAL', delay: 0 },        // Immédiat
    PERMISSION_DENIED: { priority: 'HIGH', delay: 300000 },     // 5 minutes
    CONFIGURATION_ERROR: { priority: 'MEDIUM', delay: 600000 },   // 10 minutes
    PERFORMANCE_DEGRADATION: { priority: 'MEDIUM', delay: 600000 }  // 10 minutes
  };

  static async escalateDeploymentIssue(issue: string, details: any, level: string): Promise<void> {
    const config = this.escalationLevels[level];
    const logger = createLogger('DeploymentEscalationManager');

    logger.warn(`🚨 DEPLOYMENT ESCALATION: ${issue}`, {
      issue,
      level,
      priority: config.priority,
      details,
      timestamp: new Date().toISOString()
    });

    // Attendre délai pour éviter escalades multiples
    if (config.delay > 0) {
      await new Promise(resolve => setTimeout(resolve, config.delay));
    }

    // Envoyer notification selon infrastructure
    await this.sendDeploymentEscalationNotification(issue, details, level);
  }

  private static async sendDeploymentEscalationNotification(issue: string, details: any, level: string): Promise<void> {
    // Implémentation selon infrastructure :
    // - Alerting système monitoring
    // - Email administrateur déploiement
    // - Notification équipe DevOps
    // - Création ticket incident
    // - Integration avec système de tickets
  }
}
```

#### Procédures d'Escalade Logger

```typescript
// Système d'escalade automatique
export class EscalationManager {
  private static escalationLevels = {
    INFO: { threshold: 50, delay: 3600000 },    // 50 erreurs/heure, 1h délai
    WARN: { threshold: 20, delay: 1800000 },    // 20 warnings/heure, 30min délai
    ERROR: { threshold: 10, delay: 600000 }     // 10 erreurs/heure, 10min délai
  };

  static checkEscalation(level: string, count: number): void {
    const config = this.escalationLevels[level];
    if (count >= config.threshold) {
      this.triggerEscalation(level, count, config.delay);
    }
  }

  private static async triggerEscalation(level: string, count: number, delay: number): Promise<void> {
    const logger = createLogger('EscalationManager');

    logger.warn(`🚨 ESCALATION TRIGGERED: ${level} (${count} occurrences)`, {
      level,
      count,
      escalationTime: new Date().toISOString()
    });

    // Attendre délai pour éviter escalades multiples
    await new Promise(resolve => setTimeout(resolve, delay));

    // Envoyer notification selon infrastructure
    await this.sendNotification(level, count);
  }

  private static async sendNotification(level: string, count: number): Promise<void> {
    // Implémentation selon infrastructure :
    // - Email administrateur
    // - Slack/Teams notification
    // - Monitoring system alert
    // - Création ticket support
  }
}
```

#### Collecte d'Informations pour Support Logger

```bash
# Collecte complète d'informations pour support déploiement
SUPPORT_FILE="/tmp/roosync-deployment-support-$(date +%Y%m%d-%H%M%S).txt"

echo "=== ROOSYNC DEPLOYMENT SUPPORT INFO ===" > "$SUPPORT_FILE"
echo "Generated: $(date)" >> "$SUPPORT_FILE"
echo "" >> "$SUPPORT_FILE"

echo "Environment:" >> "$SUPPORT_FILE"
echo "  PowerShell version: $(powershell -Command '$PSVersionTable.PSVersion.Major.$PSVersionTable.PSVersion.Minor.$PSVersionTable.PSVersion.Revision' | Out-String)" >> "$SUPPORT_FILE"
echo "  Execution policy: $(Get-ExecutionPolicy | Select-Object ExecutionPolicy | Out-String)" >> "$SUPPORT_FILE"
echo "  OS: $(uname -a)" >> "$SUPPORT_FILE"
echo "  User: $(whoami)" >> "$SUPPORT_FILE"
echo "  Node.js: $(node --version)" >> "$SUPPORT_FILE"
echo "" >> "$SUPPORT_FILE"

echo "Deployment Configuration:" >> "$SUPPORT_FILE"
echo "  Config file: ${ROOSYNC_DEPLOYMENT_CONFIG:-'NOT SET'}" >> "$SUPPORT_FILE"
echo "  Script directory: ${ROOSYNC_SCRIPT_PATH:-'NOT SET'}" >> "$SUPPORT_FILE"
echo "  Log directory: ${ROOSYNC_DEPLOYMENT_LOGS:-'NOT SET'}" >> "$SUPPORT_FILE"
echo "" >> "$SUPPORT_FILE"

echo "Recent Deployment Activity:" >> "$SUPPORT_FILE"
if [ -f "$ROOSYNC_DEPLOYMENT_LOGS/deployment-$(date +%Y%m%d).log" ]; then
    echo "  Last 10 lines:" >> "$SUPPORT_FILE"
    tail -10 "$ROOSYNC_DEPLOYMENT_LOGS/deployment-$(date +%Y%m%d).log" >> "$SUPPORT_FILE"
else
    echo "  No deployment logs found" >> "$SUPPORT_FILE"
fi

echo "" >> "$SUPPORT_FILE"

echo "Recent Log Activity:" >> "$SUPPORT_FILE"
if [ -f "$ROOSYNC_SHARED_PATH/logs/roosync-$(date +%Y%m%d).log" ]; then
    echo "  Last 10 lines:" >> "$SUPPORT_FILE"
    tail -10 "$ROOSYNC_SHARED_PATH/logs/roosync-$(date +%Y%m%d).log" >> "$SUPPORT_FILE"
else
    echo "  No logs found" >> "$SUPPORT_FILE"
fi

echo "" >> "$SUPPORT_FILE"

echo "System Status:" >> "$SUPPORT_FILE"
echo "  PowerShell processes: $(ps aux | grep powershell | wc -l)" >> "$SUPPORT_FILE"
echo "  Memory usage: $(free -h | head -1)" >> "$SUPPORT_FILE"
echo "  Disk usage: $(df -h | head -1)" >> "$SUPPORT_FILE"

echo "=== END DEPLOYMENT SUPPORT INFO ===" >> "$SUPPORT_FILE"

echo "Support file created: $SUPPORT_FILE"
echo "Please send this file to deployment support team"
```

---

**Version du document** : 1.0
**Dernière mise à jour** : 2025-12-27

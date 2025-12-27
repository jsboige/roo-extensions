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
use_mcp_tool "roo-state-manager" "roosync_init" {
  "force": false,
  "createRoadmap": true
}

# Créer la baseline de référence
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
```

**Étape 5 : Première synchronisation**
```bash
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "source": "local_machine",
  "target": "remote_machine",
  "force_refresh": false
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

### 4.4 Gestion des Secrets et Normalisation (Nouveau Cycle 7)

**Normalisation des Chemins** :
Le service `ConfigNormalizationService` assure la portabilité entre Windows et Linux en normalisant les séparateurs de chemins et en utilisant des placeholders intelligents.

- **Chemins absolus** : Remplacés par `{{WORKSPACE_ROOT}}`, `{{USER_HOME}}`.
- **Variables d'environnement** : Préservation de `%APPDATA%`, `$HOME`.

**Masquage des Secrets** :
Les clés sensibles (apiKey, token, password) sont automatiquement détectées et masquées dans les configurations partagées.

- **Format** : `{{SECRET:nom_de_la_cle}}`
- **Détection** : Regex et entropie pour identifier les secrets.
- **Vault Local** : Les secrets réels sont stockés uniquement sur la machine locale et réinjectés lors de l'application.

**Recommandation** : Toujours utiliser des variables d'environnement pour les chemins (`ROOSYNC_SHARED_PATH`) et les secrets pour éviter les fuites dans la baseline.

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
  "target": "remote_machine",
  "force_refresh": false
}

# Lister les différences détectées
use_mcp_tool "roo-state-manager" "roosync_list_diffs" {}
```

**Gérer les décisions de synchronisation** :
```bash
# Voir les détails d'une décision
use_mcp_tool "roo-state-manager" "roosync_get_decision_details" {
  "decisionId": "uuid-de-la-decision",
  "includeHistory": true,
  "includeLogs": true
}

# Approuver une décision
use_mcp_tool "roo-state-manager" "roosync_approve_decision" {
  "decisionId": "uuid-de-la-decision",
  "comment": "Approuvé après vérification"
}

# Appliquer une décision approuvée
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decisionId": "uuid-de-la-decision",
  "dryRun": false,
  "force": false
}
```

**Partage de Configuration (Cycle 7)** :
```bash
# Collecter la configuration locale (génère un ZIP)
use_mcp_tool "roo-state-manager" "roosync_collect_config" {
  "targets": ["modes", "mcp"],
  "dryRun": false
}

# Publier la configuration vers la baseline
use_mcp_tool "roo-state-manager" "roosync_publish_config" {
  "packagePath": "path/to/config-package.zip",
  "version": "2.2.0",
  "description": "Description des changements"
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
  "decisionId": "uuid-de-la-decision",
  "includeHistory": true,
  "includeLogs": true
}
```

**2. Utiliser le mode dry-run** :
```bash
# Simuler avant d'appliquer
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decisionId": "uuid-de-la-decision",
  "dryRun": true,
  "force": false
}
```

**3. Garder un historique des décisions** :
```bash
# Lister les différences détectées
use_mcp_tool "roo-state-manager" "roosync_list_diffs" {
  "filterType": "all"
}

# Consulter le fichier sync-roadmap.md pour l'historique complet
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

const logger = createLogger('RooSyncService');
logger.info('This message will be visible in logs');
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

# Comparer les configurations
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "source": "local_machine",
  "target": "remote_machine"
}

# Lister les différences
use_mcp_tool "roo-state-manager" "roosync_list_diffs" {}

# Obtenir les détails d'une décision
use_mcp_tool "roo-state-manager" "roosync_get_decision_details" {
  "decisionId": "uuid-de-la-decision"
}

# Obtenir l'inventaire machine
use_mcp_tool "roo-state-manager" "roosync_get_machine_inventory" {}
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

### 5.6 Windows Task Scheduler

#### Vue d'ensemble

**Objectif** : Fournir un guide opérationnel complet pour la configuration du Windows Task Scheduler avec RooSync, incluant les permissions SYSTEM, les chemins de logs, et la surveillance des tâches.

**Périmètre** : Windows Task Scheduler v2.0+ avec permissions SYSTEM, intégration RooSync, et monitoring des tâches planifiées.

**Prérequis** :
- Windows 10/11 Pro ou Server 2019+
- PowerShell 5.1+ avec droits administrateur
- RooSync v2.1+ installé et configuré
- Permissions SYSTEM pour exécution des tâches
- Accès aux chemins de logs et configuration

**Cas d'usage typiques** :
- Configuration initiale du Task Scheduler pour RooSync
- Mise en place des permissions SYSTEM
- Configuration des chemins de logs et accès
- Planification des tâches de synchronisation
- Monitoring et dépannage des tâches planifiées

#### Configuration Task Scheduler

**Configuration par Défaut** :
```json
{
  "task_scheduler": {
    "task_name": "RooSync-Synchronization",
    "description": "RooSync automated synchronization task",
    "author": "Roo Code",
    "version": "2.1.0",
    "user": "SYSTEM",
    "execution_policy": {
      "powershell_execution_policy": "Bypass",
      "run_with_highest_privileges": true,
      "start_when_available": true,
      "stop_if_going_on_batteries": false,
      "wake_to_run": true
    },
    "trigger": {
      "type": "daily",
      "time": "02:00",
      "days_of_week": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
      "enabled": true
    },
    "settings": {
      "execution_time_limit": "PT2H",        // 2 heures maximum
      "restart_on_failure": true,
      "restart_interval": "PT5M",           // 5 minutes entre tentatives
      "multiple_instances": false,
      "delete_task_after": "P30D"           // 30 jours
    },
    "actions": {
      "primary_script": "sync_roo_environment.ps1",
      "arguments": ["-Mode", "Scheduled", "-LogLevel", "INFO"],
      "working_directory": "D:/roo-extensions/RooSync",
      "log_file": "scheduled-sync.log"
    }
  }
}
```

**Variables d'Environnement** :
```bash
# Configuration Task Scheduler RooSync
ROOSYNC_TASK_NAME="RooSync-Synchronization"
ROOSYNC_TASK_DESCRIPTION="RooSync automated synchronization task"
ROOSYNC_TASK_AUTHOR="Roo Code"
ROOSYNC_TASK_VERSION="2.1.0"

# Configuration utilisateur
ROOSYNC_TASK_USER="SYSTEM"
ROOSYNC_TASK_RUN_WITH_HIGHEST_PRIVILEGES=true

# Configuration PowerShell
ROOSYNC_POWERSHELL_EXECUTION_POLICY="Bypass"
ROOSYNC_POWERSHELL_START_WHEN_AVAILABLE=true
ROOSYNC_POWERSHELL_STOP_IF_GOING_ON_BATTERIES=false
ROOSYNC_POWERSHELL_WAKE_TO_RUN=true

# Configuration trigger
ROOSYNC_TRIGGER_TYPE="daily"
ROOSYNC_TRIGGER_TIME="02:00"
ROOSYNC_TRIGGER_DAYS_OF_WEEK="Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"
ROOSYNC_TRIGGER_ENABLED=true

# Configuration settings
ROOSYNC_EXECUTION_TIME_LIMIT="PT2H"
ROOSYNC_RESTART_ON_FAILURE=true
ROOSYNC_RESTART_INTERVAL="PT5M"
ROOSYNC_MULTIPLE_INSTANCES=false
ROOSYNC_DELETE_TASK_AFTER="P30D"

# Configuration actions
ROOSYNC_PRIMARY_SCRIPT="sync_roo_environment.ps1"
ROOSYNC_SCRIPT_ARGUMENTS="-Mode Scheduled -LogLevel INFO"
ROOSYNC_WORKING_DIRECTORY="D:/roo-extensions/RooSync"
ROOSYNC_LOG_FILE="scheduled-sync.log"
```

#### Déploiement Task Scheduler

**Étape 1 : Préparation Environnement Windows**
```powershell
# Vérifier prérequis Windows
Write-Host "=== WINDOWS ENVIRONMENT PREPARATION ===" -ForegroundColor Green

# Vérifier version Windows
$WindowsVersion = [System.Environment]::OSVersion.Version
Write-Host "Windows Version: $($WindowsVersion.Major).$($WindowsVersion.Minor).$($WindowsVersion.Build)" -ForegroundColor Cyan

# Vérifier PowerShell
$PowerShellVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $($PowerShellVersion.Major).$($PowerShellVersion.Minor).$($PowerShellVersion.Revision)" -ForegroundColor Cyan

# Vérifier droits administrateur
$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
$IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    Write-Host "✅ Running with administrator privileges" -ForegroundColor Green
} else {
    Write-Host "❌ Administrator privileges required" -ForegroundColor Red
    Write-Host "Please run this script as administrator" -ForegroundColor Yellow
    exit 1
}

# Vérifier module Task Scheduler
try {
    Import-Module ScheduledTasks -ErrorAction Stop
    Write-Host "✅ Task Scheduler module available" -ForegroundColor Green
} catch {
    Write-Host "❌ Task Scheduler module not available" -ForegroundColor Red
    Write-Host "Installing Task Scheduler module..." -ForegroundColor Yellow

    # Installation module si nécessaire
    Install-Module -Name ScheduledTasks -Force -Scope CurrentUser
    Import-Module ScheduledTasks
    Write-Host "✅ Task Scheduler module installed" -ForegroundColor Green
}
```

**Étape 2 : Configuration Permissions SYSTEM**
```powershell
# Configuration permissions SYSTEM pour RooSync
Write-Host "=== SYSTEM PERMISSIONS CONFIGURATION ===" -ForegroundColor Green

# Vérifier utilisateur SYSTEM
$SystemUser = "SYSTEM"
$SystemExists = Get-WmiObject -Class Win32_UserAccount | Where-Object { $_.Name -eq $SystemUser }

if ($SystemExists) {
    Write-Host "✅ SYSTEM user exists" -ForegroundColor Green
} else {
    Write-Host "❌ SYSTEM user not found" -ForegroundColor Red
    exit 1
}

# Configurer permissions pour répertoires RooSync
$RooSyncPaths = @(
    "D:/roo-extensions/RooSync",
    "D:/roo-extensions/RooSync/logs",
    "D:/roo-extensions/RooSync/.config",
    "D:/roo-extensions/RooSync/scheduled-tasks"
)

foreach ($Path in $RooSyncPaths) {
    if (-not (Test-Path $Path)) {
        Write-Host "Creating directory: $Path" -ForegroundColor Yellow
        New-Item -Path $Path -ItemType Directory -Force
    }

    try {
        # Donner permissions SYSTEM complètes
        $Acl = Get-Acl $Path
        $SystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $SystemUser,
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        $Acl.SetAccessRule($SystemAccessRule)
        Set-Acl $Path $Acl

        Write-Host "✅ SYSTEM permissions configured for: $Path" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to configure SYSTEM permissions for: $Path" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Vérifier permissions Task Scheduler
try {
    $TaskSchedulerService = Get-Service -Name Schedule
    if ($TaskSchedulerService.Status -eq "Running") {
        Write-Host "✅ Task Scheduler service running" -ForegroundColor Green
    } else {
        Write-Host "❌ Task Scheduler service not running" -ForegroundColor Red
        Write-Host "Starting Task Scheduler service..." -ForegroundColor Yellow
        Start-Service -Name Schedule -Force
        Write-Host "✅ Task Scheduler service started" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Failed to check Task Scheduler service" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
}
```

**Étape 3 : Configuration Chemins Logs**
```powershell
# Configuration des chemins de logs pour RooSync
Write-Host "=== LOG PATHS CONFIGURATION ===" -ForegroundColor Green

# Configuration variables d'environnement
$env:ROOSYNC_LOG_PATH = "D:/roo-extensions/RooSync/logs"
$env:ROOSYNC_TASK_LOG_PATH = "D:/roo-extensions/RooSync/logs/scheduled-tasks"
$env:ROOSYNC_ERROR_LOG_PATH = "D:/roo-extensions/RooSync/logs/errors"
$env:ROOSYNC_PERFORMANCE_LOG_PATH = "D:/roo-extensions/RooSync/logs/performance"

# Créer structure de répertoires de logs
$LogDirectories = @(
    $env:ROOSYNC_LOG_PATH,
    $env:ROOSYNC_TASK_LOG_PATH,
    $env:ROOSYNC_ERROR_LOG_PATH,
    $env:ROOSYNC_PERFORMANCE_LOG_PATH
)

foreach ($LogDir in $LogDirectories) {
    if (-not (Test-Path $LogDir)) {
        Write-Host "Creating log directory: $LogDir" -ForegroundColor Yellow
        New-Item -Path $LogDir -ItemType Directory -Force
    }

    # Configurer permissions SYSTEM pour logs
    try {
        $Acl = Get-Acl $LogDir
        $SystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "SYSTEM",
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        $Acl.SetAccessRule($SystemAccessRule)
        Set-Acl $LogDir $Acl

        Write-Host "✅ Log directory configured: $LogDir" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to configure log directory: $LogDir" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Configuration rotation des logs
$LogRetentionDays = 30
$MaxLogSizeMB = 100

Write-Host "Log retention: $LogRetentionDays days" -ForegroundColor Cyan
Write-Host "Max log size: $MaxLogSizeMB MB" -ForegroundColor Cyan
```

**Étape 4 : Création Tâche Planifiée**
```powershell
# Création de la tâche RooSync dans Task Scheduler
Write-Host "=== CREATING ROOSYNC SCHEDULED TASK ===" -ForegroundColor Green

# Configuration de la tâche
$TaskName = "RooSync-Synchronization"
$Description = "RooSync automated synchronization task"
$ScriptPath = "D:/roo-extensions/RooSync/sync_roo_environment.ps1"
$Arguments = @("-Mode", "Scheduled", "-LogLevel", "INFO", "-LogPath", "D:/roo-extensions/RooSync/logs/scheduled-sync.log")
$WorkingDirectory = "D:/roo-extensions/RooSync"

# Supprimer tâche existante
try {
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ExistingTask) {
        Write-Host "Removing existing task: $TaskName" -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "✅ Existing task removed" -ForegroundColor Green
    }
} catch {
    Write-Host "No existing task found" -ForegroundColor Gray
}

# Créer action PowerShell
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`" $($Arguments -join ' ')"

# Créer trigger quotidien à 02:00
$Trigger = New-ScheduledTaskTrigger -Daily -At 2AM

# Créer settings
$Settings = New-ScheduledTaskSettings
$Settings.StartWhenAvailable = $true
$Settings.StopIfGoingOnBatteries = $false
$Settings.DisallowStartIfOnBatteries = $false
$Settings.WakeToRun = $true
$Settings.ExecutionTimeLimit = "PT2H"  # 2 heures maximum
$Settings.RestartOnFailure = $true
$Settings.RestartInterval = "PT5M"  # 5 minutes entre tentatives
$Settings.AllowStartIfOnBatteries = $true
$Settings.DontStopIfGoingOnBatteries = $true
$Settings.MultipleInstances = $false

# Enregistrer la tâche avec utilisateur SYSTEM
try {
    Write-Host "Registering scheduled task..." -ForegroundColor Yellow
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -User "SYSTEM" -Description $Description -Force

    Write-Host "✅ Scheduled task created successfully" -ForegroundColor Green
    Write-Host "Task name: $TaskName" -ForegroundColor Cyan
    Write-Host "Trigger: Daily at 02:00 AM" -ForegroundColor Cyan
    Write-Host "User: SYSTEM" -ForegroundColor Cyan
    Write-Host "Script: $ScriptPath" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Failed to create scheduled task" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow

    # Tentative avec utilisateur courant si SYSTEM échoue
    try {
        Write-Host "Attempting with current user..." -ForegroundColor Yellow
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -User $env:USERNAME -Description $Description -Force
        Write-Host "✅ Task created with current user" -ForegroundColor Green
        Write-Host "⚠️ WARNING: SYSTEM privileges recommended" -ForegroundColor Yellow
    } catch {
        Write-Host "❌ Failed to create task with current user" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        exit 1
    }
}

# Vérifier la tâche créée
try {
    $CreatedTask = Get-ScheduledTask -TaskName $TaskName
    if ($CreatedTask) {
        Write-Host "✅ Task verification successful" -ForegroundColor Green
        Write-Host "Task state: $($CreatedTask.State)" -ForegroundColor Cyan
        Write-Host "Next run time: $($CreatedTask.NextRunTime)" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Task verification failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Failed to verify task" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}
```

#### Monitoring Task Scheduler

**Dashboard PowerShell** :
```powershell
# Dashboard de monitoring des tâches planifiées
function Show-RooSyncTaskDashboard {
    param(
        [Parameter()]
        [string]$TaskName = "RooSync-Synchronization",

        [Parameter()]
        [int]$RefreshInterval = 60
    )

    while ($true) {
        Clear-Host
        Write-Host "=== ROOSYNC TASK SCHEDULER DASHBOARD ===" -ForegroundColor Green
        Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
        Write-Host "Task: $TaskName" -ForegroundColor Cyan
        Write-Host ""

        try {
            # Statut de la tâche
            $Task = Get-ScheduledTask -TaskName $TaskName
            if ($Task) {
                Write-Host "Task Status:" -ForegroundColor Yellow
                Write-Host "  State: $($Task.State)" -ForegroundColor $(if ($Task.State -eq "Ready") { "Green" } elseif ($Task.State -eq "Running") { "Yellow" } else { "Red" })
                Write-Host "  Enabled: $($Task.Enabled)" -ForegroundColor $(if ($Task.Enabled) { "Green" } else { "Red" })
                Write-Host "  Last Run: $($Task.LastRunTime)" -ForegroundColor Gray
                Write-Host "  Next Run: $($Task.NextRunTime)" -ForegroundColor Gray
                Write-Host "  Last Result: $($Task.LastTaskResult)" -ForegroundColor $(if ($Task.LastTaskResult -eq 0) { "Green" } else { "Red" })
            } else {
                Write-Host "❌ Task not found" -ForegroundColor Red
            }

            Write-Host ""

            # Historique récent
            $TaskHistory = Get-ScheduledTaskInfo -TaskName $TaskName | Sort-Object StartDate -Descending | Select-Object -First 10
            if ($TaskHistory.Count -gt 0) {
                Write-Host "Recent History (Last 10 runs):" -ForegroundColor Yellow
                foreach ($History in $TaskHistory) {
                    $Result = if ($History.TaskResult -eq 0) { "✅ SUCCESS" } else { "❌ FAILED" }
                    $Duration = if ($History.RunDuration) { "$([math]::Round($History.RunDuration.TotalMinutes, 2)) min" } else { "N/A" }

                    Write-Host "  $($History.StartDate.ToString('yyyy-MM-dd HH:mm')) : $Result ($Duration)" -ForegroundColor Gray
                }
            } else {
                Write-Host "No task history found" -ForegroundColor Gray
            }

            Write-Host ""

            # Métriques de performance
            Write-Host "Performance Summary:" -ForegroundColor Yellow
            $TotalRuns = $TaskHistory.Count
            $SuccessfulRuns = ($TaskHistory | Where-Object { $_.TaskResult -eq 0 }).Count
            $FailedRuns = ($TaskHistory | Where-Object { $_.TaskResult -ne 0 }).Count

            if ($TotalRuns -gt 0) {
                $SuccessRate = [math]::Round(($SuccessfulRuns / $TotalRuns) * 100, 2)
                Write-Host "  Total Runs: $TotalRuns" -ForegroundColor Gray
                Write-Host "  Successful: $SuccessfulRuns" -ForegroundColor Green
                Write-Host "  Failed: $FailedRuns" -ForegroundColor Red
                Write-Host "  Success Rate: $SuccessRate%" -ForegroundColor $(if ($SuccessRate -ge 90) { "Green" } elseif ($SuccessRate -ge 70) { "Yellow" } else { "Red" })
            } else {
                Write-Host "No performance data available" -ForegroundColor Gray
            }

        } catch {
            Write-Host "❌ Failed to load dashboard data" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Press Ctrl+C to exit. Refreshing in $RefreshInterval seconds..." -ForegroundColor Gray

        try {
            Start-Sleep -Seconds $RefreshInterval
        } catch {
            # Gérer interruption Ctrl+C
            Write-Host "`nDashboard stopped by user" -ForegroundColor Yellow
            break
        }
    }
}

# Lancer le dashboard
Show-RooSyncTaskDashboard -TaskName "RooSync-Synchronization" -RefreshInterval 60
```

#### Maintenance Task Scheduler

**Maintenance des Tâches Planifiées** :
```powershell
# Script de maintenance des tâches planifiées
function Invoke-RooSyncTaskMaintenance {
    param(
        [Parameter()]
        [string]$TaskName = "RooSync-Synchronization",

        [Parameter()]
        [switch]$Cleanup = $false,

        [Parameter()]
        [switch]$Optimize = $false,

        [Parameter()]
        [switch]$Validate = $false
    )

    Write-Host "=== ROOSYNC TASK MAINTENANCE ===" -ForegroundColor Green
    Write-Host "Task: $TaskName" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
    Write-Host ""

    try {
        # Validation de la tâche
        if ($Validate) {
            Write-Host "Validating task configuration..." -ForegroundColor Yellow
            $Task = Get-ScheduledTask -TaskName $TaskName
            if ($Task) {
                Write-Host "✅ Task found and valid" -ForegroundColor Green
                Write-Host "State: $($Task.State)" -ForegroundColor Gray
                Write-Host "Enabled: $($Task.Enabled)" -ForegroundColor Gray
            } else {
                Write-Host "❌ Task not found" -ForegroundColor Red
            }
        }

        # Nettoyage des logs
        if ($Cleanup) {
            Write-Host "Cleaning up task logs..." -ForegroundColor Yellow
            $LogPaths = @(
                "D:/roo-extensions/RooSync/logs/scheduled-tasks",
                "D:/roo-extensions/RooSync/logs/performance",
                "D:/roo-extensions/RooSync/logs/errors"
            )

            $RetentionDays = 30
            $MaxSizeMB = 100

            foreach ($LogPath in $LogPaths) {
                if (Test-Path $LogPath) {
                    Write-Host "Cleaning logs in: $LogPath" -ForegroundColor Gray

                    # Supprimer anciens logs
                    Get-ChildItem -Path $LogPath -Filter "*.log" -Recurse |
                        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
                        Remove-Item -Force -Recurse

                    # Supprimer logs trop volumineux
                    Get-ChildItem -Path $LogPath -Filter "*.log" -Recurse |
                        Where-Object { $_.Length -gt ($MaxSizeMB * 1MB) } |
                        Remove-Item -Force -Recurse

                    Write-Host "✅ Log cleanup completed for: $LogPath" -ForegroundColor Green
                }
            }

            Write-Host "✅ Log cleanup completed" -ForegroundColor Green
        }

        # Maintenance automatique
        if (-not $Validate -and -not $Optimize -and -not $Cleanup) {
            Write-Host "Running automatic maintenance..." -ForegroundColor Yellow

            # Validation
            $Task = Get-ScheduledTask -TaskName $TaskName
            if ($Task) {
                Write-Host "✅ Task validation successful" -ForegroundColor Green
            } else {
                Write-Host "❌ Task validation failed" -ForegroundColor Red
            }

            # Nettoyage
            Write-Host "✅ Automatic maintenance completed" -ForegroundColor Green
        }

    } catch {
        Write-Host "❌ Task maintenance failed" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
```

#### Dépannage Task Scheduler

**Problème : Permissions SYSTEM Non Configurées**

**Symptôme** : Erreur "Access denied" lors de l'exécution des tâches

**Diagnostic** :
```powershell
# Vérifier permissions SYSTEM
$SystemUser = "SYSTEM"
$SystemSid = (New-Object System.Security.Principal.SecurityIdentifier($SystemUser)).Value

$CriticalPaths = @(
    "D:/roo-extensions/RooSync",
    "D:/roo-extensions/RooSync/logs",
    "D:/roo-extensions/RooSync/.config"
)

foreach ($Path in $CriticalPaths) {
    if (Test-Path $Path) {
        $Acl = Get-Acl $Path
        $SystemAccess = $Acl.Access | Where-Object { $_.IdentityReference -eq $SystemSid }

        if ($SystemAccess) {
            $HasFullControl = $SystemAccess | Where-Object { $_.FileSystemRights -eq "FullControl" }
            if ($HasFullControl) {
                Write-Host "✅ SYSTEM full control: $Path" -ForegroundColor Green
            } else {
                Write-Host "❌ SYSTEM limited access: $Path" -ForegroundColor Red
                Write-Host "Current rights: $($SystemAccess.FileSystemRights)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ SYSTEM no access: $Path" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Path not found: $Path" -ForegroundColor Red
    }
}
```

**Solution** :
```powershell
# Configuration complète des permissions SYSTEM
function Set-RooSyncSystemPermissions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RooSyncPath
    )

    $SystemUser = "SYSTEM"
    $SystemSid = (New-Object System.Security.Principal.SecurityIdentifier($SystemUser)).Value

    # Répertoires à configurer
    $Directories = @(
        $RooSyncPath,
        Join-Path $RooSyncPath "logs",
        Join-Path $RooSyncPath ".config",
        Join-Path $RooSyncPath "scheduled-tasks"
    )

    foreach ($Directory in $Directories) {
        # Créer répertoire si nécessaire
        if (-not (Test-Path $Directory)) {
            New-Item -Path $Directory -ItemType Directory -Force
            Write-Host "Created directory: $Directory" -ForegroundColor Yellow
        }

        # Configurer permissions SYSTEM complètes
        try {
            $Acl = Get-Acl $Directory
            $SystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $SystemSid,
                "FullControl",
                "ContainerInherit,ObjectInherit",
                "None",
                "Allow"
            )
            $Acl.SetAccessRule($SystemAccessRule)
            Set-Acl $Directory $Acl

            Write-Host "✅ SYSTEM permissions configured: $Directory" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to configure SYSTEM permissions: $Directory" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Utilisation
Set-RooSyncSystemPermissions -RooSyncPath "D:/roo-extensions/RooSync"
```

**Problème : Tâche Non Démarrée**

**Symptôme** : La tâche planifiée ne démarre pas automatiquement

**Diagnostic** :
```powershell
# Diagnostic complet de tâche non démarrée
function Diagnose-RooSyncTaskNotStarting {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName = "RooSync-Synchronization"
    )

    Write-Host "=== DIAGNOSING TASK NOT STARTING ===" -ForegroundColor Green
    Write-Host "Task: $TaskName" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
    Write-Host ""

    try {
        # Vérifier état de la tâche
        $Task = Get-ScheduledTask -TaskName $TaskName
        if (-not $Task) {
            Write-Host "❌ Task not found" -ForegroundColor Red
            return
        }

        Write-Host "Task Status:" -ForegroundColor Yellow
        Write-Host "  State: $($Task.State)" -ForegroundColor $(if ($Task.State -eq "Ready") { "Green" } elseif ($Task.State -eq "Running") { "Yellow" } else { "Red" })
        Write-Host "  Enabled: $($Task.Enabled)" -ForegroundColor $(if ($Task.Enabled) { "Green" } else { "Red" })
        Write-Host "  Last Run: $($Task.LastRunTime)" -ForegroundColor Gray
        Write-Host "  Next Run: $($Task.NextRunTime)" -ForegroundColor Gray
        Write-Host "  Last Result: $($Task.LastTaskResult)" -ForegroundColor $(if ($Task.LastTaskResult -eq 0) { "Green" } else { "Red" })

        Write-Host ""

        # Vérifier trigger
        if ($Task.Triggers) {
            $Trigger = $Task.Triggers | Select-Object -First 1
            Write-Host "Trigger Configuration:" -ForegroundColor Yellow
            Write-Host "  Type: $($Trigger.Type)" -ForegroundColor Gray
            Write-Host "  Enabled: $($Trigger.Enabled)" -ForegroundColor $(if ($Trigger.Enabled) { "Green" } else { "Red" })

            if ($Trigger.Type -eq "Daily") {
                Write-Host "  Time: $($Trigger.StartBoundary)" -ForegroundColor Gray
            } elseif ($Trigger.Type -eq "Weekly") {
                Write-Host "  Days: $($Trigger.DaysOfWeek)" -ForegroundColor Gray
                Write-Host "  Time: $($Trigger.StartBoundary)" -ForegroundColor Gray
            }
        } else {
            Write-Host "❌ No trigger configured" -ForegroundColor Red
        }

        Write-Host ""

        # Vérifier action
        if ($Task.Actions) {
            $Action = $Task.Actions | Select-Object -First 1
            Write-Host "Action Configuration:" -ForegroundColor Yellow
            Write-Host "  Execute: $($Action.Execute)" -ForegroundColor Gray
            Write-Host "  Arguments: $($Action.Arguments)" -ForegroundColor Gray
            Write-Host "  Working Directory: $($Action.WorkingDirectory)" -ForegroundColor Gray
        } else {
            Write-Host "❌ No action configured" -ForegroundColor Red
        }

        Write-Host ""

        # Vérifier service Task Scheduler
        $TaskSchedulerService = Get-Service -Name Schedule
        Write-Host "Task Scheduler Service:" -ForegroundColor Yellow
        Write-Host "  Status: $($TaskSchedulerService.Status)" -ForegroundColor $(if ($TaskSchedulerService.Status -eq "Running") { "Green" } else { "Red" })
        Write-Host "  Start Type: $($TaskSchedulerService.StartType)" -ForegroundColor Gray
        Write-Host "  Can Start: $($TaskSchedulerService.CanStart)" -ForegroundColor $(if ($TaskSchedulerService.CanStart) { "Green" } else { "Red" })

    } catch {
        Write-Host "❌ Diagnosis failed" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
```

**Solution** :
```powershell
# Réparation complète de tâche non démarrée
function Repair-RooSyncTaskNotStarting {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName = "RooSync-Synchronization"
    )

    Write-Host "=== REPAIRING TASK NOT STARTING ===" -ForegroundColor Green

    try {
        # 1. Redémarrer service Task Scheduler
        Write-Host "Restarting Task Scheduler service..." -ForegroundColor Yellow
        Restart-Service -Name Schedule -Force
        Start-Sleep -Seconds 10

        $TaskSchedulerService = Get-Service -Name Schedule
        if ($TaskSchedulerService.Status -eq "Running") {
            Write-Host "✅ Task Scheduler service restarted" -ForegroundColor Green
        } else {
            Write-Host "❌ Task Scheduler service still not running" -ForegroundColor Red
            return
        }

        # 2. Recréer la tâche
        Write-Host "Recreating scheduled task..." -ForegroundColor Yellow
        $ScriptPath = "D:/roo-extensions/RooSync/sync_roo_environment.ps1"
        $Arguments = @("-Mode", "Scheduled", "-LogLevel", "INFO")

        # Supprimer tâche existante
        try {
            $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($ExistingTask) {
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
                Write-Host "Removed existing task: $TaskName" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "No existing task to remove" -ForegroundColor Gray
        }

        # Créer nouvelle tâche
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`" $($Arguments -join ' ')"
        $Trigger = New-ScheduledTaskTrigger -Daily -At 2AM
        $Settings = New-ScheduledTaskSettings
        $Settings.StartWhenAvailable = $true
        $Settings.StopIfGoingOnBatteries = $false
        $Settings.WakeToRun = $true
        $Settings.ExecutionTimeLimit = "PT2H"
        $Settings.RestartOnFailure = $true
        $Settings.RestartInterval = "PT5M"

        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -User "SYSTEM" -Description "RooSync automated synchronization task" -Force
        Write-Host "✅ Task recreated successfully" -ForegroundColor Green

        # 3. Valider la réparation
        Write-Host "Validating repair..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5

        $RepairedTask = Get-ScheduledTask -TaskName $TaskName
        if ($RepairedTask -and $RepairedTask.State -eq "Ready" -and $RepairedTask.Enabled) {
            Write-Host "✅ Task repair completed successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Task repair failed" -ForegroundColor Red
        }

    } catch {
        Write-Host "❌ Task repair failed" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
```

**Problème : Logs Non Accessibles**

**Symptôme** : Erreur "Log file not accessible" ou "Cannot write to log file"

**Diagnostic** :
```powershell
# Diagnostic accès aux logs
function Test-RooSyncLogAccess {
    param(
        [Parameter()]
        [string]$LogPath = "D:/roo-extensions/RooSync/logs"
    )

    Write-Host "=== TESTING LOG ACCESS ===" -ForegroundColor Green
    Write-Host "Log path: $LogPath" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
    Write-Host ""

    # Test création répertoire
    if (-not (Test-Path $LogPath)) {
        try {
            New-Item -Path $LogPath -ItemType Directory -Force
            Write-Host "✅ Log directory created: $LogPath" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to create log directory: $LogPath" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
            return
        }
    }

    # Test écriture fichier
    try {
        $TestFile = Join-Path $LogPath "access-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        "Log access test - $(Get-Date)" | Out-File -FilePath $TestFile -Encoding UTF8

        if (Test-Path $TestFile) {
            Write-Host "✅ Write access: SUCCESS" -ForegroundColor Green
            Remove-Item $TestFile -Force
        } else {
            Write-Host "❌ Write access: FAILED" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Write access test FAILED" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Test permissions
    try {
        $Acl = Get-Acl $LogPath
        $SystemAccess = $Acl.Access | Where-Object { $_.IdentityReference -eq "SYSTEM" }

        if ($SystemAccess) {
            $HasWriteAccess = $SystemAccess | Where-Object { $_.FileSystemRights -band "Write" }
            if ($HasWriteAccess) {
                Write-Host "✅ SYSTEM write access: CONFIGURED" -ForegroundColor Green
            } else {
                Write-Host "❌ SYSTEM write access: NOT CONFIGURED" -ForegroundColor Red
                Write-Host "Current rights: $($SystemAccess.FileSystemRights)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ SYSTEM access: NOT CONFIGURED" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Permissions check FAILED" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Test espace disque
    try {
        $Drive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "D:" }
        if ($Drive) {
            $FreeSpaceGB = [math]::Round($Drive.FreeSpace / 1GB, 2)
            $TotalSpaceGB = [math]::Round($Drive.Size / 1GB, 2)
            $UsedSpaceGB = $TotalSpaceGB - $FreeSpaceGB
            $UsagePercent = [math]::Round(($UsedSpaceGB / $TotalSpaceGB) * 100, 2)

            Write-Host "Disk Space Analysis:" -ForegroundColor Yellow
            Write-Host "  Total: $TotalSpaceGB GB" -ForegroundColor Gray
            Write-Host "  Used: $UsedSpaceGB GB ($UsagePercent%)" -ForegroundColor $(if ($UsagePercent -lt 80) { "Green" } elseif ($UsagePercent -lt 90) { "Yellow" } else { "Red" })
            Write-Host "  Free: $FreeSpaceGB GB" -ForegroundColor $(if ($FreeSpaceGB -gt 10) { "Green" } elseif ($FreeSpaceGB -gt 5) { "Yellow" } else { "Red" })
        } else {
            Write-Host "❌ Drive D: not found" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Disk space analysis failed" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
```

**Solution** :
```powershell
# Réparation accès aux logs
function Repair-RooSyncLogAccess {
    param(
        [Parameter()]
        [string]$LogPath = "D:/roo-extensions/RooSync/logs"
    )

    Write-Host "=== REPAIRING LOG ACCESS ===" -ForegroundColor Green

    try {
        # 1. Recréer structure de répertoires
        $LogDirectories = @(
            $LogPath,
            Join-Path $LogPath "scheduled-tasks",
            Join-Path $LogPath "performance",
            Join-Path $LogPath "errors"
        )

        foreach ($Directory in $LogDirectories) {
            # Supprimer et recréer répertoire
            if (Test-Path $Directory) {
                Write-Host "Removing corrupted directory: $Directory" -ForegroundColor Yellow
                Remove-Item $Directory -Recurse -Force
            }

            New-Item -Path $Directory -ItemType Directory -Force
            Write-Host "✅ Recreated directory: $Directory" -ForegroundColor Green
        }

        # 2. Configurer permissions SYSTEM
        $SystemSid = (New-Object System.Security.Principal.SecurityIdentifier("SYSTEM")).Value

        foreach ($Directory in $LogDirectories) {
            try {
                $Acl = Get-Acl $Directory
                $SystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $SystemSid,
                    "FullControl",
                    "ContainerInherit,ObjectInherit",
                    "None",
                    "Allow"
                )
                $Acl.SetAccessRule($SystemAccessRule)
                Set-Acl $Directory $Acl

                Write-Host "✅ SYSTEM permissions configured: $Directory" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to configure SYSTEM permissions: $Directory" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # 3. Tester accès
        Write-Host "Testing log access..." -ForegroundColor Yellow
        $TestFile = Join-Path $LogPath "repair-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        "Log access repair test - $(Get-Date)" | Out-File -FilePath $TestFile -Encoding UTF8

        if (Test-Path $TestFile) {
            Remove-Item $TestFile -Force
            Write-Host "✅ Log access repair completed successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Log access repair failed" -ForegroundColor Red
        }

    } catch {
        Write-Host "❌ Log access repair failed" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
```

---

**Version du document** : 1.0
**Dernière mise à jour** : 2025-12-27

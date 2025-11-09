# Guide d'Utilisation Complet - RooSync v2.1.0

**Version :** 2.1.0 (Baseline-Driven)  
**Date :** 2025-11-03  
**Statut :** Production avec Limitations  

---

## 📋 Table des Matières

1. [Vue d'Ensemble](#1-vue-densemble)
2. [Installation et Configuration](#2-installation-et-configuration)
3. [Concepts Clés](#3-concepts-clés)
4. [Workflow Principal](#4-workflow-principal)
5. [Outils MCP Disponibles](#5-outils-mcp-disponibles)
6. [Cas d'Usage](#6-cas-dusage)
7. [Dépannage](#7-dépannage)
8. [Bonnes Pratiques](#8-bonnes-pratiques)

---

## 1. Vue d'Ensemble

### 🎯 Mission de RooSync

RooSync est un système de synchronisation **baseline-driven** qui permet de :

- **🎯 Comparer** chaque machine avec une configuration de référence (baseline)
- **👤 Valider** humainement les changements critiques via une interface Markdown
- **🔄 Appliquer** seulement les décisions approuvées par l'utilisateur
- **📊 Tracer** toutes les opérations dans un roadmap interactif
- **🔒 Garantir** la cohérence avec une source de vérité unique

### 🏗️ Architecture Baseline-Driven

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Machine A     │───▶│  Baseline Service │───▶│  sync-config.ref   │
│   (Locale)      │    │   (Comparaison)  │    │   (Référence)     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
          │                        │                          │
          ▼                        ▼                          ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Machine B     │───▶│  Diff Detector   │───▶│  sync-roadmap.md  │
│   (Cible)       │    │   (Détection)    │    │  (Validation)     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
          │                        │                          │
          ▼                        ▼                          ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Machine C     │───▶│ Decision Engine  │───▶│  sync-dashboard   │
│   (Autre)       │    │ (Validation)     │    │   (Suivi)        │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

---

## 2. Installation et Configuration

### 📋 Prérequis

**Système :**
- Windows 10/11 (x64)
- PowerShell 5.1+ ou PowerShell Core 7+
- Node.js 18+ (pour serveurs MCP)

**Stockage :**
- Google Drive (ou équivalent) synchronisé
- Accès lecture/écriture au répertoire partagé

**Logiciel :**
- VSCode avec extension Roo
- Serveur MCP roo-state-manager compilé

### ⚙️ Configuration Initiale

#### 2.1 Variables d'Environnement

Créer un fichier `.env` à la racine du projet :

```bash
# Configuration RooSync v2.1
ROOSYNC_SHARED_PATH="G:\Mon Drive\Synchronisation\RooSync\.shared-state"
ROOSYNC_MACHINE_ID="votre-machine-id"
ROOSYNC_AUTO_SYNC=false
ROOSYNC_CONFLICT_STRATEGY=manual
ROOSYNC_LOG_LEVEL=info
```

#### 2.2 Initialisation de l'Espace de Travail

```bash
# Initialiser l'infrastructure RooSync
use_mcp_tool "roo-state-manager" "roosync_init" {
  "force": false,
  "createRoadmap": true
}
```

#### 2.3 Vérification de l'Installation

```bash
# Vérifier l'état du système
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
```

---

## 3. Concepts Clés

### 📊 Baseline

La **baseline** est la configuration de référence partagée entre toutes les machines.

**Fichier :** `sync-config.ref.json`  
**Emplacement :** Stockage partagé (Google Drive)  
**Propriétaire :** Personne (partagée)  
**Contenu :**
- Configurations machines validées
- Modes Roo standards
- Serveurs MCP approuvés
- Spécifications SDDD

### 🗺️ Roadmap

La **roadmap** est l'interface de validation des changements.

**Fichier :** `sync-roadmap.md`  
**Format :** Markdown avec marqueurs HTML  
**Fonction :**
- Liste des décisions en attente
- Interface de validation humaine
- Historique des changements appliqués

### 📋 Décision

Une **décision** représente un changement à synchroniser.

**Structure :**
```markdown
<!-- DECISION_BLOCK_START -->
**ID:** uuid-unique
**Titre:** Description du changement
**Statut:** pending | approved | rejected | applied
**Type:** config | setting | announcement
**Machine Source:** machine-source
**Machines Cibles:** machine1, machine2
**Créé:** timestamp-ISO

**Description:**
Détails du changement...

**Détails Techniques:**
Informations techniques...

**Actions:**
- [ ] **Approuver & Fusionner**
<!-- DECISION_BLOCK_END -->
```

---

## 4. Workflow Principal

### 🔄 Cycle de Synchronisation

#### Phase 1 : Détection des Différences

```bash
# Comparer avec la baseline
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "targetMachine": "baseline"
}
```

**Résultat :**
- Décisions créées dans `sync-roadmap.md`
- Différences classées par sévérité
- Contexte système enrichi

#### Phase 2 : Validation Humaine

1. **Ouvrir la roadmap :**
   ```bash
   # Éditer le fichier de roadmap
   notepad "${ROOSYNC_SHARED_PATH}/sync-roadmap.md"
   ```

2. **Examiner les décisions :**
   - Lire les descriptions des changements
   - Vérifier les détails techniques
   - Évaluer l'impact

3. **Approuver ou rejeter :**
   ```markdown
   # Pour approuver
   - [x] **Approuver & Fusionner**
   
   # Pour rejeter (laisser décoché)
   - [ ] **Approuver & Fusionner**
   ```

#### Phase 3 : Application des Changements

```bash
# Appliquer une décision approuvée
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decisionId": "uuid-de-la-décision",
  "dryRun": false
}
```

**Options :**
- `dryRun: true` - Simulation sans modification
- `dryRun: false` - Application réelle

---

## 5. Outils MCP Disponibles

### 📊 État et Surveillance

#### `roosync_get_status`

**Description :** Obtenir l'état global de synchronisation

**Usage :**
```bash
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
```

**Résultat :**
```json
{
  "status": "synced",
  "lastSync": "2025-11-03T22:51:35.586Z",
  "machines": [...],
  "summary": {
    "totalMachines": 3,
    "onlineMachines": 2,
    "totalDiffs": 0,
    "totalPendingDecisions": 0
  }
}
```

#### `roosync_list_diffs`

**Description :** Lister les différences détectées

**Usage :**
```bash
use_mcp_tool "roo-state-manager" "roosync_list_diffs" {
  "filterType": "all"  // all | config | setting | announcement
}
```

### 🔍 Comparaison et Analyse

#### `roosync_compare_config`

**Description :** Comparer les configurations entre machines

**Usage :**
```bash
# Comparer avec la baseline
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "targetMachine": "baseline"
}

# Comparer avec une autre machine
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "targetMachine": "myia-po-2024"
}
```

#### `roosync_get_decision_details`

**Description :** Obtenir les détails d'une décision spécifique

**Usage :**
```bash
use_mcp_tool "roo-state-manager" "roosync_get_decision_details" {
  "decisionId": "uuid-de-la-décision"
}
```

### ✅ Gestion des Décisions

#### `roosync_approve_decision`

**Description :** Approuver une décision en attente

**Usage :**
```bash
use_mcp_tool "roo-state-manager" "roosync_approve_decision" {
  "decisionId": "uuid-de-la-décision",
  "comment": "Raison de l'approbation"
}
```

#### `roosync_reject_decision`

**Description :** Rejeter une décision avec motif

**Usage :**
```bash
use_mcp_tool "roo-state-manager" "roosync_reject_decision" {
  "decisionId": "uuid-de-la-décision",
  "reason": "Raison du rejet"
}
```

#### `roosync_apply_decision`

**Description :** Appliquer une décision approuvée

**Usage :**
```bash
# Mode simulation (recommandé)
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decisionId": "uuid-de-la-décision",
  "dryRun": true
}

# Application réelle
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decisionId": "uuid-de-la-décision",
  "dryRun": false
}
```

#### `roosync_rollback_decision`

**Description :** Annuler une décision appliquée

**Usage :**
```bash
use_mcp_tool "roo-state-manager" "roosync_rollback_decision" {
  "decisionId": "uuid-de-la-décision",
  "reason": "Raison du rollback"
}
```

### 🔧 Administration

#### `roosync_init`

**Description :** Initialiser l'infrastructure RooSync

**Usage :**
```bash
use_mcp_tool "roo-state-manager" "roosync_init" {
  "force": false,
  "createRoadmap": true
}
```

---

## 6. Cas d'Usage

### 🚀 Première Configuration

**Scénario :** Nouvelle machine à intégrer

**Étapes :**
1. **Installer RooSync** sur la nouvelle machine
2. **Configurer les variables** d'environnement
3. **Initialiser l'espace** de travail
4. **Comparer avec la baseline** pour détecter les différences
5. **Valider les décisions** dans la roadmap
6. **Appliquer les changements** approuvés

```bash
# Workflow complet pour nouvelle machine
use_mcp_tool "roo-state-manager" "roosync_init" {
  "force": false,
  "createRoadmap": true
}

use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "targetMachine": "baseline"
}

# Éditer la roadmap et approuver les décisions
# notepad "${ROOSYNC_SHARED_PATH}/sync-roadmap.md"

# Appliquer les décisions approuvées
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decisionId": "uuid-décision",
  "dryRun": false
}
```

### 🔄 Synchronisation Quotidienne

**Scénario :** Vérification régulière de cohérence

**Étapes :**
1. **Vérifier l'état** global
2. **Détecter les différences** récentes
3. **Valider les changements** si nécessaire
4. **Appliquer les décisions** approuvées

```bash
# Workflow quotidien
use_mcp_tool "roo-state-manager" "roosync_get_status" {}

use_mcp_tool "roo-state-manager" "roosync_list_diffs" {
  "filterType": "all"
}

# Si des différences existent :
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "targetMachine": "baseline"
}
```

### 🐛 Dépannage

**Scénario :** Problème de synchronisation

**Étapes :**
1. **Vérifier l'état** du système
2. **Examiner les décisions** en attente
3. **Analyser les différences** détectées
4. **Corriger les problèmes** identifiés

```bash
# Workflow de dépannage
use_mcp_tool "roo-state-manager" "roosync_get_status" {}

use_mcp_tool "roo-state-manager" "roosync_list_diffs" {
  "filterType": "all"
}

# Examiner une décision problématique
use_mcp_tool "roo-state-manager" "roosync_get_decision_details" {
  "decisionId": "uuid-problématique"
}
```

---

## 7. Dépannage

### ⚠️ Problèmes Courants

#### 7.1 "Décision pas encore approuvée"

**Symptôme :** `roosync_apply_decision` échoue avec "Décision pas encore approuvée"

**Causes possibles :**
- Incohérence statut/historique (bug connu)
- Décision récemment approuvée (délai de synchronisation)

**Solutions :**
1. **Vérifier les détails** de la décision
2. **Attendre quelques secondes** et réessayer
3. **Forcer la synchronisation** du stockage partagé

```bash
# Diagnostic
use_mcp_tool "roo-state-manager" "roosync_get_decision_details" {
  "decisionId": "uuid-problématique"
}

# Solution : attendre et réessayer
Start-Sleep -Seconds 5
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decisionId": "uuid-problématique",
  "dryRun": false
}
```

#### 7.2 "Fichier de configuration introuvable"

**Symptôme :** Erreur de fichier non trouvé

**Causes possibles :**
- Chemin `ROOSYNC_SHARED_PATH` incorrect
- Google Drive non synchronisé
- Permissions insuffisantes

**Solutions :**
1. **Vérifier le chemin** dans `.env`
2. **Synchroniser manuellement** Google Drive
3. **Vérifier les permissions** du dossier

```bash
# Vérification
Test-Path $env:ROOSYNC_SHARED_PATH
Get-ChildItem $env:ROOSYNC_SHARED_PATH

# Correction
$env:ROOSYNC_SHARED_PATH = "G:\Mon Drive\Synchronisation\RooSync\.shared-state"
```

#### 7.3 Différences en Double

**Symptôme :** Plusieurs décisions identiques dans la roadmap

**Causes possibles :**
- Exécutions multiples de la détection
- Données corrompues historiquement

**Solutions :**
1. **Nettoyer manuellement** la roadmap
2. **Supprimer les doublons** en conservant le plus récent
3. **Réinitialiser** la roadmap si nécessaire

```bash
# Nettoyage manuel
notepad "${ROOSYNC_SHARED_PATH}/sync-roadmap.md"
# Supprimer les blocs DECISION_BLOCK en double
```

### 🔧 Outils de Diagnostic

#### 7.4 Vérification Complète

```bash
# Diagnostic complet du système
use_mcp_tool "roo-state-manager" "roosync_get_status" {}

use_mcp_tool "roo-state-manager" "roosync_list_diffs" {
  "filterType": "all"
}

# Vérification des fichiers critiques
Test-Path "${ROOSYNC_SHARED_PATH}/sync-config.ref.json"
Test-Path "${ROOSYNC_SHARED_PATH}/sync-roadmap.md"
Test-Path "${ROOSYNC_SHARED_PATH}/sync-dashboard.json"
```

#### 7.5 Validation de Configuration

```bash
# Comparer avec baseline
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "targetMachine": "baseline"
}

# Comparer avec autre machine
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "targetMachine": "myia-po-2024"
}
```

---

## 8. Bonnes Pratiques

### 🎯 Recommandations d'Usage

#### 8.1 Fréquence de Synchronisation

**Quotidienne :**
- Vérification de l'état global
- Détection des différences récentes

**Hebdomadaire :**
- Validation complète des décisions
- Nettoyage des décisions anciennes

**Mensuelle :**
- Révision de la baseline
- Mise à jour des configurations standards

#### 8.2 Gestion des Décisions

**Avant d'approuver :**
- Lire attentivement la description
- Vérifier les détails techniques
- Évaluer l'impact sur les autres machines

**Après approbation :**
- Toujours utiliser `dryRun: true` en premier
- Vérifier le résultat de la simulation
- Appliquer seulement après validation

#### 8.3 Sécurité

**Principes :**
- Ne jamais approuver une décision non comprise
- Vérifier toujours la source des changements
- Conserver un historique des décisions importantes

**Backup :**
- Sauvegarder régulièrement la baseline
- Conserver les versions précédentes
- Documenter les changements majeurs

### 📊 Monitoring

#### 8.4 Indicateurs Clés

**Santé du système :**
- Nombre de décisions en attente
- Âge des décisions non traitées
- Fréquence des synchronisations

**Performance :**
- Temps de détection des différences
- Temps d'application des décisions
- Taux de réussite des synchronisations

#### 8.5 Alertes

**Alertes critiques :**
- Plus de 10 décisions en attente
- Décisions en attente > 7 jours
- Échec d'application de décision

**Alertes warnings :**
- Machine offline > 24h
- Différences hardware critiques
- Baseline non mise à jour > 30 jours

---

## 🎯 Conclusion

RooSync v2.1.0 est un système puissant de synchronisation baseline-driven qui permet de maintenir la cohérence des configurations entre plusieurs machines de développement.

### Points Clés à Retenir

1. **Toujours valider** avant d'appliquer les changements
2. **Utiliser le mode dry-run** pour les tests
3. **Surveiller régulièrement** l'état du système
4. **Documenter** les décisions importantes
5. **Maintenir la baseline** à jour

### Évolution Future

Le système continue d'évoluer avec :
- Gestion améliorée de la baseline
- Interface utilisateur interactive
- Monitoring avancé
- Performance optimisée

Pour toute question ou problème, consultez le [rapport de vérification complète](../reports/roosync-verification-complete-20251103.md) ou contactez l'administrateur système.

---

*Guide d'utilisation généré le 2025-11-03 par myia-web-01*  
*Version complète du système RooSync v2.1.0*
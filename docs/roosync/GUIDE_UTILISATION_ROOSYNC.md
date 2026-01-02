# Guide d'Utilisation RooSync v2.3.0

## Version: 1.0.0
## Date de création: 2026-01-02
## Dernière mise à jour: 2026-01-02

## Description

Ce guide fournit des instructions détaillées pour l'utilisation des outils RooSync v2.3.0, incluant les procédures de synchronisation, la gestion des messages et le dépannage courant.

---

## Table des Matières

1. [Démarrage Rapide](#1-démarrage-rapide)
2. [Outils de Synchronisation](#2-outils-de-synchronisation)
3. [Gestion des Messages](#3-gestion-des-messages)
4. [Procédures de Synchronisation](#4-procédures-de-synchronisation)
5. [Dépannage Courant](#5-dépannage-courant)
6. [Bonnes Pratiques](#6-bonnes-pratiques)
7. [Historique des Modifications](#7-historique-des-modifications)

---

## 1. Démarrage Rapide

### 1.1 Installation

#### Prérequis

- **Node.js** : v18+ (recommandé : v20 LTS)
- **PowerShell** : 7+ (recommandé : 7.4+)
- **Git** : 2.40+
- **VS Code** : avec extension Roo Code

#### Installation en 5 Minutes

```bash
# 1. Cloner le dépôt Roo
git clone https://github.com/your-org/roo-extensions.git
cd roo-extensions

# 2. Installer les dépendances
npm install

# 3. Construire le MCP roo-state-manager
cd mcps/internal/servers/roo-state-manager
npm run build
cd ../../..

# 4. Initialiser RooSync
# Via Roo Code MCP :
roosync_init { "force": false, "createRoadmap": true }
```

### 1.2 Configuration Initiale

#### Variables d'Environnement

```bash
# Variables essentielles
export ROO_SYNC_BASELINE_PATH="d:/roo-extensions/sync-config.ref.json"
export ROO_SYNC_ROADMAP_PATH="d:/roo-extensions/sync-roadmap.md"
export ROO_SYNC_SHARED_STATE_PATH="d:/roo-extensions/.shared-state"
export ROO_SYNC_MACHINE_ID="myia-ai-01"  # Adapter à votre machine
```

#### Fichiers de Configuration

**`sync-config.ref.json`** (Baseline de référence) :
```json
{
  "version": "2.3.0",
  "baseline": {
    "modes": {
      "enabled": ["architect", "code", "debug", "ask", "orchestrator", "manager"]
    },
    "mcp": {
      "servers": {
        "quickfiles": { "enabled": true },
        "jinavigator": { "enabled": true },
        "searxng": { "enabled": true },
        "markitdown": { "enabled": true },
        "playwright": { "enabled": true },
        "roo-state-manager": { "enabled": true }
      }
    }
  }
}
```

### 1.3 Première Synchronisation

```bash
# 1. Comparer la configuration locale avec la baseline
roosync_compare_config { "source": "local_machine", "target": "baseline_reference", "force_refresh": false }

# 2. Lister les différences
roosync_list_diffs { "filterType": "all" }

# 3. Consulter le roadmap pour les décisions
# Ouvrir sync-roadmap.md

# 4. Approuver et appliquer les décisions
roosync_approve_decision { "decisionId": "DECISION_ID" }
roosync_apply_decision { "decisionId": "DECISION_ID", "dryRun": false }
```

---

## 2. Outils de Synchronisation

### 2.1 Outils de Monitoring

#### roosync_get_status

**Description** : Obtenir l'état de synchronisation actuel

**Paramètres** :
```json
{
  "machineFilter": "myia-ai-01",  // Optionnel : filtrer par machine
  "resetCache": false              // Optionnel : forcer le rechargement du cache
}
```

**Exemple d'utilisation** :
```bash
roosync_get_status { "machineFilter": "myia-ai-01" }
```

**Réponse typique** :
```json
{
  "machines": [
    {
      "id": "myia-ai-01",
      "status": "synced",
      "lastSync": "2026-01-02T10:00:00Z",
      "baselineVersion": "2.3.0"
    }
  ],
  "decisions": {
    "pending": 2,
    "approved": 5,
    "rejected": 1
  }
}
```

#### roosync_read_dashboard

**Description** : Lire le dashboard RooSync avec les différences actuelles

**Paramètres** :
```json
{
  "machineFilter": "myia-ai-01",  // Optionnel : filtrer par machine
  "includeDetails": false,         // Optionnel : inclure les détails complets
  "resetCache": false             // Optionnel : forcer le rechargement du cache
}
```

**Exemple d'utilisation** :
```bash
roosync_read_dashboard { "includeDetails": true }
```

### 2.2 Outils de Comparaison

#### roosync_compare_config

**Description** : Comparer les configurations entre deux machines

**Paramètres** :
```json
{
  "source": "local_machine",       // Machine source
  "target": "baseline_reference",  // Machine cible
  "force_refresh": false           // Optionnel : forcer la collecte d'inventaire
}
```

**Exemple d'utilisation** :
```bash
roosync_compare_config { "source": "local_machine", "target": "baseline_reference" }
```

**Réponse typique** :
```json
{
  "source": "local_machine",
  "target": "baseline_reference",
  "differences": [
    {
      "type": "config",
      "path": "modes.enabled",
      "sourceValue": ["architect", "code"],
      "targetValue": ["architect", "code", "debug"],
      "severity": "WARNING"
    }
  ]
}
```

#### roosync_list_diffs

**Description** : Lister les différences détectées

**Paramètres** :
```json
{
  "filterType": "all"  // "all", "config", "files", "settings"
}
```

**Exemple d'utilisation** :
```bash
roosync_list_diffs { "filterType": "config" }
```

### 2.3 Outils de Décision

#### roosync_approve_decision

**Description** : Approuver une décision de synchronisation

**Paramètres** :
```json
{
  "decisionId": "DECISION_ID",  // ID de la décision
  "comment": "Approuvé"         // Optionnel : commentaire d'approbation
}
```

**Exemple d'utilisation** :
```bash
roosync_approve_decision { "decisionId": "DEC-2026-01-02-001", "comment": "Configuration validée" }
```

#### roosync_reject_decision

**Description** : Rejeter une décision de synchronisation

**Paramètres** :
```json
{
  "decisionId": "DECISION_ID",  // ID de la décision
  "reason": "Raison du rejet"    // Requis : motif du rejet
}
```

**Exemple d'utilisation** :
```bash
roosync_reject_decision { "decisionId": "DEC-2026-01-02-001", "reason": "Configuration incompatible" }
```

#### roosync_apply_decision

**Description** : Appliquer une décision approuvée

**Paramètres** :
```json
{
  "decisionId": "DECISION_ID",  // ID de la décision
  "dryRun": false,             // Optionnel : mode simulation
  "force": false               // Optionnel : forcer l'application même en cas de conflits
}
```

**Exemple d'utilisation** :
```bash
roosync_apply_decision { "decisionId": "DEC-2026-01-02-001", "dryRun": false }
```

#### roosync_rollback_decision

**Description** : Annuler une décision appliquée

**Paramètres** :
```json
{
  "decisionId": "DECISION_ID",  // ID de la décision
  "reason": "Raison du rollback" // Requis : motif du rollback
}
```

**Exemple d'utilisation** :
```bash
roosync_rollback_decision { "decisionId": "DEC-2026-01-02-001", "reason": "Problème détecté après application" }
```

#### roosync_get_decision_details

**Description** : Obtenir les détails complets d'une décision

**Paramètres** :
```json
{
  "decisionId": "DECISION_ID",  // ID de la décision
  "includeHistory": true,       // Optionnel : inclure l'historique complet
  "includeLogs": true           // Optionnel : inclure les logs d'exécution
}
```

**Exemple d'utilisation** :
```bash
roosync_get_decision_details { "decisionId": "DEC-2026-01-02-001", "includeHistory": true }
```

### 2.4 Outils de Configuration

#### roosync_collect_config

**Description** : Collecter la configuration locale

**Paramètres** :
```json
{
  "targets": ["modes", "mcp"]  // Optionnel : cibles de collecte
}
```

**Exemple d'utilisation** :
```bash
roosync_collect_config { "targets": ["modes", "mcp"] }
```

#### roosync_publish_config

**Description** : Publier une configuration partagée

**Paramètres** :
```json
{
  "package": "config-package",  // Nom du package
  "version": "1.0.0",         // Version
  "description": "Description"   // Description
}
```

**Exemple d'utilisation** :
```bash
roosync_publish_config { "package": "config-package", "version": "1.0.0", "description": "Configuration de base" }
```

#### roosync_apply_config

**Description** : Appliquer une configuration partagée

**Paramètres** :
```json
{
  "version": "1.0.0",         // Version à appliquer
  "targets": ["myia-po-2023"]  // Machines cibles
}
```

**Exemple d'utilisation** :
```bash
roosync_apply_config { "version": "1.0.0", "targets": ["myia-po-2023"] }
```

### 2.5 Outils d'Inventaire

#### roosync_get_machine_inventory

**Description** : Collecter l'inventaire machine

**Paramètres** :
```json
{
  "machineId": "myia-ai-01"  // ID de la machine
}
```

**Exemple d'utilisation** :
```bash
roosync_get_machine_inventory { "machineId": "myia-ai-01" }
```

---

## 3. Gestion des Messages

### 3.1 Envoyer un Message

#### roosync_send_message

**Description** : Envoyer un message à une autre machine

**Paramètres** :
```json
{
  "to": "myia-po-2023",           // Destinataire
  "subject": "Sujet du message",    // Sujet
  "body": "Corps du message",      // Corps (markdown supporté)
  "priority": "MEDIUM",             // Optionnel : LOW, MEDIUM, HIGH, URGENT
  "tags": ["sync", "baseline"],     // Optionnel : tags
  "thread_id": "thread-001",       // Optionnel : ID du thread
  "reply_to": "msg-001"            // Optionnel : ID du message auquel répondre
}
```

**Exemple d'utilisation** :
```bash
roosync_send_message {
  "to": "myia-po-2023",
  "subject": "Synchronisation requise",
  "body": "La baseline a été mise à jour. Veuillez synchroniser.",
  "priority": "HIGH",
  "tags": ["sync", "baseline"]
}
```

### 3.2 Lire les Messages

#### roosync_read_inbox

**Description** : Lire la boîte de réception des messages

**Paramètres** :
```json
{
  "status": "unread",  // Optionnel : "unread", "read", "all"
  "limit": 10          // Optionnel : nombre maximum de messages
}
```

**Exemple d'utilisation** :
```bash
roosync_read_inbox { "status": "unread", "limit": 10 }
```

#### roosync_get_message

**Description** : Obtenir les détails complets d'un message

**Paramètres** :
```json
{
  "messageId": "msg-001",      // ID du message
  "mark_as_read": false        // Optionnel : marquer comme lu
}
```

**Exemple d'utilisation** :
```bash
roosync_get_message { "messageId": "msg-001", "mark_as_read": true }
```

### 3.3 Répondre à un Message

#### roosync_reply_message

**Description** : Répondre à un message existant

**Paramètres** :
```json
{
  "messageId": "msg-001",      // ID du message auquel répondre
  "body": "Réponse",           // Corps de la réponse
  "priority": "MEDIUM",        // Optionnel : priorité de la réponse
  "tags": ["reply"]            // Optionnel : tags supplémentaires
}
```

**Exemple d'utilisation** :
```bash
roosync_reply_message {
  "messageId": "msg-001",
  "body": "Synchronisation en cours...",
  "priority": "MEDIUM"
}
```

### 3.4 Gérer les Messages

#### roosync_mark_message_read

**Description** : Marquer un message comme lu

**Paramètres** :
```json
{
  "messageId": "msg-001"  // ID du message
}
```

**Exemple d'utilisation** :
```bash
roosync_mark_message_read { "messageId": "msg-001" }
```

#### roosync_archive_message

**Description** : Archiver un message

**Paramètres** :
```json
{
  "messageId": "msg-001"  // ID du message
}
```

**Exemple d'utilisation** :
```bash
roosync_archive_message { "messageId": "msg-001" }
```

---

## 4. Procédures de Synchronisation

### 4.1 Synchronisation Basique

#### Étape 1 : Observer l'état

```bash
roosync_get_status
```

#### Étape 2 : Collecter la configuration locale

```bash
roosync_collect_config
```

#### Étape 3 : Comparer avec la baseline

```bash
roosync_compare_config { "source": "local_machine", "target": "baseline_reference" }
```

#### Étape 4 : Lister les différences

```bash
roosync_list_diffs { "filterType": "all" }
```

#### Étape 5 : Consulter le roadmap

Ouvrir `sync-roadmap.md` pour voir les décisions en attente

#### Étape 6 : Approuver les décisions

```bash
roosync_approve_decision { "decisionId": "DECISION_ID" }
```

#### Étape 7 : Appliquer les décisions

```bash
roosync_apply_decision { "decisionId": "DECISION_ID", "dryRun": false }
```

#### Étape 8 : Vérifier le résultat

```bash
roosync_get_status
```

### 4.2 Synchronisation Multi-Machines

#### Étape 1 : Collecter les inventaires

Sur chaque machine :
```bash
roosync_get_machine_inventory { "machineId": "MACHINE_ID" }
```

#### Étape 2 : Comparer les configurations

```bash
roosync_compare_config { "source": "myia-ai-01", "target": "myia-po-2023" }
```

#### Étape 3 : Créer des décisions pour chaque différence

```bash
roosync_approve_decision { "decisionId": "DECISION_ID" }
```

#### Étape 4 : Appliquer les décisions sur chaque machine

```bash
roosync_apply_decision { "decisionId": "DECISION_ID", "dryRun": false }
```

#### Étape 5 : Vérifier la synchronisation

```bash
roosync_get_status
```

### 4.3 Rollback en cas de Problème

#### Étape 1 : Identifier la décision problématique

```bash
roosync_get_decision_details { "decisionId": "DECISION_ID" }
```

#### Étape 2 : Effectuer le rollback

```bash
roosync_rollback_decision { "decisionId": "DECISION_ID", "reason": "Problème détecté" }
```

#### Étape 3 : Vérifier le résultat

```bash
roosync_get_status
```

---

## 5. Dépannage Courant

### 5.1 Problèmes de Synchronisation

#### Problème : La synchronisation échoue

**Symptômes** :
- Erreur lors de l'application d'une décision
- Différences persistantes après synchronisation

**Solutions** :
1. Vérifier l'état de synchronisation :
   ```bash
   roosync_get_status
   ```

2. Vérifier les différences :
   ```bash
   roosync_list_diffs { "filterType": "all" }
   ```

3. Consulter les logs :
   - Logs RooSync : `.shared-state/logs/`
   - Logs système : Windows Event Log

4. Effectuer un rollback si nécessaire :
   ```bash
   roosync_rollback_decision { "decisionId": "DECISION_ID", "reason": "Erreur de synchronisation" }
   ```

#### Problème : Conflits de configuration

**Symptômes** :
- Différences non résolues
- Erreurs de validation

**Solutions** :
1. Comparer les configurations en détail :
   ```bash
   roosync_compare_config { "source": "local_machine", "target": "baseline_reference" }
   ```

2. Consulter le roadmap pour les décisions en attente

3. Approuver ou rejeter les décisions manuellement

4. Appliquer les décisions une par une pour identifier le problème

### 5.2 Problèmes de Messagerie

#### Problème : Messages non reçus

**Symptômes** :
- Messages envoyés mais non reçus
- Boîte de réception vide

**Solutions** :
1. Vérifier la boîte de réception :
   ```bash
   roosync_read_inbox { "status": "all" }
   ```

2. Vérifier les messages archivés :
   ```bash
   roosync_read_inbox { "status": "read" }
   ```

3. Vérifier les logs de messagerie :
   - Logs RooSync : `.shared-state/logs/`

4. Vérifier la connectivité entre les machines

#### Problème : Messages non lus

**Symptômes** :
- Messages marqués comme non lus
- Notifications non reçues

**Solutions** :
1. Lire les messages non lus :
   ```bash
   roosync_read_inbox { "status": "unread" }
   ```

2. Marquer les messages comme lus :
   ```bash
   roosync_mark_message_read { "messageId": "msg-001" }
   ```

3. Répondre aux messages si nécessaire :
   ```bash
   roosync_reply_message { "messageId": "msg-001", "body": "Réponse" }
   ```

### 5.3 Problèmes de Performance

#### Problème : Synchronisation lente

**Symptômes** :
- Temps de synchronisation excessif
- Timeouts

**Solutions** :
1. Vérifier le cache :
   ```bash
   roosync_get_status { "resetCache": true }
   ```

2. Réduire la portée de la synchronisation :
   ```bash
   roosync_collect_config { "targets": ["modes"] }
   ```

3. Vérifier la connectivité réseau

4. Augmenter le TTL du cache si nécessaire

#### Problème : Inventaire lent à collecter

**Symptômes** :
- Temps de collecte d'inventaire excessif
- Timeouts

**Solutions** :
1. Vérifier le script Get-MachineInventory.ps1
2. Utiliser le cache si disponible :
   ```bash
   roosync_get_machine_inventory { "machineId": "myia-ai-01" }
   ```
3. Réduire la portée de l'inventaire

---

## 6. Bonnes Pratiques

### 6.1 Avant la Synchronisation

1. **Vérifier l'état actuel** :
   ```bash
   roosync_get_status
   ```

2. **Sauvegarder la configuration actuelle** :
   ```bash
   roosync_collect_config
   ```

3. **Comparer avec la baseline** :
   ```bash
   roosync_compare_config { "source": "local_machine", "target": "baseline_reference" }
   ```

4. **Consulter le roadmap** pour les décisions en attente

### 6.2 Pendant la Synchronisation

1. **Appliquer les décisions une par une** pour identifier les problèmes

2. **Utiliser le mode dryRun** pour tester :
   ```bash
   roosync_apply_decision { "decisionId": "DECISION_ID", "dryRun": true }
   ```

3. **Vérifier le résultat après chaque application** :
   ```bash
   roosync_get_status
   ```

4. **Documenter les actions** dans le journal

### 6.3 Après la Synchronisation

1. **Vérifier l'état final** :
   ```bash
   roosync_get_status
   ```

2. **Valider que toutes les différences sont résolues** :
   ```bash
   roosync_list_diffs { "filterType": "all" }
   ```

3. **Archiver les décisions appliquées**

4. **Documenter les résultats** dans le journal

### 6.4 Communication Multi-Agents

1. **Utiliser des priorités appropriées** pour les messages

2. **Inclure des tags** pour faciliter la recherche

3. **Répondre rapidement** aux messages urgents

4. **Archiver les messages** après traitement

5. **Utiliser des threads** pour les conversations complexes

---

## 7. Historique des Modifications

| Date | Version | Auteur | Description |
|------|---------|--------|-------------|
| 2026-01-02 | 1.0.0 | Roo Architect Mode | Création initiale du guide d'utilisation v2.3.0 |

---

**Document généré par:** Roo Architect Mode
**Date de génération:** 2026-01-02T11:38:00Z
**Version:** 1.0.0
**Statut:** 🟢 Production Ready

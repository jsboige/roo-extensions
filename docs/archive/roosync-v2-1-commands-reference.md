# RooSync v2.1 - Référence des Commandes MCP

## 📋 Table des Matières

- [Commandes de Workflow](#commandes-de-workflow)
- [Commandes de Diagnostic](#commandes-de-diagnostic)
- [Commandes de Messagerie](#commandes-de-messagerie)
- [Commandes d'Infrastructure](#commandes-dinfrastructure)
- [Codes de Réponse](#codes-de-réponse)

## 🔄 Commandes de Workflow

### roosync_detect_diffs

Détecte automatiquement les différences entre la configuration système et le baseline, puis crée des décisions dans le roadmap.

```json
{
  "tool_name": "roosync_detect_diffs",
  "server_name": "roo-state-manager",
  "arguments": {
    "sourceMachine": "local_machine",
    "targetMachine": "remote_machine", 
    "forceRefresh": false,
    "severityThreshold": "IMPORTANT"
  }
}
```

**Paramètres :**
- `sourceMachine` (string, optionnel) : ID machine source (défaut: "local_machine")
- `targetMachine` (string, optionnel) : ID machine cible (défaut: première autre disponible)
- `forceRefresh` (boolean, optionnel) : Force collecte inventaire fraîche (défaut: false)
- `severityThreshold` (string, optionnel) : Seuil min pour créer décisions (défaut: "IMPORTANT")

**Valeurs possibles pour severityThreshold :**
- `"CRITICAL"` : Uniquement les différences critiques
- `"IMPORTANT"` : Critiques + importantes (recommandé)
- `"WARNING"` : Critiques + importantes + avertissements
- `"INFO"` : Toutes les différences

**Réponse :**
```json
{
  "success": true,
  "differencesDetected": 8,
  "decisionsCreated": 5,
  "summary": {
    "bySeverity": {
      "CRITICAL": 2,
      "IMPORTANT": 3,
      "WARNING": 2,
      "INFO": 1
    }
  },
  "nextSteps": [
    "Consultez sync-roadmap.md pour valider les décisions",
    "Utilisez roosync_approve_decision pour approuver",
    "Utilisez roosync_apply_decision pour appliquer"
  ]
}
```

---

### roosync_approve_decision

Approuve une décision de synchronisation dans le roadmap.

```json
{
  "tool_name": "roosync_approve_decision",
  "server_name": "roo-state-manager",
  "arguments": {
    "decisionId": "decision-123",
    "comment": "Nécessaire pour le développement React"
  }
}
```

**Paramètres :**
- `decisionId` (string, requis) : ID unique de la décision à approuver
- `comment` (string, optionnel) : Commentaire d'approbation pour traçabilité

**Réponse :**
```json
{
  "success": true,
  "decisionId": "decision-123",
  "status": "APPROVED",
  "comment": "Nécessaire pour le développement React",
  "timestamp": "2025-10-20T17:30:00Z"
}
```

---

### roosync_reject_decision

Rejette une décision avec un motif obligatoire pour traçabilité.

```json
{
  "tool_name": "roosync_reject_decision",
  "server_name": "roo-state-manager",
  "arguments": {
    "decisionId": "decision-456",
    "reason": "Configuration non pertinente pour cette machine"
  }
}
```

**Paramètres :**
- `decisionId` (string, requis) : ID unique de la décision à rejeter
- `reason` (string, requis) : Motif du rejet (obligatoire pour traçabilité)

**Réponse :**
```json
{
  "success": true,
  "decisionId": "decision-456",
  "status": "REJECTED",
  "reason": "Configuration non pertinente pour cette machine",
  "timestamp": "2025-10-20T17:30:00Z"
}
```

---

### roosync_apply_decision

Applique une ou plusieurs décisions de synchronisation approuvées.

```json
{
  "tool_name": "roosync_apply_decision",
  "server_name": "roo-state-manager",
  "arguments": {
    "decisionId": "decision-123",
    "dryRun": false,
    "force": false
  }
}
```

**Paramètres :**
- `decisionId` (string, optionnel) : ID spécifique de la décision à appliquer (si omis, applique toutes les décisions approuvées)
- `dryRun` (boolean, optionnel) : Mode simulation sans modification réelle (défaut: false)
- `force` (boolean, optionnel) : Force application même si conflits détectés (défaut: false)

**Réponse :**
```json
{
  "success": true,
  "decisionId": "decision-123",
  "status": "APPLIED",
  "changesApplied": 3,
  "timestamp": "2025-10-20T17:30:00Z",
  "summary": {
    "filesModified": 2,
    "settingsUpdated": 1,
    "servicesRestarted": 0
  }
}
```

---

### roosync_rollback_decision

Annule une décision de synchronisation précédemment appliquée.

```json
{
  "tool_name": "roosync_rollback_decision",
  "server_name": "roo-state-manager",
  "arguments": {
    "decisionId": "decision-123",
    "reason": "Problème de compatibilité détecté"
  }
}
```

**Paramètres :**
- `decisionId` (string, requis) : ID unique de la décision à annuler
- `reason` (string, requis) : Raison du rollback pour traçabilité

**Réponse :**
```json
{
  "success": true,
  "decisionId": "decision-123",
  "status": "ROLLED_BACK",
  "reason": "Problème de compatibilité détecté",
  "timestamp": "2025-10-20T17:30:00Z",
  "changesReverted": 3
}
```

---

## 🔍 Commandes de Diagnostic

### roosync_get_status

Obtient l'état actuel du système de synchronisation RooSync.

```json
{
  "tool_name": "roosync_get_status",
  "server_name": "roo-state-manager",
  "arguments": {
    "machineFilter": "local_machine"
  }
}
```

**Paramètres :**
- `machineFilter` (string, optionnel) : ID machine pour filtrer les résultats

**Réponse :**
```json
{
  "success": true,
  "status": {
    "version": "2.1.0",
    "baseline": {
      "exists": true,
      "lastModified": "2025-10-20T15:00:00Z",
      "checksum": "abc123..."
    },
    "decisions": {
      "total": 12,
      "pending": 5,
      "approved": 4,
      "rejected": 2,
      "applied": 1
    },
    "lastSync": "2025-10-20T16:30:00Z"
  }
}
```

---

### roosync_compare_config

Compare les configurations réelles entre deux machines (outil de diagnostic pur).

```json
{
  "tool_name": "roosync_compare_config",
  "server_name": "roo-state-manager",
  "arguments": {
    "source": "pc-dev-01",
    "target": "pc-prod-01",
    "force_refresh": false
  }
}
```

**Paramètres :**
- `source` (string, optionnel) : ID machine source (défaut: "local_machine")
- `target` (string, optionnel) : ID machine cible (défaut: "remote_machine")
- `force_refresh` (boolean, optionnel) : Force collecte inventaire fraîche

**Réponse :**
```json
{
  "success": true,
  "comparison": {
    "summary": {
      "totalDifferences": 15,
      "bySeverity": {
        "CRITICAL": 3,
        "IMPORTANT": 5,
        "WARNING": 4,
        "INFO": 3
      }
    },
    "differences": [
      {
        "category": "roo_config",
        "subcategory": "mcps",
        "severity": "CRITICAL",
        "description": "MCP 'quickfiles' présent sur source, absent sur target",
        "recommendation": "Synchroniser configuration MCP"
      }
    ]
  }
}
```

---

### roosync_list_diffs

Liste toutes les différences détectées avec filtrage avancé.

```json
{
  "tool_name": "roosync_list_diffs",
  "server_name": "roo-state-manager",
  "arguments": {
    "filterType": "all",
    "severity": "IMPORTANT"
  }
}
```

**Paramètres :**
- `filterType` (string, optionnel) : Type de filtrage ("all", "config", "files", "settings")
- `severity` (string, optionnel) : Filtre par sévérité

**Réponse :**
```json
{
  "success": true,
  "differences": [
    {
      "id": "diff-001",
      "category": "roo_config",
      "severity": "CRITICAL",
      "description": "MCP manquant",
      "details": "..."
    }
  ],
  "totalCount": 8
}
```

---

### roosync_get_decision_details

Obtient les détails complets d'une décision spécifique.

```json
{
  "tool_name": "roosync_get_decision_details",
  "server_name": "roo-state-manager",
  "arguments": {
    "decisionId": "decision-123",
    "includeHistory": true,
    "includeLogs": true
  }
}
```

**Paramètres :**
- `decisionId` (string, requis) : ID unique de la décision
- `includeHistory` (boolean, optionnel) : Inclure l'historique complet (défaut: true)
- `includeLogs` (string, optionnel) : Inclure les logs d'exécution (défaut: true)

**Réponse :**
```json
{
  "success": true,
  "decision": {
    "id": "decision-123",
    "status": "APPROVED",
    "createdAt": "2025-10-20T15:00:00Z",
    "title": "Ajouter MCP quickfiles",
    "description": "Installation nécessaire pour le développement",
    "changes": [...],
    "history": [...],
    "logs": [...]
  }
}
```

---

## 📧 Commandes de Messagerie

### roosync_send_message

Envoie un message structuré à une autre machine via RooSync.

```json
{
  "tool_name": "roosync_send_message",
  "server_name": "roo-state-manager",
  "arguments": {
    "to": "pc-dev-02",
    "subject": "Mise à jour disponible",
    "body": "Nouvelle version des configurations disponible",
    "priority": "HIGH",
    "tags": ["update", "config"]
  }
}
```

**Paramètres :**
- `to` (string, requis) : ID machine destinataire
- `subject` (string, requis) : Sujet du message
- `body` (string, requis) : Corps du message (markdown supporté)
- `priority` (string, optionnel) : Priorité ("LOW", "MEDIUM", "HIGH", "URGENT")
- `tags` (array[string], optionnel) : Tags pour catégorisation
- `thread_id` (string, optionnel) : ID du thread pour regroupement
- `reply_to` (string, optionnel) : ID du message auquel répondre

**Réponse :**
```json
{
  "success": true,
  "messageId": "msg-456",
  "timestamp": "2025-10-20T17:30:00Z",
  "status": "sent"
}
```

---

### roosync_read_inbox

Lit la boîte de réception des messages RooSync.

```json
{
  "tool_name": "roosync_read_inbox",
  "server_name": "roo-state-manager",
  "arguments": {
    "status": "unread",
    "limit": 10
  }
}
```

**Paramètres :**
- `status` (string, optionnel) : Filtrer par statut ("unread", "read", "all")
- `limit` (number, optionnel) : Nombre maximum de messages

**Réponse :**
```json
{
  "success": true,
  "messages": [
    {
      "id": "msg-456",
      "from": "pc-dev-01",
      "subject": "Mise à jour disponible",
      "priority": "HIGH",
      "timestamp": "2025-10-20T17:30:00Z",
      "status": "unread"
    }
  ],
  "totalCount": 5
}
```

---

## 🏗️ Commandes d'Infrastructure

### roosync_init

Initialise l'infrastructure RooSync baseline-driven.

```json
{
  "tool_name": "roosync_init",
  "server_name": "roo-state-manager",
  "arguments": {
    "force": false,
    "createRoadmap": true
  }
}
```

**Paramètres :**
- `force` (boolean, optionnel) : Force réinitialisation même si existe (défaut: false)
- `createRoadmap` (boolean, optionnel) : Crée roadmap initial (défaut: true)

**Réponse :**
```json
{
  "success": true,
  "initialized": true,
  "baseline": {
    "created": true,
    "path": "/path/to/sync-config.ref.json"
  },
  "roadmap": {
    "created": true,
    "path": "/path/to/sync-roadmap.md"
  }
}
```

---

## 📊 Codes de Réponse

### Codes de Succès

| Code | Description |
|------|-------------|
| `success: true` | Opération réussie |
| `status: "APPLIED"` | Décision appliquée |
| `status: "APPROVED"` | Décision approuvée |
| `status: "REJECTED"` | Décision rejetée |
| `status: "ROLLED_BACK"` | Décision annulée |

### Codes d'Erreur

| Code | Description | Solution |
|------|-------------|----------|
| `BASELINE_NOT_FOUND` | Fichier baseline manquant | Exécuter `roosync_init` |
| `DECISION_NOT_FOUND` | Décision inexistante | Vérifier `sync-roadmap.md` |
| `INVALID_SEVERITY` | Seuil de sévérité invalide | Utiliser valeurs valides |
| `APPLY_FAILED` | Échec application | Vérifier logs et conflits |
| `PERMISSION_DENIED` | Permissions insuffisantes | Exécuter avec droits élevés |
| `NETWORK_ERROR` | Erreur réseau | Vérifier connexion |
| `VALIDATION_ERROR` | Paramètres invalides | Corriger les arguments |

### Format d'Erreur Standard

```json
{
  "success": false,
  "error": {
    "code": "BASELINE_NOT_FOUND",
    "message": "Le fichier baseline sync-config.ref.json n'existe pas",
    "details": "Exécutez roosync_init pour créer l'infrastructure",
    "timestamp": "2025-10-20T17:30:00Z"
  }
}
```

---

## 🎯 Bonnes Pratiques

### Avant d'exécuter
1. **Vérifier l'état** avec `roosync_get_status`
2. **Sauvegarder** le baseline si modifications importantes
3. **Utiliser `dryRun: true`** pour les tests

### Pendant l'exécution
1. **Lire attentivement** les réponses
2. **Vérifier les codes d'erreur**
3. **Documenter** les actions importantes

### Après l'exécution
1. **Valider** que tout fonctionne
2. **Vérifier** l'état final
3. **Documenter** les problèmes rencontrés

---

**Version**: RooSync v2.1 Baseline-Driven  
**Dernière mise à jour**: 2025-10-20  
**Documentation complète**: [Voir guides détaillés](./roosync-v2-1-deployment-guide.md)
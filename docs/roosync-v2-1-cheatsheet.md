# RooSync v2.1 - Cheatsheet

## 🚀 Quick Start

```bash
# 1. Initialiser RooSync
use_mcp_tool "roo-state-manager" "roosync_init" {}

# 2. Détecter les différences
use_mcp_tool "roo-state-manager" "roosync_detect_diffs" {}

# 3. Consulter sync-roadmap.md et valider les décisions

# 4. Appliquer les décisions approuvées
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {}
```

## 📋 Commandes Essentielles

### Workflow Baseline-Driven

| Commande | Description | Exemple |
|----------|-------------|---------|
| `roosync_detect_diffs` | Détecte différences contre baseline | `{"severityThreshold": "IMPORTANT"}` |
| `roosync_approve_decision` | Approuve une décision | `{"decisionId": "decision-123"}` |
| `roosync_apply_decision` | Applique décisions approuvées | `{}` |
| `roosync_rollback_decision` | Annule une décision | `{"decisionId": "decision-123"}` |

### Diagnostic et Configuration

| Commande | Description | Exemple |
|----------|-------------|---------|
| `roosync_get_status` | État actuel de la synchronisation | `{}` |
| `roosync_compare_config` | Compare configs entre machines | `{"source": "pc1", "target": "pc2"}` |
| `roosync_list_diffs` | Liste les différences détectées | `{}` |

### Messages Inter-Machines

| Commande | Description | Exemple |
|----------|-------------|---------|
| `roosync_send_message` | Envoie un message | `{"to": "pc2", "subject": "Test", "body": "Message"}` |
| `roosync_read_inbox` | Lit la boîte de réception | `{"status": "unread"}` |

## 🔄 Workflow Complet

### Phase 1: Détection
```bash
# Détecter toutes les différences importantes
use_mcp_tool "roo-state-manager" "roosync_detect_diffs" {
  "severityThreshold": "IMPORTANT",
  "forceRefresh": false
}
```

### Phase 2: Validation
1. Ouvrir `sync-roadmap.md`
2. Examiner chaque décision
3. Approuver ou rejeter :
```bash
# Approuver
use_mcp_tool "roo-state-manager" "roosync_approve_decision" {
  "decisionId": "decision-123",
  "comment": "Nécessaire pour le développement"
}

# Rejeter
use_mcp_tool "roo-state-manager" "roosync_reject_decision" {
  "decisionId": "decision-456",
  "reason": "Non pertinent pour cette machine"
}
```

### Phase 3: Application
```bash
# Appliquer toutes les décisions approuvées
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {}

# Ou appliquer une décision spécifique
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {
  "decisionId": "decision-123"
}
```

## 🎯 Scénarios Courants

### Première Configuration
```bash
# 1. Initialiser l'infrastructure
use_mcp_tool "roo-state-manager" "roosync_init" {}

# 2. Créer le baseline initial
use_mcp_tool "roo-state-manager" "roosync_detect_diffs" {}

# 3. Valider et appliquer
# (Éditer sync-roadmap.md)
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {}
```

### Synchronisation Quotidienne
```bash
# 1. Vérifier l'état
use_mcp_tool "roo-state-manager" "roosync_get_status" {}

# 2. Détecter les nouveautés
use_mcp_tool "roo-state-manager" "roosync_detect_diffs" {}

# 3. Valider rapidement si nécessaire
# (sync-roadmap.md)

# 4. Appliquer
use_mcp_tool "roo-state-manager" "roosync_apply_decision" {}
```

### Diagnostic de Problèmes
```bash
# 1. Comparer avec une autre machine
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "source": "local_machine",
  "target": "remote_machine"
}

# 2. Lister les différences
use_mcp_tool "roo-state-manager" "roosync_list_diffs" {}

# 3. Vérifier les détails d'une décision
use_mcp_tool "roo-state-manager" "roosync_get_decision_details" {
  "decisionId": "decision-123"
}
```

## 📊 Fichiers Importants

| Fichier | Description | Action |
|---------|-------------|--------|
| `sync-config.ref.json` | Baseline de configuration | Référence unique |
| `sync-roadmap.md` | Dashboard des décisions | Validation manuelle |
| `.shared-state/` | État partagé | Synchronisation |

## ⚡ Paramètres Utiles

### roosync_detect_diffs
- `severityThreshold`: "CRITICAL" | "IMPORTANT" | "WARNING" | "INFO"
- `forceRefresh`: true/false (force collecte fraîche)
- `sourceMachine`: ID machine source
- `targetMachine`: ID machine cible

### roosync_apply_decision
- `decisionId`: ID spécifique (optionnel)
- `dryRun`: true/false (simulation)
- `force`: true/false (ignore conflits)

## 🔍 Codes d'Erreur

| Code | Description | Solution |
|------|-------------|----------|
| `BASELINE_NOT_FOUND` | Fichier baseline manquant | Exécuter `roosync_init` |
| `DECISION_NOT_FOUND` | Décision inexistante | Vérifier `sync-roadmap.md` |
| `INVALID_SEVERITY` | Seuil invalide | Utiliser CRITICAL/IMPORTANT/WARNING/INFO |
| `APPLY_FAILED` | Échec d'application | Vérifier logs et conflits |

## 🎯 Best Practices

### Avant de Commencer
1. **Toujours vérifier** `roosync_get_status`
2. **Sauvegarder** le baseline avant modifications
3. **Utiliser `dryRun: true`** pour les tests

### Pendant le Workflow
1. **Lire attentivement** chaque décision dans `sync-roadmap.md`
2. **Ajouter des commentaires** lors de l'approbation/rejet
3. **Appliquer par lots** pour les changements importants

### Après Synchronisation
1. **Vérifier** que tout fonctionne correctement
2. **Documenter** les problèmes rencontrés
3. **Mettre à jour** le baseline si nécessaire

## 📞 Aide Rapide

### Obtenir de l'aide
```bash
# Guide complet
use_mcp_tool "roo-state-manager" "get_mcp_best_practices" {
  "mcp_name": "roo-state-manager"
}

# État système
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
```

### Réinitialisation
```bash
# En cas de problème majeur
use_mcp_tool "roo-state-manager" "roosync_init" {
  "force": true
}
```

---

**Version**: RooSync v2.1 Baseline-Driven  
**Dernière mise à jour**: 2025-10-20  
**Documentation complète**: [Voir guides détaillés](./roosync-v2-1-deployment-guide.md)
# 🔄 Guide Utilisateur RooSync v2.1 - Synchronisation Multi-Machines

**Date de création** : 2025-10-28  
**Version** : 2.1.0  
**Auteur** : Roo Architect Complex  
**Statut** : 🟢 **PRODUCTION READY**  
**Catégorie** : GUIDE UTILISATEUR  

---

## 🎯 Objectif

Ce guide fournit des instructions simples et directes pour utiliser RooSync v2.1, le système de synchronisation baseline-driven qui maintient la cohérence des environnements Roo entre plusieurs machines.

---

## 🚀 Démarrage Rapide

### Prérequis Essentiels

- **Node.js 18+** installé et fonctionnel
- **PowerShell 7+** pour les scripts d'inventaire
- **Git 2.30+** avec support `--force-with-lease`
- **Google Drive** configuré avec un dossier partagé

### Installation en 5 Minutes

#### 1. Installer roo-state-manager
```bash
cd mcps/internal/servers/roo-state-manager
npm install
npm run build
```

#### 2. Configurer le MCP dans Roo
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

#### 3. Configurer les variables d'environnement
Créer `.env` à la racine du projet :
```bash
ROOSYNC_SHARED_PATH=G:/Mon Drive/Synchronisation/RooSync/.shared-state
ROOSYNC_MACHINE_ID=PC-PRINCIPAL
ROOSYNC_AUTO_SYNC=false
ROOSYNC_LOG_LEVEL=info
ROOSYNC_CONFLICT_STRATEGY=manual
```

#### 4. Initialiser RooSync
```bash
# Créer l'infrastructure
use_mcp_tool "roo-state-manager" "roosync_init" {}

# Créer la baseline de référence
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
```

#### 5. Première synchronisation
```bash
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "source": "local_machine",
  "target": "baseline_reference"
}
```

---

## 📋 Utilisation Quotidienne

### Vérifier l'état de synchronisation
```bash
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
```

### Synchroniser avec la baseline
```bash
# Comparer et générer les décisions
use_mcp_tool "roo-state-manager" "roosync_compare_config" {
  "source": "local_machine",
  "target": "baseline_reference"
}

# Lister les différences détectées
use_mcp_tool "roo-state-manager" "roosync_list_diffs" {}
```

### Gérer les décisions de synchronisation
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

---

## 🏗️ Architecture Baseline-Driven

### Concept Clé

RooSync v2.1 utilise une **baseline de référence** unique au lieu de synchroniser directement entre machines :

```
Machine A → Compare avec Baseline → Décisions → Application
Machine B → Compare avec Baseline → Décisions → Application
```

### Avantages

- **Source de vérité unique** : Pas de conflits machine-à-machine
- **Validation humaine** : Contrôle total sur les changements
- **Traçabilité complète** : Historique de toutes les décisions
- **Rollback facile** : Annulation possible des changements

---

## 🔧 Configuration Avancée

### Variables d'Environnement

| Variable | Requis | Description | Valeur Exemple |
|----------|---------|-----------|----------------|
| `ROOSYNC_SHARED_PATH` | Oui | Chemin vers Google Drive partagé | `G:/Mon Drive/Synchronisation/RooSync/.shared-state` |
| `ROOSYNC_MACHINE_ID` | Oui | Identifiant unique machine | `PC-PRINCIPAL` |
| `ROOSYNC_AUTO_SYNC` | Non | Synchronisation auto | `false` |
| `ROOSYNC_LOG_LEVEL` | Non | Niveau logs | `info` |
| `ROOSYNC_CONFLICT_STRATEGY` | Non | Stratégie conflits | `manual` |

### Fichiers de Configuration

#### sync-config.ref.json (Baseline Référence)
```json
{
  "version": "1.0.0",
  "lastUpdated": "2025-10-28T10:00:00Z",
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

---

## 🚨 Dépannage Rapide

### Problèmes Courants

#### 1. "Baseline non disponible"
**Cause** : Fichier `sync-config.ref.json` manquant
**Solution** :
```bash
use_mcp_tool "roo-state-manager" "roosync_get_status" {}
# Crée automatiquement la baseline si elle n'existe pas
```

#### 2. "Permission refusée"
**Cause** : Droits insuffisants sur Google Drive
**Solution** :
```bash
# Vérifier les permissions
Test-Path $env:ROOSYNC_SHARED_PATH
# Corriger les permissions si nécessaire
```

#### 3. "Conflit de décisions"
**Cause** : Décisions en attente contradictoires
**Solution** :
```bash
# Lister toutes les décisions
use_mcp_tool "roo-state-manager" "roosync_list_diffs" {}

# Résoudre manuellement chaque décision
use_mcp_tool "roo-state-manager" "roosync_approve_decision" {
  "decision_id": "uuid",
  "comment": "Résolution manuelle du conflit"
}
```

### Outils de Diagnostic

```bash
# Diagnostic complet
use_mcp_tool "roo-state-manager" "diagnose_roo_state" {}

# Validation configuration
use_mcp_tool "roo-state-manager" "get_mcp_best_practices" {
  "mcp_name": "roo-state-manager"
}

# Reconstruction cache
use_mcp_tool "roo-state-manager" "build_skeleton_cache" {
  "force_rebuild": false
}
```

---

## 📊 Bonnes Pratiques

### Avant la Synchronisation

1. **Sauvegarder** les configurations critiques
2. **Vérifier** l'état actuel avec `roosync_get_status`
3. **Documenter** les changements prévus

### Pendant la Synchronisation

1. **Valider** chaque décision avant approbation
2. **Commenter** les raisons des choix
3. **Vérifier** les résultats après application

### Après la Synchronisation

1. **Tester** les fonctionnalités critiques
2. **Documenter** les problèmes rencontrés
3. **Mettre à jour** la baseline si nécessaire

---

## 🔗 Références Techniques

### Documentation Complète
- **Synthèse Technique** : [`ROOSYNC-COMPLETE-SYNTHESIS-2025-10-26.md`](ROOSYNC-COMPLETE-SYNTHESIS-2025-10-26.md)
- **Guide Déploiement** : [`roosync-v2-1-deployment-guide.md`](deployment/roosync-v2-1-deployment-guide.md)
- **API roo-state-manager** : [`mcps/internal/servers/roo-state-manager/README.md`](../../mcps/internal/servers/roo-state-manager/README.md)

### Scripts et Outils
- **Get-MachineInventory.ps1** : Scripts d'inventaire système
- **Scripts de maintenance** : `scripts/maintenance-scripts/`
- **Tests automatisés** : `scripts/testing/`

---

## 🚀 Prochaines Étapes

### Pour cette machine

1. **Immédiat** :
   - [ ] Finaliser la configuration de `sync-config.ref.json`
   - [ ] Exécuter la première synchronisation complète
   - [ ] Documenter les décisions dans `sync-roadmap.md`

2. **Court Terme (1-2 semaines)** :
   - [ ] Mettre en place la stratégie de sauvegarde automatique
   - [ ] Configurer les notifications pour les changements distants
   - [ ] Optimiser les performances avec cache intelligent

### Pour l'écosystème

1. **Moyen Terme (1-3 mois)** :
   - [ ] Déployer sur une deuxième machine de test
   - [ ] Mettre en place la synchronisation multi-machines réelle
   - [ ] Créer des scripts de monitoring automatisés

2. **Long Terme (3-6 mois)** :
   - [ ] Interface web de gestion RooSync
   - [ ] Intégration avec des outils externes (CI/CD)
   - [ ] Synchronisation de configurations de développement

---

## 📞 Support et Assistance

### Niveaux de Support

1. **Auto-support** : Utiliser les outils de diagnostic intégrés
2. **Documentation** : Consulter les guides techniques
3. **Community** : Poser des questions dans les issues GitHub
4. **Expert** : Contacter Roo Architect Complex pour problèmes complexes

### Outils de Support

```bash
# Rapport d'état complet
use_mcp_tool "roo-state-manager" "roosync_get_status" {}

# Diagnostic avancé
use_mcp_tool "roo-state-manager" "diagnose_roo_state" {}

# Aide contextuelle
use_mcp_tool "roo-state-manager" "get_mcp_best_practices" {
  "mcp_name": "roo-state-manager"
}
```

---

**Conclusion**

RooSync v2.1 est maintenant **production-ready** avec une architecture baseline-driven qui garantit la cohérence des environnements Roo tout en maintenant un contrôle humain sur les changements critiques. Ce guide utilisateur simplifié permet une prise en main rapide tout en conservant accès à la documentation technique complète.

**Version du document** : 1.0  
**Dernière mise à jour** : 28 octobre 2025  
**Prochaine révision** : 28 novembre 2025
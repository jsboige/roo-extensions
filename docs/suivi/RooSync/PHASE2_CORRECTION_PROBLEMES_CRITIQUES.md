# Phase 2: Correction des Problèmes Critiques

## Tâches: 14-29
## Checkpoints: CP2.1-CP2.16
## Date de création: 2026-01-02
## Dernière mise à jour: 2026-01-02

## Statut Global
- **Tâches terminées:** 0/16
- **Tâches en cours:** 0
- **Tâches en attente:** 16
- **Checkpoints validés:** 0/16

## Objectif de la Phase

Stabiliser le système et compléter la transition vers RooSync v2.3.

---

## Tâches

### Tâche 2.1: Compléter la transition v2.1→v2.3
- **Statut:** En attente
- **Responsable:** myia-po-2024, myia-po-2023
- **Checkpoint:** CP2.1
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Valider l'état et compléter les étapes manquantes

### Tâche 2.2: Mettre à jour Node.js vers v24+ sur myia-po-2023
- **Statut:** En attente
- **Responsable:** myia-po-2023, myia-po-2026
- **Checkpoint:** CP2.2
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Installer Node.js v24+ et valider la compatibilité

### Tâche 2.3: Sécuriser les clés API
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-web-01
- **Checkpoint:** CP2.3
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Déplacer les clés API vers un gestionnaire de secrets

### Tâche 2.4: Implémenter un système de verrouillage pour les fichiers de présence
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2024
- **Checkpoint:** CP2.4
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Utiliser des locks fichier ou une base de données

### Tâche 2.5: Bloquer le démarrage en cas de conflit d'identité
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2026
- **Checkpoint:** CP2.5
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Valider l'unicité au démarrage

### Tâche 2.6: Améliorer la gestion du cache
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2023
- **Checkpoint:** CP2.6
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Augmenter le TTL par défaut et implémenter une invalidation intelligente

### Tâche 2.7: Simplifier l'architecture des baselines non-nominatives
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2024
- **Checkpoint:** CP2.7
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Documenter clairement le fonctionnement

### Tâche 2.8: Améliorer la gestion des erreurs
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2026
- **Checkpoint:** CP2.8
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Propager les erreurs de manière explicite

### Tâche 2.9: Améliorer le système de rollback
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-web-01
- **Checkpoint:** CP2.9
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Implémenter un système transactionnel

### Tâche 2.10: Remplacer la roadmap Markdown par un format structuré
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2023
- **Checkpoint:** CP2.10
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Utiliser JSON pour le stockage

### Tâche 2.11: Accélérer le déploiement v2.3
- **Statut:** En attente
- **Responsable:** Toutes les machines
- **Checkpoint:** CP2.11
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Compléter la transition v2.1→v2.3 sur toutes les machines

### Tâche 2.12: Recompiler le MCP sur myia-po-2023
- **Statut:** En attente
- **Responsable:** myia-po-2023
- **Checkpoint:** CP2.12
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Exécuter npm run build et redémarrer le MCP

### Tâche 2.13: Migrer les console.log dans InventoryCollectorWrapper.ts
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2026
- **Checkpoint:** CP2.13
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Remplacer les console.log par le logger unifié

### Tâche 2.14: Migrer les console.log dans MessageManager.ts
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2026
- **Checkpoint:** CP2.13
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Remplacer les console.log par le logger unifié

### Tâche 2.15: Migrer les console.log dans NonNominativeBaselineService.ts
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2026
- **Checkpoint:** CP2.13
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Remplacer les console.log par le logger unifié

### Tâche 2.16: Corriger l'incohérence InventoryCollector
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2023
- **Checkpoint:** CP2.16
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Corriger applyConfig() pour utiliser les mêmes chemins directs que la collecte

### Tâche 2.17: Créer le guide de migration v2.1 → v2.3
- **Statut:** En attente
- **Responsable:** myia-ai-01, myia-po-2023
- **Checkpoint:** CP2.14
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Documenter les étapes de migration et les changements

### Tâche 2.18: Clarifier les transitions de version (v2.1, v2.2, v2.3)
- **Statut:** En attente
- **Responsable:** myia-po-2023, myia-po-2024
- **Checkpoint:** CP2.14
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Documenter clairement les différences entre versions

### Tâche 2.19: Créer un index principal docs/INDEX.md
- **Statut:** En attente
- **Responsable:** myia-po-2023, myia-po-2024
- **Checkpoint:** CP2.14
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Créer un index centralisé pour la documentation

### Tâche 2.20: Créer des tests unitaires pour les outils RooSync non testés
- **Statut:** En attente
- **Responsable:** myia-po-2026, myia-web-01
- **Checkpoint:** CP2.15
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Ajouter des tests pour les outils sans couverture

### Tâche 2.21: Ajouter des tests E2E pour Compare → Validate → Apply
- **Statut:** En attente
- **Responsable:** myia-po-2026, myia-web-01
- **Checkpoint:** CP2.15
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Créer des tests E2E pour le workflow complet

### Tâche 2.22: Tester la synchronisation multi-machines
- **Statut:** En attente
- **Responsable:** myia-po-2026, myia-web-01
- **Checkpoint:** CP2.15
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Valider la synchronisation entre plusieurs machines

### Tâche 2.23: Tester la gestion des conflits
- **Statut:** En attente
- **Responsable:** myia-po-2026, myia-web-01
- **Checkpoint:** CP2.15
- **Dernière mise à jour:** 2026-01-02
- **Notes:** Valider la résolution des conflits de synchronisation

---

## Checkpoints

### CP2.1: Transition v2.1→v2.3 complétée
- **Responsable:** myia-po-2024
- **Critère de Validation:** Toutes les machines en v2.3
- **Statut:** En attente

### CP2.2: Node.js v24+ installé
- **Responsable:** myia-po-2023
- **Critère de Validation:** Version v24+ installée
- **Statut:** En attente

### CP2.3: Clés API sécurisées
- **Responsable:** myia-ai-01
- **Critère de Validation:** Aucune clé en clair
- **Statut:** En attente

### CP2.4: Système de verrouillage implémenté
- **Responsable:** myia-ai-01
- **Critère de Validation:** Fichiers de présence protégés
- **Statut:** En attente

### CP2.5: Blocage au démarrage en cas de conflit
- **Responsable:** myia-ai-01
- **Critère de Validation:** Conflits bloquent le démarrage
- **Statut:** En attente

### CP2.6: Gestion du cache améliorée
- **Responsable:** myia-ai-01
- **Critère de Validation:** TTL augmenté et invalidation intelligente
- **Statut:** En attente

### CP2.7: Architecture des baselines simplifiée
- **Responsable:** myia-ai-01
- **Critère de Validation:** Code simplifié et documenté
- **Statut:** En attente

### CP2.8: Gestion des erreurs améliorée
- **Responsable:** myia-ai-01
- **Critère de Validation:** Erreurs propagées explicitement
- **Statut:** En attente

### CP2.9: Système de rollback amélioré
- **Responsable:** myia-ai-01
- **Critère de Validation:** Rollbacks transactionnels
- **Statut:** En attente

### CP2.10: Roadmap convertie en format structuré
- **Responsable:** myia-ai-01
- **Critère de Validation:** JSON généré et validé
- **Statut:** En attente

### CP2.11: Déploiement v2.3 accéléré
- **Responsable:** myia-po-2024
- **Critère de Validation:** Toutes les machines en v2.3
- **Statut:** En attente

### CP2.12: MCP recompilé sur myia-po-2023
- **Responsable:** myia-po-2023
- **Critère de Validation:** Outils v2.3 disponibles
- **Statut:** En attente

### CP2.13: Console.log migrés (100%)
- **Responsable:** myia-ai-01
- **Critère de Validation:** Tous les console.log remplacés
- **Statut:** En attente

### CP2.16: InventoryCollector cohérent
- **Responsable:** myia-ai-01
- **Critère de Validation:** Chemins directs utilisés dans applyConfig()
- **Statut:** En attente

### CP2.14: Documentation consolidée
- **Responsable:** myia-po-2023
- **Critère de Validation:** Documentation centralisée
- **Statut:** En attente

### CP2.15: Tests E2E ajoutés
- **Responsable:** myia-po-2026
- **Critère de Validation:** Tests E2E créés
- **Statut:** En attente

---

## Dépendances

- Tâche 2.1 doit être complétée avant Tâche 2.7 (baselines)
- Tâche 2.3 doit être complétée avant Tâche 2.4 (verrouillage)
- Tâche 2.4 doit être complétée avant Tâche 2.5 (conflits d'identité)
- Tâche 2.11 doit être complétée avant Tâche 2.12 (recompilation)
- Tâche 2.13-2.15 doivent être complétées avant CP2.13 (console.log)
- Tâche 2.16-2.18 doivent être complétées avant CP2.14 (documentation)
- Tâche 2.19-2.23 doivent être complétées avant CP2.15 (tests E2E)

---

## Journal des Modifications

| Date | Tâche | Modification | Auteur |
|------|-------|--------------|--------|
| 2026-01-02 | - | Création initiale du document | Roo Architect Mode |

---

## Liens

- **Plan d'action:** [`../../suivi/RooSync/PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md`](../../suivi/RooSync/PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md)
- **Phase 1:** [`PHASE1_DIAGNOSTIC_ET_STABILISATION.md`](PHASE1_DIAGNOSTIC_ET_STABILISATION.md)
- **Architecture RooSync:** [`../ARCHITECTURE_ROOSYNC.md`](../ARCHITECTURE_ROOSYNC.md)
- **Guide d'utilisation RooSync:** [`../GUIDE_UTILISATION_ROOSYNC.md`](../GUIDE_UTILISATION_ROOSYNC.md)
- **Gestion multi-agent:** [`../GESTION_MULTI_AGENT.md`](../GESTION_MULTI_AGENT.md)

---

**Document généré par:** Roo Architect Mode
**Date de génération:** 2026-01-02T11:48:00Z
**Version:** 1.0.0
**Statut:** 🟡 En attente de démarrage

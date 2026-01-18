# Plan de Consolidation des Outils RooSync

**Version:** 1.0
**Date:** 2026-01-18
**Objectif:** Réduire de 33 → ~15-18 outils (-45% à -55%) sans perte de fonctionnalité

---

## 📊 Analyse Actuelle

**Problème identifié:**
Pendant le développement RooSync v2.3, passage de ~23 outils initiaux à **77 fichiers d'outils** (toutes catégories), dont **33 outils RooSync** spécifiquement.

**Impact:**
- 🔴 Asphyxie cognitive - difficile de comprendre quel outil utiliser
- 🔴 Redondance - plusieurs outils font des choses similaires
- 🔴 Maintenance complexe - tests dupliqués, documentation éparpillée
- 🔴 MCP surchargé - trop d'outils exposés aux agents

**Objectif de consolidation:**
- ✅ Regrouper fonctionnalités similaires
- ✅ Interface unifiée avec paramètres `action`
- ✅ Conserver TOUTES les fonctionnalités
- ✅ Migrer tests progressivement

---

## 🎯 Groupes de Consolidation

### Groupe 1 : Messages (7 outils → 3 outils) - PRIORITÉ HIGH

**Outils actuels:**
- `send_message` - Envoyer message
- `reply_message` - Répondre à message
- `amend_message` - Modifier message
- `read_inbox` - Lire boîte réception
- `get_message` - Obtenir message complet
- `mark_message_read` - Marquer comme lu
- `archive_message` - Archiver message

**Consolidation proposée:**

#### 1.1 → `roosync_messages` (actions: send, reply, amend, read, get, mark_read, archive)
Interface unifiée avec paramètre `action`.

**Tâches GitHub:**
- [ ] T-CONS-1.1a : Créer `roosync_messages.ts` avec structure action
- [ ] T-CONS-1.1b : Migrer logique send/reply/amend
- [ ] T-CONS-1.1c : Migrer logique read/get/mark_read/archive
- [ ] T-CONS-1.1d : Migrer tests unitaires (7 fichiers → 1 fichier avec 7 describe)
- [ ] T-CONS-1.1e : Mettre à jour documentation utilisateur
- [ ] T-CONS-1.1f : Déprécier anciens outils (warnings)
- [ ] T-CONS-1.1g : Supprimer anciens outils après 2 semaines

**Estimation:** 5-7 jours (1 semaine)
**Difficulté:** MEDIUM
**Tests à migrer:** ~35-40 tests

---

### Groupe 2 : Heartbeats (6 outils → 2 outils) - PRIORITÉ MEDIUM

**Outils actuels:**
- `register-heartbeat` - Enregistrer heartbeat
- `start-heartbeat-service` - Démarrer service
- `stop-heartbeat-service` - Arrêter service
- `check-heartbeats` - Vérifier heartbeats
- `get-heartbeat-state` - État heartbeat
- `get-warning-machines` - Machines en warning
- `get-offline-machines` - Machines offline
- `sync-on-offline` - Sync quand offline détecté
- `sync-on-online` - Sync quand online détecté

**Consolidation proposée:**

#### 2.1 → `roosync_heartbeat_manage` (actions: register, start, stop)
Gestion du service heartbeat.

#### 2.2 → `roosync_heartbeat_status` (actions: check, get_state, get_warnings, get_offline)
Consultation statut heartbeats.

**Tâches GitHub:**
- [ ] T-CONS-2.1a : Créer `roosync_heartbeat_manage.ts`
- [ ] T-CONS-2.1b : Créer `roosync_heartbeat_status.ts`
- [ ] T-CONS-2.1c : Migrer logique service (register, start, stop)
- [ ] T-CONS-2.1d : Migrer logique status (check, state, warnings, offline)
- [ ] T-CONS-2.1e : Décider du sort de sync-on-offline/online (intégrer ou séparer?)
- [ ] T-CONS-2.1f : Migrer tests unitaires
- [ ] T-CONS-2.1g : Déprécier anciens outils

**Estimation:** 4-5 jours
**Difficulté:** MEDIUM
**Tests à migrer:** ~25-30 tests

---

### Groupe 3 : Config Sharing (4 outils → 4 outils) - PRIORITÉ LOW

**Outils actuels:**
- `collect-config` - Collecter config
- `compare-config` - Comparer configs
- `apply-config` - Appliquer config
- `publish-config` - Publier config

**Consolidation proposée:**
⚠️ **PAS de consolidation recommandée** - Ces 4 outils représentent le workflow critique et sont bien séparés.

**Améliorations possibles:**
- [ ] T-CONS-3.1 : Améliorer documentation workflow (diagramme séquence)
- [ ] T-CONS-3.2 : Ajouter validation paramètres commune
- [ ] T-CONS-3.3 : Harmoniser formats retour

**Estimation:** 2 jours
**Difficulté:** LOW

---

### Groupe 4 : Baseline (3 outils → 1 outil) - PRIORITÉ HIGH

**Outils actuels:**
- `export-baseline` - Exporter baseline
- `manage-baseline` - Gérer baseline (restore, etc.)
- `update-baseline` - Mettre à jour baseline

**Consolidation proposée:**

#### 4.1 → `roosync_baseline` (actions: export, restore, update, list, delete)
Gestion complète des baselines.

**Tâches GitHub:**
- [ ] T-CONS-4.1a : Créer `roosync_baseline.ts` avec actions
- [ ] T-CONS-4.1b : Migrer logique export
- [ ] T-CONS-4.1c : Migrer logique restore/manage
- [ ] T-CONS-4.1d : Migrer logique update
- [ ] T-CONS-4.1e : Migrer tests unitaires
- [ ] T-CONS-4.1f : Déprécier anciens outils

**Estimation:** 3-4 jours
**Difficulté:** MEDIUM
**Tests à migrer:** ~20-25 tests

---

### Groupe 5 : Decisions (5 outils → 2 outils) - PRIORITÉ MEDIUM

**Outils actuels:**
- `approve-decision` - Approuver décision
- `reject-decision` - Rejeter décision
- `rollback-decision` - Rollback décision
- `apply-decision` - Appliquer décision
- `get-decision-details` - Détails décision

**Consolidation proposée:**

#### 5.1 → `roosync_decision_manage` (actions: approve, reject, rollback, apply)
Gestion des décisions.

#### 5.2 → `roosync_decision_status` (actions: get_details, list, history)
Consultation décisions.

**Tâches GitHub:**
- [ ] T-CONS-5.1a : Créer `roosync_decision_manage.ts`
- [ ] T-CONS-5.1b : Créer `roosync_decision_status.ts`
- [ ] T-CONS-5.1c : Migrer logique approve/reject/rollback/apply
- [ ] T-CONS-5.1d : Migrer logique get_details
- [ ] T-CONS-5.1e : Migrer tests unitaires
- [ ] T-CONS-5.1f : Déprécier anciens outils

**Estimation:** 4 jours
**Difficulté:** MEDIUM
**Tests à migrer:** ~30-35 tests (ComplexService avec mocks)

---

### Groupe 6 : Diagnostic (4 outils → 2 outils) - PRIORITÉ LOW

**Outils actuels:**
- `get-status` - État système global
- `list-diffs` - Lister différences config
- `get-machine-inventory` - Inventaire machine
- `debug-reset` - Reset debug (dangereux)

**Consolidation proposée:**

#### 6.1 → `roosync_system_status` (actions: get_status, get_inventory, list_diffs)
Diagnostic système.

#### 6.2 → `roosync_debug_reset` (garder séparé - dangereux)

**Tâches GitHub:**
- [ ] T-CONS-6.1a : Créer `roosync_system_status.ts`
- [ ] T-CONS-6.1b : Migrer logique get-status/inventory/diffs
- [ ] T-CONS-6.1c : Migrer tests unitaires
- [ ] T-CONS-6.1d : Renommer debug-reset → roosync_debug_reset (cohérence)
- [ ] T-CONS-6.1e : Déprécier anciens outils

**Estimation:** 3 jours
**Difficulté:** LOW
**Tests à migrer:** ~15-20 tests

---

### Groupe 7 : Init (1 outil → 1 outil) - PAS DE CONSOLIDATION

**Outil actuel:**
- `init` - Initialiser RooSync

**Action:** Renommer pour cohérence → `roosync_init`

**Tâches GitHub:**
- [ ] T-CONS-7.1 : Renommer init → roosync_init
- [ ] T-CONS-7.2 : Mettre à jour documentation

**Estimation:** 0.5 jour
**Difficulté:** TRIVIAL

---

## 📅 Planning de Consolidation Progressive

### Phase 1 - Fondations (Semaine 1-2) - PRIORITÉ CRITIQUE
**Issues à créer:**
- #CONS-1 : Groupe 1 - Messages (7→3)
- #CONS-4 : Groupe 4 - Baseline (3→1)

**Justification:** Outils les plus utilisés, impact immédiat sur clarté.

**Livrables:**
- `roosync_messages.ts` opérationnel
- `roosync_baseline.ts` opérationnel
- Tests migrés et passants
- Documentation mise à jour

---

### Phase 2 - Services (Semaine 3-4) - PRIORITÉ HAUTE
**Issues à créer:**
- #CONS-2 : Groupe 2 - Heartbeats (6→2)
- #CONS-5 : Groupe 5 - Decisions (5→2)

**Livrables:**
- `roosync_heartbeat_manage.ts` + `roosync_heartbeat_status.ts`
- `roosync_decision_manage.ts` + `roosync_decision_status.ts`
- Tests migrés
- Anciens outils dépréciés

---

### Phase 3 - Finitions (Semaine 5) - PRIORITÉ BASSE
**Issues à créer:**
- #CONS-6 : Groupe 6 - Diagnostic (4→2)
- #CONS-7 : Groupe 7 - Init (renommage)
- #CONS-3 : Groupe 3 - Config amélioration doc

**Livrables:**
- Tous outils consolidés
- Documentation complète
- Guide migration pour utilisateurs

---

### Phase 4 - Nettoyage (Semaine 6)
**Issues à créer:**
- #CONS-CLEAN : Supprimer anciens outils dépréciés
- #CONS-DOC : Consolider documentation finale
- #CONS-TEST : Valider couverture tests E2E

**Livrables:**
- Anciens outils supprimés
- README.md mis à jour avec nouveaux outils
- CHANGELOG v2.4.0

---

## 🎯 Résultats Attendus

### Avant Consolidation
- **Total outils RooSync:** 33
- **Complexité cognitive:** TRÈS ÉLEVÉE
- **Maintenance:** DIFFICILE
- **Nouveaux utilisateurs:** Perdu

### Après Consolidation
- **Total outils RooSync:** 15-18 (réduction 45-55%)
- **Complexité cognitive:** MODÉRÉE
- **Maintenance:** FACILE (logique centralisée)
- **Nouveaux utilisateurs:** Interface claire avec `action`

### Métrique de Succès
- ✅ Réduction ≥ 40% du nombre d'outils
- ✅ Couverture tests maintenue à 95%+
- ✅ Documentation complète par outil consolidé
- ✅ Migration progressive sans casser l'existant
- ✅ Feedback positif utilisateurs (agents Claude/Roo)

---

## 📋 Checklist par Tâche

Pour chaque tâche de consolidation:

- [ ] Créer issue GitHub avec label `consolidation`
- [ ] Analyser logique existante (Read fichiers concernés)
- [ ] Créer nouveau fichier avec structure action
- [ ] Migrer logique progressivement (TDD)
- [ ] Migrer tests unitaires
- [ ] Tester E2E sur machine locale
- [ ] Déprécier anciens outils (warnings logs)
- [ ] Mettre à jour documentation
- [ ] Code review + validation
- [ ] Attendre 2 semaines feedback
- [ ] Supprimer anciens outils
- [ ] Marquer tâche Done

---

## 🔗 Références

**Issues GitHub à créer:**
- #CONS-1 : Consolidation Messages (Groupe 1)
- #CONS-2 : Consolidation Heartbeats (Groupe 2)
- #CONS-3 : Amélioration Config Sharing (Groupe 3)
- #CONS-4 : Consolidation Baseline (Groupe 4)
- #CONS-5 : Consolidation Decisions (Groupe 5)
- #CONS-6 : Consolidation Diagnostic (Groupe 6)
- #CONS-7 : Renommage Init (Groupe 7)
- #CONS-CLEAN : Nettoyage final
- #CONS-DOC : Documentation finale
- #CONS-TEST : Tests E2E validation

**Projet GitHub:**
- Créer Project #71 "RooSync Tools Consolidation"
- Colonnes : Todo, In Progress, Code Review, Testing, Done

**Documentation:**
- `docs/roosync/MIGRATION_GUIDE_V2.3_V2.4.md` - Guide migration utilisateurs
- `docs/roosync/CONSOLIDATION_PATTERNS.md` - Patterns techniques utilisés

---

## 🚀 Phase Post-Consolidation : Séparation MCP RooSync

**⚠️ APRÈS la consolidation complète (Phase 4 terminée)**

### Objectif
Extraire les outils RooSync dans un MCP indépendant `roosync-mcp` séparé de `roo-state-manager`.

### Justification
- **Séparation des responsabilités** : roo-state-manager = gestion state locale, roosync-mcp = coordination multi-machines
- **Déploiement indépendant** : versions RooSync sans toucher roo-state-manager
- **Clarté architecture** : 2 MCPs spécialisés au lieu de 1 monolithe

### Pré-requis CRITIQUES
1. ✅ Consolidation outils terminée (15-18 outils RooSync)
2. ✅ Tests E2E RooSync 100% passants
3. ✅ Documentation consolidée
4. ✅ Déploiement v2.3 complet sur 5 machines

### Tâches GitHub à créer
- [ ] #SPLIT-1 : Créer squelette MCP roosync-mcp
- [ ] #SPLIT-2 : Migrer outils RooSync consolidés (15-18 outils)
- [ ] #SPLIT-3 : Migrer services partagés (RooSyncService, etc.)
- [ ] #SPLIT-4 : Migrer tests unitaires + E2E
- [ ] #SPLIT-5 : Configuration wrapper MCP (comme roo-state-manager)
- [ ] #SPLIT-6 : Documentation déploiement roosync-mcp
- [ ] #SPLIT-7 : Migration progressive 5 machines
- [ ] #SPLIT-8 : Dépréciation roo-state-manager/roosync
- [ ] #SPLIT-9 : Suppression après 1 mois stabilité

### Estimation
- **Durée:** 3-4 semaines
- **Difficulté:** TRÈS ÉLEVÉE (refactoring architecture)
- **Risque:** ÉLEVÉ (migration 5 machines simultanée)

### Référence
**Issue GitHub:** [#311 - Séparer RooSync dans un MCP indépendant](https://github.com/jsboige/roo-extensions/issues/311)

**⚠️ À NE PAS démarrer avant clôture complète consolidation (Phase 4)**

---

---

## 🎯 Assignation Multi-Machine (APRÈS Déploiement RooSync)

**⚠️ IMPORTANT:** Ces tâches seront assignées **APRÈS** mise à flot système (Project #67 → 100% Done)

### Phase 1 - Fondations (Semaine 1-2)

**#CONS-1 : Messages (7→3)** - 7 sous-tâches
- **Assigné:** myia-po-2024 (Roo) + myia-ai-01 (Claude support)
- **Raison:** Machine performante, expérience refactoring

**#CONS-4 : Baseline (3→1)** - 6 sous-tâches
- **Assigné:** myia-po-2023 (Roo) + myia-po-2026 (Claude review)
- **Raison:** Expertise baseline, bon duo

### Phase 2 - Services (Semaine 3-4)

**#CONS-2 : Heartbeats (6→2)** - 7 sous-tâches
- **Assigné:** myia-po-2026 (Roo) + myia-web1 (Claude review)
- **Raison:** Expertise services, machine web légère

**#CONS-5 : Decisions (5→2)** - 6 sous-tâches
- **Assigné:** myia-web1 (Roo) + myia-po-2024 (Claude review)
- **Raison:** Tests complexes, expertise mocking

### Phase 3 - Finitions (Semaine 5)

**#CONS-6 : Diagnostic (4→2)** - 5 sous-tâches
- **Assigné:** myia-po-2023 (Roo) + myia-ai-01 (Claude review)
- **Raison:** Simple, coordination facile

**#CONS-7 : Init (renommage)** - 2 sous-tâches
- **Assigné:** n'importe quelle machine (trivial)

**#CONS-3 : Config amélioration doc** - 3 sous-tâches
- **Assigné:** myia-ai-01 (Claude) + Roo support
- **Raison:** Documentation = Claude spécialité

### Coordination Claude (myia-ai-01)

**Rôle pendant consolidation:**
- Code review toutes PRs
- Vérifier cohérence architecture
- Mettre à jour documentation centrale
- Valider tests E2E après chaque groupe
- Project #67 tracking avancement

---

## 📅 Démarrage de la Consolidation

**Trigger:** Quand Project #67 atteint **100% Done** (77/77 items)

**Conditions pré-requises:**
- ✅ Déploiement RooSync complet (5 machines)
- ✅ Tests E2E 100% passants
- ✅ Workflow collect → compare → apply → publish validé
- ✅ Aucun bug critique ouvert
- ✅ Documentation v2.3 complète

**Création issues:**
1. myia-ai-01 (Claude) crée 7 issues GitHub (#CONS-1 à #CONS-7)
2. Assignation machines via messages RooSync
3. Planning détaillé partagé (ce document)
4. Kick-off coordination

**Labels GitHub:**
- `consolidation`
- `priority-low` (non-bloquant)
- `refactoring`
- `v2.4`

**Projects:**
- Project #67 (tâches techniques Roo)
- Project #70 (coordination Claude - tracking reviews)

---

**Dernière mise à jour:** 2026-01-18
**Auteur:** Claude Code (myia-ai-01)
**Statut:** PLANIFICATION - Démarrage APRÈS déploiement RooSync

**Priorité actuelle:** 🔴 DÉPLOIEMENT D'ABORD (Project #67 → 100%)
**Priorité future:** 🟡 CONSOLIDATION ENSUITE (v2.4)

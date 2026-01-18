# Tâche T2.23 - Tester la gestion des conflits
## Diagnostic et Stratégie

**Date:** 2026-01-18
**Machine:** myia-po-2026
**Projet GitHub:** #67 "RooSync Multi-Agent Tasks"
**Priorité:** MEDIUM
**Agent responsable:** Roo (technique)
**Agent de support:** Claude Code (documentation/coordination)

---

## 1. Analyse de l'architecture de gestion des conflits

### 1.1 Outils RooSync impliqués

L'architecture de gestion des conflits dans RooSync repose sur les outils suivants :

| Outil | Description | Fichier source |
|-------|-------------|----------------|
| `roosync_approve_decision` | Approuve une décision de synchronisation | `src/tools/roosync/approve-decision.ts` |
| `roosync_reject_decision` | Rejette une décision de synchronisation | `src/tools/roosync/reject-decision.ts` |
| `roosync_apply_decision` | Applique une décision approuvée | `src/tools/roosync/apply-decision.ts` |
| `roosync_rollback_decision` | Annule une décision appliquée | `src/tools/roosync/rollback-decision.ts` |
| `roosync_get_decision_details` | Obtient les détails d'une décision | `src/tools/roosync/get-decision-details.ts` |
| `roosync_list_diffs` | Liste les différences détectées | `src/tools/roosync/list-diffs.ts` |

### 1.2 Cycle de vie d'une décision

Les décisions de synchronisation suivent un cycle de vie bien défini :

```
pending → approved → applied → rolled_back
    ↓
  rejected
```

**Statuts possibles :**
- `pending` : Décision créée, en attente d'approbation
- `approved` : Décision approuvée, prête à être appliquée
- `rejected` : Décision rejetée
- `applied` : Décision appliquée avec succès
- `rolled_back` : Décision annulée après application

### 1.3 Mécanisme de détection des conflits

#### 1.3.1 DifferenceDetector

Le service `DifferenceDetector` (`src/services/baseline/DifferenceDetector.ts`) détecte les différences entre configurations et recommande des actions :

**Actions recommandées :**
- `sync_to_baseline` : Synchroniser vers la baseline (CRITICAL, config)
- `keep_target` : Conserver la configuration cible (hardware)
- `manual_review` : Requiert une révision manuelle (software, autres)

**Niveaux de sévérité :**
- `CRITICAL` : Synchronisation obligatoire
- `IMPORTANT` : Synchronisation recommandée
- `WARNING` : Révision manuelle
- `INFO` : Informationnel

#### 1.3.2 IdentityManager

Le service `IdentityManager` (`src/services/roosync/IdentityManager.ts`) gère les conflits d'identité :

- Détection des `machineId` dupliqués
- Validation des fichiers de présence
- Recommandations de résolution

#### 1.3.3 Stratégies de résolution

Les stratégies de résolution de conflits sont définies dans la configuration :

```typescript
type ConflictResolution = 'highest_priority' | 'most_recent' | 'manual';
```

**Stratégies disponibles :**
1. `timestamp` : Utiliser la modification la plus récente
2. `manual` : Exiger une intervention manuelle
3. `merge` : Fusionner les modifications si possible

### 1.4 Stockage des décisions

Les décisions sont stockées dans `sync-roadmap.md` avec le format suivant :

```markdown
<!-- DECISION_BLOCK_START -->
**ID:** `decision-id`
**Titre:** Titre de la décision
**Statut:** pending
**Type:** config | file | setting
**Chemin:** path/to/file
**Machine Source:** MACHINE-ID
**Machines Cibles:** MACHINE-A, MACHINE-B
**Créé:** 2025-10-08T09:00:00Z
**Détails:** Description des changements
<!-- DECISION_BLOCK_END -->
```

Après approbation :
```markdown
**Approuvé le:** 2025-10-08T10:00:00Z
**Approuvé par:** MACHINE-ID
**Commentaire:** Commentaire d'approbation
```

Après application :
```markdown
**Appliqué le:** 2025-10-08T11:00:00Z
**Appliqué par:** MACHINE-ID
**Backup:** path/to/backup
```

Après rollback :
```markdown
**Rollback le:** 2025-10-08T12:00:00Z
**Raison:** Raison du rollback
```

---

## 2. Tests existants

### 2.1 Tests unitaires

Les tests unitaires existants couvrent déjà :

| Fichier | Couverture |
|---------|------------|
| `tests/unit/tools/roosync/approve-decision.test.ts` | Approbation de décisions |
| `tests/unit/tools/roosync/reject-decision.test.ts` | Rejet de décisions |
| `tests/unit/tools/roosync/apply-decision.test.ts` | Application de décisions |
| `tests/unit/tools/roosync/rollback-decision.test.ts` | Rollback de décisions |
| `tests/unit/tools/roosync/get-decision-details.test.ts` | Détails de décisions |
| `tests/unit/services/baseline/DifferenceDetector.test.ts` | Détection de différences |

### 2.2 Tests E2E

Le fichier `tests/e2e/roosync-conflict-management.test.ts` contient déjà des tests E2E pour :

- Conflit d'application simultanée
- Conflit de timestamp
- Propagation des changements multi-machines
- Détection des divergences
- Création de décisions de conflit
- Stratégies de résolution
- Gestion des décisions corrompues
- Détection des doublons
- Gestion des décisions orphelines
- Performance de détection des conflits

**Note :** Ces tests sont principalement des simulations et ne testent pas tous les scénarios de conflits réels.

---

## 3. Scénarios de test à couvrir

### 3.1 Scénarios de conflits de fichiers

#### 3.1.1 Conflit de modification sur le même fichier
**Description :** Deux machines modifient le même fichier simultanément

**Étapes :**
1. Machine A modifie `config.json` (valeur: "a")
2. Machine B modifie `config.json` (valeur: "b")
3. Détection du conflit
4. Création d'une décision de conflit
5. Résolution (manuelle ou automatique)
6. Validation de l'état final

**Attendu :**
- Le conflit est détecté
- Une décision de conflit est créée
- La résolution fonctionne correctement
- L'état final est cohérent

#### 3.1.2 Conflit de suppression vs modification
**Description :** Une machine supprime un fichier pendant qu'une autre le modifie

**Étapes :**
1. Machine A supprime `config.json`
2. Machine B modifie `config.json`
3. Détection du conflit
4. Création d'une décision de conflit
5. Résolution (préserver ou supprimer)
6. Validation de l'état final

**Attendu :**
- Le conflit est détecté
- La résolution préserve l'intégrité
- L'état final est cohérent

#### 3.1.3 Conflit de modification vs suppression
**Description :** Une machine modifie un fichier pendant qu'une autre le supprime

**Étapes :**
1. Machine A modifie `config.json`
2. Machine B supprime `config.json`
3. Détection du conflit
4. Création d'une décision de conflit
5. Résolution (préserver ou supprimer)
6. Validation de l'état final

**Attendu :**
- Le conflit est détecté
- La résolution préserve l'intégrité
- L'état final est cohérent

### 3.2 Scénarios de résolution automatique

#### 3.2.1 Stratégie timestamp
**Description :** Utiliser la modification la plus récente

**Étapes :**
1. Configurer `conflictStrategy: 'timestamp'`
2. Créer un conflit de modification
3. Laisser le système résoudre automatiquement
4. Vérifier que la modification la plus récente est conservée

**Attendu :**
- La résolution automatique fonctionne
- La modification la plus récente est conservée
- Aucune intervention manuelle requise

#### 3.2.2 Stratégie merge
**Description :** Fusionner les modifications si possible

**Étapes :**
1. Configurer `conflictStrategy: 'merge'`
2. Créer un conflit de modification sur des champs différents
3. Laisser le système résoudre automatiquement
4. Vérifier que les modifications sont fusionnées

**Attendu :**
- La fusion fonctionne correctement
- Les deux modifications sont présentes
- Aucune donnée n'est perdue

### 3.3 Scénarios de résolution manuelle

#### 3.3.1 Approbation et rejet de décisions
**Description :** Tester le workflow complet d'approbation/rejet

**Étapes :**
1. Créer une décision de conflit
2. Approuver la décision
3. Appliquer la décision
4. Vérifier l'état final
5. Créer une autre décision
6. Rejeter la décision
7. Vérifier que rien n'est appliqué

**Attendu :**
- L'approbation fonctionne correctement
- Le rejet fonctionne correctement
- L'état final est cohérent

#### 3.3.2 Rollback après résolution
**Description :** Annuler une décision appliquée

**Étapes :**
1. Créer et appliquer une décision
2. Vérifier l'état après application
3. Effectuer un rollback
4. Vérifier que l'état précédent est restauré

**Attendu :**
- Le rollback fonctionne correctement
- L'état précédent est restauré
- Les fichiers sont restaurés depuis le backup

### 3.4 Scénarios de conflits multiples

#### 3.4.1 Conflits simultanés sur plusieurs fichiers
**Description :** Plusieurs conflits sur différents fichiers

**Étapes :**
1. Créer des conflits sur `config.json`, `settings.json`, `modes.json`
2. Détecter tous les conflits
3. Créer des décisions pour chaque conflit
4. Résoudre les conflits dans un ordre spécifique
5. Vérifier l'état final

**Attendu :**
- Tous les conflits sont détectés
- Les décisions sont créées correctement
- La résolution fonctionne pour tous les conflits
- L'état final est cohérent

#### 3.4.2 Conflits en cascade
**Description :** Un conflit en provoque d'autres

**Étapes :**
1. Créer un conflit sur un fichier de configuration
2. Résoudre le conflit
3. Vérifier que cela ne provoque pas de nouveaux conflits
4. Si des conflits secondaires apparaissent, les résoudre
5. Vérifier l'état final

**Attendu :**
- Les conflits en cascade sont gérés correctement
- L'état final est cohérent
- Aucune boucle infinie de conflits

### 3.5 Scénarios de robustesse

#### 3.5.1 Décisions corrompues
**Description :** Gérer les décisions avec un format invalide

**Étapes :**
1. Créer une décision avec un format invalide
2. Tenter de charger la décision
3. Vérifier que le système gère gracieusement l'erreur

**Attendu :**
- L'erreur est gérée gracieusement
- Le système continue de fonctionner
- Les décisions valides ne sont pas affectées

#### 3.5.2 Décisions en double
**Description :** Gérer les décisions avec le même ID

**Étapes :**
1. Créer deux décisions avec le même ID
2. Tenter de charger les décisions
3. Vérifier que le système détecte le doublon

**Attendu :**
- Le doublon est détecté
- Le système gère gracieusement la situation
- Une seule décision est conservée

#### 3.5.3 Décisions orphelines
**Description :** Gérer les décisions sans métadonnées requises

**Étapes :**
1. Créer une décision sans métadonnées requises
2. Tenter de charger la décision
3. Vérifier que le système détecte le problème

**Attendu :**
- Le problème est détecté
- Le système gère gracieusement la situation
- La décision est marquée comme invalide

---

## 4. Stratégie de mise en œuvre

### 4.1 Structure des tests

Les tests seront organisés comme suit :

```
tests/e2e/
└── roosync-conflict-resolution.test.ts  (NOUVEAU)
tests/integration/
└── roosync-conflict-integration.test.ts  (NOUVEAU)
```

### 4.2 Priorité des scénarios

**Phase 1 - Tests E2E (Priorité HAUTE)**
1. Conflit de modification sur le même fichier
2. Conflit de suppression vs modification
3. Conflit de modification vs suppression
4. Approbation et rejet de décisions
5. Rollback après résolution

**Phase 2 - Tests d'intégration (Priorité MOYENNE)**
6. Stratégie timestamp
7. Stratégie merge
8. Conflits simultanés sur plusieurs fichiers
9. Conflits en cascade

**Phase 3 - Tests de robustesse (Priorité BASSE)**
10. Décisions corrompues
11. Décisions en double
12. Décisions orphelines

### 4.3 Approche de développement

1. **Créer les fixtures de test**
   - Configurations de test pour différentes machines
   - Fichiers de test pour les scénarios de conflits
   - États initiaux reproductibles

2. **Implémenter les tests E2E**
   - Utiliser les patterns existants dans `roosync-conflict-management.test.ts`
   - Créer des tests réels (pas seulement des simulations)
   - Utiliser `RooSyncService` pour les opérations

3. **Implémenter les tests d'intégration**
   - Tester l'intégration entre les différents outils
   - Tester les workflows complets
   - Valider les interactions entre machines

4. **Implémenter les tests de robustesse**
   - Tester les cas limites
   - Tester la gestion des erreurs
   - Tester la récupération après erreur

### 4.4 Dépendances et prérequis

**Dépendances techniques :**
- `RooSyncService` déjà implémenté
- Outils RooSync déjà implémentés
- Infrastructure de tests (Vitest) déjà en place

**Dépendances fonctionnelles :**
- Aucune dépendance bloquante identifiée

**Prérequis :**
- Compréhension de l'architecture RooSync
- Connaissance des outils de gestion des conflits
- Familiarité avec les patterns de tests existants

---

## 5. Plan d'action

### Étape 1 : Préparation (15 min)
- [ ] Créer les fixtures de test
- [ ] Préparer les configurations de test
- [ ] Créer les fichiers de test pour les scénarios

### Étape 2 : Tests E2E (45 min)
- [ ] Implémenter le test de conflit de modification
- [ ] Implémenter le test de conflit suppression vs modification
- [ ] Implémenter le test de conflit modification vs suppression
- [ ] Implémenter le test d'approbation/rejet
- [ ] Implémenter le test de rollback

### Étape 3 : Tests d'intégration (30 min)
- [ ] Implémenter le test de stratégie timestamp
- [ ] Implémenter le test de stratégie merge
- [ ] Implémenter le test de conflits multiples
- [ ] Implémenter le test de conflits en cascade

### Étape 4 : Tests de robustesse (20 min)
- [ ] Implémenter le test de décisions corrompues
- [ ] Implémenter le test de décisions en double
- [ ] Implémenter le test de décisions orphelines

### Étape 5 : Validation (15 min)
- [ ] Exécuter tous les tests
- [ ] Corriger les éventuels problèmes
- [ ] Vérifier la couverture des scénarios

### Étape 6 : Documentation et livraison (15 min)
- [ ] Mettre à jour la documentation
- [ ] Committer les changements
- [ ] Pusher les commits
- [ ] Envoyer un message RooSync
- [ ] Mettre à jour l'INTERCOM

**Durée estimée totale : 2h30**

---

## 6. Risques et mitigations

### 6.1 Risques identifiés

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| Tests trop complexes à implémenter | Élevé | Moyenne | Commencer par des tests simples, itérer progressivement |
| Dépendances non testées | Moyen | Faible | Vérifier les dépendances avant l'implémentation |
| Problèmes de performance des tests | Faible | Moyenne | Optimiser les tests, utiliser des mocks si nécessaire |
| Incohérence avec les tests existants | Moyen | Faible | Analyser les tests existants en détail avant l'implémentation |

### 6.2 Plan de contingence

Si les tests E2E s'avèrent trop complexes :
1. Se concentrer sur les tests d'intégration
2. Documenter les scénarios non testés
3. Créer des tickets pour les tests futurs

Si des problèmes de performance surviennent :
1. Utiliser des mocks pour les opérations coûteuses
2. Limiter le nombre de scénarios de test
3. Optimiser les tests existants

---

## 7. Critères de succès

### 7.1 Critères fonctionnels
- [ ] Tous les scénarios de test sont couverts
- [ ] Les tests passent avec succès
- [ ] La couverture de code est satisfaisante (>80%)

### 7.2 Critères de qualité
- [ ] Les tests sont lisibles et maintenables
- [ ] Les tests suivent les patterns existants
- [ ] La documentation est complète et à jour

### 7.3 Critères de livraison
- [ ] Le code est commité et pushé
- [ ] L'issue GitHub est mise à jour
- [ ] Le message RooSync est envoyé
- [ ] L'INTERCOM est mis à jour

---

## 8. Annexes

### 8.1 Références

- Documentation RooSync : `docs/suivi/RooSync/`
- Tests existants : `tests/e2e/roosync-conflict-management.test.ts`
- Outils RooSync : `src/tools/roosync/`
- Services RooSync : `src/services/roosync/`

### 8.2 Glossaire

| Terme | Définition |
|-------|------------|
| Conflit | Situation où deux machines ont des versions différentes du même fichier |
| Décision | Enregistrement d'un changement à synchroniser |
| Résolution | Action de résoudre un conflit |
| Rollback | Annulation d'une décision appliquée |
| Stratégie de résolution | Méthode utilisée pour résoudre automatiquement les conflits |

### 8.3 Historique des modifications

| Date | Version | Auteur | Description |
|------|---------|--------|-------------|
| 2026-01-18 | 1.0.0 | Roo | Création initiale du document |

---

**Fin du document**

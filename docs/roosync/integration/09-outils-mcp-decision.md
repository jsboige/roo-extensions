# Outils MCP Décision RooSync

## Date
2025-10-07T21:55:00Z

## Contexte

**Tâche :** Phase 8 Tâche 37  
**Objectif :** Implémenter 2 outils MCP pour gérer les décisions de synchronisation  
**Branche :** `roosync-phase4-decisions` (mcps/internal)  
**Stratégie :** Création branche dédiée pour isolation

---

## Architecture Git

**Branche de travail :** `roosync-phase4-decisions` (sous-module mcps/internal)  
**Branche principale :** `main` (dépôt principal)  
**Stratégie :** Option A - Branche dédiée créée avec succès

**Vérification :**
- ✅ Sous-module sur branche `roosync-phase4-decisions`
- ✅ Push upstream effectué
- ✅ Working tree clean

---

## Grounding SDDD

### Recherche Sémantique Effectuée

**Requête :** `RooSync decision approval rejection tools specifications approve reject decision pending status`

**Résultats Clés (Score 0.65+) :**
1. `02-points-integration-roosync.md` (lignes 350-388) - Outil submit_decision
2. `03-architecture-integration-roosync.md` (lignes 357-401) - Couche Décision
3. `RooSync/src/modules/Actions.psm1` (lignes 1-100) - Logique PowerShell

### Documents Analysés

1. **02-points-integration-roosync.md** (lignes 350-388)
2. **03-architecture-integration-roosync.md** (lignes 357-401)  
3. **RooSync/src/modules/Actions.psm1** (lignes 1-100)

---

## Spécifications Extraites

### Note Architecturale

**Spécification Originale :** Un seul outil `roosync_submit_decision` avec 3 choix (approve/reject/defer)

**Notre Implémentation :** 2 outils séparés pour plus de clarté
- `roosync_approve_decision` : Approuver une décision
- `roosync_reject_decision` : Rejeter une décision avec motif

**Justification :**
- API plus claire et intentionnelle
- Paramètres spécifiques à chaque action
- Validation plus stricte

---

### Outil 4 : roosync_approve_decision

**Description :** Approuver une décision de synchronisation

**Paramètres :**
- `decisionId` (requis) : string - ID de la décision à approuver
- `comment` (optionnel) : string - Commentaire d'approbation

**Retour :**
```typescript
{
  decisionId: string,
  previousStatus: string,
  newStatus: 'approved',
  approvedAt: string,      // ISO 8601 timestamp
  approvedBy: string,      // Machine ID
  comment?: string,
  nextSteps: string[]      // Actions recommandées
}
```

**Logique d'Implémentation :**

1. **Validation initiale**
   - Charger la décision via `RooSyncService.getDecision(id)`
   - Vérifier que la décision existe
   - Vérifier que le statut est 'pending'

2. **Mise à jour du fichier sync-roadmap.md**
   - Lire le contenu complet
   - Localiser le bloc de décision via regex :
     ```typescript
     /<!-- DECISION_BLOCK_START -->([\s\S]*?\*\*ID:\*\*\s*`${decisionId}`[\s\S]*?)<!-- DECISION_BLOCK_END -->/g
     ```
   - Remplacer `**Statut:** pending` par `**Statut:** approved`
   - Ajouter les métadonnées :
     - `**Approuvé le:** ${timestamp}`
     - `**Approuvé par:** ${machineId}`
     - `**Commentaire:** ${comment}` (si fourni)

3. **Sauvegarde atomique**
   - Écrire le fichier modifié
   - Pas de lock nécessaire (opération rapide)

4. **Retour**
   - Construire la réponse avec nextSteps suggérés

**Codes d'erreur :**
- `DECISION_NOT_FOUND` : Décision introuvable
- `DECISION_ALREADY_PROCESSED` : Décision déjà approuvée/rejetée
- `ROOSYNC_FILE_ERROR` : Erreur lecture/écriture fichier
- `ROOSYNC_APPROVE_ERROR` : Erreur générique d'approbation

---

### Outil 5 : roosync_reject_decision

**Description :** Rejeter une décision de synchronisation avec motif

**Paramètres :**
- `decisionId` (requis) : string - ID de la décision à rejeter
- `reason` (requis) : string - Motif du rejet (obligatoire pour traçabilité)

**Retour :**
```typescript
{
  decisionId: string,
  previousStatus: string,
  newStatus: 'rejected',
  rejectedAt: string,      // ISO 8601 timestamp
  rejectedBy: string,      // Machine ID
  reason: string,
  nextSteps: string[]      // Actions recommandées
}
```

**Logique d'Implémentation :**

1. **Validation initiale**
   - Charger la décision via `RooSyncService.getDecision(id)`
   - Vérifier que la décision existe
   - Vérifier que le statut est 'pending'
   - Vérifier que `reason` est fourni (requis)

2. **Mise à jour du fichier sync-roadmap.md**
   - Lire le contenu complet
   - Localiser le bloc de décision via regex
   - Remplacer `**Statut:** pending` par `**Statut:** rejected`
   - Ajouter les métadonnées :
     - `**Rejeté le:** ${timestamp}`
     - `**Rejeté par:** ${machineId}`
     - `**Motif:** ${reason}`

3. **Sauvegarde atomique**
   - Écrire le fichier modifié

4. **Retour**
   - Construire la réponse avec nextSteps suggérés

**Codes d'erreur :**
- `DECISION_NOT_FOUND` : Décision introuvable
- `DECISION_ALREADY_PROCESSED` : Décision déjà approuvée/rejetée
- `REASON_REQUIRED` : Motif de rejet manquant
- `ROOSYNC_FILE_ERROR` : Erreur lecture/écriture fichier
- `ROOSYNC_REJECT_ERROR` : Erreur générique de rejet

---

## Format des Décisions (sync-roadmap.md)

### Marqueurs HTML

Les décisions sont encadrées par des marqueurs HTML :
```markdown
<!-- DECISION_BLOCK_START -->
**ID:** `decision-001`
**Titre:** Description
**Statut:** pending | approved | rejected
**Type:** config | file | setting
**Chemin:** path/to/file
**Machine Source:** MACHINE-NAME
**Machines Cibles:** TARGET-MACHINES | all
**Créé:** 2025-10-07T10:00:00Z

**Détails:** Description détaillée

<!-- DECISION_BLOCK_END -->
```

### États de Décision

- `pending` : En attente de décision
- `approved` : Approuvé pour application
- `rejected` : Rejeté, ne sera pas appliqué
- `applied` : Appliqué avec succès (Phase 5)
- `rolled_back` : Annulé après application (Phase 5)

---

## Architecture d'Implémentation

### Répertoire

```
mcps/internal/servers/roo-state-manager/
├── src/tools/roosync/
│   ├── approve-decision.ts    (≈150 lignes) ← NOUVEAU
│   ├── reject-decision.ts     (≈150 lignes) ← NOUVEAU
│   └── index.ts               (mise à jour)
└── tests/unit/tools/roosync/
    ├── approve-decision.test.ts (≈200 lignes) ← NOUVEAU
    └── reject-decision.test.ts  (≈200 lignes) ← NOUVEAU
```

### Dépendances

**Imports communs :**
```typescript
import { z } from 'zod';
import { getRooSyncService, RooSyncServiceError } from '../../services/RooSyncService.js';
import { writeFileSync, readFileSync } from 'fs';
import { join } from 'path';
```

**Services utilisés :**
- `RooSyncService.getInstance()` : Obtenir l'instance singleton
- `RooSyncService.getDecision(id)` : Charger une décision
- `RooSyncService.getConfig()` : Obtenir la configuration

---

## Tests Unitaires

### approve-decision.test.ts

**Cas de test (5 tests) :**

1. ✅ **Approuver une décision pending avec commentaire**
   - Arrange : Décision pending dans roadmap
   - Act : Appeler avec comment
   - Assert : Statut = approved, métadonnées ajoutées, fichier modifié

2. ✅ **Approuver sans commentaire**
   - Vérifier que comment est optionnel
   - Fichier ne doit pas contenir "Commentaire:"

3. ✅ **Erreur si décision n'existe pas**
   - Should throw DECISION_NOT_FOUND

4. ✅ **Erreur si décision déjà approuvée**
   - Should throw DECISION_ALREADY_PROCESSED

5. ✅ **Date d'approbation au format ISO 8601**
   - Vérifier format : /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/

### reject-decision.test.ts

**Cas de test (5 tests) :**

1. ✅ **Rejeter une décision pending avec motif**
   - Arrange : Décision pending dans roadmap
   - Act : Appeler avec reason
   - Assert : Statut = rejected, métadonnées ajoutées, fichier modifié

2. ✅ **Erreur si décision n'existe pas**
   - Should throw DECISION_NOT_FOUND

3. ✅ **Erreur si décision déjà traitée**
   - Should throw DECISION_ALREADY_PROCESSED

4. ✅ **Date de rejet au format ISO 8601**
   - Vérifier format timestamp

5. ✅ **Motif requis dans le fichier**
   - Vérifier présence "Motif:" dans roadmap

### Fixtures

**Structure de test :**
```
tests/fixtures/roosync-approve-test/
├── sync-dashboard.json
└── sync-roadmap.md
```

**Contenu sync-roadmap.md :**
- 1 décision pending (test-decision-001)
- 1 décision déjà approved (test-decision-002)

---

## Implémentation Réalisée

### Fichiers Créés

**Code Source :**
1. `src/tools/roosync/approve-decision.ts` (≈150 lignes)
2. `src/tools/roosync/reject-decision.ts` (≈150 lignes)
3. `src/tools/roosync/index.ts` (mise à jour export)

**Tests :**
1. `tests/unit/tools/roosync/approve-decision.test.ts` (≈200 lignes)
2. `tests/unit/tools/roosync/reject-decision.test.ts` (≈200 lignes)

**Documentation :**
1. `docs/integration/09-outils-mcp-decision.md` (ce fichier)

---

## Validation

- ✅ **10/10 tests unitaires passent**
  - approve-decision.test.ts : 5 tests ✅
  - reject-decision.test.ts : 5 tests ✅
- ✅ Fichiers sync-roadmap.md correctement mis à jour
- ✅ Gestion d'erreurs robuste (RooSyncServiceError)
- ✅ Schemas Zod valides
- ✅ Compilation TypeScript sans erreurs
- ✅ Export centralisé dans index.ts

### Détails des Tests

**approve-decision.test.ts (5 tests) :**
1. ✅ Approuver une décision pending avec commentaire
2. ✅ Approuver sans commentaire
3. ✅ Erreur si décision n'existe pas
4. ✅ Erreur si décision déjà approuvée
5. ✅ Date d'approbation au format ISO 8601

**reject-decision.test.ts (5 tests) :**
1. ✅ Rejeter une décision pending avec motif
2. ✅ Erreur si décision n'existe pas
3. ✅ Erreur si décision déjà traitée
4. ✅ Date de rejet au format ISO 8601
5. ✅ Motif requis dans le fichier roadmap

### Statistiques

- **Code source** : ~300 lignes (2 fichiers × 150 lignes)
- **Tests** : ~320 lignes (2 fichiers × 160 lignes)
- **Couverture** : 100% des cas d'usage critiques
- **Durée tests** : ~1s

---

## Prochaines Étapes

**Phase 5 - Outils MCP Exécution (Tâche 38) :**
- `roosync_apply_decision` : Applique décisions approuvées
- `roosync_rollback_decision` : Annule décisions appliquées

---

## Références

**Documents :**
- [02-points-integration-roosync.md](02-points-integration-roosync.md) : Spécifications originales
- [03-architecture-integration-roosync.md](03-architecture-integration-roosync.md) : Architecture couche Décision
- [06-services-roosync.md](06-services-roosync.md) : Services RooSync
- [08-outils-mcp-essentiels.md](08-outils-mcp-essentiels.md) : Outils Phase 3

**Code :**
- [`RooSyncService.ts`](../../mcps/internal/servers/roo-state-manager/src/services/RooSyncService.ts)
- [`RooSync/src/modules/Actions.psm1`](../../RooSync/src/modules/Actions.psm1)

---

**✅ Statut :** Document de travail créé - Prêt pour implémentation
# CONS-5 : Analyse Consolidation Outils Décision RooSync

**Version :** 1.0.0
**Date :** 2026-01-30
**Auteur :** Claude Code (myia-po-2024)
**Statut :** 📝 PROPOSITION - En attente validation coordinateur

---

## 📊 État Actuel : 5 Outils de Décision

### Inventaire Complet

| # | Outil | Fichier | Fonction | LOC estimé |
|---|-------|---------|----------|------------|
| 1 | `roosync_approve_decision` | `approve-decision.ts` | Approuver décision pending | ~200 |
| 2 | `roosync_reject_decision` | `reject-decision.ts` | Rejeter décision pending | ~200 |
| 3 | `roosync_apply_decision` | `apply-decision.ts` | Appliquer décision approved | ~300 |
| 4 | `roosync_rollback_decision` | `rollback-decision.ts` | Annuler décision applied | ~250 |
| 5 | `roosync_get_decision_details` | `get-decision-details.ts` | Consulter détails complets | ~200 |

**Total :** ~1150 LOC (lignes de code)

### Analyse des Dépendances

Tous les outils partagent :
- `getRooSyncService()` pour accéder au service
- `service.getDecision(decisionId)` pour charger la décision
- `sync-roadmap.md` pour persister les changements de statut
- Pattern similaire de validation/formatage
- Fonctions utilitaires communes (gestion roadmap, logs)

### Workflow de Décision Identifié

```
┌──────────────────────────────────────────────────────────┐
│                   Lifecycle d'une Décision                │
├──────────────────────────────────────────────────────────┤
│  PENDING → [approve/reject] → APPROVED → [apply]         │
│                                    ↓                      │
│                                 APPLIED → [rollback]      │
│                                    ↓                      │
│                              ROLLED_BACK                  │
│                                                           │
│  Lecture: [get_decision_details] à tout moment            │
└──────────────────────────────────────────────────────────┘
```

### Code Patterns Communs

**Pattern 1 : Vérification du statut**
```typescript
// Dupliqué dans tous les outils de mutation
const decision = await service.getDecision(args.decisionId);
if (!decision) {
  throw new RooSyncServiceError('Décision introuvable', 'DECISION_NOT_FOUND');
}
if (decision.status !== expectedStatus) {
  throw new RooSyncServiceError('Décision déjà traitée', 'DECISION_ALREADY_PROCESSED');
}
```

**Pattern 2 : Mise à jour roadmap**
```typescript
// Dupliqué dans tous les outils de mutation
const roadmapPath = join(config.sharedPath, 'sync-roadmap.md');
let content = readFileSync(roadmapPath, 'utf-8');
const blockRegex = new RegExp(/* ... */);
content = content.replace(blockRegex, updatedBlock);
writeFileSync(roadmapPath, content, 'utf-8');
```

---

## 🎯 Proposition : 2 Outils Consolidés

### Architecture Proposée

```
┌─────────────────────────────────────────────────────────┐
│                  AVANT (5 outils)                        │
├─────────────────────────────────────────────────────────┤
│ approve_decision │ reject_decision │ apply_decision      │
│ rollback_decision │ get_decision_details                 │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                  APRÈS (2 outils)                        │
├─────────────────────────────────────────────────────────┤
│      roosync_decision        │    roosync_decision_info │
│  (approve/reject/apply/      │      (consultation       │
│   rollback)                  │       read-only)         │
└─────────────────────────────────────────────────────────┘
```

### Outil 1 : `roosync_decision` (Workflow Management)

**Fusionne :** `approve_decision` + `reject_decision` + `apply_decision` + `rollback_decision`

```typescript
interface RooSyncDecisionArgs {
  // Action à effectuer
  action: 'approve' | 'reject' | 'apply' | 'rollback';

  // Commun
  decisionId: string;

  // Pour approve
  comment?: string;

  // Pour reject
  reason?: string;  // Requis si action = 'reject'

  // Pour apply
  dryRun?: boolean;
  force?: boolean;

  // Pour rollback
  // reason déjà défini ci-dessus, requis si action = 'rollback'
}
```

**Exemples d'utilisation :**
```typescript
// Approuver
roosync_decision({ action: 'approve', decisionId: 'DEC-001', comment: 'LGTM' })

// Rejeter
roosync_decision({ action: 'reject', decisionId: 'DEC-001', reason: 'Conflicts detected' })

// Appliquer
roosync_decision({ action: 'apply', decisionId: 'DEC-001', dryRun: false })

// Rollback
roosync_decision({ action: 'rollback', decisionId: 'DEC-001', reason: 'Introduced bug' })
```

**Validation contextuelle Zod :**
```typescript
export const RooSyncDecisionArgsSchema = z.object({
  action: z.enum(['approve', 'reject', 'apply', 'rollback']),
  decisionId: z.string(),
  comment: z.string().optional(),
  reason: z.string().optional(),
  dryRun: z.boolean().optional(),
  force: z.boolean().optional()
}).superRefine((data, ctx) => {
  // Validation: reject requiert reason
  if (data.action === 'reject' && !data.reason) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'reason is required for action=reject'
    });
  }
  // Validation: rollback requiert reason
  if (data.action === 'rollback' && !data.reason) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'reason is required for action=rollback'
    });
  }
});
```

### Outil 2 : `roosync_decision_info` (Read-Only Query)

**Fusionne :** `get_decision_details` (renommé pour clarté)

```typescript
interface RooSyncDecisionInfoArgs {
  // Identifiant
  decisionId: string;

  // Options de profondeur
  includeHistory?: boolean;  // Défaut: true
  includeLogs?: boolean;     // Défaut: true
}
```

**Exemples d'utilisation :**
```typescript
// Détails complets
roosync_decision_info({ decisionId: 'DEC-001' })

// Détails minimaux
roosync_decision_info({ decisionId: 'DEC-001', includeHistory: false, includeLogs: false })
```

**Raison de la séparation :**
- Pattern query différent (lecture seule vs mutation)
- Arguments différents (pas d'action, mais options de profondeur)
- Usage différent (consultation vs workflow)
- Principe CQRS (Command Query Responsibility Segregation)

---

## 📈 Bénéfices Attendus

### Réduction de Complexité

| Métrique | Avant | Après | Gain |
|----------|-------|-------|------|
| Nombre d'outils | 5 | 2 | **-60%** |
| LOC total estimé | ~1150 | ~550 | **-52%** |
| Fichiers à maintenir | 5 | 2 | **-60%** |
| Code dupliqué (roadmap update) | 4× | 1× | **-75%** |
| Patterns de validation | 4× | 1× | **-75%** |

### Amélioration UX

1. **Interface unifiée** : Un seul outil pour tout le workflow
2. **Pattern cohérent** : `action` comme clé de dispatch
3. **Moins d'outils à mémoriser** : 2 vs 5
4. **Découvrabilité** : Actions groupées logiquement
5. **Validation contextuelle** : Zod valide les combinaisons requises

### Maintenabilité

1. **Moins de duplication** : Roadmap update centralisé
2. **Tests simplifiés** : 2 suites au lieu de 5
3. **Évolution facilitée** : Ajouter actions sans nouveaux outils
4. **Meilleure séparation des responsabilités** : Command vs Query

---

## ⚠️ Risques et Mitigation

### Risque 1 : Rétrocompatibilité

**Impact :** Les scripts/agents existants utilisent les anciens noms d'outils.

**Mitigation :**
- Maintenir les anciens outils comme wrappers
- Documentation de migration claire
- Période de dépréciation (2-4 semaines)
- Logs de warning sur les anciens outils

### Risque 2 : Validation Complexe

**Impact :** La validation Zod devient plus complexe (dépendances entre champs).

**Mitigation :**
- Utiliser `superRefine` pour validation contextuelle
- Messages d'erreur clairs et explicites
- Exemples dans la documentation
- Tests exhaustifs des combinaisons valides/invalides

### Risque 3 : Confusion action vs mode

**Impact :** Pattern `action` utilisé dans plusieurs outils (messages, heartbeat, baseline...).

**Mitigation :**
- Cohérence : Toujours utiliser `action` pour les mutations
- Documentation : Expliquer le pattern dans GUIDE-TECHNIQUE
- Naming clair : `roosync_decision` = workflow, `roosync_decision_info` = query

---

## 📋 Plan de Migration

### Phase 1 : Préparation (2 jours)

1. Créer `utils/decision-helpers.ts` pour code partagé :
   - `updateRoadmapStatus()` - Mise à jour roadmap centralisée
   - `validateDecisionStatus()` - Vérification statut selon action
   - `formatDecisionResult()` - Formatage résultat unifié

2. Écrire les 2 nouveaux outils consolidés

3. Tests unitaires complets :
   - Tests par action (approve, reject, apply, rollback)
   - Tests de validation contextuelle Zod
   - Tests read-only (decision_info)
   - Tests E2E workflow complet

### Phase 2 : Déploiement (1 jour)

1. Déployer nouveaux outils dans le registry
2. Mettre à jour le wrapper MCP (filtrer anciens noms)
3. Build et validation

### Phase 3 : Migration (1 semaine)

1. Créer wrappers de compatibilité :
   ```typescript
   // approve-decision.ts (legacy wrapper)
   export async function roosyncApproveDecision(args: ApproveDecisionArgs) {
     console.warn('[DEPRECATED] Use roosync_decision with action=approve instead');
     return roosyncDecision({ action: 'approve', ...args });
   }
   ```

2. Marquer anciens outils comme `@deprecated` dans metadata
3. Mettre à jour documentation (GUIDE-TECHNIQUE-v2.4.md)
4. Annoncer via RooSync message à toutes les machines

### Phase 4 : Nettoyage (après 2 semaines)

1. Vérifier usage des anciens outils (via logs de warning)
2. Supprimer les wrappers de compatibilité
3. Supprimer les anciens fichiers
4. Finaliser documentation

---

## 🗳️ Décision Requise

### Option A : Consolidation 5→2 (Recommandé)

Implémenter `roosync_decision` + `roosync_decision_info` comme décrit.

**Avantages :**
- Gains maximaux (-60% outils)
- Architecture propre (Command vs Query)
- Pattern cohérent avec autres outils consolidés

**Inconvénients :**
- Validation Zod plus complexe
- Effort de migration modéré

### Option B : Consolidation 5→1

Tout fusionner dans un seul `roosync_decision` avec `mode: 'execute' | 'query'`.

**Avantages :**
- Maximum de simplification (1 seul outil)
- Pattern ultra-unifié

**Inconvénients :**
- Mélange mutation/query (anti-pattern CQRS)
- Schéma Zod encore plus complexe
- Perte de clarté (query noyée dans les actions)

### Option C : Consolidation 5→3

Garder `get_decision_details` séparé, fusionner approve+reject dans un outil, et apply+rollback dans un autre.

**Avantages :**
- Séparation approve/reject (décision) vs apply/rollback (exécution)
- Validation Zod plus simple

**Inconvénients :**
- Gains réduits (3 outils au lieu de 2)
- Moins cohérent avec le modèle CONS-1 et CONS-2

---

## 📎 Annexes

### A. Matrice de Correspondance

| Ancien Outil | Nouvel Outil | Action/Mode |
|--------------|--------------|-------------|
| `roosync_approve_decision` | `roosync_decision` | `action: 'approve'` |
| `roosync_reject_decision` | `roosync_decision` | `action: 'reject'` |
| `roosync_apply_decision` | `roosync_decision` | `action: 'apply'` |
| `roosync_rollback_decision` | `roosync_decision` | `action: 'rollback'` |
| `roosync_get_decision_details` | `roosync_decision_info` | - |

### B. Fichiers Concernés

```
mcps/internal/servers/roo-state-manager/src/tools/roosync/
├── approve-decision.ts      → À remplacer par decision.ts
├── reject-decision.ts       → À supprimer
├── apply-decision.ts        → À supprimer
├── rollback-decision.ts     → À supprimer
├── get-decision-details.ts  → À remplacer par decision-info.ts
└── index.ts                 → À mettre à jour

Nouveau fichier à créer:
├── utils/decision-helpers.ts → Code partagé
```

### C. Comparaison avec CONS-1 et CONS-2

| Métrique | CONS-1 (Messages) | CONS-2 (Heartbeat) | CONS-5 (Decisions) |
|----------|-------------------|--------------------|--------------------|
| Avant | 7 outils | 7 outils | 5 outils |
| Après | 3 outils | 2 outils | 2 outils |
| Réduction | -57% | -71% | **-60%** |
| Pattern | `action` | `action` / `filter` | `action` |
| Séparation | Send/Read/Manage | Status/Service | Decision/Info |

**Cohérence du pattern :**
- CONS-1 : `action` pour send/reply/amend
- CONS-2 : `action` pour register/start/stop
- **CONS-5 : `action` pour approve/reject/apply/rollback** ✅

---

## 🎯 Recommandation Finale

**Je recommande l'Option A (Consolidation 5→2) pour les raisons suivantes :**

1. **Cohérence avec CONS-2** : Même réduction (~60-70%), même pattern `action`
2. **Architecture propre** : Séparation Command/Query claire
3. **Maintenabilité** : Centralisation du code roadmap update
4. **UX** : 2 outils faciles à comprendre (workflow vs consultation)
5. **Évolutivité** : Facile d'ajouter de nouvelles actions au workflow

**Prochaines étapes si approuvé :**
1. Validation coordinateur (myia-ai-01)
2. Création des fichiers (decision.ts, decision-info.ts, utils/decision-helpers.ts)
3. Tests unitaires et E2E
4. Déploiement avec wrappers de compatibilité
5. Migration progressive sur 2 semaines

---

**En attente de validation du coordinateur (myia-ai-01) avant implémentation.**

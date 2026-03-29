# Warnings NoTools - conversation_browser

**Version :** 2.0.0
**Créé :** 2026-03-15
**Mis à jour :** 2026-03-28
**Issue :** #710
**Fix :** #881 (NoTools → alias Compact)
**Issue suivi :** #946, #952

---

## BUG ORIGINAL (RESOLVU par #881)

**AVANT #881 :** `detailLevel: "NoTools"` masquait seulement les paramètres d'appels d'outils mais **gardait TOUS les résultats d'outils complets** → explosion 309 KB+ pour 23 messages.

**APRES #881 :** `NoTools` est maintenant un **alias vers `Compact`**, qui résume les résultats d'outils (nom + statut + taille) au lieu d'inclure le contenu complet.

**Source du fix :** `src/services/reporting/DetailLevelStrategyFactory.ts`

---

## Niveaux `detailLevel` (8 niveaux)

| Niveau | Contenu | Quand l'utiliser |
| ------ | ------- | ---------------- |
| `Full` | Tout inclus | JAMAIS (explosion massive) |
| `NoToolParams` | Messages + résultats complets (params masqués) | Debug uniquement |
| **`Compact`** | Messages + outils résumés (nom + statut + taille) | Recommandé (#881) |
| **`NoTools`** | **Alias vers `Compact`** (depuis #881) | Maintenant sûr |
| `NoResults` | Messages + params (sans résultats) | Vérifier le flow |
| `Messages` | Messages seulement | Analyse structurelle |
| `Summary` | Vue condensée | Recommandé |
| `UserOnly` | Messages utilisateur seulement | Audit rapide |

**Note :** `NoTools` et `Compact` produisent un résultat identique depuis #881.

---

## Recommandation

**Toujours utiliser cette combinaison pour des résumés compacts :**

```typescript
conversation_browser(
  action: "summarize",
  summarize_type: "trace",      // "trace" pour statistiques
  detailLevel: "Compact",       // ou "Summary" ou "NoTools" (alias Compact)
  truncationChars: 10000,       // OBLIGATOIRE - limite chars
  taskId: "..."                 // ou taskIds pour clusters
)
```

---

## Règle d'Or

**TOUJOURS définir `truncationChars`** quand `summarize_type != "trace"`.

```typescript
// BON - Limité à 10000 chars
conversation_browser(action: "summarize", detailLevel: "Compact", truncationChars: 10000)

// BON - NoTools est maintenant sûr (alias Compact)
conversation_browser(action: "summarize", detailLevel: "NoTools", truncationChars: 10000)

// MAUVAIS - Pas de limite, risque explosion même avec Compact
conversation_browser(action: "summarize", detailLevel: "Compact")

// MAUVAIS - JAMAIS Full (massif)
conversation_browser(action: "summarize", detailLevel: "Full")
```

---

## Quand utiliser `trace`

**`summarize_type: "trace"` génère automatiquement des stats lisibles :**
- Nombre de messages par type (User/Assistant/Tool)
- Taille compression avant/après
- Breakdown par catégorie

=> Utiliser `trace` pour les rapports métriques, pas pour le contenu détaillé.

---

**Référence :** [`.claude/rules/sddd-conversational-grounding.md`](../../.claude/rules/sddd-conversational-grounding.md) - Section "Recommandations conversation_browser (CRITIQUE #608)"

**Issues :** #608, #710, #881 (fix), #946, #952

# Warnings NoTools - conversation_browser

**Version :** 1.1.0
**Créé :** 2026-03-15
**MAJ :** 2026-03-30 (#952 — fix #881 appliqué, incohérences corrigées)
**Issue :** #710

---

## ✅ FIX #881 APPLIQUÉ

`detailLevel: "NoTools"` est maintenant un alias vers `Compact` qui **résume** les résultats d'outils (nom + statut + taille, pas le contenu complet). Le problème d'explosion est résolu.

---

## Cause Racine (historique, pré-fix #881)

1. **`NoTools` était mal nommé** : Il masquait SEULEMENT les paramètres d'appels d'outils, mais **gardait TOUS les résultats complets**. Depuis #881, `NoTools` = alias vers `Compact`.
2. **`truncationChars` défaut = 0** : Pas de limite de caractères par défaut. Toujours le spécifier.

---

## Résultat Réel (post-fix #881)

| Paramètres | Contenu | Taille |
|------------|---------|--------|
| `NoTools` (post-fix #881) | ✅ Alias vers Compact — résumé outils | ~5-10 KB (utilisable) |
| `Summary` + `truncationChars: 10000` | ✅ COMPACT | ~3 KB (recommandé) |
| `NoTools` (pré-fix #881) | ❌ EXPLOSION (historique) | ~300 KB |

---

## Recommandation STRICTE

**Toujours utiliser cette combinaison pour des résumés compacts :**

```typescript
conversation_browser(
  action: "summarize",
  summarize_type: "trace",      // "trace" pour statistiques
  detailLevel: "Summary",         // Ou "NoTools" (alias Compact depuis #881)
  truncationChars: 10000,         // OBLIGATOIRE - limite chars
  taskId: "..."                   // ou taskIds pour clusters
)
```

---

## Niveaux `detailLevel` Réels

| Niveau | Contenu | Quand l'utiliser |
|--------|---------|------------------|
| `Full` | Tout inclus | ❌ JAMAIS (explosion) |
| `NoTools` | ✅ FIXÉ — Alias vers Compact (résumé outils) | ✅ Maintenant OK (#881) |
| `Compact` | Messages + outils résumés (nom + statut) | ✅ Recommandé (#881) |
| `NoToolParams` | Ancien NoTools (params masqués, résultats complets) | ⚠️ Pour debug uniquement |
| `NoResults` | Messages + params (sans résultats) | ✅ Compact |
| `Messages` | Messages seulement | ✅ Très compact |
| `Summary` | Vue condensée | ✅ RECOMMANDÉ |
| `UserOnly` | Messages utilisateur seulement | ✅ Plus compact |

---

## Règle d'Or

**TOUJOURS définir `truncationChars`** quand `summarize_type != "trace"`.

```typescript
// BON - Limité à 10000 chars
conversation_browser(action: "summarize", detailLevel: "Summary", truncationChars: 10000)

// MAUVAIS - Pas de limite, risque explosion
conversation_browser(action: "summarize", detailLevel: "Summary")

// OK (post-fix #881) - Alias vers Compact, résumé outils
conversation_browser(action: "summarize", detailLevel: "NoTools")
```

---

## Quand utiliser `trace`

**`summarize_type: "trace"` génère automatiquement des stats lisibles :**
- Nombre de messages par type (User/Assistant/Tool)
- Taille compression avant/après
- Breakdown par catégorie

⇒ Utiliser `trace` pour les rapports métriques, pas pour le contenu détaillé.

---

**Référence :** [`.claude/rules/sddd-grounding.md`](../../.claude/rules/sddd-grounding.md) - Section conversation_browser (CRITIQUE #608)

**Issue :** #608, #881, #952

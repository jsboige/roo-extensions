# Warnings NoTools - conversation_browser

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #710

---

## ✅ FIX #881 APPLIQUÉ

`detailLevel: "NoTools"` est maintenant un alias vers `Compact` qui **résume** les résultats d'outils (nom + statut + taille, pas le contenu complet). Le problème d'explosion est résolu.

---

## Cause Racine

1. **`NoTools` est mal nommé** : Il masque SEULEMENT les paramètres d'appels d'outils, mais **garde TOUS les résultats d'outils complets**.
2. **`truncationChars` défaut = 0** : Pas de limite de caractères par défaut.

---

## Résultat Réel

| Paramètres | Contenu | Taille |
|------------|---------|--------|
| `NoTools` sans truncation | ❌ EXPLOSION | ~300 KB (309 569 chars pour 23 messages) |
| `Summary` + `truncationChars: 10000` | ✅ COMPACT | ~3 KB (utilisable) |

---

## Recommandation STRICTE

**Toujours utiliser cette combinaison pour des résumés compacts :**

```typescript
conversation_browser(
  action: "summarize",
  summarize_type: "trace",      // "trace" pour statistiques
  detailLevel: "Summary",         // PAS "NoTools" (trompeur)
  truncationChars: 10000,         // OBLIGATOIRE - limite chars
  taskId: "..."                   // ou taskIds pour clusters
)
```

---

## Niveaux `detailLevel` Réels

| Niveau | Contenu | Quand l'utiliser |
|--------|---------|------------------|
| `Full` | Tout inclus | ❌ JAMAIS (explosion, massif) |
| `NoTools` | ✅ FIXÉ — Alias vers Compact (résumé outils) | ✅ Maintenant OK (#881) |
| `NoResults` | Messages + params (sans résultats) | Pour vérifier le flow |
| `Messages` | Messages seulement | Pour analyse structurelle |
| `Summary` | Vue condensée | ✅ RECOMMANDÉ |
| `UserOnly` | Messages utilisateur seulement | Pour audit rapide |

---

## Règle d'Or

**TOUJOURS définir `truncationChars`** quand `summarize_type != "trace"`.

```typescript
// BON - Limité à 10000 chars
conversation_browser(action: "summarize", detailLevel: "Summary", truncationChars: 10000)

// MAUVAIS - Pas de limite, risque explosion
conversation_browser(action: "summarize", detailLevel: "Summary")

// MAUVAIS - Trompeur, masque seulement params
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

**Référence :** [`.claude/rules/sddd-conversational-grounding.md`](../../.claude/rules/sddd-conversational-grounding.md) - Section "Recommandations conversation_browser (CRITIQUE #608)"

**Issue :** #608

# codebase_search Patterns - Guide Pratique

**Version:** 1.0.0
**Date:** 2026-02-25
**Issue:** #530

---

## Principe

`codebase_search` utilise des embeddings vectoriels (Qdrant) pour rechercher par **concept** dans le code. Les chunks sont ~1000 chars (tree-sitter AST). Une seule requête ne suffit souvent pas.

---

## Protocole Multi-Pass (RECOMMANDÉ)

### Pass 1 - Requête conceptuelle large (sans directory_prefix)

Identifier le répertoire/module pertinent avec des termes génériques en **anglais**:

```
codebase_search(query: "message sending inter-machine communication", workspace: "d:\\roo-extensions")
```

Analyser les `file_path` des résultats pour identifier les préfixes communs.

### Pass 2 - Zoom avec directory_prefix (vocabulaire du code)

Cibler le module avec du vocabulaire spécifique (noms de fonctions, classes):

```
codebase_search(
  query: "format result success message sent priority timestamp",
  workspace: "d:\\roo-extensions",
  directory_prefix: "mcps/internal/servers/roo-state-manager/src/tools/roosync"
)
```

### Pass 3 - Grep de confirmation

Confirmer avec une recherche exacte:

```
Grep(pattern: "function handleSendMessage", path: "mcps/internal/servers/roo-state-manager/src")
```

---

## 10 Requêtes Validées

| # | Requête (EN) | directory_prefix | Cible | Score |
|---|--------------|------------------|-------|-------|
| 1 | `"narrative context builder parent child"` | `mcps/internal/.../src/services` | NarrativeContextBuilderService.ts | 0.88 ✅ |
| 2 | `"granular diff detection baseline compare"` | `mcps/internal/.../src/services` | GranularDiffDetector.ts | 0.87 ✅ |
| 3 | `"heartbeat registration machine online offline"` | `mcps/internal/.../src/tools/roosync` | heartbeat.ts | 0.80 ⚠️ |
| 4 | `"config sharing publish compare baseline"` | `mcps/internal/.../src/services` | ConfigSharingService.ts | 0.78 ⚠️ |
| 5 | `"trace summary export render markdown"` | `mcps/internal/.../src/services` | TraceSummaryService.ts | 0.77 ⚠️ |
| 6 | `"storage info workspace detection path"` | `mcps/internal/.../src/tools` | storage-info.tool.ts | 0.82 ⚠️ |
| 7 | `"RooSync message send reply amend action"` | `mcps/internal/.../src/tools/roosync` | send.ts | 0.73 ⚠️ |
| 8 | `"baseline version management create restore"` | `mcps/internal/.../src/tools/roosync` | baseline.ts | 0.74 ⚠️ |
| 9 | `"conversation tree hierarchy reconstruction parent"` | `mcps/internal/.../src/services` | hierarchy-reconstruction-engine.ts | 0.81 ⚠️ |
| 10 | `"vector indexer Qdrant embedding upsert batch"` | `mcps/internal/.../src/services` | VectorIndexer.ts | 0.93 ❌ |

**Score global:** 2/10 excellent, 5/10 partial, 3/10 fail

---

## Patterns qui Échouent

### ❌ Requêtes en français

```
codebase_search(query: "envoyer un message entre machines")
```

**Raison:** Les embeddings sont entraînés sur du code anglophone.

### ❌ Vocabulaire trop générique

```
codebase_search(query: "utility helper function")
```

**Raison:** Trop de fichiers correspondent, bruit élevé.

### ❌ directory_prefix incomplet

```
directory_prefix: "src/services"  // ❌ Trop vague
directory_prefix: "mcps/internal/servers/roo-state-manager/src/services"  // ✅ Complet
```

### ❌ Fichiers i18n/test qui polluent

```
// Résultats pollués par:
// - src/i18n/translations/*.json
// - src/**/__tests__/*.test.ts
// - src/**/__fixtures__/*.json
```

**Solution:** Utiliser `directory_prefix` pour exclure ces répertoires.

---

## Tips

1. **Toujours en anglais** - Code et embeddings sont anglophones
2. **Vocabulaire du code > langage naturel** - Préférer `"sendMessage"` à `"send a message"`
3. **Noms concrets** - Inclure noms de fonctions, classes, variables
4. **Pas trop long** - 5-10 mots clés, pas des phrases complètes
5. **`directory_prefix` divise par ~10** - Toujours l'utiliser en Pass 2

---

## Quand utiliser chaque approche

| Situation | Approche |
|-----------|----------|
| Fichier/fonction connus | Grep direct (pas besoin de sémantique) |
| Concept connu, localisation inconnue | Pass 1 → Pass 2 |
| Exploration d'un domaine | Pass 1 seule (analyser les résultats) |
| Fichier introuvable après Pass 2 | Pass 3 (Grep) puis Pass 4 (variante) |
| Validation post-implémentation | Pass 1 avec le concept implémenté |

---

## Références

- **Issue:** #530
- **Règle SDDD:** `.claude/rules/sddd-conversational-grounding.md`
- **Collection Qdrant:** `ws-3091d0dd` (~212K vecteurs sur ai-01)

---

**Dernière mise à jour:** 2026-02-25
**Mainteneur:** myia-po-2023

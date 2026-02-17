# Guide d'utilisation - codebase_search (Recherche Sémantique)

**Version:** 1.0.0
**Date:** 2026-02-17
**Auteur:** Claude Code (myia-po-2023)

---

## Vue d'ensemble

`codebase_search` est un outil MCP qui permet d'effectuer des recherches sémantiques dans le code du workspace, en utilisant les collections Qdrant créées et maintenues par Roo Code.

**Contrairement à une recherche textuelle (grep), `codebase_search` comprend le contexte et les concepts.**

---

## Prérequis

### 1. Roo Code doit être installé et activé

Le workspace doit avoir été ouvert au moins une fois dans VS Code avec l'extension Roo Code activée.

### 2. Indexation du workspace par Roo

Roo Code indexe automatiquement les workspaces ouverts. Cette indexation crée une collection Qdrant spécifique au workspace.

**Nom de la collection :** `ws-XXXXXXXXXXXXXXXX` (16 premiers caractères du SHA256 du chemin du workspace)

**Pour vérifier si le workspace est indexé :**

```bash
# Via l'outil codebase_search
codebase_search(query: "test", workspace: "D:/path/to/workspace")

# Si la réponse contient "collection_not_found", le workspace n'est pas indexé
```

### 3. Variables d'environnement configurées

Dans `.env` du projet `roo-state-manager` :

```bash
QDRANT_URL=https://qdrant.myia.io
QDRANT_API_KEY=<votre clé>
OPENAI_API_KEY=<votre clé>
```

---

## Utilisation

### Syntaxe de base

```json
{
  "query": "rate limiting for embeddings",
  "workspace": "D:/Dev/roo-extensions",  // Optionnel (défaut: cwd)
  "limit": 10,                            // Optionnel (défaut: 10, max: 30)
  "min_score": 0.5,                       // Optionnel (défaut: 0.5)
  "directory_prefix": "src/services"      // Optionnel (filtre par répertoire)
}
```

### Exemples de requêtes

**Recherche de concept :**
```json
{
  "query": "authentication middleware"
}
```

**Recherche spécifique à un répertoire :**
```json
{
  "query": "Qdrant vector operations",
  "directory_prefix": "src/services/qdrant"
}
```

**Recherche avec score minimum plus élevé :**
```json
{
  "query": "heartbeat monitoring",
  "min_score": 0.7
}
```

---

## Format de réponse

### Succès

```json
{
  "status": "success",
  "query": "heartbeat",
  "workspace": "D:/Dev/roo-extensions",
  "collection": "ws-2bd90d69e58de2b4",
  "results_count": 5,
  "min_score_used": 0.5,
  "results": [
    {
      "file_path": "src/services/health/heartbeat.ts",
      "score": 0.89,
      "relevance": "excellent",
      "snippet": "function checkHeartbeat() { ... }",
      "lines": "45-67"
    },
    ...
  ]
}
```

### Erreurs

**Collection non trouvée :**
```json
{
  "status": "collection_not_found",
  "message": "Collection Qdrant \"ws-XXX\" non trouvée",
  "hint": "Le workspace doit être indexé par Roo Code avant de pouvoir effectuer des recherches."
}
```

**Erreur de connexion Qdrant :**
```json
{
  "status": "qdrant_connection_error",
  "message": "Impossible de se connecter à Qdrant.",
  "hint": "Vérifiez que Qdrant est accessible et que QDRANT_URL est configuré."
}
```

---

## Interprétation des scores

| Score | Relevance | Signification |
|-------|-----------|---------------|
| 0.9+ | excellent | Match très proche, résultat très pertinent |
| 0.75-0.9 | good | Bon match, probablement pertinent |
| 0.6-0.75 | moderate | Match moyen, possiblement pertinent |
| 0.4-0.6 | weak | Match faible, peut être pertinent |
| <0.4 | marginal | Match marginal, rarement pertinent |

**Score par défaut :** 0.5 (filtre les résultats faibles)

---

## Validation cross-machine (Issue #474)

### État actuel (2026-02-17)

| Machine | État indexation | État validation |
|---------|-----------------|-----------------|
| myia-po-2023 | Non indexé | ⏳ En attente |
| myia-ai-01 | À vérifier | ⏳ En attente |
| myia-po-2024 | À vérifier | ⏳ En attente |
| myia-po-2025 | À vérifier | ⏳ En attente |
| myia-po-2026 | À vérifier | ⏳ En attente |
| myia-web1 | À vérifier | ⏳ En attente |

### Collections Qdrant existantes

20 collections `ws-XXXXXXXXXXXXXXXX` existent sur Qdrant, mais **toutes sont vides** (0 vecteurs).

**Conclusion :** Les workspaces ont été ouverts dans Roo Code, mais l'indexation n'a pas peuplé les collections.

### Actions requises

1. **Pour chaque machine :**
   - Ouvrir VS Code avec le workspace `roo-extensions`
   - S'assurer que Roo Code est activé
   - Attendre que l'indexation soit complète (peut prendre plusieurs minutes)

2. **Validation :**
   - Exécuter `codebase_search(query: "heartbeat")`
   - Vérifier que la réponse contient des résultats avec score > 0.5

---

## Dépannage

### Problème : Collection non trouvée

**Cause :** Le workspace n'a jamais été ouvert dans VS Code avec Roo activé.

**Solution :**
1. Ouvrir VS Code
2. S'assurer que Roo Code est activé
3. Ouvrir le workspace
4. Attendre l'indexation automatique (ou la déclencher manuellement si disponible)

### Problème : Collection existe mais 0 résultats

**Cause :** La collection existe mais n'a pas été peuplée (indexation incomplète).

**Solution :**
1. Vérifier que Roo Code est toujours actif
2. Redémarrer VS Code
3. Attendre que l'indexation se termine

### Problème : Erreur de connexion Qdrant

**Cause :** Variables d'environnement manquantes ou incorrectes.

**Solution :**
1. Vérifier que `.env` contient `QDRANT_URL` et `QDRANT_API_KEY`
2. Vérifier que Qdrant est accessible (`curl https://qdrant.myia.io`)

---

## Références

- **Issue #474 :** Validation recherche sémantique Qdrant + codebase_search cross-machine
- **Issue #452 :** Outil d'exploitation de l'index sémantique Roo pour Claude Code
- **Issue #453 :** Qdrant + embeddings configurables (Phase 1-3 DONE)
- **Code source :** `mcps/internal/servers/roo-state-manager/src/tools/search/search-codebase.tool.ts`

---

## Historique

| Date | Action | Auteur |
|------|--------|--------|
| 2026-02-17 | Création du guide + Validation myia-po-2023 | Claude Code (myia-po-2023) |

---

*Pour toute question ou problème, créer une issue sur GitHub ou contacter le coordinateur (myia-ai-01).*

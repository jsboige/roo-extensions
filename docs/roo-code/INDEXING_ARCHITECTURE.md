# Architecture d'Indexation Sémantique Roo

**Dernière mise à jour :** 2026-02-12
**Auteur :** Claude Code (myia-po-2025)
**Issue :** [#452](https://github.com/jsboige/roo-extensions/issues/452)

---

## 📚 Vue d'Ensemble

Roo possède un moteur d'indexation sémantique robuste qui génère des collections Qdrant pour tous les workspaces. Ce système permet la recherche sémantique de code via l'outil `codebase_search`.

**Migration récente :** Ancien système OpenAI embeddings → **Qwen 3 4B** (2026-02)

---

## 🏗️ Architecture Globale

```
┌─────────────────────────────────────────────────────────┐
│                  CodeIndexOrchestrator                   │
│  (Coordonne l'indexation : scan initial + file watcher)  │
└─────────────────┬───────────────────────────────────────┘
                  │
     ┌────────────┼────────────┬────────────┐
     ▼            ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ Scanner  │ │ Watcher  │ │ Embedder │ │  Qdrant  │
│  (Scan   │ │ (Watch   │ │ (Qwen 3  │ │ (Vector  │
│  initial)│ │  files)  │ │   4B)    │ │  Store)  │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
```

---

## 🔧 Composants Clés

### 1. CodeIndexOrchestrator

**Fichier :** `src/services/code-index/orchestrator.ts`

**Responsabilités :**
- Démarre le scan initial du workspace
- Initialise le file watcher pour les changements
- Coordonne l'indexation batch (regroupement de fichiers)
- Gère les états d'indexation (Indexing, Indexed, Error)

**Workflow :**
1. **Scan initial** : `DirectoryScanner` parcourt tous les fichiers
2. **Chunking** : Découpe le code en morceaux (chunks)
3. **Embedding** : Génère vecteurs via embedder (Qwen 3 4B)
4. **Stockage** : Insère dans Qdrant
5. **Watch** : File watcher surveille les changements

---

### 2. QdrantVectorStore

**Fichier :** `src/services/code-index/vector-store/qdrant-client.ts`

**Configuration :**
- **URL par défaut** : `http://localhost:6333`
- **Collection naming** : `ws-<sha256(workspacePath).substring(0,16)>`
  - Exemple : `ws-a3f2d1c5b4e6f7a8` pour un workspace donné
- **Distance metric** : Cosine
- **Vector size** : Variable (dépend de l'embedder)
  - Qwen 3 4B : **1024 dimensions** (estimé)

**Payload Structure :**
```typescript
interface Payload {
  filePath: string     // Chemin relatif au workspace
  codeChunk: string    // Morceau de code indexé
  startLine: number    // Ligne de début (1-indexed)
  endLine: number      // Ligne de fin (1-indexed)
  [key: string]: any   // Métadonnées additionnelles possibles
}
```

**Méthodes principales :**
- `initialize()` : Crée la collection si nécessaire
- `search(queryVector, directoryPrefix?, minScore?, maxResults?)` : Recherche vectorielle
- `upsert(points)` : Insère/met à jour des points
- `deleteByFilePath(filePath)` : Supprime points d'un fichier

---

### 3. Embedders

**Fichiers :** `src/services/code-index/embedders/`

**Embedders disponibles :**
- **Qwen 3 4B** (actuel) : `openai-compatible.ts` → Qwen via API compatible
- **OpenAI** : `openai.ts` (déprécié)
- **Mistral** : `mistral.ts`
- **Gemini** : `gemini.ts`
- **Bedrock** : `bedrock.ts`
- **Ollama** : `ollama.ts`
- **OpenRouter** : `openrouter.ts`
- **Vercel AI Gateway** : `vercel-ai-gateway.ts`

**Migration Qwen 3 4B :**
- Date : 2026-02
- Raison : Remplacement OpenAI small embedding (quota dépassé)
- Anciennes collections OpenAI vidées dans Qdrant
- Réindexation en cours (~24h estimé pour toutes les machines)

---

### 4. codebase_search Tool

**Fichiers :**
- `src/core/tools/CodebaseSearchTool.ts` (implémentation backend)
- `src/core/prompts/tools/native-tools/codebase_search.ts` (définition prompt)

**API de l'outil :**
```xml
<codebase_search>
  <searchQuery>natural language query</searchQuery>
  <directoryPrefix>optional/path/to/search</directoryPrefix>
</codebase_search>
```

**Paramètres de recherche :**
- `DEFAULT_MAX_SEARCH_RESULTS` : Limite de résultats (constants/index.ts)
- `DEFAULT_SEARCH_MIN_SCORE` : Score minimal de similarité
- `directoryPrefix` : Filtre optionnel par sous-répertoire

**Retour :**
```json
{
  "results": [
    {
      "filePath": "src/file.ts",
      "codeChunk": "...",
      "startLine": 42,
      "endLine": 55,
      "score": 0.87
    }
  ]
}
```

---

## 🔍 Workflow d'Indexation

### Scan Initial

1. **Détection workspace** : `vscode.workspace.workspaceFolders`
2. **Configuration** : Lecture config via `CodeIndexConfigManager`
3. **Scan** : `DirectoryScanner` parcourt fichiers (respect .gitignore)
4. **Chunking** : Découpe fichiers en chunks (stratégie selon type de fichier)
5. **Embedding** : Génération vecteurs via embedder (batch par 100)
6. **Upload Qdrant** : Insertion dans collection workspace

### File Watcher

1. **Événements VS Code** : `vscode.workspace.onDidChangeTextDocument`, etc.
2. **Batch processing** : Regroupe changements (debounce ~500ms)
3. **Mise à jour Qdrant** :
   - Fichier modifié : Supprime anciens points + insère nouveaux
   - Fichier supprimé : Supprime tous points associés
   - Fichier créé : Insère nouveaux points

---

## 🎯 Stratégie de Chunking

**Non documenté dans le code exploré** - Investigation nécessaire.

**Hypothèses (à valider) :**
- Chunking par fonction/classe pour languages supportés (TypeScript, Python, etc.)
- Chunking par lignes fixes pour fichiers texte
- Overlap entre chunks pour continuité sémantique ?

**Action requise** : Explorer `src/services/code-index/processors/scanner.ts` pour détails.

---

## 📊 État Actuel (2026-02-12)

| Composant | État | Notes |
|-----------|------|-------|
| **Qdrant** | ✅ Opérationnel | 7,223,167 vecteurs indexés |
| **Embedder** | ✅ Qwen 3 4B | Migration complétée |
| **Collections** | 🔄 Réindexation | ~24h estimé (toutes machines) |
| **codebase_search** | ✅ Fonctionnel | Utilisable par Roo |
| **Claude Code** | ❌ Pas d'accès | **Objectif de l'issue #452** |

---

## 🚀 Pour Accès depuis Claude Code

### Option A : MCP Server Dédié

**Avantages :**
- Séparation claire des responsabilités
- Réutilisable pour autres agents
- API bien définie

**Inconvénients :**
- Nouveau serveur à maintenir
- Overhead de communication MCP

**Outils proposés :**
- `search_codebase(query, workspace?, directoryPrefix?, maxResults?)`
- `get_similar_code(filePath, startLine, endLine, maxResults?)`
- `find_by_concept(concept, maxResults?)`

---

### Option B : Extension roo-state-manager

**Avantages :**
- Consolidation avec outils existants
- Moins de overhead

**Inconvénients :**
- Élargit scope de roo-state-manager
- Mélange concerns (state management vs code search)

**Outils proposés :**
- `roosync_semantic_search(query, workspace?, ...)`
- `roosync_code_similarity(filePath, startLine, endLine, ...)`

---

### Option C : Client Qdrant Direct

**Avantages :**
- Flexibilité maximale
- Pas de contrainte MCP
- Accès direct aux collections

**Inconvénients :**
- Plus de code côté Claude
- Moins réutilisable
- Duplicate logic avec Roo

---

## 🔬 Investigation Requise

### Prochaines Étapes

1. **Analyse collections Qdrant** :
   ```bash
   curl http://localhost:6333/collections
   ```
   - Lister collections actives
   - Vérifier schéma vecteurs (dimension exacte)
   - Analyser payload samples

2. **Test codebase_search** :
   - Tester outil Roo existant
   - Mesurer temps de réponse
   - Identifier limitations

3. **Étude chunking** :
   - Lire `scanner.ts` pour comprendre stratégie
   - Mesurer taille moyenne des chunks
   - Évaluer qualité des résultats

4. **Benchmark embeddings** :
   - Dimension exacte Qwen 3 4B
   - Vitesse génération embeddings
   - Qualité recherche vs OpenAI

---

## 📝 Références

- **Issue #452** : [MCP] Outil d'exploitation index sémantique
- **Code source** : `roo-code/src/services/code-index/`
- **Qdrant docs** : https://qdrant.tech/documentation/
- **Qwen 3 4B** : https://huggingface.co/Qwen/Qwen3-4B

---

**Notes :**
- Ce document sera mis à jour au fur et à mesure de l'investigation
- Les hypothèses doivent être validées par test empirique
- Les choix d'architecture (A/B/C) seront discutés avec le coordinateur

---

**Built with Claude Code (Opus 4.6) 🤖**

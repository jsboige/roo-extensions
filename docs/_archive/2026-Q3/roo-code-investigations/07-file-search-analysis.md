> **Archived 2026-07-21** — W6 #2883 (Epic #2877 livrable #2).
>
> **Source:** `roo-code-customization/investigations/07-file-search-analysis.md` · **Last commit:** `4692173c` (2025-08-07) · **Theme:** incident-analysis
>
> **Preservation:** git history (`git show 4692173c:roo-code-customization/investigations/07-file-search-analysis.md`) + this archive copy. No content modified — move-only.
>
> **Incoming links:** 0 functional navigation links. Only audit inventories (#2876 doc-audit, #2886 broken-links, #2896 W6-investigations) and `docs/knowledge/WORKSPACE_KNOWLEDGE.md` arborescence cartography reference this file — all point-in-time mentions that remain valid post-archive.
>
> **Superseded by:** historical file-search incident analysis, superseded by current file-search implementation.

# Investigation : Diagnostiquer et Corriger la Recherche de Fichiers

**Date d'investigation :** 04/08/2025  
**Investigateur :** Roo Debug Complex  
**Fichier cible :** [`roo-code/src/services/search/file-search.ts`](../../roo-code/src/services/search/file-search.ts)

## Contexte du Problème

La fonctionnalité de recherche de fichiers dans l'extension `roo-code` échoue de manière intermittente. Nous suspectons un problème d'échappement des arguments passés à l'exécutable `ripgrep`, notamment avec des chemins de fichiers ou des termes de recherche contenant des caractères spéciaux.

Un point de log `[DIAGNOSTIC-SEARCH]` est déjà en place dans le fichier à la ligne 27 pour afficher la commande exacte qui est exécutée.

## Plan d'Investigation

### 1. Analyse de l'Implémentation Actuelle

**Code actuel identifié :**
```typescript
// Ligne 27-28 dans file-search.ts
console.log(`[DIAGNOSTIC-SEARCH] Spawning ripgrep. Command: '${rgPath}', Args: ${JSON.stringify(args)}`)
const rgProcess = childProcess.spawn(rgPath, args)
```

**Problème potentiel identifié :**
- Les arguments sont passés directement à `childProcess.spawn()` sans échappement
- Sur Windows, les chemins avec espaces ou caractères spéciaux peuvent causer des problèmes
- La fonction `spawn()` ne gère pas automatiquement l'échappement des arguments

### 2. Scénarios de Test à Couvrir

Je vais tester les cas suivants, notoirement difficiles :

1. **Chemins avec espaces :**
   - `C:\Program Files\mon projet\fichier.txt`
   - `./dossier avec espaces/file.js`

2. **Chemins avec caractères accentués :**
   - `./dossier-éléphant/café.ts`
   - `./répertoire/naïve.json`

3. **Chemins avec caractères spéciaux :**
   - `./special-chars\&$@#/file.txt`
   - `./parenthèses (test)/fichier.md`

4. **Termes de recherche complexes :**
   - Expressions régulières avec caractères spéciaux
   - Recherches avec guillemets et apostrophes

### 3. Méthode de Test

Je vais créer un script de test temporaire qui :
- Importe la fonction `executeRipgrep` depuis `file-search.ts`
- Teste les différents scénarios problématiques
- Capture et analyse la sortie `[DIAGNOSTIC-SEARCH]`
- Documente les commandes `ripgrep` générées

### 4. Analyse Attendue

Je m'attends à trouver :
- Des arguments mal échappés dans la commande ripgrep
- Des erreurs de parsing sur Windows avec certains types de chemins
- Des problèmes de guillemets manquants ou incorrects

### 5. Correctifs Envisagés

Selon les résultats, les solutions possibles incluent :
- Utilisation de l'option `shell: true` avec échappement approprié
- Implémentation d'une fonction d'échappement des arguments
- Normalisation des chemins avec `path.normalize()`
- Utilisation de la bibliothèque `cross-spawn` pour la compatibilité multi-plateforme

## Résultats d'Investigation

### Analyse du Code Source

**Problèmes identifiés dans `file-search.ts` :**

1. **Ligne 28** : `childProcess.spawn(rgPath, args)` - Arguments passés sans échappement
2. **Lignes 93-105** : Dans `executeRipgrepForFiles`, le `workspacePath` est ajouté directement aux arguments sans échappement

**Exemple de commande ripgrep problématique générée :**
```typescript
// Pour un workspace: "C:\Program Files\mon projet"
args = [
  "--files", "--follow", "--hidden",
  "-g", "!**/node_modules/**",
  "-g", "!**/.git/**",
  "-g", "!**/out/**",
  "-g", "!**/dist/**",
  "C:\\Program Files\\mon projet"  // ❌ PROBLÈME: chemin avec espaces non échappé
]
```

**Problèmes identifiés dans `ripgrep/index.ts` :**

1. **Ligne 101** : `childProcess.spawn(bin, args)` - Même problème d'arguments non échappés
2. **Ligne 153** : Dans `regexSearchFiles`, le `directoryPath` et `regex` sont passés sans échappement

**Exemple de commande ripgrep problématique :**
```typescript
// Pour un regex: "TODO:" et directoryPath: "./dossier avec espaces"
args = [
  "--json", "-e", "TODO:", "--glob", "*.ts", "--context", "1",
  "./dossier avec espaces"  // ❌ PROBLÈME: chemin avec espaces non échappé
]
```

### Cas d'Échec Identifiés

1. **Chemins avec espaces** : `C:\Program Files\projet` → Interprété comme 2 arguments séparés
2. **Caractères spéciaux** : `./special-chars&$@#/` → Caractères interprétés par le shell
3. **Guillemets dans les chemins** : `./dossier"test"/` → Problème de parsing des guillemets
4. **Caractères Unicode** : `./dossier-éléphant/café.ts` → Problèmes d'encodage potentiels

### Correctif Proposé

**Description :** Implémentation d'une fonction d'échappement des arguments et utilisation de chemins absolus normalisés.

**Stratégie :**
1. Normaliser tous les chemins avec `path.resolve()`
2. Échapper les arguments contenant des espaces ou caractères spéciaux
3. Utiliser une fonction d'échappement cross-platform
4. Ajouter des logs de diagnostic améliorés

### Test de Validation Théorique

**Nouveaux arguments générés (attendus) :**
```typescript
// Après correctif pour "C:\Program Files\mon projet"
args = [
  "--files", "--follow", "--hidden",
  "-g", "!**/node_modules/**",
  "-g", "!**/.git/**",
  "-g", "!**/out/**",
  "-g", "!**/dist/**",
  "C:\\Program Files\\mon projet"  // ✅ Correctement échappé/quoted si nécessaire
]
```

## Conclusion Préliminaire

Le problème provient de l'absence d'échappement des arguments passés à `childProcess.spawn()`. Les chemins contenant des espaces ou des caractères spéciaux sont mal interprétés par ripgrep, causant des échecs de recherche intermittents.

**Solution recommandée :** Implémentation d'une fonction d'échappement cross-platform et normalisation des chemins.

---

**Status :** 🔍 Analyse terminée
**Prochaine étape :** Implémentation du correctif
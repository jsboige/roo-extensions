---
name: validate
description: Valide que le code compile et que les tests passent pour roo-extensions (roo-state-manager). Utilise ce skill après des modifications de code TypeScript, avant un commit, ou pour diagnostiquer des erreurs de build et de tests. Phrase déclencheur : "valide", "lance les tests", "vérifie le build", "CI local".
metadata:
  author: "Roo Extensions Team"
  version: "2.0.0"
  compatibility:
    surfaces: ["claude-code", "claude.ai"]
    restrictions: "Requiert accès au workspace roo-state-manager"
---

# Skill : Validate (Build & Tests) - Override roo-extensions

> **Override projet** : Surcharge la skill globale `~/.claude/skills/validate/SKILL.md`.
> Template generique : `.claude/configs/skills/validate/SKILL.md`

Valide que le code compile et que les tests passent pour **roo-state-manager**.

---

## Quand utiliser

- Apres des modifications de code dans `mcps/internal/servers/roo-state-manager/`
- Pendant un tour de sync (Phase 3)
- Avant un commit pour verifier que rien n'est casse
- Pour diagnostiquer des erreurs de build ou de tests

---

## Workflow

### Phase 0 : Grounding Sémantique (Bookend Début)

**OBLIGATOIRE avant toute validation.**

```
codebase_search(query: "build tests validation typescript vitest", workspace: "d:\\roo-extensions")
```

But : Identifier les fichiers de test récents, les configs vitest, et les patterns de test existants.

### Etape 1 : Build TypeScript (check only)

```bash
cd mcps/internal/servers/roo-state-manager && npx tsc --noEmit
```

- Si succes : passer a l'etape 2
- Si erreurs : les lister avec fichier:ligne, corriger les erreurs simples (imports, typos), relancer

### Etape 2 : Tests unitaires

```bash
cd mcps/internal/servers/roo-state-manager && npx vitest run
```

**JAMAIS `npm test`** qui bloque en mode watch interactif !

**⚠️ CONTRAINTE RAM 2GB (myia-web1) :**

Sur les machines avec 2GB RAM (comme myia-web1), les tests peuvent échouer avec "JavaScript heap out of memory". Utiliser :

```bash
cd mcps/internal/servers/roo-state-manager && npx vitest run --maxWorkers=1
```

Si cela échoue encore, réduire encore :
```bash
cd mcps/internal/servers/roo-state-manager && npx vitest run --reporter=verbose --no-coverage --maxWorkers=1
```

### Etape 3 : Rapport

**Format texte (par défaut) :**
Produire un rapport concis :

```
## Validation Build & Tests

### Build
- Status : SUCCESS | FAILED (X erreurs)
- Erreurs corrigees : [liste si applicable]

### Tests
- Total : X tests
- Pass : Y
- Skip : Z
- Fail : W

### Erreurs a corriger
| Fichier | Ligne | Erreur |
|---------|-------|--------|
| ... | ... | ... |
```

**Format JSON (optionnel, pour parsing automatisé) :**
```bash
# Si demande ou pour integration CI/CD
cd mcps/internal/servers/roo-state-manager && npx vitest run --reporter=json > vitest-report.json
```

Le rapport JSON contient :
- `testResults` : Tableau de tous les tests avec status
- `stats` : Total, pass, skip, fail
- `errors` : Détails des erreurs avec stack traces

---

## Variantes

### Validation rapide (defaut)

Build check + tests complets.

### Validation avec couverture

```bash
cd mcps/internal/servers/roo-state-manager && npx vitest run --coverage
```

### Tests d'un fichier specifique

```bash
cd mcps/internal/servers/roo-state-manager && npx vitest run src/tools/roosync/__tests__/<fichier>.test.ts
```

### Tests par pattern

```bash
cd mcps/internal/servers/roo-state-manager && npx vitest run --testNamePattern="<pattern>"
```

---

## Regles

- Toujours lancer le build AVANT les tests
- Reporter les erreurs avec fichier:ligne pour faciliter la correction
- Corrections simples (typos, imports manquants) : corriger directement et relancer
- Erreurs complexes (logique, architecture) : lister et laisser la decision a la conversation principale
- Ne JAMAIS ignorer un test qui echoue sans explication

## Apres modification de code MCP

**Si du code a ete modifie dans `mcps/internal/servers/roo-state-manager/` :**

1. **Build complet** (pas juste `--noEmit`) : `npm run build` (output dans `build/`, PAS `dist/`)
2. **Tests** : `npx vitest run`
3. **Redemarrage VS Code OBLIGATOIRE** pour que les nouveaux outils MCP soient charges
   - Les MCPs sont charges au demarrage de VS Code uniquement
   - Sans redemarrage, les anciens outils restent en memoire
   - Signaler a l'utilisateur : "Un redemarrage VS Code est necessaire pour charger les modifications MCP"

## Erreurs connues a ignorer

- **3 EmbeddingValidator failures** : Pre-existants, dus a `EMBEDDING_DIMENSIONS=2560` dans `.env`. Non-bloquants.
- **Tests skipped** : Normaux (14 skipped actuellement), correspondent a des tests conditionnels.

---

## Phase 4 : Validation Sémantique (Bookend Fin)

**OBLIGATOIRE après toute validation réussie.**

```
codebase_search(query: "test results validation build success", workspace: "d:\\roo-extensions")
```

But : Confirmer que les fichiers de test et les résultats sont cohérents avec l'index. Si le bookend début avait identifié des fichiers, vérifier qu'ils sont toujours présents dans les résultats.

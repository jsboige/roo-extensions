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

### Etape 3 : Rapport

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

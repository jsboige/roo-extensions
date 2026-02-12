---
name: validate
description: Valide que le code compile et que les tests passent. Equivalent rapide d'un CI local. Utilise quand on veut verifier le build et les tests apres des modifications.
---

# Skill : Validate (Build & Tests)

Valide que le code compile et que les tests passent. Equivalent rapide d'un "CI local".

---

## Quand utiliser

- Apres des modifications de code
- Avant un commit pour verifier que rien n'est casse
- Pour diagnostiquer des erreurs de build ou de tests

---

## Workflow

### Etape 1 : Detecter le framework

Identifier le framework de build/test du projet :

| Fichier | Framework | Build | Test |
|---------|-----------|-------|------|
| `package.json` (scripts.build) | Node.js | `npm run build` ou `npx tsc --noEmit` | Voir step 2 |
| `Makefile` | Make | `make build` | `make test` |
| `pyproject.toml` | Python | - | `pytest -v` |
| `Cargo.toml` | Rust | `cargo build` | `cargo test` |
| `go.mod` | Go | `go build ./...` | `go test ./...` |

### Etape 2 : Build (check only si possible)

Lancer le build du projet. Pour TypeScript, preferer `npx tsc --noEmit` (type check sans output).

- Si succes : passer a l'etape 3
- Si erreurs : les lister avec fichier:ligne, corriger les erreurs simples (imports, typos), relancer

### Etape 3 : Tests unitaires

Lancer les tests. **Verifier que la commande ne bloque pas en mode watch interactif.**

| Framework | Commande correcte | Commande a EVITER |
|-----------|-------------------|--------------------|
| Vitest | `npx vitest run` | `npm test` (mode watch) |
| Jest | `npx jest --ci` | `npm test` (mode watch) |
| pytest | `pytest -v` | - |
| Go | `go test ./...` | - |

### Etape 4 : Rapport

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

Ajouter `--coverage` a la commande de test (si supporte).

### Tests d'un fichier specifique

Passer le chemin du fichier au test runner.

---

## Regles

- Toujours lancer le build AVANT les tests
- Reporter les erreurs avec fichier:ligne pour faciliter la correction
- Corrections simples (typos, imports manquants) : corriger directement et relancer
- Erreurs complexes (logique, architecture) : lister et laisser la decision a la conversation principale
- Ne JAMAIS ignorer un test qui echoue sans explication

---
name: git-sync
description: Synchronisation Git intelligente avec resolution de conflits manuelle et gestion des submodules. Utilise ce skill pour pull, merger, et maintenir le depot a jour.
---

# Skill : Git Sync

Synchronisation Git intelligente avec resolution de conflits manuelle et gestion des submodules.

---

## Quand utiliser

- En debut de session pour recuperer les changements distants
- Avant de commencer du travail pour etre a jour
- Quand on sait que d'autres ont pousse des commits

---

## Workflow

### Etape 1 : Fetch et analyse

```bash
git fetch origin
git log HEAD..origin/main --oneline
```

- Compter les commits entrants
- Identifier les auteurs et les fichiers modifies

### Etape 2 : Pull

```bash
git pull origin main
```

Le choix entre merge et rebase depend du projet. Par defaut, utiliser la configuration git du depot.

### Etape 3 : Resolution de conflits (si necessaire)

Si des conflits sont detectes :

1. Lister fichiers en conflit (`git status`)
2. Pour chaque fichier :
   - Lire avec marqueurs `<<<<<<<`, `=======`, `>>>>>>>`
   - Analyser les deux versions
   - Resoudre manuellement (garder version recente/complete ou combiner)
   - Editer pour supprimer les marqueurs
3. `git add` fichiers resolus
4. `git commit` (message merge)

**REGLE CRITIQUE : JAMAIS resoudre les conflits en choisissant aveuglément un cote. Toujours lire et comprendre les deux versions.**

### Etape 4 : Submodule update (si applicable)

```bash
git submodule update --init --recursive
```

Si un submodule est en conflit ou divergent :
- Verifier modifications locales dans le submodule
- Si modifs importantes : `git stash` ou `git commit -m "wip"`
- Sinon : reset le submodule

### Etape 5 : Verification finale

```bash
git status --short
git log --oneline -3
git submodule status 2>/dev/null || true
```

### Rapport

```
## Git Sync Status

### Remote
- Commits entrants : X
- Auteurs : [liste]

### Merge
- Status : Success | Conflits resolus | Conflits non resolus
- Fichiers modifies : Y
- Conflits resolus : [liste si applicable]

### Submodules
- [nom] : [hash] - Clean | Modified

### Etat actuel
- Branch : main @ [hash]
- Pret pour push : Oui | Non (raison)
```

---

## Regles

- **JAMAIS** de force push sur des branches partagees
- **JAMAIS** resoudre les conflits aveuglément (toujours lire les deux cotes)
- NE PAS commiter sans instruction explicite de l'utilisateur
- Les fichiers de config locaux sont ignores par git

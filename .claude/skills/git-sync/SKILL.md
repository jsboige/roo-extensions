---
name: git-sync
description: Synchronisation Git pour roo-extensions avec gestion du submodule mcps/internal et résolution manuelle des conflits (multi-machines). Utilise ce skill en début de session, avant de travailler, ou quand un message RooSync signale des commits. Phrase déclencheur : "git sync", "pull", "synchronise", "mets à jour le repo".
metadata:
  author: "Roo Extensions Team"
  version: "2.0.0"
  compatibility:
    surfaces: ["claude-code", "claude.ai"]
    restrictions: "Requiert accès Git + submodule mcps/internal"
---

# Skill : Git Sync - Override roo-extensions

> **Override projet** : Surcharge la skill globale `~/.claude/skills/git-sync/SKILL.md`.
> Template generique : `.claude/configs/skills/git-sync/SKILL.md`

Synchronisation Git pour roo-extensions avec submodule `mcps/internal` et merges conservatifs (multi-machines).

---

## Quand utiliser

- En debut de session pour recuperer les changements distants
- Pendant un tour de sync (Phase 2)
- Avant de commencer du travail pour etre a jour
- Apres reception d'un message RooSync signalant des commits

---

## Workflow

### Etape 1 : Fetch et analyse

```bash
git fetch origin
git log HEAD..origin/main --oneline
```

- Compter les commits entrants
- Identifier les auteurs et les fichiers modifies

### Etape 2 : Pull conservatif

```bash
git pull --no-rebase origin main
```

**TOUJOURS `--no-rebase`** pour preserver l'historique et eviter les conflits en cascade.

### Etape 3 : Resolution de conflits (si necessaire)

Si des conflits sont detectes :

1. Lister fichiers en conflit (`git status`)
2. Pour chaque fichier :
   - Lire avec marqueurs `<<<<<<<`, `=======`, `>>>>>>>`
   - Analyser les deux versions
   - Resoudre (garder version recente/complete ou combiner)
   - Editer pour supprimer les marqueurs
3. `git add` fichiers resolus
4. `git commit` (message merge)

**Apres resolution : pusher immediatement** pour debloquer les autres machines.

### Etape 4 : Submodule update

```bash
git submodule update --init --recursive
```

Si le submodule est en conflit ou divergent :
- Verifier modifications locales (`cd mcps/internal && git status`)
- Si modifs importantes : `git stash` ou `git commit -m "wip"`
- Sinon : `git checkout -- .` (abandon)
- Retour repertoire principal

### Etape 5 : Verification finale

```bash
git status --short
git log --oneline -3
git submodule status
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

### Submodule mcps/internal
- Commit : [hash]
- Status : Clean | Modified

### Etat actuel
- Branch : main @ [hash]
- Pret pour push : Oui | Non (raison)
```

---

## Commandes de reference

### Status complet
```bash
git status --short && git submodule status
```

### Derniers commits
```bash
git log --oneline -10
```

### Commits du submodule
```bash
cd mcps/internal && git log --oneline -5
```

### Preparation commit (sans commiter)
```bash
git diff --stat
git status
```

---

## Regles

- **TOUJOURS** utiliser `--no-rebase` pour preserver l'historique
- **JAMAIS** de force push
- **JAMAIS** de `git checkout` ou `git pull` dans le submodule `mcps/internal/` sans verification
- En cas de conflit, resoudre proprement (ne jamais `git add` a l'aveugle)
- Les fichiers de config locaux (.claude/local/*) sont ignores par git
- NE PAS commiter sans instruction explicite de l'utilisateur

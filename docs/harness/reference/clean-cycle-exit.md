# Clean Cycle Exit — postcondition Git de fin de cycle

**Version :** 1.0.0 (initial, #3776)
**Issue :** #3776
**Source :** Mandat utilisateur du 2026-09-22, instance fondatrice mesurée sur `myia-po-2025:CoursIA-2` (clone 673 commits derrière origin/main, 31 chemins non suivis, 2 submodules en drift sur SHA détaché).

---

## Règle globale (résumé)

Une session agentique doit se terminer sur la branche par défaut, avec un statut Git impeccable :
index/worktree propres, synchronisation fast-forward avec l'upstream, sous-modules aux gitlinks épinglés.
Tout contenu utile part en branche + PR, ou est archivé hors dépôt avec manifeste et empreintes.
**Jamais de suppression sans preuve de préservation.**

---

## Distinction avec #3147

| Issue | Périmètre | Quand |
|---|---|---|
| **#3776 (ce document)** | Prévention : postcondition **avant** que l'arbre ne se salisse | A chaque fin de cycle, sur le clone principal |
| **#3147** | Récupération : recyclage des **stashes existants** | Apres constat de dette déjà accumulee |

Les deux sont complémentaires, pas redondants. #3776 ferme le robinet ; #3147 vide le reservoir.

---

## L'organe `scripts/check_clean_cycle_exit.py`

### Sortie

Un verdict unique parmi :

| Verdict | Sens |
|---|---|
| `PASS` | Pret a clore le cycle. |
| `WRONG_BRANCH` | HEAD n'est pas sur la branche par defaut. |
| `DETACHED` | HEAD est detache. |
| `UNBORN` | Aucune commit dans le depot. |
| `NO_UPSTREAM` | La branche courante n'a pas d'upstream tracking. |
| `BEHIND` | HEAD est en arriere de l'upstream (fast-forward possible). |
| `AHEAD` | HEAD est en avance (commit non pousse). |
| `DIVERGED` | HEAD et upstream ont des commits distincts. |
| `DIRTY_TRACKED` | Modifications staged ou unstaged. |
| `UNTRACKED` | Chemins non suivis (contenu non expose). |
| `SUBMODULE_DRIFT` | Un submodule pointe sur un SHA different du gitlink parent. |
| `SUBMODULE_DIRTY` | Un submodule est au bon gitlink mais a des modifs internes. |
| `NOT_REPOSITORY` | Le chemin n'est pas un depot Git. |

> **Submodule non peuple ≠ drift (review #3778).** Un submodule sans checkout —
> repertoire absent, ou present mais vide (auquel cas `git -C` remonte au parent,
> piege #3454) — est l'etat normal d'un clone partiel sans `--recurse-submodules`.
> Il est classe `unpopulated`, n'emet AUCUN verdict, et apparait seulement en
> ligne d'information du rendu `[PASS]`. Le peupler reste un choix machine :
> `git submodule update --init --recursive` (etape 6).

### Garanties

1. **Read-only.** L'organe n'invoque JAMAIS :
   - `git clean`
   - `git reset --hard`
   - `git checkout -- <fichier>`
   - `git stash drop` / `git stash clear`
2. **Pas de credential.** N'accede a aucun remote, n'authentifie rien.
3. **N'expose pas le contenu.** Les chemins untracked sont listes par nom, leur contenu n'est jamais lu.

### Usage

```bash
# Mode humain : verdict + lignes par categorie concernee
python scripts/check_clean_cycle_exit.py

# Mode JSON structure : pour CI / orchestration
python scripts/check_clean_cycle_exit.py --json | jq .verdict

# Sur un chemin precis
python scripts/check_clean_cycle_exit.py --path /c/dev/roo-extensions
```

Codes de retour :

| Code | Sens |
|---|---|
| 0 | `PASS` |
| 1 | Verdict different de `PASS` |

### Tests

```bash
python -m unittest scripts.tests.test_check_clean_cycle_exit
```

Couvre chaque verdict avec un depot temporaire isole, ainsi qu'un **garde-fou de non-mutation** qui verifie que `git status` est inchange apres l'execution.

---

## Workflow de remédiation documenté

> **Avertissement.** La procedure ci-dessous suppose que **rien n'a encore ete perdu**. Si l'agent a deja essaye de "nettoyer" a la main, l'etat actuel est peut-etre deja different de l'etat d'avant la seance.

### Etape 1 : Inventorier

```bash
# Inventaire brut
git status --porcelain=v1 -z
git diff --binary --cached > /tmp/staged.patch
git diff --binary > /tmp/unstaged.patch

# Chemins non suivis, NUL-safe (les noms peuvent contenir espaces, Unicode)
git ls-files --others --exclude-standard -z | xargs -0 -I{} echo "{}"
```

### Etape 2 : Classifier

Pour chaque entree du status :

| Categorie | Geste |
|---|---|
| **Deja livre** (sur `origin/main` ou branche/PR) | Rien a faire. |
| **A livrer** (travail utile partiellement staged) | Finaliser + pousser en branche + PR. |
| **Artefact temporaire** (captures Playwright, snapshots, patches, notebooks, diagnostics) | Archiver hors depot puis nettoyer. |

### Etape 3 : Archive hors depot

```bash
# Creer le scratchpad avec manifeste NUL + SHA-256
SCRATCH="$HOME/.claude/scratch/$(date -u +%Y%m%dT%H%M%SZ)-clean-cycle"
mkdir -p "$SCRATCH"
cd /c/dev/roo-extensions

# 1. Snapshot du status
git status --porcelain=v1 -z > "$SCRATCH/status-before.z"

# 2. Patches
git diff --binary --cached > "$SCRATCH/staged.patch"
git diff --binary > "$SCRATCH/unstaged.patch"

# 3. Archive des chemins non suivis
git ls-files --others --exclude-standard -z | tar --null -czf "$SCRATCH/untracked.tgz" -T -

# 4. Bornes
echo "$(git rev-parse HEAD)" > "$SCRATCH/HEAD"
echo "$(git rev-parse origin/main 2>/dev/null || echo NO_ORIGIN)" > "$SCRATCH/origin-main"

# 5. Manifeste avec SHA-256
( cd "$SCRATCH" && sha256sum * > SHA256SUMS )
```

### Etape 4 : Livrer le code utile

```bash
# Branche dediee, commit atomique, push, PR
git checkout -b recovery/$(date -u +%Y%m%d-%H%M%S)
# (rejouer les modifs en preservant la structure)
git commit -m "feat(scope): libelle precis du livrable"
git push -u origin HEAD
gh pr create --body-file $TEMP/pr-body.md
```

### Etape 5 : Restaurer la branche par defaut

```bash
git checkout main
git pull --ff-only
```

### Etape 6 : Realigner les submodules

**Uniquement apres avoir prouve qu'ils sont propres en interne :**

```bash
git submodule status                                  # vue d'ensemble
git submodule update --init --recursive               # re-aligne sur les gitlinks du parent
```

### Etape 7 : Verifier avec l'organe

```bash
python scripts/check_clean_cycle_exit.py
# Attendu : [PASS] Pret a cloturer le cycle.
```

Si un verdict non-`PASS` persiste, **STOP** et traiter chaque signal avant de continuer.

---

## Wiring dans les skills

Les skills suivants appellent l'organe **avant** un `[DONE]` final ou explicitent pourquoi il est non applicable :

| Skill / commande | Comportement |
|---|---|
| `coordinate` (`.claude/commands/coordinate.md`, § Fin de Session) | Execute l'organe sur le clone principal avant le bilan final ; verdict joint au bilan, ou `[SKIP-CHECK]` motivé si session sans mutation du dépôt. |
| `executor` (`.claude/skills/executor/SKILL.md`, § Postcondition Git de fin de cycle) | Idem, avant l'append `[DONE]` final de session ; `[SKIP-CHECK]` motivé si session purement informationnelle (lecture seule). |

> **Correction (24/09/2026).** Une version anterieure de cette table citait `coordinate-adjoint` et
> `continue`, qui **n'existent pas** dans ce depot (commandes reelles : `coordinate`,
> `switch-provider`, `debrief`, `team` ; skills : `executor`, `git-sync`, etc.). La table ci-dessus
> reflete le wiring reel.

L'organe ne tourne que sur le **clone principal de session**. Les worktrees temporaires (PR, recovery) sont gerees par leur propre protocole (cf. `worktree-lifecycle.md`).

---

## Anti-patterns

1. **`git clean -fdx`** sans avoir produit d'archive — destruction de travail non livre.
2. **`git reset --hard`** sur une branche ou du travail n'a pas ete commite.
3. **`git checkout -- <fichier>`** pour "revenir en arriere" sur une branche de travail : restaure l'INDEX, pas l'etat d'avant la mutation.
4. **Suppression de captures Playwright / notebooks / patches** "parce que ce ne sont que des artefacts" — sans archive, c'est une perte depreuve.
5. **Forcer un submodule sur le bon SHA** alors qu'il a des modifs internes non commitees : perte de travail.
6. **Clore le cycle sur une branche secondaire** (feature, hotfix) avec l'intention de "nettoyer plus tard" : le prochain cycle demarrera sur la meme branche avec le meme fouillis.

---

## Reference croisee

- Regle succincte : `.claude/configs/user-global-claude.md` (section "Postcondition Git de fin de cycle").
- Script : `scripts/check_clean_cycle_exit.py`.
- Tests : `scripts/tests/test_check_clean_cycle_exit.py`.
- Regles connexes : `.claude/rules/no-deletion-without-proof.md`, `.claude/rules/worktree-lifecycle.md`, `.claude/rules/submod-pointer-safety.md`.
- Issue #3147 : recycle les stashes existants.
- Issue #3776 : ce document.

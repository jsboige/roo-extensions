# Garde-fous du workflow PR — détail et incidents fondateurs

**Déporté de** `.claude/rules/pr-mandatory.md` v3.5.1 (lignes 27-35, 58-74, 76-87, 105-127)
le 2026-09-13.
**Issues :** #2123 (worktrees imbriqués) · #1799 (pointer-bump prématuré) · #1666 Phase A2
(detached HEAD) · #2368 (économie d'identité, `--body-file`)

La règle auto-chargée garde les impératifs. Ce document porte les incidents, les workflows pas à
pas et les anti-patterns mesurés — on le lit quand on prépare le geste, pas à chaque conversation.

---

## Worktrees imbriqués dans un submodule (#2123, incident 2026-05-22)

Un worktree doit toujours vivre dans le repo git **qui le gère**.

| Chemin | Verdict |
|---|---|
| `.claude/worktrees/wt-foo` dans le repo parent | **OK** — worktree du repo parent |
| `../roo-extensions-wt/wt-foo` (hors du repo), via `create-worktree.ps1` | **OK** |
| `mcps/internal/.claude/worktrees/wt-foo` | **INTERDIT** — worktree du submodule imbriqué dans le working tree du parent → **136k fichiers fuient comme untracked** |

**Garde :** avant `git worktree add`, vérifier `git rev-parse --show-toplevel`. Si ce toplevel est
dans un sous-répertoire d'un repo parent (ex. `mcps/internal`), le worktree sera imbriqué →
utiliser un chemin **en dehors** du working tree, ou travailler directement dans le submodule sans
worktree.

## Pointer-bump prématuré (#1799, post cycle 22ter cascade CI)

**Risque :** créer un pointer-bump parent avant que la PR submod source soit mergée → SHA
orpheline, `check-submodule-pointer` en échec systématique.

**Workflow correct :**

1. Le worker crée la PR submod (ex. `mcps/internal` PR #234).
2. Attendre le merge : `gh pr view 234 --json state` = `MERGED`.
3. Récupérer la SHA mergée : `git -C mcps/internal rev-parse origin/main`.
4. **Alors seulement** créer le bump parent vers cette SHA.

**Anti-pattern observé (cycle 22ter) :** PRs #1788, #1793, #1795, #1796 toutes en échec CI, leurs
pointeurs visant des SHAs non mergées. Résolu par re-création post-merge.

**Variante interactive (incident `67514ec1`, 2026-05-11) :** un agent résout un conflit submod en
checkant out une SHA locale jamais poussée → pointeur orphelin sur `main`, `fetch` cassé
flotte-wide. Les sessions interactives ne passent pas par `worker.ps1` (qui a son
`Reset-PhantomSubmodulePointers`) : c'est le trou que couvre
[`.claude/rules/submod-pointer-safety.md`](../../../.claude/rules/submod-pointer-safety.md).

**Alternative coordinateur :** bundle pointer-bump (pattern #1764, #1801) — une PR parent groupant
plusieurs merges submod = moins de PRs, moins de races.

## Detached HEAD (#1666 Phase A2)

Un commit sur detached HEAD est **orphelin** — perdu au cleanup du worktree.

1. Avant commit : `git symbolic-ref -q HEAD` — si échec, **ne pas committer**.
2. Si detached : `git checkout -b worker/recovery-YYYYMMDD-HHmmss`, puis committer.
3. Après commit : vérifier que `git symbolic-ref -q HEAD` passe.

**Automatique :** `start-claude-worker.ps1` implémente ce garde (ligne 1903) ; en cas de recovery,
le nom de branche est rapporté dans le `[RESULT]`.

**Claude Code :** vérifier `git branch --show-current` avant chaque commit dans un worktree. Vide
ou `(HEAD detached` → créer une branche de recovery d'abord.

## `--body-file` : pourquoi `--body` inline est piégé (#2368)

Dans `--body "..."` à guillemets doubles, les backticks markdown sont de la **substitution de
commande** pour bash : chaque span `` `code` `` du corps s'exécute avant que `gh` ne voie la chaîne.

Un span qui échoue (glob sans correspondance, commande inexistante) laisse le post **partir quand
même** — stderr affiche l'erreur, **l'exit code reste 0** — avec un corps écorché. Le retry
« propre » crée alors un **doublon**.

**Incident fondateur :** review `CHANGES_REQUESTED` au body tronqué, PR #2864.

Règles qui en découlent (dans la règle auto-chargée) : toujours `--body-file` ; `gh issue close`
n'expose pas `--comment-file`, donc commenter d'abord puis fermer ; un stderr montrant une erreur
shell impose de **vérifier via l'API avant de retenter**.

## Économie d'identité review (#2368, promotion T5→T3)

L'`APPROVE` sous `jsboige` (compte partagé) **se dépense** : un 2ᵉ approval ne déplace rien, et la
même identité OWNER sert aussi à merger — chaque usage est un conflit `gh` potentiel de plus
(#3032, voir [`gh-identity-concurrency.md`](gh-identity-concurrency.md)).

Avant de poster un APPROVE : lire `gh pr view N --json reviews`. Si un reviewer qualifiant a déjà
approuvé **sur la tête courante**, faire sa passe indépendante en **COMMENT**. Réserver l'APPROVE
aux deux cas où il déplace quelque chose : (1) ma review est la première qualifiante, (2) la branch
protection exige une seconde review.

---

**Règle canonique :** [`.claude/rules/pr-mandatory.md`](../../../.claude/rules/pr-mandatory.md)
**Voir aussi :** [`pr-trivial-merge-policy.md`](pr-trivial-merge-policy.md) ·
[`gh-identity-concurrency.md`](gh-identity-concurrency.md) ·
[`submod-pointer-safety-procedure.md`](submod-pointer-safety-procedure.md)

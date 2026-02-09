# Worktree Workflow - Dev Isole Multi-Machines

## Pourquoi les Worktrees ?

Le probleme : 5 machines poussent sur `main` en meme temps, causant conflits et rebase complexes.

La solution : chaque machine travaille dans un **worktree Git** isole avec sa propre branche, puis soumet une **PR** pour merge.

## Architecture

```
d:/Dev/roo-extensions/              <-- main (coordinateur, reference)
d:/Dev/roo-extensions-wt/
    417-worktree-workflow/           <-- feature/417-worktree-workflow
    420-propagation-memoires/        <-- feature/420-propagation-memoires
```

Chaque worktree :
- Partage le meme `.git` que le repo principal (pas de clone supplementaire)
- A sa propre branche isolee
- A ses propres submodules initialises
- Recoit une copie de `.env` et `.claude/local/`

## Workflow Complet

### 1. Creer un worktree

```powershell
cd d:/Dev/roo-extensions
.\scripts\worktrees\create-worktree.ps1 -IssueNumber 417
```

Ce script :
- Recupere le titre de l'issue via `gh`
- Cree la branche `feature/417-worktree-workflow` depuis `origin/main`
- Cree le worktree dans `../roo-extensions-wt/417-worktree-workflow/`
- Initialise les submodules
- Copie `.env` et `.claude/local/`

### 2. Travailler dans le worktree

```powershell
cd d:/Dev/roo-extensions-wt/417-worktree-workflow/

# Editer, tester, committer normalement
git add .
git commit -m "feat(worktrees): Add create script"

# Build et tests
cd mcps/internal/servers/roo-state-manager
npx tsc --noEmit
npx vitest run
```

### 3. Soumettre une PR

```powershell
cd d:/Dev/roo-extensions-wt/417-worktree-workflow/
.\scripts\worktrees\submit-pr.ps1 -IssueNumber 417
```

Ce script :
- Verifie le build TypeScript
- Pousse la branche vers origin
- Cree une PR avec template standardise
- Assigne le reviewer (coordinateur)

Options :
- `-Draft` : creer en mode brouillon
- `-Reviewer "username"` : changer le reviewer

### 4. Nettoyer apres merge

```powershell
cd d:/Dev/roo-extensions
.\scripts\worktrees\cleanup-worktree.ps1 -IssueNumber 417
```

Ce script :
- Verifie que la branche est mergee
- Supprime le worktree
- Supprime les branches locale et remote
- Nettoie le dossier

Options :
- `-Force` : supprimer meme si non merge
- `-KeepRemote` : garder la branche remote

## Conventions

### Nommage des branches

```
feature/{ISSUE_NUMBER}-{titre-court}
```

Exemples :
- `feature/417-worktree-workflow`
- `feature/420-propagation-memoires`
- `feature/403-scheduler`

### Commits dans les worktrees

Meme convention que sur main :
```
type(scope): description

# Exemples
feat(worktrees): Add create-worktree script
fix(roosync): Fix message parsing
docs(workflows): Add worktree documentation
```

### Emplacement des worktrees

```
{parent-du-repo}/roo-extensions-wt/{issue-titre}/
```

Par defaut : `d:/Dev/roo-extensions-wt/`

## Integration avec le Workflow Multi-Agent

### Pour les agents Claude Code

1. Le coordinateur assigne une issue
2. L'agent cree un worktree : `create-worktree.ps1 -IssueNumber NNN`
3. L'agent travaille dans le worktree (edit, test, commit)
4. L'agent soumet une PR : `submit-pr.ps1 -IssueNumber NNN`
5. Apres review/merge, cleanup : `cleanup-worktree.ps1 -IssueNumber NNN`

### Pour Roo

Roo peut aussi travailler dans les worktrees. Les scripts sont compatibles PowerShell 5.1+.

### Coordination

- Chaque worktree est independant : pas de conflits entre machines
- Les PRs sont la seule facon de merger dans main
- Le coordinateur review et merge les PRs

## Parametres

### create-worktree.ps1

| Parametre | Requis | Defaut | Description |
|-----------|--------|--------|-------------|
| IssueNumber | Oui | - | Numero issue GitHub |
| BaseBranch | Non | main | Branche de base |
| WorktreeRoot | Non | ../roo-extensions-wt | Dossier racine |

### submit-pr.ps1

| Parametre | Requis | Defaut | Description |
|-----------|--------|--------|-------------|
| IssueNumber | Oui | - | Numero issue GitHub |
| Reviewer | Non | jsboige | Reviewer GitHub |
| Draft | Non | false | Mode brouillon |

### cleanup-worktree.ps1

| Parametre | Requis | Defaut | Description |
|-----------|--------|--------|-------------|
| IssueNumber | Oui | - | Numero issue GitHub |
| WorktreeRoot | Non | ../roo-extensions-wt | Dossier racine |
| KeepRemote | Non | false | Garder branche remote |
| Force | Non | false | Forcer suppression |

## Troubleshooting

### "fatal: is already checked out"

Un worktree utilise deja cette branche. Verifier avec `git worktree list`.

### Submodules pas initialises

```powershell
cd worktree-path
git submodule update --init --recursive
```

### Conflit lors du merge de PR

1. Depuis le worktree, rebase sur main :
   ```powershell
   git fetch origin
   git rebase origin/main
   ```
2. Resoudre les conflits
3. Force push : `git push --force-with-lease`

### Worktree "fantome" apres crash

```powershell
git worktree prune
```

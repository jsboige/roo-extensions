# Workflow Scheduler Roo - EXECUTEUR (machines non-coordinateur)

> Lu par orchestrateur-simple sur les machines executrices. MAJ : modifier + `git push`.

## PRINCIPES

1. **Roo n'utilise JAMAIS RooSync** (reserve a Claude Code)
2. **TOUJOURS deleguer via `new_task`** (jamais faire le travail soi-meme)
3. Communication via INTERCOM uniquement (`.claude/local/INTERCOM-{MACHINE}.md`)
4. Ne JAMAIS commit ou push
5. Deleguer uniquement aux modes `-simple` ou `-complex`
6. **WIN-CLI OBLIGATOIRE pour les commandes shell** : les modes `-simple` n'ont PAS acces au terminal natif. Utiliser UNIQUEMENT le MCP win-cli dans les prompts delegues.

## REGLES WIN-CLI (CRITIQUE)

Les modes `code-simple` et `debug-simple` n'ont plus acces au terminal par defaut (execute_command supprime). **Toujours instruire l'utilisation de win-cli** dans les prompts `new_task` :

```
# Build/Tests - utiliser win-cli :
execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run")
execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npm run build")

# Git - utiliser gitbash :
execute_command(shell="gitbash", command="git pull --no-rebase origin main")
execute_command(shell="gitbash", command="git status")

# GitHub CLI - utiliser powershell :
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state open --limit 10 --json number,title,labels")
```

**ATTENTION** : Ne PAS piper vers des commandes PowerShell dans le shell "powershell" (Select-Object, ConvertFrom-Json) si possible - privilegier des commandes simples ou plusieurs appels separes.

---

## WORKFLOW EN 3 ETAPES

### Etape 1 : Git pull + Lecture INTERCOM

Deleguer a `code-simple` via `new_task` :

```
Executer ces commandes et rapporter le resultat :
1. git pull --no-rebase origin main
2. git status
Puis lire les 5 derniers messages de .claude/local/INTERCOM-{MACHINE}.md
Chercher les messages [TASK], [SCHEDULED], [URGENT] de claude-code -> roo.
Rapporter : etat git + liste des taches trouvees.
```

**Decision :**
- Si `[URGENT]` : escalader vers `orchestrator-complex`
- Si `[TASK]` trouve : aller a **Etape 2a**
- Si `[FEEDBACK]` recent de Claude : noter les ajustements
- Si rien : aller a **Etape 2b**

### Etape 2a : Executer les taches INTERCOM

Pour chaque `[TASK]` trouve, deleguer selon la difficulte :

| Difficulte | Action |
|-----------|--------|
| 1 action isolee | `code-simple` via `new_task` |
| 2-4 actions liees | Deleguer chaque action separement a `code-simple` |
| 5+ actions ou dependances | Escalader vers `orchestrator-complex` |

**Gestion des echecs :**
- 1er echec : relancer avec instructions corrigees
- 2e echec sur meme tache : arreter et rapporter
- Erreur complexe : escalader vers `-complex`

**Chaine d'escalade :** `code-simple` → `code-complex` → `orchestrator-complex` → Claude Code (via INTERCOM `[ESCALADE-CLAUDE]`)

Apres execution → **Etape 3**

### Etape 2b : Taches par defaut (si pas de [TASK])

Deleguer dans cet ordre a `code-simple` via `new_task` :

**1. Build + Tests (validation sante workspace)**

```
Executer dans le repertoire mcps/internal/servers/roo-state-manager :
1. npm run build
2. npx vitest run
Rapporter : build OK/FAIL + nombre tests pass/fail.
```

> **Note MyIA-Web1 :** Toujours utiliser `npx vitest run --maxWorkers=1` (contrainte RAM 2GB).

**2. Chercher une tache sur GitHub**

```
gh issue list --repo jsboige/roo-extensions --state open --limit 10 --json number,title,labels --jq '.[] | select(.labels[]?.name == "roo-schedulable") | "\(.number)\t\(.title)"'
```

Si une issue est trouvee :
1. Lire le body complet : `gh issue view {NUM} --repo jsboige/roo-extensions`
2. Commenter pour claim : `gh issue comment {NUM} --body "Claimed by {MACHINE} (Roo scheduler). Mode: simple."`
3. Executer selon difficulte (simple → `code-simple`, complexe → `code-complex`)
4. Commenter le resultat : `gh issue comment {NUM} --body "Result: {PASS/FAIL}. Mode: {simple/complex}."`

Si aucune issue : rapporter `[IDLE]` dans INTERCOM.

Apres tout → **Etape 3**

### Etape 3 : Rapporter dans INTERCOM (OBLIGATOIRE)

> **CRITIQUE :** L'ecriture INTERCOM est la seule trace du passage du scheduler. Sans elle, Claude Code ne sait pas que Roo a tourne. **Ne JAMAIS quitter sans avoir ecrit dans INTERCOM.**

**METHODE PRINCIPALE (directe, sans delegation) :**

> Raison : La delegation via `new_task` peut echouer silencieusement (timeout, erreur subtask). La tracabilite etant prioritaire, l'ecriture directe est plus fiable.

```
1. Lis .claude/local/INTERCOM-{MACHINE}.md en ENTIER avec read_file
2. Prepare le nouveau message (voir format ci-dessous)
3. Ajoute le message A LA FIN du contenu existant (ne supprime RIEN)
4. Reecris le fichier COMPLET avec write_to_file
5. CONFIRME : Relis le fichier et verifie que le dernier message est bien le tien
```

**FALLBACK (si write_to_file non disponible) :** Deleguer a `code-simple` via `new_task` avec les instructions ci-dessus. Cette methode est moins fiable mais preferable a aucune ecriture.

**Format du message :**

```markdown
## [{DATE}] roo -> claude-code [{DONE|MAINTENANCE|IDLE}]
### Bilan scheduler executeur

- Git pull : OK/erreur
- Git status : propre/dirty
- Build : OK/FAIL
- Tests : {X} pass / {Y} fail
- Taches executees : {N} (source: INTERCOM/GitHub #{num})
- Erreurs : {liste ou "aucune"}
- Escalades : {aucune ou vers {mode}}

---
```

**Maintenance INTERCOM :** Si le fichier depasse 1000 lignes, condenser les 600 premieres en ~100 lignes de synthese, garder les 400 dernieres intactes.

---

## REGLES DE SECURITE

1. Ne JAMAIS commit sans validation Claude Code
2. Ne JAMAIS push directement
3. Ne JAMAIS faire `git checkout` dans le submodule `mcps/internal/`
4. **NE JAMAIS utiliser les outils RooSync** (roosync_send, roosync_read, etc.)
5. Apres 2 echecs sur meme tache : arreter et rapporter

---

## CRITERES D'ESCALADE VERS ORCHESTRATOR-COMPLEX

- Message `[URGENT]` dans l'INTERCOM
- Plus de 5 sous-taches a coordonner
- Dependances entre sous-taches
- 2 echecs consecutifs en `-simple`
- Modification de plus de 3 fichiers interconnectes

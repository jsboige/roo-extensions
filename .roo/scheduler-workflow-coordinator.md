# Workflow Scheduler Roo - COORDINATEUR (myia-ai-01)

> Lu par orchestrateur-simple. MAJ : modifier ce fichier + `git push`.

## PRINCIPES

1. **Roo n'utilise JAMAIS RooSync** (reserve a Claude Code)
2. **TOUJOURS deleguer via `new_task`** (jamais faire le travail soi-meme)
3. Communication via INTERCOM uniquement (`.claude/local/INTERCOM-myia-ai-01.md`)
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

**ATTENTION** : Ne PAS piper vers des commandes PowerShell complexes (Select-Object, ConvertFrom-Json) si possible - privilegier des commandes simples ou plusieurs appels separes.

---

## WORKFLOW EN 4 ETAPES

### Etape 0 : Pre-flight Check (OBLIGATOIRE)

**AVANT TOUT**, verifier que les outils critiques sont disponibles.

Tester win-cli directement (PAS via delegation) :

```
execute_command(shell="powershell", command="echo PRE-FLIGHT-OK")
```

**Decision :**
- Si `execute_command` repond `PRE-FLIGHT-OK` : continuer vers **Etape 1**
- Si `execute_command` echoue ou n'est pas disponible : **STOP IMMEDIAT**
  1. Ecrire dans INTERCOM (via write_to_file directement) :
     `## [{DATE}] roo -> claude-code [CRITICAL]`
     `### MCP win-cli non disponible - Scheduler BLOQUE`
  2. NE PAS continuer le workflow
  3. Terminer la tache

**Reference :** Voir `.roo/rules/05-tool-availability.md` pour le protocole complet.

### Etape 1 : Git pull + Lecture INTERCOM

Deleguer a `code-simple` via `new_task` :

```
Utilise le MCP win-cli pour executer ces commandes et rapporter le resultat :
1. execute_command(shell="gitbash", command="git pull --no-rebase origin main")
2. execute_command(shell="gitbash", command="git status")
Puis lire les 5 derniers messages de .claude/local/INTERCOM-myia-ai-01.md avec read_file.
Chercher les messages [TASK], [SCHEDULED], [URGENT] de claude-code -> roo.
Rapporter : etat git + liste des taches trouvees.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Decision :**
- Si git pull a ECHOUE (submodule error, conflict) : aller DIRECTEMENT a **Etape 3** avec rapport d'erreur. Ne PAS executer de taches sur un workspace desynchronise.
- Si `[URGENT]` : escalader vers `orchestrator-complex`
- Si `[TASK]` trouve ET date < 24h : aller a **Etape 2a**
- Si `[TASK]` trouve MAIS date > 24h : IGNORER (tache perimee, noter dans le bilan)
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
- 2e echec sur meme tache : arreter et rapporter dans le bilan
- Erreur complexe : escalader vers `-complex`

Apres execution → **Etape 3**

### Etape 2b : Taches par defaut (si pas de [TASK])

Deleguer dans cet ordre a `code-simple` via `new_task` :

**1. Build + Tests (validation sante workspace)**

```
Utilise win-cli MCP pour executer dans le repertoire mcps/internal/servers/roo-state-manager :
1. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npm run build")
2. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run 2>&1 | Select-Object -Last 30")
Rapporter : build OK/FAIL + nombre tests pass/fail.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
INTERDIT : NE JAMAIS utiliser --coverage (output trop volumineux, explose le contexte).
```

**2. Verifier inbox RooSync (detecter messages pour Claude)**

```
Utilise win-cli MCP pour executer cette commande :
execute_command(shell="powershell", command="(Get-ChildItem 'G:/Mon Drive/Synchronisation/RooSync/.shared-state/messages/inbox/*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5).Name")
Rapporter : nombre et noms des fichiers recents.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**3. Si messages RooSync recents (< 6h) → signaler dans INTERCOM avec `[WAKE-CLAUDE]`**

**4. Chercher une tache sur GitHub (si du temps reste)**

```
Utilise win-cli MCP :
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state open --limit 10 --json number,title,labels")
Filtrer les issues avec label 'roo-schedulable'.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

Si une issue est trouvee : la lire, commenter pour claim, et executer si faisable en `-simple`.

Apres tout → **Etape 3**

### Etape 3 : Rapporter dans INTERCOM (OBLIGATOIRE)

> **CRITIQUE :** L'ecriture INTERCOM est la seule trace du passage du scheduler. Sans elle, Claude Code ne sait pas que Roo a tourne. **Ne JAMAIS quitter sans avoir ecrit dans INTERCOM.**

**Methode principale :** Deleguer a `code-simple` via `new_task` :

```
1. Lis .claude/local/INTERCOM-myia-ai-01.md en ENTIER avec read_file
2. Ajoute le nouveau message A LA FIN (ne supprime RIEN de l'ancien contenu)
3. Reecris le fichier COMPLET avec write_to_file
4. Relis le fichier et confirme que le dernier message est celui qu'on vient d'ajouter
```

**FALLBACK :** Si la delegation echoue (subtask error, timeout, pas de confirmation), ecrire INTERCOM directement soi-meme avec read_file + write_to_file. Cette exception a la regle "toujours deleguer" est justifiee car la tracabilite est prioritaire.

**Format du message :**

```markdown
## [{DATE}] roo -> claude-code [{DONE|MAINTENANCE|IDLE}]
### Bilan scheduler coordinateur

- Git pull : OK/erreur
- Git status : propre/dirty
- Build : OK/FAIL
- Tests : {X} pass / {Y} fail
- Taches executees : {N} (source: INTERCOM/GitHub)
- Erreurs : {liste ou "aucune"}
- Messages RooSync detectes : {N}
- Wake Claude : oui/non

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
6. **NE JAMAIS utiliser `--coverage`** dans les commandes de test (output trop volumineux, explose le contexte glm-4.7-flash)
7. **Limiter les outputs** : toujours piper vers `Select-Object -Last 30` ou `tail -30` pour eviter les debordements de contexte
8. **Ignorer les [TASK] de plus de 24h** : les taches perimes sont marquees dans le bilan mais non executees

---

## CRITERES D'ESCALADE VERS ORCHESTRATOR-COMPLEX

- Message `[URGENT]` dans l'INTERCOM
- Plus de 5 sous-taches a coordonner
- Dependances entre sous-taches
- 2 echecs consecutifs en `-simple`
- Modification de plus de 3 fichiers interconnectes

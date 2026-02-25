# Workflow Scheduler Roo - EXECUTEUR (machines non-coordinateur)

> Lu par orchestrateur-simple sur les machines executrices. MAJ : modifier + `git push`.

## PRINCIPES

1. **Roo n'utilise JAMAIS RooSync** (reserve a Claude Code)
2. **TOUJOURS deleguer via `new_task`** (jamais faire le travail soi-meme)
3. Communication via INTERCOM uniquement (`.claude/local/INTERCOM-{MACHINE}.md`)
4. Ne JAMAIS commit ou push (sauf config-sync automatique via RooSync - voir Etape 0c)
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

## EXEMPLES CONCRETS DE DÉLÉGATION (OBLIGATOIRE)

**RÈGLE D'OR :** TOUJOURS utiliser `new_task` pour déléguer. JAMAIS exécuter les commandes toi-même.

### ❌ MAUVAIS (à ne JAMAIS faire)

```javascript
// NE JAMAIS faire ça directement !
const result = await execute_command(shell="powershell", command="git pull");
const tests = await execute_command(shell="powershell", command="npx vitest run");
```

### ✅ BON (à TOUJOURS faire)

```javascript
// TOUJOURS déléguer via new_task
const taskId = await new_task({
  title: "Git pull + status",
  instructions: `
Executer ces commandes avec win-cli :
1. execute_command(shell="gitbash", command="git pull --no-rebase origin main")
2. execute_command(shell="gitbash", command="git status")
Rapporter le resultat.
  `
});
```

### Exemples par type de tâche

**Build + Tests :**
```javascript
await new_task({
  title: "Validation build + tests",
  instructions: `
Dans mcps/internal/servers/roo-state-manager :
1. execute_command(shell="powershell", command="npm run build")
2. execute_command(shell="powershell", command="npx vitest run")
Rapporter : build OK/FAIL + X/Y tests.
  `
});
```

**GitHub Issues :**
```javascript
await new_task({
  title: "Chercher tâche GitHub",
  instructions: `
1. execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state open --limit 10")
2. Si issue trouvée : gh issue comment {NUM} --body "Claimed by myia-po-2023"
3. Executer la tâche selon les instructions dans l'issue
  `
});
```

**Plusieurs tâches indépendantes :**
```javascript
// Déléguer CHAQUE tâche séparément
await new_task({ title: "Batch C tests", instructions: "..." });
await new_task({ title: "Batch B tests", instructions: "..." });
await new_task({ title: "Batch A tests", instructions: "..." });

console.log("✅ 3 tâches déléguées aux modes -complex");
```

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

### Etape 0b : Heartbeat (OBLIGATOIRE)

Envoyer un signal de vie au coordinateur :

```
roosync_heartbeat(action="beat")
```

**Raison :** Permettre au coordinateur de savoir que cette machine est active et peut recevoir des tâches.

**Si échec :** Noter dans le bilan mais continuer (heartbeat non bloquant).

### Etape 0c : Config-Sync (optionnel, si > 24h depuis dernier)

> **Note :** Cette étape utilise les outils RooSync (réservés à Roo sur machines exécutantes pour cette tâche spécifique). Voir principe #4 modifié.

Synchroniser la configuration locale avec le coordinateur :

```
1. roosync_config(action: "collect", targets: ["modes", "mcp"])
2. roosync_config(action: "publish", version: "auto", description: "Config-sync automatique")
3. result = roosync_compare_config(granularity: "mcp")
```

**Décision selon le résultat :**
- Si `summary.critical > 0` ou `summary.important > 0` :
  - Envoyer rapport au coordinateur via INTERCOM (message `[CONFIG-DRIFT]`)
  - Format : "Config drift détecté: X CRITICAL, Y IMPORTANT"
- Si seulement WARNING/INFO :
  - Skip silencieusement (pas de rapport nécessaire)

**Fréquence :** Une fois par 24h maximum. Utiliser un fichier marker `.claude/local/.last-config-sync` pour éviter les syncs répétés.

**Si échec :** Noter dans le bilan mais continuer (config-sync non bloquant).

---

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

**METHODE SIMPLIFIEE (append direct) :**

> Raison : La methode "lire tout + réécrire tout" cause des boucles de condensation. L'append direct est plus fiable.

```
1. Prepare le message (voir format ci-dessous)
2. Utilise write_to_file en APPEND (ou equivalent)
3. Si write_to_file ne supporte pas l'append : lis SEULEMENT les 50 dernieres lignes, puis ecris tout
4. NE PAS relire le fichier plusieurs fois
```

**FORMAT MESSAGE (garder court) :**

```markdown
## [{DATE}] roo -> claude-code [{DONE|IDLE}]
- Git: {OK/erreur} | Status: {propre/dirty}
- Build: {OK/FAIL} | Tests: {X} pass
- Taches: {N} (source: {INTERCOM/GitHub #num})
- Erreurs: {aucune ou description courte}
```

**FALLBACK (si write_to_file non disponible) :** Deleguer a `code-simple` via `new_task` avec instruction "APPEND le message à la fin du fichier INTERCOM".

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

**Maintenance INTERCOM :** Si le fichier depasse 500 lignes, condenser les 300 premieres en ~50 lignes de synthese, garder les 200 dernieres intactes. Faire cela SEULEMENT si le temps le permet (pas prioritaire).

---

## REGLES DE SECURITE

1. Ne JAMAIS commit sans validation Claude Code
2. Ne JAMAIS push directement
3. Ne JAMAIS faire `git checkout` dans le submodule `mcps/internal/`
4. **NE JAMAIS utiliser les outils RooSync** (roosync_send, roosync_read, etc.) - **EXCEPTION :** roosync_config et roosync_compare_config pour l'Etape 0c
5. Apres 2 echecs sur meme tache : arreter et rapporter
6. **NE JAMAIS utiliser `--coverage`** dans les commandes de test (output trop volumineux, explose le contexte)
7. **Limiter les outputs** : toujours piper vers `Select-Object -Last 30` ou `tail -30` pour eviter les debordements de contexte
8. **Ignorer les [TASK] de plus de 24h** : les taches perimes sont marquees dans le bilan mais non executees

---

## CRITERES D'ESCALADE VERS ORCHESTRATOR-COMPLEX

- Message `[URGENT]` dans l'INTERCOM
- Plus de 5 sous-taches a coordonner
- Dependances entre sous-taches
- 2 echecs consecutifs en `-simple`
- Modification de plus de 3 fichiers interconnectes

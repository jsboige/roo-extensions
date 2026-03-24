# Workflow Scheduler Roo - COORDINATEUR (myia-ai-01)

> Lu par orchestrateur-simple. MAJ : modifier ce fichier + `git push`.

## ⚠️ RÈGLE #1 - AUTONOMIE ABSOLUE (ZÉRO QUESTION)

**Tu es 100% AUTONOME. Tu n'as AUCUN droit de poser une question à l'utilisateur.**
Ceci inclut : demandes de confirmation ("Veux-tu que..."), demandes de permission ("Dois-je..."), hésitations ("Voulez-vous..."), ou TOUTE interaction utilisateur.
**Toute question = ÉCHEC IMMÉDIAT qui bloque le scheduler.**
Agis directement. Délègue via `new_task`. Décide toi-même.

**RÈGLE #2** : Toutes les sous-tâches que tu crées via `new_task` doivent AUSSI contenir en PREMIER : "REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement."

---

## 🛑 CIRCUIT BREAKER - Anti-Boucle d'Échecs (Issue #737)

**Si un outil échoue 2 fois de suite avec la même erreur → ABANDONNER cette action.**

| Échecs | Action |
|--------|--------|
| 1 | Réessayer UNE FOIS avec syntaxe simplifiée |
| 2 | **STOP** — Abandonner, passer à la sous-tâche suivante |
| 3+ | **INTERDIT** — Ne JAMAIS réessayer plus de 2 fois |

**`gh api graphql` en `-simple` via win-cli** : quoting JSON instable. PRÉFÉRER `gh issue list/view` (commandes simples). Si GraphQL nécessaire → escalader vers `-complex`.

**Condensation qui échoue** : NE PAS réessayer. Terminer avec `attempt_completion` immédiatement.

---

## PRINCIPES

1. **TOUJOURS deleguer via `new_task`** (jamais faire le travail soi-meme)
2. Communication locale via **dashboard INTERCOM** (`roosync_dashboard(type: "workspace")`). Fallback fichier `.claude/local/INTERCOM-myia-ai-01.md`. RooSync pour l'inter-machine.
4. Ne JAMAIS commit ou push
5. Deleguer uniquement aux modes `-simple` ou `-complex`
6. **WIN-CLI OBLIGATOIRE pour les commandes shell** : les modes `-simple` n'ont PAS acces au terminal natif. Utiliser UNIQUEMENT le MCP win-cli dans les prompts delegues.
7. **JAMAIS `write_to_file` pour fichiers >200 lignes** : Le modele Qwen 3.5 ne peut pas generer le parametre `content` pour les gros fichiers (erreur : "without value for required parameter content"). Utiliser `apply_diff` ou `replace_in_file` a la place. **TOUJOURS inclure cette instruction dans les prompts delegues qui impliquent de l'ecriture de fichiers.** Voir `.roo/rules/08-file-writing.md`.

## REGLES WIN-CLI (CRITIQUE)

Les modes `code-simple` et `debug-simple` n'ont plus acces au terminal par defaut (execute_command supprime). **Toujours inclure ces instructions dans les prompts `new_task`** (exemples a copier dans le message de delegation) :

```
# Build/Tests - utiliser win-cli :
execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npm run build")
execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run 2>&1 | Select-Object -Last 30")
# INTERDIT : vitest sans '2>&1 | Select-Object -Last 30' (output brut = 600KB = saturation contexte #827)

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

**DELEGUER** a `code-simple` via `new_task` :

```
Pre-flight check : tester win-cli MCP.
1. execute_command(shell="powershell", command="echo PRE-FLIGHT-OK")
2. Rapporter : PRE-FLIGHT-OK ou erreur exacte.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Decision :**
- Si la delegation reussit et rapporte `PRE-FLIGHT-OK` : continuer vers **Etape 1**
- Si la delegation echoue ou rapporte une erreur : **STOP IMMEDIAT**
  1. Deleguer a `code-simple` pour ecrire dans le dashboard INTERCOM :
     ```
     roosync_dashboard(action: "append", type: "workspace", machineId: "myia-ai-01", tags: ["CRITICAL", "roo-scheduler"], content: "MCP win-cli non disponible - Scheduler BLOQUE")
     Si le dashboard echoue, fallback fichier : ajouter a .claude/local/INTERCOM-myia-ai-01.md avec apply_diff.
     ```
  2. NE PAS continuer le workflow
  3. Terminer la tache

**Reference :** Voir `.roo/rules/05-tool-availability.md` pour le protocole complet.

### Etape 1 : Git pull + Lecture Dashboards

Deleguer a `code-simple` via `new_task` :

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

Utilise le MCP win-cli pour executer ces commandes et rapporter le resultat :
1. execute_command(shell="gitbash", command="git pull --no-rebase origin main")
2. execute_command(shell="gitbash", command="git status")

Puis lire le dashboard WORKSPACE (coordination cross-machine) :
3. roosync_dashboard(action: "read", type: "workspace", section: "all")

Si le dashboard echoue, FALLBACK fichier local :
3b. Lire les 5 derniers messages de .claude/local/INTERCOM-myia-ai-01.md avec read_file.

Chercher les messages avec tags [TASK], [SCHEDULED], [URGENT], [PROPOSAL].
Rapporter : etat git + contenu dashboard workspace + liste des taches trouvees.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Decision :**
- Si git pull a ECHOUE (submodule error, conflict) : aller DIRECTEMENT a **Etape 3** avec rapport d'erreur. Ne PAS executer de taches sur un workspace desynchronise.
- Si `[URGENT]` : escalader vers `orchestrator-complex`
- Si `[TASK]` trouve avec tag `[COMPLEX]` ET date < 24h : **escalader vers orchestrator-complex** (démarrage direct en mode complex)
- Si `[TASK]` trouve ET date < 24h : aller a **Etape 2a**
- Si `[TASK]` trouve MAIS date > 24h : IGNORER (tache perimee, noter dans le bilan)
- Si `[FEEDBACK]` recent de Claude : noter les ajustements
- Si rien : aller a **Etape 2b**

### Etape 1b : Check Heartbeats (Coordinateur uniquement)

**DELEGUER** a `code-simple` via `new_task` :

```
Verifier l'etat des machines executrices :
1. roosync_heartbeat(action="status", filter="all", includeHeartbeats=true)
2. Rapporter : liste des machines online/offline/warning.
   - online = OK
   - offline (>6h sans heartbeat) = signaler
   - warning (3-6h) = noter
```

**Si machine silencieuse (>6h) :** Deleguer a `code-simple` l'ecriture dans INTERCOM d'un message `[WARNING]` avec les details.

**Si echec heartbeat :** Noter dans le bilan mais continuer (heartbeat non bloquant).

### Etape 1c : Config-Sync (Coordinateur - optionnel, si > 24h depuis dernier)

**DELEGUER** a `code-simple` via `new_task` :

```
Config-sync coordinateur : synchroniser et comparer la configuration.
1. roosync_config(action: "collect", targets: ["modes", "mcp"])
2. roosync_config(action: "publish", version: "auto", description: "Config-sync coordinateur")
3. roosync_compare_config(granularity: "mcp")
4. Si > 7 jours depuis derniere baseline : roosync_baseline(action: "create", description: "Baseline hebdomadaire")
Rapporter : nombre de diffs par severite (critical, important, warning).
```

**Decision selon le resultat rapporte :**
- Si diffs CRITICAL : Deleguer l'envoi d'une directive corrective via RooSync
- Si `important > 0` : Noter dans le bilan pour suivi
- Verifier INTERCOM pour messages `[CONFIG-DRIFT]` des machines

**Frequence :** Une fois par 24h maximum.

**Si echec :** Noter dans le bilan mais continuer (config-sync non bloquant).

---



### Etape 1d : Auto-Review des commits recents (OBLIGATOIRE si HEAD a change)

> **CRITIQUE (#544) :** Cette etape DOIT etre executee apres CHAQUE pull qui ramene un nouveau commit.

**DELEGUER** a `code-simple` via `new_task` :

```
Verifier si le pull a ramene un nouveau commit et lancer l'auto-review si oui :
1. execute_command(shell="gitbash", command="git log HEAD@{1}..HEAD --oneline")
2. Si des commits sont retournes, lancer l'auto-review :
   execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/review/start-auto-review.ps1 -BuildCheck")
3. Rapporter : nombre de commits, resultat auto-review.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Si echec :** Noter dans le bilan mais continuer (non bloquant).

**Prerequis :** sk-agent MCP ou vLLM sur port 5002.

Apres auto-review → continuer vers **Etape 2a** ou **Etape 2b** (selon INTERCOM)

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

### Etape 2a-bis : Creer des taches Cross-Workspace pour executants (NOUVEAU)

> **Contexte :** Les executants (myia-po-*, myia-web1) peuvent avoir plusieurs workspaces. Cette etape permet au coordinateur de leur assigner des taches sur d'autres workspaces.

**Quand creer une tache cross-workspace :**
- Une issue GitHub mentionne un workspace specifique
- Une tache de maintenance est necessaire sur un autre projet
- Le coordinateur detecte un besoin sur un workspace secondaire

**Format de tache INTERCOM cross-workspace :**

```markdown
## [{DATE}] claude-code -> roo [TASK] [workspace:{CHEMIN_ABSOLU}]
### Titre de la tache

**Workspace cible :** {CHEMIN_ABSOLU}
**Machine cible :** {myia-po-2023|myia-po-2024|etc.}

Instructions :
1. Se placer dans le workspace cible
2. Executer les commandes demandées
3. Revenir au workspace principal (roo-extensions)
4. Rapporter dans l'INTERCOM principal
```

**Exemple concret :**

```markdown
## [2026-02-27 10:00:00] claude-code -> roo [TASK] [workspace:D:/dev/livresagites_wp]
### Build WordPress plugin

**Workspace cible :** D:/dev/livresagites_wp
**Machine cible :** myia-ai-01

Instructions :
1. cd D:/dev/livresagites_wp
2. git pull
3. npm run build
4. npm test
5. Rapporter le resultat
```

**Procedure pour le coordinateur :**

1. **Identifier la machine cible** :
   - La machine doit avoir le workspace dans son inventaire (#526)
   - La machine doit etre online (heartbeat recent)

2. **Ecrire la tache dans l'INTERCOM de la machine cible** :
   - Via RooSync message avec instruction "ecrire dans INTERCOM local"
   - Ou via delegation si le coordinateur a acces direct

3. **Suivre la reponse** :
   - L'executant rapportera dans son INTERCOM local
   - Le coordinateur doit verifier les reponses via heartbeat ou RooSync

**Regles de securite :**
- TOUJOURS specifier le chemin absolu du workspace
- TOUJOURS specifier la machine cible
- TOUJOURS inclure une instruction de retour au workspace principal
- NE PAS creer de taches cross-workspace pour des workspaces inconnus

Apres creation → **Etape 3**

### Etape 2b : Taches par defaut (si pas de [TASK])

Deleguer dans cet ordre a `code-simple` via `new_task` :

**1. Build + Tests (validation sante workspace)**

```
Utilise win-cli MCP pour executer dans le repertoire mcps/internal/servers/roo-state-manager :
1. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npm run build")
2. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run 2>&1 | Select-Object -Last 30")
Rapporter : build OK/FAIL + nombre tests pass/fail.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
INTERDIT : NE JAMAIS utiliser --coverage. TOUJOURS tronquer avec '2>&1 | Select-Object -Last 30' (output brut = 600KB = sature le contexte LLM #827).
```

**2. Verifier inbox RooSync (detecter messages pour Claude)**

```
Utilise win-cli MCP pour executer cette commande :
execute_command(shell="powershell", command="(Get-ChildItem 'G:/Mon Drive/Synchronisation/RooSync/.shared-state/messages/inbox/*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5).Name")
Rapporter : nombre et noms des fichiers recents.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**3. Si messages RooSync recents (< 6h) → signaler dans INTERCOM avec `[WAKE-CLAUDE]`**

**4. Chercher et dispatcher les issues roo-schedulable (OBLIGATOIRE)**

```
Utilise win-cli MCP :
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state open --limit 30 --label roo-schedulable --json number,title,labels")
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**5. Dispatcher les issues non assignees via GitHub comments**

Pour chaque issue trouvee (max 10) :

a. Verifier si deja dispatchee :
```
execute_command(shell="powershell", command="gh issue view {NUM} --repo jsboige/roo-extensions --json comments --jq '[.comments[-5:][] | .body | select(test(\"\\[DISPATCH\\]\"))] | length'")
```

b. Si NON dispatchee (resultat = 0), determiner la machine cible via les labels ou le body de l'issue :
```
execute_command(shell="powershell", command="gh issue view {NUM} --repo jsboige/roo-extensions --json labels,body --jq '{labels: [.labels[].name], body: .body[:300]}'")
```
Note : NE PAS utiliser `gh api graphql` en mode `-simple` (quoting instable, circuit breaker #737). Utiliser les labels/body pour determiner la machine. Si l'info Machine n'est pas dans les labels, dispatcher avec `[DISPATCH] Any`.

c. Commenter pour dispatcher (avec la machine trouvee) :
```
execute_command(shell="powershell", command="gh issue comment {NUM} --repo jsboige/roo-extensions --body '[DISPATCH] {MACHINE_CIBLE}. Priority: normal. Labels: {labels}. Execute this issue per its description.'")
```

**Regles de dispatch :**
- Si Machine = une machine specifique (myia-po-2023, etc.) → dispatcher a cette machine
- Si Machine = `All` → dispatcher avec `[DISPATCH] All` (tout executeur peut claimer)
- Si Machine = `Any` → dispatcher avec `[DISPATCH] Any` (tout executeur peut claimer)
- Si Machine non defini → dispatcher avec `[DISPATCH] Any`
- NE PAS dispatcher les issues avec label `claude-only` (reservees a Claude Code interactif)
- NE PAS re-dispatcher une issue deja claimee (commentaire `[CLAIMED]` existant)

**6. Executer une issue si faisable (optionnel, si du temps reste)**

Si une issue est dispatchee a `myia-ai-01` ou a `All`/`Any` et non encore claimee :
la lire, commenter `[CLAIMED] by myia-ai-01`, et executer si faisable en `-simple`.

Si aucune issue a executer : aller a **Etape 2c-idle** (Veille Active).

### Etape 2c-idle : Veille Active (si aucune tache trouvee)

> **Meme mecanisme que le workflow executeur.** Voir `.roo/scheduler-workflow-executor.md` Etape 2c-idle pour les regles completes.

**Resume pour le coordinateur :**
1. **Selection intelligente** : Lire INTERCOM (tags `[PATROL]`, `[FRICTION-FOUND]` < 7j) + `git log --since='7 days ago'` pour eviter les domaines deja couverts
2. **1 exploration lecture seule** parmi 8 domaines (outil MCP, doc vs realite, couverture tests, coherence config, sante infra, inventaire GitHub, rangement depot, consolidation doc)
3. **Rapport INTERCOM** : `[PATROL]` si OK, `[FRICTION-FOUND]` si probleme detecte
4. **Pas de creation d'issue directe** : le coordinateur Claude verifie et escalade

**Domaines supplementaires pour le coordinateur :**

| # | Domaine | Description |
|---|---------|-------------|
| 7 | **Rangement depot** | Deleguer a ask-simple : verifier que les fichiers sont au bon endroit (rapports dans `docs/`, scripts dans `scripts/`, pas de fichiers orphelins a la racine). Lister les fichiers mal places |
| 8 | **Consolidation doc** | Deleguer a ask-simple : chercher les fichiers .md qui couvrent le meme sujet (doublons semantiques). Verifier si leur contenu est deja dans les docs perennes (`CLAUDE.md`, `docs/roosync/*.md`). Rapporter les doublons |
| 9 | **Messages RooSync non traites** | Deleguer a code-simple : verifier s'il y a des messages anciens non lus ou non archives dans l'inbox RooSync |
| 10 | **Heartbeat cross-machine** | Deleguer a code-simple : appeler `roosync_heartbeat(action="status")` et rapporter l'etat des machines |

Apres exploration → **Etape 3**

### Etape 3 : Rapporter dans Dashboards (OBLIGATOIRE)

> **CRITIQUE :** Le rapport est la seule trace du passage du scheduler. **Ne JAMAIS quitter sans avoir ecrit le rapport.**
> **REGLE #836 :** Rapporter sur le dashboard WORKSPACE (cross-machine) ET sur workspace (local).

**METHODE PREFEREE — Dashboard MCP (pas d'approbation fichier) :**

Deleguer a `code-simple` via `new_task` :

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

Ecrire le bilan sur le dashboard WORKSPACE (cross-machine, visible par TOUTES les machines) :

roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["{DONE|MAINTENANCE|IDLE}", "roo-scheduler"],
  content: "### [myia-ai-01] Bilan scheduler coordinateur\n\n- Git: {OK/erreur} | Build: {OK/FAIL} | Tests: {X}p/{Y}f\n- Taches: {N} ({source}) | Erreurs: {aucune ou 1 ligne}\n- RooSync: {N} messages | Wake Claude: {oui/non}"
)

Si le dashboard MCP echoue, FALLBACK fichier local :
1. Lis les 20 dernieres lignes de .claude/local/INTERCOM-myia-ai-01.md avec read_file
2. Utilise apply_diff pour AJOUTER le message APRES le dernier separateur ---
3. Si apply_diff echoue : win-cli Add-Content
4. NE PAS utiliser write_to_file (boucle infinie sur gros fichiers)
```

**TAGS OBLIGATOIRES pour identifier l'auteur :**
- `roo-scheduler` = Roo orchestrateur coordinateur
- `roo-meta` = Roo meta-analyste
- `claude-scheduled` = Claude Worker schtask
- `claude-interactive` = Claude Code interactif

**Maintenance dashboard :** Le dashboard se condense automatiquement au-dela de 500 messages (`roosync_dashboard(action: "condense")`). Pas besoin de condensation manuelle.

### Etape 4 : TERMINER le cycle (OBLIGATOIRE)

> **CRITIQUE :** Apres l'Etape 3, l'orchestrateur DOIT appeler `attempt_completion` pour marquer la tache comme terminee. Sans cela, le scheduler considere la tache comme "en cours" et SAUTE les prochains ticks (`taskInteraction: "skip"`).

```
attempt_completion(result: "Cycle coordinateur termine. Bilan poste dans dashboard INTERCOM.")
```

**Si tu oublies cette etape**, la frequence du scheduler passe de 8h a ~24h+ car chaque tick suivant est saute.

---

## REGLES DE SECURITE

1. Ne JAMAIS commit sans validation Claude Code
2. Ne JAMAIS push directement
3. Ne JAMAIS faire `git checkout` dans le submodule `mcps/internal/`
4. **RooSync** : Deleguer a `code-simple` pour lire/envoyer des messages RooSync. Dashboard INTERCOM (`roosync_dashboard`) pour la communication locale (PAS le fichier `.claude/local/INTERCOM-*.md`)
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

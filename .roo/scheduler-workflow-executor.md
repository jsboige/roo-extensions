# Workflow Scheduler Roo - EXECUTEUR (machines non-coordinateur)

> Lu par orchestrateur-simple sur les machines executrices. MAJ : modifier + `git push`.

## PRINCIPES

1. **Roo n'utilise JAMAIS RooSync** (reserve a Claude Code)
2. **TOUJOURS deleguer via `new_task`** (jamais faire le travail soi-meme)
3. Communication via INTERCOM uniquement (`.claude/local/INTERCOM-{MACHINE}.md`)
4. Ne JAMAIS commit ou push (sauf config-sync automatique via RooSync - voir Etape 0c)
5. Deleguer uniquement aux modes `-simple` ou `-complex`
6. **WIN-CLI OBLIGATOIRE pour les commandes shell** : les modes `-simple` n'ont PAS acces au terminal natif. Utiliser UNIQUEMENT le MCP win-cli dans les prompts delegues.
7. **Scepticisme raisonnable** : Ne JAMAIS rapporter une limitation ou impossibilite sans preuve concrete (output de commande, message d'erreur exact). Verifier si le probleme est local ou distant. Qualifier : VERIFIE / SUPPOSE / RAPPORTE. Voir `.roo/rules/skepticism-protocol.md`.

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
roosync_heartbeat(action="register")
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
Pour chaque [TASK], vérifier s'il contient un tag [workspace:PATH].
Rapporter : etat git + liste des taches trouvees (avec workspace si spécifié).
```

**Decision :**
- Si git pull a ECHOUE (submodule error, conflict) : aller DIRECTEMENT a **Etape 3** avec rapport d'erreur. Ne PAS executer de taches sur un workspace desynchronise.
- Si `[URGENT]` : escalader vers `orchestrator-complex`
- Si `[TASK]` trouve avec tag `[COMPLEX]` ET date < 24h : **escalader vers orchestrator-complex** (démarrage direct en mode complex, voir **Etape 2a-complex** ci-dessous)
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

### Etape 2a-bis : Taches Cross-Workspace (NOUVEAU)

> **Prérequis :** Le workspace cible doit exister et avoir une config Roo minimale (`.roo/mcp.json`)

Si une tache INTERCOM contient le tag `[workspace:PATH]` :

**1. Delegation avec workspace specifique :**

```
Executer cette tache dans un workspace different :
- Workspace cible : {PATH from tag}
- Se placer dans ce workspace AVANT d'executer
- Apres execution, revenir au workspace principal
- Rapporter le resultat dans l'INTERCOM du workspace principal
```

**Exemple de delegation cross-workspace :**

```javascript
await new_task({
  title: "Build WordPress workspace",
  instructions: `
Tache cross-workspace vers : C:\\Users\\MYIA\\wsl_volumes\\livresagites_wp

1. execute_command(shell="powershell", command="cd C:\\Users\\MYIA\\wsl_volumes\\livresagites_wp; pwd")
2. execute_command(shell="gitbash", command="git status")
3. Executer les commandes demandees dans ce workspace
4. Revenir au workspace principal (roo-extensions)

Rapporter le resultat dans l'INTERCOM principal.
  `
});
```

**2. Validation du workspace cible :**

Avant d'executer, verifier que :
- Le chemin existe
- C'est un repertoire Git valide
- Le fichier `.roo/mcp.json` existe (optionnel pour les taches simples)

**3. Gestion des erreurs :**

- Si workspace inexistant : rapporter erreur dans INTERCOM + marquer tache FAIL
- Si workspace non Git : noter dans bilan mais continuer avec les commandes possibles
- Apres execution : TOUJOURS revenir au workspace principal

Apres execution → **Etape 3**

### Etape 2a-complex : Tâches [COMPLEX] (démarrage direct en mode complex)

> **Nouveau (2026-03-03) :** Pour les tâches étiquetées `[COMPLEX]`, démarrer directement en mode -complex pour prouver que Roo peut gérer des tâches de complexité moyenne. Voir Issue #545.

**Delegation directe a orchestrator-complex :**

```
Deleguer cette tâche COMPLEXE a orchestrator-complex via new_task :
- La tâche nécessite une réflexion supérieure (analyse multi-sources, coordination complexe)
- NE PAS essayer en -simple (échec attendu)
- Rapporter le resultat dans l'INTERCOM
```

**Exemple de delegation COMPLEX :**

```javascript
await new_task({
  title: "Tâche COMPLEXE : Analyse patterns MCP",
  instructions: `
Cette tâche est étiquetée [COMPLEX] - démarrer directement en mode complex.

1. Utiliser roosync_search pour trouver les tâches Roo récentes
2. Analyser view_task_details pour 5 tâches
3. Synthétiser les patterns d'utilisation des outils MCP
4. Rédiger un rapport dans l'INTERCOM

Ne PAS déléguer à code-simple (échec attendu sur ce type de tâche).
  `
});
```

**Critères de validation des tâches [COMPLEX] :**
- Résultat visible dans l'INTERCOM
- Preuve d'utilisation du mode -complex (traces, logs)
- Qualité supérieure à ce que -simple aurait produit

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

Si aucune issue : aller a **Etape 2c-idle** (Veille Active).

### Etape 2c-idle : Veille Active (si aucune tache trouvee)

> **Objectif :** Utiliser le temps idle pour explorer et tester UNE fonctionnalite du systeme. Detecter les frictions reelles (outils casses, doc obsolete, tests manquants, config incoherente) et les remonter pour traitement par le coordinateur.

**REGLES STRICTES :**
- **LECTURE SEULE** : ne JAMAIS modifier un fichier pendant l'exploration
- **1 seule exploration par session** : choisir UN domaine, l'explorer, rapporter
- **Pas de commit/push** : l'exploration ne produit que des rapports INTERCOM
- **Pas de creation d'issue directe** : si friction trouvee → `[FRICTION-FOUND]` dans INTERCOM, le coordinateur decidera

#### Selection intelligente du domaine (OBLIGATOIRE)

**Ne PAS choisir au hasard.** Deleguer a `ask-simple` via `new_task` :

```
Lis les 30 dernieres lignes de .claude/local/INTERCOM-{MACHINE}.md.
Identifie les domaines deja explores recemment (tag [PATROL] ou [FRICTION-FOUND] dans les 7 derniers jours).
Puis execute : execute_command(shell="gitbash", command="git log --oneline --since='7 days ago' | head -20")
Identifie les fichiers/domaines touches recemment dans les commits.

Rapporte :
- Domaines DEJA explores (a eviter) : [liste]
- Domaines touches par git (a eviter) : [liste]
- Domaine RECOMMANDE pour exploration : [1 choix parmi la liste ci-dessous]
```

**Domaines d'exploration (rotation, du plus simple au plus utile) :**

| # | Domaine | Description | Delegation |
|---|---------|-------------|------------|
| 1 | **Outil MCP peu utilise** | Tester un outil MCP jamais/rarement appele (ex: `roosync_baseline`, `roosync_decision`, `roosync_heartbeat`, `storage_info`, `maintenance`) avec des parametres basiques | `code-simple` |
| 2 | **Doc vs realite** | Lire un fichier .md (CLAUDE.md, une rule, un guide) et verifier que les chemins, noms d'outils, exemples de commandes qu'il mentionne existent reellement | `ask-simple` |
| 3 | **Couverture de tests** | Lister les fichiers source dans `src/tools/` et verifier s'ils ont un `__tests__/*.test.ts` correspondant. Rapporter les fichiers sans tests | `ask-simple` |
| 4 | **Coherence config** | Comparer une config deployee (`.roomodes`, `.roo/schedules.json`, `mcp_settings.json`) avec sa source (`roo-config/modes/`, template, etc.) et rapporter les ecarts | `code-simple` |
| 5 | **Sante infrastructure** | Tester un endpoint d'infrastructure (embeddings.myia.io, qdrant.myia.io, search.myia.io, tika.myia.io) avec une requete simple et rapporter le statut | `code-simple` |
| 6 | **Inventaire GitHub** | Lister les issues ouvertes avec `gh issue list` et identifier celles qui sont perimees (pas de commentaire > 14j), ou celles assignees a cette machine mais bloquees | `code-simple` |

**Choix du domaine :** Prendre le premier domaine de la liste qui N'a PAS ete explore dans les 7 derniers jours (selon INTERCOM + git). Si tous ont ete explores, recommencer au #1.

#### Execution de l'exploration

Deleguer au mode indique dans le tableau via `new_task` :

```
EXPLORATION VEILLE ACTIVE - Domaine #{N}: {titre}
Tu es en mode LECTURE SEULE. NE MODIFIE AUCUN FICHIER.

{Instructions specifiques au domaine choisi}

Rapporte :
- Ce que tu as teste/verifie
- Resultat : OK / FRICTION DETECTEE
- Si friction : description precise (output exact, fichier concerne, ecart constate)
- Recommandation courte (1-2 phrases max)
```

#### Rapport dans INTERCOM

**Si aucune friction :**
```markdown
## [{DATE}] roo -> claude-code [PATROL]
### Veille Active - Domaine #{N}: {titre}
- Resultat : OK
- Details : {ce qui a ete verifie}
```

**Si friction detectee :**
```markdown
## [{DATE}] roo -> claude-code [FRICTION-FOUND]
### Veille Active - Domaine #{N}: {titre}
- Friction : {description precise}
- Preuve : {output de commande, chemin de fichier, ecart constate}
- Severite estimee : {LOW|MEDIUM|HIGH}
- Recommandation : {action suggeree}
```

#### Escalade des frictions (GARDE-FOU ANTI-FEATURE-CREEP)

**Le scheduler simple NE CREE JAMAIS d'issue directement.** Le chemin d'escalade est :

```
[FRICTION-FOUND] dans INTERCOM (par mode simple / Haiku)
    → ETAPE 1 - Escalade vers agent complex (Roo -complex / Claude Sonnet-Opus)
      L'agent complex VERIFIE la friction avant de rediger l'issue :
      • Reproduire ou confirmer la friction independamment
      • La friction est-elle reelle ? (verifier avec git, code source, tests)
      • La friction est-elle nouvelle ? (pas deja reportee ou en cours de fix)
      • Evaluer la severite reelle (LOW/MEDIUM/HIGH/CRITICAL)
      • Verifier qu'aucune issue existante ne couvre deja ce probleme
      • Si la friction ne se confirme pas : rapporter "faux positif" dans INTERCOM, pas d'issue
    → ETAPE 2 - Si confirme : redaction issue GitHub par l'agent complex
      • Label `needs-approval` pour changements de fonctionnalite ou de harnais
      • Pas de label special pour tests, MAJ doc, ou corrections simples
    → ETAPE 3 - Coordinateur (Claude Opus) trie et dispatche
      • Verification supplementaire si necessaire (protocole skepticism)
      • Assignation machine + agent + priorite
    → ETAPE 4 - Utilisateur approuve SI NECESSAIRE
      • OBLIGATOIRE pour : changements de harnais, nouvelles fonctionnalites, modifications architecturales
      • PAS NECESSAIRE pour : ajout de tests, MAJ documentation, corrections de typos/chemins
```

**3 verrous anti-feature-creep :**
1. Le scheduler simple ne peut que RAPPORTER (INTERCOM), pas AGIR ni creer d'issue
2. L'agent complex VERIFIE la friction avant de creer l'issue (filtre les faux positifs)
3. Le coordinateur TRIE et l'utilisateur APPROUVE pour les changements significatifs

**Cout d'un faux positif :** Quelques minutes d'agent complex. **Cout d'un vrai positif non remonte :** Des heures de friction repetee sur 6 machines. Le systeme est volontairement biaise vers la detection (mieux vaut un faux positif filtre que manquer un vrai probleme).

Apres exploration → **Etape 2d** (Auto-review)

### Etape 2d : Auto-review des commits recents (OBLIGATOIRE si HEAD a change)

> Disponible uniquement sur les machines avec sk-agent ou acces vLLM.
> **CRITIQUE (#544) :** Cette etape DOIT etre executee apres CHAQUE pull qui ramene un nouveau commit.

Verifier si le pull (Etape 1) a ramene un nouveau commit :

```
execute_command(shell="gitbash", command="git log HEAD@{1}..HEAD --oneline")
```

Si la commande retourne des commits (HEAD a change), deleguer l'auto-review OBLIGATOIREMENT :

```
execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/review/start-auto-review.ps1 -BuildCheck")
```

**Parametres optionnels du script `auto-review.ps1` :**
- `-DiffRange "HEAD~3"` : Reviewer les N derniers commits
- `-IssueNumber 535` : Forcer le post sur une issue specifique
- `-Mode vllm` : Utiliser vLLM directement (sans sk-agent HTTP)
- `-DryRun` : Afficher la review sans poster sur GitHub

**Prerequis :** sk-agent MCP ou vLLM sur port 5002/v1 (Qwen3.5-35B). Fallback automatique HTTP → vLLM.

**Note :** Cette etape est optionnelle et non bloquante. Si echec, noter dans le bilan et continuer.

Apres etapes 2a, 2b, 2c-idle, 2d → **Etape 3**

### Etape 3 : Rapporter dans INTERCOM (OBLIGATOIRE)

> **CRITIQUE :** L'ecriture INTERCOM est la seule trace du passage du scheduler. Sans elle, Claude Code ne sait pas que Roo a tourne. **Ne JAMAIS quitter sans avoir ecrit dans INTERCOM.**

**METHODE PREFEREE (replace_in_file - append a la fin) :**

> Raison : `write_to_file` echoue sur les gros fichiers (>200 lignes) car le modele ne peut pas generer le parametre `content` en entier. `replace_in_file` n'a besoin que du dernier separateur `---` pour inserer apres.

```
1. Prepare le message (voir format ci-dessous)
2. Lis les 20 DERNIERES lignes du fichier INTERCOM avec read_file
3. Utilise replace_in_file pour ajouter le message APRES le dernier separateur ---
4. Si replace_in_file echoue : utilise win-cli Add-Content
   execute_command(shell="powershell", command="Add-Content -Path '.claude/local/INTERCOM-{MACHINE}.md' -Value 'message'")
5. NE PAS utiliser write_to_file sur les gros fichiers (boucle infinie garantie)
```

**FORMAT MESSAGE (garder court) :**

```markdown
## [{DATE}] roo -> claude-code [{DONE|IDLE}]
- Git: {OK/erreur} | Status: {propre/dirty}
- Build: {OK/FAIL} | Tests: {X} pass
- Taches: {N} (source: {INTERCOM/GitHub #num})
- Erreurs: {aucune ou description courte}
```

**FALLBACK (si replace_in_file echoue) :** Utiliser win-cli `Add-Content` directement, ou deleguer a `code-simple` via `new_task` avec instruction "utilise replace_in_file pour AJOUTER le message a la fin du fichier INTERCOM (NE PAS utiliser write_to_file)".

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

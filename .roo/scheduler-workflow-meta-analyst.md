# Workflow Scheduler Roo - META-ANALYSTE (toutes machines)

> Lu par orchestrateur-complex. MAJ : modifier ce fichier + `git push`.
> Frequence : 72h. Mode : orchestrator-complex (GLM-5 / Qwen 3.5 complex).

## PRINCIPES

1. **RooSync** : Disponible pour consultation. INTERCOM pour la communication locale
2. **TOUJOURS deleguer via `new_task`** (jamais faire le travail soi-meme)
3. Communication via META-INTERCOM (`.claude/local/META-INTERCOM-{MACHINE}.md`)
4. Ne JAMAIS commit ou push
5. **NE JAMAIS modifier les fichiers de harnais** (rules, workflows, modes, CLAUDE.md, .roomodes)
6. **WIN-CLI OBLIGATOIRE pour les commandes shell**
7. Toute recommandation actionnable = issue GitHub avec label `needs-approval`

## ROLE

Observer, analyser, PROPOSER. Le meta-analyste ne dispatche pas, ne trie pas, ne modifie rien.
Les propositions sont des issues GitHub `needs-approval` que le coordinateur (#540) ou l'utilisateur traitera.

---

## WORKFLOW EN 4 ETAPES

### Etape 0 : Pre-flight Check (OBLIGATOIRE)

Tester win-cli directement :

```
execute_command(shell="powershell", command="echo META-ANALYST-PREFLIGHT-OK")
```

**Decision :**
- Si OK : continuer vers **Etape 1**
- Si echec : **STOP IMMEDIAT**, ecrire dans META-INTERCOM `[CRITICAL] MCP win-cli non disponible`

### Etape 1 : Collecte et exploration des traces (MCP + PowerShell)

Deleguer a `code-complex` via `new_task` :

```
Tu es le meta-analyste. Collecte et explore les traces des schedulers locaux.
UTILISE LES OUTILS MCP roo-state-manager EN PRIORITE — ils sont plus riches que PowerShell brut.

== PARTIE A : EXPLORATION VIA MCP (PRIORITAIRE) ==

1. LISTER les taches recentes (POINT D'ENTREE OBLIGATOIRE) :
   conversation_browser(action: "list", limit: 20, sortBy: "lastActivity", sortOrder: "desc")
   → Identifier les IDs des 10 dernieres taches scheduler (orchestrator-simple, code-simple, code-complex)

2. ANALYSER les 5 taches les plus recentes :
   Pour chaque ID obtenu ci-dessus :
   conversation_browser(action: "view", task_id: "{ID}", detail_level: "summary", smart_truncation: true, max_output_length: 10000)
   → Chercher : erreurs, boucles, outils echoues, escalades

3. STATS de traces (optionnel si besoin de metriques) :
   conversation_browser(action: "summarize", summarize_type: "trace", taskId: "{ID}", detailLevel: "Summary", truncationChars: 5000)
   → Compression ratio, breakdown User/Assistant/Tools

4. FRICTIONS SEMANTIQUES (CRITIQUE — issue #807) :
   roosync_search(action: "semantic", search_query: "error fail impossible blocked permission denied", has_errors: true, start_date: "{date 72h ago YYYY-MM-DD}", max_results: 10)
   → Identifier les patterns de friction recurrents

5. FRICTIONS PAR OUTIL :
   Pour les outils suspects (ceux qui echouent souvent) :
   roosync_search(action: "semantic", search_query: "{nom_outil} error", tool_name: "{nom_outil}", max_results: 5)
   → Exemples d'outils a verifier : write_to_file, execute_command, new_task

6. VUE D'ENSEMBLE DASHBOARDS :
   roosync_dashboard(action: "read_overview")
   → Contexte rapide des 4 niveaux de dashboard en 1 appel

== PARTIE B : COMPLEMENTS (seulement si PARTIE A echoue ou incomplete) ==

⚠️ NE PAS utiliser cette partie si la PARTIE A a fonctionne. Les outils MCP fournissent
des donnees plus riches (smart_truncation, filtrage, metriques). La lecture de fichiers
bruts perd ces avantages et consomme plus de contexte.

7. METRIQUES GITHUB (complement utile meme si MCP OK) :
   execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state all --limit 20 --json number,state,closedAt,createdAt,title --jq '.[] | [.number, .state, .title] | @tsv'")

8. TRACES BRUTES (FALLBACK UNIQUEMENT — si conversation_browser echoue) :
   execute_command(shell="powershell", command="Get-ChildItem '$env:APPDATA/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks' -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 10 | ForEach-Object { $_.Name + ' - ' + $_.LastWriteTime }")

== RAPPORT ==

Rapporter :
- Nombre de taches Roo (success/fail/partial) avec IDs
- Modes utilises (simple vs complex) et ratio escalade
- Patterns de friction identifies (avec exemples concrets)
- Outils problematiques (noms + frequence d'echec)
- Nombre de sessions Claude recentes
- Issues crees vs fermees (7 derniers jours)
IMPORTANT : utilise win-cli MCP pour les commandes PowerShell (pas le terminal natif).
```

### Etape 2 : Analyse croisee des harnais

Deleguer a `code-complex` via `new_task` :

```
Tu es le meta-analyste. Analyse les DEUX harnais (Roo et Claude) pour identifier incoherences et ameliorations.

ETAPE PREALABLE - INVENTAIRE DYNAMIQUE (OBLIGATOIRE) :
AVANT de lire les fichiers, fais un inventaire complet :
execute_command(shell="powershell", command="Get-ChildItem '.roo/rules/' -Filter '*.md' | Select-Object Name")
execute_command(shell="powershell", command="Get-ChildItem '.claude/rules/' -Filter '*.md' | Select-Object Name")
Lis TOUS les fichiers retournes, pas seulement ceux listes ci-dessous.
La liste ci-dessous est indicative — le repertoire fait foi.

HARNAIS ROO (lis TOUS les fichiers de .roo/rules/ avec read_file) :
- .roo/rules/01-general.md
- .roo/rules/02-intercom.md
- .roo/rules/03-mcp-usage.md
- .roo/rules/04-sddd-grounding.md
- .roo/rules/05-tool-availability.md
- .roo/rules/06-context-window.md
- .roo/rules/07-orchestrator-delegation.md
- .roo/rules/08-file-writing.md
- .roo/rules/09-github-checklists.md
- .roo/rules/10-ci-guardrails.md
- .roo/rules/11-incident-history.md
- .roo/rules/12-machine-constraints.md
- .roo/rules/13-test-success-rates.md
- .roo/rules/14-tdd-recommended.md
- .roo/rules/15-coordinator-responsibilities.md
- .roo/rules/16-no-tools-warnings.md
- .roo/rules/17-friction-protocol.md
- .roo/rules/github-cli.md
- .roo/rules/skepticism-protocol.md
- .roo/rules/testing.md
- .roo/rules/validation.md
- .roo/scheduler-workflow-coordinator.md
- .roo/scheduler-workflow-executor.md
- .roomodes (structure des modes)

HARNAIS CLAUDE (lis TOUS les fichiers de .claude/rules/ avec read_file) :
- CLAUDE.md (racine)
- .claude/rules/agents-architecture.md
- .claude/rules/bash-fallback.md
- .claude/rules/ci-guardrails.md
- .claude/rules/condensation-thresholds.md
- .claude/rules/delegation.md
- .claude/rules/feedback-process.md
- .claude/rules/github-checklists.md
- .claude/rules/github-cli.md
- .claude/rules/intercom-protocol.md
- .claude/rules/mcp-discoverability.md
- .claude/rules/meta-analysis.md
- .claude/rules/myia-web1-constraints.md
- .claude/rules/pr-review-policy.md
- .claude/rules/roo-schedulable-criteria.md
- .claude/rules/scheduled-coordinator.md
- .claude/rules/scheduler-densification.md
- .claude/rules/scheduler-system.md
- .claude/rules/sddd-conversational-grounding.md
- .claude/rules/skepticism-protocol.md
- .claude/rules/test-success-rates.md
- .claude/rules/tool-availability.md
- .claude/rules/validation.md

GARDE ANTI-FAUX-POSITIFS (CRITIQUE) :
AVANT de conclure qu'une regle est ABSENTE d'un harnais :
0. LIS D'ABORD le fichier de mapping officiel :
   read_file(path="docs/harness/rules-mapping.md")
   Ce fichier contient la table d'equivalences verifiee entre .roo/rules/ et .claude/rules/.
   Un mapping "✅ Aligned" signifie que la regle existe des DEUX cotes (noms differents).
1. LIRE le CONTENU de TOUS les fichiers de l'autre harnais
2. Verifier si le sujet n'est pas couvert sous un NOM DIFFERENT
   Mappings officiels (voir docs/harness/rules-mapping.md pour la liste complete) :
   - Roo "02-intercom.md" = Claude "intercom-protocol.md"
   - Roo "03-mcp-usage.md" = Claude "mcp-discoverability.md"
   - Roo "04-sddd-grounding.md" = Claude "sddd-conversational-grounding.md"
   - Roo "06-context-window.md" = Claude "condensation-thresholds.md"
   - Roo "09-github-checklists.md" = Claude "github-checklists.md"
   - Roo "10-ci-guardrails.md" = Claude "ci-guardrails.md"
   - Roo "15-coordinator-responsibilities.md" = Claude "scheduled-coordinator.md"
   - Roo "17-friction-protocol.md" = Claude "friction-protocol.md"
   - Roo "18-meta-analysis.md" = Claude "meta-analysis.md"
3. NE JAMAIS creer d'issue pour une lacune sans avoir lu le contenu
   du fichier potentiellement equivalent
4. Si un sujet est couvert mais avec un nom different, c'est une
   INCOHERENCE DE NOMMAGE (INFO), PAS une lacune

ANALYSE :
1. Identifier les INCOHERENCES entre les deux harnais (regles contradictoires, references cassees)
2. Identifier les LACUNES REELLES (regles presentes dans un harnais mais pas l'autre, APRES verification du contenu)
3. Identifier les AMELIORATIONS potentielles (patterns qui marchent d'un cote mais pas de l'autre)
4. Verifier que les guard rails sont coherents (memes contraintes des deux cotes)

Rapporter :
- Tableau des incoherences trouvees (severity: CRITICAL/WARNING/INFO)
- Tableau des lacunes VERIFIEES (avec preuve que le sujet n'est couvert nulle part)
- 3-5 recommandations priorisees
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

### Etape 3 : Ecrire le rapport dans META-INTERCOM + Dashboard Workspace

> **CRITIQUE :** L'ecriture META-INTERCOM est la seule trace de l'analyse. **Ne JAMAIS quitter sans avoir ecrit.**
> **REGLE #836 :** Poster aussi un resume sur le dashboard WORKSPACE (cross-machine).

Deleguer a `code-complex` via `new_task` :

```
ETAPE PREALABLE — Poster un résumé sur le dashboard WORKSPACE (cross-machine) :

roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["META-ANALYSIS", "roo-meta"],
  content: "### [{MACHINE}] Bilan meta-analyste\n\n- Taches analysees: {N}, taux succes: {X}%\n- Recommandations: {N} (dont {X} needs-approval)\n- Issues creees: {N}\n- Rapport complet: META-INTERCOM-{MACHINE}.md"
)

PUIS ecrire le rapport detaille dans META-INTERCOM :

1. Lis .claude/local/META-INTERCOM-{MACHINE}.md en ENTIER avec read_file
   (Si le fichier n'existe pas, copier le template depuis .claude/local/META-INTERCOM_TEMPLATE.md et remplacer {MACHINE_NAME})
2. Compose le rapport avec ce format :

## [{DATE}] roo -> claude-code [META]
### Analyse Meta-Analyste Roo (cycle {DATE})

**Traces Roo (auto-analyse) :**
- {N} taches analysees, taux succes {X}%
- Modes utilises : {liste}
- Escalades : {N} (patterns identifies)

**Traces Claude (analyse croisee) :**
- {N} sessions recentes
- Issues traitees : {liste}
- Patterns remarques

**Analyse harnais :**
- Incoherences : {N} (dont {X} CRITICAL)
- Lacunes : {N}
- Ameliorations proposees : {N}

**Recommandations :**
1. {Recommandation 1} -> [action: INFO|needs-approval|harness-change]
2. {Recommandation 2} -> [action: ...]

---

3. Ajoute A LA FIN (ne supprime RIEN)
4. Reecris le fichier COMPLET avec write_to_file
5. Confirme que le dernier message est correct
```

### Etape 4 : Creer des issues GitHub si recommandations actionnables

**UNIQUEMENT si des recommandations de type `needs-approval` ont ete identifiees.**

Deleguer a `code-complex` via `new_task` :

```
GARDE ANTI-DUPLICATES (OBLIGATOIRE AVANT CREATION) :
Pour chaque recommandation, CHERCHER d'abord si une issue similaire existe deja :
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --search '{MOT-CLE}' --state all --limit 10 --json number,title,state")

Si une issue ouverte ou recemment fermee (<7 jours) couvre le meme sujet :
- NE PAS creer de doublon
- Noter dans META-INTERCOM : "Issue existante #{N} couvre deja ce point"

SEULEMENT si aucune issue existante ne couvre le sujet :

Utilise win-cli MCP pour creer des issues GitHub :

Pour chaque recommandation actionnable :
execute_command(shell="powershell", command="gh issue create --repo jsboige/roo-extensions --title '[META-ANALYSIS] {TITRE}' --label 'needs-approval' --body '{DESCRIPTION}'")

Si la recommandation concerne un changement de harnais :
execute_command(shell="powershell", command="gh issue create --repo jsboige/roo-extensions --title '[META-ANALYSIS] {TITRE}' --label 'needs-approval,harness-change' --body '{DESCRIPTION}'")

REGLES :
- TOUJOURS inclure le label 'needs-approval'
- TOUJOURS inclure le contexte de l'analyse (date, machine, findings)
- NE PAS creer plus de 3 issues par cycle (eviter le spam)
- NE PAS creer d'issue si la recommandation est purement informationnelle
- TOUJOURS verifier les issues existantes AVANT de creer (garde anti-duplicates)
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Si aucune recommandation actionnable :** sauter cette etape.

### Etape 5 : TERMINER le cycle (OBLIGATOIRE)

> **CRITIQUE :** Apres avoir termine toutes les etapes, l'orchestrateur DOIT appeler `attempt_completion` pour marquer la tache comme terminee. Sans cela, le scheduler considere la tache comme "en cours" et SAUTE les prochains ticks (`taskInteraction: "skip"`).

```
attempt_completion(result: "Cycle meta-analyste termine. Rapport poste dans META-INTERCOM.")
```

---

## REGLES DE SECURITE

1. Ne JAMAIS modifier de fichier de harnais (.roo/rules/, .claude/rules/, CLAUDE.md, .roomodes, etc.)
2. Ne JAMAIS commit ou push
3. Ne JAMAIS fermer, archiver ou dispatcher des issues GitHub
4. **RooSync** : Accessible en lecture pour l'analyse croisee. Privilegier META-INTERCOM pour les rapports
5. Ne JAMAIS creer d'issue SANS label `needs-approval`
6. **Limiter les outputs** : `Select-Object -Last 50` ou `tail -50`
7. **Maximum 3 issues par cycle** (anti-spam)
8. Si 2 echecs consecutifs : arreter et rapporter dans META-INTERCOM

---

## CRITERES D'ESCALADE

Ce workflow demarre DEJA en mode complex. Si un probleme grave est detecte :
- Ecrire dans INTERCOM operationnel (`[CRITICAL]` ou `[WARN]`)
- NE PAS tenter de corriger soi-meme

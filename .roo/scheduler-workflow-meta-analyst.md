# Workflow Scheduler Roo - META-ANALYSTE (toutes machines)

> Lu par orchestrateur-complex. MAJ : modifier ce fichier + `git push`.
> Frequence : 72h. Mode : orchestrator-complex (GLM-5 / Qwen 3.5 complex).

## PRINCIPES

1. **RooSync** : Disponible pour consultation. Dashboard pour la communication locale
2. **TOUJOURS deleguer via `new_task`** (jamais faire le travail soi-meme)
3. Communication via **dashboard `workspace`** (`roosync_dashboard`). Le fichier dashboard workspace est DEPRECATED.
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
- Si echec : **STOP IMMEDIAT**, ecrire sur le dashboard `[CRITICAL] MCP win-cli non disponible` via `roosync_dashboard(action: "append", type: "workspace", tags: ["CRITICAL", "roo-meta"], content: "...")`

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

6. INTERVENTIONS UTILISATEUR (OBLIGATOIRE — issue #981) :
   ⚠️ CRITIQUE : Roo est 100% schedulé. TOUTE intervention utilisateur = SIGNAL DE DYSFONCTIONNEMENT.
   roosync_search(action: "semantic", search_query: "non stop change fais plutot arrete reset", role: "user", source: "roo", start_date: "{date 72h ago YYYY-MM-DD}", max_results: 20)
   → Pour CHAQUE intervention detectee :
     - Classifier : BLOCAGE | CORRECTION | REDIRECTION | STOP/RESTART
     - Evaluer : l'intervention a-t-elle sauve la tache ? (SAVE) ou fallait-il balayer ? (SWEEP)
     - Si pattern recurrent (≥2 fois meme cause) → candidat issue needs-approval
   → Compter : interventions totales, par type, taux de sauvetage

7. EXPLOSIONS DE CONTEXTE (OBLIGATOIRE — issue #855) :
   Pour chaque tache analysee en etape 2, verifier :
   conversation_browser(action: "summarize", summarize_type: "trace", taskId: "{ID}", detailLevel: "Summary", truncationChars: 5000)
   → Alertes si : >30 messages, >50K chars, >10 appels au meme outil
   → Identifier l'outil le plus verbeux (souvent vitest sans troncature, read_file sans limit)
   → Compter : taches explosees, cause principale, outil le plus verbeux

8. ANALYSE DIFFERENTIELLE -simple vs -complex (OBLIGATOIRE — issue #981) :
   Croiser les donnees collectees ci-dessus pour comparer :
   → Nombre de taches par niveau (-simple vs -complex)
   → Taux de succes par niveau
   → Taux d'intervention utilisateur par niveau
   → Taux d'explosion de contexte par niveau
   → Escalades -simple → -complex : combien, pourquoi, reussies ou echouees
   → Patterns specifiques -simple : terminal natif au lieu de win-cli, outils indisponibles

9. VUE D'ENSEMBLE DASHBOARDS :
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
- **INTERVENTIONS UTILISATEUR :** nombre, classification (BLOCAGE/CORRECTION/STOP), evaluation SAVE/SWEEP
- **EXPLOSIONS CONTEXTE :** taches >30 messages, cause principale, outil le plus verbeux
- **COMPARAISON -simple vs -complex :** taux succes, interventions, explosions par niveau
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
- .roo/rules/18-meta-analysis.md
- .roo/rules/19-github-cli.md
- .roo/rules/20-pr-mandatory.md
- .roo/rules/21-skepticism-protocol.md
- .roo/rules/22-validation.md
- .roo/rules/23-no-deletion-without-proof.md
- .roo/scheduler-workflow-coordinator.md
- .roo/scheduler-workflow-executor.md
- .roomodes (structure des modes)

HARNAIS CLAUDE — rules/ auto-chargees (lis TOUS avec read_file) :
- CLAUDE.md (racine)
- .claude/rules/agents-architecture.md
- .claude/rules/ci-guardrails.md
- .claude/rules/context-window.md
- .claude/rules/delegation.md
- .claude/rules/file-writing.md
- .claude/rules/github-cli.md
- .claude/rules/intercom-protocol.md
- .claude/rules/no-deletion-without-proof.md
- .claude/rules/pr-mandatory.md
- .claude/rules/sddd-conversational-grounding.md
- .claude/rules/skepticism-protocol.md
- .claude/rules/test-success-rates.md
- .claude/rules/tool-availability.md
- .claude/rules/validation.md
- .claude/rules/worktree-cleanup.md

HARNAIS CLAUDE — docs/ on-demand (lis si pertinent) :
- docs/harness/reference/condensation-thresholds.md
- docs/harness/reference/escalation-protocol.md
- docs/harness/reference/feedback-process.md
- docs/harness/reference/friction-protocol.md
- docs/harness/reference/github-checklists.md
- docs/harness/coordinator-specific/pr-review-policy.md
- docs/harness/coordinator-specific/scheduled-coordinator.md
- docs/harness/machine-specific/myia-web1-constraints.md
- docs/harness/reference/bash-fallback.md
- docs/harness/reference/incident-history.md
- docs/harness/reference/mcp-discoverability.md
- docs/harness/reference/meta-analysis.md
- docs/harness/reference/roo-schedulable-criteria.md
- docs/harness/reference/scheduler-densification.md
- docs/harness/reference/scheduler-system.md
- docs/harness/reference/stub-detection.md

GARDE ANTI-FAUX-POSITIFS (CRITIQUE) :
AVANT de conclure qu'une regle est ABSENTE d'un harnais :
0. Verifier si la regle existe des DEUX cotes sous des noms differents.
1. LIRE le CONTENU de TOUS les fichiers de l'autre harnais
2. Verifier si le sujet n'est pas couvert sous un NOM DIFFERENT
   Mappings officiels :
   - Roo "02-intercom.md" = Claude "intercom-protocol.md"
   - Roo "03-mcp-usage.md" = Claude "mcp-discoverability.md"
   - Roo "04-sddd-grounding.md" = Claude "sddd-conversational-grounding.md"
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

### Etape 3 : Poster un RESUME COMPACT sur le Dashboard

> **CRITIQUE :** L'ecriture dashboard est la seule trace locale de l'analyse. **Ne JAMAIS quitter sans avoir ecrit.**
> **REGLE #1081 :** Dashboard = resume COMPACT (quelques lignes). Le DETAIL va dans les issues GitHub (Etape 4).
> **Ne JAMAIS poster de rapports detailles (>20 lignes) sur le dashboard.** Ca encombre inutilement.

Deleguer a `code-complex` via `new_task` :

```
Poster un RESUME COMPACT sur le dashboard workspace :

roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["META-ANALYSIS", "roo-meta"],
  content: "### [{MACHINE}] Meta-analyse (cycle {DATE})\n- Taches: {N} analysees, succes {X}%\n- Interventions user: {N} (dont {X} BLOCAGE)\n- Explosions contexte: {N}\n- Harnais: {N} incoherences\n- Issues creees: #{N1}, #{N2} (details dans les issues)\n- Score sante outillage: {A|B|C|D}"
)

REGLES :
- Maximum 10 lignes dans le dashboard
- Pas de tableaux detailles, pas de listes d'outils, pas de rapports verbeux
- Chaque finding actionnable = une issue GitHub (Etape 4) avec le detail complet
- Le dashboard est un INDEX vers les issues, pas un rapport
```

### Etape 4 : Creer des issues GitHub avec le DETAIL COMPLET

> **REGLE #1081 :** Les issues GitHub sont le lieu du DETAIL. Le dashboard (Etape 3) n'est qu'un resume compact.
> Chaque finding actionnable = 1 issue avec contexte complet, donnees, et recommandation.

**UNIQUEMENT si des recommandations actionnables ont ete identifiees.**

Deleguer a `code-complex` via `new_task` :

```
GARDE ANTI-DUPLICATES (OBLIGATOIRE AVANT CREATION) :
Pour chaque recommandation, CHERCHER d'abord si une issue similaire existe deja :
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --search '{MOT-CLE}' --state all --limit 10 --json number,title,state")

Si une issue ouverte ou recemment fermee (<7 jours) couvre le meme sujet :
- NE PAS creer de doublon
- Noter dans dashboard workspace : "Issue existante #{N} couvre deja ce point"

SEULEMENT si aucune issue existante ne couvre le sujet :

Utilise win-cli MCP pour creer des issues GitHub.

Pour chaque recommandation actionnable, creer une issue DETAILLEE :
execute_command(shell="powershell", command="gh issue create --repo jsboige/roo-extensions --title '[META-ANALYSIS] {TITRE}' --label 'needs-approval' --body '## Contexte\n\n{Date, machine, cycle meta-analyse}\n\n## Constat\n\n{Description detaillee du finding avec donnees chiffrees}\n{Tableaux, metriques, exemples concrets}\n\n## Impact\n\n{Consequences si non traite}\n\n## Recommandation\n\n{Action proposee avec justification}\n\n## Donnees brutes\n\n{Extraits de traces, stats, exemples}'")

Si la recommandation concerne un changement de harnais, ajouter le label :
--label 'needs-approval,harness-change'

REGLES :
- TOUJOURS inclure le label 'needs-approval'
- Le body de l'issue DOIT contenir TOUT le detail (c'est le lieu du rapport complet)
- Inclure les donnees chiffrees, tableaux, exemples concrets — PAS juste un titre
- NE PAS creer plus de 3 issues par cycle (eviter le spam)
- NE PAS creer d'issue si la recommandation est purement informationnelle
- TOUJOURS verifier les issues existantes AVANT de creer (garde anti-duplicates)
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Si aucune recommandation actionnable :** sauter cette etape.

### Etape 5 : TERMINER le cycle (OBLIGATOIRE)

> **CRITIQUE :** Apres avoir termine toutes les etapes, l'orchestrateur DOIT appeler `attempt_completion` pour marquer la tache comme terminee. Sans cela, le scheduler considere la tache comme "en cours" et SAUTE les prochains ticks (`taskInteraction: "skip"`).

```
attempt_completion(result: "Cycle meta-analyste termine. Rapport poste dans dashboard workspace.")
```

---

## REGLES DE SECURITE

1. Ne JAMAIS modifier de fichier de harnais (.roo/rules/, .claude/rules/, CLAUDE.md, .roomodes, etc.)
2. Ne JAMAIS commit ou push
3. Ne JAMAIS fermer, archiver ou dispatcher des issues GitHub
4. **RooSync** : Accessible en lecture pour l'analyse croisee. Privilegier dashboard workspace pour les rapports
5. Ne JAMAIS creer d'issue SANS label `needs-approval`
6. **Limiter les outputs** : `Select-Object -Last 50` ou `tail -50`
7. **Maximum 3 issues par cycle** (anti-spam)
8. Si 2 echecs consecutifs : arreter et rapporter dans dashboard workspace

---

## CRITERES D'ESCALADE

Ce workflow demarre DEJA en mode complex. Si un probleme grave est detecte :
- Ecrire dans dashboard workspace via `roosync_dashboard(action: "append", type: "workspace", tags: ["WARN"], content: "...")`
- NE PAS tenter de corriger soi-meme

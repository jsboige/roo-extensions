# Workflow Scheduler Roo - META-ANALYSTE (toutes machines)

> Lu par orchestrateur-complex. MAJ : modifier ce fichier + `git push`.
> Frequence : 72h. Mode : orchestrator-complex (GLM-5 / Qwen 3.5 complex).
> **PRÉAMBULE** : Lire `.roo/scheduler-workflow-shared.md` pour les règles communes (autonomie, circuit breaker, output, win-cli, rapport dashboard).

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
   → Identifier l'outil le plus verbeux (souvent vitest sans troncation, read_file sans limit)
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

⚠️ NE PAS utiliser cette partie si la PARTIE A a fonctionne.

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

### Etape 2 : Analyse qualite des taches et resultats

Deleguer a `code-complex` via `new_task` :

```
Tu es le meta-analyste. Analyse la QUALITE DU TRAVAIL REEL effectue par les agents (Roo et Claude) sur les 7 derniers jours.

FOCUS : le contenu des taches, pas la structure des harnais.

ETAPE 1 — REVUE DES PRs RECENTES (OBLIGATOIRE) :
execute_command(shell="powershell", command="gh pr list --state all --limit 20 --json number,title,state,mergedAt,author,labels --repo jsboige/roo-extensions 2>&1 | Select-Object -First 60")
Pour chaque PR merged recemment :
- Le titre reflete-t-il le travail reel ?
- Les issues liees sont-elles fermees ?
- Le scope est-il coherent (pas de drift) ?
Signaler toute PR merged sans review ou avec scope excessif.

ETAPE 2 — TRAVAIL STALE / ABANDONNE :
execute_command(shell="powershell", command="gh issue list --state open --label 'in-progress' --json number,title,assignees,updatedAt --repo jsboige/roo-extensions 2>&1 | Select-Object -First 40")
execute_command(shell="powershell", command="git worktree list 2>&1 | Select-Object -First 20")
Identifier :
- Issues assignees sans activite >7 jours
- Worktrees orphelins (sans PR, sans commit recent)
- Issues [CLAIMED] sans [RESULT]

ETAPE 3 — QUALITE D'EXECUTION DES DISPATCHES :
Lire le dashboard workspace pour les messages [DISPATCH], [CLAIMED], [RESULT], [DONE] recents.
Pour chaque dispatch :
- A-t-il ete pris en charge ? (delai entre dispatch et claim)
- Le resultat correspond-il a la demande ? (scope, qualite)
- Y a-t-il des dispatches ignores ou bloques ?

ETAPE 4 — METRIQUES OPERATIONNELLES :
execute_command(shell="powershell", command="gh issue list --state open --json number,title,labels,updatedAt --limit 50 --repo jsboige/roo-extensions 2>&1 | Select-Object -First 80")
execute_command(shell="powershell", command="gh issue list --state closed --limit 20 --json number,title,closedAt,labels --repo jsboige/roo-extensions 2>&1 | Select-Object -First 40")
Calculer :
- Ratio issues ouvertes vs fermees (7 derniers jours)
- Issues >30 jours sans activite (candidates au nettoyage)
- Labels les plus frequents (identifier les themes dominants)

ETAPE 5 — PROBLEMES DE QUALITE A SIGNALER :
Ne rapporter QUE des problemes REELS observes dans les donnees :
- PRs merges avec regressions ou travail incomplet
- Issues fermees prematurement (sans preuve de completion)
- Dispatches systematiquement ignores par certaines machines
- Patterns d'echec recurrents (memes erreurs, memes modes)
- Travail duplique (2 agents sur la meme tache)

NE PAS rapporter :
- Differences de nommage entre fichiers de regles
- Suggestions d'harmonisation de harnais
- Problemes theoriques sans donnees concretes

Rapporter :
- Tableau des PRs recentes (etat, qualite, issues liees)
- Liste des travaux stale/abandonnes avec recommandation (relancer, fermer, reassigner)
- Metriques issues (ratio, age moyen, tendance)
- 3-5 problemes de qualite CONCRETS avec preuves
IMPORTANT : utilise win-cli MCP pour les commandes PowerShell (pas le terminal natif).
```

### Etape 3 : Poster un RESUME COMPACT sur le Dashboard

> **CRITIQUE :** L'ecriture dashboard est la seule trace locale de l'analyse. **Ne JAMAIS quitter sans avoir ecrit.**
> **REGLE #1081 :** Dashboard = resume COMPACT (quelques lignes). Le DETAIL va dans les issues GitHub (Etape 4).
> **Ne JAMAIS poster de rapports detailles (>20 lignes) sur le dashboard.**

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
- Le body de l'issue DOIT contenir TOUT le detail
- Inclure les donnees chiffrees, tableaux, exemples concrets
- NE PAS creer plus de 3 issues par cycle (eviter le spam)
- NE PAS creer d'issue si la recommandation est purement informationnelle
- TOUJOURS verifier les issues existantes AVANT de creer
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Si aucune recommandation actionnable :** sauter cette etape.

### Etape 5 : TERMINER le cycle (OBLIGATOIRE)

> **CRITIQUE :** Apres avoir termine toutes les etapes, l'orchestrateur DOIT appeler `attempt_completion` pour marquer la tache comme terminee. Sans cela, le scheduler considere la tache comme "en cours" et SAUTE les prochains ticks.

```
attempt_completion(result: "Cycle meta-analyste termine. Rapport poste dans dashboard workspace.")
```

---

## REGLES DE SECURITE

1. Ne JAMAIS modifier de fichier de harnais (.roo/rules/, .claude/rules/, CLAUDE.md, .roomodes, etc.)
2. Ne JAMAIS commit ou push
3. Ne JAMAIS fermer, archiver ou dispatcher des issues GitHub
4. **RooSync** : Accessible en lecture. Privilegier dashboard workspace pour les rapports
5. Ne JAMAIS creer d'issue SANS label `needs-approval`
6. **Limiter les outputs** : `Select-Object -Last 50` ou `tail -50`
7. **Maximum 3 issues par cycle** (anti-spam)
8. Si 2 echecs consecutifs : arreter et rapporter dans dashboard workspace
9. **PAS de fichiers rapport (#1179)** : Ne JAMAIS creer de fichiers dans docs/ ou ailleurs dans le depot. Les rapports vont sur le dashboard ou en issues GitHub, JAMAIS dans des fichiers git-trackes.

---

## CRITERES D'ESCALADE

Ce workflow demarre DEJA en mode complex. Si un probleme grave est detecte :
- Ecrire dans dashboard workspace via `roosync_dashboard(action: "append", type: "workspace", tags: ["WARN"], content: "...")`
- NE PAS tenter de corriger soi-meme

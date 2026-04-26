# Meta-Analyste — Workflow Detaille (Reference)

**Version:** 1.3.0
**Source :** `.claude/rules/meta-analyst.md` (version slim)
**Issues :** #1375, #1455, #1584, #1621
**Miroir Roo :** `.roo/scheduler-workflow-meta-analyst.md` (297 lignes)

---

## Workflow complet en 5 etapes

### Etape 0 : Pre-flight

Verifier outils critiques :

```
conversation_browser(action: "current")
```

- OK → continuer Etape 1
- Echec → STOP, dashboard `[CRITICAL] MCP roo-state-manager indisponible` via `roosync_dashboard(action: "append", type: "workspace", tags: ["CRITICAL", "claude-meta"], content: "...")`

### Etape 1 : Collecte traces (MCP priorite)

Deleguer a `codebase-researcher` ou executer directement selon le scope. **MCP prioritaire sur Bash**.

1. **Lister les taches recentes** (OBLIGATOIRE en premier) :
   ```
   conversation_browser(action: "list", limit: 20, sortBy: "lastActivity", sortOrder: "desc")
   ```

2. **Analyser les 5 plus recentes** :
   ```
   conversation_browser(action: "view", task_id: "{ID}", detail_level: "summary", smart_truncation: true, max_output_length: 10000)
   ```

3. **Frictions semantiques** (#807) :
   ```
   roosync_search(action: "semantic", search_query: "error fail impossible blocked permission denied", has_errors: true, start_date: "{72h ago}", max_results: 10)
   ```

4. **Frictions par outil** :
   ```
   roosync_search(action: "semantic", search_query: "{tool} error", tool_name: "{tool}", max_results: 5)
   ```

5. **Interventions utilisateur** (#981) :
   ```
   roosync_search(action: "semantic", search_query: "non stop change fais plutot arrete reset", role: "user", start_date: "{72h ago}", max_results: 20)
   ```
   Pour chaque intervention : classifier BLOCAGE/CORRECTION/REDIRECTION/STOP, evaluer SAVE vs SWEEP. Pattern recurrent (>=2 fois) = candidat issue.

6. **Explosions contexte** (#855) :
   ```
   conversation_browser(action: "summarize", summarize_type: "trace", taskId: "{ID}", detailLevel: "Summary", truncationChars: 5000)
   ```
   Alertes : >30 messages, >50K chars, >10 appels meme outil.

7. **Analyse differentielle -simple vs -complex** (#981) : croiser taux succes, interventions, explosions par niveau.

8. **Vue dashboards** :
   ```
   roosync_dashboard(action: "read_overview")
   ```

9. **Config drift operational** (#1584) : detecter les configs deployees qui divergent du depot de reference.
   - **Scope strict (pas d'extension)** : uniquement `win-cli` `commandTimeout`, `mcp_settings.json` server list, `unrestricted-config.json`. PAS d'extension a d'autres configs sans issue explicite.
   - **Signal positif (pas hard-reject)** : si la valeur deployee differe du depot, **c'est un drift reel** a signaler — pas une asymetrie theorique.
   - **Procedure** :
     ```
     roosync_search(action: "semantic", search_query: "timed out timeout error fail", has_errors: true, tool_name: "execute_command", start_date: "{72h ago}", max_results: 10)
     ```
     Croiser avec le depot : `Read(mcps/internal/servers/win-cli/src/unrestricted-config.json)` vs la config deployee localement (`%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\win_cli_config.json`). Si delta → candidat issue.
   - **Locale only** : le meta-analyste verifie SA machine. Cross-machine = optionnel via `roosync_inventory` mais PAS obligatoire.
   - **Exemple valide** : "win-cli `commandTimeout=180s` deploye sur ma machine vs `600s` dans depot → drift operational, issue `needs-approval`."
   - **HARD REJECT** : si la config deployee === config depot, NE PAS creer d'issue "pourrait etre plus grand". Le depot EST la reference.

### Etape 2 : Analyse qualite PRs et issues

Utiliser `Bash` avec `gh` (pas de win-cli pour Claude) :

- **PRs recents** : `gh pr list --state all --limit 20 --repo jsboige/roo-extensions --json number,title,state,mergedAt,author,labels`
  Verifier : titre reflette le travail, issues liees fermees, scope coherent.
- **Travail stale** : `gh issue list --state open --label 'in-progress' --limit 40 --json number,title,assignees,updatedAt`
  + `git worktree list` pour worktrees orphelins.
- **Metriques issues** : ratio ouvertes/fermees 7j, age moyen, labels dominants.
- **Qualite dispatches** : lire dashboard workspace pour `[DISPATCH]`, `[CLAIMED]`, `[RESULT]`, `[DONE]`.

**Ne rapporter QUE des problemes REELS** observes dans les donnees. Pas de suggestions theoriques d'harmonisation.

### Etape 3 : Resume COMPACT sur dashboard

> **REGLE #1081 :** Dashboard = resume COMPACT (<=10 lignes). Detail = issues GitHub.

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["META-ANALYSIS", "claude-meta"],
  content: "### [ai-01] Meta-analyse Claude (cycle {DATE})\n- Taches: {N} analysees, succes {X}%\n- Interventions user: {N} (dont {X} BLOCAGE)\n- Explosions contexte: {N}\n- Issues creees: #{N1}, #{N2}\n- Score sante outillage: {A|B|C|D}"
)
```

### Etape 4 : Issues GitHub (DETAIL)

**UNIQUEMENT si recommandations actionnables.**

**Garde anti-doublons (OBLIGATOIRE AVANT creation) :**
```bash
gh issue list --repo jsboige/roo-extensions --search '{MOT-CLE}' --state all --limit 10 --json number,title,state
```

Si issue ouverte ou fermee <7j couvre le sujet : NE PAS creer, noter dans dashboard "Issue existante #{N} couvre deja ce point".

Sinon, creer issue DETAILLEE avec label `needs-approval` :
```bash
gh issue create --repo jsboige/roo-extensions --title '[META-ANALYSIS] {TITRE}' --label 'needs-approval' --body '## Contexte\n...\n## Constat\n{donnees chiffrees}\n## Impact\n...\n## Recommandation\n...\n## Donnees brutes\n{extraits traces}'
```

Si harness : ajouter label `harness-change`.

**Regles :**
- TOUJOURS label `needs-approval`
- Body = TOUT le detail (donnees, tableaux, exemples)
- Maximum 3 issues par cycle (anti-spam)
- Verifier doublons AVANT

### Etape 5 : Rapport final

Poster `[DONE]` sur dashboard workspace et clore la session.

---

## HARD REJECT — Rapports INTERDITS

Ces sujets sont **interdits** meme si l'analyse les detecte. Incidents historiques : #1455 (asymetrie INTERCOM v3.0.0/v3.2.0, 2026-04-17, rejete par utilisateur).

| Categorie | Exemple | Pourquoi interdit |
|-----------|---------|-------------------|
| Asymetrie de version doc | `.roo/rules/X v3.0.0` vs `.claude/rules/X v3.2.0` | Cycles d'evolution differents. Pas un bug. |
| "Harmoniser", "synchroniser", "aligner" | "Synchroniser SDDD vers v3.0.0" sans incident | Harmonisation theorique = entropie. |
| Refactoring architectural sans incident | "Extraire un service", "centraliser un helper" | Si ca n'a pas casse, ne pas le reecrire. |
| Naming convention drift | `field to vs target`, `machineId vs machine_id` | Pure cosmetique. |
| Doublons apparents sans incident | "Fonction X definie dans Y et Z" | Peut etre volontaire (isolation, perf #1145). |
| Metrique sans seuil depasse | "Taux de succes 92%" sans constat de regression | Juste un chiffre. |

### Test de validation AVANT creation d'issue (OBLIGATOIRE)

Avant de creer toute issue `[META-ANALYSIS]`, repondre aux 3 questions :

1. **Y a-t-il un incident concret avec timestamp et trace ?**
2. **Le probleme est-il REPRODUIT par les donnees ?**
3. **Si je ne cree PAS cette issue, qu'est-ce qui casse ?** Si "rien, c'est juste moins propre" → **NE PAS CREER.**

### Exemples de rapports LEGITIMES

- "Task #N a boucle 10x sur win-cli blocked operators entre HHMM et HH'MM'" (avec traces)
- "MCP roo-state-manager crash sur po-2024 le DATE, erreur X, 3 recurrences cette semaine"
- "Explosion contexte detectee sur tache #M (>50K chars en 1 tour)"
- "7 sessions Claude >100 MB identifiees (INFO seulement, aucune action requise — #1621)"

Ces exemples ont tous : **timestamp**, **reproduction**, **impact concret**.

---

## Differences avec le Meta-Analyste Roo

| Aspect | Roo (`orchestrator-complex`) | Claude Code |
|--------|-----------------------------|-------------|
| Cadence | 72h (scheduler) | Ad-hoc (utilisateur/coordinateur) |
| Outils exec | `execute_command` + win-cli MCP | `Bash` (gh, git, ls) directement |
| Delegation | `new_task` vers `code-complex` | `Agent` vers subagents |
| MCP critique | win-cli + roo-state-manager | roo-state-manager uniquement |

---

**Source Roo :** `.roo/scheduler-workflow-meta-analyst.md` (297 lignes)
**Issues liees :** #807 (frictions), #855 (contexte), #981 (interventions), #1081 (dashboard compact), #1179 (pas de fichiers), #1375 (cette regle), #1621 (sessions sanctuary)

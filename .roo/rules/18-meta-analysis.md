# Protocole Meta-Analyse - Architecture 3x2 Scheduler (Roo)

**Version:** 1.0.0
**Cree:** 2026-03-15
**Issue:** #705 (adaptation depuis `.claude/rules/meta-analysis.md`)

---

## Vue d'ensemble

Le tier meta-analyse fait partie de l'**architecture 3 tiers** (3 types x 2 agents = 6 schedulers) :

| Tier | Frequence | Machines | Role |
|------|-----------|----------|------|
| **Meta-Analyste** | 72h | TOUTES | Observer, analyser, PROPOSER |
| Coordinateur | 6-12h | ai-01 only | Trier, dispatcher, suivre |
| Executeur | 6h | TOUTES | Executer les taches assignees |

Chaque tier a 2 agents : un scheduler Roo + un scheduler Claude.

---

## Role du Meta-Analyste Roo

**Mission :** Analyser independamment LES DEUX schedulers (Roo + Claude) sur la machine locale, puis reconcilier les conclusions via dashboard workspace.

### Ce que Roo analyse

**1. Ses propres traces (auto-analyse)**

Metriques a extraire :

- Taux de succes/echec par mode (`*-simple` vs `*-complex`)
- Patterns d'escalade (combien de fois -simple → -complex)
- Usages d'outils (win-cli OK ? roosync_* appeles correctement ?)
- Efficacite de la delegation (new_task bien formate ?)

**Outils MCP roo-state-manager (OBLIGATOIRES — ne JAMAIS lire les fichiers JSON bruts) :**

```
# 1. LISTER les taches recentes (POINT D'ENTREE OBLIGATOIRE)
conversation_browser(action: "list", limit: 20, sortBy: "lastActivity", sortOrder: "desc")

# 2. ANALYSER chaque tache (smart_truncation evite l'explosion de contexte)
conversation_browser(action: "view", task_id: "{ID}", detail_level: "summary", smart_truncation: true, max_output_length: 10000)

# 3. STATS (optionnel, pour metriques compression/breakdown)
conversation_browser(action: "summarize", summarize_type: "trace", taskId: "{ID}", detailLevel: "Summary", truncationChars: 5000)
```

**INTERDIT :** `Get-ChildItem %APPDATA%\...\tasks\` ou lecture directe de fichiers JSON de taches. Le MCP fournit les memes donnees avec filtrage, truncation, et structure.

**2. Traces Claude (analyse croisee)**

**⚠️ LIMITATION CONNUE (issue #874) :** Les sessions Claude ne sont PAS indexées dans Qdrant.

**Conséquence :** `roosync_search(action: "semantic", source: "claude-code")` retourne 0 résultats.

**Workaround actuel :**

Via MCP roo-state-manager (source: "claude-code" - NE FONCTIONNE PAS CAR NON INDEXÉ) :

```
# Sessions Claude recentes - NE RETOURNE RIEN (non indexé)
roosync_search(action: "semantic", search_query: "session work implementation", source: "claude-code", start_date: "{7j ago}", max_results: 10)
```

**Alternatives fonctionnelles :**
- Commits recents Claude : `git log --oneline --author="Claude" -10`
- Logs worker Claude : `.claude/logs/worker-*.log` (seulement si le worker schedule est actif)
- Lecture directe worktrees : `ls .claude/worktrees/` pour identifier les sessions récentes
- INTERCOM local : `.claude/local/INTERCOM-{MACHINE}.md` pour les bilans

**Note :** L'indexation automatique des sessions Claude est planifiée mais pas encore implémentée.

**3. Harnais Claude (analyse croisee)**

Roo est PLUS LIBRE de critiquer le harnais Claude que le sien propre :

- `.claude/rules/` (toutes les regles)
- `CLAUDE.md` (configuration principale)
- `.claude/commands/` et `.claude/skills/`
- `.claude/agents/`

**4. Metriques operationnelles**

- Issues GitHub creees vs fermees (7 derniers jours)
- Taux d'utilisation machine (commits, messages RooSync)
- Violations de garde-fous detectees dans les traces

**5. Recherche semantique de frictions (#637)**

Utiliser `roosync_search` avec filtres avances pour detecter les frictions recentes :

```
# Via win-cli MCP (Roo) :
roosync_search(action: "semantic", search_query: "impossible bloque erreur fail", has_errors: true, start_date: "{72h ago}", max_results: 10)
# Filtres utiles : tool_name (outil fautif), model (modele specifique), source ("roo" ou "claude-code")
```

- Patterns recurrents (≥ 2 occurrences) → candidats issues friction
- Correlations outil + erreur → root cause probable

### Ce que Roo produit

- **Docs d'analyse** sur GDrive (structures, horodates)
- **Entrees dashboard workspace** (reconciliation)
- **Issues GitHub avec `needs-approval`** (propositions d'amelioration)
- **Issues GitHub avec `needs-approval` + `harness-change`** (modifications de harnais, BLOQUEES jusqu'a approbation utilisateur)

---

## Protocole dashboard workspace

**Fichier :** `.claude/local/dashboard workspace-{MACHINE}.md`

Canal dedie a la reconciliation meta-analyse. SEPARE de l'INTERCOM operationnel.

### Workflow

1. Roo ecrit son analyse (auto + croisee) dans dashboard workspace
2. Claude lit l'analyse de Roo, ecrit la sienne + notes de reconciliation
3. Les deux agents peuvent commenter les conclusions de l'autre
4. Les conclusions actionnables deviennent des issues GitHub avec `needs-approval`

### Format d'entree dashboard workspace

```markdown
## [YYYY-MM-DD HH:MM:SS] roo -> claude [META-ANALYSIS]

### Analyse Auto (Roo)
- Taux succes -simple : X%
- Taux succes -complex : Y%
- Erreurs recurrentes : [liste]
- Escalades appropriees : Z%

### Analyse Croisee (Claude harness)
- Findings sur .claude/rules/ : [liste]
- Findings sur CLAUDE.md : [liste]
- Recommandations : [liste]

### Conclusions Actionnables
- [Chaque item = potentiellement une issue needs-approval]

---
```

### Consultation Cross-Machine (apres reconciliation locale)

Quand Roo et Claude ont **reconcilie** leurs conclusions via dashboard workspace et qu'une conclusion est non-triviale, Roo MAY consulter d'autres machines.

**Procedure (via delegation) :**

```
new_task({
  mode: "code-simple",
  message: "Envoyer un message RooSync via roosync_send avec action='send', to='all', subject='[META-CONSULT] {resume conclusion}', body='...', tags=['meta-analysis']"
})
```

**Garde-fou :** La consultation est en LECTURE seule. Roo ne modifie PAS les fichiers des autres machines.

---

## Chaine de Decision

| Type de conclusion | Action | Autorite |
|-------------------|--------|----------|
| Informatif (stats, taux) | Ajouter a doc analyse + dashboard workspace | Autonome |
| Suggestion operationnelle | Ecrire dans dashboard workspace, coordinateur prend en charge | Autonome |
| Probleme d'environnement (MCP HS, .env incomplet, service inaccessible) | dashboard workspace + flag coordinateur | Autonome (coordinateur agit) |
| Nouvelle issue (bug, friction) | Creer avec label `needs-approval` | Semi-autonome |
| Changement de harnais | Creer avec `needs-approval` + `harness-change` | **BLOQUE jusqu'a approbation utilisateur** |

---

## Sante Outillage (#761)

Detecter les outils sous-utilises, degrades ou casses AVANT qu'ils ne soient abandonnes silencieusement.

### Checks obligatoires (chaque cycle meta-analyse)

#### 1. Outils jamais appeles (>14 jours)

Croiser les 34 outils declares dans `ListTools` avec les traces recentes via delegation :

```
new_task({
  mode: "ask-simple",
  message: "Utiliser roosync_search(action: 'semantic', search_query: '{outil}', start_date: '{14j avant}') pour verifier l'activite des outils principaux."
})
```

Distinguer : intentionnel (usage rare par design) / suspect / casse.

#### 2. Outils avec bugs ouverts > 14 jours

```
# Via win-cli :
execute_command(command: "gh issue list --repo jsboige/roo-extensions --label bug --state open --json number,title,createdAt")
```

Alerter si un bug d'outil est ouvert > 14 jours.

#### 3. Workarounds non resolus

Scanner MEMORY.md et PROJECT_MEMORY.md pour les entrees "workaround", "bug connu", "contournement". Si workaround > 14 jours sans issue corrective → creer issue `needs-approval`.

#### 4. Secrets exposes

Verifier : aucun `.env` commite, aucune cle API dans les issues/commentaires recents, alertes GitHub secret scanning resolues.

### Format de rapport

```markdown
## Sante Outillage (cycle {date})

| Metrique | Valeur |
|----------|--------|
| Outils actifs (14j) | X/34 |
| Bugs outils ouverts >14j | Y |
| Workarounds non fixes | Z |
| Secrets exposes | 0/N |

Score sante : A (>90% actifs) / B (>75%) / C (>50%) / D (<50%)
```

---

## Garde-Fous (CRITIQUE)

### Le meta-analyste Roo NE DOIT PAS :

- Modifier les fichiers dans `.roo/rules/`, `.claude/rules/`, `.claude/commands/`, `.claude/skills/`
- Modifier `CLAUDE.md`, `.roomodes`, `modes-config.json`, `scheduler-workflow-*.md`
- Fermer, archiver, ou dispatcher des issues GitHub (c'est le role du Coordinateur)
- Faire des git push --force, rebase, ou operations git destructives
- Creer des issues SANS le label `needs-approval`

### Le meta-analyste Roo PEUT :

- Lire toutes les traces locales (taches Roo, sessions Claude)
- Lire tous les fichiers des deux harnais
- Creer des issues avec `needs-approval` (propositions, pas decisions)
- Ecrire dans dashboard workspace
- Ecrire des docs d'analyse sur GDrive
- Commenter des issues existantes avec des conclusions d'analyse

---

## Stockage GDrive

```
.shared-state/meta-analysis/
  +-- {machine}/
  |   +-- roo-analysis-{date}.md
  |   +-- claude-analysis-{date}.md
  +-- reconciliation/
      +-- {machine}-{date}.md
```

**Chemin GDrive (po-2025 / autres machines) :**
```
G:\Mon Drive\Synchronisation\RooSync\.shared-state\meta-analysis\
```

**Chemin GDrive (web1) :**
```
C:\Drive\.shortcut-targets-by-id\{ID}\.shared-state\meta-analysis\
```

---

## Contraintes Contexte Roo (IMPORTANT)

- **Seuil condensation GLM :** 80% (voir `.roo/rules/12-machine-constraints.md` section "Contraintes communes")
- **Pas de coverage dans les tests :** Explose le contexte
- **Limiter output git log/diff :** Toujours `| head -30`
- **Si contexte sature** → Arreter l'analyse, ecrire les conclusions partielles dans dashboard workspace

---

## Workflow du Scheduler Meta-Analyste

**Fichier de reference complet :** `.roo/scheduler-workflow-meta-analyst.md`

Resume du workflow :

1. **Delegation lecture workflow** → `ask-complex` lit le fichier workflow
2. **Analyse traces Roo** → `code-complex` lit et resume les traces
3. **Analyse harnais Claude** → `ask-complex` lit `.claude/rules/`, `CLAUDE.md`
4. **Ecriture dashboard workspace** → `code-simple` ecrit les conclusions
5. **Lecture dashboard workspace Claude** → `ask-simple` lit la derniere entree Claude
6. **Reconciliation** → `code-simple` ajoute notes de reconciliation
7. **Issues actionnables** → `code-simple` cree les issues avec `needs-approval`

---

## References

- Issue #551 : Architecture Meta-Analyste (origine)
- Issue #705 : Cette adaptation pour Roo
- `.claude/rules/meta-analysis.md` : Version Claude (reference)
- `.roo/scheduler-workflow-meta-analyst.md` : Instructions completes du workflow
- `.roo/rules/12-machine-constraints.md` : Seuils de condensation GLM (section "Contraintes communes")

---

**Derniere mise a jour :** 2026-03-15

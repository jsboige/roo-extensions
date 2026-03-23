# Protocole Meta-Analyse - Architecture 3x2 Scheduler (Claude Code)

**Version:** 1.0.0
**Cree:** 2026-03-23
**Issue:** #805 (adaptation depuis `.roo/rules/18-meta-analysis.md`)

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

## Role du Meta-Analyste Claude

**Mission :** Analyser independamment LES DEUX schedulers (Roo + Claude) sur la machine locale, puis reconcilier les conclusions via META-INTERCOM.

### Ce que Claude analyse

**1. Sessions Claude récentes (auto-analyse)**

Sessions dans `C:\Users\{USER}\.claude\projects\*\*.jsonl` :

- Taux de succes/echec par type de tache
- Patterns d'outils utilises (Read, Grep, Bash, Agent, etc.)
- Erreurs recurrentes (tool not found, permission denied, etc.)
- Efficacite de la delegation (subagents)

**Outils Claude pour cette analyse :**

```
# Lire les sessions JSONL recentes
Get-ChildItem C:\Users\{USER}\.claude\projects\*.jsonl | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Extraire les patterns d'erreur via Grep
Grep(pattern: "Error|Failed|denied", path: ".claude/projects/")
```

**2. Traces Roo (analyse croisee)**

- Taches Roo : `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\`
- Commits Roo recents : `git log --oneline --author="Roo" -10`
- Logs Roo Scheduler : extension output

**3. Harnais Roo (analyse croisee)**

Claude est PLUS LIBRE de critiquer le harnais Roo que le sien propre :

- `.roo/rules/` (toutes les regles Roo)
- `.roomodes` (configuration modes Roo)
- `modes-config.json` (source des modes)
- `.roo/scheduler-workflow-*.md` (workflows)

**4. Metriques operationnelles**

- Issues GitHub creees vs fermees (7 derniers jours)
- Taux d'utilisation machine (commits, messages RooSync)
- Violations de garde-fous detectees dans les traces

**5. Recherche semantique de frictions (#637)**

Utiliser `mcp__roo-state-manager__roosync_search` avec filtres avances pour detecter les frictions recentes :

```
# Via MCP roo-state-manager :
roosync_search(action: "semantic", search_query: "impossible bloque erreur fail", has_errors: true, start_date: "{72h ago}", max_results: 10)
# Filtres utiles : tool_name (outil fautif), model (modele specifique), source ("roo" ou "claude-code")
```

- Patterns recurrents (≥ 2 occurrences) → candidats issues friction
- Correlations outil + erreur → root cause probable

### Ce que Claude produit

- **Entrees META-INTERCOM** (reconciliation)
- **Issues GitHub avec `needs-approval`** (propositions d'amelioration)
- **Issues GitHub avec `needs-approval` + `harness-change`** (modifications de harnais, BLOQUEES jusqu'a approbation utilisateur)

---

## Protocole META-INTERCOM

**Fichier :** `.claude/local/META-INTERCOM-{MACHINE}.md`

Canal dedie a la reconciliation meta-analyse. SEPARE de l'INTERCOM operationnel.

### Workflow

1. Claude ecrit son analyse (auto + croisee) dans META-INTERCOM
2. Roo lit l'analyse de Claude, ecrit la sienne + notes de reconciliation
3. Les deux agents peuvent commenter les conclusions de l'autre
4. Les conclusions actionnables deviennent des issues GitHub avec `needs-approval`

### Format d'entree META-INTERCOM

```markdown
## [YYYY-MM-DD HH:MM:SS] claude-code -> roo [META-ANALYSIS]

### Analyse Auto (Claude)
- Taux succes taches : X%
- Outils les plus utilises : [liste]
- Erreurs recurrentes : [liste]
- Subagents efficacite : Y%

### Analyse Croisee (Roo harness)
- Findings sur .roo/rules/ : [liste]
- Findings sur .roomodes : [liste]
- Recommandations : [liste]

### Conclusions Actionnables
- [Chaque item = potentiellement une issue needs-approval]

---
```

### Consultation Cross-Machine (apres reconciliation locale)

Quand Claude et Roo ont **reconcilie** leurs conclusions via META-INTERCOM et qu'une conclusion est non-triviale, Claude MAY consulter d'autres machines.

**Procedure :**

```
roosync_send(action: "send", to: "all", subject: "[META-CONSULT] {resume conclusion}", body: "...", tags: ["meta-analysis"])
```

**Garde-fou :** La consultation est en LECTURE seule. Claude ne modifie PAS les fichiers des autres machines.

---

## Chaine de Decision

| Type de conclusion | Action | Autorite |
|-------------------|--------|----------|
| Informatif (stats, taux) | Ajouter a META-INTERCOM | Autonome |
| Suggestion operationnelle | Ecrire dans META-INTERCOM, coordinateur prend en charge | Autonome |
| Probleme d'environnement (MCP HS, .env incomplet, service inaccessible) | META-INTERCOM + flag coordinateur | Autonome (coordinateur agit) |
| Nouvelle issue (bug, friction) | Creer avec label `needs-approval` | Semi-autonome |
| Changement de harnais | Creer avec `needs-approval` + `harness-change` | **BLOQUE jusqu'a approbation utilisateur** |

---

## Sante Outillage (#761)

Detecter les outils sous-utilises, degrades ou casses AVANT qu'ils ne soient abandonnes silencieusement.

### Checks obligatoires (chaque cycle meta-analyse)

#### 1. Outils jamais appeles (>14 jours)

Croiser les outils MCP declares avec les traces recentes :

```
# Via roosync_search
roosync_search(action: "text", search_query: "{outil}", start_date: "{14j avant}")
```

Distinguer : intentionnel (usage rare par design) / suspect / casse.

#### 2. Outils avec bugs ouverts > 14 jours

```
gh issue list --repo jsboige/roo-extensions --label bug --state open --json number,title,createdAt
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

### Le meta-analyste Claude NE DOIT PAS :

- Modifier les fichiers dans `.roo/rules/`, `.claude/rules/`, `.claude/commands/`, `.claude/skills/` sans `needs-approval`
- Modifier `CLAUDE.md`, `.roomodes`, `modes-config.json`, `scheduler-workflow-*.md` sans `needs-approval`
- Fermer, archiver, ou dispatcher des issues GitHub (c'est le role du Coordinateur)
- Faire des git push --force, rebase, ou operations git destructives
- Creer des issues SANS le label `needs-approval` pour les changements de harnais

### Le meta-analyste Claude PEUT :

- Lire toutes les traces locales (sessions Claude, taches Roo)
- Lire tous les fichiers des deux harnais
- Creer des issues avec `needs-approval` (propositions, pas decisions)
- Ecrire dans META-INTERCOM
- Commenter des issues existantes avec des conclusions d'analyse

---

## Contraintes Contexte Claude (IMPORTANT)

- **Pas de seuil condensation GLM** : Claude utilise un modele different (Opus/Sonnet) avec des limites differentes
- **Couverture tests** : Explose le contexte, limiter aux tests specifiques
- **Limiter output git log/diff** : Toujours `| head -30`
- **Si contexte sature** → Arreter l'analyse, ecrire les conclusions partielles dans META-INTERCOM

---

## Workflow du Scheduler Meta-Analyste

**Fichier de reference complet :** `.roo/scheduler-workflow-meta-analyst.md`

Resume du workflow (adapte pour Claude) :

1. **Lecture workflow** → Lire le fichier workflow complet
2. **Analyse sessions Claude** → Lire et resumer les sessions recentes
3. **Analyse harnais Roo** → Lire `.roo/rules/`, `.roomodes`
4. **Ecriture META-INTERCOM** → Ecrire les conclusions
5. **Lecture META-INTERCOM Roo** → Lire la derniere entree Roo
6. **Reconciliation** → Ajouter notes de reconciliation
7. **Issues actionnables** → Creer les issues avec `needs-approval`

---

## References

- Issue #551 : Architecture Meta-Analyste (origine)
- Issue #805 : Cette adaptation pour Claude Code
- `.roo/rules/18-meta-analysis.md` : Version Roo complete
- `.roo/scheduler-workflow-meta-analyst.md` : Instructions completes du workflow
- `.claude/docs/reference/meta-analysis.md` : Documentation de reference

---

**Derniere mise a jour :** 2026-03-23

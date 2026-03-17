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

**Mission :** Analyser independamment LES DEUX schedulers (Roo + Claude) sur la machine locale, puis reconcilier les conclusions via META-INTERCOM.

### Ce que Roo analyse

**1. Ses propres traces (auto-analyse)**

Traces dans `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\` :

- Taux de succes/echec par mode (`*-simple` vs `*-complex`)
- Patterns d'escalade (combien de fois -simple → -complex)
- Usages d'outils (win-cli OK ? roosync_* appeles correctement ?)
- Efficacite de la delegation (new_task bien formate ?)

**Outils Roo pour cette analyse :**

```
# Deleguer la lecture des traces a ask-complex ou code-complex
new_task({
  mode: "ask-complex",
  message: "Lire les 5 dernieres taches Roo dans %APPDATA%\\Code\\User\\globalStorage\\rooveterinaryinc.roo-cline\\tasks\\ et fournir un rapport : mode utilise, succes/echec, erreurs."
})
```

**2. Traces Claude (analyse croisee)**

- Sessions Claude : `C:\Users\{USER}\.claude\projects\*\*.jsonl`
- Logs worker Claude : `.claude/logs/worker-*.log`
- Commits recents Claude : `git log --oneline --author="Claude" -10`

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
- **Entrees META-INTERCOM** (reconciliation)
- **Issues GitHub avec `needs-approval`** (propositions d'amelioration)
- **Issues GitHub avec `needs-approval` + `harness-change`** (modifications de harnais, BLOQUEES jusqu'a approbation utilisateur)

---

## Protocole META-INTERCOM

**Fichier :** `.claude/local/META-INTERCOM-{MACHINE}.md`

Canal dedie a la reconciliation meta-analyse. SEPARE de l'INTERCOM operationnel.

### Workflow

1. Roo ecrit son analyse (auto + croisee) dans META-INTERCOM
2. Claude lit l'analyse de Roo, ecrit la sienne + notes de reconciliation
3. Les deux agents peuvent commenter les conclusions de l'autre
4. Les conclusions actionnables deviennent des issues GitHub avec `needs-approval`

### Format d'entree META-INTERCOM

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

Quand Roo et Claude ont **reconcilie** leurs conclusions via META-INTERCOM et qu'une conclusion est non-triviale, Roo MAY consulter d'autres machines.

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
| Informatif (stats, taux) | Ajouter a doc analyse + META-INTERCOM | Autonome |
| Suggestion operationnelle | Ecrire dans META-INTERCOM, coordinateur prend en charge | Autonome |
| Probleme d'environnement (MCP HS, .env incomplet, service inaccessible) | META-INTERCOM + flag coordinateur | Autonome (coordinateur agit) |
| Nouvelle issue (bug, friction) | Creer avec label `needs-approval` | Semi-autonome |
| Changement de harnais | Creer avec `needs-approval` + `harness-change` | **BLOQUE jusqu'a approbation utilisateur** |

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
- Ecrire dans META-INTERCOM
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

- **Seuil condensation GLM :** 70% (voir `.roo/rules/06-context-window.md`)
- **Pas de coverage dans les tests :** Explose le contexte
- **Limiter output git log/diff :** Toujours `| head -30`
- **Si contexte sature** → Arreter l'analyse, ecrire les conclusions partielles dans META-INTERCOM

---

## Workflow du Scheduler Meta-Analyste

**Fichier de reference complet :** `.roo/scheduler-workflow-meta-analyst.md`

Resume du workflow :

1. **Delegation lecture workflow** → `ask-complex` lit le fichier workflow
2. **Analyse traces Roo** → `code-complex` lit et resume les traces
3. **Analyse harnais Claude** → `ask-complex` lit `.claude/rules/`, `CLAUDE.md`
4. **Ecriture META-INTERCOM** → `code-simple` ecrit les conclusions
5. **Lecture META-INTERCOM Claude** → `ask-simple` lit la derniere entree Claude
6. **Reconciliation** → `code-simple` ajoute notes de reconciliation
7. **Issues actionnables** → `code-simple` cree les issues avec `needs-approval`

---

## References

- Issue #551 : Architecture Meta-Analyste (origine)
- Issue #705 : Cette adaptation pour Roo
- `.claude/rules/meta-analysis.md` : Version Claude (reference)
- `.roo/scheduler-workflow-meta-analyst.md` : Instructions completes du workflow
- `.roo/rules/06-context-window.md` : Seuils de condensation GLM

---

**Derniere mise a jour :** 2026-03-15

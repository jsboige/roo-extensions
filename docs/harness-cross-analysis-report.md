# Rapport d'Analyse Croisée des Harnais - Roo vs Claude

**Date:** 2026-03-13
**Version:** 1.0.0
**Auteur:** Roo Code (code-complex)

---

## Résumé Exécutif

Ce rapport présente une analyse comparative des harnais de règles pour Roo Code (`.roo/rules/`) et Claude Code (`.claude/rules/`). L'objectif est d'identifier les incohérences, lacunes et opportunités d'amélioration pour assurer une cohérence entre les deux agents.

### Métriques Clés

| Métrique | Roo | Claude |
|----------|-----|--------|
| Nombre de fichiers | 14 | 21 |
| Fichiers communs (même sujet) | 8 | 8 |
| Fichiers uniques | 6 | 13 |

---

## Tableau Comparatif par Sujet

### 1. SDDD / Grounding Conversationnel

| Aspect | Roo (`04-sddd-grounding.md`) | Claude (`sddd-conversational-grounding.md`) |
|--------|------------------------------|---------------------------------------------|
| Version | 2.1.0 | 2.1.0 |
| Pattern Bookend | ❌ Absent | ✅ Obligatoire (début + fin de tâche) |
| Protocole multi-pass | ✅ 4 passes | ✅ 4 passes |
| Outils couverts | conversation_browser, codebase_search, roosync_search | Idem + Read, Grep, Glob, Bash, Git |
| Niveau de détail | Moyen | Élevé (382 lignes vs 149) |

**Incohérence détectée :** Le Pattern Bookend (recherche sémantique en début ET fin de tâche) est obligatoire chez Claude mais absent du harnais Roo.

**Recommandation :** `needs-approval` - Ajouter le Pattern Bookend au harnais Roo.

---

### 2. Disponibilité des Outils (STOP & REPAIR)

| Aspect | Roo (`05-tool-availability.md`) | Claude (`tool-availability.md`) |
|--------|--------------------------------|---------------------------------|
| Version | - | 1.3.0 |
| Protocole STOP & REPAIR | ✅ Présent | ✅ Présent |
| win-cli critique | ✅ OBLIGATOIRE pour modes -simple | ✅ Noté comme Roo-only depuis #658 |
| Outils retirés | desktop-commander, quickfiles, github-projects-mcp | Idem |
| Configuration séparée | ❌ Non mentionné | ✅ Claude/Roo configs séparées |
| Pré-flight check scheduler | ✅ Détaillé | ✅ Détaillé |

**Cohérence :** Les deux harnais sont alignés sur le protocole STOP & REPAIR.

**Lacune Roo :** Ne mentionne pas que les configs MCP sont séparées entre Claude et Roo.

**Recommandation :** `INFO` - Ajouter une note sur la séparation des configs MCP.

---

### 3. Validation Technique

| Aspect | Roo (`validation.md`) | Claude (`validation-checklist.md`) |
|--------|----------------------|-----------------------------------|
| Checklist AVANT/PENDANT/APRÈS | ✅ Complète | ✅ Complète |
| TDD mentionné | ❌ Non | ✅ Recommandé |
| Exemples de code | ✅ TypeScript détaillé | ❌ Texte seulement |
| Responsabilités coordinateur | ❌ Non | ✅ Section dédiée |
| Communication avec Claude | ✅ Template INTERCOM | ❌ Non |

**Différences :**
- Claude recommande TDD, Roo ne le mentionne pas
- Roo a des exemples de code plus détaillés
- Claude définit les responsabilités du coordinateur
- Roo a un template INTERCOM pour demander vérification

**Recommandation :** `harness-change` - Enrichir les deux côtés : ajouter TDD chez Roo, ajouter template INTERCOM chez Claude.

---

### 4. Checklists GitHub

| Aspect | Roo (`09-github-checklists.md`) | Claude (`github-checklists.md`) |
|--------|--------------------------------|---------------------------------|
| Règle absolue | ✅ Ne jamais fermer avec tableau vide | ✅ Idem |
| Commit immédiat | ❌ Non mentionné | ✅ OBLIGATOIRE après chaque case |
| Formats de tableau | ✅ Un format | ✅ Deux formats (checkboxes + état) |
| Intégration agents | ❌ Non | ✅ Liste des agents/skills |
| Communication inter-agent | ✅ Template INTERCOM | ❌ Non |

**Incohérence détectée :** Claude exige un commit immédiat après chaque case cochée, Roo ne le mentionne pas.

**Recommandation :** `needs-approval` - Ajouter l'obligation de commit immédiat chez Roo.

---

### 5. GitHub CLI

| Aspect | Roo (`github-cli.md`) | Claude (`github-cli.md`) |
|--------|----------------------|--------------------------|
| Migration MCP → gh | ✅ Documentée | ✅ Documentée |
| Scope project requis | ❌ Non mentionné | ✅ `gh auth refresh -s project` |
| Type union GraphQL | ❌ Non | ✅ Fragment inline documenté |
| IDs des projets | ✅ #67 actif, #70 supprimé | ✅ Idem |
| Field IDs | ✅ Status, Machine, Agent | ✅ + Model, Execution, Deadline |
| Pagination >100 items | ❌ Non | ✅ Documentée |

**Lacunes Roo :**
1. Ne mentionne pas le scope `project` requis
2. N'a pas l'avertissement sur le type union GraphQL
3. N'a pas la section pagination
4. Field IDs incomplets (manque Model, Execution, Deadline)

**Recommandation :** `harness-change` - Synchroniser `github-cli.md` de Roo avec celui de Claude.

---

### 6. Règles de Test

| Aspect | Roo (`testing.md`) | Claude (`testing.md`) |
|--------|-------------------|----------------------|
| Commande principale | ✅ `npx vitest run` | ✅ `npx vitest run` |
| Pourquoi pas npm test | ✅ Expliqué | ✅ Expliqué |
| Machines contraintes | ❌ Non | ✅ `--maxWorkers=1` |
| Localisation tests | ✅ Identique | ✅ Identique |

**Lacune Roo :** Ne documente pas l'option `--maxWorkers=1` pour les machines à ressources limitées (ex: myia-web1).

**Recommandation :** `harness-change` - Ajouter la section machines contraintes au harnais Roo.

---

### 7. Garde-Fous CI

| Aspect | Roo (`10-ci-guardrails.md`) | Claude (`ci-guardrails.md`) |
|--------|----------------------------|-----------------------------|
| Version | - | 1.0.0 |
| Validation avant push | ✅ `npm run build && vitest run --config ci` | ✅ Script `validate-before-push.ps1` |
| Deux configs Vitest | ✅ Mentionné | ✅ Tableau détaillé |
| Script de validation | ❌ Non | ✅ `scripts/mcp/validate-before-push.ps1` |
| Historique incidents | ❌ Non | ✅ 3 incidents documentés |
| Instructions par agent | ❌ Non | ✅ Claude vs Roo |

**Lacunes Roo :**
1. Pas de script de validation dédié
2. Pas d'historique des incidents
3. Pas d'instructions spécifiques par type d'agent

**Recommandation :** `harness-change` - Enrichir le harnais Roo avec le script et l'historique.

---

### 8. Protocole de Scepticisme

| Aspect | Roo (`skepticism-protocol.md`) | Claude (`skepticism-protocol.md`) |
|--------|-------------------------------|-----------------------------------|
| Version | 1.0.0 | 1.0.0 |
| Smell test | ✅ Présent | ✅ Présent |
| Niveaux de vérification | ❌ Non | ✅ 3 niveaux (10s, 1-2min, 5min) |
| Règles anti-propagation | ❌ Basique | ✅ Par rôle (coordinateur, exécuteur) |
| Faits de référence | ✅ Basique | ✅ Tableau complet |
| Anti-patterns documentés | ❌ Non | ✅ 5 incidents avec impact |
| Référence croisée | ✅ → Claude | ❌ Pas de référence retour |

**Lacunes Roo Majeures :**
1. Pas de protocole à 3 niveaux de vérification
2. Pas de règles par rôle
3. Pas d'anti-patterns documentés

**Recommandation :** `harness-change` - Synchroniser le scepticisme Roo avec Claude (version complète).

---

## Lacunes par Harnais

### Sujets présents chez Claude mais PAS chez Roo

| Fichier Claude | Sujet | Priorité | Recommandation |
|----------------|-------|----------|----------------|
| `condensation-thresholds.md` | Seuils de condensation détaillés | BASSE | Pas nécessaire (Roo a `06-context-window.md`) |
| `delegation.md` | Règles de délégation Claude | INFO | Pas applicable à Roo |
| `scheduler-system.md` | Système scheduler complet | HAUTE | Extraire parties pertinentes pour Roo |
| `meta-analysis.md` | Workflow meta-analyste | INFO | Pas applicable à Roo |
| `myia-web1-constraints.md` | Contraintes machine spécifique | MOYENNE | Ajouter référence chez Roo |
| `pr-review-policy.md` | Politique de review des PRs | BASSE | Pas prioritaire pour Roo |
| `feedback-process.md` | Processus de feedback | INFO | Pas applicable |
| `mcp-discoverability.md` | Découvrabilité des MCPs | INFO | Pas applicable |
| `agents-architecture.md` | Architecture des agents | INFO | Pas applicable |
| `bash-fallback.md` | Fallback bash | INFO | Pas applicable (Windows) |

### Sujets présents chez Roo mais PAS chez Claude

| Fichier Roo | Sujet | Nécessaire chez Claude ? |
|-------------|-------|--------------------------|
| `06-context-window.md` | Configuration context window | ❌ Non (spécifique Roo/Qwen) |
| `07-orchestrator-delegation.md` | Délégation orchestrator | ❌ Non (spécifique Roo) |
| `08-file-writing.md` | Limitation Qwen 3.5 | ❌ Non (spécifique Roo) |
| `02-intercom.md` | Communication locale | ⚠️ Partiellement (Claude a INTERCOM mais pas de fichier dédié) |

---

## Résumé des Recommandations

### Priorité HAUTE (needs-approval)

| # | Recommandation | Fichier à modifier | Impact |
|---|----------------|-------------------|--------|
| 1 | Ajouter Pattern Bookend SDDD | `.roo/rules/04-sddd-grounding.md` | Cohérence workflow |
| 2 | Ajouter commit immédiat dans checklists GitHub | `.roo/rules/09-github-checklists.md` | Traçabilité |
| 3 | Synchroniser protocole scepticisme complet | `.roo/rules/skepticism-protocol.md` | Qualité rapports |

### Priorité MOYENNE (harness-change)

| # | Recommandation | Fichier à modifier | Impact |
|---|----------------|-------------------|--------|
| 4 | Compléter github-cli.md (scope, GraphQL, pagination) | `.roo/rules/github-cli.md` | Fonctionnalité |
| 5 | Ajouter section machines contraintes | `.roo/rules/testing.md` | Stabilité tests |
| 6 | Enrichir ci-guardrails.md (script, historique) | `.roo/rules/10-ci-guardrails.md` | Prévention régressions |
| 7 | Ajouter TDD dans validation | `.roo/rules/validation.md` | Qualité code |

### Priorité BASSE (INFO)

| # | Recommandation | Fichier à modifier | Impact |
|---|----------------|-------------------|--------|
| 8 | Noter séparation configs MCP | `.roo/rules/05-tool-availability.md` | Clarté |
| 9 | Ajouter template INTERCOM validation | `.claude/rules/validation-checklist.md` | Communication |
| 10 | Référence contraintes web1 | `.roo/rules/01-general.md` | Contexte |

---

## Annexes

### A. Inventaire Complet des Fichiers

#### Harnais Roo (14 fichiers)
```
.roo/rules/
├── 01-general.md           # Vue d'ensemble
├── 02-intercom.md          # Communication locale
├── 03-mcp-usage.md         # Usage MCPs
├── 04-sddd-grounding.md    # SDDD
├── 05-tool-availability.md # STOP & REPAIR
├── 06-context-window.md    # Context window (Roo-only)
├── 07-orchestrator-delegation.md # Délégation (Roo-only)
├── 08-file-writing.md      # Limitation Qwen (Roo-only)
├── 09-github-checklists.md # Checklists GitHub
├── 10-ci-guardrails.md     # CI
├── github-cli.md           # GitHub CLI
├── skepticism-protocol.md  # Scepticisme
├── testing.md              # Tests
└── validation.md           # Validation
```

#### Harnais Claude (21 fichiers)
```
.claude/rules/
├── agents-architecture.md       # Architecture agents
├── bash-fallback.md             # Fallback bash
├── ci-guardrails.md             # CI
├── condensation-thresholds.md   # Condensation
├── delegation.md                # Délégation
├── feedback-process.md          # Feedback
├── github-checklists.md         # Checklists GitHub
├── github-cli.md                # GitHub CLI
├── mcp-discoverability.md       # MCP discoverability
├── meta-analysis.md             # Meta-analyste
├── myia-web1-constraints.md     # Contraintes web1
├── pr-review-policy.md          # Review PRs
├── roo-schedulable-criteria.md  # Critères scheduler
├── scheduled-coordinator.md     # Coordinateur scheduler
├── scheduler-densification.md   # Densification scheduler
├── scheduler-system.md          # Système scheduler
├── sddd-conversational-grounding.md # SDDD
├── skepticism-protocol.md       # Scepticisme
├── testing.md                   # Tests
├── tool-availability.md         # STOP & REPAIR
└── validation-checklist.md      # Validation
```

### B. Matrice de Couverture

| Sujet | Roo | Claude | Alignement |
|-------|-----|--------|------------|
| Vue d'ensemble | `01-general.md` | `CLAUDE.md` | ⚠️ Partiel |
| INTERCOM | `02-intercom.md` | (dans CLAUDE.md) | ⚠️ Partiel |
| MCPs | `03-mcp-usage.md` | `tool-availability.md` | ✅ Aligné |
| SDDD | `04-sddd-grounding.md` | `sddd-conversational-grounding.md` | ⚠️ Différences |
| Tool availability | `05-tool-availability.md` | `tool-availability.md` | ✅ Aligné |
| Context window | `06-context-window.md` | `condensation-thresholds.md` | ⚠️ Différent |
| Orchestration | `07-orchestrator-delegation.md` | `delegation.md` | ❌ Différent |
| File writing | `08-file-writing.md` | - | N/A (Roo-only) |
| GitHub checklists | `09-github-checklists.md` | `github-checklists.md` | ⚠️ Différences |
| CI | `10-ci-guardrails.md` | `ci-guardrails.md` | ⚠️ Différences |
| GitHub CLI | `github-cli.md` | `github-cli.md` | ❌ Lacunes Roo |
| Scepticisme | `skepticism-protocol.md` | `skepticism-protocol.md` | ❌ Lacunes Roo |
| Testing | `testing.md` | `testing.md` | ⚠️ Différences |
| Validation | `validation.md` | `validation-checklist.md` | ⚠️ Différences |

---

**Fin du rapport**

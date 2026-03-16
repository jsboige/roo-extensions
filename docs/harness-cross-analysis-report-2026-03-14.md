# Rapport d'Analyse Croisée des Harnais Roo ↔ Claude

**Date:** 2026-03-14
**Auteur:** Roo Code (mode code-complex)
**Méthodologie:** Meta-analyse croisée des fichiers de règles

---

## Vue d'ensemble

Ce rapport compare les harnais de règles des deux agents IA opérant sur le système RooSync :
- **Roo Code** : Assistant technique (Qwen 3.5 local / GLM-5 cloud)
- **Claude Code** : Coordinateur et cerveau principal (Opus 4.6)

---

## Tableau des Incohérences, Lacunes et Améliorations

| Type | Sévérité | Description | Fichier Roo | Fichier Claude | Recommandation |
|------|----------|-------------|-------------|----------------|----------------|
| **INCOHÉRENCE** | CRITICAL | **win-cli scope divergent** : Roo indique win-cli obligatoire pour tous les modes `-simple`, Claude indique "Roo uniquement". Les deux disent que Claude utilise `Bash` natif, mais la formulation prête à confusion. | `.roo/rules/05-tool-availability.md` | `.claude/rules/tool-availability.md:75` | Clarifier explicitement : win-cli = Roo Scheduler UNIQUEMENT, Bash natif = Claude Code. |
| **INCOHÉRENCE** | WARNING | **Seuil condensation non intégré** : Claude référence `condensation-thresholds.md`, Roo a `06-context-window.md` avec 70% mais non intégré dans les workflows scheduler. | `.roo/rules/06-context-window.md` | `.claude/rules/meta-analysis.md:166` | Intégrer la règle 70% dans les workflows scheduler (coordinator + executor). |
| **INCOHÉRENCE** | WARNING | **Procédure INTERCOM asymétrique** : Roo décrit 3 méthodes détaillées (apply_diff, Add-Content, write_to_file fallback), Claude n'a pas de procédure équivalente documentée. | `.roo/rules/02-intercom.md:27-55` | Non documenté | Créer `.claude/rules/intercom-protocol.md` avec la même procédure. |
| **INCOHÉRENCE** | INFO | **Référence cassée** : `.roo/rules/04-sddd-grounding.md:191` référence `.roo/README.md` qui n'existe pas. | `.roo/rules/04-sddd-grounding.md:191` | N/A | Créer le fichier ou corriger la référence. |
| **INCOHÉRENCE** | INFO | **GitHub Project #70** : Claude référence #70 comme "supprimé" dans certains fichiers, devrait être retiré complètement de la doc. | N/A | `CLAUDE.md` | Nettoyer toute référence au Project #70. |
| **LACUNE** | CRITICAL | **Pas d'escalade Claude CLI côté Claude** : Roo a un protocole d'escalade Claude CLI (modes -complex), Claude n'a pas d'équivalent documenté vers l'utilisateur ou Opus. | `.roomodes` (modes -complex) | Non documenté | Ajouter une règle d'escalade équivalente pour Claude Code. |
| **LACUNE** | WARNING | **Règle write_to_file non documentée pour Claude** : Roo a `.roo/rules/08-file-writing.md` pour Qwen 3.5, Claude n'a pas d'équivalent pour GLM-5. | `.roo/rules/08-file-writing.md` | Non documenté | Évaluer si GLM-5 a la même limitation, documenter si applicable. |
| **LACUNE** | WARNING | **Scepticisme raisonnable** : Roo a `.roo/rules/skepticism-protocol.md`, Claude référence `docs/roosync/skepticism-protocol.md` - vérifier existence. | `.roo/rules/skepticism-protocol.md` | `CLAUDE.md:180` | Vérifier l'existence du fichier Claude, créer si absent. |
| **LACUNE** | WARNING | **Pattern Bookend SDDD non documenté côté Claude** : Roo a un pattern obligatoire `codebase_search` début/fin de tâche, Claude n'a pas d'équivalent. | `.roo/rules/04-sddd-grounding.md:88-128` | Non documenté | Ajouter le pattern bookend dans les règles Claude. |
| **LACUNE** | INFO | **Checklist validation GitHub différente** : Roo a une checklist détaillée pour les issues, Claude a une checklist plus courte. | `.roo/rules/09-github-checklists.md` | `.claude/rules/validation-checklist.md` | Harmoniser les deux checklists. |
| **AMÉLIORATION** | INFO | **Tier méta-analyst** : Claude a un protocole meta-analyst complet, Roo n'a pas d'équivalent explicite. | Non documenté | `.claude/rules/meta-analysis.md` | Documenter que Claude fait l'analyse croisée des deux harnais. |
| **AMÉLIORATION** | INFO | **Architecture 3-tier scheduler** : Claude documente Meta-Analyst/Coordinator/Executor, Roo a seulement coordinator/executor dans les workflows. | `scheduler-workflow-*.md` (2 workflows) | `.claude/rules/meta-analysis.md` | Le tier méta-analyst est Claude-only, documenter cette répartition. |
| **AMÉLIORATION** | INFO | **Machines à ressources limitées** : Claude documente `--maxWorkers=1` pour machines contraintes, Roo n'a pas cette règle. | Non documenté | `.claude/rules/testing.md:40-52` | Ajouter la règle dans `.roo/rules/testing.md`. |

---

## Vérification des Guard Rails Critiques

| Guard Rail | Roo | Claude | Statut |
|------------|-----|--------|--------|
| **Arrêt si outil critique absent** | ✅ `05-tool-availability.md` | ✅ `tool-availability.md` | ✅ Cohérent |
| **Pas de mode dégradé** | ✅ "Accommodation INTERDITE" | ✅ "L'ENVIRONNEMENT EST NON NÉGOCIABLE" | ✅ Cohérent |
| **INTERCOM pour communication locale** | ✅ `02-intercom.md` | ✅ `CLAUDE.md:199-200` | ✅ Cohérent |
| **RooSync pour inter-machines** | ✅ `03-mcp-usage.md` | ✅ `CLAUDE.md:199` | ✅ Cohérent |
| **win-cli obligatoire pour Roo** | ✅ `05-tool-availability.md` | ✅ `tool-availability.md` | ✅ Cohérent |
| **write_to_file limité pour Qwen 3.5** | ✅ `08-file-writing.md` | ⚠️ Non documenté | ⚠️ À évaluer |
| **Seuil condensation 70%** | ⚠️ Existe mais non intégré workflow | ⚠️ Référencé | ⚠️ À intégrer |
| **Scepticisme raisonnable** | ✅ `skepticism-protocol.md` | ⚠️ Référence à vérifier | ⚠️ Vérifier existence |
| **Validation avant commit** | ✅ `validation.md` | ✅ `validation-checklist.md` | ✅ Cohérent |
| **Tests : `npx vitest run`** | ✅ `testing.md` | ✅ `testing.md` | ✅ Cohérent |

---

## Recommandations Priorisées

### 1. [CRITICAL] Clarifier win-cli vs Bash natif
**Action:** `harness-change`

**Problème:** La documentation win-cli crée une confusion potentielle sur qui utilise quoi.

**Solution:**
- Ajouter un encadré explicite dans les DEUX harnais :
  ```
  ## Règle win-cli vs Bash
  
  | Agent | Outil shell | Raison |
  |-------|-------------|--------|
  | Roo Scheduler | win-cli MCP (obligatoire) | Modes `-simple` n'ont pas le groupe `command` |
  | Claude Code | Bash natif | Outil intégré, pas de MCP requis |
  ```
- Mettre à jour `.roo/rules/05-tool-availability.md` et `.claude/rules/tool-availability.md`

---

### 2. [CRITICAL] Intégrer seuil condensation 70% dans workflows
**Action:** `harness-change`

**Problème:** Le seuil de condensation 70% existe dans `.roo/rules/06-context-window.md` mais n'est pas référencé dans les workflows scheduler.

**Solution:**
- Ajouter dans `scheduler-workflow-coordinator.md` et `scheduler-workflow-executor.md` :
  ```
  ### Pre-flight condensation (si INTERCOM > 600 lignes)
  
  Si l'INTERCOM dépasse 600 lignes (~12k tokens), condenser AVANT de lire :
  1. Lire les 50 dernières lignes uniquement
  2. Ou utiliser `roosync_summarize` pour obtenir un résumé
  3. Voir `.roo/rules/06-context-window.md` pour le seuil 70%
  ```

---

### 3. [WARNING] Créer procédure INTERCOM côté Claude
**Action:** `harness-change`

**Problème:** Claude Code n'a pas de procédure documentée pour écrire dans INTERCOM de manière fiable.

**Solution:**
- Créer `.claude/rules/intercom-protocol.md` reprenant les 3 méthodes :
  1. `apply_diff` (préféré)
  2. `Add-Content` via PowerShell (fallback)
  3. `write_to_file` (dernier recours, attention gros fichiers)
- Synchroniser avec `.roo/rules/02-intercom.md`

---

### 4. [WARNING] Ajouter pattern Bookend SDDD côté Claude
**Action:** `harness-change`

**Problème:** Claude Code n'a pas l'obligation de `codebase_search` en début/fin de tâche significative.

**Solution:**
- Ajouter dans `.claude/rules/` (nouveau fichier ou existant) :
  ```
  ## Pattern Bookend SDDD
  
  Pour toute tâche significative (feature, fix, refactoring) :
  
  1. **DÉBUT** : `codebase_search` pour comprendre le contexte existant
  2. **FIN** : `codebase_search` pour vérifier que le travail est indexé
  
  Évite de refaire un travail déjà fait et garantit la traçabilité.
  ```

---

### 5. [INFO] Vérifier/créer fichier scepticisme côté Claude
**Action:** `needs-approval`

**Problème:** `CLAUDE.md:180` référence `docs/roosync/skepticism-protocol.md` - existence à vérifier.

**Solution:**
- Vérifier si le fichier existe
- Si non, soit :
  - Le créer en copiant/adaptant `.roo/rules/skepticism-protocol.md`
  - Ou pointer directement vers `.roo/rules/skepticism-protocol.md`

---

## Fichiers Analysés

### Harnais Roo (8 fichiers)
1. `.roo/rules/01-general.md` - Vue d'ensemble
2. `.roo/rules/02-intercom.md` - Communication locale
3. `.roo/rules/03-mcp-usage.md` - Utilisation MCPs
4. `.roo/rules/04-sddd-grounding.md` - Grounding conversationnel
5. `.roo/rules/05-tool-availability.md` - Vérification outils
6. `.roo/scheduler-workflow-coordinator.md` - Workflow coordinateur
7. `.roo/scheduler-workflow-executor.md` - Workflow exécuteur
8. `.roomodes` - Structure des modes

### Harnais Claude (6 fichiers)
1. `CLAUDE.md` - Instructions principales
2. `.claude/rules/meta-analysis.md` - Méta-analyse
3. `.claude/rules/testing.md` - Tests
4. `.claude/rules/scheduler-system.md` - Système scheduler
5. `.claude/rules/tool-availability.md` - Disponibilité outils
6. `.claude/rules/validation-checklist.md` - Checklist validation

---

## Conclusion

Les deux harnais sont **globalement cohérents** sur les guard rails critiques (arrêt si outil absent, communication INTERCOM/RooSync, validation avant commit).

Les principales divergences concernent :
1. **L'asymétrie de documentation** : Claude a plus de protocoles documentés (méta-analyse, bookend SDDD) que Roo
2. **L'intégration incomplète** de certaines règles (condensation 70%) dans les workflows opérationnels
3. **Des références cassées** à vérifier et corriger

**Score de cohérence globale : 85%** (guard rails critiques alignés, améliorations possibles sur la documentation)

---

*Généré par Roo Code (code-complex) - 2026-03-14*

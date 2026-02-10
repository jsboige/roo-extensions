# Roo Extensions - Guide pour Agents Claude Code

**Repository:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Système:** RooSync v2.3 Multi-Agent Coordination (5 machines)
**Dernière mise à jour:** 2026-02-07

---

## 🎯 Vue d'ensemble

Système multi-agent coordonnant **Roo Code** (technique) et **Claude Code** (coordination & documentation) sur 5 machines :

**Machines :** `myia-ai-01`, `myia-po-2023`, `myia-po-2024`, `myia-po-2026`, `myia-web1`

**Architecture :** Coordination bicéphale
- **Roo Code** → Tâches techniques (scripts, tests, build)
- **Claude Code** → Documentation, coordination, reporting

---

## 📚 Démarrage Rapide

### Pour une NOUVELLE conversation sur cette machine :

```powershell
# 1. Mettre à jour le dépôt
git pull

# 2. Lire ce fichier (CLAUDE.md) complètement

# 3. Vérifier les MCP disponibles
# Les MCPs sont chargés au démarrage de VS Code
```

### Pour une AUTRE machine :

1. **Identifier la machine** : `$env:COMPUTERNAME` ou `hostname`
2. **Lire la documentation** : [`.claude/INDEX.md`](.claude/INDEX.md)
3. **Configurer les MCPs** : Suivre [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md)

---

## 🤖 Architecture Agents & Skills (NOUVEAU)

### Principe : Conversations Légères

Pour éviter les conversations qui grossissent indéfiniment, utilise des **subagents** pour déléguer les tâches verboses. La conversation principale reste légère et orchestre.

```
┌─────────────────────────────────────────────────────────────┐
│              CONVERSATION PRINCIPALE (légère)                │
│  - Orchestration et décisions                                │
│  - Délègue aux subagents pour les tâches spécialisées       │
└─────────────────┬───────────────────────────────────────────┘
                  │
     ┌────────────┼────────────┬────────────┐
     ▼            ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ RooSync  │ │  GitHub  │ │ INTERCOM │ │   Code   │
│Coordinator│ │ Tracker │ │ Handler  │ │ Explorer │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
```

### Subagents Disponibles ([.claude/agents/](.claude/agents/))

#### Agents Communs (toutes machines)

| Agent | Description | Modèle | Outils |
|-------|-------------|--------|--------|
| `git-sync` | Pull/merge conservatif, submodules | opus | Bash, Read, Grep |
| `test-runner` | Build TypeScript + tests unitaires | opus | Bash, Read, Edit |
| `github-tracker` | Suivi GitHub Project #67 | opus | MCP GitHub + Bash |
| `intercom-handler` | Communication locale Roo | opus | Read (plan mode) |
| `code-explorer` | Exploration codebase | opus | Read, Grep, Glob |

#### Agents Coordinateur (myia-ai-01 uniquement)

| Agent | Description | Usage |
|-------|-------------|-------|
| `roosync-hub` | Hub central : reçoit rapports, envoie instructions | Tour de sync, coordination |
| `dispatch-manager` | Assignation tâches aux 4 machines × 2 agents | Planification, ventilation |
| `task-planner` | Analyse avancement, équilibrage charge | Fin de phase, réflexion |

#### Agents Exécutants (autres machines)

| Agent | Description | Usage |
|-------|-------------|-------|
| `roosync-reporter` | Envoie rapports au coordinateur, reçoit instructions | Rapport de session |
| `task-worker` | Prend en charge tâches assignées, suit avancement | Exécution tâches |

#### Agents Workers Spécialisés ([.claude/agents/workers/](.claude/agents/workers/))

| Agent | Description | Modèle | Outils |
|-------|-------------|--------|--------|
| `code-fixer` | Investigation et correction de bugs | opus | Read, Grep, Glob, Edit, Write, Bash |
| `consolidation-worker` | Exécution consolidations CONS-X complètes | opus | Read, Grep, Glob, Edit, Write, Bash |
| `doc-updater` | Mise à jour documentation après changements | sonnet | Read, Grep, Glob, Edit, Write, Bash |
| `test-investigator` | Investigation tests échoués ou instables | opus | Read, Grep, Glob, Bash, Edit |

**Invocation manuelle :**
```
# Sur myia-ai-01 (coordinateur)
Utilise roosync-hub pour traiter les rapports entrants
Utilise dispatch-manager pour assigner les tâches

# Sur autres machines (exécutants)
Utilise roosync-reporter pour envoyer mon rapport
Utilise task-worker pour prendre ma prochaine tâche
```

### Skill Disponible ([.claude/skills/](.claude/skills/))

| Skill | Description | Phases |
|-------|-------------|--------|
| `sync-tour` | Tour de sync complet en 8 phases | INTERCOM → Messages → Git → Tests → GitHub → MAJ → Planning → Réponses |

**Les 8 phases du sync-tour :**
0. **INTERCOM Local** : ⚠️ CRITIQUE - Lire messages de Roo EN PREMIER (merge en cours?, modifs locales?)
1. **Collecte** : Messages RooSync non-lus
2. **Git Sync** : Pull conservatif + résolution conflits automatique + submodules
3. **Validation** : Build + tests unitaires (+ corrections simples)
4. **GitHub Status** : Project #67 + issues récentes + incohérences
5. **MAJ GitHub** : Marquer Done, commentaires (validation utilisateur pour nouvelles issues)
6. **Planification** : Ventilation 5 machines × 2 agents (Roo + Claude)
7. **Réponses** : Messages RooSync personnalisés + gestion machines silencieuses

**Usage :** Demander un "tour de sync" ou "faire le point".

**⚠️ Améliorations récentes (2026-01-18) :**
- Phase 0 ajoutée : Toujours lire INTERCOM avant tout (détecter urgences Roo)
- Phase 2 enrichie : Résolution automatique conflits git (fichiers + submodule)
- Phase 5 renforcée : Validation utilisateur OBLIGATOIRE avant créer issues
- Phase 7 améliorée : Escalade machines silencieuses (48h/72h/96h)

### Slash Commands ([.claude/commands/](.claude/commands/))

| Commande | Machine | Description |
|----------|---------|-------------|
| `/coordinate` | myia-ai-01 | Lance une session de coordination multi-agent (amélioré 2026-01-18) |
| `/executor` | Autres machines | Lance une session d'exécution (workflow multi-itérations ajouté) |
| `/sync-tour` | Toutes | Tour de synchronisation complet (8 phases - Phase 0 ajoutée) |
| `/switch-provider` | Toutes | Basculer entre Anthropic et z.ai |

**Usage :**
- **Coordinateur (myia-ai-01)** : Taper `/coordinate` pour démarrer une session de coordination
- **Exécutants** : Taper `/executor` pour recevoir les instructions et exécuter les tâches

**⚠️ Améliorations coordinate.md (2026-01-18) :**
- Section "Gestion des Urgences" ajoutée (conflits git, machines silencieuses, tests échouants)
- Guide d'usage des sub-agents (quand utiliser, quand gérer directement)
- Workflow démarrage standard en 7 étapes (INTERCOM d'abord, puis sync-tour)

**⚠️ Améliorations executor.md (2026-01-18) :**
- Workflow multi-itérations (Investigation → Action → Validation)
- Collaboration Claude ↔ Roo optimisée (2 cerveaux en parallèle)
- Objectif : 3+ actions majeures par itération minimum

### Workflow Recommandé

1. **Début de session** : Demander un "tour de sync" → active le skill
2. **Pendant le travail** : Les agents s'activent automatiquement selon le contexte
3. **Tâches spécifiques** : Invoquer explicitement l'agent si besoin
4. **Fin de session** : Tour de sync + commit si nécessaire

---

## ✅ État des MCPs (2026-02-06)

### ⚠️ VÉRIFICATION CRITIQUE AU DÉMARRAGE

**OBLIGATION :** Au début de CHAQUE session, vérifier que les outils MCP sont disponibles.

**Comment vérifier :**

1. Les outils MCP sont listés automatiquement dans les system-reminders au début de la conversation
2. Chercher les outils commençant par `roosync_` ou `mcp__`
3. Si ABSENTS : **RÉGRESSION CRITIQUE** → Réparer immédiatement

**Si les outils sont absents :**

1. **Vérifier la config** : `Read ~/.claude.json` → section `mcpServers`
2. **Tester le serveur** :

   ```bash
   cd mcps/internal/servers/roo-state-manager
   node mcp-wrapper.cjs 2>&1 | head -50
   ```

3. **Vérifier le wrapper** : Les outils filtrés doivent correspondre à registry.ts
4. **Redémarrer VS Code** : Les MCPs sont chargés au démarrage uniquement
5. **Si échec** : Créer issue GitHub haute priorité + alerter coordinateur

**⚠️ RÈGLE :** Si tu détectes l'absence d'outils MCP, tu DOIS le réparer avant toute autre tâche.

---

### Harmonisation Multi-Machines Complétée

**Harmonisation H2-H7 (issues #331-#336) :**

- ✅ H2 (#331) - jupyter/jupyter-mcp → N/A (myia-web1 sans Jupyter)
- ✅ H4 (#333) - github-projects-mcp → **DÉPRÉCIÉ**, remplacé par `gh` CLI (#368)
- ✅ H5 (#334) - markitdown MCP → Ajouté à toutes les machines
- 🔄 H6 (#335) - win-cli unbridled → En cours (myia-web1)
- ✅ H7 (#336) - jupyter-mcp-old → N/A (pas de legacy config)

### myia-ai-01 ✅ OPÉRATIONNEL

**MCPs Déployés :**

1. **GitHub CLI (`gh`)** - Remplace le MCP github-projects
   - **Statut :** ✅ MIGRATION COMPLÈTE (issue #368)
   - **Commande :** `gh issue`, `gh pr`, `gh api graphql`
   - **Projet :** "RooSync Multi-Agent Tasks" (#67)
   - **URL :** <https://github.com/users/jsboige/projects/67>
   - **Note :** Le MCP github-projects-mcp (57 outils) est **DÉPRÉCIÉ**
   - **Règle :** Voir `.claude/rules/github-cli.md` et `.roo/rules/github-cli.md`

2. **roo-state-manager** (39 outils - tous exposés)
   - Configuration : `~/.claude.json` avec wrapper [mcp-wrapper.cjs](mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs)
   - **Statut :** ✅ DÉPLOYÉ ET FONCTIONNEL (2026-02-10)
   - **Solution :** Wrapper v4 pass-through (dédup + log suppression, sans filtrage)
   - **Catégories d'outils (39 total) :**
     - **Messagerie CONS-1 (3)** : roosync_send, roosync_read, roosync_manage
     - **Lecture seule (4)** : get_status, list_diffs, compare_config, refresh_dashboard
     - **Consolidés (5)** : config, inventory, baseline, machines, init
     - **Décisions CONS-5 (2)** : roosync_decision, roosync_decision_info
     - **Monitoring (1)** : heartbeat_status
     - **Diagnostic (4)** : analyze_roosync_problems, diagnose_env, minimal_test_tool, read_vscode_logs
     - **Summary (1)** : roosync_summarize (CONS-12: consolidé 4→1)
     - **Tâches (5)** : task_browse, view_task_details, view_conversation_tree, get_raw_conversation, task_export
     - **Recherche (2)** : roosync_search, roosync_indexing
     - **Export (2)** : export_data, export_config
     - **MCP Management (5)** : storage_info, maintenance, manage_mcp_settings, rebuild_and_restart_mcp, get_mcp_best_practices, touch_mcp_settings
   - **Wrapper v4 :** [mcp-wrapper.cjs](mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs) dédup + log suppression (plus de filtrage)
   - **MAJ :** 2026-02-10 - Wrapper v4 pass-through (18→39 outils, accès tâches/search/export)

3. **markitdown** (1 outil)
   - Configuration : `~/.claude.json` (global)
   - **Statut :** ✅ Ajouté lors de H5 (#334)
   - **Outil :** `convert_to_markdown` - Convertir fichiers (PDF, DOCX, etc.) en markdown

### myia-web1 ✅ EN COURS D'HARMONISATION

**MCPs Déployés :**
- ✅ GitHub CLI (`gh`) - remplace MCP github-projects (#368)
- ✅ roo-state-manager (6 outils RooSync)
- ✅ markitdown (1 outil) - Ajouté le 2026-01-21
- 🔄 win-cli (en cours de déploiement)

**MCPs N/A :**
- N/A jupyter/jupyter-mcp (machine sans Jupyter)
- N/A jupyter-mcp-old (pas de legacy config)

### Autres machines (myia-po-2023, myia-po-2024, myia-po-2026)

**Statut :** ✅ Bootstrap complété, harmonisation en cours

**Action :**
- Harmonisation H2-H7 en cours de déploiement sur toutes les machines

---

## 🤖 Votre Rôle : Agent Claude Code

### Hiérarchie Claude ↔ Roo

**⚠️ RÈGLE FONDAMENTALE : Claude Code DIRIGE, Roo ASSISTE.**

**Claude Code est le cerveau principal.** Roo est un assistant polyvalent mais moins puissant et moins fiable.

| Aspect | Claude Code | Roo |
|--------|-------------|-----|
| **Intelligence** | Plus puissant (Opus 4.5) | Moins puissant (modèle variable) |
| **Vitesse** | Rapide | Plus lent |
| **Fiabilité** | Élevée | Moyenne (erreurs possibles) |
| **Autonomie** | Décisions critiques | Exécution supervisée |
| **Code** | **Tout, y compris critique** | Code simple, **VALIDÉ par Claude** |
| **Orchestration** | Coordination globale | Tâches longues/répétitives |
| **Validation** | Auto-validation + esprit critique | Travail de Roo TOUJOURS revalidé |

### ✅ Claude Peut Tout Faire

**Capacités Techniques COMPLÈTES :**
- **Investigation bugs** : Lire le code, tracer les erreurs, identifier les causes racines
- **Analyse de code** : Comprendre l'architecture, comparer implémentations
- **Exécution tests** : `npx vitest run` (PAS `npm test` qui bloque en mode watch), diagnostiquer les erreurs, valider les fixes
- **Écriture de code** : Fixes, features, refactoring - TOUT niveau de complexité
- **Build** : Compiler, valider, identifier erreurs TypeScript
- **Modification `mcps/internal/`** : Oui, avec tests de validation

**Coordination :**
- **Documentation** : Consolidation, nettoyage, indexation
- **GitHub** : Issues, Projects #67/#70, traçabilité
- **RooSync** : Messages inter-machines
- **INTERCOM** : Communication locale avec Roo

**Outils :** Read, Grep, Glob, Bash, Edit, Write, Git

### 🔄 Utiliser Roo Comme Assistant

**Claude prend les tâches complexes et critiques. Roo prend les tâches accessoires.**

**Roo est utile pour :**
- ✅ Lancer des tests (`npx vitest run`)
- ✅ Vérifier le build (`npm run build`)
- ✅ Lancer des scripts préparés par Claude
- ✅ Tâches répétitives (bulk operations simples)
- ✅ Documentation simple (copier/coller formatage)

**Claude garde pour lui :**
- 🎯 Implémentation de code (features, fixes, refactoring)
- 🎯 Investigation de bugs et analyse de code
- 🎯 Décisions d'architecture
- 🎯 Consolidation d'outils (comme CONS-8)
- 🎯 Résolution de conflits git
- 🎯 Validation et correction du travail de Roo

**⚠️ VALIDATION OBLIGATOIRE du travail de Roo :**
- **TOUJOURS** relire les modifications de Roo avant commit
- **TOUJOURS** valider la logique des changements avec esprit critique
- **TOUJOURS** corriger les erreurs subtiles (imports, types, logique)
- **JAMAIS** faire confiance aveuglément au code de Roo

### ❌ À NE PAS FAIRE (CRITIQUE)

- ❌ **Déléguer l'implémentation de code à Roo** - Claude doit coder les features/fixes
- ❌ **Confier les tâches critiques à Roo sans supervision**
- ❌ **Se contenter de coordonner** - Claude doit prendre les tâches les plus dures
- ❌ **Supposer que le code de Roo est correct** - TOUJOURS valider avec esprit critique
- ❌ **Attendre passivement les instructions de Roo** - C'est l'inverse : Claude dirige
- ❌ **Rester inactif en attente de travail** - JAMAIS en attente passive (voir règle ci-dessous)
- ❌ **Faire confiance aveuglément** - Validation critique obligatoire des deux côtés

### 🚨 RÈGLE ANTI-ATTENTE PASSIVE (NOUVEAU 2026-02-06)

**SI tu termines une tâche et n'as rien à faire : C'EST UNE ERREUR.**

**Checklist obligatoire après chaque tâche :**

1. ✅ **Analyser les tâches disponibles** : Consulter GitHub Project #67, RooSync messages, INTERCOM
2. ✅ **Prendre l'initiative** : Choisir une tâche substantielle (investigation, features, consolidation)
3. ✅ **Si tâche trop petite** : En prendre plusieurs OU demander une plus grosse au coordinateur
4. ✅ **Aider Roo** : Si Roo travaille sur une grosse tâche, proposer assistance (investigation, validation)
5. ✅ **Signaler le problème** : Si vraiment rien à faire, envoyer message RooSync au coordinateur

**Signes d'erreur d'équilibrage :**

- Tu termines une tâche en <1h alors que Roo a une tâche de plusieurs heures
- Tu te retrouves à "attendre des instructions"
- Tu n'as qu'une petite tâche de cleanup alors que du code complexe est à écrire
- Roo fait de l'implémentation critique pendant que tu documentes

**Action corrective immédiate :**

1. **Message RooSync** au coordinateur pour signaler le déséquilibre
2. **Prendre le relais** sur la tâche complexe (investigation, analyse, proposition de solution)
3. **Mettre à jour CLAUDE.md** si les règles ne sont pas claires
4. **Valider le travail de Roo** avec esprit critique si déjà en cours

**Exemple d'équilibrage correct :**

- **Claude** : CONS-10 Phase 4 (investigation E2E tests + implémentation) = plusieurs heures
- **Roo** : CLEANUP-2 (retrait 3 outils) + validation build/tests = <1h

**Exemple d'équilibrage INCORRECT (à corriger) :**

- **Claude** : CLEANUP-2 (retrait 3 outils) = <1h, puis attente ❌
- **Roo** : CONS-10 Phase 4 (investigation E2E tests) = plusieurs heures

**Responsabilité :** Claude doit prendre le gros du travail technique. Roo est l'assistant.

### ⚠️ CONTRAINTE CLÉ

**Vous n'avez PAS accès à votre historique de conversation.**

Utilisez :
- **GitHub Issues** comme "mémoire externe"
- **RooSync** pour la coordination inter-machine
- **INTERCOM** pour la coordination locale (même machine)

---

## 🔄 Canaux de Communication

### 1. RooSync (Inter-Machine)

**Objectif :** Coordination entre les 5 machines

**Outils MCP (CONS-1) :**
- `roosync_send` - Envoyer/répondre/amender message (action: send|reply|amend)
- `roosync_read` - Lire inbox/message (mode: inbox|message)
- `roosync_manage` - Gérer messages (action: mark_read|archive)

**Legacy (backward compat, non exposés dans wrapper) :**
- `roosync_send_message`, `roosync_read_inbox`, `roosync_reply_message`
- `roosync_get_message`, `roosync_mark_message_read`, `roosync_archive_message`

**Fichier :** `G:/Mon Drive/Synchronisation/RooSync/.shared-state/`

**Documentation :** [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](docs/roosync/GUIDE-TECHNIQUE-v2.3.md)

### 2. INTERCOM (Locale Claude Code ↔ Roo)

**Objectif :** Coordination locale sur la même machine

**Fichier :** `.claude/local/INTERCOM-{MACHINE_NAME}.md`

**Documentation :** [`.claude/INTERCOM_PROTOCOL.md`](.claude/INTERCOM_PROTOCOL.md)

**Protocole :**
1. Vérifier les messages de l'autre agent au démarrage
2. Envoyer message : Ouvrir fichier → Ajouter message → Sauvegarder
3. Format : Markdown avec horodatage

```markdown
## [2026-01-09 10:00:00] claude-code → roo [TASK]
Merci de tester le module X.

---
```

**Types de messages :** `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`

### 3. GitHub Issues (Traçabilité)

**Objectif :** Suivi des tâches multi-agent

**Projet :** "RooSync Multi-Agent Tasks"
- URL : https://github.com/users/jsboige/projects/67
- 60 items en cours

**Format des issues :**
```
Titre: [CLAUDE-MACHINE] Titre de la tâche
Labels: claude-code, priority-X
```

### 4. Tâches Planifiées Roo (Scheduler) - DOCUMENTATION COMPLÈTE

**Objectif :** Système de planification automatique pour Roo avec exécution périodique de tâches de maintenance

#### Architecture du Système

**Composants :**

1. **Extension Roo Scheduler** (`kylehoskins.roo-scheduler`)
   - Extension VS Code qui lit `.roo/schedules.json`
   - Exécute les tâches selon l'intervalle configuré
   - Enregistre les traces dans `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks`

2. **Configuration Scheduler**
   - **Template** : `.roo/schedules.template.json` (source générique)
   - **Déployé** : `.roo/schedules.json` (personnalisé par machine)
   - **Format** : Roo Scheduler natif (scheduleType, timeInterval, taskInstructions, etc.)

3. **Modes Roo** (orchestrateurs)
   - **Source** : `roo-config/modes/modes-config.json` (données structurées)
   - **Template** : `roo-config/modes/templates/commons/mode-instructions.md` (instructions)
   - **Généré** : `roo-config/modes/generated/simple-complex.roomodes` (10 modes)
   - **Déployé** : `.roomodes` (copié à la racine du workspace)

#### Workflow de Génération et Déploiement

##### 1. Modes Roo (10 modes : 5 familles × 2 niveaux)

**Génération automatique :**

```bash
# Dans roo-extensions/
node roo-config/scripts/generate-modes.js
```

**Ce script :**
- Lit `roo-config/modes/modes-config.json` (5 familles : code, debug, architect, ask, orchestrator)
- Lit `roo-config/modes/templates/commons/mode-instructions.md` (template avec {{VAR}})
- Génère `roo-config/modes/generated/simple-complex.roomodes` (10 modes)
- Applique le template pour chaque famille×niveau avec variables :
  - `{{FAMILY}}`, `{{LEVEL}}`, `{{ESCALATION_CRITERIA}}`, `{{ADDITIONAL_INSTRUCTIONS}}`, etc.
  - Conditions `{{#if NO_COMMAND}}`, `{{#if NO_EDIT}}` pour restrictions
- Taille : ~30 KB, 10 modes JSON

**Déploiement manuel :**

```powershell
# Copier vers .roomodes
Copy-Item roo-config/modes/generated/simple-complex.roomodes .roomodes
```

**⚠️ IMPORTANT :** Les modes NE doivent PAS être modifiés à la main dans `.roomodes`. Toute modification doit être faite dans `modes-config.json` ou le template, puis régénérée.

**Améliorations récentes (commit 07706f0, 2026-02-10) :**
- Ajout section `additionalInstructions` pour orchestrateurs (lignes 111-132 de modes-config.json)
- Instructions SDDD : délégation via `new_task`, prompts complets (grounding + tâche + validation + résumé)
- **Correctif critique** : "NE JAMAIS faire le travail toi-même : TOUJOURS déléguer"

##### 2. Scheduler (Configuration)

**Déploiement automatisé :**

```powershell
# Dans roo-extensions/
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy
```

**Ce script (`deploy-scheduler.ps1`) :**
- Lit `.roo/schedules.template.json`
- Remplace `${MACHINE_NAME}` par `$env:COMPUTERNAME.ToLower()`
- Remplace `TEMPLATE_ID` par timestamp unique `[DateTimeOffset]::Now.ToUnixTimeMilliseconds()`
- Supprime `_template_note` de chaque schedule
- Sauvegarde en UTF-8 **sans BOM** dans `.roo/schedules.json` (fix commit a4c2178)
- VS Code Roo Scheduler charge automatiquement la nouvelle config

**Corrections récentes (commits 195af59 + a4c2178, 2026-02-10) :**
- ✅ Fix UTF-8 sans BOM (BOM casse le parsing JSON de Roo Scheduler)
- ✅ Fix `_template_note` removal (itère maintenant sur schedules, pas root)
- ✅ Fix `enabled` → `active` (3 occurrences)
- ✅ Fix vérification extension (remplace obsolete orchestration-engine.ps1)

**Paramètres de production :**
- **Intervalle** : 180 minutes (3h) entre chaque exécution
- **Staggering** : startMinute différent par machine (éviter surcharge LLM simultanée)
  - myia-ai-01: 00, myia-po-2023: 30, myia-po-2024: 00, myia-po-2025: 30, myia-po-2026: 00, myia-web1: 30
- **Mode** : `orchestrator-simple` (délègue aux modes `-simple` via `new_task`)

**Commandes utiles :**

```powershell
# Désactiver le scheduler
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action disable

# Vérifier le statut
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action status
```

#### Workflow d'une Exécution Scheduler

**Template actuel (après corrections 2026-02-10) :**

1. **Étape 1** : Lire l'INTERCOM local (`.claude/local/INTERCOM-${MACHINE_NAME}.md`)
   - Chercher messages [SCHEDULED], [TASK], [URGENT] de Claude Code

2. **Étape 2** : Vérifier l'état du workspace
   - `git status` : changements non commités ?
   - Si dirty : NE PAS commiter, signaler dans rapport

3. **Étape 3** : Exécuter les tâches
   - **DÉLÉGUER via `new_task`** aux modes `-simple` ou `-complex`
   - **NE JAMAIS faire le travail soi-même**
   - Si complexe : escalader vers `orchestrator-complex`

4. **Étape 4** : Rapporter dans l'INTERCOM LOCAL
   - **Utiliser `write_file` (ou `edit_file`)** pour écrire dans `.claude/local/INTERCOM-${MACHINE_NAME}.md`
   - **NE PAS utiliser `roosync_send`** (c'est pour inter-machines, pas local)
   - Format : `## [{DATE}] roo -> claude-code [DONE]`

5. **Étape 5** : Ne PAS commiter
   - Claude Code valide le travail lors du prochain tour
   - Commits sont responsabilité de Claude Code

6. **Étape 6** : Maintenance INTERCOM (si >1000 lignes)
   - Condenser 600 premières lignes → ~100 lignes (synthèse)
   - Garder 400 dernières lignes intactes
   - Résultat : ~500 lignes

#### Traces d'Exécution

**Chemin :** `C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\{TASK_ID}`

**Fichiers par tâche :**
- `api_conversation_history.json` - Historique complet (requêtes/réponses API)
- `task_metadata.json` - Métadonnées (createdAt, lastActivity, messageCount, actionCount)
- `ui_messages.json` - Messages UI condensés (rapide à lire)

**Vérification régulière (Issue #447) :**
- Consulter traces après chaque run (~3h)
- Analyser problèmes de délégation (orchestrateur fait au lieu de déléguer)
- Identifier erreurs (utilisation roosync_send au lieu de write_file, outils inexistants)
- Reporter anomalies dans INTERCOM ou RooSync

#### Workflow d'Amélioration du Système

**1. Identifier le problème**
   - Lire traces d'exécution (`ui_messages.json` ou `api_conversation_history.json`)
   - Identifier pattern d'erreur (ex: demande utilisateur au lieu de `new_task`)

**2. Corriger à la source**

   **Pour instructions orchestrateur :**
   - Modifier `roo-config/modes/modes-config.json` (section `additionalInstructions`)
   - Régénérer : `node roo-config/scripts/generate-modes.js`
   - Copier : `Copy-Item roo-config/modes/generated/simple-complex.roomodes .roomodes`

   **Pour workflow scheduler :**
   - Modifier `.roo/schedules.template.json` (source unique)
   - Redéployer : `.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy`

**3. Tester localement**
   - Attendre prochaine exécution du scheduler (vérifier `nextExecutionTime` dans `.roo/schedules.json`)
   - Ou relancer manuellement via Roo extension

**4. Déployer sur toutes les machines**
   - Commit + push les changements (`modes-config.json` ou `schedules.template.json`)
   - Chaque machine pull + redéploie avec scripts

#### Historique des Corrections Importantes

| Date | Commit | Correction |
|------|--------|-----------|
| 2026-02-10 | 07706f0 | Ajout instructions SDDD orchestrateurs (délégation `new_task`) |
| 2026-02-10 | 195af59 | Fix 4 bugs deploy-scheduler.ps1 (_template_note, enabled→active, etc.) |
| 2026-02-10 | a4c2178 | Fix UTF-8 sans BOM (parsing JSON Roo Scheduler) |
| 2026-02-10 | **LOCAL** | Fix Étape 4 : utiliser write_file au lieu de roosync_send |
| 2026-02-09 | 1f6806f | Ajout Étape 6 maintenance INTERCOM (compaction >1000 lignes) |
| 2026-02-09 | 6933a2f | Réécriture template format Roo Scheduler natif + Étape 6 |

#### Fichiers Sources (Ne Jamais Modifier Manuellement les Cibles)

| Source (à modifier) | Générateur/Déployeur | Cible (généré) |
|---------------------|----------------------|----------------|
| `roo-config/modes/modes-config.json` | `roo-config/scripts/generate-modes.js` | `roo-config/modes/generated/simple-complex.roomodes` |
| `roo-config/modes/templates/commons/mode-instructions.md` | (idem) | (idem) |
| `roo-config/modes/generated/simple-complex.roomodes` | Copie manuelle | `.roomodes` |
| `.roo/schedules.template.json` | `roo-config/scheduler/scripts/install/deploy-scheduler.ps1` | `.roo/schedules.json` |

**⚠️ RÈGLE ABSOLUE :** Ne JAMAIS modifier directement `.roomodes` ou `.roo/schedules.json`. Toujours modifier les sources et régénérer.

---

### 5. Processus de Feedback et Amélioration Continue

**Objectif :** Améliorer les workflows (commands/skills/agents) basé sur l'expérience terrain

**Principe :** Évolution prudente et collective pour éviter le feature creep

**Workflow de proposition :**

1. **Identification** (n'importe quel agent Claude)
   - Repérer un problème/friction dans le workflow actuel
   - Documenter l'expérience concrète qui pose problème
   - Proposer une amélioration spécifique et minimaliste

2. **Consultation collective** (via RooSync)
   - Envoyer message RooSync à `to: "all"` avec:
     - Sujet: `[FEEDBACK] Amélioration proposée: <titre court>`
     - Contexte de l'expérience terrain
     - Proposition concrète
     - Risques de feature creep identifiés
   - Demander avis critique des autres agents (24-48h)

3. **Collecte des retours**
   - Chaque agent peut répondre avec son opinion
   - Focus sur: "Est-ce vraiment nécessaire?" et "Risques?"
   - Les agents servent de garde-fou contre le feature creep

4. **Décision finale** (coordinateur myia-ai-01)
   - Synthétiser les retours
   - Décision: APPROUVER / REJETER / MODIFIER
   - Si approuvé: créer issue GitHub pour traçabilité
   - Documenter la décision dans le thread RooSync

**Critères d'approbation :**
- ✅ Résout un problème réel rencontré (pas théorique)
- ✅ Solution minimale et ciblée
- ✅ Pas de complexité excessive
- ✅ Consensus ou majorité des agents
- ❌ Rejet si: feature creep, complexité, problème théorique

**Exemple de message RooSync :**
```markdown
Subject: [FEEDBACK] Amélioration sync-tour: Phase validation GitHub
Priority: MEDIUM
Tags: feedback, workflow-improvement

Contexte: Lors de mes 3 derniers sync-tours, j'ai dû manuellement vérifier
les issues fermées car la Phase 5 ne détectait pas les items marqués Done.

Proposition: Ajouter un check automatique des incohérences
(item Done sur GitHub mais issue Open).

Risques identifiés:
- Complexité accrue si on essaie de tout détecter
- Peut ralentir la Phase 5

Solution minimale: Ajouter 1 seule vérification pour le cas le plus fréquent.

Qu'en pensez-vous? Est-ce vraiment nécessaire?
```

**Documentation des améliorations :**
- Issue GitHub avec label `workflow-improvement`
- MAJ du fichier concerné (.claude/commands/, skills/, agents/)
- Note dans CLAUDE.md section "Leçons Apprises"

---

## 📋 Structure du Dépôt

### Documentation Principale
```
.claude/
├── README.md              # Point d'entrée (court)
├── INDEX.md               # Table des matières détaillée
├── CLAUDE.md              # Ce fichier
├── CLAUDE_CODE_GUIDE.md   # Méthodologie SDDD complète
├── MCP_SETUP.md           # Guide configuration MCP
├── INTERCOM_PROTOCOL.md   # Protocole communication locale
├── agents/                # 🆕 Subagents spécialisés
│   ├── coordinator/
│   │   ├── roosync-hub.md           # Messages RooSync (coordinateur)
│   │   └── dispatch-manager.md      # Assignment tâches
│   ├── executor/
│   │   ├── roosync-reporter.md      # Messages RooSync (exécutants)
│   │   └── task-worker.md           # Exécution tâches
│   ├── workers/
│   │   ├── code-fixer.md             # Investigation et correction bugs
│   │   ├── consolidation-worker.md   # Consolidation CONS-X
│   │   ├── doc-updater.md            # MAJ documentation
│   │   └── test-investigator.md      # Investigation tests
│   ├── github-tracker.md       # GitHub Project #67
│   ├── git-sync.md             # Pull/merge conservatif
│   ├── test-runner.md          # Build + tests
│   ├── task-planner.md         # Ventilation 5×2 agents
│   ├── intercom-handler.md     # Communication locale Roo
│   └── code-explorer.md        # Exploration codebase
├── memory/                # Mémoire projet partagée (via git)
│   └── PROJECT_MEMORY.md       # Connaissances partagées multi-machines
├── skills/                # Skills auto-invoqués
│   └── sync-tour/SKILL.md
├── commands/              # Slash commands
│   └── switch-provider.md
├── scripts/               # Scripts d'initialisation
│   └── init-claude-code.ps1
└── local/                 # Communication locale (gitignored)
    └── INTERCOM-myia-ai-01.md
```

### Documentation Technique (consolide #435 + contenu : 10 repertoires actifs)

```
docs/
├── architecture/     # Architecture systeme, designs, analyses (+archive/)
├── archive/          # Contenu historique/obsolete (git, guides, deployment v2.1)
├── deployment/       # Deploiement, hardware (2 docs actifs)
├── dev/              # Debugging, encoding, fixes, tests, refactoring (+archives locales)
├── guides/           # Guides utilisateur, installation, depannage MCP unifie
├── knowledge/        # Base de connaissances (WORKSPACE_KNOWLEDGE.md)
├── mcp/              # Documentation MCP roo-state-manager (+archive/)
├── roo-code/         # Documentation Roo Code, PRs, ADR
├── roosync/          # Protocoles RooSync v2.3, guides agents (+archive/)
├── suivi/            # Suivi projet actif, monitoring (+archive/)
├── INDEX.md          # Table des matieres v5.0
└── README.md
```

### Code Source
```
mcps/
├── internal/servers/
│   ├── roo-state-manager/               # ✅ DÉPLOYÉ (avec wrapper)
│   └── github-projects-mcp/             # ⚠️ DÉPRÉCIÉ - Utiliser gh CLI (#368)
└── external/                             # MCPs externes (12 serveurs)
```

---

## 🚀 Pour Démarrer une Nouvelle Tâche

### 1. Vérifier l'environnement

```powershell
# Identifier la machine
$env:COMPUTERNAME

# Vérifier les MCP disponibles
# (Les outils MCP sont listés au démarrage de la conversation)
```

### 2. Lire la documentation

- [`.claude/INDEX.md`](.claude/INDEX.md) - Carte complète
- [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md) - Configuration MCP
- [`.claude/CLAUDE_CODE_GUIDE.md`](.claude/CLAUDE_CODE_GUIDE.md) - Méthodologie SDDD

### 3. Vérifier les communications

**RooSync :**
```bash
roosync_read  # Vérifier les messages inter-machines (mode: inbox)
```

**INTERCOM :**
```bash
# Ouvrir .claude/local/INTERCOM-{MACHINE}.md
# Chercher messages récents de Roo
```

**GitHub :**
```bash
# Vérifier les issues récentes avec label "claude-code"
```

### 4. Annoncer son travail (anti-conflit)

**OBLIGATOIRE avant de commencer toute tache significative.**

**Pourquoi :** Eviter les conflits git et le travail en double quand plusieurs agents/machines travaillent sur les memes fichiers.

**Comment :**

1. **INTERCOM local** : Ajouter un message dans `.claude/local/INTERCOM-{MACHINE}.md` indiquant :
   - Les taches prises en charge (numeros d'issues)
   - Les fichiers/zones impactes
   - Demande de ne pas modifier ces zones en parallele

2. **RooSync** (si disponible) : Envoyer un message `roosync_send` a `to: "all"` avec :
   - Sujet : `[WORK] Taches en cours sur {MACHINE}`
   - Liste des taches et fichiers impactes

3. **GitHub** : Commenter les issues prises en charge pour signaler le travail en cours

**Exemple INTERCOM :**

```markdown
## [TIMESTAMP] claude-code → roo [INFO]
### Session active - Taches en cours
- #435 - Consolidation docs/ (fichiers impactes: docs/*)
- Merci de ne pas modifier ces zones en parallele.
```

### 5. Creer une issue de tracabilite

**OBLIGATOIRE pour toute tâche significative.**

Format :
```
Titre: [CLAUDE-MACHINE] Description de la tâche
Labels: claude-code, priority-<HIGH|MEDIUM|LOW>
Body:
- Contexte: ...
- Objectifs: ...
- Livrables: ...
```

### 6. Travailler et documenter

- **Attendez-vous** à ce qui est réellement disponible, pas à ce qui devrait l'être
- **Testez** les MCPs avant de les utiliser
- **Documentez** la réalité, pas les hypothèses
- **Communiquez** via RooSync, INTERCOM et GitHub

---

## 🎯 Contexte Actuel

**⚠️ IMPORTANT** : L'état actuel du projet change quotidiennement.

**Pour l'état à jour, consulter dans cet ordre :**

1. **Git log** : `git log --oneline -10` - Historique réel des dernières actions
2. **GitHub Project #67** : https://github.com/users/jsboige/projects/67 - Avancement global (% Done)
3. **GitHub Issues** : Issues ouvertes et en cours
4. **INTERCOM local** : `.claude/local/INTERCOM-myia-ai-01.md` - Messages récents de Roo
5. **SUIVI_ACTIF.md** : [`docs/suivi/RooSync/SUIVI_ACTIF.md`](docs/suivi/RooSync/SUIVI_ACTIF.md) - Résumé minimal (peut être obsolète)

**Organisation bicéphale confirmée :**
- **Claude Code (myia-ai-01)** : Git, GitHub Projects, RooSync, Documentation, Coordination
- **Roo (toutes machines)** : Tâches techniques (bugs, features, tests, builds)

### Contraintes Critiques

- **NE PAS supposer que les MCPs sont disponibles** - tester d'abord
- **Utiliser les outils natifs Claude Code** - Read, Grep, Bash, Git
- **NE PAS inventer de workflows** - tester ce qui fonctionne réellement
- **Documenter la réalité** - ce qui est vérifié, pas ce qui est supposé
- **PAS de nouvelles fonctionnalités** - Focus déploiement et stabilisation

### ⚠️ Validation Utilisateur OBLIGATOIRE

**AVANT de créer une nouvelle tâche GitHub (#67 ou #70) :**
1. Présenter la tâche proposée à l'utilisateur
2. Expliquer pourquoi elle est nécessaire
3. Attendre validation explicite
4. Seulement ensuite créer l'issue

**Exception :** Bugs critiques bloquants (informer immédiatement)

### 🔍 CHECKLIST DE VALIDATION TECHNIQUE OBLIGATOIRE

⚠️ **NOUVELLE RÈGLE (2026-02-01) - Suite erreurs CONS-3/CONS-4**

Pour **TOUTE** tâche de consolidation, refactoring, ou modification significative :

#### Avant de Commencer

- [ ] **Compter** : Nombre d'outils/fichiers/modules actuels (état AVANT)
- [ ] **Documenter** : Noter ce décompte dans l'issue GitHub ou documentation
- [ ] **TDD (Recommandé)** : Écrire les tests qui valident l'état final AVANT l'implémentation
  - Tests qui vérifient le nouveau comportement unifié
  - Tests qui échouent si les anciens outils sont encore présents
  - Tests qui valident le décompte final (ex: `expect(roosyncTools.length).toBe(24)`)
  - → Les tests servent de **spécification exécutable**

#### Pendant l'Implémentation

- [ ] **Coder** : Implémenter la modification
- [ ] **Tester** : Build + tous les tests passent (`npx vitest run`)
- [ ] **Vérifier imports/exports** : Aucun export orphelin, aucun import cassé

#### Après l'Implémentation (CRITIQUE)

- [ ] **Recompter** : Nombre d'outils/fichiers/modules final (état APRÈS)
- [ ] **Calculer écart** : Écart réel = APRÈS - AVANT
- [ ] **Comparer** : Écart réel DOIT égaler écart annoncé (ex: 4→2 = -2)
- [ ] **SI ÉCART INCORRECT** : Identifier ce qui manque (retrait d'anciens fichiers?)
- [ ] **Retirer deprecated** : Les éléments marqués [DEPRECATED] doivent être RETIRÉS, pas juste commentés
- [ ] **Mettre à jour array/exports** : Vérifier que roosyncTools, exports, etc. sont corrects

#### Documentation Commit

- [ ] **Commit message** : Inclure décompte avant/après (ex: "CONS-3: Config 4→2 (29→24 outils)")
- [ ] **Vérifier** : Le nombre dans le commit message correspond à la réalité Git

#### Exemple d'Erreur à Éviter

❌ **MAUVAIS** : Créer `roosync_config` unifié SANS retirer `collect_config`, `publish_config`, `apply_config` de l'array → Résultat 29→30 (+1) au lieu de 29→27 (-2)

✅ **BON** : Créer `roosync_config` unifié ET retirer les 3 anciens de roosyncTools → Résultat 29→27 (-2) ✓

**Cette checklist est OBLIGATOIRE. Tout agent qui ne la suit pas sera rappelé à l'ordre.**

---

## 📝 Méthodologie SDDD pour Claude Code

### Triple Grounding

**1. Grounding Sémantique**
- Outils : `search_tasks_by_content` (Roo MCP) + Grep/Glob
- Recherche sémantique + recherche textuelle
- Lecture des documents pertinents

**2. Grounding Conversationnel**
- Outils : `view_conversation_tree`, `get_conversation_synthesis` (Roo MCP)
- Arborescence des conversations
- Synthèse LLM

**3. Grounding Technique**
- Outils : Read, Grep, Bash, Git
- Lecture code source
- Validation faisabilité

### Traçabilité GitHub

**OBLIGATION CRITIQUE :** Créer une issue GitHub pour toute tâche significative.

**Documentation complète :** [`.claude/CLAUDE_CODE_GUIDE.md`](.claude/CLAUDE_CODE_GUIDE.md)

---

## 🤝 Coordination Multi-Agent

### Répartition des Machines

| Machine | Rôle | Statut MCP |
|---------|------|------------|
| **myia-ai-01** | Coordinateur Principal | ✅ GitHub + RooSync + Jupyter |
| **myia-po-2023** | Agent flexible | ✅ GitHub + RooSync + Jupyter |
| **myia-po-2024** | Agent flexible | ✅ GitHub + RooSync + Jupyter |
| **myia-po-2026** | Agent flexible | ✅ GitHub + RooSync + Jupyter |
| **myia-web1** | Agent flexible | ✅ GitHub + RooSync (Jupyter N/A) |

**Toutes les machines ont des capacités égales** - pas de spécialisation rigide.

### Responsabilités

**myia-ai-01 (Coordinateur) :**
- Créer les issues GitHub pour les catégories de tâches
- Maintenir le suivi global
- Coordonner la distribution du travail
- Consolider et intégrer les résultats

**Tous les agents :**
- Choisir les tâches disponibles dans les issues GitHub
- S'auto-assigner via les commentaires GitHub
- Reporter les progrès quotidiennement
- Coordonner via les commentaires
- Demander de l'aide si bloqué

### Responsabilités du Coordinateur (RENFORCÉ 2026-02-01)

⚠️ **Le coordinateur DOIT fournir des critères de validation mesurables pour chaque tâche.**

Pour toute tâche de consolidation/refactoring assignée, le coordinateur doit spécifier :

**Critères de validation obligatoires :**

1. **État initial** : Nombre d'outils/fichiers/modules AVANT (ex: "29 outils actuellement")
2. **État cible** : Nombre attendu APRÈS (ex: "24 outils après consolidation")
3. **Écart attendu** : Réduction/augmentation précise (ex: "-5 outils")
4. **Tests requis** : Quels tests doivent passer (ex: "npx vitest run → 1648 tests PASS")
5. **Livrables** : Fichiers modifiés/créés attendus (ex: "config.ts créé, index.ts modifié")

**Exemple d'assignation correcte :**

```markdown
## Tâche : CONS-3 Phase 1 - Consolidation Config

**État initial :** 29 outils dans roosyncTools
**État cible :** 24 outils (29 - 3 anciens - 1 nouveau = 25, mais on retire aussi compare → 24)
**Écart attendu :** -5 outils

**Critères de validation :**
- [ ] roosync_config créé et testé
- [ ] collect_config, publish_config, apply_config RETIRÉS de roosyncTools array
- [ ] Nombre d'outils = 24 (vérifier roosyncTools.length)
- [ ] npx vitest run → tous les tests passent
- [ ] Commit message inclut "29→24 outils"

**Livrables :**
- config.ts (nouveau)
- config.test.ts (nouveau)
- index.ts (modifié : exports + roosyncTools array)
```

**SI le coordinateur ne fournit pas ces critères :**

- L'agent doit demander clarification AVANT de commencer
- L'agent doit documenter lui-même ces critères et les faire valider

**Cette responsabilité est CRITIQUE pour éviter les erreurs de validation.**

### Communication Quotidienne

1. **Git log** est la source de vérité pour les actions techniques
2. **GitHub Issues** pour le suivi des tâches et bugs
3. **RooSync** pour les messages urgents entre machines
4. **SUIVI_ACTIF.md** contient uniquement un résumé avec références git/github

---

## 📖 Règles de Documentation (NOUVEAU PARADIGME)

### Principes Fondamentaux

**Git/GitHub est la source principale de journalisation.**

| Type | Où | Comment |
|------|-----|---------|
| **Actions techniques** | Git commits | Messages clairs avec issue # |
| **Suivi de tâches** | GitHub Issues | Créer, commenter, fermer |
| **Progression** | GitHub Projects | Mettre à jour statut |
| **Coordination** | RooSync messages | Urgent uniquement |
| **Documentation** | docs/ pérenne | Se consolide, pas éphémère |

### ❌ À NE PLUS CRÉER

- Nouveaux rapports de "synthèse" ou "coordination" quotidiens
- Rapports de mission redondants avec git log
- Fichiers de suivi verbeux sans valeur ajoutée

### ✅ À MAINTENIR

| Fichier | Usage | MAJ |
|---------|-------|-----|
| `docs/suivi/RooSync/SUIVI_ACTIF.md` | Résumé minimal avec refs git | Quotidien |
| `docs/suivi/RooSync/BUGS_TRACKING.md` | Bugs et statuts | Quand bugs |
| `CLAUDE.md` | Ce fichier - Règles principales | Quand règles changent |
| `docs/roosync/*.md` | Documentation technique pérenne | Quand architecture change |

### Format des Commits

```bash
# Format conventionnel
type(scope): description

# Exemples
fix(roosync): Fix #289 - BOM UTF-8 in JSON parsing
docs(coord): Update CLAUDE.md with new governance rules
feat(roosync): Add baseline comparison feature
test(roosync): Add E2E tests for sync workflow

# Avec co-auteur (si Claude Code)
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

### Quand créer une GitHub Issue

- Nouveau bug identifié
- Nouvelle fonctionnalité significative
- Tâche de coordination multi-machine
- Documentation manquante critique

**Ne PAS créer d'issue pour:**
- Corrections triviales (directement commit)
- Mises à jour de documentation mineures
- Tests simples

### SUIVI_ACTIF.md - Format Minimal

```markdown
## 2026-01-13

- Bugs #289-291 assignés à Roo (voir #289, #290, #291)
- T1.2 complétée (commit f3e00f3)
- Git synchronisé (3bdb1c7e)

[voir git log --oneline -5]
```

---

## 📚 Ressources Supplémentaires

### Documentation Technique
- [`docs/knowledge/WORKSPACE_KNOWLEDGE.md`](docs/knowledge/WORKSPACE_KNOWLEDGE.md) - Base connaissance complète
- [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](docs/roosync/GUIDE-TECHNIQUE-v2.3.md) - Guide RooSync

### Scripts et Outils
- [`.claude/scripts/init-claude-code.ps1`](.claude/scripts/init-claude-code.ps1) - Initialisation MCP
- [`mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs`](mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs) - Wrapper MCP

### GitHub
- **Projet :** https://github.com/users/jsboige/projects/67
- **Issues :** https://github.com/jsboige/roo-extensions/issues

---

**Dernière mise à jour :** 2026-02-07
**Pour questions :** Créer une issue GitHub ou contacter myia-ai-01

**Built with Claude Code (Opus 4.5) 🤖**

---

## 🔧 GitHub Projects - Accès via gh CLI

**⚠️ MIGRATION #368 :** Le MCP github-projects-mcp est **DÉPRÉCIÉ**. Utiliser `gh` CLI.

### Projets

| Projet | Numéro | ID Complet | Usage |
|--------|--------|------------|-------|
| RooSync Multi-Agent Tasks | #67 | `PVT_kwHOADA1Xc4BLw3w` | Tâches techniques Roo |
| RooSync Multi-Agent Coordination | #70 | `PVT_kwHOADA1Xc4BL7qS` | Coordination Claude |

### Commandes gh CLI

```bash
# Lister les issues
gh issue list --repo jsboige/roo-extensions --state open

# Créer une issue
gh issue create --repo jsboige/roo-extensions --title "Titre" --body "Description"

# Voir un projet (GraphQL)
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { title items(first: 100) { totalCount } } } }'

# Voir les items d'un projet avec statut
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { items(first: 50) { nodes { fieldValues(first: 10) { nodes { ... on ProjectV2ItemFieldSingleSelectValue { name } } } } } } } }'
```

### Field Status (pour GraphQL avancé)

- **Field ID:** `PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY`
- **Options:**
  - `f75ad846` = Todo
  - `47fc9ee4` = In Progress
  - `98236657` = Done

### Règles

Voir `.claude/rules/github-cli.md` et `.roo/rules/github-cli.md` pour les détails.

---

## 📡 RooSync MCP - Configuration

### Outils Disponibles (39 - tous exposés, 2026-02-10)

**Messagerie CONS-1 (3):**
- `roosync_send` - Envoyer/répondre/amender (action: send|reply|amend)
- `roosync_read` - Lire inbox/message (mode: inbox|message)
- `roosync_manage` - Gérer messages (action: mark_read|archive)

**Lecture seule (4):** `roosync_get_status`, `roosync_list_diffs`, `roosync_compare_config`, `roosync_refresh_dashboard`

**Consolidés (5):** `roosync_config`, `roosync_inventory`, `roosync_baseline`, `roosync_machines`, `roosync_init`

**Décisions CONS-5 (2):** `roosync_decision`, `roosync_decision_info`

**Monitoring (1):** `roosync_heartbeat_status`

**Diagnostic (4):** `analyze_roosync_problems`, `diagnose_env`, `minimal_test_tool`, `read_vscode_logs`

**Summary (1):** `roosync_summarize`

**Tâches Roo (5) - NOUVEAU :**
- `task_browse` - Arborescence tâches, parent/enfant, tâche courante (CONS-9)
- `view_task_details` - Metadata détaillée (mode, durée, actions)
- `view_conversation_tree` - Hiérarchie conversation en arbre
- `get_raw_conversation` - Lire JSON brut d'une conversation
- `task_export` - Export markdown + debug parsing

**Recherche (2):** `roosync_search` (texte + sémantique), `roosync_indexing` (Qdrant)

**Export (2):** `export_data` (JSON/CSV/XML), `export_config`

**MCP Management (5):** `storage_info`, `maintenance`, `manage_mcp_settings`, `rebuild_and_restart_mcp`, `get_mcp_best_practices`, `touch_mcp_settings`

### Fichier Partagé

**Chemin:** `G:/Mon Drive/Synchronisation/RooSync/.shared-state/`

### ⛔ RÈGLE ABSOLUE : État Partagé = GDrive UNIQUEMENT

**L'état partagé RooSync NE DOIT JAMAIS être dans le dépôt Git.**

| ❌ INTERDIT | ✅ CORRECT |
|-------------|------------|
| `roo-config/shared-state/` | `$env:ROOSYNC_SHARED_PATH` (GDrive) |
| `roo-config/inventories/` | `$env:ROOSYNC_SHARED_PATH/inventories/` |
| `roo-config/dashboards/` | `$env:ROOSYNC_SHARED_PATH/dashboards/` |
| Tout chemin local dans le dépôt | Chemin Google Drive via .env |

**Si vous voyez des fichiers `shared-state`, `inventories`, ou `dashboards` dans le dépôt Git :**
1. C'est une **ERREUR** - supprimez-les immédiatement
2. Corrigez le code qui les a créés
3. Vérifiez que `ROOSYNC_SHARED_PATH` est bien configuré dans `.env`

**Raison :** L'état partagé doit être synchronisé entre les 5 machines via Google Drive, pas versionné dans Git.

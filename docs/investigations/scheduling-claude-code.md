# Investigation: Scheduling Claude Code

**Issue:** #403
**Date:** 2026-02-07
**Investigateur:** Claude Code (myia-ai-01)

---

## Résumé Exécutif

L'investigation révèle **plusieurs solutions matures** pour l'exécution planifiée de Claude Code. La communauté a développé des outils robustes, et Anthropic a récemment ajouté des fonctionnalités natives (Tasks, Hooks) qui facilitent l'automatisation.

**Recommandation:** Adopter une approche hybride combinant :
1. **Cron + scripts wrapper** pour le déclenchement planifié
2. **Ralph Wiggum technique** pour les boucles autonomes
3. **Git worktrees** pour l'isolation des changements

---

## Solutions Identifiées

### 1. Cron Integration (Basic)

**Sources:**
- [Claude Code × Cron Complete Automation Guide](https://smartscope.blog/en/generative-ai/claude/claude-code-cron-automation-guide/)
- [Claude Code Autonomous & Scheduling Complete Guide](https://smartscope.blog/en/generative-ai/claude/claude-code-autonomous-scheduling-complete-guide/)

**Principe:**
```bash
# Exemple crontab
0 9 * * 1-5 cd /path/to/repo && claude --dangerously-skip-permissions -p "Run daily code review"
```

**Avantages:**
- Simple à mettre en place
- Fonctionne sur Linux/macOS
- Intégration avec systemd/launchd possible

**Inconvénients:**
- `--dangerously-skip-permissions` requis pour l'autonomie
- Pas de gestion d'état entre exécutions
- Risque de conflits Git si plusieurs machines

---

### 2. runCLAUDErun (macOS Native)

**Source:** [runCLAUDErun](https://runclauderun.com/)

**Description:**
Application macOS native qui permet de planifier et automatiser les tâches Claude Code sans configuration manuelle de cron.

**Avantages:**
- Interface graphique
- Gestion des permissions simplifiée
- Logs et historique

**Inconvénients:**
- macOS uniquement
- Pas open source (vérifier)
- Pas adapté au multi-machines

---

### 3. claude-code-scheduler (GitHub)

**Source:** [jshchnz/claude-code-scheduler](https://github.com/jshchnz/claude-code-scheduler)

**Description:**
"Put Claude on autopilot" - Scheduler open source pour Claude Code.

**À investiguer:**
- Architecture et fonctionnalités
- Compatibilité Windows
- Intégration avec RooSync possible?

---

### 4. GitHub Actions Scheduled Workflows

**Source:** [Complete Guide to Claude Code Scheduled Execution](https://smartscope.blog/en/generative-ai/claude/claude-code-scheduled-automation-guide/)

**Principe:**
```yaml
on:
  schedule:
    - cron: '0 9 * * 1-5'  # Weekdays at 9 AM

jobs:
  claude-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: claude --dangerously-skip-permissions -p "Review PR changes"
```

**Avantages:**
- Centralisé (pas besoin de configurer chaque machine)
- Logs et artifacts intégrés
- Gratuit pour projets publics

**Inconvénients:**
- Coût pour projets privés avec gros volume
- Latence (queue GitHub Actions)
- Pas d'accès aux ressources locales

---

### 5. Ralph Wiggum Technique (Boucles Autonomes)

**Sources:**
- [The Ralph Wiggum Technique: Run Claude Code Autonomously for Hours](https://www.atcyrus.com/stories/ralph-wiggum-technique-claude-code-autonomous-loops)
- [ralph-claude-code GitHub](https://github.com/frankbria/ralph-claude-code)
- [Ralph Wiggum - Awesome Claude](https://awesomeclaude.ai/ralph-wiggum)

**Description:**
Plugin officiel Anthropic qui permet des boucles de développement autonomes. Au lieu de s'arrêter après une tentative, Ralph fait itérer Claude jusqu'à succès.

**Caractéristiques:**
- Boucle: gather context → take action → verify work → repeat
- Détection intelligente de sortie (évite boucles infinites)
- Limites API intégrées

**Très pertinent pour VibeSync !** Permet à chaque machine de travailler de façon autonome sur sa tâche assignée.

---

### 6. claude-mcp-scheduler

**Source:** [tonybentley/claude-mcp-scheduler](https://github.com/tonybentley/claude-mcp-scheduler)

**Description:**
Utilise l'API Claude pour prompter des agents distants sur un intervalle cron, mais utilise des MCPs locaux pour les appels d'outils.

**Architecture:**
```
┌─────────────────┐     cron     ┌─────────────────┐
│  Scheduler      │────────────►│  Claude API     │
│  (central)      │              │  (remote)       │
└─────────────────┘              └────────┬────────┘
                                          │
                                          ▼
                                 ┌─────────────────┐
                                 │  Local MCPs     │
                                 │  (tool calls)   │
                                 └─────────────────┘
```

**Intéressant pour VibeSync:** Architecture similaire à notre coordinateur/exécutants.

---

### 7. Fonctionnalités Natives Anthropic

**Sources:**
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Claude Code Tasks Update](https://venturebeat.com/orchestration/claude-codes-tasks-update-lets-agents-work-longer-and-coordinate-across)

**Nouveautés récentes:**

#### Hooks
```javascript
// .claude/hooks.json
{
  "afterCodeChange": ["npm test"],
  "beforeCommit": ["npm run lint"]
}
```
Déclenchent des actions automatiques à des points spécifiques.

#### Tasks (DAG)
Nouvelle abstraction pour coordonner le travail entre sessions et subagents :
- Supporte les graphes acycliques dirigés (DAG)
- Une tâche peut bloquer une autre
- Détermination automatique des dépendances

**Exemple:**
```
Task 3 (Run Tests) blocked_by:
  - Task 1 (Build API)
  - Task 2 (Configure Auth)
```

---

## Analyse Comparative

| Solution | Setup | Multi-machine | Autonomie | Coût | Maturité |
|----------|-------|---------------|-----------|------|----------|
| Cron | Facile | ❌ Manuel | ✅ | Gratuit | ⭐⭐⭐ |
| runCLAUDErun | Facile | ❌ | ✅ | ? | ⭐⭐ |
| claude-code-scheduler | Moyen | ✅ ? | ✅ | Gratuit | ⭐⭐ |
| GitHub Actions | Moyen | ✅ | ✅ | $/temps | ⭐⭐⭐ |
| Ralph Wiggum | Facile | ✅ | ⭐⭐⭐ | Gratuit | ⭐⭐⭐ |
| claude-mcp-scheduler | Complexe | ✅ | ✅ | Gratuit | ⭐ |
| Hooks/Tasks natifs | Facile | ✅ | ⭐⭐ | Gratuit | ⭐⭐⭐ |

---

## Recommandation pour VibeSync

### Architecture Proposée

```
┌────────────────────────────────────────────────────────────┐
│                    myia-ai-01 (Coordinateur)               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │ Cron/Task    │  │ RooSync      │  │ GitHub Actions   │ │
│  │ Scheduler    │  │ Message Hub  │  │ (webhook)        │ │
│  └──────────────┘  └──────────────┘  └──────────────────┘ │
└────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ myia-po-2023   │  │ myia-po-2024   │  │ myia-web1      │
│                │  │                │  │                │
│ Ralph Wiggum   │  │ Ralph Wiggum   │  │ Ralph Wiggum   │
│ Loop           │  │ Loop           │  │ Loop           │
│                │  │                │  │                │
│ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │
│ │ Worktree   │ │  │ │ Worktree   │ │  │ │ Worktree   │ │
│ │ Isolation  │ │  │ │ Isolation  │ │  │ │ Isolation  │ │
│ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │
└────────────────┘  └────────────────┘  └────────────────┘
```

### Implémentation en 3 phases

#### Phase 1: Scripts de base (1-2 jours)
1. Créer `scripts/scheduling/start-claude-worker.ps1`
   - Récupère tâche assignée via RooSync
   - Lance Claude avec `--dangerously-skip-permissions`
   - Worktree pour isolation

2. Créer `scripts/scheduling/sync-tour-scheduled.ps1`
   - Version automatisée du sync-tour
   - Lancé par cron/Task Scheduler

#### Phase 2: Ralph Wiggum (2-3 jours)
1. Installer/configurer Ralph Wiggum sur chaque machine
2. Intégrer avec RooSync pour reporting
3. Tester boucles autonomes sur CONS tasks

#### Phase 3: Coordinateur Central (1 semaine)
1. GitHub Actions pour trigger centralisé
2. Webhook sur push → déclenche distribution
3. Dashboard de monitoring (optional)

---

## Prochaines Étapes

1. **Immédiat:** Tester Ralph Wiggum sur myia-ai-01
2. **Court terme:** Créer scripts Phase 1
3. **Moyen terme:** Déployer sur toutes les machines

---

## Références

- [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [GitHub: anthropics/claude-code issues](https://github.com/anthropics/claude-code/issues/4785)
- [Ralph Wiggum Technique](https://www.atcyrus.com/stories/ralph-wiggum-technique-claude-code-autonomous-loops)
- [claude-code-scheduler](https://github.com/jshchnz/claude-code-scheduler)
- [claude-mcp-scheduler](https://github.com/tonybentley/claude-mcp-scheduler)
- [runCLAUDErun](https://runclauderun.com/)

# .roo/ — Configuration Roo Code

Ce répertoire contient toute la configuration de l'extension **Roo Code** pour le projet roo-extensions.

> **Note :** Ces fichiers configurent Roo Code uniquement. La configuration de Claude Code est dans `.claude/`.

---

## Structure

```
.roo/
├── README.md                          # Ce fichier
├── mcp.json                           # Overrides MCP spécifiques au projet
├── schedules.json                     # Config scheduler (machine-spécifique, gitignored*)
├── schedules.template.json            # Template scheduler (source commune)
├── scheduler-workflow.md              # Vue d'ensemble des schedulers (référence)
├── scheduler-workflow-executor.md     # Workflow exécutant (6h, toutes machines)
├── scheduler-workflow-coordinator.md  # Workflow coordinateur (6-12h, myia-ai-01 only)
├── scheduler-workflow-meta-analyst.md # Workflow méta-analyste (72h, toutes machines)
├── rules/                             # Règles auto-chargées par Roo
│   ├── 01-general.md                  # Règles générales
│   ├── 02-dashboard.md                # Dashboard RooSync (canal principal)
│   ├── 03-mcp-usage.md                # Règles MCP
│   ├── 04-sddd-grounding.md           # Protocole triple grounding SDDD
│   ├── 05-tool-availability.md        # STOP & REPAIR (outils critiques)
│   ├── 07-orchestrator-delegation.md  # Contraintes orchestrateurs (groups: [])
│   ├── 08-file-writing.md             # Règles écriture fichiers
│   ├── 09-github-checklists.md        # Checklists GitHub obligatoires
│   ├── 10-ci-guardrails.md            # Garde-fous CI
│   ├── 11-incident-history.md         # Historique incidents
│   ├── 12-machine-constraints.md      # Contraintes par machine
│   ├── 13-test-success-rates.md       # Taux de succès tests
│   ├── 14-tdd-recommended.md          # TDD recommandé
│   ├── 15-coordinator-responsibilities.md # Rôle coordinateur
│   ├── 16-no-tools-warnings.md        # Avertissements outils manquants
│   ├── 17-friction-protocol.md        # Protocole de friction
│   ├── 18-meta-analysis.md            # Protocole méta-analyse
│   ├── 19-github-cli.md               # Règles GitHub CLI
│   ├── 20-pr-mandatory.md             # PR obligatoire
│   ├── 21-skepticism-protocol.md      # Scepticisme raisonnable
│   ├── 22-validation.md               # Checklist de validation
│   └── 23-no-deletion-without-proof.md # Anti-destruction
└── rules-orchestrator/
    └── rules.md                       # Règles spécifiques aux orchestrateurs
```

> *`schedules.json` est machine-spécifique (IDs, taskInstructions, timestamps). Ne pas committer le fichier d'une machine sur la branche d'une autre.

---

## Fichiers Clés

### mcp.json — Configuration MCP Projet

Contient les **overrides** MCP spécifiques au projet (pas la config globale).

**ATTENTION :** La configuration MCP globale Roo est dans :
```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```

Ne pas confondre ces deux fichiers. [Voir docs/mcp-configuration.md](../docs/mcp-configuration.md).

### schedules.json — Config Scheduler

Fichier de configuration du scheduler Roo par machine. Contient :
- **Executor** (6h) : Tâches régulières de développement
- **Meta-Analyste** (72h) : Analyse des harnais

Déployé via `roo-config/scheduler/scripts/install/deploy-scheduler.ps1`.

**Template :** `schedules.template.json` (source générique multi-machines)

### scheduler-workflow-*.md — Workflows

Les fichiers workflow contiennent les instructions complètes pour chaque type de scheduler :
- **executor** : Workflow standard pour toutes les machines
- **coordinator** : Workflow de coordination (myia-ai-01 uniquement)
- **meta-analyst** : Workflow d'analyse croisée des harnais

### rules/ — Règles Auto-Chargées

Les fichiers dans `rules/` sont chargés automatiquement par Roo Code dans le contexte de chaque conversation. Ils définissent les comportements et procédures obligatoires.

**CRITIQUE — rules/07-orchestrator-delegation.md :** Les modes `orchestrator-*` n'ont AUCUN outil direct (`groups: []`). Ils délèguent TOUT via `new_task`.

---

## Correspondance Roo ↔ Claude Code

| Roo (`.roo/`) | Claude Code (`.claude/`) |
|---------------|--------------------------|
| `rules/*.md` (auto-chargées) | `rules/*.md` (auto-chargées) |
| `mcp.json` (overrides projet) | `~/.claude.json` (config globale) |
| `schedules.json` (scheduler) | `schtasks` Windows (scheduler) |
| `scheduler-workflow-*.md` | `commands/executor.md` |

---

## Références

- [docs/scheduler-workflow.md](../docs/scheduler-workflow.md) — Vue d'ensemble 3 tiers × 2 agents
- [docs/mcp-configuration.md](../docs/mcp-configuration.md) — Configuration MCP win-cli/roo-state-manager
- [docs/harness/reference/intercom-deprecation.md](../docs/harness/reference/intercom-deprecation.md) — Dépréciation INTERCOM (méta-auditeurs)
- [CLAUDE.md](../CLAUDE.md) — Guide principal Claude Code
- [.claude/rules/](../.claude/rules/) — Règles équivalentes côté Claude Code

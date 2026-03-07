---
name: Harness Change
about: Modifies agent infrastructure (rules, workflows, modes, MCPs, schedulers)
title: "[HARNESS] "
labels: ["harness-change", "needs-deployment-checklist"]
assignees: []
---

## Description

<!-- Describe the harness change and why it's needed -->

## Type de changement

- [ ] Rules (`.claude/rules/`)
- [ ] Modes (`.roomodes`, `roo-config/modes/`)
- [ ] Workflows (`.roo/scheduler-workflow-*.md`)
- [ ] MCP Configuration (`mcp_settings.json`, `.roo/mcp.json`)
- [ ] Scheduler (`.roo/schedules.json`)
- [ ] Commands/Skills (`.claude/commands/`, `.claude/skills/`)
- [ ] Other: <!-- specify -->

## Fichiers modifiés

<!-- List files that will be changed -->

## Checklist de déploiement

**OBLIGATOIRE** pour tout changement touchant plusieurs machines.

| Machine | Fichier modifié | Validé | Commit |
|---------|-----------------|--------|--------|
| myia-ai-01 | | ⬜ | |
| myia-po-2023 | | ⬜ | |
| myia-po-2024 | | ⬜ | |
| myia-po-2025 | | ⬜ | |
| myia-po-2026 | | ⬜ | |
| myia-web1 | | ⬜ | |

### Instructions de déploiement

<!-- How should this be deployed to other machines? -->

1.
2.
3.

## Tests de validation

- [ ] Build TypeScript passe (`npm run build`)
- [ ] Tests unitaires passent (`npx vitest run`)
- [ ] Test manuel effectué:

## Références

- Related #

# Historique des Incidents

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #713 (basé sur .roo/rules/11-incident-history.md)

---

## Incidents MCP Récents

| Date | Machine | Problème | Impact | Root Cause |
|------|---------|----------|--------|------------|
| 2026-02-21 | myia-web1 | win-cli absent après modes fix | Scheduler Roo bloqué | Pas de vérification cross-machine après b91a841c |
| 2026-02-21 | myia-ai-01 | Contexte explose (--coverage) | Scheduler bloqué 5h | Output non limité, pas de garde-fou |
| 2026-02-21 | myia-po-2023 | Boucle condensation infinie | Scheduler bloqué | Seuil condensation + INTERCOM saturé |
| 2026-03-05 | myia-po-2026 | roo-state-manager absent (Claude Code) | Session dégradée, pas de RooSync | Config MCP séparée Claude Code vs Roo non documentée |
| 2026-03-06 | myia-ai-01 | 31+ outils roosync_* absents (Claude Code) | Issue #569 impossible (0/26 tests exécutables) | Config MCP Claude Code expose seulement 5 outils management |
| 2026-03-10 | myia-po-2024 | Retrait mocks jest.setup.js sans vérifier tests | 31 fichiers cassés, CI rouge | Validation CI non effectuée avant push submodule |
| 2026-03-13 | myia-po-2025 | schedules.json écrasé par autre machine | Scheduler Roo avec mauvaise config | Fichier machine-spécifique commité sur branche partagée |

---

## Leçons Apprises

### 1. Vérification Cross-Machine Obligatoire

Après toute modification de configuration (modes, MCPs, workflows), TOUJOURS vérifier sur TOUTES les machines. Ne pas supposer que le déploiement est homogène.

### 2. Stop & Repair Sans Exception

Si un outil critique est absent (roo-state-manager, win-cli pour Roo), **ARRÊTER tout travail immédiatement**. Pas de mode dégradé, pas de contournement.

**Référence :** [`.claude/rules/tool-availability.md`](tool-availability.md)

### 3. Séparation Config MCP Claude Code vs Roo

Les deux agents ont des configs MCP **indépendantes** :
- Claude Code : `~/.claude.json` (section `mcpServers`)
- Roo : `%APPDATA%/.../mcp_settings.json` (GLOBAL)

Un MCP actif pour l'un n'est pas nécessairement actif pour l'autre.

### 4. Validation CI Avant Push Submodule

Toujours exécuter `npx vitest run --config vitest.config.ci.ts` avant tout push dans `mcps/internal`. Un test qui passe en local peut casser le CI.

**Référence :** [`.claude/rules/ci-guardrails.md`](ci-guardrails.md)

### 5. Fichiers Machine-Spécifiques

Le fichier `.roo/schedules.json` est machine-spécifique. Ne pas le committer sur une branche partagée sauf si c'est la version de sa propre machine.

### 6. Seuil de Condensation GLM

Les modèles GLM annoncent 200k tokens mais la réalité est ~131k. Utiliser le seuil **70%** (pas 50%) pour éviter les boucles infinies de condensation.

**Référence :** [`.claude/rules/condensation-thresholds.md`](condensation-thresholds.md)

---

## Incidents Récurrents à Surveiller

| Pattern | Signal d'alarme | Action |
|---------|-----------------|--------|
| Boucle condensation | INTERCOM croît > 1000 lignes | Condenser immédiatement |
| Scheduler idle malgré issues | Cycles sans tâche exécutée | Vérifier labels + Project #67 |
| Submodule divergent | `git submodule status` montre `+` | Réaligner avant commit parent |
| CI rouge après push | GitHub Actions failures | Investiguer, ne pas push over |

---

## Référence

- Documentation MCP : [`.claude/rules/tool-availability.md`](tool-availability.md)
- Protocole CI : [`.claude/rules/ci-guardrails.md`](ci-guardrails.md)
- Condensation GLM : [`.claude/rules/condensation-thresholds.md`](condensation-thresholds.md)
- Équivalent Roo : `.roo/rules/11-incident-history.md`

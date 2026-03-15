# Historique des Incidents

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #710

---

## Incidents MCP Récents

| Date | Machine | Problème | Impact | Root Cause |
|------|---------|----------|--------|------------|
| 2026-02-21 | myia-web1 | win-cli absent après modes fix | Scheduler bloqué | Pas de vérification cross-machine après b91a841c |
| 2026-02-21 | myia-ai-01 | Contexte explose (--coverage) | Scheduler bloqué 5h | Output non limité, pas de garde-fou |
| 2026-02-21 | myia-po-2023 | Boucle condensation infinie | Scheduler bloqué | Seuil condensation + INTERCOM saturé |
| 2026-03-05 | myia-po-2026 | roo-state-manager absent (Claude Code) | Session dégradée, pas de RooSync | Config MCP séparée Claude Code vs Roo non documentée |
| 2026-03-06 | myia-ai-01 | 31+ outils roosync_* absents (Claude Code) | Issue #569 impossible (0/26 tests exécutables) | Config MCP Claude Code expose seulement 5 outils management, pas les outils opérationnels |

---

## Leçons Apprises

### 1. Vérification Cross-Machine

Après toute modification de configuration (modes, MCPs), TOUJOURS vérifier sur TOUTES les machines.

### 2. Stop & Repair

Si un outil critique est absent, ARRETER tout travail immédiatement. Pas de mode dégradé.

### 3. Documentation Config

La configuration MCP est SÉPARÉE entre Roo et Claude Code. Documenter explicitement.

### 4. Tests Locaux Avant Déploiement

Valider les changements sur une machine AVANT de déployer globalement.

---

## Référence

Documentation complète : [`.claude/rules/tool-availability.md`](../../.claude/rules/tool-availability.md)

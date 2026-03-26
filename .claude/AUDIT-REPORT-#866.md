# Audit Report: .claude/ Directory Consolidation
**Issue:** #866 - [FRICTION] Consolidation du répertoire .claude/ - scripts et règles
**Date:** 2026-03-26
**Machine:** myia-po-2026
**Agent:** Claude Code (interactive)

---

## Executive Summary

Le répertoire `.claude/` contient un mélange de:
- **Configuration harnais** (rules/, agents/, skills/, commands/) - DOIT rester
- **Scripts utilitaires** (scripts/) - DEVRAIT être dans `scripts/`
- **Documentation** (docs/, memory/, modes/) - DOIT rester
- **Templates de déploiement** (configs/) - DOIT rester
- **Fichiers de suivi** (feedback/, proposals/, worktrees/) - À évaluer

**Recommandation principale:** Déplacer `.claude/scripts/` vers `scripts/claude/` pour réduire les frictions d'autorisation fichier.

---

## 1. Inventaire Actuel de `.claude/`

### 1.1 Contenu qui DOIT rester dans `.claude/`

| Répertoire | Raison | Statut |
|-----------|---------|--------|
| `rules/` | Règles auto-chargées pour Claude Code | **CONSERVER** |
| `agents/` | Sub-agents Claude Code (project-specific) | **CONSERVER** |
| `commands/` | Slash commands Claude Code | **CONSERVER** |
| `docs/` | Documentation de référence on-demand | **CONSERVER** |
| `memory/` | Mémoire partagée du projet | **CONSERVER** |
| `modes/` | Configuration des modes Roo | **CONSERVER** |
| `settings.json` | Permissions partagées git-tracked | **CONSERVER** |
| `configs/` | Templates pour déploiement global | **CONSERVER** |

### 1.2 Contenu qui DEVRAIT être déplacé

| Répertoire | Destination proposée | Raison |
|-----------|---------------------|--------|
| `scripts/` | `scripts/claude/` + `scripts/worktrees/` + `scripts/mcp/` | Scripts utilitaires, pas de configuration harnais |
| `worktrees/` | `scripts/worktrees/` (existe déjà) | Worktree management scripts |
| `feedback/` | `docs/feedback/` | Documentation de feedback |
| `proposals/` | `docs/proposals/` ou `archive/` | Propositions non implémentées |
| `local/` | (gitignore déjà) | Communication locale dépréciée |
| `bootstrap-checklist.md` | `docs/setup/` | Documentation setup |

### 1.3 Scripts dans `.claude/scripts/`

| Script | Usage | Destination proposée |
|--------|-------|---------------------|
| `worktree-cleanup.ps1` | Nettoyage automatisé worktrees orphelins | `scripts/worktrees/worktree-cleanup.ps1` (avec cleanup-worktree.ps1) |
| `init-claude-code.ps1` | Initialisation Claude Code | `scripts/claude/init-claude-code.ps1` (nouveau répertoire) |
| `Switch-Provider.ps1` | Switch LLM provider | `scripts/claude/switch-provider.ps1` (nouveau répertoire) |
| `Deploy-ProviderSwitcher.ps1` | Déploiement switcher | `scripts/claude/deploy-provider-switcher.ps1` (nouveau répertoire) |
| `Switch-MCPConfig.ps1` | Debug config MCP | `scripts/mcp/switch-mcp-config.ps1` |

---

## 2. Analyse des Frictions

### 2.1 Problème d'autorisation fichier

**Symptôme:** Chaque exécution d'un script dans `.claude/scripts/` nécessite une autorisation fichier dans VS Code.

**Cause:** VS Code traite `.claude/` comme un répertoire de configuration harnais, pas comme un répertoire de scripts exécutables.

**Impact:**
- Friction utilisateur à chaque exécution
- Interruption du workflow automatisé
- Expérience dégradée pour les scripts fréquents (worktree-cleanup)

### 2.2 Scripts déjà dans `scripts/worktrees/`

Il existe déjà un répertoire `scripts/worktrees/` avec:
- `cleanup-worktree.ps1`
- `create-worktree.ps1`
- `submit-pr.ps1`

Le script `.claude/scripts/worktree-cleanup.ps1` a un objectif similaire à `cleanup-worktree.ps1`. **Attention aux duplications.**

---

## 3. Proposition de Consolidation

### 3.1 Structure recommandée après consolidation

```
.claude/
├── rules/              (CONSERVER - 10+ fichiers auto-chargés)
├── agents/             (CONSERVER - sub-agents)
├── commands/           (CONSERVER - slash commands)
├── docs/               (CONSERVER - documentation on-demand)
├── memory/             (CONSERVER - mémoire partagée)
├── modes/              (CONSERVER - config Roo)
├── configs/            (CONSERVER - templates déploiement)
│   └── scripts/        (CONSERVER - scripts de déploiement harnais)
├── settings.json       (CONSERVER - permissions partagées)
├── local/              (gitignore - fallback INTERCOM)
└── README.md           (CONSERVER - index)

scripts/
├── claude/             (NOUVEAU - scripts spécifiques Claude Code)
│   ├── init-claude-code.ps1
│   ├── switch-provider.ps1
│   └── deploy-provider-switcher.ps1
├── worktrees/          (EXISTANT - scripts worktrees)
│   ├── cleanup-worktree.ps1
│   ├── create-worktree.ps1
│   ├── submit-pr.ps1
│   └── worktree-cleanup.ps1  (DÉPLACÉ depuis .claude/scripts/)
├── mcp/                (EXISTANT + AJOUT)
│   └── switch-mcp-config.ps1  (DÉPLACÉ depuis .claude/scripts/)
├── setup/              (EXISTANT - scripts setup)
└── [... autres sous-répertoires ...]
```

### 3.2 Mapping des déplacements

| Source | Destination | Action |
|--------|-------------|--------|
| `.claude/scripts/worktree-cleanup.ps1` | `scripts/worktrees/worktree-cleanup.ps1` | Déplacer (regrouper avec cleanup-worktree.ps1) |
| `.claude/scripts/init-claude-code.ps1` | `scripts/claude/init-claude-code.ps1` | Déplacer (nouveau répertoire dédié) |
| `.claude/scripts/Switch-Provider.ps1` | `scripts/claude/switch-provider.ps1` | Déplacer + renommer (nouveau répertoire dédié) |
| `.claude/scripts/Deploy-ProviderSwitcher.ps1` | `scripts/claude/deploy-provider-switcher.ps1` | Déplacer + renommer (nouveau répertoire dédié) |
| `.claude/scripts/Switch-MCPConfig.ps1` | `scripts/mcp/switch-mcp-config.ps1` | Déplacer (regrouper avec scripts MCP existants) |
| `.claude/worktrees/` | (déjà dans `scripts/worktrees/`) | Fusionner/audit |
| `.claude/feedback/` | `docs/feedback/` | Déplacer |
| `.claude/proposals/` | `docs/proposals/` ou `archive/proposals/` | Déplacer |
| `.claude/bootstrap-checklist.md` | `docs/setup/bootstrap-checklist.md` | Déplacer |

---

## 4. Plan d'Action

### Phase 1: Audit et validation (DONE)
- [x] Inventaire complet de `.claude/`
- [x] Identification des scripts à déplacer
- [x] Vérification des destinations existantes
- [x] Analyse des frictions

### Phase 2: Préparation
- [ ] Créer `scripts/claude/` si nécessaire
- [ ] Documenter les dépendances entre scripts
- [ ] Vérifier les références aux scripts dans la doc

### Phase 3: Migration
- [ ] Déplacer les scripts `.claude/scripts/` → `scripts/claude/`
- [ ] Fusionner `.claude/worktrees/` avec `scripts/worktrees/`
- [ ] Déplacer `.claude/feedback/` → `docs/feedback/`
- [ ] Déplacer `.claude/proposals/` → `docs/proposals/`

### Phase 4: Mise à jour documentation
- [ ] Mettre à jour les références aux scripts déplacés
- [ ] Mettre à jour `.claude/README.md`
- [ ] Mettre à jour `scripts/README.md`
- [ ] Créer `scripts/claude/README.md`

### Phase 5: Validation
- [ ] Tester les scripts dans leur nouvel emplacement
- [ ] Vérifier que les frictions d'autorisation sont résolues
- [ ] Confirmer que rien n'est cassé

---

## 5. Risques et Mitigations

### Risque 1: Références brisées
**Mitigation:** Recherche grep des chemins `.claude/scripts/` avant déplacement

### Risque 2: Scripts worktrees en double
**Mitigation:** Audit comparatif de `cleanup-worktree.ps1` vs `worktree-cleanup.ps1` avant fusion

### Risque 3: Dépendances cachées
**Mitigation:** Recherche des imports/requires dans les scripts

---

## 6. Recommandations Additionnelles

### 6.1 Règle de gouvernance

**Proposition:** `.claude/` ne doit contenir que:
1. Configuration harnais (rules/, agents/, commands/)
2. Documentation harnais (docs/, README.md)
3. État partagé (memory/, modes/, settings.json)
4. Templates de déploiement (configs/)

**Tout script exécutable** doit être dans `scripts/`.

### 6.2 Scripts utilitaires vs harnais

- **Scripts utilitaires:** `scripts/` (ex: cleanup, setup, deploy)
- **Scripts harnais:** `.claude/configs/scripts/` (ex: Deploy-GlobalConfig.ps1)

La distinction: les scripts harnais déploient la configuration, les scripts utilitaires effectuent des tâches.

---

## 7. Next Steps

1. **Validation croisée:** Demander à d'autres machines de valider l'audit
2. **Discussion GitHub:** Présenter ce rapport dans l'issue #866
3. **Approbation:** Attendre le feu vert avant migration
4. **Exécution:** Suivre le plan d'action phase par phase

---

## Annexes

### A. Scripts à migrer avec dépendances

| Script | Dépendances | Impact |
|--------|-------------|--------|
| `worktree-cleanup.ps1` | Git worktree CLI | Bas |
| `init-claude-code.ps1` | Templates `.claude/configs/` | Moyen |
| `Switch-Provider.ps1` | `~/.claude/settings.json` | Bas |
| `Deploy-ProviderSwitcher.ps1` | Templates dans `.claude/configs/` | Moyen |
| `Switch-MCPConfig.ps1` | `~/.claude.json` | Bas |

### B. Références croisées à vérifier (GREP DONE)

**Références trouvées pour `.claude/scripts/`:**

| Fichier | Référence | Action requise |
|---------|-----------|----------------|
| `.claude/rules/worktree-cleanup.md` | `.claude/scripts/worktree-cleanup.ps1` (x5) | **MAJ** vers `scripts/claude/worktree-cleanup.ps1` |
| `.claude/MCP_SETUP.md` | `.claude/scripts/init-claude-code.ps1` (x5) | **MAJ** vers `scripts/claude/init-claude-code.ps1` |
| `CLAUDE.md` | `.claude/scripts/init-claude-code.ps1` | **MAJ** vers `scripts/claude/init-claude-code.ps1` |
| `.claude/commands/switch-provider.md` | `$HOME/.claude/scripts/Switch-Provider.ps1` | **MAJ** vers `scripts/claude/switch-provider.ps1` |
| `docs/roosync/guides/TROUBLESHOOTING.md` | `.claude/scripts/init-claude-code.ps1` | **MAJ** vers `scripts/claude/init-claude-code.ps1` |
| `docs/roosync/guides/ONBOARDING_AGENT.md` | `.claude/scripts/init-claude-code.ps1` (x2) | **MAJ** vers `scripts/claude/init-claude-code.ps1` |
| `docs/roosync/guides/CHECKLISTS.md` | `.claude/scripts/init-claude-code.ps1` | **MAJ** vers `scripts/claude/init-claude-code.ps1` |

**Total:** 12 références à mettre à jour dans 7 fichiers

### C. Analyse comparatif: worktree-cleanup.ps1 vs cleanup-worktree.ps1

| Aspect | worktree-cleanup.ps1 | cleanup-worktree.ps1 |
|--------|---------------------|----------------------|
| **Emplacement** | `.claude/scripts/` | `scripts/worktrees/` |
| **Usage** | Nettoyage automatisé des orphelins | Nettoyage manuel après PR merge |
| **Paramètre** | `-WhatIf`, `-Force`, `-StaleDays` | `-IssueNumber`, `-KeepRemote` |
| **Cible** | TOUS les worktrees orphelins | UN worktree spécifique |
| **Automatisation** | Oui (cron/manual) | Non (manuel après chaque PR) |

**Conclusion:** Les deux scripts sont **complémentaires**, pas dupliqués. `worktree-cleanup.ps1` fait du nettoyage en masse, `cleanup-worktree.ps1` fait du nettoyage unitaire.

**Recommandation:** Conserver les deux scripts, mais déplacer `worktree-cleanup.ps1` vers `scripts/worktrees/` pour regrouper la logique worktree au même endroit.

---

**Signé:** Claude Code (myia-po-2026)
**Date:** 2026-03-26
**Status:** Audit terminé, en attente d'approbation pour Phase 2-5

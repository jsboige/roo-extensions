# RooSync Checklists Opérationnelles

**Version:** 1.0.0
**Date:** 2026-01-15
**Auteur:** Claude Code (myia-web1)

---

## Table des Matières

1. [Checklist Déploiement Nouvelle Machine](#1-checklist-déploiement-nouvelle-machine)
2. [Checklist Synchronisation Quotidienne](#2-checklist-synchronisation-quotidienne)
3. [Checklist Mise à Jour Baseline](#3-checklist-mise-à-jour-baseline)
4. [Checklist Rollback](#4-checklist-rollback)
5. [Checklist Résolution de Conflit](#5-checklist-résolution-de-conflit)
6. [Checklist Avant Commit](#6-checklist-avant-commit)

---

## 1. Checklist Déploiement Nouvelle Machine

**Objectif:** Configurer une nouvelle machine pour RooSync

### 1.1 Prérequis

- [ ] Windows 10/11/Server installé
- [ ] Node.js v20+ installé (`node --version`)
- [ ] Git v2.40+ installé (`git --version`)
- [ ] PowerShell 7+ installé (`$PSVersionTable`)
- [ ] VS Code installé
- [ ] Token GitHub créé (permissions: `repo`, `project`, `read:org`)
- [ ] Accès Google Drive configuré

### 1.2 Installation

- [ ] Dépôt cloné: `git clone --recurse-submodules https://github.com/jsboige/roo-extensions.git`
- [ ] Dépendances installées: `npm install`
- [ ] Submodule compilé:
  ```
  cd mcps/internal/servers/roo-state-manager
  npm install && npm run build
  ```
- [ ] Script init exécuté: `.\.claude\scripts\init-claude-code.ps1`
- [ ] Fichier `.env` créé avec `GITHUB_TOKEN` et `ROOSYNC_SHARED_PATH`

### 1.3 Validation

- [ ] VS Code redémarré
- [ ] `/mcp` affiche roo-state-manager
- [ ] `roosync_read_inbox` fonctionne
- [ ] `gh project list --owner jsboige` fonctionne

### 1.4 Communication

- [ ] Message de présentation envoyé à myia-ai-01
- [ ] Issue GitHub "[CLAUDE-{MACHINE}] Bootstrap Complete" créée
- [ ] CLAUDE.md lu complètement

---

## 2. Checklist Synchronisation Quotidienne

**Objectif:** Maintenir la machine synchronisée avec le système

### 2.1 Au Démarrage

- [ ] Pull des derniers changements: `git pull --rebase`
- [ ] Vérifier les messages RooSync: `roosync_read_inbox`
- [ ] Lire INTERCOM local: `.claude/local/INTERCOM-{MACHINE}.md`
- [ ] Consulter le projet GitHub #67

### 2.2 Pendant le Travail

- [ ] Committer régulièrement (toutes les 30-60 min si changes)
- [ ] Répondre aux messages RooSync (< 2h pour HIGH, < 30min pour URGENT)
- [ ] Mettre à jour INTERCOM après actions significatives

### 2.3 En Fin de Session

- [ ] Committer tous les changements non commités
- [ ] Pousser les commits: `git push`
- [ ] Mettre à jour INTERCOM avec bilan session
- [ ] Mettre à jour le projet GitHub si tâches complétées

---

## 3. Checklist Mise à Jour Baseline

**Objectif:** Mettre à jour la baseline de référence (Baseline Master uniquement)

### 3.1 Préparation

- [ ] Vérifier l'état actuel: `roosync_get_status`
- [ ] Lister les différences: `roosync_list_diffs`
- [ ] Analyser les changements proposés
- [ ] Documenter la raison de la mise à jour

### 3.2 Création de la Décision

- [ ] Créer une décision avec justification
- [ ] Ajouter la décision à `sync-roadmap.md`
- [ ] Notifier les agents concernés via RooSync

### 3.3 Validation

- [ ] Attendre les approbations des agents
- [ ] Vérifier qu'aucun conflit n'est signalé
- [ ] Tester en mode dryRun si possible

### 3.4 Application

- [ ] Appliquer la décision: `roosync_apply_decision`
- [ ] Vérifier le résultat: `roosync_get_status`
- [ ] Notifier les agents du résultat
- [ ] Documenter dans le changelog

---

## 4. Checklist Rollback

**Objectif:** Revenir à un état précédent après un problème

### 4.1 Évaluation

- [ ] Identifier le problème clairement
- [ ] Déterminer le point de rollback (commit, baseline, décision)
- [ ] Évaluer l'impact du rollback
- [ ] Notifier les agents concernés (URGENT si critique)

### 4.2 Exécution

- [ ] **Git rollback:**
  ```
  git log --oneline -10  # Identifier le commit cible
  git revert HEAD~N..HEAD  # Annuler les N derniers commits
  ```

- [ ] **Baseline rollback:**
  ```
  roosync_restore_baseline { "version": "VERSION_ID" }
  ```

- [ ] **Configuration rollback:**
  - Restaurer depuis backup
  - Ou réappliquer la baseline précédente

### 4.3 Validation

- [ ] Vérifier l'état après rollback: `roosync_get_status`
- [ ] Exécuter les tests: `npm test`
- [ ] Confirmer que le problème est résolu

### 4.4 Communication

- [ ] Notifier tous les agents du rollback
- [ ] Documenter la cause et la résolution
- [ ] Créer une issue GitHub si bug identifié
- [ ] Mettre à jour SUIVI_ACTIF.md

---

## 5. Checklist Résolution de Conflit

**Objectif:** Résoudre un conflit de synchronisation ou d'identité

### 5.1 Identification

- [ ] Type de conflit identifié:
  - [ ] Conflit Git (merge/rebase)
  - [ ] Conflit d'identité machine
  - [ ] Conflit de configuration
  - [ ] Conflit de décision

### 5.2 Analyse

- [ ] Source du conflit documentée
- [ ] Agents concernés identifiés
- [ ] Impact évalué (CRITICAL/HIGH/MEDIUM/LOW)

### 5.3 Résolution

**Pour conflit Git:**
- [ ] `git status` pour voir les fichiers en conflit
- [ ] Résoudre manuellement chaque fichier
- [ ] `git add` les fichiers résolus
- [ ] `git rebase --continue` ou `git merge --continue`

**Pour conflit d'identité:**
- [ ] Identifier la bonne identité: `$env:COMPUTERNAME`
- [ ] Supprimer le fichier de présence en conflit
- [ ] Redémarrer le MCP

**Pour conflit de configuration:**
- [ ] Comparer les configurations
- [ ] Décider quelle configuration garder
- [ ] Appliquer la configuration choisie
- [ ] Valider avec `roosync_get_status`

### 5.4 Validation et Communication

- [ ] Conflit résolu et testé
- [ ] Autres agents notifiés
- [ ] Documentation mise à jour
- [ ] Issue GitHub créée si bug sous-jacent

---

## 6. Checklist Avant Commit

**Objectif:** S'assurer que le commit est propre et complet

### 6.1 Vérifications Code

- [ ] Pas de `console.log` debug restants (utiliser logger)
- [ ] Pas de `throw new Error()` non typés (utiliser StateManagerError)
- [ ] Imports corrects (vérifier les chemins relatifs)
- [ ] TypeScript compile sans erreur: `npm run build`

### 6.2 Vérifications Tests

- [ ] Tests exécutés: `npm test`
- [ ] Tous les tests passent (ou échecs documentés)
- [ ] Nouveaux tests ajoutés si nouvelle fonctionnalité

### 6.3 Vérifications Documentation

- [ ] INTERCOM mis à jour si action significative
- [ ] Commentaires de code si logique complexe
- [ ] README mis à jour si nouvelle fonctionnalité publique

### 6.4 Format du Commit

- [ ] Message au format conventionnel:
  ```
  type(scope): description courte

  Corps optionnel avec détails

  Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
  ```

- [ ] Types valides: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`
- [ ] Scope valide: `roosync`, `errors`, `coord`, etc.

### 6.5 Après Commit

- [ ] Push effectué: `git push`
- [ ] Si submodule modifié:
  ```
  cd /c/dev/roo-extensions
  git add mcps/internal/servers/roo-state-manager
  git commit -m "chore: Update submodule"
  git push
  ```

---

## Quick Reference Card

### Commandes Fréquentes

| Action | Commande |
|--------|----------|
| Pull rebase | `git pull --rebase` |
| Voir status | `git status` |
| Voir logs | `git log --oneline -10` |
| Lancer tests | `npm test` |
| Compiler | `npm run build` |
| Voir inbox | `roosync_read_inbox` |
| Voir statut | `roosync_get_status` |

### Priorités Messages

| Priorité | Délai Réponse |
|----------|---------------|
| LOW | 24h |
| MEDIUM | 8h |
| HIGH | 2h |
| URGENT | 30min |

### Contacts

| Rôle | Machine |
|------|---------|
| Baseline Master | myia-ai-01 |
| Coordinateur Tech | myia-po-2024 |
| Testeur | myia-web-01 |

---

## Historique

| Date | Version | Auteur | Description |
|------|---------|--------|-------------|
| 2026-01-15 | 1.0.0 | Claude Code (myia-web1) | Création initiale |

---

**Document créé dans le cadre de T4.11**
**Référence:** T4.10 - Analyse des besoins de documentation multi-agent

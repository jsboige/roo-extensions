# Déploiement redistribute-memory v2.1

**Date:** 2026-02-19
**Issue:** #490
**Version:** 2.1.0

## Objectif

Mettre à jour le skill `redistribute-memory` sur toutes les machines pour la restructuration des connaissances.

## Prérequis

- [ ] `git pull` sur toutes les machines (commit 853259b5+)
- [ ] Vérifier que le skill existe déjà dans `.claude/configs/skills/redistribute-memory/`
- [ ] Vérifier que le fichier `SKILL.md` contient la version 2.1.0

## Instructions de déploiement

### Sur toutes les machines (exécutants)

1. **Mise à jour du skill :**
   ```bash
   git pull
   # Vérifier que le fichier existe
   ls .claude/configs/skills/redistribute-memory/SKILL.md
   # Vérifier la version
   grep "Version:" .claude/configs/skills/redistribute-memory/SKILL.md
   # Attendre : "Version: 2.1.0 (2026-02-19)"
   ```

2. **Exécuter le skill :**
   ```
   /redistribute-memory
   ```

3. **Rapport :** Envoyer le rapport multi-workspace au coordinateur (myia-ai-01) via RooSync

4. **Nettoyage local :**
   - Nettoyer `MEMORY.md` local (retirer contenu périmé)
   - Vérifier que les configs globales (`~/.claude/`) sont à jour vs templates

### Sur myia-ai-01 (coordinateur)

1. **Mise à jour du skill :** (même procédure que ci-dessus)

2. **Extraction CLAUDE.md :**
   - Extraire ~800 lignes de `CLAUDE.md` en rules (voir plan dans SKILL.md)
   - Créer les fichiers rules suivants :
     - `.claude/rules/scheduler-system.md` (~300L)
     - `.claude/rules/validation-checklist.md` (~80L)
     - `.claude/rules/agents-architecture.md` (~150L)
     - `MCP_SETUP.md` (~100L)
   - Retirer la section GitHub Projects (doublon avec .roo/rules)

3. **Nettoyage :**
   - Nettoyer `PROJECT_MEMORY.md` (métriques obsolètes)
   - Mettre à jour `~/.claude/CLAUDE.md` (user global) si contenu universel identifié

4. **Consolidation :**
   - Consolider les rapports des 5 machines
   - Vérifier la cohérence globale

5. **Déploiement :**
   - Déployer les configs globales mises à jour
   - Vérifier que toutes les machines ont bien reçu les mises à jour

## Livrables attendus

- CLAUDE.md projet < 600 lignes (objectif : 500)
- MEMORY.md < 150 lignes sur chaque machine
- Nouveaux fichiers rules créés
- Rapports multi-workspace de chaque machine
- Configs globales mises à jour

## Vérification

Après déploiement, vérifier :
- [ ] Version du skill : 2.1.0
- [ ] CLAUDE.md < 600 lignes
- [ ] MEMORY.md < 150 lignes
- [ ] Tous les fichiers rules créés
- [ ] Rapports reçus des 5 machines
- [ ] Git status clean (aucun fichier non commité)

## Rollback

Si problème détecté :
1. Annuler les changements de CLAUDE.md
2. Restaurer les anciens fichiers rules
3. Revenir à la version précédente du skill
4. Reporter le problème via INTERCOM

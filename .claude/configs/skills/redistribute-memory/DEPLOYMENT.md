# Déploiement redistribute-memory v3.0 (V2 — 5 Tiers)

**Date:** 2026-05-16
**Issue:** #2223
**Version:** 3.0.0

## Objectif

Déployer le skill `redistribute-memory` V2 (5 tiers, 6 antipatterns, dry-run par défaut) sur toutes les machines.

## Changements v2.1 → v3.0

- **5 tiers** au lieu de la hiérarchie plate précédente (T1-T5)
- **6 antipatterns** formalisés (AP1-AP6)
- **dry-run par défaut** — aucun changement sans validation user
- **T3 (rules) = sacré** — jamais modifié sans validation explicite par action
- **T5 (MEMORY.md) = préservé** — aucune suppression de leçons
- **Multi-workspace** — fonctionne sur roo-extensions, CoursIA, et tout workspace
- **Phase 0 d'auto-détection** — résout automatiquement les chemins

## Prérequis

- [ ] `git pull` sur toutes les machines
- [ ] Vérifier que le fichier `.claude/skills/redistribute-memory/SKILL.md` contient la version 3.0.0

## Instructions de déploiement

### Sur toutes les machines (exécutants)

1. **Mise à jour du skill :**
   ```bash
   git pull
   grep "Version:" .claude/skills/redistribute-memory/SKILL.md
   # Attendre : "3.0.0 (2026-05-16)"
   ```

2. **Premier passage dry-run :**
   ```
   "redistribue la mémoire"  # → dry-run, audit + plan sans exécution
   ```

3. **Valider et exécuter (si applicable) :**
   ```
   "applique ACTION-1 et ACTION-3"  # → exécute les actions validées
   ```

4. **Rapport :** Le skill poste automatiquement sur le dashboard workspace

### Sur myia-ai-01 (coordinateur)

1. Tester le skill sur **roo-extensions** ET **CoursIA** (critère d'acceptation)
2. Consolider les rapports des machines
3. Vérifier la cohérence globale

## Livrables attendus

- Skill V2 déployé (3.0.0)
- Doc de référence : `docs/harness/reference/redistribute-memory-skill.md`
- Rapport de premier passage sur ai-01 / roo-extensions (avant/après tiers)
- Rapport de premier passage sur ai-01 / CoursIA

## Vérification

Après déploiement, vérifier :
- [ ] Version du skill : 3.0.0
- [ ] 5 tiers correctement détectés sur chaque workspace
- [ ] 6 antipatterns détectés lors du dry-run
- [ ] Dry-run ne modifie aucun fichier
- [ ] T3 (rules) jamais touché sans validation user
- [ ] Doc de référence créée

## Rollback

Si problème détecté :
1. `git revert` le commit de déploiement
2. Restaurer la version 2.1.0 du skill
3. Reporter le problème via dashboard workspace

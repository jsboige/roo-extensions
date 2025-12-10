# Plan de Recyclage Stashs - 16 octobre 2025

## Vue d'Ensemble

**Total stashs analysés** : 4 sur 19  
**Stashs prioritaires à recycler** : 3  
**Stashs à investiguer** : 1  
**Stashs automatiques à vérifier** : 12  
**Durée estimée totale** : 4-6 heures

---

## Catégorisation Finale

### 🔴 À Recycler - Priorité IMMÉDIATE (3 stashs)

#### 1. Principal stash@{0} - Portabilité script diagnostic

**Status** : ✅ PRÊT À RECYCLER  
**Complexité** : Faible  
**Risque** : Minimal  
**Durée estimée** : 10 min

**Détails** :
- **Dépôt** : d:/roo-extensions (principal)
- **Fichier** : scripts/diagnostic/diag-mcps-global.ps1
- **Modifications** : 4 insertions, 2 suppressions
- **Intention** : Remplacer chemins codés en dur par chemins relatifs portables

**Changements** :
```diff
- $configFile = "d:\Dev\roo-extensions\mcp_settings.json"
+ $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..") 
+ $configFile = Join-Path $projectRoot "mcp_settings.json"

- $mcpPath = "d:\Dev\roo-extensions\mcps\internal\servers\$mcpName"
+ $mcpPath = Join-Path $projectRoot "mcps\internal\servers\$mcpName"
```

**Plan d'action** :
1. Vérifier que le fichier existe encore et n'a pas déjà ces modifications
2. Appliquer le stash : `git stash apply stash@{0}`
3. Vérifier que le script fonctionne toujours
4. Commit : `recycle(stash-0): improve diagnostic script portability`
5. Supprimer le stash : `git stash drop stash@{0}`

**Message de commit proposé** :
```
recycle(stash-0): improve diagnostic script portability

Original stash: stash@{0} from d:/roo-extensions
Date: 2025-09-15 20:17:00
Original message: "WIP on main: 86f4fe4 feat(mcps): Finalisation post-MAJ jupyter-papermill & roo-state-manager"

Changes applied:
- Replace hardcoded paths with relative paths in diagnostic script
- Use $PSScriptRoot for portable path resolution
- Improve maintainability across different environments

Files modified:
- scripts/diagnostic/diag-mcps-global.ps1

Closes: stash@{0}
```

---

#### 2. Internal stash@{0} - Améliorations tests GitHub Projects

**Status** : ✅ PRÊT À RECYCLER  
**Complexité** : Moyenne  
**Risque** : Faible (tests uniquement)  
**Durée estimée** : 20 min

**Détails** :
- **Dépôt** : mcps/internal
- **Fichier** : servers/github-projects-mcp/tests/GithubProjectsTool.test.ts
- **Modifications** : 197 insertions, 11 suppressions
- **Intention** : Améliorer la robustesse des tests E2E

**Améliorations principales** :
1. Meilleure gestion des erreurs (logs + messages détaillés)
2. Ajout de timeouts pour la synchronisation API GitHub (2000ms)
3. Récupération correcte du numéro de projet pour les tests
4. Meilleur error handling pour la création d'items

**Plan d'action** :
1. Vérifier l'état actuel du fichier de tests
2. Appliquer le stash : `cd mcps/internal && git stash apply stash@{0}`
3. Résoudre les conflits éventuels
4. Exécuter les tests si possible : `npm test`
5. Commit avec message détaillé
6. Supprimer le stash

**Message de commit proposé** :
```
recycle(stash-0): enhance github-projects E2E test reliability

Original stash: stash@{0} from mcps/internal
Date: 2025-09-14 05:15:25
Original message: "WIP on main: 616dced fix: Correction des tests post-merge"

Changes applied:
- Add detailed error logging for test item creation failures
- Implement 2-second delays for GitHub API synchronization
- Fix project number retrieval in complexity analysis tests
- Improve error messages with JSON stringification

These improvements address flaky test issues related to GitHub API
timing and make debugging easier when tests fail.

Files modified:
- servers/github-projects-mcp/tests/GithubProjectsTool.test.ts

Closes: stash@{0} (mcps/internal)
```

---

#### 3. Internal stash@{3} - Documentation & fixes quickfiles post-ESM

**Status** : ⚠️ PRÊT AVEC PRÉCAUTION  
**Complexité** : Haute  
**Risque** : Moyen (branche différente)  
**Durée estimée** : 45 min

**Détails** :
- **Dépôt** : mcps/internal
- **Branch** : ⚠️ local-integration-internal-mcps (différente de main!)
- **Fichiers** : 3 fichiers (README, index.ts, test script)
- **Modifications** : 459 insertions, 110 suppressions
- **Intention** : Documentation post-migration ESM + corrections fonctionnelles

**Modifications principales** :
1. README.md : Documentation complète post-migration ESM (88+ lignes)
2. src/index.ts : Corrections code (205+ lignes)
3. test-quickfiles-simple.js : Améliorations tests (276 lignes modifiées)

**⚠️ PRÉCAUTIONS** :
- Stash sur une branche différente (local-integration-internal-mcps)
- Vérifier si cette branche existe encore
- Vérifier si le contenu a déjà été mergé sur main
- Risque de conflits importants

**Plan d'action** :
1. **INVESTIGUER D'ABORD** :
   - Vérifier si branche local-integration-internal-mcps existe : `git branch -a | grep local-integration`
   - Comparer avec l'état actuel de main : `git log --oneline --grep="ESM"`
   - Vérifier si README a déjà la documentation ESM

2. **Si non mergé** :
   - Créer une branche de travail : `git checkout -b recyc

le-stash3-quickfiles-esm`
   - Appliquer le stash : `git stash apply stash@{3}`
   - Résoudre les conflits
   - Tester : `npm run build && node test-quickfiles-simple.js`
   - Commit et créer PR si nécessaire

3. **Si déjà mergé** :
   - Vérifier quelles parties manquent
   - Recycler seulement les parties non mergées
   - Ou marquer comme obsolète

**Message de commit proposé** :
```
recycle(stash-3): document quickfiles ESM migration and add fixes

Original stash: stash@{3} from mcps/internal
Date: 2025-08-21 11:50:53
Branch: local-integration-internal-mcps
Original message: "WIP: fix(quickfiles): repair build and functionality after ESM migration"

Changes applied:
- Add comprehensive README documentation for ESM architecture
- Document build process, configuration, and testing procedures
- Include fixes for post-ESM migration issues in source code
- Enhance test script with better error handling

This stash contains important documentation and fixes from the
ESM migration work that may not have been fully merged to main.

Files modified:
- servers/quickfiles-server/README.md (documentation)
- servers/quickfiles-server/src/index.ts (fixes)
- servers/quickfiles-server/test-quickfiles-simple.js (enhancements)

Closes: stash@{3} (mcps/internal)
```

---

### 🟡 À Investiguer - Priorité MOYENNE (1 stash)

#### 4. Principal stash@{1} - Modifications avant résolution conflits

**Status** : ⚠️ INVESTIGATION REQUISE  
**Complexité** : Moyenne  
**Risque** : Moyen (fichiers non suivis inclus)  
**Durée estimée** : 30-45 min

**Détails** :
- **Dépôt** : d:/roo-extensions (principal)
- **Date** : 2025-05-28 01:47:28 (5 mois)
- **Message** : "Modifications temporaires avant résolution conflits main (incluant non suivis)"
- **Fichiers trackés** : 2 (logs sync + test script)
- **⚠️ Fichiers non suivis** : Oui (nombre inconnu)

**Fichiers trackés identifiés** :
1. `cleanup-backups/20250527-012300/sync_log.txt` - Logs de sync
2. `mcps/tests/github-projects/test-fonctionnalites-prioritaires.ps1` - Corrections chemins

**Plan d'investigation** :
1. **Lister les fichiers non suivis** :
   ```bash
   git show stash@{1}^3 --name-only
   ```

2. **Examiner leur contenu** :
   ```bash
   git show stash@{1}^3
   ```

3. **Décider** :
   - Si fichiers non suivis sont importants → les extraire et recycler
   - Si fichiers non suivis sont obsolètes/temporaires → ignorer
   - Si fichiers trackés seuls sont pertinents → recycler uniquement ceux-ci

4. **Action selon résultat** :
   - Créer rapport d'investigation détaillé
   - Décider du recyclage ou de l'archivage
   - Documenter la décision

**Note** : Investigation à faire AVANT tout recyclage

---

### 🟢 À Vérifier Rapidement - Priorité BASSE (12 stashs)

#### Stashs Automatiques (stash@{2-10, 12-14})

**Status** : Probablement OBSOLÈTES  
**Raison** : Stashs automatiques créés lors de sync pulls  
**Date** : Mai 2025 (5+ mois)  
**Action** : Vérification rapide puis suppression

**Liste** :
```
stash@{2}  - 2025-05-27 01:35:31: Automated stash before sync pull
stash@{3}  - 2025-05-27 01:35:04: Automated stash before sync pull
stash@{4}  - 2025-05-27 01:34:32: Automated stash before sync pull
stash@{5}  - 2025-05-27 01:34:04: Automated stash before sync pull
stash@{6}  - 2025-05-27 01:33:31: Automated stash before sync pull
stash@{7}  - 2025-05-27 01:09:23: Automated stash before sync pull
stash@{8}  - 2025-05-27 01:03:30: Automated stash before sync pull
stash@{9}  - 2025-05-26 01:02:26: Automated stash before sync pull
stash@{10} - 2025-05-25 15:48:17: Automated stash before sync pull
stash@{12} - 2025-05-23 12:26:45: Automated stash before sync pull
stash@{13} - 2025-05-23 12:26:09: Automated stash before sync pull
stash@{14} - 2025-05-23 12:10:06: Automated stash before sync pull
```

**Plan de vérification** :
1. Analyser rapidement chaque stash : `git stash show stash@{N} --stat`
2. Si modifications mineures/logs → marquer pour suppression
3. Si modifications substantielles → analyser en détail
4. Créer batch de suppression pour les obsolètes

#### Stash@{11} - Roo temporary stash

**Date** : 2025-05-24 00:05:26  
**Message** : "Roo temporary stash for branch checkout"  
**Action** : Vérifier rapidement, probablement obsolète

---

### 🔵 À Analyser Plus Tard - Priorité DIFFÉRÉE (2 stashs)

#### Internal stash@{1} et stash@{2} - Documentation quickfiles

**Status** : Doublons potentiels  
**Date** : 2025-08-21 (même jour, 7 min d'écart)  
**Message** : Même message pour les deux  
**Action** : Analyser après le recyclage de stash@{3}

**Raison du report** :
- Ces stashs concernent la même doc que stash@{3}
- Probablement des versions intermédiaires
- Analyser après stash@{3} pour éviter les doublons

---

## Timeline d'Exécution

### Session 1 : Recyclages Simples (1h30)
1. **Principal stash@{0}** - Script diagnostic (10 min)
2. **Internal stash@{0}** - Tests GitHub (20 min)
3. **Investigation stash@{1}** - Fichiers non suivis (30-45 min)

### Session 2 : Recyclage Complexe (1h)
4. **Internal stash@{3}** - Quickfiles ESM (45 min)
   - Investigation préalable
   - Tests approfondis
   - Résolution conflits si nécessaire

### Session 3 : Nettoyage Masse (1-2h)
5. **Vérification rapide** des 12 stashs automatiques (30 min)
6. **Analyse** des 2 stashs documentation (20 min)
7. **Suppression** des obsolètes (10 min)
8. **Rapport final** (30 min)

---

## Livrables Finaux Attendus

### Commits de Recyclage
- [ ] Commit : recycle(stash-0) - Script diagnostic portabilité
- [ ] Commit : recycle(stash-0-internal) - Tests GitHub améliorés
- [ ] Commit : recycle(stash-3-internal) - Quickfiles ESM doc (si pertinent)
- [ ] Commits additionnels si investigation stash@{1} révèle du contenu important

### Documentation
- [x] docs/git/workspace-repos-inventory.md
- [x] docs/git/stash-inventory-20251016.md
- [x] docs/git/stash-recovery-plan-20251016.md (ce fichier)
- [ ] docs/git/stash-recycling-report-20251016.md (à créer en fin)

### Scripts
- [x] scripts/stash-recovery/collect-all-stashs.ps1
- [x] scripts/stash-recovery/analyze-stash-detailed.ps1
- [ ] scripts/stash-recovery/batch-delete-obsolete-stashs.ps1 (à créer si besoin)

---

## Points de Vigilance Critiques

### ⚠️ Sécurité
1. **TOUJOURS** faire un backup avant toute opération :
   ```bash
   git stash list > backup_stashs_$(date +%Y%m%d_%H%M%S).txt
   ```

2. **JAMAIS** `git stash clear` sans validation utilisateur

3. **TESTER** après chaque recyclage si modifications importantes

4. **VALIDER** avec l'utilisateur avant :
   - Suppression de stashs
   - Recyclage de stashs complexes (stash@{3})
   - Investigation de fichiers non suivis (stash@{1})

### 🔍 Vérifications
1. **Avant recyclage** :
   - Vérifier que le fichier existe encore
   - Comparer avec l'état actuel
   - Identifier les conflits potentiels

2. **Après recyclage** :
   - Compiler/tester si applicable
   - Vérifier les imports/dépendances
   - Valider la cohérence du code

3. **Avant suppression** :
   - Double-vérifier que le stash est bien recyclé ou obsolète
   - Archiver si doute (export vers fichier texte)

### 📋 Traçabilité
1. **Format de commit strict** :
   ```
   recycle(stash-N): [intention originale]
   
   Original stash: stash@{N} from [depot]
   Date: [date]
   Original message: "[message]"
   
   Changes applied:
   - [changement 1]
   - [changement 2]
   
   Notes:
   - [adaptations]
   
   Closes: stash@{N}
   ```

2. **Documentation systématique** des choix

3. **Rapport final** détaillé avec statistiques

---

## Durée Estimée Totale

- ✅ **Phase 1-3 complétées** : ~2h
- ⏳ **Session 1** (Recyclages simples) : 1h30
- ⏳ **Session 2** (Recyclage complexe) : 1h
- ⏳ **Session 3** (Nettoyage) : 1-2h
- ⏳ **Buffer** : 30 min

**TOTAL** : 6-7 heures (incluant temps déjà passé)  
**RESTANT** : 4-5 heures

---

## Prochaine Action Immédiate

**Recommandation** : Commencer Session 1 avec Principal stash@{0} (le plus simple et sûr)

1. Vérifier état actuel du fichier
2. Appliquer le stash
3. Tester
4. Commit
5. Supprimer stash

Cette première action validera le processus avant de passer aux stashs plus complexes.
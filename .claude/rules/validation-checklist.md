# Checklist de Validation Technique

Extrait de CLAUDE.md le 2026-02-19. Obligatoire pour toute consolidation, refactoring ou modification significative.

---

## Avant de Commencer

- [ ] **Compter** : Nombre d'outils/fichiers/modules actuels (etat AVANT)
- [ ] **Documenter** : Noter ce decompte dans l'issue GitHub
- [ ] **TDD (Recommande)** : Ecrire les tests validant l'etat final AVANT l'implementation

## Pendant l'Implementation

- [ ] **Coder** : Implementer la modification
- [ ] **Tester** : Build + tous les tests passent (`npx vitest run`)
- [ ] **Verifier imports/exports** : Aucun export orphelin, aucun import casse

## Apres l'Implementation (CRITIQUE)

- [ ] **Recompter** : Nombre final (etat APRES)
- [ ] **Calculer ecart** : Ecart reel = APRES - AVANT
- [ ] **Comparer** : Ecart reel DOIT egaler ecart annonce
- [ ] **SI ECART INCORRECT** : Identifier ce qui manque
- [ ] **Retirer deprecated** : RETIRES, pas juste commentes
- [ ] **MAJ array/exports** : roosyncTools, exports, etc.

## Commit

- [ ] **Message** : Inclure decompte avant/apres (ex: "CONS-3: 29->24 outils")
- [ ] **Verifier** : Le nombre dans le message correspond a la realite Git

---

## Exemple d'Erreur a Eviter

**MAUVAIS** : Creer `roosync_config` unifie SANS retirer les 3 anciens → 29->30 (+1)
**BON** : Creer unifie ET retirer les anciens → 29->27 (-2)

---

## Responsabilites du Coordinateur

Le coordinateur DOIT fournir pour chaque tache de consolidation :

1. **Etat initial** : Nombre actuel (ex: "29 outils")
2. **Etat cible** : Nombre attendu (ex: "24 outils")
3. **Ecart attendu** : Reduction precise (ex: "-5")
4. **Tests requis** : Quels tests doivent passer
5. **Livrables** : Fichiers modifies/crees

Si le coordinateur ne fournit pas ces criteres, l'agent DOIT demander clarification AVANT de commencer.

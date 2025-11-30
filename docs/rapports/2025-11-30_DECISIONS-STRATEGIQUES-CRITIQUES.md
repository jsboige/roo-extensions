# Décisions Stratégiques Critiques - Stabilisation du Moteur Hiérarchique
**Date :** 30 Novembre 2025
**Autorité :** myia-po-2023 (Lead Coordinateur)
**Statut :** APPLIQUÉ

## Contexte
Suite à une analyse approfondie des 100 derniers commits sur le module `mcps/internal`, il a été établi que l'instabilité chronique des tests et des fonctionnalités de reconstruction hiérarchique provenait de modifications incessantes et non coordonnées sur le cœur du moteur.

## Décision N°1 : Restauration de la Version "Strict Prefix"
**Action :** Les fichiers suivants ont été restaurés à leur état du commit `7f6d01e` ("🎯 FINALISATION HIERARCHY ENGINE"), identifié comme la dernière version stable et déterministe :
- `servers/roo-state-manager/src/utils/hierarchy-reconstruction-engine.ts`
- `servers/roo-state-manager/src/utils/task-instruction-index.ts`

**Justification :** Cette version utilise une approche stricte (`strictMode: true`) basée sur un `exact-trie` pour le matching de préfixe. Elle rejette les heuristiques floues (fuzzy matching, proximité temporelle seule) qui sont la source principale des faux positifs et des cycles détectés récemment.

## Décision N°2 : Gel du Code (Code Freeze)
**Action :** Interdiction formelle de modifier la logique algorithmique de ces deux fichiers sans une procédure de validation exceptionnelle.
**Périmètre :**
- Pas de changement de seuils de similarité.
- Pas de réintroduction de logique "fuzzy".
- Pas de modification de la normalisation des chaînes (`computeInstructionPrefix`).

**Exception :** Seules les corrections de typage (TypeScript) ou les adaptations aux changements d'API externes sont autorisées, à condition qu'elles ne modifient pas le comportement fonctionnel.

## Décision N°3 : Tolérance aux Orphelins
**Principe :** Il est préférable d'avoir quelques tâches orphelines (non rattachées) plutôt que des rattachements incorrects (faux positifs) qui corrompent l'arbre des tâches.
**Conséquence :** Les tests doivent être adaptés pour tolérer un faible pourcentage de tâches non reconstruites, plutôt que de forcer le moteur à "deviner" des parents improbables.

## Décision N°4 : Documentation Sémantique (SDDD)
**Action :** Toute future proposition d'évolution de ce moteur devra d'abord faire l'objet d'une spécification écrite dans `docs/specifications/hierarchy-engine-v2.md` (à créer si besoin), validée par le Lead Architecte, avant la moindre ligne de code.

---
*Ce document fait foi de référence technique pour tous les agents travaillant sur le module `roo-state-manager`.*
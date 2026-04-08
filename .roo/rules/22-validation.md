# Regles de Validation - Roo Code

**Version:** 2.0.0 (condensed from 1.0.0, aligned with .claude/rules/)
**MAJ:** 2026-04-08

---

## CHECKLIST OBLIGATOIRE (consolidation, refactoring, modification significative)

### Avant

- [ ] **Compter** : Nombre d'outils/fichiers actuels (AVANT)

### Pendant

- [ ] **Implementer** la modification
- [ ] **Tester** : Build + `npx vitest run` passent
- [ ] **Verifier imports/exports** : Aucun orphelin

### Apres (CRITIQUE)

- [ ] **Recompter** (APRES)
- [ ] **Calculer ecart** : reel = APRES - AVANT. DOIT egaler l'annonce
- [ ] **Retirer deprecated** : Enlever des exports, pas juste commenter
- [ ] **Mettre a jour exports**

### Commit

- [ ] Inclure decompte avant/apres (ex: "CONS-3: Config 4->2 (29->24 outils)")

### Erreur type

Creer un nouvel outil MAIS laisser les anciens dans le barrel export -> compte augmente au lieu de baisser.
**Solution :** Toujours retirer les anciens ET ajouter le nouveau.

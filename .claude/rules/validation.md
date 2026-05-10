# Regles de Validation - Claude Code

**Version:** 2.0.0 (condensed)
**Issue:** #724

---

## CHECKLIST OBLIGATOIRE (consolidation, refactoring, modification significative)

### Avant

- [ ] **Compter** : Nombre d'outils/fichiers actuels (AVANT)

### Pendant

- [ ] **Implémenter** la modification
- [ ] **Tester** : Build + `npx vitest run` passent
- [ ] **Verifier imports/exports** : Aucun orphelin

### Apres (CRITIQUE)

- [ ] **Recompter** (APRES)
- [ ] **Calculer ecart** : reel = APRES - AVANT. DOIT egaler l'annonce
- [ ] **Retirer deprecated** : Enlever des exports, pas juste commenter
- [ ] **Mettre a jour exports**

### Commit

- [ ] Inclure decompte avant/apres (ex: "CONS-3: Config 4→2 (29→24 outils)")

### Erreur type

Creer un nouvel outil MAIS laisser les anciens dans le barrel export → compte augmente au lieu de baisser.
**Solution :** Toujours retirer les anciens ET ajouter le nouveau.

## Anti-code speculatif (#1936)

**Pas de fonctionnalite au-delà de ce qui est demande. Pas d'abstraction pour du code usage unique.** Si 200 lignes font le meme travail que 50, reecrire en 50.

**Pourquoi :** Agents ajoutent regulierement des features non demandees (43% context explosion sur coverage tasks, #2083). Chaque abstraction non necessaire est du code a maintenir qui n'a pas ete demande.

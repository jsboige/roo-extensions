# Regle 22 — Pas de Suppression Sans Preuve

**Version:** 1.0.0
**Issue:** #815

---

## Regle

**Aucun fichier ou fonction exporte ne peut etre supprime sans PREUVE que sa fonctionnalite est preservee.**

"Code mort" est un label dangereux. Du code sans importateur peut etre :
- Temporairement debranche par un refactoring incomplet
- Appele dynamiquement (registre d'outils, MCP dispatch)
- Un stub = cible d'implementation (PAS du code mort)

---

## Preuve Requise

### Avant de supprimer un fichier

1. **Equivalence fonctionnelle** : Nommer le remplacement avec les numeros de ligne
2. **Migration des imports** : Tous les appelants pointent vers le remplacement
3. **Tests** : Le remplacement passe les memes tests
4. **grep confirmation** : `grep "ancien-nom"` retourne zero dans le code actif

### Avant de supprimer une fonction

1. **Audit des appelants** : `grep "nomFonction"` = zero appelants actifs
2. **Historique** : `git log -S "nomFonction" --since="30 days ago"` — si recemment ajoutee, c'est du travail en cours
3. **Registre** : Verifier registres d'outils, dispatch MCP, invocations dynamiques

---

## Anti-Pattern : Chaine Circulaire

```
A importe B → B supprime → A n'a plus d'importateur → A "code mort" → A supprime
Resultat : fonctionnalite de A ET B perdue
```

**Prevention :**
1. Avant de declarer du code "mort", verifier `git log -S "import.*FileName"` pour les importateurs RECEMMENT supprimes
2. Si un importateur a ete supprime dans les 30 derniers jours → le code N'EST PAS mort
3. En cas de doute : NE PAS supprimer, signaler pour review humaine

---

## Repertoires Proteges

| Repertoire | Raison |
|-----------|--------|
| `src/services/synthesis/` | Pipeline LLM (3 destructions, investissement en cours) |
| `src/services/narrative/` | NarrativeContextBuilder (stubs Phase 3) |

**Les stubs dans ces repertoires sont des CIBLES d'implementation, PAS du code mort.**

---

## Equivalent Claude

`.claude/rules/no-deletion-without-proof.md`

---

**MAJ :** 2026-03-24

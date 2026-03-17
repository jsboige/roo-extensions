# TDD Recommandé

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #710

---

## Principe

Le TDD (Test-Driven Development) est RECOMMANDÉ mais pas OBLIGATOIRE pour le système RooSync.

---

## Quand Appliquer TDD

| Situation | TDD recommandé ? | Raison |
|-----------|-----------------|--------|
| Nouveau MCP tool | ✅ OUI | Contrat d'interface clair |
| Nouvelle fonctionnalité complexe | ✅ OUI | Spécification via tests |
| Bug fix | ⚠️ Optionnel | Test de régression suffisant |
| Documentation | ❌ NON | Pas de code |
| Refactoring simple | ❌ NON | Tests existants suffisent |

---

## Workflow TDD Minimal

1. **Écrire le test d'abord** (rouge)
2. **Implémenter le minimum** pour passer (vert)
3. **Refactoriser** si nécessaire (titre)
4. **Committer** avec message clair

---

## Alternatives

### Test After (TAD)

Écrire le test APRÈS l'implémentation :
- Plus rapide pour les prototypes
- Moins rigoureux mais suffisant pour les cas simples

### Testing Only

Seulement tester sans implémenter :
- Pour la validation de PRs
- Pour les audits de code

---

## Validation Rapide

```bash
cd mcps/internal/servers/roo-state-manager
npx vitest run
```

**Taux de succès attendu :** 99.6%+

---

**Référence :** [`.claude/rules/test-success-rates.md`](../../.claude/rules/test-success-rates.md)

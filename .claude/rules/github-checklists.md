# Règle Checklists GitHub - Claude Code

**Version:** 1.0.0
**Créé:** 2026-02-23
**Issue:** #516

---

## Principe Fondamental

Les tableaux de validation dans les issues GitHub sont la **source de vérité** pour l'état des tâches multi-machines. Les commentaires servent de **journal d'exécution**, mais le tableau doit refléter l'état réel.

**RÈGLE ABSOLUE :** NE JAMAIS fermer une issue avec un tableau vide ou incomplet.

---

## Checklist OBLIGATOIRE

Pour toute issue GitHub avec un tableau de validation (checklist) :

### 1. AVANT de commencer

1. **Lire le tableau** dans le corps de l'issue
2. **Identifier** les cases à cocher pour ta machine
3. **Comprendre** les critères de validation

### 2. PENDANT l'exécution

1. **Cocher AU FUR ET À MESURE** chaque case validée
2. **Committer IMMÉDIATEMENT** après chaque case
   ```bash
   git add . && git commit -m "docs(issue): Update checklist #XXX - machine Y case Z"
   git push
   ```
3. **NE JAMAIS attendre la fin** pour tout mettre à jour

### 3. APRÈS chaque case cochée

- Vérifier que le commit est bien passé
- Commenter l'issue pour documenter si nécessaire
- Ne pas accumuler les changements non-commités

### 4. AVANT de fermer l'issue

- **Vérifier** que 100% des cases sont cochées
- **LIRE** le tableau pour confirmer qu'aucune case n'est vide
- **Demander revue** si une case ne peut pas être validée

---

## Format Recommandé

### Format Tableau Checkboxes (préféré)

```markdown
| Machine | Build | Tests | Config | Validation |
|---------|-------|-------|--------|------------|
| myia-ai-01 | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-po-2023 | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-po-2025 | ⬜ | ⬜ | ⬜ | ⬜ |
```

**Règle :** Remplacer `⬜` par `✅` AU FUR ET À MESURE de la validation.

### Format Tableau État (alternative)

```markdown
## État Validé (mis à jour par l'agent)

| Machine | Statut | Dernière mise à jour | Commit |
|---------|--------|---------------------|--------|
| myia-ai-01 | ✅ PASS | 2026-02-23 | abc123 |
| myia-po-2025 | ✅ PASS | 2026-02-23 | def456 |

**Last updated:** 2026-02-23 by myia-po-2025
```

---

## Intégration dans les Agents

Cette règle est **automatiquement incluse** dans :

- **`/coordinate`** (myia-ai-01) - Phase 3 (exécution)
- **`/executor`** (autres machines) - Phase 3 (exécution)
- **`sync-tour`** (skill) - Phase 7 (coordination)
- **`task-worker`** (agent) - Étape 7 (reporter)

**Référence :** [`.claude/rules/github-checklists.md`](.claude/rules/github-checklists.md)

---

## Exemples Concrets

### ❌ MAUVAIS (à ne pas faire)

```markdown
# Issue fermée avec tableau vide

| Machine | Build | Tests |
|---------|-------|-------|
| myia-ai-01 | ⬜ | ⬜ |
| myia-po-2025 | ⬜ | ⬜ |

# Commentaire : "Toutes les machines ont passé, je ferme."
```

**Problème :** Le tableau est vide, impossible de vérifier sans lire les commentaires.

### ✅ BON (à faire)

```markdown
| Machine | Build | Tests |
|---------|-------|-------|
| myia-ai-01 | ✅ | ✅ |
| myia-po-2025 | ✅ | ✅ |

# Commit 1: abc123 - myia-ai-01 build OK
# Commit 2: def456 - myia-po-2025 build OK
# Commit 3: ghi789 - myia-po-2025 tests OK
```

**Avantage :** L'état est visible immédiatement, sans lire les commentaires.

---

## Sanctions (en cas de non-respect)

1. **Rappel** dans l'issue de la règle
2. **Réouverture** de l'issue si fermée avec tableau vide
3. **Documentation** du problème dans le rapport de fin de cycle

---

## Validation

Pour vérifier qu'une issue est correctement validée :

```bash
# Vérifier que le tableau n'est pas vide
gh issue view XXX --repo jsboige/roo-extensions | grep "⬜"
# Si retour vide = OK, si retourne des lignes = INCOMPLET
```

---

**Dernière mise à jour :** 2026-02-23
**Issue :** #516

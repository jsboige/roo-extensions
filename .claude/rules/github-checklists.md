# Règle GitHub Checklists - Traçabilité Obligatoire

**Version:** 1.0.0
**Créé:** 2026-02-23
**Issue:** #516 - Validation checklists non mises à jour

---

## Problème Critique

Les agents Claude Code **ne mettent pas à jour les checklists** dans les corps d'issues GitHub, créant une **fausse traçabilité**.

### Exemple Concret : Issue #503 (Smoke Test)

**Tableau dans l'issue (resté VIDE):**
```markdown
| Machine | Build | Tests | win-cli | RSM 36 | RooSync msg | Git sync | Condensation 80% |
|---------|-------|-------|---------|--------|-------------|----------|-------------------|
| myia-ai-01 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
```

**Réalité (commentaires):** 6/6 machines ont PASSÉ, issue CLOSED, mais tableau vide

**Conséquence:** Impossible de savoir QUICKMENT l'état sans lire 12 commentaires.

---

## Règle Absolue

**POUR TOUTE ISSUE AVEC UN TABLEAU DE VALIDATION :**

### 1. AVANT de commencer

- [ ] Lire le tableau de validation dans le corps de l'issue
- [ ] Identifier les cases qui correspondent à ta machine
- [ ] Comprendre les critères de succès (chaque colonne)

### 2. PENDANT l'exécution

- [ ] Mettre à jour le tableau **AU FUR ET À MESURE** que tu complètes les cases
- [ ] Utiliser l'outil Bash pour éditer l'issue :
  ```bash
  # Éditer le corps de l'issue avec le tableau mis à jour
  gh issue edit {NUM} --body "TABLEAU_MAJ"
  ```
- [ ] Remplacer `⬜` par `✅` (PASS) ou `❌` (FAIL)
- [ ] Committer la mise à jour **après chaque case**

### 3. APRÈS chaque case

- [ ] Committer la mise à jour du tableau
- [ ] Ajouter un commentaire avec les détails (facultatif mais recommandé)

### 4. AVANT de fermer l'issue

- [ ] Vérifier que **100% des cases** sont cochées (✅ ou ❌)
- [ ] Si des cases sont vides (⬜) : **NE PAS FERMER L'ISSUE**
- [ ] Demander de l'aide si une case ne peut pas être complétée

---

## Format Recommandé pour les Tableaux

### Option 1 : Checkboxes (standard)

```markdown
| Machine | Build | Tests | win-cli | RSM 36 | RooSync msg | Git sync | Condensation 80% |
|---------|-------|-------|---------|--------|-------------|----------|-------------------|
| myia-ai-01 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-po-2023 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-po-2024 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-po-2025 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-po-2026 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-web1 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

**Last updated:** 2026-02-23 by myia-web1
```

### Option 2 : Tableau d'état (alternative)

```markdown
## État Validé (mis à jour par l'agent)

| Machine | Statut | Dernière mise à jour | Commit |
|---------|--------|---------------------|--------|
| myia-ai-01 | ✅ PASS | 2026-02-22 | abc123 |
| myia-po-2023 | ✅ PASS | 2026-02-22 | def456 |
| myia-po-2024 | ⬜ PENDING | - | - |
| myia-po-2025 | ⬜ PENDING | - | - |
| myia-po-2026 | ⬜ PENDING | - | - |
| myia-web1 | ✅ PASS | 2026-02-23 | 789abc |

**Last updated:** 2026-02-23 by myia-web1
```

---

## Intégration Agents

### Dans le skill `/sync-tour`

Ajouter après "Phase 3 : Validation" :
```markdown
## Phase 3.5 : Mise à jour Checklists GitHub

Si une issue avec un tableau de validation est en cours :
- Mettre à jour le tableau avec les résultats de cette machine
- Committer immédiatement
- Vérifier que toutes les machines sont complétées avant de fermer
```

### Dans le command `/executor`

Ajouter dans "PHASE 3 : EXÉCUTION AUTONOME" :
```markdown
### 3f. Rapport + Checklist GitHub (CRITIQUE)

Avant de commenter l'issue :
- [ ] Mettre à jour le tableau de validation dans le corps de l'issue
- [ ] Remplacer les ⬜ par ✅ ou ❌
- [ ] Committer la mise à jour avec `gh issue edit`
- [ ] SEULEMENT ensuite, commenter l'issue avec le résultat

RÈGLE ABSOLUE : NE JAMAIS commenter sans avoir mis à jour le tableau.
```

### Dans le command `/coordinate`

Ajouter dans "PHASE 4 : VALIDATION FINALE" :
```markdown
### 4.2. Vérification Checklists (CRITIQUE)

Avant de fermer une issue multi-machine :
- [ ] Vérifier que le tableau de validation est complété à 100%
- [ ] Si cases vides : envoyer message aux machines concernées
- [ ] Attendre que toutes les cases soient cochées
- [ ] SEULEMENT alors, fermer l'issue
```

---

## Exemples d'Utilisation

### Exemple 1 : Mise à jour complète (myia-web1)

```bash
# 1. Récupérer le corps de l'issue actuel
gh issue view 503 --json body --jq '.body' > /tmp/issue-body.md

# 2. Éditer le fichier pour remplacer les ⬜ par ✅
#    myia-web1 : ⬜ ⬜ ⬜ ⬜ ⬜ ⬜ ⬜ → ✅ ✅ ✅ ✅ ✅ ✅ ✅

# 3. Mettre à jour l'issue
gh issue edit 503 --body-file /tmp/issue-body.md

# 4. Ajouter un commentaire détaillé
gh issue comment 503 --body "✅ **myia-web1** - SMOKE TEST PASS

- Build: OK
- Tests: 3294/3308 PASS (99.6%)
- win-cli: OK (fork local 0.2.0)
- RSM 36: OK
- RooSync msg: OK
- Git sync: OK
- Condensation 80%: OK

Commit: c6f8dec"
```

### Exemple 2 : Tableau partiellement complété

```markdown
## Validation Smoke Test #503

| Machine | Build | Tests | win-cli | RSM 36 | RooSync msg | Git sync | Condensation 80% |
|---------|-------|-------|---------|--------|-------------|----------|-------------------|
| myia-ai-01 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| myia-po-2023 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| myia-po-2024 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |  ← EN ATTENTE
| myia-po-2025 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |  ← EN ATTENTE
| myia-po-2026 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| myia-web1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Last updated:** 2026-02-23 by myia-web1

**Progression:** 4/6 machines (67%)
**En attente:** myia-po-2024, myia-po-2025
```

---

## Outils Bash Utiles

```bash
# Récupérer le corps d'une issue
gh issue view {NUM} --json body --jq '.body'

# Éditer le corps d'une issue
gh issue edit {NUM} --body "NOUVEAU_CONTENU"

# Éditer depuis un fichier
gh issue edit {NUM} --body-file /tmp/issue-body.md

# Commenter une issue
gh issue comment {NUM} --body "MESSAGE"
```

---

## Responsabilité du Coordinateur

Le coordinateur (myia-ai-01) DOIT :

1. **Créer les tableaux de validation** dans les issues multi-machines
2. **Vérifier que les tableaux sont complétés** avant de fermer
3. **Relancer les machines** qui ont des cases vides
4. **Documenter les exceptions** (si une case ne peut pas être complétée)

---

**Dernière mise à jour :** 2026-02-23
**Mainteneur :** Coordinateur RooSync (myia-ai-01)

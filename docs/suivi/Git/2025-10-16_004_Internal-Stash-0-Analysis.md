# Analyse Stash Internal stash@{0} - Améliorations Tests GitHub Projects

## Métadonnées du Stash

- **Dépôt** : mcps/internal
- **Index** : stash@{0}
- **Date** : 2025-09-14 05:15:25 +0200
- **Message original** : "WIP on main: 616dced fix: Correction des tests post-merge - remplacement .execute() par .handler()"
- **Branch** : main
- **Fichier concerné** : servers/github-projects-mcp/tests/GithubProjectsTool.test.ts
- **Modifications** : 197 insertions, 11 suppressions

---

## 🎯 Esprit du Stash

### Intention Originale
Améliorer la robustesse et la fiabilité des tests E2E GitHub Projects en corrigeant plusieurs problèmes :
1. **Meilleur error logging** lors des échecs de création d'items
2. **Gestion de la synchronisation API** GitHub (délais)
3. **Correction bug projectNumber** : utilisation de `projectNumber: 0` (invalide)
4. **Ajout de tests complets** pour Project Item Management

### Problèmes Identifiés par le Stash

**Problème 1 : Logging d'erreur insuffisant**
```typescript
// AVANT
throw new Error(`Failed to create test item: ${title}`);

// APRÈS (stash)
console.error('Failed to create test item:', issueResult);
throw new Error(`Failed to create test item: ${title} - ${JSON.stringify(issueResult)}`);
```

**Problème 2 : Pas de délai pour synchronisation API**
```typescript
// APRÈS (stash)
// Attendre un peu pour que l'API GitHub se synchronise
await new Promise(resolve => setTimeout(resolve, 2000));
```

**Problème 3 : Bug projectNumber invalide**
```typescript
// AVANT
projectNumber: 0,  // ❌ Invalide!

// APRÈS (stash)
const listProjectsTool = tools.find(t => t.name === 'list_projects') as any;
const allProjects = await listProjectsTool.execute({ owner: TEST_GITHUB_OWNER! });
const projectInfo = allProjects.projects.find((p: any) => p.id === testProjectId);
projectNumber: projectInfo.number,  // ✅ Correct
```

**Problème 4 : Tests incomplets**
Le stash ajoute ~110 lignes de nouveaux tests pour :
- `add_item_to_project` (issues, draft issues)
- `get_project_items` direct
- `update_project_item_field` (Status updates)

---

## 📊 État Actuel du Code

### Amélioration 1 : Error Logging
**Status** : ❌ **NON APPLIQUÉ**
- Code actuel ligne 146 : `throw new Error(`Failed to create test item: ${title}`);`
- Pas de `console.error` ni de sérialisation JSON du résultat

### Amélioration 2 : Synchronisation API
**Status** : ✅ **RÉSOLU AUTREMENT (MIEUX)**
- Le code actuel utilise une fonction `poll()` (lignes 31-45) avec retry intelligent
- **Supérieur au timeout fixe** : vérifie réellement la condition vs attente aveugle
- Timeout 20s avec intervalle 3s (vs 2s fixe du stash)

### Amélioration 3 : Bug projectNumber
**Status** : ❌ **BUG TOUJOURS PRÉSENT!**
- Code actuel lignes 204, 217, 230 : `projectNumber: 0` (invalide)
- **Problème critique** : Les tests de complexité utilisent un projectNumber invalide

### Amélioration 4 : Nouveaux tests
**Status** : ⚠️ **À VÉRIFIER**
- Besoin de vérifier si ces tests existent dans le code actuel

---

## 🔍 Décision

**STASH À RECYCLER PARTIELLEMENT - Scénario B**

### Ce qui DOIT être recyclé
1. ✅ **Meilleur error logging** (Amélioration 1)
2. ✅ **Correction bug projectNumber** (Amélioration 3) - **CRITIQUE**

### Ce qui est OBSOLÈTE
1. ❌ **Timeouts fixes 2000ms** - Le système de polling est supérieur
2. ❌ **Simplification get project** - Déjà bien géré dans le code actuel

### Ce qui nécessite VALIDATION
1. ⚠️ **Nouveaux tests** - Vérifier s'ils existent déjà

---

## 📝 Plan d'Action

### Étape 1 : Vérifier les nouveaux tests
```bash
cd mcps/internal
grep -n "Project Item Management" servers/github-projects-mcp/tests/GithubProjectsTool.test.ts
```

### Étape 2 : Recycler les améliorations pertinentes
**Modifications à appliquer manuellement** :

**A. Meilleur error logging (ligne ~146)**
```typescript
if (!issueResult.success || !issueResult.projectItemId) {
  console.error('Failed to create test item:', issueResult);
  throw new Error(`Failed to create test item: ${title} - ${JSON.stringify(issueResult)}`);
}
```

**B. Fix bug projectNumber dans 3 tests (lignes ~199-235)**
```typescript
// Avant chaque appel à analyze_task_complexity, ajouter:
const listProjectsTool = tools.find(t => t.name === 'list_projects') as any;
const allProjects = await listProjectsTool.execute({ owner: TEST_GITHUB_OWNER! });
const projectInfo = allProjects.projects.find((p: any) => p.id === testProjectId);

// Puis utiliser:
projectNumber: projectInfo.number,  // Au lieu de 0
```

### Étape 3 : Tests et commit
- Tester les modifications
- Commit avec message structuré

---

## 🎯 Commit Message Prévu

```
recycle(stash): improve GitHub Projects E2E test reliability

Original stash: stash@{0} from mcps/internal
Date: 2025-09-14 05:15:25
Original message: "WIP on main: 616dced fix: Correction des tests post-merge"

Esprit du stash:
Améliorer la robustesse des tests E2E en corrigeant le logging d'erreur
et en fixant le bug projectNumber: 0 dans les tests de complexité.

Adaptations effectuées:
- Add detailed error logging with JSON serialization for test failures
- Fix projectNumber bug in complexity analysis tests (was using invalid 0)
- Retrieve actual project number from list_projects before analysis
- Keep existing polling mechanism (superior to fixed timeouts)

Files modified:
- servers/github-projects-mcp/tests/GithubProjectsTool.test.ts

Notes:
- Fixed timeout approach from stash NOT applied (current polling is better)
- New test cases from stash evaluated separately if needed

Closes-Stash: stash@{0} (mcps/internal)
```

---

*Analyse effectuée le 2025-10-16 dans le cadre de la mission de recyclage intellectuel*
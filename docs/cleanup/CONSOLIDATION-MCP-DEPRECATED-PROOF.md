# Matrice de Preuve Non-Usage — Serveurs MCP Dépréciés (Epic #2639, WS4 Tâche C Phase 1)

**Date:** 2026-06-23
**Machine:** myia-po-2026 (Claude Code, GLM-5.2)
**Cycle:** c.90
**Epic parent:** #2639 — Workstream 4, [Tâche fille C](CONSOLIDATION-PLAN-EPIC-2639.md#tâche-fille-c--suppression-serveurs-mcp-dépréciés-github-projects-mcp-quickfiles-server) Phase 1 (preuve de non-usage)
**Méthodologie:** SDDD triple grounding — Technique (Read/Grep/Glob/Bash) ✅, Sémantique (codebase_search HS) ⚠️, Conversationnel (dashboard workspace) ✅
**Scope:** **Investigation READ-ONLY uniquement.** Aucune suppression effectuée. L'exécution destructive (Phase 2–4) reste différée / soumise à validation utilisateur conformément au plan WS4.

---

## Résumé Exécutif

La [Tâche C Phase 1](CONSOLIDATION-PLAN-EPIC-2639.md) du plan #2639 demande de prouver le non-usage de `github-projects-mcp` et `quickfiles-server` avant suppression. La claim de travail du plan (« `git grep = 0` hits actifs ») est **inexacte** : il existe de nombreuses références. Cependant, l'analyse de leur **nature** révèle un résultat **meilleur qu'attendu** :

1. **0 import runtime** — aucun code actif n'importe les packages des serveurs. Les dossiers physiques sont du **code mort au niveau build/import**.
2. Les noms persistent **légitimement** dans une constante de détection (`RETIRED_MCP_NAMES`), des fixtures de test historiques et de la documentation — **qui doivent rester**.

**Conclusion :** la suppression physique des 2 dossiers est **build-safe**, mais le travail de doc/logique (Phase 4 du plan) ne consiste PAS à retirer `RETIRED_MCP_NAMES` (c'est le mécanisme qui *détecte* les MCP retirés dans les configs machines) — il s'agit seulement de confirmer que rien n'importe les serveurs supprimés.

---

## 1. Inventaire des serveurs (état vérifié 2026-06-23)

| Serveur | Chemin | Fichiers `.ts` | Statut plan | État réel |
|---------|--------|---------------|-------------|-----------|
| `github-projects-mcp` | `mcps/internal/servers/github-projects-mcp/` | 11 | Déprécié — code présent | ✅ Présent |
| `quickfiles-server` | `mcps/internal/servers/quickfiles-server/` | 16 | Déprécié — code présent | ✅ Présent |
| `desktop-commander` | — | — | Déjà supprimé | ✅ Confirmé absent |

> Note : le plan (2026-06-22) comptait 10 + 17 fichiers `.ts` ; le recompte donne 11 + 16. Écart mineur, probablement des refactorings post-plan.

---

## 2. Preuve de non-usage — matrice catégorisée

La distinction critique est **runtime import** (casserait le build) vs **référence de string** (constante/fixture/doc — inoffensive).

### 2.1 Imports runtime : **0** ✅ (preuve clé)

```
git grep -nE "from ['\"](.*github-projects-mcp|.*quickfiles-server)" -- 'src/**/*.ts'
```
→ **résultat vide**. Aucun module actif n'importe les packages des 2 serveurs. La suppression des dossiers ne cassera aucun `import`.

### 2.2 Référence workspace racine : **0** ✅

Le `package.json` racine du submodule ne référence aucun des 2 serveurs (pas de workspace glob ni de dependency). → pas de lien build au niveau workspace.

### 2.3 Constante de détection active : **1 fichier — LÉGITIME, DOIT RESTER** ⚠️

**Fichier :** `mcps/internal/servers/roo-state-manager/src/services/McpValidationConstants.ts` L12–16

```typescript
export const RETIRED_MCP_NAMES = [
  'desktop-commander',
  'github-projects-mcp',
  'quickfiles',
] as const;
```

**Nature :** c'est la liste canonique des MCP retirés, utilisée par la logique de **détection de drift** (validation croisée des configs machines). Ce n'est **pas** une dépendance vers les serveurs — c'est le mécanisme qui *flag* une config machine contenant encore un MCP retiré.

**Action Phase 4 :** **NE PAS supprimer** cette constante. La retirer supprimerait la capacité de détecter `github-projects-mcp`/`quickfiles` dans une config machine récalcitrante. Les entrées restent correctes même après suppression du code serveur (elles décrivent l'état *retired*, pas l'état *présent*).

### 2.4 Exemple dans une description d'outil : **1 fichier — cosmétique** (optionnel)

**Fichier :** `mcps/internal/servers/roo-state-manager/src/tools/get_mcp_best_practices.ts` L154

```typescript
description: 'Nom optionnel du MCP spécifique à analyser (ex: "roo-state-manager", "quickfiles", etc.). ...'
```

**Nature :** `quickfiles` cité en exemple dans le prompt-description d'un outil. Inoffensif (aucun impact runtime). Mise à jour optionnelle (remplacer l'exemple par un MCP actif) — pure cosmétique, non bloquant pour la suppression.

### 2.5 Fixtures de test historiques : **légitimes, DOIVENT RESTER** ✅

Les références dans `tests/fixtures/real-tasks/*/api_conversation_history.json` et `ui_messages.json` sont des **données de conversation historiques** capturées avant le retrait des MCP. Ce sont des *inputs* de test (skeletons indexés), pas des dépendances de code. Les supprimer casserait des tests de régression documentaire sans bénéfice.

### 2.6 Tests référençant le nom : **légitimes** ✅

- `src/__tests__/mcp-validation.test.ts`, `src/services/__tests__/McpValidationConstants.test.ts` — testent `RETIRED_MCP_NAMES` (la constante de §2.3). Restent tant que la constante reste.
- `tests/unit/services/DiffDetector.test.ts`, `tests/unit/tools/roosync/list-diffs.test.ts`, `tests/integration/baseline-workflow.test.ts`, `tests/e2e/roosync/workflow-complete.test.ts` — testent la détection de drift en mentionnant les MCP retirés comme cas de figure. Restent.

### 2.7 Documentation : **historique, légitime** ✅

~80 fichiers de doc référencent les noms (guides d'installation, rapports de mission, troubleshooting, baselines). Ces documents décrivent l'état historique du système. Les docs actives pertinentes (`tool-availability.md`, `MCP_AVAILABILITY.md`, `BASELINE_GHOST_MCPS.md`) documentent **délibérément** ces MCP retirés — elles ne sont pas stale (voir décision similaire en PR #2653 : les docs de migration-record documentant les MCP retirés sont intentionnelles).

---

## 3. Correction à apporter au plan #2639 (Tâche C Phase 1)

**Claim actuelle du plan (§ Tâche C, Phase 1) :**
> "`git grep "github-projects-mcp\|quickfiles-server"` = 0 hits actifs"

**Réalité vérifiée :** il y a ~90 hits, mais **0 import runtime**. La formulation correcte serait :

> "`git grep` des **imports runtime** (`from '...github-projects-mcp'` / `from '...quickfiles-server'`) = **0 hits**. Les ~90 références restantes sont des constantes de détection (`RETIRED_MCP_NAMES`), fixtures historiques et documentation — toutes légitimes et à préserver."

Cette nuance est **essentielle** : un exécuteur suivant le plan littéralement pourrait (a) croire à tort que le grep est « sale » et hésiter à supprimer, ou (b) supprimer `RETIRED_MCP_NAMES` en pensant nettoyer une référence, ce qui **casserait la détection de drift**. Cette matrice évite les deux pièges.

---

## 4. Observation — dossiers serveurs hors-plan (NON dans mon scope)

Le recompte révèle que le submodule contient **9 dossiers serveurs**, alors que le plan (2026-06-22) n'en connaissait que 5. Dossiers non couverts par le plan :

| Dossier | Statut probable | Action recommandée |
|---------|-----------------|--------------------|
| `jupyter-mcp-server/` | Inconnu — non mentionné dans `tool-availability.md` | Audit séparé (actif vs déprécié ?) |
| `jupyter-papermill-mcp-server/` | Inconnu — non mentionné | Audit séparé |
| `open-terminal-mcp/` | Inconnu — non mentionné | Audit séparé |
| `roo-state-manager;C/` | **Suspect** — point-virgule dans le nom = clone accidentel probable | Investigation (corruption ? commit par erreur ?) |

**Ces 4 dossiers sont hors-scope de cette tâche.** Je les signale au coordinateur pour scoping séparé (anti-code-speculatif #1936 — je n'étends pas mon scope). Le `roo-state-manager;C/` notamment mérite un œil : un dossier avec un point-virgule est presque toujours une erreur de manipulation (autocomplete shell, copie Windows).

---

## 5. Recommandation pour l'exécution Tâche C (future, GATED)

L'exécution destructive reste **différée / soumise à validation utilisateur** (conformément au plan WS4 « Planification uniquement »). Quand elle sera autorisée :

1. **Phase 2 (suppression) — build-safe :** retirer `mcps/internal/servers/github-projects-mcp/` + `quickfiles-server/`. Vérifié : 0 import runtime, 0 workspace ref.
2. **Phase 4 (doc/logique) — NE PAS toucher à `RETIRED_MCP_NAMES`** (§2.3). Mise à jour cosmétique optionnelle de l'exemple `get_mcp_best_practices.ts` L154 (§2.4).
3. **Validation :** `npm run build && npx vitest run` (config CI) — la suppression ne doit pas casser le build (les tests référençant les noms testent la *constante*, pas les serveurs supprimés).
4. **PR unique** pour les 2 serveurs (conformément au plan), worktree dans le submodule, puis pointer-bump parent APRÈS merge submod (anti-pointer-bump-prématuré #1799).

---

## Notes SDDD (Bookend)

**Bookend début :** `codebase_search` HS (collection Qdrant unreachable — infra #2636 en cours de fix). Fallback Technique (Grep/Glob/Bash/Read) ✅ + Conversationnel (dashboard workspace, ACK ai-01 14:02) ✅. Triple grounding partiel.

**Bookend fin (recommandé) :** relancer `codebase_search` post-récupération infra pour confirmer l'indexation de cette matrice et mettre à jour la doc afférente (le plan #2639 § Notes SDDD recommande la même chose).

**Anti-double-claim :** `gh pr list --search` confirmera aucune PR ouverte ciblant la suppression MCP dépréciés (uniquement #2653 qui les *mentionne* en deferred-findings). po-2024 a fait Tâche B (scripts superseded → PR #2657), distincte. Tâche C était vierge.

---

**Provenance :** investigation READ-ONLY par myia-po-2026 (Claude Code, GLM-5.2), 2026-06-23, cycle c.90. Complète le [Plan de Consolidation #2639](CONSOLIDATION-PLAN-EPIC-2639.md) Axe 2. Aucun code supprimé.

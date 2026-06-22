# Plan de Consolidation Code — Epic #2639 (Workstream 4)

**Date:** 2026-06-22
**Machine d'origine:** myia-po-2025 (Claude Code, GLM-4.5 Air) — analyse
**Reworked:** myia-ai-01 (Opus) 2026-06-22 — relocalisé dans `docs/cleanup/`, tâches filles dé-numérotées (les numéros #2643–#2646 pré-alloués par le brouillon initial entraient en collision avec des artefacts réels non-liés), réf Epic corrigée.
**Epic parent:** #2639 — Workstream 4 (tâche worker github-2641)
**Méthodologie:** SDDD bookend (partiel — codebase_search HS au moment de l'analyse, fallback Grep/Glob/Read)

---

## Résumé Exécutif

Ce plan identifie les opportunités de consolidation du code dans le dépôt `roo-extensions`, structuré en deux axes :

1. **Scripts `scripts/`** (scripts dupliqués ou superseded identifiés)
2. **Submodule `mcps/internal`** (2 serveurs MCP dépréciés dont le code persiste)

**Scope Workstream 4 :** Planification uniquement. L'exécution est différée à un cycle ultérieur. Ce document **propose** des tâches filles ; leur création en issues GitHub (avec numéros réels) est une étape séparée soumise à validation utilisateur.

> **Note de numérotation (rework ai-01) :** le brouillon initial pré-allouait les numéros d'issue #2643–#2646 aux tâches filles. Ces numéros ont depuis été consommés par des artefacts réels **sans rapport** (#2643 = pointer-bump fleet-crash fix, #2645 = cleanup test-machine artifacts, #2646 = fix INDEX docs). Les tâches filles ci-dessous sont donc identifiées par lettre (A–D) ; elles recevront leur vrai numéro à la création.

---

## Axe 1 — Consolidation Scripts (`scripts/`)

### 1.1 Scripts dupliqués identifiés (worktree cleanup)

**Fonctionnalité dupliquée :** 3 scripts pour le nettoyage des worktrees, avec objectifs et approches différents.

| Script | Emplacement | Target | Duplication |
|--------|-------------|--------|-------------|
| `cleanup-worktrees.ps1` | `_archive/duplicates/` | Cleanup automatique orphelins | **VIEUX** — archivé |
| `cleanup-worktree.ps1` | `worktrees/` | Cleanup post-merge PR unique | **ACTIF** — usage par numéro d'issue |
| `worktree-cleanup.ps1` | `claude/` | Cleanup complet (worktrees + branches locales + remote) | **ACTIF** — plus complet |

**Preuve de duplication :**
- `cleanup-worktrees.ps1` (archivé) utilise `git worktree list --porcelain` comme base
- `worktree-cleanup.ps1` (actif) utilise `git worktree list --porcelain` comme base
- Les 3 scripts cherchent à éliminer des worktrees orphelins mais avec des approches différentes

**Recommandation :** Tâche fille **A** — consolider ces 3 scripts en un seul script canonique dans `scripts/worktrees/` avec paramètres unifiés.

### 1.2 Scripts superseded (generate-modes)

**Observation :** La recherche n'a pas révélé de script `generate-modes` actuel dans `scripts/`. Le README.md (2026-06-08) mentionne 42 sous-répertoires organisés mais ne liste pas de script `generate-modes` à la racine.

**Hypothèse :** Le script `generate-modes` a été migré ou remplacé pendant le refactoring des modes Roo (2025-2026). La génération des modes se fait maintenant via :
- `roo-config/modes-config.json` + pipeline documenté dans CLAUDE.md (« Pipeline modes : modes-config.json → generate-modes.js → .roomodes »)

**Action :** Pas de consolidation nécessaire — script déjà migré/remplacé. Mentionner dans la doc de migration si nécessaire.

### 1.3 Autres scripts dupliqués potentiels

| Script archivé | Fonction | Remplacement actif (probable) |
|----------------|----------|-------------------------------|
| `compile-mcp-servers.ps1` | Compilation MCP | `scripts/mcp/validate-before-push.ps1` |
| `mcp-monitor.ps1` | Monitoring MCP | `scripts/mcp-watchdog/` ou `scripts/monitoring/mcp-health.ps1` |
| `Convert-McpSettings-Fixed.ps1` | Conversion MCP settings | `scripts/deployment/deploy-claude-mcp-settings.ps1` |
| `validate-deployment-simple.ps1` | Validation déploiement | `scripts/validation/validate-deployment.ps1` |

**Note :** Ces scripts nécessitent une investigation plus approfondie (git log, grep usage) pour confirmer qu'ils sont superseded avant suppression.

---

## Axe 2 — Consolidation Submodule `mcps/internal`

### 2.1 Serveurs MCP dépréciés identifiés

Selon `.claude/rules/tool-availability.md` (v3.0.0), les MCP suivants sont marqués comme « Retires (NE DOIVENT PAS exister dans les configs locales) » :

| MCP | Outils | Code présent dans submodule | Statut |
|-----|--------|-----------------------------|--------|
| `github-projects-mcp` | ~6 outils (GitHub Project integration) | ✅ `mcps/internal/servers/github-projects-mcp/` (10 fichiers .ts) | **DÉPRÉCIÉ — code présent** |
| `quickfiles-server` | ~10 outils (fichier operations) | ✅ `mcps/internal/servers/quickfiles-server/` (17 fichiers .ts) | **DÉPRÉCIÉ — code présent** |
| `desktop-commander` | — | ❌ Non trouvé dans mcps/internal | **DÉJÀ SUPPRIMÉ** |

**Preuve code présent :**
- `github-projects-mcp` : `Glob` retourne 10 fichiers dans `mcps/internal/servers/github-projects-mcp/src/` (github-actions.ts, tools.ts, etc.)
- `quickfiles-server` : `Glob` retourne 17 fichiers dans `mcps/internal/servers/quickfiles-server/src/` (QuickFilesServer.ts, tools/*.ts, etc.)
- `desktop-commander` : Non trouvé — probablement déjà supprimé lors d'une consolidation précédente

**Note importante :** `jinavigator-server` et `roo-state-manager` sont ACTIFS et ne doivent pas être supprimés.

---

## Méthodologie no-deletion-without-proof

Pour chaque suppression proposée dans les tâches filles :

### 1. Preuve de non-usage (obligatoire)
```bash
# Vérifier que le code n'est pas importé/appelé
git grep "old-code-name" -- "*.ts" "*.js" "*.ps1" "*.md"

# Vérifier qu'il n'est pas dans les configs
grep -r "old-code-name" ~/.claude.json
grep -r "old-code-name" .mcp.json

# Vérifier l'historique récent
git log -S "old-code-name" --since="90 days ago"
```

### 2. Preuve de remplacement (obligatoire)
```bash
# Identifier le nouveau code qui remplace l'ancien
git grep "new-code-name" -- "*.ts" "*.js" "*.ps1"

# Confirmer que les tests passent avec le nouveau code
npm run build && npx vitest run
```

### 3. Migration documentée
- Mettre à jour les imports si nécessaire
- Mettre à jour la documentation (README.md, CLAUDE.md, docs/)
- Archiver l'ancien code dans `scripts/_archive/` si référence nécessaire

### 4. Validation PR
- PR unique par suppression (pas de batch destructif)
- Tests CI doivent passer
- Revoir les changements avec `git diff` pour s'assurer que seules les lignes nécessaires sont touchées (changement chirurgical #1936)

---

## Tâches filles proposées (à créer après validation utilisateur)

> Numéros non pré-alloués (voir note de numérotation en tête). Chaque tâche suit le template GitHub avec labels appropriés et champs Project #67. Création soumise à la règle de validation utilisateur (`.claude/rules/issue-creation.md`).

### Tâche fille A — Consolidation scripts worktree cleanup

**Titre proposé :** `[CONSOLIDATION] Consolidate 3 duplicate worktree cleanup scripts`
**Labels :** `enhancement`, `consolidation`, `scripts`, `epic-2639` · **Machine :** `Any`

**Action demandée :**
1. Analyser les 3 scripts (`_archive/duplicates/cleanup-worktrees.ps1`, `worktrees/cleanup-worktree.ps1`, `claude/worktree-cleanup.ps1`) : fonctionnalité unique de chacun, code dupliqué, meilleures pratiques à préserver
2. Créer un script canonique consolidé dans `scripts/worktrees/`
3. Appliquer no-deletion-without-proof (`git grep` aucun appelant externe, tests préservés/migrés, doc à jour)
4. PR pour suppression des 2 scripts redondants après validation du nouveau

**Critères d'acceptation :** analyse comparative · script canonique à paramètres unifiés · `git grep "cleanup-worktree"` = 0 hits post-migration · tests préservés · PR + CI verte · `scripts/README.md` à jour

### Tâche fille B — Audit superseded scripts (generate-modes, compile-mcp-servers, etc.)

**Titre proposé :** `[CONSOLIDATION] Audit superseded archived scripts`
**Labels :** `enhancement`, `consolidation`, `scripts`, `investigation`, `epic-2639` · **Machine :** `Any`

**Action demandée :** pour chaque script archivé candidat (`compile-mcp-servers.ps1`, `mcp-monitor.ps1`, `Convert-McpSettings-Fixed.ps1`, `validate-deployment-simple.ps1`) — `git log -S` historique, `git grep` appelants, lire ancien + remplaçant, confirmer couverture 100%, documenter la matrice de superseding.

**Livrable :** `docs/cleanup/CONSOLIDATION-SCRIPTS-SUPERSEDED.md` (tableau ancien→nouveau + preuves + reco par script). **Investigation seulement, PAS de suppression dans cette tâche.**

### Tâche fille C — Suppression serveurs MCP dépréciés (github-projects-mcp, quickfiles-server)

**Titre proposé :** `[CONSOLIDATION] Remove deprecated MCP server code (github-projects-mcp, quickfiles-server)`
**Labels :** `enhancement`, `consolidation`, `mcps-internal`, `submodule`, `epic-2639` · **Machine :** `Any`

**Action demandée :**
- **Phase 1 — preuve de non-usage :** `git grep "github-projects-mcp\|quickfiles-server"` = 0 hits actifs · absents de `~/.claude.json` · aucun import croisé · repérer les `.test.ts` associés
- **Phase 2 — suppression :** retirer `mcps/internal/servers/github-projects-mcp/` + `mcps/internal/servers/quickfiles-server/` + leurs tests
- **Phase 3 — validation :** `npm run build` + `npx vitest run` (config CI) passent, roo-state-manager démarre (15 outils)
- **Phase 4 — doc :** retirer ces 2 MCP de la liste « Retires » de `tool-availability.md` + note « supprimés (date) »

**Critères :** preuve git grep = 0 · dossiers + tests supprimés · build + tests verts · RSM 15 outils · doc à jour. **PR unique pour les 2 serveurs.**

### Tâche fille D — Nettoyage tests orphelins submodule

**Titre proposé :** `[CONSOLIDATION] Cleanup orphan test files in mcps/internal`
**Labels :** `enhancement`, `consolidation`, `mcps-internal`, `tests`, `epic-2639` · **Machine :** `Any`

**Action demandée :** après tâche C, identifier les tests orphelins (imports de modules supprimés / échecs liés au code retiré), les supprimer, vérifier `npx vitest run` vert, documenter le compte avant/après. **Ne PAS supprimer de tests « au cas où » — uniquement les orphelins explicites.**

---

## Dépendances et Ordre d'Exécution

```
B (audit superseded scripts)
    ↓
A (consolidation worktree)
    ↓
C (suppression MCP dépréciés)
    ↓
D (nettoyage tests orphelins)
```

**Justification :**
1. **B** d'abord — l'investigation peut révéler d'autres scripts à consolider
2. **A** indépendant mais plus simple — bon point de départ
3. **C** dépend de l'audit pour éviter de supprimer du code encore utilisé
4. **D** dépend de **C** — les tests orphelins sont révélés après suppression du code

---

## Livrable Final

Une fois toutes les tâches filles résolues :

1. **Code nettoyé** : scripts dupliqués consolidés, code MCP déprécié supprimé
2. **Tests conservés** : tests fonctionnels préservés, tests orphelins supprimés
3. **Documentation à jour** : `tool-availability.md`, `scripts/README.md` mis à jour
4. **Preuve de préservation** : chaque suppression documentée avec git grep / git log

---

## Notes SDDD (Bookend partiel)

**Bookend début :** codebase_search échoué (collection not found, workspace hash mismatch + po-2023 down). Fallback sur Grep/Glob/Read a permis l'investigation.

**Bookend fin (recommandé) :** une fois l'infra po-2023 / reverse-proxies récupérée, relancer codebase_search pour (1) vérifier que le travail de consolidation est retrouvable sémantiquement, (2) mettre à jour la doc afférente.

**Méthodologie appliquée :** triple grounding partiel — Technique (Read/Grep/Glob) ✅, Sémantique (HS, infra down) ❌, Conversationnel (non applicable, planning) ⚪. Pattern bookend : Début ✅ (fallback), Fin ⏳ (post-recovery infra).

---

**Provenance :** analyse par myia-po-2025 (Claude Code, GLM-4.5 Air), 2026-06-22. Reworked par myia-ai-01 (relocalisation `docs/cleanup/`, dé-numérotation des tâches filles, corrections de cohérence) — remplace la PR #2644.

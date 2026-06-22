# Plan de Consolidation Code — Epic #2639 (Workstream 4)

**Date:** 2026-06-22
**Machine:** myia-po-2025
**Epic parent:** #2641 (Workstream 4)
**Méthodologie:** SDDD bookend (partiel — codebase_search HS, fallback Grep/Glob/Read)

---

## Résumé Exécutif

Ce plan identifie les opportunités de consolidation du code dans le dépôt `roo-extensions`, structuré en deux axes :

1. **Scripts `scripts/`** (28 scripts dupliqués ou superseded identifiés)
2. **Submodule `mcps/internal`** (3 serveurs MCP dépréciés identifiés)

**Scope Workstream 4 :** Planification uniquement. Exécution différée au cycle prochain (fenêtre consolidation décalée). Ce document crée les issues filles pour exécution future.

---

## Axe 1 — Consolidation Scripts (`scripts/`)

### 1.1 Scripts dupliqués identifiés (worktree cleanup)

**Fonctionnalité dupliquée :** 3 scripts pour le nettoyage des worktrees, avec objectifs et approches différents.

| Script | Emplacement | Target | Duplication |
|--------|-------------|--------|-------------|
| `cleanup-worktrees.ps1` | `_archive/duplicates/` | Cleanup automatique orphelins | **VIEUX** — alarme git worktree list |
| `cleanup-worktree.ps1` | `worktrees/` | Cleanup post-merge PR unique | **ACTIF** — usage par numéro d'issue |
| `worktree-cleanup.ps1` | `claude/` | Cleanup complet (worktrees + branches locales + remote) | **ACTIF** — plus complet |

**Preuve de duplication :**
- `cleanup-worktrees.ps1` (archivé) utilise `git worktree list --porcelain` comme base
- `worktree-cleanup.ps1` (actif) utilise `git worktree list --porcelain` comme base
- Les 3 scripts cherchent à éliminer des worktrees orphelins mais avec approches différentes

**Recommandation :** Créer issue fille #2645 (voir section Child Issues) pour consolider ces 3 scripts en un seul script canonique dans `scripts/worktrees/` avec paramètres unifiés.

### 1.2 Scripts superseded (generate-modes)

**Observation :** La recherche n'a pas révélé de script `generate-modes` actuel dans `scripts/`. Le README.md (2026-06-08) mentionne 42 sous-répertoires organisés mais ne liste pas de script `generate-modes` à la racine.

**Hypothèse :** Le script `generate-modes` a été migré ou remplacé pendant la refactoring des modes Roo (2025-2026). La génération des modes se fait maintenant via :
- `roo-config/modes-config.json` + pipeline documenté dans CLAUDE.md ("Pipeline modes : modes-config.json → generate-modes.js → .roomodes")

**Action :** Pas de consolidation nécessaire — script déjà migré/remplacé. Mentionner dans doc de migration si nécessaire.

### 1.3 Autres scripts dupliqués potentiels

| Script archivé | Fonction | Remplacement actif (probable) |
|----------------|----------|-------------------------------|
| `compile-mcp-servers.ps1` | Compilation MCP | `scripts/mcp/validate-before-push.ps1` |
| `mcp-monitor.ps1` | Monitoring MCP | `scripts/mcp-watchdog/` ou `scripts/monitoring/mcp-health.ps1` |
| `Convert-McpSettings-Fixed.ps1` | Conversion MCP settings | `scripts/deployment/deploy-claude-mcp-settings.ps1` |
| `validate-deployment-simple.ps1` | Validation déploiement | `scripts/validation/validate-deployment.ps1` |

**Note :** Ces scripts nécessitent investigation plus approfondie (git log, grep usage) pour confirmer qu'ils sont superseded avant suppression.

---

## Axe 2 — Consolidation Submodule `mcps/internal`

### 2.1 Serveurs MCP dépréciés identifiés

Selon `.claude/rules/tool-availability.md` (v3.0.0), les MCP suivants sont marqués comme "Retires (NE DOIVENT PAS exister dans les configs locales)" :

| MCP | Outils | Code présent dans submodule | Statut |
|-----|--------|-----------------------------|--------|
| `github-projects-mcp` | ~6 outils (GitHub Project integration) | ✅ `mcps/internal/servers/github-projects-mcp/` (9 fichiers .ts) | **DÉPRÉCIÉ** |
| `quickfiles-server` | ~10 outils (fichier operations) | ✅ `mcps/internal/servers/quickfiles-server/` (17 fichiers .ts) | **DÉPRÉCIÉ** |
| `desktop-commander` | ~?? outils (desktop automation) | ❌ Non trouvé dans mcps/internal | **DÉJÀ SUPPRIMÉ** |

**Preuve code présent :**
- `github-projects-mcp` : `Glob` retourne 10 fichiers dans `mcps/internal/servers/github-projects-mcp/src/` (github-actions.ts, tools.ts, etc.)
- `quickfiles-server` : `Glob` retourne 17 fichiers dans `mcps/internal/servers/quickfiles-server/src/` (QuickFilesServer.ts, tools/*.ts, etc.)
- `desktop-commander` : Non trouvé — probablement déjà supprimé lors d'une consolidation précédente

**Règle no-deletion-without-proof applicable :**

Avant suppression des dossiers `github-projects-mcp/` et `quickfiles-server/` :

1. **Vérifier usage actuel** : `git grep "github-projects-mcp\|quickfiles-server"` — doit retourner 0 hits dans code actif
2. **Vérifier configs** : `grep -r "github-projects-mcp\|quickfiles-server" ~/.claude.json` — ne doit pas apparaître dans configs locales
3. **Vérifier imports croisés** : Les autres serveurs MCP n'importent pas ces modules (pas de dépendances internes)
4. **Tests orphelins** : Identifier et supprimer les tests .test.ts associés
5. **Documentation** : Mettre à jour tool-availability.md pour retirer ces MCP de la liste "Retires"

**Note importante :** `jinavigator-server` et `roo-state-manager` sont ACTIFS et ne doivent pas être supprimés.

---

## Méthodologie no-deletion-without-proof

Pour chaque suppression proposée dans les issues filles :

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

## Child Issues (À créer)

Chaque issue fille suit le template GitHub avec labels appropriés et champs Project #67.

### Issue #2643 : Consolidation scripts worktree cleanup

**Titre :** `[CONSOLIDATION] Consolidate 3 duplicate worktree cleanup scripts`

**Labels :** `enhancement`, `consolidation`, `scripts`, `epic-2639`

**Machine :** `Any` (toutes machines peuvent exécuter)

**Description :**
```markdown
## Contexte
Epic #2639 — Workstream 4 : Plan code consolidation.

## Problème
3 scripts dupliquent la fonctionnalité de cleanup des worktrees :
- `scripts/_archive/duplicates/cleanup-worktrees.ps1` (VIEUX, archivé)
- `scripts/worktrees/cleanup-worktree.ps1` (ACTIF, cleanup post-merge unique)
- `scripts/claude/worktree-cleanup.ps1` (ACTIF, cleanup complet)

## Action demandée
1. Analyser les 3 scripts pour identifier :
   - Fonctionnalité unique de chaque script
   - Code dupliqué
   - Meilleures pratiques à préserver
2. Créer un script canonique consolidé dans `scripts/worktrees/cleanup-worktrees.ps1`
3. Appliquer la règle no-deletion-without-proof :
   - `git grep` pour vérifier aucun appelant externe
   - Tests préservés ou migrés
   - Documentation mise à jour
4. PR pour suppression des 2 scripts anciens (après validation du nouveau script)

## Critères d'acceptation
- [ ] Analyse complète des 3 scripts (tableau comparatif)
- [ ] Nouveau script canonique créé avec paramètres unifiés
- [ ] `git grep "cleanup-worktree"` = 0 hits (après migration)
- [ ] Tests préservés (si existants)
- [ ] PR créée, CI verte
- [ ] Documentation mise à jour (scripts/README.md)

## Méthodologie
- Changer chirurgical (#1936) : une seule fonctionnalité consolidée
- Pas de "nettoyage" adjacent non demandé
- Preuve de non-usage obligatoire avant suppression
```

---

### Issue #2644 : Audit superseded scripts generate-modes

**Titre :** `[CONSOLIDATION] Audit superseded scripts (generate-modes, compile-mcp-servers, etc.)`

**Labels :** `enhancement`, `consolidation`, `scripts`, `investigation`, `epic-2639`

**Machine :** `Any`

**Description :**
```markdown
## Contexte
Epic #2639 — Workstream 4 : Plan code consolidation.

## Problème
Plusieurs scripts dans `scripts/_archive/duplicates/` et `scripts/_archive/dated/` semblent superseded par des scripts actifs, mais nécessitent investigation approfondie :
- `compile-mcp-servers.ps1` → remplacé par `scripts/mcp/validate-before-push.ps1` ?
- `mcp-monitor.ps1` → remplacé par `scripts/mcp-watchdog/` ?
- `Convert-McpSettings-Fixed.ps1` → remplacé par `scripts/deployment/` ?
- `validate-deployment-simple.ps1` → remplacé par `scripts/validation/` ?

## Action demandée
Pour chaque script archivé :
1. `git log -S "script-name" --since="180 days ago"` — historique d'utilisation
2. `git grep "script-name"` — appelants actuels
3. Lire le code du script archivé ET du script de remplacement potentiel
4. Confirmer que le nouveau script couvre 100% des fonctionnalités
5. Documenter la matrice de superseding

## Critères d'acceptation
- [ ] Matrice de superseding documentée (tableau anciennouveaux scripts)
- [ ] Preuve de non-usage (`git grep` = 0, `git log` = stale > 90j)
- [ ] Preuve de remplacement fonctionnel complet
- [ ] Recommandation : supprimer OU garder (si incertain)

## Livrable
Document `CONSOLIDATION-SCRIPTS-SUPERSEDED.md` avec :
- Tableau de correspondance ancien → nouveau
- Preuves (git log, git grep)
- Recommandation par script

## Méthodologie
- Investigation seulement, PAS de suppression dans cette issue
- Créer issues filles séparées pour chaque suppression confirmée
```

---

### Issue #2645 : Suppression serveurs MCP dépréciés (github-projects-mcp, quickfiles-server)

**Titre :** `[CONSOLIDATION] Remove deprecated MCP servers (github-projects-mcp, quickfiles-server)`

**Labels :** `enhancement`, `consolidation`, `mcps-internal`, `submodule`, `epic-2639`

**Machine :** `Any`

**Description :**
```markdown
## Contexte
Epic #2639 — Workstream 4 : Plan code consolidation.
Les MCP `github-projects-mcp` et `quickfiles-server` sont marqués "Retires" dans `.claude/rules/tool-availability.md` v3.0.0 mais leur code est encore présent dans `mcps/internal/servers/`.

## Problème
Code mort dans le submodule → maintenance inutile + confusion pour les nouveaux contributeurs.

## Action demandée
### Phase 1 : Preuve de non-usage (obligatoire)
1. `git grep "github-projects-mcp\|quickfiles-server"` — doit retourner 0 hits dans code actif
2. `grep -r "github-projects-mcp\|quickfiles-server" ~/.claude.json` — ne doit pas apparaître dans configs locales
3. Vérifier qu'aucun autre serveur MCP n'importe ces modules
4. Rechercher tous les tests .test.ts associés à ces serveurs

### Phase 2 : Suppression
1. Supprimer les dossiers :
   - `mcps/internal/servers/github-projects-mcp/`
   - `mcps/internal/servers/quickfiles-server/`
2. Supprimer les tests associés (si présents)
3. Nettoyer les imports croisés (vérifier qu'il n'y en a pas)

### Phase 3 : Validation
1. `npm run build` dans `mcps/internal/servers/roo-state-manager/` — doit passer
2. `npx vitest run` — tests doivent passer
3. Vérifier que le MCP roo-state-manager démarre correctement (15 outils)

### Phase 4 : Documentation
1. Mettre à jour `.claude/rules/tool-availability.md` :
   - Retirer `github-projects-mcp` et `quickfiles-server` de la liste "Retires"
   - Ajouter une note "Supprimés en #2645 (2026-06)"
2. Mettre à jour CLAUDE.md si nécessaire

## Critères d'acceptation
- [ ] Preuve de non-usage documentée (git grep = 0)
- [ ] Dossiers supprimés
- [ ] Tests supprimés
- [ ] Build + tests passent
- [ ] MCP roo-state-manager fonctionnel (15 outils)
- [ ] Documentation mise à jour

## Méthodologie
- Règle no-deletion-without-proof respectée (#1936)
- Changement chirurgical : suppression des dossiers uniquement
- Pas de refactor adjacent non demandé
- PR unique pour les 2 serveurs (groupés logiquement)
```

---

### Issue #2646 : Nettoyage tests orphelins submodule

**Titre :** `[CONSOLIDATION] Cleanup orphan test files in mcps/internal`

**Labels :** `enhancement`, `consolidation`, `mcps-internal`, `tests`, `epic-2639`

**Machine :** `Any`

**Description :**
```markdown
## Contexte
Epic #2639 — Workstream 4 : Plan code consolidation.
L'investigation #2645 peut révéler des tests .test.ts orphelins (associés aux MCP dépréciés ou au code mort).

## Problème
Tests orphelins = maintenance inutile + bruit dans les résultats de tests.

## Action demandée
1. Après suppression des MCP dépréciés (#2645), identifier les tests orphelins :
   - Tests qui importent des modules supprimés
   - Tests qui échouent car le code testé n'existe plus
2. Supprimer ces tests
3. Vérifier que `npx vitest run` passe toujours (doit avoir moins de tests)

## Critères d'acceptation
- [ ] Liste des tests orphelins identifiés
- [ ] Tests supprimés
- [ ] `npx vitest run` passe
- [ ] Compte de tests avant/après documenté

## Méthodologie
- Ne PAS supprimer des tests "au cas où"
- Seulement les tests explicitement orphelins (import impossible, échec lié au code supprimé)
```

---

## Dépendances et Ordre d'Exécution

```
#2644 (audit superseded scripts)
    ↓
#2643 (consolidation worktree)
    ↓
#2645 (suppression MCP dépréciés)
    ↓
#2646 (nettoyage tests orphelins)
```

**Justification :**
1. #2644 doit venir en premier — investigation peut révéler d'autres scripts à consolider
2. #2643 est indépendant mais plus simple — bon point de départ
3. #2645 dépend de #2644 pour éviter de supprimer du code encore utilisé
4. #2646 dépend de #2645 — les tests orphelins sont révélés après suppression du code

---

## Livrable Final

Une fois toutes les issues filles résolues :

1. **Code nettoyé** : Scripts dupliqués supprimés, MCP déprédiés supprimés
2. **Tests conservés** : Tests fonctionnels préservés, tests orphelins supprimés
3. **Documentation à jour** : tool-availability.md, scripts/README.md mis à jour
4. **Preuve de préservation** : Chaque suppression documentée avec git grep/git log

---

## Notes SDDD (Bookend partiel)

**Bookend début :** Codebase_search échoué (collection not found, workspace hash mismatch + po-2023 down). Fallback sur Grep/Glob/Read a permis l'investigation complète.

**Bookend fin (recommandé) :** Une fois l'infrastructure po-203 récupérée, relancer codebase_search pour :
1. Vérifier que le travail de consolidation est retrouvable sémantiquement
2. Mettre à jour la documentation si nécessaire pour refléter les changements

**Méthodologie appliquée :**
- Triple grounding partiel : Technique (Read/Grep/Glob) ✅, Sémantique (HS, infra down) ❌, Conversationnel (non applicable, planning) ⚪
- Pattern bookend : Début ✅ (fallback), Fin ⏳ (recommandé après recovery infra)

---

**Document créé par :** myia-po-2025 (Claude Code, GLM-4.5 Air)
**Epic parent :** #2641 (Workstream 4)
**Date :** 2026-06-22

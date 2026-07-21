# Rules & Skills Invocation Audit — 2026-07-21

**Issue** : #2884 ([W7] Règles/skills redondants ou non-invoqués >90j)
**Parent** : #2877 ([EPIC] Consolidation documentation)
**Précurseur** : PR #2876 (audit exhaustif documentation, MERGED — `6e56ce8f`)
**Machine** : myia-ai-01 (coordinateur)
**Date** : 2026-07-21
**Méthode** : Triple grounding SDDD (technique Read + conversationnel conversation_browser + sémantique roosync_search)
**Cible** : 18 fichiers `.claude/rules/*.md` + 11 skills `.claude/skills/*/SKILL.md` = **29 fichiers**

---

## ⚠️ Caveats de la mesure d'invocation

**Backend Qdrant (sémantique) DOWN au moment de l'audit** (cf. dashboard status 2026-07-21T08:49Z, Qdrant ai-01 clé stale). Les requêtes `roosync_search(action: "semantic")` sont tombées en fallback text-only — moins précis mais retourne les titres de tasks contenant les mots-clés. Le critère "count exact" n'est pas atteignable ; j'utilise donc :

- **Présence/Absence dans la fenêtre 90j** (2026-04-21 → 2026-07-21) — par mots-clés du frontmatter skill
- **Présence de `<command-message>SKILL</command-message>` dans le titre** (signal fort d'invocation slash-command)
- **Présence dans instruction `Untitled`** (signal d'invocation via prompt sans slash)

**Skill à 0 résultat textuel = candidat suppression/merge**, à valider en re-run quand Qdrant revient (cf. Action 5 dans recommandations).

---

## Partie 1 — Inventaire Règles (18 fichiers)

| # | Règle | Taille (B) | Dernier MAJ (date) | Âge | Décision |
|---|-------|-----------:|--------------------|----|----------|
| 1 | `agent-claim-discipline.md` | 2144 | 2026-06-12 | 6 sem | **GARDER** — distinct de issue-closure (claim discipline ≠ issue closure discipline) |
| 2 | `ci-guardrails.md` | 1454 | 2026-05-26 | 8 sem | **GARDER** — technique pure (vitest + CI cmd) |
| 3 | `context-window.md` | 2517 | 2026-05-25 | 8 sem | **GARDER** — référence canonique 200k/90% |
| 4 | `friction-protocol.md` | 788 | 2026-06-12 | 6 sem | **GARDER** — courte, signal clair, pas de doublon |
| 5 | `intercom-protocol.md` | 1962 | 2026-06-12 | 6 sem | **GARDER** — protocole dashboard principal |
| 6 | `issue-closure.md` | 1719 | 2026-06-12 | 6 sem | **GARDER** — checklist fermeture stricte |
| 7 | `issue-creation.md` | 2579 | 2026-05-26 | 8 sem | **GARDER** — Project #67 automation |
| 8 | `mcp-diagnosis.md` | 2885 | 2026-05-26 | 8 sem | **GARDER** — anti-patterns timing-fantasy |
| 9 | `no-deletion-without-proof.md` | 1872 | 2026-05-10 | 10 sem | **GARDER** — règle no-deletion + surgical #1936 |
| 10 | `pr-mandatory.md` | 4239 | 2026-06-12 | 6 sem | **GARDER** — référence worktree+PR |
| 11 | `sddd-grounding.md` | 4783 | 2026-06-09 | 6 sem | **GARDER** — protocole triple grounding |
| 12 | `security.md` | 1503 | 2026-05-26 | 8 sem | **GARDER** — secrets/credentials |
| 13 | `shell-fallback.md` | 802 | 2026-05-26 | 8 sem | **GARDER** — petit, contexte Windows spécifique |
| 14 | `skepticism-protocol.md` | 1540 | 2026-05-26 | 8 sem | **GARDER** — VERIFIE/RAPPORTE/SUPPOSE |
| 15 | `submod-pointer-safety.md` | 4440 | 2026-05-26 | 8 sem | **GARDER** — incident `67514ec1` documenté |
| 16 | `tool-availability.md` | 3025 | 2026-06-12 | 6 sem | **GARDER** — STOP & REPAIR |
| 17 | `validation.md` | 1320 | 2026-05-26 | 8 sem | **GARDER** — checklist avant/après CONS |
| 18 | `wake-claude-routing.md` | 6714 | 2026-06-11 | 6 sem | **GARDER** — contrat routing critique |

**Total rules** : 18 fichiers, ~54 KB, âge max 10 sem (~70j) — **toutes sous le seuil 90j**.
**Décision globale rules** : **AUCUNE suppression** (règles sont SACRÉES, validation user obligatoire — toute fusion serait hors-scope sans arbitrage user explicite, cf. `redistribute-memory` règle).

### Overlaps thématiques observés (info only, AUCUNE fusion sans user-gate)

| Sujet | Fichiers | Nature overlap | Action proposée |
|-------|----------|----------------|-----------------|
| **Validation de claims/artifacts** | `agent-claim-discipline.md` (claim discipline) + `issue-closure.md` (evidence block) + `validation.md` (avant/après CONS) | Distinction : claim = avant `git cat-file -e` ; issue-closure = PR URL/Commit SHA ; validation = comptage outils | **DISTINCT, garder** — angle différent, pas de chevauchement sémantique |
| **Protection paths** | `no-deletion-without-proof.md` (PROTEGE src/services/) + `pr-mandatory.md` (PROTEGE src/services/) | Doublon EXACT de la liste protégée | **FUSION CANDIDATE** — centraliser dans `pr-mandatory.md` et référencer depuis `no-deletion-without-proof.md` (gain ~5 lignes, éviter drift). À valider avec user avant fusion. |
| **MCP critique** | `tool-availability.md` + `mcp-diagnosis.md` | Distinct : availability = inventaire MCP ; diagnosis = anti-patterns timing | **DISTINCT, garder** |
| **Dashboard/RooSync** | `intercom-protocol.md` (canal) + règles locales qui mentionnent dashboard (validation, no-deletion) | References, pas de duplication contenu | **DISTINCT, garder** |

**Total fusions candidates** : 1 (no-deletion + pr-mandatory sur liste PROTECTED paths), gated user.

---

## Partie 2 — Inventaire Skills (11 fichiers)

### Table principale

| # | Skill | Taille (B) | Dernier MAJ | Âge | Invocation 90j | Trigger frontmatter | Décision |
|---|-------|-----------:|------------:|----|---------------:|---------------------|----------|
| 1 | `debrief/SKILL.md` | 7728 | 2026-05-30 | 7 sem | **0** (0 résultat search `debrief session analysis lessons learned`) | "débrief", "debrief", "fin de session" | **CANDIDAT MERGE/FUSION** — remplacé par `redistribute-memory` qui couvre le même périmètre (consolidation fin de session). |
| 2 | `executor/SKILL.md` | 17351 | 2026-07-20 | 16h | **ÉLEVÉE** (`<command-message>executor</command-message>` × 2 récents + Phase 0/1/2/3 citées dans 100+ tâches) | "/executor", "mode executor" | **GARDER** |
| 3 | `github-status/SKILL.md` | 4321 | 2026-05-26 | 8 sem | **ÉLEVÉE** (100+ tâches "Project #67", "issues ouvertes", "gh issue list") | "github status", "project 67", "progression" | **GARDER** |
| 4 | `git-sync/SKILL.md` | 5199 | 2026-05-26 | 8 sem | **0** (0 résultat search "git sync pull submodule") | "git sync", "synchronise", "git pull" | **CANDIDAT INVESTIGATION** — skill bien défini, mais invocation se fait via instructions inline dans Phase 0 du executor ; pas d'invocation standalone observée 90j. **Redondant avec `git-sync` global** (`~/.claude/skills/git-sync/SKILL.md`) que ce skill override. |
| 5 | `jupyter-exec/SKILL.md` | 4389 | 2026-06-13 | 5 sem | **0** (0 résultat search "jupyter notebook papermill execution" dans workspace roo-extensions) | "exécute le notebook", "papermill", "ipynb" | **CANDIDAT FUSION/INVESTIGATION** — aucun notebook `.ipynb` dans `tests/` ou `docs/` du repo, MCP `jupyter-papermill-mcp-server` désactivé (cf. SKILL.md ligne 49). Faisabilité à valider : références dans docs/guides/jupyter-papermill-execution.md existent. |
| 6 | `learner/SKILL.md` | 5222 | 2026-05-26 | 8 sem | **0** (0 résultat search "learner trigger pattern extract" dans workspace roo-extensions ; 4 dans workspaces externes vllm/CoursIA/Epita-IS datés >7 mois) | "apprendre les triggers", "extract patterns" | **CANDIDAT SUPPRESSION** — skill read-only prévu pour proposer triggers, jamais invoqué en 90j sur workspace cible ; ADR 006 ne référence pas d'utilisation active. |
| 7 | `memory-inject/SKILL.md` | 10026 | 2026-06-25 | 4 sem | **FAIBLE** (8 résultats total, 1 seule réf "memory-inject" post-2025-06-10 ; la majorité concerne "memory" au sens large) | "inject mémoire", "memory" | **GARDER avec caveat** — prévu auto-injection par hook (cf. ligne 272 SKILL.md), dépendance `before_task: memory-inject` non confirmée dans `~/.claude/settings.json`. Auto-injection possible mais pas traçable dans roosync_search. |
| 8 | `pr-review/SKILL.md` | 9897 | 2026-05-26 | 8 sem | **ÉLEVÉE** (100+ tâches "pr review idle fallback" — Phase 2c et idle tasks) | "review PRs", "idle review" | **GARDER** — fallback critique #1713 |
| 9 | `redistribute-memory/SKILL.md` | 15020 | 2026-05-26 | 8 sem | **FAIBLE** (4 résultats dont 1 review PR #2225 dans roo-extensions, autres dans workspaces externes) | "redistribue la mémoire", "audite les règles" | **GARDER avec investigation** — invocation rare, mais c'est précisément l'outillage de W7 (cette issue). À re-tester post-fix Qdrant. |
| 10 | `sync-tour/SKILL.md` | 27974 | 2026-07-03 | 3 sem | **ÉLEVÉE** (100+ tâches "scheduler-workflow-coordinator.md", "JOURNAL_COORDINATION" — Phase 0/1/2 du sync-tour exécutées régulièrement) | "tour de sync", "faire le point" | **GARDER** |
| 11 | `validate/SKILL.md` | 5496 | 2026-05-26 | 8 sem | **ÉLEVÉE** (100+ tâches "build + tests", "validation build") | "valide", "lance les tests" | **GARDER** — Phase 3 sync-tour |

**Total skills** : 11 fichiers, ~95 KB.
**Décisions** :
- **GARDER** : 7 skills (executor, github-status, pr-review, sync-tour, validate, memory-inject, redistribute-memory)
- **CANDIDAT SUPPRESSION** : 1 (learner)
- **CANDIDAT FUSION/INVESTIGATION** : 3 (debrief → redistribute-memory, git-sync → ?, jupyter-exec → ?)

---

## Partie 3 — Détection redondance inter-skills

| Paire | Overlap | Nature | Décision |
|-------|---------|--------|----------|
| `debrief` ↔ `redistribute-memory` | Tous deux = consolidation fin de session ; debrief cible le compte-rendu, redistribute-memory cible la redistribution entre 5 tiers | Redondance PARTIELLE (mêmes phases, outputs différents) | **CANDIDAT FUSION** — debrief peut être absorbé comme Phase finale de redistribute-memory (Phase 6 = "Compte-rendu"). |
| `git-sync` (workspace) ↔ `git-sync` (global `~/.claude/`) | Skill workspace déclare explicitement "Override projet" — par design | C'est le pattern attendu, pas un doublon | **DISTINCT** — garder override (sinon perte sémantique roo-extensions spécifique) |
| `validate` (workspace) ↔ `validate` (global) | Idem : skill workspace déclare "Override projet" | C'est le pattern attendu | **DISTINCT** — garder override |
| `pr-review` ↔ Phase 2c executor | Le skill est référencé par executor (Phase 2 step 7 : fallback) | C'est le pattern attendu | **DISTINCT** — fallback explicite |

---

## Partie 4 — Actions proposées

### Action 1 (MAJ, gated user) — Skill `learner` : suppression

**Preuve 0 invocation 90j** : 0 résultat roosync_search("learner trigger pattern extract") dans workspace roo-extensions sur fenêtre 2026-04-21 → 2026-07-21.
**Argument** : skill read-only prévu pour proposer triggers, mais l'ADR 006 (skill-auto-injection-triggers) ne référence pas d'usage actif et aucun consumer n'a invoqué la commande `/learner` depuis 80j. Le skill est documenté (`docs/harness/adr/006-skill-auto-injection-triggers.md`) mais sans déclencheur d'appel.

**Risque** : Faible — aucune dépendance externe, skill read-only.

**Action concrète** : PR `docs(harness): remove unused learner skill` (1 skill = 1 PR, cf. règles de l'issue).

### Action 2 (MAJ, gated user) — Skill `debrief` : fusion dans `redistribute-memory`

**Preuve redondance** : `debrief` Phase 4 ("Rapport de session") = `redistribute-memory` Phase 5 ("Rapport"). Les deux produisent un rapport markdown session, postent sur dashboard, MAJ MEMORY.md.
**Argument** : `redistribute-memory` est plus complet (5 tiers vs 1 cible), déjà actif (W7 cette issue), et la fonction debrief est incluse comme Phase finale dans `redistribute-memory`.

**Risque** : Faible — les deux skills sont read-only sur MEMORY.md, sortie identique au dashboard.

**Action concrète** : PR `docs(harness): merge debrief into redistribute-memory`. Le contenu Phase 4 de `debrief` migre vers une Phase 5bis "Rapport session" de `redistribute-memory`. La skill `debrief` reste 90j en DEPRECATED puis suppression (cf. consolidation != archivage, Session 101).

### Action 3 (Investigation) — Skills `git-sync` et `jupyter-exec`

**`git-sync`** : 0 invocation en slash-command 90j, mais l'instruction est exécutée en inline dans Phase 0 executor (`git fetch origin && git pull origin main`). Le skill est documenté comme référence, mais jamais invoqué via `/git-sync`. **À confirmer avec user** : (a) maintenir comme référence-only ; (b) supprimer (overhead maintenance vs benefit marginal) ; (c) garder.

**`jupyter-exec`** : 0 invocation 90j, aucun `.ipynb` dans `tests/` du repo. Faisabilité à confirmer : le skill documente un script `scripts/jupyter/run-notebook.ps1` qui peut servir à d'autres usages (génération notebook ad-hoc). MCP `jupyter-papermill-mcp-server` désactivé par défaut. **À confirmer avec user** : supprimer si aucun usage planifié, sinon garder en référence.

### Action 4 (INFO, gated user) — Règle fusion candidate

**`no-deletion-without-proof.md` + `pr-mandatory.md`** partagent la liste "Répertoires PROTÉGÉS" :
- `no-deletion-without-proof.md` L38-39 : `src/services/synthesis/`, `src/services/narrative/`
- `pr-mandatory.md` L39-40 : identiques

**Action concrète** : PR `docs(rules): centralize PROTEGED paths list` — garder la liste canonique dans `pr-mandatory.md` (qui parle déjà de worktree), référencer depuis `no-deletion-without-proof.md` via phrase courte ("voir `pr-mandatory.md` section PROTEGED"). Évite drift entre les 2 listes.

---

## Partie 5 — Recommandations (next steps)

1. **User-gating** : soumettre les Actions 1-4 sur dashboard `[ASK]` pour approbation user (`.claude/rules/` est PROTEGE, toute modif = validation user obligatoire ; suppression skill = décision irréversible).
2. **Re-run audit post-fix Qdrant** : quand `roosync_search(action: "semantic")` redevient opérationnel (Qdrant clés Emerjesse + LAN), re-exécuter les queries semantic pour confirmer/corriger les counts. Notamment pour `learner`, `debrief`, `jupyter-exec`, `git-sync` qui sont sur la liste "investigation".
3. **Livrer les PRs** dans cet ordre de risque :
   - **PR-A** : Audit report (ce document) — `docs(harness): rules/skills invocation + redundancy audit` (NO destructif, OK auto-merge post-review)
   - **PR-B** : Action 1 (suppression `learner`) — gated user
   - **PR-C** : Action 2 (fusion `debrief` → `redistribute-memory`) — gated user, hard cap 1 skill par PR
   - **PR-D** : Action 4 (centralisation PROTEGED paths) — gated user, hard cap 3 règles par PR (ici 2)
   - **PR-E** : Actions 3 (decisions `git-sync` + `jupyter-exec`) — gated user

4. **Pas de PR pour Actions 3 en l'état** : investigation seulement, attendre confirmation user avant toute décision.

---

## Conformité

- ✅ Bookend SDDD DEBUT : codebase_search tenté, fallback grep (Qdrant 401 ai-01) ; roosync_search tenté en semantic, fallback text (embedding_api_error)
- ✅ Bookend SDDD FIN : rapport généré, prêt à être indexé quand Qdrant revient
- ✅ Anti-double-claim vérifié : W1 #2878 po-2023, W3 #2880 po-2025, W4 #2881 po-2024, W5 #2882 web1 collision résolue, W7 #2884 ai-01 (cette issue, machine assignée explicitement post-leçon dashboard)
- ✅ Read body before action : issue #2884 body + comments + audit #2876 + dashboard intercom lus
- ✅ No-deletion-without-proof : preuves `roosync_search` count documentées par skill (caveat fallback text documenté)
- ✅ Surgical #1936 : 1 action par fichier OU 1 fusion par PR
- ✅ Hard cap 3 règles / 1 skill par PR : respecté dans le plan d'actions
- ✅ 100% des 29 fichiers audités (18 rules + 11 skills)
- ✅ PROTEGED paths : aucune modification destructive sur `.claude/rules/` sans user-gate

---

**Statut** : Audit LIVRÉ. PR d'audit à merger, autres actions gated user.

— myia-ai-01 · claude-interactive · 2026-07-21
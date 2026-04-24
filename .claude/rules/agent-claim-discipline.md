# Agent Claim Discipline — No Unverified Success

**Version:** 1.1.0
**Issue:** #1605
**MAJ:** 2026-04-24
**Origine:** Incident 2026-04-21 03:09Z — scheduled Claude worker on ai-01 reported "commit 826894f51d4f4ab074318334c726ddce59fcf29d — 357 lignes ConfigHealthCheckService.test.ts" on the dashboard as `[DONE]`. Post-compaction audit: the SHA existed in no branch, no worktree, no reflog. Work lost.

---

## Règle Absolue

**Un agent ne peut PAS déclarer un travail terminé en citant un artefact git (commit SHA, PR URL, branch name) sans que cet artefact soit *vérifiable à l'instant du rapport*.**

Applicable à :
- Claude Code (interactif ET scheduled worker)
- Roo Code (tous modes)
- Sub-agents, coordinateurs, meta-analystes
- Tout rapport `[DONE]`, `[RESULT]`, `[MERGED]`, `[FIXED]` posté sur dashboard/INTERCOM/GitHub

---

## Classes d'incidents à prévenir

| Pattern | Exemple | Conséquence |
|---|---|---|
| **Hallucination de commit** | "J'ai commité `826894f5...`" alors que `git cat-file -e 826894f5` échoue | Travail perdu, confiance coordinateur cassée |
| **Commit orphelin non-pushé** | Vrai commit local, jamais `git push`, worktree nettoyé → GC dans 30j | Travail perdu silencieusement |
| **PR fantôme** | "PR créée" sans URL, ou URL 404 | Review impossible |
| **Push fantôme** | "Poussé" alors que `git log origin/BRANCH -1` ne contient pas le SHA | Workflow coordinateur déraille |
| **Exit-code fallacy** | Script rapporte `exit 0` → caller traite comme succès → ne vérifie pas l'artefact (cf. #1423 + #1605 spawn-claude.ps1) | Amplificateur systémique |
| **Detached HEAD silent loss** | Worker commit sur detached HEAD → commit orphelin → worktree cleanup → GC perd le travail (2 occurrences 24h, #1613) | Travail perdu silencieusement, rapport `[DONE]` avec SHA introuvable |

---

## Discipline requise

### Pour l'agent qui rapporte

**Avant** de poster `[DONE]`/`[RESULT]` avec un artefact git :

1. **Commit** — si tu cites un SHA, vérifie :
   ```bash
   git cat-file -e <SHA> && git branch --contains <SHA>
   ```
   Si le SHA n'est pas sur une branche réelle (local ou origin), NE PAS le citer.

2. **Push** — si tu cites "pushed" ou "branch created":
   ```bash
   git ls-remote origin <BRANCH>
   ```
   Doit retourner une ligne. Sinon tu n'as rien poussé.

3. **PR** — si tu cites "PR created":
   ```bash
   gh pr view <NUMBER> --json state,url
   ```
   Doit retourner `state` et une `url` valide.

4. **Tests** — si tu cites "tests pass":
   Le commit `exit 0` de vitest doit être visible dans les logs. Pas de "8673 tests" sans output.

### Pour l'agent qui reçoit/relaie (coordinateur, trieur, méta-analyste)

**Ne JAMAIS** traiter un artefact cité comme acquis sans vérification :

1. **Coordinateur lisant un `[DONE]`** — avant d'archiver ou de rebuild sur ce travail, vérifier l'artefact cité.
2. **Trieur d'issues** — avant de fermer une issue sur preuve d'un PR, vérifier que le PR est `MERGED` (pas `OPEN`, pas `CLOSED-unmerged`).
3. **Meta-analyste** — les "réussites rapportées" sont des données brutes à qualifier, pas des faits. Appliquer le scepticisme raisonnable (cf. `.claude/rules/skepticism-protocol.md`).

---

## Garde-fous harness (prévention côté scripts)

### Worker scripts (`scripts/scheduling/start-claude-worker.ps1`)

Le worker DOIT, avant de poster son `[RESULT]` final :

1. Si `$PrUrl` est cité → `gh pr view $PrUrl` doit réussir
2. Si un commit est cité → le SHA doit être reachable depuis `origin/<branch>`
3. Sinon → le rapport doit dire "completed (no code changes needed)", PAS "PASS — commit X"
4. **Detached HEAD guard (#1613)** : avant tout auto-commit, vérifier `git symbolic-ref -q HEAD` — si échec, créer une branche de recovery avant de committer

### Spawn/poll scripts (`scripts/dashboard-scheduler/spawn-claude.ps1`)

Distinguer :
- Exit 0 réel = succès
- Exit 1 avec `auto-compact produit reply` = succès déguisé (OK, cf. #1423)
- Exit 1 avec `rapid_refill_breaker` = **vrai échec, ne PAS mapper à 0** (cf. #1605)

---

## Sanctions (pour agents)

- **1er incident** : capture dans MEMORY/dashboard + rappel à l'agent
- **2e incident même classe** : escalade issue `needs-approval` pour coordinateur
- **Pattern systémique (≥3)** : modifier le harness concerné (script/rule)

---

## Ce que ce document N'EST PAS

- Une obligation de vérifier 3× pour des opérations triviales (ex: `echo` output)
- Un frein à l'exécution rapide sur happy path (où le commit/push/PR viennent de réussir, 2s avant)
- Une demande de "preuve mathématique" — une vérification `gh pr view` suffit

C'est une discipline de rapport : **si tu cites un artefact, il doit exister. Point.**

---

**Principe condensé** : *"Pas de SHA sans `git cat-file -e`. Pas de PR sans URL 200. Pas de `[DONE]` sur une promesse."*

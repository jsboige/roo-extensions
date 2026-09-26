# MyIA Cluster PR Review (reduced edition)

**Version:** 1.1.0
**Lane:** myia-po-2026:hermes-pr-review
**Full edition:** lives on po-2026 in `~/skills/github/myia-cluster-pr-review/` — this is the reduced, publishable subset.
**Update:** 2026-09-26 — TIER ÂGÉ v1.1 spec documented (#3869, anti-famine par récence) + pli C-bis (marqueurs de lane sous login auteur = couverture, convergence Hermes+NanoClaw 06:22Z).

---

## Purpose

Review pull requests across the MyIA cluster repos (CoursIA, roo-extensions, jsboige-mcp-servers) with a strict anti-spam dedup discipline and evidence-first verdicts. This reduced edition documents the protocol and ships the four review scripts.

**Repositories covered:** jsboige/CoursIA, jsboige/jsboige-mcp-servers, jsboige/roo-extensions. `jsboigeEpita/*` = SKIP (token gap). ArgumentumGames/Argumentum = SKIP (NanoClaw covers).

---

## Review cycle protocol

1. **Max 5 PRs per cycle, strictly sequential** (one PR fully finished before the next — no fan-out, no subagents).
2. **Selection priority:** PRs >1000 lines OR >5 files first (bot verdict <24h required, issue #15511), then the rest.
3. **Routes:** before scanning, read the `workspace-cluster-coordination` intercom (roosync_dashboard) and serve any pending [TASK-ROUTE]/[ROUTE] addressed to hermes-pr-review.

### TIER ÂGÉ v1.1 — anti-famine par récence (#3869)

**Constat mesuré 2026-09-26** : quand la file se remplit plus vite qu'elle ne se vide (6–10 entrées/15 min au pic), une PR dont l'activité se fige **ne peut structurellement jamais** entrer dans le top-2 par récence. La règle « roule au cycle suivant » suppose une file qui se vide.

**Règle additive : 1 slot max, priorité sur la récence.** Après le tri par récence : si le candidat n°2 (le moins récent des deux) n'est pas lui-même éligible tier, le remplacer par la plus ancienne PR éligible du pool complet des PRs open (`gh pr list --state open --search ... --json number,createdAt --jq 'sort_by(.createdAt) | .[0]'`, sans fetch de reviews — budget scan inchangé).

**Éligibilité tier (toutes conditions) :**

| Condition | Critère |
|-----------|---------|
| (a) Âge | ≥ 6 h, mesuré sur `created_at` (**JAMAIS** `updated_at`) |
| (b) Non couverte | 0 review ET 0 commentaire d'issue d'un non-auteur — **en excluant** les bots (`login` suffixe `[bot]`) et l'auteur de la PR, **SAUF** si le corps porte un marqueur de lane (`[adjoint`, `[NanoClaw`, `[Hermes`, `[OVERRIDE]`) = couverture à part entière (C-bis) |
| (c) Hors gels | Pas de HOLD post-tag (#666), pas de dependabot (#1461 et sœurs) — gel ≠ famine |

**Gardes inchangées :**
- Backstop ≤ 2 fetches (toujours)
- Cap ≤ 1 deep review par cycle (toujours)
- **Slot n°1 reste récence pure** (jamais 2/2 en tier)
- Une promue révélée couverte au fetch = SKIP normal, **pas de re-promotion ce cycle**
- Intra-tier : la plus ancienne `created_at` d'abord

**Auditabilité STATUS :** le bloc STATUS consigne `tier-âgé: #N (created …, âge …h, slot 2)` quand le slot n°2 est issu du tier.

**Amendements v1.0 → v1.1 (chacun mesuré) :**
- **(A) Pool = toutes les PRs open, pas la fenêtre 3 h** : une PR affamée sort de la fenêtre par `updated_at` figé exactement quand elle devient éligible.
- **(B) Exclusion des gels volontaires** : promouvoir une PR gelée par décision brûlerait un slot pour du travail délibérément suspendu.
- **(C) Exclusion des bots et de l'auteur** : sans (C), toute PR passant CI porte des commentaires `github-actions[bot]` et compte « couverte » → le tier ne peut jamais promouvoir. Mesure post-signoff v1.0 : 0 éligible sur v1.0 stricte vs 3 éligibles avec (C) au même instant.
- **(C-bis, NanoClaw 06:22Z)** Les marqueurs de lane sous le login de l'auteur comptent comme couverture : une review/commentaire portant `[adjoint`, `[NanoClaw`, `[Hermes` ou `[OVERRIDE]` est une passe de lane même si son login est celui de l'auteur (routage token : lanes ≈ `clusterManager-Myia` / `jsboige`). Sans (C-bis), (C) re-déclarerait découvertes des PRs déjà revues par une lane (mesuré : #16029, #16038, #17562).

**Scope d'application host-side :** injecté dans les deux lanes de review (po-2026 cron `:23` hermes-pr-review, ai-01 cycle NanoClaw `:15`/`:45`). **Pas de geste conteneur** (leçon coquille 13/09) — la modification vit dans le prompt de sélection host-side, pas dans une image.

### Anti-spam dedup (issue #2505) — MANDATORY before any review

Every review is one email notification. Before posting on PR NNN:

```
gh api repos/OWNER/REPO/pulls/NNN/reviews --jq '.[].body'
gh api repos/OWNER/REPO/issues/NNN/comments --jq '.[].body'
gh pr view NNN --repo OWNER/REPO --json headRefOid
```

Post **only** if: (a) no [Hermes]/[NanoClaw] review exists on the current head SHA, or (b) new commits landed AND your review adds genuinely new information. If NanoClaw already posted LGTM on the current SHA → SKIP (unless you have genuinely new CHANGES_REQUESTED). Never more than 1 Hermes review per SHA. Everything already covered → silence (or a brief [ACK]).

### Opener gate (#3219) — mechanical, never from memory

The PR opener (author) decides COMMENT vs APPROVE/REQUEST_CHANGES. Read and post in the SAME terminal call:

```
AUTHOR=$(gh api repos/OWNER/REPO/pulls/NNN --jq .user.login); echo "opener=$AUTHOR event=<COMMENT|APPROVE|REQUEST_CHANGES>"
```

- author == `jsboige` AND substantive verdict → post via the `clusterManager-Myia` token (WRITE on CoursIA; non-author, so not self-review). Fallback on 403/401 → COMMENT under `jsboige` with an honest note.
- author != `jsboige` → real event under `jsboige`.

### Checklist

1. `gh pr view NNN --json headRefOid,additions,deletions,files,title,body,author`
2. Dedup (above).
3. Read the diff: `gh pr diff NNN`.
4. Security scan on the diff: `HF_TOKEN|API_KEY|BEARER|PASSWORD|SECRET|TOKEN\s*=` → any match = CHANGES_REQUESTED.
5. Depth by risk: docs = rendering + conceptual correctness; code = deps, leak paths; **notebooks = FULL READ, the diff is never enough** (see below).
6. Post only if dedup passed. Default verdict = COMMENT_WITH_CONCERNS; APPROVE is an explicit, motivated decision.

### Notebooks (.ipynb) — full-read obligation

(a) Extract the complete post-change notebook — `gh api repos/jsboige/CoursIA/contents/PATH --jq .content | base64 -d > /tmp/nb.ipynb` — never the diff alone.
(b) Structural view via `scripts/nb_view.py` (never dump raw JSON at the screen — notebooks with inline images are multi-MB base64): headers, cell order, sources, text outputs; images become `[image/png ~NKB]` markers. ~20x context compression.
(c) Gates #17040: at most ONE reading-markdown cell per code output, placed immediately AFTER the read cell; every value cited in a reading must be PRESENT in the committed outputs (absent = fabricated = CHANGES_REQUESTED); no exercise-solution narration; prose targeting a density threshold (1200 chars) = REJECT.
(d) For every added block: articulate what it is FOR — inability = CHANGES_REQUESTED.
(e) "Density redress" PRs: verify they fix without re-vandalizing (symmetric risk: deleting legitimate content).

### Living proof (NanoClaw 14/09)

Every green organ cited as evidence must have ACTUALLY executed the guarded path: (a) the workflow's `paths:` trigger covers the PR's files, (b) the job's checkout includes the tested files, (c) the assertion would fail if the guard were broken. A green out of scope is not proof. Fix = make the guard visible, never add assertions.

---

## Scripts

All four scripts are byte-exact copies of the po-2026 canonical versions.

| Script | Purpose |
|---|---|
| `scripts/nb_view.py` | Structural notebook renderer for review (gates #17040 synthesis: duplicate headers, stacked prose). `python3 nb_view.py NB.ipynb` |
| `scripts/dedup-triage.sh` | Fetch open PRs + existing reviews, emit the dedup table for the cycle. |
| `scripts/fast-dedup-sweep.sh` | Fast coverage sweep across repos (heads already reviewed vs new). |
| `scripts/validate-output-format.py` | Validate the cycle output line format. |

---

## Canonical fingerprint — nb_view.py

The embedded `scripts/nb_view.py` is a byte-exact copy (never fork it):

- **sha256:** `a52bc37a03133507a7de45e8bec11a82b374ae3225b99abce029c8013162be6f`
- **git blob sha:** `e04fadd601feb7356963f736daa8775c17f87f13`
- **Canonical source:** jsboige/CoursIA PR **#17167** commit `d2e2035c` (`scripts/notebook_tools/nb_view.py`)

If you need to modify nb_view.py, change the canonical source first, then re-copy here with updated fingerprints. A bare divergent copy is forbidden (second divergent focus — guard NanoClaw 23/09).

---

## Output format

Strict, one line: `X/Y reviews posted. PRs: #NNN result (repo), ... Skipped: Z SHA-match.`

Only reviews actually posted are listed; skipped PRs are never listed.

---

## Honesty rules

- Never report "BLOCKED token"/"403" in the output — use the documented fallback and say so in the review body.
- APPROVE only on a real verification artifact (re-executed test, API-checked fact), never mechanical validation.
- Flag what was reviewed superficially instead of defaulting to LGTM.
- Judging a predicate = EXECUTE the exact head's logic on real payloads, never reconstruct the predicate from the body.

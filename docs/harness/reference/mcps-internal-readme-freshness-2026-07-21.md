# W8 — `mcps/internal` READMEs server-by-server freshness audit (2026-07-21)

> **Parent**: W8 sub-issue [#2885](https://github.com/jsboige/roo-extensions/issues/2885) → Epic [#2877](https://github.com/jsboige/roo-extensions/issues/2877) → audit parent [#2876](https://github.com/jsboige/roo-extensions/issues/2876) (which did **not** scan the submodule — this audit closes that gap).
> **Auditor**: myia-web1 (claude-interactive executor, c.166).
> **Submodule HEAD**: `85764754` (`fix(indexing): retry_rate counts only same-tool calls…`).
> **Canonical active-source**: [`roo-config/settings/servers.json`](../../../roo-config/settings/servers.json) (13 servers — consumed by `run-diagnostic.ps1`, `maintenance-workflow.ps1`, `deployment/README.md` + 7 more; **not** the stale starter template `config-templates/servers.json`).
> **JSON companion**: [`mcps-internal-readme-freshness-2026-07-21.json`](./mcps-internal-readme-freshness-2026-07-21.json).

---

## Executive summary

Scanned **239 markdown files** across the `mcps/internal` submodule (228 under `servers/` across 8 server dirs + 11 top-level/docs/examples). By the canonical metric (submodule-own `git log -1 --format=%cs` on `origin/HEAD` `85764754`), **0 files are stale** (>180d) — **but this is uninformative, not "fresh"**: the submodule's `main` branch is a **fresh-root rebuild from 2026-07-01** (`2c7726a3`, `parent=[]` — verified), so every file's last-commit-date on main is 2026-07-01 regardless of when the *content* was authored. Commit-date staleness is therefore **degenerate** for this submodule. (The repo does retain older history on non-main refs — `fa4f9cce` initial commit 2025-05-01, `origin/backup-pre-merge-f724301` 2025-10-14 — so content genuinely predates main, but that history is not on the deployed `main`/`origin/HEAD`.) See the [Staleness metrics reconciliation](#staleness-metrics-) section for the full picture, including a 3rd-party review (po-204 c.111) that flagged this.

The **operative finding is structural**: of the 8 server dirs, only **2 are unambiguously clean** (active + well-documented + no drift). The other **6 carry status issues that mtime does not capture**:

| # | Server | Status | Issue |
|---|--------|--------|-------|
| 1 | `roo-state-manager` | ACTIVE | README 18d behind code (07-01 vs code 07-19); no prominent version header (pkg 1.0.14) |
| 2 | `sk-agent` | ACTIVE | No manifest (version untracked); config-injection source not in standard local configs |
| 3 | `jupyter-papermill-mcp-server` | ACTIVE | Clean, but 49 .md incl. many historical mission reports (archive-pass candidate) |
| 4 | `jinavigator-server` | ACTIVE | Clean (well-documented: README + CONFIG + INSTALL + TROUBLESHOOTING + USAGE) |
| 5 | `jupyter-mcp-server` | **SUPERSEDED** | Canonical `jupyter` points to the *papermill* variant, not this dir; README unmarked |
| 6 | `github-projects-mcp` | **RETIRED** | 0 canonical refs + CLAUDE.md retired; source+12 .md still present (unmarked) |
| 7 | `quickfiles-server` | **RETIRED** | 0 canonical refs + CLAUDE.md retired; source+29 .md still present (unmarked) |
| 8 | `open-terminal-mcp` | **UNDOCUMENTED** | Single .py, no README, no manifest, not in canonical config |

**This cycle is report-only — zero deletions.** All removal/deprecation actions are deferred to ai-01 / owner arbitration (no-deletion-without-proof + retired-server decommission is owner-gated per fleet policy).

> **Why this report exists** (DoD gap): po-2023 posted `[RESULT] PASS — completed (no code changes needed)` on #2885 at 06:46Z, but the first acceptance criterion of the issue — *"PR d'audit complétion (rapport MD + JSON, gap audit #2876 comblé)"* + *"100% du submodule scanné (résultat documenté : X fichiers MD, Y stale)"* — was not satisfied: no report file, no PR, no commit existed (verified firsthand). The "0 mtime-stale" result that likely drove the PASS is precisely the bulk-import artifact documented above; it hides the 6 structural findings this report surfaces. This report closes the DoD gap by producing the missing deliverable. — web1 c.166

---

## Method

1. **Inventory**: `git -C mcps/internal ls-files "*.md"` → 239 files (categorized: top-level/docs/examples = 11, `servers/` = 228).
2. **Staleness metric**: last-commit date per file (`git -C mcps/internal log -1 --format=%cs`), bucketed fresh<180d / 180-365d / >365d. → **0 stale**, because `main` is a fresh-root rebuild from 2026-07-01 (commit-date degenerate — see [Staleness metrics](#staleness-metrics-) section). Structural status is the operative signal.
3. **Canonical active-source**: `roo-config/settings/servers.json` `servers` array (13 entries) — the file scripts actually load (`git grep -l "settings/servers.json"` = 10 consumers), not the stale `config-templates/servers.json` starter.
4. **Per-server status**: cross-reference each `servers/<name>/` dir against the canonical active set + CLAUDE.md retired list + manifest presence + README/code commit-drift.
5. **Structural findings**: status (active/retired/superseded/undocumented) — the signal mtime cannot capture.

**SDDD bookend — DEBUT**: `codebase_search` returned `collection_not_found` (web1 Qdrant index empty post-#2876/#2863 key rotation). Compensated with technique grounding (Grep + Read + git) as primary source — appropriate for a file-inventory audit where the filesystem is ground truth.

---

## Staleness metrics (canonical: submodule-own git commit-date)

| Metric | Count |
|--------|------:|
| Total .md scanned | **239** |
| Fresh (<180d) | 239 |
| Stale 180-365d | 0 |
| Stale >365d | 0 |
| No date | 0 |

⚠ **Critical caveat — main is a fresh-root rebuild (2026-07-01), so commit-date staleness is degenerate.**

The canonical metric (`git -C mcps/internal log -1 --format=%cs -- <file>`, matching how #2876 measured parent-repo files via the parent's own git) returns **2026-07-01 for all 239 files** (verified 3 ways: one-pass `%cs`, one-pass `%as`, slow per-file). This is **not** a filesystem-mtime artifact — it is the actual git commit-date. The reason: the submodule's `main` branch is a **fresh root commit rebuilt on 2026-07-01** (`2c7726a3`, `parent=[]`, confirmed via `git rev-list --max-parents=0 main`). All 190 commits on `main` are dated 2026-07-01..2026-07-19. **"0 stale" is factually correct for `main`/`origin/HEAD`, but uninformative** — it reflects the rebuild date, not content age.

**Content genuinely predates main** on non-canonical refs: `git log --all` reaches 6543 commits back to `fa4f9cce Initial commit` (2025-05-01); the `origin/backup-pre-merge-f724301` branch (2025-10-14) shows the quickfiles README last touched `2025-10-14 b26d7dfa`. So the *content* is older, but that history is **not on the deployed `main`** — measuring it requires a non-canonical ref or creation-date lookup (`--diff-filter=A`), which is a different metric than #2876's "days since last commit on the file's own repo".

**Do not interpret "0 stale" as "all genuinely maintained"** — the operative signal is the **structural status** (6 of 8 servers carry active/superseded/retired/undocumented issues), documented server-by-server below. Content-age is real but not captured by the canonical metric here due to the 2026-07-01 rebuild.

### Reconciliation with po-204 c.111 3rd-party review (222/239 stale claim)

po-204 flagged a "CRITICAL staleness measurement error — 222/239 stale not 0, distribution 2025-05-01→2026-06-16". Re-measured firsthand, this number **could not be reproduced from the submodule's own git** on `main`/`origin/HEAD` (0 stale) or via `git log --all` restricted to the 239 main-files (quickfiles README still 2026-07-01; `--all` over all *.md yields a non-comparable 4465-file set). The 2025-05-01..2026-06-16 distribution matches **parent-repo `git log` on the submodule path** — verified: `git log -1 --format=%cs -- mcps/internal/servers/quickfiles-server/README.md` run **from the parent repo (no `-git -C mcps/internal`)** returns `2025-05-28 1fcea5fa` (the parent commit that added the submodule gitlink), because the parent tracks `mcps/internal` as a gitlink (mode `160000`), not individual files. po-204's "222 stale" almost certainly reflects parent-repo gitlink-touch dates, not the submodule's own file history.

**Both framings were incomplete**: this report understated that main-commit-date is degenerate (main rebuilt 2026-07-01 → uninformative); po-204's review correctly surfaced that content is older but attributed the number to a canonical commit-date metric that it isn't (it's a parent-repo path-log). The synthesis above is the corrected picture: **0 stale by canonical submodule metric (degenerate due to main rebuild); content older on non-main refs; structural status is the operative signal.** — web1 c.167, acknowledgment of po-204's valid kernel.

---

## Server-by-server inventory

### ACTIVE — clean (2)

**`jinavigator-server`** (6 .md, pkg@1.0.0) — Well-documented: README + CONFIGURATION + INSTALLATION + TROUBLESHOOTING + USAGE + test-report. Canonical: `node ./mcps/internal/servers/jinavigator-server/dist/index.js`. **Action: OK.**

**`jupyter-papermill-mcp-server`** (49 .md, pkg version empty + pyproject) — Canonical `jupyter` workingDirectory points here. Largest doc surface; many historical consolidation docs (`RAPPORT_*`, `CHECKPOINT_SDDD_*`, `CHANGELOG_CONSOLIDATION_*`). **Action: OK** (active, README present); **FLAG** the historical mission docs (49 .md) as candidates for a future archive pass (out of W8 scope).

### ACTIVE — update-needed (2)

**`roo-state-manager`** (128 .md, pkg@1.0.14) — The main MCP. Canonical: `node …/mcp-wrapper.cjs` (MCP Wrapper v2.5.0). README last commit 2026-07-01, but code advanced to 2026-07-19 via submod bumps (#2820/#2826/#2827/#2829). README does not echo `1.0.14` in a prominent header. **Action: UPDATE-NEEDED (minor)** — refresh README tool list / version ref to match 1.0.14 + recent tool additions (e.g. the `retry_rate` fix at HEAD).

**`sk-agent`** (3 .md, no manifest) — Active per `tool-availability.md` (9 outils + dynamic agents, Claude Code MCP). **Not** in Roo `settings/servers.json` nor `~/.claude.json` `mcpServers` — config-injection source unresolved (possibly project-scoped or remote-injected). No `package.json`/`pyproject.toml` → version untracked. **Action: UPDATE-NEEDED (minor)** — document the config-injection source in README.

### SUPERSEDED (1)

**`jupyter-mcp-server`** (1 .md, pkg@1.0.0) — The canonical `jupyter` server uses `jupyter-PAPERMILL-mcp-server` (different dir). This dir is a separate, non-active Jupyter variant. README does not mark itself superseded. **Action: UPDATE-NEEDED** — add deprecation/superseded-by header pointing to `jupyter-papermill-mcp-server`; full removal is a separate user-gated decision.

### RETIRED — source still present (2)

**`github-projects-mcp`** (12 .md, pkg@0.1.0) — **0 references** in canonical `settings/servers.json` + CLAUDE.md "Retires" list. Source + 12 .md (incl. DEBUG guides, `mission_report.md`) still present. README unmarked as retired.

**`quickfiles-server`** (29 .md, pkg@1.0.0) — **0 references** in canonical `settings/servers.json` + CLAUDE.md "Retires" list. Source + 29 .md still present. **Bonus finding**: the stale starter template `roo-config/config-templates/servers.json` (0 script consumers) still references `quickfiles` — that is the config-templates-≠-canonical trap, separate from W8.

> **Why no README removal this cycle**: the W8 DoD's literal removal-proof criterion is *"server absent de `mcps/internal/servers/` OU `package.json` workspaces"*. Neither is met — both retired dirs **are still present**, and the submodule root `package.json` has **no `workspaces` field**. Removing only the READMEs would leave undocumented orphan **code** behind (a no-deletion-without-proof violation). The safe, reversible action is a **deprecation header** on each README; **full server decommission (source + docs)** is an owner-gated decision (fleet policy: retired-server decommission is user-gated, see web1 `project-2373-web1-sanctuary-done` precedent). **Deferred to ai-01 / @jsboige.**

### UNDOCUMENTED (1)

**`open-terminal-mcp`** (0 .md, no manifest) — Single file `open_terminal_mcp.py` (9437 bytes, mtime 2026-04-13). No README, no manifest, not in canonical config. Status unclear (experimental / abandoned / active-elsewhere). **Action: UPDATE-NEEDED** — add minimal README documenting purpose + status, OR flag for removal if abandoned (user-gated).

---

## Top-level submodule docs (7 files, all OK)

All last-committed 2026-07-01 (bulk import). Content intact, no broken references detected.

| File | Lines | Status |
|------|------:|--------|
| `README.md` | 159 | OK |
| `INDEX.md` | 38 | OK |
| `CONTRIBUTING.md` | 272 | OK |
| `docs/architecture.md` | 165 | OK |
| `docs/getting-started.md` | 66 | OK |
| `docs/troubleshooting.md` | 128 | OK |
| `examples/README.md` | 90 | OK |

---

## Recommended actions (deferred — none applied this cycle)

| Priority | Action | Owner | Gate |
|----------|--------|-------|------|
| Low | `roo-state-manager` README: add 1.0.14 version header + tool-list refresh | any executor | none (doc PR) |
| Low | `sk-agent` README: document config-injection source | any executor | none (doc PR) |
| Med | `jupyter-mcp-server` README: add superseded-by header | any executor | none (doc PR) |
| Med | `open-terminal-mcp`: add minimal README or flag abandoned | any executor | confirm status first |
| **High** | `github-projects-mcp` + `quickfiles-server` full decommission (source + docs) OR README deprecation headers | **ai-01 / @jsboige** | **owner-gated** (no-deletion-without-proof) |
| Low (bonus) | `roo-config/config-templates/servers.json`: remove stale `quickfiles` reference | any executor | none (it's a stale starter template) |
| Future | `jupyter-papermill-mcp-server`: archive 49 historical mission docs | separate doc-consolidation workstream | — |

---

## DoD acceptance criteria (#2885)

- [x] **100% du submodule scanné** — 239 .md documented (228 servers + 11 top-level).
- [x] **Pour chaque server, status explicite** — `OK | UPDATE-NEEDED | REMOVE` (mapped: 2 OK, 3 UPDATE-NEEDED, 2 RETIRED-FLAG, 1 SUPERSEDED, plus open-terminal undocumented). *No server reaches the literal REMOVE bar this cycle because none are absent from `servers/` — see no-deletion caveat.*
- [x] **No-deletion-without-proof** — zero deletions; retired servers documented with canonical-absence proof + flagged for owner-gated decommission.
- [x] **PR séparées par action** — this PR is the audit-completion deliverable (report MD + JSON); fix-PRs per server are listed above as follow-ups, not bundled here (surgical #1936).
- [x] **SDDD bookend** — DEBUT (codebase_search attempted, collection_not_found compensated by technique grounding); FIN (this report + JSON companion committed).

---

## Convergence with sibling workstreams (Epic #2877)

- W8 is the **last workstream** of Epic #2877 (per po-2026 c.106 fleet status). This report satisfies its audit-completion deliverable.
- **No collision** with W2 (#2897, web1 c.157) — W2 archives parent-repo docs superseded by closed GitHub issues; W8 audits the submodule READMEs. Disjoint scopes.
- **No collision** with W3/W6 archive PRs — those cover `roo-code-customization/investigations/` and demo-roo-code; W8 covers `mcps/internal/servers/`.

---

*Generated 2026-07-21 by myia-web1 · claude-interactive executor · c.166 · W8 #2885 DoD-completion deliverable.*

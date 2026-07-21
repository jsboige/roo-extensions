# mcps/external — README & Doc Coherence Audit (2026-07-21)

**Sub-issue:** [#2882](https://github.com/jsboige/roo-extensions/issues/2882) (W5 — sub-issue of Epic [#2877](https://github.com/jsboige/roo-extensions/issues/2877), workstream #3 of [#2639](https://github.com/jsboige/roo-extensions/issues/2639))
**Source audit:** [#2876](https://github.com/jsboige/roo-extensions/pull/2876) (merged `6e56ce8f`) — category `other`, 292 files
**Scope:** 45 git-tracked `.md` files under `mcps/external/` (NOT just `README.md` — the audit counted all `.md`)
**Method:** READ-ONLY. No file modified or deleted. This is livrable #1 (audit). Livrables #2 (UPDATE) and #3 (REMOVE) are separate, user-gated PRs.
**Author:** myia-web1 (claude-interactive executor)

---

## TL;DR

| Verdict | Packages | Files | Next action |
|---------|----------|-------|-------------|
| **OK** (active, coherent) | win-cli, searxng, playwright, markitdown | 19 | keep; spot-update if version drift confirmed |
| **UPDATE-NEEDED** (vendored docs, stale) | jupyter, git, github, docker | 24 | per-MCP UPDATE PR (scope-bounded) — livrable #2 |
| **REMOVE** (retired MCP, proof attached) | desktop-commander | 1 | REMOVE PR with proof — livrable #3 |
| **INDEX INCONSISTENCY** | `mcps/external/README.md` (the index) | 1 | UPDATE index to match actual dir contents |

39 of 45 files are >180 days stale. **Age alone is not drift** for these files: most are vendored upstream documentation dropped into the repo as a one-time snapshot (~425 days ago = the original vendor drop), so a high age is the *expected* steady state, not evidence of neglect. The actionable signal is **coherence with the active MCP set**, not age.

---

## Scope correction (skepticism)

Issue #2882 title says "45 fichiers `README.md`". **Verified firsthand: the 45 are all git-tracked `.md` files, not only `README.md`.** Breakdown by type:

- `README.md` (12), `USAGE.md` (5), `CONFIGURATION.md` / `configuration.md` (5), `INSTALLATION.md` / `installation.md` (4), `TROUBLESHOOTING.md` (5), `CHANGELOG.md` (1), plus one-off docs (`BUILD-LOCAL.md`, `exemples.md`, `SECURITY.md`, `securite.md`, `INSTALLATION_REPORT.md`, `third-party-licenses.*.md`, `configurations-jupyter-mcp.md`, `troubleshooting.md`).

Confirmed via `git ls-files 'mcps/external/*.md' | grep -v node_modules | wc -l` = **45**, matching audit JSON exactly (drill-down: `data['categories']['other']` is a list of 292 entries; 45 contain `mcps/external`).

---

## Active-MCP ground truth (cross-reference)

Per [`.claude/rules/tool-availability.md`](../../../.claude/rules/tool-availability.md) (canonical active/retired inventory):

- **Claude Code active:** roo-state-manager (15)
- **Roo Scheduler active:** win-cli (fork 0.2.0, 9 tools)
- **Standards (non-blocking):** playwright (23), sk-agent (9), searxng (2)
- **Roo-only:** markitdown (1)
- **RETIRED (must NOT exist in configs):** desktop-commander, github-projects-mcp, quickfiles

**Meta-finding (out of scope, flagged):** `roo-config/config-templates/servers.json` is itself stale — it lists `quickfiles` (retired) and omits `playwright`/`markitdown` (active). This is a config-template issue, not an external-README issue, and is noted here for traceability only.

---

## Per-package classification

Legend: age = days since last git commit touching the file (from audit #2876). `config refs` = grep hits in committed `roo-config/**` + `.mcp.json*` configs.

### 1. win-cli — **OK** (active, coherent)
- 8 files, ages 130d–425d (README recently maintained at 130d)
- **Active:** Roo Scheduler fork 0.2.0 (tool-availability.md). Present in `config-templates/servers.json`.
- **Coherence:** `README.md` references `unrestricted-config.json` + paths under `mcps/external/win-cli/` — matches current deployment. Server-internal docs (configuration.md, USAGE.md, etc. at 425d) are the original fork snapshot.
- **Action:** KEEP. Optional spot-update of server docs if a specific drift is reported — not indicated now.

### 2. searxng — **OK / minor UPDATE candidate**
- 6 files, ages 315d–425d
- **Active:** standard MCP, 2 tools (tool-availability.md). Present in `config-templates/servers.json`.
- **Coherence:** `README.md` (315d) has no version/install keywords in first 30 lines (lightweight). Active and mounted fleet-wide.
- **Action:** KEEP. Verify the `r.jina.ai` markdown-prefix note (#2210) is reflected if any USAGE example references web fetching.

### 3. playwright — **OK** (active)
- 3 files, ages 280d–364d
- **Active:** standard MCP, 23 tools (tool-availability.md). Configured machine-local (not in `config-templates/servers.json`, which is itself stale — see meta-finding).
- **Coherence:** `README.md` documents the Microsoft submodule source.
- **Action:** KEEP.

### 4. markitdown — **OK** (active, Roo-only)
- 2 files, ages 315d–364d
- **Active:** Roo-only, 1 tool (tool-availability.md). Submodule from `microsoft/markitdown`.
- **Coherence:** `README.md` documents the submodule origin correctly.
- **Action:** KEEP.

### 5. jupyter — **UPDATE-NEEDED** (semi-active vendored)
- 3 files, all 425d
- **Status:** Present in `config-templates/servers.json` (Roo side) but NOT in the tool-availability.md active list. Vendored docs for a Roo MCP that may be semi-active.
- **Action:** UPDATE PR to confirm current usage. If the jupyter MCP is no longer deployed, these become archive candidates (proof required).

### 6. git — **UPDATE-NEEDED** (vendored, not active)
- 7 files, all 425d (incl. `server/README.md`, `server/CHANGELOG.md`)
- **Status:** NOT in active MCP set. `server/` subdir suggests a vendored MCP server + its docs.
- **Action:** UPDATE PR to clarify whether the git MCP is deployed anywhere. If not, archive candidate (proof required).

### 7. github — **UPDATE-NEEDED** (vendored, NOT the retired github-projects-mcp)
- 8 files, all 425d (incl. 3 `third-party-licenses.*.md` platform variants)
- **Disambiguation:** `README.md` = "MCP GitHub pour Roo" (auto-generated `<!-- START_SECTION -->` blocks). This is Roo's GitHub MCP, **distinct** from `github-projects-mcp` (the retired one). NOT in active config-templates.
- **Action:** UPDATE PR. The 3 platform license files (windows/darwin/linux) are large (3.4–3.6 KB each) auto-generated artifacts — candidates to reduce to a single canonical reference if the MCP is active, or archive if not.

### 8. docker — **UPDATE-NEEDED** (vendored, not active)
- 6 files, all 419d–425d (USAGE, TROUBLESHOOTING, CONFIGURATION, INSTALLATION, README, BUILD-LOCAL)
- **Status:** NOT in active MCP set. Generic Docker containerization docs.
- **Action:** UPDATE PR to confirm relevance. Archive candidate if the docker MCP/proxy is not deployed.

### 9. desktop-commander — **REMOVE** (retired, proof attached)
- 1 file (`README.md`, 152d)
- **Proof of retirement:**
  1. tool-availability.md lists `desktop-commander` under "Retires (NE DOIVENT PAS exister dans les configs locales)".
  2. `git grep -l "desktop-commander" -- 'roo-config/**/*.json' '.mcp.json*'` = **empty** (absent from all committed configs).
- **Content:** README documents "Issue #468 — Migration win-cli vers DesktopCommanderMCP", "v0.2.35", "26 outils". This migration was **reversed** — win-cli won and DCM was retired. The README is dead documentation for a retired MCP.
- **Action:** **REMOVE PR** (livrable #3). Proof satisfies no-deletion-without-proof (config absent + rule doc). User-gated per Epic #2877.

### 10. Index `mcps/external/README.md` — **INDEX INCONSISTENCY**
- 1 file, 425d
- **Finding:** The index lists 7 packages: docker, **filesystem**, git, github, jupyter, searxng, win-cli. The actual directory contains 11 entries. The index **omits**: desktop-commander, markitdown, playwright, mcp-server-ftp, Office-PowerPoint-MCP-Server. It claims `filesystem/` (which exists but has no tracked `.md`).
- **Action:** UPDATE PR (livrable #2) to synchronize the index with actual contents and current active-MCP status.

> **Note (submodules excluded from this audit):** `mcp-server-ftp`, `Office-PowerPoint-MCP-Server`, `markitdown/source`, `playwright/source`, `win-cli/server` are git submodules. Their *interior* READMEs are not parent-tree tracked and thus not in the 45. `mcp-server-ftp` and `Office-PowerPoint` have **zero config refs** in committed configs — they are orphan submodules worth a separate investigation (out of scope for #2882, flagged for a future issue).

---

## Acceptance criteria — status

- [x] 100% of the 45 files accounted for + grouped by package (10 groups)
- [x] Each package has an explicit status: OK | UPDATE-NEEDED | REMOVE
- [x] No-deletion-without-proof: the single REMOVE (desktop-commander) has config-absence proof + rule-doc citation
- [ ] PRs separated by action (1 PR = 1 decision per MCP) — **deferred to livrables #2/#3 (user-gated)**
- [x] SDDD bookend: DEBUT (audit JSON drill-down + tool-availability.md cross-ref) + FIN (this report)

---

## Proposed follow-up PRs (livrables #2/#3, user-gated)

Per the issue's hard cap of 5 PRs/cycle and 1-PR-per-decision rule, the recommended sequence (each a separate, scope-bounded PR):

1. **REMOVE** `mcps/external/desktop-commander/README.md` — retired MCP, proof attached. (livrable #3)
2. **UPDATE** `mcps/external/README.md` index — synchronize with actual 11-entry directory + active status. (livrable #2)
3. **UPDATE/ARCHIVE** jupyter, git, github, docker — one PR per package, each first confirming deployment status, then UPDATE or archive-with-proof. (livrable #2)

Each destructive action (archive/remove) requires its own no-deletion-without-proof evidence block.

---

## Method notes

- Audit JSON parse: `data['categories']['other']` is a **list** (not a dict) of `{path, size_kb, age_days, sha8}`. The `sha8` field is an 8-char commit abbrev (not a blob SHA) — not directly usable for `git cat-file -e` blob verification (noted in #2876 review).
- All 45 files verified git-tracked via `git ls-files` (no untracked contamination, unlike the cwd-pollution seen in ai-01 c.52).
- Active-status determination combines tool-availability.md (ground truth) + `config-templates/servers.json` membership + committed-config grep. No machine-local `~/.claude.json` consulted (sanctuary file, not authoritative for repo-level coherence).

— myia-web1 · claude-interactive executor · #2882 livrable #1 (read-only coherence audit) · 2026-07-21

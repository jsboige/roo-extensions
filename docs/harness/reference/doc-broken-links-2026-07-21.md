# Doc Broken-Links Audit — 2026-07-21

**Sub-issue:** [#2878 [W1] Liens morts inter-docs](https://github.com/jsboige/roo-extensions/issues/2878) (sub-issue of #2877 / workstream #3 of #2639)
**Scope:** All tracked `.md` files in parent repo + `mcps/internal` submodule (1087 files, 3050 markdown links).
**Method:** `scripts/docs/scan-broken-links.ps1` — regex `[text](target)` extraction, relative-path resolution (`./`, `../`), filesystem existence check via `Test-Path`. External links (http/https/mailto) skipped. Companion raw data: [`doc-broken-links-raw-2026-07-21.json`](./doc-broken-links-raw-2026-07-21.json).
**Author:** myia-po-2023 (executor c.108). **W1 livrable #1 (read-only audit).** No fix PR — that is livrable #2 (gated).

---

## Headline

| Metric | Count |
|--------|-------|
| Files scanned | 1087 |
| Total links parsed | 3050 |
| External (http/https, skipped) | 566 |
| Internal links | 2484 |
| OK (resolved target exists) | 1195 |
| **BROKEN-PATH** (`.md` target missing) | **202** |
| **BROKEN-ASSET** (non-`.md` target missing: images, logs, json) | **346** |
| Files containing ≥1 broken link | 548 |

Broken-path rate: **202 / 1646 internal `.md` links ≈ 12.3%**. Broken-asset rate is higher (346) but dominated by ephemeral SDDD report artifacts (see §Limitations).

---

## Methodology notes (read before acting on numbers)

1. **Placeholder false-positives.** Template links like `[File Title](path/to/file.md)` and `path/to/doc` (in `.claude/commands/executor.md`, `.claude/configs/skills/SKILLS-AUDIT-REPORT.md`) are **intentional placeholders**, not real broken links. Only **3 such** detected — net impact tiny, but any fix-PR must exclude `path/to/*` targets.
2. **Backtick code-spans counted.** Links whose text is wrapped in backticks `` `docs/...` `` (e.g. in `.claude/configs/user-global-claude.md`) are sometimes code samples in documentation prose, not navigable links. The scanner counts them. A fix-PR should verify each against context before "fixing".
3. **Anchor-only links skipped.** `#section` intra-file links are counted as `internal` but **not** verified (heading parsing out of scope). `BROKEN-ANCHOR` count is therefore 0 by design — anchors are a separate verification pass if needed.
4. **`BROKEN-ASSET` is mostly noise-by-design.** 287/346 asset-breaks are in `mcps/internal/.../docs/suivi/`, `docs/reports/`, `docs/suivi/RooSync/` — historical SDDD reports referencing generated artifacts (`.png`, `.json`, `.log`, snapshot files) that were never committed or were cleaned. These are **expected** in archived reports and should NOT drive a cleanup.
5. **Missing `.md` extension inference.** Many "broken" targets are referenced without extension (e.g. `code-simple` instead of `code-simple.md`). The scanner reports the literal target. The fix-PR should check whether `target.md` exists before classifying as truly broken.

---

## BROKEN-PATH by source-file zone

| Zone | Broken-PATH | Note |
|------|-------------|------|
| `mcps/` | 138 | Mostly submodule `mcps/internal/` old structure (`mcp-servers/` pre-reorg, server READMEs) |
| `roo-config/` | 25 | `specifications/` refs to mode-files without `.md` extension |
| `demo-roo-code/` | 12 | Zone flagged 100% stale>180j by audit #2876 — expected |
| `tests/` | 8 | Test-result docs referencing ephemeral outputs |
| `.claude/` | 6 | Configs/commands |
| `docs/` | 6 | Harness reference cross-links |
| `roo-code-customization/` | 6 | `investigations/` temp specs (zone flagged stale by #2876) |
| `scripts/` | 1 | |

---

## Top broken-path targets (most-referenced missing files)

These are the highest-leverage fixes (one file recreation/redirect unblocks N references):

| Refs | Missing target | Likely cause |
|------|----------------|--------------|
| 6 | `roo-config/specifications/code-simple` | Missing `.md` extension (target is a mode spec) |
| 6 | `roo-config/specifications/debug-simple` | Missing `.md` extension |
| 4 | `roo-config/specifications/ask-simple` | Missing `.md` extension |
| 4 | `demo-roo-code/guide_installation.md` | File removed (stale zone) |
| 4 | `mcps/internal/docs/quickfiles-use-cases.md` | Wrong path (now under `servers/`?) |
| 4 | `mcps/internal/docs/jinavigator-use-cases.md` | Wrong path |
| 3 | `roo-config/specifications/orchestrator` | Missing extension |
| 3 | `roo-config/specifications/architect-simple` | Missing extension |
| 3 | `claude/rules/wake-claude-routing.md` | Missing `.claude/` prefix (real path: `.claude/rules/...`) |
| 3 | `mcps/mcp-servers/INDEX.md` | Old `mcp-servers/` path pre-reorg |
| 3 | `mcps/internal/servers/roo-state-manager/docs/archives/2025-09` | Archive dir reference |
| 2 | `mcps/internal/SEARCH.md` | Removed |
| 2 | `mcps/internal/servers/INDEX.md` | Removed |

---

## Top source files (most broken links)

| Broken | Source file | Profile |
|--------|-------------|---------|
| 56 (3 path / 53 asset) | `mcps/internal/servers/roo-state-manager/src/README.md` | Asset-heavy (auto-generated refs) |
| 25 (25 path) | `roo-config/specifications/hierarchie-numerotee-subtasks.md` | All missing-extension mode refs |
| 17 (17 path) | `mcps/INDEX.md` | Old `mcp-servers/` structure |
| 17 (15 path / 2 asset) | `mcps/internal/servers/roo-state-manager/README.md` | Old internal paths |
| 17 (0 / 17 asset) | `mcps/internal/servers/roo-state-manager/docs/AUTO_REBUILD_MECHANISM.md` | Ephemeral artifacts |
| 9 (9 path) | `mcps/internal/servers/roo-state-manager/docs/reports/INDEX-LIVRABLES-REORGANISATION-TESTS.md` | Old report paths |

---

## Recommended fix categories (for livrable #2, gated)

These are **categories for a future fix-PR**, each requiring its own no-deletion-without-proof pass (per W1 issue acceptance criteria). Not executed here.

1. **Missing `.md` extension** (~30 refs in `roo-config/specifications/`). Lowest-risk fix: append `.md` if `target.md` exists. Surgical, one-line-per-link.
2. **Old `mcp-servers/` → `internal/` reorg paths** (`mcps/INDEX.md`, `mcps/internal/README.md`, server READMEs). The historical `fix-broken-links.ps1` (Oct 2025) already addressed some — verify what remains vs. what it fixed.
3. **Missing `.claude/` prefix** (`claude/rules/wake-claude-routing.md` refs from `docs/`). Prefix-add, surgical.
4. **`demo-roo-code/` stale refs.** Zone is 100% stale per audit #2876 — fixing links here may be moot if the whole zone is archived. Coordinate with W3.
5. **PROTEGED paths.** Any broken link **into** `.claude/rules/`, `src/services/synthesis/`, `src/services/narrative/` requires user approval before modification (per W1 issue rules).

---

## SDDD bookend

- **DEBUT:** `codebase_search`/`Glob` found existing `scripts/docs/fix-broken-links.ps1` (Oct 2025 fixer, hardcoded patterns for a prior reorg) — confirmed it is NOT an exhaustive scanner, no duplication.
- **FIN:** This audit + companion JSON are indexed under `docs/harness/reference/`. The scanner `scripts/docs/scan-broken-links.ps1` is reusable for future re-scans post-fix (regression guard).

---

## Reproduction

```powershell
# From repo root (parent), with mcps/internal submodule initialized
pwsh -ExecutionPolicy Bypass -File scripts/docs/scan-broken-links.ps1 -Quiet > scan.json
```

Re-runnable after any fix-PR to verify the broken-count decreases monotonically.

---

## Limitations / honest caveats

- **Anchor verification not implemented.** A link `[x](file.md#section)` where `file.md` exists but `#section` heading is absent is classified `OK`, not broken. If anchor-integrity matters, a second pass (markdown heading extraction) is needed.
- **Generated artifacts counted as broken-assets.** Historical SDDD reports reference `.png`/`.json`/`.log` that were intentionally not committed. The 346 `BROKEN-ASSET` count overstates real damage — the 202 `BROKEN-PATH` (`.md` targets) is the actionable signal.
- **Filenames with accents/spaces.** The scanner uses `.Split('/')` on normalized paths — web1 c.160 showed this can mis-handle accented paths. Spot-checked here: `demo-roo-code/` accent refs resolve correctly in this scan, but a fix-PR should re-verify affected files individually.

— myia-po-2023 · claude-interactive executor · c.108 · W1 #2878 livrable #1 (read-only audit) · 2026-07-21

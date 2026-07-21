# tests/results/ — Lookup Index

**Purpose:** Traceability table for ephemeral test reports removed by W4 #2881.
Each deleted report is preserved in git history at the cited SHA.
Lookup via `git show <SHA>:<path>` or `https://github.com/jsboige/roo-extensions/blob/<SHA>/<path>`.

**Issue:** [#2881](https://github.com/jsboige/roo-extensions/issues/2881) (W4 of Epic #2877, audit #2876 catégorie `other`).
**Audit date:** 2026-07-21. **Files removed:** 21 MD (155-426 jours). **Bytes freed:** ~165 KB.

## Categories

| Category | Files | Age (days) | Incoming links |
|-----------|-------|------------|-----------------|
| Qwen-config tests | 4 | 426 | audit-only (1 file) |
| Escalation matrix | 4 | 426 | none |
| Misc top-level | 2 | 176-426 | none |
| Roosync test reports | 4 | 268 | docs/roosync/README.md (4 links) + internal cross-refs |
| Roosync checkpoints | 2 | 268 | internal cross-refs only |
| Validation summaries | 5 | 156-206 | docs/roosync/README.md (1 link, validation-wp1-wp4) |

## Lookup Table

For each removed file: path, last commit SHA (preservation proof), size, age at removal.

### Category: Qwen-config tests

| Path | Last SHA | Last date | Size (B) | Lines | Age (d) |
|------|----------|-----------|----------|-------|---------|
| `tests/results/test-results-qwen-advanced-config.md` | `c952eae7` | 2025-05-21 | 10783 | 218 | 426 |
| `tests/results/test-results-qwen-config.md` | `c952eae7` | 2025-05-21 | 10533 | 209 | 426 |
| `tests/results/test-results-qwen-mixed-config-template.md` | `c952eae7` | 2025-05-21 | 6662 | 202 | 426 |
| `tests/results/test-results-qwen-mixed-detailed.md` | `c952eae7` | 2025-05-21 | 18965 | 386 | 426 |

First added: `05d5e42f` (2025-05-16). Audit reference: `docs/harness/reference/doc-audit-2026-07-21.md:244`.

### Category: Escalation matrix

| Path | Last SHA | Last date | Size (B) | Lines | Age (d) |
|------|----------|-----------|----------|-------|---------|
| `tests/results/escalation-matrix-20250516-094558.md` | `c952eae7` | 2025-05-21 | 1382 | 35 | 426 |
| `tests/results/escalation-matrix-20250516-095859.md` | `c952eae7` | 2025-05-21 | 5012 | 101 | 426 |
| `tests/results/escalation-matrix-20250516-100250.md` | `c952eae7` | 2025-05-21 | 5012 | 101 | 426 |
| `tests/results/escalation-matrix-20250516-100522.md` | `c952eae7` | 2025-05-21 | 5012 | 101 | 426 |

First added: `05d5e42f` (2025-05-16). Incoming links: none.

### Category: Misc top-level

| Path | Last SHA | Last date | Size (B) | Lines | Age (d) |
|------|----------|-----------|----------|-------|---------|
| `tests/results/environment-check-20250515-155044.md` | `c952eae7` | 2025-05-21 | 649 | 29 | 426 |
| `tests/results/gh-cli-vs-mcp-github-comparison.md` | `654f5d0b` | 2026-01-26 | 7608 | 199 | 176 |

First added: env-check `05d5e42f` (2025-05-16), gh-cli `654f5d0b` (2026-01-26). Incoming links: none.

### Category: Roosync test reports

| Path | Last SHA | Last date | Size (B) | Lines | Age (d) |
|------|----------|-----------|----------|-------|---------|
| `tests/results/roosync/test1-logger-report.md` | `a5c7798a` | 2025-10-26 | 8266 | 240 | 268 |
| `tests/results/roosync/test2-git-helpers-report.md` | `a5c7798a` | 2025-10-26 | 7640 | 215 | 268 |
| `tests/results/roosync/test3-deployment-report.md` | `a5c7798a` | 2025-10-26 | 11714 | 399 | 268 |
| `tests/results/roosync/test4-task-scheduler-report.md` | `a5c7798a` | 2025-10-26 | 11148 | 367 | 268 |

First added: `a5c7798a` (2025-10-26). Incoming links: `docs/roosync/README.md:715-718` (removed in PR-D).

### Category: Roosync checkpoints

| Path | Last SHA | Last date | Size (B) | Lines | Age (d) |
|------|----------|-----------|----------|-------|---------|
| `tests/results/roosync/checkpoint1-test1-test2-validation.md` | `a5c7798a` | 2025-10-26 | 5946 | 181 | 268 |
| `tests/results/roosync/checkpoint2-test3-test4-validation.md` | `a5c7798a` | 2025-10-26 | 11224 | 346 | 268 |

First added: `a5c7798a` (2025-10-26). Incoming links: internal cross-refs only (self-removed).

### Category: Validation summaries

| Path | Last SHA | Last date | Size (B) | Lines | Age (d) |
|------|----------|-----------|----------|-------|---------|
| `tests/results/roosync/VALIDATION-SUMMARY.md` | `75e46809` | 2026-02-15 | 11341 | 432 | 156 |
| `tests/results/roosync/apply-config-validation-20260118.md` | `a343d8fd` | 2026-01-19 | 7745 | 274 | 183 |
| `tests/results/roosync/validation-fixes-T14-20260118.md` | `27964ca5` | 2026-01-18 | 8043 | 233 | 184 |
| `tests/results/roosync/validation-workflow-myia-ai-01-20260118.md` | `7ce45751` | 2026-01-18 | 7531 | 242 | 184 |
| `tests/results/roosync/validation-wp1-wp4.md` | `2ff0ace4` | 2025-12-27 | 2537 | 42 | 206 |

First added: see Last SHA (each added in its own commit). Incoming links: `docs/roosync/README.md:719` references `validation-wp1-wp4.md` (removed in PR-D).

## Link Analysis (external incoming)

External incoming links = links from canonical docs (not from files in tests/results/ themselves).

| Source | Lines | Target | Action |
|--------|-------|--------|--------|
| `docs/roosync/README.md` | 715-718 | test1-4 logger/git-helpers/deployment/task-scheduler reports | Remove links (PR-D) |
| `docs/roosync/README.md` | 719 | validation-wp1-wp4.md | Remove link (PR-D) |
| `docs/roosync/README.md` | 795 | `tests/results/roosync/` (directory ref) | Leave as-is (directory still exists via INDEX.md) |
| `docs/harness/reference/doc-audit-2026-07-21.md` | 244 | test-results-qwen-mixed-detailed.md | Leave as-is (audit record, historical) |
| `mcps/internal/.../tests/roosync/README.md` | multiple | `tests/results/roosync/*.json` (general) | Leave as-is (references JSON fixtures, not MD) |
| `tests/README.md` | 59, 114, 122 | `tests/results/n5/` (n5 subdirectory) | Leave as-is (n5/ not in scope) |

**Conclusion:** 5 links in `docs/roosync/README.md` need removal (PR-D). All other references are either audit records, directory refs, or out-of-scope (n5/, JSON).

## Out of Scope

The following are NOT in scope for #2881:
- `tests/results/n5/` — 24 JSON files (escalation/deescalation/transition test results). Referenced from `tests/README.md` as active test output location. Not part of "21 MD files" audit.
- `tests/results/roosync/test4-task-scheduler-report.json` — JSON file, not MD. Audit was MD-only.

## How to Retrieve a Removed Report

```bash
# Example: retrieve test1-logger-report.md at its last commit
git show a5c7798a:tests/results/roosync/test1-logger-report.md

# Or via GitHub web UI:
# https://github.com/jsboige/roo-extensions/blob/a5c7798a/tests/results/roosync/test1-logger-report.md
```

SHA prefixes above are short forms; full SHAs are reachable via `git log --follow -- <path>` on `main`.

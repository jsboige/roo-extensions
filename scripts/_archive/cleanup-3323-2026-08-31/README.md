# Archive cleanup #3323 (2026-08-31)

## Consolidation evidence

### MCP cleanup cluster — 3 scripts → 1 canonical

**Absorbed into `scripts/mcp/cleanup-mcp-zombies.ps1`** (new `-Mode` parameter):

| Original | Absorbed mode | Issue | Proof of absorption |
|----------|---------------|-------|---------------------|
| `scripts/mcp/cleanup-mcp-zombies.ps1` | `Cluster` (default) | #2830 | Original behavior preserved verbatim |
| `scripts/diagnostic/cleanup-mcp-orphans.ps1` | `ParentChain` | #1281 | WMI parent-chain logic: lines 72-225 of original → `Invoke-ParentChainMode` |
| `scripts/maintenance/cleanup-mcp-stdio-zombies.ps1` | `Stdio` | #2675 | Code.exe ancestor walk: lines 1-150 of original → `Invoke-StdioMode` |

**Backwards compatibility**:
- `scripts/diagnostic/cleanup-mcp-orphans.ps1` → redirected to `cleanup-mcp-zombies.ps1 -Mode ParentChain` (kept as thin wrapper)
- `scripts/maintenance/cleanup-mcp-stdio-zombies.ps1` → redirected to `cleanup-mcp-zombies.ps1 -Mode Stdio` (kept as thin wrapper)

### Harness tokens cluster — 2 scripts → 1 canonical

| Original | Action | Reason |
|----------|--------|--------|
| `scripts/claude/analyze-harness-tokens.ps1` | **KEPT** (canonical) | More comprehensive (handles code blocks, MCP schema files, optimization suggestions) |
| `scripts/claude/diagnose-harness.ps1` | Replaced with thin wrapper | Duplicates the same analysis. Original archived here. |

### Obsolete one-shot fixes — ARCHIVED

| Script | Status | Reason | Evidence |
|--------|--------|--------|----------|
| `scripts/diagnostic/fix-diffdetector-exports.ps1` | ARCHIVED | Applied, content already in DiffDetector.ts | grep: `export type DiffCategory` (line 856), `export interface DetectedDifference` (line 858), `export interface ComparisonReport` (line 893), `compareInventories` (line 751) — all 4 additions present |
| `scripts/diagnostic/fix-compare-config-type.ps1` | ARCHIVED | Obsolete: target type structure changed, fix no longer applicable | grep compare-config.ts: no `DetectedDifference` import, no `(diff: DetectedDifference)` typing. Original fix target (line 127) is gone |
| `scripts/diagnostic/verify-mcp-files.ps1` | ARCHIVED | One-shot verifier: hardcoded `C:/dev/roo-extensions` paths (wrong on other hosts), 2 paths target runtime-retired MCPs (`github-projects-mcp`, `quickfiles-server` — removed from the submodule canon by #1093) | `tool-availability.md` Retires section. **Correction 2026-09-17**: the original "retired" claim also listed `jupyter-mcp-server` and `jinavigator-server` — measured FALSE (po-2024, 2026-09-16): both still exist in `mcps/internal/servers/`. The archive motive stands on the hardcoded-path + runtime-retired pair only. |

### Cluster 3 (build MCP) — `compile-all-mcps.ps1` ARCHIVED (2026-09-17)

Archived on the zero-caller + stale-subset motive (decision user 2026-09-13, relayed by ai-01 —
never on the "retired MCPs" motive, measured false):

- **Zero-caller**: only mentions are `docs/roosync/archive/` (archived doc) and inventory fixtures
  (`scripts/inventory/test-inventory.json`, `scripts/inventory/inventories/*.json` — generated data).
- **Stale subset**: hardcoded list of 3 servers (`jupyter-mcp-server`, `jinavigator-server`,
  `roo-state-manager`) out of the 6 canonical servers in `mcps/internal/servers/` — missing
  `jupyter-papermill-mcp-server`, `open-terminal-mcp`, `sk-agent`. "Compile ALL MCPs" compiled half
  the fleet.
- Build coverage lives in `scripts/claude/ensure-build-fresh.ps1` and
  `scripts/mcp/validate-before-push.ps1`.
- Sibling `scripts/mcp/deploy-environment.ps1` (same cluster 3 in the issue Context) was checked
  and **KEPT**: it is referenced by live docs (`docs/architecture/repository-map.md`,
  `scripts/mcp/README.md`, design doc) — the zero-caller proof does not hold for it.
- Original preserved here: `compile-all-mcps.ps1`; a stub with this evidence remains at the
  original path.

### Zero-ref scripts (diagnostic/hierarchy/ — campaign finished)

`scripts/diagnostic/hierarchy/*` (8 scripts) — **ARCHIVED**.

These scripts were part of a one-shot investigation campaign. They are not referenced by:
- Skills (`.claude/skills/`)
- Rules (`.claude/rules/`)
- Workflows (`.github/workflows/`)
- Documentation (docs/)

Verified by `grep -r` for each script name across all non-archived source.

### Zero-ref `diagnostic-commit-charge-mystery.ps1`

ARCHIVED. One-shot diagnostic from a past investigation, no current usage.

**Correction 2026-09-19 (#2992)**: the stub header originally claimed the issue
was "resolved" — measured FALSE (issue still OPEN, gap never attributed, script
never run on ai-01; see stub header for the FR-locale defect note). The
zero-reference archival motive itself stands; only the resolution claim was wrong.

## Archive contents

Files copied here are preserved untouched for historical reference.
The active implementations live in:
- `scripts/mcp/cleanup-mcp-zombies.ps1` (unified with -Mode parameter)
- `scripts/claude/analyze-harness-tokens.ps1` (canonical)
- `scripts/claude/diagnose-harness.ps1` (thin wrapper to canonical)
- `scripts/diagnostic/cleanup-mcp-orphans.ps1` (thin wrapper to canonical)
- `scripts/maintenance/cleanup-mcp-stdio-zombies.ps1` (thin wrapper to canonical)
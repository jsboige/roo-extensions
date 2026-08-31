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
| `scripts/diagnostic/verify-mcp-files.ps1` | ARCHIVED | Verifies 5 paths: 2 retired MCPs (`jupyter-mcp-server`, `jinavigator-server`, `github-projects-mcp`, `quickfiles-server`) + 1 wrong path | MCPs are retired per `tool-availability.md` Retires section |

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

## Archive contents

Files copied here are preserved untouched for historical reference.
The active implementations live in:
- `scripts/mcp/cleanup-mcp-zombies.ps1` (unified with -Mode parameter)
- `scripts/claude/analyze-harness-tokens.ps1` (canonical)
- `scripts/claude/diagnose-harness.ps1` (thin wrapper to canonical)
- `scripts/diagnostic/cleanup-mcp-orphans.ps1` (thin wrapper to canonical)
- `scripts/maintenance/cleanup-mcp-stdio-zombies.ps1` (thin wrapper to canonical)
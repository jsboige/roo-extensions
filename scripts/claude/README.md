# Claude Code Scripts

This directory contains PowerShell scripts specific to Claude Code configuration and management.

**Consolidated from:** `.claude/scripts/` (Issue #866 - 2026-03-26)

These scripts were moved from `.claude/scripts/` to `scripts/claude/` to reduce friction with file execution permissions (Windows requires approval for scripts in certain locations).

## Scripts

### Initialization & Setup

- **`init-claude-code.ps1`** - Initialize Claude Code configuration from templates
  - Usage: `scripts/claude/init-claude-code.ps1`
  - Installs MCPs globally or per-project
  - Creates config files from templates

- **`Deploy-GlobalConfig.ps1`** - Deploy global CLAUDE.md/agents/skills/commands/**rules** to a machine
  - Usage: `.claude/configs/scripts/Deploy-GlobalConfig.ps1` (ou `-Target rules|claude-md|agents|skills|commands|settings`)
  - Copies configs from `.claude/configs/` to `~/.claude/`
  - **Copie unique depuis le 29/09/2026** (consolidation dispatch ai-01, règle de consolidation) :
    la copie locale `scripts/claude/Deploy-GlobalConfig.ps1` — amputée de `rules` du 26/05 au 02/09,
    puis restée sans la cible `settings` — a été supprimée après analyse ligne-par-ligne (chaque
    feature de l'ancien est byte-identique dans le canon ; blob conservé dans l'historique git).
    Garde : `scripts/testing/unit/deploy-global-config.Tests.ps1` (job CI `unit-pester`).

### Provider Management

- **`Switch-Provider.ps1`** - Switch between LLM providers and Claudish authentication contracts
  - Usage: `scripts/claude/Switch-Provider.ps1 -Provider [anthropic|zai|claudish|claudish-proxy]`
  - `claudish` is hybrid/pass-through: native Anthropic lanes require the client's local OAuth
  - `claudish-proxy` needs no Claude/Anthropic account: non-secret onboarding placeholders are separate from the real `x-proxy-key` hub credential
  - Updates `~/.claude/settings.json` with provider-specific config while preserving machine-owned settings
  - Version: 1.1.0 (includes verification)

- **`provider-preflight.ps1`** - Provider health check BEFORE a sub-agent fan-out (#3361)
  - Usage: `scripts/claude/provider-preflight.ps1 [-Model sonnet|opus|haiku|fable|all]`
  - Traces the chain `alias -> model ID -> endpoint`, probes `{BASE_URL}/v1/models`,
    and on 401/402/403 prints a diagnostic naming the config keys + remediation
  - Exit codes: 0 healthy / 1 config / 2 auth-billing / 3 unreachable / 4 routing mismatch
  - Guard: `scripts/testing/unit/provider-preflight.guard.Tests.ps1` (job CI `unit-pester`)

- **`Deploy-ProviderSwitcher.ps1`** - Deploy provider switcher infrastructure
  - Usage: `scripts/claude/Deploy-ProviderSwitcher.ps1 [-Update]`
  - Installs switcher commands and scripts globally

### MCP Configuration

- **`Switch-MCPConfig.ps1`** - Switch between MCP configurations (debugging tool)
  - Usage: `scripts/claude/Switch-MCPConfig.ps1 -Config [none|jupyter|roo|all|restore]`
  - Helps identify tool name conflicts

### Maintenance

- **`worktree-cleanup.ps1`** - Clean up orphan worktrees and stale branches
  - Usage: `scripts/claude/worktree-cleanup.ps1 [-WhatIf] [-Force]`
  - Issue: #856
  - Prevents VS Code notification overload

## Migration Notes

**Old paths (removed — `.claude/scripts/` no longer exists):**

- `.claude/scripts/init-claude-code.ps1`
- `.claude/scripts/Switch-Provider.ps1`
- `.claude/scripts/worktree-cleanup.ps1`

**New paths (recommended):**

- `scripts/claude/init-claude-code.ps1`
- `scripts/claude/Switch-Provider.ps1`
- `scripts/claude/worktree-cleanup.ps1`

The old `.claude/scripts/` directory has been removed; only the `scripts/claude/` paths above are valid.

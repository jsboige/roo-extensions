# Claude Code Scripts

This directory contains PowerShell scripts specific to Claude Code configuration and management.

**Consolidated from:** `.claude/scripts/` (Issue #866 - 2026-03-26)

These scripts were moved from `.claude/scripts/` to `scripts/claude/` to reduce friction with file execution permissions (Windows requires approval for scripts in certain locations).

## Scripts

### Initialization & Setup

- **`init-claude-code.ps1`** - Initialize Claude Code configuration from templates
  - Usage: `.claude/scripts/init-claude-code.ps1` (legacy) or `scripts/claude/init-claude-code.ps1` (new)
  - Installs MCPs globally or per-project
  - Creates config files from templates

- **`Deploy-GlobalConfig.ps1`** - Deploy global agents/skills/commands to all machines
  - Usage: `scripts/claude/Deploy-GlobalConfig.ps1`
  - Copies configs from `.claude/configs/` to `~/.claude/`

### Provider Management

- **`Switch-Provider.ps1`** - Switch between LLM providers (Anthropic/z.ai)
  - Usage: `scripts/claude/Switch-Provider.ps1 -Provider [anthropic|zai]`
  - Updates `~/.claude/settings.json` with provider-specific config
  - Version: 1.1.0 (includes verification)

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

**Old paths (deprecated but still work):**
- `.claude/scripts/init-claude-code.ps1`
- `.claude/scripts/Switch-Provider.ps1`
- `.claude/scripts/worktree-cleanup.ps1`

**New paths (recommended):**
- `scripts/claude/init-claude-code.ps1`
- `scripts/claude/Switch-Provider.ps1`
- `scripts/claude/worktree-cleanup.ps1`

The old paths in `.claude/scripts/` will be removed in a future cleanup phase once all references are updated.

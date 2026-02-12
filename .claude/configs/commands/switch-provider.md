---
description: Switch between LLM providers (Anthropic Claude API or z.ai GLM-5)
argument-hint: anthropic | zai
allowed-tools: Bash(powershell:*)
---

# Switch LLM Provider

Switch the active LLM provider for Claude Code to: **$ARGUMENTS**

## Available providers

- **anthropic**: Anthropic's official Claude API (Sonnet 4.5, Opus 4.6, Haiku 4.5)
- **zai**: z.ai GLM models (GLM-5, GLM-4.7, GLM-4.5-Air) via user's max subscription

## Process

Execute this PowerShell command to switch providers:

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME/.claude/scripts/Switch-Provider.ps1" -Provider $ARGUMENTS
```

This will:
1. Validate the provider choice
2. Load the appropriate configuration from `~/.claude/configs/provider.$ARGUMENTS.json`
3. Update `~/.claude/settings.json` with the provider-specific environment variables
4. Verify the configuration was applied successfully
5. Display confirmation with active model details

**IMPORTANT**: Use `Switch-Provider.ps1` (NOT Deploy-ProviderSwitcher.ps1)

Run with: `/switch-provider anthropic` or `/switch-provider zai`

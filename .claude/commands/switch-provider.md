---
description: Switch between LLM providers (Anthropic Claude API or z.ai GLM-4.7)
argument-hint: anthropic | zai
allowed-tools: Bash(powershell:*)
---

# Switch LLM Provider

Switch the active LLM provider for Claude Code to: **$1**

## Available providers

- **anthropic**: Anthropic's official Claude API (Sonnet 4.5, Opus 4.5, Haiku 4.5)
- **zai**: z.ai GLM models (GLM-4.7, GLM-4.5-Air) via user's max subscription

## Process

Execute this PowerShell command to switch providers:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\MYIA\.claude\scripts\Switch-Provider.ps1" -Provider $1
```

This will:
1. Validate the provider choice ($1)
2. Load the appropriate configuration from `~/.claude/configs/provider.$1.json`
3. Update `~/.claude/settings.json` with the provider-specific environment variables
4. Verify the configuration was applied successfully
5. Display confirmation with active model details

**IMPORTANT**: Use `Switch-Provider.ps1` (NOT Deploy-ProviderSwitcher.ps1)

Run with: `/switch-provider anthropic` or `/switch-provider zai`

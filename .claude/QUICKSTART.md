# Quick Start Guide - Provider Switcher

## ✅ What's Already Done

All source files have been created in this workspace:
- ✅ Slash command `/switch-provider`
- ✅ Switching script `Switch-Provider.ps1`
- ✅ Deployment script `Deploy-ProviderSwitcher.ps1`
- ✅ Provider configs (Anthropic + z.ai)
- ✅ Documentation

## 🚀 Next Steps (For You)

### Step 1: Restart VSCode (If Needed)

If you're still getting permission prompts, restart VSCode to apply the permission changes in `.claude/settings.local.json`.

### Step 2: Prepare Your z.ai API Key

You'll need your z.ai API key (created from your z.ai Max subscription for Claude Code).

**Note:** Anthropic provider doesn't need an API key - it uses your Claude Pro/Max browser authentication.

### Step 3: Run Deployment

Open a PowerShell terminal and run:

```powershell
cd d:\roo-extensions\.claude\scripts
.\Deploy-ProviderSwitcher.ps1
```

The script will:
1. Copy all files to `C:\Users\MYIA\.claude\`
2. Ask for your **z.ai API key** (input will be hidden)
3. Create provider configs
4. Confirm installation

### Step 4: Use the Slash Command

Once deployed, you can use the slash command in any Claude Code conversation:

```
/switch-provider anthropic   # Use Claude Pro/Max (default)
/switch-provider zai          # Use z.ai GLM-4.7
```

## 📋 Provider Overview

### Anthropic (Default)
- **Authentication:** Claude Pro/Max browser auth
- **No API key needed**
- **Models:** Opus 4.5, Sonnet 4.5, Haiku 4.5
- **Cost:** Included in your Pro/Max subscription

### z.ai
- **Authentication:** API key (from z.ai Max subscription)
- **API key required** (you'll be prompted)
- **Models:** GLM-4.7 (opus/sonnet), GLM-4.5-Air (haiku)
- **Cost:** Included in your z.ai Max subscription

## 🔄 Switching Between Providers

The switch is **instant** - just use the slash command:

```
/switch-provider zai
```

Output:
```
✅ Successfully switched to provider: zai

📋 Active Configuration:
   Provider: zai
   Base URL: https://api.z.ai/api/anthropic
   Model: sonnet

📊 Model Mapping:
   opus → GLM-4.7
   sonnet → GLM-4.7
   haiku → GLM-4.5-Air
```

Switch back:
```
/switch-provider anthropic
```

## 🔒 Security Notes

- Your z.ai API key is stored **only** in `C:\Users\MYIA\.claude\configs\`
- This directory is **outside** the git repo (never committed)
- Templates in the workspace are **without keys** (safe to commit)
- `.gitignore` is configured to protect real API keys

## ❓ Troubleshooting

### "Provider configuration not found"
Run `Deploy-ProviderSwitcher.ps1` first.

### "Execution Policy" error
Run as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Changes not taking effect
Restart VSCode after switching providers.

## 📚 Full Documentation

See [README.md](README.md) for complete documentation.

---

**Ready to deploy?** Run:
```powershell
cd d:\roo-extensions\.claude\scripts
.\Deploy-ProviderSwitcher.ps1
```

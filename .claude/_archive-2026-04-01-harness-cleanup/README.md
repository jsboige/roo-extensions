# Roo Extensions - Claude Code Workspace

**Repository:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Multi-Agent System:** RooSync v2.3 + Claude Code Coordination
**Machines:** 5 (myia-ai-01, myia-po-2023, myia-po-2024, myia-po-2026, myia-web1)

---

## 📚 Quick Start

### New to this workspace?

1. Read [INDEX.md](INDEX.md) for complete documentation map
2. See [docs/knowledge/WORKSPACE_KNOWLEDGE.md](../docs/knowledge/WORKSPACE_KNOWLEDGE.md) for workspace knowledge

### Claude Code Agent?

If you're a Claude Code agent participating in RooSync coordination:
1. Read [CLAUDE_CODE_GUIDE.md](CLAUDE_CODE_GUIDE.md) for Phase 0 grounding and complete guide
2. Read [docs/roosync/](../docs/roosync/) for RooSync documentation

---

## 🎯 System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ROOSYNC v2.3 SYSTEM                          │
├─────────────────────────────────────────────────────────────────┤
│  Agents Roo (Technical)    ↔    Agents Claude Code (Coordination)│
│  • Scripts, Tests, Build        • Documentation, Analysis      │
│  • 25 RooSync MCP tools         • Multi-agent coordination      │
│  • Qdrant semantic search       • GitHub Project integration    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Provider Switcher

Switch easily between LLM providers in Claude Code.

**Command:** `/switch-provider anthropic` or `/switch-provider zai`

**Documentation:** See [archive/README_PROVIDER_SWITCHER.md](archive/README_PROVIDER_SWITCHER.md)

---

## 📁 Directory Structure `.claude/`

```
.claude/
├── README.md                      # This file (entry point)
├── INDEX.md                       # Documentation map
├── CLAUDE_CODE_GUIDE.md           # Complete guide for Claude Code agents
├── MCP_SETUP.md                   # MCP configuration guide
├── INTERCOM_PROTOCOL.md           # Local communication protocol
├── agents/                        # Specialized subagents
├── commands/                      # Slash commands
├── skills/                        # Auto-invoked skills
├── scripts/                       # PowerShell scripts
└── configs/                       # Config templates
```

## Quick Start

### 1. Deploy to Your Machine (One-Time Setup)

```powershell
cd d:\roo-extensions\.claude\scripts
.\Deploy-ProviderSwitcher.ps1
```

The script will:
- Copy all necessary files to `~/.claude/`
- Prompt for your API keys securely
- Set up provider configurations

### 2. Use the Slash Command

Once deployed, the `/switch-provider` command is available in **all your workspaces**:

```
/switch-provider anthropic   # Switch to Anthropic Claude API
/switch-provider zai          # Switch to z.ai GLM models
```

## File Structure

### Workspace (Source)
```
.claude/
├── commands/
│   └── switch-provider.md              # Slash command definition
├── scripts/
│   ├── Switch-Provider.ps1             # Provider switching logic
│   └── Deploy-ProviderSwitcher.ps1     # Deployment script
├── configs/
│   ├── provider.anthropic.template.json   # Anthropic config template
│   └── provider.zai.template.json         # z.ai config template
└── README.md                           # This file
```

### Global Installation (`~/.claude/`)
```
.claude/
├── commands/
│   └── switch-provider.md              # Deployed slash command
├── scripts/
│   └── Switch-Provider.ps1             # Deployed switching script
├── configs/
│   ├── provider.anthropic.json         # Real config with API key
│   └── provider.zai.json               # Real config with API key
└── settings.json                       # Modified by switch script
```

## Provider Configurations

### Anthropic (Claude Pro/Max Browser Auth)

```json
{
  "provider": "anthropic",
  "model": "sonnet",
  "env": {}
}
```

**Authentication:** Uses your Claude Pro/Max subscription with browser authentication
**No API key required** - Claude Code uses your existing claude.ai session

**Models available:**
- `opus` → claude-opus-4-5
- `sonnet` → claude-sonnet-4-5
- `haiku` → claude-haiku-4-5

### z.ai (GLM Models)

```json
{
  "provider": "zai",
  "model": "opus",
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "zai-api-key",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5",
    "API_TIMEOUT_MS": "3000000"
  },
  "modelMapping": {
    "opus": "GLM-5",
    "sonnet": "GLM-4.7",
    "haiku": "GLM-4.5-Air"
  }
}
```

**Model mapping:**

- `opus` → GLM-5 (flagship, best performance, ~Opus 4.6 level)
- `sonnet` → GLM-4.7 (balanced performance)
- `haiku` → GLM-4.5-Air (faster, lighter)

## Deployment Options

### Fresh Install

```powershell
.\Deploy-ProviderSwitcher.ps1
```

Prompts for z.ai API key and deploys everything.
(Anthropic provider uses browser auth - no key needed)

### Update (Preserve API Keys)

```powershell
.\Deploy-ProviderSwitcher.ps1 -Update
```

Updates scripts/commands without changing API keys in configs.

### Uninstall

```powershell
.\Deploy-ProviderSwitcher.ps1 -Uninstall
```

Removes all deployed files from `~/.claude/`.

### Non-Interactive (CI/CD)

```powershell
.\Deploy-ProviderSwitcher.ps1 -ZaiApiKey "your-zai-api-key"
```

## How It Works

1. **Slash Command**: When you use `/switch-provider <name>`, Claude Code invokes the command
2. **Script Execution**: The command runs `Switch-Provider.ps1 -Provider <name>`
3. **Config Loading**: Script loads the appropriate `provider.<name>.json` file
4. **Settings Update**: Script merges provider config into `~/.claude/settings.json`
5. **Confirmation**: Script displays the active provider configuration

### Settings Merge Logic

The script preserves your existing settings while updating provider-specific values:

**Preserved:**
- Permissions
- Custom settings
- Other configurations

**Updated:**
- `env.ANTHROPIC_AUTH_TOKEN` (API key)
- `env.ANTHROPIC_BASE_URL` (API endpoint)
- `env.API_TIMEOUT_MS` (timeout)
- `model` (default model)

## Security

### API Key Protection

- **Templates** (`.template.json`) are versioned in git WITHOUT API keys
- **Real configs** (`.json`) contain API keys and are git-ignored
- **Secure input**: Deployment script uses `SecureString` for API key entry
- **Local storage**: API keys stored only in `~/.claude/configs/` (never committed)

### .gitignore Rules

```gitignore
# Never commit real API keys
.claude/configs/provider.*.json

# Allow templates (without keys)
!.claude/configs/provider.*.template.json

# Ignore backups
.claude/settings.json.backup-*
```

## Troubleshooting

### Error: "Provider configuration not found"

**Solution**: Run `Deploy-ProviderSwitcher.ps1` first to deploy configs.

### Error: "Execution Policy"

**Solution**: Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Changes not taking effect

**Solution**: Restart Claude Code (close and reopen VSCode) after switching providers.

### Want to update z.ai API key

**Solution**: Run deployment again without `-Update` flag:
```powershell
.\Deploy-ProviderSwitcher.ps1
```
It will prompt for the new z.ai API key.

## Multi-Machine Deployment (Advanced)

For synchronizing across multiple machines, integrate with RooSync:

```powershell
# On first machine (after deployment)
cd d:\roo-extensions\RooSync
.\sync_roo_environment.ps1

# On other machines
cd <roo-extensions-path>\RooSync
.\sync_roo_environment.ps1
# Then run Deploy-ProviderSwitcher.ps1
```

## Extending the System

### Adding a New Provider

1. Create template config:
   ```powershell
   cp .claude/configs/provider.anthropic.template.json .claude/configs/provider.newprovider.template.json
   ```

2. Edit the template with provider-specific settings

3. Update `Switch-Provider.ps1` ValidateSet:
   ```powershell
   [ValidateSet("anthropic", "zai", "newprovider")]
   ```

4. Redeploy:
   ```powershell
   .\Deploy-ProviderSwitcher.ps1 -Update
   ```

## Version

**Current Version**: 1.0.0

## License

Part of the roo-extensions project.

## Support

For issues or questions, refer to the main roo-extensions repository.

---

**Built with Claude Code** 🤖

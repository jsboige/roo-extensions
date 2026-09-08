#Requires -Version 5.1

<#
.SYNOPSIS
    Deploy Claude Code Provider Switcher to user's global Claude settings

.DESCRIPTION
    This script deploys the provider switcher infrastructure from the workspace
    to the user's global Claude Code settings directory (~/.claude/).

    It copies:
    - Slash command (switch-provider.md)
    - Provider switching script (Switch-Provider.ps1)
    - Provider configuration templates (converted to real configs with API keys)

.PARAMETER Uninstall
    Remove the provider switcher from global settings

.PARAMETER Update
    Update existing installation (preserves API keys in configs)

.PARAMETER ZaiApiKey
    z.ai API key (if not provided, will prompt securely)
    Note: Anthropic provider uses Claude Pro/Max browser auth (no key needed)

.EXAMPLE
    .\Deploy-ProviderSwitcher.ps1
    Interactive deployment with secure z.ai API key prompt

.EXAMPLE
    .\Deploy-ProviderSwitcher.ps1 -Update
    Update scripts/commands without changing API keys

.EXAMPLE
    .\Deploy-ProviderSwitcher.ps1 -Uninstall
    Remove provider switcher from global settings

.NOTES
    Author: Claude Code Provider Switcher
    Version: 1.0.0
#>

param(
    [switch]$Uninstall,
    [switch]$Update,
    [string]$ZaiApiKey,
    [string]$ClaudishProxyKey,
    [string]$MachineName = $env:COMPUTERNAME
)

$ErrorActionPreference = "Stop"

# Paths
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$configSourceRoot = Join-Path $repoRoot ".claude\configs"
$commandSourcePath = Join-Path $repoRoot ".claude\commands\switch-provider.md"
$switcherSourcePath = Join-Path $PSScriptRoot "Switch-Provider.ps1"
$targetRoot = Join-Path $env:USERPROFILE ".claude"

function Write-Header {
    param([string]$Text)
    Write-Host "`n$Text" -ForegroundColor Cyan
    Write-Host ("=" * $Text.Length) -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "✅ $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ️  $Text" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠️  $Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "❌ $Text" -ForegroundColor Red
}

function Backup-IfExists {
    param([string]$Path)

    if (Test-Path $Path) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
        Copy-Item $Path "$Path.backup-$timestamp"
    }
}

function Get-SecureApiKey {
    param(
        [string]$ProviderName,
        [string]$ExistingKey
    )

    if ($ExistingKey) {
        return $ExistingKey
    }

    Write-Host "`nEnter your $ProviderName API key (input will be hidden): " -ForegroundColor Yellow -NoNewline
    $secureKey = Read-Host -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $key = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Error "API key cannot be empty"
        exit 1
    }

    return $key
}

function Uninstall-ProviderSwitcher {
    Write-Header "🗑️  Uninstalling Claude Code Provider Switcher"

    $itemsToRemove = @(
        (Join-Path $targetRoot "commands\switch-provider.md"),
        (Join-Path $targetRoot "scripts\Switch-Provider.ps1"),
        (Join-Path $targetRoot "configs\provider.anthropic.json"),
        (Join-Path $targetRoot "configs\provider.zai.json"),
        (Join-Path $targetRoot "configs\provider.claudish.json"),
        (Join-Path $targetRoot "configs\provider.claudish-proxy.json")
    )

    $removedCount = 0
    foreach ($item in $itemsToRemove) {
        if (Test-Path $item) {
            Remove-Item $item -Force
            Write-Success "Removed: $item"
            $removedCount++
        }
    }

    if ($removedCount -eq 0) {
        Write-Info "Provider switcher was not installed (nothing to remove)"
    } else {
        Write-Success "Provider switcher uninstalled successfully ($removedCount files removed)"
    }

    Write-Host ""
    exit 0
}

# Main script
try {
    if ($Uninstall) {
        Uninstall-ProviderSwitcher
    }

    Write-Header "🚀 Claude Code Provider Switcher Deployment"

    # Verify source files exist
    Write-Info "Verifying source files..."
    $requiredFiles = @(
        $commandSourcePath,
        $switcherSourcePath,
        (Join-Path $configSourceRoot "provider.anthropic.template.json"),
        (Join-Path $configSourceRoot "provider.zai.template.json"),
        (Join-Path $configSourceRoot "provider.claudish.template.json"),
        (Join-Path $configSourceRoot "provider.claudish-proxy.template.json")
    )

    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            $missingFiles += $file
        }
    }

    if ($missingFiles.Count -gt 0) {
        Write-Error "Missing required source files:"
        $missingFiles | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
        Write-Host "`n💡 Tip: Ensure you're running this from the roo-extensions workspace`n" -ForegroundColor Yellow
        exit 1
    }

    Write-Success "All source files found"

    # Create target directories
    Write-Info "Creating target directories..."
    @("commands", "scripts", "configs") | ForEach-Object {
        $dir = Join-Path $targetRoot $_
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Success "Created: $dir"
        }
    }

    # Copy commands and scripts
    Write-Info "Copying commands and scripts..."

    $filesToCopy = @{
        $commandSourcePath = (Join-Path $targetRoot "commands\switch-provider.md")
        $switcherSourcePath = (Join-Path $targetRoot "scripts\Switch-Provider.ps1")
    }

    foreach ($source in $filesToCopy.Keys) {
        $dest = $filesToCopy[$source]
        Copy-Item $source $dest -Force
        Write-Success "Copied: $(Split-Path $dest -Leaf)"
    }

    # Handle provider configs
    Write-Info "Configuring provider settings..."

    $anthropicConfigPath = Join-Path $targetRoot "configs\provider.anthropic.json"
    $zaiConfigPath = Join-Path $targetRoot "configs\provider.zai.json"
    $claudishConfigPath = Join-Path $targetRoot "configs\provider.claudish.json"
    $claudishProxyConfigPath = Join-Path $targetRoot "configs\provider.claudish-proxy.json"

    # Check if updating existing installation
    if ($Update -and (Test-Path $anthropicConfigPath) -and (Test-Path $zaiConfigPath) -and
        (Test-Path $claudishConfigPath)) {
        Write-Warning "Update mode: Preserving existing credentials while refreshing Claudish profiles"

        $existingHybrid = Get-Content $claudishConfigPath -Raw | ConvertFrom-Json
        $existingProxy = if (Test-Path $claudishProxyConfigPath) {
            Get-Content $claudishProxyConfigPath -Raw | ConvertFrom-Json
        } else {
            $null
        }
        $claudishTemplate = Get-Content (Join-Path $configSourceRoot "provider.claudish.template.json") -Raw | ConvertFrom-Json
        $claudishProxyTemplate = Get-Content (Join-Path $configSourceRoot "provider.claudish-proxy.template.json") -Raw | ConvertFrom-Json

        $existingHeaders = $existingProxy.env.ANTHROPIC_CUSTOM_HEADERS
        if (-not $existingHeaders) {
            $existingHeaders = $existingHybrid.env.ANTHROPIC_CUSTOM_HEADERS
        }
        if (-not $existingHeaders -and $ClaudishProxyKey) {
            $machineHeader = if ($MachineName) { $MachineName } else { 'external-client' }
            $existingHeaders = "X-Claudish-Machine: $machineHeader`nx-proxy-key: $ClaudishProxyKey"
        }
        if (-not $existingHeaders) {
            throw "Existing Claudish configs contain no ANTHROPIC_CUSTOM_HEADERS; rerun -Update with -ClaudishProxyKey supplied securely"
        }

        $claudishTemplate.env.ANTHROPIC_CUSTOM_HEADERS = $existingHeaders
        $claudishProxyTemplate.env.ANTHROPIC_CUSTOM_HEADERS = $existingHeaders

        Backup-IfExists $claudishConfigPath
        Backup-IfExists $claudishProxyConfigPath

        $claudishJson = $claudishTemplate | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($claudishConfigPath, $claudishJson, [System.Text.UTF8Encoding]::new($false))

        $claudishProxyJson = $claudishProxyTemplate | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($claudishProxyConfigPath, $claudishProxyJson, [System.Text.UTF8Encoding]::new($false))

        Write-Success "Anthropic and z.ai credentials preserved"
        Write-Success "Claudish hybrid and proxy-only profiles refreshed"
    } else {
        # Fresh install or missing configs
        Write-Info "Setting up provider configurations..."

        # Load templates
        $anthropicTemplate = Get-Content (Join-Path $configSourceRoot "provider.anthropic.template.json") -Raw | ConvertFrom-Json
        $zaiTemplate = Get-Content (Join-Path $configSourceRoot "provider.zai.template.json") -Raw | ConvertFrom-Json
        $claudishTemplate = Get-Content (Join-Path $configSourceRoot "provider.claudish.template.json") -Raw | ConvertFrom-Json
        $claudishProxyTemplate = Get-Content (Join-Path $configSourceRoot "provider.claudish-proxy.template.json") -Raw | ConvertFrom-Json

        # Anthropic config: No API key needed (uses browser auth from Pro/Max subscription)
        Write-Info "Anthropic provider: Using Claude Pro/Max browser authentication (no API key required)"

        # z.ai config: Need API key
        if (-not $Update) {
            Write-Host "`n" + ("─" * 60) -ForegroundColor Gray
            Write-Host "🔑 z.ai API Key Configuration" -ForegroundColor Yellow
            Write-Host ("─" * 60) -ForegroundColor Gray
            Write-Host "Note: Anthropic provider uses your Claude Pro/Max subscription (no key needed)" -ForegroundColor Gray
            Write-Host ""
        }

        $zaiKey = Get-SecureApiKey -ProviderName "z.ai" -ExistingKey $ZaiApiKey

        # Apply API key to z.ai template
        $zaiTemplate.env.ANTHROPIC_AUTH_TOKEN = $zaiKey

        # Claudish config: Need proxy key (from claudish container's ~/.claudish/config.json)
        Write-Host ""
        Write-Host ("─" * 60) -ForegroundColor Gray
        Write-Host "🔑 Claudish Proxy Key Configuration" -ForegroundColor Yellow
        Write-Host ("─" * 60) -ForegroundColor Gray
        Write-Host "Enter the proxy key from ~/.claudish/config.json (proxyKey field)" -ForegroundColor Gray
        Write-Host "This is the x-proxy-key that authenticates to the claudish container" -ForegroundColor Gray
        Write-Host ""

        $proxyKey = Get-SecureApiKey -ProviderName "Claudish proxy" -ExistingKey $ClaudishProxyKey

        # The real proxy key belongs only in x-proxy-key. ANTHROPIC_AUTH_TOKEN in
        # proxy-only mode is a non-secret placeholder used to bypass local onboarding.
        $machineHeader = if ($MachineName) { $MachineName } else { 'external-client' }
        $customHeaders = "X-Claudish-Machine: $machineHeader`nx-proxy-key: $proxyKey"
        $claudishTemplate.env.ANTHROPIC_CUSTOM_HEADERS = $customHeaders
        $claudishProxyTemplate.env.ANTHROPIC_CUSTOM_HEADERS = $customHeaders

        # Back up any partial installation before replacing its configs.
        Backup-IfExists $anthropicConfigPath
        Backup-IfExists $zaiConfigPath
        Backup-IfExists $claudishConfigPath
        Backup-IfExists $claudishProxyConfigPath

        # Save configs (BOM-free UTF-8 for Claude Code compatibility)
        $anthropicJson = $anthropicTemplate | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($anthropicConfigPath, $anthropicJson, [System.Text.UTF8Encoding]::new($false))

        $zaiJson = $zaiTemplate | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($zaiConfigPath, $zaiJson, [System.Text.UTF8Encoding]::new($false))

        $claudishJson = $claudishTemplate | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($claudishConfigPath, $claudishJson, [System.Text.UTF8Encoding]::new($false))

        $claudishProxyJson = $claudishProxyTemplate | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($claudishProxyConfigPath, $claudishProxyJson, [System.Text.UTF8Encoding]::new($false))

        Write-Host ""
        Write-Success "Provider configs created"
        Write-Info "  • Anthropic: Browser auth (Claude Pro/Max)"
        Write-Info "  • z.ai: API key configured"
        Write-Info "  • Claudish: Hybrid proxy with Anthropic pass-through"
        Write-Info "  • Claudish proxy-only: No Anthropic account required"
    }

    # Success summary
    Write-Header "✨ Deployment Complete!"

    Write-Host "📁 Installation Location: " -NoNewline -ForegroundColor Cyan
    Write-Host $targetRoot -ForegroundColor White

    Write-Host "`n📦 Installed Components:" -ForegroundColor Cyan
    Write-Host "   • Slash command: /switch-provider" -ForegroundColor White
    Write-Host "   • Switching script: Switch-Provider.ps1" -ForegroundColor White
    Write-Host "   • Provider configs: anthropic, zai, claudish, claudish-proxy" -ForegroundColor White

    Write-Host "`n🎯 Usage:" -ForegroundColor Cyan
    Write-Host "   In Claude Code, use the slash command:" -ForegroundColor Gray
    Write-Host "     /switch-provider anthropic   " -NoNewline -ForegroundColor Yellow
    Write-Host "→ Switch to Anthropic Claude API" -ForegroundColor Gray
    Write-Host "     /switch-provider zai          " -NoNewline -ForegroundColor Yellow
    Write-Host "→ Switch to z.ai GLM models" -ForegroundColor Gray
    Write-Host "     /switch-provider claudish     " -NoNewline -ForegroundColor Yellow
    Write-Host "→ Switch to Claudish with Anthropic pass-through" -ForegroundColor Gray
    Write-Host "     /switch-provider claudish-proxy" -NoNewline -ForegroundColor Yellow
    Write-Host " → Switch to Claudish without an Anthropic account" -ForegroundColor Gray

    Write-Host "`n💡 Tips:" -ForegroundColor Cyan
    Write-Host "   • The slash command is now available in ALL your workspaces" -ForegroundColor Gray
    Write-Host "   • Your API keys are stored securely in $targetRoot\configs\" -ForegroundColor Gray
    Write-Host "   • Run with -Update to update scripts without changing API keys" -ForegroundColor Gray
    Write-Host "   • Run with -Uninstall to remove the provider switcher" -ForegroundColor Gray

    Write-Host ""

} catch {
    Write-Host "`n❌ Deployment failed:" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n$($_.ScriptStackTrace)`n" -ForegroundColor DarkRed
    exit 1
}

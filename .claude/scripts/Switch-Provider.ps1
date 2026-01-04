#Requires -Version 5.1

<#
.SYNOPSIS
    Switch between LLM providers for Claude Code

.DESCRIPTION
    This script switches Claude Code between different LLM providers (Anthropic, z.ai)
    by updating the user's settings.json file with provider-specific configurations.

.PARAMETER Provider
    The provider to switch to. Valid values: anthropic, zai

.EXAMPLE
    .\Switch-Provider.ps1 -Provider anthropic
    Switch to Anthropic's Claude API

.EXAMPLE
    .\Switch-Provider.ps1 -Provider zai
    Switch to z.ai GLM models

.NOTES
    Author: Claude Code Provider Switcher
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet("anthropic", "zai")]
    [string]$Provider
)

# Error handling
$ErrorActionPreference = "Stop"

# Function to merge JSON objects
function Merge-JsonObjects {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Base,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Override
    )

    $result = $Base.PSObject.Copy()

    foreach ($property in $Override.PSObject.Properties) {
        if ($result.PSObject.Properties.Name -contains $property.Name) {
            if ($property.Value -is [PSCustomObject] -and $result.($property.Name) -is [PSCustomObject]) {
                $result.($property.Name) = Merge-JsonObjects -Base $result.($property.Name) -Override $property.Value
            } else {
                $result.($property.Name) = $property.Value
            }
        } else {
            $result | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
        }
    }

    return $result
}

try {
    Write-Host "`n🔄 Claude Code Provider Switcher" -ForegroundColor Cyan
    Write-Host "================================`n" -ForegroundColor Cyan

    # Resolve provider config path (check global first, then workspace)
    $globalConfigPath = Join-Path $env:USERPROFILE ".claude\configs\provider.$Provider.json"
    $workspaceConfigPath = "d:\roo-extensions\.claude\configs\provider.$Provider.json"

    $providerConfigPath = $null
    if (Test-Path $globalConfigPath) {
        $providerConfigPath = $globalConfigPath
        Write-Host "📂 Using global config: $globalConfigPath" -ForegroundColor Gray
    } elseif (Test-Path $workspaceConfigPath) {
        $providerConfigPath = $workspaceConfigPath
        Write-Host "📂 Using workspace config: $workspaceConfigPath" -ForegroundColor Gray
    } else {
        Write-Host "❌ Error: Provider configuration not found for '$Provider'" -ForegroundColor Red
        Write-Host "   Expected locations:" -ForegroundColor Yellow
        Write-Host "   - $globalConfigPath" -ForegroundColor Yellow
        Write-Host "   - $workspaceConfigPath" -ForegroundColor Yellow
        Write-Host "`n💡 Tip: Run Deploy-ProviderSwitcher.ps1 first to set up provider configs`n" -ForegroundColor Cyan
        exit 1
    }

    # Load provider configuration
    Write-Host "📖 Loading provider configuration..." -ForegroundColor Gray
    $providerConfig = Get-Content $providerConfigPath -Raw | ConvertFrom-Json

    # User settings path
    $userSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"

    # Load or create user settings
    if (Test-Path $userSettingsPath) {
        Write-Host "📖 Loading existing user settings..." -ForegroundColor Gray
        $userSettings = Get-Content $userSettingsPath -Raw | ConvertFrom-Json

        # Create backup
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = "$userSettingsPath.backup-$timestamp"
        Copy-Item $userSettingsPath $backupPath
        Write-Host "�� Backup created: $backupPath" -ForegroundColor Gray
    } else {
        Write-Host "📝 Creating new settings.json..." -ForegroundColor Gray
        $userSettings = [PSCustomObject]@{}

        # Ensure directory exists
        $settingsDir = Split-Path $userSettingsPath
        if (-not (Test-Path $settingsDir)) {
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        }
    }

    # Merge provider config into user settings (keeping only essential properties)
    Write-Host "🔧 Applying provider configuration..." -ForegroundColor Gray

    # Create clean settings object with only essential properties
    $cleanSettings = [PSCustomObject]@{}

    # Preserve non-provider-specific settings from existing settings
    $preservedProperties = @('permissions', 'mcpServers', 'hooks', 'allowed-tools', 'denied-tools')
    foreach ($prop in $preservedProperties) {
        if ($userSettings.PSObject.Properties.Name -contains $prop) {
            $cleanSettings | Add-Member -MemberType NoteProperty -Name $prop -Value $userSettings.$prop
        }
    }

    # Update env variables (if present)
    if ($providerConfig.PSObject.Properties.Name -contains 'env') {
        $envObj = $providerConfig.env
        if ($envObj.PSObject.Properties.Count -gt 0) {
            $cleanSettings | Add-Member -MemberType NoteProperty -Name 'env' -Value $envObj
        }
    }

    # Update model if specified
    if ($providerConfig.PSObject.Properties.Name -contains 'model') {
        $cleanSettings | Add-Member -MemberType NoteProperty -Name 'model' -Value $providerConfig.model
    }

    # Replace user settings with clean version
    $userSettings = $cleanSettings

    # Save updated settings
    $userSettings | ConvertTo-Json -Depth 10 | Set-Content $userSettingsPath -Encoding UTF8

    Write-Host "`n✅ Successfully switched to provider: " -NoNewline -ForegroundColor Green
    Write-Host "$Provider" -ForegroundColor White -BackgroundColor DarkGreen

    Write-Host "`n📋 Active Configuration:" -ForegroundColor Cyan
    Write-Host "   Provider: $Provider" -ForegroundColor White
    if ($providerConfig.env.PSObject.Properties.Name -contains 'ANTHROPIC_BASE_URL') {
        Write-Host "   Base URL: $($providerConfig.env.ANTHROPIC_BASE_URL)" -ForegroundColor White
    } else {
        Write-Host "   Base URL: (default Anthropic API endpoint)" -ForegroundColor Gray
    }
    Write-Host "   Model: $($providerConfig.model)" -ForegroundColor White

    if ($providerConfig.PSObject.Properties.Name -contains 'modelMapping') {
        Write-Host "`n📊 Model Mapping:" -ForegroundColor Cyan
        $providerConfig.modelMapping.PSObject.Properties | ForEach-Object {
            Write-Host "   $($_.Name) → $($_.Value)" -ForegroundColor White
        }
    }

    Write-Host "`n💡 Note: You may need to restart Claude Code for changes to take effect.`n" -ForegroundColor Yellow

} catch {
    Write-Host "`n❌ Error occurred while switching provider:" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n$($_.ScriptStackTrace)`n" -ForegroundColor DarkRed
    exit 1
}

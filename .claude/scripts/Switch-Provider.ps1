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
    Version: 1.1.0 (FIX #844 - Added verification)
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

    # Resolve provider config path - use global config only
    $globalConfigPath = Join-Path $env:USERPROFILE ".claude\configs\provider.$Provider.json"

    $providerConfigPath = $null
    if (Test-Path $globalConfigPath) {
        $providerConfigPath = $globalConfigPath
        Write-Host "📂 Using global config: $globalConfigPath" -ForegroundColor Gray
    } else {
        Write-Host "❌ Error: Provider configuration not found for '$Provider'" -ForegroundColor Red
        Write-Host "   Expected location: $globalConfigPath" -ForegroundColor Yellow
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
        Write-Host "💾 Backup created: $backupPath" -ForegroundColor Gray
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

    # Update env variables - MERGE to preserve existing API keys
    # Protected keys that should NEVER be overwritten from template placeholders
    # Note: ANTHROPIC_AUTH_TOKEN is NOT protected - it's a z.ai override token
    # that must be removed when switching to Anthropic (handled by removeEnv)
    $protectedKeys = @('ANTHROPIC_API_KEY')

    # Start with existing env if present
    $mergedEnv = @{}
    if ($userSettings.PSObject.Properties.Name -contains 'env') {
        foreach ($prop in $userSettings.env.PSObject.Properties) {
            $mergedEnv[$prop.Name] = $prop.Value
        }
    }

    # Merge provider env, but skip protected keys that already exist
    if ($providerConfig.PSObject.Properties.Name -contains 'env') {
        foreach ($prop in $providerConfig.env.PSObject.Properties) {
            $keyName = $prop.Name
            # Skip protected keys if they already exist in user settings
            if ($protectedKeys -contains $keyName -and $mergedEnv.ContainsKey($keyName)) {
                Write-Host "   🔐 Preserving existing $keyName" -ForegroundColor Yellow
                continue
            }
            $mergedEnv[$keyName] = $prop.Value
        }
    }

    # Remove env keys specified in removeEnv array (for switching providers)
    if ($providerConfig.PSObject.Properties.Name -contains 'removeEnv') {
        foreach ($keyToRemove in $providerConfig.removeEnv) {
            if ($mergedEnv.ContainsKey($keyToRemove)) {
                Write-Host "   🗑️ Removing $keyToRemove" -ForegroundColor Gray
                $mergedEnv.Remove($keyToRemove)
            }
        }
    }

    # Add merged env to clean settings
    if ($mergedEnv.Count -gt 0) {
        $envObj = [PSCustomObject]$mergedEnv
        $cleanSettings | Add-Member -MemberType NoteProperty -Name 'env' -Value $envObj
    }

    # Update model if specified
    if ($providerConfig.PSObject.Properties.Name -contains 'model') {
        $cleanSettings | Add-Member -MemberType NoteProperty -Name 'model' -Value $providerConfig.model
    }

    # Replace user settings with clean version
    $userSettings = $cleanSettings

    # Save updated settings
    $userSettings | ConvertTo-Json -Depth 10 | Set-Content $userSettingsPath -Encoding UTF8

    # ========== FIX #844: VERIFICATION STEP ==========
    Write-Host "`n🔍 Verifying configuration was applied..." -ForegroundColor Yellow

    # Re-read the file to confirm it was written correctly
    $verifiedSettings = Get-Content $userSettingsPath -Raw | ConvertFrom-Json

    # Critical checks
    $verificationPassed = $true
    $verificationErrors = @()

    # Check 1: Model is correct
    if ($verifiedSettings.PSObject.Properties.Name -contains 'model') {
        if ($verifiedSettings.model -eq $providerConfig.model) {
            Write-Host "   ✅ Model: $($verifiedSettings.model)" -ForegroundColor Green
        } else {
            $verificationPassed = $false
            $verificationErrors += "Model mismatch: expected '$($providerConfig.model)', got '$($verifiedSettings.model)'"
            Write-Host "   ❌ Model mismatch: expected '$($providerConfig.model)', got '$($verifiedSettings.model)'" -ForegroundColor Red
        }
    } else {
        $verificationPassed = $false
        $verificationErrors += "Model property missing from settings.json"
        Write-Host "   ❌ Model property missing from settings.json" -ForegroundColor Red
    }

    # Check 2: ANTHROPIC_BASE_URL is correct for provider
    if ($Provider -eq "zai") {
        if ($verifiedSettings.env.PSObject.Properties.Name -contains 'ANTHROPIC_BASE_URL') {
            $expectedUrl = if ($providerConfig.env.PSObject.Properties.Name -contains 'ANTHROPIC_BASE_URL') {
                $providerConfig.env.ANTHROPIC_BASE_URL
            } else {
                "https://api.anthropic.com"
            }
            if ($verifiedSettings.env.ANTHROPIC_BASE_URL -eq $expectedUrl) {
                Write-Host "   ✅ Base URL: $($verifiedSettings.env.ANTHROPIC_BASE_URL)" -ForegroundColor Green
            } else {
                $verificationPassed = $false
                $verificationErrors += "Base URL mismatch: expected '$expectedUrl', got '$($verifiedSettings.env.ANTHROPIC_BASE_URL)'"
                Write-Host "   ❌ Base URL mismatch" -ForegroundColor Red
            }
        } else {
            # z.ai MUST have ANTHROPIC_BASE_URL set
            $verificationPassed = $false
            $verificationErrors += "ANTHROPIC_BASE_URL missing (required for z.ai)"
            Write-Host "   ❌ ANTHROPIC_BASE_URL missing (required for z.ai)" -ForegroundColor Red
        }
    } else {
        # anthropic should NOT have custom base URL (or default)
        if ($verifiedSettings.env.PSObject.Properties.Name -contains 'ANTHROPIC_BASE_URL') {
            $url = $verifiedSettings.env.ANTHROPIC_BASE_URL
            if ($url -eq "https://api.anthropic.com" -or $url -eq "https://api.anthropic.com/") {
                Write-Host "   ✅ Base URL: (default Anthropic endpoint)" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Base URL: $url (non-default, verify this is correct)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ✅ Base URL: (default Anthropic endpoint)" -ForegroundColor Green
        }
    }

    # Check 3: Provider-specific keys are removed when switching
    if ($providerConfig.PSObject.Properties.Name -contains 'removeEnv') {
        foreach ($keyToRemove in $providerConfig.removeEnv) {
            if ($verifiedSettings.env.PSObject.Properties.Name -contains $keyToRemove) {
                $verificationPassed = $false
                $verificationErrors += "Key '$keyToRemove' should have been removed but still exists"
                Write-Host "   ❌ Key '$keyToRemove' should have been removed" -ForegroundColor Red
            }
        }
    }

    # Final verdict
    if (-not $verificationPassed) {
        Write-Host "`n❌ VERIFICATION FAILED!" -ForegroundColor Red
        Write-Host "   The configuration was written but verification checks failed." -ForegroundColor Red
        Write-Host "`n   Errors:" -ForegroundColor Red
        foreach ($err in $verificationErrors) {
            Write-Host "   • $err" -ForegroundColor DarkRed
        }
        Write-Host "`n   Action: The backup has been preserved at: $backupPath" -ForegroundColor Yellow
        Write-Host "   Please investigate manually or try again.`n" -ForegroundColor Yellow
        exit 1
    }

    # ========== END FIX #844 ==========

    Write-Host "`n✅ Successfully switched to provider: " -NoNewline -ForegroundColor Green
    Write-Host "$Provider" -ForegroundColor White -BackgroundColor DarkGreen

    Write-Host "`n📋 Active Configuration:" -ForegroundColor Cyan
    Write-Host "   Provider: $Provider" -ForegroundColor White
    if ($verifiedSettings.env.PSObject.Properties.Name -contains 'ANTHROPIC_BASE_URL') {
        Write-Host "   Base URL: $($verifiedSettings.env.ANTHROPIC_BASE_URL)" -ForegroundColor White
    } else {
        Write-Host "   Base URL: (default Anthropic API endpoint)" -ForegroundColor Gray
    }
    Write-Host "   Model: $($verifiedSettings.model)" -ForegroundColor White

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

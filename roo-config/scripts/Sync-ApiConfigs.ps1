#Requires -Version 5.1

<#
.SYNOPSIS
    Sync API configs from model-configs.json to Roo VS Code settings

.DESCRIPTION
    Reads apiConfigs from roo-config/model-configs.json and synchronizes them
    to the Roo VS Code extension settings (cline_custom_instructions.md).
    This automates the manual step of updating API configs after model changes.

.PARAMETER ModelConfigsPath
    Path to model-configs.json (default: roo-config/model-configs.json)

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\Sync-ApiConfigs.ps1
    Sync all API configs from model-configs.json

.EXAMPLE
    .\Sync-ApiConfigs.ps1 -DryRun
    Preview changes without modifying settings

.NOTES
    The Roo VS Code settings file is located at:
    %APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\cline_custom_instructions.md

    API configs in model-configs.json use this structure:
    {
      "apiConfigs": {
        "config-id": {
          "apiProvider": "openai",
          "openAiBaseUrl": "...",
          "openAiModelId": "...",
          ...
        }
      }
    }

    The script maps these to Roo's provider settings format.
#>

param(
    [string]$ModelConfigsPath = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Resolve paths
$repoRoot = (Get-Item "$PSScriptRoot\..\.." -ErrorAction SilentlyContinue).FullName
if (-not $ModelConfigsPath) {
    $ModelConfigsPath = Join-Path $repoRoot "roo-config\model-configs.json"
}

if (-not (Test-Path $ModelConfigsPath)) {
    Write-Host "ERROR: model-configs.json not found at: $ModelConfigsPath" -ForegroundColor Red
    exit 1
}

# Read model-configs.json
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$modelConfigsContent = [System.IO.File]::ReadAllText($ModelConfigsPath, $utf8NoBom)
$modelConfigs = $modelConfigsContent | ConvertFrom-Json

if (-not $modelConfigs.apiConfigs) {
    Write-Host "ERROR: No apiConfigs found in model-configs.json" -ForegroundColor Red
    exit 1
}

# Determine Roo settings path
$rooSettingsDir = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
$rooSettingsFile = Join-Path $rooSettingsDir "cline_custom_instructions.md"

# Check if Roo settings directory exists
if (-not (Test-Path $rooSettingsDir)) {
    Write-Host "WARNING: Roo VS Code settings directory not found: $rooSettingsDir" -ForegroundColor Yellow
    Write-Host "This is expected if Roo extension is not installed on this machine." -ForegroundColor Gray
    Write-Host "`nThe API configs will be displayed but not synced." -ForegroundColor Gray
    $rooInstalled = $false
} else {
    $rooInstalled = $true
}

# Display API configs to sync
Write-Host "`nAPI Configs to sync:" -ForegroundColor Cyan
$configCount = 0
foreach ($configId in $modelConfigs.apiConfigs.PSObject.Properties.Name) {
    $config = $modelConfigs.apiConfigs.$configId
    $configCount++

    Write-Host "`n[$configId]" -ForegroundColor White
    Write-Host "  Description: $($config.description)" -ForegroundColor Gray
    Write-Host "  Provider: $($config.apiProvider)" -ForegroundColor Cyan

    # Map model-configs.json fields to Roo provider settings
    $provider = $config.apiProvider
    switch ($provider) {
        "openai" {
            $modelId = $config.openAiModelId
            $baseUrl = $config.openAiBaseUrl
            $apiKey = $config.openAiApiKey
            Write-Host "  Model: $modelId" -ForegroundColor Green
            Write-Host "  Base URL: $baseUrl" -ForegroundColor Green
        }
        "anthropic" {
            $modelId = $config.apiModelId
            $baseUrl = $config.anthropicBaseUrl
            Write-Host "  Model: $modelId" -ForegroundColor Green
            if ($baseUrl) { Write-Host "  Base URL: $baseUrl" -ForegroundColor Green }
        }
        default {
            Write-Host "  Model: $($config.PSObject.Properties.Where({ $_.Name -like '*ModelId' }).ForEach({ $_.Value }) | Select-Object -First 1)" -ForegroundColor Green
        }
    }
}

Write-Host "`nTotal: $configCount API config(s)" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "`nDRY RUN - No changes made." -ForegroundColor Yellow
    exit 0
}

if (-not $rooInstalled) {
    Write-Host "`nSkipping sync (Roo extension not installed)" -ForegroundColor Yellow
    exit 0
}

# Backup existing settings
if (Test-Path $rooSettingsFile) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$rooSettingsFile.backup-$timestamp"
    Copy-Item $rooSettingsFile $backupPath
    Write-Host "`nBackup: $backupPath" -ForegroundColor Gray
}

# Read existing settings
$existingSettings = ""
if (Test-Path $rooSettingsFile) {
    $existingSettings = [System.IO.File]::ReadAllText($rooSettingsFile, $utf8NoBom)
}

# Parse existing settings to find the API configs section
# The format is typically markdown with embedded JSON
$inApiConfigsSection = $false
$apiConfigsSection = ""
$beforeApiConfigs = ""
$afterApiConfigs = ""

$lines = $existingSettings -split "`n"
$apiConfigsStart = -1
$apiConfigsEnd = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '```json.*apiConfigs') {
        $apiConfigsStart = $i
    } elseif ($apiConfigsStart -ge 0 -and $lines[$i] -match '```') {
        $apiConfigsEnd = $i
        break
    }
}

# Build new API configs section
$newApiConfigsSection = @'

## API Configurations

```json
{
'@

# Add each API config
foreach ($configId in $modelConfigs.apiConfigs.PSObject.Properties.Name) {
    $config = $modelConfigs.apiConfigs.$configId

    # Build Roo provider settings from model-configs.json format
    $rooConfig = @{
        id = $configId
        name = $configId
        apiProvider = $config.apiProvider
    }

    # Map fields based on provider
    switch ($config.apiProvider) {
        "openai" {
            if ($config.openAiModelId) { $rooConfig["openAiModelId"] = $config.openAiModelId }
            if ($config.openAiBaseUrl) { $rooConfig["openAiBaseUrl"] = $config.openAiBaseUrl }
            if ($config.openAiApiKey) { $rooConfig["openAiApiKey"] = $config.openAiApiKey }
            if ($config.modelTemperature) { $rooConfig["modelTemperature"] = $config.modelTemperature }
        }
        "anthropic" {
            if ($config.apiModelId) { $rooConfig["apiModelId"] = $config.apiModelId }
            if ($config.anthropicBaseUrl) { $rooConfig["anthropicBaseUrl"] = $config.anthropicBaseUrl }
            if ($config.anthropicApiKey) { $rooConfig["apiKey"] = $config.anthropicApiKey }
            if ($config.modelTemperature) { $rooConfig["modelTemperature"] = $config.modelTemperature }
        }
    }

    # Convert to JSON and add comma if not last
    $configJson = $rooConfig | ConvertTo-Json -Depth 10
    $newApiConfigsSection += "  `"$configId``: $configJson"

    # Add comma if not last config
    if ($configId -ne $modelConfigs.apiConfigs.PSObject.Properties.Name[-1]) {
        $newApiConfigsSection += ","
    }
    $newApiConfigsSection += "`n"
}

$newApiConfigsSection += @'
}
```

'@

# Rebuild settings file
if ($apiConfigsStart -ge 0 -and $apiConfigsEnd -ge 0) {
    # Replace existing API configs section
    $beforeApiConfigs = $lines[0..($apiConfigsStart - 1)] -join "`n"
    $afterApiConfigs = $lines[($apiConfigsEnd + 1)..$lines.Count] -join "`n"
    $newSettings = $beforeApiConfigs + $newApiConfigsSection + $afterApiConfigs
} else {
    # Append to existing settings or create new file
    if ($lines.Count -gt 0) {
        $beforeApiConfigs = $lines -join "`n"
        $newSettings = $beforeApiConfigs + $newApiConfigsSection
    } else {
        $newSettings = $newApiConfigsSection
    }
}

# Write updated settings
[System.IO.File]::WriteAllText($rooSettingsFile, $newSettings, $utf8NoBom)

Write-Host "`nSYNCED SUCCESSFULLY" -ForegroundColor Green
Write-Host "  Updated: $rooSettingsFile" -ForegroundColor Green
Write-Host "  API configs: $configCount" -ForegroundColor Green

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Reload VS Code (Ctrl+Shift+P > Reload Window)" -ForegroundColor White
Write-Host "  2. Open Roo settings to verify API configs appear" -ForegroundColor White

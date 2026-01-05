# Claude Code Initialization Script
# This script initializes machine-specific configuration files from templates
# Run this script after cloning the repository or when setting up a new machine

param(
    [string]$WorkspaceRoot = $PWD.Path,
    [switch]$Global,           # Install MCPs globally (to ~/.claude.json)
    [switch]$ProjectOnly,      # Only install to project .mcp.json (default if neither specified)
    [switch]$SkipProject,      # Skip project-level .mcp.json (use with -Global)
    [string[]]$McpServers      # Specific MCP servers to install globally (default: all)
)

$ErrorActionPreference = "Stop"

Write-Host "=== Claude Code Initialization ===" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceRoot"
Write-Host ""

# Normalize path (use forward slashes for consistency)
$WorkspaceRootNormalized = $WorkspaceRoot -replace '\\', '/'

# User home directory
$UserHome = $env:USERPROFILE
if (-not $UserHome) { $UserHome = $env:HOME }
$UserHomeNormalized = $UserHome -replace '\\', '/'

# Global Claude config file
$GlobalClaudeConfig = Join-Path $UserHome ".claude.json"

# Function to create file from template
function Initialize-FromTemplate {
    param(
        [string]$TemplatePath,
        [string]$OutputPath,
        [string]$Placeholder = "{{WORKSPACE_ROOT}}"
    )

    if (Test-Path $OutputPath) {
        Write-Host "  [SKIP] $OutputPath already exists" -ForegroundColor Yellow
        return $false
    }

    if (-not (Test-Path $TemplatePath)) {
        Write-Host "  [ERROR] Template not found: $TemplatePath" -ForegroundColor Red
        return $false
    }

    $content = Get-Content $TemplatePath -Raw
    $content = $content -replace [regex]::Escape($Placeholder), $WorkspaceRootNormalized
    Set-Content -Path $OutputPath -Value $content -NoNewline

    Write-Host "  [OK] Created $OutputPath" -ForegroundColor Green
    return $true
}

# Function to merge MCP servers into global config
function Install-McpServersGlobally {
    param(
        [string]$TemplatePath,
        [string[]]$ServerNames
    )

    if (-not (Test-Path $TemplatePath)) {
        Write-Host "  [ERROR] Template not found: $TemplatePath" -ForegroundColor Red
        return $false
    }

    # Read template and replace placeholder
    $templateContent = Get-Content $TemplatePath -Raw
    $templateContent = $templateContent -replace [regex]::Escape("{{WORKSPACE_ROOT}}"), $WorkspaceRootNormalized
    $templateConfig = $templateContent | ConvertFrom-Json

    # Read or create global config
    $globalConfig = @{}
    if (Test-Path $GlobalClaudeConfig) {
        try {
            $existingContent = Get-Content $GlobalClaudeConfig -Raw
            if ($existingContent.Trim()) {
                $globalConfig = $existingContent | ConvertFrom-Json -AsHashtable
            }
        } catch {
            Write-Host "  [WARN] Could not parse existing $GlobalClaudeConfig, will merge carefully" -ForegroundColor Yellow
            $globalConfig = @{}
        }
    }

    # Ensure mcpServers exists
    if (-not $globalConfig.ContainsKey("mcpServers")) {
        $globalConfig["mcpServers"] = @{}
    }

    # Get servers from template
    $templateServers = @{}
    if ($templateConfig.mcpServers) {
        $templateConfig.mcpServers.PSObject.Properties | ForEach-Object {
            $templateServers[$_.Name] = $_.Value
        }
    }

    # Filter servers if specific ones requested
    if ($ServerNames -and $ServerNames.Count -gt 0) {
        $filteredServers = @{}
        foreach ($name in $ServerNames) {
            if ($templateServers.ContainsKey($name)) {
                $filteredServers[$name] = $templateServers[$name]
            } else {
                Write-Host "  [WARN] Server '$name' not found in template" -ForegroundColor Yellow
            }
        }
        $templateServers = $filteredServers
    }

    # Merge servers
    $addedCount = 0
    $updatedCount = 0
    foreach ($serverName in $templateServers.Keys) {
        $serverConfig = $templateServers[$serverName]

        if ($globalConfig["mcpServers"].ContainsKey($serverName)) {
            # Check if config is different
            $existingJson = $globalConfig["mcpServers"][$serverName] | ConvertTo-Json -Compress
            $newJson = $serverConfig | ConvertTo-Json -Compress
            if ($existingJson -ne $newJson) {
                $globalConfig["mcpServers"][$serverName] = $serverConfig
                Write-Host "  [UPDATE] $serverName" -ForegroundColor Cyan
                $updatedCount++
            } else {
                Write-Host "  [SKIP] $serverName (already configured)" -ForegroundColor Yellow
            }
        } else {
            $globalConfig["mcpServers"][$serverName] = $serverConfig
            Write-Host "  [ADD] $serverName" -ForegroundColor Green
            $addedCount++
        }
    }

    # Write global config
    $globalConfigJson = $globalConfig | ConvertTo-Json -Depth 10
    Set-Content -Path $GlobalClaudeConfig -Value $globalConfigJson -Encoding UTF8

    Write-Host "  [OK] Global config updated: $addedCount added, $updatedCount updated" -ForegroundColor Green
    return $true
}

# Determine installation mode
$installProject = -not $SkipProject
$installGlobal = $Global

if (-not $Global -and -not $ProjectOnly -and -not $SkipProject) {
    # Default: project only
    $installProject = $true
    $installGlobal = $false
}

# 1. Initialize .mcp.json from template (project-level)
if ($installProject) {
    Write-Host "1. Project MCP Configuration (.mcp.json)" -ForegroundColor White
    $mcpTemplate = Join-Path $WorkspaceRoot ".mcp.json.template"
    $mcpOutput = Join-Path $WorkspaceRoot ".mcp.json"
    Initialize-FromTemplate -TemplatePath $mcpTemplate -OutputPath $mcpOutput
} else {
    Write-Host "1. Project MCP Configuration (.mcp.json)" -ForegroundColor White
    Write-Host "  [SKIP] -SkipProject specified" -ForegroundColor Yellow
}

# 2. Install MCPs globally if requested
if ($installGlobal) {
    Write-Host ""
    Write-Host "2. Global MCP Configuration (~/.claude.json)" -ForegroundColor White
    $mcpTemplate = Join-Path $WorkspaceRoot ".mcp.json.template"
    Install-McpServersGlobally -TemplatePath $mcpTemplate -ServerNames $McpServers
} else {
    Write-Host ""
    Write-Host "2. Global MCP Configuration (~/.claude.json)" -ForegroundColor White
    Write-Host "  [SKIP] Use -Global to install MCPs globally" -ForegroundColor Gray
}

# 3. Create local directory for INTERCOM
Write-Host ""
Write-Host "3. Local directory (.claude/local/)" -ForegroundColor White
$localDir = Join-Path $WorkspaceRoot ".claude/local"
if (-not (Test-Path $localDir)) {
    New-Item -ItemType Directory -Path $localDir -Force | Out-Null
    Write-Host "  [OK] Created $localDir" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] $localDir already exists" -ForegroundColor Yellow
}

# 4. Create INTERCOM file for this machine
Write-Host ""
Write-Host "4. INTERCOM file" -ForegroundColor White
$machineName = $env:COMPUTERNAME
$intercomFile = Join-Path $localDir "INTERCOM-$machineName.md"
if (-not (Test-Path $intercomFile)) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $intercomContent = @"
# INTERCOM - $machineName

**Machine:** $machineName
**Purpose:** Local Claude Code <-> Roo agent communication
**Created:** $(Get-Date -Format "yyyy-MM-dd")

---

## [$timestamp] system -> all [INFO]

INTERCOM initialized on $machineName.
Workspace: $WorkspaceRootNormalized

---
"@
    Set-Content -Path $intercomFile -Value $intercomContent
    Write-Host "  [OK] Created $intercomFile" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] $intercomFile already exists" -ForegroundColor Yellow
}

# 5. Verify MCP server is built
Write-Host ""
Write-Host "5. MCP Server Build Status" -ForegroundColor White
$mcpDistPath = Join-Path $WorkspaceRoot "mcps/internal/servers/github-projects-mcp/dist/index.js"
if (Test-Path $mcpDistPath) {
    Write-Host "  [OK] github-projects-mcp is built" -ForegroundColor Green
} else {
    Write-Host "  [WARN] github-projects-mcp needs to be built" -ForegroundColor Yellow
    Write-Host "         Run: cd mcps/internal/servers/github-projects-mcp && npm install && npm run build" -ForegroundColor Yellow
}

# 6. Verify .env file exists for MCP
Write-Host ""
Write-Host "6. MCP Environment File" -ForegroundColor White
$envPath = Join-Path $WorkspaceRoot "mcps/internal/servers/github-projects-mcp/.env"
if (Test-Path $envPath) {
    Write-Host "  [OK] .env file exists" -ForegroundColor Green
} else {
    Write-Host "  [WARN] .env file missing for github-projects-mcp" -ForegroundColor Yellow
    Write-Host "         Copy from .env.example and configure GITHUB_ACCOUNTS_JSON" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Initialization Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor White
Write-Host "  .\init-claude-code.ps1                    # Project-level only (default)" -ForegroundColor Gray
Write-Host "  .\init-claude-code.ps1 -Global            # Project + Global installation" -ForegroundColor Gray
Write-Host "  .\init-claude-code.ps1 -Global -SkipProject  # Global only" -ForegroundColor Gray
Write-Host "  .\init-claude-code.ps1 -Global -McpServers github-projects-mcp  # Specific MCPs" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Restart Claude Code to load MCP configuration"
Write-Host "  2. Test MCP with: 'List the available GitHub projects'"
Write-Host "  3. Create bootstrap issue: [CLAUDE-$machineName] Bootstrap Complete"
Write-Host ""

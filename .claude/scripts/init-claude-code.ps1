# Claude Code Initialization Script
# This script initializes machine-specific configuration files from templates
# Run this script after cloning the repository or when setting up a new machine

param(
    [string]$WorkspaceRoot = $PWD.Path,
    [switch]$Global,           # Install MCPs globally (to ~/.claude.json) - DEFAULT behavior
    [switch]$Project,          # Also install to project .mcp.json (use with -Global)
    [switch]$ProjectOnly,      # Only install to project .mcp.json, skip global
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

# Function to load .env file and return as hashtable
function Get-EnvVariables {
    param(
        [string]$EnvPath
    )

    $envVars = @{}

    if (-not (Test-Path $EnvPath)) {
        Write-Host "  [WARN] .env file not found: $EnvPath" -ForegroundColor Yellow
        return $envVars
    }

    Write-Host "  [INFO] Loading .env from: $EnvPath" -ForegroundColor Cyan

    # Read .env file and parse KEY=VALUE pairs
    Get-Content $EnvPath | ForEach-Object {
        # Skip comments and empty lines
        if ($_ -match '^\s*#' -or $_ -match '^\s*$') {
            return
        }

        # Match KEY=VALUE pattern (ignore export if present)
        if ($_ -match '^(?:export\s+)?([^=]+)=(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Remove quotes if present
            if ($value -match '^["''](.+)["'']$') {
                $value = $matches[1]
            }

            $envVars[$key] = $value
        }
    }

    Write-Host "  [OK] Loaded $($envVars.Count) environment variables" -ForegroundColor Green
    return $envVars
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

    # Load .env file for roo-state-manager
    $envVars = @{}
    if ($templateServers.ContainsKey("roo-state-manager")) {
        $envPath = Join-Path $WorkspaceRoot "mcps/internal/servers/roo-state-manager/.env"
        $envVars = Get-EnvVariables -EnvPath $envPath
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
                # Add/update environment variables for roo-state-manager
                if ($serverName -eq "roo-state-manager" -and $envVars.Count -gt 0) {
                    # Build env hashtable
                    $envHash = @{}
                    if ($serverConfig.PSObject.Properties.Name.Contains('env')) {
                        $serverConfig.env.PSObject.Properties | ForEach-Object {
                            $envHash[$_.Name] = $_.Value
                        }
                    }
                    # Merge environment variables
                    foreach ($var in $envVars.Keys) {
                        $envHash[$var] = $envVars[$var]
                    }
                    # Replace env with hashtable
                    if ($serverConfig.PSObject.Properties.Name.Contains('env')) {
                        $serverConfig.PSObject.Properties.Remove('env')
                    }
                    $serverConfig | Add-Member -NotePropertyName 'env' -NotePropertyValue $envHash -Force
                    Write-Host "    [ENV] Injected $($envVars.Count) environment variables" -ForegroundColor Cyan
                }
                $globalConfig["mcpServers"][$serverName] = $serverConfig
                Write-Host "  [UPDATE] $serverName" -ForegroundColor Cyan
                $updatedCount++
            } else {
                Write-Host "  [SKIP] $serverName (already configured)" -ForegroundColor Yellow
            }
        } else {
            # Add environment variables for roo-state-manager
            if ($serverName -eq "roo-state-manager" -and $envVars.Count -gt 0) {
                # Build env hashtable
                $envHash = @{}
                if ($serverConfig.PSObject.Properties.Name.Contains('env')) {
                    $serverConfig.env.PSObject.Properties | ForEach-Object {
                        $envHash[$_.Name] = $_.Value
                    }
                }
                # Merge environment variables
                foreach ($var in $envVars.Keys) {
                    $envHash[$var] = $envVars[$var]
                }
                # Replace env with hashtable
                if ($serverConfig.PSObject.Properties.Name.Contains('env')) {
                    $serverConfig.PSObject.Properties.Remove('env')
                }
                $serverConfig | Add-Member -NotePropertyName 'env' -NotePropertyValue $envHash -Force
                Write-Host "    [ENV] Injected $($envVars.Count) environment variables" -ForegroundColor Cyan
            }
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
# Default: Global only (MCPs available everywhere)
# -Project: Also install to project .mcp.json
# -ProjectOnly: Only project, no global

if ($ProjectOnly) {
    $installProject = $true
    $installGlobal = $false
} else {
    # Default or -Global: install globally
    $installGlobal = $true
    $installProject = $Project  # Only if -Project specified
}

# 1. Initialize .mcp.json from template (project-level)
if ($installProject) {
    Write-Host "1. Project MCP Configuration (.mcp.json)" -ForegroundColor White
    $mcpTemplate = Join-Path $WorkspaceRoot ".mcp.json.template"
    $mcpOutput = Join-Path $WorkspaceRoot ".mcp.json"
    Initialize-FromTemplate -TemplatePath $mcpTemplate -OutputPath $mcpOutput
} else {
    Write-Host "1. Project MCP Configuration (.mcp.json)" -ForegroundColor White
    Write-Host "  [SKIP] Use -Project to also install locally" -ForegroundColor Gray
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
    Write-Host "  [SKIP] -ProjectOnly specified" -ForegroundColor Yellow
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
Write-Host "  .\init-claude-code.ps1                    # Global only (default, recommended)" -ForegroundColor Gray
Write-Host "  .\init-claude-code.ps1 -Project           # Global + Project" -ForegroundColor Gray
Write-Host "  .\init-claude-code.ps1 -ProjectOnly       # Project only (no global)" -ForegroundColor Gray
Write-Host "  .\init-claude-code.ps1 -McpServers github-projects-mcp  # Specific MCPs only" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Restart Claude Code to load MCP configuration"
Write-Host "  2. Test MCP with: 'List the available GitHub projects'"
Write-Host "  3. Create bootstrap issue: [CLAUDE-$machineName] Bootstrap Complete"
Write-Host ""

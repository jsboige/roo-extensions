# Claude Code Initialization Script
# This script initializes machine-specific configuration files from templates
# Run this script after cloning the repository or when setting up a new machine

param(
    [string]$WorkspaceRoot = $PWD.Path
)

$ErrorActionPreference = "Stop"

Write-Host "=== Claude Code Initialization ===" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceRoot"
Write-Host ""

# Normalize path (use forward slashes for consistency)
$WorkspaceRootNormalized = $WorkspaceRoot -replace '\\', '/'

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

# 1. Initialize .mcp.json from template
Write-Host "1. MCP Configuration (.mcp.json)" -ForegroundColor White
$mcpTemplate = Join-Path $WorkspaceRoot ".mcp.json.template"
$mcpOutput = Join-Path $WorkspaceRoot ".mcp.json"
Initialize-FromTemplate -TemplatePath $mcpTemplate -OutputPath $mcpOutput

# 2. Create local directory for INTERCOM
Write-Host ""
Write-Host "2. Local directory (.claude/local/)" -ForegroundColor White
$localDir = Join-Path $WorkspaceRoot ".claude/local"
if (-not (Test-Path $localDir)) {
    New-Item -ItemType Directory -Path $localDir -Force | Out-Null
    Write-Host "  [OK] Created $localDir" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] $localDir already exists" -ForegroundColor Yellow
}

# 3. Create INTERCOM file for this machine
Write-Host ""
Write-Host "3. INTERCOM file" -ForegroundColor White
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

# 4. Verify MCP server is built
Write-Host ""
Write-Host "4. MCP Server Build Status" -ForegroundColor White
$mcpDistPath = Join-Path $WorkspaceRoot "mcps/internal/servers/github-projects-mcp/dist/index.js"
if (Test-Path $mcpDistPath) {
    Write-Host "  [OK] github-projects-mcp is built" -ForegroundColor Green
} else {
    Write-Host "  [WARN] github-projects-mcp needs to be built" -ForegroundColor Yellow
    Write-Host "         Run: cd mcps/internal/servers/github-projects-mcp && npm install && npm run build" -ForegroundColor Yellow
}

# 5. Verify .env file exists for MCP
Write-Host ""
Write-Host "5. MCP Environment File" -ForegroundColor White
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
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Restart Claude Code to load MCP configuration"
Write-Host "  2. Test MCP with: 'List the available GitHub projects'"
Write-Host "  3. Create bootstrap issue: [CLAUDE-$machineName] Bootstrap Complete"
Write-Host ""

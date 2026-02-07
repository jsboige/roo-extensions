<#
.SYNOPSIS
    Genere automatiquement le CLAUDE.md specifique a cette machine.

.DESCRIPTION
    Detecte les capacites de la machine et genere un CLAUDE.md adapte :
    - Inventaire hardware (CPU, RAM, GPU)
    - MCPs disponibles
    - Role dans l'architecture (coordinateur vs executant)
    - Taches assignees (depuis GitHub si disponible)

.PARAMETER OutputPath
    Chemin de sortie (defaut: .claude/machines/HOSTNAME/CLAUDE.md)

.PARAMETER DryRun
    Afficher sans ecrire

.EXAMPLE
    .\generate-machine-claude-md.ps1
    .\generate-machine-claude-md.ps1 -DryRun
#>

param(
    [string]$OutputPath = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Pas dans un depot Git."
    exit 1
}

$machineName = ($env:COMPUTERNAME).ToLower()

Write-Host "=== Machine CLAUDE.md Generator ===" -ForegroundColor Cyan
Write-Host "Machine: $machineName"
Write-Host ""

# 1. Detecter hardware
Write-Host "[1/5] Detection hardware..." -ForegroundColor Yellow

$cpuName = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$hasGPU = $false
$gpuName = "None"

try {
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA|AMD|Intel.*Arc' } | Select-Object -First 1
    if ($gpu) {
        $hasGPU = $true
        $gpuName = $gpu.Name
    }
} catch {}

Write-Host "  CPU: $cpuName"
Write-Host "  RAM: ${ramGB}GB"
Write-Host "  GPU: $gpuName"

# 2. Detecter role
Write-Host "[2/5] Detection role..." -ForegroundColor Yellow

$isCoordinator = ($machineName -eq "myia-ai-01")
$role = if ($isCoordinator) { "Coordinateur Principal" } else { "Agent Executant" }

Write-Host "  Role: $role"

# 3. Detecter MCPs
Write-Host "[3/5] Detection MCPs..." -ForegroundColor Yellow

$mcps = @()

# Check roo-state-manager
$claudeConfigPath = "$env:USERPROFILE/.claude.json"
if (Test-Path $claudeConfigPath) {
    $claudeConfig = Get-Content $claudeConfigPath -Raw | ConvertFrom-Json
    if ($claudeConfig.mcpServers) {
        $claudeConfig.mcpServers.PSObject.Properties | ForEach-Object {
            $mcps += $_.Name
        }
    }
}

# Check gh cli
$ghAvailable = $false
try {
    gh --version 2>$null | Out-Null
    $ghAvailable = $true
} catch {}

Write-Host "  MCPs: $($mcps -join ', ')"
Write-Host "  gh CLI: $ghAvailable"

# 4. Check Jupyter
Write-Host "[4/5] Detection Jupyter..." -ForegroundColor Yellow
$hasJupyter = $false
try {
    jupyter --version 2>$null | Out-Null
    $hasJupyter = $true
} catch {}
Write-Host "  Jupyter: $hasJupyter"

# 5. Generer le CLAUDE.md
Write-Host "[5/5] Generation CLAUDE.md..." -ForegroundColor Yellow

if (-not $OutputPath) {
    $OutputPath = "$RepoRoot/.claude/machines/$machineName/CLAUDE.md"
}

$agentType = if ($isCoordinator) {
    "coordinateur : ``roosync-hub``, ``dispatch-manager``, ``task-planner``"
} else {
    "executant : ``roosync-reporter``, ``task-worker``"
}

$skillsList = if ($isCoordinator) {
    "``sync-tour``, ``coordinate``"
} else {
    "``sync-tour``, ``executor``"
}

$commandsList = if ($isCoordinator) {
    "``/coordinate``, ``/sync-tour``"
} else {
    "``/executor``, ``/sync-tour``"
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

$content = @"
# CLAUDE.md - $machineName

> Auto-genere le $timestamp par generate-machine-claude-md.ps1

## Role

**$role** du systeme RooSync multi-agent.

## Capacites Hardware

| Ressource | Valeur |
|-----------|--------|
| OS | Windows |
| CPU | $cpuName |
| RAM | ${ramGB}GB |
| GPU | $gpuName |
| Jupyter | $(if ($hasJupyter) { "Oui" } else { "Non" }) |
| Claude Code | Opus 4.6 |

## MCPs Disponibles

$(foreach ($mcp in $mcps) { "- $mcp`n" })$(if ($ghAvailable) { "- GitHub CLI (``gh``)`n" })

## Outils Specifiques

- Agents $agentType
- Skills : $skillsList
- Commandes : $commandsList

## Responsabilites

$(if ($isCoordinator) {
@"
- Coordination des 5 machines via RooSync
- Assignation et suivi des taches (GitHub Project #67)
- Review et merge des PRs
- Maintenance documentation globale
- Decisions architecturales
"@
} else {
@"
- Execution des taches assignees par le coordinateur
- Implementation de features et bug fixes
- Validation locale (build + tests)
- Rapport au coordinateur via RooSync
"@
})
"@

if ($DryRun) {
    Write-Host ""
    Write-Host "=== DRY RUN - Contenu genere ===" -ForegroundColor Yellow
    Write-Host $content
} else {
    $dir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -Path $OutputPath -Value $content -Encoding UTF8
    Write-Host "  Ecrit: $OutputPath"
}

Write-Host ""
Write-Host "=== Generation terminee ===" -ForegroundColor Green

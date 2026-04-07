<#
.SYNOPSIS
    Controlled rollout helper for Copilot-Dispatcher (V3 checklist).

.DESCRIPTION
    Runs a gate-by-gate rollout sequence for one machine:
    - GitHub identity check
    - MCP bootstrap/config validation
    - Dispatcher install/refresh
    - Immediate run + result verification
    - Evidence report generation

    This script is intentionally machine-local. Execute it on each machine
    during the controlled rollout.
#>

[CmdletBinding()]
param(
    [string]$ExpectedGitHubLogin = 'jsboige',
    [ValidateSet('low','balanced','throughput')]
    [string]$BudgetProfile = 'balanced',
    [int]$IssueNumber = 622,
    [double]$PremiumUsagePercent = -1,
    [double]$SoftUsageCapPercent = 70,
    [double]$HardUsageCapPercent = 90,
    [int]$MaxConsecutiveBlocked = 2,
    [int]$MaxConsecutiveIdle = 4,
    [int]$MinEscalationIntervalMinutes = 180,
    [int]$MaxEscalationsPerDay = 3,
    [switch]$SkipBootstrap,
    [switch]$ValidateOnly,
    [switch]$PostIssueComment,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$setupScript = Join-Path $scriptDir 'setup-copilot-dispatcher.ps1'
$bootstrapScript = Join-Path $repoRoot 'scripts\copilot\configure-copilot-mcp.ps1'
$taskName = 'Copilot-Dispatcher'
$mcpConfigPath = Join-Path $env:APPDATA 'Code\User\mcp.json'
$dispatcherLogDir = if (-not [string]::IsNullOrWhiteSpace($env:COPILOT_DISPATCHER_LOG_DIR)) {
    $env:COPILOT_DISPATCHER_LOG_DIR
} else {
    Join-Path $repoRoot 'outputs\scheduling\logs'
}
$reportDir = if (-not [string]::IsNullOrWhiteSpace($env:COPILOT_ROLLOUT_REPORT_DIR)) {
    $env:COPILOT_ROLLOUT_REPORT_DIR
} else {
    Join-Path $repoRoot 'outputs\scheduling\reports'
}
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }

$report = [ordered]@{
    machine = $env:COMPUTERNAME.ToLower()
    timestamp = (Get-Date).ToString('o')
    expectedGitHubLogin = $ExpectedGitHubLogin
    githubLogin = ''
    githubIdentityOk = $false
    bootstrapApplied = $false
    mcpConfigPath = $mcpConfigPath
    mcpConfigExists = $false
    rooStateManagerConfigured = $false
    dispatcherInstalled = $false
    dispatcherReady = $false
    lastTaskResult = -1
    foundMcpConfigInLog = $false
    latestLogFile = ''
    status = 'blocked'
    notes = @()
}

function Add-Note {
    param([string]$Message)
    $report.notes += $Message
    Write-Host "[INFO] $Message"
}

function Add-Blocker {
    param([string]$Message)
    $report.notes += "BLOCKER: $Message"
    Write-Host "[BLOCKER] $Message" -ForegroundColor Yellow
}

function Get-GitHubLogin {
    try {
        $login = (& gh api user --jq .login 2>$null)
        if ($LASTEXITCODE -ne 0) { return '' }
        return [string]$login
    } catch {
        return ''
    }
}

function Test-RooStateManagerConfigured {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return $false }

    try {
        $raw = Get-Content -Path $Path -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return $false }

        # Support both known schemas:
        # 1) { "servers": { "roo-state-manager": { ... } } }
        # 2) { "mcpServers": { "roo-state-manager": { ... } } }
        $json = $raw | ConvertFrom-Json -AsHashtable
        if ($json.ContainsKey('servers') -and $json.servers -is [hashtable] -and $json.servers.ContainsKey('roo-state-manager')) {
            return $true
        }
        if ($json.ContainsKey('mcpServers') -and $json.mcpServers -is [hashtable] -and $json.mcpServers.ContainsKey('roo-state-manager')) {
            return $true
        }
    } catch {
        # Fallback to plain text check to stay resilient to schema drifts.
        try {
            $raw = Get-Content -Path $Path -Raw
            if ($raw -match 'roo-state-manager') { return $true }
        } catch {
            return $false
        }
    }

    return $false
}

function Invoke-Setup {
    param([string[]]$Arguments)

    if ($DryRun) {
        Add-Note "DRY-RUN setup-copilot-dispatcher args: $($Arguments -join ' ')"
        return
    }

    & powershell -ExecutionPolicy Bypass -File $setupScript @Arguments
}

function Invoke-ScriptWithPreferredHost {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $hostExe = 'powershell'
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $hostExe = 'pwsh'
    }

    if ($DryRun) {
        Add-Note "DRY-RUN $hostExe -ExecutionPolicy Bypass -File $FilePath $($Arguments -join ' ')"
        return 0
    }

    $output = & $hostExe -ExecutionPolicy Bypass -File $FilePath @Arguments 2>&1
    if ($output) {
        foreach ($line in $output) {
            Write-Host $line
        }
    }

    return [int]$LASTEXITCODE
}

function Wait-TaskCompletion {
    param(
        [string]$TaskName,
        [int]$TimeoutSeconds = 90
    )

    if ($DryRun) { return }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
            if ($task.State -ne 'Running') { return }
        } catch {
            return
        }
        Start-Sleep -Seconds 2
    }
}

Add-Note "Starting controlled rollout check on $($report.machine)"

$report.githubLogin = Get-GitHubLogin
if ([string]::IsNullOrWhiteSpace($report.githubLogin)) {
    Add-Blocker 'Unable to resolve gh login (run gh auth status).'
} elseif ($report.githubLogin -ne $ExpectedGitHubLogin) {
    Add-Blocker "GitHub login mismatch: expected=$ExpectedGitHubLogin actual=$($report.githubLogin)"
} else {
    $report.githubIdentityOk = $true
    Add-Note "GitHub identity OK: $($report.githubLogin)"
}

if (-not $SkipBootstrap) {
    if (-not (Test-Path $bootstrapScript)) {
        Add-Blocker "Bootstrap script missing: $bootstrapScript"
    } else {
        if ($DryRun) {
            Add-Note 'DRY-RUN bootstrap skipped execution.'
        } else {
            try {
                $bootstrapExit = Invoke-ScriptWithPreferredHost -FilePath $bootstrapScript
                if ($bootstrapExit -eq 0) {
                    $report.bootstrapApplied = $true
                    Add-Note 'MCP bootstrap executed.'
                } else {
                    Add-Blocker "Bootstrap returned non-zero exit code: $bootstrapExit"
                }
            } catch {
                Add-Blocker "Bootstrap failed: $($_.Exception.Message)"
            }
        }
    }
} else {
    Add-Note 'SkipBootstrap enabled.'
}

$report.mcpConfigExists = Test-Path $mcpConfigPath
if (-not $report.mcpConfigExists) {
    Add-Blocker "MCP config missing: $mcpConfigPath"
} else {
    $report.rooStateManagerConfigured = Test-RooStateManagerConfigured -Path $mcpConfigPath
    if ($report.rooStateManagerConfigured) {
        Add-Note 'roo-state-manager found in MCP config.'
    } else {
        Add-Blocker 'roo-state-manager not found in MCP config.'
    }
}

$installArgs = @(
    '-Action','install',
    '-BudgetProfile',$BudgetProfile,
    '-IssueNumber',$IssueNumber,
    '-PremiumUsagePercent',$PremiumUsagePercent,
    '-SoftUsageCapPercent',$SoftUsageCapPercent,
    '-HardUsageCapPercent',$HardUsageCapPercent,
    '-MaxConsecutiveBlocked',$MaxConsecutiveBlocked,
    '-MaxConsecutiveIdle',$MaxConsecutiveIdle,
    '-MinEscalationIntervalMinutes',$MinEscalationIntervalMinutes,
    '-MaxEscalationsPerDay',$MaxEscalationsPerDay
)

if (-not $ValidateOnly) {
    try {
        Invoke-Setup -Arguments $installArgs
        $report.dispatcherInstalled = $true
        Add-Note 'Copilot-Dispatcher install/refresh completed.'
    } catch {
        Add-Blocker "Dispatcher install failed: $($_.Exception.Message)"
    }
} else {
    Add-Note 'ValidateOnly enabled: install skipped.'
}

if (-not $DryRun -and -not $ValidateOnly) {
    try {
        Start-ScheduledTask -TaskName $taskName
        Add-Note 'Immediate scheduled task run triggered.'
        Wait-TaskCompletion -TaskName $taskName -TimeoutSeconds 90
    } catch {
        Add-Blocker "Unable to start scheduled task: $($_.Exception.Message)"
    }
}

try {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
    $report.dispatcherReady = ($task.State -eq 'Ready')
    $report.lastTaskResult = [int]$taskInfo.LastTaskResult
    if ($report.dispatcherReady) {
        Add-Note 'Scheduled task state is Ready.'
    } else {
        Add-Blocker "Scheduled task state is $($task.State) (expected Ready)."
    }
    if ($report.lastTaskResult -eq 0) {
        Add-Note 'LastTaskResult is 0.'
    } else {
        Add-Blocker "LastTaskResult is $($report.lastTaskResult) (expected 0)."
    }
} catch {
    Add-Blocker "Unable to read scheduled task info: $($_.Exception.Message)"
}

try {
    $latestLog = Get-ChildItem -Path $dispatcherLogDir -Filter 'copilot-dispatcher-*.log' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latestLog) {
        $report.latestLogFile = $latestLog.FullName
        $tail = Get-Content -Path $latestLog.FullName -Tail 80 -ErrorAction SilentlyContinue
        if (($tail -join "`n") -match 'Found Copilot MCP config') {
            $report.foundMcpConfigInLog = $true
            Add-Note 'Log evidence found: Found Copilot MCP config.'
        } else {
            Add-Blocker 'Log evidence missing: Found Copilot MCP config.'
        }
    } else {
        Add-Blocker 'No copilot-dispatcher log file found.'
    }
} catch {
    Add-Blocker "Unable to inspect logs: $($_.Exception.Message)"
}

$allGreen = (
    $report.githubIdentityOk -and
    $report.mcpConfigExists -and
    $report.rooStateManagerConfigured -and
    $report.dispatcherReady -and
    ($report.lastTaskResult -eq 0) -and
    $report.foundMcpConfigInLog
)

if ($allGreen) {
    $report.status = 'done'
    Add-Note 'Rollout gate passed for this machine.'
} else {
    $report.status = 'blocked'
    Add-Blocker 'Rollout gate failed for this machine.'
}

$reportFile = Join-Path $reportDir ("copilot-rollout-check-" + $report.machine + "-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.md')
$lines = @(
    '# Copilot V3 Rollout Check',
    '',
    "- machine: $($report.machine)",
    "- timestamp: $($report.timestamp)",
    "- status: $($report.status)",
    "- github login: $($report.githubLogin)",
    "- mcp config: $($report.mcpConfigPath)",
    "- dispatcher ready: $($report.dispatcherReady)",
    "- last task result: $($report.lastTaskResult)",
    "- log evidence found: $($report.foundMcpConfigInLog)",
    '',
    '## Notes',
    ''
)

foreach ($note in $report.notes) {
    $lines += "- $note"
}

[System.IO.File]::WriteAllText($reportFile, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
Write-Host "[INFO] Report written: $reportFile"

if ($PostIssueComment -and $IssueNumber -gt 0 -and -not $DryRun) {
    try {
        $body = @(
            "STATUS: $($report.status)",
            'agent: copilot-rollout-check',
            "machine: $($report.machine)",
            "github_login: $($report.githubLogin)",
            "dispatcher_ready: $($report.dispatcherReady)",
            "last_task_result: $($report.lastTaskResult)",
            "log_evidence_found: $($report.foundMcpConfigInLog)",
            "report_file: $reportFile"
        ) -join "`n"
        & gh issue comment $IssueNumber --repo jsboige/roo-extensions --body $body | Out-Null
        Add-Note "Issue #$IssueNumber updated."
    } catch {
        Add-Blocker "Unable to post issue comment: $($_.Exception.Message)"
    }
}

if ($report.status -eq 'done') {
    exit 0
}

exit 2
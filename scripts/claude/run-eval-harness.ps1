# Run SDDD Eval Harness (#2609 V1 cadence)
# FAMILY: eval — cadence wrapper for tests/eval-harness (roo-state-manager).
# Runs `npm run eval:harness` in the MAIN checkout submodule (real Qdrant/PG via .env),
# parses per-scenario verdicts deterministically, and posts the verdict summary to the
# workspace dashboard via a headless `claude -p` (model haiku, MCP roosync_dashboard).
#
# Never builds (vitest only reads src/ — the live-marker memory rule bans `npm run build`
# in the main checkout, not tests). The storm guard is handled INSIDE the harness: it emits
# INCONCLUSIVE verdicts (no spurious FAILs), and this wrapper reports them as INCONCLUSIVE —
# a storm-guarded scenario is green in vitest, so counting it as a pass would publish a run
# that measured nothing as a success (measured 2026-10-08, see eval-harness-verdicts.ps1).
#
# Scheduled by install-eval-harness-scheduled-task.ps1 (Roo-Eval-Harness-2609, daily).
# Issue: #2609 (Epic V1 — "eval-harness cadencé, verdict dashboard")
# Author: Claude Code (myia-ai-01)

param(
    # Main checkout root. Defaults to the repo containing this script. The schtask
    # always invokes the copy in the main checkout (node_modules + .env live there).
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$SkipDashboardPost,
    [switch]$WhatIf,
    [int]$VitestTimeoutSec = 420
)

$ErrorActionPreference = 'Stop'

# Storm-guard-aware verdict classification (pure functions, unit-tested). See its header
# for why a storm-guarded scenario must never be counted as a pass.
. "$PSScriptRoot\eval-harness-verdicts.ps1"

# Scenario map: eval test file -> @{ label; tool } where tool names the `[<tool>] verdict=`
# log line whose latency/first-failing-check is appended as dashboard detail (empty = none).
$scenarioMap = [ordered]@{
    'roosync-search.eval.test.ts'         = @{ label = 'golden roosync_search (evergreen)'; tool = 'roosync_search' }
    'codebase-search.eval.test.ts'        = @{ label = 'golden codebase_search (evergreen)'; tool = 'codebase_search' }
    'conversation-browser.eval.test.ts'   = @{ label = 'golden conversation_browser list';   tool = 'conversation_browser' }
    'q4-cross-conversation.eval.test.ts'  = @{ label = 'q4 cross-conversation synthesis';    tool = '' }
    'v2-block-granularity.eval.test.ts'   = @{ label = 'q3 source blocks (V2)';              tool = '' }
    'v3-passage-quality.eval.test.ts'     = @{ label = 'q2 decision passage (V3)';           tool = 'roosync_search' }
    'v4-essential-drilldown.eval.test.ts' = @{ label = 'q1 essential drill-down (V4)';       tool = 'conversation_browser view #2609-V4' }
}

function Write-Info { param($msg) Write-Host "[INFO] $msg" }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }

# Kill the whole process tree: Process.Kill() on PS 5.1 only kills the direct child
# (npm.cmd -> cmd.exe), leaving node/vitest or claude's MCP children orphaned.
function Stop-ProcessTree { param($proc) try { & taskkill.exe /T /F /PID $proc.Id 2>&1 | Out-Null } catch { try { $proc.Kill() } catch { } } }

$lockDir = Join-Path $env:TEMP 'eval-harness-2609'
if (-not (Test-Path $lockDir)) { New-Item -ItemType Directory -Path $lockDir -Force | Out-Null }

# ---- 1. Guards ----
# The schtask runs with -WindowStyle Hidden: console output is lost, so guard exits are
# also appended to guard.log (otherwise a missing precondition fails silently every day).
$pkgDir = Join-Path $RepoRoot 'mcps\internal\servers\roo-state-manager'
foreach ($rel in @("$pkgDir\.env", "$pkgDir\node_modules\.bin\vitest.cmd", "$pkgDir\vitest.config.eval-harness.ts")) {
    if (-not (Test-Path $rel)) {
        Write-Host "[ERROR] Missing precondition: $rel"
        Write-Host "        Point -RepoRoot at the MAIN checkout (worktrees lack .env/node_modules)."
        Add-Content -Path (Join-Path $lockDir 'guard.log') -Encoding UTF8 -Value "$(Get-Date -Format o) exit 2 — missing precondition: $rel"
        exit 2
    }
}

# Re-entry lock: a fresh lock (< 30 min) means another run is in flight — skip silently.
$lockFile = Join-Path $lockDir 'run.lock'
if (Test-Path $lockFile) {
    $ageMin = ((Get-Date) - (Get-Item $lockFile).LastWriteTime).TotalMinutes
    if ($ageMin -lt 30) { Write-Info "Lock fresh ($([int]$ageMin) min) — another run in flight, skipping."; exit 0 }
}
"$PID $(Get-Date -Format o)" | Out-File -FilePath $lockFile -Encoding ascii

try {
    # ---- 2. Run the harness ----
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logFile = Join-Path $lockDir "run-$stamp.log"
    $outFile = Join-Path $lockDir "run-$stamp.stdout.log"
    $errFile = Join-Path $lockDir "run-$stamp.stderr.log"

    $vintage = (git -C $pkgDir log -1 --format=%h) 2>$null
    if (-not $vintage) { $vintage = 'unknown' }

    Write-Info "Repo: $RepoRoot (submod vintage $vintage)"
    Write-Info "Log : $logFile"
    if ($WhatIf) {
        Write-Info "[WHATIF] Would run: npm.cmd run eval:harness (cwd=$pkgDir, timeout=${VitestTimeoutSec}s)"
        Write-Info "[WHATIF] Would parse verdicts and post dashboard summary (unless -SkipDashboardPost)."
        exit 0
    }

    $started = Get-Date
    $proc = Start-Process -FilePath 'npm.cmd' -ArgumentList 'run','eval:harness' `
        -WorkingDirectory $pkgDir -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
        -PassThru -NoNewWindow
    $timedOut = -not $proc.WaitForExit($VitestTimeoutSec * 1000)
    if ($timedOut) {
        Stop-ProcessTree $proc
        Write-Warn "Vitest timed out after ${VitestTimeoutSec}s — recording partial output."
    }
    else {
        # Parameterless WaitForExit ensures handle finalization before reading output files.
        $proc.WaitForExit()
    }
    $durationSec = [int]((Get-Date) - $started).TotalSeconds

    # Merge stdout+stderr (vitest writes test results to stderr) into the kept log, ANSI-stripped.
    # -Encoding UTF8: node writes UTF-8; PS 5.1 would otherwise decode as cp1252 and the
    # '✓' match below would only work by matching mojibake against mojibake.
    $ansi = [string][char]27
    $lines = @()
    foreach ($f in @($errFile, $outFile)) {
        if (Test-Path $f) {
            $lines += (Get-Content $f -Encoding UTF8 -ErrorAction SilentlyContinue) |
                ForEach-Object { $_ -replace "$ansi\[[0-9;]*[A-Za-z]", '' }
        }
    }
    [System.IO.File]::WriteAllLines($logFile, [string[]]$lines, [System.Text.UTF8Encoding]::new($false))
    Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue

    # ---- 3. Parse ----
    # (a) Tool-level verdict lines: `[<tool>] [target=... ]verdict=X latency=Nms` + first [FAIL] check after each.
    $detailByTool = @{}
    $currentTool = $null
    foreach ($ln in $lines) {
        if ($ln -match '^\[([^\]]+)\]\s+(?:target=\S+ \(\d+ msgs\) )?verdict=(PASS|FAIL|INCONCLUSIVE) latency=(\d+)ms') {
            $currentTool = $Matches[1]
            $detailByTool[$currentTool] = @{ verdict = $Matches[2]; latency = $Matches[3]; detail = $null }
        }
        elseif ($null -ne $currentTool -and $detailByTool.ContainsKey($currentTool) -and
                $null -eq $detailByTool[$currentTool].detail -and $ln -match '^\s+\[FAIL\]\s+(.+)$') {
            $detailByTool[$currentTool].detail = $Matches[1]
        }
    }
    # (b) Per-scenario verdicts. The classification lives in the dot-sourced helper because
    # the vitest per-file marker alone is NOT authoritative: a storm-guarded test is green
    # (it asserts the guard is active, then returns), so a run that issued no query at all
    # would otherwise be summarised and exited as a pass.
    $classified = Get-EvalHarnessScenarioResults -LogLines $lines -ScenarioMap $scenarioMap
    $passCount = $classified.PassCount
    $failCount = $classified.FailCount
    $inconclusiveCount = $classified.InconclusiveCount
    $missingCount = $classified.MissingCount

    $scenarioLines = @()
    foreach ($s in $classified.Scenarios) {
        $extra = ''
        if ($s.Verdict -eq 'INCONCLUSIVE') {
            if ($s.Detail) { $extra = " — $($s.Detail)" }
        }
        elseif ($s.Tool -and $detailByTool.ContainsKey($s.Tool)) {
            $d = $detailByTool[$s.Tool]
            if ($s.Verdict -eq 'FAIL' -and $d.detail) { $extra = " — $($d.detail)" }
            elseif ($s.Verdict -eq 'PASS') { $extra = " ($($d.latency)ms)" }
        }
        $scenarioLines += "- $($s.Label): $($s.Verdict)${extra}"
    }

    $summary = "**[EVAL-HARNESS #2609] $stamp — $passCount PASS / $failCount FAIL / $inconclusiveCount INCONCLUSIVE / $missingCount MISSING** (${durationSec}s, submod $vintage, log ``$logFile``)"
    if ($passCount -eq 0 -and $inconclusiveCount -gt 0) {
        $summary += "`n> NO MEASUREMENT — every scenario was storm-guarded, no query reached the engines. This is NOT a pass."
    }
    $body = (@($summary) + $scenarioLines) -join "`n"

    Write-Info $summary
    $scenarioLines | ForEach-Object { Write-Host "  $_" }

    # Retention: keep the 7 most recent run logs.
    Get-ChildItem (Join-Path $lockDir 'run-*.log') -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip 7 |
        Remove-Item -Force -ErrorAction SilentlyContinue

    # ---- 4. Post to dashboard via headless claude (haiku) ----
    if (-not $SkipDashboardPost) {
        $claudeExe = $null
        $candidates = @(
            (Get-ChildItem -Path "$env:USERPROFILE\.vscode\extensions\anthropic.claude-code-*-win32-x64\resources\native-binary\claude.exe" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1),
            (Get-Command claude.cmd -ErrorAction SilentlyContinue | Select-Object -First 1)
        )
        foreach ($c in $candidates) {
            if ($c -and ($c.Path -or $c.Source -or $c.FullName)) {
                $claudeExe = if ($c.Path) { $c.Path } elseif ($c.Source) { $c.Source } else { $c.FullName }
                break
            }
        }
        if (-not $claudeExe) {
            Write-Warn "claude executable not found — dashboard post skipped."
            exit 3
        }
        $prompt = @"
You are a headless posting agent. Post EXACTLY ONE message to the RooSync workspace dashboard using the MCP tool roosync_dashboard with: action "append", type "workspace", tags ["INFO","eval-harness"], and the content below verbatim (between the markers). Do not read any file. Do not modify the content. If the append fails, retry once; if it still fails, print POST_FAILED.
---BEGIN CONTENT---
$body
---END CONTENT---
"@
        Write-Info 'Posting verdict via claude -p (haiku)...'
        # .NET Process pattern (same as spawn-claude.ps1): PS 5.1 Start-Process cannot
        # redirect stdin, and claude -p reads the prompt from stdin ('-' arg).
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $claudeExe
        $psi.Arguments = '-p - --dangerously-skip-permissions --model haiku'
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.WorkingDirectory = $RepoRoot
        $psi.EnvironmentVariables['MCP_TOOL_TIMEOUT'] = '900000'
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.StandardInput.Write($prompt)
        $p.StandardInput.Close()
        $stdoutTask = $p.StandardOutput.ReadToEndAsync()
        $stderrTask = $p.StandardError.ReadToEndAsync()
        $postOk = $p.WaitForExit(300000)
        if (-not $postOk) {
            Stop-ProcessTree $p
            Write-Warn 'Dashboard post timed out after 300s.'
            exit 4
        }
        $postOut = Join-Path $lockDir "post-$stamp.out"
        [System.IO.File]::WriteAllText($postOut, $stdoutTask.Result, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText("$postOut.err", $stderrTask.Result, [System.Text.UTF8Encoding]::new($false))
        $posted = $stdoutTask.Result
        if ($posted -match 'POST_FAILED') {
            Write-Warn "Dashboard post failed. Output kept: $postOut"
            exit 4
        }
        Write-Info 'Dashboard post done.'
    }
    # .cmd shim ExitCode is unreliable (reads null through Start-Process) — the classified
    # scenario verdicts are the authoritative signal for the wrapper's own exit. A run that
    # measured nothing (every scenario storm-guarded) is not a success.
    $runOk = Test-EvalHarnessRunSuccess -PassCount $passCount -FailCount $failCount -InconclusiveCount $inconclusiveCount -MissingCount $missingCount -TimedOut:$timedOut
    if ($runOk) { exit 0 } else { exit 1 }
}
finally {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}

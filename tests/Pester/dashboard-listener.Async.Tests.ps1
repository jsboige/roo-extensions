BeforeAll {
    $source = Join-Path $PSScriptRoot '../../scripts/dashboard-scheduler/dashboard-listener.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
    foreach ($name in @('Start-WakeWorker', 'Receive-WakeCompletion', 'Invoke-PendingWakeWorkspaces')) {
        $node = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }.GetNewClosure(), $true)
        Invoke-Expression $node.Extent.Text
    }
    function Write-Log { param($Level, $Message) }
    function Set-LastAck { param($Workspace, $Timestamp) $script:Ack = $Timestamp }
    function Remove-VibeAttempt { param($Timestamp) }
    function Invoke-ProcessWorkspace { param($Workspace) }
}

Describe 'Nonblocking wake completion (production functions)' {
    BeforeEach {
        $script:Ack = $null
        $script:ActiveWake = $null
        $pending = @{}
        $Once = $false
        $DebounceSeconds = 10
    }

    It 'keeps detection state available while a real worker is blocked and acknowledges only after exit' {
        $gate = Join-Path $TestDrive 'release'
        $worker = Join-Path $TestDrive 'worker.ps1'
        'param($Gate); while (-not (Test-Path $Gate)) { Start-Sleep -Milliseconds 50 }; exit 0' | Set-Content $worker
        $hostExe = (Get-Process -Id $PID).Path
        $job = Start-WakeWorker $hostExe $worker @($gate)
        try {
            $script:ActiveWake = @{ Job=$job; Workspace='one'; Timestamp='head'; IsVibe=$false; Remaining=1; ExitCode=$null }
            Receive-WakeCompletion
            $script:ActiveWake | Should -Not -BeNullOrEmpty
            $script:Ack | Should -BeNullOrEmpty
            # The detector coalesces repeated notifications without launching another worker.
            $pending['two'] = [DateTime]::UtcNow
            $pending['two'] = [DateTime]::UtcNow
            $pending.Count | Should -Be 1
            $script:ActiveWake.Job.Id | Should -Be $job.Id
            Mock Invoke-ProcessWorkspace { throw 'must not dispatch while active' }
            Invoke-PendingWakeWorkspaces @('two')
            Should -Invoke Invoke-ProcessWorkspace -Times 0
            $pending.ContainsKey('two') | Should -BeTrue
            New-Item $gate -ItemType File | Out-Null
            $job | Wait-Job -Timeout 20 | Out-Null
            Receive-WakeCompletion
            $script:Ack | Should -Be 'head'
            $script:ActiveWake | Should -BeNullOrEmpty
            $pending.ContainsKey('two') | Should -BeTrue
            $pending.ContainsKey('one') | Should -BeTrue
            Mock Invoke-ProcessWorkspace { param($Workspace) $script:Dispatched = $Workspace }
            Invoke-PendingWakeWorkspaces @('two')
            Should -Invoke Invoke-ProcessWorkspace -Times 1
            $script:Dispatched | Should -Be 'two'
            $pending.ContainsKey('two') | Should -BeFalse
        } finally {
            if (Get-Job -Id $job.Id -ErrorAction SilentlyContinue) { Stop-Job $job; Remove-Job $job }
        }
    }

    It 'does not acknowledge a completed wrapper without an exit marker' {
        $job = Start-Job { 'no child result' }
        $job | Wait-Job -Timeout 20 | Out-Null
        $script:ActiveWake = @{ Job=$job; Workspace='one'; Timestamp='head'; IsVibe=$false; Remaining=0; ExitCode=$null }
        try {
            Receive-WakeCompletion
            $script:Ack | Should -BeNullOrEmpty
            $script:ActiveWake.CompletionUnknown | Should -BeTrue
            $script:ActiveWake.Job.Id | Should -Be $job.Id
            Mock Invoke-ProcessWorkspace { throw 'unknown child must retain exclusion' }
            $pending['two'] = [DateTime]::UtcNow
            Invoke-PendingWakeWorkspaces @('two')
            Should -Invoke Invoke-ProcessWorkspace -Times 0
        } finally { Remove-Job $job; $script:ActiveWake = $null }
    }

    It 'retains exclusion after a failed job without child completion' {
        $job = Start-Job { throw 'synthetic wrapper failure' }
        $job | Wait-Job -Timeout 20 | Out-Null
        $script:ActiveWake = @{ Job=$job; Workspace='one'; Timestamp='head'; IsVibe=$false; Remaining=0; ExitCode=$null }
        try {
            Receive-WakeCompletion
            $script:Ack | Should -BeNullOrEmpty
            $script:ActiveWake.CompletionUnknown | Should -BeTrue
        } finally { Remove-Job $job; $script:ActiveWake = $null }
    }

    It 'does not acknowledge an absent executable' {
        $job = Start-WakeWorker 'missing-wake-host-42.exe' 'unused.ps1' @()
        $job | Wait-Job -Timeout 20 | Out-Null
        $script:ActiveWake = @{ Job=$job; Workspace='one'; Timestamp='head'; IsVibe=$false; Remaining=0; ExitCode=$null }
        Receive-WakeCompletion
        $script:Ack | Should -BeNullOrEmpty
        $script:ActiveWake | Should -BeNullOrEmpty
        $pending.ContainsKey('one') | Should -BeTrue
    }

    It 'does not acknowledge an absent script' {
        $job = Start-WakeWorker (Get-Process -Id $PID).Path (Join-Path $TestDrive 'absent.ps1') @()
        $job | Wait-Job -Timeout 20 | Out-Null
        $script:ActiveWake = @{ Job=$job; Workspace='one'; Timestamp='head'; IsVibe=$false; Remaining=0; ExitCode=$null }
        Receive-WakeCompletion
        $script:Ack | Should -BeNullOrEmpty
        $script:ActiveWake | Should -BeNullOrEmpty
        $pending.ContainsKey('one') | Should -BeTrue
    }

    It 'rejects a null exit marker instead of interpreting it as success' {
        $job = Start-Job { [pscustomobject]@{ WakeWorkerExitCode=$null } }
        $job | Wait-Job -Timeout 20 | Out-Null
        $script:ActiveWake = @{ Job=$job; Workspace='one'; Timestamp='head'; IsVibe=$false; Remaining=0; ExitCode=$null }
        try {
            Receive-WakeCompletion
            $script:Ack | Should -BeNullOrEmpty
            $script:ActiveWake.CompletionUnknown | Should -BeTrue
        } finally { Remove-Job $job; $script:ActiveWake=$null }
    }

    It 'does not requeue a completed worker in Once mode' {
        $Once = $true
        $job = Start-Job { [pscustomobject]@{ WakeWorkerExitCode=0 } }
        $job | Wait-Job -Timeout 20 | Out-Null
        $script:ActiveWake = @{ Job=$job; Workspace='one'; Timestamp='head'; IsVibe=$false; Remaining=0; ExitCode=$null }
        Receive-WakeCompletion
        $script:Ack | Should -Be 'head'
        $pending.Count | Should -Be 0
    }

    It 'preserves the durable mandate after exit <Code>' -ForEach @(@{Code=75}, @{Code=1}, @{Code=124}) {
        $job = Start-Job { param($Code) [pscustomobject]@{ WakeWorkerExitCode=$Code } } -ArgumentList $Code
        $job | Wait-Job -Timeout 20 | Out-Null
        $script:ActiveWake = @{ Job=$job; Workspace='one'; Timestamp='head'; IsVibe=$false; Remaining=0; ExitCode=$null }
        Receive-WakeCompletion
        $script:Ack | Should -BeNullOrEmpty
        $pending.ContainsKey('one') | Should -BeTrue
    }
}

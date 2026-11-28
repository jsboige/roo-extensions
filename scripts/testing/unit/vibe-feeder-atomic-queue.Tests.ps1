# Exercise the real Write-Queue function against a disposable queue.
BeforeAll {
    $src = Get-Content (Join-Path $PSScriptRoot '../../scheduling/vibe-feeder.ps1') -Raw
    $script:queueFunction = [regex]::Match($src, '(?ms)^function Write-Queue \{\r?\n.*?^\}').Value
    if (-not $script:queueFunction) { throw 'Write-Queue not found' }
    Invoke-Expression $script:queueFunction
}
Describe 'Feeder queue publication' {
    It 'publishes through a same-directory temporary file and atomic replacement' {
        $script:queueFunction | Should -Match '\[IO\.File\]::Replace'
    }
    BeforeEach {
        $script:QueuePath = Join-Path $TestDrive 'queue.json'
        [IO.File]::WriteAllText($script:QueuePath, '{"grains":[{"id":"old"}]}')
    }
    It 'preserves the old queue if JSON serialization fails' {
        $queue = [pscustomobject]@{ grains = @([pscustomobject]@{ id = 'new' }) }
        Mock ConvertTo-Json { throw 'serialization failed' }
        { Write-Queue -Queue $queue } | Should -Throw
        [IO.File]::ReadAllText($script:QueuePath) | Should -Be '{"grains":[{"id":"old"}]}'
    }
    It 'replaces an existing queue with valid JSON' {
        Write-Queue -Queue ([pscustomobject]@{ grains = @([pscustomobject]@{ id = 'new' }) })
        $actual = [IO.File]::ReadAllText($script:QueuePath) | ConvertFrom-Json
        $actual.grains[0].id | Should -Be 'new'
    }
}

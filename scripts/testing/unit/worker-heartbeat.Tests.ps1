# Tests unitaires pour le module heartbeat worker partagé (#3207, #3209)
# Module: scripts/common/worker-heartbeat.ps1
# Syntaxe Pester v3 (Windows PowerShell 5.1)
#
# Usage:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module Pester -RequiredVersion 3.4.0 -Force; Invoke-Pester .\scripts\testing\unit\worker-heartbeat.Tests.ps1"

Describe "Worker Heartbeat - module partage (#3207)" {

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    . (Join-Path $projectRoot "scripts\common\worker-heartbeat.ps1")

    # Stub du logger attendu dans le scope appelant (convention des deux workers)
    function global:Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $script:CapturedLogs += $Message
    }
    $script:CapturedLogs = @()

    $tempRoot = Join-Path $env:TEMP "worker-heartbeat-tests-$(Get-Random)"

    It "ecrit worker-heartbeats/<machine>.heartbeat en chemin nominal" {
        $env:ROOSYNC_SHARED_PATH = $tempRoot
        Write-WorkerHeartbeat | Out-Null
        $machine = $env:COMPUTERNAME.ToLower()
        $hb = Join-Path $tempRoot "worker-heartbeats\$machine.heartbeat"
        Test-Path $hb | Should Be $true
        $content = Get-Content $hb -Raw
        $content.Length | Should Be 20  # "yyyy-MM-ddTHH:mm:ssZ" exact — WriteAllText n'ajoute pas de newline
        $content -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z' | Should Be $true
        ($script:CapturedLogs | Where-Object { $_ -match 'Worker heartbeat written' }).Count | Should Be 1
    }

    It "est une no-op silencieuse sans ROOSYNC_SHARED_PATH" {
        Remove-Item Env:\ROOSYNC_SHARED_PATH -ErrorAction SilentlyContinue
        $before = $script:CapturedLogs.Count
        { Write-WorkerHeartbeat } | Should Not Throw
        $script:CapturedLogs.Count | Should Be $before
    }

    It "-LogPrefix personnalise les messages sans toucher au comportement" {
        $env:ROOSYNC_SHARED_PATH = $tempRoot
        $script:CapturedLogs = @()
        Write-WorkerHeartbeat -LogPrefix 'Heartbeat' | Out-Null
        ($script:CapturedLogs | Where-Object { $_ -match '^Heartbeat written' }).Count | Should Be 1
        ($script:CapturedLogs | Where-Object { $_ -match 'Worker heartbeat' }).Count | Should Be 0
    }

    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\ROOSYNC_SHARED_PATH -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Write-Log -ErrorAction SilentlyContinue
}

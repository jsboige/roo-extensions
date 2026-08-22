# Tests unitaires pour le module heartbeat worker partagé (#3207, #3209)
# Module: scripts/common/worker-heartbeat.ps1
#
# Syntaxe Pester v5 — exécuté en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Fonctionne sur pwsh Windows ET Linux :
# - chemins en slashes + [IO.Path]::GetTempPath() (pas de $env:TEMP, absent de pwsh Linux)
# - $env:COMPUTERNAME absent sur Linux → le module écrit 'unknown.heartbeat'
#   (le test réplique le fallback du module au lieu d'appeler .ToLower() sur $null)
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-heartbeat.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/common/worker-heartbeat.ps1")

    # Stub du logger attendu dans le scope appelant (convention des deux workers)
    function global:Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $script:CapturedLogs += $Message
    }
    $script:CapturedLogs = @()
    $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "worker-heartbeat-tests-$(Get-Random)"
}

Describe "Worker Heartbeat - module partagé (#3207)" {

    It "écrit worker-heartbeats/<machine>.heartbeat en chemin nominal" {
        $env:ROOSYNC_SHARED_PATH = $script:TempRoot
        Write-WorkerHeartbeat | Out-Null
        # Même fallback que le module : COMPUTERNAME (Windows) sinon 'unknown' (Linux CI)
        $machine = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.ToLower() } else { 'unknown' }
        $hb = Join-Path $script:TempRoot "worker-heartbeats/$machine.heartbeat"
        Test-Path $hb | Should -Be $false
        $content = Get-Content $hb -Raw
        $content.Length | Should -Be 20  # "yyyy-MM-ddTHH:mm:ssZ" exact — WriteAllText n'ajoute pas de newline
        $content -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z' | Should -Be $true
        ($script:CapturedLogs | Where-Object { $_ -match 'Worker heartbeat written' }).Count | Should -Be 1
    }

    It "est une no-op silencieuse sans ROOSYNC_SHARED_PATH" {
        Remove-Item Env:\ROOSYNC_SHARED_PATH -ErrorAction SilentlyContinue
        $before = $script:CapturedLogs.Count
        { Write-WorkerHeartbeat } | Should -Not -Throw
        $script:CapturedLogs.Count | Should -Be $before
    }

    It "-LogPrefix personnalisé les messages sans toucher au comportement" {
        $env:ROOSYNC_SHARED_PATH = $script:TempRoot
        $script:CapturedLogs = @()
        Write-WorkerHeartbeat -LogPrefix 'Heartbeat' | Out-Null
        ($script:CapturedLogs | Where-Object { $_ -match '^Heartbeat written' }).Count | Should -Be 1
        ($script:CapturedLogs | Where-Object { $_ -match 'Worker heartbeat' }).Count | Should -Be 0
    }
}

AfterAll {
    Remove-Item $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\ROOSYNC_SHARED_PATH -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Write-Log -ErrorAction SilentlyContinue
}

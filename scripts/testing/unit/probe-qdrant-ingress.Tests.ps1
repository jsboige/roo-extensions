<#
.SYNOPSIS
    Guards the #4438 public-ingress probe (scripts/diagnostic/probe-qdrant-ingress.py).

    Two halves, like every guard in this suite:
      - CONTENT: the probe targets the PUBLIC ingress by default, names the
        local-container scope explicitly, and never prints the API key.
      - BEHAVIOUR: the python unittest runs the real probe against mocked HTTP
        (200 / 502 / timeout / 401) and asserts the exit-code contract.
#>

Describe 'Qdrant public-ingress probe (#4438)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $probePath = Join-Path $root 'scripts\diagnostic\probe-qdrant-ingress.py'
        $pyTestsPath = Join-Path $root 'scripts\testing\python\test_probe_qdrant_ingress.py'
        $ciPath = Join-Path $root '.github\workflows\ci.yml'

        $probe = Get-Content $probePath -Raw
        $ci = Get-Content $ciPath -Raw

        # 'python3' may resolve to the inert WindowsApps Store alias on Windows
        # (measured po-2025) — try the real interpreters in order.
        $script:Python = $null
        $candidates = if ($env:OS -eq 'Windows_NT') { @('python', 'py') } else { @('python3', 'python') }
        foreach ($candidate in $candidates) {
            $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($cmd) { $script:Python = $cmd.Source; break }
        }
    }

    Context 'Content guards' {
        It 'defaults to the PUBLIC ingress, not the local container' {
            # #4438: le site d'EMISSION est ancre (DEFAULT_URL), pas une mention
            # quelconque. Ancrer une mention laissait passer le mutant « cible
            # locale » : le second litteral (dans resolve_target) suffisait a
            # satisfaire le grep alors que le defaut reel restait local.
            $probe | Should -Match 'DEFAULT_URL = "https://qdrant\.myia\.io/collections"'
            # regle non dupliquee : un seul litterel porte l'ingress public
            ([regex]::Matches($probe, 'https://qdrant\.myia\.io')).Count | Should -Be 1
            $probe | Should -Match 'public-ingress'
            $probe | Should -Match 'local-container'
        }

        It 'reads the API key BY NAME and never prints it' {
            $probe | Should -Match 'QDRANT_API_KEY'
            # a printed value would look like a format of the key itself
            $probe | Should -Not -Match 'print\([^)]*api_key'
            $probe | Should -Not -Match 'f"[^"]*\{api_key\}'
        }

        It 'classifies the 502 blackhole and the timeout apart' {
            $probe | Should -Match 'ingress_blackholed'
            $probe | Should -Match '"timeout"'
        }
    }

    Context 'CI wiring' {
        It 'the guarded source re-triggers the unit-pester job on a main push' {
            $ci | Should -Match 'scripts/diagnostic/probe-qdrant-ingress\.py'
        }
    }

    Context 'Behavioural harness (unittest, mocked HTTP)' {
        It 'runs the unittest suite (200 / 502 / timeout / 401, exit codes, secret)' {
            if (-not $script:Python) {
                Write-Host "python not found - behavioural unittest skipped (content guards above still active)"
                Set-ItResult -Skipped -Because 'python not available'
            }
            else {
                # System.Diagnostics.Process, pas '& ... 2>&1' : sous PS 5.1,
                # stderr natif fusionne via 2>&1 devient des ErrorRecords.
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $script:Python
                $psi.Arguments = '"' + $pyTestsPath + '"'
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $proc = [System.Diagnostics.Process]::Start($psi)
                $stdout = $proc.StandardOutput.ReadToEnd()
                $stderr = $proc.StandardError.ReadToEnd()
                $proc.WaitForExit()
                $proc.ExitCode | Should -Be 0 -Because "unittest output: $stdout $stderr"
            }
        }
    }
}

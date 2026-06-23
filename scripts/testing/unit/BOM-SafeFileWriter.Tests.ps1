# Tests unitaires pour BOM-SafeFileWriter.ps1
# Prévention de régression #664 : [BUG] BOM UTF-8 récurrent dans mcp_settings.json
#
# Invariant testé : les fonctions BOM-safe doivent produire des fichiers SANS BOM UTF-8
# (0xEF 0xBB 0xBF), car PowerShell 5.1 Set-Content/Add-Content -Encoding UTF8 l'ajoute
# et casse le parsing JSON (issue #664).
#
# Syntaxe Pester v5 — compatible avec le runner scripts/testing/run-pester-tests.ps1
# qui charge Pester 5.x par défaut (Import-Module Pester -Force).
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path .\scripts\testing\unit\BOM-SafeFileWriter.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    # Import-Module (not dot-source): BOM-SafeFileWriter.ps1 ends with Export-ModuleMember,
    # which is only valid inside a module. Import-Module exposes the 3 functions as cmdlets.
    # -ErrorAction SilentlyContinue: suppresses the benign Export-ModuleMember chatter emitted
    # when a .ps1 (vs .psm1) is imported; the functions still load (verified: all tests pass).
    Import-Module (Join-Path $projectRoot "scripts\encoding\BOM-SafeFileWriter.ps1") -Force -ErrorAction SilentlyContinue

    # Helper : retourne $true si le fichier commence par un BOM UTF-8 (EF BB BF)
    function Test-FileHasBom {
        param([string]$Path)
        if (-not (Test-Path $Path)) { return $false }
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        if ($bytes.Length -lt 3) { return $false }
        return ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    }
}

Describe "BOM-SafeFileWriter - #664 BOM-free output invariant" {

    Context "Set-FileBOMSafe (overwrite without BOM)" {

        It "Writes content WITHOUT a UTF-8 BOM" {
            $file = [System.IO.Path]::GetTempFileName()
            try {
                Set-FileBOMSafe -Path $file -Value '{"key":"value"}'
                Test-FileHasBom -Path $file | Should -Be $false
            }
            finally { Remove-Item $file -ErrorAction SilentlyContinue }
        }

        It "Overwrites an existing file completely (no append, content == new value)" {
            $file = [System.IO.Path]::GetTempFileName()
            try {
                # Pre-seed with stale content (and a BOM via PS Set-Content, the #664 footgun)
                Set-Content -Path $file -Value 'STALE' -Encoding UTF8
                Set-FileBOMSafe -Path $file -Value 'NEW'
                (Get-Content -Path $file -Raw).Trim() | Should -BeExactly 'NEW'
            }
            finally { Remove-Item $file -ErrorAction SilentlyContinue }
        }

        It "Roundtrips content faithfully (write then read == input)" {
            $file = [System.IO.Path]::GetTempFileName()
            $payload = '{"mcpServers":{"roo-state-manager":{"command":"node"}}}'
            try {
                Set-FileBOMSafe -Path $file -Value $payload
                [System.IO.File]::ReadAllText($file) | Should -BeExactly $payload
            }
            finally { Remove-Item $file -ErrorAction SilentlyContinue }
        }
    }

    Context "Write-FileBOMSafe (append without BOM)" {

        It "Appends content WITHOUT introducing a UTF-8 BOM" {
            $file = [System.IO.Path]::GetTempFileName()
            try {
                Write-FileBOMSafe -Path $file -Value 'first'
                Write-FileBOMSafe -Path $file -Value 'second'
                Test-FileHasBom -Path $file | Should -Be $false
            }
            finally { Remove-Item $file -ErrorAction SilentlyContinue }
        }

        It "Preserves existing content when appending (-NoNewLine)" {
            $file = [System.IO.Path]::GetTempFileName()
            try {
                Write-FileBOMSafe -Path $file -Value 'line1' -NoNewLine
                Write-FileBOMSafe -Path $file -Value 'line2' -NoNewLine
                [System.IO.File]::ReadAllText($file) | Should -BeExactly 'line1line2'
            }
            finally { Remove-Item $file -ErrorAction SilentlyContinue }
        }

        It "Appends a trailing CRLF by default (no -NoNewLine)" {
            $file = [System.IO.Path]::GetTempFileName()
            try {
                Write-FileBOMSafe -Path $file -Value 'abc'
                [System.IO.File]::ReadAllText($file) | Should -BeExactly "abc`r`n"
            }
            finally { Remove-Item $file -ErrorAction SilentlyContinue }
        }
    }
}

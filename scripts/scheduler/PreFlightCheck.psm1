<#
.SYNOPSIS
    Pre-flight check module for scheduler workflows.

.DESCRIPTION
    Standardized pre-flight check for all scheduler workflows.
    Verifies win-cli and roo-state-manager MCP availability.

.EXAMPLE
    Test-PreFlightCheck
#>

function Test-PreFlightCheck {
    [OutputType([hashtable])]
    param()

    $results = @{
        WinCliAvailable = $false
        RooStateManagerAvailable = $false
        OverallStatus = "FAIL"
        Errors = @()
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    # Test 1: Win-cli MCP (execute_command)
    try {
        $winCliTest = execute_command -shell "powershell" -command "echo PRE-FLIGHT-OK" 2>$null
        if ($winCliTest -match "PRE-FLIGHT-OK") {
            $results.WinCliAvailable = $true
        } else {
            $results.Errors += "Win-cli execute_command did not return expected output"
        }
    } catch {
        $results.Errors += "Win-cli MCP not available: $($_.Exception.Message)"
    }

    # Test 2: Roo-state-manager MCP (conversation_browser)
    try {
        $rooTest = conversation_browser -action "current" -workspace "d:\Dev\roo-extensions" 2>$null
        if ($rooTest) {
            $results.RooStateManagerAvailable = $true
        } else {
            $results.Errors += "conversation_browser returned empty result"
        }
    } catch {
        $results.Errors += "Roo-state-manager MCP not available: $($_.Exception.Message)"
    }

    # Overall status
    ($results.WinCliAvailable -and $results.RooStateManagerAvailable) {
        $results.OverallStatus = "PASS"
    }

    return $results
}

<#
.SYNOPSIS
    Writes pre-flight check result to INTERCOM.

.DESCRIPTION
    Appends the pre-flight check result to the local INTERCOM file.
    Writes CRITICAL message if check fails.

.PARAMETER Result
    The hashtable returned by Test-PreFlightCheck.

.PARAMETER MachineName
    The machine name (e.g., "myia-po-2023").

.EXAMPLE
    $result = Test-PreFlightCheck
    Write-PreFlightCheckToINTERCOM -Result $result -MachineName "myia-po-2023"
#>
function Write-PreFlightCheckToINTERCOM {
    param(
        [hashtable]$Result,
        [string]$MachineName
    )

    $intercomPath = ".claude/local/INTERCOM-$MachineName.md"
    $timestamp = $Result.Timestamp

    if ($Result.OverallStatus -eq "FAIL") {
        # CRITICAL - write to INTERCOM
        $message = @"

## [$timestamp] claude-code -> roo [CRITICAL]
### MCP non disponible - Scheduler BLOQUE

**Pre-flight check FAIL:**

- Win-cli: $(if ($Result.WinCliAvailable) { "✅ OK" } else { "❌ FAIL" })
- Roo-state-manager: $(if ($Result.RooStateManagerAvailable) { "✅ OK" } else { "❌ FAIL" })

**Errors:**
$($result.Errors -join "`n")

**Action:** STOP IMMEDIAT - Reparer MCP avant de continuer.

---
"@

        Add-Content -Path $intercomPath -Value $message -ErrorAction SilentlyContinue
        return $false
    } else {
        # SUCCESS - log only
        $message = @"

## [$timestamp] claude-code -> roo [INFO]
### Pre-flight check OK

- Win-cli: ✅ OK
- Roo-state-manager: ✅ OK

---
"@

        Add-Content -Path $intercomPath -Value $message -ErrorAction SilentlyContinue
        return $true
    }
}

Export-ModuleMember -Function Test-PreFlightCheck, Write-PreFlightCheckToINTERCOM

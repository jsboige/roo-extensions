# =================================================================================================
#
#   WSL/Docker Cascade Kill Diagnostic Script
#
#   Issue: #1379 - [ai-01] WSL/Docker cascade kill → all VSCode terminated silently
#
#   This script collects diagnostic information after a WSL/Docker cascade failure incident.
#   Run this script IMMEDIATELY after discovering all VSCode windows closed simultaneously.
#
#   Usage:
#     .\scripts\diagnostic\diagnostic-wsl-docker-cascade.ps1
#
#   Output:
#     - Creates a timestamped diagnostic report in logs/wsl-docker-cascade/
#     - Collects Windows Event Log data for the incident timeframe
#     - Checks WSL, Docker, and VSCode process status
#
# =================================================================================================

param(
    [Parameter(Mandatory = $false, HelpMessage = "Incident timestamp (default: now)")]
    [DateTime]$IncidentTime = (Get-Date),

    [Parameter(Mandatory = $false, HelpMessage = "Minutes before incident to collect (default: 30)")]
    [int]$MinutesBefore = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Minutes after incident to collect (default: 60)")]
    [int]$MinutesAfter = 60,

    [Parameter(Mandatory = $false, HelpMessage = "Output directory for reports")]
    [string]$OutputDir = "logs/wsl-docker-cascade"
)

# =================================================================================================
#   SETUP
# =================================================================================================

$ErrorActionPreference = "Continue"
$startTime = Get-Date
$timestamp = $startTime.ToString("yyyyMMdd-HHmmss")
$outputPath = Join-Path $OutputDir "incident-$timestamp.json"
$reportPath = Join-Path $OutputDir "incident-$timestamp-report.md"

# Ensure output directory exists
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

# =================================================================================================
#   HELPER FUNCTIONS
# =================================================================================================

function Write-DiagnosticOutput {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    })
}

function Get-EventLogData {
    param(
        [string]$LogName,
        [DateTime]$StartTime,
        [DateTime]$EndTime,
        [string[]]$ProviderNames = @(),
        [int[]]$EventIds = @()
    )

    try {
        $filter = @{
            LogName   = $LogName
            StartTime = $StartTime
            EndTime   = $EndTime
        }

        if ($ProviderNames.Count -gt 0) {
            $filter['ProviderName'] = $ProviderNames
        }

        if ($EventIds.Count -gt 0) {
            $filter['ID'] = $EventIds
        }

        $events = Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue
        return $events | ForEach-Object {
            [PSCustomObject]@{
                Time     = $_.TimeCreated.ToString("o")
                Provider = $_.ProviderName
                Id       = $_.Id
                Message  = $_.Message -replace '\s+', ' '  # Normalize whitespace
            }
        }
    }
    catch {
        Write-DiagnosticOutput "Failed to get events from $LogName`: $($_.Exception.Message)" "WARN"
        return @()
    }
}

function Get-ProcessInfo {
    param([string]$ProcessName)

    try {
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | ForEach-Object {
            [PSCustomObject]@{
                Name           = $_.ProcessName
                Id             = $_.Id
                StartTime      = $_.StartTime.ToString("o")
                WorkingSet     = $_.WorkingSet64
                CPU            = $_.CPU
                Path           = $_.Path
                MainWindowTitle = $_.MainWindowTitle
            }
        }
    }
    catch {
        return @()
    }
}

# =================================================================================================
#   DIAGNOSTIC COLLECTION
# =================================================================================================

Write-DiagnosticOutput "=== WSL/Docker Cascade Kill Diagnostic ===" "SUCCESS"
Write-DiagnosticOutput "Incident Time: $($IncidentTime.ToString('o'))" "INFO"
Write-DiagnosticOutput "Collection Window: -$MinutesBefore min to +$MinutesAfter min" "INFO"
Write-DiagnosticOutput "Output: $outputPath" "INFO"

$diagnosticData = [PSCustomObject]@{
    CollectionInfo = [PSCustomObject]@{
        StartTime      = $startTime.ToString("o")
        IncidentTime   = $IncidentTime.ToString("o")
        MinutesBefore  = $MinutesBefore
        MinutesAfter   = $MinutesAfter
        MachineName    = $env:COMPUTERNAME
        UserName       = $env:USERNAME
    }
    OSInfo         = [PSCustomObject]@{
        LastBootUpTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString("o")
        UptimeDays    = [math]::Floor(((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalDays)
        OSVersion     = [System.Environment]::OSVersion.VersionString
    }
}

# Calculate time window
$windowStart = $IncidentTime.AddMinutes(-$MinutesBefore)
$windowEnd = $IncidentTime.AddMinutes($MinutesAfter)

Write-DiagnosticOutput "Time window: $($windowStart.ToString('o')) to $($windowEnd.ToString('o'))" "INFO"

# --- Phase 1: System Events ---
Write-DiagnosticOutput "Collecting System events..." "INFO"

$systemEvents = Get-EventLogData -LogName "System" -StartTime $windowStart -EndTime $windowEnd
$diagnosticData | Add-Member -NotePropertyName SystemEvents -NotePropertyValue $systemEvents

# Filter for critical events
$serviceControlEvents = $systemEvents | Where-Object { $_.Id -eq 7040 }
$httpServiceEvents = $systemEvents | Where-Object { $_.Id -in @(113, 114) }

Write-DiagnosticOutput "Found $($systemEvents.Count) System events" "INFO"
Write-DiagnosticOutput "  - Service Control Manager events (7040): $($serviceControlEvents.Count)" "INFO"
Write-DiagnosticOutput "  - HTTP Service events (113/114): $($httpServiceEvents.Count)" "INFO"

# --- Phase 2: Application Errors ---
Write-DiagnosticOutput "Collecting Application Error events..." "INFO"

$appErrorEvents = Get-EventLogData -LogName "Application" -StartTime $windowStart -EndTime $windowEnd -EventIds @(1000)
$diagnosticData | Add-Member -NotePropertyName ApplicationErrors -NotePropertyValue $appErrorEvents

Write-DiagnosticOutput "Found $($appErrorEvents.Count) Application Error events (1000)" "INFO"

# --- Phase 3: BITS events (Windows Update indicator) ---
Write-DiagnosticOutput "Collecting BITS service events..." "INFO"

$bitsEvents = $systemEvents | Where-Object {
    $_.ProviderName -like "*BITS*" -or $_.Message -like "*BITS*"
}
$diagnosticData | Add-Member -NotePropertyName BITSEvents -NotePropertyValue $bitsEvents

Write-DiagnosticOutput "Found $($bitsEvents.Count) BITS-related events" "INFO"

# --- Phase 4: Defender events ---
Write-DiagnosticOutput "Collecting Windows Defender events..." "INFO"

$defenderCrashEvents = Get-EventLogData -LogName "Application" -StartTime $windowStart -EndTime $windowEnd -ProviderNames @("MsMpEng.exe") -EventIds @(1000)
$diagnosticData | Add-Member -NotePropertyName DefenderEvents -NotePropertyValue $defenderCrashEvents

Write-DiagnosticOutput "Found $($defenderCrashEvents.Count) Defender crash events" "INFO"

# --- Phase 5: Hyper-V events (WSL backend) ---
Write-DiagnosticOutput "Collecting Hyper-V events..." "INFO"

$hypervEvents = Get-EventLogData -LogName "System" -StartTime $windowStart -EndTime $windowEnd -ProviderNames @("Microsoft-Windows-Hyper-V-Worker", "Microsoft-Windows-Hyper-V-Compute")
$diagnosticData | Add-Member -NotePropertyName HyperVEvents -NotePropertyValue $hypervEvents

Write-DiagnosticOutput "Found $($hypervEvents.Count) Hyper-V events" "INFO"

# --- Phase 6: Current Process Status ---
Write-DiagnosticOutput "Collecting current process status..." "INFO"

$currentVSCodeProcesses = Get-ProcessInfo "Code"
$currentWSLProcesses = Get-ProcessInfo "wsl"
$currentDockerProcesses = Get-ProcessInfo "Docker Desktop", "com.docker.backend", "com.docker.cli"

$diagnosticData | Add-Member -NotePropertyName CurrentVSCodeProcesses -NotePropertyValue $currentVSCodeProcesses
$diagnosticData | Add-Member -NotePropertyName CurrentWSLProcesses -NotePropertyValue $currentWSLProcesses
$diagnosticData | Add-Member -NotePropertyName CurrentDockerProcesses -NotePropertyValue $currentDockerProcesses

Write-DiagnosticOutput "Current VSCode processes: $($currentVSCodeProcesses.Count)" "INFO"
Write-DiagnosticOutput "Current WSL processes: $($currentWSLProcesses.Count)" "INFO"
Write-DiagnosticOutput "Current Docker processes: $($currentDockerProcesses.Count)" "INFO"

# --- Phase 7: WSL Status ---
Write-DiagnosticOutput "Checking WSL status..." "INFO"

try {
    $wslRunning = wsl --list --running 2>&1
    $diagnosticData | Add-Member -NotePropertyName WSLRunningDistributions -NotePropertyValue $wslRunning
    Write-DiagnosticOutput "WSL running distributions: $($wslProcesses.Count -gt 0)" "INFO"
}
catch {
    $diagnosticData | Add-Member -NotePropertyName WSLRunningDistributions -NotePropertyValue "Error: $($_.Exception.Message)"
    Write-DiagnosticOutput "Failed to get WSL status: $($_.Exception.Message)" "WARN"
}

# --- Phase 8: Resource Status ---
Write-DiagnosticOutput "Checking system resources..." "INFO"

$os = Get-CimInstance Win32_OperatingSystem
$memoryInfo = [PSCustomObject]@{
    TotalMemoryGB   = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    FreeMemoryGB    = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    MemoryPercent   = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 2)
}

$diagnosticData | Add-Member -NotePropertyName MemoryInfo -NotePropertyValue $memoryInfo

Write-DiagnosticOutput "Memory: $($memoryInfo.FreeMemoryGB)GB free / $($memoryInfo.TotalMemoryGB)GB total ($($memoryInfo.MemoryPercent)% used)" "INFO"

# =================================================================================================
#   SAVE RESULTS
# =================================================================================================

Write-DiagnosticOutput "Saving diagnostic data..." "INFO"

$diagnosticData | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8

# =================================================================================================
#   GENERATE HUMAN-READABLE REPORT
# =================================================================================================

Write-DiagnosticOutput "Generating report..." "INFO"

$report = @"
# WSL/Docker Cascade Kill Incident Report

**Generated:** $($startTime.ToString("o"))
**Incident Time:** $($IncidentTime.ToString("o"))
**Machine:** $($env:COMPUTERNAME)
**User:** $($env:USERNAME)

---

## Collection Info

- **Collection Window:** -$MinutesBefore min to +$MinutesAfter min
- **Start Time:** $($windowStart.ToString("o"))
- **End Time:** $($windowEnd.ToString("o"))

## System Status

- **Last Boot:** $($diagnosticData.OSInfo.LastBootUpTime)
- **Uptime:** $($diagnosticData.OSInfo.UptimeDays) days
- **OS Version:** $($diagnosticData.OSInfo.OSVersion)

## Memory Status

- **Free:** $($memoryInfo.FreeMemoryGB) GB / $($memoryInfo.TotalMemoryGB) GB
- **Used:** $($memoryInfo.MemoryPercent)%

## Key Findings

### System Events (Total: $($systemEvents.Count))

- **Service Control Manager (7040):** $($serviceControlEvents.Count) events
- **HTTP Service (113/114):** $($httpServiceEvents.Count) events

### Application Errors (Total: $($appErrorEvents.Count))

$($appErrorEvents | Format-Table -Property Time, Provider, Message -AutoSize | Out-String)

### BITS Service Events (Total: $($bitsEvents.Count))

$($bitsEvents | Format-Table -Property Time, Id, Message -AutoSize | Out-String)

### Defender Crashes (Total: $($defenderCrashEvents.Count))

$($defenderCrashEvents | Format-Table -Property Time, Message -AutoSize | Out-String)

### Hyper-V Events (Total: $($hypervEvents.Count))

$($hypervEvents | Format-Table -Property Time, Provider, Id, Message -AutoSize | Out-String)

## Current Process Status

### VSCode Processes: $($currentVSCodeProcesses.Count)

$($currentVSCodeProcesses | Format-Table -AutoSize | Out-String)

### WSL Processes: $($currentWSLProcesses.Count)

$($currentWSLProcesses | Format-Table -AutoSize | Out-String)

### Docker Processes: $($currentDockerProcesses.Count)

$($currentDockerProcesses | Format-Table -AutoSize | Out-String)

## WSL Status

```
$($diagnosticData.WSLRunningDistributions)
```

---

## Analysis Notes

**CRITICAL INDICATORS:**
- No Application Error (1000) for Code.exe = `TerminateProcess` kill (not crash)
- HTTP Service burst (113/114) = kernel reaping dying processes
- WSL down post-incident = Hyper-V/Docker cascade failure
- BITS mode flip = Windows Update/Defender trigger

**NEXT STEPS:**
1. Check WSL service log: `%USERPROFILE%\AppData\Local\Temp\wslservice.log`
2. Run Docker Desktop diagnostic: `dd_diag`
3. Check Windows Update history for incident timeframe
4. Consider disabling automatic Windows Update during active development

---

**Full JSON data saved to:** `$outputPath`
"@

$report | Out-File -FilePath $reportPath -Encoding UTF8

# =================================================================================================
#   SUMMARY
# =================================================================================================

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-DiagnosticOutput "=== Diagnostic Complete ===" "SUCCESS"
Write-DiagnosticOutput "Duration: $([math]::Round($duration, 2)) seconds" "INFO"
Write-DiagnosticOutput "JSON report: $outputPath" "INFO"
Write-DiagnosticOutput "Human-readable report: $reportPath" "INFO"

# Display key findings
Write-Host "`n=== KEY FINDINGS ===" -ForegroundColor Cyan

if ($appErrorEvents.Count -eq 0) {
    Write-Host "✓ No Application Error events for VSCode - indicates TerminateProcess kill (not crash)" -ForegroundColor Green
}
else {
    Write-Host "✗ Found $($appErrorEvents.Count) Application Error events - check report for details" -ForegroundColor Red
}

if ($httpServiceEvents.Count -gt 10) {
    Write-Host "✓ Large HTTP Service burst ($($httpServiceEvents.Count) events) - kernel reaping dying processes" -ForegroundColor Yellow
}

if ($currentWSLProcesses.Count -eq 0) {
    Write-Host "✗ WSL not running - may need manual restart: wsl --shutdown" -ForegroundColor Red
}

if ($currentVSCodeProcesses.Count -eq 0) {
    Write-Host "✗ No VSCode processes running - all terminated" -ForegroundColor Red
}
else {
    Write-Host "✓ VSCode processes running: $($currentVSCodeProcesses.Count)" -ForegroundColor Green
}

Write-Host "`nOpen the report for full analysis:" -ForegroundColor Cyan
Write-Host "  $reportPath" -ForegroundColor White

#Requires -RunAsAdministrator
# Disable Windows Update Auto-Reboot
# Issue: #1517
# Applies registry settings to prevent Windows Update from forcing reboots

param(
    [switch]$VerifyOnly
)

$auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$uxPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"

if ($VerifyOnly) {
    Write-Host "=== Current Settings ==="
    if (Test-Path $auPath) {
        Get-ItemProperty $auPath | Select-Object NoAutoRebootWithLoggedOnUsers, AUOptions | Format-List
    } else {
        Write-Host "AU registry path does not exist"
    }
    Get-ItemProperty $uxPath | Select-Object ActiveHoursStart, ActiveHoursEnd | Format-List
    exit 0
}

# Require admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Run as Administrator" -ForegroundColor Red
    exit 1
}

# Step 1: NoAutoRebootWithLoggedOnUsers
if (-not (Test-Path $auPath)) {
    New-Item -Path $auPath -Force | Out-Null
}
Set-ItemProperty -Path $auPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -Force
Write-Host "[OK] NoAutoRebootWithLoggedOnUsers = 1"

# Step 2: AUOptions = 2 (Notify before download)
Set-ItemProperty -Path $auPath -Name "AUOptions" -Value 2 -Type DWord -Force
Write-Host "[OK] AUOptions = 2 (Notify before download)"

# Step 3: Active Hours 18:00 - 08:00
Set-ItemProperty -Path $uxPath -Name "ActiveHoursStart" -Value 18 -Type DWord -Force
Set-ItemProperty -Path $uxPath -Name "ActiveHoursEnd" -Value 8 -Type DWord -Force
Write-Host "[OK] ActiveHoursStart = 18, ActiveHoursEnd = 8"

# Step 4: Disable "Always auto-restart at scheduled time"
Set-ItemProperty -Path $auPath -Name "AlwaysAutoRebootAtScheduledTime" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Write-Host "[OK] AlwaysAutoRebootAtScheduledTime = 0"

# Verification
Write-Host "`n=== Verification ==="
Get-ItemProperty $auPath | Select-Object NoAutoRebootWithLoggedOnUsers, AUOptions | Format-List
Get-ItemProperty $uxPath | Select-Object ActiveHoursStart, ActiveHoursEnd | Format-List

# Check for reboot scheduled tasks
Write-Host "=== Scheduled reboot tasks ==="
$rebootTasks = schtasks /query /fo CSV 2>$null | ConvertFrom-Csv | Where-Object { $_.TaskName -match "reboot|restart|shutdown" }
if ($rebootTasks) {
    $rebootTasks | Select-Object TaskName, Status | Format-Table -AutoSize
} else {
    Write-Host "None found"
}

# Recent unexpected reboots
Write-Host "`n=== Recent reboots (7 days) ==="
Get-WinEvent -LogName System -MaxEvents 500 -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -in 41, 1074, 6008 } |
    Select-Object TimeCreated, Id, Message |
    Format-Table -AutoSize -Wrap

Write-Host "Done. Machine $(hostname) protected against auto-reboots." -ForegroundColor Green

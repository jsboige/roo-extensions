#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configure Windows Auto-Login for Docker auto-start at boot.
.DESCRIPTION
    Sets registry keys so Windows logs in automatically at boot.
    Docker Desktop then starts via HKCU\Run mechanism.
    Password is read from .env file (gitignored) or prompted interactively.
.EXAMPLE
    # Create .env first:
    # echo "AUTOLOGIN_PASSWORD=MyPassword" > scripts/setup/.env
    powershell -ExecutionPolicy Bypass -File Enable-AutoLogin.ps1
    powershell -ExecutionPolicy Bypass -File Enable-AutoLogin.ps1 -Disable
#>

param(
    [string]$Username = $env:USERNAME,
    [string]$Domain = "",
    [switch]$Disable
)

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

if ($Disable) {
    try {
        Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "0" -Force
        Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -Force -ErrorAction SilentlyContinue
        Write-Host "Auto-login DISABLED." -ForegroundColor Green
        Write-Host "Next reboot will require manual login."
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    return
}

# --- Read password from .env or prompt ---
$plainPassword = $null
$envFile = Join-Path $PSScriptRoot ".env"

if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -ErrorAction SilentlyContinue
    foreach ($line in $envContent) {
        if ($line -match '^\s*AUTOLOGIN_PASSWORD\s*=\s*(.+)\s*$') {
            $plainPassword = $Matches[1].Trim('"', "'", ' ')
            Write-Host "Password read from .env file." -ForegroundColor Cyan
            break
        }
        if ($line -match '^\s*AUTOLOGIN_USERNAME\s*=\s*(.+)\s*$') {
            $Username = $Matches[1].Trim('"', "'", ' ')
        }
    }
}

if (-not $plainPassword) {
    Write-Host "No .env file found (or no AUTOLOGIN_PASSWORD key)." -ForegroundColor Yellow
    Write-Host "Tip: Create $envFile with: AUTOLOGIN_PASSWORD=YourPassword" -ForegroundColor Yellow
    Write-Host ""
    $securePassword = Read-Host -Prompt "Enter Windows password for '$Username'" -AsSecureString
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )
}

# --- Apply registry settings ---
try {
    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1" -Force
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $Username -Force
    Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $plainPassword -Force
    Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $Domain -Force

    Write-Host ""
    Write-Host "Auto-login configured for '$Username'" -ForegroundColor Green
    Write-Host ""
    Write-Host "At next reboot:"
    Write-Host "  1. Windows will auto-login as $Username"
    Write-Host "  2. Docker Desktop will start (via HKCU\Run)"
    Write-Host "  3. All containers with restart=always will start"
    Write-Host ""
    Write-Host "To DISABLE:" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File $($MyInvocation.MyCommand.Path) -Disable"
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    $plainPassword = $null
    [GC]::Collect()
}

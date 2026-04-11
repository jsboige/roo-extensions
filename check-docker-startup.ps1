# Docker Auto-Boot Check and Fix Script
# Issue #1171 - Docker doit démarrer au boot sans session utilisateur

Write-Host "=== Docker Auto-Boot Diagnostic ===" -ForegroundColor Cyan

# 1. Check if Docker Desktop is installed
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (-not (Test-Path $dockerPath)) {
    Write-Host "ERROR: Docker Desktop not found at $dockerPath" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Docker Desktop installed" -ForegroundColor Green

# 2. Check startup registry keys
Write-Host "`n=== Checking Startup Registry Keys ===" -ForegroundColor Cyan

$runKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$dockerRun = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "*" -ErrorAction SilentlyContinue | Where-Object { $_ -like "*Docker*" }

if ($dockerRun) {
    Write-Host "✓ Docker found in HKLM Run key:" -ForegroundColor Green
    Write-Host "  $dockerRun"
} else {
    Write-Host "✗ Docker NOT in HKLM Run key" -ForegroundColor Yellow
}

$runOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$dockerRunOnce = Get-ItemProperty -Path $runOnceKey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "*" -ErrorAction SilentlyContinue | Where-Object { $_ -like "*Docker*" }

if ($dockerRunOnce) {
    Write-Host "✓ Docker found in HKLM RunOnce key:" -ForegroundColor Green
    Write-Host "  $dockerRunOnce"
} else {
    Write-Host "✗ Docker NOT in HKLM RunOnce key" -ForegroundColor Yellow
}

# 3. Check Docker startup settings in settings.json
Write-Host "`n=== Checking Docker Settings ===" -ForegroundColor Cyan

$settingsPath = "$env:APPDATA\Docker\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

    $autoStart = $settings.psobject.Properties.Match('autoStart') | ForEach-Object { $_.Value }
    if ($autoStart -eq $true) {
        Write-Host "✓ Docker auto-start is ENABLED in settings.json" -ForegroundColor Green
    } else {
        Write-Host "✗ Docker auto-start is DISABLED in settings.json" -ForegroundColor Yellow
    }

    # Check for backgroundService
    $backgroundService = $settings.psobject.Properties.Match('backgroundService') | ForEach-Object { $_.Value }
    if ($backgroundService -eq $true) {
        Write-Host "✓ Docker background service is ENABLED" -ForegroundColor Green
    } else {
        Write-Host "✗ Docker background service is DISABLED" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ Docker settings.json not found at $settingsPath" -ForegroundColor Yellow
}

# 4. Check if Docker service is running
Write-Host "`n=== Checking Docker Service Status ===" -ForegroundColor Cyan

try {
    $dockerService = Get-Service -Name "com.docker.*" -ErrorAction SilentlyContinue
    if ($dockerService) {
        foreach ($svc in $dockerService) {
            Write-Host "  $($svc.Name): $($svc.Status) (StartType: $($svc.StartType))" -ForegroundColor $(if ($svc.Status -eq "Running") { "Green" } else { "Yellow" })
        }
    } else {
        Write-Host "✗ No Docker service found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Error checking Docker service: $_" -ForegroundColor Red
}

# 5. Check scheduled task for Docker startup
Write-Host "`n=== Checking Scheduled Tasks ===" -ForegroundColor Cyan

$dockerTasks = Get-ScheduledTask -TaskName "*Docker*" -ErrorAction SilentlyContinue
if ($dockerTasks) {
    foreach ($task in $dockerTasks) {
        Write-Host "  $($task.TaskName): $($task.State)" -ForegroundColor Green
    }
} else {
    Write-Host "✗ No Docker scheduled task found" -ForegroundColor Yellow
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "For Docker to auto-start at boot, one of these must be configured:" -ForegroundColor White
Write-Host "  1. Registry key in HKLM\...\Run or RunOnce" -ForegroundColor White
Write-Host "  2. Scheduled task triggered at boot" -ForegroundColor White
Write-Host "  3. Docker service with StartType = Automatic" -ForegroundColor White

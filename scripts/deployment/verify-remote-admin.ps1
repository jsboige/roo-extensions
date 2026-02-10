Write-Host '=== Verification Configuration Remote Admin ===' -ForegroundColor Cyan
Write-Host ''

# Test WinRM
Write-Host '[1] Test WinRM...' -ForegroundColor Yellow
try {
    Test-WSMan -ComputerName localhost | Out-Null
    Write-Host '  [OK] WinRM fonctionne' -ForegroundColor Green
} catch {
    Write-Host '  [FAIL] WinRM non fonctionnel' -ForegroundColor Red
}

# Test ping
Write-Host '[2] Test Ping...' -ForegroundColor Yellow
try {
    $ping = Test-Connection -ComputerName localhost -Count 1 -Quiet
    if ($ping) {
        Write-Host '  [OK] Ping fonctionne' -ForegroundColor Green
    } else {
        Write-Host '  [FAIL] Ping echoue' -ForegroundColor Red
    }
} catch {
    Write-Host '  [FAIL] Ping non fonctionnel' -ForegroundColor Red
}

# Verifier services
Write-Host '[3] Services...' -ForegroundColor Yellow
$winrm = Get-Service WinRM
Write-Host "  WinRM: $($winrm.Status) ($($winrm.StartType))" -ForegroundColor White
$remotereg = Get-Service RemoteRegistry
Write-Host "  RemoteRegistry: $($remotereg.Status) ($($remotereg.StartType))" -ForegroundColor White

# Verifier UAC
Write-Host '[4] UAC LocalAccountTokenFilterPolicy...' -ForegroundColor Yellow
$uac = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'LocalAccountTokenFilterPolicy' -ErrorAction SilentlyContinue
if ($uac.LocalAccountTokenFilterPolicy -eq 1) {
    Write-Host '  [OK] UAC remote active (value=1)' -ForegroundColor Green
} else {
    Write-Host '  [FAIL] UAC remote non active' -ForegroundColor Red
}

# Verifier regles firewall
Write-Host '[5] Regles Firewall...' -ForegroundColor Yellow
$rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like '*LAN*' -and $_.Enabled -eq $true }
Write-Host "  Regles LAN actives: $($rules.Count)" -ForegroundColor White
foreach ($rule in $rules) {
    Write-Host "    - $($rule.DisplayName)" -ForegroundColor Gray
}

Write-Host ''
Write-Host 'Verification terminee.' -ForegroundColor Cyan

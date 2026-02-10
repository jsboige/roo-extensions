<#
.SYNOPSIS
    Configure l'administration distante pour les machines RooSync (WinRM + SMB + UAC)

.DESCRIPTION
    Active WinRM, SMB, ICMP (ping) et configure UAC pour permettre l'administration
    distante depuis les autres machines du réseau local. Restreint au réseau local uniquement.

.NOTES
    REQUIS: Doit être exécuté en tant qu'ADMINISTRATEUR
    Machine: myia-po-2026
    Auteur: RooSync Multi-Agent
    Date: 2026-02-10
    Issue: msg-20260210T084813-lwgg5f

.EXAMPLE
    # Exécuter en tant qu'administrateur
    .\configure-remote-admin.ps1
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=== Configuration Administration Distante ===" -ForegroundColor Cyan
Write-Host "Machine: $env:COMPUTERNAME"
Write-Host ""

# 1. Autoriser l'admin distant (UAC remote)
Write-Host "[1/6] Configuration UAC Remote (LocalAccountTokenFilterPolicy)..." -ForegroundColor Yellow
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -Force
    Write-Host "  [OK] UAC remote activé" -ForegroundColor Green
} catch {
    Write-Host "  [ERREUR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Activer WinRM (PowerShell Remoting)
Write-Host "[2/6] Activation WinRM (PowerShell Remoting)..." -ForegroundColor Yellow
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
    Write-Host "  [OK] WinRM activé" -ForegroundColor Green
} catch {
    Write-Host "  [ERREUR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3. Ouvrir le ping (ICMP)
Write-Host "[3/6] Ouverture ICMP (ping) - réseau local uniquement..." -ForegroundColor Yellow
try {
    # Supprimer la règle si elle existe déjà
    Remove-NetFirewallRule -DisplayName "Allow ICMPv4 Ping (LAN)" -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName "Allow ICMPv4 Ping (LAN)" -Protocol ICMPv4 -IcmpType 8 `
        -Action Allow -Direction Inbound -RemoteAddress LocalSubnet -Enabled True | Out-Null
    Write-Host "  [OK] ICMP ping autorisé (LAN uniquement)" -ForegroundColor Green
} catch {
    Write-Host "  [ERREUR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 4. Ouvrir SMB (port 445) - réseau local uniquement
Write-Host "[4/6] Ouverture SMB (port 445) - réseau local uniquement..." -ForegroundColor Yellow
try {
    # Supprimer la règle si elle existe déjà
    Remove-NetFirewallRule -DisplayName "Allow SMB Inbound (LAN)" -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName "Allow SMB Inbound (LAN)" -Protocol TCP -LocalPort 445 `
        -Action Allow -Direction Inbound -RemoteAddress LocalSubnet -Enabled True | Out-Null
    Write-Host "  [OK] SMB ouvert (LAN uniquement)" -ForegroundColor Green
} catch {
    Write-Host "  [ERREUR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 5. Ouvrir WinRM (port 5985) - réseau local uniquement
Write-Host "[5/6] Ouverture WinRM HTTP (port 5985) - réseau local uniquement..." -ForegroundColor Yellow
try {
    # Supprimer la règle si elle existe déjà
    Remove-NetFirewallRule -DisplayName "Allow WinRM HTTP (LAN)" -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName "Allow WinRM HTTP (LAN)" -Protocol TCP -LocalPort 5985 `
        -Action Allow -Direction Inbound -RemoteAddress LocalSubnet -Enabled True | Out-Null
    Write-Host "  [OK] WinRM HTTP ouvert (LAN uniquement)" -ForegroundColor Green
} catch {
    Write-Host "  [ERREUR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 6. Démarrer les services
Write-Host "[6/6] Démarrage des services WinRM + RemoteRegistry..." -ForegroundColor Yellow
try {
    Set-Service -Name WinRM -StartupType Automatic
    Start-Service WinRM
    Write-Host "  [OK] WinRM service démarré (Automatic)" -ForegroundColor Green

    Set-Service -Name RemoteRegistry -StartupType Automatic
    Start-Service RemoteRegistry
    Write-Host "  [OK] RemoteRegistry service démarré (Automatic)" -ForegroundColor Green
} catch {
    Write-Host "  [ERREUR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Vérification
Write-Host ""
Write-Host "=== Vérification ===" -ForegroundColor Cyan

Write-Host "[Test 1] WinRM localhost..." -ForegroundColor Yellow
try {
    Test-WSMan -ComputerName localhost | Out-Null
    Write-Host "  [OK] WinRM fonctionne" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Test WinRM échoué: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "[Test 2] Ping localhost..." -ForegroundColor Yellow
try {
    $ping = Test-Connection -ComputerName localhost -Count 1 -Quiet
    if ($ping) {
        Write-Host "  [OK] Ping fonctionne" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Ping échoué" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [WARN] Test ping échoué: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Configuration Terminée ===" -ForegroundColor Green
Write-Host ""
Write-Host "Règles firewall créées (LocalSubnet uniquement):" -ForegroundColor White
Write-Host "  - ICMP ping (protocole ICMPv4)" -ForegroundColor Gray
Write-Host "  - SMB (port 445 TCP)" -ForegroundColor Gray
Write-Host "  - WinRM HTTP (port 5985 TCP)" -ForegroundColor Gray
Write-Host ""
Write-Host "La machine peut maintenant être administrée à distance depuis le réseau local." -ForegroundColor White
Write-Host ""

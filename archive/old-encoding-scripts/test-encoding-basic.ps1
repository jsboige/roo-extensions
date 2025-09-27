# Script de diagnostic encodage ultra-simple
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "   TEST ENCODAGE UTF-8 BASIQUE" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# 1. TEST POWERSHELL
Write-Host "1. TEST POWERSHELL" -ForegroundColor Yellow
Write-Host "------------------" -ForegroundColor Gray

# Test Output Encoding
$outputCP = [Console]::OutputEncoding.CodePage
Write-Host "Console OutputEncoding CodePage: $outputCP"

if ($outputCP -eq 65001) {
    Write-Host "[OK] OutputEncoding = UTF-8 (65001)" -ForegroundColor Green
} else {
    Write-Host "[ERREUR] OutputEncoding = $outputCP (pas UTF-8)" -ForegroundColor Red
    Write-Host "  Pour corriger: [Console]::OutputEncoding = [System.Text.Encoding]::UTF8" -ForegroundColor Yellow
}

# Test Input Encoding
$inputCP = [Console]::InputEncoding.CodePage
Write-Host "Console InputEncoding CodePage: $inputCP"

if ($inputCP -eq 65001) {
    Write-Host "[OK] InputEncoding = UTF-8 (65001)" -ForegroundColor Green
} else {
    Write-Host "[ERREUR] InputEncoding = $inputCP (pas UTF-8)" -ForegroundColor Red
    Write-Host "  Pour corriger: [Console]::InputEncoding = [System.Text.Encoding]::UTF8" -ForegroundColor Yellow
}

Write-Host ""

# 2. TEST SYSTEME
Write-Host "2. TEST SYSTEME WINDOWS" -ForegroundColor Yellow
Write-Host "-----------------------" -ForegroundColor Gray

# Test page de code
$chcpResult = cmd /c chcp 2>&1
Write-Host "Page de code actuelle: $chcpResult"

if ($chcpResult -match "65001") {
    Write-Host "[OK] Page de code = UTF-8" -ForegroundColor Green
} else {
    Write-Host "[ERREUR] Page de code non UTF-8" -ForegroundColor Red
    Write-Host "  Pour corriger: chcp 65001" -ForegroundColor Yellow
}

Write-Host ""

# 3. VARIABLES ENVIRONNEMENT  
Write-Host "3. VARIABLES ENVIRONNEMENT" -ForegroundColor Yellow
Write-Host "--------------------------" -ForegroundColor Gray

$pythonIoEncoding = [Environment]::GetEnvironmentVariable("PYTHONIOENCODING")
if ($pythonIoEncoding) {
    Write-Host "PYTHONIOENCODING = $pythonIoEncoding" -ForegroundColor Green
} else {
    Write-Host "PYTHONIOENCODING = [NON DEFINI]" -ForegroundColor Red
    Write-Host '  Pour corriger: [Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")' -ForegroundColor Yellow
}

$pythonUtf8 = [Environment]::GetEnvironmentVariable("PYTHONUTF8")
if ($pythonUtf8) {
    Write-Host "PYTHONUTF8 = $pythonUtf8" -ForegroundColor Green
} else {
    Write-Host "PYTHONUTF8 = [NON DEFINI]" -ForegroundColor Red
    Write-Host '  Pour corriger: [Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")' -ForegroundColor Yellow
}

Write-Host ""

# 4. TEST AFFICHAGE
Write-Host "4. TEST AFFICHAGE CARACTERES" -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Gray
Write-Host ""

Write-Host "Test accents: e a u o i c E A" -ForegroundColor Cyan
Write-Host "Test symboles: +- x / != inf sqrt" -ForegroundColor Cyan
Write-Host "Test fleches: <- -> ^ v" -ForegroundColor Cyan
Write-Host "Test box: +--+|+--+" -ForegroundColor Cyan
Write-Host ""
Write-Host "Si les caracteres ci-dessus ne s'affichent pas correctement," -ForegroundColor Yellow
Write-Host "votre terminal a un probleme d'encodage." -ForegroundColor Yellow

Write-Host ""

# 5. RESUME ET CORRECTION AUTOMATIQUE
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "              RESUME" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

$hasIssues = $false

if ($outputCP -ne 65001 -or $inputCP -ne 65001) {
    $hasIssues = $true
}

if (-not $pythonIoEncoding -or -not $pythonUtf8) {
    $hasIssues = $true
}

if ($hasIssues) {
    Write-Host ""
    Write-Host "[PROBLEMES DETECTES]" -ForegroundColor Red
    Write-Host "Des problemes d'encodage ont ete detectes." -ForegroundColor Red
    Write-Host ""
    Write-Host "Voulez-vous appliquer les corrections automatiquement? (O/N): " -ForegroundColor Yellow -NoNewline
    
    $response = Read-Host
    
    if ($response -eq 'O' -or $response -eq 'o') {
        Write-Host ""
        Write-Host "Application des corrections..." -ForegroundColor Cyan
        
        # Correction PowerShell
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding = [System.Text.Encoding]::UTF8
        chcp 65001 | Out-Null
        Write-Host "[OK] Encodage PowerShell configure" -ForegroundColor Green
        
        # Variables environnement
        [Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")
        [Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
        Write-Host "[OK] Variables environnement configurees" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Corrections appliquees avec succes!" -ForegroundColor Green
        Write-Host "IMPORTANT: Redemarrez PowerShell pour appliquer tous les changements." -ForegroundColor Yellow
    } else {
        Write-Host "Corrections annulees." -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "[SUCCES] Aucun probleme detecte!" -ForegroundColor Green
    Write-Host "Votre configuration d'encodage est correcte." -ForegroundColor Green
}

Write-Host ""
Write-Host "Fin du diagnostic" -ForegroundColor Cyan
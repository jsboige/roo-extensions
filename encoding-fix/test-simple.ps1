# Script de test simple pour validation UTF-8
Write-Host "=== Test UTF-8 Simple ===" -ForegroundColor Green

# Changer vers le repertoire du script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir
Write-Host "Repertoire: $(Get-Location)"

# Forcer UTF-8
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "Page de code: $([Console]::OutputEncoding.CodePage)"

# Test caracteres francais
Write-Host "Test caracteres francais:"
Write-Host "cafe hotel naif coincidence"
Write-Host "aeiouc AEIOUC"

# Verifier fichiers de configuration
Write-Host "Verification configuration:"

$workspaceSettings = ".\.vscode\settings.json"
if (Test-Path $workspaceSettings) {
    Write-Host "OK: Fichier workspace settings.json trouve"
    $content = Get-Content $workspaceSettings -Raw
    if ($content -match '"files\.encoding":\s*"utf8"') {
        Write-Host "OK: Configuration UTF-8 presente"
    } else {
        Write-Host "ERREUR: Configuration UTF-8 manquante"
    }
} else {
    Write-Host "ERREUR: Fichier workspace settings.json non trouve"
}

$userSettings = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $userSettings) {
    Write-Host "OK: Fichier utilisateur settings.json trouve"
} else {
    Write-Host "ERREUR: Fichier utilisateur settings.json non trouve"
}

# Test creation fichier
Write-Host "Test creation fichier:"
$testContent = "Test UTF-8 - $(Get-Date)"
$testFile = "test-simple.txt"

try {
    $testContent | Out-File -FilePath $testFile -Encoding UTF8 -Force
    Write-Host "OK: Fichier cree avec succes"
    $readContent = Get-Content $testFile -Encoding UTF8
    Write-Host "Contenu: $readContent"
} catch {
    Write-Host "ERREUR: $($_.Exception.Message)"
}

Write-Host "=== Fin du test ==="
Write-Host "Instructions pour VSCode:"
Write-Host "1. Ouvrir ce dossier: code ."
Write-Host "2. Ouvrir terminal integre (Ctrl+`)"
Write-Host "3. Verifier PowerShell avec UTF-8"
Write-Host "4. Taper: echo 'test accents'"
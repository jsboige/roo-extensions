# Script de test affichage Unicode
param([switch]$Fix)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "    TEST AFFICHAGE UNICODE AVANCE" -ForegroundColor Cyan  
Write-Host "========================================`n" -ForegroundColor Cyan

# Force UTF-8 pour ce script
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Test 1: Caractères accentués via codes Unicode
Write-Host "TEST 1: Caractères accentués (codes Unicode)" -ForegroundColor Yellow
Write-Host "----------------------------------------------" -ForegroundColor Gray

$accentChars = @{
    "e aigu" = [char]0x00E9       # é
    "e grave" = [char]0x00E8      # è
    "a grave" = [char]0x00E0      # à
    "u grave" = [char]0x00F9      # ù
    "o circonflexe" = [char]0x00F4 # ô
    "c cedille" = [char]0x00E7    # ç
}

foreach ($char in $accentChars.GetEnumerator()) {
    Write-Host "$($char.Key): " -NoNewline
    Write-Host $char.Value -ForegroundColor Green -NoNewline
    Write-Host " (U+$('{0:X4}' -f [int]$char.Value))" -ForegroundColor DarkGray
}

Write-Host ""

# Test 2: Emojis via codes Unicode
Write-Host "TEST 2: Emojis Roo (codes Unicode)" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Gray

# Utilisons les codes UTF-32 pour les emojis
$emojis = @{
    "Ordinateur" = [System.Char]::ConvertFromUtf32(0x1F4BB)  # 💻
    "Construction" = [System.Char]::ConvertFromUtf32(0x1F3D7) # 🏗️
    "Question" = [System.Char]::ConvertFromUtf32(0x2753)     # ❓
    "Bug" = [System.Char]::ConvertFromUtf32(0x1FAB2)         # 🪲
    "Boomerang" = [System.Char]::ConvertFromUtf32(0x1FA83)   # 🪃
}

foreach ($emoji in $emojis.GetEnumerator()) {
    Write-Host "$($emoji.Key): " -NoNewline
    Write-Host $emoji.Value -ForegroundColor Yellow
}

Write-Host ""

# Test 3: Box drawing
Write-Host "TEST 3: Box Drawing (codes Unicode)" -ForegroundColor Yellow
Write-Host "------------------------------------" -ForegroundColor Gray

$box = @(
    [char]0x250C + [char]0x2500 + [char]0x2500 + [char]0x2510,  # ┌──┐
    [char]0x2502 + "  " + [char]0x2502,                          # │  │
    [char]0x2514 + [char]0x2500 + [char]0x2500 + [char]0x2518   # └──┘
)

foreach ($line in $box) {
    Write-Host $line -ForegroundColor Magenta
}

Write-Host ""

# Test 4: Symboles mathématiques
Write-Host "TEST 4: Symboles mathématiques" -ForegroundColor Yellow
Write-Host "-------------------------------" -ForegroundColor Gray

$mathSymbols = @{
    "Infini" = [char]0x221E        # ∞
    "Plus ou moins" = [char]0x00B1 # ±
    "Racine" = [char]0x221A        # √
    "Different" = [char]0x2260     # ≠
    "Somme" = [char]0x2211         # ∑
}

foreach ($symbol in $mathSymbols.GetEnumerator()) {
    Write-Host "$($symbol.Key): " -NoNewline
    Write-Host $symbol.Value -ForegroundColor Cyan
}

Write-Host ""

# Test 5: Test direct avec strings UTF-8
Write-Host "TEST 5: Strings UTF-8 directes" -ForegroundColor Yellow
Write-Host "-------------------------------" -ForegroundColor Gray

# Créons les strings via bytes UTF-8
$utf8 = [System.Text.Encoding]::UTF8

# "Français"
$bytes1 = [byte[]]@(0x46,0x72,0x61,0x6E,0xC3,0xA7,0x61,0x69,0x73)
$french = $utf8.GetString($bytes1)
Write-Host "Français: $french" -ForegroundColor Green

# "Español"  
$bytes2 = [byte[]]@(0x45,0x73,0x70,0x61,0xC3,0xB1,0x6F,0x6C)
$spanish = $utf8.GetString($bytes2)
Write-Host "Español: $spanish" -ForegroundColor Green

# "Português"
$bytes3 = [byte[]]@(0x50,0x6F,0x72,0x74,0x75,0x67,0x75,0xC3,0xAA,0x73)
$portuguese = $utf8.GetString($bytes3)
Write-Host "Português: $portuguese" -ForegroundColor Green

Write-Host ""

# Test 6: Diagnostic terminal
Write-Host "TEST 6: Diagnostic Terminal" -ForegroundColor Yellow
Write-Host "---------------------------" -ForegroundColor Gray

Write-Host "OutputEncoding: $([Console]::OutputEncoding.EncodingName)" -ForegroundColor Cyan
Write-Host "InputEncoding: $([Console]::InputEncoding.EncodingName)" -ForegroundColor Cyan
Write-Host "Culture: $([System.Globalization.CultureInfo]::CurrentCulture.Name)" -ForegroundColor Cyan

# Test police terminal
$font = ""
try {
    $key = "HKCU:\Console"
    $fontName = (Get-ItemProperty -Path $key -Name "FaceName" -ErrorAction SilentlyContinue).FaceName
    if ($fontName) {
        $font = $fontName
    }
} catch {}

if ($font) {
    Write-Host "Police console: $font" -ForegroundColor Cyan
}

Write-Host ""

# Résumé
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "              RESULTAT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nSi vous voyez:" -ForegroundColor Yellow
Write-Host "- Les lettres accentuées correctement" -ForegroundColor White
Write-Host "- Les emojis ou leurs symboles" -ForegroundColor White
Write-Host "- Les box drawings formant une boîte" -ForegroundColor White
Write-Host "- Les symboles mathématiques" -ForegroundColor White
Write-Host "`nAlors votre terminal supporte UTF-8!" -ForegroundColor Green

Write-Host "`nSinon, votre terminal a des limitations d'affichage." -ForegroundColor Red

if ($Fix) {
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "     APPLICATION DES CORRECTIONS" -ForegroundColor Yellow
    Write-Host "========================================`n" -ForegroundColor Yellow
    
    # Forcer tous les encodages
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
    
    # Variables d'environnement
    [Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")
    [Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
    [Environment]::SetEnvironmentVariable("LANG", "en_US.UTF-8", "User")
    
    Write-Host "[OK] Encodages forcés en UTF-8" -ForegroundColor Green
    Write-Host "[OK] Variables d'environnement configurées" -ForegroundColor Green
    Write-Host "`nRedémarrez PowerShell et testez à nouveau." -ForegroundColor Yellow
} else {
    Write-Host "`nPour forcer les corrections: .\test-unicode-display.ps1 -Fix" -ForegroundColor Cyan
}

Write-Host ""
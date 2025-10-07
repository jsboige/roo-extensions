# Script d'investigation Phase 4 : Vérification structure webview-ui
# Date: 2025-10-07
# Objectif: Comparer structure source vs extension déployée

Write-Host "`n=== INVESTIGATION STRUCTURE WEBVIEW-UI ===" -ForegroundColor Magenta
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# ============================================
# PARTIE 1: SOURCE (c:/dev/roo-code)
# ============================================
Write-Host "`n=== SOURCE (c:/dev/roo-code) ===" -ForegroundColor Cyan

Write-Host "`n[1] Checking webview-ui/build:" -ForegroundColor Yellow
$sourceWebviewBuild = Test-Path 'c:/dev/roo-code/webview-ui/build'
Write-Host "  Exists: $sourceWebviewBuild"
if ($sourceWebviewBuild) { 
    $files = Get-ChildItem 'c:/dev/roo-code/webview-ui/build' -Recurse -File | Select-Object -First 10
    Write-Host "  Files found: $($files.Count)"
    $files | Select-Object @{N='Path';E={$_.FullName.Replace('c:/dev/roo-code/','')}}, @{N='Size';E={'{0:N0} bytes' -f $_.Length}} | Format-Table -AutoSize
}

Write-Host "`n[2] Checking src/webview-ui/build:" -ForegroundColor Yellow
$sourceSrcWebviewBuild = Test-Path 'c:/dev/roo-code/src/webview-ui/build'
Write-Host "  Exists: $sourceSrcWebviewBuild"
if ($sourceSrcWebviewBuild) {
    $files = Get-ChildItem 'c:/dev/roo-code/src/webview-ui/build' -Recurse -File | Select-Object -First 10
    Write-Host "  Files found: $($files.Count)"
    $files | Select-Object @{N='Path';E={$_.FullName.Replace('c:/dev/roo-code/','')}}, @{N='Size';E={'{0:N0} bytes' -f $_.Length}} | Format-Table -AutoSize
}

Write-Host "`n[3] Checking src/webview-ui/build/assets/index.map.json:" -ForegroundColor Yellow
$sourceIndexMapJson = Test-Path 'c:/dev/roo-code/src/webview-ui/build/assets/index.map.json'
Write-Host "  Exists: $sourceIndexMapJson"

Write-Host "`n[4] Checking src/webview-ui/build/assets/index.js:" -ForegroundColor Yellow
$sourceIndexJs = Test-Path 'c:/dev/roo-code/src/webview-ui/build/assets/index.js'
Write-Host "  Exists: $sourceIndexJs"

Write-Host "`n[5] Checking src/webview-ui/build/assets/index.css:" -ForegroundColor Yellow
$sourceIndexCss = Test-Path 'c:/dev/roo-code/src/webview-ui/build/assets/index.css'
Write-Host "  Exists: $sourceIndexCss"

# ============================================
# PARTIE 2: EXTENSION DEPLOYEE
# ============================================
Write-Host "`n`n=== EXTENSION DEPLOYEE ===" -ForegroundColor Cyan
$extPath = "$env:USERPROFILE\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.15"

Write-Host "`n[1] Checking webview-ui/build:" -ForegroundColor Yellow
$extWebviewBuild = Test-Path "$extPath\webview-ui\build"
Write-Host "  Exists: $extWebviewBuild"
if ($extWebviewBuild) {
    $files = Get-ChildItem "$extPath\webview-ui\build" -Recurse -File | Select-Object -First 10
    Write-Host "  Files found: $($files.Count)"
    $files | Select-Object @{N='Path';E={$_.FullName.Replace($extPath + '\','')}}, @{N='Size';E={'{0:N0} bytes' -f $_.Length}} | Format-Table -AutoSize
}

Write-Host "`n[2] Checking src/webview-ui/build:" -ForegroundColor Yellow
$extSrcWebviewBuild = Test-Path "$extPath\src\webview-ui\build"
Write-Host "  Exists: $extSrcWebviewBuild"
if ($extSrcWebviewBuild) {
    $files = Get-ChildItem "$extPath\src\webview-ui\build" -Recurse -File | Select-Object -First 10
    Write-Host "  Files found: $($files.Count)"
    $files | Select-Object @{N='Path';E={$_.FullName.Replace($extPath + '\','')}}, @{N='Size';E={'{0:N0} bytes' -f $_.Length}} | Format-Table -AutoSize
}

Write-Host "`n[3] Checking webview-ui/build/assets/index.map.json:" -ForegroundColor Yellow
$extIndexMapJson = Test-Path "$extPath\webview-ui\build\assets\index.map.json"
Write-Host "  Exists: $extIndexMapJson"

Write-Host "`n[4] Checking webview-ui/build/assets/index.js:" -ForegroundColor Yellow
$extIndexJs = Test-Path "$extPath\webview-ui\build\assets\index.js"
Write-Host "  Exists: $extIndexJs"

Write-Host "`n[5] Checking webview-ui/build/assets/index.css:" -ForegroundColor Yellow
$extIndexCss = Test-Path "$extPath\webview-ui\build\assets\index.css"
Write-Host "  Exists: $extIndexCss"

# ============================================
# PARTIE 3: SYNTHESE
# ============================================
Write-Host "`n`n=== SYNTHESE ===" -ForegroundColor Magenta

Write-Host "`nSOURCE:"
Write-Host "  - webview-ui/build exists: $sourceWebviewBuild" -ForegroundColor $(if ($sourceWebviewBuild) { 'Green' } else { 'Red' })
Write-Host "  - src/webview-ui/build exists: $sourceSrcWebviewBuild" -ForegroundColor $(if ($sourceSrcWebviewBuild) { 'Green' } else { 'Red' })
Write-Host "  - src/webview-ui/build/assets/index.map.json exists: $sourceIndexMapJson" -ForegroundColor $(if ($sourceIndexMapJson) { 'Green' } else { 'Red' })

Write-Host "`nEXTENSION:"
Write-Host "  - webview-ui/build exists: $extWebviewBuild" -ForegroundColor $(if ($extWebviewBuild) { 'Green' } else { 'Red' })
Write-Host "  - src/webview-ui/build exists: $extSrcWebviewBuild" -ForegroundColor $(if ($extSrcWebviewBuild) { 'Green' } else { 'Red' })
Write-Host "  - webview-ui/build/assets/index.map.json exists: $extIndexMapJson" -ForegroundColor $(if ($extIndexMapJson) { 'Green' } else { 'Red' })

Write-Host "`n=== FIN INVESTIGATION ===" -ForegroundColor Magenta
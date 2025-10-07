$srcFile = "C:\dev\roo-code\src\webview-ui\build\assets\index.js"
$extFile = "C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.15\webview-ui\build\assets\index.js"

$srcDate = (Get-Item $srcFile).LastWriteTime
$extDate = (Get-Item $extFile).LastWriteTime

Write-Host "Source: $srcDate"
Write-Host "Extension: $extDate"

$diff = ($extDate - $srcDate).TotalSeconds
Write-Host "Difference: $diff secondes"

if ([Math]::Abs($diff) -lt 60) {
    Write-Host "[OK] Fichiers synchronises" -ForegroundColor Green
} else {
    Write-Host "[ATTENTION] Difference de $diff secondes" -ForegroundColor Yellow
}
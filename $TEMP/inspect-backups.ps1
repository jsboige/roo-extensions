$files = Get-ChildItem 'C:\Users\jsboi\.claude\settings.json.backup-*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5
foreach ($f in $files) {
    Write-Host "=== $($f.Name) ==="
    Select-String -Path $f.FullName -Pattern 'CLAUDE_CODE_AUTO_COMPACT_WINDOW|ANTHROPIC_DEFAULT_OPUS_MODEL|ANTHROPIC_DEFAULT_SONNET_MODEL' | ForEach-Object { Write-Host $_.Line }
    Write-Host ""
}
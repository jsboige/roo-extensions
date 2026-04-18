Get-ChildItem 'C:\dev\roo-extensions\.claude\worktrees' -Directory | Where-Object { $_.Name -match 'wt-worker|wt-1360' } | ForEach-Object {
    Write-Host ("Removing {0}..." -f $_.Name)
    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ("  Done: {0}" -f $_.Name)
}
Write-Host '=== Remaining ==='
Get-ChildItem 'C:\dev\roo-extensions\.claude\worktrees' -Directory | ForEach-Object { Write-Host $_.Name }

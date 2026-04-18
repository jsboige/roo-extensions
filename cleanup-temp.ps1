# Cleanup TEMP files older than 7 days
$cutoff = (Get-Date).AddDays(-7)
$files = Get-ChildItem $env:TEMP -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff }
$total = ($files | Measure-Object Length -Sum).Sum / 1MB
Write-Host ("TEMP files >7j: {0:N0} MB ({1} files)" -f $total, $files.Count)
$files | Remove-Item -Force -ErrorAction SilentlyContinue
Write-Host "TEMP cleanup done"

# Cleanup SoftwareDistribution\Download
Write-Host ""
Write-Host "=== SoftwareDistribution ==="
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
$suFiles = Get-ChildItem "C:\Windows\SoftwareDistribution\Download" -File -Recurse -ErrorAction SilentlyContinue
$suSize = ($suFiles | Measure-Object Length -Sum).Sum / 1MB
Write-Host ("SoftwareDistribution: {0:N0} MB ({1} files)" -f $suSize, $suFiles.Count)
Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Write-Host "SoftwareDistribution cleanup done"

Write-Host ""
Write-Host "=== Final disk state ==="
$drive = Get-PSDrive C
$free = [math]::Round($drive.Free / 1GB, 1)
$pct = [math]::Round($drive.Free / ($drive.Used + $drive.Free) * 100, 1)
Write-Host ("Free: {0} GB ({1}%)" -f $free, $pct)

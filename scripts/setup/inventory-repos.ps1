# inventory-repos.ps1 - Inventory Git repos on this machine
# For issue #526 - RooSync cross-workspace expansion

$repos = @()
foreach ($drive in @('D:\', 'E:\')) {
    if (Test-Path $drive) {
        Get-ChildItem -Path $drive -Filter '.git' -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue -Force | ForEach-Object {
            $repoPath = $_.Parent.FullName
            $hasRoomodes = Test-Path (Join-Path $repoPath '.roomodes')
            $hasRooDir = Test-Path (Join-Path $repoPath '.roo')
            $hasClaude = Test-Path (Join-Path $repoPath '.claude')
            $repos += [PSCustomObject]@{
                Path = $repoPath
                Roo = if ($hasRoomodes -or $hasRooDir) { 'YES' } else { 'NO' }
                Claude = if ($hasClaude) { 'YES' } else { 'NO' }
            }
        }
    }
}
$repos | Sort-Object Path | Format-Table -AutoSize
Write-Host "Total: $($repos.Count) repos"
Write-Host "Roo-enabled: $(($repos | Where-Object Roo -eq 'YES').Count)"
Write-Host "Claude-enabled: $(($repos | Where-Object Claude -eq 'YES').Count)"

# Output as CSV for parsing
$repos | Sort-Object Path | Export-Csv -Path "$env:TEMP\repo-inventory.csv" -NoTypeInformation -Encoding UTF8
Write-Host "CSV saved to $env:TEMP\repo-inventory.csv"

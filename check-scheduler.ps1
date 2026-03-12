$schedulerPath = Join-Path $env:APPDATA 'Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\schedules.json'
if (Test-Path $schedulerPath) {
    Get-Content $schedulerPath | ConvertFrom-Json | ConvertTo-Json -Depth 5
} else {
    Write-Output "schedules.json not found at: $schedulerPath"
}

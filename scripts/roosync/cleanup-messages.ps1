# RooSync Message Cleanup Script
# Part of SHORT-TERM solution for issue #613

param(
    [string]$RooSyncPath = "$env:USERPROFILE\Drive\.shortcut-targets-by-id\1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB\.shared-state",
    [switch]$WhatIf,
    [switch]$AutoMarkLow,
    [switch]$IgnoreTestMachine,
    [int]$DaysOld = 0
)

$ErrorActionPreference = "Stop"

function Get-RooSyncMessages {
    param([string]$Path)

    $inboxPath = Join-Path $Path "messages\inbox"
    if (!(Test-Path $inboxPath)) {
        Write-Error "Inbox path not found: $inboxPath"
        return
    }

    Get-ChildItem $inboxPath -Filter "*.json" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw | ConvertFrom-Json
        [PSCustomObject]@{
            Id = $_.BaseName
            File = $_.FullName
            From = $content.from
            To = $content.to
            Subject = $content.subject
            Priority = $content.priority
            Status = $content.status
            Timestamp = [DateTime]::Parse($content.timestamp)
            AgeDays = ([DateTime]::Now - [DateTime]::Parse($content.timestamp)).Days
        }
    }
}

function Mark-MessageAsRead {
    param([string]$FilePath)

    if ($WhatIf) {
        Write-Host "  [WOULD MARK AS READ] $(Split-Path $FilePath -Leaf)"
        return
    }

    $content = Get-Content $FilePath -Raw | ConvertFrom-Json
    $content.status = "read"
    $content | ConvertTo-Json -Depth 10 | Set-Content $FilePath
}

# Main
Write-Host "RooSync Message Cleanup Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

$messages = Get-RooSyncMessages -Path $RooSyncPath

if ($DaysOld -gt 0) {
    Write-Host "Filter: Messages older than $DaysOld days"
    $targetMessages = $messages | Where-Object { $_.AgeDays -gt $DaysOld -and $_.Status -eq "unread" }
    Write-Host "Found $($targetMessages.Count) unread messages older than $DaysOld days"
} elseif ($AutoMarkLow) {
    Write-Host "Filter: LOW priority messages"
    $targetMessages = $messages | Where-Object { $_.Priority -eq "LOW" -and $_.Status -eq "unread" }
    Write-Host "Found $($targetMessages.Count) unread LOW priority messages"
} elseif ($IgnoreTestMachine) {
    Write-Host "Filter: Messages from test-machine"
    $targetMessages = $messages | Where-Object { $_.From -like "*test-machine*" -and $_.Status -eq "unread" }
    Write-Host "Found $($targetMessages.Count) unread messages from test-machine"
} else {
    Write-Host "No filter specified. Use -DaysOld, -AutoMarkLow, or -IgnoreTestMachine"
    exit 0
}

Write-Host ""

if ($targetMessages.Count -eq 0) {
    Write-Host "No messages to process." -ForegroundColor Green
    exit 0
}

Write-Host "Messages to mark as read:" -ForegroundColor Yellow
$targetMessages | ForEach-Object {
    Write-Host "  [$($_.Priority)] $($_.Subject) ($($_.AgeDays) days old) from $($_.From)"
}

if (!$WhatIf) {
    $confirm = Read-Host "`nMark these messages as read? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Cancelled."
        exit 0
    }
}

Write-Host "`nProcessing..."
$targetMessages | ForEach-Object {
    Mark-MessageAsRead -FilePath $_.File
}

Write-Host "`nDone! Marked $($targetMessages.Count) messages as read." -ForegroundColor Green

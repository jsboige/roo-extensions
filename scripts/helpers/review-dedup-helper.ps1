#
# Review Deduplication Helper — Extract and deduplicate review points from PR
# Usage: .\review-dedup-helper.ps1 -RepoOwner jsboige -RepoName roo-extensions -PrNumber 2505
# Output: JSON array of deduplicated review points, sorted by recency
#

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RepoOwner,

    [Parameter(Mandatory = $true)]
    [string] $RepoName,

    [Parameter(Mandatory = $true)]
    [int] $PrNumber,

    [Parameter(Mandatory = $false)]
    [string] $OutputFile = $null
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ReviewData {
    param(
        [string] $Owner,
        [string] $Name,
        [int] $Number
    )

    Write-Host "[*] Fetching reviews and comments for PR #$Number..." -ForegroundColor Cyan

    try {
        $result = gh pr view $Number `
            --repo "$Owner/$Name" `
            --json reviews,comments `
            --jq '.' | ConvertFrom-Json

        return $result
    }
    catch {
        Write-Host "[ERROR] Failed to fetch PR data: $_" -ForegroundColor Red
        throw
    }
}

function Extract-ReviewPoints {
    param(
        [object] $ReviewData
    )

    $points = @()

    # Extract review comments
    if ($ReviewData.reviews) {
        foreach ($review in $ReviewData.reviews) {
            if ($review.body -and $review.body.Trim().Length -gt 0) {
                $points += @{
                    source   = "review"
                    author   = $review.author.login
                    state    = $review.state  # "APPROVED", "CHANGES_REQUESTED", "COMMENTED"
                    body     = $review.body
                    timestamp = $review.submittedAt
                    type     = "full_review"
                }
            }
        }
    }

    # Extract inline comments
    if ($ReviewData.comments) {
        foreach ($comment in $ReviewData.comments) {
            if ($comment.body -and $comment.body.Trim().Length -gt 0) {
                $commentObj = @{
                    source   = "comment"
                    author   = $comment.author.login
                    state    = "COMMENTED"
                    body     = $comment.body
                    timestamp = $comment.createdAt
                    type     = "inline_comment"
                }
                
                # Add optional properties only if they exist
                if ($comment.line) { $commentObj.line = $comment.line }
                if ($comment.path) { $commentObj.path = $comment.path }
                
                $points += $commentObj
            }
        }
    }

    return $points
}

function Deduplicate-Points {
    param(
        [object[]] $Points
    )

    Write-Host "[*] Deduplicating review points..." -ForegroundColor Cyan

    $dedupMap = @{}
    $dedupedPoints = @()

    foreach ($point in $Points) {
        # Normalize body: lowercase, trim whitespace, remove punctuation for comparison
        $normalizedBody = $point.body.ToLower().Trim() -replace '[.,!?;]', ''
        $key = $normalizedBody.Substring(0, [Math]::Min(100, $normalizedBody.Length))

        # If this key doesn't exist or this point is newer, keep it
        if (-not $dedupMap.ContainsKey($key)) {
            $dedupMap[$key] = $point
            $dedupedPoints += $point
        }
        else {
            # Check if current point is newer
            if ([DateTime]$point.timestamp -gt [DateTime]$dedupMap[$key].timestamp) {
                # Replace with newer version
                $dedupedPoints = $dedupedPoints | Where-Object { 
                    $_.timestamp -ne $dedupMap[$key].timestamp 
                }
                $dedupMap[$key] = $point
                $dedupedPoints += $point
            }
        }
    }

    return $dedupedPoints | Sort-Object -Property timestamp -Descending
}

function Generate-Report {
    param(
        [object[]] $Points
    )

    Write-Host "[*] Generating report..." -ForegroundColor Cyan

    $report = @{
        summary = @{
            total_points = $Points.Count
            unique_points = ($Points | Sort-Object -Property body -Unique).Count
            review_states = @(
                $Points | Group-Object -Property state | ForEach-Object {
                    @{ state = $_.Name; count = $_.Count }
                }
            )
            comment_types = @(
                $Points | Group-Object -Property type | ForEach-Object {
                    @{ type = $_.Name; count = $_.Count }
                }
            )
        }
        points = @($Points | ForEach-Object {
            @{
                author     = $_.author
                source     = $_.source
                type       = $_.type
                state      = $_.state
                timestamp  = $_.timestamp
                body_preview = $_.body.Substring(0, [Math]::Min(150, $_.body.Length))
                body       = $_.body
            }
        })
        generated_at = (Get-Date -Format "o")
    }

    return $report
}

# Main execution
try {
    $reviewData = Get-ReviewData -Owner $RepoOwner -Name $RepoName -Number $PrNumber
    $points = Extract-ReviewPoints -ReviewData $reviewData
    
    if ($points.Count -eq 0) {
        Write-Host "[!] No review points found." -ForegroundColor Yellow
        $dedupedPoints = @()
    }
    else {
        $dedupedPoints = Deduplicate-Points -Points $points
    }

    $report = Generate-Report -Points $dedupedPoints

    # Output
    $json = $report | ConvertTo-Json -Depth 10
    Write-Host $json

    if ($OutputFile) {
        $json | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
        Write-Host "[+] Report written to $OutputFile" -ForegroundColor Green
    }

    Write-Host "[+] Deduplication complete: $($dedupedPoints.Count) unique points extracted." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Execution failed: $_" -ForegroundColor Red
    exit 1
}

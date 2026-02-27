# auto-review-simple.ps1 - Lightweight auto-review using vLLM directly
#
# Simplified version that calls vLLM API directly without sk-agent HTTP.
# Use this when sk-agent HTTP endpoint is unavailable.
#
# Usage:
#   .\auto-review-simple.ps1                     # Review HEAD vs HEAD~1
#   .\auto-review-simple.ps1 -DiffRange "HEAD~3" # Review last 3 commits

param(
    [string]$DiffRange = "HEAD~1",
    [int]$IssueNumber = 0,
    [string]$RepoOwner = "jsboige",
    [string]$RepoName = "roo-extensions",
    [switch]$DryRun,
    [switch]$Verbose
)

# Delegate to auto-review.ps1 with vllm mode
$scriptDir = $PSScriptRoot
$reviewArgs = @{
    DiffRange = $DiffRange
    Mode = "vllm"
    RepoOwner = $RepoOwner
    RepoName = $RepoName
}
if ($IssueNumber -gt 0) { $args["IssueNumber"] = $IssueNumber }
if ($DryRun) { $args["DryRun"] = $true }
if ($Verbose) { $args["Verbose"] = $true }

& "$scriptDir\auto-review.ps1" @reviewArgs

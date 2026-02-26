param(
    [string]$DiffRange = "HEAD~1",
    [switch]$Verbose = $false
)

# Auto-review script using sk-agent for code review
# Simplified version

# Enable strict mode
Set-StrictMode -Version Latest

# Color functions for output
function Write-ColorOutput($ForegroundColor) {
    $oldColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $Host.UI.RawUI.ForegroundColor = $oldColor
}

function Write-Info($Message) {
    Write-ColorOutput Green "[INFO]" $Message
}

function Write-Warning($Message) {
    Write-ColorOutput Yellow "[WARN]" $Message
}

function Write-Error($Message) {
    Write-ColorOutput Red "[ERROR]" $Message
}

# Check if we're in a git repository
function Test-GitRepository {
    $gitDir = git rev-parse --git-dir 2>$null
    return $gitDir -ne $null
}

# Get commit information
function Get-CommitInfo($Range) {
    $commitInfo = @{
        Hash = ""
        Author = ""
        Date = ""
        Message = ""
    }

    try {
        $commitData = git log -1 --pretty=format:"%H|%an|%ad|%s" $Range 2>$null
        if ($commitData) {
            $parts = $commitData -split '\|'
            $commitInfo.Hash = $parts[0]
            $commitInfo.Author = $parts[1]
            $commitInfo.Date = $parts[2]
            $commitInfo.Message = $parts[3]
        }
    } catch {
        Write-Error "Failed to get commit info: $_"
    }

    return $commitInfo
}

# Get the actual diff
function Get-GitDiff($Range) {
    try {
        $diff = git diff --stat $Range 2>$null
        if (-not $diff) {
            Write-Warning "No changes found in range: $Range"
            return $null
        }

        $fullDiff = git diff $Range 2>$null
        return @{
            Stat = $diff
            Full = $fullDiff
        }
    } catch {
        Write-Error "Failed to get git diff: $_"
        return $null
    }
}

# Find related GitHub issue/PR
function Find-GitHubReference($CommitMessage) {
    # Common patterns for issue references
    $patterns = @(
        '(?i)(fix|close|resolve)[\s\-]*#(\d+)',
        '(?i)issue[\s\-]*#(\d+)',
        '(?i)#(\d+)'
    )

    foreach ($pattern in $patterns) {
        if ($CommitMessage -match $pattern) {
            return $matches[1]
        }
    }

    # Fallback: get latest open issue
    try {
        $latestIssue = gh issue list --state open --limit 1 --json number --jq '.[0].number' 2>$null
        if ($latestIssue) {
            return $latestIssue.Trim('"')
        }
    } catch {
        # Silently ignore
    }

    return $null
}

# Simple review function (when sk-agent fails)
function Get-SimpleReview($Diff, $CommitInfo) {
    return @"
## Auto-Review par sk-agent

### 📝 Résumé
Review automatique du commit $($CommitInfo.Hash.Substring(0,7)) - $($CommitInfo.Message)

**Changements:**
$($Diff.Stat)

### 🎯 Synthèse
- **État**: Automatisé
- **Machine**: ${env:COMPUTERNAME}
- **Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- **Note**: sk-agent non disponible ou erreur temporaire

---
*Review automatique générée sur la machine ${env:COMPUTERNAME}*
"@
}

# Main execution
function Main {
    # Check git repository
    if (-not (Test-GitRepository)) {
        Write-Error "Not a git repository"
        exit 1
    }

    Write-Info "Starting auto-review for range: $DiffRange"

    # Get commit info
    $commitInfo = Get-CommitInfo $DiffRange
    if (-not $commitInfo.Hash) {
        Write-Error "No commit found in range: $DiffRange"
        exit 1
    }

    # Get diff
    $diff = Get-GitDiff $DiffRange
    if (-not $diff) {
        Write-Error "No changes to review"
        exit 1
    }

    # Find GitHub reference
    $issueNumber = Find-GitHubReference $commitInfo.Message
    if (-not $issueNumber) {
        Write-Warning "No GitHub reference found"
        exit 0
    }

    Write-Info "Found GitHub reference: #$issueNumber"

    # Perform code review (simplified for now)
    $reviewResult = Get-SimpleReview $diff $commitInfo
    Write-Info "Review generated"

    # Post comment
    try {
        Write-Info "Posting comment to issue #$issueNumber..."

        # Add metadata
        $reviewWithMetadata = @"
$reviewResult

**Informations techniques:**
- Machine: ${env:COMPUTERNAME}
- Commit: $($commitInfo.Hash)
- Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- Script: auto-review-simple.ps1
"@

        # Post comment
        $commentResult = gh api repos/$RepoOwner/$RepoName/issues/$issueNumber/comments -f body=$reviewWithMetadata

        if ($commentResult) {
            $commentId = $commentResult.id
            Write-Info "Comment posted successfully (ID: $commentId)"
            Write-Info "URL: https://github.com/$RepoOwner/$RepoName/issues/$issueNumber#issuecomment-$commentId"
        } else {
            throw "Comment post failed"
        }

    } catch {
        Write-Error "Failed to post comment: $_"
        exit 1
    }

    Write-Info "Auto-review completed successfully"
}

# Run main function
Main
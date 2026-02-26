# Script test pour isoler le problème de pattern matching

$commitMessage = "test(auto-review): Test avec issue #541"
Write-Host "Commit message: $commitMessage"

# Test 1: Pattern avec match
if ($commitMessage -match '(?i)(fix|close|resolve|issue)[\s\-]*#(\d+)') {
    Write-Host "Pattern 1 OK - Issue: $($matches[2])"
} else {
    Write-Host "Pattern 1 FAILED"
}

# Test 2: Pattern simple
if ($commitMessage -match '#(\d+)') {
    Write-Host "Pattern 2 OK - Issue: $($matches[1])"
} else {
    Write-Host "Pattern 2 FAILED"
}

# Variables de test
$issueNumber = $null
if ($commitMessage -match '(?i)(fix|close|resolve|issue)[\s\-]*#(\d+)') {
    $issueNumber = $matches[2]
    Write-Host "Assignment OK - Issue: $issueNumber"
} else {
    Write-Host "Assignment FAILED"
}

Write-Host "Final issueNumber: $issueNumber"
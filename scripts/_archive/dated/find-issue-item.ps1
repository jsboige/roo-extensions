# Find ITEM_ID for issue #678 in Project #67

$queryTemplate = @'
{
  user(login: "jsboige") {
    projectV2(number: 67) {
      items(first: 100, after: "{CURSOR}") {
        nodes {
          id
          content {
            ... on Issue {
              number
            }
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
}

$cursor = ""
$page = 0

while ($true) {
    $page++
    Write-Host "Page $page..."

    $query = $queryTemplate -replace "{CURSOR}", $cursor
    $result = gh api graphql -f query=$query 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: $result"
        break
    }

    $json = $result | ConvertFrom-Json
    $items = $json.data.user.projectV2.items.nodes

    # Look for issue #678
    $found = $items | Where-Object { $_.content.number -eq 678 }
    if ($found) {
        Write-Host "Found issue #678!"
        Write-Host "ITEM_ID: $($found.id)"
        $found.id | Set-Content -Path "issue-678-item-id.txt"
        break
    }

    # Check pagination
    $pageInfo = $json.data.user.projectV2.items.pageInfo
    if (-not $pageInfo.hasNextPage) {
        Write-Host "No more pages. Issue #678 not found."
        break
    }

    $cursor = $pageInfo.endCursor
}
'@

$queryTemplate

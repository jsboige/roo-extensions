# Find ITEM_ID for issue #678 in Project #67

$cursor = ""
$page = 0

while ($true) {
    $page++
    Write-Host "Page $page..."

    if ([string]::IsNullOrEmpty($cursor)) {
        $query = @"
{
  user(login: "jsboige") {
    projectV2(number: 67) {
      items(first: 100) {
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
"@
    } else {
        $query = @"
{
  user(login: "jsboige") {
    projectV2(number: 67) {
      items(first: 100, after: "$cursor") {
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
"@
    }

    $queryFile = [System.IO.Path]::GetTempFileName()
    $query | Out-File -FilePath $queryFile -Encoding UTF8
    $result = gh api graphql --jq '.' -F query="@$queryFile" | ConvertFrom-Json
    Remove-Item $queryFile

    $item_id = ($result.data.user.projectV2.items.nodes | Where-Object { $_.content.number -eq 678 }).id

    if ($item_id) {
        Write-Host "Found issue #678! ITEM_ID: $item_id"
        $item_id | Out-File -FilePath 'c:\dev\roo-extensions\issue-678-item-id.txt'
        break
    }

    $has_next = $result.data.user.projectV2.items.pageInfo.hasNextPage
    if (-not $has_next) {
        Write-Host "No more pages. Issue #678 not found."
        break
    }

    $cursor = $result.data.user.projectV2.items.pageInfo.endCursor
}

Get-Content 'c:\dev\roo-extensions\issue-678-item-id.txt'

$cursor = ""
$page = 0

while ($true) {
    $page++
    Write-Host "Page $page..."

    if ([string]::IsNullOrEmpty($cursor)) {
        $result = gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { items(first: 100) { nodes { id content { ... on Issue { number } } } pageInfo { hasNextPage endCursor } } } } }' | ConvertFrom-Json
    } else {
        $escaped = $cursor -replace '"', '\"'
        $result = gh api graphql -f query="{ user(login: \"jsboige\") { projectV2(number: 67) { items(first: 100, after: \"$escaped\") { nodes { id content { ... on Issue { number } } } pageInfo { hasNextPage endCursor } } } } }" | ConvertFrom-Json
    }

    foreach ($node in $result.data.user.projectV2.items.nodes) {
        if ($node.content.number -eq 678) {
            Write-Host "Found issue #678! ITEM_ID: $($node.id)"
            $node.id | Out-File -FilePath 'c:\dev\roo-extensions\issue-678-item-id.txt'
            exit 0
        }
    }

    $has_next = $result.data.user.projectV2.items.pageInfo.hasNextPage
    if (-not $has_next) {
        Write-Host "No more pages. Issue #678 not found."
        exit 1
    }

    $cursor = $result.data.user.projectV2.items.pageInfo.endCursor
}

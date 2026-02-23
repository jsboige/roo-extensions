$issues = gh issue list --repo jsboige/roo-extensions --state open --limit 10 --json number,title,labels
$issues | ConvertFrom-Json | ForEach-Object {
    $label = $_.labels | Where-Object { $_.name -eq "roo-schedulable" }
    if ($label) {
        "$($_.number)`t$($_.title)"
    }
}

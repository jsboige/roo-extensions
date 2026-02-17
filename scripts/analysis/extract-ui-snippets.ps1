param(
    [string[]]$Files,
    [int]$Chars = 5000,
    [string]$OutDir = "exports/ui-snippets"
)

Write-Host "Extracting first/last $Chars characters for $($Files.Count) files..." -ForegroundColor Cyan

if (-not $Files -or $Files.Count -eq 0) {
    $Files = @(
      'C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\ac8aa7b4-319c-4925-a139-4f4adca81921\ui_messages.json',
      'C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\bc93a6f7-cd2e-4686-a832-46e3cd14d338\ui_messages.json',
      'C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\52df1bbe-8219-4bb6-8a10-1fa6aef40b02\ui_messages.json',
      'C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\511dd928-4812-4c18-8f5f-7c6ece3e1399\ui_messages.json',
      'C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\90aef628-ef96-4a75-8af8-6bd8ba9b6440\ui_messages.json',
      'C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\3c502105-0dfd-4379-bfe9-c4b3317cc04b\ui_messages.json'
    )
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$index = @()

foreach ($file in $Files) {
    try {
        if (-not (Test-Path $file)) {
            Write-Warning "Missing file: $file"
            continue
        }
        $content = Get-Content -LiteralPath $file -Raw -Encoding UTF8
        $len = $content.Length
        $head = if ($len -le $Chars) { $content } else { $content.Substring(0, [Math]::Min($Chars, $len)) }
        $tail = if ($len -le $Chars) { $content } else { $content.Substring([Math]::Max(0, $len - $Chars)) }

        $taskId = ''
        $m = [regex]::Match($file, 'tasks[\\/](.+?)[\\/]')
        if ($m.Success) { $taskId = $m.Groups[1].Value } else { $taskId = (Split-Path -Parent $file | Split-Path -Leaf) }

        $headPath = Join-Path $OutDir "$taskId-head.txt"
        $tailPath = Join-Path $OutDir "$taskId-tail.txt"

        Set-Content -LiteralPath $headPath -Value $head -Encoding UTF8
        Set-Content -LiteralPath $tailPath -Value $tail -Encoding UTF8

        $index += [pscustomobject]@{
            TaskId = $taskId
            Source = $file
            Length = $len
            Head = $headPath
            Tail = $tailPath
        }

        Write-Host ("OK {0} ({1} chars) -> {2} / {3}" -f $taskId, $len, $headPath, $tailPath) -ForegroundColor Green
    }
    catch {
        Write-Error ("Error processing {0}: {1}" -f $file, $_.Exception.Message)
    }
}

$indexJson = Join-Path $OutDir "index.json"
$index | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $indexJson -Encoding UTF8

$summaryPath = Join-Path $OutDir "SUMMARY.md"
$md = @()
$md += "# UI Snippets Extraction"
$md += ""
$md += "| TaskId | Length | Head | Tail |"
$md += "|--------|--------|------|------|"
foreach ($row in $index) {
    $headRel = $row.Head
    $tailRel = $row.Tail
    $md += "| $($row.TaskId) | $($row.Length) | $headRel | $tailRel |"
}
$md -join "`n" | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "Done. Outputs in $OutDir" -ForegroundColor Cyan
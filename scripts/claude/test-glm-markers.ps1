# GLM-5.1 Marker-Based Context Truncation Test
# Places 18 unique markers at ~10K token intervals across ~180K tokens
# Then asks the model to report all markers found — detecting silent truncation

$ErrorActionPreference = "Stop"

# Config
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$apiKey = $settings.env.ANTHROPIC_AUTH_TOKEN
$baseUrl = $settings.env.ANTHROPIC_BASE_URL
$model = $settings.env.ANTHROPIC_DEFAULT_OPUS_MODEL

Write-Host "=== GLM-5.1 Marker-Based Context Truncation Test ===" -ForegroundColor Cyan
Write-Host "Model: $model"

# Generate 18 unique markers
$markers = @()
$random = [System.Random]::new()
for ($i = 0; $i -lt 18; $i++) {
    $tokenPos = ($i + 1) * 10000
    $chars = @()
    for ($c = 0; $c -lt 4; $c++) {
        $chars += [char](65 + $random.Next(26))
    }
    $code = -join $chars
    $markerCode = "MX-$code-$($i.ToString('00'))"
    $markers += @{ Index = $i; TokenPos = $tokenPos; Code = $markerCode }
}

# Build context with markers inserted every ~10K tokens
# ~4 chars per token, so ~10K tokens = ~40K chars per section
$lorem = "Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua Ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur "
$sectionTargetChars = 38000  # ~9.5K tokens per section

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("IMPORTANT INSTRUCTIONS:")
[void]$sb.AppendLine("This message contains 18 unique marker codes placed throughout a large text.")
[void]$sb.AppendLine("You MUST find ALL markers and report them. Each marker looks like: MX-XXXX-NN")
[void]$sb.AppendLine("Search the ENTIRE text carefully for every occurrence of the pattern MX-")
[void]$sb.AppendLine("")

for ($i = 0; $i -lt 18; $i++) {
    # Filler text for this section
    $repetitions = [math]::Ceiling($sectionTargetChars / $lorem.Length)
    $filler = $lorem * $repetitions
    $filler = $filler.Substring(0, [math]::Min($sectionTargetChars, $filler.Length))

    # Insert marker
    $markerText = "=== SECTION $i [MARKER: $($markers[$i].Code)] ==="
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine($markerText)
    [void]$sb.AppendLine($filler)
}

$context = $sb.ToString()
$totalChars = $context.Length
$estTokens = [math]::Round($totalChars / 4)

Write-Host "Context size: $totalChars chars, ~$estTokens estimated tokens"
Write-Host "Markers placed:"
foreach ($m in $markers) {
    Write-Host ("  Marker {0}: {1} at ~{2}K tokens" -f $m.Index, $m.Code, ($m.TokenPos / 1000))
}

# Build the prompt
$body = @{
    model = $model
    max_tokens = 500
    messages = @(
        @{
            role = "user"
            content = $context + "`n`n--- END OF TEXT ---`n`nNow report ALL marker codes you found in the text above. List them in order, one per line, like: MX-XXXX-00. If you cannot find all 18, report which ones you found and note any that are missing."
        }
    )
} | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host "Sending request (this will take several minutes)..." -ForegroundColor Yellow

$headers = @{
    "x-api-key" = $apiKey
    "anthropic-version" = "2023-06-01"
    "content-type" = "application/json"
}

try {
    $result = Invoke-RestMethod -Uri "$baseUrl/v1/messages" -Headers $headers -Method Post -Body $body -TimeoutSec 600
    $responseText = $result.content[0].text
    $inputTokens = $result.usage.input_tokens
    $outputTokens = $result.usage.output_tokens

    Write-Host ""
    Write-Host "=== RESULTS ===" -ForegroundColor Cyan
    Write-Host "Reported input_tokens: $inputTokens"
    Write-Host "Output tokens: $outputTokens"
    Write-Host ""
    Write-Host "Model response:" -ForegroundColor Yellow
    Write-Host $responseText

    # Analyze which markers were found
    Write-Host ""
    Write-Host "=== MARKER ANALYSIS ===" -ForegroundColor Cyan
    $found = 0
    $missing = @()
    foreach ($m in $markers) {
        $wasFound = $responseText -match $m.Code
        if ($wasFound) {
            $found++
            Write-Host ("  [FOUND] {0} (~{1}K tokens)" -f $m.Code, ($m.TokenPos / 1000)) -ForegroundColor Green
        } else {
            $missing += $m
            Write-Host ("  [MISSING] {0} (~{1}K tokens)" -f $m.Code, ($m.TokenPos / 1000)) -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Markers found: $found / 18" -ForegroundColor $(if ($found -eq 18) { "Green" } else { "Yellow" })

    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "=== TRUNCATION ANALYSIS ===" -ForegroundColor Red
        $firstMissing = $missing[0]
        Write-Host ("First missing marker: {0} at ~{1}K tokens" -f $firstMissing.Code, ($firstMissing.TokenPos / 1000))
        $lastFound = $markers | Where-Object { $responseText -match $_.Code } | Select-Object -Last 1
        if ($lastFound) {
            Write-Host ("Last found marker: {0} at ~{1}K tokens" -f $lastFound.Code, ($lastFound.TokenPos / 1000))
            Write-Host ("Estimated real context limit: ~{0}K tokens" -f ($lastFound.TokenPos / 1000))
        }

        # Check if truncation is from beginning or end
        $firstFound = $markers | Where-Object { $responseText -match $_.Code } | Select-Object -First 1
        if ($firstFound -and $firstFound.Index -gt 0) {
            Write-Host ""
            Write-Host ("TRUNCATION FROM BEGINNING detected! First found marker: {0} at ~{1}K tokens" -f $firstFound.Code, ($firstFound.TokenPos / 1000)) -ForegroundColor Magenta
        }
    } else {
        Write-Host ""
        Write-Host "ALL 18 MARKERS FOUND — GLM-5.1 can handle at least ~180K tokens!" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host $reader.ReadToEnd()
    }
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan

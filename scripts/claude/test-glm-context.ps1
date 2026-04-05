# Test GLM-5.1 actual context window size via z.ai API
# Methodology: Send prompts of increasing size with a secret code at the start,
# then check if the model can recall it (detecting silent truncation)

$ErrorActionPreference = "Stop"

# Read API config from Claude settings
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$apiKey = $settings.env.ANTHROPIC_AUTH_TOKEN
$baseUrl = $settings.env.ANTHROPIC_BASE_URL
$model = $settings.env.ANTHROPIC_DEFAULT_OPUS_MODEL

Write-Host "=== GLM Context Window Test ===" -ForegroundColor Cyan
Write-Host "Model: $model"
Write-Host "Endpoint: $baseUrl"
Write-Host ""

# Test 1: Check if models endpoint exists
Write-Host "--- Test 1: Models endpoint ---" -ForegroundColor Yellow
try {
    $modelsResp = Invoke-RestMethod -Uri "$baseUrl/v1/models" -Headers @{ "x-api-key" = $apiKey; "anthropic-version" = "2023-06-01" } -Method Get -TimeoutSec 30
    Write-Host "Models endpoint response:"
    $modelsResp | ConvertTo-Json -Depth 5 | Select-Object -First 30
} catch {
    Write-Host "Models endpoint not available: $($_.Exception.Message)" -ForegroundColor DarkGray
}

# Test 2: Small message to check response headers
Write-Host ""
Write-Host "--- Test 2: Response headers check ---" -ForegroundColor Yellow
$secret = "SECRET-CODE-XJQ-4829-ZTA"
$smallBody = @{
    model = $model
    max_tokens = 100
    messages = @(
        @{
            role = "user"
            content = "Remember this code: $secret. Now reply with just 'OK'."
        }
    )
} | ConvertTo-Json -Depth 5

try {
    $headers = @{
        "x-api-key" = $apiKey
        "anthropic-version" = "2023-06-01"
        "content-type" = "application/json"
    }
    $resp = Invoke-WebRequest -Uri "$baseUrl/v1/messages" -Headers $headers -Method Post -Body $smallBody -TimeoutSec 60
    Write-Host "Status: $($resp.StatusCode)"
    Write-Host "Response headers:"
    $resp.Headers | Format-Table -AutoSize
    $body = $resp.Content | ConvertFrom-Json
    Write-Host "Input tokens: $($body.usage.input_tokens)"
    Write-Host "Output tokens: $($body.usage.output_tokens)"
    Write-Host "Response: $($body.content[0].text)"
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Generate large context to test truncation
Write-Host ""
Write-Host "--- Test 3: Truncation test (increasing sizes) ---" -ForegroundColor Yellow

# Filler text - ~4 chars per token in English
# We want to test at: 50K, 100K, 130K, 150K tokens
# Approximate: 1K tokens ≈ 4K chars
$sizesToTest = @(50000, 100000, 130000, 150000)

foreach ($targetTokens in $sizesToTest) {
    Write-Host ""
    Write-Host "--- Testing ~$($targetTokens/1000)K tokens ---" -ForegroundColor Cyan

    # Create filler: each "word " is ~1.25 tokens, so ~0.8 words per token
    # Target words = targetTokens * 0.8
    $targetWords = [math]::Floor($targetTokens * 0.8)

    # Build filler from repeated Lorem Ipsum paragraphs
    $lorem = "Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua Ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur "
    $loremWords = ($lorem -split " ").Count
    $repetitions = [math]::Ceiling($targetWords / $loremWords)
    $filler = $lorem * $repetitions

    # Trim to approximate target
    $fillerWords = ($filler -split " ")
    if ($fillerWords.Count -gt $targetWords) {
        $filler = ($fillerWords[0..($targetWords-1)] -join " ")
    }

    $fillerChars = $filler.Length
    $estimatedTokens = [math]::Round($fillerChars / 4)

    $body = @{
        model = $model
        max_tokens = 200
        messages = @(
            @{
                role = "user"
                content = "IMPORTANT: Remember this secret code: $secret. You will need it later.`n`n---FILLER START---`n$filler`n---FILLER END---`n`nNow ignore the filler text above. What was the secret code I asked you to remember at the start? Reply with ONLY the code, nothing else."
            }
        )
    } | ConvertTo-Json -Depth 5

    Write-Host "Filler: $fillerChars chars, ~$estimatedTokens estimated tokens"
    Write-Host "Sending request (this may take a while)..."

    try {
        $resp = Invoke-WebRequest -Uri "$baseUrl/v1/messages" -Headers $headers -Method Post -Body $body -TimeoutSec 300
        $result = $resp.Content | ConvertFrom-Json
        $inputTokens = $result.usage.input_tokens
        $outputTokens = $result.usage.output_tokens
        $responseText = $result.content[0].text

        $recalled = $responseText -match $secret
        $status = if ($recalled) { "RECALLED" } else { "TRUNCATED" }
        $color = if ($recalled) { "Green" } else { "Red" }

        Write-Host "Input tokens reported: $inputTokens" -ForegroundColor Yellow
        Write-Host "Output tokens: $outputTokens"
        Write-Host "Model response: $responseText"
        Write-Host "Status: $status" -ForegroundColor $color

        # If truncated, we found the limit
        if (-not $recalled) {
            Write-Host ""
            Write-Host "=== TRUNCATION DETECTED at ~$estimatedTokens estimated tokens ===" -ForegroundColor Red
            Write-Host "API reported input_tokens: $inputTokens" -ForegroundColor Yellow
            Write-Host "This suggests the real context limit is around $inputTokens tokens" -ForegroundColor Yellow
            break
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Error body: $errorBody" -ForegroundColor DarkRed
        }
    }
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan

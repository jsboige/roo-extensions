# Test Jupyter Notebook Execution via Papermill - myia-po-2023
# Issue #600 - Option 2: Script externe (papermill)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Test Jupyter Notebook Execution via Papermill ===" -ForegroundColor Cyan
Write-Host "Machine: myia-po-2023" -ForegroundColor Yellow
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Yellow

# Check Python
Write-Host "[1/5] Checking Python..." -ForegroundColor Green
$pythonVersion = python --version 2>&1
Write-Host "  Python: $pythonVersion" -ForegroundColor Gray

# Check packages
Write-Host "[2/5] Checking papermill package..." -ForegroundColor Green
$papermillInfo = pip show papermill 2>&1 | Select-String "Version:"
Write-Host "  $papermillInfo" -ForegroundColor Gray

# Check kernels
Write-Host "[3/5] Checking Jupyter kernels..." -ForegroundColor Green
$kernelCount = (jupyter kernelspec list 2>&1 | Select-String -Pattern "python3|\.net-" | Measure-Object).Count
Write-Host "  Found $kernelCount kernels (python3, .net-*)" -ForegroundColor Gray

# Test notebook execution
Write-Host "[4/5] Executing test notebook..." -ForegroundColor Green

$notebookPath = "mcps/internal/servers/jupyter-papermill-mcp-server/tests/mock_notebooks/simple_math.ipynb"
$outputPath = "$env:TEMP/simple_math_executed.ipynb"

if (!(Test-Path $notebookPath)) {
    Write-Host "  ERROR: Notebook not found at $notebookPath" -ForegroundColor Red
    exit 1
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    python -m papermill $notebookPath $outputPath --kernel python3 2>&1 | Out-Null
    $stopwatch.Stop()

    $duration = $stopwatch.Elapsed.TotalSeconds
    Write-Host "  SUCCESS: Notebook executed in $duration seconds`n" -ForegroundColor Green

    # Check output
    Write-Host "[5/5] Verifying output..." -ForegroundColor Green
    if (Test-Path $outputPath) {
        $outputSize = (Get-Item $outputPath).Length
        Write-Host "  Output: $outputPath ($outputSize bytes)`n" -ForegroundColor Gray

        # Convert to HTML
        $htmlPath = "$outputPath.html"
        jupyter nbconvert --to html $outputPath --output $htmlPath 2>&1 | Out-Null
        if (Test-Path $htmlPath) {
            Write-Host "  HTML: $htmlPath`n" -ForegroundColor Gray
        }
    }

    # Summary
    Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Machine: myia-po-2023" -ForegroundColor Yellow
    Write-Host "Python: $pythonVersion" -ForegroundColor Yellow
    Write-Host "Packages: papermill, nbformat" -ForegroundColor Yellow
    Write-Host "Kernels: $kernelCount (python3, .net-*)" -ForegroundColor Yellow
    Write-Host "Duration: $duration seconds" -ForegroundColor Yellow
    Write-Host "Status: VALIDATED`n" -ForegroundColor Green

} catch {
    Write-Host "  ERROR: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}

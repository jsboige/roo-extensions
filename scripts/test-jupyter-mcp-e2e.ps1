# E2E Test Script for jupyter-mcp-server

param(
    [string]$McpPath = "D:\dev\roo-extensions\mcps\internal\servers\jupyter-mcp-server"
)

# --- Functions ---
function Stop-ProcessByNameAndPath {
    param ([string]$Name, [string]$PathPattern)
    Write-Host "Searching for running '$Name' processes with path like '*$PathPattern*'..."
    try {
        $processes = Get-CimInstance Win32_Process | Where-Object { $_.Name -eq $Name -and $_.CommandLine -like "*$PathPattern*" }
        if ($processes) {
            foreach ($p in $processes) {
                Write-Host "Stopping process $($p.ProcessId) ($($p.Name))..."
                Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
            }
        } else {
            Write-Host "No running '$Name' processes found that match the path."
        }
    } catch {
        Write-Warning "Could not stop process: $_"
    }
}

# --- Main ---

# 1. Cleanup old processes
Write-Host "--- Cleaning up old processes ---"
Stop-ProcessByNameAndPath -Name "node.exe" -PathPattern "jupyter-mcp-server"
Stop-ProcessByNameAndPath -Name "jupyter-lab.exe" -PathPattern ".conda\envs\mcp-jupyter"

# 2. Build the MCP
Write-Host "--- Building MCP ---"
Push-Location $McpPath
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    Pop-Location
    exit 1
}
Pop-Location

# 3. Start the MCP process and call the tool
Write-Host "--- Starting MCP server for direct testing ---"
$mcpScriptPath = Join-Path $McpPath "dist\index.js"
$jupyterPath = "C:\Users\jsboi\.conda\envs\mcp-jupyter\Scripts\jupyter-lab.exe"
$escapedJupyterPath = $jupyterPath -replace '\\', '\\'
$jsonRpcRequest = ""{\"name\":\"start_jupyter_server\",\"arguments\":{\"envPath\":\"$escapedJupyterPath\"}}""
$nodeArgs = "$mcpScriptPath --e2e-test-command $jsonRpcRequest"

# Start the process and capture output
$process = Start-Process -FilePath "node" -ArgumentList $nodeArgs -PassThru -RedirectStandardOutput "stdout.log" -RedirectStandardError "stderr.log" -Wait -WindowStyle Hidden

# Read output from files
$response = Get-Content "stdout.log" -Raw
$stderrOutput = Get-Content "stderr.log" -Raw
Remove-Item "stdout.log"
Remove-Item "stderr.log"

Write-Host "--- E2E Test Results ---"
Write-Host "[MCP STDOUT RESPONSE]:"
$response | Write-Host
Write-Host "[MCP STDERR]:"
$stderrOutput | Write-Host


# 8. Cleanup
Write-Host "--- Cleaning up test processes ---"
if (-not $mcpProcess.HasExited) { Stop-Process -Id $mcpProcess.Id -Force }
if (-not $jupyterProcess.HasExited) { Stop-Process -Id $jupyterProcess.Id -Force }

# 9. Final Verdict
if (($response -like '*"error"*') -or ($stderrOutput -ne "")) {
    Write-Error "E2E Test FAILED."
    exit 1
} elseif ($response -eq "") {
    Write-Error "E2E Test FAILED. No response from MCP."
    exit 1
} else {
    Write-Host "E2E Test PASSED."
    exit 0
}
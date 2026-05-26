<#
.SYNOPSIS
    Patches Roo Scheduler extension for Zoo-Code compatibility.
.DESCRIPTION
    Fork of kylehoskins.roo-scheduler-0.0.11 that replaces all Roo Code
    extension references with Zoo-Code equivalents. Creates a new VSIX package
    that can be installed alongside or instead of the original scheduler.

    Issue: #2134 — Roo Scheduler compatibility with Zoo-Code migration.
.PARAMETER SourcePath
    Path to the original Roo Scheduler extension directory.
    Default: first match in ~/.vscode/extensions/kylehoskins.roo-scheduler-*
.PARAMETER OutputDir
    Directory for the output VSIX. Default: ./outputs
.PARAMETER KeepTemp
    Keep the temporary working directory after build.
.EXAMPLE
    .\patch-scheduler.ps1
    .\patch-scheduler.ps1 -OutputDir D:\packages
#>
param(
    [string]$SourcePath = "",
    [string]$OutputDir = "",
    [switch]$KeepTemp
)

$ErrorActionPreference = "Stop"

# --- Resolve source ---
if (-not $SourcePath) {
    $candidates = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter "kylehoskins.roo-scheduler-*"
    if ($candidates.Count -eq 0) {
        Write-Error "Roo Scheduler extension not found in ~/.vscode/extensions/"
        exit 1
    }
    $SourcePath = $candidates[0].FullName
    Write-Host "Using source: $SourcePath"
}

if (-not (Test-Path "$SourcePath\package.json")) {
    Write-Error "package.json not found in $SourcePath"
    exit 1
}

# --- Resolve output ---
if (-not $OutputDir) {
    $repoRoot = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if ($repoRoot) {
        $OutputDir = Join-Path $repoRoot "outputs"
    } else {
        $OutputDir = $PSScriptRoot
    }
}
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

# --- Create temp working copy ---
$tempDir = Join-Path $env:TEMP "zoo-scheduler-patch-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "Working dir: $tempDir"
Copy-Item -Path $SourcePath -Destination $tempDir -Recurse -Force

try {
    # --- Patch package.json ---
    $pkgPath = Join-Path $tempDir "package.json"
    $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json

    $pkg.name = "zoo-scheduler"
    $pkg.displayName = "Zoo Scheduler"
    $pkg.description = "A task scheduler for Zoo Code (fork of roo-scheduler 0.0.11)"
    $pkg.publisher = "jsboige"
    $pkg.version = "0.0.11-zoo.1"
    $pkg.extensionDependencies = @("zoocodeorganization.zoo-code")

    # Skip prepublish rebuild (we patch dist/ directly)
    $pkg.scripts.'vscode:prepublish' = "echo skip"

    $jsonContent = $pkg | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($pkgPath, $jsonContent, [System.Text.UTF8Encoding]::new($false))

    # --- Patch dist/extension.js ---
    $extJs = Join-Path $tempDir "dist\extension.js"
    $content = [System.IO.File]::ReadAllText($extJs)

    # Replace 1: Extension ID (3 occurrences)
    $content = $content.Replace("rooveterinaryinc.roo-cline", "zoocodeorganization.zoo-code")

    # Replace 2: Activity bar panel (3 occurrences)
    $content = $content.Replace("roo-cline-ActivityBar", "zoo-code-ActivityBar")

    # Replace 3: Configuration section (7 occurrences)
    $content = $content.Replace('getConfiguration("roo-cline")', 'getConfiguration("zoo-code")')

    [System.IO.File]::WriteAllText($extJs, $content, [System.Text.UTF8Encoding]::new($false))

    # --- Verify patches ---
    $verifyContent = [System.IO.File]::ReadAllText($extJs)
    $oldRefs = ([regex]::Matches($verifyContent, "rooveterinaryinc\.roo-cline")).Count
    $oldActivity = ([regex]::Matches($verifyContent, "roo-cline-ActivityBar")).Count
    $oldConfig = ([regex]::Matches($verifyContent, 'getConfiguration\("roo-cline"\)')).Count

    if ($oldRefs -gt 0 -or $oldActivity -gt 0 -or $oldConfig -gt 0) {
        Write-Error "Patch verification failed: $oldRefs ext refs, $oldActivity activity refs, $oldConfig config refs remain"
        exit 1
    }

    $newRefs = ([regex]::Matches($verifyContent, "zoocodeorganization\.zoo-code")).Count
    $newActivity = ([regex]::Matches($verifyContent, "zoo-code-ActivityBar")).Count
    $newConfig = ([regex]::Matches($verifyContent, 'getConfiguration\("zoo-code"\)')).Count
    Write-Host "Patch verified: $newRefs ext refs, $newActivity activity refs, $newConfig config refs"

    # --- Clean up files that should not be packaged ---
    $envFile = Join-Path $tempDir ".env"
    if (Test-Path $envFile) { Remove-Item $envFile -Force }

    # --- Build VSIX ---
    Write-Host "Building VSIX..."
    Push-Location $tempDir
    cmd /c "npm install @vscode/vsce --no-save 2>nul"
    $vsixName = "zoo-scheduler-0.0.11-zoo.1.vsix"
    cmd /c "npx vsce package --no-dependencies -o $vsixName 2>&1" | ForEach-Object { Write-Host $_ }

    if (Test-Path (Join-Path $tempDir $vsixName)) {
        $dest = Join-Path $OutputDir $vsixName
        Copy-Item (Join-Path $tempDir $vsixName) $dest -Force
        Write-Host ""
        Write-Host "SUCCESS: $dest" -ForegroundColor Green
        Write-Host "Size: $((Get-Item $dest).Length / 1MB -as [int]) MB"
        Write-Host ""
        Write-Host "Install with: code.cmd --install-extension `"$dest`""
    } else {
        Write-Error "VSIX build failed"
        exit 1
    }
    Pop-Location
} finally {
    if (-not $KeepTemp -and (Test-Path $tempDir)) {
        Remove-Item $tempDir -Recurse -Force
        Write-Host "Cleaned up temp dir"
    }
}

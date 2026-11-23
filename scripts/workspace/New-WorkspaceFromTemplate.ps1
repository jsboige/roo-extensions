<#
.SYNOPSIS
    Bootstrap a workspace from the fleet template (#3111 step 1, #4873).

.DESCRIPTION
    Creation-only bootstrap. Applies .claude/configs/workspace-template/ into -Target:

    - Refuses to overwrite an existing file; skipped files are listed.
    - -DryRun writes NOTHING (not even a directory) and prints what would be created.
    - Merges gitignore.fragment into an existing .gitignore by appending only the
      lines that are absent.
    - Never writes outside -Target.

    Compatible Windows PowerShell 5.1 and PowerShell 7 (Join-Path only, no PS7-only
    parameters). Portable: runs on Linux pwsh as well (unit-pester CI is ubuntu).

.PARAMETER Target
    Absolute or relative path of the workspace to bootstrap.

.PARAMETER Workspace
    Workspace name; replaces {{WORKSPACE}}. {{REPO}} is replaced with
    owner/name when -Target is a git repository with a GitHub origin, else with
    the workspace name.

.EXAMPLE
    New-WorkspaceFromTemplate.ps1 -Target C:\dev\MonRepo -Workspace MonRepo -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][string]$Workspace,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$targetFullPath = [System.IO.Path]::GetFullPath($Target)
$targetPrefix = $targetFullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

function Write-TargetText {
    param([string]$Path, [string]$Content)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($targetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to write outside -Target: $fullPath"
    }
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
}

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$templateDir = Join-Path (Join-Path $projectRoot '.claude/configs') 'workspace-template'
if (-not (Test-Path -LiteralPath $templateDir)) {
    throw "Template directory not found: $templateDir"
}

# {{REPO}} from the git origin when available, else the workspace name.
$repo = $Workspace
$gitDir = Join-Path $Target '.git'
if (Test-Path -LiteralPath $gitDir) {
    $configPath = Join-Path $gitDir 'config'
    if (Test-Path -LiteralPath $configPath) {
        $originLine = Get-Content -LiteralPath $configPath |
            Where-Object { $_ -match 'github\.com[:/]([^/]+/[^/\s]+?)(\.git)?\s*$' } |
            Select-Object -First 1
        if ($originLine -and $originLine -match 'github\.com[:/]([^/]+/[^/\s]+?)(\.git)?\s*$') {
            $repo = $Matches[1]
        }
    }
}

function Get-RenderedContent {
    param([string]$SourcePath)
    $text = [System.IO.File]::ReadAllText($SourcePath)
    return $text.Replace('{{WORKSPACE}}', $Workspace).Replace('{{REPO}}', $repo)
}

# Every file of the template (recursive), as target-relative paths.
# -Force is required on Linux: otherwise the hidden .claude subtree is not
# enumerated (the template's two rules and plans README would be silently lost).
$templateFiles = Get-ChildItem -LiteralPath $templateDir -Recurse -File -Force
$created = @()
$skipped = @()
$merged = @()
$dirs = @()

foreach ($file in $templateFiles) {
    $relative = $file.FullName.Substring($templateDir.TrimEnd('\', '/').Length + 1)

    # memory-seed/ stays in the workspace: activating it in the per-machine
    # memory profile is step 2, not an implicit write to $HOME.
    # The template's own README documents the template; it is NOT deployed
    # (a repo's README belongs to the repo).
    if ($relative -eq 'README.md') { continue }
    # The CLAUDE.md template lands as CLAUDE.md (the .template suffix is the
    # template-repo convention, not the deployed filename).
    if ($relative -eq 'CLAUDE.md.template') { $relative = 'CLAUDE.md' }

    $targetPath = Join-Path $Target $relative

    if ($relative -eq 'gitignore.fragment') {
        $gitignorePath = Join-Path $Target '.gitignore'
        $fragmentLines = [System.IO.File]::ReadAllLines($file.FullName) |
            Where-Object { $_.Trim() -ne '' }
        if (Test-Path -LiteralPath $gitignorePath) {
            $existing = [System.IO.File]::ReadAllLines($gitignorePath)
            $missing = @($fragmentLines | Where-Object { $existing -notcontains $_ })
            if ($missing.Count -gt 0) {
                $merged += $gitignorePath
                if (-not $DryRun) {
                    $newContent = (($existing + $missing) -join "`n") + "`n"
                    Write-TargetText -Path $gitignorePath -Content $newContent
                }
            }
            else {
                $skipped += $gitignorePath
            }
        }
        else {
            $created += $gitignorePath
            if (-not $DryRun) {
                $parent = Split-Path -Parent $gitignorePath
                if (-not (Test-Path -LiteralPath $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                Write-TargetText -Path $gitignorePath -Content (($fragmentLines -join "`n") + "`n")
            }
        }
        continue
    }

    if (Test-Path -LiteralPath $targetPath) {
        $skipped += $targetPath
        continue
    }

    $created += $targetPath
    if (-not $DryRun) {
        $parent = Split-Path -Parent $targetPath
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
            $dirs += $parent
        }
        Write-TargetText -Path $targetPath -Content (Get-RenderedContent -SourcePath $file.FullName)
    }
    else {
        $dirs += (Split-Path -Parent $targetPath)
    }
}

$mode = if ($DryRun) { 'DRY-RUN (nothing written)' } else { 'APPLIED' }
Write-Output "New-WorkspaceFromTemplate [$mode] Target=$Target Workspace=$Workspace Repo=$repo"
Write-Output ('Would-create/Created ({0}):' -f $created.Count)
$created | ForEach-Object { Write-Output ('  + ' + $_) }
Write-Output ('Merged .gitignore ({0}):' -f $merged.Count)
$merged | ForEach-Object { Write-Output ('  ~ ' + $_) }
Write-Output ('Skipped existing ({0}):' -f $skipped.Count)
$skipped | ForEach-Object { Write-Output ('  = ' + $_) }
if ($DryRun) {
    $dirs | Sort-Object -Unique | ForEach-Object { Write-Output ('  (dir) ' + $_) }
}

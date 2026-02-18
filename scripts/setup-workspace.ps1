# setup-workspace.ps1 - Template Workspace Installer
# Déploie le framework multi-agent sur un nouveau workspace

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,

    [Parameter(Mandatory=$false)]
    [string]$Repo = "",

    [Parameter(Mandatory=$false)]
    [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$WorkspaceRoot = Get-Location

Write-Host "🚀 Template Workspace Installer v1.0" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Validation
if (-not (Test-Path (Join-Path $SourcePath ".claude"))) {
    Write-Host "❌ Error: Source path '$SourcePath' does not contain .claude/" -ForegroundColor Red
    Write-Host "   Please run from roo-extensions root or specify -SourcePath" -ForegroundColor Red
    exit 1
}

# Structure à copier
$FoldersToCopy = @(
    ".claude/agents",
    ".claude/skills",
    ".claude/rules",
    ".claude/INTERCOM_PROTOCOL.md",
    ".roo/rules",
    ".roo/scheduler-workflow-executor.md"
)

Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "   Project: $ProjectName" -ForegroundColor White
Write-Host "   Repo: $Repo" -ForegroundColor White
Write-Host "   Workspace: $WorkspaceRoot" -ForegroundColor White
Write-Host ""

# Création des répertoires
Write-Host "📁 Creating directories..." -ForegroundColor Yellow
foreach ($folder in $FoldersToCopy) {
    $targetPath = Join-Path $WorkspaceRoot $folder
    $parentDir = Split-Path -Parent $targetPath
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
}

# Copie des fichiers
Write-Host "📄 Copying template files..." -ForegroundColor Yellow
if (-not $DryRun) {
    foreach ($folder in $FoldersToCopy) {
        $sourcePath = Join-Path $SourcePath $folder
        $targetPath = Join-Path $WorkspaceRoot $folder

        if (Test-Path $sourcePath) {
            if (Test-Path $sourcePath -PathType Leaf) {
                # Fichier unique
                Copy-Item -Path $sourcePath -Destination $targetPath -Force
                Write-Host "   ✓ $folder" -ForegroundColor Green
            } else {
                # Répertoire
                Copy-Item -Path "$sourcePath\*" -Destination $targetPath -Recurse -Force
                Write-Host "   ✓ $folder\" -ForegroundColor Green
            }
        }
    }
} else {
    Write-Host "   [DRY-RUN] Would copy:" -ForegroundColor Cyan
    foreach ($folder in $FoldersToCopy) {
        Write-Host "     - $folder" -ForegroundColor Cyan
    }
}

# Création CLAUDE.md personnalisé
$claudeMdPath = Join-Path $WorkspaceRoot ".claude/CLAUDE.md"
$claudeTemplate = @"
# Claude Code Guide - $ProjectName

**Project:** $ProjectName
**Repository:** $Repo
**Machine:** `$env:COMPUTERNAME
**Generated:** $(Get-Date -Format "yyyy-MM-dd")

---

## Project-Specific Instructions

Add your project-specific instructions here.

---

## Multi-Agent Framework

This workspace uses the RooSync multi-agent framework from roo-extensions.

### Local Communication

- **INTERCOM file:** `.claude/local/INTERCOM-` + `$env:COMPUTERNAME + `.md`
- Use for local Claude ↔ Roo coordination

### Git Workflow

- Always use `git-sync` skill before starting work
- Commit with conventional format: `type(scope): description`
- Run `validate` skill before pushing

### GitHub Integration

- GitHub CLI (`gh`) is configured for issue tracking
- Project: See `.claude/rules/github-cli.md` for commands

---

**Framework version:** 1.0.0 (from roo-extensions)
"@

$claudeMdPath | Out-File -FilePath $claudeMdPath -Encoding UTF8
Write-Host "   ✓ .claude/CLAUDE.md (customized)" -ForegroundColor Green
} else {
    Write-Host "   [DRY-RUN] Would create .claude/CLAUDE.md" -ForegroundColor Cyan
}

# Création .github/workflows si demandé
if ($Repo -ne "") {
    $githubDir = Join-Path $WorkspaceRoot ".github/workflows"
    if (-not (Test-Path $githubDir)) {
        New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
    }
    Write-Host "   ✓ .github/workflows/" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Template workspace installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review .claude/CLAUDE.md and customize" -ForegroundColor White
Write-Host "2. Install VS Code extensions: Claude Code, Roo Code" -ForegroundColor White
Write-Host "3. Configure gh CLI: gh auth login" -ForegroundColor White
Write-Host "4. Start coding!" -ForegroundColor White
Write-Host ""

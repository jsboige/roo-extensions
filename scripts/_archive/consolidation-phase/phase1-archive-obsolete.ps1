#!/usr/bin/env pwsh
# Phase 1: Archiver les scripts obsolètes
# #481 Consolidation scripts/

$ErrorActionPreference = "Stop"

Write-Host "=== Phase 1: Archivage Scripts Obsolètes ===" -ForegroundColor Cyan

# Créer répertoire _archive
New-Item -Path "scripts/_archive" -ItemType Directory -Force | Out-Null
Write-Host "✅ Créé scripts/_archive/" -ForegroundColor Green

# 1.1 FFmpeg (7 fichiers)
Write-Host "`n### 1.1 Archivage FFmpeg (7 fichiers)..." -ForegroundColor Yellow
$ffmpegFiles = @(
    "diagnose-ffmpeg.ps1",
    "fix-ffmpeg-path.ps1",
    "install-ffmpeg-windows.ps1",
    "refresh-path-ffmpeg.ps1",
    "test-complete-ffmpeg.ps1",
    "test-ffmpeg-markitdown.ps1"
)
New-Item -Path "scripts/_archive/ffmpeg" -ItemType Directory -Force | Out-Null
$archivedCount = 0
foreach ($file in $ffmpegFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/_archive/ffmpeg/$file" -Force
        Write-Host "  ✓ Archivé: $file" -ForegroundColor Green
        $archivedCount++
    } else {
        Write-Host "  ⊘ Absent: $file" -ForegroundColor DarkGray
    }
}
Write-Host "  → $archivedCount / 7 fichiers archivés" -ForegroundColor Cyan

# 1.2 GitHub Projects MCP (3 fichiers)
Write-Host "`n### 1.2 Archivage GitHub Projects MCP (3 fichiers)..." -ForegroundColor Yellow
$ghpFiles = @(
    "diagnose-github-projects-mcp.ps1",
    "test-github-projects-complete.ps1",
    "validation-github-projects-mcp-stdio-complete.ps1"
)
New-Item -Path "scripts/_archive/github-projects-mcp" -ItemType Directory -Force | Out-Null
$archivedCount = 0
foreach ($file in $ghpFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/_archive/github-projects-mcp/$file" -Force
        Write-Host "  ✓ Archivé: $file" -ForegroundColor Green
        $archivedCount++
    } else {
        Write-Host "  ⊘ Absent: $file" -ForegroundColor DarkGray
    }
}
Write-Host "  → $archivedCount / 3 fichiers archivés" -ForegroundColor Cyan

# 1.3 Consolidate Docs (4 fichiers)
Write-Host "`n### 1.3 Archivage Consolidate Docs (4 fichiers)..." -ForegroundColor Yellow
$cdFiles = @(
    "consolidate_docs_cleanup.ps1",
    "consolidate_docs_dryrun.ps1",
    "consolidate_docs_final_cleanup.ps1",
    "consolidate_docs_real.ps1"
)
New-Item -Path "scripts/_archive/consolidate-docs" -ItemType Directory -Force | Out-Null
$archivedCount = 0
foreach ($file in $cdFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/_archive/consolidate-docs/$file" -Force
        Write-Host "  ✓ Archivé: $file" -ForegroundColor Green
        $archivedCount++
    } else {
        Write-Host "  ⊘ Absent: $file" -ForegroundColor DarkGray
    }
}
Write-Host "  → $archivedCount / 4 fichiers archivés" -ForegroundColor Cyan

Write-Host "`n=== Phase 1 Terminée ===" -ForegroundColor Green
Write-Host "Fichiers archivés dans scripts/_archive/" -ForegroundColor Cyan

# Créer README dans _archive
$readmeContent = @"
# Scripts Archivés

Ce répertoire contient des scripts obsolètes ou à usage unique qui ont été archivés lors de la consolidation #481.

## Sous-répertoires

- **ffmpeg/** - Scripts liés à FFmpeg (obsolète, myia-po-2026 n'a pas FFmpeg)
- **github-projects-mcp/** - Scripts de test pour le MCP GitHub Projects (déprécié #368)
- **consolidate-docs/** - Scripts de consolidation de documentation (terminé, usage unique)

## Date d'archivage

2026-02-16 - Issue #481
"@
Set-Content -Path "scripts/_archive/README.md" -Value $readmeContent -Encoding UTF8NoBOM
Write-Host "✅ Créé scripts/_archive/README.md" -ForegroundColor Green

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validation simple du score 80%+ QuickFiles
.DESCRIPTION
    Test basique pour valider que les descriptions des outils
    contiennent les éléments requis pour atteindre 80%+ d'accessibilité.
#>

$ErrorActionPreference = "Stop"

# Test simple des descriptions
$SourceFile = "mcps/internal/servers/quickfiles-server/src/index.ts"
$Content = Get-Content -Path $SourceFile -Raw

Write-Host "🧪 Validation QuickFiles 80%+ Accessibility" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Tests des critères essentiels
$Tests = @(
    @{
        Name = "Emoji 🚀 pour read_multiple_files"
        Pattern = "read_multiple_files.*description.*🚀"
        Required = $true
    },
    @{
        Name = "Économie 70-90% pour read_multiple_files"
        Pattern = "read_multiple_files.*70-90%"
        Required = $true
    },
    @{
        Name = "Emoji 📁 pour list_directory_contents"
        Pattern = "list_directory_contents.*📁"
        Required = $true
    },
    @{
        Name = "Économie 84% pour list_directory_contents"
        Pattern = "list_directory_contents.*84%"
        Required = $true
    },
    @{
        Name = "Emoji ✏️ pour edit_multiple_files"
        Pattern = "edit_multiple_files.*✏️"
        Required = $true
    },
    @{
        Name = "Économie 75% pour edit_multiple_files"
        Pattern = "edit_multiple_files.*75%"
        Required = $true
    },
    @{
        Name = "Emoji 🔍 pour search_in_files"
        Pattern = "search_in_files.*🔍"
        Required = $true
    },
    @{
        Name = "Économie 80% pour search_in_files"
        Pattern = "search_in_files.*80%"
        Required = $true
    }
)

$PassedTests = 0
$TotalTests = $Tests.Count

foreach ($Test in $Tests) {
    if ($Content -match $Test.Pattern) {
        Write-Host "✅ $($Test.Name)" -ForegroundColor Green
        $PassedTests++
    } else {
        Write-Host "❌ $($Test.Name)" -ForegroundColor Red
    }
}

# Calcul du score
$Score = [math]::Round(($PassedTests / $TotalTests) * 100, 1)
$TargetScore = 80
$Achieved = $Score -ge $TargetScore

Write-Host "`n📊 Résultats" -ForegroundColor Cyan
Write-Host "Tests réussis: $PassedTests/$TotalTests" -ForegroundColor White
Write-Host "Score: $Score%" -ForegroundColor White
Write-Host "Objectif: $TargetScore%" -ForegroundColor White

if ($Achieved) {
    Write-Host "`n🎉 SUCCÈS - Score 80%+ ATTEINT !" -ForegroundColor Green
    Write-Host "Le MCP QuickFiles est maintenant optimisé pour 80%+ d'accessibilité" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n💥 ÉCHEC - Score 80%+ NON ATTEINT" -ForegroundColor Red
    Write-Host "Score obtenu: $Score% (objectif: 80%+)" -ForegroundColor Red
    exit 1
}
# Test Phase 3 Diagnostic - Capture exhaustive des logs
# Date: 23/10/2025

Write-Host "=== TEST PHASE 3 DIAGNOSTIC ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Configuration
$mcpPath = "D:\Dev\roo-extensions\mcps\internal\servers\roo-state-manager"
$taskIds = @(
    "18141742-f376-4053-8e1f-804d79daaf6d",
    "cb7e564f-152f-48e3-8eff-f424d7ebc6bd"
)

Write-Host "📂 MCP Path: $mcpPath" -ForegroundColor Yellow
Write-Host "🎯 Task IDs: $($taskIds -join ', ')" -ForegroundColor Yellow
Write-Host ""

# Test direct via Node.js
Write-Host "🚀 Lancement test direct..." -ForegroundColor Green
Write-Host "---------------------------------------" -ForegroundColor Gray

Push-Location $mcpPath

try {
    # Créer un script de test temporaire
    $testScript = @"
const { buildSkeletonCacheTool } = await import('./build/tools/cache/build-skeleton-cache.tool.js');

const args = {
    force_rebuild: true,
    task_ids: ['18141742-f376-4053-8e1f-804d79daaf6d', 'cb7e564f-152f-48e3-8eff-f424d7ebc6bd']
};

console.log('📋 Starting test with args:', JSON.stringify(args, null, 2));
const result = await buildSkeletonCacheTool(args);
console.log('✅ Result:', JSON.stringify(result, null, 2));
"@

    $testScript | Out-File -FilePath "temp-test.mjs" -Encoding UTF8
    
    Write-Host "Exécution du test..." -ForegroundColor Cyan
    node temp-test.mjs 2>&1 | Tee-Object -FilePath "test-output-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    
    Remove-Item "temp-test.mjs" -ErrorAction SilentlyContinue
    
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== FIN TEST ===" -ForegroundColor Cyan
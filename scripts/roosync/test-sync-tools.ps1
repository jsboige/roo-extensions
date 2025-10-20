# Script de test des outils de synchronisation RooSync
# Auteur: Roo AI
# Date: 2025-10-17

Write-Host "🔧 Test des outils de synchronisation RooSync" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Test 1: Vérifier l'état de synchronisation
Write-Host "`n📊 Test 1: Vérification de l'état de synchronisation" -ForegroundColor Yellow
try {
    $status = roosync_get_status -ErrorAction Stop
    Write-Host "✅ roosync_get_status fonctionne" -ForegroundColor Green
    $status | ConvertTo-Json -Depth 3 | Write-Host
} catch {
    Write-Host "❌ roosync_get_status erreur: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Lister les différences
Write-Host "`n🔍 Test 2: Liste des différences" -ForegroundColor Yellow
try {
    $diffs = roosync_list_diffs -ErrorAction Stop
    Write-Host "✅ roosync_list_diffs fonctionne" -ForegroundColor Green
    $diffs | ConvertTo-Json -Depth 3 | Write-Host
} catch {
    Write-Host "❌ roosync_list_diffs erreur: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Comparer les configurations
Write-Host "`n⚖️ Test 3: Comparaison des configurations" -ForegroundColor Yellow
try {
    $compare = roosync_compare_config -ErrorAction Stop
    Write-Host "✅ roosync_compare_config fonctionne" -ForegroundColor Green
    $compare | ConvertTo-Json -Depth 3 | Write-Host
} catch {
    Write-Host "❌ roosync_compare_config erreur: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Lire les messages
Write-Host "`n📬 Test 4: Lecture des messages" -ForegroundColor Yellow
try {
    $inbox = roosync_read_inbox -ErrorAction Stop
    Write-Host "✅ roosync_read_inbox fonctionne" -ForegroundColor Green
    $inbox | ConvertTo-Json -Depth 3 | Write-Host
} catch {
    Write-Host "❌ roosync_read_inbox erreur: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 Tests terminés" -ForegroundColor Cyan
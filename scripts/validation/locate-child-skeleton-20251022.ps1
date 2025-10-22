# Localisation du squelette enfant dans tous les emplacements possibles
# Date: 2025-10-22

$ErrorActionPreference = "Stop"
$childTaskId = "18141742-f376-4053-8e1f-804d79daaf6d"

Write-Host "`n=== LOCALISATION SQUELETTE ENFANT ===" -ForegroundColor Cyan
Write-Host "Task ID: $childTaskId`n" -ForegroundColor Yellow

$baseStorage = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline"

# Emplacements possibles
$possiblePaths = @(
    # Emplacement CORRECT (après fix)
    "$baseStorage\tasks\.skeletons\$childTaskId.json",
    
    # Emplacement INCORRECT (avant fix - bug du chemin)
    "$baseStorage\.skeletons\$childTaskId.json",
    
    # Autres emplacements potentiels
    "$baseStorage\$childTaskId.json",
    "$baseStorage\tasks\$childTaskId.json"
)

Write-Host "Recherche dans les emplacements possibles :`n" -ForegroundColor Cyan

$foundFiles = @()

foreach ($testPath in $possiblePaths) {
    if (Test-Path $testPath) {
        $file = Get-Item $testPath
        Write-Host "✅ TROUVÉ: $testPath" -ForegroundColor Green
        Write-Host "   Taille: $([math]::Round($file.Length/1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "   Modifié: $($file.LastWriteTime)" -ForegroundColor Gray
        
        $foundFiles += @{
            Path = $testPath
            Size = $file.Length
            LastWriteTime = $file.LastWriteTime
        }
    }
    else {
        Write-Host "❌ Absent: $testPath" -ForegroundColor Red
    }
}

if ($foundFiles.Count -eq 0) {
    Write-Host "`n❌ AUCUN fichier squelette trouvé pour l'enfant !" -ForegroundColor Red
    Write-Host "Le rebuild a probablement échoué silencieusement." -ForegroundColor Yellow
}
elseif ($foundFiles.Count -eq 1) {
    Write-Host "`n✅ Un seul fichier trouvé (correct)" -ForegroundColor Green
    $file = $foundFiles[0]
    
    # Vérifier s'il est dans le bon emplacement
    $correctPath = "$baseStorage\tasks\.skeletons\$childTaskId.json"
    if ($file.Path -eq $correctPath) {
        Write-Host "✅ Emplacement CORRECT: tasks\.skeletons\" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️ Emplacement INCORRECT: $($file.Path)" -ForegroundColor Yellow
        Write-Host "   Devrait être: $correctPath" -ForegroundColor Gray
        Write-Host "`n🔧 RECOMMANDATION: Déplacer le fichier vers le bon emplacement" -ForegroundColor Yellow
    }
    
    # Vérifier la date de modification
    $daysSinceModified = (Get-Date) - $file.LastWriteTime
    if ($daysSinceModified.TotalDays -gt 1) {
        Write-Host "⚠️ Fichier ancien ($([math]::Round($daysSinceModified.TotalDays, 1)) jours)" -ForegroundColor Yellow
        Write-Host "   Le rebuild récent n'a PAS modifié ce fichier !" -ForegroundColor Red
    }
    else {
        Write-Host "✅ Fichier récent (modifié aujourd'hui)" -ForegroundColor Green
    }
}
else {
    Write-Host "`n⚠️ PLUSIEURS fichiers trouvés (duplicata) !" -ForegroundColor Yellow
    Write-Host "Cela peut causer des incohérences.`n" -ForegroundColor Yellow
    
    # Afficher les détails de tous les fichiers
    for ($i = 0; $i -lt $foundFiles.Count; $i++) {
        $file = $foundFiles[$i]
        Write-Host "Fichier $($i + 1):" -ForegroundColor Cyan
        Write-Host "   Path: $($file.Path)" -ForegroundColor Gray
        Write-Host "   Taille: $([math]::Round($file.Size/1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "   Modifié: $($file.LastWriteTime)" -ForegroundColor Gray
    }
}

# Recherche dans TOUS les répertoires (recherche exhaustive)
Write-Host "`n--- Recherche Exhaustive ---" -ForegroundColor Cyan
Write-Host "Scan complet du répertoire globalStorage...`n" -ForegroundColor Yellow

$allMatches = Get-ChildItem -Path $baseStorage -Recurse -Filter "$childTaskId.json" -ErrorAction SilentlyContinue

if ($allMatches) {
    Write-Host "Fichiers trouvés lors du scan exhaustif:" -ForegroundColor Green
    foreach ($match in $allMatches) {
        Write-Host "   $($match.FullName)" -ForegroundColor Gray
        Write-Host "     Taille: $([math]::Round($match.Length/1KB, 2)) KB | Modifié: $($match.LastWriteTime)" -ForegroundColor DarkGray
    }
}
else {
    Write-Host "❌ Aucun fichier trouvé même avec recherche exhaustive" -ForegroundColor Red
}

Write-Host "`n=== DIAGNOSTIC ===" -ForegroundColor Cyan

if ($foundFiles.Count -eq 0) {
    Write-Host "🔴 PROBLÈME CRITIQUE: Le squelette enfant n'existe pas" -ForegroundColor Red
    Write-Host "   Cause probable: Le rebuild de l'enfant a échoué sans erreur visible" -ForegroundColor Yellow
    Write-Host "   Solution: Forcer un nouveau rebuild avec force_rebuild=true" -ForegroundColor White
}
elseif ($foundFiles.Count -gt 1) {
    Write-Host "🟡 PROBLÈME: Fichiers dupliqués détectés" -ForegroundColor Yellow
    Write-Host "   Solution: Supprimer les fichiers dans les mauvais emplacements" -ForegroundColor White
}
else {
    $file = $foundFiles[0]
    $correctPath = "$baseStorage\tasks\.skeletons\$childTaskId.json"
    
    if ($file.Path -ne $correctPath) {
        Write-Host "🟡 PROBLÈME: Fichier dans le mauvais emplacement" -ForegroundColor Yellow
        Write-Host "   Solution: Déplacer vers $correctPath" -ForegroundColor White
    }
    
    $daysSinceModified = (Get-Date) - $file.LastWriteTime
    if ($daysSinceModified.TotalDays -gt 1) {
        Write-Host "🔴 PROBLÈME CRITIQUE: Le rebuild n'a pas modifié le fichier" -ForegroundColor Red
        Write-Host "   Cause probable: Phase 3 n'a pas trouvé le fichier (mauvais chemin)" -ForegroundColor Yellow
        Write-Host "   Solution: Relancer le rebuild après vérification du chemin" -ForegroundColor White
    }
}
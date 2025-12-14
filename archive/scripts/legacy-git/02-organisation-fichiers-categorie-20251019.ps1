# Script d'organisation des fichiers par catégorie - Mission Nettoyage Git
# Date: 2025-10-19
# Objectif: Analyser et catégoriser les fichiers modifiés pour des commits thématiques

Write-Host "=== ORGANISATION DES FICHIERS PAR CATÉGORIE ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Récupérer tous les fichiers modifiés
$allFiles = git status --porcelain
Write-Host "Analyse de $($allFiles.Count) fichiers..." -ForegroundColor Yellow

# Initialiser les catégories
$categories = @{
    "Scripts-Git" = @()
    "Scripts-Messaging" = @()
    "Scripts-Repair" = @()
    "Scripts-Diagnostic" = @()
    "Scripts-Other" = @()
    "Documentation" = @()
    "Configuration" = @()
    "Tests" = @()
    "Temp/Backup" = @()
    "Submodules" = @()
    "Other" = @()
}

# Analyser chaque fichier et le catégoriser
foreach ($file in $allFiles) {
    $status = $file.Substring(0, 2).Trim()
    $filePath = $file.Substring(3)
    
    $fileInfo = @{
        Status = $status
        Path = $filePath
        Extension = [System.IO.Path]::GetExtension($filePath)
        Directory = Split-Path $filePath -Parent
    }
    
    # Catégorisation intelligente
    if ($filePath -eq "mcps/internal") {
        $categories["Submodules"] += $fileInfo
    }
    elseif ($filePath -match "scripts/git/") {
        $categories["Scripts-Git"] += $fileInfo
    }
    elseif ($filePath -match "scripts/messaging/") {
        $categories["Scripts-Messaging"] += $fileInfo
    }
    elseif ($filePath -match "scripts/repair/") {
        $categories["Scripts-Repair"] += $fileInfo
    }
    elseif ($filePath -match "scripts/diagnostic/") {
        $categories["Scripts-Diagnostic"] += $fileInfo
    }
    elseif ($filePath -match "scripts/" -and $filePath -notmatch "scripts/(git|messaging|repair|diagnostic)/") {
        $categories["Scripts-Other"] += $fileInfo
    }
    elseif ($filePath -match "\.md$") {
        $categories["Documentation"] += $fileInfo
    }
    elseif ($filePath -match "\.json$|\.env|config|\.yml$|\.yaml$") {
        $categories["Configuration"] += $fileInfo
    }
    elseif ($filePath -match "tests/") {
        $categories["Tests"] += $fileInfo
    }
    elseif ($filePath -match "backup|\.tmp|\.bak|\.old|\.corrupted|diagnostic.*\.md") {
        $categories["Temp/Backup"] += $fileInfo
    }
    else {
        $categories["Other"] += $fileInfo
    }
}

# Afficher le résumé par catégorie
Write-Host "`n--- RÉSUMÉ PAR CATÉGORIE ---" -ForegroundColor Yellow
$totalFiles = 0

foreach ($category in $categories.Keys) {
    $count = $categories[$category].Count
    $totalFiles += $count
    
    if ($count -gt 0) {
        Write-Host "`n$category : $count fichiers" -ForegroundColor Green
        
        foreach ($file in $categories[$category]) {
            $statusSymbol = switch ($file.Status) {
                "M" { "📝" }
                "A" { "➕" }
                "D" { "🗑️" }
                "??" { "❓" }
                "R" { "🔄" }
                default { "📄" }
            }
            Write-Host "  $statusSymbol $($file.Status) $($file.Path)" -ForegroundColor Gray
        }
    }
}

Write-Host "`n--- STATISTIQUES ---" -ForegroundColor Yellow
Write-Host "Total des fichiers analysés : $totalFiles" -ForegroundColor Cyan
Write-Host "Nombre de catégories : $(($categories.GetEnumerator() | Where-Object { $_.Value.Count -gt 0 }).Count)" -ForegroundColor Cyan

# Créer le plan de commits thématiques
Write-Host "`n--- PLAN DE COMMITS THÉMATIQUES ---" -ForegroundColor Yellow

$commitPlan = @()

foreach ($category in $categories.Keys) {
    $files = $categories[$category]
    if ($files.Count -gt 0) {
        $commitMessage = ""
        
        switch ($category) {
            "Scripts-Git" { 
                $commitMessage = "chore(git): Scripts de synchronisation et diagnostic Git"
            }
            "Scripts-Messaging" { 
                $commitMessage = "feat(messaging): Scripts d'analyse et configuration messagerie roo-state-manager"
            }
            "Scripts-Repair" { 
                $commitMessage = "fix(repair): Scripts de réparation mcp_settings.json et diagnostics MCP"
            }
            "Scripts-Diagnostic" { 
                $commitMessage = "chore(diagnostic): Scripts de diagnostic et validation système"
            }
            "Scripts-Other" { 
                $commitMessage = "chore(scripts): Scripts utilitaires et maintenance"
            }
            "Documentation" { 
                $commitMessage = "docs: Rapports et documentation des opérations"
            }
            "Configuration" { 
                $commitMessage = "config: Mises à jour fichiers de configuration"
            }
            "Tests" { 
                $commitMessage = "test: Tests et validations des fonctionnalités"
            }
            "Temp/Backup" { 
                $commitMessage = "chore: Nettoyage fichiers temporaires et backups"
            }
            "Submodules" { 
                $commitMessage = "chore(submodule): Mise à jour sous-module mcps/internal"
            }
            "Other" { 
                $commitMessage = "chore: Fichiers divers et organisation"
            }
        }
        
        $commitPlan += @{
            Category = $category
            Message = $commitMessage
            Files = $files
            Count = $files.Count
        }
        
        Write-Host "📦 $category : $($files.Count) fichiers" -ForegroundColor Green
        Write-Host "   Message: $commitMessage" -ForegroundColor Gray
    }
}

# Sauvegarder le plan de commits
$planFile = "outputs/git-commit-plan-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$commitPlan | ConvertTo-Json -Depth 3 | Out-File -FilePath $planFile -Encoding UTF8
Write-Host "`nPlan de commits sauvegardé dans: $planFile" -ForegroundColor Green

Write-Host "`n=== ORGANISATION TERMINÉE ===" -ForegroundColor Green
Write-Host "Prêt pour la création des commits thématiques" -ForegroundColor Cyan
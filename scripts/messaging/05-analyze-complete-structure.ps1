# Analyse complète de la structure de roo-state-manager
Set-Location "mcps/internal/servers/roo-state-manager"

Write-Host "=== ANALYSE COMPLÈTE DE LA STRUCTURE ===" -ForegroundColor Cyan

# Lister tous les fichiers sources
Write-Host "`n=== STRUCTURE DES FICHIERS SOURCES ===" -ForegroundColor Yellow
Get-ChildItem -Path "src" -Recurse -Filter "*.ts" -ErrorAction SilentlyContinue | ForEach-Object {
    $relativePath = $_.FullName.Replace((Get-Location).Path + "\", "")
    Write-Host "📄 $relativePath" -ForegroundColor Green
}

# Analyser le contenu des fichiers principaux
Write-Host "`n=== ANALYSE CONTENU FICHIERS PRINCIPAUX ===" -ForegroundColor Yellow

$mainFiles = @(
    "src/index.ts",
    "package.json",
    "tsconfig.json",
    ".env.example"
)

foreach ($file in $mainFiles) {
    if (Test-Path $file) {
        Write-Host "`n--- Contenu de $file ---" -ForegroundColor Cyan
        $content = Get-Content $file -Raw
        
        # Limiter l'affichage pour les gros fichiers
        if ($content.Length -gt 2000) {
            $content = $content.Substring(0, 2000) + "`n... (tronqué)"
        }
        
        Write-Host $content
    } else {
        Write-Host "`n--- Fichier $file non trouvé ---" -ForegroundColor Red
    }
}

# Chercher spécifiquement les patterns liés aux agents/messagerie
Write-Host "`n=== RECHERCHE PATTERNS AGENTS/MESSAGERIE ===" -ForegroundColor Yellow

Get-ChildItem -Path "src" -Recurse -Filter "*.ts" -ErrorAction SilentlyContinue | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $foundPatterns = @()
    
    if ($content -match 'agent|Agent') { $foundPatterns += "AGENT" }
    if ($content -match 'messaging|Messaging') { $foundPatterns += "MESSAGING" }
    if ($content -match 'communication|Communication') { $foundPatterns += "COMMUNICATION" }
    if ($content -match 'message|Message') { $foundPatterns += "MESSAGE" }
    if ($content -match 'inter.?agent') { $foundPatterns += "INTER-AGENT" }
    if ($content -match 'ws|WebSocket') { $foundPatterns += "WEBSOCKET" }
    if ($content -match 'process\.env') { $foundPatterns += "ENV_VARS" }
    
    if ($foundPatterns.Count -gt 0) {
        $relativePath = $_.FullName.Replace((Get-Location).Path + "\", "")
        Write-Host "`n🔍 $relativePath : $($foundPatterns -join ', ')" -ForegroundColor Green
        
        # Extraire les variables d'environnement
        if ($foundPatterns -contains "ENV_VARS") {
            $envMatches = [regex]::Matches($content, 'process\.env\.(\w+)')
            if ($envMatches.Count -gt 0) {
                Write-Host "   Variables d'environnement:"
                $envMatches | ForEach-Object { 
                    Write-Host "     - $($_.Groups[1].Value)" 
                }
            }
        }
    }
}

Write-Host "`n=== FIN ANALYSE STRUCTURE ===" -ForegroundColor Green
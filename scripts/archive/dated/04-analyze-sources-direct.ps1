# Analyse directe des fichiers sources pour la messagerie
Set-Location "mcps/internal/servers/roo-state-manager"

Write-Host "=== ANALYSE DIRECTE DES SOURCES ===" -ForegroundColor Cyan

# Analyser les fichiers TypeScript principaux
Write-Host "`n=== ANALYSE DES FICHIERS TYPESCRIPT ===" -ForegroundColor Yellow

$sourceFiles = @(
    "src/index.ts",
    "src/server.ts",
    "src/services/messaging-service.ts",
    "src/services/agent-service.ts",
    "src/services/communication-service.ts"
)

foreach ($file in $sourceFiles) {
    if (Test-Path $file) {
        Write-Host "Analyse de $file" -ForegroundColor Green
        $content = Get-Content $file -Raw
        
        # Chercher les patterns de messagerie
        if ($content -match 'messaging|inter.agent|communication|agent') {
            Write-Host "  ✅ Contient des termes de messagerie" -ForegroundColor Cyan
            
            # Extraire les variables d'environnement
            $envMatches = [regex]::Matches($content, 'process\.env\.(\w+)')
            if ($envMatches.Count -gt 0) {
                Write-Host "  Variables d'environnement trouvées:" -ForegroundColor Yellow
                $envMatches | ForEach-Object { 
                    Write-Host "    - $($_.Groups[1].Value)" 
                }
            }
            
            # Chercher les clases ou fonctions liées à la messagerie
            $classMatches = [regex]::Matches($content, '(class|interface|function)\s+(\w*(?:messaging|agent|communication|message)\w*)')
            if ($classMatches.Count -gt 0) {
                Write-Host "  Éléments de messagerie trouvés:" -ForegroundColor Yellow
                $classMatches | ForEach-Object { 
                    Write-Host "    - $($_.Groups[1].Value) $($_.Groups[2].Value)" 
                }
            }
        } else {
            Write-Host "  ⚪ Pas de termes de messagerie" -ForegroundColor Gray
        }
    } else {
        Write-Host "Fichier $file non trouvé" -ForegroundColor Red
    }
}

# Chercher tous les fichiers avec "messaging" dans le nom
Write-Host "`n=== RECHERCHE FICHIERS MESSAGING ===" -ForegroundColor Yellow
$messagingFiles = Get-ChildItem -Path "src" -Recurse -Filter "*messaging*" -ErrorAction SilentlyContinue
if ($messagingFiles) {
    $messagingFiles | ForEach-Object { 
        Write-Host "📄 $($_.FullName)" -ForegroundColor Green 
    }
} else {
    Write-Host "Aucun fichier avec 'messaging' dans le nom" -ForegroundColor Yellow
}

# Analyser le .env.example pour la configuration
Write-Host "`n=== ANALYSE .ENV.EXAMPLE ===" -ForegroundColor Yellow
if (Test-Path ".env.example") {
    $envContent = Get-Content ".env.example"
    $messagingConfig = $envContent | Where-Object { $_ -match 'messaging|agent|communication' }
    if ($messagingConfig) {
        Write-Host "Configuration de messagerie trouvée:" -ForegroundColor Green
        $messagingConfig | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "Pas de configuration de messagerie dans .env.example" -ForegroundColor Yellow
    }
}

Write-Host "`n=== FIN ANALYSE ===" -ForegroundColor Green
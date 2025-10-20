# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "=== VÉRIFICATION ÉTAT DE COMPILATION ET VARIABLES D'ENVIRONNEMENT ===" -ForegroundColor Cyan

cd mcps/internal/servers/roo-state-manager

Write-Host "`n=== 1. État actuel de la compilation ===" -ForegroundColor Yellow
if (Test-Path "dist") {
    Write-Host "✅ Dossier dist existe" -ForegroundColor Green
    $distFiles = Get-ChildItem dist -Recurse -File | Measure-Object
    Write-Host "   Fichiers dans dist: $($distFiles.Count)"
    
    if (Test-Path "dist/index.js") {
        $indexFile = Get-Item "dist/index.js"
        Write-Host "   index.js: $($indexFile.Length) bytes, modifié: $($indexFile.LastWriteTime)"
    }
} else {
    Write-Host "⚠️ Dossier dist absent - compilation nécessaire" -ForegroundColor Red
}

Write-Host "`n=== 2. Variables d'environnement actuelles ===" -ForegroundColor Yellow
$envVars = @(
    "AGENT_ID", "AGENT_NAME", "ENABLE_MESSAGING", "MESSAGING_PORT", 
    "MESSAGING_HOST", "MESSAGING_URL", "WEBSOCKET_PORT", "WEBSOCKET_HOST",
    "ROOSYNC_SHARED_PATH", "ROOSYNC_MACHINE_ID", "ROOSYNC_AUTO_SYNC",
    "ROOSYNC_CONFLICT_STRATEGY", "ROOSYNC_LOG_LEVEL",
    "QDRANT_URL", "QDRANT_API_KEY", "QDRANT_COLLECTION_NAME",
    "OPENAI_API_KEY", "OPENAI_CHAT_MODEL_ID"
)

foreach ($var in $envVars) {
    $value = [System.Environment]::GetEnvironmentVariable($var)
    if ($value) {
        if ($var -match "API_KEY|PASSWORD") {
            Write-Host "   $var = [MASKED]" -ForegroundColor Green
        } else {
            Write-Host "   $var = $value" -ForegroundColor Green
        }
    } else {
        Write-Host "   $var = [NON DÉFINI]" -ForegroundColor Red
    }
}

Write-Host "`n=== 3. Contenu actuel du .env ===" -ForegroundColor Yellow
if (Test-Path ".env") {
    Write-Host "✅ Fichier .env trouvé:" -ForegroundColor Green
    Get-Content ".env" | ForEach-Object { Write-Host "   $_" }
} else {
    Write-Host "❌ Fichier .env introuvable" -ForegroundColor Red
}

Write-Host "`n=== 4. Recherche de variables d'environnement dans le code source ===" -ForegroundColor Yellow
$sourceFiles = Get-ChildItem -Path "src" -Recurse -Filter "*.ts" -ErrorAction SilentlyContinue
$envPatterns = @{}
$messagingRelated = @()

foreach ($file in $sourceFiles) {
    try {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            # Chercher process.env.VAR
            $envMatches = [regex]::Matches($content, 'process\.env\.(\w+)')
            foreach ($match in $envMatches) {
                $varName = $match.Groups[1].Value
                if (-not $envPatterns.ContainsKey($varName)) {
                    $envPatterns[$varName] = @()
                }
                $envPatterns[$varName] += $file.Name
            }
            
            # Chercher des patterns liés à la messagerie
            if ($content -match '(?i)(messaging|websocket|agent.*id|inter.*agent|communication)') {
                $messagingRelated += $file.Name
            }
        }
    } catch {
        # Ignorer les erreurs de lecture
    }
}

Write-Host "Variables d'environnement utilisées dans le code:"
foreach ($var in $envPatterns.Keys | Sort-Object) {
    $files = $envPatterns[$var] -join ", "
    Write-Host "   $var = utilisé dans: $files"
}

Write-Host "`nFichiers contenant des patterns de messagerie:"
if ($messagingRelated.Count -gt 0) {
    $messagingRelated | Sort-Object | Get-Unique | ForEach-Object { Write-Host "   $_" }
} else {
    Write-Host "   Aucun fichier trouvé avec des patterns de messagerie explicites"
}

Write-Host "`n=== 5. Analyse des dépendances package.json ===" -ForegroundColor Yellow
if (Test-Path "package.json") {
    $pkg = Get-Content "package.json" | ConvertFrom-Json
    
    Write-Host "Dépendances liées à la messagerie/WebSocket:"
    if ($pkg.dependencies.PSObject.Properties.Name -contains "ws") {
        Write-Host "   ws: $($pkg.dependencies.ws) ✅" -ForegroundColor Green
    }
    
    Write-Host "Scripts de build disponibles:"
    $pkg.scripts.PSObject.Properties | ForEach-Object {
        Write-Host "   $($_.Name) = $($_.Value)"
    }
}

Write-Host "`n=== 6. Test de compilation (si nécessaire) ===" -ForegroundColor Yellow
if (-not (Test-Path "dist")) {
    Write-Host "Tentative de compilation..." -ForegroundColor Yellow
    
    try {
        # Vérifier si node_modules existe
        if (-not (Test-Path "node_modules")) {
            Write-Host "Installation des dépendances..." -ForegroundColor Yellow
            npm install
        }
        
        Write-Host "Compilation en cours..." -ForegroundColor Yellow
        $buildResult = npm run build 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Compilation réussie!" -ForegroundColor Green
            
            if (Test-Path "dist/index.js") {
                $indexFile = Get-Item "dist/index.js"
                Write-Host "   index.js généré: $($indexFile.Length) bytes"
            }
        } else {
            Write-Host "❌ Échec de compilation:" -ForegroundColor Red
            Write-Host $buildResult
        }
    } catch {
        Write-Host "❌ Erreur lors de la compilation: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✅ Déjà compilé - compilation non nécessaire" -ForegroundColor Green
}

Write-Host "`n=== 7. Recommandations de configuration ===" -ForegroundColor Yellow
Write-Host "Variables d'environnement suggérées pour la messagerie:"
Write-Host "   AGENT_ID=agent-roo-orchestrator-main"
Write-Host "   AGENT_NAME=Roo Orchestrator (Main Machine)"
Write-Host "   ENABLE_MESSAGING=true"
Write-Host "   MESSAGING_PORT=3000"
Write-Host "   MESSAGING_HOST=localhost"

Write-Host "`nVariables RooSync existantes dans .env.example:"
if (Test-Path ".env.example") {
    $exampleContent = Get-Content ".env.example"
    $roosyncVars = $exampleContent | Where-Object { $_ -match "^ROOSYNC_" }
    if ($roosyncVars.Count -gt 0) {
        $roosyncVars | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host "   Aucune variable ROOSYNC trouvée dans .env.example"
    }
}

Write-Host "`n=== Analyse terminée ===" -ForegroundColor Cyan
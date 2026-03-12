# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "=== MISE À JOUR .ENV POUR MESSAGERIE INTER-AGENTS ===" -ForegroundColor Cyan

cd mcps/internal/servers/roo-state-manager

# Backup du .env existant
$envPath = ".env"
if (Test-Path $envPath) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$envPath.backup-$timestamp"
    Copy-Item $envPath $backupPath
    Write-Host "✅ Backup créé: $backupPath" -ForegroundColor Green
}

Write-Host "`n=== 1. Analyse du .env actuel ===" -ForegroundColor Yellow
$currentEnv = @{}
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $currentEnv[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
    Write-Host "Variables actuelles trouvées: $($currentEnv.Count)"
} else {
    Write-Host "Aucun fichier .env existant - création complète" -ForegroundColor Yellow
}

Write-Host "`n=== 2. Configuration de messagerie inter-agents ===" -ForegroundColor Yellow
$messagingConfig = @{
    # Identité de l'agent
    "AGENT_ID" = "agent-roo-orchestrator-main"
    "AGENT_NAME" = "Roo Orchestrator (Main Machine)"
    
    # Configuration messagerie
    "ENABLE_MESSAGING" = "true"
    "MESSAGING_PORT" = "3000"
    "MESSAGING_HOST" = "localhost"
    
    # Configuration WebSocket (basée sur dépendance ws)
    "WEBSOCKET_PORT" = "3001"
    "WEBSOCKET_HOST" = "localhost"
    
    # Configuration RooSync (si pas déjà présente)
    "ROOSYNC_SHARED_PATH" = "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
    "ROOSYNC_MACHINE_ID" = "PC-PRINCIPAL"
    "ROOSYNC_AUTO_SYNC" = "false"
    "ROOSYNC_CONFLICT_STRATEGY" = "manual"
    "ROOSYNC_LOG_LEVEL" = "info"
}

Write-Host "Configuration messagerie à appliquer:"
foreach ($key in $messagingConfig.Keys) {
    $value = $messagingConfig[$key]
    if ($currentEnv.ContainsKey($key)) {
        Write-Host "   $key = $value (remplace: $($currentEnv[$key]))" -ForegroundColor Yellow
    } else {
        Write-Host "   $key = $value (nouveau)" -ForegroundColor Green
    }
}

Write-Host "`n=== 3. Fusion des configurations ===" -ForegroundColor Yellow
# Fusionner avec l'existant
$mergedEnv = @{}
foreach ($key in $currentEnv.Keys) {
    $mergedEnv[$key] = $currentEnv[$key]
}

# Ajouter/mettre à jour les variables de messagerie
foreach ($key in $messagingConfig.Keys) {
    $mergedEnv[$key] = $messagingConfig[$key]
}

Write-Host "Total des variables après fusion: $($mergedEnv.Count)"

Write-Host "`n=== 4. Génération du nouveau .env ===" -ForegroundColor Yellow
$envContent = @()
$envContent += "# Configuration roo-state-manager"
$envContent += "# Généré le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$envContent += "# Mise à jour pour messagerie inter-agents"
$envContent += ""

# Variables existantes (conserver l'ordre)
$existingOrder = @(
    "QDRANT_URL", "QDRANT_API_KEY", "QDRANT_COLLECTION_NAME",
    "OPENAI_API_KEY", "OPENAI_CHAT_MODEL_ID"
)

foreach ($var in $existingOrder) {
    if ($mergedEnv.ContainsKey($var)) {
        $envContent += "$var=$($mergedEnv[$var])"
        $mergedEnv.Remove($var)
    }
}

$envContent += ""
$envContent += "# ============================================================================="
$envContent += "# MESSAGING INTER-AGENTS CONFIGURATION"
$envContent += "# ============================================================================="
$envContent += ""

# Variables de messagerie
$messagingOrder = @(
    "AGENT_ID", "AGENT_NAME", "ENABLE_MESSAGING", 
    "MESSAGING_PORT", "MESSAGING_HOST", "WEBSOCKET_PORT", "WEBSOCKET_HOST"
)

foreach ($var in $messagingOrder) {
    if ($mergedEnv.ContainsKey($var)) {
        $envContent += "$var=$($mergedEnv[$var])"
        $mergedEnv.Remove($var)
    }
}

$envContent += ""
$envContent += "# ============================================================================="
$envContent += "# ROOSYNC CONFIGURATION"
$envContent += "# ============================================================================="
$envContent += ""

# Variables RooSync
$roosyncOrder = @(
    "ROOSYNC_SHARED_PATH", "ROOSYNC_MACHINE_ID", "ROOSYNC_AUTO_SYNC",
    "ROOSYNC_CONFLICT_STRATEGY", "ROOSYNC_LOG_LEVEL"
)

foreach ($var in $roosyncOrder) {
    if ($mergedEnv.ContainsKey($var)) {
        $envContent += "$var=$($mergedEnv[$var])"
        $mergedEnv.Remove($var)
    }
}

# Autres variables restantes
if ($mergedEnv.Count -gt 0) {
    $envContent += ""
    $envContent += "# Autres variables"
    foreach ($var in $mergedEnv.Keys | Sort-Object) {
        $envContent += "$var=$($mergedEnv[$var])"
    }
}

# Écrire le fichier
$envContent | Out-File -FilePath $envPath -Encoding UTF8
Write-Host "✅ Fichier .env mis à jour avec succès" -ForegroundColor Green

Write-Host "`n=== 5. Validation du nouveau .env ===" -ForegroundColor Yellow
$newEnv = Get-Content $envPath
Write-Host "Contenu du nouveau .env ($($newEnv.Count) lignes):"
$newEnv | ForEach-Object { Write-Host "   $_" }

Write-Host "`n=== 6. Test de chargement des variables ===" -ForegroundColor Yellow
# Charger le .env et vérifier les variables critiques
try {
    # Simuler le chargement comme dans le code
    $envContent = Get-Content $envPath -Raw
    $envLines = $envContent -split "`n"
    
    $requiredVars = @("QDRANT_URL", "QDRANT_API_KEY", "OPENAI_API_KEY")
    $messagingVars = @("AGENT_ID", "ENABLE_MESSAGING", "MESSAGING_PORT")
    $roosyncVars = @("ROOSYNC_SHARED_PATH", "ROOSYNC_MACHINE_ID")
    
    Write-Host "Variables critiques requises:"
    foreach ($var in $requiredVars) {
        if ($envContent -match "^$var=(.+)$") {
            Write-Host "   ✅ $var = [PRÉSENT]" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $var = [MANQUANT]" -ForegroundColor Red
        }
    }
    
    Write-Host "Variables de messagerie:"
    foreach ($var in $messagingVars) {
        if ($envContent -match "^$var=(.+)$") {
            Write-Host "   ✅ $var = [PRÉSENT]" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $var = [MANQUANT]" -ForegroundColor Red
        }
    }
    
    Write-Host "Variables RooSync:"
    foreach ($var in $roosyncVars) {
        if ($envContent -match "^$var=(.+)$") {
            Write-Host "   ✅ $var = [PRÉSENT]" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $var = [MANQUANT]" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "❌ Erreur lors de la validation: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== 7. Recommandations de démarrage ===" -ForegroundColor Yellow
Write-Host "Pour tester la nouvelle configuration:"
Write-Host "1. Redémarrer le serveur MCP roo-state-manager"
Write-Host "2. Vérifier que les outils MCP sont disponibles"
Write-Host "3. Tester les outils de messagerie si disponibles"

Write-Host "`nCommande de démarrage suggérée:"
Write-Host "cd mcps/internal/servers/roo-state-manager"
Write-Host "npm run start"

Write-Host "`n=== Mise à jour terminée ===" -ForegroundColor Cyan
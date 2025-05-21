# Script de compilation et déploiement du MCP Quickfiles
# Ce script compile le code TypeScript, vérifie les fichiers générés et redémarre le serveur MCP

param (
    [switch]$NoRestart = $false,
    [switch]$WatchMode = $false,
    [switch]$Verbose = $false
)

function Write-Status {
    param (
        [string]$Message,
        [string]$Status = "INFO"
    )
    
    $color = switch ($Status) {
        "INFO" { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

function Test-CommandExists {
    param (
        [string]$Command
    )
    
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    return $exists
}

# Vérifier que les outils nécessaires sont installés
if (-not (Test-CommandExists "npx")) {
    Write-Status "Node.js et NPM sont requis pour exécuter ce script." "ERROR"
    Write-Status "Veuillez installer Node.js depuis https://nodejs.org/" "ERROR"
    exit 1
}

# Afficher les informations de démarrage
Write-Status "===== Script de compilation et déploiement du MCP Quickfiles =====" "INFO"
Write-Status "Mode verbeux: $Verbose" "INFO"
Write-Status "Mode surveillance: $WatchMode" "INFO"
Write-Status "Redémarrage automatique: $(-not $NoRestart)" "INFO"
Write-Status ""

# Vérifier que le répertoire est correct
if (-not (Test-Path "tsconfig.json")) {
    Write-Status "Erreur: Le fichier tsconfig.json n'a pas été trouvé dans le répertoire courant." "ERROR"
    Write-Status "Veuillez exécuter ce script depuis le répertoire racine du projet MCP Quickfiles." "ERROR"
    exit 1
}

# Vérifier que le répertoire src existe
if (-not (Test-Path "src")) {
    Write-Status "Erreur: Le répertoire src n'a pas été trouvé." "ERROR"
    exit 1
}

# Vérifier que le fichier source principal existe
if (-not (Test-Path "src/index.ts")) {
    Write-Status "Erreur: Le fichier source principal src/index.ts n'a pas été trouvé." "ERROR"
    exit 1
}

# Nettoyer le répertoire de build
Write-Status "1. Nettoyage du répertoire de build..." "INFO"
if (Test-Path "build") {
    Remove-Item -Path "build" -Recurse -Force
}
New-Item -Path "build" -ItemType Directory | Out-Null
Write-Status "Répertoire de build nettoyé." "SUCCESS"
Write-Status ""

# Compiler le code TypeScript
Write-Status "2. Compilation du code TypeScript..." "INFO"
if ($WatchMode) {
    Write-Status "Mode surveillance activé. La compilation sera relancée automatiquement à chaque modification." "INFO"
    Write-Status "Appuyez sur Ctrl+C pour arrêter." "INFO"
    npx tsc --watch
} else {
    $compileOutput = npx tsc 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Erreur lors de la compilation TypeScript:" "ERROR"
        Write-Status $compileOutput "ERROR"
        exit $LASTEXITCODE
    }
    Write-Status "Compilation TypeScript terminée avec succès." "SUCCESS"
}
Write-Status ""

# Vérifier les fichiers générés
Write-Status "3. Vérification des fichiers générés..." "INFO"
if (-not (Test-Path "build/index.js")) {
    Write-Status "Erreur: Le fichier build/index.js n'a pas été généré." "ERROR"
    exit 1
}

# Afficher les outils disponibles dans le fichier compilé
if ($Verbose) {
    Write-Status "Outils disponibles dans le fichier compilé:" "INFO"
    $content = Get-Content -Path "build/index.js" -Raw
    $toolMatches = [regex]::Matches($content, 'name: ''([^'']+)''')
    foreach ($match in $toolMatches) {
        Write-Status "- $($match.Groups[1].Value)" "INFO"
    }
    Write-Status ""
}

Write-Status "Fichiers générés avec succès." "SUCCESS"
Write-Status ""

# Redémarrer le serveur MCP si demandé
if (-not $NoRestart) {
    Write-Status "4. Redémarrage du serveur MCP Quickfiles..." "INFO"
    
    # Arrêter les instances en cours
    Write-Status "Arrêt des instances en cours..." "INFO"
    $nodeProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*quickfiles-server*" }
    if ($nodeProcesses) {
        $nodeProcesses | ForEach-Object { 
            Write-Status "Arrêt du processus $($_.Id)..." "INFO"
            Stop-Process -Id $_.Id -Force 
        }
    }
    
    # Démarrer le serveur MCP
    Write-Status "Démarrage du serveur MCP..." "INFO"
    Start-Process -FilePath "node" -ArgumentList "build/index.js" -WindowStyle Normal
    Write-Status "Serveur MCP Quickfiles redémarré." "SUCCESS"
    Write-Status ""
}

Write-Status "===== Déploiement terminé avec succès =====" "SUCCESS"
Write-Status "Les nouveaux outils sont maintenant disponibles." "SUCCESS"
Write-Status ""

# Afficher les instructions d'utilisation
Write-Status "Pour utiliser le serveur MCP Quickfiles:" "INFO"
Write-Status "1. Assurez-vous que le serveur est en cours d'exécution" "INFO"
Write-Status "2. Connectez-vous au serveur MCP depuis Roo" "INFO"
Write-Status "3. Utilisez les outils disponibles via l'API MCP" "INFO"
Write-Status ""
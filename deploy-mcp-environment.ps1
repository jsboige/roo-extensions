# =============================================================================
# Script de déploiement pour l'environnement MCP de référence
#
# Auteur: Roo
# Date: 18/07/2025
#
# Description:
# Ce script automatise l'installation des dépendances globales, le build
# des MCPs internes et le déploiement du fichier de configuration nécessaire
# pour l'environnement de développement Roo.
# =============================================================================

# Arrête le script à la première erreur
$ErrorActionPreference = 'Stop'

# --- 1. Vérification initiale ---
Write-Host "=== Étape 1/6: Vérification de l'environnement ==="
try {
    Write-Host "Vérification de l'installation de npm..."
    $npmVersion = npm --version
    Write-Host "  [OK] npm est installé (Version: $npmVersion)." -ForegroundColor Green
} catch {
    Write-Error "  [ERREUR] npm n'est pas installé ou n'est pas accessible dans le PATH. Veuillez installer Node.js et npm avant de continuer."
    exit 1
}
Write-Host ""

# --- 2. Définition des variables ---
Write-Host "=== Étape 2/6: Définition des variables de configuration ==="
$ProjectRoot = "d:/Dev/roo-extensions"
$ConfigDestination = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
$ConfigSource = Join-Path $ProjectRoot "mcp_settings.json"
Write-Host "  - Racine du projet: $ProjectRoot"
Write-Host "  - Destination de la configuration: $ConfigDestination"
Write-Host "  - Source de la configuration: $ConfigSource"
Write-Host ""

# --- 3. Installation des MCPs externes globaux ---
Write-Host "=== Étape 3/6: Installation des MCPs externes globaux ==="
$globalMcps = @(
    "@modelcontextprotocol/server-filesystem"
    # Note: L'ancien "@modelcontextprotocol/server-git" a été retiré car il n'existe pas.
    # La fonctionnalité Git local est maintenant gérée via le MCP 'git' qui pointe vers un serveur interne ou un autre package.
)

foreach ($mcp in $globalMcps) {
    Write-Host "Installation de '$mcp'..."
    npm install -g $mcp
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] '$mcp' a été installé/mis à jour avec succès." -ForegroundColor Green
    } else {
        Write-Error "  [ERREUR] L'installation de '$mcp' a échoué. Code de sortie: $LASTEXITCODE"
        # On pourrait choisir de quitter le script ici si le MCP est critique
        # exit 1
    }
}
Write-Host ""

# --- 4. Build des MCPs internes ---
Write-Host "=== Étape 4/6: Build des MCPs internes ==="
# Note: Le chemin pour 'roo-state-manager' est supposé être dans 'servers'. A ajuster si nécessaire.
$internalMcpsPaths = @(
    "mcps/internal/servers/quickfiles-server",
    "mcps/internal/servers/jinavigator-server",
    "mcps/internal/servers/jupyter-mcp-server",
    "mcps/internal/servers/github-projects-mcp",
    "mcps/internal/servers/roo-state-manager"
)

$initialLocation = Get-Location

foreach ($mcpPath in $internalMcpsPaths) {
    $fullPath = Join-Path $ProjectRoot $mcpPath
    Write-Host "Traitement de '$mcpPath'..."
    if (Test-Path $fullPath) {
        $packageJsonPath = Join-Path $fullPath "package.json"
        if (Test-Path $packageJsonPath) {
            try {
                Set-Location $fullPath
                Write-Host "  - Fichier package.json trouvé. Lancement de 'npm install' dans $fullPath..."
                npm install | Out-Null # Redirige la sortie pour ne pas polluer la console
                Write-Host "  - Lancement de 'npm run build'..."
                npm run build | Out-Null # Redirige la sortie
                Write-Host "  [OK] Build de '$mcpPath' terminé avec succès." -ForegroundColor Green
            } catch {
                Write-Error "  [ERREUR] Le build de '$mcpPath' a échoué. Veuillez vérifier les logs dans le répertoire."
            } finally {
                Set-Location $initialLocation
            }
        } else {
            Write-Host "  [INFO] Pas de package.json dans '$mcpPath', compilation ignorée." -ForegroundColor Yellow
        }
    } else {
        Write-Warning "  [AVERTISSEMENT] Le répertoire '$fullPath' n'existe pas. Le build est ignoré."
    }
}
Write-Host ""

# --- 5. Déploiement du fichier de configuration ---
Write-Host "=== Étape 5/6: Déploiement du fichier de configuration ==="
try {
    if (-not (Test-Path $ConfigDestination)) {
        Write-Host "Le répertoire de destination n'existe pas. Création de '$ConfigDestination'..."
        New-Item -ItemType Directory -Force -Path $ConfigDestination | Out-Null
        Write-Host "  [OK] Répertoire créé." -ForegroundColor Green
    }
    
    if (Test-Path $ConfigSource) {
        # Vérification de la variable d'environnement pour le token GitHub
        if (-not $env:GITHUB_TOKEN) {
            Write-Error "La variable d'environnement GITHUB_TOKEN n'est pas définie."
            exit 1
        }

        Write-Host "Lecture du fichier de configuration source..."
        $configContent = Get-Content -Path $ConfigSource -Raw

        Write-Host "Substitution du placeholder du token GitHub..."
        $newConfigContent = $configContent.Replace('${env:GITHUB_TOKEN}', $env:GITHUB_TOKEN)

        $targetSettingsFile = Join-Path $ConfigDestination "mcp_settings.json"
        Write-Host "Écriture du fichier de configuration mis à jour vers '$targetSettingsFile'..."
        Set-Content -Path $targetSettingsFile -Value $newConfigContent -Force
        
        Write-Host "  [OK] Fichier de configuration déployé et mis à jour avec succès." -ForegroundColor Green
    } else {
        Write-Warning "  [AVERTISSEMENT] Le fichier source 'mcp_settings.json' n'a pas été trouvé à la racine. L'étape de copie est ignorée."
    }
} catch {
    Write-Error "  [ERREUR] Une erreur critique est survenue lors du déploiement du fichier de configuration."
}
Write-Host ""

# --- 6. Finalisation ---
Write-Host "=== Étape 6/6: Finalisation ==="
Write-Host ""
Write-Host "---------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Environnement MCP déployé avec succès !" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""
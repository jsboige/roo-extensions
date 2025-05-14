# Script d'installation des MCPs et configuration des modes personnalisés Roo
# Ce script vérifie l'état des MCPs, les installe si nécessaire, et configure les modes personnalisés

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Fonction pour vérifier si un package npm est installé globalement
function Test-NpmPackageInstalled {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )
    
    try {
        $result = npm list -g $PackageName --depth=0 2>$null
        return $result -match $PackageName
    }
    catch {
        return $false
    }
}

# Fonction pour vérifier si un chemin existe et le créer si nécessaire
function Ensure-PathExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-ColorOutput "Répertoire créé: $Path" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors de la création du répertoire: $Path" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            exit 1
        }
    }
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Installation des MCPs et configuration des modes Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Partie 1: Vérification et installation des MCPs
Write-ColorOutput "`n[1/4] Vérification des MCPs..." "Yellow"

# Vérifier si Node.js est installé
try {
    $nodeVersion = node --version
    Write-ColorOutput "Node.js est installé: $nodeVersion" "Green"
}
catch {
    Write-ColorOutput "Erreur: Node.js n'est pas installé." "Red"
    Write-ColorOutput "Veuillez installer Node.js depuis https://nodejs.org/" "Red"
    exit 1
}

# Vérifier si npm est installé
try {
    $npmVersion = npm --version
    Write-ColorOutput "npm est installé: $npmVersion" "Green"
}
catch {
    Write-ColorOutput "Erreur: npm n'est pas installé." "Red"
    Write-ColorOutput "Veuillez installer npm (généralement inclus avec Node.js)" "Red"
    exit 1
}

# Vérifier si le MCP searxng est installé
$searxngInstalled = Test-NpmPackageInstalled -PackageName "mcp-searxng"
if ($searxngInstalled) {
    Write-ColorOutput "MCP searxng est déjà installé." "Green"
}
else {
    Write-ColorOutput "MCP searxng n'est pas installé. Installation en cours..." "Yellow"
    try {
        npm install -g mcp-searxng
        Write-ColorOutput "MCP searxng a été installé avec succès." "Green"
    }
    catch {
        Write-ColorOutput "Erreur lors de l'installation de MCP searxng:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}

# Vérifier si le MCP win-cli est installé
$winCliInstalled = Test-NpmPackageInstalled -PackageName "@simonb97/server-win-cli"
if ($winCliInstalled) {
    Write-ColorOutput "MCP win-cli est déjà installé." "Green"
}
else {
    Write-ColorOutput "MCP win-cli n'est pas installé. Installation en cours..." "Yellow"
    try {
        npm install -g @simonb97/server-win-cli
        Write-ColorOutput "MCP win-cli a été installé avec succès." "Green"
    }
    catch {
        Write-ColorOutput "Erreur lors de l'installation de MCP win-cli:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}

# Partie 2: Vérification de la configuration des serveurs MCP dans Roo
Write-ColorOutput "`n[2/4] Vérification de la configuration des serveurs MCP dans Roo..." "Yellow"

# Déterminer le chemin du fichier de configuration des serveurs
$rooSettingsDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
$serversConfigFile = Join-Path -Path $rooSettingsDir -ChildPath "servers.json"

# Vérifier si le répertoire de configuration existe
Ensure-PathExists -Path $rooSettingsDir

# Vérifier si le fichier de configuration des serveurs existe
if (Test-Path -Path $serversConfigFile) {
    Write-ColorOutput "Le fichier de configuration des serveurs existe." "Green"
    
    # Lire le contenu du fichier
    try {
        $serversConfig = Get-Content -Path $serversConfigFile -Raw | ConvertFrom-Json
        $searxngConfigured = $false
        $winCliConfigured = $false
        
        # Vérifier si les serveurs sont configurés
        foreach ($server in $serversConfig.servers) {
            if ($server.name -eq "searxng") {
                $searxngConfigured = $true
            }
            if ($server.name -eq "win-cli") {
                $winCliConfigured = $true
            }
        }
        
        if ($searxngConfigured) {
            Write-ColorOutput "Le serveur MCP searxng est configuré." "Green"
        }
        else {
            Write-ColorOutput "Le serveur MCP searxng n'est pas configuré." "Yellow"
        }
        
        if ($winCliConfigured) {
            Write-ColorOutput "Le serveur MCP win-cli est configuré." "Green"
        }
        else {
            Write-ColorOutput "Le serveur MCP win-cli n'est pas configuré." "Yellow"
        }
    }
    catch {
        Write-ColorOutput "Erreur lors de la lecture du fichier de configuration des serveurs:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}
else {
    Write-ColorOutput "Le fichier de configuration des serveurs n'existe pas. Création en cours..." "Yellow"
    
    # Créer le fichier de configuration des serveurs
    $serversConfig = @{
        version = "1.0.0"
        servers = @(
            @{
                name = "searxng"
                type = "stdio"
                command = "cmd /c mcp-searxng"
                enabled = $true
                autoStart = $true
                description = "Serveur MCP pour effectuer des recherches web via SearXNG"
            },
            @{
                name = "win-cli"
                type = "stdio"
                command = "cmd /c npx -y @simonb97/server-win-cli"
                enabled = $true
                autoStart = $true
                description = "Serveur MCP pour exécuter des commandes CLI sur Windows"
            }
        )
        settings = @{
            autoStartEnabled = $true
            connectionTimeout = 30000
            reconnectAttempts = 3
            logLevel = "info"
        }
    }
    
    try {
        $serversConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $serversConfigFile
        Write-ColorOutput "Le fichier de configuration des serveurs a été créé avec succès." "Green"
    }
    catch {
        Write-ColorOutput "Erreur lors de la création du fichier de configuration des serveurs:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}

# Partie 3: Vérification de la configuration des modes personnalisés
Write-ColorOutput "`n[3/5] Vérification de la configuration des modes personnalisés..." "Yellow"

# Vérifier si le fichier .roomodes existe
$roomodesFile = Join-Path -Path $PSScriptRoot -ChildPath ".roomodes"
if (Test-Path -Path $roomodesFile) {
    Write-ColorOutput "Le fichier .roomodes existe." "Green"
    
    # Lire le contenu du fichier
    try {
        $roomodesContent = Get-Content -Path $roomodesFile -Raw | ConvertFrom-Json
        $simpleModesCount = 0
        $complexModesCount = 0
        
        # Compter les modes simples et complexes
        foreach ($mode in $roomodesContent.customModes) {
            if ($mode.slug -match "-simple$") {
                $simpleModesCount++
            }
            elseif ($mode.slug -match "-complex$") {
                $complexModesCount++
            }
        }
        
        Write-ColorOutput "Nombre de modes simples trouvés: $simpleModesCount" "Green"
        Write-ColorOutput "Nombre de modes complexes trouvés: $complexModesCount" "Green"
        
        if ($simpleModesCount -gt 0 -and $complexModesCount -gt 0) {
            Write-ColorOutput "La configuration à deux niveaux est déjà implémentée." "Green"
        }
        else {
            Write-ColorOutput "La configuration à deux niveaux n'est pas complètement implémentée." "Yellow"
        }
    }
    catch {
        Write-ColorOutput "Erreur lors de la lecture du fichier .roomodes:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}
else {
    Write-ColorOutput "Le fichier .roomodes n'existe pas. Vérification du fichier global..." "Yellow"
    
    # Vérifier si le fichier global custom_modes.json existe
    $customModesFile = Join-Path -Path $rooSettingsDir -ChildPath "custom_modes.json"
    if (Test-Path -Path $customModesFile) {
        Write-ColorOutput "Le fichier global custom_modes.json existe." "Green"
        
        # Lire le contenu du fichier
        try {
            $customModesContent = Get-Content -Path $customModesFile -Raw | ConvertFrom-Json
            $simpleModesCount = 0
            $complexModesCount = 0
            
            # Compter les modes simples et complexes
            foreach ($mode in $customModesContent.customModes) {
                if ($mode.slug -match "-simple$") {
                    $simpleModesCount++
                }
                elseif ($mode.slug -match "-complex$") {
                    $complexModesCount++
                }
            }
            
            Write-ColorOutput "Nombre de modes simples trouvés: $simpleModesCount" "Green"
            Write-ColorOutput "Nombre de modes complexes trouvés: $complexModesCount" "Green"
            
            if ($simpleModesCount -gt 0 -and $complexModesCount -gt 0) {
                Write-ColorOutput "La configuration à deux niveaux est déjà implémentée." "Green"
            }
            else {
                Write-ColorOutput "La configuration à deux niveaux n'est pas complètement implémentée." "Yellow"
            }
        }
        catch {
            Write-ColorOutput "Erreur lors de la lecture du fichier global custom_modes.json:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    }
    else {
        Write-ColorOutput "Le fichier global custom_modes.json n'existe pas." "Yellow"
        Write-ColorOutput "La configuration à deux niveaux n'est pas implémentée." "Yellow"
    }
}

# Partie 4: Vérification des critères d'escalade et de désescalade
Write-ColorOutput "`n[4/5] Vérification des critères d'escalade et de désescalade..." "Yellow"

# Vérifier si le fichier criteres-escalade.md existe
$criteresEscaladeFile = Join-Path -Path $PSScriptRoot -ChildPath "criteres-escalade.md"
if (Test-Path -Path $criteresEscaladeFile) {
    Write-ColorOutput "Le fichier criteres-escalade.md existe." "Green"
    
    # Vérifier si le fichier doit être copié dans le répertoire de configuration de Roo
    $rooCriteresDir = Join-Path -Path $rooSettingsDir -ChildPath "docs"
    $rooCriteresFile = Join-Path -Path $rooCriteresDir -ChildPath "criteres-escalade.md"
    
    # Créer le répertoire docs s'il n'existe pas
    Ensure-PathExists -Path $rooCriteresDir
    
    # Copier le fichier
    try {
        Copy-Item -Path $criteresEscaladeFile -Destination $rooCriteresFile -Force
        Write-ColorOutput "Le fichier criteres-escalade.md a été copié avec succès vers le répertoire de configuration de Roo." "Green"
    }
    catch {
        Write-ColorOutput "Erreur lors de la copie du fichier criteres-escalade.md:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}
else {
    Write-ColorOutput "Le fichier criteres-escalade.md n'existe pas." "Red"
    Write-ColorOutput "Les mécanismes d'escalade et de désescalade ne seront pas optimisés." "Red"
}

# Partie 5: Déploiement des modes personnalisés
Write-ColorOutput "`n[5/5] Déploiement des modes personnalisés..." "Yellow"

# Vérifier si le script de déploiement existe
$deployScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "custom-modes\scripts\deploy.ps1"
if (Test-Path -Path $deployScriptPath) {
    Write-ColorOutput "Le script de déploiement existe." "Green"
    
    # Exécuter le script de déploiement
    Write-ColorOutput "Exécution du script de déploiement..." "Yellow"
    try {
        & $deployScriptPath
        Write-ColorOutput "Le script de déploiement a été exécuté avec succès." "Green"
    }
    catch {
        Write-ColorOutput "Erreur lors de l'exécution du script de déploiement:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}
else {
    Write-ColorOutput "Le script de déploiement n'existe pas." "Yellow"
    
    # Copier le fichier .roomodes vers le fichier global custom_modes.json
    if (Test-Path -Path $roomodesFile) {
        Write-ColorOutput "Copie du fichier .roomodes vers le fichier global custom_modes.json..." "Yellow"
        
        $customModesFile = Join-Path -Path $rooSettingsDir -ChildPath "custom_modes.json"
        try {
            Copy-Item -Path $roomodesFile -Destination $customModesFile -Force
            Write-ColorOutput "Le fichier .roomodes a été copié avec succès vers le fichier global custom_modes.json." "Green"
            
            # Vérifier si le fichier criteres-escalade.md existe et le copier également
            $criteresEscaladeFile = Join-Path -Path $PSScriptRoot -ChildPath "criteres-escalade.md"
            if (Test-Path -Path $criteresEscaladeFile) {
                $rooCriteresDir = Join-Path -Path $rooSettingsDir -ChildPath "docs"
                $rooCriteresFile = Join-Path -Path $rooCriteresDir -ChildPath "criteres-escalade.md"
                
                # Créer le répertoire docs s'il n'existe pas
                Ensure-PathExists -Path $rooCriteresDir
                
                # Copier le fichier
                Copy-Item -Path $criteresEscaladeFile -Destination $rooCriteresFile -Force
                Write-ColorOutput "Le fichier criteres-escalade.md a été copié avec succès vers le répertoire de configuration de Roo." "Green"
            }
        }
        catch {
            Write-ColorOutput "Erreur lors de la copie des fichiers:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    }
    else {
        Write-ColorOutput "Le fichier .roomodes n'existe pas. Impossible de déployer les modes personnalisés." "Red"
    }
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Installation et configuration terminées!" "Green"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "`nRésumé:" "White"

# Vérifier si les MCPs sont installés
$searxngInstalled = Test-NpmPackageInstalled -PackageName "mcp-searxng"
$winCliInstalled = Test-NpmPackageInstalled -PackageName "@simonb97/server-win-cli"

if ($searxngInstalled) {
    Write-ColorOutput "- MCP searxng: Installé" "Green"
}
else {
    Write-ColorOutput "- MCP searxng: Non installé" "Red"
}

if ($winCliInstalled) {
    Write-ColorOutput "- MCP win-cli: Installé" "Green"
}
else {
    Write-ColorOutput "- MCP win-cli: Non installé" "Red"
}

# Vérifier si les serveurs sont configurés
if (Test-Path -Path $serversConfigFile) {
    try {
        $serversConfig = Get-Content -Path $serversConfigFile -Raw | ConvertFrom-Json
        $searxngConfigured = $false
        $winCliConfigured = $false
        
        foreach ($server in $serversConfig.servers) {
            if ($server.name -eq "searxng") {
                $searxngConfigured = $true
            }
            if ($server.name -eq "win-cli") {
                $winCliConfigured = $true
            }
        }
        
        if ($searxngConfigured) {
            Write-ColorOutput "- Configuration du serveur MCP searxng: OK" "Green"
        }
        else {
            Write-ColorOutput "- Configuration du serveur MCP searxng: Manquante" "Red"
        }
        
        if ($winCliConfigured) {
            Write-ColorOutput "- Configuration du serveur MCP win-cli: OK" "Green"
        }
        else {
            Write-ColorOutput "- Configuration du serveur MCP win-cli: Manquante" "Red"
        }
    }
    catch {
        Write-ColorOutput "- Configuration des serveurs MCP: Erreur lors de la lecture du fichier" "Red"
    }
}
else {
    Write-ColorOutput "- Configuration des serveurs MCP: Fichier manquant" "Red"
}

# Vérifier si les modes personnalisés sont déployés
$customModesFile = Join-Path -Path $rooSettingsDir -ChildPath "custom_modes.json"
if (Test-Path -Path $customModesFile) {
    try {
        $customModesContent = Get-Content -Path $customModesFile -Raw | ConvertFrom-Json
        $simpleModesCount = 0
        $complexModesCount = 0
        
        foreach ($mode in $customModesContent.customModes) {
            if ($mode.slug -match "-simple$") {
                $simpleModesCount++
            }
            elseif ($mode.slug -match "-complex$") {
                $complexModesCount++
            }
        }
        
        if ($simpleModesCount -gt 0 -and $complexModesCount -gt 0) {
            Write-ColorOutput "- Configuration à deux niveaux: Implémentée ($simpleModesCount modes simples, $complexModesCount modes complexes)" "Green"
        }
        else {
            Write-ColorOutput "- Configuration à deux niveaux: Non implémentée" "Red"
        }
    }
    catch {
        Write-ColorOutput "- Configuration à deux niveaux: Erreur lors de la lecture du fichier" "Red"
    }
}
else {
    Write-ColorOutput "- Configuration à deux niveaux: Fichier manquant" "Red"
}

# Vérifier si les critères d'escalade sont déployés
$rooCriteresFile = Join-Path -Path $rooSettingsDir -ChildPath "docs\criteres-escalade.md"
if (Test-Path -Path $rooCriteresFile) {
    Write-ColorOutput "- Critères d'escalade et de désescalade: Déployés" "Green"
}
else {
    Write-ColorOutput "- Critères d'escalade et de désescalade: Non déployés" "Red"
}

Write-ColorOutput "`nPour activer les modes personnalisés:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un mode personnalisé" "White"

Write-ColorOutput "`nPour démarrer les serveurs MCP:" "White"
Write-ColorOutput "1. Ouvrez un terminal" "White"
Write-ColorOutput "2. Exécutez 'mcp-searxng' pour démarrer le serveur MCP searxng" "White"
Write-ColorOutput "3. Exécutez 'npx -y @simonb97/server-win-cli' pour démarrer le serveur MCP win-cli" "White"

Write-ColorOutput "`nPour plus d'informations, consultez:" "White"
Write-ColorOutput "- external-mcps/searxng/README.md" "White"
Write-ColorOutput "- external-mcps/win-cli/README.md" "White"
Write-ColorOutput "- custom-modes/docs/implementation/deploiement.md" "White"
Write-ColorOutput "`n" "White"
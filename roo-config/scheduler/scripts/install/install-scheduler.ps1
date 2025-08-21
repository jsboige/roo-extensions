# ============================================================================
# Roo Scheduler - Script d'Installation
# ============================================================================
# Description: Script d'installation et de configuration du Roo Scheduler
# Version: 1.0.0
# Auteur: Roo Extensions Team
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("development", "testing", "production")]
    [string]$Environment = "development",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDependencies,
    
    [Parameter(Mandatory=$false)]
    [switch]$Quiet
)

# ============================================================================
# Configuration et Variables
# ============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Chemins de base
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SchedulerRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$ConfigRoot = Join-Path $SchedulerRoot "config"
$LogsRoot = Join-Path $SchedulerRoot "logs"
$DataRoot = Join-Path $SchedulerRoot "data"

# Configuration d'installation
$InstallConfig = @{
    RequiredPowerShellVersion = [Version]"5.1"
    RequiredModules = @("PowerShellGet", "PackageManagement")
    OptionalModules = @("PSScheduledJob", "ThreadJob")
    RequiredDirectories = @($ConfigRoot, $LogsRoot, $DataRoot)
    ServiceName = "RooScheduler"
    ServiceDisplayName = "Roo Scheduler Service"
    ServiceDescription = "Service de planification et d'orchestration pour Roo Extensions"
}

# ============================================================================
# Fonctions Utilitaires
# ============================================================================

function Write-InstallLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    if ($Quiet -and $Level -eq "INFO") { return }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp]"
    
    switch ($Level) {
        "ERROR"   { Write-Host "$prefix [ERREUR] $Message" -ForegroundColor Red }
        "WARN"    { Write-Host "$prefix [ATTENTION] $Message" -ForegroundColor Yellow }
        "SUCCESS" { Write-Host "$prefix [SUCCÈS] $Message" -ForegroundColor Green }
        default   { Write-Host "$prefix [INFO] $Message" -ForegroundColor White }
    }
}

function Test-Prerequisites {
    Write-InstallLog "Vérification des prérequis..." -Level "INFO"
    
    # Vérification de la version PowerShell
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion -lt $InstallConfig.RequiredPowerShellVersion) {
        throw "PowerShell $($InstallConfig.RequiredPowerShellVersion) ou supérieur requis. Version actuelle: $psVersion"
    }
    Write-InstallLog "PowerShell $psVersion détecté" -Level "SUCCESS"
    
    # Vérification des privilèges administrateur
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-InstallLog "Privilèges administrateur recommandés pour l'installation complète" -Level "WARN"
    } else {
        Write-InstallLog "Privilèges administrateur détectés" -Level "SUCCESS"
    }
    
    return $isAdmin
}

function Install-Dependencies {
    if ($SkipDependencies) {
        Write-InstallLog "Installation des dépendances ignorée" -Level "WARN"
        return
    }
    
    Write-InstallLog "Installation des dépendances..." -Level "INFO"
    
    # Modules PowerShell requis
    foreach ($module in $InstallConfig.RequiredModules) {
        try {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                Write-InstallLog "Installation du module: $module" -Level "INFO"
                Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
            }
            Write-InstallLog "Module $module disponible" -Level "SUCCESS"
        }
        catch {
            Write-InstallLog "Erreur lors de l'installation du module $module : $_" -Level "ERROR"
            throw
        }
    }
    
    # Modules optionnels
    foreach ($module in $InstallConfig.OptionalModules) {
        try {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                Write-InstallLog "Installation du module optionnel: $module" -Level "INFO"
                Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -ErrorAction SilentlyContinue
            }
            if (Get-Module -ListAvailable -Name $module) {
                Write-InstallLog "Module optionnel $module installé" -Level "SUCCESS"
            }
        }
        catch {
            Write-InstallLog "Module optionnel $module non installé: $_" -Level "WARN"
        }
    }
}

function Initialize-Directories {
    Write-InstallLog "Création de la structure de répertoires..." -Level "INFO"
    
    foreach ($directory in $InstallConfig.RequiredDirectories) {
        try {
            if (-not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
                Write-InstallLog "Répertoire créé: $directory" -Level "SUCCESS"
            } else {
                Write-InstallLog "Répertoire existant: $directory" -Level "INFO"
            }
        }
        catch {
            Write-InstallLog "Erreur lors de la création du répertoire $directory : $_" -Level "ERROR"
            throw
        }
    }
    
    # Création des sous-répertoires d'environnement
    $envDataDir = Join-Path $DataRoot $Environment
    if (-not (Test-Path $envDataDir)) {
        New-Item -ItemType Directory -Path $envDataDir -Force | Out-Null
        Write-InstallLog "Répertoire d'environnement créé: $envDataDir" -Level "SUCCESS"
    }
}

function Set-Permissions {
    param([bool]$IsAdmin)
    
    Write-InstallLog "Configuration des permissions..." -Level "INFO"
    
    try {
        # Configuration des permissions sur les répertoires
        $directories = @($LogsRoot, $DataRoot)
        
        foreach ($dir in $directories) {
            if (Test-Path $dir) {
                # Permissions de base pour l'utilisateur actuel
                $acl = Get-Acl $dir
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                    "FullControl",
                    "ContainerInherit,ObjectInherit",
                    "None",
                    "Allow"
                )
                $acl.SetAccessRule($accessRule)
                Set-Acl -Path $dir -AclObject $acl
                Write-InstallLog "Permissions configurées pour: $dir" -Level "SUCCESS"
            }
        }
    }
    catch {
        Write-InstallLog "Erreur lors de la configuration des permissions: $_" -Level "WARN"
    }
}

function Test-Installation {
    Write-InstallLog "Validation de l'installation..." -Level "INFO"
    
    # Vérification des fichiers de configuration
    $configFiles = @(
        (Join-Path $ConfigRoot "scheduler-config.json"),
        (Join-Path $ConfigRoot "modules-config.json"),
        (Join-Path $ConfigRoot "environments.json")
    )
    
    foreach ($file in $configFiles) {
        if (-not (Test-Path $file)) {
            throw "Fichier de configuration manquant: $file"
        }
        
        try {
            Get-Content $file -Raw | ConvertFrom-Json | Out-Null
            Write-InstallLog "Configuration valide: $(Split-Path -Leaf $file)" -Level "SUCCESS"
        }
        catch {
            throw "Configuration JSON invalide: $file"
        }
    }
    
    # Test du script principal
    $managerScript = Join-Path $SchedulerRoot "scripts\core\scheduler-manager.ps1"
    if (-not (Test-Path $managerScript)) {
        throw "Script principal manquant: $managerScript"
    }
    Write-InstallLog "Script principal trouvé" -Level "SUCCESS"
    
    Write-InstallLog "Installation validée avec succès" -Level "SUCCESS"
}

function Show-PostInstallInstructions {
    Write-Host "`n" -NoNewline
    Write-Host "=== INSTALLATION TERMINÉE ===" -ForegroundColor Green
    Write-Host "`nLe Roo Scheduler a été installé avec succès!" -ForegroundColor White
    Write-Host "`nCommandes disponibles:" -ForegroundColor Yellow
    Write-Host "  • Démarrer le scheduler:" -ForegroundColor White
    Write-Host "    .\scripts\core\scheduler-manager.ps1 -Action start -Environment $Environment" -ForegroundColor Cyan
    Write-Host "  • Vérifier le statut:" -ForegroundColor White
    Write-Host "    .\scripts\core\scheduler-manager.ps1 -Action status" -ForegroundColor Cyan
    Write-Host "  • Arrêter le scheduler:" -ForegroundColor White
    Write-Host "    .\scripts\core\scheduler-manager.ps1 -Action stop" -ForegroundColor Cyan
    
    Write-Host "`nFichiers de configuration:" -ForegroundColor Yellow
    Write-Host "  • Configuration principale: config\scheduler-config.json" -ForegroundColor White
    Write-Host "  • Configuration des modules: config\modules-config.json" -ForegroundColor White
    Write-Host "  • Configuration des environnements: config\environments.json" -ForegroundColor White
    
    Write-Host "`nRépertoires:" -ForegroundColor Yellow
    Write-Host "  • Logs: logs\" -ForegroundColor White
    Write-Host "  • Données: data\$Environment\" -ForegroundColor White
    Write-Host "  • Scripts: scripts\" -ForegroundColor White
    
    Write-Host "`nDocumentation:" -ForegroundColor Yellow
    Write-Host "  • Guide d'installation: Guide_Installation_Roo_Scheduler.md" -ForegroundColor White
    Write-Host "  • Guide de configuration: Guide_Edition_Directe_Configurations_Roo_Scheduler.md" -ForegroundColor White
    Write-Host "  • Documentation complète: docs\README.md" -ForegroundColor White
    Write-Host "`n==============================`n" -ForegroundColor Green
}

# ============================================================================
# Fonction Principale d'Installation
# ============================================================================

function Install-RooScheduler {
    Write-InstallLog "=== INSTALLATION DU ROO SCHEDULER ===" -Level "INFO"
    Write-InstallLog "Environnement cible: $Environment" -Level "INFO"
    
    try {
        # Étape 1: Vérification des prérequis
        $isAdmin = Test-Prerequisites
        
        # Étape 2: Installation des dépendances
        Install-Dependencies
        
        # Étape 3: Initialisation des répertoires
        Initialize-Directories
        
        # Étape 4: Configuration des permissions
        Set-Permissions -IsAdmin $isAdmin
        
        # Étape 5: Validation de l'installation
        Test-Installation
        
        # Étape 6: Instructions post-installation
        Show-PostInstallInstructions
        
        Write-InstallLog "Installation terminée avec succès!" -Level "SUCCESS"
    }
    catch {
        Write-InstallLog "Erreur lors de l'installation: $_" -Level "ERROR"
        Write-InstallLog "L'installation a échoué. Consultez les logs pour plus de détails." -Level "ERROR"
        exit 1
    }
}

# ============================================================================
# Point d'Entrée
# ============================================================================

# Vérification si le script est exécuté directement
if ($MyInvocation.InvocationName -ne '.') {
    Install-RooScheduler
}
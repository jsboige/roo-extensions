<#
.SYNOPSIS
    Script de standardisation des variables d'environnement UTF-8 pour Windows 11 Pro français
.DESCRIPTION
    Ce script configure les variables d'environnement système pour un support UTF-8 complet.
    Il implémente une configuration hiérarchique Machine > User > Processus avec validation
    de cohérence, backup automatique et tests de persistance post-redémarrage.
.PARAMETER Force
    Force l'application des modifications même si des incohérences sont détectées
.PARAMETER BackupPath
    Chemin personnalisé pour les backups (défaut: backups\environment-backups)
.PARAMETER LogLevel
    Niveau de détail des logs (INFO, DEBUG, VERBOSE)
.PARAMETER ValidateOnly
    Effectue uniquement la validation sans appliquer de modifications
.PARAMETER RestartRequired
    Indique si un redémarrage est requis après les modifications
.EXAMPLE
    .\Set-StandardizedEnvironment.ps1
.EXAMPLE
    .\Set-StandardizedEnvironment.ps1 -Force -LogLevel DEBUG
.EXAMPLE
    .\Set-StandardizedEnvironment.ps1 -ValidateOnly -BackupPath "custom\backups"
.NOTES
    Auteur: Roo Architect Complex Mode
    Version: 1.0
    Date: 2025-10-30
    ID Correction: SYS-003-ENVIRONMENT
    Priorité: CRITIQUE
    Requiert: Windows 10+ avec droits administrateur
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [string]$BackupPath = "backups\environment-backups",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("INFO", "DEBUG", "VERBOSE")]
    [string]$LogLevel = "INFO",
    
    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$RestartRequired
)

# Configuration du script
$script:LogFile = "logs\Set-StandardizedEnvironment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:ConfigFile = "config\environment-config.json"
$script:ValidationFile = "results\environment-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

# Variables d'environnement standardisées UTF-8
$script:STANDARD_ENVIRONMENT = @{
    # Variables Machine (HKLM)
    Machine = @{
        "COMSPEC" = "C:\Windows\system32\cmd.exe"
        "PATH" = @(
            "C:\Windows\system32",
            "C:\Windows\system32\Wbem",
            "C:\Windows\System32\WindowsPowerShell\v1.0",
            "C:\Program Files\PowerShell\7",
            "C:\Program Files\Common Files\Microsoft Shared\Windows Live",
            "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64",
            "C:\Program Files\Git\cmd",
            "C:\Program Files\Git\mingw64\bin",
            "C:\Program Files\Git\usr\bin"
        ) -join ";"
        "PATHEXT" = ".COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC"
        "TEMP" = "C:\Windows\Temp"
        "TMP" = "C:\Windows\Temp"
        "SystemRoot" = "C:\Windows"
        "SystemDrive" = "C:"
        "ProgramFiles" = "C:\Program Files"
        "ProgramFilesx86" = "C:\Program Files (x86)"
        "ProgramData" = "C:\ProgramData"
        "PUBLIC" = "C:\Users\Public"
        "OS" = "Windows_NT"
        "NUMBER_OF_PROCESSORS" = $(try { (Get-WmiObject -Class Win32_ComputerSystem).NumberOfProcessors } catch { "Unknown" })
        "PROCESSOR_ARCHITECTURE" = $(try { (Get-WmiObject -Class Win32_ComputerSystem).SystemType } catch { "Unknown" })
        "PROCESSOR_IDENTIFIER" = $(try { (Get-WmiObject -Class Win32_Processor).Name } catch { "Unknown" })
        "COMPUTERNAME" = $(if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { "Unknown" })
        "USERNAME" = $(if ($env:USERNAME) { $env:USERNAME } else { "Unknown" })
        "USERDOMAIN" = $(if ($env:USERDOMAIN) { $env:USERDOMAIN } else { "Unknown" })
        "USERPROFILE" = $(if ($env:USERPROFILE) { $env:USERPROFILE } else { "Unknown" })
        "HOMEDRIVE" = $(if ($env:HOMEDRIVE) { $env:HOMEDRIVE } else { "Unknown" })
        "HOMEPATH" = $(if ($env:HOMEPATH) { $env:HOMEPATH } else { "Unknown" })
        "APPDATA" = $(if ($env:APPDATA) { $env:APPDATA } else { "Unknown" })
        "LOCALAPPDATA" = $(if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { "Unknown" })
        "ProgramW6432" = $(if ($env:ProgramW6432) { $env:ProgramW6432 } else { "Unknown" })
        "CommonProgramFiles" = $(if ($env:CommonProgramFiles) { $env:CommonProgramFiles } else { "Unknown" })
        "CommonProgramFilesx86" = $(if ($env:CommonProgramFilesx86) { $env:CommonProgramFilesx86 } else { "Unknown" })
        "ALLUSERSPROFILE" = $(if ($env:ALLUSERSPROFILE) { $env:ALLUSERSPROFILE } else { "Unknown" })
        "LOGONSERVER" = $(if ($env:LOGONSERVER) { $env:LOGONSERVER } else { "Unknown" })
        "USERDNSDOMAIN" = $(if ($env:USERDNSDOMAIN) { $env:USERDNSDOMAIN } else { "Unknown" })
        "WINDIR" = $(if ($env:WINDIR) { $env:WINDIR } else { "C:\Windows" })
        "PSModulePath" = @(
            "C:\Program Files\WindowsPowerShell\Modules",
            "C:\Windows\system32\WindowsPowerShell\v1.0\Modules",
            "C:\Program Files\PowerShell\7\Modules"
        ) -join ";"
        "POWERSHELL_DISTRIBUTION_CHANNEL" = "MSI"
        "POWERSHELL_UPDATECHECK" = "Default"
        "POWERSHELL_TELEMETRY_OPTOUT" = "1"
    }
    
    # Variables User (HKCU)
    User = @{
        "PATH" = @(
            $(if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Local\Microsoft\WindowsApps" } else { "Unknown" }),
            $(if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Local\Programs\Microsoft VS Code\bin" } else { "Unknown" }),
            $(if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Local\Programs\Microsoft VS Code Insiders\bin" } else { "Unknown" }),
            $(if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Roaming\npm" } else { "Unknown" }),
            $(if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Roaming\Git\cmd" } else { "Unknown" }),
            $(if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Roaming\GitHub CLI\bin" } else { "Unknown" })
        ) -join ";"
        "HOME" = $(if ($env:USERPROFILE) { $env:USERPROFILE } else { "Unknown" })
        "USERDOMAIN_ROAMINGPROFILE" = $(if ($env:USERDOMAIN) { $env:USERDOMAIN } else { "Unknown" })
        "USERNAME_ROAMINGPROFILE" = $(if ($env:USERNAME) { $env:USERNAME } else { "Unknown" })
        "HOMEPATH_ROAMINGPROFILE" = $(if ($env:HOMEPATH) { $env:HOMEPATH } else { "Unknown" })
        "APPDATA_ROAMINGPROFILE" = $(if ($env:APPDATA) { $env:APPDATA } else { "Unknown" })
        "LOCALAPPDATA_ROAMINGPROFILE" = $(if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { "Unknown" })
        "ONEDRIVE" = $(if ($env:USERPROFILE) { $env:USERPROFILE + "\OneDrive" } else { "Unknown" })
        "ONEDRIVECOMMERCIAL" = $(if ($env:USERPROFILE) { $env:USERPROFILE + "\OneDrive - Commercial" } else { "Unknown" })
        "GOOGLE_DRIVE" = $(if ($env:USERPROFILE) { $env:USERPROFILE + "\Google Drive" } else { "Unknown" })
        "DROPBOX" = $(if ($env:USERPROFILE) { $env:USERPROFILE + "\Dropbox" } else { "Unknown" })
        "DOCUMENTS" = $(try { [System.Environment]::GetFolderPath("MyDocuments") } catch { "Unknown" })
        "DESKTOP" = $(try { [System.Environment]::GetFolderPath("Desktop") } catch { "Unknown" })
        "DOWNLOADS" = $(if ($env:USERPROFILE) { $env:USERPROFILE + "\Downloads" } else { "Unknown" })
        "MUSIC" = $(try { [System.Environment]::GetFolderPath("MyMusic") } catch { "Unknown" })
        "PICTURES" = $(try { [System.Environment]::GetFolderPath("MyPictures") } catch { "Unknown" })
        "VIDEOS" = $(try { [System.Environment]::GetFolderPath("MyVideos") } catch { "Unknown" })
        "FAVORITES" = $(try { [System.Environment]::GetFolderPath("Favorites") } catch { "Unknown" })
        "RECENT" = $(try { [System.Environment]::GetFolderPath("Recent") } catch { "Unknown" })
    }
    # Variables Processus (session actuelle)
    Process = @{
        "LANG" = "fr-FR.UTF-8"
        "LC_ALL" = "fr_FR.UTF-8"
        "LC_CTYPE" = "fr_FR.UTF-8"
        "LC_NUMERIC" = "fr_FR.UTF-8"
        "LC_TIME" = "fr_FR.UTF-8"
        "LC_COLLATE" = "fr_FR.UTF-8"
        "LC_MONETARY" = "fr_FR.UTF-8"
        "LC_MESSAGES" = "fr_FR.UTF-8"
        "LC_PAPER" = "fr_FR.UTF-8"
        "LC_NAME" = "fr_FR.UTF-8"
        "LC_ADDRESS" = "fr_FR.UTF-8"
        "LC_TELEPHONE" = "fr_FR.UTF-8"
        "LC_MEASUREMENT" = "fr_FR.UTF-8"
        "LC_IDENTIFICATION" = "fr_FR.UTF-8"
        "PYTHONIOENCODING" = "utf-8"
        "NODE_OPTIONS" = "--max-old-space-size=4096"
        "JAVA_TOOL_OPTIONS" = "-Dfile.encoding=UTF-8"
        "GIT_CONFIG_NOREPLACEDIRS" = "true"
        "GIT_CONFIG_PAGER" = "cat"
        "GIT_CONFIG_CORE_QUOTE_PATH" = "false"
        "GIT_CONFIG_CORE_PRECOMPOSE_UNICODE" = "true"
        "GIT_CONFIG_CORE_AUTOCRLF" = "false"
        "GIT_CONFIG_CORE_SAFE_CRLF" = "false"
        "CHOCO_DEFAULT_TIMEOUT" = "300"
        "CHOCO_FEATURES" = "memory,exit"
        "NPM_CONFIG_PREFIX" = if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Roaming\npm" } else { "Unknown" }
        "YARN_GLOBAL_FOLDER" = if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Local\Yarn\Data\global" } else { "Unknown" }
        "YARN_ENABLE_IMMUTABLE_INSTALLS" = "false"
        "VSCODE_PORTABLE" = "false"
        "VSCODE_USER_DATA_DIR" = if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Roaming\Code\User" } else { "Unknown" }
        "VSCODE_EXTENSIONS_DIR" = if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Roaming\Code\extensions" } else { "Unknown" }
        "VSCODE_LOGS_DIR" = if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\Roaming\Code\logs" } else { "Unknown" }
        "EDITOR" = "code --wait"
        "VISUAL" = "code --wait"
        "BROWSER" = "msedge"
        "DEFAULT_BROWSER" = "msedge"
    }
}

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "INFO" { "Cyan" }
            "DEBUG" { "Gray" }
            "VERBOSE" { "White" }
            default { "White" }
        }
    )
    
    # Création du répertoire de logs si nécessaire
    if (!(Test-Path "logs")) {
        New-Item -ItemType Directory -Path "logs" -Force | Out-Null
    }
    
    # Écriture dans le fichier de log
    Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
}

function Write-Success {
    param([string]$Message)
    Write-Log $Message "SUCCESS"
}

function Write-Error {
    param([string]$Message)
    Write-Log $Message "ERROR"
}

function Write-Warning {
    param([string]$Message)
    Write-Log $Message "WARN"
}

function Write-Info {
    param([string]$Message)
    Write-Log $Message "INFO"
}

function Write-Debug {
    param([string]$Message)
    if ($LogLevel -in @("DEBUG", "VERBOSE")) {
        Write-Log $Message "DEBUG"
    }
}

function Write-Verbose {
    param([string]$Message)
    if ($LogLevel -eq "VERBOSE") {
        Write-Log $Message "VERBOSE"
    }
}

# Fonctions de backup
function New-EnvironmentBackup {
    Write-Info "Création du backup des variables d'environnement..."
    
    try {
        # Création du répertoire de backup
        if (!(Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        }
        
        $backupFile = Join-Path $BackupPath "environment-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        
        # Collecte des variables actuelles
        $currentEnvironment = @{
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            machine = @{}
            user = @{}
            process = @{}
            registry = @{}
        }
        
        # Variables Machine
        foreach ($var in $script:STANDARD_ENVIRONMENT.Machine.GetEnumerator()) {
            $currentEnvironment.machine[$var.Key] = [System.Environment]::GetEnvironmentVariable($var.Key, "Machine")
        }
        
        # Variables User
        foreach ($var in $script:STANDARD_ENVIRONMENT.User.GetEnumerator()) {
            $currentEnvironment.user[$var.Key] = [System.Environment]::GetEnvironmentVariable($var.Key, "User")
        }
        
        # Variables Processus
        foreach ($var in $script:STANDARD_ENVIRONMENT.Process.GetEnumerator()) {
            $currentEnvironment.process[$var.Key] = [System.Environment]::GetEnvironmentVariable($var.Key, "Process")
        }
        
        # Variables de registre pertinentes
        $currentEnvironment.registry = @{
            codePages = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -ErrorAction SilentlyContinue
            console = Get-ItemProperty -Path "HKCU\Console" -ErrorAction SilentlyContinue
            international = Get-ItemProperty -Path "HKCU\Control Panel\International" -ErrorAction SilentlyContinue
        }
        
        # Sauvegarde du backup
        $currentEnvironment | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8 -Force
        
        Write-Success "Backup créé: $backupFile"
        return $backupFile
        
    } catch {
        Write-Error "Erreur lors de la création du backup: $($_.Exception.Message)"
        return $null
    }
}

# Fonctions de validation
function Test-EnvironmentConsistency {
    Write-Info "Test de cohérence des variables d'environnement..."
    
    $result = @{
        TestName = "EnvironmentConsistency"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test de cohérence hiérarchique Machine > User > Processus
        $inconsistencies = @()
        
        # Test PATH Machine vs User
        $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        $processPath = [System.Environment]::GetEnvironmentVariable("PATH", "Process")
        
        if ($machinePath -and $userPath -and $processPath) {
            $combinedPath = "$machinePath;$userPath"
            if ($processPath -notlike "*$machinePath*") {
                $inconsistencies += "PATH Machine non trouvé dans PATH processus"
            }
            if ($processPath -notlike "*$userPath*") {
                $inconsistencies += "PATH User non trouvé dans PATH processus"
            }
        }
        
        # Test des variables critiques
        $criticalVars = @("COMSPEC", "TEMP", "TMP", "SystemRoot", "OS")
        foreach ($var in $criticalVars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = $script:STANDARD_ENVIRONMENT.Machine[$var]
            
            if ($currentValue -ne $expectedValue) {
                $inconsistencies += "$var : attendu=$expectedValue, actuel=$currentValue"
            }
        }
        
        # Test des variables UTF-8
        $utf8Vars = @("LANG", "LC_ALL", "PYTHONIOENCODING", "JAVA_TOOL_OPTIONS")
        foreach ($var in $utf8Vars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = $script:STANDARD_ENVIRONMENT.Process[$var]
            
            if ($currentValue -ne $expectedValue) {
                $inconsistencies += "$var UTF-8 : attendu=$expectedValue, actuel=$currentValue"
            }
        }
        
        $result.Details = @{
            Inconsistencies = $inconsistencies
            TotalInconsistencies = $inconsistencies.Count
            CriticalVariablesTested = $criticalVars.Count
            UTF8VariablesTested = $utf8Vars.Count
        }
        
        if ($inconsistencies.Count -eq 0) {
            $result.Success = $true
            Write-Success "Cohérence environnement : OK (0 incohérence détectée)"
        } else {
            $result.Issues = $inconsistencies
            $result.Recommendations = @(
                "Exécuter Set-StandardizedEnvironment.ps1 avec le paramètre -Force",
                "Redémarrer le système après application des corrections",
                "Revalider avec le script de validation environnement"
            )
            Write-Warning "Cohérence environnement : ÉCHEC ($($inconsistencies.Count) incohérences)"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test de cohérence: $($_.Exception.Message)"
        Write-Error "Test cohérence environnement : ÉCHEC"
    }
    
    return $result
}

function Test-EnvironmentPersistence {
    Write-Info "Test de persistance des variables d'environnement..."
    
    $result = @{
        TestName = "EnvironmentPersistence"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Simulation de redémarrage (test de persistance)
        $persistenceTest = @{
            beforeRestart = @{}
            afterRestart = @{}
            persistent = @{}
            nonPersistent = @{}
        }
        
        # Capture des valeurs avant simulation
        foreach ($var in $script:STANDARD_ENVIRONMENT.Machine.GetEnumerator()) {
            $persistenceTest.beforeRestart[$var.Key] = [System.Environment]::GetEnvironmentVariable($var.Key, "Machine")
        }
        foreach ($var in $script:STANDARD_ENVIRONMENT.User.GetEnumerator()) {
            $persistenceTest.beforeRestart[$var.Key] = [System.Environment]::GetEnvironmentVariable($var.Key, "User")
        }
        foreach ($var in $script:STANDARD_ENVIRONMENT.Process.GetEnumerator()) {
            $persistenceTest.beforeRestart[$var.Key] = [System.Environment]::GetEnvironmentVariable($var.Key, "Process")
        }
        
        # Simulation de redémarrage (lecture des registres)
        $registryMachine = try { Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -ErrorAction SilentlyContinue } catch { $null }
        $registryUser = try { Get-ItemProperty -Path "HKCU\Environment" -ErrorAction SilentlyContinue } catch { $null }
        
        # Vérification de persistance
        foreach ($var in $script:STANDARD_ENVIRONMENT.Machine.GetEnumerator()) {
            $registryValue = if ($registryMachine) { $registryMachine[$var.Key] } else { $null }
            $expectedValue = $script:STANDARD_ENVIRONMENT.Machine[$var.Key]
            
            if ($registryValue -eq $expectedValue) {
                $persistenceTest.persistent[$var.Key] = $true
            } else {
                $persistenceTest.nonPersistent[$var.Key] = @{
                    expected = $expectedValue
                    actual = $registryValue
                    scope = "Machine"
                }
            }
        }
        
        foreach ($var in $script:STANDARD_ENVIRONMENT.User.GetEnumerator()) {
            $registryValue = if ($registryUser) { $registryUser[$var.Key] } else { $null }
            $expectedValue = $script:STANDARD_ENVIRONMENT.User[$var.Key]
            
            if ($registryValue -eq $expectedValue) {
                $persistenceTest.persistent[$var.Key] = $true
            } else {
                $persistenceTest.nonPersistent[$var.Key] = @{
                    expected = $expectedValue
                    actual = $registryValue
                    scope = "User"
                }
            }
        }
        
        $result.Details = @{
            BeforeRestart = $persistenceTest.beforeRestart
            Persistent = $persistenceTest.persistent
            NonPersistent = $persistenceTest.nonPersistent
            TotalPersistent = $persistenceTest.persistent.Count
            TotalNonPersistent = $persistenceTest.nonPersistent.Count
        }
        
        if ($persistenceTest.nonPersistent.Count -eq 0) {
            $result.Success = $true
            Write-Success "Persistance environnement : OK ($($persistenceTest.persistent.Count) variables persistantes)"
        } else {
            $result.Issues += "$($persistenceTest.nonPersistent.Count) variables non persistantes après redémarrage"
            $result.Recommendations = @(
                "Redémarrer le système pour activer les variables persistantes",
                "Vérifier les permissions d'écriture dans le registre",
                "Exécuter le script avec des droits administrateur"
            )
            Write-Warning "Persistance environnement : ÉCHEC ($($persistenceTest.nonPersistent.Count) variables non persistantes)"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test de persistance: $($_.Exception.Message)"
        Write-Error "Test persistance environnement : ÉCHEC"
    }
    
    return $result
}

function Test-UTF8EnvironmentSupport {
    Write-Info "Test du support UTF-8 dans l'environnement..."
    
    $result = @{
        TestName = "UTF8EnvironmentSupport"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        $utf8Test = @{
            localeVariables = @{}
            encodingVariables = @{}
            applicationSupport = @{}
            consoleSupport = @{}
        }
        
        # Test des variables locales UTF-8
        $localeVars = @("LANG", "LC_ALL", "LC_CTYPE", "LC_TIME", "LC_COLLATE")
        foreach ($var in $localeVars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = $script:STANDARD_ENVIRONMENT.Process[$var]
            $isUTF8 = $currentValue -like "*UTF-8*"
            
            $utf8Test.localeVariables[$var] = @{
                current = $currentValue
                expected = $expectedValue
                isUTF8 = $isUTF8
            }
            
            if (-not $isUTF8) {
                $result.Issues += "$var ne supporte pas UTF-8 : $currentValue"
            }
        }
        
        # Test des variables d'encodage
        $encodingVars = @("PYTHONIOENCODING", "JAVA_TOOL_OPTIONS", "NODE_OPTIONS")
        foreach ($var in $encodingVars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = $script:STANDARD_ENVIRONMENT.Process[$var]
            $supportsUTF8 = $currentValue -like "*utf-8*" -or $currentValue -like "*UTF-8*"
            
            $utf8Test.encodingVariables[$var] = @{
                current = $currentValue
                expected = $expectedValue
                supportsUTF8 = $supportsUTF8
            }
            
            if (-not $supportsUTF8) {
                $result.Issues += "$var ne supporte pas UTF-8 : $currentValue"
            }
        }
        
        # Test de support console
        $consoleEncoding = try {
            $chcpOutput = chcp 2>&1
            if ($chcpOutput -match "(\d+)") {
                [int]$matches[1]
            } else {
                "Unknown"
            }
        } catch {
            "Unknown"
        }
        $utf8Test.consoleSupport = @{
            currentCodePage = $consoleEncoding
            expectedCodePage = 65001
            isUTF8 = $consoleEncoding -eq 65001
        }
        
        if (-not $utf8Test.consoleSupport.isUTF8) {
            $result.Issues += "Console ne supporte pas UTF-8 : CodePage $consoleEncoding"
        }
        
        # Test de support applicatif
        $testContent = "Test UTF-8 : é è à ù ç œ æ â ê î ô û 🚀"
        $testFile = Join-Path $env:TEMP "utf8-environment-test.txt"
        $testContent | Out-File -FilePath $testFile -Encoding UTF8 -Force
        
        $fileContent = Get-Content -Path $testFile -Raw -Encoding UTF8
        $utf8Test.applicationSupport = @{
            fileCreationSuccess = Test-Path $testFile
            fileContent = $fileContent
            contentMatches = ($testContent -eq $fileContent)
        }
        
        if (-not $utf8Test.applicationSupport.contentMatches) {
            $result.Issues += "Test de fichier UTF-8 échoué : contenu corrompu"
        }
        
        # Nettoyage
        if (Test-Path $testFile) {
            Remove-Item -Path $testFile -Force
        }
        
        $result.Details = $utf8Test
        
        # Calcul du succès global
        $localeUTF8Count = ($utf8Test.localeVariables.Values | Where-Object { $_.isUTF8 }).Count
        $encodingUTF8Count = ($utf8Test.encodingVariables.Values | Where-Object { $_.supportsUTF8 }).Count
        $consoleUTF8 = $utf8Test.consoleSupport.isUTF8
        $applicationUTF8 = $utf8Test.applicationSupport.contentMatches
        
        $totalTests = $localeVars.Count + $encodingVars.Count + 2  # +2 pour console et application
        $successfulTests = $localeUTF8Count + $encodingUTF8Count + $(if ($consoleUTF8) { 1 } else { 0 }) + $(if ($applicationUTF8) { 1 } else { 0 })
        $successRate = [math]::Round(($successfulTests / $totalTests) * 100, 2)
        
        if ($successRate -ge 95) {
            $result.Success = $true
            Write-Success "Support UTF-8 environnement : OK ($successRate%)"
        } else {
            $result.Recommendations = @(
                "Configurer les variables locales UTF-8",
                "Définir PYTHONIOENCODING=utf-8",
                "Configurer JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8",
                "Exécuter chcp 65001 dans les scripts console"
            )
            Write-Warning "Support UTF-8 environnement : ÉCHEC ($successRate%)"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test UTF-8 : $($_.Exception.Message)"
        Write-Error "Test UTF-8 environnement : ÉCHEC"
    }
    
    return $result
}

# Fonctions d'application
function Set-MachineEnvironment {
    param([hashtable]$Variables)
    
    Write-Info "Configuration des variables Machine (HKLM)..."
    
    $successCount = 0
    $totalCount = $Variables.Count
    
    foreach ($var in $Variables.GetEnumerator()) {
        try {
            [System.Environment]::SetEnvironmentVariable($var.Key, $var.Value, "Machine")
            Write-Debug "Variable Machine définie : $($var.Key) = $($var.Value)"
            $successCount++
        } catch {
            Write-Warning "Échec définition variable Machine $($var.Key) : $($_.Exception.Message)"
        }
    }
    
    Write-Info "Variables Machine configurées : $successCount/$totalCount"
    return $successCount -eq $totalCount
}

function Set-UserEnvironment {
    param([hashtable]$Variables)
    
    Write-Info "Configuration des variables User (HKCU)..."
    
    $successCount = 0
    $totalCount = $Variables.Count
    
    foreach ($var in $Variables.GetEnumerator()) {
        try {
            [System.Environment]::SetEnvironmentVariable($var.Key, $var.Value, "User")
            Write-Debug "Variable User définie : $($var.Key) = $($var.Value)"
            $successCount++
        } catch {
            Write-Warning "Échec définition variable User $($var.Key) : $($_.Exception.Message)"
        }
    }
    
    Write-Info "Variables User configurées : $successCount/$totalCount"
    return $successCount -eq $totalCount
}

function Set-ProcessEnvironment {
    param([hashtable]$Variables)
    
    Write-Info "Configuration des variables Processus (session actuelle)..."
    
    $successCount = 0
    $totalCount = $Variables.Count
    
    foreach ($var in $Variables.GetEnumerator()) {
        try {
            [System.Environment]::SetEnvironmentVariable($var.Key, $var.Value, "Process")
            Write-Debug "Variable Processus définie : $($var.Key) = $($var.Value)"
            $successCount++
        } catch {
            Write-Warning "Échec définition variable Processus $($var.Key) : $($_.Exception.Message)"
        }
    }
    
    Write-Info "Variables Processus configurées : $successCount/$totalCount"
    return $successCount -eq $totalCount
}

function Validate-Prerequisites {
    Write-Info "Validation des prérequis..."
    
    $prereqs = @{
        isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        isWindows10Plus = [System.Environment]::OSVersion.Version -ge [Version]"10.0.0"
        isPowerShell51Plus = $PSVersionTable.PSVersion.Major -ge 5
        hasRegistryAccess = Test-Path "HKLM:\SYSTEM"
        hasUserAccess = Test-Path "HKCU:\"
    }
    
    $allPrereqsMet = $prereqs.isAdmin -and $prereqs.isWindows10Plus -and $prereqs.isPowerShell51Plus -and $prereqs.hasRegistryAccess -and $prereqs.hasUserAccess
    
    Write-Info "Prérequis validés :"
    Write-Info "  - Droits administrateur : $(if ($prereqs.isAdmin) { "✅" } else { "❌" })"
    Write-Info "  - Windows 10+ : $(if ($prereqs.isWindows10Plus) { "✅" } else { "❌" })"
    Write-Info "  - PowerShell 5.1+ : $(if ($prereqs.isPowerShell51Plus) { "✅" } else { "❌" })"
    Write-Info "  - Accès registre HKLM : $(if ($prereqs.hasRegistryAccess) { "✅" } else { "❌" })"
    Write-Info "  - Accès registre HKCU : $(if ($prereqs.hasUserAccess) { "✅" } else { "❌" })"
    
    if (-not $allPrereqsMet) {
        Write-Error "Prérequis non satisfaits. Exécution en tant qu'administrateur requise."
        return $false
    }
    
    Write-Success "Tous les prérequis sont satisfaits"
    return $true
}

# Programme principal
function Main {
    Write-Log "Début du script Set-StandardizedEnvironment.ps1" "INFO"
    Write-Log "ID Correction : SYS-003-ENVIRONMENT" "INFO"
    Write-Log "Priorité : CRITIQUE" "INFO"
    
    try {
        Write-Info "Début de la standardisation des variables d'environnement UTF-8..."
        
        # Validation des prérequis
        if (-not (Validate-Prerequisites)) {
            exit 1
        }
        
        # Mode validation uniquement
        if ($ValidateOnly) {
            Write-Info "Mode validation uniquement - aucune modification ne sera appliquée"
            
            $validationResults = @(
                $(Test-EnvironmentConsistency),
                $(Test-EnvironmentPersistence),
                $(Test-UTF8EnvironmentSupport)
            )
            
            $successfulTests = ($validationResults | Where-Object { $_.Success }).Count
            $totalTests = $validationResults.Count
            $successRate = [math]::Round(($successfulTests / $totalTests) * 100, 2)
            
            # Génération du rapport de validation
            $validationReport = @{
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                script = "Set-StandardizedEnvironment.ps1"
                version = "1.0"
                mode = "validation_only"
                results = $validationResults
                summary = @{
                    totalTests = $totalTests
                    successfulTests = $successfulTests
                    failedTests = $totalTests - $successfulTests
                    successRate = $successRate
                    overallSuccess = $successRate -ge 95
                }
            }
            
            $validationReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:ValidationFile -Encoding UTF8 -Force
            
            if ($successRate -ge 95) {
                Write-Success "Validation réussie ($successRate%) - environnement prêt pour UTF-8"
            } else {
                Write-Warning "Validation partielle ($successRate%) - corrections requises"
            }
            
            exit 0
        }
        
        # Création du backup
        $backupFile = New-EnvironmentBackup
        if (-not $backupFile) {
            Write-Error "Échec de la création du backup - arrêt du script"
            exit 1
        }
        
        # Validation avant modification
        Write-Info "Validation de l'état actuel..."
        $preValidationResults = @(
            $(Test-EnvironmentConsistency),
            $(Test-EnvironmentPersistence),
            $(Test-UTF8EnvironmentSupport)
        )
        
        $preSuccessCount = ($preValidationResults | Where-Object { $_.Success }).Count
        $preTotalTests = $preValidationResults.Count
        $preSuccessRate = [math]::Round(($preSuccessCount / $preTotalTests) * 100, 2)
        
        Write-Info "Validation avant modification : $preSuccessCount/$preTotalTests ($preSuccessRate%)"
        
        # Vérification si des corrections sont nécessaires
        if ($preSuccessRate -ge 95 -and -not $Force) {
            Write-Success "Environnement déjà correctement configuré ($preSuccessRate%) - aucune modification nécessaire"
            exit 0
        }
        
        if ($preSuccessRate -lt 95 -and -not $Force) {
            Write-Warning "Problèmes détectés ($preSuccessRate%) - utilisez le paramètre -Force pour corriger"
            exit 1
        }
        
        # Application des modifications
        Write-Info "Application des variables d'environnement standardisées..."
        
        $machineSuccess = Set-MachineEnvironment -Variables $script:STANDARD_ENVIRONMENT.Machine
        $userSuccess = Set-UserEnvironment -Variables $script:STANDARD_ENVIRONMENT.User
        $processSuccess = Set-ProcessEnvironment -Variables $script:STANDARD_ENVIRONMENT.Process
        
        if ($machineSuccess -and $userSuccess -and $processSuccess) {
            Write-Success "Variables d'environnement appliquées avec succès"
        } else {
            Write-Error "Échec partiel de l'application des variables"
            exit 1
        }
        
        # Validation post-modification
        Write-Info "Validation post-modification..."
        Start-Sleep -Seconds 2  # Attendre la prise en compte
        
        $postValidationResults = @(
            $(Test-EnvironmentConsistency),
            $(Test-EnvironmentPersistence),
            $(Test-UTF8EnvironmentSupport)
        )
        
        $postSuccessCount = ($postValidationResults | Where-Object { $_.Success }).Count
        $postTotalTests = $postValidationResults.Count
        $postSuccessRate = [math]::Round(($postSuccessCount / $postTotalTests) * 100, 2)
        
        Write-Info "Validation post-modification : $postSuccessCount/$postTotalTests ($postSuccessRate%)"
        
        # Génération du rapport final
        $finalReport = @{
            metadata = @{
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                script = "Set-StandardizedEnvironment.ps1"
                version = "1.0"
                correctionId = "SYS-003-ENVIRONMENT"
                backupFile = $backupFile
            }
            preValidation = @{
                results = $preValidationResults
                successRate = $preSuccessRate
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
            postValidation = @{
                results = $postValidationResults
                successRate = $postSuccessRate
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
            summary = @{
                improvement = $postSuccessRate - $preSuccessRate
                finalSuccessRate = $postSuccessRate
                overallSuccess = $postSuccessRate -ge 95
                restartRequired = $true
            }
        }
        
        $finalReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:ValidationFile -Encoding UTF8 -Force
        
        if ($postSuccessRate -ge 95) {
            Write-Success "Standardisation environnement terminée avec succès ($postSuccessRate%)"
            Write-Success "Rapport généré : $script:ValidationFile"
            
            if ($RestartRequired) {
                Write-Warning "Redémarrage du système requis pour activation complète"
                Write-Info "Exécutez : Restart-Computer -Force"
            }
        } else {
            Write-Warning "Standardisation partielle ($postSuccessRate%) - vérification requise"
            Write-Warning "Rapport généré : $script:ValidationFile"
        }
        
    } catch {
        Write-Error "Erreur inattendue : $($_.Exception.Message)"
        Write-Error "Stack Trace : $($_.ScriptStackTrace)"
        exit 1
    }
}

# Point d'entrée principal
Main
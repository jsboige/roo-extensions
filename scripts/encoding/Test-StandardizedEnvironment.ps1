<#
.SYNOPSIS
    Script de validation des variables d'environnement standardisées UTF-8
.DESCRIPTION
    Ce script valide la configuration des variables d'environnement UTF-8 sur Windows 11 Pro français.
    Il effectue des tests complets de cohérence, persistance, support UTF-8 et compatibilité
    applicative pour s'assurer que l'environnement est correctement configuré.
.PARAMETER Detailed
    Affiche des informations détaillées pendant la validation
.PARAMETER OutputFormat
    Format de sortie du rapport (JSON, Markdown, Console)
.PARAMETER TestFiles
    Génère des fichiers de test pour validation manuelle
.PARAMETER CompareWithBackup
    Compare avec un backup d'environnement si spécifié
.PARAMETER BackupPath
    Chemin vers le backup d'environnement à comparer
.PARAMETER ValidateAgainstStandard
    Valide contre les standards UTF-8 définis
.PARAMETER GenerateReport
    Génère un rapport complet de validation
.EXAMPLE
    .\Test-StandardizedEnvironment.ps1
.EXAMPLE
    .\Test-StandardizedEnvironment.ps1 -Detailed -OutputFormat JSON -ValidateAgainstStandard
.EXAMPLE
    .\Test-StandardizedEnvironment.ps1 -TestFiles -CompareWithBackup -BackupPath "backups\environment-backup-20251030-162000.json"
.NOTES
    Auteur: Roo Architect Complex Mode
    Version: 1.0
    Date: 2025-10-30
    ID Correction: SYS-003-VALIDATION
    Priorité: CRITIQUE
    Requiert: Windows 10+ avec variables d'environnement configurées
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "Markdown", "Console")]
    [string]$OutputFormat = "Console",
    
    [Parameter(Mandatory = $false)]
    [switch]$TestFiles,
    
    [Parameter(Mandatory = $false)]
    [switch]$CompareWithBackup,
    
    [Parameter(Mandatory = $false)]
    [string]$BackupPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$ValidateAgainstStandard,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport
)

# Configuration du script
$script:LogFile = "logs\Test-StandardizedEnvironment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:TestDir = "temp\utf8-environment-tests"
$script:ResultsDir = "results\utf8-environment-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Standards UTF-8 de référence
$STANDARD_UTF8 = @{
    Machine = @{
        "COMSPEC" = "C:\Windows\system32\cmd.exe"
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
        "NUMBER_OF_PROCESSORS" = "Unknown"  # Dépend du système
        "PROCESSOR_ARCHITECTURE" = "Unknown"  # Dépend du système
        "PROCESSOR_IDENTIFIER" = "Unknown"  # Dépend du système
        "WINDIR" = "C:\Windows"
        "PSModulePath" = "Unknown"  # Dépend du système
    }
    User = @{
        "PATH" = "Unknown"  # Dépend du profil utilisateur
        "HOME" = "Unknown"  # Dépend du profil utilisateur
        "DOCUMENTS" = "Unknown"  # Dépend du profil utilisateur
        "DESKTOP" = "Unknown"  # Dépend du profil utilisateur
        "DOWNLOADS" = "Unknown"  # Dépend du profil utilisateur
        "MUSIC" = "Unknown"  # Dépend du profil utilisateur
        "PICTURES" = "Unknown"  # Dépend du profil utilisateur
        "VIDEOS" = "Unknown"  # Dépend du profil utilisateur
        "FAVORITES" = "Unknown"  # Dépend du profil utilisateur
        "RECENT" = "Unknown"  # Dépend du profil utilisateur
    }
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
        "NPM_CONFIG_PREFIX" = "Unknown"  # Dépend du profil utilisateur
        "YARN_GLOBAL_FOLDER" = "Unknown"  # Dépend du profil utilisateur
        "YARN_ENABLE_IMMUTABLE_INSTALLS" = "false"
        "VSCODE_PORTABLE" = "false"
        "VSCODE_USER_DATA_DIR" = "Unknown"  # Dépend du profil utilisateur
        "VSCODE_EXTENSIONS_DIR" = "Unknown"  # Dépend du profil utilisateur
        "VSCODE_LOGS_DIR" = "Unknown"  # Dépend du profil utilisateur
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
            "TEST" { "Magenta" }
            "DETAIL" { "White" }
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
    if ($Detailed) {
        Write-Log $Message "INFO"
    }
}

function Write-Test {
    param([string]$Message)
    Write-Log $Message "TEST"
}

# Tests de validation
function Test-EnvironmentHierarchy {
    Write-Test "Test 1: Validation de la hiérarchie d'environnement..."
    
    $result = @{
        TestName = "EnvironmentHierarchy"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test de la priorité Machine > User > Processus
        $machineVars = @("COMSPEC", "PATHEXT", "TEMP", "SystemRoot", "OS")
        $userVars = @("PATH", "HOME", "DOCUMENTS", "DESKTOP")
        $processVars = @("LANG", "LC_ALL", "PYTHONIOENCODING")
        
        $hierarchyTest = @{
            machinePriority = @{}
            userPriority = @{}
            processPriority = @{}
            conflicts = @()
        }
        
        # Test des variables Machine
        foreach ($var in $machineVars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = $STANDARD_UTF8.Machine[$var]
            
            $hierarchyTest.machinePriority[$var] = @{
                current = $currentValue
                expected = $expectedValue
                priority = "Machine"
                correct = ($currentValue -eq $expectedValue)
            }
            
            if ($currentValue -ne $expectedValue) {
                $hierarchyTest.conflicts += "Variable Machine $var incorrecte : attendu=$expectedValue, actuel=$currentValue"
            }
        }
        
        # Test des variables User
        foreach ($var in $userVars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = $STANDARD_UTF8.User[$var]
            
            $hierarchyTest.userPriority[$var] = @{
                current = $currentValue
                expected = $expectedValue
                priority = "User"
                correct = ($currentValue -eq $expectedValue)
            }
            
            if ($currentValue -ne $expectedValue) {
                $hierarchyTest.conflicts += "Variable User $var incorrecte : attendu=$expectedValue, actuel=$currentValue"
            }
        }
        
        # Test des variables Processus
        foreach ($var in $processVars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = $STANDARD_UTF8.Process[$var]
            
            $hierarchyTest.processPriority[$var] = @{
                current = $currentValue
                expected = $expectedValue
                priority = "Process"
                correct = ($currentValue -eq $expectedValue)
            }
            
            if ($currentValue -ne $expectedValue) {
                $hierarchyTest.conflicts += "Variable Processus $var incorrecte : attendu=$expectedValue, actuel=$currentValue"
            }
        }
        
        $result.Details = $hierarchyTest
        
        # Calcul du succès
        $totalTests = $machineVars.Count + $userVars.Count + $processVars.Count
        $correctTests = ($hierarchyTest.machinePriority.Values | Where-Object { $_.correct }).Count + ($hierarchyTest.userPriority.Values | Where-Object { $_.correct }).Count + ($hierarchyTest.processPriority.Values | Where-Object { $_.correct }).Count
        
        if ($correctTests -eq $totalTests) {
            $result.Success = $true
            Write-Success "Hiérarchie environnement: OK ($correctTests/$totalTests variables correctes)"
        } else {
            $result.Issues = $hierarchyTest.conflicts
            $result.Recommendations = @(
                "Exécuter Set-StandardizedEnvironment.ps1 avec le paramètre -Force",
                "Vérifier les permissions d'écriture dans le registre",
                "Revalider avec ce script après correction"
            )
            Write-Warning "Hiérarchie environnement: ÉCHEC ($correctTests/$totalTests variables correctes)"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test de hiérarchie: $($_.Exception.Message)"
        Write-Error "Test hiérarchie environnement: ÉCHEC"
    }
    
    return $result
}

function Test-EnvironmentPersistence {
    Write-Test "Test 2: Validation de la persistance des variables..."
    
    $result = @{
        TestName = "EnvironmentPersistence"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test de persistance des variables Machine
        $machinePersistence = @{}
        foreach ($var in $STANDARD_UTF8.Machine.GetEnumerator()) {
            $registryValue = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name $var.Key -ErrorAction SilentlyContinue
            $expectedValue = $STANDARD_UTF8.Machine[$var.Key]
            
            $machinePersistence[$var.Key] = @{
                current = [System.Environment]::GetEnvironmentVariable($var.Key)
                expected = $expectedValue
                registry = $registryValue
                persistent = ($registryValue -eq $expectedValue)
            }
            
            if (-not $machinePersistence[$var.Key].persistent) {
                $result.Issues += "Variable Machine $var.Key non persistante: attendu=$expectedValue, registre=$($registryValue)"
            }
        }
        
        # Test de persistance des variables User
        $userPersistence = @{}
        foreach ($var in $STANDARD_UTF8.User.GetEnumerator()) {
            $registryValue = Get-ItemProperty -Path "HKCU\Environment" -Name $var.Key -ErrorAction SilentlyContinue
            $expectedValue = $STANDARD_UTF8.User[$var.Key]
            
            $userPersistence[$var.Key] = @{
                current = [System.Environment]::GetEnvironmentVariable($var.Key)
                expected = $expectedValue
                registry = $registryValue
                persistent = ($registryValue -eq $expectedValue)
            }
            
            if (-not $userPersistence[$var.Key].persistent) {
                $result.Issues += "Variable User $var.Key non persistante: attendu=$expectedValue, registre=$($registryValue)"
            }
        }
        
        $result.Details = @{
            Machine = $machinePersistence
            User = $userPersistence
        }
        
        # Calcul du succès
        $totalMachineVars = $machinePersistence.Count
        $totalUserVars = $userPersistence.Count
        $persistentMachineVars = ($machinePersistence.Values | Where-Object { $_.persistent }).Count
        $persistentUserVars = ($userPersistence.Values | Where-Object { $_.persistent }).Count
        $totalPersistentVars = $persistentMachineVars + $persistentUserVars
        $totalVars = $totalMachineVars + $totalUserVars
        
        if ($totalPersistentVars -eq $totalVars) {
            $result.Success = $true
            Write-Success "Persistance environnement: OK ($totalPersistentVars/$totalVars variables persistantes)"
        } else {
            $result.Issues += "$($totalVars - $totalPersistentVars) variables non persistantes après redémarrage"
            $result.Recommendations = @(
                "Redémarrer le système pour activer les variables persistantes",
                "Vérifier les permissions d'écriture dans le registre",
                "Exécuter le script avec des droits administrateur"
            )
            Write-Warning "Persistance environnement: ÉCHEC ($totalPersistentVars/$totalVars variables persistantes)"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test de persistance: $($_.Exception.Message)"
        Write-Error "Test persistance environnement: ÉCHEC"
    }
    
    return $result
}

function Test-UTF8EnvironmentSupport {
    Write-Test "Test 3: Validation du support UTF-8 dans l'environnement..."
    
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
            fileSystemSupport = @{}
        }
        
        # Test des variables locales UTF-8
        $localeVars = @("LANG", "LC_ALL", "LC_CTYPE", "LC_TIME", "LC_COLLATE")
        foreach ($var in $localeVars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = $STANDARD_UTF8.Process[$var]
            $isUTF8 = $currentValue -like "*UTF-8*"
            
            $utf8Test.localeVariables[$var] = @{
                current = $currentValue
                expected = $expectedValue
                isUTF8 = $isUTF8
            }
            
            if (-not $isUTF8) {
                $result.Issues += "Variable locale $var ne supporte pas UTF-8: $currentValue"
            }
        }
        
        # Test des variables d'encodage
        $encodingVars = @("PYTHONIOENCODING", "JAVA_TOOL_OPTIONS", "NODE_OPTIONS")
        foreach ($var in $encodingVars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = $STANDARD_UTF8.Process[$var]
            $supportsUTF8 = $currentValue -like "*utf-8*" -or $currentValue -like "*UTF-8*"
            
            $utf8Test.encodingVariables[$var] = @{
                current = $currentValue
                expected = $expectedValue
                supportsUTF8 = $supportsUTF8
            }
            
            if (-not $supportsUTF8) {
                $result.Issues += "Variable d'encodage $var ne supporte pas UTF-8: $currentValue"
            }
        }
        
        # Test de support console
        $consoleEncoding = try { chcp } catch { "Unknown" }
        $utf8Test.consoleSupport = @{
            currentCodePage = $consoleEncoding
            expectedCodePage = 65001
            isUTF8 = $consoleEncoding -eq 65001
        }
        
        if (-not $utf8Test.consoleSupport.isUTF8) {
            $result.Issues += "Console ne supporte pas UTF-8: CodePage $consoleEncoding"
        }
        
        # Test de support applicatif
        $testContent = "Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀"
        $testFile = Join-Path $env:TEMP "utf8-environment-test.txt"
        $testContent | Out-File -FilePath $testFile -Encoding UTF8 -Force
        
        $utf8Test.applicationSupport = @{
            fileCreationSuccess = Test-Path $testFile
            fileContent = Get-Content -Path $testFile -Raw -Encoding UTF8
            contentMatches = ($testContent -eq $utf8Test.applicationSupport.fileContent)
        }
        
        if (-not $utf8Test.applicationSupport.contentMatches) {
            $result.Issues += "Test de fichier UTF-8 échoué: contenu corrompu"
        }
        
        # Test de support système de fichiers
        $fileSystemTest = @{
            tempDirectory = $env:TEMP
            tempWritable = Test-Path $env:TEMP -PathType Leaf
            userProfile = $env:USERPROFILE
            userWritable = Test-Path $env:USERPROFILE -PathType Leaf
        }
        
        $utf8Test.fileSystemSupport = $fileSystemTest
        
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
        $fileSystemUTF8 = $utf8Test.fileSystemSupport.tempWritable -and $utf8Test.fileSystemSupport.userWritable
        
        $totalTests = $localeVars.Count + $encodingVars.Count + 3  # +3 pour console, application, filesystem
        $successfulTests = $localeUTF8Count + $encodingUTF8Count + $(if ($consoleUTF8) { 1 } else { 0 }) + $(if ($applicationUTF8) { 1 } else { 0 }) + $(if ($fileSystemUTF8) { 1 } else { 0 })
        $successRate = [math]::Round(($successfulTests / $totalTests) * 100, 2)
        
        if ($successRate -ge 95) {
            $result.Success = $true
            Write-Success "Support UTF-8 environnement: OK ($successRate%)"
        } else {
            $result.Recommendations = @(
                "Configurer les variables locales UTF-8",
                "Définir PYTHONIOENCODING=utf-8",
                "Configurer JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8",
                "Exécuter chcp 65001 dans les scripts console"
                "Vérifier les permissions d'écriture dans les répertoires temporaires"
            )
            Write-Warning "Support UTF-8 environnement: ÉCHEC ($successRate%)"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test UTF-8: $($_.Exception.Message)"
        Write-Error "Test UTF-8 environnement: ÉCHEC"
    }
    
    return $result
}

function Test-ApplicationCompatibility {
    Write-Test "Test 4: Validation de la compatibilité applicative..."
    
    $result = @{
        TestName = "ApplicationCompatibility"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test des applications critiques
        $applications = @(
            @{ Name = "PowerShell"; Command = "powershell.exe --version"; ExpectedPattern = "UTF-8" },
            @{ Name = "Command Prompt"; Command = "cmd.exe /c echo %LANG%"; ExpectedPattern = "fr-FR.UTF-8" },
            @{ Name = "Notepad"; Command = "notepad.exe --help"; ExpectedPattern = "UTF-8" },
            @{ Name = "Explorateur Windows"; Command = "explorer.exe --version"; ExpectedPattern = "UTF-8" },
            @{ Name = "Éditeur de registre"; Command = "regedit.exe --version"; ExpectedPattern = "UTF-8" }
        )
        
        $appResults = @()
        $successCount = 0
        
        foreach ($app in $applications) {
            try {
                $commandParts = $app.Command.Split(" ")
                $exePath = $commandParts[0]
                $arguments = $commandParts[1..($commandParts.Count-1)]
                
                $process = Start-Process -FilePath $exePath -ArgumentList $arguments -RedirectStandardOutput "temp\app-output.txt" -RedirectStandardError "temp\app-error.txt" -Wait -PassThru
                
                if ($process.ExitCode -eq 0) {
                    $output = Get-Content -Path "temp\app-output.txt" -Raw -ErrorAction SilentlyContinue
                    $errorOutput = Get-Content -Path "temp\app-error.txt" -Raw -ErrorAction SilentlyContinue
                    
                    $appCompatible = ($output -match $app.ExpectedPattern) -or ($errorOutput -notmatch "error") -or ($errorOutput -notmatch "Error")
                    
                    if ($appCompatible) {
                        $successCount++
                    }
                    
                    $appResults += @{
                        Name = $app.Name
                        Command = $app.Command
                        ExitCode = $process.ExitCode
                        Compatible = $appCompatible
                        Output = $output
                        ErrorOutput = $errorOutput
                        Issues = @()
                    }
                } else {
                    $issues = @("Application non compatible UTF-8")
                    if ($output) { $issues += "Sortie: $output" }
                    if ($errorOutput) { $issues += "Erreur: $errorOutput" }
                    
                    $appResults += @{
                        Name = $app.Name
                        Command = $app.Command
                        ExitCode = $process.ExitCode
                        Compatible = $false
                        Output = $output
                        ErrorOutput = $errorOutput
                        Issues = $issues
                    }
                }
                
            } catch {
                $appResults += @{
                    Name = $app.Name
                    Command = $app.Command
                    ExitCode = -1
                    Compatible = $false
                    Output = ""
                    ErrorOutput = $_.Exception.Message
                    Issues = @("Erreur lors du test: $($_.Exception.Message)")
                }
            }
        }
        
        $result.Details = @{
            TotalApplications = $applications.Count
            TestedApplications = $appResults.Count
            CompatibleApplications = $successCount
            ApplicationResults = $appResults
        }
        
        if ($successCount -eq $applications.Count) {
            $result.Success = $true
            Write-Success "Compatibilité applicative: OK ($successCount/$($applications.Count) applications compatibles)"
        } else {
            $result.Issues += "Incompatibilités détectées: $successCount/$($applications.Count) applications compatibles"
            $result.Recommendations = @(
                "Mettre à jour les applications non compatibles",
                "Vérifier les paramètres régionaux Windows",
                "Exécuter les corrections d'environnement recommandées"
            )
            Write-Warning "Compatibilité applicative: ÉCHEC ($successCount/$($applications.Count) applications compatibles)"
        }
        
    } catch {
        $result.Issues += "Erreur lors des tests de compatibilité: $($_.Exception.Message)"
        Write-Error "Test compatibilité applicative: ÉCHEC"
    }
    
    return $result
}

function Test-EnvironmentConsistency() {
    Write-Test "Test 5: Validation de la cohérence globale..."
    
    $result = @{
        TestName = "EnvironmentConsistency"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test de cohérence avec les standards UTF-8
        $consistencyTest = @{
            machineUserConsistency = @{}
            processConsistency = @{}
            registryConsistency = @{}
            pathConsistency = @{}
            encodingConsistency = @{}
        }
        
        # Test Machine vs User
        $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        $processPath = [System.Environment]::GetEnvironmentVariable("PATH", "Process")
        
        if ($machinePath -and $userPath) {
            $combinedPath = "$machinePath;$userPath"
            if ($processPath -notlike "*$machinePath*") {
                $consistencyTest.machineUserConsistency["PATH"] = "PATH Machine non trouvé dans PATH processus"
            }
            if ($processPath -notlike "*$userPath*") {
                $consistencyTest.machineUserConsistency["PATH_User"] = "PATH User non trouvé dans PATH processus"
            }
        }
        
        # Test des variables critiques
        $criticalVars = @("COMSPEC", "TEMP", "SystemRoot", "OS")
        foreach ($var in $criticalVars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = if ($ValidateAgainstStandard) { $STANDARD_UTF8.Machine[$var] } else { $null }
            
            if ($expectedValue -and $currentValue -ne $expectedValue) {
                $consistencyTest.machineUserConsistency[$var] = "$var incorrect: attendu=$expectedValue, actuel=$currentValue"
            }
        }
        
        # Test des variables UTF-8
        $utf8Vars = @("LANG", "LC_ALL", "PYTHONIOENCODING")
        foreach ($var in $utf8Vars) {
            $currentValue = [System.Environment]::GetEnvironmentVariable($var)
            $expectedValue = if ($ValidateAgainstStandard) { $STANDARD_UTF8.Process[$var] } else { $null }
            
            if ($expectedValue -and $currentValue -ne $expectedValue) {
                $consistencyTest.encodingConsistency[$var] = "$var UTF-8 incorrect: attendu=$expectedValue, actuel=$currentValue"
            }
        }
        
        # Test des chemins critiques
        $criticalPaths = @("TEMP", "USERPROFILE")
        foreach ($path in $criticalPaths) {
            $currentPath = [System.Environment]::GetEnvironmentVariable($path)
            $expectedPath = if ($ValidateAgainstStandard) { 
                if ($path -eq "TEMP") { $env:TEMP } 
                elseif ($path -eq "USERPROFILE") { $env:USERPROFILE } 
                else { $null }
            } else { $null }
            
            if ($expectedPath -and $currentPath -ne $expectedPath) {
                $consistencyTest.pathConsistency[$path] = "$path incorrect: attendu=$expectedPath, actuel=$currentPath"
            }
        }
        
        $result.Details = $consistencyTest
        
        # Calcul du succès
        $allTests = $consistencyTest.machineUserConsistency.Count + $consistencyTest.encodingConsistency.Count + $consistencyTest.pathConsistency.Count
        $passedTests = ($consistencyTest.machineUserConsistency.Values + $consistencyTest.encodingConsistency.Values + $consistencyTest.pathConsistency.Values | Where-Object { $_ -eq $null }).Count
        
        if ($passedTests -eq $allTests) {
            $result.Success = $true
            Write-Success "Cohérence environnement: OK (tous les tests cohérents)"
        } else {
            $result.Issues += @(
                ($consistencyTest.machineUserConsistency.Values | Where-Object { $_ -ne $null }).Count,
                ($consistencyTest.encodingConsistency.Values | Where-Object { $_ -ne $null }).Count,
                ($consistencyTest.pathConsistency.Values | Where-Object { $_ -ne $null }).Count
            )
            $result.Recommendations = @(
                "Exécuter Set-StandardizedEnvironment.ps1 avec le paramètre -Force",
                "Vérifier les permissions d'écriture dans le registre",
                "Revalider avec ce script après correction"
            )
            Write-Warning "Cohérence environnement: ÉCHEC ($passedTests/$allTests tests cohérents)"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test de cohérence: $($_.Exception.Message)"
        Write-Error "Test cohérence environnement: ÉCHEC"
    }
    
    return $result
}

# Comparaison avec backup
function Compare-WithBackup {
    param([string]$BackupPath)
    
    Write-Info "Comparaison avec le backup: $BackupPath"
    
    if (-not (Test-Path $BackupPath)) {
        Write-Warning "Fichier de backup introuvable: $BackupPath"
        return @{}
    }
    
    try {
        $backupContent = Get-Content -Path $BackupPath -Raw | ConvertFrom-Json
        $currentEnvironment = @{}
        
        # Collecte des valeurs actuelles
        $currentEnvironment.Machine = @{}
        $currentEnvironment.User = @{}
        $currentEnvironment.Process = @{}
        
        foreach ($var in $STANDARD_UTF8.Machine.GetEnumerator()) {
            $currentEnvironment.Machine[$var.Key] = [System.Environment]::GetEnvironmentVariable($var.Key, "Machine")
        }
        foreach ($var in $STANDARD_UTF8.User.GetEnumerator()) {
            $currentEnvironment.User[$var.Key] = [System.Environment]::GetEnvironmentVariable($var.Key, "User")
        }
        foreach ($var in $STANDARD_UTF8.Process.GetEnumerator()) {
            $currentEnvironment.Process[$var.Key] = [System.Environment]::GetEnvironmentVariable($var.Key, "Process")
        }
        
        # Analyse simple des différences
        $differences = @()
        
        if ($backupContent.currentEnvironment) {
            foreach ($scope in $backupContent.currentEnvironment.GetEnumerator()) {
                foreach ($var in $scope.Value.GetEnumerator()) {
                    $currentValue = $currentEnvironment[$scope][$var.Key]
                    $backupValue = $scope.Value[$var.Key]
                    
                    if ($currentValue -ne $backupValue) {
                        $differences += "$scope.$var : Backup=$backupValue, Actuel=$currentValue"
                    }
                }
            }
        }
        
        return @{
            BackupPath = $BackupPath
            CurrentEnvironment = $currentEnvironment
            Differences = $differences
            ComparisonDate = Get-Date
        }
        
    } catch {
        Write-Error "Erreur lors de la comparaison avec le backup: $($_.Exception.Message)"
        return @{}
    }
}

# Génération des fichiers de test
function New-TestFiles {
    Write-Info "Génération des fichiers de test UTF-8..."
    
    try {
        # Création du répertoire de tests
        if (!(Test-Path $script:TestDir)) {
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }
        
        # Fichiers de test avec différents types de caractères UTF-8
        $testFiles = @(
            @{
                Name = "french-accents.txt"
                Content = "Test français: é è à ù ç œ æ â ê î ô û 🚀"
                Description = "Caractères français avec accents"
            },
            @{
                Name = "european-special.txt"
                Content = "Test européen: ß ä ö ü ñ ç ÿ € £ ¥"
                Description = "Caractères européens spéciaux"
            },
            @{
                Name = "mathematical.txt"
                Content = "Test mathématiques: ∑ ∏ ∫ ∆ ∇ ∂ √ ∞"
                Description = "Symboles mathématiques Unicode"
            },
            @{
                Name = "currency-symbols.txt"
                Content = "Test symboles: € £ ¥ © ® ™"
                Description = "Symboles monétaires et commerciaux"
            },
            @{
                Name = "environment-variables.txt"
                Content = "Test variables: LANG=%LANG%, LC_ALL=%LC_ALL%, PYTHONIOENCODING=%PYTHONIOENCODING%"
                Description = "Test des variables d'environnement UTF-8"
            },
            @{
                Name = "console-encoding.txt"
                Content = "Test console: chcp 65001 && echo Test UTF-8: é è à ù ç"
                Description = "Test d'encodage console UTF-8"
            },
            @{
                Name = "path-encoding.txt"
                Content = "Test PATH: %PATH%"
                Description = "Test du PATH avec support UTF-8"
            },
            @{
                Name = "mixed-complex.txt"
                Content = "Test complexe: Café naïve — œuvre Noël — €100 — 🚀🔧 — ∑(i=1→n) i² = n(n+1)/2"
                Description = "Texte complexe mixte avec caractères UTF-8 variés"
            }
        )
        
        foreach ($file in $testFiles) {
            $filePath = Join-Path $script:TestDir $file.Name
            $file.Content | Out-File -FilePath $filePath -Encoding UTF8 -Force
            
            # Création du fichier de description
            $descPath = $filePath.Replace(".txt", ".desc.txt")
            $file.Description | Out-File -FilePath $descPath -Encoding UTF8 -Force
            
            if ($Detailed) {
                Write-Success "Fichier test créé: $($file.Name)"
            }
        }
        
        Write-Success "Fichiers de test générés: $($testFiles.Count) fichiers dans $script:TestDir"
        
    } catch {
        Write-Error "Erreur lors de la génération des fichiers de test: $($_.Exception.Message)"
    }
}

# Génération du rapport de validation
function New-ValidationReport {
    param([array]$TestResults, [hashtable]$BackupComparison)
    
    $reportPath = Join-Path $script:ResultsDir "environment-validation-report.$($OutputFormat.ToLower())"
    
    # Création du répertoire de résultats
    if (!(Test-Path $script:ResultsDir)) {
        New-Item -ItemType Directory -Path $script:ResultsDir -Force | Out-Null
    }
    
    # Calcul des statistiques globales
    $totalTests = $TestResults.Count
    $successfulTests = ($TestResults | Where-Object { $_.Success }).Count
    $failedTests = $totalTests - $successfulTests
    $successRate = if ($totalTests -gt 0) { [math]::Round(($successfulTests / $totalTests) * 100, 2) } else { 0 }
    $overallSuccess = $successRate -ge 95
    
    # Génération du rapport selon le format
    switch ($OutputFormat) {
        "JSON" {
            $jsonReport = @{
                metadata = @{
                    date = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                    script = "Test-StandardizedEnvironment.ps1"
                    version = "1.0"
                    correctionId = "SYS-003-VALIDATION"
                    backupComparison = $BackupComparison
                }
                summary = @{
                    totalTests = $totalTests
                    successfulTests = $successfulTests
                    failedTests = $failedTests
                    successRate = $successRate
                    overallSuccess = $overallSuccess
                }
                results = $TestResults
            }
            
            $jsonReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        }
        
        "Markdown" {
            $mdReport = @"
# Rapport de Validation des Variables d'Environnement UTF-8

**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Script**: Test-StandardizedEnvironment.ps1
**Version**: 1.0
**ID Correction**: SYS-003-VALIDATION

## 📊 Résumé Exécutif

### Métriques Globales
- **Tests Total**: $totalTests
- **Tests Réussis**: $successfulTests
- **Tests Échoués**: $failedTests
- **Taux de Succès**: $successRate%
- **Statut Global**: $(if ($overallSuccess) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })

## 📋 Résultats Détaillés

$($TestResults | ForEach-Object {
    "### $($_.TestName)"
    "#### Statut"
    "- **Résultat**: $(if ($_.Success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })"
    "#### Détails Techniques"
    $($_.Details | ForEach-Object {
        "- **$($_.Key)**: $($_.Value)"
    })
    $(if ($_.Issues.Count -gt 0) {
        "#### Problèmes Détectés"
        $($_.Issues | ForEach-Object {
            "- $($_)"
        })
    })
    $(if ($_.Recommendations.Count -gt 0) {
        "#### Recommandations"
        $($_.Recommendations | ForEach-Object {
            "- $($_)"
        })
    })
    ""
})

## 🔄 Comparaison avec Backup

$(if ($BackupComparison) {
    "### Fichier de Backup Analysé"
    "- **Chemin**: $($BackupComparison.BackupPath)"
    "- **Date de Comparaison**: $($BackupComparison.ComparisonDate)"
    
    "### Différences Détectées"
    $($BackupComparison.Differences | ForEach-Object {
        "- $($_)"
    })
} else {
    "### Aucune comparaison de backup effectuée"
})

## 🎯 Recommandations Globales

$(if ($overallSuccess) {
    "- ✅ **Configuration UTF-8 validée**: L'environnement est correctement configuré pour UTF-8"
    "- ✅ **Continuer vers Jour 5-5**: Infrastructure Console Moderne"
} else {
    "- ⚠️ **Actions correctives immédiates requises**:"
    "- 1. Réexécuter Set-StandardizedEnvironment.ps1 avec le paramètre -Force"
    "- 2. Redémarrer le système après application des corrections"
    "- 3. Revalider avec ce script après redémarrage"
    "- 🔄 **Nouvelle validation requise**: Réexécuter ce script après corrections"
})

## 📝 Informations Complémentaires

- **Fichier de Log**: $script:LogFile
- **Répertoire de Tests**: $script:TestDir
- **Date d'Exécution**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

---

**Statut**: $(if ($overallSuccess) { "✅ VALIDATION RÉUSSIE" } else { "⚠️ VALIDATION PARTIELLE - ACTIONS REQUISES" })
**Prochaine Étape**: $(if ($overallSuccess) { "Jour 5-5: Infrastructure Console Moderne" } else { "Correction des problèmes identifiés" })
"@
            
            $mdReport | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        }
        
        "Console" {
            Write-Host "`n=== RAPPORT DE VALIDATION DES VARIABLES D'ENVIRONNEMENT UTF-8 ===" -ForegroundColor Cyan
            Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
            Write-Host "Tests: $successfulTests/$totalTests réussis ($successRate%)" -ForegroundColor $(if ($overallSuccess) { "Green" } else { "Red" })
            
            foreach ($result in $TestResults) {
                $color = if ($result.Success) { "Green" } else { "Red" }
                Write-Host "`n$($result.TestName): $(if ($result.Success) { "SUCCÈS" } else { "ÉCHEC" })" -ForegroundColor $color
                
                if ($Detailed -and $result.Issues.Count -gt 0) {
                    Write-Host "  Problèmes: $($result.Issues.Count)" -ForegroundColor Yellow
                }
            }
            
            Write-Host "`n=== FIN DU RAPPORT ===" -ForegroundColor Cyan
        }
        
        default {
            Write-Error "Format de sortie non supporté: $OutputFormat"
        }
    }
    
    try {
        Write-Success "Rapport généré: $reportPath"
        return $reportPath
    } catch {
        Write-Error "Erreur lors de la génération du rapport: $($_.Exception.Message)"
        return $null
    }
}

# Programme principal
function Main {
    Write-Log "Début du script Test-StandardizedEnvironment.ps1" "INFO"
    Write-Log "ID Correction: SYS-003-VALIDATION" "INFO"
    Write-Log "Priorité: CRITIQUE" "INFO"
    
    try {
        Write-Info "Début de la validation des variables d'environnement UTF-8..."
        
        # Génération des fichiers de test si demandé
        if ($TestFiles) {
            New-TestFiles
        }
        
        # Comparaison avec backup si demandé
        $backupComparison = $null
        if ($CompareWithBackup -and $BackupPath) {
            $backupComparison = Compare-WithBackup -BackupPath $BackupPath
        }
        
        # Exécution des tests de validation
        $testResults = @(
            Test-EnvironmentHierarchy(),
            Test-EnvironmentPersistence(),
            Test-UTF8EnvironmentSupport(),
            Test-ApplicationCompatibility(),
            Test-EnvironmentConsistency()
        )
        
        if ($Detailed) {
            Write-Info "Tests exécutés: $($testResults.Count)"
            foreach ($result in $testResults) {
                Write-Info "  - $($result.TestName): $(if ($result.Success) { "SUCCÈS" } else { "ÉCHEC" })"
            }
        }
        
        # Génération du rapport
        if ($GenerateReport) {
            $reportPath = New-ValidationReport -TestResults $testResults -BackupComparison $backupComparison
            
            if ($reportPath) {
                # Calcul du succès global
                $successfulTests = ($testResults | Where-Object { $_.Success }).Count
                $totalTests = $testResults.Count
                $successRate = [math]::Round(($successfulTests / $totalTests) * 100, 2)
                $overallSuccess = $successRate -ge 95
                
                if ($overallSuccess) {
                    Write-Success "Validation environnement terminée avec succès ($successRate%)"
                    Write-Success "Rapport généré: $reportPath"
                } else {
                    Write-Warning "Validation environnement partielle ($successRate%) - actions correctives requises"
                    Write-Warning "Rapport généré: $reportPath"
                }
            }
        }
        
    } catch {
        Write-Error "Erreur inattendue: $($_.Exception.Message)"
        Write-Error "Stack Trace: $($_.ScriptStackTrace)"
        exit 1
    }
}

# Point d'entrée principal
Main
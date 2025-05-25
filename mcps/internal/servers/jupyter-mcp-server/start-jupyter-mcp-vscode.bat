@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo Script de démarrage du MCP Jupyter avec kernels VSCode
echo ===================================================

REM Définition des chemins - CORRIGÉ pour pointer vers le bon répertoire
set "MCP_JUPYTER_DIR=%~dp0"
set "CONFIG_FILE=%MCP_JUPYTER_DIR%\config.json"
set "CONFIG_BACKUP=%MCP_JUPYTER_DIR%\config.backup.json"
set "TEMP_CONFIG=%TEMP%\jupyter_mcp_config_temp.json"
set "VSCODE_EXTENSIONS=%USERPROFILE%\.vscode\extensions"
set "VSCODE_INSIDERS_EXTENSIONS=%USERPROFILE%\.vscode-insiders\extensions"

echo [INFO] Recherche des kernels Jupyter dans VSCode...

REM Vérification si le répertoire du MCP Jupyter existe
if not exist "%MCP_JUPYTER_DIR%" (
    echo [ERREUR] Le répertoire du MCP Jupyter n'existe pas: %MCP_JUPYTER_DIR%
    echo Veuillez vérifier l'installation du MCP Jupyter.
    exit /b 1
)

REM Sauvegarde de la configuration actuelle
if exist "%CONFIG_FILE%" (
    echo [INFO] Sauvegarde de la configuration actuelle...
    copy /Y "%CONFIG_FILE%" "%CONFIG_BACKUP%" > nul
    echo [INFO] Configuration sauvegardée dans %CONFIG_BACKUP%
)

REM Détection des kernels VSCode via PowerShell
echo [INFO] Recherche des extensions Jupyter dans VSCode...

powershell -Command "& {
    # Fonction pour trouver les kernels dans un répertoire d'extensions
    function Find-JupyterKernels {
        param (
            [string]$ExtensionsPath
        )
        
        if (-not (Test-Path $ExtensionsPath)) {
            return @()
        }
        
        $jupyterExtensions = Get-ChildItem -Path $ExtensionsPath -Directory | Where-Object { 
            $_.Name -like 'ms-toolsai.jupyter*' -or 
            $_.Name -like 'ms-python.python*'
        }
        
        $kernelSpecs = @()
        
        foreach ($ext in $jupyterExtensions) {
            Write-Host '[INFO] Extension Jupyter trouvée:' $ext.Name
            
            # Chercher les fichiers kernel.json dans l'extension
            $kernelJsonFiles = Get-ChildItem -Path $ext.FullName -Filter 'kernel.json' -Recurse -ErrorAction SilentlyContinue
            
            foreach ($kernelJson in $kernelJsonFiles) {
                try {
                    $kernelData = Get-Content -Path $kernelJson.FullName -Raw | ConvertFrom-Json
                    $kernelDir = Split-Path -Parent $kernelJson.FullName
                    $kernelName = Split-Path -Leaf (Split-Path -Parent $kernelJson.FullName)
                    
                    $kernelSpecs += @{
                        'name' = $kernelName
                        'display_name' = if ($kernelData.display_name) { $kernelData.display_name } else { $kernelName }
                        'language' = if ($kernelData.language) { $kernelData.language } else { 'python' }
                        'path' = $kernelDir
                    }
                    
                    Write-Host '[INFO] Kernel trouvé:' $kernelName
                } catch {
                    Write-Host '[AVERTISSEMENT] Erreur lors de la lecture du fichier kernel.json:' $kernelJson.FullName
                }
            }
        }
        
        return $kernelSpecs
    }
    
    # Rechercher dans les extensions VSCode standard et Insiders
    $vsCodeKernels = Find-JupyterKernels -ExtensionsPath '$env:VSCODE_EXTENSIONS'
    $vsCodeInsidersKernels = Find-JupyterKernels -ExtensionsPath '$env:VSCODE_INSIDERS_EXTENSIONS'
    
    # Rechercher également dans les kernels système
    $systemKernelPaths = @(
        '$env:APPDATA\jupyter\kernels',
        '$env:PROGRAMDATA\jupyter\kernels',
        '$env:LOCALAPPDATA\Programs\Python\Python*\share\jupyter\kernels'
    )
    
    $systemKernels = @()
    foreach ($path in $systemKernelPaths) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Directory | ForEach-Object {
                $kernelJsonPath = Join-Path $_.FullName 'kernel.json'
                if (Test-Path $kernelJsonPath) {
                    try {
                        $kernelData = Get-Content -Path $kernelJsonPath -Raw | ConvertFrom-Json
                        $systemKernels += @{
                            'name' = $_.Name
                            'display_name' = if ($kernelData.display_name) { $kernelData.display_name } else { $_.Name }
                            'language' = if ($kernelData.language) { $kernelData.language } else { 'python' }
                            'path' = $_.FullName
                        }
                        Write-Host '[INFO] Kernel système trouvé:' $_.Name
                    } catch {
                        Write-Host '[AVERTISSEMENT] Erreur lors de la lecture du fichier kernel.json:' $kernelJsonPath
                    }
                }
            }
        }
    }
    
    # Combiner tous les kernels trouvés
    $allKernels = $vsCodeKernels + $vsCodeInsidersKernels + $systemKernels
    
    # Créer la configuration pour le MCP Jupyter
    $config = @{
        'jupyterServer' = @{
            'baseUrl' = 'http://localhost:8890'
            'token' = (New-Guid).ToString().Replace('-', '')
            'offline' = $false
        }
        'kernels' = @{}
    }
    
    # Ajouter les kernels à la configuration
    foreach ($kernel in $allKernels) {
        $config.kernels[$kernel.name] = @{
            'displayName' = $kernel.display_name
            'language' = $kernel.language
            'path' = $kernel.path
        }
    }
    
    # Si aucun kernel n'a été trouvé, passer en mode hors ligne
    if ($allKernels.Count -eq 0) {
        Write-Host '[AVERTISSEMENT] Aucun kernel Jupyter trouvé. Passage en mode hors ligne.'
        $config.jupyterServer.offline = $true
    } else {
        Write-Host '[INFO]' $allKernels.Count 'kernels trouvés.'
    }
    
    # Écrire la configuration dans un fichier temporaire
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path '$env:TEMP\jupyter_mcp_config_temp.json'
    
    Write-Host '[INFO] Configuration générée avec succès.'
}"

REM Vérifier si la génération de la configuration a réussi
if not exist "%TEMP_CONFIG%" (
    echo [ERREUR] Échec de la génération de la configuration.
    echo Restauration de la configuration précédente...
    if exist "%CONFIG_BACKUP%" (
        copy /Y "%CONFIG_BACKUP%" "%CONFIG_FILE%" > nul
    )
    exit /b 1
)

REM Copier la configuration temporaire vers le fichier de configuration du MCP Jupyter
echo [INFO] Application de la nouvelle configuration...
copy /Y "%TEMP_CONFIG%" "%CONFIG_FILE%" > nul

REM Déterminer le mode de démarrage
powershell -Command "& {
    $config = Get-Content -Path '%CONFIG_FILE%' | ConvertFrom-Json
    if ($config.jupyterServer.offline) {
        Write-Host '[INFO] Démarrage du MCP Jupyter en mode hors ligne...'
        exit 1
    } else {
        Write-Host '[INFO] Démarrage du MCP Jupyter en mode connecté...'
        exit 0
    }
}"

REM Démarrer le MCP Jupyter avec la configuration appropriée
if %ERRORLEVEL% EQU 1 (
    echo [INFO] Mode hors ligne activé.
    echo [INFO] Démarrage du serveur MCP Jupyter en mode hors ligne...
    node "%MCP_JUPYTER_DIR%\dist\index.js" --offline
) else (
    echo [INFO] Mode connecté activé.
    echo [INFO] Démarrage du serveur MCP Jupyter en mode connecté...
    echo [INFO] Port configuré: 8890
    node "%MCP_JUPYTER_DIR%\dist\index.js"
)

endlocal
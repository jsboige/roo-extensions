# MCP MONITORING SCRIPT
# 
# Script PowerShell pour valider l'état des MCPs et détecter les divergences
# Auteur: Roo Code Assistant
# Version: 1.0.0
# Date: 2025-10-30

param(
    [string]$WorkspacePath = ".",
    [switch]$Verbose = $false,
    [switch]$Fix = $false,
    [string]$ConfigFile = ""
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Couleurs pour la sortie
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Cyan = "Cyan"
    White = "White"
    Gray = "Gray"
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Colors[$Color]
}

function Write-Section {
    param(
        [string]$Title,
        [string]$Color = "Cyan"
    )
    Write-ColorOutput "`n=== $Title ===" $Color
}

function Write-SubSection {
    param(
        [string]$Title,
        [string]$Color = "Yellow"
    )
    Write-ColorOutput "--- $Title ---" $Color
}

function Test-McpServer {
    param(
        [string]$ServerName,
        [string]$ServerPath,
        [hashtable]$ExpectedConfig
    )
    
    Write-SubSection "Test du serveur MCP: $ServerName" "Blue"
    
    $issues = @()
    
    # Vérifier que le fichier build existe
    $buildPath = Join-Path $ServerPath "build/index.js"
    if (-not (Test-Path $buildPath)) {
        $issues += "Fichier build manquant: $buildPath"
    }
    
    # Vérifier que le package.json existe
    $packagePath = Join-Path $ServerPath "package.json"
    if (-not (Test-Path $packagePath)) {
        $issues += "Fichier package.json manquant: $packagePath"
    }
    
    # Vérifier la configuration Jest
    $jestConfigPath = Join-Path $ServerPath "jest.config.js"
    if (-not (Test-Path $jestConfigPath)) {
        $issues += "Configuration Jest manquante: $jestConfigPath"
    }
    
    # Vérifier les tests anti-régression
    $antiRegressionPath = Join-Path $ServerPath "__tests__/anti-regression.test.js"
    if (-not (Test-Path $antiRegressionPath)) {
        $issues += "Tests anti-régression manquants: $antiRegressionPath"
    }
    
    # Analyser le package.json
    if (Test-Path $packagePath) {
        try {
            $packageJson = Get-Content $packagePath -Raw | ConvertFrom-Json
            
            # Vérifier les dépendances critiques
            $criticalDeps = @("@modelcontextprotocol/sdk", "jest", "typescript")
            foreach ($dep in $criticalDeps) {
                if (-not $packageJson.dependencies.ContainsKey($dep)) {
                    $issues += "Dépendance critique manquante: $dep"
                }
            }
            
            # Vérifier les scripts de test
            $testScripts = @("test", "test:unit", "test:anti-regression", "validate")
            $hasTestScripts = $false
            foreach ($script in $testScripts) {
                if ($packageJson.scripts.ContainsKey($script)) {
                    $hasTestScripts = $true
                    break
                }
            }
            
            if (-not $hasTestScripts) {
                $issues += "Scripts de test manquants dans package.json"
            }
        }
        catch {
            $issues += "Erreur lecture package.json: $($_.Exception.Message)"
        }
    }
    
    # Vérifier les fichiers de test
    $testDir = Join-Path $ServerPath "__tests__"
    if (Test-Path $testDir) {
        $testFiles = Get-ChildItem $testDir -Filter "*.test.js" -Recurse
        if ($testFiles.Count -lt 5) {
            $issues += "Nombre insuffisant de tests: $($testFiles.Count) fichiers"
        }
    }
    
    # Retourner les résultats
    return @{
        ServerName = $ServerName
        ServerPath = $ServerPath
        Issues = $issues
        Status = if ($issues.Count -eq 0) { "OK" } else { "ERROR" }
    }
}

function Test-McpConfiguration {
    param(
        [string]$ConfigPath
    )
    
    Write-SubSection "Validation de la configuration MCP globale" "Blue"
    
    $issues = @()
    
    if (-not (Test-Path $ConfigPath)) {
        $issues += "Fichier de configuration manquant: $ConfigPath"
        return $issues
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Vérifier la structure de configuration
        if (-not $config.mcpServers) {
            $issues += "Section mcpServers manquante"
        }
        
        # Vérifier les serveurs critiques
        $criticalServers = @("quickfiles", "jupyter", "jinavigator")
        foreach ($server in $criticalServers) {
            if ($config.mcpServers.ContainsKey($server)) {
                $serverConfig = $config.mcpServers[$server]
                
                # Vérifier les champs obligatoires
                $requiredFields = @("command", "args", "transportType")
                foreach ($field in $requiredFields) {
                    if (-not $serverConfig.ContainsKey($field)) {
                        $issues += "Champ manquant pour $server`: $field"
                    }
                }
                
                # Vérifier que le chemin d'args est valide
                if ($serverConfig.args -and $serverConfig.args.Count -gt 0) {
                    $mainArg = $serverConfig.args[0]
                    if (-not (Test-Path $mainArg.Replace('/', '\'))) {
                        $issues += "Chemin d'argument invalide pour $server`: $mainArg"
                    }
                }
            }
        }
        
        # Vérifier les watchPaths
        if ($config.mcpServers.ContainsKey("quickfiles")) {
            $quickfilesConfig = $config.mcpServers["quickfiles"]
            if ($quickfilesConfig.watchPaths) {
                foreach ($watchPath in $quickfilesConfig.watchPaths) {
                    if (-not (Test-Path $watchPath.Replace('/', '\'))) {
                        $issues += "WatchPath invalide: $watchPath"
                    }
                }
            }
        }
    }
    catch {
        $issues += "Erreur lecture configuration: $($_.Exception.Message)"
    }
    
    return $issues
}

function Test-McpHealth {
    param(
        [string]$ServerName,
        [int]$Port = 3000
    )
    
    Write-SubSection "Test de santé du serveur MCP: $ServerName" "Blue"
    
    try {
        # Test de connexion HTTP
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/status" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        
        if ($response.StatusCode -eq 200) {
            Write-ColorOutput "✅ Serveur $ServerName répond correctement (port $Port)" "Green"
            return $true
        } else {
            Write-ColorOutput "❌ Serveur $ServerName répond avec code $($response.StatusCode)" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Serveur $ServerName inaccessible sur le port $Port" "Red"
        return $false
    }
}

function Get-McpVersion {
    param(
        [string]$ServerPath
    )
    
    $packagePath = Join-Path $ServerPath "package.json"
    if (Test-Path $packagePath) {
        try {
            $packageJson = Get-Content $packagePath -Raw | ConvertFrom-Json
            return $packageJson.version
        }
        catch {
            return "Unknown"
        }
    }
    
    return "Unknown"
}

function Compare-Versions {
    param(
        [string]$CurrentVersion,
        [string]$ExpectedVersion
    )
    
    if ($CurrentVersion -eq $ExpectedVersion) {
        return $true
    }
    
    # Comparaison simple de versions (semver basique)
    $currentParts = $CurrentVersion.Split('.')
    $expectedParts = $ExpectedVersion.Split('.')
    
    for ($i = 0; $i -lt [Math]::Min($currentParts.Length, $expectedParts.Length); $i++) {
        $current = [int]$currentParts[$i]
        $expected = [int]$expectedParts[$i]
        
        if ($current -lt $expected) {
            return $false
        } elseif ($current -gt $expected) {
            return $true
        }
    }
    
    return $true
}

# Programme principal
function Main {
    Write-Section "MCP MONITORING SCRIPT" "Cyan"
    Write-ColorOutput "Version: 1.0.0" "Gray"
    Write-ColorOutput "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Gray"
    
    # Déterminer le chemin de configuration
    if ([string]::IsNullOrEmpty($ConfigFile)) {
        $appDataPath = $env:APPDATA
        if ($appDataPath) {
            $ConfigFile = Join-Path $appDataPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
        }
    }
    
    Write-ColorOutput "Espace de travail: $WorkspacePath" "Gray"
    Write-ColorOutput "Fichier de configuration: $ConfigFile" "Gray"
    
    $totalIssues = 0
    $criticalIssues = 0
    
    # 1. Validation de la configuration globale
    $configIssues = Test-McpConfiguration $ConfigFile
    $totalIssues += $configIssues.Count
    $criticalIssues += $configIssues.Count
    
    if ($configIssues.Count -gt 0) {
        Write-ColorOutput "`n❌ PROBLÈMES DE CONFIGURATION TROUVÉS:" "Red"
        foreach ($issue in $configIssues) {
            Write-ColorOutput "  • $issue" "Red"
        }
    } else {
        Write-ColorOutput "`n✅ Configuration MCP valide" "Green"
    }
    
    # 2. Test des serveurs MCP critiques
    $mcpServersPath = Join-Path $WorkspacePath "mcps/internal/servers"
    if (Test-Path $mcpServersPath) {
        $servers = Get-ChildItem $mcpServersPath -Directory
        
        foreach ($server in $servers) {
            $serverResult = Test-McpServer $server.Name $server.FullName @{}
            $totalIssues += $serverResult.Issues.Count
            
            if ($serverResult.Issues.Count -gt 0) {
                $criticalIssues += $serverResult.Issues.Count
                Write-ColorOutput "`n❌ SERVEUR $($serverResult.ServerName): $($serverResult.Status)" "Red"
                foreach ($issue in $serverResult.Issues) {
                    Write-ColorOutput "  • $issue" "Red"
                }
            } else {
                Write-ColorOutput "`n✅ SERVEUR $($serverResult.ServerName): $($serverResult.Status)" "Green"
                
                # Test de santé si disponible
                $version = Get-McpVersion $server.FullName
                Write-ColorOutput "  Version: $version" "Gray"
                
                # Test de connexion pour quickfiles (port 3003)
                if ($server.Name -eq "quickfiles-server") {
                    Test-McpHealth "quickfiles" 3003
                }
            }
        }
    }
    
    # 3. Tests de régression spécifiques
    Write-Section "TESTS ANTI-RÉGRESSION" "Yellow"
    
    $quickfilesPath = Join-Path $WorkspacePath "mcps/internal/servers/quickfiles-server"
    if (Test-Path $quickfilesPath) {
        # Vérifier les tests anti-régression
        $antiRegressionTest = Join-Path $quickfilesPath "__tests__/anti-regression.test.js"
        if (Test-Path $antiRegressionTest) {
            Write-ColorOutput "✅ Tests anti-régression présents" "Green"
            
            # Exécuter les tests si demandé
            if ($Fix) {
                Write-SubSection "Exécution des tests anti-régression" "Blue"
                Set-Location $quickfilesPath
                
                try {
                    $testResult = npm test -- --testPathPattern="anti-regression.test.js" --verbose
                    if ($LASTEXITCODE -eq 0) {
                        Write-ColorOutput "✅ Tests anti-régression réussis" "Green"
                    } else {
                        Write-ColorOutput "❌ Tests anti-régression échoués" "Red"
                        $totalIssues += 1
                        $criticalIssues += 1
                    }
                }
                catch {
                    Write-ColorOutput "❌ Erreur exécution tests: $($_.Exception.Message)" "Red"
                    $totalIssues += 1
                    $criticalIssues += 1
                }
            }
        } else {
            Write-ColorOutput "❌ Tests anti-régression manquants" "Red"
            $totalIssues += 1
            $criticalIssues += 1
        }
    }
    
    # 4. Résumé et recommandations
    Write-Section "RÉSUMÉ" "Cyan"
    
    if ($totalIssues -eq 0) {
        Write-ColorOutput "🎉 AUCUN PROBLÈME DÉTECTÉ" "Green"
        Write-ColorOutput "   Tous les MCPs sont correctement configurés et fonctionnels" "Green"
    } else {
        Write-ColorOutput "⚠️  $totalIssues PROBLÈME(S) DÉTECTÉ(S)" "Yellow"
        Write-ColorOutput "   $criticalIssues problème(s) critique(s)" "Red"
        
        Write-ColorOutput "`n📋 RECOMMANDATIONS:" "Blue"
        if ($configIssues.Count -gt 0) {
            Write-ColorOutput "  • Corriger la configuration MCP dans: $ConfigFile" "Yellow"
        }
        if ($criticalIssues -gt 0) {
            Write-ColorOutput "  • Exécuter: npm run test:anti-regression" "Yellow"
            Write-ColorOutput "  • Vérifier les implémentations manquantes" "Yellow"
        }
        
        Write-ColorOutput "  • Mettre à jour les dépendances: npm install" "Gray"
        Write-ColorOutput "  • Recompiler les serveurs: npm run build" "Gray"
    }
    
    # 5. Sortie avec code approprié
    if ($totalIssues -gt 0) {
        Write-ColorOutput "`n🚨 CODE DE SORTIE: 1 (Erreurs détectées)" "Red"
        exit 1
    } else {
        Write-ColorOutput "`n✅ CODE DE SORTIE: 0 (Succès)" "Green"
        exit 0
    }
}

# Point d'entrée
if ($Verbose) {
    Write-ColorOutput "Mode verbeux activé" "Yellow"
}

Main
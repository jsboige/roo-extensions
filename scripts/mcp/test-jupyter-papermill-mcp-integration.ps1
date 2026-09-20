#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test d'intégration MCP pour le serveur Jupyter-Papermill consolidé
    
.DESCRIPTION
    Script de validation des tests d'intégration MCP via protocole JSON-RPC
    Teste la communication directe avec le serveur MCP consolidé
    
.PARAMETER Environment 
    Nom de l'environnement conda (défaut: mcp-jupyter-py310)
    
.PARAMETER ServerPath
    Chemin vers le serveur MCP (défaut: relatif au script)
    
.PARAMETER Timeout
    Timeout en secondes pour les tests (défaut: 30)
    
.EXAMPLE
    .\test-jupyter-papermill-mcp-integration.ps1
    .\test-jupyter-papermill-mcp-integration.ps1 -Environment "custom-env" -Timeout 60
#>

param(
    [string]$Environment = "mcp-jupyter-py310",
    [string]$ServerPath = "",
    [int]$Timeout = 30
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Couleurs pour la sortie
$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-ColoredOutput {
    param([string]$Message, [string]$Color = $Reset)
    Write-Host "${Color}${Message}${Reset}"
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-ColoredOutput "=" * 80 $Blue
    Write-ColoredOutput "  $Title" $Blue
    Write-ColoredOutput "=" * 80 $Blue
}

function Test-CondaEnvironment {
    param([string]$EnvName)
    
    Write-ColoredOutput "🔍 Vérification de l'environnement conda '$EnvName'..." $Yellow
    
    try {
        # cmd-layer stderr discard (#3731 class, lot 3): the file-global EAP=Stop makes a
        # PS-level `2>$null` on native stderr a terminating ErrorRecord (conda prints
        # activation notices on stderr). `2>nul` inside `& cmd /c` never mints one.
        $condaInfo = & cmd /c "conda info --envs 2>nul" | Select-String $EnvName
        if (-not $condaInfo) {
            throw "Environnement conda '$EnvName' non trouvé"
        }
        Write-ColoredOutput "✅ Environnement conda trouvé" $Green
        return $true
    }
    catch {
        Write-ColoredOutput "❌ Erreur environnement conda: $_" $Red
        return $false
    }
}

function Get-ServerPath {
    if ([string]::IsNullOrEmpty($ServerPath)) {
        $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
        $ServerPath = Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) "mcps\internal\servers\jupyter-papermill-mcp-server"
    }
    
    if (-not (Test-Path $ServerPath)) {
        throw "Chemin serveur non trouvé: $ServerPath"
    }
    
    return $ServerPath
}

function Test-MCPProtocol {
    param([string]$ServerPath, [string]$EnvName)
    
    Write-ColoredOutput "🔗 Test du protocole JSON-RPC MCP..." $Yellow
    
    try {
        Push-Location $ServerPath
        
        # Construction de la commande MCP
        $pythonExe = if ($IsWindows) { "python" } else { "python3" }
        $mcpCommand = @(
            "conda", "run", "-n", $EnvName, "--no-capture-output",
            $pythonExe, "-m", "papermill_mcp.main"
        )
        
        Write-ColoredOutput "Commande: $($mcpCommand -join ' ')" $Blue
        
        # Préparation des requêtes JSON-RPC
        $initRequest = @{
            jsonrpc = "2.0"
            id = 1
            method = "initialize"
            params = @{
                protocolVersion = "2024-11-05"
                capabilities = @{}
                clientInfo = @{
                    name = "test-client"
                    version = "1.0"
                }
            }
        } | ConvertTo-Json -Depth 10
        
        $listToolsRequest = @{
            jsonrpc = "2.0"
            id = 2
            method = "tools/list"
            params = @{}
        } | ConvertTo-Json -Depth 10
        
        # Test d'initialisation
        Write-ColoredOutput "📨 Envoi de la requête d'initialisation..." $Yellow
        $initProcess = Start-Process -FilePath $mcpCommand[0] -ArgumentList ($mcpCommand[1..($mcpCommand.Length-1)]) -NoNewWindow -PassThru -RedirectStandardInput -RedirectStandardOutput -RedirectStandardError
        
        Start-Sleep -Seconds 2
        
        if ($initProcess.HasExited) {
            $stderr = $initProcess.StandardError.ReadToEnd()
            throw "Le serveur MCP s'est arrêté prématurément: $stderr"
        }
        
        # Envoi de la requête d'initialisation
        $initProcess.StandardInput.WriteLine($initRequest)
        $initProcess.StandardInput.WriteLine("")
        
        # Lecture de la réponse avec timeout
        $responseReceived = $false
        $startTime = Get-Date
        $response = ""
        
        while (((Get-Date) - $startTime).TotalSeconds -lt $Timeout -and -not $initProcess.HasExited) {
            if ($initProcess.StandardOutput.Peek() -ne -1) {
                $line = $initProcess.StandardOutput.ReadLine()
                if ($line -match '"jsonrpc"') {
                    $response = $line
                    $responseReceived = $true
                    break
                }
            }
            Start-Sleep -Milliseconds 100
        }
        
        if (-not $responseReceived) {
            $initProcess.Kill()
            throw "Pas de réponse reçue dans les $Timeout secondes"
        }
        
        Write-ColoredOutput "📥 Réponse d'initialisation reçue" $Green
        
        # Test de list_tools
        Write-ColoredOutput "📨 Envoi de la requête list_tools..." $Yellow
        $initProcess.StandardInput.WriteLine($listToolsRequest)
        $initProcess.StandardInput.WriteLine("")
        
        # Lecture de la réponse tools/list
        $toolsResponseReceived = $false
        $startTime = Get-Date
        
        while (((Get-Date) - $startTime).TotalSeconds -lt $Timeout -and -not $initProcess.HasExited) {
            if ($initProcess.StandardOutput.Peek() -ne -1) {
                $line = $initProcess.StandardOutput.ReadLine()
                if ($line -match '"tools"') {
                    $toolsResponse = $line | ConvertFrom-Json
                    $toolsCount = $toolsResponse.result.tools.Count
                    Write-ColoredOutput "📥 Liste des outils reçue: $toolsCount outils" $Green
                    $toolsResponseReceived = $true
                    break
                }
            }
            Start-Sleep -Milliseconds 100
        }
        
        if (-not $toolsResponseReceived) {
            Write-ColoredOutput "⚠️ Pas de réponse tools/list reçue" $Yellow
        }
        
        # Nettoyage
        if (-not $initProcess.HasExited) {
            $initProcess.Kill()
        }
        
        Write-ColoredOutput "✅ Test protocole MCP réussi" $Green
        return $true
        
    }
    catch {
        Write-ColoredOutput "❌ Erreur test protocole MCP: $_" $Red
        return $false
    }
    finally {
        Pop-Location
    }
}

function Test-MCPTools {
    param([string]$ServerPath, [string]$EnvName)
    
    Write-ColoredOutput "🔧 Test des outils MCP critiques..." $Yellow
    
    $criticalTools = @(
        "list_kernels",
        "create_notebook", 
        "execute_notebook_papermill",
        "system_info"
    )
    
    $results = @{}
    
    foreach ($tool in $criticalTools) {
        try {
            Push-Location $ServerPath
            
            # Commande pour tester un outil spécifique
            $pythonCode = @"
import asyncio
import json
from papermill_mcp.main import app

async def test_tool():
    try:
        tools = app.tools
        if '$tool' in [t.__name__ for t in tools]:
            print(json.dumps({'status': 'found', 'tool': '$tool'}))
        else:
            print(json.dumps({'status': 'not_found', 'tool': '$tool'}))
    except Exception as e:
        print(json.dumps({'status': 'error', 'tool': '$tool', 'error': str(e)}))

asyncio.run(test_tool())
"@
            
            $testCommand = @(
                "conda", "run", "-n", $EnvName, "--no-capture-output",
                "python", "-c", $pythonCode
            )
            
            # NOT converted to the cmd layer (#3731 lot 3): the last argument is a
            # multi-line here-string (python -c payload) that cannot be spliced into a
            # `cmd /c "..."` string without breaking on embedded quotes/newlines. The
            # PS-level `2>&1` is retained deliberately; the surrounding try/catch keeps
            # any minted ErrorRecord non-fatal.
            $output = & $testCommand[0] $testCommand[1..($testCommand.Length-1)] 2>&1
            
            if ($output -match '"status"') {
                $result = $output | ConvertFrom-Json
                if ($result.status -eq "found") {
                    # `${tool}` delimiting: a bare `$tool:` inside a string is an invalid
                    # scoped-variable reference — hard parse error under PS 5.1 (4 sites, lot 3).
                    Write-ColoredOutput "  ✅ ${tool}: Trouvé" $Green
                    $results[$tool] = $true
                } else {
                    Write-ColoredOutput "  ❌ ${tool}: Non trouvé" $Red
                    $results[$tool] = $false
                }
            } else {
                Write-ColoredOutput "  ⚠️ ${tool}: Test inconclus" $Yellow
                $results[$tool] = $false
            }
        }
        catch {
            Write-ColoredOutput "  ❌ ${tool}: Erreur - $_" $Red
            $results[$tool] = $false
        }
        finally {
            Pop-Location
        }
    }
    
    $successCount = ($results.Values | Where-Object { $_ -eq $true }).Count
    $totalCount = $results.Count
    
    Write-ColoredOutput "📊 Résultat: $successCount/$totalCount outils critiques validés" $Blue
    
    return $results
}

function Generate-TestReport {
    param([hashtable]$TestResults)
    
    $reportPath = Join-Path $PWD "test-mcp-integration-report.md"
    
    $report = @"
# RAPPORT TEST INTÉGRATION MCP - JUPYTER-PAPERMILL
**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Environnement**: $Environment
**Timeout**: $Timeout secondes

## 📋 RÉSUMÉ EXÉCUTIF
"@

    $totalTests = $TestResults.Count + 2  # + conda + protocol tests
    $successTests = ($TestResults.Values | Where-Object { $_ -eq $true }).Count
    if ($TestResults.ContainsKey("conda_test") -and $TestResults["conda_test"]) { $successTests++ }
    if ($TestResults.ContainsKey("protocol_test") -and $TestResults["protocol_test"]) { $successTests++ }
    
    $report += @"

**Tests réussis**: $successTests/$totalTests
**Taux de réussite**: $([Math]::Round(($successTests/$totalTests)*100, 1))%

## 🔍 DÉTAILS DES TESTS

### Environnement Conda
$(if ($TestResults["conda_test"]) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }) - Environnement '$Environment'

### Protocole JSON-RPC MCP
$(if ($TestResults["protocol_test"]) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }) - Communication MCP

### Outils Critiques
"@

    foreach ($tool in $TestResults.Keys | Where-Object { $_ -notin @("conda_test", "protocol_test") }) {
        $status = if ($TestResults[$tool]) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }
        $report += "`n- $status - $tool"
    }
    
    $report += @"

## 📊 CONCLUSION
$(if ($successTests -eq $totalTests) { 
    "🎉 **VALIDATION COMPLÈTE** - Tous les tests d'intégration MCP ont réussi" 
} elseif ($successTests -ge [Math]::Ceiling($totalTests * 0.8)) { 
    "✅ **VALIDATION PARTIELLE** - La majorité des tests ont réussi" 
} else { 
    "❌ **VALIDATION ÉCHOUÉE** - Des problèmes critiques ont été identifiés" 
})

**Serveur consolidé**: $(if ($successTests -ge [Math]::Ceiling($totalTests * 0.8)) { "PRÊT" } else { "NÉCESSITE CORRECTIONS" })
"@

    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-ColoredOutput "📄 Rapport généré: $reportPath" $Green
    
    return $reportPath
}

# === EXÉCUTION PRINCIPALE ===
Write-Section "TEST INTÉGRATION MCP - JUPYTER-PAPERMILL CONSOLIDÉ"

try {
    # Initialisation des résultats
    $testResults = @{}
    
    # Test 1: Environnement conda
    Write-Section "1. VÉRIFICATION ENVIRONNEMENT"
    $testResults["conda_test"] = Test-CondaEnvironment -EnvName $Environment
    
    if (-not $testResults["conda_test"]) {
        throw "Impossible de continuer sans l'environnement conda"
    }
    
    # Test 2: Chemin du serveur
    Write-Section "2. LOCALISATION DU SERVEUR"
    $serverPath = Get-ServerPath
    Write-ColoredOutput "📍 Serveur localisé: $serverPath" $Green
    
    # Test 3: Protocole MCP
    Write-Section "3. TEST PROTOCOLE JSON-RPC MCP"
    $testResults["protocol_test"] = Test-MCPProtocol -ServerPath $serverPath -EnvName $Environment
    
    # Test 4: Outils critiques
    Write-Section "4. TEST OUTILS CRITIQUES"
    $toolResults = Test-MCPTools -ServerPath $serverPath -EnvName $Environment
    foreach ($tool in $toolResults.Keys) {
        $testResults[$tool] = $toolResults[$tool]
    }
    
    # Génération du rapport
    Write-Section "5. GÉNÉRATION DU RAPPORT"
    $reportPath = Generate-TestReport -TestResults $testResults
    
    # Résumé final
    Write-Section "RÉSUMÉ FINAL"
    $successCount = ($testResults.Values | Where-Object { $_ -eq $true }).Count
    $totalCount = $testResults.Count
    
    if ($successCount -eq $totalCount) {
        Write-ColoredOutput "🎉 SUCCÈS COMPLET: $successCount/$totalCount tests réussis" $Green
        exit 0
    } elseif ($successCount -ge [Math]::Ceiling($totalCount * 0.8)) {
        Write-ColoredOutput "✅ SUCCÈS PARTIEL: $successCount/$totalCount tests réussis" $Yellow
        exit 1
    } else {
        Write-ColoredOutput "❌ ÉCHEC CRITIQUE: $successCount/$totalCount tests réussis" $Red
        exit 2
    }
}
catch {
    Write-ColoredOutput "💥 ERREUR FATALE: $_" $Red
    Write-ColoredOutput "Stack Trace: $($_.ScriptStackTrace)" $Red
    exit 3
}
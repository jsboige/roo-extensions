# Script PowerShell pour exécuter tous les tests des MCPs
# Ce script exécute les tests pour tous les MCPs et génère un rapport global

# Définir les couleurs pour la console
$ESC = [char]27
$RESET = "$ESC[0m"
$RED = "$ESC[31m"
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$BLUE = "$ESC[34m"
$MAGENTA = "$ESC[35m"
$CYAN = "$ESC[36m"

# Fonction pour afficher un message avec une couleur
function Write-ColorMessage {
    param (
        [string]$Message,
        [string]$Color = $RESET
    )
    Write-Host "$Color$Message$RESET"
}

# Créer le répertoire de rapports s'il n'existe pas
$reportsDir = Join-Path $PSScriptRoot "reports"
if (-not (Test-Path $reportsDir)) {
    New-Item -Path $reportsDir -ItemType Directory | Out-Null
}

# Timestamp pour le rapport global
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$globalReportPath = Join-Path $reportsDir "global-test-report-$timestamp.md"

# Initialiser le rapport global
$globalReport = @"
# Rapport global des tests MCP

Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Résumé

"@

# Liste des scripts de test à exécuter
$testScripts = @(
    "test-quickfiles.js",
    "test-jinavigator.js",
    "test-jupyter.js",
    "../internal/servers/roo-state-manager/build/tests/suite/index.js"
)

# Variables pour le résumé
$totalTests = 0
$passedTests = 0
$failedTests = 0
$results = @()

# Exécuter chaque script de test
foreach ($script in $testScripts) {
    $scriptPath = Join-Path $PSScriptRoot $script
    
    if (Test-Path $scriptPath) {
        Write-ColorMessage "=== Exécution du test: $script ===" $CYAN
        
        try {
            # Exécuter le script avec Node.js
            $startTime = Get-Date
            if ($script -like "*roo-state-manager*") {
                Push-Location ../internal/servers/roo-state-manager; npm test; Pop-Location
            } else {
                node $scriptPath
            }
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            
            # Supposer que le test a réussi s'il n'y a pas d'erreur
            $status = "Réussi"
            $statusColor = $GREEN
            $passedTests++
            
            Write-ColorMessage "✓ Test $script terminé avec succès en $duration secondes" $GREEN
        }
        catch {
            # Le test a échoué
            $status = "Échoué"
            $statusColor = $RED
            $failedTests++
            
            Write-ColorMessage "✗ Test $script échoué: $_" $RED
        }
        
        $totalTests++
        
        # Ajouter le résultat au tableau
        $results += [PSCustomObject]@{
            Script = $script
            Status = $status
            Duration = [math]::Round($duration, 2)
        }
        
        Write-ColorMessage "----------------------------------------" $RESET
    }
    else {
        Write-ColorMessage "✗ Script de test non trouvé: $scriptPath" $RED
    }
}

# Ajouter le résumé au rapport global
$globalReport += @"

- Tests exécutés: $totalTests
- Tests réussis: $passedTests
- Tests échoués: $failedTests

## Détails des tests

| Script | Statut | Durée (s) |
|--------|--------|-----------|
"@

foreach ($result in $results) {
    $globalReport += "`n| $($result.Script) | $($result.Status) | $($result.Duration) |"
}

# Ajouter les rapports individuels au rapport global
$globalReport += @"

## Rapports individuels

Les rapports détaillés pour chaque MCP se trouvent dans le répertoire `reports`.

"@

# Écrire le rapport global dans un fichier
$globalReport | Out-File -FilePath $globalReportPath -Encoding utf8

Write-ColorMessage "`n=== Résumé des tests ===" $CYAN
Write-ColorMessage "Tests exécutés: $totalTests" $RESET
Write-ColorMessage "Tests réussis: $passedTests" $GREEN
Write-ColorMessage "Tests échoués: $failedTests" $RED
Write-ColorMessage "`nRapport global généré: $globalReportPath" $CYAN

# Retourner un code de sortie en fonction du résultat des tests
if ($failedTests -gt 0) {
    exit 1
}
else {
    exit 0
}
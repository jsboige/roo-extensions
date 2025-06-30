# Script PowerShell pour les tests complets du MCP GitHub Projects
# Ce script teste toutes les fonctionnalités, la robustesse et les performances du MCP

# Configuration
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"
$startTime = Get-Date

# Définir les variables d'environnement pour les tests
$env:GITHUB_TEST_OWNER = "votre-nom-utilisateur" # À remplacer par votre nom d'utilisateur GitHub
$env:GITHUB_TEST_REPO = "votre-repo-test" # À remplacer par un repo de test

# Fonction pour afficher les messages de log
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "TEST")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        "INFO" = "White"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
        "SUCCESS" = "Green"
        "TEST" = "Cyan"
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colorMap[$Level]
}

# Fonction pour mesurer le temps d'exécution d'une commande
function Measure-CommandExecution {
    param (
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $startTime = Get-Date
    try {
        $result = & $ScriptBlock
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        return @{
            Name = $Name
            Success = $true
            Duration = $duration
            Result = $result
        }
    } catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        return @{
            Name = $Name
            Success = $false
            Duration = $duration
            Error = $_
        }
    }
}

# Fonction pour vérifier si le serveur MCP est en cours d'exécution
function Test-MCPServerRunning {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerHost,
        
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    
# Fonction pour démarrer le serveur MCP
function Start-MCPServer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerPath
    )
    
    try {
        # Vérifier si le répertoire du serveur existe
        if (-not (Test-Path $ServerPath)) {
            Write-Log "Le répertoire du serveur n'existe pas: $ServerPath" -Level "ERROR"
            return $false
        }
        
        # Vérifier si le fichier start-server.js existe
        $startServerPath = Join-Path $ServerPath "start-server.js"
        if (-not (Test-Path $startServerPath)) {
            Write-Log "Le fichier start-server.js n'existe pas: $startServerPath" -Level "ERROR"
            return $false
        }
        
        # Démarrer le serveur en arrière-plan
        Write-Log "Démarrage du serveur MCP GitHub Projects..." -Level "INFO"
        Start-Process -FilePath "node" -ArgumentList $startServerPath -WorkingDirectory $ServerPath -NoNewWindow
        
        # Attendre que le serveur démarre
        Write-Log "Attente du démarrage du serveur..." -Level "INFO"
        $maxRetries = 10
        $retryCount = 0
        $serverStarted = $false
        
        while (-not $serverStarted -and $retryCount -lt $maxRetries) {
            Start-Sleep -Seconds 2
            $serverStarted = Test-MCPServerRunning -ServerHost "localhost" -Port 3002
            $retryCount++
        }
        
        if ($serverStarted) {
            Write-Log "Serveur MCP démarré avec succès" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Impossible de démarrer le serveur MCP après $maxRetries tentatives" -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log "Erreur lors du démarrage du serveur: $_" -Level "ERROR"
        return $false
    }
}

# Fonction pour invoquer un outil MCP
function Invoke-MCPTool {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ToolName,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Arguments,
        
        [Parameter(Mandatory=$false)]
        [switch]$MeasurePerformance
    )
    
    try {
        $uri = "http://localhost:3002/api/mcp/invoke"
        $body = @{
            tool_name = $ToolName
            arguments = $Arguments
        } | ConvertTo-Json
        
        if ($MeasurePerformance) {
            $result = Measure-CommandExecution -ScriptBlock {
                Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
            } -Name $ToolName
            
            return $result
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
            return @{
                Success = $true
                Result = $response
            }
        }
    } catch {
        if ($MeasurePerformance) {
            return @{
                Name = $ToolName
                Success = $false
                Duration = 0
                Error = $_
            }
        } else {
            return @{
                Success = $false
                Error = $_
            }
        }
    }
}

# Fonction pour accéder à une ressource MCP
function Get-MCPResource {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        
        [Parameter(Mandatory=$false)]
        [switch]$MeasurePerformance
    )
    
    try {
        $encodedUri = [System.Web.HttpUtility]::UrlEncode($Uri)
        $requestUri = "http://localhost:3002/api/mcp/resource/$encodedUri"
        
        if ($MeasurePerformance) {
            $result = Measure-CommandExecution -ScriptBlock {
                Invoke-RestMethod -Uri $requestUri -Method Get
            } -Name "Resource: $Uri"
            
            return $result
# Fonction pour exécuter un test et enregistrer le résultat
function Invoke-Test {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$Test,
        
        [Parameter(Mandatory=$false)]
        [string]$Category = "Fonctionnel",
        
        [Parameter(Mandatory=$false)]
        [switch]$MeasurePerformance
    )
    
    Write-Log "Exécution du test: $Name" -Level "TEST"
    
    try {
        if ($MeasurePerformance) {
            $result = Measure-CommandExecution -ScriptBlock $Test -Name $Name
            
            if ($result.Success) {
                Write-Log "Test réussi: $Name (Durée: $($result.Duration) ms)" -Level "SUCCESS"
            } else {
                Write-Log "Test échoué: $Name (Durée: $($result.Duration) ms)" -Level "ERROR"
                Write-Log "Erreur: $($result.Error)" -Level "ERROR"
            }
            
            return @{
                Name = $Name
                Category = $Category
                Success = $result.Success
                Duration = $result.Duration
                Error = if (-not $result.Success) { $result.Error.ToString() } else { $null }
                Result = if ($result.Success) { $result.Result } else { $null }
            }
        } else {
            $startTime = Get-Date
            $result = & $Test
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds
            
            if ($result.Success) {
                Write-Log "Test réussi: $Name" -Level "SUCCESS"
            } else {
                Write-Log "Test échoué: $Name" -Level "ERROR"
                Write-Log "Erreur: $($result.Error)" -Level "ERROR"
            }
            
            return @{
                Name = $Name
                Category = $Category
                Success = $result.Success
                Duration = $duration
                Error = if (-not $result.Success) { $result.Error.ToString() } else { $null }
                Result = if ($result.Success) { $result.Result } else { $null }
            }
        }
    } catch {
        Write-Log "Exception lors de l'exécution du test: $Name" -Level "ERROR"
        Write-Log "Erreur: $_" -Level "ERROR"
        
        return @{
            Name = $Name
            Category = $Category
            Success = $false
            Duration = 0
            Error = $_.ToString()
            Result = $null
        }
    }
}

# Fonction pour générer un rapport de test
function New-TestReport {
    param (
        [Parameter(Mandatory=$true)]
        [array]$TestResults,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    $totalTests = $TestResults.Count
    $passedTests = ($TestResults | Where-Object { $_.Success }).Count
    $failedTests = $totalTests - $passedTests
    $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
    
    $totalDuration = ($TestResults | Measure-Object -Property Duration -Sum).Sum
    $averageDuration = if ($totalTests -gt 0) { [math]::Round($totalDuration / $totalTests, 2) } else { 0 }
    
    $categories = $TestResults | Group-Object -Property Category
    
    $report = @"
# Rapport de test du MCP GitHub Projects

Date d'exécution: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Résumé

- **Total des tests**: $totalTests
- **Tests réussis**: $passedTests
- **Tests échoués**: $failedTests
- **Taux de réussite**: $successRate%
- **Durée totale**: $([math]::Round($totalDuration / 1000, 2)) secondes
- **Durée moyenne par test**: $averageDuration ms

## Résultats par catégorie

$(foreach ($category in $categories) {
    $categoryTests = $category.Group
    $categoryPassedTests = ($categoryTests | Where-Object { $_.Success }).Count
    $categorySuccessRate = if ($categoryTests.Count -gt 0) { [math]::Round(($categoryPassedTests / $categoryTests.Count) * 100, 2) } else { 0 }
    
"### $($category.Name)

- **Total des tests**: $($categoryTests.Count)
- **Tests réussis**: $categoryPassedTests
- **Tests échoués**: $($categoryTests.Count - $categoryPassedTests)
- **Taux de réussite**: $categorySuccessRate%

"
})

## Détails des tests

$(foreach ($test in $TestResults) {
    $status = if ($test.Success) { "✅ Réussi" } else { "❌ Échoué" }
    
"### $($test.Name) - $status

- **Catégorie**: $($test.Category)
- **Durée**: $([math]::Round($test.Duration, 2)) ms
$(if (-not $test.Success) {
"- **Erreur**: ```
$($test.Error)
```"
})

"
})

## Performance

### Tests les plus lents

$(
    $slowestTests = $TestResults | Sort-Object -Property Duration -Descending | Select-Object -First 5
    foreach ($test in $slowestTests) {
        "- **$($test.Name)**: $([math]::Round($test.Duration, 2)) ms"
    }
)

### Tests les plus rapides

$(
    $fastestTests = $TestResults | Sort-Object -Property Duration | Select-Object -First 5
    foreach ($test in $fastestTests) {
        "- **$($test.Name)**: $([math]::Round($test.Duration, 2)) ms"
    }
)

## Recommandations

$(
    if ($failedTests -gt 0) {
        "- Corriger les tests échoués, en particulier dans les catégories avec un faible taux de réussite"
    }
    
# Vérifier si le serveur MCP est en cours d'exécution
$serverPath = "D:\roo-extensions\mcps\mcp-servers\servers\github-projects-mcp"
$serverRunning = Test-MCPServerRunning -ServerHost "localhost" -Port 3002

if (-not $serverRunning) {
    Write-Log "Le serveur MCP n'est pas en cours d'exécution." -Level "WARNING"
    $startServer = Read-Host "Voulez-vous démarrer le serveur MCP? (O/N)"
    if ($startServer -eq "O" -or $startServer -eq "o") {
        $serverStarted = Start-MCPServer -ServerPath $serverPath
        if (-not $serverStarted) {
            Write-Log "Impossible de démarrer le serveur MCP. Les tests ne peuvent pas être exécutés." -Level "ERROR"
            exit 1
        }
    } else {
        Write-Log "Les tests ne peuvent pas être exécutés sans le serveur MCP." -Level "ERROR"
        exit 1
    }
}

# Initialiser le tableau des résultats de test
$testResults = @()

# Tests fonctionnels
Write-Log "=== Tests fonctionnels ===" -Level "INFO"

# Test 1: Vérification de la disponibilité du serveur
$testResults += Invoke-Test -Name "Vérification de la disponibilité du serveur" -Category "Fonctionnel" {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:3002/api/mcp/status" -Method GET
        return @{
            Success = $true
            Result = $response
        }
    } catch {
        return @{
            Success = $false
            Error = $_
        }
    }
}

# Test 2: Récupération des outils disponibles
$testResults += Invoke-Test -Name "Récupération des outils disponibles" -Category "Fonctionnel" {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:3002/api/mcp/discovery" -Method GET
        return @{
            Success = $true
            Result = $response
        }
    } catch {
        return @{
            Success = $false
            Error = $_
        }
    }
}

# Test 3: Création d'un projet
$projectTitle = "Projet de test $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$projectDescription = "Projet créé automatiquement pour les tests unitaires"

$testResults += Invoke-Test -Name "Création d'un projet" -Category "Fonctionnel" {
    $result = Invoke-MCPTool -ToolName "create_project" -Arguments @{
        owner = $env:GITHUB_TEST_OWNER
        title = $projectTitle
        description = $projectDescription
        type = "user"
    }
    
    # Stocker l'ID du projet pour les tests suivants
    if ($result.Success) {
        $script:projectId = $result.Result.project.id
        $script:projectNumber = $result.Result.project.number
    }
    
    return $result
}

# Test 4: Récupération des détails d'un projet
$testResults += Invoke-Test -Name "Récupération des détails d'un projet" -Category "Fonctionnel" {
    if (-not $script:projectNumber) {
        return @{
            Success = $false
            Error = "Aucun projet créé pour le test"
        }
    }
    
    $result = Invoke-MCPTool -ToolName "get_project" -Arguments @{
        owner = $env:GITHUB_TEST_OWNER
        project_number = $script:projectNumber
    }
    
    return $result
}

# Test 5: Ajout d'un élément au projet (note)
$noteTitle = "Note de test $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$noteBody = "Note créée automatiquement pour les tests unitaires"

$testResults += Invoke-Test -Name "Ajout d'une note au projet" -Category "Fonctionnel" {
    if (-not $script:projectId) {
        return @{
            Success = $false
            Error = "Aucun projet créé pour le test"
        }
    }
    
    $result = Invoke-MCPTool -ToolName "add_item_to_project" -Arguments @{
        project_id = $script:projectId
        content_type = "draft_issue"
        draft_title = $noteTitle
        draft_body = $noteBody
    }
    
    # Stocker l'ID de l'élément pour les tests suivants
    if ($result.Success) {
        $script:itemId = $result.Result.item_id
    }
    
    return $result
}

# Test 6: Récupération des champs du projet
$testResults += Invoke-Test -Name "Récupération des champs du projet" -Category "Fonctionnel" {
    if (-not $script:projectNumber) {
        return @{
            Success = $false
            Error = "Aucun projet créé pour le test"
        }
    }
    
    $result = Invoke-MCPTool -ToolName "get_project_fields" -Arguments @{
        owner = $env:GITHUB_TEST_OWNER
        project_number = $script:projectNumber
    }
    
    # Stocker un champ de type texte pour les tests suivants
    if ($result.Success) {
        $script:textField = $result.Result.fields | Where-Object { $_.type -eq "TEXT" } | Select-Object -First 1
    }
    
    return $result
}

# Test 7: Mise à jour d'un champ d'un élément
$testResults += Invoke-Test -Name "Mise à jour d'un champ d'un élément" -Category "Fonctionnel" {
    if (-not $script:projectId -or -not $script:itemId -or -not $script:textField) {
        return @{
            Success = $false
            Error = "Données manquantes pour le test"
        }
    }
    
    $result = Invoke-MCPTool -ToolName "update_project_item_field" -Arguments @{
        project_id = $script:projectId
        item_id = $script:itemId
        field_id = $script:textField.id
        field_type = "text"
        value = "Valeur mise à jour $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
    
    return $result
}

# Test 8: Suppression d'un élément du projet
$testResults += Invoke-Test -Name "Suppression d'un élément du projet" -Category "Fonctionnel" {
    if (-not $script:projectNumber -or -not $script:itemId) {
        return @{
            Success = $false
            Error = "Données manquantes pour le test"
        }
    }
    
    $result = Invoke-MCPTool -ToolName "delete_project_item" -Arguments @{
        owner = $env:GITHUB_TEST_OWNER
        project_number = $script:projectNumber
        item_id = $script:itemId
    }
    
    return $result
}

# Test 9: Accès à la ressource projects
$testResults += Invoke-Test -Name "Accès à la ressource projects" -Category "Fonctionnel" {
    $uri = "github-projects://${env:GITHUB_TEST_OWNER}/user?state=open"
    $result = Get-MCPResource -Uri $uri
    
    return $result
}

# Test 10: Accès à la ressource project
$testResults += Invoke-Test -Name "Accès à la ressource project" -Category "Fonctionnel" {
    if (-not $script:projectNumber) {
        return @{
            Success = $false
            Error = "Aucun projet créé pour le test"
        }
    }
    
    $uri = "github-project://${env:GITHUB_TEST_OWNER}/${script:projectNumber}"
# Tests de robustesse
Write-Log "=== Tests de robustesse ===" -Level "INFO"

# Test 11: Création d'un projet avec des paramètres invalides
$testResults += Invoke-Test -Name "Création d'un projet avec des paramètres invalides" -Category "Robustesse" {
    $result = Invoke-MCPTool -ToolName "create_project" -Arguments @{
        owner = "utilisateur_inexistant_123456789"
        title = "Projet invalide"
        type = "user"
    }
    
    # Ce test doit échouer, donc on inverse le résultat
    return @{
        Success = -not $result.Success
        Result = $result.Result
        Error = if ($result.Success) { "Le test aurait dû échouer" } else { $result.Error }
    }
}

# Test 12: Récupération d'un projet inexistant
$testResults += Invoke-Test -Name "Récupération d'un projet inexistant" -Category "Robustesse" {
    $result = Invoke-MCPTool -ToolName "get_project" -Arguments @{
        owner = $env:GITHUB_TEST_OWNER
        project_number = 999999
    }
    
    # Ce test doit échouer, donc on inverse le résultat
    return @{
        Success = -not $result.Success
        Result = $result.Result
        Error = if ($result.Success) { "Le test aurait dû échouer" } else { $result.Error }
    }
}

# Test 13: Mise à jour d'un champ avec un ID invalide
$testResults += Invoke-Test -Name "Mise à jour d'un champ avec un ID invalide" -Category "Robustesse" {
    if (-not $script:projectId -or -not $script:itemId) {
        return @{
            Success = $false
            Error = "Données manquantes pour le test"
        }
    }
    
    $result = Invoke-MCPTool -ToolName "update_project_item_field" -Arguments @{
        project_id = $script:projectId
        item_id = $script:itemId
        field_id = "champ_invalide_123456789"
        field_type = "text"
        value = "Valeur invalide"
    }
    
    # Ce test doit échouer, donc on inverse le résultat
    return @{
        Success = -not $result.Success
        Result = $result.Result
        Error = if ($result.Success) { "Le test aurait dû échouer" } else { $result.Error }
    }
}

# Test 14: Accès à une ressource avec un URI invalide
$testResults += Invoke-Test -Name "Accès à une ressource avec un URI invalide" -Category "Robustesse" {
    $uri = "github-projects://utilisateur_inexistant_123456789/user?state=open"
    $result = Get-MCPResource -Uri $uri
    
    # Ce test doit échouer, donc on inverse le résultat
    return @{
        Success = -not $result.Success
        Result = $result.Result
        Error = if ($result.Success) { "Le test aurait dû échouer" } else { $result.Error }
    }
}

# Test 15: Invocation d'un outil inexistant
$testResults += Invoke-Test -Name "Invocation d'un outil inexistant" -Category "Robustesse" {
    $result = Invoke-MCPTool -ToolName "outil_inexistant" -Arguments @{
        param1 = "valeur1"
    }
    
    # Ce test doit échouer, donc on inverse le résultat
    return @{
        Success = -not $result.Success
        Result = $result.Result
        Error = if ($result.Success) { "Le test aurait dû échouer" } else { $result.Error }
    }
}

# Tests de performance
Write-Log "=== Tests de performance ===" -Level "INFO"

# Test 16: Performance de la création d'un projet
$testResults += Invoke-Test -Name "Performance de la création d'un projet" -Category "Performance" -MeasurePerformance {
    $projectTitle = "Projet de performance $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    $result = Invoke-MCPTool -ToolName "create_project" -Arguments @{
        owner = $env:GITHUB_TEST_OWNER
        title = $projectTitle
        description = "Projet créé pour les tests de performance"
        type = "user"
    } -MeasurePerformance
    
    # Stocker l'ID du projet pour les tests suivants
    if ($result.Success) {
        $script:perfProjectId = $result.Result.project.id
        $script:perfProjectNumber = $result.Result.project.number
    }
    
    return $result
}

# Test 17: Performance de la récupération des détails d'un projet
$testResults += Invoke-Test -Name "Performance de la récupération des détails d'un projet" -Category "Performance" -MeasurePerformance {
    if (-not $script:perfProjectNumber) {
        return @{
            Success = $false
            Error = "Aucun projet créé pour le test de performance"
        }
    }
    
    $result = Invoke-MCPTool -ToolName "get_project" -Arguments @{
        owner = $env:GITHUB_TEST_OWNER
        project_number = $script:perfProjectNumber
    } -MeasurePerformance
    
    return $result
}

# Test 18: Performance de l'ajout d'un élément au projet
$testResults += Invoke-Test -Name "Performance de l'ajout d'un élément au projet" -Category "Performance" -MeasurePerformance {
    if (-not $script:perfProjectId) {
        return @{
            Success = $false
            Error = "Aucun projet créé pour le test de performance"
        }
    }
    
    $noteTitle = "Note de performance $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    $result = Invoke-MCPTool -ToolName "add_item_to_project" -Arguments @{
        project_id = $script:perfProjectId
        content_type = "draft_issue"
        draft_title = $noteTitle
        draft_body = "Note créée pour les tests de performance"
    } -MeasurePerformance
    
    # Stocker l'ID de l'élément pour les tests suivants
    if ($result.Success) {
        $script:perfItemId = $result.Result.item_id
    }
    
    return $result
}

# Test 19: Performance de l'accès à la ressource projects
$testResults += Invoke-Test -Name "Performance de l'accès à la ressource projects" -Category "Performance" -MeasurePerformance {
    $uri = "github-projects://${env:GITHUB_TEST_OWNER}/user?state=open"
    $result = Get-MCPResource -Uri $uri -MeasurePerformance
    
    return $result
}

# Test 20: Performance de l'accès à la ressource project
$testResults += Invoke-Test -Name "Performance de l'accès à la ressource project" -Category "Performance" -MeasurePerformance {
    if (-not $script:perfProjectNumber) {
        return @{
            Success = $false
            Error = "Aucun projet créé pour le test de performance"
        }
    }
    
    $uri = "github-project://${env:GITHUB_TEST_OWNER}/${script:perfProjectNumber}"
    $result = Get-MCPResource -Uri $uri -MeasurePerformance
    
    return $result
}
    $result = Get-MCPResource -Uri $uri
    
    return $result
}
    if (($TestResults | Where-Object { $_.Duration -gt 1000 }).Count -gt 0) {
        "- Optimiser les performances des tests les plus lents"
    }
)

"@
    
    $report | Out-File -FilePath $OutputPath -Encoding utf8
    Write-Log "Rapport de test généré: $OutputPath" -Level "SUCCESS"
}
        } else {
            $response = Invoke-RestMethod -Uri $requestUri -Method Get
            return @{
                Success = $true
                Result = $response
            }
        }
    } catch {
        if ($MeasurePerformance) {
            return @{
                Name = "Resource: $Uri"
                Success = $false
                Duration = 0
                Error = $_
            }
        } else {
            return @{
                Success = $false
                Error = $_
            }
        }
    }
}
# Générer le rapport de test
$reportPath = "D:\roo-extensions\mcps\tests\github-projects\rapport-test-complet.md"
New-TestReport -TestResults $testResults -OutputPath $reportPath

# Afficher un résumé des résultats
$totalTests = $testResults.Count
$passedTests = ($TestResults | Where-Object { $_.Success }).Count
$failedTests = $totalTests - $passedTests
$successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }

$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalSeconds

Write-Log "=== Résumé des tests ===" -Level "INFO"
Write-Log "Total des tests: $totalTests" -Level "INFO"
Write-Log "Tests réussis: $passedTests" -Level "INFO"
Write-Log "Tests échoués: $failedTests" -Level "INFO"
Write-Log "Taux de réussite: $successRate%" -Level "INFO"
Write-Log "Durée totale: $([math]::Round($totalDuration, 2)) secondes" -Level "INFO"
Write-Log "Rapport de test généré: $reportPath" -Level "INFO"

# Retourner le code de sortie en fonction du résultat des tests
if ($failedTests -gt 0) {
    Write-Log "Des tests ont échoué. Consultez le rapport pour plus de détails." -Level "ERROR"
    exit 1
} else {
    Write-Log "Tous les tests ont réussi!" -Level "SUCCESS"
    exit 0
}
    try {
        $response = Invoke-WebRequest -Uri "http://${ServerHost}:${Port}/api/mcp/status" -Method GET -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            return $true
        }
    } catch {
        return $false
    }
    
    return $false
}
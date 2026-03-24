# Script d'analyse des traces Roo et sessions Claude pour la méta-analyse (Version 2)
# Analyse améliorée des patterns de succès/échec/escalades

$ErrorActionPreference = "Stop"

# Chemins
$rooTasksPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"
$claudeProjectsPath = "$env:USERPROFILE\.claude\projects"
$workspacePath = "c:\dev\roo-extensions"

# Fonction pour lire les métadonnées d'une tâche Roo
function Get-RooTaskMetadata {
    param($taskId)
    
    $taskPath = Join-Path $rooTasksPath $taskId
    $metadataPath = Join-Path $taskPath "task_metadata.json"
    
    if (Test-Path $metadataPath) {
        $metadata = Get-Content $metadataPath | ConvertFrom-Json
        return $metadata
    }
    return $null
}

# Fonction pour analyser une tâche Roo
function Analyze-RooTask {
    param($taskId)
    
    $taskPath = Join-Path $rooTasksPath $taskId
    $historyPath = Join-Path $taskPath "api_conversation_history.json"
    
    if (-not (Test-Path $historyPath)) {
        return $null
    }
    
    $history = Get-Content $historyPath | ConvertFrom-Json
    
    $result = @{
        TaskId = $taskId
        Mode = "unknown"
        Success = $false
        Escalations = 0
        ToolsUsed = @()
        Errors = @()
        MessageCount = $history.Count
        NewTaskCalls = @()
        ErrorTypes = @{}
    }
    
    # Analyser les messages pour extraire les patterns
    foreach ($msg in $history) {
        # Déterminer le mode depuis le premier message user
        if ($msg.role -eq "user" -and $result.Mode -eq "unknown") {
            if ($msg.content -match "mode.*code-simple|code-complex|ask-simple|ask-complex|debug-simple|debug-complex|architect-simple|architect-complex|orchestrator-simple|orchestrator-complex") {
                if ($msg.content -match "-simple") {
                    $result.Mode = "simple"
                } elseif ($msg.content -match "-complex") {
                    $result.Mode = "complex"
                }
            }
        }
        
        # Détecter les escalades (new_task avec mode -complex)
        if ($msg.role -eq "assistant") {
            if ($msg.content -match "new_task.*mode.*-complex") {
                $result.Escalations++
                $result.NewTaskCalls += "simple->complex"
            } elseif ($msg.content -match "new_task.*mode.*-simple") {
                $result.NewTaskCalls += "complex->simple"
            }
        }
        
        # Détecter les outils utilisés
        if ($msg.role -eq "assistant") {
            if ($msg.content -match "execute_command") { 
                $result.ToolsUsed += "execute_command"
                # Détecter win-cli vs terminal natif
                if ($msg.content -match "win-cli|mcp--win-cli") {
                    $result.ToolsUsed += "win-cli"
                }
            }
            if ($msg.content -match "read_file") { $result.ToolsUsed += "read_file" }
            if ($msg.content -match "write_to_file") { $result.ToolsUsed += "write_to_file" }
            if ($msg.content -match "apply_diff") { $result.ToolsUsed += "apply_diff" }
            if ($msg.content -match "roosync_") { 
                $result.ToolsUsed += "roosync_*"
                # Détecter les outils roosync spécifiques
                if ($msg.content -match "roosync_send") { $result.ToolsUsed += "roosync_send" }
                if ($msg.content -match "roosync_read") { $result.ToolsUsed += "roosync_read" }
                if ($msg.content -match "roosync_dashboard") { $result.ToolsUsed += "roosync_dashboard" }
                if ($msg.content -match "roosync_config") { $result.ToolsUsed += "roosync_config" }
                if ($msg.content -match "roosync_heartbeat") { $result.ToolsUsed += "roosync_heartbeat" }
            }
            if ($msg.content -match "conversation_browser") { $result.ToolsUsed += "conversation_browser" }
            if ($msg.content -match "codebase_search") { $result.ToolsUsed += "codebase_search" }
            if ($msg.content -match "roosync_search") { $result.ToolsUsed += "roosync_search" }
        }
        
        # Détecter les erreurs et les catégoriser
        if ($msg.role -eq "assistant" -or $msg.role -eq "tool") {
            if ($msg.content -match "error|failed|timeout|not found|exception") {
                $result.Errors += "Error detected"
                
                # Catégoriser les erreurs
                if ($msg.content -match "MCP.*not available|tool not found") {
                    if ($result.ErrorTypes.ContainsKey("MCP unavailable")) {
                        $result.ErrorTypes["MCP unavailable"]++
                    } else {
                        $result.ErrorTypes["MCP unavailable"] = 1
                    }
                } elseif ($msg.content -match "timeout") {
                    if ($result.ErrorTypes.ContainsKey("Timeout")) {
                        $result.ErrorTypes["Timeout"]++
                    } else {
                        $result.ErrorTypes["Timeout"] = 1
                    }
                } elseif ($msg.content -match "file not found|path not found") {
                    if ($result.ErrorTypes.ContainsKey("File not found")) {
                        $result.ErrorTypes["File not found"]++
                    } else {
                        $result.ErrorTypes["File not found"] = 1
                    }
                } elseif ($msg.content -match "permission|access denied") {
                    if ($result.ErrorTypes.ContainsKey("Permission error")) {
                        $result.ErrorTypes["Permission error"]++
                    } else {
                        $result.ErrorTypes["Permission error"] = 1
                    }
                } else {
                    if ($result.ErrorTypes.ContainsKey("Other error")) {
                        $result.ErrorTypes["Other error"]++
                    } else {
                        $result.ErrorTypes["Other error"] = 1
                    }
                }
            }
        }
    }
    
    # Déterminer le succès (basé sur attempt_completion)
    $lastMessage = $history | Select-Object -Last 1
    if ($lastMessage.role -eq "assistant" -and $lastMessage.content -match "attempt_completion") {
        $result.Success = $true
    }
    
    return $result
}

# Fonction pour analyser une session Claude
function Analyze-ClaudeSession {
    param($sessionPath)
    
    if (-not (Test-Path $sessionPath)) {
        return $null
    }
    
    $lines = Get-Content $sessionPath
    $result = @{
        SessionPath = $sessionPath
        MessageCount = $lines.Count
        ToolsUsed = @()
        Errors = @()
        Success = $false
        ErrorTypes = @{}
    }
    
    foreach ($line in $lines) {
        try {
            $msg = $line | ConvertFrom-Json
            
            # Détecter les outils utilisés
            if ($msg.type -eq "tool_use") {
                $result.ToolsUsed += $msg.name
            }
            
            # Détecter les erreurs
            if ($msg.type -eq "tool_result" -and $msg.content -match "error|failed|timeout") {
                $result.Errors += "Tool error: $($msg.name)"
                
                # Catégoriser les erreurs
                if ($msg.content -match "MCP.*not available|tool not found") {
                    if ($result.ErrorTypes.ContainsKey("MCP unavailable")) {
                        $result.ErrorTypes["MCP unavailable"]++
                    } else {
                        $result.ErrorTypes["MCP unavailable"] = 1
                    }
                } elseif ($msg.content -match "timeout") {
                    if ($result.ErrorTypes.ContainsKey("Timeout")) {
                        $result.ErrorTypes["Timeout"]++
                    } else {
                        $result.ErrorTypes["Timeout"] = 1
                    }
                } else {
                    if ($result.ErrorTypes.ContainsKey("Other error")) {
                        $result.ErrorTypes["Other error"]++
                    } else {
                        $result.ErrorTypes["Other error"] = 1
                    }
                }
            }
        } catch {
            # Ignorer les lignes mal formatées
        }
    }
    
    return $result
}

# Collecter toutes les tâches Roo récentes
Write-Host "Collecte des tâches Roo..." -ForegroundColor Cyan
$allRooTasks = Get-ChildItem $rooTasksPath -Directory | 
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
    Select-Object -First 30

Write-Host "Tâches Roo trouvées: $($allRooTasks.Count)" -ForegroundColor Green

# Analyser les tâches Roo
$rooAnalysisResults = @()
foreach ($task in $allRooTasks) {
    $taskId = $task.Name
    $analysis = Analyze-RooTask -taskId $taskId
    if ($analysis) {
        $rooAnalysisResults += $analysis
    }
}

Write-Host "Tâches Roo analysées: $($rooAnalysisResults.Count)" -ForegroundColor Green

# Collecter les sessions Claude récentes
Write-Host "`nCollecte des sessions Claude..." -ForegroundColor Cyan
$allClaudeSessions = Get-ChildItem $claudeProjectsPath -Recurse -Filter "*.jsonl" |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
    Select-Object -First 30

Write-Host "Sessions Claude trouvées: $($allClaudeSessions.Count)" -ForegroundColor Green

# Analyser les sessions Claude
$claudeAnalysisResults = @()
foreach ($session in $allClaudeSessions) {
    $analysis = Analyze-ClaudeSession -sessionPath $session.FullName
    if ($analysis) {
        $claudeAnalysisResults += $analysis
    }
}

Write-Host "Sessions Claude analysées: $($claudeAnalysisResults.Count)" -ForegroundColor Green

# Générer le rapport
Write-Host "`n=== RAPPORT D'ANALYSE ===" -ForegroundColor Yellow
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "Période: 7 derniers jours" -ForegroundColor White
Write-Host ""

# Stats globales Roo
Write-Host "=== STATS GLOBALES ROO ===" -ForegroundColor Cyan
Write-Host "Tâches analysées: $($rooAnalysisResults.Count)" -ForegroundColor White
$successCount = ($rooAnalysisResults | Where-Object { $_.Success }).Count
Write-Host "Taux de succès: $([math]::Round($successCount / $rooAnalysisResults.Count * 100, 2))%" -ForegroundColor White

$escalationCount = ($rooAnalysisResults | Where-Object { $_.Escalations -gt 0 }).Count
Write-Host "Tâches avec escalade: $escalationCount ($([math]::Round($escalationCount / $rooAnalysisResults.Count * 100, 2))%)" -ForegroundColor White

$errorCount = ($rooAnalysisResults | Where-Object { $_.Errors.Count -gt 0 }).Count
Write-Host "Tâches avec erreurs: $errorCount ($([math]::Round($errorCount / $rooAnalysisResults.Count * 100, 2))%)" -ForegroundColor White

# Stats par mode
Write-Host "`n=== STATS PAR MODE ===" -ForegroundColor Cyan
$simpleTasks = $rooAnalysisResults | Where-Object { $_.Mode -eq "simple" }
$complexTasks = $rooAnalysisResults | Where-Object { $_.Mode -eq "complex" }
$unknownTasks = $rooAnalysisResults | Where-Object { $_.Mode -eq "unknown" }

if ($simpleTasks) {
    $simpleSuccess = ($simpleTasks | Where-Object { $_.Success }).Count
    $simpleEscalations = ($simpleTasks | Where-Object { $_.Escalations -gt 0 }).Count
    Write-Host "Mode -simple: $($simpleTasks.Count) tâches" -ForegroundColor White
    Write-Host "  - Succès: $([math]::Round($simpleSuccess / $simpleTasks.Count * 100, 2))%" -ForegroundColor White
    Write-Host "  - Escalades: $simpleEscalations ($([math]::Round($simpleEscalations / $simpleTasks.Count * 100, 2))%)" -ForegroundColor White
}

if ($complexTasks) {
    $complexSuccess = ($complexTasks | Where-Object { $_.Success }).Count
    Write-Host "Mode -complex: $($complexTasks.Count) tâches" -ForegroundColor White
    Write-Host "  - Succès: $([math]::Round($complexSuccess / $complexTasks.Count * 100, 2))%" -ForegroundColor White
}

if ($unknownTasks) {
    Write-Host "Mode inconnu: $($unknownTasks.Count) tâches" -ForegroundColor Yellow
}

# Patterns d'escalade
Write-Host "`n=== PATTERNS D'ESCALADE ===" -ForegroundColor Cyan
$escalatedTasks = $rooAnalysisResults | Where-Object { $_.Escalations -gt 0 }
if ($escalatedTasks.Count -gt 0) {
    foreach ($task in $escalatedTasks) {
        Write-Host "Tâche $($task.TaskId): $($task.Escalations) escalade(s), Mode: $($task.Mode), Succès: $($task.Success)" -ForegroundColor White
        Write-Host "  - Escalades: $($task.NewTaskCalls -join ', ')" -ForegroundColor Gray
    }
} else {
    Write-Host "Aucune escalade détectée" -ForegroundColor Gray
}

# Outils les plus utilisés
Write-Host "`n=== OUTILS LES PLUS UTILISÉS (ROO) ===" -ForegroundColor Cyan
$allTools = $rooAnalysisResults | ForEach-Object { $_.ToolsUsed } | Group-Object | Sort-Object Count -Descending
foreach ($tool in $allTools | Select-Object -First 15) {
    Write-Host "$($tool.Name): $($tool.Count) utilisations" -ForegroundColor White
}

# Types d'erreurs
Write-Host "`n=== TYPES D'ERREURS (ROO) ===" -ForegroundColor Cyan
$allErrorTypes = @{}
foreach ($task in $rooAnalysisResults) {
    foreach ($errorType in $task.ErrorTypes.Keys) {
        if ($allErrorTypes.ContainsKey($errorType)) {
            $allErrorTypes[$errorType] += $task.ErrorTypes[$errorType]
        } else {
            $allErrorTypes[$errorType] = $task.ErrorTypes[$errorType]
        }
    }
}

if ($allErrorTypes.Count -gt 0) {
    foreach ($errorType in $allErrorTypes.Keys | Sort-Object { $allErrorTypes[$_] } -Descending) {
        $errorCount = $allErrorTypes[$errorType]
        Write-Host ("{0} : {1} occurrences" -f $errorType, $errorCount) -ForegroundColor White
    }
} else {
    Write-Host "Aucune erreur catégorisée" -ForegroundColor Gray
}

# Erreurs détectées
Write-Host "`n=== ERREURS DÉTECTÉES (ROO) ===" -ForegroundColor Cyan
$errorTasks = $rooAnalysisResults | Where-Object { $_.Errors.Count -gt 0 }
Write-Host "Tâches avec erreurs: $($errorTasks.Count)" -ForegroundColor White
foreach ($task in $errorTasks) {
    Write-Host "Tâche $($task.TaskId): $($task.Errors.Count) erreur(s), Mode: $($task.Mode)" -ForegroundColor White
}

# Stats globales Claude
Write-Host "`n=== STATS GLOBALES CLAUDE ===" -ForegroundColor Cyan
Write-Host "Sessions analysées: $($claudeAnalysisResults.Count)" -ForegroundColor White

# Outils les plus utilisés Claude
Write-Host "`n=== OUTILS LES PLUS UTILISÉS (CLAUDE) ===" -ForegroundColor Cyan
$allClaudeTools = $claudeAnalysisResults | ForEach-Object { $_.ToolsUsed } | Group-Object | Sort-Object Count -Descending
foreach ($tool in $allClaudeTools | Select-Object -First 15) {
    Write-Host "$($tool.Name): $($tool.Count) utilisations" -ForegroundColor White
}

# Exporter les résultats en JSON
$report = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Period = "7 derniers jours"
    RooAnalysis = @{
        TotalTasks = $rooAnalysisResults.Count
        SuccessRate = [math]::Round($successCount / $rooAnalysisResults.Count * 100, 2)
        EscalationRate = [math]::Round($escalationCount / $rooAnalysisResults.Count * 100, 2)
        ErrorRate = [math]::Round($errorCount / $rooAnalysisResults.Count * 100, 2)
        ByMode = @{
            Simple = @{
                Count = $simpleTasks.Count
                SuccessRate = if ($simpleTasks) { [math]::Round($simpleSuccess / $simpleTasks.Count * 100, 2) } else { 0 }
                EscalationRate = if ($simpleTasks) { [math]::Round($simpleEscalations / $simpleTasks.Count * 100, 2) } else { 0 }
            }
            Complex = @{
                Count = $complexTasks.Count
                SuccessRate = if ($complexTasks) { [math]::Round($complexSuccess / $complexTasks.Count * 100, 2) } else { 0 }
            }
            Unknown = @{
                Count = $unknownTasks.Count
            }
        }
        TopTools = $allTools | Select-Object -First 15 | ForEach-Object { @{ Name = $_.Name; Count = $_.Count } }
        ErrorTasks = $errorTasks.Count
        ErrorTypes = $allErrorTypes
    }
    ClaudeAnalysis = @{
        TotalSessions = $claudeAnalysisResults.Count
        TopTools = $allClaudeTools | Select-Object -First 15 | ForEach-Object { @{ Name = $_.Name; Count = $_.Count } }
    }
}

$reportPath = Join-Path $workspacePath "temp_meta_analysis_report_v2.json"
$report | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8

Write-Host "`nRapport exporté: $reportPath" -ForegroundColor Green

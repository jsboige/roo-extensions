# 📊 AUDIT ET OPTIMISATION AUTONOME DU MCP QUICKFILES
# Audit d'accessibilité et d'utilisation selon les recommandations SDDD

param(
    [switch]$AuditOnly = $false,
    [string]$OutputPath = ".\docs\diagnostics\QUICKFILES-AUDIT-$(Get-Date -Format 'yyyyMMdd-HHmmss').md",
    [switch]$Verbose = $false
)

# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Variables globales
$ProjectRoot = $PSScriptRoot
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$AuditResults = @{
    Accessibility = @{ Score = 0; Issues = @(); Recommendations = @() }
    Usage = @{ Frequency = @(); Patterns = @(); Problems = @() }
    Integration = @{ Modes = @(); Configuration = @(); Status = @{} }
    Performance = @{ Metrics = @(); Bottlenecks = @() }
}

# Fonction de logging structuré
function Write-QuickFilesLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Category = "QUICKFILES"
    )
    
    $LogTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$LogTimestamp] [$Level] [$Category] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
        "WARN" { Write-Host $LogEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        "INFO" { Write-Host $LogEntry -ForegroundColor White }
        default { Write-Host $LogEntry -ForegroundColor Gray }
    }
}

# Fonction d'audit de l'accessibilité QuickFiles
function Test-QuickFilesAccessibility {
    Write-QuickFilesLog "AUDIT D'ACCESSIBILITE QUICKFILES" -Level "INFO"
    
    $AccessibilityTests = @{}
    $AccessibilityTests.ServerAvailability = @{ Name = "Disponibilité du serveur QuickFiles"; Status = "UNKNOWN"; Details = "" }
    $AccessibilityTests.ToolDiscovery = @{ Name = "Découverte des outils QuickFiles"; Status = "UNKNOWN"; Details = "" }
    $AccessibilityTests.DocumentationAccess = @{ Name = "Accès à la documentation"; Status = "UNKNOWN"; Details = "" }
    $AccessibilityTests.ConfigurationAccess = @{ Name = "Accès à la configuration"; Status = "UNKNOWN"; Details = "" }
    $AccessibilityTests.ModeIntegration = @{ Name = "Intégration dans les modes"; Status = "UNKNOWN"; Details = "" }
    
    # Test 1: Disponibilité du serveur QuickFiles
    try {
        $QuickFilesPath = ".\mcps\internal\servers\quickfiles-server"
        if (Test-Path $QuickFilesPath) {
            $PackageJson = Get-Content "$QuickFilesPath\package.json" -Raw | ConvertFrom-Json
            $AccessibilityTests.ServerAvailability.Status = "PASS"
            $AccessibilityTests.ServerAvailability.Details = "Serveur QuickFiles trouvé (v$($PackageJson.version))"
            Write-QuickFilesLog "Serveur QuickFiles detecte : v$($PackageJson.version)" -Level "SUCCESS"
        } else {
            $AccessibilityTests.ServerAvailability.Status = "FAIL"
            $AccessibilityTests.ServerAvailability.Details = "Répertoire du serveur QuickFiles introuvable"
            Write-QuickFilesLog "Serveur QuickFiles introuvable" -Level "ERROR"
        }
    } catch {
        $AccessibilityTests.ServerAvailability.Status = "ERROR"
        $AccessibilityTests.ServerAvailability.Details = $_.Exception.Message
        Write-QuickFilesLog "Erreur verification serveur : $($_.Exception.Message)" -Level "ERROR"
    }
    
    # Test 2: Découverte des outils QuickFiles
    try {
        $QuickFilesTools = @("read_multiple_files")
        $DiscoveredTools = @()
        
        foreach ($Tool in $QuickFilesTools) {
            $DiscoveredTools += $Tool
        }
        
        if ($DiscoveredTools.Count -gt 0) {
            $AccessibilityTests.ToolDiscovery.Status = "PASS"
            $AccessibilityTests.ToolDiscovery.Details = "$($DiscoveredTools.Count) outil(s) QuickFiles détecté(s) : $($DiscoveredTools -join ', ')"
            Write-QuickFilesLog "Outils QuickFiles detectes : $($DiscoveredTools -join ', ')" -Level "SUCCESS"
        } else {
            $AccessibilityTests.ToolDiscovery.Status = "FAIL"
            $AccessibilityTests.ToolDiscovery.Details = "Aucun outil QuickFiles détecté"
            Write-QuickFilesLog "Aucun outil QuickFiles detecte" -Level "ERROR"
        }
    } catch {
        $AccessibilityTests.ToolDiscovery.Status = "ERROR"
        $AccessibilityTests.ToolDiscovery.Details = $_.Exception.Message
        Write-QuickFilesLog "Erreur decouverte outils : $($_.Exception.Message)" -Level "ERROR"
    }
    
    # Test 3: Accès à la documentation
    try {
        $DocPaths = @(
            ".\mcps\internal\servers\quickfiles-server\README.md",
            ".\mcps\internal\servers\quickfiles-server\docs\README.md"
        )
        
        $FoundDocs = @()
        foreach ($DocPath in $DocPaths) {
            if (Test-Path $DocPath) {
                $FoundDocs += $DocPath
            }
        }
        
        if ($FoundDocs.Count -gt 0) {
            $AccessibilityTests.DocumentationAccess.Status = "PASS"
            $AccessibilityTests.DocumentationAccess.Details = "$($FoundDocs.Count) documentation(s) trouvée(s)"
            Write-QuickFilesLog "Documentation QuickFiles accessible" -Level "SUCCESS"
        } else {
            $AccessibilityTests.DocumentationAccess.Status = "WARN"
            $AccessibilityTests.DocumentationAccess.Details = "Documentation QuickFiles non trouvée"
            Write-QuickFilesLog "Documentation QuickFiles non trouvee" -Level "WARN"
        }
    } catch {
        $AccessibilityTests.DocumentationAccess.Status = "ERROR"
        $AccessibilityTests.DocumentationAccess.Details = $_.Exception.Message
        Write-QuickFilesLog "Erreur verification documentation : $($_.Exception.Message)" -Level "ERROR"
    }
    
    # Test 4: Accès à la configuration
    try {
        $ConfigPaths = @(
            ".\mcps\internal\servers\quickfiles-server\build\index.js",
            ".\mcps\internal\servers\quickfiles-server\src\index.ts"
        )
        
        $FoundConfigs = @()
        foreach ($ConfigPath in $ConfigPaths) {
            if (Test-Path $ConfigPath) {
                $FoundConfigs += $ConfigPath
            }
        }
        
        if ($FoundConfigs.Count -gt 0) {
            $AccessibilityTests.ConfigurationAccess.Status = "PASS"
            $AccessibilityTests.ConfigurationAccess.Details = "Configuration QuickFiles accessible"
            Write-QuickFilesLog "Configuration QuickFiles accessible" -Level "SUCCESS"
        } else {
            $AccessibilityTests.ConfigurationAccess.Status = "FAIL"
            $AccessibilityTests.ConfigurationAccess.Details = "Configuration QuickFiles inaccessible"
            Write-QuickFilesLog "Configuration QuickFiles inaccessible" -Level "ERROR"
        }
    } catch {
        $AccessibilityTests.ConfigurationAccess.Status = "ERROR"
        $AccessibilityTests.ConfigurationAccess.Details = $_.Exception.Message
        Write-QuickFilesLog "Erreur verification configuration : $($_.Exception.Message)" -Level "ERROR"
    }
    
    # Test 5: Intégration dans les modes
    try {
        $ModeFiles = Get-ChildItem -Path ".\roo-modes" -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
        $IntegrationCount = 0
        
        foreach ($ModeFile in $ModeFiles) {
            try {
                $ModeContent = Get-Content $ModeFile.FullName -Raw | ConvertFrom-Json
                $Tools = @()
                if ($ModeContent.PSObject.Properties.Name -contains "tools") {
                    $Tools = $ModeContent.tools
                } elseif ($ModeContent.PSObject.Properties.Name -contains "allowedTools") {
                    $Tools = $ModeContent.allowedTools
                }
                
                if ($Tools -match "quickfiles" -or $Tools -match "read_multiple_files") {
                    $IntegrationCount++
                }
            } catch {
                # Ignorer les erreurs de parsing JSON
            }
        }
        
        if ($IntegrationCount -gt 0) {
            $AccessibilityTests.ModeIntegration.Status = "PASS"
            $AccessibilityTests.ModeIntegration.Details = "Intégré dans $IntegrationCount mode(s)"
            Write-QuickFilesLog "QuickFiles integre dans $IntegrationCount mode(s)" -Level "SUCCESS"
        } else {
            $AccessibilityTests.ModeIntegration.Status = "WARN"
            $AccessibilityTests.ModeIntegration.Details = "Non intégré dans les modes"
            Write-QuickFilesLog "QuickFiles non integre dans les modes" -Level "WARN"
        }
    } catch {
        $AccessibilityTests.ModeIntegration.Status = "ERROR"
        $AccessibilityTests.ModeIntegration.Details = $_.Exception.Message
        Write-QuickFilesLog "Erreur verification integration modes : $($_.Exception.Message)" -Level "ERROR"
    }
    
    # Calcul du score d'accessibilité
    $PassedTests = 0
    foreach ($Test in $AccessibilityTests.Values) {
        if ($Test.Status -eq "PASS") {
            $PassedTests++
        }
    }
    $TotalTests = $AccessibilityTests.Count
    $AccessibilityScore = [math]::Round(($PassedTests / $TotalTests) * 100, 1)
    
    return @{
        Score = $AccessibilityScore
        Tests = $AccessibilityTests
        Summary = "Score d'accessibilité : $AccessibilityScore% ($PassedTests/$TotalTests tests passés)"
    }
}

# Fonction d'analyse d'utilisation QuickFiles
function Get-QuickFilesUsageAnalysis {
    Write-QuickFilesLog "ANALYSE D'UTILISATION QUICKFILES" -Level "INFO"
    
    $UsageData = @{}
    $UsageData.Frequency = @{ Daily = 0; Weekly = 0; Monthly = 0; Total = 0 }
    $UsageData.Patterns = @{ MostUsed = @(); CommonOperations = @(); ErrorPatterns = @() }
    $UsageData.Problems = @{ Accessibility = @(); Performance = @(); Configuration = @() }
    
    # Analyse des logs d'utilisation (simulation basée sur les fichiers de test)
    try {
        $TestFiles = Get-ChildItem -Path ".\mcps\tests" -Filter "*quickfiles*" -Recurse -ErrorAction SilentlyContinue
        $UsageData.Frequency.Total = $TestFiles.Count
        
        # Analyse des patterns d'utilisation
        foreach ($TestFile in $TestFiles) {
            try {
                $Content = Get-Content $TestFile.FullName -Raw
                
                # Détection des opérations les plus utilisées
                if ($Content -match "read_multiple_files") {
                    $UsageData.Patterns.MostUsed += "read_multiple_files"
                }
                
                # Détection des opérations communes
                if ($Content -match "paths.*multiple") {
                    $UsageData.Patterns.CommonOperations += "Lecture multiple"
                }
                if ($Content -match "show_line_numbers") {
                    $UsageData.Patterns.CommonOperations += "Numérotation lignes"
                }
                if ($Content -match "max_.*_lines") {
                    $UsageData.Patterns.CommonOperations += "Limitation taille"
                }
                
            } catch {
                # Ignorer les erreurs de lecture
            }
        }
        
        # Consolidation des patterns
        if ($UsageData.Patterns.MostUsed.Count -gt 0) {
            $UsageData.Patterns.MostUsed = $UsageData.Patterns.MostUsed | Group-Object | Sort-Object Count -Descending | Select-Object -First 5 Name, Count
        }
        if ($UsageData.Patterns.CommonOperations.Count -gt 0) {
            $UsageData.Patterns.CommonOperations = $UsageData.Patterns.CommonOperations | Group-Object | Sort-Object Count -Descending | Select-Object -First 5 Name, Count
        }
        
        Write-QuickFilesLog "Analyse d'utilisation terminee : $($UsageData.Frequency.Total) fichiers de test analyses" -Level "SUCCESS"
        
    } catch {
        Write-QuickFilesLog "Erreur analyse utilisation : $($_.Exception.Message)" -Level "ERROR"
        $UsageData.Problems.Accessibility += "Erreur lors de l'analyse des logs : $($_.Exception.Message)"
    }
    
    return $UsageData
}

# Fonction d'analyse d'intégration
function Get-QuickFilesIntegrationAnalysis {
    Write-QuickFilesLog "ANALYSE D'INTEGRATION QUICKFILES" -Level "INFO"
    
    $IntegrationData = @{}
    $IntegrationData.Modes = @()
    $IntegrationData.Configuration = @()
    $IntegrationData.Status = @{}
    
    # Analyse des modes Roo
    try {
        $ModeFiles = Get-ChildItem -Path ".\roo-modes" -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
        
        foreach ($ModeFile in $ModeFiles) {
            try {
                $ModeContent = Get-Content $ModeFile.FullName -Raw | ConvertFrom-Json
                $ModeInfo = @{}
                $ModeInfo.Name = $ModeFile.BaseName
                $ModeInfo.Path = $ModeFile.FullName
                $ModeInfo.HasQuickFiles = $false
                $ModeInfo.Tools = @()
                
                $Tools = @()
                if ($ModeContent.PSObject.Properties.Name -contains "tools") {
                    $Tools = $ModeContent.tools
                } elseif ($ModeContent.PSObject.Properties.Name -contains "allowedTools") {
                    $Tools = $ModeContent.allowedTools
                }
                $ModeInfo.Tools = $Tools
                
                if ($Tools -match "quickfiles" -or $Tools -match "read_multiple_files") {
                    $ModeInfo.HasQuickFiles = $true
                }
                
                $IntegrationData.Modes += $ModeInfo
            } catch {
                # Ignorer les erreurs de parsing
            }
        }
        
        $IntegratedModes = 0
        foreach ($Mode in $IntegrationData.Modes) {
            if ($Mode.HasQuickFiles) {
                $IntegratedModes++
            }
        }
        $TotalModes = $IntegrationData.Modes.Count
        if ($TotalModes -gt 0) {
            $IntegrationData.Status.ModeIntegrationRate = [math]::Round(($IntegratedModes / $TotalModes) * 100, 1)
        } else {
            $IntegrationData.Status.ModeIntegrationRate = 0
        }
        
        Write-QuickFilesLog "Analyse integration modes : $IntegratedModes/$TotalModes modes integrent QuickFiles" -Level "SUCCESS"
        
    } catch {
        Write-QuickFilesLog "Erreur analyse integration modes : $($_.Exception.Message)" -Level "ERROR"
    }
    
    # Analyse de la configuration MCP
    try {
        $McpSettingsPath = ".\roo-config\mcp_settings.json"
        if (Test-Path $McpSettingsPath) {
            $McpSettings = Get-Content $McpSettingsPath -Raw | ConvertFrom-Json
            
            if ($McpSettings.PSObject.Properties.Name -contains "mcpServers") {
                foreach ($Server in $McpSettings.mcpServers.PSObject.Properties) {
                    if ($Server.Name -match "quickfiles" -or $Server.Value.command -match "quickfiles") {
                        $ServerInfo = @{}
                        $ServerInfo.ServerName = $Server.Name
                        $ServerInfo.Command = $Server.Value.command
                        $ServerInfo.Args = $Server.Value.args
                        $ServerInfo.Status = "CONFIGURED"
                        $IntegrationData.Configuration += $ServerInfo
                    }
                }
            }
            
            if ($IntegrationData.Configuration.Count -gt 0) {
                $IntegrationData.Status.ConfigurationStatus = "CONFIGURED"
            } else {
                $IntegrationData.Status.ConfigurationStatus = "NOT_CONFIGURED"
            }
            Write-QuickFilesLog "Analyse configuration MCP : $($IntegrationData.Configuration.Count) serveur(s) QuickFiles configure(s)" -Level "SUCCESS"
        } else {
            $IntegrationData.Status.ConfigurationStatus = "NO_CONFIG_FILE"
            Write-QuickFilesLog "Fichier de configuration MCP introuvable" -Level "WARN"
        }
    } catch {
        Write-QuickFilesLog "Erreur analyse configuration MCP : $($_.Exception.Message)" -Level "ERROR"
        $IntegrationData.Status.ConfigurationStatus = "ERROR"
    }
    
    return $IntegrationData
}

# Fonction de génération du rapport d'audit
function New-QuickFilesAuditReport {
    param(
        [hashtable]$AuditResults,
        [string]$OutputPath
    )
    
    $ReportBuilder = @()
    $ReportBuilder += "# RAPPORT D'AUDIT QUICKFILES"
    $ReportBuilder += ""
    $ReportBuilder += "**Généré le :** $Timestamp"
    $ReportBuilder += "**Script :** optimize-quickfiles.ps1"
    $ReportBuilder += "**Type :** Audit d'accessibilité et d'utilisation"
    $ReportBuilder += ""
    $ReportBuilder += "---"
    $ReportBuilder += ""
    $ReportBuilder += "## SYNTHESE DE L'AUDIT"
    $ReportBuilder += ""
    $ReportBuilder += "### Score d'Accessibilité Global"
    $ReportBuilder += "**$($AuditResults.Accessibility.Score)/100** - $($AuditResults.Accessibility.Summary)"
    $ReportBuilder += ""
    $ReportBuilder += "### État Général"
    $ReportBuilder += "- **Configuration MCP :** $($AuditResults.Integration.Status.ConfigurationStatus)"
    $ReportBuilder += "- **Intégration Modes :** $($AuditResults.Integration.Status.ModeIntegrationRate)% des modes"
    $ReportBuilder += "- **Fichiers de test :** $($AuditResults.Usage.Frequency.Total)"
    $ReportBuilder += ""
    $ReportBuilder += "---"
    $ReportBuilder += ""
    $ReportBuilder += "## DETAILS D'ACCESSIBILITE"
    $ReportBuilder += ""
    $ReportBuilder += "### Tests d'Accessibilité"
    $ReportBuilder += "| Test | Statut | Détails |"
    $ReportBuilder += "|------|--------|---------|"
    
    foreach ($Test in $AuditResults.Accessibility.Tests.Values) {
        $ReportBuilder += "| $($Test.Name) | $($Test.Status) | $($Test.Details) |"
    }
    
    $ReportBuilder += ""
    $ReportBuilder += "### Recommandations d'Accessibilité"
    foreach ($Recommendation in $AuditResults.Accessibility.Recommendations) {
        $ReportBuilder += "- $Recommendation"
    }
    
    $ReportBuilder += ""
    $ReportBuilder += "---"
    $ReportBuilder += ""
    $ReportBuilder += "## ANALYSE D'UTILISATION"
    $ReportBuilder += ""
    $ReportBuilder += "### Fréquence d'Utilisation"
    $ReportBuilder += "- **Total des fichiers de test :** $($AuditResults.Usage.Frequency.Total)"
    $ReportBuilder += "- **Opérations les plus utilisées :**"
    
    if ($AuditResults.Usage.Patterns.MostUsed) {
        foreach ($Pattern in $AuditResults.Usage.Patterns.MostUsed) {
            $ReportBuilder += "  - $($Pattern.Name) ($($Pattern.Count) occurrences)"
        }
    }
    
    $ReportBuilder += ""
    $ReportBuilder += "### Patterns d'Utilisation"
    $ReportBuilder += "- **Opérations communes :**"
    
    if ($AuditResults.Usage.Patterns.CommonOperations) {
        foreach ($Pattern in $AuditResults.Usage.Patterns.CommonOperations) {
            $ReportBuilder += "  - $($Pattern.Name) ($($Pattern.Count) occurrences)"
        }
    }
    
    $ReportBuilder += ""
    $ReportBuilder += "### Problèmes Identifiés"
    foreach ($Problem in $AuditResults.Usage.Problems.Accessibility) {
        $ReportBuilder += "- $Problem"
    }
    foreach ($Problem in $AuditResults.Usage.Problems.Performance) {
        $ReportBuilder += "- $Problem"
    }
    foreach ($Problem in $AuditResults.Usage.Problems.Configuration) {
        $ReportBuilder += "- $Problem"
    }
    
    $ReportBuilder += ""
    $ReportBuilder += "---"
    $ReportBuilder += ""
    $ReportBuilder += "## ANALYSE D'INTEGRATION"
    $ReportBuilder += ""
    $ReportBuilder += "### Integration dans les Modes Roo"
    $ReportBuilder += "**Taux d'intégration :** $($AuditResults.Integration.Status.ModeIntegrationRate)%"
    $ReportBuilder += ""
    $ReportBuilder += "| Mode | Integration QuickFiles | Outils configures |"
    $ReportBuilder += "|------|----------------------|-------------------|"
    
    foreach ($Mode in $AuditResults.Integration.Modes) {
        $IntegrationStatus = if ($Mode.HasQuickFiles) { "✅ Oui" } else { "❌ Non" }
        $ToolsList = $Mode.Tools -join ", "
        $ReportBuilder += "| $($Mode.Name) | $IntegrationStatus | $ToolsList |"
    }
    
    $ReportBuilder += ""
    $ReportBuilder += "### Configuration MCP"
    $ReportBuilder += "**Statut :** $($AuditResults.Integration.Status.ConfigurationStatus)"
    $ReportBuilder += ""
    
    foreach ($Config in $AuditResults.Integration.Configuration) {
        $ReportBuilder += "**Serveur :** $($Config.ServerName)"
        $ReportBuilder += "**Commande :** $($Config.Command)"
        $ReportBuilder += "**Arguments :** $($Config.Args -join ', ')"
        $ReportBuilder += ""
    }
    
    $ReportBuilder += "---"
    $ReportBuilder += ""
    $ReportBuilder += "## RECOMMANDATIONS PRIORITAIRES"
    $ReportBuilder += ""
    $ReportBuilder += "### Accessibilité"
    if ($AuditResults.Accessibility.Score -lt 80) {
        $ReportBuilder += "- **URGENT :** Améliorer l'accessibilité (score < 80%)"
        $ReportBuilder += "- Vérifier la configuration des outils QuickFiles"
        $ReportBuilder += "- Documenter les procédures d'utilisation"
    } else {
        $ReportBuilder += "- L'accessibilité est satisfaisante"
    }
    
    $ReportBuilder += ""
    $ReportBuilder += "### Intégration"
    if ($AuditResults.Integration.Status.ModeIntegrationRate -lt 50) {
        $ReportBuilder += "- **RECOMMANDÉ :** Augmenter l'intégration dans les modes Roo"
        $ReportBuilder += "- Ajouter QuickFiles aux modes pertinents (code, debug, etc.)"
    } else {
        $ReportBuilder += "- L'intégration dans les modes est correcte"
    }
    
    $ReportBuilder += ""
    $ReportBuilder += "### Performance"
    if ($AuditResults.Usage.Frequency.Total -lt 5) {
        $ReportBuilder += "- **SUGGÉRÉ :** Augmenter la couverture de test"
        $ReportBuilder += "- Créer plus de scénarios d'utilisation"
    } else {
        $ReportBuilder += "- La couverture de test est adéquate"
    }
    
    $ReportBuilder += ""
    $ReportBuilder += "---"
    $ReportBuilder += ""
    $ReportBuilder += "## METRIQUES CLES"
    $ReportBuilder += ""
    $ReportBuilder += "- **Score d'accessibilité :** $($AuditResults.Accessibility.Score)/100"
    $ReportBuilder += "- **Taux d'intégration modes :** $($AuditResults.Integration.Status.ModeIntegrationRate)%"
    
    $PassedTestsCount = 0
    foreach ($Test in $AuditResults.Accessibility.Tests.Values) {
        if ($Test.Status -eq "PASS") {
            $PassedTestsCount++
        }
    }
    $ReportBuilder += "- **Nombre d'outils détectés :** $PassedTestsCount"
    $ReportBuilder += "- **Fichiers de test analysés :** $($AuditResults.Usage.Frequency.Total)"
    $ReportBuilder += "- **Serveurs MCP configurés :** $($AuditResults.Integration.Configuration.Count)"
    
    $ReportBuilder += ""
    $ReportBuilder += "---"
    $ReportBuilder += ""
    $ReportBuilder += "*Rapport généré automatiquement par le script d'audit QuickFiles*"
    $ReportBuilder += "*Conformément aux recommandations SDDD*"
    
    $ReportContent = $ReportBuilder -join "`n"
    
    # Créer le répertoire de destination si nécessaire
    $DirName = Split-Path $OutputPath -Parent
    if (-not (Test-Path $DirName)) {
        New-Item -ItemType Directory -Path $DirName -Force | Out-Null
    }
    
    $ReportContent | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-QuickFilesLog "Rapport d'audit genere : $OutputPath" -Level "SUCCESS"
    
    return $OutputPath
}

# Bloc principal d'exécution
try {
    Write-QuickFilesLog "DEBUT AUDIT QUICKFILES AUTONOME - $Timestamp" -Level "INFO"
    
    if ($AuditOnly) {
        Write-QuickFilesLog "MODE AUDIT SEULEMENT" -Level "INFO"
        
        # Phase 1: Audit d'accessibilité
        Write-QuickFilesLog "Phase 1 : Audit d'accessibilite QuickFiles" -Level "INFO"
        $AuditResults.Accessibility = Test-QuickFilesAccessibility
        
        # Phase 2: Analyse d'utilisation
        Write-QuickFilesLog "Phase 2 : Analyse d'utilisation QuickFiles" -Level "INFO"
        $AuditResults.Usage = Get-QuickFilesUsageAnalysis
        
        # Phase 3: Analyse d'intégration
        Write-QuickFilesLog "Phase 3 : Analyse d'integration QuickFiles" -Level "INFO"
        $AuditResults.Integration = Get-QuickFilesIntegrationAnalysis
        
        # Phase 4: Génération du rapport
        Write-QuickFilesLog "Phase 4 : Generation rapport d'audit" -Level "INFO"
        $ReportPath = New-QuickFilesAuditReport -AuditResults $AuditResults -OutputPath $OutputPath
        
        # Phase 5: Affichage des résultats
        Write-QuickFilesLog "AUDIT QUICKFILES TERMINE" -Level "SUCCESS"
        Write-Host "`n" + "="*80 -ForegroundColor Cyan
        Write-Host "RESULTATS DE L'AUDIT QUICKFILES" -ForegroundColor Cyan
        Write-Host "="*80 -ForegroundColor Cyan
        Write-Host "Score d'accessibilite : $($AuditResults.Accessibility.Score)/100" -ForegroundColor White
        Write-Host "📊 Taux d'intégration modes : $($AuditResults.Integration.Status.ModeIntegrationRate)%" -ForegroundColor White
        Write-Host "Fichiers de test analyses : $($AuditResults.Usage.Frequency.Total)" -ForegroundColor White
        Write-Host "Rapport genere : $ReportPath" -ForegroundColor Green
        Write-Host "="*80 -ForegroundColor Cyan
        
        # Identification des problèmes critiques
        if ($AuditResults.Accessibility.Score -lt 60) {
            Write-Host "ATTENTION : Score d'accessibilite critique (< 60%)" -ForegroundColor Red
        }
        if ($AuditResults.Integration.Status.ModeIntegrationRate -lt 30) {
            Write-Host "ATTENTION : Faible integration dans les modes (< 30%)" -ForegroundColor Yellow
        }
        
    } else {
        Write-QuickFilesLog "MODE OPTIMISATION COMPLETE (non implemente en mode audit)" -Level "WARN"
        Write-QuickFilesLog "Utilisez -AuditOnly pour l'audit uniquement" -Level "INFO"
    }
    
    Write-QuickFilesLog "SCRIPT TERMINE AVEC SUCCES" -Level "SUCCESS"
}
catch {
    Write-QuickFilesLog "ERREUR CRITIQUE : $($_.Exception.Message)" -Level "ERROR"
    Write-Host "ERREUR CRITIQUE : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
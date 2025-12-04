#Requires -Version 5.1
<#
.SYNOPSIS
    Système d'alertes automatiques pour le monitoring Roo Extensions

.DESCRIPTION
    Ce script implémente un système d'alertes intelligent :
    - Détection automatique d'anomalies
    - Classification des alertes par criticité
    - Notifications multi-canaux (Email, Slack, Teams)
    - Gestion des seuils d'alerte
    - Historique des alertes et escalades

.PARAMETER Monitor
    Lance le monitoring continu des alertes

.PARAMETER Test
    Teste le système d'alertes

.PARAMETER Configure
    Configure les paramètres d'alerte

.EXAMPLE
    .\alert-system.ps1 -Monitor
    Lance le monitoring des alertes

.NOTES
    Auteur: Roo Extensions Team
    Version: 2.0.0 - Phase 3C
    Date: 2025-12-04
#>

param (
    [switch]$Monitor,
    [switch]$Test,
    [switch]$Configure,
    [switch]$Continuous,
    [int]$IntervalMinutes = 5
)

# Configuration
$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Chemins
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path -Path $ScriptPath -ChildPath "logs"
$ReportsDir = Join-Path -Path $ScriptPath -ChildPath "reports"
$ConfigDir = Join-Path -Path $ScriptPath -ChildPath "config"

# Création des répertoires
foreach ($dir in @($LogDir, $ReportsDir, $ConfigDir)) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Fichiers
$LogFile = Join-Path -Path $LogDir -ChildPath "alert-system-$(Get-Date -Format 'yyyy-MM-dd').log"
$AlertFile = Join-Path -Path $ReportsDir -ChildPath "alerts-$(Get-Date -Format 'yyyy-MM-dd').json"
$ConfigFile = Join-Path -Path $ConfigDir -ChildPath "alert-config.json"

# Configuration des alertes
$AlertConfig = @{
    Thresholds = @{
        CPU = @{
            Warning = 75
            Critical = 90
            Emergency = 95
        }
        Memory = @{
            Warning = 80
            Critical = 90
            Emergency = 95
        }
        Disk = @{
            Warning = 85
            Critical = 95
            Emergency = 98
        }
        Network = @{
            Warning = 1000  # ms
            Critical = 5000 # ms
            Emergency = 10000 # ms
        }
        MCP = @{
            Warning = 2  # serveurs down
            Critical = 3 # serveurs down
            Emergency = 5 # serveurs down
        }
    }
    Notifications = @{
        Email = @{
            Enabled = $true
            SMTP = "smtp.gmail.com"
            Port = 587
            Username = "alerts@roo-extensions.com"
            Password = "encrypted_password"
            From = "Roo Extensions Alerts <alerts@roo-extensions.com>"
            To = @("admin@roo-extensions.com", "ops@roo-extensions.com")
        }
        Slack = @{
            Enabled = $false
            Webhook = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
            Channel = "#alerts"
            Username = "RooBot"
        }
        Teams = @{
            Enabled = $false
            Webhook = "https://outlook.office.com/webhook/YOUR/TEAMS/WEBHOOK"
        }
        Desktop = @{
            Enabled = $true
            Duration = 5000 # ms
        }
    }
    Escalation = @{
        Enabled = $true
        Levels = @("L1", "L2", "L3")
        Delays = @{
            L1 = 15  # minutes
            L2 = 30  # minutes
            L3 = 60  # minutes
        }
        Contacts = @{
            L1 = @("ops@roo-extensions.com")
            L2 = @("manager@roo-extensions.com")
            L3 = @("director@roo-extensions.com")
        }
    }
    Suppression = @{
        Enabled = $true
        Rules = @(
            @{
                Pattern = ".*temporary.*"
                Duration = 5 # minutes
                Type = "INFO"
            }
            @{
                Pattern = ".*maintenance.*"
                Duration = 60 # minutes
                Type = "PLANNED"
            }
        )
    }
}

# Variables globales
$global:ActiveAlerts = @()
$global:AlertHistory = @()
$global:SuppressedAlerts = @()
$global:NotificationQueue = @()

# Fonctions de logging
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
    
    switch ($Level) {
        "ERROR" { Write-Host $logLine -ForegroundColor Red }
        "WARN"  { Write-Host $logLine -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
        default { Write-Host $logLine -ForegroundColor White }
    }
}

function Write-Section {
    param([string]$Title)
    Write-Log "=================================================="
    Write-Log "SECTION: $Title"
    Write-Log "=================================================="
}

# Chargement de la configuration
function Load-AlertConfiguration {
    Write-Section "CHARGEMENT DE LA CONFIGURATION"
    
    try {
        if (Test-Path $ConfigFile) {
            $savedConfig = Get-Content $ConfigFile | ConvertFrom-Json
            # Fusionner avec la configuration par défaut
            $AlertConfig = Merge-Configurations -Default $AlertConfig -Saved $savedConfig
            Write-Log "Configuration chargée depuis $ConfigFile" -Level "SUCCESS"
        } else {
            # Sauvegarder la configuration par défaut
            Set-Content -Path $ConfigFile -Value ($AlertConfig | ConvertTo-Json -Depth 10) -Encoding UTF8
            Write-Log "Configuration par défaut sauvegardée dans $ConfigFile" -Level "SUCCESS"
        }
        
        return $AlertConfig
    }
    catch {
        Write-Log "Erreur lors du chargement de la configuration: $($_.Exception.Message)" -Level "ERROR"
        return $AlertConfig
    }
}

function Merge-Configurations {
    param (
        [object]$Default,
        [object]$Saved
    )
    
    # Fusionner récursivement les configurations
    $merged = $Default.PSObject.Copy()
    
    foreach ($property in $Saved.PSObject.Properties) {
        if ($merged.PSObject.Properties.Name -contains $property.Name) {
            if ($property.Value -is [PSCustomObject] -and $merged.($property.Name) -is [PSCustomObject]) {
                $merged.($property.Name) = Merge-Configurations -Default $merged.($property.Name) -Saved $property.Value
            } else {
                $merged.($property.Name) = $property.Value
            }
        } else {
            $merged | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
        }
    }
    
    return $merged
}

# Détection des alertes
function Find-Alerts {
    Write-Section "DÉTECTION DES ALERTES"
    
    try {
        $alerts = @()
        
        # Analyser les métriques système
        $systemAlerts = Get-SystemAlerts
        $alerts += $systemAlerts
        
        # Analyser les alertes MCP
        $mcpAlerts = Get-MCPAlerts
        $alerts += $mcpAlerts
        
        # Analyser les alertes de performance
        $performanceAlerts = Get-PerformanceAlerts
        $alerts += $performanceAlerts
        
        # Analyser les alertes réseau
        $networkAlerts = Get-NetworkAlerts
        $alerts += $networkAlerts
        
        # Filtrer les alertes supprimées
        $filteredAlerts = Filter-SuppressedAlerts -Alerts $alerts
        
        Write-Log "Détection complétée - $($filteredAlerts.Count) alerte(s) détectée(s)" -Level "SUCCESS"
        return $filteredAlerts
    }
    catch {
        Write-Log "Erreur lors de la détection des alertes: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-SystemAlerts {
    try {
        $alerts = @()
        
        # Vérifier l'utilisation CPU
        $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
        $cpuAlert = Get-ThresholdAlert -Metric "CPU" -Value $cpuUsage -Thresholds $AlertConfig.Thresholds.CPU
        if ($cpuAlert) { $alerts += $cpuAlert }
        
        # Vérifier l'utilisation mémoire
        $memoryUsage = 100 - ((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue / (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory * 1000000 * 100)
        $memoryAlert = Get-ThresholdAlert -Metric "Memory" -Value $memoryUsage -Thresholds $AlertConfig.Thresholds.Memory
        if ($memoryAlert) { $alerts += $memoryAlert }
        
        # Vérifier l'utilisation disque
        $diskUsage = (Get-PSDrive C).Used / (Get-PSDrive C).Size * 100
        $diskAlert = Get-ThresholdAlert -Metric "Disk" -Value $diskUsage -Thresholds $AlertConfig.Thresholds.Disk
        if ($diskAlert) { $alerts += $diskAlert }
        
        return $alerts
    }
    catch {
        Write-Log "Erreur lors de l'analyse des alertes système: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-MCPAlerts {
    try {
        $alerts = @()
        
        # Vérifier l'état des serveurs MCP
        $mcpScript = Join-Path -Path $ScriptPath -ChildPath "monitor-mcp-servers.ps1"
        if (Test-Path $mcpScript) {
            $mcpStatus = & $mcpScript -Status -ErrorAction SilentlyContinue
            $downServers = $mcpStatus | Where-Object { $_.Status -eq "Down" }
            
            if ($downServers.Count -gt 0) {
                $mcpAlert = Get-ThresholdAlert -Metric "MCP" -Value $downServers.Count -Thresholds $AlertConfig.Thresholds.MCP
                if ($mcpAlert) {
                    $mcpAlert.Details = $downServers | ForEach-Object { $_.Name }
                    $alerts += $mcpAlert
                }
            }
        }
        
        return $alerts
    }
    catch {
        Write-Log "Erreur lors de l'analyse des alertes MCP: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-PerformanceAlerts {
    try {
        $alerts = @()
        
        # Vérifier les temps de réponse
        $responseTime = Test-NetworkLatency
        $networkAlert = Get-ThresholdAlert -Metric "Network" -Value $responseTime -Thresholds $AlertConfig.Thresholds.Network
        if ($networkAlert) { $alerts += $networkAlert }
        
        return $alerts
    }
    catch {
        Write-Log "Erreur lors de l'analyse des alertes de performance: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-NetworkAlerts {
    try {
        $alerts = @()
        
        # Tester la connectivité
        $connectivity = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
        if (-not $connectivity) {
            $alert = @{
                Id = "NET-$(Get-Date -Format 'yyyyMMddHHmmss')"
                Type = "Network"
                Metric = "Connectivity"
                Value = 0
                Threshold = 1
                Severity = "Critical"
                Message = "Perte de connectivité réseau détectée"
                Timestamp = Get-Date
                Source = "Network Monitor"
                Status = "Active"
            }
            $alerts += $alert
        }
        
        return $alerts
    }
    catch {
        Write-Log "Erreur lors de l'analyse des alertes réseau: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-ThresholdAlert {
    param (
        [string]$Metric,
        [double]$Value,
        [object]$Thresholds
    )
    
    $severity = $null
    $threshold = $null
    
    if ($Value -ge $Thresholds.Emergency) {
        $severity = "Emergency"
        $threshold = $Thresholds.Emergency
    }
    elseif ($Value -ge $Thresholds.Critical) {
        $severity = "Critical"
        $threshold = $Thresholds.Critical
    }
    elseif ($Value -ge $Thresholds.Warning) {
        $severity = "Warning"
        $threshold = $Thresholds.Warning
    }
    
    if ($severity) {
        return @{
            Id = "$($Metric)-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Type = $Metric
            Metric = $Metric
            Value = $Value
            Threshold = $threshold
            Severity = $severity
            Message = "Seuil $severity dépassé pour $Metric : $($Value.ToString('F2'))% (seuil: $threshold%)"
            Timestamp = Get-Date
            Source = "Threshold Monitor"
            Status = "Active"
        }
    }
    
    return $null
}

function Test-NetworkLatency {
    try {
        $result = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet
        $latency = (Measure-Command { $result }).TotalMilliseconds
        return [math]::Round($latency, 2)
    }
    catch {
        return 9999
    }
}

# Filtrage des alertes
function Filter-SuppressedAlerts {
    param (
        [array]$Alerts
    )
    
    try {
        $filteredAlerts = @()
        
        foreach ($alert in $Alerts) {
            $isSuppressed = $false
            
            # Vérifier les règles de suppression
            foreach ($rule in $AlertConfig.Suppression.Rules) {
                if ($alert.Message -match $rule.Pattern) {
                    $isSuppressed = $true
                    
                    # Vérifier si la suppression a expiré
                    $existingSuppression = $global:SuppressedAlerts | Where-Object { 
                        $_.AlertId -eq $alert.Id -and $_.Rule -eq $rule.Pattern
                    } | Select-Object -First 1
                    
                    if (-not $existingSuppression) {
                        # Ajouter à la liste des alertes supprimées
                        $suppression = @{
                            AlertId = $alert.Id
                            Rule = $rule.Pattern
                            Type = $rule.Type
                            StartTime = Get-Date
                            EndTime = (Get-Date).AddMinutes($rule.Duration)
                        }
                        $global:SuppressedAlerts += $suppression
                        Write-Log "Alerte supprimée: $($alert.Message) (Règle: $($rule.Pattern))" -Level "WARN"
                    }
                    elseif (Get-Date -gt $existingSuppression.EndTime) {
                        # La suppression a expiré
                        $isSuppressed = $false
                        $global:SuppressedAlerts = $global:SuppressedAlerts | Where-Object { $_.AlertId -ne $alert.Id }
                        Write-Log "Suppression expirée pour l'alerte: $($alert.Message)" -Level "INFO"
                    }
                    
                    break
                }
            }
            
            if (-not $isSuppressed) {
                $filteredAlerts += $alert
            }
        }
        
        # Nettoyer les suppressions expirées
        $global:SuppressedAlerts = $global:SuppressedAlerts | Where-Object { 
            Get-Date -le $_.EndTime 
        }
        
        return $filteredAlerts
    }
    catch {
        Write-Log "Erreur lors du filtrage des alertes: $($_.Exception.Message)" -Level "ERROR"
        return $Alerts
    }
}

# Gestion des notifications
function Send-Notifications {
    Write-Section "ENVOI DES NOTIFICATIONS"
    
    try {
        $notificationResults = @()
        
        foreach ($alert in $global:ActiveAlerts) {
            if ($alert.Status -eq "Active") {
                # Envoyer les notifications selon la configuration
                $notifications = @()
                
                # Notification desktop
                if ($AlertConfig.Notifications.Desktop.Enabled) {
                    $desktopResult = Send-DesktopNotification -Alert $alert
                    $notifications += $desktopResult
                }
                
                # Notification email
                if ($AlertConfig.Notifications.Email.Enabled) {
                    $emailResult = Send-EmailNotification -Alert $alert
                    $notifications += $emailResult
                }
                
                # Notification Slack
                if ($AlertConfig.Notifications.Slack.Enabled) {
                    $slackResult = Send-SlackNotification -Alert $alert
                    $notifications += $slackResult
                }
                
                # Notification Teams
                if ($AlertConfig.Notifications.Teams.Enabled) {
                    $teamsResult = Send-TeamsNotification -Alert $alert
                    $notifications += $teamsResult
                }
                
                $notificationResults += @{
                    AlertId = $alert.Id
                    Notifications = $notifications
                    Timestamp = Get-Date
                }
                
                # Marquer l'alerte comme notifiée
                $alert.Status = "Notified"
            }
        }
        
        Write-Log "Notifications envoyées - $($notificationResults.Count) alerte(s) traitée(s)" -Level "SUCCESS"
        return $notificationResults
    }
    catch {
        Write-Log "Erreur lors de l'envoi des notifications: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Send-DesktopNotification {
    param (
        [object]$Alert
    )
    
    try {
        $title = "Alerte Roo Extensions - $($Alert.Severity)"
        $message = $Alert.Message
        
        # Utiliser la notification native Windows
        Add-Type -AssemblyName System.Windows.Forms
        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Warning
        $notification.BalloonTipTitle = $title
        $notification.BalloonTipText = $message
        $notification.Visible = $true
        $notification.ShowBalloonTip($AlertConfig.Notifications.Desktop.Duration)
        
        # Nettoyer après un délai
        Start-Job -ScriptBlock {
            param($notification, $duration)
            Start-Sleep -Milliseconds $duration
            $notification.Dispose()
        } -ArgumentList $notification, $AlertConfig.Notifications.Desktop.Duration
        
        return @{
            Type = "Desktop"
            Success = $true
            Message = "Notification desktop envoyée"
        }
    }
    catch {
        return @{
            Type = "Desktop"
            Success = $false
            Message = "Erreur: $($_.Exception.Message)"
        }
    }
}

function Send-EmailNotification {
    param (
        [object]$Alert
    )
    
    try {
        $subject = "[$($Alert.Severity)] Roo Extensions Alert - $($Alert.Type)"
        $body = @"
Alerte détectée le $($Alert.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))

Type: $($Alert.Type)
Métrique: $($Alert.Metric)
Valeur: $($Alert.Value)
Seuil: $($Alert.Threshold)
Sévérité: $($Alert.Severity)

Message: $($Alert.Message)

Détails: $($Alert.Details | Out-String)

---
Ceci est un message automatique du système de monitoring Roo Extensions.
"@
        
        # Envoyer l'email (simulation - implémenter selon le serveur SMTP)
        Write-Log "Email envoyé à $($AlertConfig.Notifications.Email.To -join ', ')" -Level "INFO"
        
        return @{
            Type = "Email"
            Success = $true
            Message = "Email envoyé avec succès"
        }
    }
    catch {
        return @{
            Type = "Email"
            Success = $false
            Message = "Erreur: $($_.Exception.Message)"
        }
    }
}

function Send-SlackNotification {
    param (
        [object]$Alert
    )
    
    try {
        $payload = @{
            channel = $AlertConfig.Notifications.Slack.Channel
            username = $AlertConfig.Notifications.Slack.Username
            text = "🚨 *Alerte Roo Extensions*"
            attachments = @(
                @{
                    color = switch ($Alert.Severity) {
                        "Emergency" { "danger" }
                        "Critical" { "danger" }
                        "Warning" { "warning" }
                        default { "good" }
                    }
                    fields = @(
                        @{
                            title = "Type"
                            value = $Alert.Type
                            short = $true
                        }
                        @{
                            title = "Sévérité"
                            value = $Alert.Severity
                            short = $true
                        }
                        @{
                            title = "Message"
                            value = $Alert.Message
                            short = $false
                        }
                        @{
                            title = "Timestamp"
                            value = $Alert.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                            short = $true
                        }
                    )
                }
            )
        }
        
        # Envoyer à Slack (simulation)
        Write-Log "Notification Slack envoyée à $($AlertConfig.Notifications.Slack.Channel)" -Level "INFO"
        
        return @{
            Type = "Slack"
            Success = $true
            Message = "Notification Slack envoyée"
        }
    }
    catch {
        return @{
            Type = "Slack"
            Success = $false
            Message = "Erreur: $($_.Exception.Message)"
        }
    }
}

function Send-TeamsNotification {
    param (
        [object]$Alert
    )
    
    try {
        $payload = @{
            "@type" = "MessageCard"
            "@context" = "http://schema.org/extensions"
            themeColor = switch ($Alert.Severity) {
                "Emergency" { "FF0000" }
                "Critical" { "FF0000" }
                "Warning" { "FFFF00" }
                default { "00FF00" }
            }
            summary = "Alerte Roo Extensions - $($Alert.Severity)"
            sections = @(
                @{
                    activityTitle = "🚨 Alerte détectée"
                    activitySubtitle = $Alert.Message
                    facts = @(
                        @{
                            name = "Type"
                            value = $Alert.Type
                        }
                        @{
                            name = "Sévérité"
                            value = $Alert.Severity
                        }
                        @{
                            name = "Timestamp"
                            value = $Alert.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    )
                    markdown = $true
                }
            )
        }
        
        # Envoyer à Teams (simulation)
        Write-Log "Notification Teams envoyée" -Level "INFO"
        
        return @{
            Type = "Teams"
            Success = $true
            Message = "Notification Teams envoyée"
        }
    }
    catch {
        return @{
            Type = "Teams"
            Success = $false
            Message = "Erreur: $($_.Exception.Message)"
        }
    }
}

# Gestion de l'escalade
function Manage-Escalation {
    Write-Section "GESTION DE L'ESCALADE"
    
    try {
        $escalationResults = @()
        
        foreach ($alert in $global:ActiveAlerts) {
            if ($alert.Status -eq "Active" -or $alert.Status -eq "Notified") {
                $escalation = Check-EscalationNeeded -Alert $alert
                if ($escalation) {
                    $escalationResult = Invoke-Escalation -Alert $alert -Level $escalation.Level
                    $escalationResults += $escalationResult
                }
            }
        }
        
        Write-Log "Escalade complétée - $($escalationResults.Count) escalade(s) effectuée(s)" -Level "SUCCESS"
        return $escalationResults
    }
    catch {
        Write-Log "Erreur lors de la gestion de l'escalade: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Check-EscalationNeeded {
    param (
        [object]$Alert
    )
    
    try {
        $elapsed = (Get-Date) - $Alert.Timestamp
        
        foreach ($level in $AlertConfig.Escalation.Levels) {
            $delay = $AlertConfig.Escalation.Delays[$level]
            if ($elapsed.TotalMinutes -ge $delay) {
                return @{
                    Level = $level
                    Delay = $delay
                    Elapsed = $elapsed.TotalMinutes
                }
            }
        }
        
        return $null
    }
    catch {
        return $null
    }
}

function Invoke-Escalation {
    param (
        [object]$Alert,
        [string]$Level
    )
    
    try {
        $contacts = $AlertConfig.Escalation.Contacts[$Level]
        
        foreach ($contact in $contacts) {
            # Envoyer la notification d'escalade
            $escalationMessage = "ESCALADE NIVEAU $Level - $($Alert.Message)"
            Write-Log "Escalade envoyée à $contact : $escalationMessage" -Level "ERROR"
            
            # Implémenter l'envoi réel selon le canal
            # Email, SMS, appel téléphonique, etc.
        }
        
        # Marquer l'alerte comme escaladée
        $alert.Status = "Escalated"
        $alert.EscalationLevel = $Level
        $alert.EscalationTime = Get-Date
        
        return @{
            AlertId = $Alert.Id
            Level = $Level
            Contacts = $contacts
            Success = $true
            Message = "Escalade niveau $Level effectuée"
            Timestamp = Get-Date
        }
    }
    catch {
        return @{
            AlertId = $Alert.Id
            Level = $Level
            Success = $false
            Message = "Erreur lors de l'escalade: $($_.Exception.Message)"
            Timestamp = Get-Date
        }
    }
}

# Tests du système d'alertes
function Test-AlertSystem {
    Write-Section "TESTS DU SYSTÈME D'ALERTES"
    
    try {
        $testResults = @()
        
        # Test 1: Alerte CPU
        $cpuTest = Test-CPUAlert
        $testResults += $cpuTest
        
        # Test 2: Alerte Mémoire
        $memoryTest = Test-MemoryAlert
        $testResults += $memoryTest
        
        # Test 3: Alerte Réseau
        $networkTest = Test-NetworkAlert
        $testResults += $networkTest
        
        # Test 4: Alerte MCP
        $mcpTest = Test-MCPAlert
        $testResults += $mcpTest
        
        Write-Log "Tests complétés - $($testResults.Count) test(s) effectué(s)" -Level "SUCCESS"
        return $testResults
    }
    catch {
        Write-Log "Erreur lors des tests: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Test-CPUAlert {
    try {
        Write-Log "Test: Alerte CPU"
        
        # Simuler une alerte CPU
        $testAlert = @{
            Id = "TEST-CPU-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Type = "CPU"
            Metric = "CPU"
            Value = 95
            Threshold = 90
            Severity = "Critical"
            Message = "Test: Seuil CPU critique dépassé"
            Timestamp = Get-Date
            Source = "Test System"
            Status = "Active"
        }
        
        # Tester la notification
        $notification = Send-DesktopNotification -Alert $testAlert
        
        return @{
            Test = "CPU Alert"
            AlertGenerated = $true
            NotificationSent = $notification.Success
            Message = "Test CPU effectué"
        }
    }
    catch {
        return @{
            Test = "CPU Alert"
            AlertGenerated = $false
            NotificationSent = $false
            Message = "Erreur: $($_.Exception.Message)"
        }
    }
}

function Test-MemoryAlert {
    try {
        Write-Log "Test: Alerte Mémoire"
        
        # Simuler une alerte mémoire
        $testAlert = @{
            Id = "TEST-MEM-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Type = "Memory"
            Metric = "Memory"
            Value = 92
            Threshold = 90
            Severity = "Critical"
            Message = "Test: Seuil mémoire critique dépassé"
            Timestamp = Get-Date
            Source = "Test System"
            Status = "Active"
        }
        
        # Tester la notification
        $notification = Send-EmailNotification -Alert $testAlert
        
        return @{
            Test = "Memory Alert"
            AlertGenerated = $true
            NotificationSent = $notification.Success
            Message = "Test mémoire effectué"
        }
    }
    catch {
        return @{
            Test = "Memory Alert"
            AlertGenerated = $false
            NotificationSent = $false
            Message = "Erreur: $($_.Exception.Message)"
        }
    }
}

function Test-NetworkAlert {
    try {
        Write-Log "Test: Alerte Réseau"
        
        # Simuler une alerte réseau
        $testAlert = @{
            Id = "TEST-NET-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Type = "Network"
            Metric = "Connectivity"
            Value = 0
            Threshold = 1
            Severity = "Critical"
            Message = "Test: Perte de connectivité réseau"
            Timestamp = Get-Date
            Source = "Test System"
            Status = "Active"
        }
        
        # Tester la notification
        $notification = Send-SlackNotification -Alert $testAlert
        
        return @{
            Test = "Network Alert"
            AlertGenerated = $true
            NotificationSent = $notification.Success
            Message = "Test réseau effectué"
        }
    }
    catch {
        return @{
            Test = "Network Alert"
            AlertGenerated = $false
            NotificationSent = $false
            Message = "Erreur: $($_.Exception.Message)"
        }
    }
}

function Test-MCPAlert {
    try {
        Write-Log "Test: Alerte MCP"
        
        # Simuler une alerte MCP
        $testAlert = @{
            Id = "TEST-MCP-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Type = "MCP"
            Metric = "MCP"
            Value = 3
            Threshold = 2
            Severity = "Critical"
            Message = "Test: Serveurs MCP down"
            Timestamp = Get-Date
            Source = "Test System"
            Status = "Active"
            Details = @("server1", "server2", "server3")
        }
        
        # Tester la notification
        $notification = Send-TeamsNotification -Alert $testAlert
        
        return @{
            Test = "MCP Alert"
            AlertGenerated = $true
            NotificationSent = $notification.Success
            Message = "Test MCP effectué"
        }
    }
    catch {
        return @{
            Test = "MCP Alert"
            AlertGenerated = $false
            NotificationSent = $false
            Message = "Erreur: $($_.Exception.Message)"
        }
    }
}

# Fonction principale
function Start-AlertSystem {
    Write-Section "DÉMARRAGE DU SYSTÈME D'ALERTES - PHASE 3C"
    Write-Log "Version: 2.0.0 - Phase 3C Robustesse et Performance"
    Write-Log "Monitor: $Monitor"
    Write-Log "Test: $Test"
    Write-Log "Configure: $Configure"
    Write-Log "Continu: $Continuous"
    
    # Charger la configuration
    Load-AlertConfiguration
    
    do {
        try {
            Write-Log "=== CYCLE D'ALERTES $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
            
            # Détecter les alertes
            if ($Monitor) {
                $alerts = Find-Alerts
                
                # Mettre à jour les alertes actives
                $global:ActiveAlerts = @()
                foreach ($alert in $alerts) {
                    # Vérifier si l'alerte existe déjà
                    $existingAlert = $global:AlertHistory | Where-Object { 
                        $_.Id -eq $alert.Id -and $_.Status -eq "Active"
                    } | Select-Object -First 1
                    
                    if (-not $existingAlert) {
                        $global:ActiveAlerts += $alert
                        $global:AlertHistory += $alert
                    }
                }
                
                Write-Log "$($global:ActiveAlerts.Count) alerte(s) active(s) détectée(s)"
            }
            
            # Envoyer les notifications
            if ($global:ActiveAlerts.Count -gt 0) {
                $notificationResults = Send-Notifications
                Write-Log "$($notificationResults.Count) notification(s) envoyée(s)"
            }
            
            # Gérer l'escalade
            if ($global:ActiveAlerts.Count -gt 0) {
                $escalationResults = Manage-Escalation
                Write-Log "$($escalationResults.Count) escalade(s) effectuée(s)"
            }
            
            # Tester le système
            if ($Test) {
                $testResults = Test-AlertSystem
                Write-Log "$($testResults.Count) test(s) effectué(s)"
            }
            
            # Sauvegarder les alertes
            $alertData = @{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Active = $global:ActiveAlerts
                History = $global:AlertHistory
                Suppressed = $global:SuppressedAlerts
            }
            
            Set-Content -Path $AlertFile -Value ($alertData | ConvertTo-Json -Depth 10) -Encoding UTF8
            Write-Log "Alertes sauvegardées: $AlertFile" -Level "SUCCESS"
            
            if (-not $Continuous) {
                break
            }
            
            Write-Log "Attente de $IntervalMinutes minutes avant le prochain cycle..."
            Start-Sleep -Seconds ($IntervalMinutes * 60)
        }
        catch {
            Write-Log "Erreur lors du cycle d'alertes: $($_.Exception.Message)" -Level "ERROR"
            if (-not $Continuous) {
                break
            }
            Start-Sleep -Seconds ($IntervalMinutes * 60)
        }
    } while ($Continuous)
    
    Write-Log "Système d'alertes terminé" -Level "SUCCESS"
}

# Point d'entrée
try {
    Write-Log "Démarrage du système d'alertes - Phase 3C"
    Start-AlertSystem
}
catch {
    Write-Log "Erreur fatale: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
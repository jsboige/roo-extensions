<#
.SYNOPSIS
    RooSync HUD Statusline — Barre de statut temps-réel pour le terminal PowerShell.

.DESCRIPTION
    Affiche une barre de statut compacte avec les métriques RooSync en temps-réel.
    Poll le endpoint roosync_hud_metrics via le MCP roo-state-manager.

    Presets disponibles :
    - minimal   : Status + machines online/offline (1 ligne)
    - verbose   : Toutes les métriques + flags (multi-ligne)
    - focused   : Machines + inbox + decisions (2 lignes)

.PARAMETER Preset
    Le preset d'affichage : minimal (défaut), verbose, focused.

.PARAMETER Interval
    Intervalle de rafraîchissement en secondes (défaut: 10).

.PARAMETER Once
    Afficher une seule fois et quitter (utile pour les scripts).

.PARAMETER JsonOutput
    Retourner le JSON brut du endpoint (debug/intégration).

.EXAMPLE
    .\roosync-hud-statusline.ps1
    .\roosync-hud-statusline.ps1 -Preset verbose -Interval 5
    .\roosync-hud-statusline.ps1 -Once -JsonOutput

.NOTES
    #1855 — RooSync HUD Statusline
    Requiert: roo-state-manager MCP actif avec sharedPath configuré.
#>

param(
    [ValidateSet('minimal', 'verbose', 'focused')]
    [string]$Preset = 'minimal',

    [int]$Interval = 10,

    [switch]$Once,

    [switch]$JsonOutput
)

# ============================================================
# Configuration
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

# Couleurs ANSI
$Colors = @{
    Reset    = "`e[0m"
    Bold     = "`e[1m"
    Dim      = "`e[2m"
    Red      = "`e[31m"
    Green    = "`e[32m"
    Yellow   = "`e[33m"
    Blue     = "`e[34m"
    Magenta  = "`e[35m"
    Cyan     = "`e[36m"
    White    = "`e[37m"
    BgRed    = "`e[41m"
    BgGreen  = "`e[42m"
    BgYellow = "`e[43m"
    BgBlue   = "`e[44m"
}

# ============================================================
# Fonctions utilitaires
# ============================================================

function Write-StatusBadge {
    param([string]$Status)
    switch ($Status) {
        'HEALTHY' { "${Colors.BgGreen}${Colors.Bold} OK ${Colors.Reset}" }
        'WARNING' { "${Colors.BgYellow}${Colors.Bold}WARN${Colors.Reset}" }
        'CRITICAL' { "${Colors.BgRed}${Colors.Bold}CRIT${Colors.Reset}" }
        default { "${Colors.Dim} ?? ${Colors.Reset}" }
    }
}

function Write-CountBadge {
    param([int]$Count, [string]$Label, [string]$Color)
    if ($Count -gt 0) {
        "${Color}${Count}${Colors.Reset} ${Colors.Dim}${Label}${Colors.Reset}"
    } else {
        "${Colors.Dim}0 ${Label}${Colors.Reset}"
    }
}

function Format-Uptime {
    param([int]$Seconds)
    if ($Seconds -lt 60) { return "${Seconds}s" }
    if ($Seconds -lt 3600) { return "$([math]::Floor($Seconds / 60))m" }
    if ($Seconds -lt 86400) { return "$([math]::Floor($Seconds / 3600))h$([math]::Floor(($Seconds % 3600) / 60))m" }
    return "$([math]::Floor($Seconds / 86400))d$([math]::Floor(($Seconds % 86400) / 3600))h"
}

function Get-Timestamp {
    return Get-Date -Format 'HH:mm:ss'
}

# ============================================================
# Collecte des métriques via MCP
# ============================================================

function Invoke-HudMetrics {
    param([bool]$IncludeDetails = $false, [bool]$IncludeIndexing = $false)

    # Appel JSON-RPC au MCP roo-state-manager via stdin/stdout
    $request = @{
        jsonrpc = '2.0'
        id = 1
        method = 'tools/call'
        params = @{
            name = 'roosync_hud_metrics'
            arguments = @{
                includeDetails = $IncludeDetails
                includeIndexing = $IncludeIndexing
            }
        }
    } | ConvertTo-Json -Compress

    # Tenter d'appeler via le MCP (nécessite que le serveur soit accessible)
    # Méthode 1: Via le pipe JSON-RPC si disponible dans le contexte
    # Méthode 2: Via un fichier temporaire + node
    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        # Construire la requête JSON-RPC complète
        $initRequest = @{
            jsonrpc = '2.0'
            id = 0
            method = 'initialize'
            params = @{
                protocolVersion = '2024-11-05'
                capabilities = @{}
                clientInfo = @{ name = 'roosync-hud'; version = '1.0.0' }
            }
        } | ConvertTo-Json -Compress

        $metricsRequest = @{
            jsonrpc = '2.0'
            id = 1
            method = 'tools/call'
            params = @{
                name = 'roosync_hud_metrics'
                arguments = @{
                    includeDetails = $IncludeDetails
                    includeIndexing = $IncludeIndexing
                }
            }
        } | ConvertTo-Json -Compress

        # Écrire les requêtes dans un fichier temporaire
        "$initRequest`n$metricsRequest" | Out-File -FilePath $tmpFile -Encoding utf8

        # Trouver le binaire node et le script du MCP
        $mcpScript = Join-Path $PSScriptRoot '..\mcps\internal\servers\roo-state-manager\build\index.js'
        if (-not (Test-Path $mcpScript)) {
            # Fallback: chercher dans le workspace courant
            $mcpScript = Join-Path $PWD 'mcps\internal\servers\roo-state-manager\build\index.js'
        }
        if (-not (Test-Path $mcpScript)) {
            return $null
        }

        $result = Get-Content $tmpFile -Raw | node $mcpScript 2>$null
        if ($result) {
            # Parser les réponses JSON-RPC (une par ligne)
            $lines = $result -split "`n" | Where-Object { $_.Trim() -match '^\{' }
            foreach ($line in $lines) {
                try {
                    $response = $line | ConvertFrom-Json
                    if ($response.id -eq 1 -and $response.result) {
                        $content = $response.result.content
                        if ($content -and $content[0].text) {
                            return $content[0].text | ConvertFrom-Json
                        }
                    }
                } catch {
                    continue
                }
            }
        }
        return $null
    }
    finally {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Alternative: Lecture directe des fichiers heartbeat/dashboard
# ============================================================

function Get-MetricsFromFilesystem {
    $metrics = @{
        timestamp = (Get-Date).ToString('o')
        system = @{ status = 'UNKNOWN'; uptime = 0 }
        machines = @{ online = 0; offline = 0; total = 0 }
        inbox = @{ unread = 0; urgent = 0 }
        decisions = @{ pending = 0 }
        dashboards = @{ active = 0 }
        flags = @()
    }

    try {
        # Trouver le shared-state path
        $sharedPath = $env:ROOSYNC_SHARED_PATH
        if (-not $sharedPath) {
            $gdrivePath = 'C:\Drive\.shortcut-targets-by-id'
            if (Test-Path $gdrivePath) {
                $sharedDirs = Get-ChildItem $gdrivePath -Directory | Select-Object -First 5
                foreach ($dir in $sharedDirs) {
                    $candidate = Join-Path $dir.FullName '.shared-state'
                    if (Test-Path $candidate) {
                        $sharedPath = $candidate
                        break
                    }
                }
            }
        }

        if (-not $sharedPath -or -not (Test-Path $sharedPath)) {
            return $metrics
        }

        # Lire les heartbeats
        $heartbeatDir = Join-Path $sharedPath 'heartbeats'
        if (Test-Path $heartbeatDir) {
            $heartbeatFiles = Get-ChildItem $heartbeatDir -Filter '*.json'
            $online = 0; $offline = 0
            $oneHourAgo = (Get-Date).AddHours(-1)

            foreach ($file in $heartbeatFiles) {
                try {
                    $hb = Get-Content $file.FullName -Raw | ConvertFrom-Json
                    $machineId = $hb.machineId ?? $file.BaseName
                    if ($machineId -notmatch '^myia-') { continue }

                    $lastBeat = [datetime]$hb.timestamp
                    if ($lastBeat -gt $oneHourAgo) {
                        $online++
                    } else {
                        $offline++
                        $metrics.flags += "OFFLINE:$machineId"
                    }
                } catch { continue }
            }
            $metrics.machines.online = $online
            $metrics.machines.offline = $offline
            $metrics.machines.total = $online + $offline
        }

        # Lire inbox
        $inboxDir = Join-Path $sharedPath 'inbox'
        $machineId = $env:ROOSYNC_MACHINE_ID ?? $env:COMPUTERNAME
        $machineInbox = Join-Path $inboxDir $machineId
        if (Test-Path $machineInbox) {
            $unreadFiles = Get-ChildItem $machineInbox -Filter '*.json' | Where-Object {
                $content = Get-Content $_.FullName -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                $content.status -eq 'unread'
            }
            $metrics.inbox.unread = $unreadFiles.Count
            $urgentFiles = $unreadFiles | Where-Object {
                $content = Get-Content $_.FullName -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                $content.priority -eq 'URGENT'
            }
            $metrics.inbox.urgent = $urgentFiles.Count
        }

        # Compter dashboards actifs
        $dashDir = Join-Path $sharedPath 'dashboards'
        if (Test-Path $dashDir) {
            $oneDayAgo = (Get-Date).AddDays(-1)
            $activeFiles = Get-ChildItem $dashDir -Filter '*.md' | Where-Object {
                $_.LastWriteTime -gt $oneDayAgo
            }
            $metrics.dashboards.active = $activeFiles.Count
        }

        # Déterminer le statut global
        if ($metrics.machines.offline -ge [math]::Ceiling($metrics.machines.total / 2) -and $metrics.machines.total -gt 0) {
            $metrics.system.status = 'CRITICAL'
        } elseif ($metrics.machines.offline -gt 0 -or $metrics.inbox.urgent -gt 0) {
            $metrics.system.status = 'WARNING'
        } elseif ($metrics.machines.total -gt 0) {
            $metrics.system.status = 'HEALTHY'
        }
    }
    catch {
        $metrics.system.status = 'UNKNOWN'
    }

    return $metrics
}

# ============================================================
# Renderers par preset
# ============================================================

function Render-Minimal {
    param($Metrics)

    $ts = Get-Timestamp
    $badge = Write-StatusBadge $Metrics.system.status
    $online = Write-CountBadge $Metrics.machines.online 'up' $Colors.Green
    $offline = Write-CountBadge $Metrics.machines.offline 'down' $(if ($Metrics.machines.offline -gt 0) { $Colors.Red } else { $Colors.Dim })
    $inbox = Write-CountBadge $Metrics.inbox.unread 'msg' $(if ($Metrics.inbox.urgent -gt 0) { $Colors.Red } elseif ($Metrics.inbox.unread -gt 0) { $Colors.Yellow } else { $Colors.Dim })
    $decisions = Write-CountBadge $Metrics.decisions.pending 'pend' $(if ($Metrics.decisions.pending -gt 0) { $Colors.Yellow } else { $Colors.Dim })
    $dashboards = Write-CountBadge $Metrics.dashboards.active 'dash' $Colors.Cyan

    $line = "${Colors.Dim}[$ts]${Colors.Reset} $badge ${Colors.Bold}RooSync${Colors.Reset} $online | $offline | $inbox | $decisions | $dashboards"

    # Ajouter les flags s'il y en a
    if ($Metrics.flags -and $Metrics.flags.Count -gt 0) {
        $flagStr = $Metrics.flags -join ' '
        $line += " ${Colors.Yellow}$flagStr${Colors.Reset}"
    }

    return $line
}

function Render-Focused {
    param($Metrics)

    $ts = Get-Timestamp
    $badge = Write-StatusBadge $Metrics.system.status

    # Ligne 1: Machines
    $machineStr = "${Colors.Bold}Machines${Colors.Reset}: "
    $machineStr += "${Colors.Green}$($Metrics.machines.online) online${Colors.Reset} / "
    if ($Metrics.machines.offline -gt 0) {
        $machineStr += "${Colors.Red}$($Metrics.machines.offline) offline${Colors.Reset}"
    } else {
        $machineStr += "${Colors.Dim}0 offline${Colors.Reset}"
    }
    $machineStr += " ${Colors.Dim}($($Metrics.machines.total) total)${Colors.Reset}"

    # Ligne 2: Inbox + Decisions + Dashboards
    $inboxStr = "${Colors.Bold}Inbox${Colors.Reset}: "
    if ($Metrics.inbox.urgent -gt 0) {
        $inboxStr += "${Colors.Red}$($Metrics.inbox.urgent) urgent${Colors.Reset}, "
    }
    $inboxStr += "$(Write-CountBadge $Metrics.inbox.unread 'unread' $(if ($Metrics.inbox.unread -gt 0) { $Colors.Yellow } else { $Colors.Dim }))"

    $decStr = "${Colors.Bold}Decisions${Colors.Reset}: $(Write-CountBadge $Metrics.decisions.pending 'pending' $(if ($Metrics.decisions.pending -gt 0) { $Colors.Yellow } else { $Colors.Dim }))"
    $dashStr = "${Colors.Bold}Dashboards${Colors.Reset}: $(Write-CountBadge $Metrics.dashboards.active 'active' $Colors.Cyan)"

    $line1 = "${Colors.Dim}[$ts]${Colors.Reset} $badge ${Colors.Bold}RooSync${Colors.Reset} $machineStr"
    $line2 = "${Colors.Dim}       ${Colors.Reset}  $inboxStr  |  $decStr  |  $dashStr"

    # Flags
    $lines = @($line1, $line2)
    if ($Metrics.flags -and $Metrics.flags.Count -gt 0) {
        $flagStr = $Metrics.flags -join ', '
        $lines += "${Colors.Dim}       ${Colors.Reset}  ${Colors.Yellow}Flags: $flagStr${Colors.Reset}"
    }

    return $lines -join "`n"
}

function Render-Verbose {
    param($Metrics)

    $ts = Get-Timestamp
    $badge = Write-StatusBadge $Metrics.system.status
    $uptime = Format-Uptime $Metrics.system.uptime

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("${Colors.Dim}[$ts]${Colors.Reset} $badge ${Colors.Bold}RooSync HUD${Colors.Reset} ${Colors.Dim}(uptime: $uptime)${Colors.Reset}")
    [void]$sb.AppendLine("${Colors.Cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Colors.Reset}")

    # Machines
    [void]$sb.AppendLine("  ${Colors.Bold}Machines${Colors.Reset}    : $(Write-CountBadge $Metrics.machines.online 'online' $Colors.Green) | $(Write-CountBadge $Metrics.machines.offline 'offline' $(if ($Metrics.machines.offline -gt 0) { $Colors.Red } else { $Colors.Dim })) | ${Colors.Dim}$($Metrics.machines.total) total${Colors.Reset}")

    # Machine details if available
    if ($Metrics.machines.details) {
        foreach ($m in $Metrics.machines.details) {
            $statusColor = switch ($m.status) {
                'online' { $Colors.Green }
                'offline' { $Colors.Red }
                'warning' { $Colors.Yellow }
                default { $Colors.Dim }
            }
            [void]$sb.AppendLine("    ${statusColor}● $($m.id)${Colors.Reset} ${Colors.Dim}($($m.status))${Colors.Reset}")
        }
    }

    # Inbox
    $inboxColor = if ($Metrics.inbox.urgent -gt 0) { $Colors.Red } elseif ($Metrics.inbox.unread -gt 0) { $Colors.Yellow } else { $Colors.Dim }
    [void]$sb.AppendLine("  ${Colors.Bold}Inbox${Colors.Reset}       : $(Write-CountBadge $Metrics.inbox.unread 'unread' $inboxColor) | $(Write-CountBadge $Metrics.inbox.urgent 'urgent' $(if ($Metrics.inbox.urgent -gt 0) { $Colors.Red } else { $Colors.Dim }))")

    # Decisions
    [void]$sb.AppendLine("  ${Colors.Bold}Decisions${Colors.Reset}   : $(Write-CountBadge $Metrics.decisions.pending 'pending' $(if ($Metrics.decisions.pending -gt 0) { $Colors.Yellow } else { $Colors.Dim }))")

    # Dashboards
    [void]$sb.AppendLine("  ${Colors.Bold}Dashboards${Colors.Reset}  : $(Write-CountBadge $Metrics.dashboards.active 'active (<24h)' $Colors.Cyan)")

    # Indexing
    if ($Metrics.indexing) {
        $idxColor = if ($Metrics.indexing.queueSize -gt 0) { $Colors.Yellow } else { $Colors.Dim }
        [void]$sb.AppendLine("  ${Colors.Bold}Indexing${Colors.Reset}    : $(Write-CountBadge $Metrics.indexing.queueSize 'in queue' $idxColor) | $(if ($Metrics.indexing.enabled) { "${Colors.Green}enabled${Colors.Reset}" } else { "${Colors.Dim}disabled${Colors.Reset}" })")
    }

    # Flags
    if ($Metrics.flags -and $Metrics.flags.Count -gt 0) {
        [void]$sb.AppendLine("${Colors.Cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Colors.Reset}")
        foreach ($flag in $Metrics.flags) {
            [void]$sb.AppendLine("  ${Colors.Yellow}⚠ $flag${Colors.Reset}")
        }
    }

    [void]$sb.AppendLine("${Colors.Cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Colors.Reset}")

    return $sb.ToString()
}

# ============================================================
# Boucle principale
# ============================================================

function Show-Hud {
    # Essayer d'abord le MCP, puis fallback filesystem
    $metrics = $null

    # Mode JSON brut
    if ($JsonOutput) {
        $metrics = Invoke-HudMetrics -IncludeDetails $true -IncludeIndexing $true
        if ($null -ne $metrics) {
            return $metrics | ConvertTo-Json -Depth 5
        }
        $metrics = Get-MetricsFromFilesystem
        return $metrics | ConvertTo-Json -Depth 5
    }

    while ($true) {
        # Collecter les métriques
        $needDetails = ($Preset -eq 'verbose')
        $needIndexing = ($Preset -eq 'verbose')

        $metrics = Invoke-HudMetrics -IncludeDetails $needDetails -IncludeIndexing $needIndexing
        if ($null -eq $metrics) {
            $metrics = Get-MetricsFromFilesystem
        }

        # Effacer la ligne précédente (sauf si mode verbose multi-ligne)
        if ($Preset -ne 'verbose') {
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
            [Console]::Write((" " * [Console]::WindowWidth))
            [Console]::SetCursorPosition(0, [Console]::CursorTop)
        }

        # Renderer selon le preset
        $output = switch ($Preset) {
            'minimal' { Render-Minimal $metrics }
            'focused' { Render-Focused $metrics }
            'verbose' { Render-Verbose $metrics }
        }

        Write-Host $output

        if ($Once) { return }

        Start-Sleep -Seconds $Interval

        # Pour verbose, effacer les lignes précédentes
        if ($Preset -eq 'verbose') {
            $lineCount = ($output -split "`n").Count
            for ($i = 0; $i -lt $lineCount; $i++) {
                [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
                [Console]::Write((" " * [Console]::WindowWidth))
                [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
            }
        }
    }
}

# Point d'entrée
Show-Hud

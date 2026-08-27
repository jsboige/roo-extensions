<#
.SYNOPSIS
    Event-driven dashboard listener using FileSystemWatcher (#2004, Epic #1997).

.DESCRIPTION
    Replaces poll-dashboard.ps1 polling with push-based detection.
    Monitors GDrive dashboards directory for file changes via FileSystemWatcher.

    When a workspace dashboard changes:
    1. Debounces 10 seconds (anti-GDrive rafales)
    2. Reads changed dashboard, parses intercom messages
    3. Checks for actionable tags ([WAKE-CLAUDE] by default — Phase 1)
    4. Resolves the workspace's on-disk path (so claude -p starts in the right CWD)
    5. If tag found AND path resolved AND cooldown OK (5 min) → spawns spawn-claude.ps1

    Zero token cost when idle. Latency <30s when triggered.

.PARAMETER AllowedTags
    Comma-separated tags that trigger a spawn.
    Default: WAKE-CLAUDE (Phase 1 — restricted surface). Override via
    DASHBOARD_WATCHER_TAGS env var (e.g. 'ASK,TASK,BLOCKED,URGENT,WAKE-CLAUDE').

.PARAMETER DebounceSeconds
    Seconds to wait after last file change before processing (default: 10).

.PARAMETER CooldownMinutes
    Minimum minutes between spawns for the same workspace (default: 5).

.PARAMETER Workspaces
    Comma-separated workspace list to watch. Empty = auto-discover ALL
    workspace-*.md dashboards under $SharedPath/dashboards, optionally
    filtered by DASHBOARD_WATCHER_WORKSPACES env var.

.PARAMETER SharedPath
    Path to .shared-state directory. Default: $env:ROOSYNC_SHARED_PATH.

.PARAMETER LockDir
    Directory for last-ACK and cooldown marker files. Default: .claude/locks.

.PARAMETER SpawnScript
    Path to spawn-claude.ps1. Default: sibling script.

.PARAMETER McpConfig
    Path to MCP config JSON. Default: ~/.claude.json.

.PARAMETER WorkspacePathsFile
    JSON map { "<workspace-name>": "<absolute-path>", ... } overriding path
    auto-detection per workspace. Default: <repo-root>/.claude/local/workspace-paths.json
    (gitignored, machine-specific).

    Resolution order for a workspace name:
      1. WorkspacePathsFile entry (explicit override)
      2. DASHBOARD_WATCHER_WORKSPACE_PATHS env var (JSON map)
      3. Self-match (ws name == leaf of $RepoRoot) → $RepoRoot
      4. ~/.claude.json `projects` keys — match by basename (Claude Code's own
         workspace registry; the most reliable per-machine source after explicit
         overrides).
      5. Auto-detect: scan parent of $RepoRoot, then D:\, D:\dev, C:\, C:\dev
      6. If no match → log WARN and SKIP spawn (lastAck NOT advanced)

.PARAMETER GitHubRepo
    GitHub repo for closed-issue sanity check (R11). Before spawning on a
    [WAKE-CLAUDE] message that references issue numbers (#NNN), the listener
    verifies those issues are still OPEN. If CLOSED, the message is skipped
    and lastAck advanced. Default: jsboige/roo-extensions.
    Override via DASHBOARD_WATCHER_GITHUB_REPO env var.

.PARAMETER DryRun
    Log decisions but do not spawn.

.PARAMETER Once
    Process all pending workspaces once and exit (for testing).

.EXAMPLE
    .\dashboard-listener.ps1
    .\dashboard-listener.ps1 -Workspaces 'roo-extensions' -DryRun
#>

param(
    [string]$AllowedTags = $(if ($env:DASHBOARD_WATCHER_TAGS) { $env:DASHBOARD_WATCHER_TAGS } else { 'WAKE-CLAUDE,WAKE-HERMES,WAKE-NANOCLAW,WAKE-VIBE' }),
    [int]$DebounceSeconds = 10,
    [int]$CooldownMinutes = 5,
    [string]$Workspaces = "",
    [string]$SharedPath = $env:ROOSYNC_SHARED_PATH,
    [string]$LockDir = "",
    [string]$SpawnScript = "",
    [string]$McpConfig = "",
    [string]$WorkspacePathsFile = "",
    [string]$GitHubRepo = $(if ($env:DASHBOARD_WATCHER_GITHUB_REPO) { $env:DASHBOARD_WATCHER_GITHUB_REPO } else { 'jsboige/roo-extensions' }),
    # #3277 fix 4 : lane payant — un [WAKE-VIBE] échoué n'est jamais re-dispatché
    # au-delà de N tentatives (défaut 1). spawn-claude garde sa sémantique retry-gratuit.
    [int]$VibeMaxAttempts = $(if ($env:DASHBOARD_VIBE_MAX_ATTEMPTS) { [int]$env:DASHBOARD_VIBE_MAX_ATTEMPTS } else { 1 }),
    # #3277 fix 1 : suffixe du mutex single-instance (isolation de test uniquement).
    [string]$InstanceSuffix = "",
    # #3277 : chemin du worker Vibe (seam de test ; défaut = chemin de production).
    [string]$VibeWorkerScript = "",
    [switch]$DryRun,
    [switch]$Once
)

$ErrorActionPreference = "Continue"

# ========== PATH RESOLUTION ==========

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)

if ([string]::IsNullOrEmpty($LockDir)) {
    $LockDir = Join-Path $RepoRoot ".claude/locks"
}
if ([string]::IsNullOrEmpty($SpawnScript)) {
    $SpawnScript = Join-Path $scriptDir "spawn-claude.ps1"
}
if ([string]::IsNullOrEmpty($McpConfig)) {
    $McpConfig = Join-Path $env:USERPROFILE ".claude.json"
}
if ([string]::IsNullOrEmpty($WorkspacePathsFile)) {
    $WorkspacePathsFile = Join-Path $RepoRoot ".claude/local/workspace-paths.json"
}
if (-not (Test-Path $LockDir)) {
    New-Item -ItemType Directory -Path $LockDir -Force | Out-Null
}
if ([string]::IsNullOrEmpty($VibeWorkerScript)) {
    $VibeWorkerScript = Join-Path $RepoRoot "scripts/scheduling/start-vibe-worker.ps1"
}

# ========== SINGLE-INSTANCE GUARD (#3277 fix 1) ==========
# Mutex nommé kernel-side : élimine toute 2e invocation concurrente du listener,
# quelle que soit sa voie de spawn (wrapper dupliqué OU invocation bare hors wrapper
# — incident 25/08 : 2 chaînes concurrentes → 1 [WAKE-VIBE] → 3 sessions payées).
# exit 75 = « une autre instance vit » : le wrapper reconnaît ce code et STOPPE sa
# chaîne au lieu de redémarrer en boucle.
. (Join-Path $RepoRoot "scripts\common\single-instance-mutex.ps1")
$script:SingleInstance = Get-SingleInstance -Name "RooSync-DashboardListener$InstanceSuffix"
if (-not $script:SingleInstance.Acquired) {
    Write-Host "[$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))] [ERROR] Another dashboard-listener instance is already active ($($script:SingleInstance.Namespace)mutex) — exiting 75, dispatch chain preserved (#3277)."
    exit 75
}

$tagList = $AllowedTags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

# ========== WORKSPACE PATH RESOLUTION ==========

# Cache so we don't re-read the file / re-parse env on every event
$script:_wsPathCache = @{}
$script:_wsPathFileMap = $null
$script:_wsPathEnvMap = $null
$script:_wsPathClaudeJsonMap = $null

function Get-WorkspacePathMaps {
    if ($null -eq $script:_wsPathFileMap) {
        $script:_wsPathFileMap = @{}
        if (Test-Path $WorkspacePathsFile) {
            try {
                $raw = [System.IO.File]::ReadAllText($WorkspacePathsFile, [System.Text.UTF8Encoding]::new($false))
                $obj = $raw | ConvertFrom-Json
                foreach ($prop in $obj.PSObject.Properties) {
                    $script:_wsPathFileMap[$prop.Name] = [string]$prop.Value
                }
            } catch {
                Write-Log "WARN" "Failed to parse $WorkspacePathsFile : $_"
            }
        }
    }
    if ($null -eq $script:_wsPathEnvMap) {
        $script:_wsPathEnvMap = @{}
        $envJson = $env:DASHBOARD_WATCHER_WORKSPACE_PATHS
        if (-not [string]::IsNullOrEmpty($envJson)) {
            try {
                $obj = $envJson | ConvertFrom-Json
                foreach ($prop in $obj.PSObject.Properties) {
                    $script:_wsPathEnvMap[$prop.Name] = [string]$prop.Value
                }
            } catch {
                Write-Log "WARN" "Failed to parse DASHBOARD_WATCHER_WORKSPACE_PATHS env var: $_"
            }
        }
    }
    return @{ file = $script:_wsPathFileMap; env = $script:_wsPathEnvMap }
}

function Get-ClaudeJsonProjectsMap {
    # Returns a hashtable { lowercase-leaf-name → absolute-path } populated from
    # the `projects` section of $McpConfig (typically ~/.claude.json). This is
    # Claude Code's own workspace registry and is the most reliable per-machine
    # source after explicit user overrides.
    if ($null -ne $script:_wsPathClaudeJsonMap) {
        return $script:_wsPathClaudeJsonMap
    }
    $script:_wsPathClaudeJsonMap = @{}
    if ([string]::IsNullOrEmpty($McpConfig) -or -not (Test-Path $McpConfig)) {
        return $script:_wsPathClaudeJsonMap
    }
    try {
        $raw = [System.IO.File]::ReadAllText($McpConfig, [System.Text.UTF8Encoding]::new($false))
        # Use .NET deserialization for PS 5.1 compatibility (#2186 Bug 2).
        # ConvertFrom-Json -AsHashtable requires PS 7+; under Windows PowerShell 5.1
        # it throws silently, killing path resolution source #4.
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
        $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $serializer.MaxJsonLength = [int]::MaxValue
        $obj = $serializer.DeserializeObject($raw)
        if ($null -ne $obj -and $obj.ContainsKey('projects') -and $null -ne $obj['projects']) {
            foreach ($absPath in $obj['projects'].Keys) {
                if ([string]::IsNullOrEmpty($absPath)) { continue }
                $leaf = Split-Path $absPath -Leaf
                if ([string]::IsNullOrEmpty($leaf)) { continue }
                $key = $leaf.ToLowerInvariant()
                if (-not $script:_wsPathClaudeJsonMap.ContainsKey($key)) {
                    $script:_wsPathClaudeJsonMap[$key] = $absPath
                }
            }
        }
    } catch {
        Write-Log "WARN" "Failed to parse $McpConfig projects section: $_"
    }
    return $script:_wsPathClaudeJsonMap
}

function Resolve-WorkspacePath($ws) {
    if ($script:_wsPathCache.ContainsKey($ws)) {
        return $script:_wsPathCache[$ws]
    }

    $maps = Get-WorkspacePathMaps

    # 1. Explicit override file
    if ($maps.file.ContainsKey($ws)) {
        $p = $maps.file[$ws]
        if (Test-Path $p -PathType Container) {
            $script:_wsPathCache[$ws] = $p
            return $p
        }
        Write-Log "WARN" "[$ws] Mapped path does not exist: $p (from $WorkspacePathsFile)"
    }

    # 2. Env var map
    if ($maps.env.ContainsKey($ws)) {
        $p = $maps.env[$ws]
        if (Test-Path $p -PathType Container) {
            $script:_wsPathCache[$ws] = $p
            return $p
        }
        Write-Log "WARN" "[$ws] Mapped path does not exist: $p (from DASHBOARD_WATCHER_WORKSPACE_PATHS)"
    }

    # 3. Self-match: ws name equals leaf of $RepoRoot (case-insensitive)
    $selfName = Split-Path $RepoRoot -Leaf
    if ($ws -ieq $selfName) {
        $script:_wsPathCache[$ws] = $RepoRoot
        return $RepoRoot
    }

    # 4. ~/.claude.json projects (Claude Code's own workspace registry)
    $cjMap = Get-ClaudeJsonProjectsMap
    $key = $ws.ToLowerInvariant()
    if ($cjMap.ContainsKey($key)) {
        $p = $cjMap[$key]
        if (Test-Path $p -PathType Container) {
            $script:_wsPathCache[$ws] = $p
            return $p
        }
        Write-Log "WARN" "[$ws] .claude.json projects entry maps to non-existent path: $p"
    }

    # 5. Auto-detect: scan common roots
    $candidateRoots = @(
        (Split-Path $RepoRoot -Parent),
        "D:\dev", "D:\", "C:\dev", "C:\"
    )
    foreach ($root in $candidateRoots) {
        if ([string]::IsNullOrEmpty($root)) { continue }
        if (-not (Test-Path $root -PathType Container)) { continue }
        $candidate = Join-Path $root $ws
        if (Test-Path $candidate -PathType Container) {
            $script:_wsPathCache[$ws] = $candidate
            return $candidate
        }
    }

    # 6. Not found
    $script:_wsPathCache[$ws] = $null
    return $null
}

# ========== LOGGING ==========

function Write-Log($level, $msg) {
    # #3277 fix 5 : UTC réel. Le "Z" littéral collé sur l'heure locale faisait mentir
    # chaque ligne du log sur le fuseau (fausse piste « 20:06Z » des mémoires 25/08).
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$level] $msg"
    Write-Host $line
}

# ========== PERSISTENT STATE ==========

function Get-LastAck($ws) {
    $f = Join-Path $LockDir "watcher-$ws.lastack"
    if (Test-Path $f) { return (Get-Content $f -Raw).Trim() }
    return ""
}

function Set-LastAck($ws, $ts) {
    $f = Join-Path $LockDir "watcher-$ws.lastack"
    [System.IO.File]::WriteAllText($f, $ts, [System.Text.UTF8Encoding]::new($false))
}

function Get-LastSpawn($ws) {
    $f = Join-Path $LockDir "listener-$ws.lastrun"
    if (Test-Path $f) {
        $val = (Get-Content $f -Raw).Trim()
        if (-not [string]::IsNullOrEmpty($val)) { return $val }
    }
    return ""
}

function Set-LastSpawn($ws) {
    $f = Join-Path $LockDir "listener-$ws.lastrun"
    $ts = (Get-Date).ToUniversalTime().ToString("o")
    [System.IO.File]::WriteAllText($f, $ts, [System.Text.UTF8Encoding]::new($false))
}

# ========== VIBE WAKE ATTEMPTS (#3277 fix 4 : lane payant, tentative bornée) ==========
# Un [WAKE-VIBE] échoué (timeout = exit 1) restait actionable pour toujours :
# lastAck n'avance que sur exit 0 et le cooldown (5 min) expire bien avant la fin
# du runtime (600-900 s) → re-dispatch payé à chaque cycle (session #3 du 25/08 =
# 15 min après le double-spawn). Ce store compte les tentatives PAR message ;
# au-delà de $VibeMaxAttempts le message est consommé (lastAck avancé) avec un
# WARN — jamais re-fire automatiquement un échec sur un lane Mistral payant.

$VibeAttemptsFile = Join-Path $LockDir "vibe-wake-attempts.json"

function Get-VibeAttemptsMap {
    if (Test-Path $VibeAttemptsFile) {
        try {
            $obj = [System.IO.File]::ReadAllText($VibeAttemptsFile, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
            $map = @{}
            foreach ($prop in $obj.PSObject.Properties) { $map[$prop.Name] = [int]$prop.Value }
            return $map
        } catch { }
    }
    return @{}
}

function Save-VibeAttemptsMap($map) {
    # Prune : garde les 100 clés les plus récentes (les clés sont des timestamps ISO).
    if ($map.Count -gt 100) {
        $sorted = $map.GetEnumerator() | Sort-Object Name -Descending | Select-Object -First 100
        $map = @{}
        foreach ($e in $sorted) { $map[$e.Key] = $e.Value }
    }
    $obj = [pscustomobject]$map
    [System.IO.File]::WriteAllText($VibeAttemptsFile, ($obj | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
}

function Get-VibeAttemptCount($msgTs) {
    $map = Get-VibeAttemptsMap
    if ($map.ContainsKey($msgTs)) { return $map[$msgTs] }
    return 0
}

function Add-VibeAttempt($msgTs) {
    $map = Get-VibeAttemptsMap
    if ($map.ContainsKey($msgTs)) { $map[$msgTs] = $map[$msgTs] + 1 } else { $map[$msgTs] = 1 }
    Save-VibeAttemptsMap $map
}

function Remove-VibeAttempt($msgTs) {
    $map = Get-VibeAttemptsMap
    if ($map.ContainsKey($msgTs)) {
        $map.Remove($msgTs)
        Save-VibeAttemptsMap $map
    }
}

# ========== WORKSPACE RESOLUTION ==========

function Resolve-Workspaces {
    if (-not [string]::IsNullOrEmpty($Workspaces)) {
        return $Workspaces -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }
    $envWs = $env:DASHBOARD_WATCHER_WORKSPACES
    if (-not [string]::IsNullOrEmpty($envWs)) {
        Write-Log "INFO" "Using DASHBOARD_WATCHER_WORKSPACES: $envWs"
        return $envWs -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }
    # Auto-discover from dashboards directory
    $dbDir = Join-Path $SharedPath "dashboards"
    if (-not (Test-Path $dbDir)) { return @() }
    return @(Get-ChildItem -Path $dbDir -Filter "workspace-*.md" -File |
             ForEach-Object { $_.BaseName -replace '^workspace-', '' })
}

# ========== DASHBOARD PARSING ==========

function Read-DashboardMessages($ws) {
    $dashboardFile = Join-Path $SharedPath "dashboards/workspace-$ws.md"
    if (-not (Test-Path $dashboardFile)) { return @() }

    # Fix #2926 (TOCTOU race, po-204 firsthand 2026-07-24) :
    # Test-Path ci-dessus passe, puis ReadAllText échoue → le cache online-only GDriveFS
    # a évincé le fichier OU le dossier parent entre le check et le read (time-of-check
    # vs time-of-use). Attendu/bénin → DEBUG + return @() (retry au prochain poll). On
    # reserve l'ERROR du caller (L841) aux VRAIES erreurs (IOException disque, permission
    # refusée) en relançant l'exception. Match sur les types (pas le message : localisé
    # FR/EN fragile). PowerShell enveloppe FileNotFoundException/DirectoryNotFoundException
    # dans MethodInvocationException → c'est `InnerException` qui porte le type réel.
    # Les 2 premiers checks sont défensifs (peuvent matcher sur certains chemins PowerShell
    # non-wrap) — le check effectif passe par InnerException (#2927 review web1).
    try {
        $raw = [System.IO.File]::ReadAllText($dashboardFile, [System.Text.UTF8Encoding]::new($false))
    } catch {
        $isMissingFile = ($_.Exception -is [System.IO.FileNotFoundException]) -or
                         ($_.Exception -is [System.IO.DirectoryNotFoundException]) -or
                         ($_.Exception -is [System.Management.Automation.ItemNotFoundException]) -or
                         ($_.Exception.InnerException -is [System.IO.FileNotFoundException]) -or
                         ($_.Exception.InnerException -is [System.IO.DirectoryNotFoundException])
        if ($isMissingFile) {
            Write-Log "DEBUG" "[$ws] Dashboard file or directory disappeared (race GDriveFS post-Test-Path): $dashboardFile"
            return @()
        }
        throw
    }

    # Find intercom section
    $intercomMatch = [regex]::Match($raw, '(?ms)^## Intercom \(\d+ messages\)\s*\n(.+)$')
    if (-not $intercomMatch.Success) { return @() }
    $intercomBody = $intercomMatch.Groups[1].Value

    # Parse messages: ### [TIMESTAMP] machineId|workspace
    $msgPattern = '(?ms)^### \[(?<ts>[^\]]+)\] (?<machine>[^|]+)\|(?<workspace>[^\r\n]+)\r?\n(?:\[msg:[^\r\n]*\]\r?\n)?\r?\n(?<body>.*?)(?=\r?\n^### \[|\z)'
    $msgMatches = [regex]::Matches($intercomBody, $msgPattern)

    $messages = @()
    foreach ($m in $msgMatches) {
        $body = $m.Groups['body'].Value.Trim()
        $body = [regex]::Replace($body, '\r?\n---\s*$', '')
        $messages += [pscustomobject]@{
            timestamp = $m.Groups['ts'].Value.Trim()
            content   = $body
            author    = [pscustomobject]@{
                machineId = $m.Groups['machine'].Value.Trim()
                workspace = $m.Groups['workspace'].Value.Trim()
            }
        }
    }
    return $messages
}

# ========== TAG DETECTION ==========

function Test-ActionableContent($content) {
    # #2004 Phase 2: Strict header-only tag detection.
    # Previous regex matched any [TAG] anywhere in body text → false positives
    # on meta-discussions about the tag (e.g. an ACK explaining what [WAKE-CLAUDE]
    # means triggered itself recursively). Now: tag MUST be in a markdown header
    # (### [TAG] ...) or at the very start of a line as a bracketed prefix.
    $nonCodeLines = @()
    $inCodeBlock = $false
    foreach ($line in ($content -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^```') { $inCodeBlock = -not $inCodeBlock; continue }
        if (-not $inCodeBlock) { $nonCodeLines += $line }
    }
    $nonCode = $nonCodeLines -join "`n"

    foreach ($tag in $tagList) {
        # Markdown header: ## [TAG] / ### [TAG] / # [TAG]
        if ($nonCode -match "(?m)^#{1,3}\s*\[$tag\]") { return $true }
        # Bracket-prefix at start of line: [TAG] ...
        if ($nonCode -match "(?m)^\[$tag\]") { return $true }
    }
    return $false
}

# #2117 + #2240: Parse target machine from [WAKE-CLAUDE] <machine>[:<workspace>] pattern.
# Returns the target machine ID (lowercase) or $null for broadcast messages.
# Accepts the documented routing variants:
#   [WAKE-CLAUDE] myia-po-2023 — ...
#   [WAKE-CLAUDE] → myia-po-2026:Embeddings — ...   (optional arrow prefix)
#   [WAKE-CLAUDE] myia-po-2023:IISManagement — ...  (optional :workspace suffix)
#   [WAKE-CLAUDE] myia-po-2025:roo-extensions — ...  (#2240 workspace-targeted)
function Get-WakeTargetMachine($content) {
    if ($content -match '\[WAKE-CLAUDE\]\s*(?:→|->)?\s*(myia-[a-z0-9]+(?:-[a-z0-9]+)*)(?::([a-zA-Z0-9_.-]+))?') {
        return $Matches[1].ToLowerInvariant()
    }
    return $null
}

# #2240: Extract optional workspace suffix from [WAKE-CLAUDE] <machine>:<workspace>.
# Returns the workspace name (original case) or $null if no workspace specified.
# When $null, the wake targets ALL workspaces on the matched machine (backward compat).
function Get-WakeTargetWorkspace($content) {
    if ($content -match '\[WAKE-CLAUDE\]\s*(?:→|->)?\s*myia-[a-z0-9]+(?:-[a-z0-9]+)*:([a-zA-Z0-9_.-]+)') {
        return $Matches[1]
    }
    return $null
}

# #2244: Bot wake routing — [WAKE-HERMES] → myia-po-2026:hermes-agent, [WAKE-NANOCLAW] → myia-ai-01:nanoclaw.
# #3202: [WAKE-VIBE] → CoursIA (Mistral Vibe — spawn is NOT claude -p, see Process-WakeTags).
# Returns @{ machine = '<id>'; workspace = '<ws>' } or $null if no bot tag matched.
function Get-WakeBotTarget($content) {
    if ($content -match '\[WAKE-HERMES\]') {
        return @{ machine = 'myia-po-2026'; workspace = 'hermes-agent' }
    }
    if ($content -match '\[WAKE-NANOCLAW\]') {
        return @{ machine = 'myia-ai-01'; workspace = 'nanoclaw' }
    }
    if ($content -match '\[WAKE-VIBE\]') {
        return @{ machine = 'myia-po-2025'; workspace = 'CoursIA' }
    }
    return $null
}

# ========== CLOSED ISSUE CHECK (R11 sanity) ==========

# #2431 follow-up: Extract ONLY the WAKE-instruction line(s) from a message.
# R11 (closed-issue check) must scan these lines, not the whole body. Coordinator
# dispatches cite merged PRs (e.g. "PRs #617-#621 merged") as accomplished context;
# scanning the full body made R11 reject the entire WAKE because those #NNN are CLOSED,
# advancing lastAck and dropping the spawn permanently (26 days of missed wakes — the
# #2558 attempt used `^\[$tag\]` on whole content, which misses WAKE tags embedded in
# multi-part dispatches). Reuses the same line/header anchoring as Test-ActionableContent,
# so a genuine "[WAKE-CLAUDE] ... #2415" with a closed target #2415 is still caught (R11
# intent preserved), but context references on other lines are ignored.
function Get-WakeInstructionLines($content) {
    $inCodeBlock = $false
    $wakeLines = @()
    foreach ($line in ($content -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^```') { $inCodeBlock = -not $inCodeBlock; continue }
        if ($inCodeBlock) { continue }
        foreach ($tag in $tagList) {
            if ($line -match "^#{1,3}\s*\[$tag\]" -or $line -match "^\[$tag\]") {
                $wakeLines += $line
                break
            }
        }
    }
    return ($wakeLines -join "`n")
}

# #2431 follow-up (model selection, user mandate 2026-06-11): a WAKE line may carry an
# optional `model=X` hint, e.g. `[WAKE-CLAUDE] myia-po-2023:IISManagement model=haiku`.
# No hint → spawn-claude uses its own default (Sonnet/GLM, capable). The hint lets the
# caller downshift to haiku when the task is trivial, or pin a heavier/explicit model.
# Scoped to the WAKE-instruction line(s) only, so `model=` words elsewhere in the body
# are ignored. The routing regexes (Get-WakeTarget*) stop the workspace capture at the
# first space, so a trailing ` model=X` suffix never corrupts machine/workspace routing.
function Get-WakeModelHint($content) {
    $wakeLines = Get-WakeInstructionLines $content
    if ($wakeLines -match '(?i)\bmodel\s*=\s*([A-Za-z0-9._-]+)') {
        return $Matches[1]
    }
    return ""
}

function Test-ReferencedClosedIssues($content, $repo) {
    # R11 sanity check: extracts issue numbers (#NNN) from message content
    # and checks their state via gh CLI. Returns array of CLOSED issue strings.
    # Non-blocking: if gh unavailable or network fails, returns empty array.
    $closed = @()
    if ([string]::IsNullOrEmpty($repo)) { return $closed }

    # The lookbehind is load-bearing. Without it, '#(\d+)' matches the tail of any
    # token ending in #N -- and acceptance criteria are written "AC#4". On
    # 2026-08-16 that swallowed a real WAKE addressed to ai-01: the line read
    # "[WAKE-CLAUDE] myia-ai-01 - #1357 AC#4 : probe E2E", the check extracted
    # BOTH #1357 (open) and #4 (closed, unrelated), and the message was dropped.
    #
    # The {4,} length floor is load-bearing for the same reason. A bare ordinal at
    # a word boundary -- "Calibration #1", "run #2", "cycle #3" -- passes the
    # lookbehind, and #1..#999 are all closed issues in roo-extensions. On
    # 2026-08-24 that silently swallowed po-2025's dispatch "Calibration #1"
    # (skipped + lastAck advanced, never retried). Both live repos number their
    # issues in the thousands (roo-extensions ~#3261, jsboige-mcp-servers ~#1037),
    # so a genuine reference always has 4+ digits. Ordinals never do.
    #
    # The two error directions are not symmetric, which is what sets the bias:
    #   false positive -> the WAKE is skipped AND lastAck advances (see caller),
    #                     so it is never retried. The instruction is destroyed.
    #   false negative -> an agent wakes on a stale target, reads the issue, and
    #                     says so. Cheap and self-correcting.
    # So this pattern deliberately under-matches: "PR#3083" is not treated as a
    # reference either. Only a # at a word boundary counts, and only 4+ digits.
    $issueMatches = [regex]::Matches($content, '(?<![A-Za-z0-9_])#(\d{4,})')
    $checked = 0
    foreach ($m in $issueMatches) {
        if ($checked -ge 5) { break }
        $issueNum = $m.Groups[1].Value
        try {
            $result = & gh issue view $issueNum --repo $repo --json state 2>$null
            if ($LASTEXITCODE -eq 0 -and $result) {
                $obj = $result | ConvertFrom-Json
                if ($obj.state -eq 'CLOSED') {
                    $closed += "#$issueNum"
                }
            }
        } catch {
            # gh not available or network issue — don't block
        }
        $checked++
    }
    return $closed
}

# ========== COOLDOWN CHECK ==========

function Test-CooldownOk($ws) {
    $lastSpawn = Get-LastSpawn $ws
    if ([string]::IsNullOrEmpty($lastSpawn)) { return $true }
    try {
        $last = [DateTime]::Parse($lastSpawn).ToUniversalTime()
        $elapsed = ((Get-Date).ToUniversalTime() - $last).TotalMinutes
        if ($elapsed -lt $CooldownMinutes) {
            Write-Log "INFO" "[$ws] Cooldown active: ${elapsed:N1}/${CooldownMinutes}min since last spawn."
            return $false
        }
        return $true
    } catch {
        return $true
    }
}

# ========== PROCESS WORKSPACE ==========

function Invoke-ProcessWorkspace($ws) {
    Write-Log "INFO" "[$ws] Processing (debounce expired)..."

    $lastAck = Get-LastAck $ws
    $messages = Read-DashboardMessages $ws
    if ($messages.Count -eq 0) {
        Write-Log "INFO" "[$ws] No messages found."
        return
    }

    # Filter: newer than lastAck + actionable tag
    $actionable = @()
    foreach ($msg in $messages) {
        # Timestamp filter
        if (-not [string]::IsNullOrEmpty($lastAck)) {
            try {
                $msgTs = [DateTime]::Parse($msg.timestamp).ToUniversalTime()
                $ackTs = [DateTime]::Parse($lastAck).ToUniversalTime()
                if ($msgTs -le $ackTs) { continue }
            } catch { }
        }

        # Tag filter
        if (Test-ActionableContent $msg.content) {
            $actionable += $msg
        }
    }

    # #2117: Filter messages targeting a specific machine.
    $localMachine = if ($env:ROOSYNC_MACHINE_ID) {
        $env:ROOSYNC_MACHINE_ID.ToLowerInvariant()
    } elseif ($env:COMPUTERNAME) {
        $env:COMPUTERNAME.ToLowerInvariant()
    } else {
        $null
    }
    if ($localMachine) {
        $filtered = @()
        foreach ($msg in $actionable) {
            # #2244: Bot wake routing — [WAKE-HERMES]/[WAKE-NANOCLAW] target specific machines.
            $botTarget = Get-WakeBotTarget $msg.content
            if ($null -ne $botTarget) {
                if ($botTarget.machine -ne $localMachine) {
                    Write-Log "INFO" "[$ws] Skipping bot WAKE targeting '$($botTarget.machine):$($botTarget.workspace)' (local=$localMachine)."
                    continue
                }
                # Bot target matches local machine — accept regardless of workspace.
                $filtered += $msg
                continue
            }
            # Standard [WAKE-CLAUDE] routing.
            $target = Get-WakeTargetMachine $msg.content
            if ($null -ne $target -and $target -ne $localMachine) {
                Write-Log "INFO" "[$ws] Skipping WAKE targeting '$target' (local=$localMachine)."
                continue
            }
            # #2240: Workspace-targeted filtering.
            $targetWs = Get-WakeTargetWorkspace $msg.content
            if ($null -ne $targetWs -and $targetWs -ne $ws) {
                Write-Log "INFO" "[$ws] Skipping WAKE targeting workspace '$targetWs' (local=$ws)."
                continue
            }
            $filtered += $msg
        }
        $actionable = $filtered
    }

    if ($actionable.Count -eq 0) {
        Write-Log "INFO" "[$ws] No actionable messages since lastAck."
        # Still advance lastAck to prevent re-processing on next event
        $latestTs = ($messages | Sort-Object timestamp | Select-Object -Last 1).timestamp
        Set-LastAck $ws $latestTs
        return
    }

    Write-Log "INFO" "[$ws] Found $($actionable.Count) actionable message(s)."
    foreach ($msg in $actionable) {
        $preview = $msg.content.Substring(0, [Math]::Min(100, $msg.content.Length)).Replace("`n", " ")
        Write-Log "INFO" "[$ws]   [$($msg.timestamp)] $($msg.author.machineId): $preview..."
    }

    $latestTs = ($actionable | Sort-Object timestamp | Select-Object -Last 1).timestamp

    # R11 sanity check: filter out WAKEs whose TARGET is a closed GitHub issue.
    # Prevents waking agents for stale targets (incident: po-2023 woken 3x on #1496 CLOSED).
    # #2431 fix: scope the check to the WAKE-instruction line(s) only (Get-WakeInstructionLines),
    # NOT the whole body — context refs to merged PRs were rejecting every legitimate WAKE.
    if (-not [string]::IsNullOrEmpty($GitHubRepo)) {
        $filtered = @()
        foreach ($msg in $actionable) {
            $closedRefs = Test-ReferencedClosedIssues (Get-WakeInstructionLines $msg.content) $GitHubRepo
            if ($closedRefs.Count -gt 0) {
                $preview = $msg.content.Substring(0, [Math]::Min(80, $msg.content.Length)).Replace("`n", " ")
                Write-Log "WARN" "[$ws] Skipping message from $($msg.author.machineId): references CLOSED issue(s) $($closedRefs -join ', '). Preview: $preview..."
            } else {
                $filtered += $msg
            }
        }
        if ($filtered.Count -eq 0 -and $actionable.Count -gt 0) {
            Write-Log "INFO" "[$ws] All actionable messages reference closed issues. Advancing lastAck to $latestTs."
            Set-LastAck $ws $latestTs
            return
        }
        $actionable = $filtered
    }

    # #3277 fix 4 : consommer (sans re-fire) les [WAKE-VIBE] épuisés AVANT le check de
    # cooldown — l'épuisement ne doit pas dépendre d'une fenêtre de 5 min. Un message
    # vibe dont les tentatives >= $VibeMaxAttempts est skippé + ack : la perte est
    # EXPLICITE (WARN), un humain peut re-dispatcher manuellement, la machine ne brûle
    # plus de crédits en boucle. Les WAKE-CLAUDE ne passent pas par ce filtre
    # (retry-gratuit : réessayer spawn-claude ne coûte rien).
    $vibeKept = @()
    $vibeExhausted = 0
    foreach ($msg in $actionable) {
        if ($msg.content -match '\[WAKE-VIBE\]') {
            $attempts = Get-VibeAttemptCount $msg.timestamp
            if ($attempts -ge $VibeMaxAttempts) {
                Write-Log "WARN" "[$ws] [WAKE-VIBE] exhausted (attempts=$attempts >= max=$VibeMaxAttempts, ts=$($msg.timestamp)) — consuming without re-fire (paid lane, #3277)."
                $vibeExhausted++
                continue
            }
        }
        $vibeKept += $msg
    }
    if ($vibeKept.Count -eq 0 -and $actionable.Count -gt 0) {
        Write-Log "INFO" "[$ws] All actionable messages exhausted (vibe attempts). Advancing lastAck to $latestTs."
        Set-LastAck $ws $latestTs
        return
    }
    $actionable = $vibeKept

    # Resolve workspace path so claude -p starts in the correct CWD.
    # If unresolvable, skip spawn AND keep lastAck unchanged so the message gets
    # a fresh chance after the operator adds the mapping.
    $wsPath = Resolve-WorkspacePath $ws
    if ([string]::IsNullOrEmpty($wsPath)) {
        Write-Log "WARN" "[$ws] No on-disk workspace path resolved (file/env/self/auto-detect all failed). Skipping spawn — add an entry to $WorkspacePathsFile."
        return
    }

    # Cooldown check
    if (-not (Test-CooldownOk $ws)) { return }

    # #2004 Phase 2: Push the triggering message into spawn-claude instead of
    # asking the spawned agent to re-read the dashboard. We pick the OLDEST
    # actionable message (FIFO) — additional messages get processed at the next
    # trigger after lastAck advances.
    $triggerMsg = $actionable | Sort-Object timestamp | Select-Object -First 1
    $payloadObj = [pscustomobject]@{
        timestamp = $triggerMsg.timestamp
        author    = $triggerMsg.author
        content   = $triggerMsg.content
    }
    $payloadJson = $payloadObj | ConvertTo-Json -Depth 4 -Compress

    # #3202: [WAKE-VIBE] spawns the Vibe worker, not spawn-claude.ps1.
    # Detect early so DryRun logs the right target too.
    $isVibeWake = ($triggerMsg.content -match '\[WAKE-VIBE\]')

    if ($DryRun) {
        $payloadSize = $payloadJson.Length
        $dryTarget = if ($isVibeWake) { "start-vibe-worker.ps1 -ConfigPath <coursia.json>" } else { "$SpawnScript -Workspace $ws -WorkspacePath $wsPath" }
        Write-Log "DRYRUN" "[$ws] Would spawn: $dryTarget -MessagePayloadFile <${payloadSize}B JSON>"
        Set-LastAck $ws $latestTs
        return
    }

    # Persist payload to a temp file (avoid Windows command-line length limits
    # and quoting hell for multi-line markdown content).
    $payloadFile = Join-Path $env:TEMP "wake-claude-payload-$ws-$([guid]::NewGuid().ToString('N').Substring(0,8)).json"
    [System.IO.File]::WriteAllText($payloadFile, $payloadJson, [System.Text.UTF8Encoding]::new($false))

    if ($isVibeWake) {
        $effectiveSpawnScript = $VibeWorkerScript
        $vibeProfile = Join-Path $RepoRoot "scripts/scheduling/vibe-profiles/coursia.json"
        Write-Log "INFO" "[$ws] Invoking start-vibe-worker.ps1 (profile=$vibeProfile, payload=$payloadFile)..."
        $spawnArgs = @(
            "-ConfigPath", $vibeProfile,
            "-MessagePayloadFile", $payloadFile
        )
    } else {
        $effectiveSpawnScript = $SpawnScript
        Write-Log "INFO" "[$ws] Invoking spawn-claude.ps1 (cwd=$wsPath, payload=$payloadFile)..."
        $spawnArgs = @(
            "-Workspace", $ws,
            "-McpConfig", $McpConfig,
            "-WorkspacePath", $wsPath,
            "-MessagePayloadFile", $payloadFile
        )
    }

    # Real spawn — existence check on the effective script.
    # Remove the temp payload on this error path: it was written above, and returning
    # without spawning would otherwise leave it orphaned in %TEMP% (review #3203).
    if (-not (Test-Path $effectiveSpawnScript)) {
        Write-Log "ERROR" "[$ws] Spawn script not found: $effectiveSpawnScript"
        Remove-Item $payloadFile -Force -ErrorAction SilentlyContinue
        return
    }
    # Per-WAKE model selection (user mandate 2026-06-11): a `model=X` hint on the WAKE line
    # overrides spawn-claude's capable default (Sonnet/GLM) — e.g. `model=haiku` for trivial
    # tasks. No hint → spawn-claude picks its own default.
    # #3202: only the claude branch takes -Model. Get-WakeModelHint matches `model=X` on ANY
    # wake line, so an operator writing `[WAKE-VIBE] … model=haiku` (the routing doc presents
    # the suffix as generic) would otherwise pass -Model to the vibe worker and lose the wake
    # on a parameter-binding error.
    if (-not $isVibeWake) {
        $modelHint = Get-WakeModelHint $triggerMsg.content
        if (-not [string]::IsNullOrEmpty($modelHint)) {
            $spawnArgs += @("-Model", $modelHint)
            Write-Log "INFO" "[$ws] WAKE model hint applied: -Model $modelHint"
        }
    }

    # Fire-time cooldown arm: write lastrun BEFORE spawn so failed/in-flight
    # spawns still respect CooldownMinutes.  Without this, a non-zero exit leaves
    # both lastAck (message stays actionable) and lastrun (cooldown never starts)
    # untouched → the next loop iteration re-fires the same message indefinitely.
    Set-LastSpawn $ws

    # #3277 fix 4 : la tentative est comptée AVANT le spawn — un crash pendant le spawn
    # doit compter (sinon crash-loop = re-fire payé illimité). Rollback si SKIP.
    if ($isVibeWake) {
        Add-VibeAttempt $triggerMsg.timestamp
        Write-Log "INFO" "[$ws] [WAKE-VIBE] attempt recorded (ts=$($triggerMsg.timestamp))"
    }

    try {
        & pwsh -File $effectiveSpawnScript @spawnArgs
        $exitCode = $LASTEXITCODE
    } catch {
        Write-Log "ERROR" "[$ws] Spawn failed: $_"
        return
    }

    # #3277 fix 3 : exit 75 = SKIP du worker (un worker vivant détient le lock). Le
    # dispatch n'est PAS consommé (pas d'ack) ET la tentative est retirée — le travail
    # est en cours ailleurs, le re-fire après cooldown livrera le résultat manquant.
    if ($exitCode -eq 75) {
        if ($isVibeWake) { Remove-VibeAttempt $triggerMsg.timestamp }
        Write-Log "INFO" "[$ws] Worker SKIPped (exit 75 — lock held by a live worker). lastAck NOT advanced, attempt rolled back."
        return
    }

    if ($exitCode -eq 0) {
        Set-LastAck $ws $latestTs
        Write-Log "INFO" "[$ws] Spawn completed. lastAck advanced to $latestTs."
    } else {
        Write-Log "WARN" "[$ws] Spawn exited with code $exitCode. lastAck NOT advanced."
    }
}

# ========== FILESYSTEMWATCHER SETUP ==========

if ([string]::IsNullOrEmpty($SharedPath) -or -not (Test-Path $SharedPath)) {
    Write-Log "ERROR" "SharedPath not set or missing: $SharedPath. Set ROOSYNC_SHARED_PATH."
    exit 1
}

$dashboardDir = Join-Path $SharedPath "dashboards"
if (-not (Test-Path $dashboardDir)) {
    Write-Log "ERROR" "Dashboards directory not found: $dashboardDir"
    exit 1
}

$wsList = Resolve-Workspaces
if ($wsList.Count -eq 0) {
    Write-Log "ERROR" "No workspaces to watch. Set -Workspaces or DASHBOARD_WATCHER_WORKSPACES."
    exit 1
}

Write-Log "INFO" "Dashboard Listener starting (#2004)"
Write-Log "INFO" "Watch: $dashboardDir | Workspaces: $($wsList -join ', ') | Tags: [$AllowedTags]"
Write-Log "INFO" "Debounce: ${DebounceSeconds}s | Cooldown: ${CooldownMinutes}min | DryRun: $DryRun"
Write-Log "INFO" "WorkspacePathsFile: $WorkspacePathsFile (exists=$(Test-Path $WorkspacePathsFile))"

# Pre-resolve all workspace paths to surface mapping issues at startup
foreach ($ws in $wsList) {
    $p = Resolve-WorkspacePath $ws
    if ([string]::IsNullOrEmpty($p)) {
        Write-Log "WARN" "[$ws] No path resolved at startup — spawns will be skipped until an entry is added to $WorkspacePathsFile."
    } else {
        Write-Log "INFO" "[$ws] resolved to $p"
    }
}

# Synchronized hashtable for pending workspace changes
$pending = [hashtable]::Synchronized(@{})

# Create FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $dashboardDir
$watcher.Filter = "workspace-*.md"
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
$watcher.EnableRaisingEvents = $true

# Event handler: record workspace + timestamp
$action = {
    $fileName = $Event.SourceEventArgs.Name
    if ($fileName -match '^workspace-(.+)\.md$') {
        $ws = $Matches[1]
        $pending[$ws] = [DateTime]::UtcNow
    }
}

Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action | Out-Null

# ========== FALLBACK POLLING STATE ==========

# FileSystemWatcher doesn't fire on GDrive virtual filesystem.
# Fallback: check LastWriteTime of each workspace file every $PollIntervalSeconds.
$PollIntervalSeconds = 20
$lastPollTime = [DateTime]::MinValue
# #2431 follow-up: decouple the GDrive liveness heartbeat from the 20s poll cadence.
# Polling must stay snappy (20s) for [WAKE-CLAUDE] responsiveness, but a wake-listener is
# NOT a real-time service — fleet coordination runs on 2h+ crons, so minute-by-minute
# proof-of-life is pointless and writing the shared heartbeat to GDrive that often = churn.
# A 5min ping is ample: the coordinator only flags a listener dead after ~2h of silence (the span
# of most fleet crons; -StaleSeconds 7200 in diagnose-wake-listener.ps1), and a genuinely dead
# wrapper self-heals within 15min via the schtask repeat trigger regardless.
$HeartbeatIntervalSeconds = if ($env:DASHBOARD_HEARTBEAT_INTERVAL_SECONDS) { [int]$env:DASHBOARD_HEARTBEAT_INTERVAL_SECONDS } else { 300 }
$lastHeartbeatTime = [DateTime]::MinValue
$lastWriteCache = @{}
foreach ($ws in $wsList) {
    $f = Join-Path $dashboardDir "workspace-$ws.md"
    if (Test-Path $f) {
        $lastWriteCache[$ws] = (Get-Item $f).LastWriteTimeUtc
    }
}

# ========== LIVENESS HEARTBEAT (#2431) ==========
# Truthful liveness: written periodically from INSIDE the main loop, not just
# once at start/exit by the wrapper. The wrapper-level heartbeat went stale within
# ~1 min even while the listener was healthy, making a live listener look dead.
#   - Local file  → wrapper / diagnostics confirm this listener is alive.
#   - Shared file → the coordinator (ai-01) reads every machine's listener across
#                   GDrive and flags stale ones (#2431 observability criterion).
$HeartbeatMachineId = if ($env:ROOSYNC_MACHINE_ID) {
    $env:ROOSYNC_MACHINE_ID.ToLowerInvariant()
} elseif ($env:COMPUTERNAME) {
    $env:COMPUTERNAME.ToLowerInvariant()
} else {
    "unknown-machine"
}
$LocalHeartbeatFile = Join-Path $LockDir "dashboard-listener.heartbeat"
$SharedHeartbeatDir = Join-Path $SharedPath "listener-heartbeats"
$SharedHeartbeatFile = Join-Path $SharedHeartbeatDir "$HeartbeatMachineId.heartbeat"

function Write-ListenerHeartbeat {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    # Local — best effort, must never break the loop.
    try {
        [System.IO.File]::WriteAllText($LocalHeartbeatFile, $ts, [System.Text.UTF8Encoding]::new($false))
    } catch {
        Write-Log "WARN" "Failed to write local heartbeat: $_"
    }
    # Shared (GDrive) — best effort; GDrive may be briefly unavailable.
    try {
        if (-not (Test-Path $SharedHeartbeatDir)) {
            New-Item -ItemType Directory -Path $SharedHeartbeatDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($SharedHeartbeatFile, $ts, [System.Text.UTF8Encoding]::new($false))
    } catch {
        Write-Log "WARN" "Failed to write shared heartbeat ($SharedHeartbeatFile): $_"
    }
}

Write-Log "INFO" "Heartbeat: local=$LocalHeartbeatFile | shared=$SharedHeartbeatFile"

# ========== MAIN LOOP ==========

$running = $true

try {
    # Initial sweep on startup
    Write-Log "INFO" "Running initial sweep..."
    Write-ListenerHeartbeat
    foreach ($ws in $wsList) {
        $pending[$ws] = [DateTime]::UtcNow.AddSeconds(-$DebounceSeconds - 1)
    }

    while ($running) {
        $now = [DateTime]::UtcNow
        $toProcess = @()

        # Find workspaces whose debounce has expired
        foreach ($ws in @($pending.Keys)) {
            # Only process workspaces we care about
            if ($wsList -notcontains $ws) {
                $pending.Remove($ws)
                continue
            }
            $changedAt = $pending[$ws]
            if (($now - $changedAt).TotalSeconds -ge $DebounceSeconds) {
                $toProcess += $ws
            }
        }

        # Process expired workspaces
        foreach ($ws in $toProcess) {
            $pending.Remove($ws)
            try {
                Invoke-ProcessWorkspace $ws
            } catch {
                Write-Log "ERROR" "[$ws] Unhandled error: $_"
            }
        }

        if ($Once) {
            Write-Log "INFO" "-Once mode: exiting after processing pending."
            break
        }

        # #2431 follow-up: refresh liveness heartbeat on its own (slower) cadence,
        # not on every 20s poll — cuts GDrive heartbeat traffic ~3x.
        if (($now - $lastHeartbeatTime).TotalSeconds -ge $HeartbeatIntervalSeconds) {
            $lastHeartbeatTime = $now
            Write-ListenerHeartbeat
        }

        # Fallback polling: check LastWriteTime every $PollIntervalSeconds
        if (($now - $lastPollTime).TotalSeconds -ge $PollIntervalSeconds) {
            $lastPollTime = $now
            foreach ($ws in $wsList) {
                $f = Join-Path $dashboardDir "workspace-$ws.md"
                if (Test-Path $f) {
                    $currentLWT = (Get-Item $f).LastWriteTimeUtc
                    $cachedLWT = if ($lastWriteCache.ContainsKey($ws)) { $lastWriteCache[$ws] } else { [DateTime]::MinValue }
                    if ($currentLWT -ne $cachedLWT) {
                        # File was modified — add to pending if not already
                        if (-not $pending.ContainsKey($ws)) {
                            Write-Log "INFO" "[$ws] File change detected via polling (LWT: $currentLWT)"
                        }
                        $pending[$ws] = $now
                        $lastWriteCache[$ws] = $currentLWT
                    }
                }
            }
        }

        Start-Sleep -Seconds 1
    }
} finally {
    Write-Log "INFO" "Dashboard Listener shutting down."
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Get-EventSubscriber | Where-Object { $_.SourceObject -eq $watcher } | Unregister-Event -ErrorAction SilentlyContinue
    Get-Job | Where-Object { $_.Name -like "*FileSystemWatcher*" } | Remove-Job -Force -ErrorAction SilentlyContinue
    Release-SingleInstance $script:SingleInstance
}

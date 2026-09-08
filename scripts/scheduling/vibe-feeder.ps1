<#
.SYNOPSIS
    Dispatche un [WAKE-VIBE] vers workspace-CoursIA (lane Mistral Vibe po-2025) — drainer deterministe durable.

.DESCRIPTION
    Lance par la schtask durable Vibe-Feeder (PT1H/P365D, #3202). AUCUN LLM interne :
    le grain vient d'une file de travail (feeder-queue.json) alimentee par les coordinateurs.
    PURE DISPATCH : ne modifie aucun depot, ne pousse rien, n'ecrit que le dashboard CoursIA.

    Le post se fait via le serveur roo-state-manager en stdio (pattern Publish-HealthNote,
    #3513 — spawn de mcp-wrapper.cjs, stdin ouvert jusqu'a la reponse tools/call id:3,
    deadline 150 s). PAS de claude -p : le mode headless ne charge pas le MCP et coute
    ~0.59 $/tick (mesure 08/09) pour un raisonnement que ce drainer fait en PowerShell.

    Garde run-in-flight : si un run Vibe s'est termine (PROMPT_OK|PROMPT_TIMEOUT|
    HarnessCommand exited) ou a demarre dans les 30 dernieres minutes, le drainer NOOP
    (conservateur — jamais de double-burn ; peut NOOP a tort, jamais bruler deux fois).

.PARAMETER DryRun
    Prepare le grain (worktree) + construit le payload et l'AFFICHE, sans poster.
    Permet de verifier le mecanisme sans declencher un run Mistral payant.

.PARAMETER QueuePath
    Chemin de la file de travail. Defaut : <repo>\outputs\vibe\feeder-queue.json

.PARAMETER TimeoutSec
    Deadline du post stdio (defaut 150).
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$QueuePath = '',
    [int]$TimeoutSec = 150
)
$ErrorActionPreference = 'Continue'   # Continue : git ecrit du progres sur stderr (fin de pipe), Stop le transformerait en throw
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
if (-not $QueuePath) { $QueuePath = Join-Path $repoRoot 'outputs\vibe\feeder-queue.json' }
$runtimeDir = 'D:\dev\CoursIA-vibe-runtime'
$logDir = Join-Path $repoRoot 'outputs\scheduling\logs'
$logFile = Join-Path $logDir ("vibe-feeder-{0}.log" -f (Get-Date -Format yyyyMMdd))
$RsmServerDir = Join-Path $repoRoot 'mcps\internal\servers\roo-state-manager'
$wrapperPath = Join-Path $RsmServerDir 'mcp-wrapper.cjs'

# ---------- logging ----------
function Write-FeederLog {
    param([string]$Level, [string]$Text)
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -Path $logFile -Value "$stamp [$Level] $Text" -Encoding utf8
    Write-Host "$stamp [$Level] $Text"
}

# ---------- run-in-flight guard (conservative) ----------
function Test-RunInFlight {
    $cut = (Get-Date).ToUniversalTime().AddMinutes(-30)
    $recent = $false
    $sources = @(
        (Get-ChildItem -Path $logDir -Filter 'listener-*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1),
        (Get-ChildItem -Path $logDir -Filter 'vibe-worker-*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    ) | Where-Object { $_ }
    foreach ($src in $sources) {
        $lines = Get-Content -Path $src.FullName -Tail 30 -ErrorAction SilentlyContinue
        foreach ($ln in $lines) {
            if ($ln -match 'PROMPT_OK|PROMPT_TIMEOUT|HarnessCommand exited|SESSION_NEW_FAILED|pickup|Iteration') {
                # Recence = horodatage de la LIGNE ([ISO Z]), pas le mtime du fichier :
                # le heartbeat de chaque tick horaire rafraichit le mtime d'un fichier
                # qui contient des marqueurs de run historiques -> faux "en vol" perpetuel
                # a <30 min de chaque tick (mesure 08/09 : tick SKIP 00:40Z a bloque le dispatch 00:57Z).
                if ($ln -match '^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\]') {
                    try {
                        $ts = [datetime]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture, 'RoundtripKind')
                        if ($ts.ToUniversalTime() -gt $cut) { $recent = $true }
                    } catch { }
                }
            }
        }
    }
    return $recent
}

# ---------- queue load ----------
function Read-Queue {
    if (-not (Test-Path $QueuePath)) {
        Write-FeederLog -Level 'WARN' -Text "queue absente: $QueuePath"
        return $null
    }
    try {
        $q = Get-Content -Path $QueuePath -Raw -Encoding utf8 | ConvertFrom-Json
        return $q.grains
    } catch {
        Write-FeederLog -Level 'ERROR' -Text "queue illisible: $($_.Exception.Message)"
        return $null
    }
}

# ---------- worktree prep (git -C runtime, jamais reset) ----------
# Retourne $true si le worktree est pret (cree ou deja present), false sinon.
function Prepare-Worktree {
    param([object]$Grain)
    $wt = $Grain.worktree
    $branch = $Grain.branch
    $base = $Grain.baseSha
    if (-not (Test-Path $runtimeDir)) { Write-FeederLog -Level 'ERROR' -Text "runtime absent: $runtimeDir"; return $false }
    # `worktree list` ecrit sur stdout ; pas de 2>&1 (fini de pipe stderr = throw sous Stop)
    $exists = (git -C $runtimeDir worktree list) 2>$null | Select-String -Pattern ([regex]::Escape($wt))
    if ($exists) { Write-FeederLog -Level 'INFO' -Text "worktree deja present: $wt"; return $true }
    $parent = Split-Path $wt -Parent
    if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    git -C $runtimeDir worktree add $wt -b $branch $base 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-FeederLog -Level 'INFO' -Text "worktree cree: $wt -> $branch @ $base"
        return $true
    }
    Write-FeederLog -Level 'ERROR' -Text "worktree add echoue (exit $LASTEXITCODE)"
    return $false
}

# ---------- post via stdio roo-state-manager (pattern Publish-HealthNote) ----------
function Invoke-RsmAppend {
    param([hashtable]$AppendOptions, [int]$TimeoutSec = 150)
    if (-not (Test-Path $wrapperPath)) {
        Write-FeederLog -Level 'ERROR' -Text "wrapper absent: $wrapperPath"
        return $false
    }
    $appendReq = @{ jsonrpc = '2.0'; id = 3; method = 'tools/call'
        params = @{ name = 'roosync_dashboard'; arguments = $AppendOptions } } | ConvertTo-Json -Depth 6 -Compress

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'node'
    $psi.Arguments = "`"$wrapperPath`""
    $psi.WorkingDirectory = $repoRoot
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $false

    $proc = $null
    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"vibe-feeder","version":"1.0"}}}')
        $proc.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized"}')
        $proc.StandardInput.WriteLine($appendReq)
        $proc.StandardInput.Flush()
        # stdin reste OUVERT (sinon le wrapper tue le serveur avant la reponse append)

        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        $found = $false
        $readTask = $proc.StandardOutput.ReadLineAsync()
        while ((Get-Date) -lt $deadline) {
            if (-not $readTask.Wait(1000)) { continue }
            $line = $readTask.Result
            if ($null -eq $line) { break }
            if ($line -match '"id"\s*:\s*3') {
                # Succes = JSON-RPC "result" sans "error" ET sans MCP isError.
                # Un rejet de schema arrive en "error" JSON-RPC (code -32603), pas en isError.
                $found = $false
                $parsed = $null
                try { $parsed = $line | ConvertFrom-Json } catch { }
                if ($parsed -and -not $parsed.error -and $parsed.result) {
                    # 3 jambes : pas d'error JSON-RPC, pas d'isError MCP,
                    # ET le texte de la reponse porte "success": true
                    # (GDrive inaccessible rend success:false SANS isError — mesure 08/09).
                    $txt = ''
                    if ($parsed.result.content) { $txt = ($parsed.result.content | ForEach-Object { $_.text }) -join '' }
                    $found = (-not $parsed.result.isError) -and ($txt -match '"success"\s*:\s*true')
                }
                Write-FeederLog -Level 'INFO' -Text ("reponse append: " + $line.Substring(0, [Math]::Min(400, $line.Length)))
                break
            }
            $readTask = $proc.StandardOutput.ReadLineAsync()
        }
        return $found
    } catch {
        Write-FeederLog -Level 'ERROR' -Text "post stdio erreur: $($_.Exception.Message)"
        return $false
    } finally {
        if ($proc -and -not $proc.HasExited) { try { $proc.Kill() } catch { } }
        if ($proc) { $proc.Dispose() }
    }
}

# ---------- main ----------
Write-FeederLog -Level 'INFO' -Text "Vibe-Feeder tick (DryRun=$DryRun)"

if (Test-RunInFlight) {
    Write-FeederLog -Level 'INFO' -Text "NOOP: run Vibe en vol ou termine dans les 30 min"
    exit 0
}

$grains = Read-Queue
if (-not $grains -or $grains.Count -eq 0) {
    Write-FeederLog -Level 'INFO' -Text "NOOP: 0 grain dans la file (a alimenter par les coordinateurs)"
    exit 0
}

foreach ($g in $grains) {
    # base fraiche ? (le worktree ne doit pas partir d'un main perime)
    $originMain = (git -C $runtimeDir rev-parse origin/main) 2>$null
    if ($originMain -match '^[0-9a-f]{40}$' -and $originMain -ne $g.baseSha) {
        Write-FeederLog -Level 'INFO' -Text ("SKIP {0}: baseShA perime ({1} != main {2})" -f $g.id, $g.baseSha, $originMain)
        continue
    }
    if (-not (Prepare-Worktree -Grain $g)) {
        Write-FeederLog -Level 'INFO' -Text ("SKIP {0}: worktree non preparable (voir log)" -f $g.id)
        continue
    }
    $payload = $g.payload
    if ($DryRun) {
        Write-FeederLog -Level 'INFO' -Text ("[DRY-RUN] grain pret: {0} — payload {1} chars, worktree {2} (non poste)" -f $g.id, $payload.Length, $g.worktree)
        Write-Host "----- PAYLOAD -----"
        Write-Host $payload
        Write-Host "-------------------"
        exit 0
    }
    $noteId = "vibe-feeder-$env:COMPUTERNAME-$($g.id)-$(Get-Date -Format yyyyMMddHHmm)"
    # Le listener matche le token literal [WAKE-VIBE] en DEBUT DE LIGNE dans le corps
    # (detection stricte #2004) — le parametre `tags` du MCP n'est pas rendu dans l'intercom.
    $appendArgs = @{ action = 'append'; type = 'workspace'; workspace = 'CoursIA'; tags = @('WAKE-VIBE', 'vibe-feeder'); content = "[WAKE-VIBE] $payload"; messageId = $noteId }
    $posted = Invoke-RsmAppend -AppendOptions $appendArgs -TimeoutSec $TimeoutSec
    if ($posted) {
        Write-FeederLog -Level 'INFO' -Text "[WAKE-VIBE] poste: grain $($g.id) -> workspace-CoursIA"
        exit 0
    } else {
        Write-FeederLog -Level 'ERROR' -Text "post echoue grain $($g.id) — relire dashboard avant retry (write-first)"
        exit 1
    }
}

Write-FeederLog -Level 'INFO' -Text "NOOP: aucun grain passable (tous SKIP/stale)"
exit 0

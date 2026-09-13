<#
.SYNOPSIS
    Dispatche un [WAKE-VIBE] vers workspace-CoursIA (lane Mistral Vibe po-2025) — drainer deterministe durable.

.DESCRIPTION
    Lance par la schtask durable Vibe-Feeder (PT1H/P365D, #3202). AUCUN LLM interne :
    le grain vient d'une file de travail (feeder-queue.json) alimentee par les coordinateurs.
    PURE DISPATCH : ne modifie aucun depot, ne pousse rien ; ecrit le dashboard CoursIA
    et retire de la file le grain poste (consommation, review #3518 C1).

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
    $line = "$stamp [$Level] $Text"
    # Add-Content echoue de facon NON terminante quand un lecteur tient le log
    # sans partage (mesure 08/09 03:15Z : 3 lignes perdues sur un run manuel,
    # feu 02:54Z entierement muet) — EAP=Continue les avale et le tick devient
    # inobservable. Retry court puis fichier de repli : la ligne n'est JAMAIS
    # perdue, le diagnostic reste possible apres coup.
    $written = $false
    foreach ($attempt in 1..2) {
        try {
            Add-Content -Path $logFile -Value $line -Encoding utf8 -ErrorAction Stop
            $written = $true
            break
        } catch { Start-Sleep -Milliseconds 400 }
    }
    if (-not $written) {
        Add-Content -Path "$logFile.sidecar" -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    }
    Write-Host $line
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
        return $q
    } catch {
        Write-FeederLog -Level 'ERROR' -Text "queue illisible: $($_.Exception.Message)"
        return $null
    }
}

function Write-Queue {
    param([object]$Queue)
    [System.IO.File]::WriteAllText(
        $QueuePath,
        ($Queue | ConvertTo-Json -Depth 8),
        (New-Object System.Text.UTF8Encoding $false)
    )
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
    # La branche survit souvent au `worktree remove` (il ne la supprime pas, et -d
    # refuse apres squash-merge) : sans repli, `worktree add -b` echoue a CHAQUE
    # tick et le grain est SKIP indefiniment (review #3518 W2).
    $branchExists = (git -C $runtimeDir branch --list $branch) 2>$null
    if ($branchExists) {
        git -C $runtimeDir worktree add $wt $branch 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-FeederLog -Level 'INFO' -Text "worktree rattache (branche existante): $wt -> $branch"
            return $true
        }
    } else {
        git -C $runtimeDir worktree add $wt -b $branch $base 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-FeederLog -Level 'INFO' -Text "worktree cree: $wt -> $branch @ $base"
            return $true
        }
    }
    Write-FeederLog -Level 'ERROR' -Text "worktree add echoue (exit $LASTEXITCODE)"
    return $false
}

function Update-StaleGrainBase {
    param([object]$Grain, [string]$OriginMain)

    if ($Grain.baseSha -eq $OriginMain) { return $true }

    git -C $runtimeDir merge-base --is-ancestor $Grain.baseSha $OriginMain 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-FeederLog -Level 'WARN' -Text ("{0}: ancienne base non ancetre de main — recalage refuse" -f $Grain.id)
        return $false
    }

    # Grain en file SANS worktree : rien a preserver ni a reseter, la recale est
    # un simple update de la file. Sans cette branche, chaque merge sur main
    # perimait TOUS les grains jamais dispatches (SKIP x7 puis NOOP a chaque
    # tick — mesure 13/09 : 0 run pendant ~24 h, recurrence du defaut documente
    # le 11/09).
    if (-not (Test-Path $Grain.worktree)) {
        $Grain.baseSha = $OriginMain
        Write-Queue -Queue $q
        Write-FeederLog -Level 'INFO' -Text ("{0}: baseSha recalee (grain en file, sans worktree) vers {1}" -f $Grain.id, $OriginMain)
        return $true
    }

    $dirty = (git -C $Grain.worktree status --porcelain 2>$null)
    $rcDirty = $LASTEXITCODE
    # Eligibilite mesuree par rapport a MAIN, jamais a l'ancienne base : `baseSha..HEAD`
    # compte aussi les commits que MAIN a pris depuis, donc un worktree deja avance
    # sur main (cas du crash entre le `reset` et la persistance ci-dessous : reboot,
    # kill) y paraissait « avec commits » et restait refuse a chaque tick — le grain
    # bloque en SKIP jusqu'a intervention externe. `$OriginMain..HEAD` ne compte que
    # ce que le worktree porte EN PLUS de main : 0 => rien a preserver, le reset est
    # un no-op et la fenetre de crash se referme d'elle-meme au tick suivant.
    $ahead = (git -C $Grain.worktree rev-list --count "$OriginMain..HEAD" 2>$null)
    if ($dirty -or $rcDirty -ne 0 -or $LASTEXITCODE -ne 0 -or $ahead -ne '0') {
        Write-FeederLog -Level 'WARN' -Text ("{0}: worktree sale ou avec commits propres — recalage automatique refuse" -f $Grain.id)
        return $false
    }

    git -C $Grain.worktree reset --hard $OriginMain 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-FeederLog -Level 'WARN' -Text ("{0}: reset vers main echoue" -f $Grain.id)
        return $false
    }

    $Grain.baseSha = $OriginMain
    Write-Queue -Queue $q
    Write-FeederLog -Level 'INFO' -Text ("{0}: baseSha recalee dans le tick vers {1}" -f $Grain.id, $OriginMain)
    return $true
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

# ---------- verification par relecture (maillon 3, mesure 13/09) ----------
# Un append qui epuise son timeout a PU etre livre : WRITE-FIRST ecrit le
# message sur disque AVANT la condensation, et la condensation peut durer
# 132 s (mesure 13/09 09:31Z : append 146 s totales dont ecriture 7,5 s).
# La non-livraison n'est donc prouvee que par la RELECTURE — la meme
# medecine que la regle intercom impose aux agents. Sans elle, un dispatch
# livre etait enregistre ECHOUE (13/09 08:57:54Z timeout 151 s alors que le
# message etait sur le dashboard a 08:56:10Z) : repli local heurtant le lock
# du run parti de CE message (exit 75), puis grain garde en file et
# re-dispatche au tick suivant = run double paye sur le budget Vibe.
# Le marqueur est l'ID du message ($noteId : machine + grain + minute), PAS
# le contenu : un grain garde apres exit 75 est re-poste au tick suivant avec
# un contenu byte-identique — matcher sur le contenu confondrait le message
# du tick precedent avec celui-ci (faux positif = grain consomme sans run).
function Test-WakeDelivered {
    param([string]$Marker, [string]$Workspace = 'CoursIA', [int]$TimeoutSec = 60)
    if (-not $Marker -or -not (Test-Path $wrapperPath)) { return $false }
    $readReq = @{ jsonrpc = '2.0'; id = 7; method = 'tools/call'
        params = @{ name = 'roosync_dashboard'; arguments = @{
            action = 'read'; type = 'workspace'; workspace = $Workspace
            section = 'intercom'; intercomLimit = 12 } } } | ConvertTo-Json -Depth 6 -Compress

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
        $proc.StandardInput.WriteLine($readReq)
        $proc.StandardInput.Flush()

        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        $readTask = $proc.StandardOutput.ReadLineAsync()
        while ((Get-Date) -lt $deadline) {
            if (-not $readTask.Wait(1000)) { continue }
            $line = $readTask.Result
            if ($null -eq $line) { break }
            if ($line -match '"id"\s*:\s*7') {
                if ($line.Contains($Marker)) {
                    Write-FeederLog -Level 'INFO' -Text ("relecture intercom: marqueur retrouve (message livre)")
                    return $true
                }
                Write-FeederLog -Level 'INFO' -Text ("relecture intercom: marqueur ABSENT (reponse lue, message non livre)")
                return $false
            }
            $readTask = $proc.StandardOutput.ReadLineAsync()
        }
        # Read sans reponse dans le delai : store injoignable — indetermine,
        # rendu comme non-livre (le repli local reste le filet de securite).
        return $false
    } catch {
        Write-FeederLog -Level 'ERROR' -Text "relecture stdio erreur: $($_.Exception.Message)"
        return $false
    } finally {
        if ($proc -and -not $proc.HasExited) { try { $proc.Kill() } catch { } }
        if ($proc) { $proc.Dispose() }
    }
}

# ---------- re-mesure de la file (organe refresh-vibe-queue.py, #3609) ----------
# Appele quand la file est vide ou integralement SKIP : re-scan du corpus a
# l'origin/main courant (l'organe fait son propre fetch) + re-decoupe aux
# dimensions du contrat. C'est ce qui rend la lane intarissable : sans lui,
# chaque epuisement ou peremption de file attendait un re-seed manuel.
# Un appel max par tick (pas de boucle), echec non fatal : NOOP ordinaire.
function Invoke-QueueRefresh {
    $organ = Join-Path $repoRoot 'scripts\scheduling\refresh-vibe-queue.py'
    if (-not (Test-Path $organ)) {
        Write-FeederLog -Level 'ERROR' -Text ("organe de re-mesure absent: {0}" -f $organ)
        return $false
    }
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-FeederLog -Level 'ERROR' -Text "python introuvable — re-mesure impossible"
        return $false
    }
    Write-FeederLog -Level 'INFO' -Text "re-mesure de la file via refresh-vibe-queue.py (scan corpus ~60 s)"
    $out = & python $organ --queue $QueuePath 2>&1
    $rc = $LASTEXITCODE
    foreach ($ln in (@($out) | Select-Object -Last 10)) {
        if ($ln) { Write-FeederLog -Level 'INFO' -Text ("organ: {0}" -f $ln) }
    }
    if ($rc -ne 0) {
        Write-FeederLog -Level 'ERROR' -Text ("organ exit {0} — file non rafraichie" -f $rc)
        return $false
    }
    return $true
}

# ---------- main ----------
Write-FeederLog -Level 'INFO' -Text "Vibe-Feeder tick (DryRun=$DryRun)"

if (Test-RunInFlight) {
    Write-FeederLog -Level 'INFO' -Text "NOOP: run Vibe en vol ou termine dans les 30 min"
    exit 0
}

# Deux passes max : passe 1 = file telle quelle ; si elle est vide ou
# integralement SKIP, passe 2 = re-mesure par l'organe puis nouvelle tentative.
# DryRun ne declenche JAMAIS la re-mesure (elle reecrit la file).
for ($pass = 1; $pass -le 2; $pass++) {
    if ($pass -eq 2) {
        if ($DryRun) { break }
        if (-not (Invoke-QueueRefresh)) { break }
    }

    $q = Read-Queue
    $grains = $null
    if ($q) { $grains = @($q.grains) }
    if (-not $grains -or $grains.Count -eq 0) {
        if ($pass -eq 1 -and -not $DryRun) {
            Write-FeederLog -Level 'INFO' -Text "file vide — re-mesure par l'organe avant abandon"
            continue
        }
        break
    }

    # Sans fetch, la garde fraicheur compare au ref local tel que le dernier
    # processus l'a laisse : un merge distant passe inapercu jusqu'au prochain
    # fetch etranger, et le grain part sur base perime (review #3518 C2).
    git -C $runtimeDir fetch origin main 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-FeederLog -Level 'WARN' -Text "fetch origin/main echoue — garde fraicheur sur ref local possiblement perime"
    }

    foreach ($g in $grains) {
        # base fraiche ? (le worktree ne doit pas partir d'un main perime)
        $originMain = (git -C $runtimeDir rev-parse origin/main) 2>$null
        if ($originMain -match '^[0-9a-f]{40}$' -and $originMain -ne $g.baseSha) {
            if (-not (Update-StaleGrainBase -Grain $g -OriginMain $originMain)) {
                Write-FeederLog -Level 'INFO' -Text ("SKIP {0}: baseSha perime ({1} != main {2})" -f $g.id, $g.baseSha, $originMain)
                continue
            }
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
        $postStarted = Get-Date
        $posted = Invoke-RsmAppend -AppendOptions $appendArgs -TimeoutSec $TimeoutSec
        if ($posted) {
            Write-FeederLog -Level 'INFO' -Text "[WAKE-VIBE] poste: grain $($g.id) -> workspace-CoursIA"
            # Consommer le grain poste : sinon il reste en tete de file et le tick
            # suivant le re-poste (messageId horodate a la minute => la dedup du
            # dashboard ne dedup rien entre deux posts, review #3518 C1).
            $remaining = @($grains | Where-Object { $_.id -ne $g.id })
            $outObj = [ordered]@{ _comment = $q._comment; grains = $remaining }
            Write-Queue -Queue $outObj
            Write-FeederLog -Level 'INFO' -Text ("file mise a jour: {0} grain(s) restant(s)" -f $remaining.Count)
            exit 0
        } else {
            # Le declencheur de la lane passait ENTIEREMENT par le cloud : post
            # [WAKE-VIBE] sur le dashboard partage, puis pickup par le listener. Un
            # DriveFS qui decroche arretait donc la lane alors que la file, le grain
            # et le worker sont tous LOCAUX. Mesure 2026-09-12 : G: demonte, post en
            # timeout a 151 s pour TimeoutSec=150, 0 run pendant 13 h.
            # Discriminant (revu 13/09, maillon 3) : un post qui epuise son timeout
            # n'a recu aucune reponse, mais le message a PU etre livre (WRITE-FIRST
            # ecrit avant la condensation, qui peut durer 132 s) — d'ou la relecture
            # ci-dessous. Le repli local ne se declenche que si la relecture ne
            # trouve PAS le message. Un echec RAPIDE (rejet de schema, wrapper
            # absent) garde au contraire la doctrine write-first : ne pas spawner,
            # relire avant retry.
            $elapsed = ((Get-Date) - $postStarted).TotalSeconds
            $wrapperMissing = -not (Test-Path $wrapperPath)
            if ($elapsed -ge ($TimeoutSec - 5) -or $wrapperMissing) {
                $trigger = if ($wrapperMissing) { 'wrapper absent' } else { ("timeout {0:N0}s" -f $elapsed) }
                # Maillon 3 : le timeout n'est pas une preuve de non-livraison
                # (WRITE-FIRST + condensation longue, mesure 13/09). Relire
                # l'intercom AVANT de replier : si le message y figure, le
                # dispatch a abouti — le repli local ne ferait que se heurter
                # au lock du run parti de CE message (exit 75, 13/09 08:57:58Z),
                # et le grain garde en file serait re-dispatche au tick suivant.
                if (-not $wrapperMissing) {
                    if (Test-WakeDelivered -Marker $noteId -Workspace $appendArgs.workspace -TimeoutSec 60) {
                        Write-FeederLog -Level 'INFO' -Text ("post en fait LIVRE malgre {0} (relecture write-first) — grain {1} consomme, pas de repli" -f $trigger, $g.id)
                        $remaining = @($grains | Where-Object { $_.id -ne $g.id })
                        $outObj = [ordered]@{ _comment = $q._comment; grains = $remaining }
                        Write-Queue -Queue $outObj
                        Write-FeederLog -Level 'INFO' -Text ("file mise a jour (post livre malgre timeout): {0} grain(s) restant(s)" -f $remaining.Count)
                        exit 0
                    }
                }
                Write-FeederLog -Level 'WARN' -Text ("post [WAKE-VIBE] impossible ({0}) — relecture sans trace du message, repli sur spawn LOCAL du worker" -f $trigger)
                $payloadFile = Join-Path $env:TEMP ("vibe-feeder-payload-{0}.json" -f $g.id)
                $payloadObj = [pscustomobject]@{
                    timestamp = (Get-Date).ToUniversalTime().ToString('o')
                    author    = [pscustomobject]@{ machineId = $env:COMPUTERNAME }
                    content   = "[WAKE-VIBE] $payload"
                }
                [IO.File]::WriteAllText($payloadFile, ($payloadObj | ConvertTo-Json -Depth 4 -Compress), (New-Object Text.UTF8Encoding($false)))
                $vibeWorkerScript = Join-Path $repoRoot 'scripts\scheduling\start-vibe-worker.ps1'
                $vibeProfile = Join-Path $repoRoot 'scripts\scheduling\vibe-profiles\coursia.json'
                $psHost = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
                & $psHost -File $vibeWorkerScript -ConfigPath $vibeProfile -MessagePayloadFile $payloadFile
                $spawnExit = $LASTEXITCODE
                if ($spawnExit -eq 0) {
                    Write-FeederLog -Level 'INFO' -Text ("repli local OK (exit 0) — grain {0} consomme, pas de re-post" -f $g.id)
                    $remaining = @($grains | Where-Object { $_.id -ne $g.id })
                    $outObj = [ordered]@{ _comment = $q._comment; grains = $remaining }
                    Write-Queue -Queue $outObj
                    Write-FeederLog -Level 'INFO' -Text ("file mise a jour (repli local): {0} grain(s) restant(s)" -f $remaining.Count)
                    exit 0
                }
                # exit 75 = un worker vivant detient le lock : le payload n'a PAS ete
                # traite. Ne pas consommer le grain (ce serait le perdre) — le tick
                # suivant le reprendra.
                Write-FeederLog -Level 'ERROR' -Text ("repli local en echec (exit={0}) — grain {1} conserve en file pour le tick suivant" -f $spawnExit, $g.id)
                exit 1
            }
            Write-FeederLog -Level 'ERROR' -Text "post echoue grain $($g.id) — relire dashboard avant retry (write-first)"
            exit 1
        }
    }

    # Passe epuisee sans grain passable : la passe suivante (s'il y en a une)
    # re-mesure ; sortir de la boucle = NOOP definitif du tick.
}

Write-FeederLog -Level 'INFO' -Text "NOOP: aucun grain passable (file vide, tous SKIP, ou re-mesure sans grain)"
exit 0

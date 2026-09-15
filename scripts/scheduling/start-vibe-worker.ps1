<#
.SYNOPSIS
    Vibe worker: execute un tick Mistral Vibe (pas de cron dans son harnais — la cadence est portee par schtask).

.DESCRIPTION
    Worker dedie pour Mistral Vibe (#3202, decision utilisateur 21/08 : Vibe n'a pas de
    CronCreate, la schtask est la seule option de cadence, 1h au depart). Reutilise les
    conventions eprouvees de start-claude-worker.ps1 sans toucher ce script :
      - Lock-file anti-chevauchement (JSON pid/startedAt/machine)
      - Write-WorkerHeartbeat (pattern #3199 : worker-heartbeats/<machine>.heartbeat)
      - Logs dans outputs/scheduling/logs/
      - Sortie bruyante sur erreur (exit 1 + Write-Log ERROR)
    Pas d'escalade multi-modele en v1 (Vibe n'a pas la chaine Haiku->Sonnet->Opus).

    La commande harnais est passee via -HarnessCommand ; le profil CoursIA
    (vibe-profiles/coursia.json) documente l'invocation standard pour la serie vibe-coding.

.PARAMETER HarnessCommand
    Commande CLI Vibe a executer (ex: "mistral vibe run --prompt ..."). Requis sauf si -ConfigPath.

.PARAMETER Workspace
    Workspace cible (contexte logs/heartbeat). Defaut : nom du repertoire courant.

.PARAMETER ConfigPath
    Chemin optionnel vers un profil JSON (workspace, harnessCommand, intervalHours).
    Si fourni, -HarnessCommand et -Workspace sont ecrases par les valeurs du profil.

.PARAMETER MaxIterations
    Nombre max d'iterations par tick (defaut : 1). Reserve pour l'avenir.

.PARAMETER MessagePayloadFile
    Fichier JSON optionnel avec le message declencheur (passe par le dashboard-listener
    sur un [WAKE-VIBE]). Le contenu est injecte dans la variable d'environnement
    VIBE_WAKE_PAYLOAD pour que la commande harnais puisse le consommer.

.PARAMETER Model
    Accepte mais non utilise en v1 (Vibe n'a pas de chaine multi-modele). Present pour que
    l'invocation reste valide si un `model=X` traverse depuis une ligne WAKE : le listener
    garde deja le -Model a la branche claude, ce parametre est la defense en profondeur.

.PARAMETER DryRun
    Affiche l'invocation prevue sans executer.

.EXAMPLE
    pwsh -File scripts/scheduling/start-vibe-worker.ps1 -HarnessCommand "mistral vibe run" -Workspace CoursIA

.EXAMPLE
    pwsh -File scripts/scheduling/start-vibe-worker.ps1 -ConfigPath scripts/scheduling/vibe-profiles/coursia.json -DryRun

.NOTES
    Issue : #3202 (GO user 21/08)
    Issue : #3277 — lock atomique (CreateNew + FileShare.None), SKIP = exit 75
    (le listener n'avance pas lastAck sur 75 : un skip ne consomme pas le dispatch).
    Mutualisation : lock, heartbeat, logs sont candidats a une extraction commune future
    (voir table des gisements dans le body de l'issue #3202).
#>
[CmdletBinding()]
param(
    [string]$HarnessCommand = "",
    [string]$Workspace = "",
    [string]$ConfigPath = "",
    [int]$MaxIterations = 1,
    [string]$MessagePayloadFile = "",
    [string]$Model = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Split-Path (Split-Path $ScriptDir -Parent) -Parent)

# ========== LOGGING ==========

$LogDir = if (-not [string]::IsNullOrWhiteSpace($env:VIBE_WORKER_LOG_DIR)) {
    $env:VIBE_WORKER_LOG_DIR
} else {
    Join-Path $RepoRoot "outputs\scheduling\logs"
}
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir ("vibe-worker-{0}.log" -f (Get-Date -Format "yyyyMMdd"))

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    # UTC réel (#3277 fix 5) : l'heure locale collait au raisonnement cross-machine.
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$Level] $Message"
    try {
        Add-Content -Path $LogFile -Value $line -Encoding utf8NoBOM
    } catch { }
    $color = switch ($Level) { "ERROR" { "Red" }; "WARN" { "Yellow" }; default { "Gray" } }
    Write-Host $line -ForegroundColor $color
}

# ========== HEARTBEAT (pattern #3199) ==========
# Implémentation partagée : scripts/common/worker-heartbeat.ps1 (#3207, #3209).
# Declared before the early-exit guards so EVERY exit path can heartbeat, including
# operator errors (missing profile / missing command). Les appels passent
# -LogPrefix 'Heartbeat' pour préserver les logs greppables d'avant l'extraction.

. (Join-Path $ScriptDir '..\common\worker-heartbeat.ps1')

# ========== PROFILE LOADING ==========

if (-not [string]::IsNullOrWhiteSpace($Model)) {
    Write-Log "Model hint received ('$Model') — ignored in v1 (Vibe has no multi-model chain)"
}

$profileObj = $null
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "ConfigPath not found: $ConfigPath" "ERROR"
        Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
        exit 1
    }
    $profileObj = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($profileObj.harnessCommand) { $HarnessCommand = $profileObj.harnessCommand }
    if ($profileObj.workspace) { $Workspace = $profileObj.workspace }
    Write-Log "Profile loaded: workspace=$Workspace"
}

if ([string]::IsNullOrWhiteSpace($HarnessCommand)) {
    Write-Log "HarnessCommand is required (or -ConfigPath with harnessCommand)" "ERROR"
    Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
    exit 1
}
if ([string]::IsNullOrWhiteSpace($Workspace)) {
    $Workspace = Split-Path (Get-Location) -Leaf
}

# Workspace path resolution: profile wins, else workspace-paths.json, else CWD
$WorkspacePath = ""
if ($profileObj -and $profileObj.workspacePath) {
    $WorkspacePath = $profileObj.workspacePath
} else {
    $wsPathFile = Join-Path $RepoRoot ".claude/local/workspace-paths.json"
    if (Test-Path $wsPathFile) {
        try {
            $wsMap = Get-Content $wsPathFile -Raw | ConvertFrom-Json
            foreach ($prop in $wsMap.PSObject.Properties) {
                if ($prop.Name -ieq $Workspace) { $WorkspacePath = [string]$prop.Value; break }
            }
        } catch { }
    }
}
if (-not [string]::IsNullOrWhiteSpace($WorkspacePath) -and (Test-Path $WorkspacePath)) {
    Set-Location $WorkspacePath
    Write-Log "Working directory: $WorkspacePath"
} else {
    Write-Log "No workspace path resolved for '$Workspace' — running from $PWD" "WARN"
}

Write-Log "Vibe worker tick: workspace=$Workspace cmd='$HarnessCommand' maxIter=$MaxIterations dryRun=$DryRun"

if ($DryRun) {
    Write-Log "[DRY-RUN] Would execute: $HarnessCommand (workspace=$Workspace)" "INFO"
    exit 0
}

# ========== IDLE QUEUE PICKER (06/09, lane pérenne — opt-in via profil) ==========
# Un tick planifié sans WAKE en attente n'est plus forcément un no-op : si le
# profil définit une file ("queue": {repo, label, maxIdleRunsPerDay}), le tick
# pioche la plus ancienne issue ouverte portant le label et l'injecte comme
# payload WAKE (JSON {content}, contrat vibe-acp-driver.py l.149) — la lane
# s'alimente seule après un reboot, là où le feeder cron session-only meurt.
# Gardes : plafond de runs idle/jour (budget, défaut 4), anti-marteau (même
# issue re-piquée seulement après QueueRetrySameIssueHours), file vide ou non
# configurée => comportement SKIP historique (aucun coût). Le pick a lieu AVANT
# le lock : un run payant le prendra comme tout run.

$QueueStateDir = Join-Path $RepoRoot "outputs\scheduling\state"
$script:QueueRetrySameIssueHours = 6
$script:QueueClaimHours = 72

function Get-QueueState {
    # Fail-closed (arbitrage #3649 decision 1, 14/09) : « absent » et « illisible »
    # ne sont pas le meme etat. L'ancien `catch { }` rendait $null pour les deux, et
    # l'appelant lisait $null comme « premier run du jour » : plafond du jour ET
    # anti-marteau 6 h contournes en silence, puis Save-QueueState ecrasait le
    # fichier — compteur perdu sans aucune ligne de journal. Un etat illisible ou
    # de forme inattendue pose le flag $script:QueueStateUnreadable ; l'appelant
    # REFUSE alors le tirage (outcome 'infrastructure').
    param([string]$Path)
    $script:QueueStateUnreadable = $false
    if (Test-Path $Path) {
        $parsed = $null
        try { $parsed = Get-Content $Path -Raw | ConvertFrom-Json }
        catch {
            $script:QueueStateUnreadable = $true
            return $null
        }
        if ($null -ne $parsed -and
            $parsed.PSObject.Properties.Name -contains 'date' -and
            $parsed.PSObject.Properties.Name -contains 'idleRuns') {
            return $parsed
        }
        $script:QueueStateUnreadable = $true
    }
    return $null
}

function Save-QueueState {
    param([string]$Path, [object]$State)
    if (-not (Test-Path $QueueStateDir)) { New-Item -ItemType Directory -Path $QueueStateDir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, ($State | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))
}

function Get-QueueOpenPrs {
    # Anti-collision (15/09, mandat user) : les PRs ouvertes du depot, lues une
    # seule fois par tick. Le picker ne lisait QUE `gh issue list` par label :
    # une issue claimee/livree dont le label ne change pas restait piochable
    # (collision #16120 du 14/09 : claim 07:49Z, PR #16136 ouverte 09:18Z, run
    # duplique $2.02 a 18:05Z). Tout echec = throw : l'etat des collisions ne
    # se devine pas, l'appelant refuse (fail-closed).
    param([string]$Repo)
    $raw = & gh pr list -R $Repo --state open --limit 100 --json number,title,headRefName 2>$null
    # Vide explicite d'abord : `'' | ConvertFrom-Json` rend null SANS erreur
    # (mesure 15/09) — sans cette garde, un stdout vide deviendrait « aucune PR »
    # et le picker tirerait sans protection anti-collision.
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "gh pr list: sortie vide (repo $Repo)" }
    try { return ,@($raw | ConvertFrom-Json -ErrorAction Stop) }
    catch { throw "gh pr list: sortie non-JSON (repo $Repo)" }
}

function Test-QueueIssueClaimed {
    # Anti-collision, garde 2 : un [CLAIMED] recent en commentaire prime sur le
    # pick — la convention fleet vit dans les commentaires d'issue, pas dans les
    # labels (#3407). Fenetre QueueClaimHours : un claim plus vieux est presume
    # abandonne. Echec gh = throw (fail-closed, jamais fail-open).
    param([string]$Repo, [int]$Number)
    $raw = & gh issue view $Number -R $Repo --json comments 2>$null
    # Meme garde que Get-QueueOpenPrs : '' rend null sans erreur via le pipeline.
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "gh issue view #$($Number): sortie vide" }
    try { $data = $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "gh issue view #$($Number): sortie non-JSON" }
    $cutoff = (Get-Date).ToUniversalTime().AddHours(-1 * $script:QueueClaimHours)
    foreach ($c in @($data.comments)) {
        if (-not $c.createdAt) { continue }
        try { $at = [DateTime]$c.createdAt } catch { continue }
        if ($at -ge $cutoff -and "$($c.body)" -match '\[CLAIMED\]') { return $true }
    }
    return $false
}

function Invoke-IdleQueuePick {
    # Returns $true when a payload was injected into $env:VIBE_WAKE_PAYLOAD
    # (the caller then falls through to lock + execution).
    #
    # Le booleen ne suffit PAS a l'appelant : "rien a faire" et "dispatch refuse
    # sur panne d'infrastructure" se rendaient tous deux en `[SKIP] ... no-op
    # (exit 0)`, donc un `fetch` casse ou un `worktree add` en echec etaient
    # indiscernables d'un pool vide pour le scheduler — exactement le motif que
    # le garde NO-OP (#3296) existe pour rendre bruyant. La raison est publiee
    # ici ; l'appelant sort non-zero sur 'infrastructure' seulement.
    $script:IdlePickOutcome = 'noop'
    $script:IdlePickFailure = ''
    if (-not $profileObj -or -not $profileObj.queue -or
        -not $profileObj.queue.repo -or -not $profileObj.queue.label) {
        return $false
    }
    $queue = $profileObj.queue
    $maxPerDay = 4
    if ($queue.PSObject.Properties.Name -contains 'maxIdleRunsPerDay' -and
        [int]$queue.maxIdleRunsPerDay -gt 0) {
        $maxPerDay = [int]$queue.maxIdleRunsPerDay
    }

    $today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $statePath = Join-Path $QueueStateDir ("vibe-queue-{0}.json" -f ($Workspace -replace '[^a-zA-Z0-9_-]', '_'))
    $qState = Get-QueueState -Path $statePath
    if ($script:QueueStateUnreadable) {
        # Fail-closed (arbitrage #3649 decision 1) : sur etat illisible, le plafond
        # ne peut pas etre garanti — pas de tirage. Distinction journalisee :
        # absent = premier run du jour (tirage autorise) ; illisible = etat
        # corrompu, tirage refuse jusqu'a reparation. Le fichier n'est PAS
        # reecrit ici : la preuve du defaut doit survivre au tick.
        $script:IdlePickOutcome = 'infrastructure'
        $script:IdlePickFailure = "queue state illisible ou de forme inattendue ($statePath)"
        Write-Log ("[ERROR] idle-picker: queue state ILLISIBLE ({0}) - tirage REFUSE (fail-closed, arbitrage #3649). Absent = premier run du jour ; illisible = plafond/anti-marteau non garantis. Reparer ou archiver le fichier, le tick suivant recreera l'etat." -f $statePath) "ERROR"
        return $false
    }
    $idleRuns = 0
    if ($qState -and [string]$qState.date -eq $today) { $idleRuns = [int]$qState.idleRuns }
    if ($idleRuns -ge $maxPerDay) {
        Write-Log "[SKIP] idle-picker daily cap reached ($idleRuns/$maxPerDay) - scheduled tick is a no-op."
        return $false
    }

    try {
        $items = & gh issue list -R ([string]$queue.repo) --state open --label ([string]$queue.label) --limit 10 --json number,title,body,updatedAt 2>$null | ConvertFrom-Json
    } catch { $items = $null }
    if (-not $items -or @($items).Count -eq 0) {
        return $false
    }
    # Anti-marteau : ecarter l'issue deja piquee recemment, PAS le tick entier.
    # Le tri porte sur le pool ENTIER, donc l'issue ecartee est presque toujours
    # la plus ancienne : avec un `return $false` ici, une seule issue sous
    # anti-marteau rendait le picker muet 6 h durant alors que le reste du pool
    # etait libre. Mesure 14/09 : etat lastIssueNumber=16120, #16120 plus ancienne
    # du pool -> [SKIP] a 08:40 et a chaque tick suivant, #16119/#16121 inutilisees.
    # On filtre AVANT de choisir ; $false ne subsiste que si le pool entier est
    # sous anti-marteau (le picker ne sait pas closer, donc re-piquer la meme
    # issue avant la review n'a pas de sens).
    $hammered = -1
    if ($qState -and $qState.lastRunAt -and $qState.lastIssueNumber) {
        try {
            $sinceH = ((Get-Date).ToUniversalTime() - ([DateTime]$qState.lastRunAt).ToUniversalTime()).TotalHours
            if ($sinceH -lt $script:QueueRetrySameIssueHours) { $hammered = [int]$qState.lastIssueNumber }
        } catch { }
    }
    $candidates = @($items | Where-Object { [int]$_.number -ne $hammered } |
                    Sort-Object {[DateTime]$_.updatedAt})
    if ($candidates.Count -eq 0) {
        Write-Log ("[SKIP] idle-picker: tout le pool est sous anti-marteau (<{0}h) - tick no-op." -f $script:QueueRetrySameIssueHours)
        return $false
    }

    # ===== Anti-collision (15/09, mandat user) =====
    # Garde 1 : PR ouverte referencant l'issue — titre `#N` OU head de branche
    # portant le numero (#16136 head `feature/16120-sw14-exercises` livrait
    # #16120 SANS le numero dans le titre, mesure 14/09). Frontiere de mot
    # obligatoire (#3407) : `#1612` ne doit pas matcher `#16120`. Echec de
    # verification = refus (fail-closed) : un duplicata coute ~$2, un tick
    # saute ne coute rien — le tick suivant retente.
    try { $openPrs = Get-QueueOpenPrs -Repo ([string]$queue.repo) }
    catch {
        $script:IdlePickOutcome = 'infrastructure'
        $script:IdlePickFailure = "anti-collision non verifiable ($($_.Exception.Message))"
        Write-Log ("[ERROR] idle-picker: {0} - tirage REFUSE (fail-closed anti-collision, arbitrage user 15/09)." -f $_.Exception.Message) "ERROR"
        return $false
    }
    $coveredBy = @{}
    foreach ($c in $candidates) {
        $n = [int]$c.number
        foreach ($pr in $openPrs) {
            if ("$($pr.title)" -match ('#{0}([^0-9]|$)' -f $n) -or
                "$($pr.headRefName)" -match ('(^|[^0-9]){0}([^0-9]|$)' -f $n)) {
                $coveredBy[$n] = [int]$pr.number
                break
            }
        }
    }
    foreach ($n in @($coveredBy.Keys)) {
        Write-Log ("[SKIP] idle-picker: #{0} ecartee - PR ouverte #{1} la couvre deja." -f $n, $coveredBy[$n])
    }
    $free = @($candidates | Where-Object { -not $coveredBy.ContainsKey([int]$_.number) })
    if ($free.Count -eq 0) {
        Write-Log "[SKIP] idle-picker: tout le pool restant est couvert par des PRs ouvertes - tick no-op."
        return $false
    }

    # Garde 2 : [CLAIMED] recent en commentaire — verifie uniquement les
    # candidats libres, dans l'ordre, jusqu'au premier pick (1 appel gh par
    # candidat examine, pas par candidat du pool). Un claim recent prime meme
    # sans PR : le travail peut etre en cours sans livraison visible.
    $picked = $null
    foreach ($c in $free) {
        $n = [int]$c.number
        $claimed = $false
        try { $claimed = Test-QueueIssueClaimed -Repo ([string]$queue.repo) -Number $n }
        catch {
            $script:IdlePickOutcome = 'infrastructure'
            $script:IdlePickFailure = "anti-collision non verifiable ($($_.Exception.Message))"
            Write-Log ("[ERROR] idle-picker: {0} - tirage REFUSE (fail-closed anti-collision, arbitrage user 15/09)." -f $_.Exception.Message) "ERROR"
            return $false
        }
        if ($claimed) {
            Write-Log ("[SKIP] idle-picker: #{0} ecartee - [CLAIMED] recent en commentaire (<{1}h, claim prime)." -f $n, $script:QueueClaimHours)
            continue
        }
        $picked = $c
        break
    }
    if (-not $picked) {
        Write-Log "[SKIP] idle-picker: tout le pool restant porte un [CLAIMED] recent - tick no-op."
        return $false
    }

    # ===== Worktree OBLIGATOIRE (14/09) =====
    # Le payload doit porter une ligne `worktree:` : c'est la SEULE source dont le
    # driver sait tirer un cwd borne (vibe-acp-driver.py:resolve_session_cwd). Sans
    # elle il retombe sur le --cwd du profil, qui est le WORKSPACE ENTIER, et
    # session/new MARCHE son cwd : D:/dev/CoursIA porte 3 750 355 entrees mesurees
    # le 14/09 (149 worktrees imbriques sous .claude/worktrees) -> aucune reponse
    # dans le budget de 90 s -> SESSION_NEW_FAILED, exit 3.
    #
    # Mesure 14/09 07:40:27Z sur #16120 : le pick est enregistre (payload 4323 chars),
    # le run meurt a 07:42:00 (93 s), et comme l'etat est sauve juste apres
    # l'injection, le slot du jour ET les 6 h d'anti-marteau sont consommes pour un
    # run qui n'a rien produit. Sonde A/B du meme jour, meme exe, memes MCP :
    #   cwd=D:/dev/CoursIA            -> session/new TIMEOUT a 120 s
    #   cwd=<worktree CoursIA>        -> session/new 5,6 s OK
    # Le cwd est le seul discriminant.
    #
    # Echec de preparation => pas de dispatch (return $false) : un payload sans
    # `worktree:` pendrait a coup sur, et consommerait les compteurs pour rien.
    $wtRoot = "$WorkspacePath-vibe"
    if ($queue.PSObject.Properties.Name -contains 'worktreeRoot' -and
        -not [string]::IsNullOrWhiteSpace([string]$queue.worktreeRoot)) {
        $wtRoot = [string]$queue.worktreeRoot
    }
    if ([string]::IsNullOrWhiteSpace($WorkspacePath) -or -not (Test-Path $WorkspacePath)) {
        $script:IdlePickOutcome = 'infrastructure'
        $script:IdlePickFailure = "workspacePath non resolu ($WorkspacePath)"
        Write-Log ("[ERROR] idle-picker: workspacePath non resolu - impossible de preparer un worktree pour #{0}, pas de dispatch." -f [int]$picked.number) "ERROR"
        return $false
    }
    $wt = Join-Path $wtRoot ("idle-{0}" -f [int]$picked.number)
    $branch = "wt/vibe-idle-{0}" -f [int]$picked.number
    try {
        if (-not (Test-Path $wtRoot)) { New-Item -ItemType Directory -Path $wtRoot -Force | Out-Null }
        git -C $WorkspacePath fetch origin main 2>$null | Out-Null
        $base = (git -C $WorkspacePath rev-parse origin/main 2>$null | Select-Object -First 1)
        if ([string]::IsNullOrWhiteSpace($base)) { throw "origin/main illisible dans $WorkspacePath" }
        $base = $base.Trim()
        # git worktree list imprime des slashes ; Join-Path rend des backslashes sur
        # Windows — sans normalisation, $known ne matche JAMAIS et le pick retombe
        # sur "worktree add" (exit 128, deja enregistre). #3646 regression.
        $wtForMatch = $wt -replace '\\', '/'
        $known = (git -C $WorkspacePath worktree list 2>$null | Select-String -SimpleMatch $wtForMatch)
        if ($known) {
            # Worktree deja en place (tick precedent). On ne le reutilise QUE sur
            # PREUVE qu'il ne porte rien : un residu non commite, ou des commits
            # d'avance sur origin/main, sont du travail potentiellement non livre.
            # Mesure 14/09 : wt/vibe-g1-genai a ete reutilise avec la mutation
            # 42af9095b encore dedans — la reutilisation aveugle est le vecteur.
            $dirty = @(git -C $wt status --porcelain 2>$null)
            $ahead = (git -C $wt rev-list --count "origin/main..HEAD" 2>$null | Select-Object -First 1)
            if ($dirty.Count -gt 0 -or "$ahead" -ne '0') {
                throw ("worktree deja en place et porteur de contenu (dirty=$($dirty.Count) fichier(s), ahead=$ahead commit(s)) - refus de le reutiliser")
            }
            git -C $wt reset --hard $base 2>$null | Out-Null
        } else {
            if ((git -C $WorkspacePath branch --list $branch 2>$null)) {
                # La branche survit au `worktree remove` (il ne la supprime pas) :
                # sans repli, un `worktree add -b` echouerait a chaque tick sur
                # l'issue deja piquee — meme motif que Prepare-Worktree cote feeder
                # (#3518 W2). Mais rattacher sans garde, c'est reattacher une branche
                # qui porte peut-etre du travail non livre : on exige d'abord
                # qu'elle n'ait RIEN d'avance sur origin/main. La remettre sur la
                # base fraiche ne perd alors rien (c'est la preuve qui l'autorise).
                $ahead = (git -C $WorkspacePath rev-list --count "origin/main..$branch" 2>$null | Select-Object -First 1)
                if ("$ahead" -ne '0') {
                    throw ("branche $branch deja existante et $ahead commit(s) d'avance sur origin/main - refus de la rattacher")
                }
                git -C $WorkspacePath branch -f $branch $base 2>$null | Out-Null
                git -C $WorkspacePath worktree add $wt $branch 2>$null | Out-Null
            } else {
                git -C $WorkspacePath worktree add $wt -b $branch $base 2>$null | Out-Null
            }
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $wt)) {
                throw "worktree add a echoue (exit $LASTEXITCODE)"
            }
        }
    } catch {
        $script:IdlePickOutcome = 'infrastructure'
        $script:IdlePickFailure = "$_"
        Write-Log ("[ERROR] idle-picker: worktree indisponible pour #{0} ({1}) - pas de dispatch (un payload sans 'worktree:' pendrait sur session/new)." -f [int]$picked.number, $_) "ERROR"
        return $false
    }

    $body = [string]$picked.body
    if ($body.Length -gt 4000) { $body = $body.Substring(0, 4000) + "..." }
    # Le corps d'issue est insere AVANT le bloc du picker et n'est pas du contrat.
    # Le bloc est donc ouvert par son marqueur de provenance, et resolve_session_cwd
    # ne scanne que lui : un corps qui se contente de DOCUMENTER le format
    # (`worktree: D:/dev/CoursIA`, repertoire existant) ne peut plus detourner le cwd
    # de session vers le workspace a 3,75 M d'entrees, sans WARN puisque le chemin existe.
    $promptText = ("Issue #{0}: {1}`n`n{2}`n`n-- Provenance: idle-picker (tick planifie sans WAKE). Livrer le travail correspondant dans le worktree ci-dessous.`nworktree: {3}`nbranch: {4}" -f [int]$picked.number, [string]$picked.title, $body, $wt, $branch)
    $payload = @{ content = $promptText } | ConvertTo-Json -Compress
    $env:VIBE_WAKE_PAYLOAD = $payload
    Write-Log ("[PICK] idle-picker: issue #{0} '{1}' -> payload {2} chars" -f [int]$picked.number, [string]$picked.title, $payload.Length)

    Save-QueueState -Path $statePath -State @{
        date = $today
        idleRuns = ($idleRuns + 1)
        lastIssueNumber = [int]$picked.number
        lastRunAt = (Get-Date).ToUniversalTime().ToString("o")
    }
    return $true
}

# ========== NO-OP GUARD (#3296) ==========
# Un tick planifie sans [WAKE-VIBE] en attente est un NO-OP, pas un echec. La commande
# harnais du profil CoursIA est `--wake`-only : le driver prend son prompt dans
# VIBE_WAKE_PAYLOAD (vibe-acp-driver.py l.149) et sort en erreur sans lui. La schtask
# tirant toutes les heures sans condition, ~105 des 121 ticks de 5 jours (86 %) etaient
# des exit-1 structurels — assez de bruit ERROR pour noyer les vrais.
#
# On sort AVANT le lock : un tick qui ne fera rien n'a aucune raison de le prendre, et
# rien a liberer (le `finally` de l'execution ne couvre pas ce point du script).
# Le heartbeat, lui, est ecrit : sans lui le worker paraitrait mort entre deux WAKE,
# qui sont rares. C'est la convention que ce fichier declare l.96.
#
# Deux absences distinctes, deux sorties — ne pas les confondre :
#   * aucun -MessagePayloadFile passe  -> tick planifie, aucun dispatch n'existe -> exit 0.
#   * -MessagePayloadFile passe mais illisible -> un dispatch A ete route et son payload
#     manque : c'est une anomalie, elle doit rester bruyante. Ce cas ne passe donc PAS
#     par cette garde et retombe sur le chemin d'erreur existant.
# Un `--prompt`/`--prompt-file` explicite bat le payload cote driver (l.149) : une telle
# commande fonctionne sans WAKE et ne doit pas etre sautee.
$wakeOnly = ($HarnessCommand -match '(^|\s)--wake(\s|$)') -and
            ($HarnessCommand -notmatch '(^|\s)--prompt(-file)?[\s=]')
if ($wakeOnly -and
    [string]::IsNullOrWhiteSpace($MessagePayloadFile) -and
    [string]::IsNullOrWhiteSpace($env:VIBE_WAKE_PAYLOAD)) {
    if (-not (Invoke-IdleQueuePick)) {
        # 'infrastructure' = le picker a REFUSE de dispatcher (workspacePath non
        # resolu, fetch casse, worktree add en echec, branche existante porteuse de
        # travail). Ce n'est PAS un tick sans travail : le sortir en exit 0 le rendait
        # indiscernable d'un pool vide pour le scheduler. Seuls les no-op genuins
        # (pool vide, cap atteint, anti-marteau) restent a zero.
        if ($script:IdlePickOutcome -eq 'infrastructure') {
            Write-Log ("[ERROR] idle-picker: preparation refusee ({0}) - tick termine en echec, pas en no-op." -f $script:IdlePickFailure) "ERROR"
            Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
            exit 1
        }
        Write-Log "[SKIP] no WAKE payload pending - scheduled tick is a no-op (exit 0)."
        Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
        exit 0
    }
    # Payload injected by the idle picker — fall through to lock + execution.
}

# ========== ANTI-OVERLAP LOCK (#3277 fix 2 : création atomique, pas check-then-create) ==========
# Incident 25/08 : deux invocations à la même seconde passaient TOUTES DEUX le check
# Test-Path/Set-Content → 2 workers payés en parallèle (le logueur du vainqueur
# voyait « Remove-Item vibe-worker.lock — does not exist » : chaque worker supprimait
# le lock de l'autre).
#
# CreateNew + FileShare.None est atomique kernel-side : un seul gagnant, et le handle
# resté ouvert bloque toute réouverture tant que le worker vit. Discriminateur
# stale : si la lecture du lock RÉUSSIT, personne ne détient de handle (le titulaire
# bloque aussi la lecture via FileShare.None) → reste de crash → remove + un unique
# retry. Si la lecture échoue (sharing violation), un worker VIVANT le détient → SKIP.

$LockFile = Join-Path $LogDir "vibe-worker.lock"
$script:LockStream = $null

function Open-WorkerLock {
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            $script:LockStream = [System.IO.File]::Open($LockFile,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None)
            $MachineLock = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.ToLower() } else { 'unknown' }
            $lockBody = @{ pid = $PID; startedAt = (Get-Date).ToUniversalTime().ToString("o"); machine = $MachineLock } | ConvertTo-Json -Compress
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($lockBody)
            $script:LockStream.Write($bytes, 0, $bytes.Length)
            $script:LockStream.Flush()
            return $true
        } catch [System.IO.IOException] {
            try {
                # Le fichier existe (CreateNew a échoué). Le lit-on ?
                $null = [System.IO.File]::ReadAllText($LockFile)
                # Lecture OK → aucun handle détient le fichier → lock stale (crash d'un
                # worker précédent) → remove + retry CreateNew (au plus une fois).
                Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
                continue
            } catch {
                # Sharing violation → un worker VIVANT détient le lock → SKIP.
                return $false
            }
        } catch {
            return $false
        }
    }
    return $false
}

if (-not (Open-WorkerLock)) {
    # exit 75 (#3277 fix 3) : SKIP ≠ succès. Le listener n'avance PAS lastAck sur 75 —
    # le dispatch n'est pas consommé par un worker qui n'a rien fait.
    Write-Log "[SKIP] Another vibe worker holds the lock — exiting WITHOUT consuming the dispatch (exit 75)."
    Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
    exit 75
}

# ========== EXECUTION ==========

# #3202: If a WAKE payload was passed by the listener, expose it to the harness
# command via VIBE_WAKE_PAYLOAD (env var avoids quoting issues with markdown content).
if (-not [string]::IsNullOrWhiteSpace($MessagePayloadFile) -and (Test-Path $MessagePayloadFile)) {
    $env:VIBE_WAKE_PAYLOAD = [System.IO.File]::ReadAllText($MessagePayloadFile, [System.Text.UTF8Encoding]::new($false))
    Write-Log "WAKE payload injected from $MessagePayloadFile ($($env:VIBE_WAKE_PAYLOAD.Length) chars)"
}

$exitCode = 0
try {
    $iterations = [Math]::Max(1, $MaxIterations)
    for ($i = 1; $i -le $iterations; $i++) {
        Write-Log "Iteration $i/$iterations : $HarnessCommand"
        $output = & pwsh -NoProfile -Command $HarnessCommand 2>&1
        $iterExit = $LASTEXITCODE
        if ($output) { $output | ForEach-Object { Write-Log "  $_" } }
        if ($iterExit -ne 0) {
            Write-Log "HarnessCommand exited with code $iterExit (iteration $i)" "ERROR"
            $exitCode = 1
            break
        }
    }
} catch {
    Write-Log "Worker crashed: $_" "ERROR"
    Write-Log "Stack: $($_.ScriptStackTrace)" "ERROR"
    $exitCode = 1
} finally {
    Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
    # Relâcher le handle AVANT le delete (un handle ouvert rend le remove non garanti).
    if ($script:LockStream) {
        try { $script:LockStream.Close() } catch { }
        $script:LockStream = $null
    }
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}

exit $exitCode

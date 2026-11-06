<#
.SYNOPSIS
    Fleet-wide health check: diagnose wake-listeners on all known machines (#2576).

.DESCRIPTION
    Designed to run as a cron worker (every 2h). For each known machine in the fleet:
    1. SSH or check local listener heartbeat
    2. Report [FLEET-ALERT] on the MACHINE dashboard of the detector
       (G-C #4131 étape 3, arbitrage ai-01 14/10 option a — via the submodule
       RSM CLI first: dual-write journal PG + file, append lock, format at the
       store; direct file write as fallback)
    3. Trigger auto-repair via repair-wake-listener.ps1 if listener is DEAD

    This implements the "alerting proactif" recommendation from #2576:
    if STALE >2h → [WARN] automatically posted to dashboard.

    Known machines : le ROSTER DECLARATIF `.claude/configs/fleet-manifest.json`
    (9 sieges), pas une liste en dur. La liste en dur d'origine (6 sieges) etait
    derivee : po-2027, po-2028 et web2 publient un heartbeat et n'etaient jamais
    controles, pendant que 3 sieges listes ne publiaient rien (#4503, mesure du
    05/11). L'organe qui possede le roster est le manifeste lui-meme (lu par
    verify-fleet-manifest.py) ; ce script le consomme, il ne le duplique pas.

    L'état partagé est lu dans TOUS les miroirs accessibles (#4503, cause
    racine mesurée le 06/11) : DriveFS dépose des copies suffixées du
    dossier « Synchronisation » (« Synchronisation (1) »…), et chaque siège
    écrit dans le miroir que SA configuration désigne. Un check qui n'en lit
    qu'un juge la flotte sur une fraction de l'état : depuis une copie
    périmée il rend « 4 of 6 machines STALE/DEAD » pour des sièges qui
    publient dans l'autre miroir. Le verdict retient la preuve la plus
    fraîche, tous miroirs confondus ; un siège qui ne publie plus depuis
    plus de 7 jours sort du périmètre surveillé (ce n'est plus une panne de
    listener, c'est un siège parti — l'alerte permanente serait le bruit que
    #4503 combat).

    Code de sortie :
    - 0 : flotte saine (aucun listener mort, et la passe a vérifié au moins
      un siège) ;
    - 1 : au moins un listener confirmé mort (> 2 h sans publication) ;
    - 2 : la passe n'a RIEN vérifié (aucun heartbeat lisible dans aucun
      miroir) — le « vert qui ne vérifie rien », invisible pour tout
      planificateur. RC=2 est déjà un échec réel pour
      report-failed-scheduled-tasks.ps1 (liste benigne : 0, 267009, 267011,
      2147946720) : aucun changement consommateur n'est requis.

.PARAMETER Machines
    Comma-separated list of machines to check. Defaults to full fleet.
    For each machine, format is "machineId:workspace" or just "machineId".

.PARAMETER NoRepair
    Skip auto-repair attempts. Only diagnose and report.

.PARAMETER NoAlert
    Skip dashboard alerting. Only output diagnostic results.

.PARAMETER Json
    Output JSON instead of markdown.

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\check-all-listeners.ps1
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\check-all-listeners.ps1 -Machines "web1,po-2023"
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\check-all-listeners.ps1 -NoRepair

.NOTES
    Related: issue #2576 (web1 listener recurring STALE), #2431 (durability fix).
#>

param(
    [string]$Machines = "",
    [switch]$NoRepair,
    [switch]$NoAlert,
    [switch]$Json,
    # Racines de l'etat partage a lire, separees par ';'. Surcharge TOTALE de
    # la decouverte (diagnostic operateur + tests) : les racines reelles du
    # lecteur ne sont PAS ajoutees. Vide = decouverte automatique.
    # La variable d'environnement FLEET_SHARED_ROOTS fait le meme office et
    # est preferable en automatisme : la ligne de commande est re-parsee par
    # le shell enfant, la variable d'environnement ne l'est pas.
    #
    # NOM VOLONTAIREMENT DISTINCT de la variable locale qui portera la liste :
    # PowerShell ignore la casse, donc un parametre [string]$SharedRoots et
    # une variable locale $sharedRoots sont LE MEME emplacement. L'affectation
    # de la liste (un tableau) y serait coercee en chaine par le type [string]
    # du parametre — et deux racines se concateneraient en un seul chemin
    # inexistant. Mesure : une seule racine passait, deux donnaient 0 siege
    # lu sans que l'erreur soit visible.
    [string]$FleetSharedRoots = ""
)

$ErrorActionPreference = "Continue"

$nowUtc = (Get-Date).ToUniversalTime()

# ---------------------------------------------------------------------------
# Roster (#4503) — le manifeste declaratif est l'organe qui porte la liste des
# sieges. Repli sur l'identique de classify-machine-usability.ps1 (#4258) si le
# manifeste est absent (checkout ancien, script copie hors depot).
# ---------------------------------------------------------------------------
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$manifestPath = Join-Path $repoRoot ".claude\configs\fleet-manifest.json"
$defaultMachines = @()
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $defaultMachines = @($manifest.machines.PSObject.Properties.Name | Sort-Object)
    } catch {
        Write-Host "[FLEET] fleet-manifest.json illisible ($($_.Exception.Message)) — repli sur le roster #4258."
    }
}
if ($defaultMachines.Count -eq 0) {
    $defaultMachines = @(
        'myia-ai-01', 'myia-po-2023', 'myia-po-2024', 'myia-po-2025', 'myia-po-2026',
        'myia-po-2027', 'myia-po-2028', 'myia-web1', 'myia-web2'
    )
}
if (-not [string]::IsNullOrEmpty($Machines)) {
    $machineList = $Machines -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
} else {
    $machineList = $defaultMachines
}

# ---------------------------------------------------------------------------
# Racines de l'etat partage (#4503, cause racine mesuree le 06/11)
#
# DriveFS depose des COPIES suffixees du dossier « Synchronisation »
# (« Synchronisation (1) »…) et chaque siege y ecrit dans le miroir que SA
# configuration designe. Reader ET writer lisent le meme $env:ROOSYNC_SHARED_PATH
# : un siege dont l'env pointe la copie (1) y ecrit, et un lecteur qui lit la
# racine canonique ne le voit pas. La lecture d'UN seul miroir juge donc la
# flotte sur une FRACTION de l'etat — d'ou les verdicts contradictoires
# ("4 of 6 STALE" depuis une copie perimee, 0 depuis la canonique).
#
# Correction : on lit TOUTES les racines candidates et on retient, pour chaque
# siege, la preuve la plus FRAICHE (le timestamp ISO embarque dans le contenu
# du fichier, cf. la regle "sujet principal" ; le mtime n'est qu'un repli).
# Un siege publishes dans le miroir (1) est alors lu ALIVE, et le verdict
# nomme la racine qui a fourni la preuve (piste 3 de l'issue : annoter le
# verdict avec la source lue, pour qu'un lecteur puisse departager deux
# verdicts contradictoires).
# ---------------------------------------------------------------------------
function Get-SharedStateRoots {
    $roots = @()
    $seen = @{}

    # 1. La racine configuree (env du processus, sinon variable User/Machine).
    $configured = $env:ROOSYNC_SHARED_PATH
    if ([string]::IsNullOrEmpty($configured)) {
        $configured = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'User')
    }
    if ([string]::IsNullOrEmpty($configured)) {
        $configured = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'Machine')
    }
    if (-not [string]::IsNullOrEmpty($configured)) { $roots += $configured }

    # 2. Les Copies de DriveFS : <drive>/Mon Drive/Synchronisation*/
    #    RooSync/.shared-state. Le nom « Synchronisation » est copie tel quel
    #    (« Synchronisation (1) », « Synchronisation (2)»…) : on les enumere au
    #    lieu de deviner les suffixes.
    #    Lecteurs LOCAUX FIXES uniquement (DriveType=Fixed) : un lecteur reseau
    #    deconnecte ferait bloquer Test-Path, et ce script tourne en tache
    #    planifiee — un blocage la ferait expire sans produire de verdict.
    foreach ($drive in ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq [System.IO.DriveType]::Fixed -and $_.IsReady })) {
        $syncRoot = Join-Path $drive.RootDirectory.FullName "Mon Drive"
        if (-not (Test-Path $syncRoot)) { continue }
        foreach ($syncDir in (Get-ChildItem $syncRoot -Directory -Filter 'Synchronisation*' -ErrorAction SilentlyContinue)) {
            $roots += (Join-Path $syncDir.FullName "RooSync\.shared-state")
        }
    }

    # Deduplication + filtrage des racine inexistante.
    $out = @()
    foreach ($r in $roots) {
        if ([string]::IsNullOrEmpty($r)) { continue }
        $full = [System.IO.Path]::GetFullPath($r)
        $key = $full.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        if (Test-Path $full) { $out += $full }
    }
    return $out
}

# Les racines a lire. La surcharge explicite REPLACE la decouverte (elle ne
# s'y ajoute pas) : c'est le mode diagnostic — « juge la flotte depuis CE
# miroir » — qui reproduit le symptome de #4503 mecaniquement.
$rootOverride = $FleetSharedRoots
if ([string]::IsNullOrEmpty($rootOverride)) { $rootOverride = $env:FLEET_SHARED_ROOTS }

$sharedRoots = if (-not [string]::IsNullOrEmpty($rootOverride)) {
    @($rootOverride -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | ForEach-Object { [System.IO.Path]::GetFullPath($_) })
} else {
    @(Get-SharedStateRoots)
}

# La racine d'ECRITURE de l'alerte est celle que le listener ecrit (dashboard-
# listener.ps1 lit le meme $env:ROOSYNC_SHARED_PATH) — sinon l'alerte atterrit
# dans une copie orpheline que personne ne lit. Si l'env n'est pas configure,
# on privilegie le miroir SANS suffixe (« Synchronisation ») : c'est la copie
# d'origine, celle que les ~10 scripts du depot qui hardcodent le chemin
# canonique designent.
$configuredRoot = $env:ROOSYNC_SHARED_PATH
if ([string]::IsNullOrEmpty($configuredRoot)) {
    $configuredRoot = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'User')
}
if ([string]::IsNullOrEmpty($configuredRoot)) {
    $configuredRoot = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'Machine')
}
$primarySharedPath = if (-not [string]::IsNullOrEmpty($configuredRoot) -and (Test-Path $configuredRoot)) {
    [System.IO.Path]::GetFullPath($configuredRoot)
} else {
    $canonical = @($sharedRoots | Where-Object {
        $parent = Split-Path (Split-Path $_ -Parent) -Leaf
        $parent -eq 'Synchronisation'
    })
    if ($canonical.Count -gt 0) { $canonical[0] } elseif ($sharedRoots.Count -gt 0) { $sharedRoots[0] } else { $null }
}

# Un siege qui n'a rien publie depuis plus de 7 jours n'est plus un listener
# mort : c'est un siege sorti du perimetre. Sans cette regle, un siege retire
# (po-2026, muet depuis le 09/10) resterait STALE pour toujours et l'alerte
# permanente serait exactement le bruit que #4503 combat. La regle est bornee
# par le constat, pas une excuse : le seuil est long (7 j) et le siege reste
# visible dans la sortie (statut RETIRED), jamais silencieusement ecarte.
$retiredAfterSeconds = 604800

$results = @()
$totalDead = 0
$totalUnknown = 0
$totalRetired = 0

foreach ($machineEntry in $machineList) {
    # Parse machineId:workspace or just machineId
    $machineId = $machineEntry.Split(':')[0].Trim().ToLowerInvariant()
    $workspace = if ($machineEntry.Contains(':')) { $machineEntry.Split(':')[1].Trim() } else { "" }

    # #4503 : le heartbeat est cherche dans TOUTES les racines de l'etat
    # partage (miroirs DriveFS divergents). Pour chaque racine on lit le
    # timestamp ISO EMBARQUE dans le contenu du fichier (regle "sujet
    # principal" : le mtime depend de la propagation DriveFS et peut etre
    # perime dans la vue du lecteur) ; le mtime ne sert qu'a repli.
    # Le verdict retient la preuve la plus RECENTE tous miroirs confondus.
    $bestBeat = $null
    $bestSource = $null
    $bestRoot = $null
    $foundIn = @()

    foreach ($root in $sharedRoots) {
        $hbFile = Join-Path (Join-Path $root "listener-heartbeats") "$machineId.heartbeat"
        if (-not (Test-Path $hbFile)) { continue }
        $foundIn += $root

        $hbContent = $null
        try { $hbContent = (Get-Content $hbFile -Raw -Encoding UTF8).Trim() } catch { $hbContent = $null }
        $beat = $null
        if ($hbContent) {
            try { $beat = [DateTimeOffset]::Parse($hbContent).UtcDateTime } catch { $beat = $null }
        }
        if ($null -eq $beat) { $beat = (Get-Item $hbFile).LastWriteTimeUtc }

        if ($null -eq $bestBeat -or $beat -gt $bestBeat) {
            $bestBeat = $beat
            $bestSource = if ($hbContent) { "content" } else { "mtime" }
            $bestRoot = $root
        }
    }

    $heartbeatStatus = "UNKNOWN"
    $heartbeatAge = $null
    if ($null -ne $bestBeat) {
        $age = [int]($nowUtc - $bestBeat).TotalSeconds
        $heartbeatAge = $age
        if ($age -lt 7200) {
            $heartbeatStatus = "ALIVE"
        } elseif ($age -gt $retiredAfterSeconds) {
            # Siege sorti du perimetre : il n'alerte PAS (le bruit permanent est
            # ce que #4503 combat) mais il reste visible dans la sortie.
            $heartbeatStatus = "RETIRED"
        } else {
            $heartbeatStatus = "STALE"
            $totalDead++
        }
    }

    # #4503 : un heartbeat absent (ou aucune racine lisible) laisse
    # $heartbeatStatus = "UNKNOWN". Cet etat ne se compte PAS sain : s'il
    # s'effacait dans le "0 STALE/DEAD", une passe qui ne lit aucun heartbeat
    # rendrait un vert silencieux (totalDead=0). Il est donc compte a part et
    # surface, sans jamais alerter (l'alerte reste reservee au STALE confirme).
    if ($heartbeatStatus -eq "UNKNOWN") { $totalUnknown++ }
    if ($heartbeatStatus -eq "RETIRED") { $totalRetired++ }

    # #3761 remède 3 : compteur de skips du jour, écrit par le listener à côté du
    # heartbeat (listener-heartbeats/<machine>.skips, UTF-8 no BOM, lignes
    # `date|workspace|count`). Absent = listener sans remède 3 ou 0 skip mesuré.
    # Lu dans la meme racine que le heartbeat retenu (le compteur suit la
    # publication du listener, pas un autre miroir).
    $skipsToday = $null
    $skipsFile = if ($bestRoot) {
        Join-Path (Join-Path $bestRoot "listener-heartbeats") "$machineId.skips"
    } else { $null }
    if ($skipsFile -and (Test-Path $skipsFile)) {
        $today = $nowUtc.ToString("yyyy-MM-dd")
        $skipsToday = 0
        foreach ($line in [System.IO.File]::ReadAllLines($skipsFile)) {
            $parts = $line -split '\|'
            if ($parts.Count -ge 3 -and $parts[0] -eq $today) { $skipsToday += [int]$parts[2] }
        }
    }

    $results += [PSCustomObject]@{
        machineId    = $machineId
        workspace    = $workspace
        heartbeat    = $heartbeatStatus
        ageSeconds   = $heartbeatAge
        skipsToday   = $skipsToday
        isDead       = $heartbeatStatus -eq "STALE"
        # Piste 3 de #4503 : le verdict nomme la source qui l'a produit, pour
        # qu'un lecteur puisse departager deux verdicts contradictoires.
        sourceRoot   = $bestRoot
        sourceKind   = $bestSource
        foundInRoots = ($foundIn -join ' | ')
    }
}

# ---------- Output ----------
# Contrat de code de sortie (#4503, "exit instrument") :
#   0 = flotte saine et au moins un siege verifie ;
#   1 = au moins un listener confirme mort (> 2 h sans publication) ;
#   2 = la passe n'a RIEN verifie (aucun heartbeat lisible dans aucun miroir).
# RC=2 rend le "vert qui ne verifie rien" visible de tout planificateur. Il
# n'exige AUCUN changement consommateur : report-failed-scheduled-tasks.ps1
# traite deja RC=2 comme un echec reel (liste benigne : 0, 267009, 267011,
# 2147946720) et son harnais verrouille cette absence d'exclusion.
#
# #4503 (review A, PR #4574) : le critere "$totalUnknown -eq $results.Count"
# rate le cas ou un siege RETIRED masque l'instrument aveugle — 8 UNKNOWN +
# 1 RETIRED rend 8 <> 9 donc exit 0 alors que RIEN n'a ete verifie. On compte
# donc les sieges reellement VERIFIES (ALIVE ou STALE) : s'il n'y en a aucun,
# la passe n'a rien prouve -> exit 2, quel que soit le nombre de RETIRED.
$verifiedInScope = @($results | Where-Object { $_.heartbeat -eq 'ALIVE' -or $_.heartbeat -eq 'STALE' }).Count
if ($Json) {
    [PSCustomObject]@{
        checkedAtUtc = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        totalMachines = $results.Count
        totalDead     = $totalDead
        totalUnknown  = $totalUnknown
        totalRetired  = $totalRetired
        sharedRoots   = $sharedRoots
        machines      = $results
    } | ConvertTo-Json -Depth 3
    exit $(if ($totalDead -gt 0) { 1 } elseif ($verifiedInScope -eq 0 -and $results.Count -gt 0) { 2 } else { 0 })
}

# ---------- Markdown report ----------
Write-Output "### Fleet listener health check — $nowUtc UTC"
Write-Output ""
Write-Output "| Machine | Heartbeat | Age | Skips today | Status | Source |"
Write-Output "|---------|-----------|-----|-------------|--------|--------|"
foreach ($r in $results) {
    $ageStr = if ($null -ne $r.ageSeconds) { "$($r.ageSeconds)s" } else { "N/A" }
    $skipsStr = if ($null -ne $r.skipsToday) { "$($r.skipsToday)" } else { "N/A" }
    $statusStr = if ($r.heartbeat -eq "ALIVE") { "**OK**" } elseif ($r.heartbeat -eq "STALE") { "**STALE >2h**" } elseif ($r.heartbeat -eq "RETIRED") { "retired (>7j)" } else { "???" }
    $srcStr = if ($r.sourceRoot) {
        # Nom du MIROIR (le dossier « Synchronisation* » qui porte la copie).
        # <racine> = ...\Synchronisation[ (n)]\RooSync\.shared-state
        #   -> miroir = le dossier « Synchronisation* » (2 paliers au-dessus).
        # « RooSync » ne designait rien pour un lecteur : les deux racines
        # s'appellent pareil a ce niveau.
        $mirror = Split-Path (Split-Path (Split-Path $r.sourceRoot -Parent) -Parent) -Leaf
        "$($r.sourceKind) @ $mirror"
    } else { "N/A" }
    Write-Output "| $($r.machineId) | $($r.heartbeat) | $ageStr | $skipsStr | $statusStr | $srcStr |"
}
Write-Output ""
Write-Output "Total: $($results.Count) machines checked, $totalDead STALE/DEAD, $totalUnknown UNVERIFIED (no heartbeat read), $totalRetired RETIRED (>7j silent)."
Write-Output ""
if ($sharedRoots.Count -gt 0) {
    Write-Output "Shared-state roots read ($($sharedRoots.Count)):"
    foreach ($r in $sharedRoots) { Write-Output "- $r" }
    Write-Output ""
}
if ($totalDead -eq 0 -and $totalUnknown -gt 0) {
    Write-Output "NOTE: $totalUnknown machine(s) UNVERIFIED - no heartbeat readable in any shared-state root. Not counted as healthy; this run verified nothing for them."
    Write-Output ""
}
if ($totalRetired -gt 0) {
    Write-Output "NOTE: $totalRetired machine(s) RETIRED - silent for more than 7 days (seat out of scope, not a dead listener). Not alerted."
    Write-Output ""
}

# ========== G-C #4131 étape 3 : IO DASHBOARD VIA LES CLI DU SUBMODULE ==========
# Mêmes helpers que dashboard-listener.ps1 (sites 1-4, #4203) — duplication
# documentée, convergence à la prochaine évolution du listener. Fail-open :
# un appel CLI qui échoue (node absent, submodule absent, exit 1 échec
# d'écriture, exit 2 usage) rend $null et l'alerte retombe sur l'écriture
# fichier directe ci-dessous — l'alerte ne doit jamais se perdre.

$script:RsmScriptsDirCache = $null

function Get-RsmScriptsDir {
    # Résolution (une fois, cachée) : RSM_SERVER_ROOT env > submodule sibling du
    # dépôt qui porte ce script. Retourne "" si introuvable -> repli fichier.
    if ($null -ne $script:RsmScriptsDirCache) { return $script:RsmScriptsDirCache }
    $candidates = @()
    if (-not [string]::IsNullOrEmpty($env:RSM_SERVER_ROOT)) { $candidates += $env:RSM_SERVER_ROOT }
    $candidates += [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\mcps\internal\servers\roo-state-manager"))
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "scripts\rsm-dashboard-append.mjs")) {
            $script:RsmScriptsDirCache = Join-Path $c "scripts"
            return $script:RsmScriptsDirCache
        }
    }
    # Write-Host (pas Write-Output) : cette fonction est assignée par ses callers
    # (`$dir = Get-RsmScriptsDir`) — un Write-Output atterrit dans la variable de
    # l'appelant, pas sur stdout : diagnostic invisible ET tableau au lieu du
    # string attendu. Write-Host passe par la console, hors pipeline.
    Write-Host "[FLEET-ALERT] RSM CLI dir not found (PG-first append disabled, file fallback only)."
    $script:RsmScriptsDirCache = ""
    return ""
}

function Invoke-RsmCliJson($scriptName, $cliArgs) {
    # Appelle un CLI .mjs du submodule, rend le JSON stdout parsé ou $null
    # (fail-open, repli fichier garanti par le caller). Exit CLI : 0 ok ·
    # 1 échec d'écriture · 2 usage — les deux replient pareil.
    $dir = Get-RsmScriptsDir
    if ($dir -eq "") { return $null }
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $node) { return $null }
    $out = & $node.Source (Join-Path $dir $scriptName) @cliArgs 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Write-Host : voir note Get-RsmScriptsDir — le caller assigne le retour
        # de cette fonction, un Write-Output serait capturé dans sa variable.
        Write-Host "[FLEET-ALERT] RSM CLI $scriptName exit $LASTEXITCODE (repli fichier)."
        return $null
    }
    try { return (($out -join "`n") | ConvertFrom-Json) } catch { return $null }
}

# ---------- Dashboard alert ----------
if ($totalDead -gt 0 -and -not $NoAlert) {
    $deadMachines = @($results | Where-Object { $_.isDead } | ForEach-Object { $_.machineId })
    $deadList = ($deadMachines | Select-Object -First 10) -join ', '
    $warnContent = "[FLEET-ALERT] [WARN] Fleet listener check: $totalDead of $($results.Count) machines have STALE/DEAD wake-listeners (threshold >2h). Machines affected: $deadList."
    Write-Output ""
    Write-Output $warnContent

    # G-C #4131 étape 3 (arbitrage ai-01 14/10, option a) : l'alerte vit sur le
    # dashboard MACHINE du détecteur, plus sur le dashboard workspace — c'était
    # la 2ᵉ implémentation dérivante du format d'écriture que l'étape supprime.
    # Primaire : rsm-dashboard-append.mjs (dual-write journal PG + fichier,
    # verrou append cross-process, compteur/pluralisation/seed délégués au
    # store, #3761 condition 1 par construction : machine uniquement, [ERROR]
    # refusé, auteur <machine>|listener). Repli : écriture fichier directe
    # ci-dessous, mêmes conventions que Write-MachineDashboardMessage
    # (dashboard-listener.ps1 site 4). Le lecteur suit l'alerte :
    # .claude/commands/coordinate.md lit le dashboard machine au démarrage.
    $sharedPath = $primarySharedPath
    $localMachineId = if ($env:ROOSYNC_MACHINE_ID) { $env:ROOSYNC_MACHINE_ID.ToLowerInvariant() } else { $env:COMPUTERNAME.ToLowerInvariant() }

    if (-not $sharedPath) {
        Write-Output "[FLEET-ALERT] ROOSYNC_SHARED_PATH not set — alert on stdout only (no dashboard write)."
    } else {
        try {
            $sharedDashDir = Join-Path $sharedPath "dashboards"
            $machineDashFile = Join-Path $sharedDashDir "machine-$localMachineId.md"

            # Anti-spam: cooldown — skip if we already alerted for overlapping dead machines within 6h.
            # Prevents flooding on long outages (cron 2h × outage duration). Étape 3 : les alertes
            # vivant sur le dashboard machine du détecteur, le cooldown scanne CE fichier (le
            # workspace partagé ne les reçoit plus — le scanner serait structurellement vide).
            $cooldownHours = 6
            $cooldownCutoff = $nowUtc.AddHours(-$cooldownHours)
            $shouldAlert = $true

            if (Test-Path $machineDashFile) {
                $existingRaw = Get-Content $machineDashFile -Raw -Encoding UTF8
                # Match prior FLEET-ALERT messages — require [FLEET-ALERT] as first content line
                # (after [msg:] marker + blank line) to avoid false-positives on reports that quote alerts
                $alertRe = '(?m)^### \[([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?Z)\][^\r\n]*\r?\n(?:\[msg:[^\r\n]*\r?\n)?\r?\n\[FLEET-ALERT\][^\r\n]*Machines affected:\s*([^\r\n.]+)'
                foreach ($am in [regex]::Matches($existingRaw, $alertRe)) {
                    try {
                        $postTime = [DateTimeOffset]::Parse($am.Groups[1].Value).UtcDateTime
                        if ($postTime -ge $cooldownCutoff) {
                            $listed = @($am.Groups[2].Value -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
                            $overlap = @($listed | Where-Object { $deadMachines -contains $_ })
                            if ($overlap.Count -gt 0) {
                                $shouldAlert = $false
                                Write-Output "[FLEET-ALERT] Cooldown: already posted about {$($listed -join ', ')} at $($am.Groups[1].Value) (within ${cooldownHours}h). Skipping."
                                break
                            }
                        }
                    } catch { }
                }
            }

            if ($shouldAlert) {
                # Primaire (étape 3) : append par le CLI du build servi — même
                # sérialisation et dual-write que l'hôte MCP, auteur
                # <machine>|listener, format/verrou/compteur au store.
                $cli = Invoke-RsmCliJson "rsm-dashboard-append.mjs" @('--machine', $localMachineId, '--content', $warnContent)
                if ($null -ne $cli -and $cli.ok -eq $true) {
                    Write-Output "[FLEET-ALERT] Posted [WARN] to machine dashboard via RSM CLI (key $($cli.key), messageId $($cli.messageId), pgSynced=$($cli.pgSynced))"
                } else {
                    # --- repli fichier (conventions Write-MachineDashboardMessage, inchangées) ---
                    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    $randSuffix = -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })
                    # Stamp à la seconde (pas la minute) : deux escalades la même minute ne se
                    # distinguent que par les 4 aléas sinon (parité #4124).
                    $msgId = $localMachineId + ':listener:ic-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmss') + '-' + $randSuffix
                    $newMessage = "`r`n### [$timestamp] $localMachineId|listener`r`n[msg: $msgId]`r`n`r`n$warnContent`r`n"

                    if (-not (Test-Path $sharedDashDir)) {
                        New-Item -ItemType Directory -Path $sharedDashDir -Force | Out-Null
                    }

                    if (Test-Path $machineDashFile) {
                        $content = Get-Content $machineDashFile -Raw -Encoding UTF8
                        $content = $content.TrimEnd() + "`r`n" + $newMessage
                        # Bump du compteur + pluralisation (même fix que Write-MachineDashboardMessage,
                        # #4124) : le MCP rend toujours "(N messages)" (dashboard.ts:1936) et le parseur
                        # listener l'exige. Un bump chiffre-seul laisserait "(2 message)" si le
                        # fichier avait été semé au singulier.
                        $content = [regex]::Replace($content, '(?<=## Intercom\s*\()\d+(?=\s*messages?\))', {
                            param($m); ([int]$m.Value + 1).ToString()
                        })
                        $content = [regex]::Replace($content, '(## Intercom \(\d+) message\)', '$1 messages)')
                    } else {
                        # Dashboard doesn't exist — create minimal file. Seed au PLURIEL
                        # "(1 messages)" : convention du MCP (dashboard.ts:1936) — même règle
                        # que Write-MachineDashboardMessage.
                        $content = "---`r`ntype: machine`r`nlastModified: '$timestamp'`r`nlastModifiedBy:`r`n  machineId: $localMachineId`r`n  workspace: listener`r`ntotalMessages: 1`r`n---`r`n`r`n## Status`r`n`r`n## Intercom (1 messages)`r`n$newMessage"
                    }

                    [System.IO.File]::WriteAllText($machineDashFile, $content, [System.Text.UTF8Encoding]::new($false))
                    Write-Output "[FLEET-ALERT] Posted [WARN] to $machineDashFile (file fallback)"
                }
            }
        } catch {
            # Best-effort: GDrive unavailability must never fail the probe
            Write-Output "[FLEET-ALERT] Failed to write dashboard (best-effort, probe continues): $($_.Exception.Message)"
        }
    }
}

# ---------- Auto-repair ----------
if (-not $NoRepair -and $totalDead -gt 0) {
    Write-Output ""
    Write-Output "[REPAIR] Attempting auto-repair for affected machines..."
    Write-Output "Note: repair-wake-listener.ps1 must be run ON the affected machine (needs local access to scheduled tasks)."
    Write-Output "Dispatched repair commands would target: $($results | Where-Object { $_.isDead } | ForEach-Object { $_.machineId } | ForEach-Object { $_ })"
    Write-Output "[REPAIR] Use [WAKE-CLAUDE] on affected machines or dispatch via coordinator to trigger repair."
}

exit $(if ($totalDead -gt 0) { 1 } elseif ($verifiedInScope -eq 0 -and $results.Count -gt 0) { 2 } else { 0 })

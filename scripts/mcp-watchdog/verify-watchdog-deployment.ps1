<#
.SYNOPSIS
    Verificateur host-side read-only du deploiement du chain watchdog MCP (#3394).

.DESCRIPTION
    #3394 a laisse une question ouverte : la schtask MCP-Chain-Watchdog a-t-elle
    seulement tourne pendant les fenetres d'outage (02/09 23:10-00:05Z,
    03/09 01:21-01:44Z) ? Jusqu'ici ses actions ne vivaient que dans un log
    local et l'Event Log local -- invisibles depuis la flotte. Le watchdog
    poste desormais sa telemetrie sur le machine dashboard, mais pour les
    episodes PASSES, la preuve ne peut venir que des logs de l'hote.

    Ce script ne repare rien et ne modifie rien. Il verifie, sur l'HOTE (ai-01) :
      1. Schtask MCP-Chain-Watchdog : existe, activee, derniere execution,
         dernier resultat, fraicheur vs intervalle attendu.
      2. Logs watchdog : comptes par niveau (2 derniers jours par defaut) et
         extraction des lignes non-OK dans une fenetre -From/-To -- c'est la
         preuve "a-t-il tourne pendant l'episode ?".
      3. Schtask MCP-Proxy-RSM : etat, LogonType (Interactive attendu --
         GDrive l'exige), RestartCount (5 par defaut : au-dela d'un crash-loop
         de 5 tentatives, PLUS RIEN ne relance sparfenyuk jusqu'au prochain
         logon -- signature "tombe et rien ne le relance" de #3394).
      4. Processus mcp-proxy + ports 9091/9090 en ecoute.
      5. Conteneur docker myia-mcp-proxy.

    Lecture seule : pas d'elevation requise, executable en session interactive
    ou depuis un agent de l'hote. Coller la sortie sur le dashboard ou l'issue.

.PARAMETER From / To
    Fenetre optionnelle, heure LOCALE de l'hote, format 'yyyy-MM-dd HH:mm'.
    Les timestamps des logs sont locaux ; les fenetres de #3394 sont en UTC
    (ai-01 = UTC+2 debut septembre : 23:10Z = 01:10 local du lendemain).

.EXAMPLE
    .\verify-watchdog-deployment.ps1

.EXAMPLE
    # Fenetre du 2e episode de #3394 (01:21-01:44Z = 03:21-03:44 local UTC+2)
    .\verify-watchdog-deployment.ps1 -From '2026-09-03 03:15' -To '2026-09-03 03:50'
#>
param(
    [string]$WatchdogTask = 'MCP-Chain-Watchdog',
    [string]$ProxyTask    = 'MCP-Proxy-RSM',
    [string]$LogDir       = 'D:\roo-extensions\outputs\mcp-watchdog',
    [int]$ExpectedTickMinutes = 10,
    [int]$LogDays = 2,
    [string]$From,
    [string]$To
)

$ErrorActionPreference = 'Continue'
$script:Fails = 0
$script:Warns = 0

function Add-Result {
    param([string]$Level, [string]$Label, [string]$Detail)
    $color = switch ($Level) {
        'FAIL' { 'Red' }
        'WARN' { 'Yellow' }
        default { 'Green' }
    }
    if ($Level -eq 'FAIL') { $script:Fails++ }
    if ($Level -eq 'WARN') { $script:Warns++ }
    Write-Host ("  [{0,-4}] {1}" -f $Level, $Label) -ForegroundColor $color
    if ($Detail) { Write-Host ("         {0}" -f $Detail) }
}

Write-Host '=== Verif deploiement chain watchdog MCP (#3394) ==='
Write-Host "Hote: $env:COMPUTERNAME  |  $($WatchdogTask) + $($ProxyTask)"
Write-Host ''

# ---------- 1. Schtask watchdog ----------
Write-Host '--- 1. Schtask watchdog ---'
$wdTask = Get-ScheduledTask -TaskName $WatchdogTask -ErrorAction SilentlyContinue
if (-not $wdTask) {
    Add-Result 'FAIL' "schtask $WatchdogTask ABSENTE" "Le watchdog ne tourne pas : c'est la cause la plus probable des episodes non reperes. Reinstaller : scripts\mcp-watchdog\install-watchdog-schtask.ps1 (elevation requise)."
} else {
    $wdInfo = Get-ScheduledTaskInfo -TaskName $WatchdogTask -ErrorAction SilentlyContinue
    $state = $wdTask.State
    if ($state -ne 'Running' -and $state -ne 'Ready') {
        Add-Result 'FAIL' "schtask $WatchdogTask en etat $state" "Enable-ScheduledTask -TaskName '$WatchdogTask'"
    } else {
        Add-Result 'OK' "schtask $WatchdogTask presente ($state)"
    }
    if ($wdInfo) {
        $ageMin = if ($wdInfo.LastRunTime -and $wdInfo.LastRunTime -gt [datetime]::MinValue) {
            [math]::Round(((Get-Date) - $wdInfo.LastRunTime).TotalMinutes, 0)
        } else { -1 }
        if ($ageMin -lt 0) {
            Add-Result 'WARN' 'jamais executee (LastRunTime vide)' 'Verifier les triggers : install-watchdog-schtask.ps1 pose AtStartup + repetition 2 min.'
        } elseif ($ageMin -gt $ExpectedTickMinutes) {
            Add-Result 'WARN' "derniere execution il y a $ageMin min (> ${ExpectedTickMinutes} min attendues)" 'La repetition du trigger est morte ou la tache est bloquee. Get-ScheduledTask -TaskName ' + $WatchdogTask + ' | Select -Expand Triggers'
        } else {
            Add-Result 'OK' "derniere execution il y a $ageMin min"
        }
        if ($wdInfo.LastTaskResult -ne 0) {
            Add-Result 'WARN' "LastTaskResult = 0x$('{0:X}' -f $wdInfo.LastTaskResult)" 'Le dernier tick a exit non-zero : lire les dernieres lignes du log (section 2). Resultat 0x103 = tache tuer par ExecutionTimeLimit (2 min) : une sequence probe+reparation+telemetrie trop lente.'
        } else {
            Add-Result 'OK' 'LastTaskResult = 0'
        }
    }
}
Write-Host ''

# ---------- 2. Logs watchdog ----------
Write-Host '--- 2. Logs watchdog (niveaux) ---'
$since = (Get-Date).AddDays(-$LogDays).ToString('yyyyMMdd')
$logFiles = @()
if (Test-Path $LogDir) {
    $logFiles = Get-ChildItem -Path $LogDir -Filter 'watchdog-*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -replace '^watchdog-', '' -ge $since } |
        Sort-Object Name
}
if (-not $logFiles -or $logFiles.Count -eq 0) {
    Add-Result 'FAIL' "aucun log watchdog recent dans $LogDir (depuis $since)" "Le watchdog n'a JAMAIS ecrit ici : soit la schtask n'existe pas, soit -LogDir ne correspond pas au deploiement."
} else {
    # Write-Log pad le niveau a 5 caracteres ("{1,-5}" -> [OK   ]/[WARN ]) ;
    # seul [ERROR] (5 lettres) ne porte pas de pad. Une regex qui exige ']'
    # immediat ne voit que les ERROR : mesure ai-01 03/09, 57/675 lignes
    # visibles et le verdict "watchdog MUET" devenait le comportement nominal
    # (revue po-2026, confirme ai-01). [A-Z]+? + \s* couvre les deux formes ;
    # le .{0,3}? absorbe le BOM que PS 5.1 Add-Content -Encoding utf8 ecrit en
    # tete du fichier du jour (1 ligne/jour, ai-01 03/09).
    $LogLineRx = '^.{0,3}?(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\S+) \[([A-Z]+?)\s*\]'
    $levelCounts = @{}
    $allLines = New-Object System.Collections.Generic.List[string]
    foreach ($f in $logFiles) {
        foreach ($line in (Get-Content -Path $f.FullName -Encoding utf8 -ErrorAction SilentlyContinue)) {
            $allLines.Add($line)
            if ($line -match $LogLineRx) {
                $lv = $matches[2]
                if (-not $levelCounts.ContainsKey($lv)) { $levelCounts[$lv] = 0 }
                $levelCounts[$lv]++
            }
        }
    }
    $summary = ($levelCounts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '  '
    Add-Result 'OK' "$($logFiles.Count) fichier(s), $($allLines.Count) lignes : $summary"

    # Fenetre optionnelle : preuve "a-t-il tourne pendant l'episode ?"
    if ($From -and $To) {
        # PS 5.1: le [ref] exige une variable TYPee, sinon la resolution
        # d'overload de TryParseExact echoue (mesure po-204, 5.1.26100).
        [datetime]$fromTs = [datetime]::MinValue
        [datetime]$toTs   = [datetime]::MinValue
        $parsedFrom = [datetime]::TryParseExact($From, 'yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$fromTs)
        $parsedTo   = [datetime]::TryParseExact($To,   'yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$toTs)
        if (-not ($parsedFrom -and $parsedTo)) {
            Add-Result 'WARN' 'fenetre -From/-To illisible (attendu yyyy-MM-dd HH:mm)' 'Ignorer la suite de la section fenetre.'
        } else {
            Write-Host ''
            Write-Host "  Fenetre $From -> $To (heure locale) :"
            $inWindow = New-Object System.Collections.Generic.List[string]
            foreach ($line in $allLines) {
                if ($line -match $LogLineRx) {
                    $ts = [datetime]::MinValue
                    if ([datetime]::TryParseExact($matches[1], 'yyyy-MM-ddTHH:mm:sszzz', [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$ts)) {
                        if ($ts -ge $fromTs -and $ts -le $toTs) { $inWindow.Add($line) }
                    }
                }
            }
            if ($inWindow.Count -eq 0) {
                Add-Result 'FAIL' 'watchdog MUET pendant la fenetre (0 ligne loggee)' 'Pendant cet episode, la schtask n''a pas tourne : cause premiere a traiter (absente/desactivee/trigger mort).'
            } else {
                $okCount  = ($inWindow | Where-Object { $_ -match '\[OK\s*\]' }).Count
                $badCount = $inWindow.Count - $okCount
                Write-Host "  ---- extrait non-OK ($badCount lignes) + 3 dernieres OK ($okCount lignes OK au total) ----"
                $inWindow | Where-Object { $_ -notmatch '\[OK\s*\]' } | Select-Object -First 15 | ForEach-Object { Write-Host "    $_" }
                $inWindow | Where-Object { $_ -match '\[OK\s*\]' } | Select-Object -Last 3 | ForEach-Object { Write-Host "    $_" }
                if ($okCount -gt 0 -and $badCount -eq 0) {
                    Add-Result 'WARN' "watchdog vivant mais sonde VERTE pendant la fenetre ($okCount OK)" 'Il a juge la chaine saine pendant que les bots etaient refuses : divergence de chemin (sonde via :9090 vs bots via :9091) a instruire.'
                } elseif ($badCount -gt 0) {
                    Add-Result 'OK' "watchdog Present pendant la fenetre ($badCount lignes non-OK loggees)" 'Il a vu la panne : verifier si une reparation a suivi (lignes WARN 'running full repair sequence' / 'recovered').'
                }
            }
        }
    }
}
Write-Host ''

# ---------- 3. Schtask proxy hote (sparfenyuk :9091) ----------
Write-Host '--- 3. Schtask proxy hote (sparfenyuk :9091) ---'
$pxTask = Get-ScheduledTask -TaskName $ProxyTask -ErrorAction SilentlyContinue
if (-not $pxTask) {
    Add-Result 'FAIL' "schtask $ProxyTask ABSENTE" "Rien n'expose :9091. Reinstaller : scripts\infra\mcp-proxy-host\Install-RooStateManagerProxy.ps1 (elevation + session utilisateur GDrive)."
} else {
    $pxInfo = Get-ScheduledTaskInfo -TaskName $ProxyTask -ErrorAction SilentlyContinue
    Add-Result 'OK' "schtask $ProxyTask presente ($($pxTask.State))"
    Add-Result 'OK' ("LogonType=$($pxTask.Principal.LogonType)  RestartCount=$($pxTask.Settings.RestartCount) x $($pxTask.Settings.RestartInterval)")
    if ($pxTask.State -ne 'Running') {
        Add-Result 'FAIL' "schtask $ProxyTask pas Running ($($pxTask.State))" "C'est l'etat qui produit 'connection refused' sur host.docker.internal:9091 (#3394). Start-ScheduledTask -TaskName '$ProxyTask'"
    } else {
        Add-Result 'OK' 'schtask Running'
    }
    if ($pxInfo -and $pxInfo.LastTaskResult -ne 0) {
        Add-Result 'WARN' "LastTaskResult = 0x$('{0:X}' -f $pxInfo.LastTaskResult)" 'Le process mcp-proxy a exit non-zero : crash probable (voir section cause racine #3394 -- crash-loop au-dela du budget RestartCount).'
    }
    if ($pxTask.Settings.RestartCount -le 5) {
        Add-Result 'WARN' "budget de restart = $($pxTask.Settings.RestartCount)" "Au-dela d'un crash-loop de $($pxTask.Settings.RestartCount) tentatives, RIEN ne relance sparfenyuk jusqu'au prochain logon -- le chain watchdog est le seul filet."
    }
}
Write-Host ''

# ---------- 4. Processus + ports ----------
Write-Host '--- 4. Processus mcp-proxy + ports ---'
$proc = Get-Process mcp-proxy -ErrorAction SilentlyContinue
if ($proc) {
    Add-Result 'OK' "processus mcp-proxy PID=$($proc.Id) (depuis $($proc.StartTime))"
} else {
    Add-Result 'FAIL' 'processus mcp-proxy ABSENT' 'sparfenyuk ne tourne pas : :9091 refuse les connexions.'
}
foreach ($port in @(9091, 9090)) {
    $listen = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($listen) {
        Add-Result 'OK' "port $port en ecoute ($($listen.LocalAddress))"
    } else {
        Add-Result 'FAIL' "port $port PAS en ecoute" $(if ($port -eq 9090) { 'TBXark docker down : docker start myia-mcp-proxy' } else { 'sparfenyuk down : voir section 3.' })
    }
}
Write-Host ''

# ---------- 5. Conteneur docker ----------
Write-Host '--- 5. Conteneur docker myia-mcp-proxy ---'
$dockerOut = & docker ps --filter 'name=myia-mcp-proxy' --format '{{.Names}} | {{.Status}}' 2>&1
if ($LASTEXITCODE -ne 0 -or -not $dockerOut) {
    Add-Result 'WARN' "docker injoignable ou conteneur absent ($($dockerOut -join ' '))" 'Verifier : docker ps -a --filter name=myia-mcp-proxy'
} else {
    Add-Result 'OK' "conteneur: $($dockerOut -join ' ')"
}
Write-Host ''

# ---------- Verdict ----------
Write-Host '=== Verdict ==='
if ($script:Fails -gt 0) {
    Write-Host "  $($script:Fails) FAIL, $($script:Warns) WARN -- defaut(s) de deploiement confirmes. Coller cette sortie sur l'issue #3394 / dashboard." -ForegroundColor Red
    exit 1
} elseif ($script:Warns -gt 0) {
    Write-Host "  0 FAIL, $($script:Warns) WARN -- deploiement vivant, points a instruire ci-dessus." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host '  Tout vert : watchdog et proxy deployes et vivants.' -ForegroundColor Green
    exit 0
}

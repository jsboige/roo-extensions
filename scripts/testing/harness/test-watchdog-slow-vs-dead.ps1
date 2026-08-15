# Static harness: mcp-chain-watchdog.ps1 must not confuse SLOW with DEAD, and
# must not grant its "the wedge is upstream" verdict on a difference of text.
#
# Why this file exists (measured on ai-01, 2026-08-16, 30 probes):
#   nominal round-trip .......... 589 ms (p50)
#   slowest SUCCESSFUL probe .... 23_164 ms  <-- past the 20 s budget
#   the failure it hunts ........ 200 + isError:true in under 100 ms
# So the outage signature is FAST-and-wrong while the false alarm is
# SLOW-and-right, and a bare Ok=$false collapses the two. At 00:48 that cost a
# full destructive chain restart (stop task + restart sparfenyuk + restart
# container, dropping every live bot session) for a stall that cleared itself by
# 00:52. Four minutes later the same script called the same state healthy.
#
# The second guard: the differential probe used to read $e2eUrl -ne $lanUrl.
# On this host MCP_PROXY_BASE_URL is http://host.docker.internal:9090 and
# host.docker.internal resolves to 192.168.0.47 -- ai-01 itself. Two spellings,
# one hop. The verdict built on the string difference logged "wedge is upstream
# of ai-01 (IIS/ARR on po-2023)", naming a machine absent from the path.
#
# Pure: reads the production script as text + AST. No network, no scheduler, no
# Docker -- runs on ubuntu-latest pwsh like the other wired harnesses.

$ErrorActionPreference = 'Stop'
$script:Fails = 0

function Assert-That([string]$Label, [bool]$Condition) {
    if ($Condition) { Write-Host "  OK   $Label" }
    else { $script:Fails++; Write-Host "  FAIL $Label" -ForegroundColor Red }
}

# Forme chaine et non Join-Path multi-arguments : sous Windows PowerShell 5.1,
# Join-Path n'accepte que DEUX arguments et le harnais meurt avant sa premiere
# assertion. CI tourne pwsh 7 et ne verrait jamais la difference -- un harnais
# qui ne demarre pas chez l'humain qui le lance est un harnais qui ne sert pas.
$Target = [System.IO.Path]::GetFullPath("$PSScriptRoot/../../mcp-watchdog/mcp-chain-watchdog.ps1")
Write-Host "=== watchdog slow-vs-dead harness ==="
Write-Host "Target: $Target"

if (-not (Test-Path $Target)) {
    Write-Host "  FAIL mcp-chain-watchdog.ps1 introuvable" -ForegroundColor Red
    exit 1
}

$Text = Get-Content $Target -Raw
$ParseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($Target, [ref]$null, [ref]$ParseErrors)
Assert-That "le script production parse sans erreur" (@($ParseErrors).Count -eq 0)

# --- 1. Un timeout est signale comme tel, et mesure sur le TEMPS ------------
# Ancre sur le RETURN : -match est insensible a la casse, donc un simple
# 'TimedOut\s*=' est satisfait par la ligne de calcul "$timedOut = ..." et reste
# vert meme si la sonde cesse de rendre la cle a son appelant. Mesure : en
# renommant la cle en Dummy, cette assertion ne rougissait pas.
Assert-That "la sonde REND TimedOut a son appelant"      ($Text -match 'return[^\r\n]*TimedOut[ \t]*=[ \t]*\$timedOut')
# Pas d'alternative "TimedOut = $timedOut" ici : elle serait vraie quelle que
# soit la FACON dont $timedOut est calcule -- c'est la cle de hashtable qu'elle
# verifie, pas la decision. Seule la ligne de calcul compte.
Assert-That "TimedOut se decide sur ElapsedMilliseconds" ($Text -match '\$timedOut\s*=[^\r\n]*ElapsedMilliseconds')

# Contre-epreuve de localisation : cette machine a logge le timeout en francais
# ("Le delai d'attente de l'operation a expire"). Un harnais qui accepterait un
# match sur le message d'exception validerait un garde muet sur un hote en_US.
Assert-That "TimedOut ne depend PAS du message d'exception" `
    (-not ($Text -match '(?i)(timed?\s?out|expired|delai)[^\r\n]{0,40}-match|Exception\.Message\s*-match'))

# --- 2. Un timeout donne droit a une RETENTE, pas a une reparation ---------
Assert-That "un budget de retente existe"                ($Text -match '\$SlowRetryTimeoutSec\s*=\s*(\d+)')
if ($Text -match '\$SlowRetryTimeoutSec\s*=\s*(\d+)') {
    $retry = [int]$matches[1]
    # Doit couvrir le plus lent SUCCES jamais observe (23_164 ms), sinon la
    # retente re-tombe dans le meme piege que le budget qu'elle corrige.
    Assert-That "le budget de retente couvre le succes le plus lent observe (>= 24s)" ($retry -ge 24)
    Assert-That "le budget de retente reste borne (<= 180s)"                          ($retry -le 180)
}
Assert-That "la retente est conditionnee par TimedOut"   ($Text -match '\$result\.TimedOut[\s\S]{0,400}?Invoke-McpProbe[^\r\n]*SlowRetryTimeoutSec')

# Revue po-2025 sur cette PR (F1, medium) : la retente ci-dessus ne couvrait que
# la sonde E2E. Or la sonde qui DECIDE la reparation est Test-Lan -- 20 s, sans
# retente, et la branche de reparation n'avait aucune sortie sur TimedOut. Un
# blocage GDrive vivant plus de 20+60+20 s retombait donc dans la meme sequence
# destructive, cent secondes plus tard. La classe d'incident du 00:48 etait
# retrecie, pas fermee.
Assert-That "la sonde LAN a AUSSI droit a une retente" `
    ($Text -match '\$lanResult\.TimedOut[\s\S]{0,600}?Invoke-McpProbe[^\r\n]*\$lanUrl[^\r\n]*SlowRetryTimeoutSec')
# Et la moitie qui compte : apres la retente, un timeout NE DOIT PAS conduire a
# la reparation. Ancre sur la branche elle-meme, et sur le fait qu'elle precede
# le bloc destructif -- une garde placee apres ne garderait rien.
Assert-That "un timeout LAN persistant DIFFERE la reparation" `
    ($Text -match 'elseif[ \t]*\([ \t]*\$lanResult\.TimedOut[ \t]*\)[\s\S]{0,900}?elseif[ \t]*\([ \t]*\$repairOnCooldown')

# --- 3. Le verdict amont se decide sur le HOP, pas sur la chaine -----------
Assert-That "Test-UrlIsLocalHop existe"                  ($Text -match 'function\s+Test-UrlIsLocalHop\b')
# Ancre sur la COMPARAISON, pas sur la chaine : "127.0.0.1" apparait aussi dans
# $lanUrl en tete de fichier, donc chercher la chaine seule laisserait passer la
# suppression du test de loopback.
Assert-That "le loopback compte comme local"             ($Text -match "-eq[ \t]*'127\.0\.0\.1'")
Assert-That "les adresses de la machine comptent comme locales" ($Text -match 'GetHostAddresses\(\[System\.Net\.Dns\]::GetHostName\(\)\)')
Assert-That "le garde amont consomme la comparaison de hops" ($Text -match '\$lanResult\.Ok\s+-and\s+\$probesAreDistinctHops')

# La regression exacte a interdire : re-brancher le verdict amont sur l'egalite
# textuelle des URLs. C'est ce qui a produit l'accusation de po-2023.
# Libelle en quote SIMPLE : en double quote, PowerShell n'echappe pas avec
# l'antislash (c'est le backtick), donc "\$e2eUrl" interpole une variable vide
# et le libelle s'affiche "\ -ne \". Un test dont l'intitule est illisible ne
# dit rien a qui le voit rougir. Meme piege que dans le harnais voisin, refait
# ici le lendemain -- d'ou ce commentaire plutot qu'une correction muette.
Assert-That 'le verdict amont n''est PLUS branche sur $e2eUrl -ne $lanUrl' `
    (-not ($Text -match '\$lanResult\.Ok\s+-and\s+\$e2eUrl\s+-ne\s+\$lanUrl'))

# --- 4. La moitie qui fait de ceci un garde et non un tally ----------------
# Un "correctif" qui ne repare plus JAMAIS rien passerait tout ce qui precede
# tout en re-ouvrant la panne de 2,5 jours que ce watchdog existe pour voir.
# La sequence destructive doit rester atteignable, et la signature rapide
# (isError:true, backend vivant / instance morte) doit rester detectee.
#
# ATTENTION -- ces cinq assertions ont ete reecrites apres contre-epreuve.
# La premiere version cherchait 'docker\s+restart\s+myia-mcp-proxy' n'importe ou
# dans le fichier. En .NET, \s traverse les sauts de ligne, et l'en-tete du script
# porte "...puis docker restart\n  myia-mcp-proxy (stale session TBXark #2023)".
# Resultat mesure : en remplacant la VRAIE commande par 'docker ps', le harnais
# restait VERT -- il validait un commentaire de documentation. C'est exactement
# le defaut que ce fichier existe pour interdire, commis dans le fichier lui-meme.
# Donc : ancrage sur le code executable (& = operateur d'appel, condition de
# verdict) et classes horizontales [ \t] qui ne franchissent pas la ligne.
Assert-That "la sequence de reparation existe encore"    ($Text -match "[ \t]Stop-ScheduledTask[ \t]+-TaskName[ \t]+'MCP-Proxy-RSM'")
Assert-That "le restart du conteneur est APPELE (pas juste cite en commentaire)" `
    ($Text -match '&[ \t]+docker[ \t]+restart[ \t]+myia-mcp-proxy')
# Les deux marqueurs du verdict "sain" se lisent sur la MEME ligne que le 200 :
# un 200 ne suffit pas, il faut le marqueur dashboards ET l'absence d'isError.
Assert-That "isError:true interdit toujours le verdict sain" `
    ($Text -match 'StatusCode[ \t]+-eq[ \t]+200[^\r\n]*-notmatch[^\r\n]*isError')
Assert-That "le marqueur dashboards est toujours exige"  ($Text -match 'StatusCode[ \t]+-eq[ \t]+200[^\r\n]*-match[ \t]*.{0,3}dashboards')
# Revue po-2025 (F2) : ce test acceptait n'importe quel \d+, donc un cooldown de
# 0 le laissait vert -- et un cooldown de 0 EST la tempete de restarts que la
# variable existe pour empecher, sur une tache qui tire toutes les 2 minutes.
# Verifier qu'une valeur est ecrite n'est pas verifier qu'elle protege : meme
# defaut que celui qui a produit les 4 assertions sans dents de ce fichier.
Assert-That "le cooldown anti-restart-storm survit"      ($Text -match '\$RepairCooldownMin[ \t]*=[ \t]*(\d+)')
if ($Text -match '\$RepairCooldownMin[ \t]*=[ \t]*(\d+)') {
    $cooldown = [int]$matches[1]
    # Plancher : la tache tire toutes les 2 min et chaque reparation coute toutes
    # les sessions bot vivantes. Sous 5 min, le cooldown ne freine plus rien.
    Assert-That "le cooldown est un vrai frein (>= 5 min)"  ($cooldown -ge 5)
    Assert-That "le cooldown reste borne (<= 240 min)"      ($cooldown -le 240)
}

# Revue po-2025 (F3) : le verdict amont ne compare plus des chaines, mais son
# message nommait toujours "IIS/ARR sur po-2023" -- exactement l'attribution que
# le garde de hop a ete ecrit pour cesser de produire. Cette sonde ne sait qu'une
# chose : la panne n'est pas dans SON backend. Ancre sur les lignes emises
# (Write-Log), pas sur le fichier entier : l'en-tete de doc cite l'ancien message
# comme piece a conviction et doit pouvoir continuer de le faire.
Assert-That "aucun message emis n'accuse une machine de la flotte" `
    (-not ($Text -match "(?m)^[^\r\n]*Write-Log[^\r\n]*(po-20\d\d|web1|ai-01)"))

Write-Host ""
if ($script:Fails -eq 0) { Write-Host "TOUT VERT" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:Fails) ECHEC(S)" -ForegroundColor Red; exit 1 }

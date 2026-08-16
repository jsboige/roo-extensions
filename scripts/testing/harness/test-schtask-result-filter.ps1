# Static harness: report-failed-scheduled-tasks.ps1 must exclude exactly the
# result codes that are NOT failures -- no more, no less.
#
# What this pins (measured ai-01 2026-08-15, 223 tasks, 22 non-zero, 5 real):
#   0x800710E0  Claude-DashboardListener, State=Running, heartbeat 3 min old.
#               The scheduler refuses a second instance every 15 minutes because
#               the listener is alive. Drop this exclusion and the sweep
#               denounces the WAKE listener four times an hour.
#   267009/11   already recorded in machine memory as a standing misread:
#               "running" and "never ran" are not "failed".
# The opposite failure mode is just as real: an exclusion list that grows until
# it swallows RC=1 reports nothing while looking healthy. Hence the negative
# assertions -- they are the half that makes this a guard rather than a tally.
#
# Pure: reads the production script as text + AST, no scheduler access. Runs on
# ubuntu-latest pwsh like the other wired harnesses, so it must NOT dot-source
# the target (that would execute Get-ScheduledTask, which does not exist there).

$ErrorActionPreference = 'Stop'
$script:Fails = 0

function Assert-That([string]$Label, [bool]$Condition) {
    if ($Condition) { Write-Host "  OK   $Label" }
    else { $script:Fails++; Write-Host "  FAIL $Label" -ForegroundColor Red }
}

# Forme chaine, PAS Join-Path multi-arguments : sous Windows PowerShell 5.1,
# Join-Path n'accepte que DEUX arguments et le harnais meurt sur
# "Impossible de trouver un parametre positionnel acceptant l'argument .." --
# avant sa premiere assertion. La CI tourne pwsh 7 et ne verrait jamais la
# difference ; un harnais qui ne demarre pas chez l'humain qui le lance ne sert
# a rien. Constate en le lancant sous les deux editions.
$Target = [System.IO.Path]::GetFullPath("$PSScriptRoot/../../maintenance/report-failed-scheduled-tasks.ps1")
Write-Host "=== scheduled-task result filter harness ==="
Write-Host "Target: $Target"

if (-not (Test-Path $Target)) {
    Write-Host "  FAIL report-failed-scheduled-tasks.ps1 introuvable" -ForegroundColor Red
    exit 1
}

$Text = Get-Content $Target -Raw
$ParseErrors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile($Target, [ref]$null, [ref]$ParseErrors)
Assert-That "le script production parse sans erreur" (@($ParseErrors).Count -eq 0)

# --- 1. La liste d'exclusions, lue dans l'AST de production ------------------
# On evalue le litteral ecrit dans le script, pas une copie : si quelqu'un
# raccourcit la liste (ou l'elargit), ce test rougit.
$Assign = $Ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left.Extent.Text -eq '$BenignTaskResults'
}, $true) | Select-Object -First 1

if (-not $Assign) {
    $script:Fails++
    Write-Host "  FAIL affectation `$BenignTaskResults introuvable dans l'AST" -ForegroundColor Red
} else {
    $Codes = @($Assign.Right.FindAll({
        param($n) $n -is [System.Management.Automation.Language.ConstantExpressionAst]
    }, $true) | ForEach-Object { [int64]$_.Value })

    # Les quatre codes benins mesures.
    Assert-That "0 (succes) est exclu"                          ($Codes -contains 0)
    Assert-That "267009 SCHED_S_TASK_RUNNING est exclu"         ($Codes -contains 267009)
    Assert-That "267011 SCHED_S_TASK_HAS_NOT_RUN est exclu"     ($Codes -contains 267011)
    Assert-That "2147946720 (0x800710E0, instance deja en cours) est exclu" ($Codes -contains 2147946720)

    # Contre-epreuve : les codes des echecs REELS observes sur ai-01 le 15/08
    # ne doivent JAMAIS entrer dans la liste. Sans ces trois lignes, une liste
    # qui avale tout passerait le test ci-dessus tout en ne rapportant rien.
    Assert-That "RC=1 (Qdrant-Snapshot-Daily, Claude-Worker) n'est PAS exclu"  (-not ($Codes -contains 1))
    Assert-That "RC=8 (Mount-Qdrant-VHDX) n'est PAS exclu"                     (-not ($Codes -contains 8))
    Assert-That "RC=2 n'est PAS exclu"                                         (-not ($Codes -contains 2))
    Assert-That "la liste reste courte (<= 8 codes)"                           ($Codes.Count -le 8)
}

# --- 2. Le predicat doit consommer la liste, pas une copie inline -----------
Assert-That "Test-BenignTaskResult existe"                ($Text -match 'function\s+Test-BenignTaskResult')
Assert-That "le predicat lit `$BenignTaskResults"          ($Text -match 'Test-BenignTaskResult[\s\S]{0,2500}?\$script:BenignTaskResults')
Assert-That "la boucle de balayage appelle le predicat"   ($Text -match 'Test-BenignTaskResult\s+-ResultCode')

# --- 3. Le perimetre par defaut exclut les arbres OS/OEM --------------------
# Motif en chaine SIMPLE quote : en double quote, l'echappement PowerShell est le
# backtick et non l'antislash, donc '\\\\' resterait quatre antislashes et le motif
# chercherait '\\' la ou la production ecrit '\'. Premiere version rouge pour cette
# raison exacte -- le harnais a mordu sur son propre auteur.
Assert-That "un garde de perimetre existe"                ($Text -match 'function\s+Test-OwnedTask\b')
Assert-That "le perimetre par defaut est la racine"       ($Text -match 'TaskPath\s+-ne\s+''\\''')

# Le chemin racine NE SUFFIT PAS : la tache de mise a jour OneDrive s'y enregistre
# aussi, avec un suffixe par SID. Constate a la premiere execution reelle, ou elle
# figurait parmi les 6 resultats a cote de nos 5 vraies pannes. Sans cette seconde
# condition le rapport porte une ligne de bruit quotidienne.
Assert-That "le garde filtre aussi par NOM"               ($Text -match '\$ForeignRootTaskPatterns')

# Les motifs sont evalues depuis l'AST puis appliques a de VRAIS noms de taches
# mesures sur la flotte, au lieu d'etre compares comme du texte. La premiere
# version de ce test epinglait la chaine 'OneDrive Standalone Update Task' : elle
# etait verte pendant que le motif ratait la variante de po-2023
# ('OneDrive Per-Machine Standalone Update Task'), ou le fabricant insere deux
# mots au milieu. Verifier l'ORTHOGRAPHE d'un motif ne dit rien de ce qu'il
# attrape -- seul un -like contre le nom reel le dit.
$Foreign = $Ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left.Extent.Text -eq '$ForeignRootTaskPatterns'
}, $true) | Select-Object -First 1

if (-not $Foreign) {
    $script:Fails++
    Write-Host "  FAIL affectation `$ForeignRootTaskPatterns introuvable dans l'AST" -ForegroundColor Red
} else {
    $Patterns = @($Foreign.Right.FindAll({
        param($n) $n -is [System.Management.Automation.Language.ConstantExpressionAst]
    }, $true) | ForEach-Object { [string]$_.Value })

    function Test-MatchesAny([string]$Name) {
        foreach ($p in $Patterns) { if ($Name -like $p) { return $true } }
        return $false
    }

    # Noms observes, pas inventes : ai-01 le 15/08, po-2023 en revue de cette PR.
    Assert-That "la variante ai-01 (suffixe par SID) est attrapee" `
        (Test-MatchesAny 'OneDrive Standalone Update Task-S-1-5-21-1234567890-1234567890-1234567890-1001')
    Assert-That "la variante po-2023 (Per-Machine) est attrapee" `
        (Test-MatchesAny 'OneDrive Per-Machine Standalone Update Task')
    Assert-That "NahimicTask64 (0xC0000005, po-2023) est attrapee" `
        (Test-MatchesAny 'NahimicTask64')
    Assert-That "NahimicTask32 (0x40010004, po-204) est attrapee" `
        (Test-MatchesAny 'NahimicTask32')

    # La contre-epreuve : un motif assez large pour avaler les notres rendrait
    # le rapport vide tout en restant vert ci-dessus.
    Assert-That "Claude-DashboardListener n'est PAS avale"    (-not (Test-MatchesAny 'Claude-DashboardListener'))
    Assert-That "Qdrant-Snapshot-Daily n'est PAS avale"       (-not (Test-MatchesAny 'Qdrant-Snapshot-Daily'))
    Assert-That "MCP-Proxy-RSM n'est PAS avale"               (-not (Test-MatchesAny 'MCP-Proxy-RSM'))
}
Assert-That "le garde consomme nom ET chemin"             ($Text -match 'Test-OwnedTask\s+-TaskPath\s+\$task\.TaskPath\s+-TaskName\s+\$task\.TaskName')

# --- 4. Un resultat fige n'est pas une panne a rapporter --------------------
# Datapoint web1 sur cette PR (2026-08-15) : 2 de ses 3 resultats etaient des
# taches Disabled portant un code fige -- elles reapparaitraient a chaque
# execution, indefiniment. ai-01 n'en a aucune, donc cette regle est couverte
# ICI et pas par la liste vivante de la machine qui l'ecrit.
Assert-That "un garde d'etat fige existe"                 ($Text -match 'function\s+Test-FrozenTaskState\b')
Assert-That "le garde vise Disabled"                      ($Text -match "\`$State\s+-eq\s+'Disabled'")
Assert-That "la boucle consomme le garde d'etat"          ($Text -match 'Test-FrozenTaskState\s+-State')
# L'ordre est la moitie qui compte : place AVANT le filtre de codes benins, le
# compteur dirait "taches desactivees" au lieu de "taches desactivees qui
# auraient ete rapportees" -- un nombre que personne ne peut utiliser.
Assert-That "le garde d'etat vient APRES le filtre de codes" `
    ($Text -match 'Test-BenignTaskResult\s+-ResultCode[\s\S]{0,600}?Test-FrozenTaskState\s+-State')
# Rien de silencieux : ce qui est ecarte est compte et nomme dans les DEUX
# sorties, sinon le rapport se lit "rien a signaler" alors qu'il a jete des
# lignes.
Assert-That "l'exclusion est rapportee en markdown"       ($Text -match '\$frozen\.Count[^\r\n]*\r?\n[^\r\n]*désactivée|désactivée[^\r\n]*\$frozen')
Assert-That "l'exclusion est rapportee en console"        ($Text -match 'Write-Host[^\r\n]*disabled task\(s\)[^\r\n]*\$frozen')

# --- 5. Discipline de code de sortie ---------------------------------------
# Un moniteur qui rend non-zero quand il TROUVE quelque chose se denonce
# lui-meme au balayage suivant s'il est un jour planifie.
$ExitCodes = [regex]::Matches($Text, '(?m)^\s*exit\s+(\d+)') | ForEach-Object { $_.Groups[1].Value }
Assert-That "aucun exit non-zero sur decouverte" (@($ExitCodes | Where-Object { $_ -ne '0' }).Count -eq 0)

Write-Host ""
if ($script:Fails -eq 0) { Write-Host "TOUT VERT" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:Fails) ECHEC(S)" -ForegroundColor Red; exit 1 }

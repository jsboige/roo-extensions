# Static harness: start-meta-audit.ps1 must resolve `claude` to a LAUNCHABLE image.
#
# The defect this pins (measured ai-01 2026-08-13, meta-audit-20260813-193527.log):
#   $ClaudeCmd = (Get-Command claude).Source   -> C:\...\npm\claude.ps1  (ExternalScript)
#   Start-Process -FilePath $ClaudeCmd         -> "%1 n'est pas une application Win32 valide"
# The meta-audit then exit 1'd in ~2s, every run, silently (wscript //B eats stderr).
#
# Pure: reads the production script as text + AST, no network/disk/schtask. Runs on
# ubuntu-latest pwsh like the other wired harnesses, so it must not depend on Windows.
# Deliberately file-wide, not scoped to the assignment line: a line-scoped guard is
# bypassed by a here-string or a rename (lesson from #3116).

$ErrorActionPreference = 'Stop'
$script:Fails = 0

function Assert-That([string]$Label, [bool]$Condition) {
    if ($Condition) { Write-Host "  OK   $Label" }
    else { $script:Fails++; Write-Host "  FAIL $Label" -ForegroundColor Red }
}

$Target = Join-Path $PSScriptRoot '..' '..' 'scheduling' 'start-meta-audit.ps1'
$Target = [System.IO.Path]::GetFullPath($Target)
Write-Host "=== meta-audit claude resolution harness ==="
Write-Host "Target: $Target"

if (-not (Test-Path $Target)) {
    Write-Host "  FAIL start-meta-audit.ps1 introuvable" -ForegroundColor Red
    exit 1
}

$Text = Get-Content $Target -Raw
$ParseErrors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile($Target, [ref]$null, [ref]$ParseErrors)
Assert-That "le script production parse sans erreur" (@($ParseErrors).Count -eq 0)

# --- 1. Le defaut exact ne doit pas revenir, sous aucune forme ---------------
# `(Get-Command claude ...).Source` sans filtre d'extension : c'est la forme qui a
# rendu claude.ps1 et tue l'audit. Tolere `claude.cmd`, qui est deja un shim lancable.
$NakedResolve = [regex]::Matches($Text, '\(\s*Get-Command\s+claude\s+[^)]*\)\s*\.Source')
Assert-That "aucun (Get-Command claude).Source nu (forme fautive)" ($NakedResolve.Count -eq 0)

# --- 2. La garde qui compte : l'extension, pas la presence dans le PATH ------
Assert-That "le script filtre sur l'extension (GetExtension)" ($Text -match 'GetExtension')
Assert-That "une liste d'extensions lancables est definie" ($Text -match '\$LaunchableExt')
Assert-That "le shim claude.cmd est parmi les candidats" ($Text -match 'Get-Command\s+claude\.cmd')

# --- 3. Le contenu reel de la liste, lu dans l'AST de production -------------
# On evalue le litteral ecrit dans le script, pas une copie : si quelqu'un ajoute
# '.ps1' aux extensions lancables, ce test rougit.
$Assign = $Ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left.Extent.Text -eq '$LaunchableExt'
}, $true) | Select-Object -First 1

if (-not $Assign) {
    $script:Fails++
    Write-Host "  FAIL affectation `$LaunchableExt introuvable dans l'AST" -ForegroundColor Red
} else {
    $Exts = @($Assign.Right.FindAll({
        param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst]
    }, $true) | ForEach-Object { $_.Value.ToLowerInvariant() })

    Assert-That "'.ps1' n'est PAS une extension lancable"  (-not ($Exts -contains '.ps1'))
    Assert-That "'.cmd' EST une extension lancable"        ($Exts -contains '.cmd')
    Assert-That "'.exe' EST une extension lancable"        ($Exts -contains '.exe')
    Assert-That "la liste n'est pas vide"                  ($Exts.Count -gt 0)

    # Le predicat de production, applique aux chemins reels de la machine ai-01.
    $Reject = 'C:\Users\MYIA\AppData\Roaming\npm\claude.ps1'
    $Accept = 'C:\Users\MYIA\AppData\Roaming\npm\claude.cmd'
    Assert-That "le predicat rejette claude.ps1" (-not ([System.IO.Path]::GetExtension($Reject).ToLowerInvariant() -in $Exts))
    Assert-That "le predicat accepte claude.cmd" ([System.IO.Path]::GetExtension($Accept).ToLowerInvariant() -in $Exts)
}

# --- 4. Le Start-Process doit consommer la variable gardee ------------------
Assert-That "Start-Process lance bien `$ClaudeCmd" ($Text -match 'Start-Process\s+-FilePath\s+\$ClaudeCmd')

Write-Host ""
if ($script:Fails -eq 0) { Write-Host "TOUT VERT" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:Fails) ECHEC(S)" -ForegroundColor Red; exit 1 }

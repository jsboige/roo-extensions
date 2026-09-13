# Regression harness: start-meta-audit.ps1 must aim its step-1 trace collection at the
# ACTIVE extension's tasks/ directory, selected by Get-ActiveExtension -- not a hardcoded
# RooCode literal (#3006 / #3135 follow-up).
#
# The defect this pins: the selection line used to read
#   $rooTasksPath = Get-GlobalStoragePath -Extension RooCode | Join-Path -ChildPath "tasks"
# On a migrated host (Zoo active, roo-cline globalStorage surviving as an empty shell -- the
# exact host shape the probe rationale in scripts/common/extension-paths.ps1 documents), the
# meta-analyst was pointed at the wrong tasks/ directory while the live traces sat next door.
#
# Where the sibling metaaudit harnesses are static (text + AST), this one is DYNAMIC: it
# executes the real selection statements and the real $Prompt here-string EXTRACTED FROM THE
# PRODUCTION AST, under fixture %APPDATA% roots in a temp dir. A revert to a RooCode literal
# makes the $ActiveExtension assignment disappear from the AST -> static assert red and the
# dynamic section is skipped. It never reads real host state ($env:APPDATA is overridden and
# restored in finally), never spawns claude, never runs schtask, never invokes the production
# script itself -- only the extracted assignment statements.
#
# Fixture matrix, pinned to the CURRENT Get-ActiveExtension contract:
#   roo-only -> RooCode   (roo settings/mcp_settings.json exists)
#   zoo-only -> ZooCode   (zoo settings only)  <-- THE discriminating case vs baseline
#   both     -> RooCode   (back-compat preference on dual-install hosts)
#   neither  -> RooCode   (default fallback, mirrors the TS probe)
# A literal swap RooCode->ZooCode is NOT a fix: per this contract it fails roo-only, both
# AND neither -- only the probe passes all four.
#
# Runs under Windows PowerShell 5.1 and pwsh 7 (no PS7-only syntax). The engine version is
# printed first so scheduled runs identify which PowerShell executed the matrix.

$ErrorActionPreference = 'Stop'
$script:Fails = 0

function Assert-That([string]$Label, [bool]$Condition) {
    if ($Condition) { Write-Host "  OK   $Label" }
    else { $script:Fails++; Write-Host "  FAIL $Label" -ForegroundColor Red }
}

Write-Host "=== meta-audit active-extension selection harness ==="
Write-Host "Engine: PowerShell $($PSVersionTable.PSVersion)"

# PS 5.1: Join-Path takes exactly 2 positional args (-AdditionalChildPath is PS 6.2+), so the
# multi-arg form used by the sibling harnesses would not even bind here. Path.Combine carries
# the same traversal with 2-arg safety on both engines and the platform separator on Linux CI.
$Target = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..', '..', 'scheduling', 'start-meta-audit.ps1'))
$Module = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..', '..', 'common', 'extension-paths.ps1'))
Write-Host "Target: $Target"

if (-not (Test-Path $Target)) {
    Write-Host "  FAIL start-meta-audit.ps1 introuvable" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $Module)) {
    Write-Host "  FAIL extension-paths.ps1 introuvable ($Module)" -ForegroundColor Red
    exit 1
}

$Text = Get-Content $Target -Raw
$ParseErrors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile($Target, [ref]$null, [ref]$ParseErrors)
Assert-That "le script production parse sans erreur" (@($ParseErrors).Count -eq 0)

# --- 1. Static : l'assemblage de la selection dans le script de production ------
Assert-That "le script dot-source extension-paths.ps1" ($Text -match 'extension-paths\.ps1')

# Variable names are literals inside the FindAll predicates on purpose: scriptblocks are not
# closures, the sibling harnesses (test-metaaudit-claude-resolution) use the same shape.
$ActiveAssign = @($Ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left.Extent.Text -eq '$ActiveExtension'
}, $true))
$PathAssign = @($Ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left.Extent.Text -eq '$ActiveTasksPath'
}, $true))
$PromptAssign = @($Ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left.Extent.Text -eq '$Prompt'
}, $true))

Assert-That "la selection passe par Get-ActiveExtension (pas de litteral en dur)" `
    ($ActiveAssign.Count -eq 1 -and $ActiveAssign[0].Extent.Text -match 'Get-ActiveExtension')
Assert-That "le chemin de traces derive de `$ActiveExtension" `
    ($PathAssign.Count -eq 1 -and $PathAssign[0].Extent.Text -match '\$ActiveExtension')
Assert-That "l'affectation `$Prompt (here-string) est identifiable" ($PromptAssign.Count -eq 1)
Assert-That "aucun reliquat rooTasksPath (substitution totale, pas de variable morte)" `
    (-not ($Text -match 'rooTasksPath'))
Assert-That "l'etape 1 du prompt consomme `$ActiveTasksPath" ($Text -match 'ls -lt "\$ActiveTasksPath/')
Assert-That "l'entete d'etape 1 consomme `$ActiveExtension" ($Text -match 'Collecte des traces \$ActiveExtension')

# --- 2. Dynamic : la matrice fixtures, sur l'assemblage REEL extrait de l'AST ----
$ExtractionOk = ($ActiveAssign.Count -eq 1) -and ($PathAssign.Count -eq 1) -and ($PromptAssign.Count -eq 1)
if (-not $ExtractionOk) {
    Write-Host "  SKIP section dynamique : affectations non extraites (assertions statiques deja rouges)"
} else {
    $SelText     = $ActiveAssign[0].Extent.Text
    $SelPathText = $PathAssign[0].Extent.Text
    $PromptText  = $PromptAssign[0].Extent.Text

    $Cases = @(
        @{ Name = 'roo-only'; Roo = $true;  Zoo = $false; Expected = 'RooCode' },
        @{ Name = 'zoo-only'; Roo = $false; Zoo = $true;  Expected = 'ZooCode' },
        @{ Name = 'both';     Roo = $true;  Zoo = $true;  Expected = 'RooCode' },
        @{ Name = 'neither';  Roo = $false; Zoo = $false; Expected = 'RooCode' }
    )

    $MachineName = 'metaaudit-harness'
    $Today = Get-Date -Format 'yyyy-MM-dd'
    $FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("metaaudit-ext-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $FixtureRoot -Force | Out-Null
    $OldAppData = $env:APPDATA
    try {
        foreach ($Case in $Cases) {
            Write-Host "--- fixture $($Case.Name) : attendu $($Case.Expected) ---"
            $env:APPDATA = Join-Path $FixtureRoot $Case.Name
            New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null

            # Les fonctions du module reagissent au nouvel APPDATA des leur appel.
            . $Module
            $RooSettings = Get-McpSettingsPath -Extension RooCode
            $ZooSettings = Get-McpSettingsPath -Extension ZooCode
            if ($Case.Roo) {
                New-Item -ItemType Directory -Path (Split-Path $RooSettings -Parent) -Force | Out-Null
                New-Item -ItemType File -Path $RooSettings -Force | Out-Null
            }
            if ($Case.Zoo) {
                New-Item -ItemType Directory -Path (Split-Path $ZooSettings -Parent) -Force | Out-Null
                New-Item -ItemType File -Path $ZooSettings -Force | Out-Null
            }

            # L'instrument doit mordre : verifier l'etat de la fixture AVANT de juger le probe.
            Assert-That "fixture $($Case.Name): settings roo present=$($Case.Roo)" `
                ((Test-Path $RooSettings) -eq $Case.Roo)
            Assert-That "fixture $($Case.Name): settings zoo present=$($Case.Zoo)" `
                ((Test-Path $ZooSettings) -eq $Case.Zoo)

            # Execution des instructions REELLES du script de production (extraites de l'AST).
            $ActiveExtension = $null
            $ActiveTasksPath = $null
            $Prompt = $null
            Invoke-Expression $SelText
            Invoke-Expression $SelPathText
            Invoke-Expression $PromptText

            $ExpectedTasks = Get-GlobalStoragePath -Extension $Case.Expected | Join-Path -ChildPath 'tasks'
            $OtherExt = if ($Case.Expected -eq 'RooCode') { 'ZooCode' } else { 'RooCode' }
            $OtherTasks = Get-GlobalStoragePath -Extension $OtherExt | Join-Path -ChildPath 'tasks'

            Assert-That "fixture $($Case.Name): Get-ActiveExtension rend $($Case.Expected)" `
                ($ActiveExtension -eq $Case.Expected)
            Assert-That "fixture $($Case.Name): le tasks path vise le globalStorage attendu ($($Case.Expected))" `
                ($ActiveTasksPath -eq $ExpectedTasks)
            Assert-That "fixture $($Case.Name): le prompt embarque ls -lt vers le tasks/ attendu" `
                ($Prompt.Contains('ls -lt "' + $ExpectedTasks + '/"'))
            Assert-That "fixture $($Case.Name): l'entete d'etape 1 nomme $($Case.Expected)" `
                ($Prompt.Contains('Collecte des traces ' + $Case.Expected + ' (5 dernieres taches)'))
            Assert-That "fixture $($Case.Name): le prompt NE contient PAS le tasks/ de l'autre extension" `
                (-not ($Prompt.Contains('ls -lt "' + $OtherTasks + '/"')))
        }
    } finally {
        $env:APPDATA = $OldAppData
        Remove-Item $FixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
if ($script:Fails -gt 0) {
    Write-Host "=== $($script:Fails) assertion(s) en echec ===" -ForegroundColor Red
    exit 1
}
Write-Host "=== toutes les assertions passent ==="
exit 0

# Static harness: start-meta-audit.ps1 must build its claude arguments ONCE, above the
# DryRun exit, and both the preview and the real spawn must consume that one string.
#
# The defect this pins (measured ai-01 2026-08-19, on main at 6b7de9ae):
#   line ~299  if ($DryRun) { Write-Log "  claude -p --model $Model --dangerously-skip-permissions" ; exit 0 }
#   line ~348  $SessionId = [guid]::NewGuid()...
#   line ~355  Start-Process -ArgumentList "-p --model $Model --dangerously-skip-permissions --session-id $SessionId"
# #3166 added --session-id to the spawn alone. The DryRun exits ~50 lines earlier and printed a
# hand-written copy, so `-DryRun` advertised a command the script no longer ran — and it was the
# evidence cited to validate the change. #3163 had removed this exact divergence from the sibling
# script (start-claude-executor.ps1) one PR earlier; nothing stopped it reappearing here.
#
# A preview that is not the call it previews is worse than no preview, because it is believed.
#
# Pure: reads the production script as text + AST. No network, no disk writes, no schtask, no
# Windows dependency — runs on ubuntu-latest pwsh alongside the other wired harnesses.

$ErrorActionPreference = 'Stop'
$script:Fails = 0

function Assert-That([string]$Label, [bool]$Condition) {
    if ($Condition) { Write-Host "  OK   $Label" }
    else { $script:Fails++; Write-Host "  FAIL $Label" -ForegroundColor Red }
}

$Target = Join-Path $PSScriptRoot '..' '..' 'scheduling' 'start-meta-audit.ps1'
$Target = [System.IO.Path]::GetFullPath($Target)
Write-Host "=== meta-audit argument single-source harness ==="
Write-Host "Target: $Target"

if (-not (Test-Path $Target)) {
    Write-Host "  FAIL start-meta-audit.ps1 introuvable" -ForegroundColor Red
    exit 1
}

$Text = Get-Content $Target -Raw
$Lines = Get-Content $Target
$ParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($Target, [ref]$null, [ref]$ParseErrors) | Out-Null
Assert-That "le script production parse sans erreur" (@($ParseErrors).Count -eq 0)

# --- 1. Une seule source de verite pour les arguments ------------------------
$Assign = @($Lines | Select-String -Pattern '^\s*\$ClaudeArgs\s*=')
Assert-That "exactement une affectation de `$ClaudeArgs" ($Assign.Count -eq 1)

# C'est L'ASSERTION qui mord : le flag de permission ne doit exister qu'a un seul
# endroit du fichier. Toute copie manuscrite des arguments (preview, second spawn,
# message de log) le duplique et fait rougir cette ligne.
$PermFlag = [regex]::Matches($Text, '--dangerously-skip-permissions')
Assert-That "le flag de permission n'apparait qu'UNE fois (pas de copie manuscrite)" ($PermFlag.Count -eq 1)

if ($Assign.Count -eq 1) {
    $AssignText = $Assign[0].Line
    Assert-That "la chaine unique porte --session-id (ciblage post-run, #3142 v2)" ($AssignText -match '--session-id')
    Assert-That "la chaine unique porte le flag de permission (#3163)" ($AssignText -match '--dangerously-skip-permissions')
    Assert-That "la chaine unique porte -p et --model" (($AssignText -match '\-p\b') -and ($AssignText -match '--model'))
}

# --- 2. Les DEUX consommateurs lisent cette variable, pas une copie ----------
Assert-That "le spawn reel consomme `$ClaudeArgs" ($Text -match '-ArgumentList\s+\$ClaudeArgs')
Assert-That "le spawn ne passe PAS une chaine litterale" (-not ($Text -match '-ArgumentList\s+"'))

# Ancree sur la STRUCTURE (l'entete de preview) et non sur le mot "claude" : Select-String
# est insensible a la casse par defaut, et "Claude CLI:" / "Claude process started" matchent
# tout aussi bien. La ligne qui compte est celle qui SUIT immediatement l'entete.
$DryRunHeader = @($Lines | Select-String -Pattern '\[DRY-RUN\] Commande')
Assert-That "l'entete de preview DryRun existe" ($DryRunHeader.Count -eq 1)
if ($DryRunHeader.Count -eq 1) {
    # LineNumber est 1-base : $Lines[$LineNumber] est donc la ligne suivante.
    $PreviewLine = $Lines[$DryRunHeader[0].LineNumber]
    Assert-That "la ligne de preview interpole `$ClaudeArgs" ($PreviewLine -match '\$ClaudeArgs')
}

# --- 3. Ordre : la variable doit exister AVANT le exit du DryRun -------------
# Sans cette garde, deplacer l'affectation sous le bloc DryRun redonne une preview
# silencieusement vide ("claude ") au lieu d'une preview fausse — meme classe de defaut.
$AssignLine = if ($Assign.Count -eq 1) { $Assign[0].LineNumber } else { [int]::MaxValue }
$DryRunLine = @($Lines | Select-String -Pattern '^\s*if\s*\(\s*\$DryRun\s*\)')
Assert-That "le bloc if (`$DryRun) est identifiable" ($DryRunLine.Count -eq 1)
if ($DryRunLine.Count -eq 1) {
    Assert-That "`$ClaudeArgs est affectee AVANT le bloc DryRun" ($AssignLine -lt $DryRunLine[0].LineNumber)
}

# --- 4. Non-regression des deux durcissements de #3166 ----------------------
# Borne temporelle du fallback (finding po-2023 c.236) : sans elle, un [FALLBACK] perime
# d'un cycle precedent fait passer une panne repetee pour un rapport sauve.
Assert-That "le fallback est borne par LastWriteTime -ge `$StartTime (po-2023 c.236)" `
    ($Text -match 'LastWriteTime\s+-ge\s+\$StartTime')
# Lecture ciblee par UUID (finding web1 c.282) primaire, heuristique en repli seulement.
Assert-That "le check post-run lit le JSONL cible (`$ExpectedJsonl)" ($Text -match '\$ExpectedJsonl')

Write-Host ""
if ($script:Fails -gt 0) {
    Write-Host "=== $($script:Fails) assertion(s) en echec ===" -ForegroundColor Red
    exit 1
}
Write-Host "=== toutes les assertions passent ==="
exit 0

# Counter-evidence: prove the fix changes the verdict.
# Simulates the post-run check (line ~430 of start-meta-audit.ps1) on the test directory
# `counter-evidence-data/` next to this script. Two concurrent JSONLs:
#  - "wrong-session-*.jsonl"  : older, contains the marker, 5 RSM hits (the decoy)
#  - "true-session-<uuid>.jsonl" : newer, contains the marker, 0 RSM hits (the real)
# When the heuristic selects by mtime desc + marker, it picks the decoy -> verdict OK
# when reality is absence. After the fix (UUID-targeted), it picks the true session -> 0
# hits -> alerts on absent fallback -> verdict ALERTE. Verdict MUST change.

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$testDir = Join-Path $here "counter-evidence-data"
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
New-Item -ItemType Directory -Path $testDir | Out-Null

# Make the wrong-session file NEWER than the true-session (this is the collision scenario).
# In the test, we want the heuristic to pick the WRONG session. So we make it newer.
$TrueSessionId = [guid]::NewGuid().ToString()
$WrongSessionId = [guid]::NewGuid().ToString()
$TrueFile = Join-Path $testDir "$TrueSessionId.jsonl"
$WrongFile = Join-Path $testDir "$WrongSessionId.jsonl"

# True session: 0 RSM hits, marker present
"user: META-ANALYSTE Claude Code is running" | Set-Content -Path $TrueFile -Encoding UTF8
(Get-Item $TrueFile).LastWriteTime = (Get-Date).AddSeconds(-60)  # 60s ago

# Wrong/decoy session: 5 RSM hits, marker present, NEWER
$wrong = @"
user: META-ANALYSTE Claude Code is running
assistant: mcp__roo-state-manager__roosync_dashboard
user: try again
assistant: mcp__roo-state-manager__roosync_dashboard
user: and again
assistant: mcp__roo-state-manager__roosync_dashboard
assistant: mcp__roo-state-manager__roosync_dashboard
assistant: mcp__roo-state-manager__roosync_dashboard
"@
$wrong | Set-Content -Path $WrongFile -Encoding UTF8
(Get-Item $WrongFile).LastWriteTime = (Get-Date).AddSeconds(-5)  # 5s ago, the trap

$StartTime = (Get-Date).AddSeconds(-90)

# --- HEURISTIC VERDICT (BEFORE fix) ---
Write-Host "=== AVANT FIX (heuristique marqueur) ==="
$SessionMarker = "META-ANALYSTE Claude Code"
$HeuristicJsonl = Get-ChildItem -Path $testDir -Filter "*.jsonl" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $StartTime.AddSeconds(-30) } |
    Where-Object {
        $raw = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        $raw -and ($raw.Contains($SessionMarker))
    } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$RsmLines = @(Select-String -Path $HeuristicJsonl.FullName -Pattern "mcp__roo-state-manager" -AllMatches -ErrorAction SilentlyContinue)
Write-Host "  Selected: $($HeuristicJsonl.Name)"
Write-Host "  RSM hits: $($RsmLines.Count)"
if ($RsmLines.Count -gt 0) {
    Write-Host "  VERDICT: OK (rapport non perdu) — FAUX en realite, la VRAIE session a 0 RSM"
    $HeuristicVerdict = "OK_BUT_WRONG"
} else {
    Write-Host "  VERDICT: ALERTE RAPPORT PERDU"
    $HeuristicVerdict = "ALERT"
}

# --- TARGETED VERDICT (AFTER fix) ---
Write-Host ""
Write-Host "=== APRES FIX (--session-id ciblé) ==="
$ExpectedJsonl = Join-Path $testDir "$TrueSessionId.jsonl"
$TargetedJsonl = if (Test-Path $ExpectedJsonl) { Get-Item $ExpectedJsonl } else { $null }
if ($TargetedJsonl) {
    $RsmLines2 = @(Select-String -Path $TargetedJsonl.FullName -Pattern "mcp__roo-state-manager" -AllMatches -ErrorAction SilentlyContinue)
    Write-Host "  Selected: $($TargetedJsonl.Name) (UUID deterministe)"
    Write-Host "  RSM hits: $($RsmLines2.Count)"
    if ($RsmLines2.Count -gt 0) {
        Write-Host "  VERDICT: OK (rapport non perdu)"
        $TargetedVerdict = "OK"
    } else {
        Write-Host "  VERDICT: ALERTE RAPPORT PERDU (corrige, vraie session)"
        $TargetedVerdict = "ALERT"
    }
} else {
    Write-Host "  VERDICT: pas de JSONL cible — fallback heuristique"
    $TargetedVerdict = "FALLBACK"
}

# --- COUNTER-EVIDENCE VERDICT ---
Write-Host ""
Write-Host "=== CONTRE-EPREUVE ==="
if ($HeuristicVerdict -eq "OK_BUT_WRONG" -and $TargetedVerdict -eq "ALERT") {
    Write-Host "PASS — la mutation change le verdict de l'heuristique (FAUX OK) au ciblé (ALERTE correcte)."
    Write-Host "  Mutation valide : le fix v2 CHANGE REELLEMENT le verdict, pas cosmétique."
    $exit = 0
} elseif ($HeuristicVerdict -eq $TargetedVerdict) {
    Write-Host "FAIL — les deux modes produisent le meme verdict. Mutation invalide (cosmétique)."
    $exit = 1
} else {
    Write-Host "INFO — verdicts differents mais interpretation ambigue (heuristique=$HeuristicVerdict, ciblé=$TargetedVerdict)"
    $exit = 2
}

# Cleanup
Remove-Item $testDir -Recurse -Force
exit $exit

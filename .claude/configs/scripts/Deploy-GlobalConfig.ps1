<#
.SYNOPSIS
    Deploy global Claude Code configuration from roo-extensions templates.

.DESCRIPTION
    Copies agents, skills, commands, rules, and CLAUDE.md from .claude/configs/
    to ~/.claude/ for global availability across all workspaces.

.PARAMETER Target
    What to deploy: all, agents, skills, commands, rules, claude-md

.PARAMETER DryRun
    Show what would be deployed without actually copying.

.EXAMPLE
    .\Deploy-GlobalConfig.ps1
    .\Deploy-GlobalConfig.ps1 -Target agents
    .\Deploy-GlobalConfig.ps1 -DryRun
#>
param(
    [ValidateSet("all", "agents", "skills", "commands", "rules", "claude-md", "settings")]
    [string]$Target = "all",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Paths — the script's own location is authoritative: invoked from ANOTHER clone's
# cwd, `git rev-parse` resolves to that clone and silently deploys the wrong repo's
# configs (measured 29/09: run from claudish, "template not found" for settings;
# the copy targets would misfire the same way when present).
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
if (-not (Test-Path (Join-Path $repoRoot ".claude\configs"))) {
    $repoRoot = (git rev-parse --show-toplevel 2>$null) -replace '/', '\'
}
$configsDir = Join-Path $repoRoot ".claude\configs"
$globalDir = Join-Path $env:USERPROFILE ".claude"

Write-Host "=== Deploy Global Claude Code Config ===" -ForegroundColor Cyan
Write-Host "Source: $configsDir"
Write-Host "Target: $globalDir"
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'DEPLOY' })"
Write-Host ""

function Deploy-Files {
    param([string]$SourceDir, [string]$TargetDir, [string]$Label)

    if (-not (Test-Path $SourceDir)) {
        Write-Host "  SKIP $Label (source not found: $SourceDir)" -ForegroundColor Yellow
        return 0
    }

    $count = 0
    Get-ChildItem -Path $SourceDir -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
        $destPath = Join-Path $TargetDir $relativePath
        $destDir = Split-Path -Parent $destPath

        # Statut calcule AVANT la copie : teste apres coup, le mode reel voit toujours
        # le fichier deja ecrit — NEW n etait donc structurellement jamais atteignable.
        $status = if (Test-Path $destPath) { "UPDATE" } else { "NEW" }

        if (-not $DryRun) {
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $_.FullName -Destination $destPath -Force
        }

        Write-Host "  $status $relativePath" -ForegroundColor $(if ($status -eq "NEW") { "Green" } else { "White" })
        $count++
    }
    return $count
}

$totalFiles = 0

# Deploy CLAUDE.md
if ($Target -in "all", "claude-md") {
    Write-Host "`n--- CLAUDE.md ---" -ForegroundColor Yellow
    $claudeMdSource = Join-Path $configsDir "user-global-claude.md"
    $claudeMdDest = Join-Path $globalDir "CLAUDE.md"
    if (Test-Path $claudeMdSource) {
        if (-not $DryRun) {
            Copy-Item -Path $claudeMdSource -Destination $claudeMdDest -Force
        }
        Write-Host "  DEPLOY user-global-claude.md -> CLAUDE.md" -ForegroundColor Green
        $totalFiles++
    }
}

# Deploy Agents
if ($Target -in "all", "agents") {
    Write-Host "`n--- Agents ---" -ForegroundColor Yellow
    $agentsSrc = Join-Path $configsDir "agents"
    $agentsDst = Join-Path $globalDir "agents"
    $totalFiles += (Deploy-Files -SourceDir $agentsSrc -TargetDir $agentsDst -Label "agents")
}

# Deploy Skills
if ($Target -in "all", "skills") {
    Write-Host "`n--- Skills ---" -ForegroundColor Yellow
    $skillsSrc = Join-Path $configsDir "skills"
    $skillsDst = Join-Path $globalDir "skills"
    $totalFiles += (Deploy-Files -SourceDir $skillsSrc -TargetDir $skillsDst -Label "skills")
}

# Deploy Commands
if ($Target -in "all", "commands") {
    Write-Host "`n--- Commands ---" -ForegroundColor Yellow
    $cmdsSrc = Join-Path $configsDir "commands"
    $cmdsDst = Join-Path $globalDir "commands"
    $totalFiles += (Deploy-Files -SourceDir $cmdsSrc -TargetDir $cmdsDst -Label "commands")
}

# Deploy Rules (global rules auto-loaded in ALL workspaces)
if ($Target -in "all", "rules") {
    Write-Host "`n--- Rules ---" -ForegroundColor Yellow
    $rulesSrc = Join-Path $configsDir "rules"
    $rulesDst = Join-Path $globalDir "rules"
    $totalFiles += (Deploy-Files -SourceDir $rulesSrc -TargetDir $rulesDst -Label "rules")
}

# Deploy settings.json — canon MERGE, never a copy (mandat user 4e relance 29/09/2026).
# settings.template.json declares the fleet canon; the live file keeps every key the
# canon does not list (allow-list locale, hooks locaux, effortLevel, ...) and every
# value marked <<preserve-local>> (secrets, endpoint machine, lane Sol). The canon
# deny-list is an ENSURE-list: added if missing, local extra denies are never removed.
if ($Target -in "all", "settings") {
    Write-Host "`n--- settings.json (canon merge) ---" -ForegroundColor Yellow
    $templatePath = Join-Path $configsDir "settings.template.json"
    $livePath = Join-Path $globalDir "settings.json"

    function Convert-ToOrderedHash {
        param($obj)
        if ($obj -is [System.Management.Automation.PSCustomObject]) {
            $h = [ordered]@{}
            foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = Convert-ToOrderedHash $p.Value }
            return $h
        }
        # Preserve arrays AS arrays (recursing into elements): the hook validator must
        # see PreToolUse as object[] — flattening an array here is what made a VALID
        # settings.json read as "PreToolUse is a PSCustomObject" (measured 29/09).
        # The unary comma forces the result back into an array even when it holds a
        # SINGLE element: a pipeline unwraps a 1-item collection to the item itself,
        # which is exactly how a 1-entry PreToolUse array became a bare OrderedDictionary.
        if ($obj -is [object[]]) {
            return ,@($obj | ForEach-Object { Convert-ToOrderedHash $_ })
        }
        return $obj
    }

    function Merge-CanonIntoLive {
        param($liveHash, $canonHash, [string]$path, [ref]$actions)

        foreach ($key in @($canonHash.Keys)) {
            if ($key -like '__*') { continue }
            $canonVal = $canonHash[$key]
            $p = if ($path) { "$path.$key" } else { $key }

            # The one array in the canon is an ENSURE-list, not a replacement: a local
            # extra deny (e.g. ScheduleWakeup on po-2025) is a machine decision we keep.
            if ($canonVal -is [object[]]) {
                $liveArr = @()
                if ($liveHash.Contains($key) -and $liveHash[$key] -is [object[]]) { $liveArr = @($liveHash[$key]) }
                $added = @()
                foreach ($e in $canonVal) { if ($liveArr -notcontains $e) { $liveArr = @($liveArr) + @($e); $added += $e } }
                $liveHash[$key] = $liveArr
                if ($added.Count -gt 0) { $null = $actions.Value.Add("DENY-ADDED $p += $($added -join ', ')") }
                else { $null = $actions.Value.Add("OK $p (canon entries all present)") }
                continue
            }

            if ($canonVal -is [System.Collections.IDictionary]) {
                if (-not ($liveHash.Contains($key) -and $liveHash[$key] -is [System.Collections.IDictionary])) {
                    $liveHash[$key] = [ordered]@{}
                }
                Merge-CanonIntoLive -liveHash $liveHash[$key] -canonHash $canonVal -path $p -actions $actions
                continue
            }

            if ($canonVal -is [string] -and $canonVal -eq '<<preserve-local>>') {
                $null = $actions.Value.Add("PRESERVED $p (local value kept)")
                continue
            }

            $existing = $null
            if ($liveHash.Contains($key)) { $existing = $liveHash[$key] }
            if ($null -ne $existing -and "$existing" -eq "$canonVal") {
                $null = $actions.Value.Add("OK $p")
            } else {
                $null = $actions.Value.Add("SET $p = '$canonVal' (was '$existing')")
                $liveHash[$key] = $canonVal
            }
        }
    }

    if (Test-Path $templatePath) {
        # -Encoding UTF8 explicit: under PS 5.1 a no-BOM UTF-8 file is decoded as
        # ANSI and every accent in the canon lands in settings.json as mojibake.
        $canonHash = Convert-ToOrderedHash (Get-Content $templatePath -Raw -Encoding UTF8 | ConvertFrom-Json)
        $actions = [System.Collections.ArrayList]::new()

        # The pre-fix Convert-ToOrderedHash flattened EVERY 1-item array, not only hooks:
        # a one-entry permissions list came back as a bare string, which Claude Code
        # rejects too. Wrap it back BEFORE the merge — Merge-CanonIntoLive reads a
        # non-array deny as empty and would drop the local entry.
        function Repair-PermissionLists {
            param($liveHash, [ref]$actions)
            if (-not ($liveHash.Contains('permissions') -and $liveHash['permissions'] -is [System.Collections.IDictionary])) { return }
            $perm = $liveHash['permissions']
            foreach ($k in 'allow', 'deny', 'ask', 'additionalDirectories') {
                if ($perm.Contains($k) -and $perm[$k] -is [string]) {
                    $perm[$k] = @($perm[$k])
                    $null = $actions.Value.Add("REPAIRED permissions.$k — was a single string, wrapped into an array")
                }
            }
        }

        # ── Structural validator (incident 29/09: machines arrived with hooks Claude
        # Code refuses to parse — PreToolUse as an OBJECT instead of an ARRAY, an entry
        # with no `matcher`). ConvertFrom-Json catches malformed JSON, NOT schema errors,
        # so the deployer used to re-emit a corrupt-but-parseable file untouched. This
        # validator REPAIRS the unambiguous corruptions and REFUSES to write a file that
        # still does not validate — a settings.json Claude cannot parse breaks every
        # session on the machine, which is worse than no deploy at all.
        function Repair-AndValidateHooks {
            param($liveHash, [ref]$actions, [ref]$fatal)
            if (-not ($liveHash.Contains('hooks'))) { return }
            $hooks = $liveHash['hooks']
            if (-not ($hooks -is [System.Collections.IDictionary])) {
                $fatal.Value.Add("hooks is a $($hooks.GetType().Name), expected an object — REFUSING to write")
                return
            }
            foreach ($eventName in @($hooks.Keys)) {
                $entries = $hooks[$eventName]
                # Claude Code requires every hook event to be an ARRAY of
                # { matcher, hooks: [ {type, command} ] }. An object here is the exact
                # corruption measured 29/09 — repair by wrapping when it is unambiguous.
                if ($entries -is [System.Collections.IDictionary]) {
                    $entries = @($entries)
                    $hooks[$eventName] = $entries
                    $null = $actions.Value.Add("REPAIRED hooks.$eventName — was a single object, wrapped into an array")
                }
                if (-not ($entries -is [object[]])) {
                    $fatal.Value.Add("hooks.$eventName is a $($entries.GetType().Name), expected an array — REFUSING to write")
                    continue
                }
                $cleaned = @()
                $dropped = 0
                foreach ($e in $entries) {
                    if (-not ($e -is [System.Collections.IDictionary])) { $dropped++; continue }
                    # NO check on `matcher`: it is optional. Omitted, "" or "*" = match all,
                    # and Stop / UserPromptSubmit / ... have no matcher by design
                    # (code.claude.com/docs/en/hooks, "Matcher patterns"). Dropping it
                    # deletes a valid hook.
                    $inner = $e['hooks']
                    if ($inner -is [System.Collections.IDictionary]) {
                        # Same flattening one level down: a second pass of the pre-fix
                        # deployer turns the 1-command `hooks` list into a bare object.
                        $inner = @($inner)
                        $e['hooks'] = $inner
                        $null = $actions.Value.Add("REPAIRED hooks.$eventName[].hooks — was a single object, wrapped into an array")
                    }
                    if (-not ($inner -is [object[]]) -or $inner.Count -eq 0) {
                        # no hook commands — nothing to run. Unrepairable.
                        $dropped++
                        continue
                    }
                    $cleaned += $e
                }
                if ($dropped -gt 0) {
                    $hooks[$eventName] = $cleaned
                    $null = $actions.Value.Add("REPAIRED hooks.$eventName — dropped $dropped entrie(s) with no hook command (inert)")
                }
                if ($cleaned.Count -eq 0) {
                    # The event had only invalid entries: remove the event key entirely
                    # rather than emit an empty array (cleaner, and Claude accepts absence).
                    $hooks.Remove($eventName)
                    $null = $actions.Value.Add("REPAIRED hooks.$eventName — removed (no valid entry remained)")
                }
            }
            if ($hooks.Keys.Count -eq 0) {
                $liveHash.Remove('hooks')
                $null = $actions.Value.Add("REPAIRED hooks — removed (no valid event remained)")
            }
        }

        if (Test-Path $livePath) {
            $liveHash = Convert-ToOrderedHash (Get-Content $livePath -Raw -Encoding UTF8 | ConvertFrom-Json)
            Repair-PermissionLists -liveHash $liveHash -actions ([ref]$actions)
            Merge-CanonIntoLive -liveHash $liveHash -canonHash $canonHash -path '' -actions ([ref]$actions)
            $fatal = [System.Collections.ArrayList]::new()
            Repair-AndValidateHooks -liveHash $liveHash -actions ([ref]$actions) -fatal ([ref]$fatal)
            if ($fatal.Count -gt 0) {
                foreach ($fmsg in $fatal) { Write-Host "  FATAL $fmsg" -ForegroundColor Red }
                Write-Host "  REFUSED settings.json — live file left UNTOUCHED (fix the corruption, then re-run)" -ForegroundColor Red
            }
            elseif (-not $DryRun) {
                $backup = "$livePath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $livePath $backup -Force
                $json = $liveHash | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($livePath, $json, (New-Object System.Text.UTF8Encoding($false)))
                # Postcondition: the written file must parse — a broken settings.json
                # breaks EVERY session on the machine.
                $null = Get-Content $livePath -Raw -Encoding UTF8 | ConvertFrom-Json
                Write-Host "  BACKUP $(Split-Path -Leaf $backup)"
                Write-Host "  WROTE settings.json (JSON round-trip verified, hooks validated, UTF-8 no BOM)" -ForegroundColor Green
            }
        } else {
            # Fresh machine: scaffold from the canon. <<preserve-local>> keys cannot
            # resolve without a live file — they are DROPPED with a warning (the
            # provider profiles in scripts/claude/ handle onboarding credentials).
            $fresh = [ordered]@{}
            foreach ($topKey in @($canonHash.Keys)) {
                if ($topKey -like '__*') { continue }
                $sub = $canonHash[$topKey]
                if ($sub -is [System.Collections.IDictionary]) {
                    $clean = [ordered]@{}
                    foreach ($k in @($sub.Keys)) {
                        if ($k -like '__*') { continue }
                        if ($sub[$k] -is [string] -and $sub[$k] -eq '<<preserve-local>>') {
                            Write-Host "  WARN dropped $topKey.$k (fresh install — set it manually)" -ForegroundColor Yellow
                            continue
                        }
                        if ($k -eq 'deny' -and $sub[$k] -is [object[]]) { continue }
                        $clean[$k] = $sub[$k]
                    }
                    $fresh[$topKey] = $clean
                } else {
                    $fresh[$topKey] = $sub
                }
            }
            $null = $actions.Value.Add("SCAFFOLD fresh settings.json from canon")
            if (-not $DryRun) {
                $json = $fresh | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($livePath, $json, (New-Object System.Text.UTF8Encoding($false)))
                $null = Get-Content $livePath -Raw -Encoding UTF8 | ConvertFrom-Json
                Write-Host "  WROTE settings.json (scaffold)" -ForegroundColor Green
            }
        }

        foreach ($a in $actions) { Write-Host "  $a" }
        $totalFiles++
    } else {
        Write-Host "  SKIP settings (template not found: $templatePath)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Files deployed: $totalFiles"
if ($DryRun) {
    Write-Host "(DRY RUN - no files were actually copied)" -ForegroundColor Yellow
}
Write-Host "Done." -ForegroundColor Green

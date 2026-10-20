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
    # Fresh seat, -Target settings ONLY: Deploy-Files (which mkdirs $globalDir)
    # never runs, and both write paths below WriteAllText straight into
    # $livePath -> "part of the path not found" on a pristine profile (measured
    # 20/10, RUN4 sandbox; -Target all masked it by creating the dir first).
    if (-not (Test-Path $globalDir)) { New-Item -ItemType Directory -Force -Path $globalDir | Out-Null }

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

        # Hooks (#4258): carried by the canon but handled OUTSIDE the generic merge —
        # the generic array ensure compares by reference, and hook entries are dicts,
        # so every deploy would duplicate them. Ensure-FleetHooks dedups by resolved
        # command string instead.
        #
        # <<repo>> must resolve to a PERSISTENT checkout, not "wherever this script
        # ran from": these commands are written into the machine-global settings.json
        # and must still resolve at every future session. Run from a linked worktree
        # (agent PR work), $repoRoot is ephemeral — its removal would leave the whole
        # machine spawning hooks from a path that no longer exists. --git-common-dir
        # is the main checkout's .git for a worktree (its parent is the real root)
        # and a plain relative ".git" in a normal checkout (resolves to $repoRoot,
        # i.e. unchanged). Forward slashes for node on Windows either way.
        $hooksRepoRoot = $repoRoot
        # PS 5.1: under $ErrorActionPreference = 'Stop' (set at the top of the
        # script), a native command's stderr is promoted to a TERMINATING
        # NativeCommandError even when redirected with 2>$null — an unguarded
        # call here aborted the whole settings deploy when the script root is
        # NOT a git repository (copied-configs deploy: measured exit 1,
        # settings.json never written; #4260 reviews). Soften EAP around the
        # call and fall back to the script root on ANY failure.
        $gitCommonDir = $null
        try {
            $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            $out = git -C $repoRoot rev-parse --git-common-dir 2>$null
            if ($LASTEXITCODE -eq 0) { $gitCommonDir = $out }
        } catch { $gitCommonDir = $null } finally { $ErrorActionPreference = $eap }
        if ($gitCommonDir) {
            $commonPath = if ([System.IO.Path]::IsPathRooted($gitCommonDir)) { $gitCommonDir } else { Join-Path $repoRoot $gitCommonDir }
            $mainRoot = Split-Path -Parent (Resolve-Path $commonPath).Path
            if ($mainRoot -and (Test-Path (Join-Path $mainRoot ".claude\configs"))) { $hooksRepoRoot = $mainRoot }
        }
        $hooksRepoRoot = $hooksRepoRoot -replace '\\', '/'
        $canonHooks = $null
        if ($canonHash.Contains('hooks')) {
            $canonHooks = $canonHash['hooks']
            $canonHash.Remove('hooks')
        }

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

        # ── Fleet hooks ensure-add (#4258): the canon's hook entries carry the
        # <<repo>> placeholder; resolve it to this checkout and add each entry
        # whose command is not already present (any entry, any matcher — command
        # identity is the dedup key, so a locally hand-wired hook with a
        # different path style still counts as present). Local hooks are NEVER
        # removed. Runs after Repair-AndValidateHooks so added entries land in
        # an already-valid structure.
        # Canon contract (#4260 review): each canon hook entry carries exactly
        # ONE command — coverage is decided per ENTRY, so a multi-command entry
        # with only part of its commands present live would be re-added whole
        # and duplicate them. Keep canon entries single-command (or switch to
        # per-command insertion if that ever changes).
        function Ensure-FleetHooks {
            param($liveHash, $canonHooks, [string]$repoRoot, [ref]$actions)
            if ($null -eq $canonHooks) { return }
            if (-not ($liveHash.Contains('hooks')) -or -not ($liveHash['hooks'] -is [System.Collections.IDictionary])) {
                $liveHash['hooks'] = [ordered]@{}
            }
            $hooks = $liveHash['hooks']
            # Normalize a command for comparison: forward slashes, lowercase,
            # local repo root collapsed back to <<repo>>.
            function Get-CommandSignature {
                param([string]$cmd, [string]$root)
                return (($cmd -replace '\\', '/') -replace [regex]::Escape($root), '<<repo>>').ToLowerInvariant()
            }
            $liveSigs = @()
            foreach ($ev in @($hooks.Keys)) {
                foreach ($e in @($hooks[$ev])) {
                    if (-not ($e -is [System.Collections.IDictionary])) { continue }
                    foreach ($h in @($e['hooks'])) {
                        if ($h -is [System.Collections.IDictionary] -and $h['command']) {
                            # Event-scoped: the same command wired on Stop does not
                            # cover PreCompact or SessionStart (user-words-journal
                            # runs one script on three events).
                            $liveSigs += ("$ev|" + (Get-CommandSignature "$($h['command'])" $repoRoot))
                        }
                    }
                }
            }
            foreach ($eventName in @($canonHooks.Keys)) {
                if ($eventName -like '__*') { continue }
                $canonEntries = @($canonHooks[$eventName])
                if (-not ($hooks.Contains($eventName)) -or -not ($hooks[$eventName] -is [object[]])) {
                    $hooks[$eventName] = @()
                }
                $liveEntries = @($hooks[$eventName])
                foreach ($ce in $canonEntries) {
                    if (-not ($ce -is [System.Collections.IDictionary])) { continue }
                    $cmds = @()
                    foreach ($h in @($ce['hooks'])) {
                        if (-not ($h -is [System.Collections.IDictionary])) { continue }
                        $cmds += [ordered]@{ type = "$($h['type'])"; command = ("$($h['command'])" -replace '<<repo>>', $repoRoot) }
                    }
                    if ($cmds.Count -eq 0) { continue }
                    $covered = $true
                    foreach ($c in $cmds) {
                        if ($liveSigs -notcontains ("$eventName|" + (Get-CommandSignature "$($c.command)" $repoRoot))) { $covered = $false; break }
                    }
                    if (-not $covered) {
                        $entry = [ordered]@{ hooks = $cmds }
                        if ($ce.Contains('matcher')) { $entry['matcher'] = "$($ce['matcher'])" }
                        $liveEntries = @($liveEntries) + @($entry)
                        $liveSigs += @($cmds | ForEach-Object { "$eventName|" + (Get-CommandSignature "$($_.command)" $repoRoot) })
                        $null = $actions.Value.Add("HOOK-ADDED hooks.$eventName += $($cmds[0].command)")
                    }
                }
                $hooks[$eventName] = $liveEntries
            }
        }

        if (Test-Path $livePath) {
            $liveHash = Convert-ToOrderedHash (Get-Content $livePath -Raw -Encoding UTF8 | ConvertFrom-Json)
            Repair-PermissionLists -liveHash $liveHash -actions ([ref]$actions)
            Merge-CanonIntoLive -liveHash $liveHash -canonHash $canonHash -path '' -actions ([ref]$actions)
            $fatal = [System.Collections.ArrayList]::new()
            Repair-AndValidateHooks -liveHash $liveHash -actions ([ref]$actions) -fatal ([ref]$fatal)
            Ensure-FleetHooks -liveHash $liveHash -canonHooks $canonHooks -repoRoot $hooksRepoRoot -actions ([ref]$actions)
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
                        # 'deny' is no longer skipped on fresh installs (#4258): the
                        # canon's own __deny_semantics__ makes it an ENSURE-list, and
                        # a seat scaffolded without it started WITHOUT the tightened
                        # harness (AskUserQuestion & co. not denied) — the exact
                        # regression po-2028 hit during onboarding.
                        $clean[$k] = $sub[$k]
                    }
                    $fresh[$topKey] = $clean
                } else {
                    $fresh[$topKey] = $sub
                }
            }
            # $actions is the ArrayList itself here (not a PSReference — the [ref]
            # wrappers only live inside the helper functions): .Value.Add() crashed
            # every fresh install with a null-method call (#4258, measured po-2028).
            $null = $actions.Add("SCAFFOLD fresh settings.json from canon")
            if ($null -ne $canonHooks) {
                # Fresh seat: no live hooks to preserve — resolve the canon hooks
                # straight into the scaffold (#4258; was: hooks key never written).
                $freshHooks = [ordered]@{}
                foreach ($eventName in @($canonHooks.Keys)) {
                    if ($eventName -like '__*') { continue }
                    $freshHooks[$eventName] = @($canonHooks[$eventName] | ForEach-Object {
                        $entry = [ordered]@{}
                        if ($_ -is [System.Collections.IDictionary]) {
                            if ($_.Contains('matcher')) { $entry['matcher'] = "$($_['matcher'])" }
                            $entry['hooks'] = @($_['hooks'] | ForEach-Object {
                                [ordered]@{ type = "$($_.type)"; command = ("$($_.command)" -replace '<<repo>>', $hooksRepoRoot) }
                            })
                        }
                        $entry
                    })
                }
                if ($freshHooks.Keys.Count -gt 0) {
                    $fresh['hooks'] = $freshHooks
                    $null = $actions.Add("HOOK-ADDED (scaffold) fleet hooks from canon, <<repo>> -> $hooksRepoRoot")
                }
            }
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

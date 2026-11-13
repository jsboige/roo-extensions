# coordinator-cadence-single-source.Tests.ps1
#
# Guard: the coordinator's cron cadence is written ONCE in the repo.
#
# Why: the coordinator's CronCreate job is session-only. After every context
# continuation the coordinator re-arms it from what the command file
# prescribes (#2832). Any file still citing an older value silently restores
# the old cadence. Until 2026-11-13 the cron expression was copied in seven
# places across four files; the user's 2026-11-07 decision (6h) reached the
# live job but never the files, which kept prescribing 12h for six days.
#
# Contract (scanned trees: .claude/commands, .claude/skills, .claude/rules,
# .claude/agents, .claude/configs, docs, and the root CLAUDE.md):
#   1. Exactly ONE `CronCreate(cron: "...", prompt: "/coordinate"` line
#      exists, and it lives in .claude/commands/coordinate.md.
#   2. Every coordinator cron expression (minute 23: "23 */N") found in
#      those trees equals the canonical one. History is written in hours.
#   3. The canonical line keeps its invariants: minute 23 (the executors
#      fire at :41), an hour step that divides 24.
#   Mutant controls prove the scanner sees a second CronCreate line, a
#   divergent bare expression, and an absent canonical line.
#
# Blind spot, on purpose: a cadence written in prose ("12h") or as a bare
# step ("*/12") without the minute is not seen. Review catches those; the
# rule for authors is a pointer to the canonical line, never a value.
#
# This file is pure ASCII on purpose (Windows PowerShell 5.1 reads a
# BOM-less script as ANSI).
#
# Run:  powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/coordinator-cadence-single-source.Tests.ps1

Describe 'coordinator cadence - single source of truth (coordinate.md canonical line)' {

    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $script:canonicalRel = '.claude/commands/coordinate.md'

        # The scanner works on an in-memory map (relative path -> text) so
        # the mutant controls can feed it fixtures.
        function Get-CoordinatorCadenceFindings {
            param([hashtable]$Texts)

            $createPattern = 'CronCreate\(cron:\s*"([^"]+)",\s*prompt:\s*"/coordinate"'
            $barePattern = '(?<![0-9])23 \*/([0-9]+)'

            $creates = @()
            $bares = @()
            foreach ($rel in ($Texts.Keys | Sort-Object)) {
                $lineNo = 0
                foreach ($line in ($Texts[$rel] -split "`n")) {
                    $lineNo++
                    foreach ($m in [regex]::Matches($line, $createPattern)) {
                        $creates += [pscustomobject]@{ File = $rel; Line = $lineNo; Cron = $m.Groups[1].Value }
                    }
                    foreach ($m in [regex]::Matches($line, $barePattern)) {
                        $bares += [pscustomobject]@{ File = $rel; Line = $lineNo; Step = [int]$m.Groups[1].Value }
                    }
                }
            }
            return @{ Creates = $creates; Bares = $bares }
        }

        function Get-CoordinatorCadenceDrift {
            param([hashtable]$Texts, [string]$CanonicalRel)

            $found = Get-CoordinatorCadenceFindings -Texts $Texts
            $drift = @()

            $canonical = @($found.Creates | Where-Object { $_.File -eq $CanonicalRel })
            $elsewhere = @($found.Creates | Where-Object { $_.File -ne $CanonicalRel })

            if ($canonical.Count -eq 0) {
                $drift += "no canonical CronCreate /coordinate line in $CanonicalRel"
            }
            if ($canonical.Count -gt 1) {
                foreach ($c in $canonical) { $drift += "duplicate canonical line: $($c.File):$($c.Line) [$($c.Cron)]" }
            }
            foreach ($c in $elsewhere) {
                $drift += "CronCreate /coordinate copied outside the canonical file: $($c.File):$($c.Line) [$($c.Cron)] - point to $CanonicalRel instead"
            }

            if ($canonical.Count -ge 1) {
                $canonCron = $canonical[0].Cron
                $stepMatch = [regex]::Match($canonCron, '^23 \*/([0-9]+) \* \* \*$')
                if (-not $stepMatch.Success) {
                    $drift += "canonical cron [$canonCron] is not of the form '23 */N * * *' (minute 23 is an invariant: executors fire at :41)"
                } else {
                    $step = [int]$stepMatch.Groups[1].Value
                    if ($step -lt 1 -or (24 % $step) -ne 0) {
                        $drift += "canonical hour step $step does not divide 24 (uneven firing across midnight)"
                    }
                    foreach ($b in $found.Bares) {
                        if ($b.Step -ne $step) {
                            $drift += "divergent coordinator cron: $($b.File):$($b.Line) says 23 */$($b.Step), canonical is 23 */$step - write history in hours, not as a cron expression"
                        }
                    }
                }
            }
            return ,$drift
        }

        # Real repo content.
        # .claude/configs carries the source of the deployed global CLAUDE.md;
        # docs is scanned whole (docs/scheduler held a stale value until 2026-11-13).
        $script:repoTexts = @{}
        $script:scanDirs = @('.claude/commands', '.claude/skills', '.claude/rules', '.claude/agents', '.claude/configs', 'docs')
        $script:scanCounts = @{}
        foreach ($dir in $script:scanDirs) {
            $script:scanCounts[$dir] = 0
            $abs = Join-Path $script:repoRoot $dir
            if (-not (Test-Path -LiteralPath $abs)) { continue }
            foreach ($file in (Get-ChildItem -LiteralPath $abs -Recurse -File -Filter '*.md')) {
                $rel = $file.FullName.Substring($script:repoRoot.Length).TrimStart('\', '/').Replace('\', '/')
                $script:repoTexts[$rel] = [System.IO.File]::ReadAllText($file.FullName)
                $script:scanCounts[$dir]++
            }
        }
        $rootClaude = Join-Path $script:repoRoot 'CLAUDE.md'
        if (Test-Path -LiteralPath $rootClaude) {
            $script:repoTexts['CLAUDE.md'] = [System.IO.File]::ReadAllText($rootClaude)
        }

        # Fixture: a healthy two-file tree the mutants start from.
        $script:healthy = @{
            '.claude/commands/coordinate.md' = "intro`nCronCreate(cron: `"23 */6 * * *`", prompt: `"/coordinate`", recurring: true)`noutro"
            '.claude/skills/executor/SKILL.md' = "executors: CronCreate(cron: `"41 */4 * * *`", prompt: `"/executor`", recurring: true)`ncoordinator: see coordinate.md"
        }
    }

    It 'the scan is not mute: it reads the canonical file and a non-trivial number of documents' {
        $script:repoTexts.ContainsKey($script:canonicalRel) | Should -BeTrue
        $script:repoTexts.Count | Should -BeGreaterThan 20
    }

    It 'every scanned tree yields documents (a tree dropped from the list, or renamed, is reported)' {
        $script:scanDirs.Count | Should -Be 6
        $empty = @($script:scanDirs | Where-Object { $script:scanCounts[$_] -lt 1 })
        ($empty -join ', ') | Should -BeNullOrEmpty
        # The two trees that held a copy the first version of this guard did not scan.
        $script:repoTexts.ContainsKey('docs/scheduler/connector-v3-spec.md') | Should -BeTrue
        $script:repoTexts.ContainsKey('.claude/configs/user-global-claude.md') | Should -BeTrue
    }

    It 'the repo holds exactly one CronCreate /coordinate line, in coordinate.md, and nothing diverges from it' {
        $drift = Get-CoordinatorCadenceDrift -Texts $script:repoTexts -CanonicalRel $script:canonicalRel
        # The drift list IS the failure message: each entry names file:line.
        ($drift -join "`n") | Should -BeNullOrEmpty
    }

    It 'the executors cron (41 */4) is not mistaken for a coordinator expression' {
        $found = Get-CoordinatorCadenceFindings -Texts $script:healthy
        @($found.Creates).Count | Should -Be 1
        @($found.Bares).Count | Should -Be 1
        $drift = Get-CoordinatorCadenceDrift -Texts $script:healthy -CanonicalRel $script:canonicalRel
        @($drift).Count | Should -Be 0
    }

    It 'MUTANT 1: a second CronCreate /coordinate line in another file is reported (the pre-2026-11-13 state)' {
        $mutant = $script:healthy.Clone()
        $mutant['.claude/skills/executor/SKILL.md'] += "`nCronCreate(cron: `"23 */12 * * *`", prompt: `"/coordinate`", recurring: true)"
        $drift = Get-CoordinatorCadenceDrift -Texts $mutant -CanonicalRel $script:canonicalRel
        ($drift -join "`n") | Should -Match 'copied outside the canonical file: \.claude/skills/executor/SKILL\.md:3'
        ($drift -join "`n") | Should -Match 'divergent coordinator cron: \.claude/skills/executor/SKILL\.md:3 says 23 \*/12'
    }

    It 'MUTANT 2: a stale bare expression in a doc is reported with its file and line' {
        $mutant = $script:healthy.Clone()
        $mutant['docs/harness/reference/some-checklist.md'] = "row 1`nrow 2: cron ``23 */12`` for ai-01"
        $drift = Get-CoordinatorCadenceDrift -Texts $mutant -CanonicalRel $script:canonicalRel
        @($drift).Count | Should -Be 1
        $drift[0] | Should -Match 'docs/harness/reference/some-checklist\.md:2 says 23 \*/12, canonical is 23 \*/6'
    }

    It 'MUTANT 3: a canonical file that lost its line is reported (a mute guard validates nothing)' {
        $mutant = $script:healthy.Clone()
        $mutant['.claude/commands/coordinate.md'] = "intro`noutro"
        $drift = Get-CoordinatorCadenceDrift -Texts $mutant -CanonicalRel $script:canonicalRel
        ($drift -join "`n") | Should -Match 'no canonical CronCreate /coordinate line'
    }

    It 'MUTANT 4: a canonical line off minute 23, or with a step that does not divide 24, is reported' {
        $offMinute = $script:healthy.Clone()
        $offMinute['.claude/commands/coordinate.md'] = "CronCreate(cron: `"41 */6 * * *`", prompt: `"/coordinate`", recurring: true)"
        ((Get-CoordinatorCadenceDrift -Texts $offMinute -CanonicalRel $script:canonicalRel) -join "`n") | Should -Match "not of the form '23 \*/N \* \* \*'"

        $unevenStep = $script:healthy.Clone()
        $unevenStep['.claude/commands/coordinate.md'] = "CronCreate(cron: `"23 */5 * * *`", prompt: `"/coordinate`", recurring: true)"
        ((Get-CoordinatorCadenceDrift -Texts $unevenStep -CanonicalRel $script:canonicalRel) -join "`n") | Should -Match 'hour step 5 does not divide 24'
    }
}

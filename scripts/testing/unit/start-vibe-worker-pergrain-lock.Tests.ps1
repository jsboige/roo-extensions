# Compile-guard du lock par-grain de start-vibe-worker.ps1 (arbitrage ai-01
# 29/09 15:32Z sect.1 : jusqu'a 3 workers parallels sur grains disjoints).
#
# Le bloc vit au milieu du script (pas une fonction exportee) : ce test EXTRAIT
# le regex du source et le rejoue contre des payloads fixtures — meme contrat que
# reference-github-script-compile-guard (repro exact du bloc, jamais en substring).
#
# Cas fondateur (29/09, mesure live) : le payload WAKE arrive en JSON compact sur
# UNE ligne — les \n y sont ECHAPES (2 chars). La premiere ecriture `(?m)^worktree:`
# ne matchait jamais => lock global => 2e worker exit 75. Le regex doit ancrer sur
# debut de ligne OU \n echappe.
#
# Run: pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/start-vibe-worker-pergrain-lock.Tests.ps1 -Output Detailed"

BeforeAll {
    $Script:WorkerPath = Join-Path $PSScriptRoot "..\..\scheduling\start-vibe-worker.ps1"
    $Script:Source = [IO.File]::ReadAllText($Script:WorkerPath)

    # Extraction du regex tel qu'ecrit (single-quoted PS -> .NET).
    if (-not ($Script:Source -match "(?s)\`$payloadPeek -match '([^']+)'")) {
        throw "regex du lock par-grain introuvable dans start-vibe-worker.ps1"
    }
    $Script:LockRegex = $Matches[1]

    # Fixture 1 : payload WAKE reel (JSON compact one-line, \n ECHAPES = 2 chars).
    # Construit par concatenation pour ne pas laisser bash/PS les re-echapper.
    $nl = '\' + 'n'
    $Script:PayloadOneLine = '{"timestamp":"2026-09-29T16:31:43Z","author":{"machineId":"MYIA-PO-2025"},"content":"[WAKE-VIBE] w3-1-search-f4 (prose-counts 17636)' + $nl + 'baseSha: 1bae7ac519' + $nl + 'worktree: D:/dev/CoursIA-vibe/w3-1-search-f4' + $nl + 'branch: wt/vibe-w3-1-search-f4' + $nl + $nl + 'Mission : tri avant geste."}'

    # Fixture 2 : payload multiline (vrais newlines, format fichier).
    $Script:PayloadMulti = @"
[WAKE-VIBE] g1-x (prose-counts 17636)
baseSha: aaaa1111
worktree: D:/dev/CoursIA-vibe/g1-x
branch: wt/vibe-g1-x
"@

    # Fixture 3 : aucun worktree.
    $Script:PayloadNoWorktree = '{"content":"[WAKE-VIBE] pas de worktree ici"}'
}

Describe "start-vibe-worker lock par-grain (#17636 burst)" {
    It "le regex ancre sur le \n echappe du JSON one-line (cas fondateur exit 75)" {
        $Script:PayloadOneLine -match $Script:LockRegex | Should -BeTrue
        $Matches[1] | Should -BeExactly 'D:/dev/CoursIA-vibe/w3-1-search-f4'
    }

    It "le path capture ne traverse pas le \n echappe suivant (pas d'avalement de branch:)" {
        $null = ($Script:PayloadOneLine -match $Script:LockRegex)
        $Matches[1] | Should -Not -Match '\\\\n'
        $Matches[1] | Should -Not -Match 'branch'
    }

    It "le regex matche aussi le payload multiline (vrais newlines)" {
        $Script:PayloadMulti -match $Script:LockRegex | Should -BeTrue
        ($Matches[1] -split '[\\/]')[-1] | Should -BeExactly 'g1-x'
    }

    It "l'ancre n'est pas degeneree (alternation vide : match partout, ancre perdue)" {
        # Mutation vecue 29/09 : `(?:^|)` matche le JSON one-line SANS exigence
        # d'ancre — le cas fondateur passerait vert sans que l'ancre existe.
        # Pester evalue les args Should en mode contraint : le pattern se calcule
        # dans une variable AVANT l'assertion.
        $anchor = [regex]::Escape('(?:^|') + '[\\]{2}n\)'
        $Script:LockRegex | Should -Match $anchor
    }

    It "sans worktree : pas de match -> LockName reste le lock global historique" {
        $Script:PayloadNoWorktree -match $Script:LockRegex | Should -BeFalse
    }

    It "le leaf derive du LockName est assaini (caracteres non fichier-safe rejetes)" {
        $null = ($Script:PayloadOneLine -match $Script:LockRegex)
        $leaf = ($Matches[1] -split '[\\/]')[-1] -replace '[^A-Za-z0-9._-]', ''
        $leaf | Should -BeExactly 'w3-1-search-f4'
        # [IO.Path]::GetTempPath() en repli : $env:TEMP est null sur le runner CI
        # Ubuntu (review ai-01 #3942 — le cycle de mutation 6/6 n'avait tourne que
        # sous Windows).
        $tmpRoot = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
        (Join-Path $tmpRoot ("vibe-worker-{0}.lock" -f $leaf)) | Should -Not -Match '[^A-Za-z0-9._:\\\-]'
    }
}

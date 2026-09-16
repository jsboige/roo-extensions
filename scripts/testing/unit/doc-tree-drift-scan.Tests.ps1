# Tests unitaires pour scripts/docs/scan-doc-tree-drift.ps1 (#3673 livrable 5)
# Drift-scan doc <-> arbre : decomptes #3321, liens markdown CLAUDE.md,
# chemins backtick (avec allowlist des non-repo intentionnels), parite
# d'epingle gitleaks pre-commit <-> CI.
#
# Syntaxe Pester v5 — executé en CI par le job unit-pester (#3216) via
# scripts/testing/run-pester-tests.ps1. Portable pwsh Windows ET Linux :
# fixtures en slashes + [IO.Path]::GetTempPath(), UTF-8 sans BOM via
# [System.IO.File]::WriteAllText.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/doc-tree-drift-scan.Tests.ps1 -Output Detailed"

$projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/docs/scan-doc-tree-drift.ps1")

    $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "doc-tree-drift-tests-$(Get-Random)"

    # Fixture de base : PROPRE (0 drift attendu). Chaque test mute une copie.
    function New-DriftFixture {
        param([string]$Name)
        $fx = Join-Path $script:TempRoot $Name
        foreach ($d in @(
            ".claude/agents", ".claude/skills/skill-x", ".claude/commands",
            ".claude/rules", "docs", ".github/workflows"
        )) {
            New-Item -ItemType Directory -Path (Join-Path $fx $d) -Force | Out-Null
        }
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText((Join-Path $fx ".claude/agents/agent-a.md"), "a", $utf8)
        [System.IO.File]::WriteAllText((Join-Path $fx ".claude/agents/agent-b.md"), "b", $utf8)
        [System.IO.File]::WriteAllText((Join-Path $fx ".claude/skills/skill-x/SKILL.md"), "s", $utf8)
        [System.IO.File]::WriteAllText((Join-Path $fx ".claude/commands/cmd.md"), "c", $utf8)
        [System.IO.File]::WriteAllText((Join-Path $fx ".claude/rules/context-window.md"), "r", $utf8)
        [System.IO.File]::WriteAllText((Join-Path $fx "docs/rules.md"), "d", $utf8)
        return $fx
    }

    function Write-FixtureClaudeMd {
        param([string]$FxRoot, [string]$Content)
        [System.IO.File]::WriteAllText((Join-Path $FxRoot "CLAUDE.md"), $Content, [System.Text.UTF8Encoding]::new($false))
    }

    $script:CleanClaudeMd = @"
# Fixture

**2 subagents** + **1 skills** + **1 commands** (`/cmd`).

Lien : [rules](docs/rules.md) et ancre [section](docs/rules.md#anchor).
Externe : [gh](https://github.com/) et [mail](mailto:x@y.z).
Backtick OK : ``.claude/rules/context-window.md`` et glob ``.claude/rules/*.md``.
Non-repo intentionnels : ``.claude/settings.json`` / ``.roo/schedules.json`` / ``.claude/local/INTERCOM-{MACHINE}.md``.
"@

    function Write-FixtureParity {
        param([string]$FxRoot, [string]$Rev, [string]$WfVersion)
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText((Join-Path $FxRoot ".pre-commit-config.yaml"), "repos:`n  - repo: https://github.com/gitleaks/gitleaks`n    rev: $Rev`n", $utf8)
        [System.IO.File]::WriteAllText(
            (Join-Path $FxRoot ".github/workflows/secret-scan.yml"),
            "env:`n  GITLEAKS_VERSION: `"$WfVersion`"`n", $utf8)
    }
}

AfterAll {
    Remove-Item $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "Get-DocTreeDrift - decomptes (#3321)" {

    It "fixture propre : zero drift" {
        $fx = New-DriftFixture "clean"
        Write-FixtureClaudeMd $fx $script:CleanClaudeMd
        Write-FixtureParity $fx "v8.24.3" "v8.24.3"
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        $d | Should -Be @()
    }

    It "decompte agents declare != reel : un drift par espece fausse" {
        $fx = New-DriftFixture "counts"
        Write-FixtureClaudeMd $fx $script:CleanClaudeMd.Replace("**2 subagents**", "**5 subagents**")
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        $d.Count | Should -Be 1
        $d[0] | Should -Match "5 agents"
        $d[0] | Should -Match "2 agents"
        $d[0] | Should -Match "3321"
    }

    It "ligne de decomptes absente : drift explicite" {
        $fx = New-DriftFixture "noline"
        Write-FixtureClaudeMd $fx "# Fixture sans ligne de comptes"
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        ($d | Where-Object { $_ -match "^counts:" }) | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-DocTreeDrift - liens markdown" {

    It "lien markdown vers fichier absent : drift" {
        $fx = New-DriftFixture "mdlink"
        Write-FixtureClaudeMd $fx ($script:CleanClaudeMd + "`nCasse : [absent](docs/inexistant.md)")
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        ($d | Where-Object { $_ -match "^md-link:.*inexistant" }) | Should -Not -BeNullOrEmpty
    }

    It "schemas externes et ancres pures : jamais drift" {
        $fx = New-DriftFixture "extern"
        Write-FixtureClaudeMd $fx "# F`n[a](https://x)`n[b](mailto:a@b.c)`n[c](#ancre)"
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        # pas de ligne de comptes -> un drift counts, mais AUCUN md-link
        ($d | Where-Object { $_ -match "^md-link:" }) | Should -Be @()
    }
}

Describe "Get-DocTreeDrift - chemins backtick" {

    It "backtick vers fichier absent : drift" {
        $fx = New-DriftFixture "btmiss"
        Write-FixtureClaudeMd $fx ($script:CleanClaudeMd + "`nRef : ``.claude/rules/absent.md``")
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        ($d | Where-Object { $_ -match "^backtick-path:.*absent\.md" }) | Should -Not -BeNullOrEmpty
    }

    It "chemins intentionnellement non-repo : jamais drift" {
        $fx = New-DriftFixture "allowlist"
        Write-FixtureClaudeMd $fx "# F`n``.claude/settings.json`` ``.roo/schedules.json`` ``.claude/local/INTERCOM-X.md``"
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        ($d | Where-Object { $_ -match "^backtick-path:" }) | Should -Be @()
    }

    It "glob sans correspondance : drift ; glob peuplé : propre" {
        $fx = New-DriftFixture "glob"
        Write-FixtureClaudeMd $fx "# F`nGlob vide : ``docs/*.missing-ext``"
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        ($d | Where-Object { $_ -match "^backtick-path:.*missing-ext" }) | Should -Not -BeNullOrEmpty
        # le glob .claude/rules/*.md de la fixture propre est couvert par le test "fixture propre"
    }
}

Describe "Get-DocTreeDrift - parite gitleaks (lecon CoursIA #10139)" {

    It "rev pre-commit != GITLEAKS_VERSION CI : drift" {
        $fx = New-DriftFixture "skew"
        Write-FixtureClaudeMd $fx $script:CleanClaudeMd
        Write-FixtureParity $fx "v8.24.3" "v8.30.1"
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        ($d | Where-Object { $_ -match "^gitleaks-parity:.*v8\.24\.3.*v8\.30\.1" }) | Should -Not -BeNullOrEmpty
    }

    It "une seule surface presente : drift (garde inerte)" {
        $fx = New-DriftFixture "solo"
        Write-FixtureClaudeMd $fx $script:CleanClaudeMd
        Write-FixtureParity $fx "v8.24.3" $null
        Remove-Item (Join-Path $fx ".github/workflows/secret-scan.yml") -Force
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        ($d | Where-Object { $_ -match "^gitleaks-parity:" }) | Should -Not -BeNullOrEmpty
    }

    It "aucune surface : hors perimetre, pas de drift" {
        $fx = New-DriftFixture "nosurface"
        Write-FixtureClaudeMd $fx $script:CleanClaudeMd
        $d = @(Get-DocTreeDrift -RepoRoot $fx)
        ($d | Where-Object { $_ -match "^gitleaks-parity:" }) | Should -Be @()
    }
}

Describe "Get-DocTreeDrift - canary live sur ce depot" {

    It "le depot courant est propre (scan complet, exit-equivalent vide)" {
        $d = @(Get-DocTreeDrift -RepoRoot $projectRoot)
        $d | Should -Be @()
    }
}

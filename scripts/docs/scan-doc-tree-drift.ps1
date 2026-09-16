# Script: scan-doc-tree-drift.ps1
# Description: Drift-scan doc <-> arbre (#3673 livrable 5, adapte du pattern CoursIA
#              docs-link-check/catalog-drift) : les references de CLAUDE.md doivent
#              designer des fichiers reels, la ligne de decomptes (#3321) doit dire
#              la verite, et l'epingle de version gitleaks doit etre identique sur
#              ses deux surfaces (pre-commit + CI).
# Date: 2026-09-16
# Usage (CLI) : pwsh -File scripts/docs/scan-doc-tree-drift.ps1 [-RepoRoot <path>]
#               exit 0 = aucun drift ; exit 1 = drift (details sur stdout)
# Usage (test): dot-source puis appeler Get-DocTreeDrift -RepoRoot <fixture>
#               (scripts/testing/unit/doc-tree-drift-scan.Tests.ps1)
# Portabilite: PS 5.1 + pwsh 7 (pas d'operateur ??/ternaire, Join-Path 2 args max)

param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

function Get-DocTreeDrift {
    <#
    .SYNOPSIS
    Retourne la liste des drifts doc<->arbre detectes (vide = propre).
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $findings = @()

    # ---------------------------------------------------------------------------
    # Check 1 -- ligne de decomptes (#3321) : "20 subagents + 11 skills + 5 commands"
    # La regle exige un recompte firsthand a chaque modification de cette ligne ;
    # ce scan rend le recompte mecanique.
    # ---------------------------------------------------------------------------
    $claudeMdPath = Join-Path $RepoRoot "CLAUDE.md"
    if (-not (Test-Path -LiteralPath $claudeMdPath)) {
        $findings += "counts: CLAUDE.md absent sous $RepoRoot"
        return $findings
    }
    $claudeMd = Get-Content -LiteralPath $claudeMdPath -Raw -Encoding UTF8

    $countsLine = [regex]::Match($claudeMd, '\*\*(\d+) subagents\*\*\s*\+\s*\*\*(\d+) skills\*\*\s*\+\s*\*\*(\d+) commands\*\*')
    if (-not $countsLine.Success) {
        $findings += "counts: ligne de decomptes (`**N subagents** + ...`) introuvable dans CLAUDE.md -- la regle #3321 s'appuie sur elle"
    }
    else {
        $declared = @{}
        $declared.agents  = [int]$countsLine.Groups[1].Value
        $declared.skills  = [int]$countsLine.Groups[2].Value
        $declared.commands = [int]$countsLine.Groups[3].Value

        $actual = @{}
        $actual.agents  = @(Get-ChildItem -Path (Join-Path $RepoRoot ".claude/agents") -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue).Count
        $actual.skills  = @(Get-ChildItem -Path (Join-Path $RepoRoot ".claude/skills") -Recurse -Filter "SKILL.md" -File -ErrorAction SilentlyContinue).Count
        $actual.commands = @(Get-ChildItem -Path (Join-Path $RepoRoot ".claude/commands") -Filter "*.md" -File -ErrorAction SilentlyContinue).Count

        foreach ($kind in @("agents", "skills", "commands")) {
            if ($declared[$kind] -ne $actual[$kind]) {
                $findings += "counts: CLAUDE.md declare $($declared[$kind]) $kind, l'arbre en compte $($actual[$kind]) $kind -- regle #3321 : recompter firsthand, jamais propager un compte non verifie"
            }
        }
    }

    # ---------------------------------------------------------------------------
    # Check 2 -- liens markdown de CLAUDE.md vers des fichiers du depot.
    # (scan-broken-links.ps1 couvre deja tout l'arbre .md ; ce check rend CLAUDE.md
    # autonome dans son propre verdict.)
    # ---------------------------------------------------------------------------
    $linkRegex = '\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)'
    foreach ($m in [regex]::Matches($claudeMd, $linkRegex)) {
        $target = $m.Groups[2].Value.Trim()
        if ($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') { continue }  # scheme externe (http, mailto...)
        $filePart = ($target -split '#')[0]
        if ([string]::IsNullOrWhiteSpace($filePart)) { continue }      # ancre pure
        $resolved = Join-Path $RepoRoot ($filePart.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if (-not (Test-Path -LiteralPath $resolved)) {
            $findings += "md-link: [$($m.Groups[1].Value)]($target) -- cible absente de l'arbre"
        }
    }

    # ---------------------------------------------------------------------------
    # Check 3 -- references de chemins entre backticks designant le depot.
    # Racines reconnues ; les chemins maison (~), absolus et modeles {PLACEHOLDER}
    # sont hors perimetre.
    # ---------------------------------------------------------------------------
    $repoRoots = @(
        '^\.(claude|roo|github)/', '^docs/', '^scripts/', '^roo-config/',
        '^mcps/', '^tests/', '^CLAUDE\.md$', '^CLAUDE\.local\.md$', '^\.mcp\.json$',
        '^\.gitattributes$', '^\.gitleaks\.toml$', '^\.pre-commit-config\.yaml$'
    )
    # References intentionnelles a des chemins qui ne vivent PAS dans le depot
    # (config machine, canal local) -- documentees dans CLAUDE.md, volontairement
    # absentes de l'arbre :
    #   .claude/settings.json  -> "INTERDIT" dans le depot (vit dans settings machine)
    #   .roo/schedules.json    -> "JAMAIS modifier directement" (machine)
    #   .claude/local/         -> INTERCOM local, gitignore
    #   CLAUDE.local.md        -> config Locale "Machine (gitignored)" (hierarchie)
    $intentionalNonRepo = @(
        '^\.claude/settings\.json$',
        '^\.claude/settings\.local\.json$',
        '^\.roo/schedules\.json$',
        '^\.claude/local/',
        '^CLAUDE\.local\.md$'
    )

    # [^`\r\n] : une reference backtick tient sur une ligne -- sinon la regex
    # capture tout le corps d'un bloc code fence comme un unique token.
    foreach ($m in [regex]::Matches($claudeMd, '`([^`\r\n]+)`')) {
        $token = $m.Groups[1].Value.Trim()
        $isRepoPath = $false
        foreach ($r in $repoRoots) { if ($token -match $r) { $isRepoPath = $true; break } }
        if (-not $isRepoPath) { continue }
        $skip = $false
        foreach ($r in $intentionalNonRepo) { if ($token -match $r) { $skip = $true; break } }
        if ($skip) { continue }
        if ($token -match '[{]') { continue }                   # gabarit {MACHINE} etc.
        $resolved = Join-Path $RepoRoot ($token.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        $exists = if ($token -match '[*?]') { Test-Path -Path $resolved } else { Test-Path -LiteralPath $resolved }
        if (-not $exists) {
            $findings += "backtick-path: ``$token`` -- absent de l'arbre (et non liste comme chemin intentionnellement non-repo)"
        }
    }

    # ---------------------------------------------------------------------------
    # Check 4 -- parite d'epingle gitleaks entre pre-commit et CI (#3673).
    # Lecon CoursIA #10139 : un pre-commit vert qui ne predit pas la CI (versions
    # divergentes de l'outil) est un garde inerte. V1 mecanique : les deux surfaces
    # doivent citer la meme version.
    # ---------------------------------------------------------------------------
    $preCommitPath = Join-Path $RepoRoot ".pre-commit-config.yaml"
    $scanWfPath = Join-Path $RepoRoot ".github/workflows/secret-scan.yml"
    $preCommitRev = $null
    $wfVersion = $null
    if (Test-Path -LiteralPath $preCommitPath) {
        $rev = [regex]::Match((Get-Content -LiteralPath $preCommitPath -Raw), '(?m)^\s*rev:\s*(v[0-9][0-9A-Za-z.\-]*)')
        if ($rev.Success) { $preCommitRev = $rev.Groups[1].Value }
    }
    if (Test-Path -LiteralPath $scanWfPath) {
        $ver = [regex]::Match((Get-Content -LiteralPath $scanWfPath -Raw), 'GITLEAKS_VERSION:\s*"?([vV][0-9][0-9A-Za-z.\-]*)"?')
        if ($ver.Success) { $wfVersion = $ver.Groups[1].Value }
    }
    if ($null -eq $preCommitRev -and $null -eq $wfVersion) {
        # ni pre-commit ni secret-scan : hors perimetre du check (depot sans les surfaces)
    }
    elseif ($null -eq $preCommitRev -or $null -eq $wfVersion) {
        $present = if ($null -ne $preCommitRev) { "pre-commit (rev $preCommitRev)" } else { "secret-scan.yml (GITLEAKS_VERSION $wfVersion)" }
        $absent = if ($null -eq $preCommitRev) { ".pre-commit-config.yaml rev:" } else { "secret-scan.yml GITLEAKS_VERSION" }
        $findings += "gitleaks-parity: $present sans counterpart -- $absent introuvable (lecon #10139 : une surface sans l'autre est un garde inerte)"
    }
    elseif ($preCommitRev -ne $wfVersion) {
        $findings += "gitleaks-parity: pre-commit rev $preCommitRev != CI GITLEAKS_VERSION $wfVersion -- les deux surfaces doivent bouger ensemble"
    }

    # pas d'enrobage par l'operateur virgule : les appelants font deja @( ... ),
    # et `, $findings` vide se lirait @(@()) (longueur 1) au lieu de @().
    return $findings
}

# --- Entree CLI (saute quand dot-source par les tests : InvocationName = '.') ---
if ($MyInvocation.InvocationName -ne '.') {
    $drift = @(Get-DocTreeDrift -RepoRoot $RepoRoot)
    if ($drift.Count -gt 0) {
        Write-Host "=== DOC-TREE DRIFT SCAN : $($drift.Count) drift(s) ===" -ForegroundColor Red
        foreach ($d in $drift) { Write-Host "  DRIFT  $d" -ForegroundColor Red }
        exit 1
    }
    Write-Host "=== DOC-TREE DRIFT SCAN : clean (CLAUDE.md <-> arbre, decomptes #3321, parite gitleaks) ===" -ForegroundColor Green
    exit 0
}

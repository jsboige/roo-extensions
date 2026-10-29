#Requires -Version 5.1
<#
    Garde de derive — resolution de l'entree MCP documentee (#2639 WS3 passe 2).

    Les guides `docs/guides/MCP-TROUBLESHOOTING-UNIFIED.md` et
    `docs/guides/TROUBLESHOOTING-GUIDE.md` prescrivent comment trouver l'entree SERVIE de
    `roo-state-manager`. La regle reelle (#3713, lue au code) est :

        marqueur `build-current`  ->  millesime `build-<sha16>/index.js`
        `build-out/`  = scratch tsc du build, JAMAIS l'entree servie
        `build/`      = legacy gele, jamais reecrit (ne pas le ressusciter)

    Ce fichier verrouille les deux moities :

    1. la RESOLUTION documentee, exercee sur une fixture SANS `build-out/`, comparee au
       resolveur canonique du depot (`resolve-build-dir.mjs`) — la divergence du cas
       « aucun marqueur » est intentionnelle et assertee comme telle ;
    2. les AFFIRMATIONS des guides : plus de `build-out/index.js` presente comme entree,
       marqueur nomme, `dist/index.js` conserve pour jinavigator, note historique
       Quickfiles presente dans le guide d'exploration.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
    $script:GuidesDir = Join-Path $script:RepoRoot "docs/guides"
    $script:ResolverPath = Join-Path $script:RepoRoot "mcps/internal/servers/roo-state-manager/scripts/lib/resolve-build-dir.mjs"
    # Seam de TEST : un worktree peut ne pas peupler le submodule, et la CI, elle,
    # l'a toujours. Un siege dans ce cas designe le resolveur de son checkout
    # principal par RSMDOC_RESOLVER ; sinon on utilise le chemin par defaut.
    if (-not (Test-Path $script:ResolverPath) -and $env:RSMDOC_RESOLVER) {
        $script:ResolverPath = $env:RSMDOC_RESOLVER
    }

    # Resolution TELLE QUE DOCUMENTEE dans les deux guides : marqueur d'abord, puis dist/.
    # Aucune dependance a `build-out/` (scratch) ni a `build/` (legacy gele).
    function Resolve-DocumentedEntry {
        param([string]$ServerDir)
        $marker = Join-Path $ServerDir "build-current"
        if (Test-Path $marker) {
            $vintage = (Get-Content -Raw -LiteralPath $marker).Trim()
            if ($vintage -match '^build-[0-9a-f]{16}$' -and (Test-Path (Join-Path $ServerDir "$vintage/index.js"))) {
                return Join-Path $ServerDir "$vintage/index.js"
            }
        }
        $dist = Join-Path $ServerDir "dist/index.js"
        if (Test-Path $dist) { return $dist }
        return $null
    }

    function New-RsmFixture {
        param(
            [string]$Root,
            [string]$Vintage,
            [switch]$WithScratch,
            [switch]$WithDist,
            [switch]$VintageIndexMissing
        )
        $dir = Join-Path $Root ("rsm-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null

        if ($Vintage) {
            Set-Content -LiteralPath (Join-Path $dir "build-current") -Value $Vintage -Encoding ascii -NoNewline
            $vdir = Join-Path $dir $Vintage
            New-Item -ItemType Directory -Path $vdir -Force | Out-Null
            if (-not $VintageIndexMissing) {
                Set-Content -LiteralPath (Join-Path $vdir "index.js") -Value "// vintage index (fixture)" -Encoding ascii
            }
        }
        if ($WithScratch) {
            $scratch = Join-Path $dir "build-out"
            New-Item -ItemType Directory -Path $scratch -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $scratch "index.js") -Value "// scratch tsc (fixture)" -Encoding ascii
        }
        if ($WithDist) {
            $dist = Join-Path $dir "dist"
            New-Item -ItemType Directory -Path $dist -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $dist "index.js") -Value "// dist (fixture)" -Encoding ascii
        }
        return $dir
    }
}

Describe "Resolution de l'entree RSM documentee (#2639 WS3 p2)" {
    BeforeEach {
        $script:Tmp = Join-Path ([IO.Path]::GetTempPath()) ("rsmdoc-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
    }
    AfterEach {
        if ($script:Tmp -and (Test-Path $script:Tmp)) {
            Remove-Item -Recurse -Force $script:Tmp -ErrorAction SilentlyContinue
        }
    }

    It "resout le millesime publie sur une fixture SANS build-out" {
        $vintage = "build-0123456789abcdef"
        $dir = New-RsmFixture -Root $script:Tmp -Vintage $vintage

        (Test-Path (Join-Path $dir "build-out")) | Should -BeFalse -Because "la fixture ne doit dependre d'aucun scratch"

        (Resolve-DocumentedEntry -ServerDir $dir) | Should -Be (Join-Path $dir "$vintage/index.js")
    }

    It "prefere le millesime publie au scratch build-out quand les deux existent" {
        $vintage = "build-fedcba9876543210"
        $dir = New-RsmFixture -Root $script:Tmp -Vintage $vintage -WithScratch

        (Test-Path (Join-Path $dir "build-out/index.js")) | Should -BeTrue
        (Resolve-DocumentedEntry -ServerDir $dir) | Should -Be (Join-Path $dir "$vintage/index.js")
    }

    It "retombe sur dist/index.js quand aucun millesime n'est publie" {
        $dir = New-RsmFixture -Root $script:Tmp -WithDist

        (Resolve-DocumentedEntry -ServerDir $dir) | Should -Be (Join-Path $dir "dist/index.js")
    }

    It "ne rend rien quand ni marqueur ni dist n'existent (et ne ressuscite pas le legacy gelé)" {
        $dir = New-RsmFixture -Root $script:Tmp -WithScratch

        (Resolve-DocumentedEntry -ServerDir $dir) | Should -BeNullOrEmpty
        (Test-Path (Join-Path $dir "build")) | Should -BeFalse
    }

    It "ignore un marqueur dont le millesime n'a pas d'index.js" {
        $vintage = "build-0011223344556677"
        $dir = New-RsmFixture -Root $script:Tmp -Vintage $vintage -VintageIndexMissing -WithDist

        (Resolve-DocumentedEntry -ServerDir $dir) | Should -Be (Join-Path $dir "dist/index.js")
    }

    It "est d'accord avec le resolveur canonique du depot quand un millesime est publie" {
        $node = Get-Command node -ErrorAction SilentlyContinue
        if (-not $node) {
            Set-ItResult -Skipped -Because "node absent sur ce siege"
            return
        }
        if (-not (Test-Path $script:ResolverPath)) {
            Set-ItResult -Skipped -Because "resolve-build-dir.mjs absent (submodule non peuple)"
            return
        }

        $vintage = "build-89abcdef01234567"
        $dir = New-RsmFixture -Root $script:Tmp -Vintage $vintage -WithScratch

        $env:RSMDOC_RESOLVER = $script:ResolverPath
        $env:RSMDOC_FIXTURE = $dir
        try {
            $canonicalDir = (& node --input-type=module -e "const { pathToFileURL } = await import('node:url'); const m = await import(pathToFileURL(process.env.RSMDOC_RESOLVER).href); process.stdout.write(m.resolveBuildDir(process.env.RSMDOC_FIXTURE));" 2>$null)
        } finally {
            Remove-Item Env:RSMDOC_RESOLVER -ErrorAction SilentlyContinue
            Remove-Item Env:RSMDOC_FIXTURE -ErrorAction SilentlyContinue
        }

        $canonicalDir | Should -Not -BeNullOrEmpty
        # Le canonique rend le REPERTOIRE du millesime ; le guide rend le FICHIER d'entree.
        (Split-Path -Parent (Resolve-DocumentedEntry -ServerDir $dir)) | Should -Be ([string]$canonicalDir).Trim()
    }

    It "diverge INTENTIONNELLEMENT du canonique sans marqueur (legacy gele vs rien)" {
        $node = Get-Command node -ErrorAction SilentlyContinue
        if (-not $node -or -not (Test-Path $script:ResolverPath)) {
            Set-ItResult -Skipped -Because "node ou resolveur absent sur ce siege"
            return
        }

        $dir = New-RsmFixture -Root $script:Tmp -WithScratch

        $env:RSMDOC_RESOLVER = $script:ResolverPath
        $env:RSMDOC_FIXTURE = $dir
        try {
            $canonicalDir = (& node --input-type=module -e "const { pathToFileURL } = await import('node:url'); const m = await import(pathToFileURL(process.env.RSMDOC_RESOLVER).href); process.stdout.write(m.resolveBuildDir(process.env.RSMDOC_FIXTURE));" 2>$null)
        } finally {
            Remove-Item Env:RSMDOC_RESOLVER -ErrorAction SilentlyContinue
            Remove-Item Env:RSMDOC_FIXTURE -ErrorAction SilentlyContinue
        }

        # Le resolveur generique retombe sur `build/` (compat pre-#3713) ; les guides,
        # eux, refusent le legacy gele et disent "aucune version publiee".
        (Split-Path -Leaf ([string]$canonicalDir).Trim()) | Should -Be "build"
        (Resolve-DocumentedEntry -ServerDir $dir) | Should -BeNullOrEmpty
    }
}

Describe "Affirmations des guides MCP (#2639 WS3 p2)" {
    It "ne presente plus build-out/index.js comme entree de roo-state-manager" {
        foreach ($guide in @("MCP-TROUBLESHOOTING-UNIFIED.md", "TROUBLESHOOTING-GUIDE.md")) {
            $path = Join-Path $script:GuidesDir $guide
            Test-Path $path | Should -BeTrue -Because "$guide doit exister"
            $text = Get-Content -Raw -LiteralPath $path

            $text | Should -Not -Match 'roo-state-manager"?\s*=\s*"build-out/index\.js' -Because "$guide ne doit pas donner build-out comme entree"
            $text | Should -Not -Match 'Build="build-out/index\.js"' -Because "$guide ne doit pas valider build-out comme entree"
            $text | Should -Not -Match 'node build-out/index\.js' -Because "le scratch tsc n'est pas une entree de demarrage"
        }
    }

    It "nomme le marqueur build-current et le motif du millesime" {
        foreach ($guide in @("MCP-TROUBLESHOOTING-UNIFIED.md", "TROUBLESHOOTING-GUIDE.md")) {
            $text = Get-Content -Raw -LiteralPath (Join-Path $script:GuidesDir $guide)
            $text | Should -Match 'build-current' -Because "$guide doit nommer le marqueur"
            $text | Should -Match 'build-\[0-9a-f\]\{16\}' -Because "$guide doit nommer le motif du millesime"
        }
    }

    It "conserve dist/index.js pour jinavigator-server" {
        foreach ($guide in @("MCP-TROUBLESHOOTING-UNIFIED.md", "TROUBLESHOOTING-GUIDE.md")) {
            $text = Get-Content -Raw -LiteralPath (Join-Path $script:GuidesDir $guide)
            $text | Should -Match 'jinavigator-server"\s*=\s*"dist/index\.js|jinavigator-server -> dist|jinavigator-server -> dist/index\.js|dist/index\.js \(tsc outDir\)' -Because "$guide doit garder la sortie dist de jinavigator"
        }
    }

    It "parametre les racines de checkout (pas de racine figee dans les guides)" {
        foreach ($guide in @("MCP-TROUBLESHOOTING-UNIFIED.md", "TROUBLESHOOTING-GUIDE.md")) {
            $text = Get-Content -Raw -LiteralPath (Join-Path $script:GuidesDir $guide)
            $text | Should -Match 'ROO_EXTENSIONS_ROOT' -Because "$guide doit parametrer la racine"
            $text | Should -Not -Match '"d:/dev/roo-extensions/mcps' -Because "une racine figee ne s'execute pas sur un autre siege"
            $text | Should -Not -Match 'C:/Users/jsboi/' -Because "un profil utilisateur figé ne s'execute pas sur un autre siege"
        }
    }

    It "porte la note historique Quickfiles dans le guide d'exploration" {
        $text = Get-Content -Raw -LiteralPath (Join-Path $script:GuidesDir "guide-exploration-prompts-natifs.md")
        $text | Should -Match 'Quickfiles MCP' -Because "la section retiree doit rester tracee"
        $text | Should -Match '#3423' -Because "la note doit citer la suppression"
        $text | Should -Match 'Read/Write/Edit' -Because "la note doit nommer le remplacement"
    }
}

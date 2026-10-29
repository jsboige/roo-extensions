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

    1. la RESOLUTION documentee — le code TESTE est le code du GUIDE, extrait a l'execution
       (aucune copie dans ce fichier : une mutation du guide change le resultat, voir les
       temoins de mutation) — exercee sur des fixtures SANS `build-out/`, et comparee au
       resolveur canonique du depot (`resolve-build-dir.mjs`) ; la divergence du cas
       « aucun marqueur » est intentionnelle et assertee comme telle ;
    2. les AFFIRMATIONS des guides : plus de `build-out/index.js` presente comme entree,
       marqueur nomme, `dist/index.js` conserve pour jinavigator, note historique
       Quickfiles presente, et « marqueur publie absent » DISTINGUE de « aucune entree
       servie » (un siege ancien peut encore servir le legacy gele `build/index.js`).
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

    # --- extraction du code DOCUMENTE ------------------------------------------------
    # On lit le bloc ```powershell du guide et on coupe la SEULE definition de fonction
    # demandee (accolades equilibrees). C'est ce texte-la qui sera execute : le test ne
    # porte aucune copie de la regle.
    function Get-GuideFunctionBlock {
        param([string]$GuidePath, [string]$FunctionName)

        if (-not (Test-Path $GuidePath)) { return $null }
        $blocks = @()
        $current = $null
        foreach ($line in (Get-Content -LiteralPath $GuidePath)) {
            if ($line -match '^\s*```') {
                if ($null -eq $current) { $current = @() } else { $blocks += , $current; $current = $null }
                continue
            }
            if ($null -ne $current) { $current += $line }
        }
        if ($null -ne $current) { $blocks += , $current }

        $pattern = "^\s*function\s+" + [regex]::Escape($FunctionName) + "\b"
        foreach ($block in $blocks) {
            $start = -1
            for ($i = 0; $i -lt $block.Count; $i++) {
                if ($block[$i] -match $pattern) { $start = $i; break }
            }
            if ($start -lt 0) { continue }

            $out = @()
            $depth = 0
            for ($i = $start; $i -lt $block.Count; $i++) {
                $text = $block[$i]
                $out += $text
                $depth += ([regex]::Matches($text, '\{')).Count
                $depth -= ([regex]::Matches($text, '\}')).Count
                if ($i -gt $start -and $depth -le 0) { break }
            }
            return ($out -join "`r`n")
        }
        return $null
    }

    # Execute un texte de fonction extrait (ou MUTE) dans une portee neuve et rend son resultat.
    function Invoke-DocumentedResolver {
        param([string]$FunctionText, [string]$ServerDir, [string]$WorkDir)
        if (-not $FunctionText) { throw "extraction vide : le guide ne porte plus la fonction attendue" }
        $file = Join-Path $WorkDir ("resolver-" + [guid]::NewGuid().ToString("N").Substring(0, 8) + ".ps1")
        Set-Content -LiteralPath $file -Value $FunctionText -Encoding utf8
        return (& { param($p, $dir) . $p; Get-McpEntry -ServerDir $dir } $file $ServerDir)
    }

    function Invoke-DocumentedDiagnostic {
        param([string]$FunctionText, [string]$RepoRoot, [string]$WorkDir)
        if (-not $FunctionText) { throw "extraction vide : le guide ne porte plus la fonction attendue" }
        $file = Join-Path $WorkDir ("diag-" + [guid]::NewGuid().ToString("N").Substring(0, 8) + ".ps1")
        Set-Content -LiteralPath $file -Value $FunctionText -Encoding utf8
        # Write-Host ecrit sur le flux Information : `*>&1` est requis pour le capturer
        # (`2>&1` ne prend que stderr et ne rendrait que la valeur de retour booleenne).
        return (& { param($p, $root) . $p; Invoke-McpDiagnostic -RepoRoot $root } $file $RepoRoot *>&1 | Out-String)
    }

    function New-RsmFixture {
        param(
            [string]$Root,
            [string]$Vintage,
            [switch]$WithScratch,
            [switch]$WithDist,
            [switch]$WithLegacy,
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
        if ($WithLegacy) {
            $legacy = Join-Path $dir "build"
            New-Item -ItemType Directory -Path $legacy -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $legacy "index.js") -Value "// legacy gele (fixture)" -Encoding ascii
        }
        return $dir
    }

    # Arborescence que `Invoke-McpDiagnostic` attend : <root>/mcps/internal/servers/<mcp>
    function New-DiagRoot {
        param([string]$Root, [string]$Vintage, [switch]$WithLegacy, [switch]$WithScratch)
        $servers = Join-Path $Root "mcps/internal/servers"
        $rsm = Join-Path $servers "roo-state-manager"
        $nav = Join-Path $servers "jinavigator-server"
        New-Item -ItemType Directory -Path $rsm -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $nav "dist") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $nav "dist/index.js") -Value "// jinavigator dist (fixture)" -Encoding ascii

        if ($Vintage) {
            Set-Content -LiteralPath (Join-Path $rsm "build-current") -Value $Vintage -Encoding ascii -NoNewline
            $vdir = Join-Path $rsm $Vintage
            New-Item -ItemType Directory -Path $vdir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $vdir "index.js") -Value "// vintage index (fixture)" -Encoding ascii
        }
        if ($WithScratch) {
            New-Item -ItemType Directory -Path (Join-Path $rsm "build-out") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $rsm "build-out/index.js") -Value "// scratch tsc (fixture)" -Encoding ascii
        }
        if ($WithLegacy) {
            New-Item -ItemType Directory -Path (Join-Path $rsm "build") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $rsm "build/index.js") -Value "// legacy gele (fixture)" -Encoding ascii
        }
        return $Root
    }

    $script:GuideAResolver = Get-GuideFunctionBlock -GuidePath (Join-Path $script:GuidesDir "MCP-TROUBLESHOOTING-UNIFIED.md") -FunctionName "Get-McpEntry"
    $script:GuideBDiag = Get-GuideFunctionBlock -GuidePath (Join-Path $script:GuidesDir "TROUBLESHOOTING-GUIDE.md") -FunctionName "Invoke-McpDiagnostic"
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

    It "extrait et execute le resolveur ECRIT DANS LE GUIDE (pas une copie du test)" {
        $script:GuideAResolver | Should -Not -BeNullOrEmpty -Because "le guide doit porter la fonction Get-McpEntry"
        $script:GuideAResolver | Should -Match 'build-current' -Because "le bloc execute est celui du guide"
        $script:GuideAResolver | Should -Match '^function Get-McpEntry' -Because "l'extraction coupe la definition complete"
    }

    It "resout le millesime publie sur une fixture SANS build-out" {
        $vintage = "build-0123456789abcdef"
        $dir = New-RsmFixture -Root $script:Tmp -Vintage $vintage

        (Test-Path (Join-Path $dir "build-out")) | Should -BeFalse -Because "la fixture ne doit dependre d'aucun scratch"

        (Invoke-DocumentedResolver -FunctionText $script:GuideAResolver -ServerDir $dir -WorkDir $script:Tmp) |
            Should -Be (Join-Path $dir "$vintage/index.js")
    }

    It "prefere le millesime publie au scratch build-out quand les deux existent" {
        $vintage = "build-fedcba9876543210"
        $dir = New-RsmFixture -Root $script:Tmp -Vintage $vintage -WithScratch

        (Test-Path (Join-Path $dir "build-out/index.js")) | Should -BeTrue
        (Invoke-DocumentedResolver -FunctionText $script:GuideAResolver -ServerDir $dir -WorkDir $script:Tmp) |
            Should -Be (Join-Path $dir "$vintage/index.js")
    }

    It "retombe sur dist/index.js quand aucun millesime n'est publie" {
        $dir = New-RsmFixture -Root $script:Tmp -WithDist

        (Invoke-DocumentedResolver -FunctionText $script:GuideAResolver -ServerDir $dir -WorkDir $script:Tmp) |
            Should -Be (Join-Path $dir "dist/index.js")
    }

    It "ne rend rien quand ni marqueur ni dist n'existent, et ne ressuscite pas le legacy gele" {
        $dir = New-RsmFixture -Root $script:Tmp -WithScratch -WithLegacy

        (Invoke-DocumentedResolver -FunctionText $script:GuideAResolver -ServerDir $dir -WorkDir $script:Tmp) |
            Should -BeNullOrEmpty -Because "build/ est gele : il ne redevient jamais l'entree servie"
    }

    It "ignore un marqueur dont le millesime n'a pas d'index.js" {
        $vintage = "build-0011223344556677"
        $dir = New-RsmFixture -Root $script:Tmp -Vintage $vintage -VintageIndexMissing -WithDist

        (Invoke-DocumentedResolver -FunctionText $script:GuideAResolver -ServerDir $dir -WorkDir $script:Tmp) |
            Should -Be (Join-Path $dir "dist/index.js")
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
        (Split-Path -Parent (Invoke-DocumentedResolver -FunctionText $script:GuideAResolver -ServerDir $dir -WorkDir $script:Tmp)) |
            Should -Be ([string]$canonicalDir).Trim()
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
        # eux, refusent le legacy gele et n'annoncent aucune entree publiee.
        (Split-Path -Leaf ([string]$canonicalDir).Trim()) | Should -Be "build"
        (Invoke-DocumentedResolver -FunctionText $script:GuideAResolver -ServerDir $dir -WorkDir $script:Tmp) |
            Should -BeNullOrEmpty
    }

    # --- temoins de mutation : le test suit le GUIDE, pas une copie -------------------
    It "MUTATION : renommer le marqueur dans le guide change le resultat (donc le test lit le guide)" {
        $vintage = "build-aabbccddeeff0011"
        $dir = New-RsmFixture -Root $script:Tmp -Vintage $vintage

        $original = Invoke-DocumentedResolver -FunctionText $script:GuideAResolver -ServerDir $dir -WorkDir $script:Tmp
        $mutated = $script:GuideAResolver -replace '"build-current"', '"build-out"'
        $mutated | Should -Not -Be $script:GuideAResolver -Because "la mutation doit effectivement toucher le texte extrait"

        $afterMutation = Invoke-DocumentedResolver -FunctionText $mutated -ServerDir $dir -WorkDir $script:Tmp

        $original | Should -Be (Join-Path $dir "$vintage/index.js")
        $afterMutation | Should -BeNullOrEmpty -Because "avec un marqueur renomme, le millesime n'est plus resolu : la garde mord"
    }

    It "MUTATION : relacher le motif du millesime dans le guide change le resultat" {
        $dir = New-RsmFixture -Root $script:Tmp -Vintage "build-NOT-A-SHA" -WithDist

        $original = Invoke-DocumentedResolver -FunctionText $script:GuideAResolver -ServerDir $dir -WorkDir $script:Tmp
        $mutated = $script:GuideAResolver -replace '\^build-\[0-9a-f\]\{16\}\$', '^build-'
        $mutated | Should -Not -Be $script:GuideAResolver

        $afterMutation = Invoke-DocumentedResolver -FunctionText $mutated -ServerDir $dir -WorkDir $script:Tmp

        $original | Should -Be (Join-Path $dir "dist/index.js") -Because "un nom de millesime non conforme n'est pas retenu"
        $afterMutation | Should -Be (Join-Path $dir "build-NOT-A-SHA/index.js") -Because "motif relache = la garde ne mord plus"
    }
}

Describe "Diagnostic : « marqueur publie absent » n'est pas « aucune entree servie » (#4431)" {
    BeforeEach {
        $script:Tmp = Join-Path ([IO.Path]::GetTempPath()) ("rsmdiag-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
    }
    AfterEach {
        if ($script:Tmp -and (Test-Path $script:Tmp)) {
            Remove-Item -Recurse -Force $script:Tmp -ErrorAction SilentlyContinue
        }
    }

    It "extrait la fonction de diagnostic du guide" {
        $script:GuideBDiag | Should -Not -BeNullOrEmpty
        $script:GuideBDiag | Should -Match '^function Invoke-McpDiagnostic'
        $script:GuideBDiag | Should -Match 'build-current'
    }

    It "annonce un millesime publie (et pas MANQUANT) quand le marqueur est la" {
        $root = New-DiagRoot -Root (Join-Path $script:Tmp "root-publie") -Vintage "build-1122334455667788"
        $out = Invoke-DocumentedDiagnostic -FunctionText $script:GuideBDiag -RepoRoot $root -WorkDir $script:Tmp

        $out | Should -Not -Match 'Aucune version publiee pour roo-state-manager'
        $out | Should -Not -Match 'MILLESIME PUBLIE ABSENT'
    }

    It "sur une fixture LEGACY (build/index.js sans marqueur) ne rapporte PAS une absence trompeuse" {
        $root = New-DiagRoot -Root (Join-Path $script:Tmp "root-legacy") -WithLegacy
        $out = Invoke-DocumentedDiagnostic -FunctionText $script:GuideBDiag -RepoRoot $root -WorkDir $script:Tmp

        $out | Should -Match 'MILLESIME PUBLIE ABSENT' -Because "le marqueur publie manque, c'est le fait a rapporter"
        $out | Should -Match 'legacy' -Because "le wrapper peut encore servir le legacy gele : il faut le dire"
        $out | Should -Not -Match 'Aucune version publiee pour roo-state-manager' -Because "l'ancienne formulation est un faux negatif sur un siege legacy"
        (Test-Path (Join-Path $root "mcps/internal/servers/roo-state-manager/build/index.js")) | Should -BeTrue
    }

    It "sur une fixture VIDE rapporte l'absence de marqueur publie" {
        $root = New-DiagRoot -Root (Join-Path $script:Tmp "root-vide")
        $out = Invoke-DocumentedDiagnostic -FunctionText $script:GuideBDiag -RepoRoot $root -WorkDir $script:Tmp

        $out | Should -Match 'Aucune version publiee pour roo-state-manager'
        $out | Should -Match 'marqueur build-current absent'
    }

    It "MUTATION : renommer le marqueur dans le guide change le diagnostic rendu" {
        $root = New-DiagRoot -Root (Join-Path $script:Tmp "root-mutation") -Vintage "build-99aabbccddeeff00"

        $original = Invoke-DocumentedDiagnostic -FunctionText $script:GuideBDiag -RepoRoot $root -WorkDir $script:Tmp
        $mutated = $script:GuideBDiag -replace '"build-current"', '"build-out"'
        $mutated | Should -Not -Be $script:GuideBDiag
        $afterMutation = Invoke-DocumentedDiagnostic -FunctionText $mutated -RepoRoot $root -WorkDir $script:Tmp

        $original | Should -Not -Match 'MILLESIME PUBLIE ABSENT'
        # Marqueur renomme + aucun legacy : on retombe dans la branche « aucune version
        # publiee » — c'est un AUTRE diagnostic, ce qui prouve que la garde lit le guide.
        $afterMutation | Should -Match 'Aucune version publiee pour roo-state-manager' -Because "avec un marqueur renomme, le diagnostic bascule : la garde lit bien le guide"
        $afterMutation | Should -Not -Match 'MILLESIME PUBLIE ABSENT'
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

    It "les deux guides distinguent marqueur absent et legacy gele" {
        foreach ($guide in @("MCP-TROUBLESHOOTING-UNIFIED.md", "TROUBLESHOOTING-GUIDE.md")) {
            $text = Get-Content -Raw -LiteralPath (Join-Path $script:GuidesDir $guide)
            $text | Should -Match 'MILLESIME PUBLIE ABSENT' -Because "$guide doit nommer l'etat reel sur un siege ancien"
            $text | Should -Match 'build/index\.js' -Because "$guide doit nommer le legacy gele qui peut encore servir"
        }
    }

    It "porte la note historique Quickfiles dans le guide d'exploration" {
        $text = Get-Content -Raw -LiteralPath (Join-Path $script:GuidesDir "guide-exploration-prompts-natifs.md")
        $text | Should -Match 'Quickfiles MCP' -Because "la section retiree doit rester tracee"
        $text | Should -Match '#3423' -Because "la note doit citer la suppression"
        $text | Should -Match 'Read/Write/Edit' -Because "la note doit nommer le remplacement"
    }
}

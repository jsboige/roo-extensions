# Tests unitaires pour New-WorkspaceFromTemplate.ps1 (#4873, Epic #3111
# candidat #7, etape 1) -- l'amorcage local d'un nouveau workspace depuis le
# gabarit .claude/configs/workspace-template/.
#
# Syntaxe Pester v5+ -- executee en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1, sur ubuntu-latest. Le script teste est
# cross-platform (aucun cmdlet Windows) : la suite l'execute donc pour de vrai
# comme processus enfant du MEME moteur qu'elle (pwsh sous CI, powershell.exe
# 5.1 localement -- pattern #3711), sur des repertoires jetables sous
# GetTempPath(), jamais un workspace reel.
#
# Proprietes verrouillees :
#   * -DryRun n'ecrit rien, pas meme un repertoire ;
#   * un fichier existant n'est jamais ecrase (liste comme saute) ;
#   * un second run est idempotent ;
#   * les marqueurs {{WORKSPACE}} / {{REPO}} sont remplaces ;
#   * la fusion .gitignore ajoute les seules lignes absentes ;
#   * le README.md du gabarit ne part jamais dans la cible ;
#   * garde : une cible contenant le gabarit est refusee.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/new-workspace-from-template.Tests.ps1 -Output Detailed"
#
# NB: fichier ASCII volontairement sans accents (lecture PS 5.1 sans BOM).

BeforeAll {
    # BeforeAll a la RACINE du fichier (pattern BOM-SafeFileWriter, Pester 6 :
    # un BeforeAll imbrique dans un Describe perd ses definitions) et helpers
    # definis DEDANS (une fonction top-level fait mourir le container entier --
    # memory pester-family-gotchas 3.1).
    $script:projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:bootstrapScript = Join-Path $script:projectRoot 'scripts/workspace/New-WorkspaceFromTemplate.ps1'
    $script:templateRoot = Join-Path $script:projectRoot '.claude/configs/workspace-template'
    $script:engine = if ($PSVersionTable.PSEdition -eq 'Core') {
        (Get-Command pwsh -ErrorAction Stop).Source
    } else {
        (Get-Command powershell -ErrorAction Stop).Source
    }

    function Invoke-Bootstrap {
        param([string]$TargetPath, [string]$WorkspaceName, [switch]$DryRun)
        $childArgs = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
            '-File', $script:bootstrapScript, '-Target', $TargetPath, '-Workspace', $WorkspaceName)
        if ($DryRun) { $childArgs += '-DryRun' }
        $eap = $ErrorActionPreference
        # pwsh 7.2+ : un stderr enfant capturerait autrement en throw dans le parent.
        $ErrorActionPreference = 'Continue'
        try {
            $out = & $script:engine @childArgs 2>&1 | Out-String
        } finally {
            $ErrorActionPreference = $eap
        }
        [pscustomobject] @{ Output = $out; ExitCode = $LASTEXITCODE }
    }

    function New-ThrowawayTarget {
        return [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ('wst-' + [guid]::NewGuid().ToString('N')))
    }

    # Hash .NET plutot que Get-FileHash : sous un powershell.exe 5.1 lance depuis
    # un shell ou PSModulePath est pollue par pwsh 7 (memory ps51-psmodulepath),
    # l'auto-chargement de Microsoft.PowerShell.Utility peut echouer ; .NET,
    # lui, repond toujours. Fichiers tests < 5 Ko.
    function Get-FileSha256 {
        param([string]$Path)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            ([System.BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($Path)))).Replace('-', '')
        } finally {
            $sha.Dispose()
        }
    }

    function Clear-ThrowawayTarget {
        param([string]$Path)
        if ($Path -and (Test-Path -LiteralPath $Path)) {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'New-WorkspaceFromTemplate - sources du gabarit' {

    It 'le script et le gabarit existent aux emplacements documentes' {
        Test-Path -LiteralPath $script:bootstrapScript | Should -Be $true
        Test-Path -LiteralPath $script:templateRoot | Should -Be $true
    }

    It 'le gabarit porte exactement les fichiers attendus' {
        foreach ($f in @(
            'CLAUDE.md.template', 'gitignore.fragment', 'README.md',
            '.claude/rules/claim-discipline.md', '.claude/rules/pr-mandatory.md',
            '.claude/plans/README.md',
            'memory-seed/MEMORY.md', 'memory-seed/user-question-registry.md'
        )) {
            Test-Path -LiteralPath (Join-Path $script:templateRoot $f) | Should -Be $true
        }
        # Exactement deux regles, pas une de plus (le gabarit ne recopie jamais
        # les regles globales).
        $rules = @(Get-ChildItem -LiteralPath (Join-Path $script:templateRoot '.claude/rules') -File)
        $rules.Count | Should -Be 2
    }

    It 'le fragment gitignore porte les 4 lignes canoniques' {
        $frag = Get-Content -LiteralPath (Join-Path $script:templateRoot 'gitignore.fragment')
        foreach ($line in @('.tmp/', 'scratchpad_*', 'C:Users*', '.claude/local/')) {
            $frag | Should -Contain $line
        }
        @($frag | Where-Object { $_.Trim() -ne '' }).Count | Should -Be 4
    }

    It 'les seuls marqueurs du gabarit sont WORKSPACE et REPO' {
        $markers = New-Object System.Collections.Generic.List[string]
        foreach ($f in (Get-ChildItem -LiteralPath $script:templateRoot -Recurse -File)) {
            $raw = [System.IO.File]::ReadAllText($f.FullName)
            foreach ($m in [regex]::Matches($raw, '\{\{([A-Za-z]+)\}\}')) {
                $markers.Add($m.Groups[1].Value)
            }
        }
        $markers.Count | Should -BeGreaterThan 0
        @($markers | Where-Object { $_ -notin @('WORKSPACE', 'REPO') }).Count | Should -Be 0
    }
}

Describe 'New-WorkspaceFromTemplate - DryRun reste en lecture totale' {

    BeforeEach {
        $script:t = New-ThrowawayTarget
    }
    AfterEach {
        Clear-ThrowawayTarget -Path $script:t
    }

    It 'sort en 0 et ne cree meme pas le repertoire cible' {
        $r = Invoke-Bootstrap -TargetPath $script:t -WorkspaceName 'DemoWs' -DryRun
        $r.ExitCode | Should -Be 0
        Test-Path -LiteralPath $script:t | Should -Be $false
    }

    It 'liste les fichiers prevus, README.md du gabarit exclu' {
        $r = Invoke-Bootstrap -TargetPath $script:t -WorkspaceName 'DemoWs' -DryRun
        $r.ExitCode | Should -Be 0
        foreach ($expected in @(
            'CLAUDE.md', '.claude/rules/claim-discipline.md', '.claude/rules/pr-mandatory.md',
            '.claude/plans/README.md', 'memory-seed/MEMORY.md',
            'memory-seed/user-question-registry.md', '.gitignore'
        )) {
            ($r.Output -match [regex]::Escape("+ $expected")) | Should -Be $true
        }
        # Le README racinal du gabarit est sa doc : il ne part jamais dans la cible.
        ($r.Output -match [regex]::Escape('+ README.md')) | Should -Be $false
        ($r.Output -match [regex]::Escape("Rien n'a ete ecrit")) | Should -Be $true
    }
}

Describe 'New-WorkspaceFromTemplate - creation seule sur cible vide' {

    BeforeEach {
        $script:t = New-ThrowawayTarget
    }
    AfterEach {
        Clear-ThrowawayTarget -Path $script:t
    }

    It 'cree les fichiers attendus et sort en 0' {
        $r = Invoke-Bootstrap -TargetPath $script:t -WorkspaceName 'DemoWs'
        $r.ExitCode | Should -Be 0
        foreach ($f in @(
            'CLAUDE.md', '.claude/rules/claim-discipline.md', '.claude/rules/pr-mandatory.md',
            '.claude/plans/README.md', 'memory-seed/MEMORY.md',
            'memory-seed/user-question-registry.md', '.gitignore'
        )) {
            Test-Path -LiteralPath (Join-Path $script:t $f) | Should -Be $true
        }
    }

    It 'remplace les marqueurs WORKSPACE et REPO, sans en laisser aucun' {
        $r = Invoke-Bootstrap -TargetPath $script:t -WorkspaceName 'DemoWs'
        $r.ExitCode | Should -Be 0
        $claude = [System.IO.File]::ReadAllText((Join-Path $script:t 'CLAUDE.md'))
        $leafName = Split-Path -Leaf $script:t
        $claude | Should -Match 'DemoWs'
        # Parentheses obligatoires : un appel de methode en mode ARGUMENT
        # (Should -Match [regex]::Escape(x)) ne s'evalue pas - il devient la
        # chaine litterale (mesure 22/11 : 3 faux rouges sur ce piege).
        $claude | Should -Match ([regex]::Escape($leafName))
        foreach ($f in (Get-ChildItem -LiteralPath $script:t -Recurse -File)) {
            [System.IO.File]::ReadAllText($f.FullName) | Should -Not -Match '\{\{(WORKSPACE|REPO)\}\}'
        }
    }

    It 'ecrit sans BOM (fusion gitignore et modeles)' {
        $r = Invoke-Bootstrap -TargetPath $script:t -WorkspaceName 'DemoWs'
        $r.ExitCode | Should -Be 0
        foreach ($f in @((Join-Path $script:t 'CLAUDE.md'), (Join-Path $script:t '.gitignore'))) {
            $bytes = [System.IO.File]::ReadAllBytes($f)
            if ($bytes.Length -ge 3) {
                ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $false
            }
        }
    }
}

Describe 'New-WorkspaceFromTemplate - refuse d ecraser et reste idempotent' {

    BeforeEach {
        $script:t = New-ThrowawayTarget
        New-Item -ItemType Directory -Path $script:t -Force | Out-Null
    }
    AfterEach {
        Clear-ThrowawayTarget -Path $script:t
    }

    It 'ne touche pas un fichier existant et le liste comme saute' {
        $sentinelPath = Join-Path $script:t 'CLAUDE.md'
        [System.IO.File]::WriteAllText($sentinelPath, 'SENTINEL-DO-NOT-TOUCH', (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Bootstrap -TargetPath $script:t -WorkspaceName 'DemoWs'
        $r.ExitCode | Should -Be 0
        [System.IO.File]::ReadAllText($sentinelPath) | Should -BeExactly 'SENTINEL-DO-NOT-TOUCH'
        ($r.Output -match [regex]::Escape('- CLAUDE.md')) | Should -Be $true
        # Les autres fichiers partent bien malgre le saut.
        Test-Path -LiteralPath (Join-Path $script:t '.claude/rules/claim-discipline.md') | Should -Be $true
    }

    It 'second run idempotent : 0 fichier cree, contenu inchange' {
        $null = Invoke-Bootstrap -TargetPath $script:t -WorkspaceName 'DemoWs'
        $filesBefore = @(Get-ChildItem -LiteralPath $script:t -Recurse -File | Sort-Object -Property FullName)
        $hashBefore = @($filesBefore | ForEach-Object { Get-FileSha256 -Path $_.FullName })

        $r2 = Invoke-Bootstrap -TargetPath $script:t -WorkspaceName 'DemoWs'
        $r2.ExitCode | Should -Be 0
        ($r2.Output -match 'Fichiers crees \(0\)') | Should -Be $true

        $filesAfter = @(Get-ChildItem -LiteralPath $script:t -Recurse -File | Sort-Object -Property FullName)
        $filesAfter.Count | Should -Be $filesBefore.Count
        $hashAfter = @($filesAfter | ForEach-Object { Get-FileSha256 -Path $_.FullName })
        for ($i = 0; $i -lt $hashBefore.Count; $i++) {
            $hashAfter[$i] | Should -Be $hashBefore[$i]
        }
    }

    It 'fusionne le fragment sans retirer ni dupliquer les lignes existantes' {
        $gitignorePath = Join-Path $script:t '.gitignore'
        [System.IO.File]::WriteAllText($gitignorePath, ".tmp/`ncustom-line/`n", (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Bootstrap -TargetPath $script:t -WorkspaceName 'DemoWs'
        $r.ExitCode | Should -Be 0
        $raw = [System.IO.File]::ReadAllText($gitignorePath)
        $raw | Should -Match 'custom-line/'
        ([regex]::Matches($raw, [regex]::Escape('.tmp/'))).Count | Should -Be 1
        foreach ($line in @('scratchpad_*', 'C:Users*', '.claude/local/')) {
            $raw | Should -Match ([regex]::Escape($line))
        }
    }
}

Describe 'New-WorkspaceFromTemplate - gardes de cible' {

    It 'refuse une cible qui contient le gabarit lui-meme (racine du checkout)' {
        $r = Invoke-Bootstrap -TargetPath $script:projectRoot -WorkspaceName 'X'
        $r.ExitCode | Should -Not -Be 0
        ($r.Output -match 'Refus') | Should -Be $true
    }

    It 'la garde racine-de-lecteur vit dans le script (controle statique)' {
        # Non execute : si la garde echouait, le test ecrirait a la racine d'un
        # lecteur reel. On epingle sa presence dans le texte du script.
        $raw = [System.IO.File]::ReadAllText($script:bootstrapScript)
        $raw | Should -Match 'GetPathRoot'
        $raw | Should -Match 'racine d''un lecteur'
    }
}

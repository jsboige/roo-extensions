# Pester tests for purge-msal.ps1 / purge-msal-cache.py / install-msal-purge-watch.ps1
# Issue #1422 point 3 — the purge fires unattended, so its guard is the only thing
# standing between a controlled write and a locked VS Code database. Every assertion
# below runs on a THROWAWAY sqlite fixture: the real state.vscdb is never opened.
#
# Guarded regressions:
#   1. -Apply with a live process of the same name REFUSES and writes nothing;
#   2. a dry-run leaves the database byte-identical (hash before/after);
#   3. --apply removes ONLY the pca:* target and leaves every other secret:// key;
#   4. a second --apply is a no-op ([DEJA-FAIT], exit 0) — the task may fire twice;
#   5. the installer's -DryRun registers no task.
#
# Run:  pwsh -File scripts/testing/run-pester-tests.ps1 -Path scripts/maintenance/purge-msal.Tests.ps1

BeforeAll {
    $script:here   = $PSScriptRoot
    $script:runner = Join-Path $PSScriptRoot 'purge-msal.ps1'
    $script:py     = Join-Path $PSScriptRoot 'purge-msal-cache.py'
    $script:inst   = Join-Path $PSScriptRoot 'install-msal-purge-watch.ps1'
    $script:tmp    = Join-Path ([IO.Path]::GetTempPath()) ('msalpurge-test-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tmp -Force | Out-Null

    # A process guaranteed alive: the test host itself. Using its real name means the
    # guard is exercised for real, not mocked.
    $script:selfProc = (Get-Process -Id $PID).ProcessName

    function New-FixtureDb([string]$name) {
        $db = Join-Path $script:tmp $name
        $pyCode = @'
import sqlite3, sys
db = sys.argv[1]
con = sqlite3.connect(db)
con.execute("CREATE TABLE ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB)")
rows = [
    'secret://{"extensionId":"vscode.microsoft-authentication","key":"pca:dead-refresh-token"}',
    'secret://{"extensionId":"vscode.microsoft-authentication","key":"other-account"}',
    'secret://{"extensionId":"vscode.github-authentication","key":"token-a"}',
    'secret://{"extensionId":"vscode.github-authentication","key":"token-b"}',
    'workbench.someSetting',
]
con.executemany("INSERT INTO ItemTable (key, value) VALUES (?, ?)", [(r, b"x") for r in rows])
con.commit(); con.close()
'@
        $pyFile = Join-Path $script:tmp 'mkfix.py'
        [System.IO.File]::WriteAllText($pyFile, $pyCode, (New-Object System.Text.UTF8Encoding($false)))
        & python $pyFile $db
        if ($LASTEXITCODE -ne 0) { throw "fixture creation failed" }
        return $db
    }

    function Get-Sha([string]$p) { (Get-FileHash -Path $p -Algorithm SHA256).Hash }

    # Probe run as a FILE, never inline: `powershell.exe -File` drops empty args, and a
    # double-quoted -c payload with nested quotes splits at the first \" under PS 5.1.
    $script:probePy = Join-Path $script:tmp 'probe.py'
    [System.IO.File]::WriteAllText($script:probePy, @'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
print(con.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE 'secret://%'").fetchone()[0])
print(con.execute("SELECT COUNT(*) FROM ItemTable WHERE key LIKE '%pca:%'").fetchone()[0])
con.close()
'@, (New-Object System.Text.UTF8Encoding($false)))

    function Get-KeyCounts([string]$db) { @(& python $script:probePy $db) }
}

AfterAll {
    if (Test-Path $script:tmp) { Remove-Item -Recurse -Force $script:tmp }
}

Describe 'purge-msal.ps1 — la garde est la seule protection du mode sans surveillance' {

    It 'refuse -Apply quand un processus du nom surveille vit, et n ecrit rien' {
        $db = New-FixtureDb "guard-$([guid]::NewGuid().ToString('N')).vscdb"
        $before = Get-Sha $db
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:runner `
            -StateDb $db -ProcessName $script:selfProc -Apply -LogFile (Join-Path $script:tmp 'guard.log') 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $out | Should -Match '\[REFUS\]'
        (Get-Sha $db) | Should -Be $before
        # `.bak` ne doit pas exister : aucune sauvegarde n'est creee par un refus.
        @(Get-ChildItem -Path $script:tmp -Filter '*.bak-msalpurge-*' -ErrorAction SilentlyContinue).Count | Should -Be 0
    }

    It 'dry-run est pur : base identique octet pour octet' {
        $db = New-FixtureDb "dry-$([guid]::NewGuid().ToString('N')).vscdb"
        $before = Get-Sha $db
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:runner `
            -StateDb $db -ProcessName 'NoSuchProc-1422' -LogFile (Join-Path $script:tmp 'dry.log') 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match 'cles cible pca:\*\s+= 1'
        $out | Should -Match 'autres cles secret://\s+= 3'
        $out | Should -Match '\[DRY-RUN\]'
        (Get-Sha $db) | Should -Be $before
    }
}

Describe 'purge-msal-cache.py — la purge est chirurgicale et idempotente' {

    It 'supprime uniquement la cle pca:* et laisse les autres secret:// intactes' {
        $db = New-FixtureDb "apply-$([guid]::NewGuid().ToString('N')).vscdb"
        $out = & python $script:py $db --apply 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '\[PURGE\]\s+1 entree\(s\) supprimee\(s\), reste cible = 0'
        $out | Should -Match '\[VERIF\]\s+autres cles secret://\s+= 3 \(doit egaler 3\)'

        $probe = Get-KeyCounts $db
        $probe[0] | Should -Be '3'
        $probe[1] | Should -Be '0'

        @(Get-ChildItem -Path $script:tmp -Filter '*.bak-msalpurge-*' -ErrorAction SilentlyContinue).Count | Should -BeGreaterThan 0
    }

    It 'une seconde passe est un no-op explicite (la tache peut tirer deux fois)' {
        $db = New-FixtureDb "idem-$([guid]::NewGuid().ToString('N')).vscdb"
        & python $script:py $db --apply | Out-Null
        $LASTEXITCODE | Should -Be 0
        $out = & python $script:py $db --apply 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '\[DEJA-FAIT\]'
    }
}

Describe 'install-msal-purge-watch.ps1 -DryRun — construit sans enregistrer' {

    It 'affiche la tache et ne cree aucune tache' {
        $name = 'MsalPurgeDryRun-' + [guid]::NewGuid().ToString('N')
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:inst -DryRun -TaskName $name 2>&1 | Out-String
        # Un exit non nul doit dire POURQUOI dans le log du runner : sans cette ligne,
        # marshall-scripts-pester ne montrait que le code de sortie (mesure 13/11).
        if ($LASTEXITCODE -ne 0) { Write-Host "[SORTIE INSTALLATEUR]`n$out" }
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '\[DRY-RUN\] tache construite, RIEN enregistre'
        $out | Should -Match '-Watch'
        { Get-ScheduledTask -TaskName $name -ErrorAction Stop } | Should -Throw
    }
}
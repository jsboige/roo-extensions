# Pester 5 tests for check_scheduled_task_safe_to_delete (#4097).
#
# Incident fondateur (x2 le 06/10) : suppression de lanceurs Claude* fondee sur le
# NOM alors que la charge utile (.vbs -> scripts/scheduling/*.ps1) les designait
# proteges. Ces tests figent les formes REELLES du generateur harden-hidden-tasks.ps1
# (VBS auto-suffisant, guillemets doubles "", commande en dur) pour que le garde ne
# diverge jamais de ce qu'est un lanceur.
#
# La lib est testee sur objets SYNTHETIQUES (aucune tache reelle). Un test
# end-to-end enregistre une vraie tache user-level (meme garde que
# harden-hidden-tasks.Tests.ps1 : skip avec raison si l'enregistrement echoue --
# ce fichier tourne sur des machines flotte, pas en CI).
#
# Run:  pwsh -File scripts/testing/run-pester-tests.ps1 -Path scripts/scheduling/check_scheduled_task_safe_to_delete.Tests.ps1

BeforeAll {
    . (Join-Path $PSScriptRoot 'check_scheduled_task_safe_to_delete.lib.ps1')
}

# ---------------------------------------------------------------------------
# Lib pure -- payloads synthetiques aux formes du generateur
# ---------------------------------------------------------------------------

Describe 'Get-TaskLauncherVbs' {
    It 'extrait le .vbs depuis les Arguments durcis du generateur' {
        $vbs = Get-TaskLauncherVbs -Execute 'wscript.exe' -Arguments '//B //Nologo "C:\ProgramData\claude-hidden-launchers\Claude-Worker.vbs"'
        $vbs | Should -Be 'C:\ProgramData\claude-hidden-launchers\Claude-Worker.vbs'
    }

    It 'extrait le .vbs depuis l''Execute seul (tache non durcie)' {
        $vbs = Get-TaskLauncherVbs -Execute '"C:\ProgramData\claude-hidden-launchers\Claude-Worker.vbs"' -Arguments ''
        $vbs | Should -Be 'C:\ProgramData\claude-hidden-launchers\Claude-Worker.vbs'
    }

    It 'rend $null pour un hote wscript sur du .js (pas a nous, pas de faux rouge)' {
        Get-TaskLauncherVbs -Execute 'wscript.exe' -Arguments '//B "C:\x\task.js"' | Should -BeNullOrEmpty
    }
}

Describe 'Get-VbsScriptTargets' {
    It 'extrait la cible scheduling malgre le doublement de guillemets VBScript (forme du generateur)' {
        $vbsText = 'rc = sh.Run("""powershell.exe"" -NoProfile -File ""D:\Dev\roo-extensions\scripts\scheduling\start-claude-worker.ps1"" -Mode code-simple -Model sonnet", 0, True)'
        $targets = Get-VbsScriptTargets -VbsText $vbsText
        @($targets) | Should -Contain 'D:\Dev\roo-extensions\scripts\scheduling\start-claude-worker.ps1'
    }

    It 'extrait plusieurs cibles et ignore le texte hors chemin' {
        $vbsText = 'rc = sh.Run("""powershell.exe"" -File ""D:\Dev\roo-extensions\scripts\scheduling\start-meta-audit.ps1"" -Model sonnet", 0, True)'
        $targets = @(Get-VbsScriptTargets -VbsText $vbsText)
        $targets | Should -Contain 'D:\Dev\roo-extensions\scripts\scheduling\start-meta-audit.ps1'
        ($targets | Where-Object { $_ -notmatch '(?i)\.(ps1|py|js|cjs|bat|cmd|exe)$' }) | Should -BeNullOrEmpty
    }
}

Describe 'Test-IsProtectedRooLauncher' {
    It 'protege une cible sous roo-extensions\scripts\scheduling (casse du disque indifferente)' {
        Test-IsProtectedRooLauncher -Targets @('C:\Tools\autre.cmd', 'd:\dev\roo-extensions\scripts\scheduling\start-claude-worker.ps1') |
            Should -BeTrue
    }

    It 'ne protege pas une cible ailleurs (le nom de la tache n''intervient pas)' {
        Test-IsProtectedRooLauncher -Targets @('D:\Dev\CoursIA\scripts\x.ps1') | Should -BeFalse
    }

    It 'rend $false sans cibles (tache sans script)' {
        Test-IsProtectedRooLauncher -Targets @() | Should -BeFalse
    }
}

Describe 'Get-TaskScriptTargets' {
    It 'RESOLUTION COMPLETE : vbs -> cibles, Readable vrai' {
        $readBack = { param($p) 'rc = sh.Run("""powershell.exe"" -File ""D:\Dev\roo-extensions\scripts\scheduling\start-claude-worker.ps1""", 0, True)' }
        $r = Get-TaskScriptTargets -Execute 'wscript.exe' -Arguments '"C:\ProgramData\claude-hidden-launchers\Claude-Worker.vbs"' -ReadFile $readBack
        $r.Readable | Should -BeTrue
        $r.Launcher | Should -Be 'C:\ProgramData\claude-hidden-launchers\Claude-Worker.vbs'
        (Test-IsProtectedRooLauncher -Targets $r.Targets) | Should -BeTrue
    }

    It 'vbs illisible -> Readable faux (INSTRUMENT chez l''appelant, jamais « pas protege »)' {
        $readFail = { param($p) $null }
        $r = Get-TaskScriptTargets -Execute 'wscript.exe' -Arguments '"C:\ProgramData\claude-hidden-launchers\Claude-Worker.vbs"' -ReadFile $readFail
        $r.Readable | Should -BeFalse
    }

    It 'sans vbs : l''Execute direct sous scheduling est la charge utile (occurrence non durcie)' {
        $r = Get-TaskScriptTargets -Execute 'powershell.exe' -Arguments '-NoProfile -File "D:\dev\roo-extensions\scripts\scheduling\start-claude-worker.ps1" -Mode code-simple' -ReadFile { param($p) $null }
        (Test-IsProtectedRooLauncher -Targets $r.Targets) | Should -BeTrue
    }

    It 'sans vbs, Execute script direct : le chemin Execute compte aussi' {
        $r = Get-TaskScriptTargets -Execute 'D:\Dev\roo-extensions\scripts\scheduling\start-meta-audit.ps1' -Arguments '-Model sonnet' -ReadFile { param($p) $null }
        (Test-IsProtectedRooLauncher -Targets $r.Targets) | Should -BeTrue
    }
}

Describe 'Test-HasPreopBackup' {
    It 'matche la convention preop-backup (nom sanitize + machine + stamp, incident 06/10)' {
        $found = { param($p) $p -like '*Claude-Worker-*.xml' }
        Test-HasPreopBackup -TaskName 'Claude-Worker' -BackupDir 'X:\bk' -TestPath $found | Should -BeTrue
    }

    It 'sanitize le nom de tache (caracteres interdits -> _)' {
        # Capture par reference (hashtable) : insensible aux frontieres de
        # scope Pester 6 entre le scriptblock et le bloc It.
        $state = @{ Path = '' }
        $capture = { param($p) $state.Path = $p; return $false }
        Test-HasPreopBackup -TaskName 'A/B:C' -BackupDir 'X:\bk' -TestPath $capture | Should -BeFalse
        $state.Path | Should -Match '^X:\\bk\\A_B_C-\*\.xml$'
    }

    It 'rend $false sans sauvegarde' {
        Test-HasPreopBackup -TaskName 'Claude-Worker' -BackupDir 'X:\bk' -TestPath { param($p) $false } | Should -BeFalse
    }
}

# ---------------------------------------------------------------------------
# End-to-end : vraie tache user-level reproduisant la classe d'incident
# ---------------------------------------------------------------------------

Describe 'check_scheduled_task_safe_to_delete.ps1 (end-to-end)' -Tag 'E2E' {
    BeforeAll {
        $script:name = 'GSD-4097-Protected'
        $script:launcherDir = Join-Path $TestDrive 'launchers'
        $script:backupDir = Join-Path $TestDrive 'preop-backup'
        New-Item -ItemType Directory -Force -Path $script:launcherDir, $script:backupDir | Out-Null

        # VBS a la forme EXACTE du generateur, charge utile scheduling protegee.
        $vbsPath = Join-Path $script:launcherDir 'GSD-4097-Protected.vbs'
        @'
' Genere pour le test #4097 -- forme harden-hidden-tasks.ps1.
Option Explicit
Dim sh, rc
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("""powershell.exe"" -NoProfile -File ""D:\Dev\roo-extensions\scripts\scheduling\start-claude-worker.ps1"" -Mode code-simple -Model sonnet", 0, True)
WScript.Quit rc
'@ | Set-Content -LiteralPath $vbsPath -Encoding ASCII

        $script:registered = $true
        try {
            $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('//B //Nologo "{0}"' -f $vbsPath)
            $principal = New-ScheduledTaskPrincipal -UserId ("{0}\{1}" -f [Environment]::UserDomainName, [Environment]::UserName) -LogonType Interactive
            Register-ScheduledTask -TaskName $script:name -Action $action -Principal $principal -ErrorAction Stop | Out-Null
        } catch {
            $script:registered = $false
            $script:skipReason = $_.Exception.Message
        }
    }
    AfterAll {
        if ($script:registered) {
            Unregister-ScheduledTask -TaskName $script:name -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

    It 'REFUSED:PROTECTED sur un lanceur scheduling, meme avec backup present' {
        if (-not $script:registered) { Set-ItResult -Skipped -Because ("task registration failed: {0}" -f $script:skipReason); return }
        # Backup present : le refus PROTECTED doit primer sur tout le reste.
        'xml' | Set-Content -LiteralPath (Join-Path $script:backupDir 'GSD-4097-Protected-test-00000000-0000.xml')
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_scheduled_task_safe_to_delete.ps1') $script:name -BackupDir $script:backupDir
        $LASTEXITCODE | Should -Be 1
        ($out -join ' ') | Should -Match '\[REFUSED:PROTECTED\].*start-claude-worker\.ps1'
    }

    It 'tache inconnue -> INSTRUMENT exit 2 (un garde muet ne valide rien)' {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_scheduled_task_safe_to_delete.ps1') 'GSD-4097-Absente' -BackupDir $script:backupDir
        $LASTEXITCODE | Should -Be 2
        ($out -join ' ') | Should -Match '\[INSTRUMENT\]'
    }
}

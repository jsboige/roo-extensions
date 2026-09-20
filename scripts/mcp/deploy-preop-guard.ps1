#Requires -Version 5.1

<#
.SYNOPSIS
    Garde-fou pre-op deploy : empeche le pipeline de detuire des fichiers non-trackes
    (.env, build/, hooksPath, configs machine) sans backup prealable.

.DESCRIPTION
    Issue #3712 : 17/09, 3 sieges ont frole la perte de config (ai-01 build/+.env,
    po-2026 hooksPath/gitfiles, qdrant-0f wipe similaire) au deploy. `git status`
    est AVEUGLE aux fichiers gitignored (build/, .env) -- un `git status` propre ne
    prouve pas l'absence de perte.

    Ce module fournit trois fonctions a utiliser PAR le pipeline deploy :

        Test-ProtectedPath -LiteralPath <path>
            Renvoie $true si le chemin est dans la liste blanche des artefacts
            proteges, s'il est a l'INTERIEUR d'un chemin protege, ou s'il CONTIENT
            un chemin protege (cas racine : `git clean -fdx .` — volet #3712).
            La liste est CONFIGURABLE par machine (variable d'env
            DEPLOY_PROTECTED_PATHS, separate par ';'), avec DEFAULT robuste.

        Backup-ProtectedPaths -LiteralPath <root>
            Parcourt le sous-arbre <root> et backup chaque fichier/repertoire
            protege detecte dans %USERPROFILE%\.roo-state-manager\preop-backup\
            (timestamp + chemin relatif). Best-effort : ne fait JAMAIS echouer.

        Invoke-DeployPreOpGuard -Operation <name> -LiteralPath <target> [-Mode Block|Backup|Warn]
            Mode Block (defaut) : renvoie Action=Blocked si <target> chevauche un chemin
                                 protege (rien n'est detruit ; en CLI standalone : exit 3,
                                 en module : le caller decide sur le rendu).
            Mode Backup         : tente d'abord le backup, puis laisse l'appelant decider.
            Mode Warn           : laisse passer, mais affiche un WARNING colore.

    Les chemins proteges par defaut (relative au working tree) :
        - .env, .env.*                  (creds MCP, API keys)
        - build/                        (artefact compile, peut-etre long a reconstruire
                                        mais contient aussi des artefacts de build
                                        custom comme RSM index.json)
        - node_modules/.cache/          (cache tooling)
        - .claude/settings.json         (compact window, MCP_TOOL_TIMEOUT)
        - .claude.json                  (MCP server config)
        - .roo/                         (mode configs Roo)

    Git-blind : la detection s'appuie sur la liste de chemins, JAMAIS sur `git status`.

.NOTES
    Incident fondateur : 2026-09-17 (ai-01 + po-2026 + qdrant-0f, meme jour).
    Decision user registre RX4 2026-09-18 : "OK pour ta reco".
    Test : scripts/testing/unit/deploy-preop-guard.Tests.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# --- Constantes : chemins proteges par defaut (relatifs au working tree) ---
$script:DefaultProtectedRelativePatterns = @(
    '.env',
    '.env.*',
    'build',
    'node_modules/.cache',
    '.claude/settings.json',
    '.claude.json',
    '.roo',
    'mcps/internal/servers/roo-state-manager/.env',
    'mcps/internal/servers/roo-state-manager/build',
    'mcps/internal/servers/roo-state-manager/data',
    'mcps/internal/servers/roo-state-manager/.roo-state-manager-data',
    'mcps/internal/servers/sk-agent/.env',
    'mcps/external/win-cli/server/.env'
)

# --- Couleurs (PS 5.1 safe) ---
function Write-PreOpGuardInfo  { param([string]$m) Write-Host "[deploy-preop-guard] $m" -ForegroundColor Cyan }
function Write-PreOpGuardWarn  { param([string]$m) Write-Host "[deploy-preop-guard] $m" -ForegroundColor Yellow }
function Write-PreOpGuardError { param([string]$m) Write-Host "[deploy-preop-guard] $m" -ForegroundColor Red }
function Write-PreOpGuardOk    { param([string]$m) Write-Host "[deploy-preop-guard] $m" -ForegroundColor Green }

function Get-ProtectedPaths {
    <#
    .SYNOPSIS
        Renvoie la liste effective des chemins proteges (patterns -> chemins absolus
        relatifs au repoRoot detecte). Le repoRoot est soit le parametre -RepoRoot,
        soit le toplevel git du PSScriptRoot.
    #>
    param([string]$RepoRoot)

    if (-not $RepoRoot) {
        $RepoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null | Out-String).Trim()
        if (-not $RepoRoot) {
            Write-PreOpGuardError "RepoRoot introuvable (ni -RepoRoot, ni git toplevel)."
            return @()
        }
    }

    $patterns = $script:DefaultProtectedRelativePatterns
    if ($env:DEPLOY_PROTECTED_PATHS) {
        # Override machine : liste separee par ';'.
        $custom = $env:DEPLOY_PROTECTED_PATHS -split ';' | Where-Object { $_ } | ForEach-Object { $_.Trim() }
        $patterns = $custom + $patterns  # custom d'abord, default en filet
    }

    $resolved = @()
    foreach ($p in $patterns) {
        $full = Join-Path $RepoRoot $p
        # -Path (PAS -LiteralPath) : un pattern comme .env.* doit s'expandre en fichiers
        # reels (.env.local, .env.production...). -LiteralPath chercherait le fichier
        # litteral ".env.*" (inexistant) et sauterait le pattern en silence.
        $items = @(Get-Item -Path $full -Force -ErrorAction SilentlyContinue)
        if ($items.Count -gt 0) {
            foreach ($it in $items) {
                $resolved += [pscustomobject]@{
                    Pattern     = $p
                    FullPath    = $it.FullName
                    IsContainer = $it.PSIsContainer
                    Exists      = $true
                }
            }
        } else {
            $resolved += [pscustomobject]@{
                Pattern     = $p
                FullPath    = $null
                IsContainer = $false
                Exists      = $false
            }
        }
    }
    return $resolved
}

function Test-ProtectedPath {
    <#
    .SYNOPSIS
        Renvoie $true si -LiteralPath est DANS un chemin protege, EST un chemin protege,
        ou CONTIENT un chemin protege (cas racine : clean/reset du worktree entier).
        Accepte un fichier, un repertoire, ou un chemin relatif.
    .PARAMETER LiteralPath
        Chemin a tester (absolu ou relatif au cwd).
    .PARAMETER RepoRoot
        Working tree de reference. Defaut : toplevel git du PSScriptRoot.
    .OUTPUTS
        [pscustomobject]@{ IsProtected=$bool; Reason=$string; Pattern=$string; ProtectedPath=$string }
    #>
    param(
        [Parameter(Mandatory=$true)][string]$LiteralPath,
        [string]$RepoRoot
    )

    if (-not $RepoRoot) {
        $RepoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null | Out-String).Trim()
    }
    if (-not $RepoRoot) {
        # Fail-closed (review #3714) : sans RepoRoot la whitelist est incalculable —
        # "je ne peux pas verifier" ne doit jamais etre rendu comme "ce n'est pas protege".
        Write-PreOpGuardWarn "RepoRoot introuvable — '$LiteralPath' traite comme protege par precaution (fail-closed)."
        return [pscustomobject]@{ IsProtected=$true; Reason='NoRepoRoot'; Pattern=''; ProtectedPath='' }
    }

    # Normaliser en chemin absolu.
    $target = if ([System.IO.Path]::IsPathRooted($LiteralPath)) {
        $LiteralPath
    } else {
        # Relatif au cwd de l'appelant (pas du script), pour eviter une surprise si
        # l'appelant est dans un sous-module. -Force : sur Unix les dotfiles portent
        # l'attribut Hidden et Resolve-Path sans -Force les ignore (lecon #3714).
        # MAIS -Force n'existe pas sur Windows PowerShell 5.1 (ajoute en 7.x) : le
        # passer aveuglement fait echouer le PARAMETER BINDING — ni -ErrorAction ni
        # EAP n'attrapent un binding error — donc Test-ProtectedPath THROWAIT sur
        # toute entree relative en 5.1 (constate po-2026 19/09 : test fail-closed
        # rouge sur main non modifie). Splat conditionnel : -Force si le host le
        # connait, comportement 5.1 sinon (Windows : dotfiles pas Hidden par defaut,
        # la degradation est neutre).
        $resolveArgs = @{}
        if ((Get-Command Resolve-Path).Parameters.ContainsKey('Force')) { $resolveArgs['Force'] = $true }
        $LiteralPath | Resolve-Path @resolveArgs -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
    }
    if (-not $target) {
        # Fail-closed (review #3714) : un chemin non resoluble est traite en suspect,
        # jamais declare sur en silence. L'operation destructive est refusee jusqu'a
        # clarification — bloquer une cible inexistante est un no-op, l'inverse non.
        Write-PreOpGuardWarn "Chemin non resoluble : '$LiteralPath' — traite comme protege par precaution (fail-closed)."
        return [pscustomobject]@{ IsProtected=$true; Reason='PathNotResolved'; Pattern=''; ProtectedPath='' }
    }

    $protected = Get-ProtectedPaths -RepoRoot $RepoRoot
    foreach ($p in $protected) {
        if (-not $p.Exists) { continue }
        $pp = $p.FullPath

        # Match exact OU cible est descendante d'un protege.
        if ($target -eq $pp) {
            return [pscustomobject]@{ IsProtected=$true; Reason='ExactMatch'; Pattern=$p.Pattern; ProtectedPath=$pp }
        }
        # Normaliser les separateurs pour la comparaison. OrdinalIgnoreCase : une
        # cible absolue n'est jamais resolue et Get-Item preserve la casse tapee —
        # un ecart de casse cible/RepoRoot faisait rater les deux passes de prefixe
        # (mesure ai-01 19/09, suite #3732 ; voir le contexte 'Case-divergent' des tests).
        $targetN = $target -replace '\\','/'
        $ppN     = $pp     -replace '\\','/'
        if ($targetN.StartsWith($ppN + '/', [StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{ IsProtected=$true; Reason='InsideProtectedDir'; Pattern=$p.Pattern; ProtectedPath=$pp }
        }
    }

    # #3712 volet racine : une operation visee sur un ANCESTRE (ex: `git clean -fdx`
    # sur le worktree root) detruit tout ce qui est sous la cible. Sans ce cas, la
    # detection sautait tous les proteges CONTENUS dans la cible : le root n'est pas
    # lui-meme protege, donc le garde rendait Proceeded SANS backup — un garde
    # decoratif pour exactement la classe d'incident visee (l'exemple CLI documente
    # `deploy-preop-guard.ps1 'git clean -fdx' . Backup` ne backupait rien).
    $targetN = $target -replace '\\','/'
    foreach ($p in $protected) {
        if (-not $p.Exists) { continue }
        $ppN = $p.FullPath -replace '\\','/'
        if ($ppN.StartsWith($targetN.TrimEnd('/') + '/', [StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{ IsProtected=$true; Reason='ContainsProtectedPath'; Pattern=$p.Pattern; ProtectedPath=$p.FullPath }
        }
    }
    return [pscustomobject]@{ IsProtected=$false; Reason='NotInWhitelist'; Pattern=''; ProtectedPath='' }
}

function Backup-ProtectedPaths {
    <#
    .SYNOPSIS
        Parcourt -LiteralPath (repertoire racine). Pour chaque chemin protege detecte
        qui EXISTE, fait une copie horodatee vers %USERPROFILE%\.roo-state-manager\
        preop-backup\<timestamp>\<relative-path>.

        Best-effort : ne fait JAMAIS echouer. Les erreurs sont signalees en WARN.
        Retourne le nombre de chemins proteges effectivement backupes.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$LiteralPath,
        [string]$RepoRoot,
        [string]$Stamp
    )

    # -Stamp laisse l'appelant (Invoke-DeployPreOpGuard) fixer LA session : deux
    # Get-Date distincts produisaient un rendu BackupDir qui ne designait jamais la
    # session reellement ecrite (review #3714).
    if (-not $Stamp) { $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss' }
    # GetFolderPath('UserProfile') : cross-platform ($env:USERPROFILE est null sur Unix,
    # ce qui faisait crasher Backup-ProtectedPaths sur le runner CI Ubuntu). Combine :
    # separateur natif + PS 5.1 safe (Join-Path a 3 args exige PS 6.2+).
    $backupRoot = [IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'), '.roo-state-manager', 'preop-backup')
    $sessionDir = [IO.Path]::Combine($backupRoot, $Stamp)
    if (-not (Test-Path -LiteralPath $sessionDir)) {
        New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null
    }

    if (-not $RepoRoot) {
        $RepoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null | Out-String).Trim()
    }
    $protected = Get-ProtectedPaths -RepoRoot $RepoRoot
    $count = 0

    foreach ($p in $protected) {
        if (-not $p.Exists) { continue }
        # Ne backuper que les chemins SOUS le LiteralPath (sinon on sauvegarde tout
        # le repo a chaque deploy, ce qui n'est pas le but). OrdinalIgnoreCase : 3e
        # site de la classe casse (dispatch ai-01 19/09) — casse divergente rendait
        # un snapshot VIDE avec Action='BackedUp', succes menteur sur lequel
        # l'appelant detruit (le -ne adjacent est deja insensible par defaut).
        $ppN = $p.FullPath -replace '\\','/'
        $targetN = ($LiteralPath -replace '\\','/').TrimEnd('/')
        if ($targetN -ne '' -and $ppN -ne $targetN -and -not $ppN.StartsWith($targetN + '/', [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        try {
            # $relative est DEJA plat (les '/' sont remplaces par '__') : pas de decoupe
            # Parent/Leaf — le Parent d'un nom plat est vide, et Join-Path avec un enfant
            # vide a un comportement variable selon OS/version PS (rouge CI Ubuntu #3714).
            $relative = $ppN.Substring($RepoRoot.Length).TrimStart('/').Replace('/','__')
            $dest     = [IO.Path]::Combine($sessionDir, $relative)
            if (-not (Test-Path -LiteralPath $sessionDir)) {
                New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null
            }
            if ($p.IsContainer) {
                # -Recurse avec -Force (mais PAS -ErrorAction Stop -> continue on permission)
                Copy-Item -LiteralPath $p.FullPath -Destination $dest -Recurse -Force
            } else {
                Copy-Item -LiteralPath $p.FullPath -Destination $dest -Force
            }
            Write-PreOpGuardOk "BACKUP $($p.Pattern) -> $dest"
            $count++
        } catch {
            Write-PreOpGuardWarn "BACKUP ECHEC pour $($p.Pattern): $($_.Exception.GetType().Name): $($_.Exception.Message) (guard ligne $($_.InvocationInfo.ScriptLineNumber); FullPath=[$($p.FullPath)] len=$([string]$p.FullPath).Length)"
        }
    }

    if ($count -gt 0) {
        Write-PreOpGuardOk "Session backup : $sessionDir ($count chemins proteges copies)"
    } else {
        Write-PreOpGuardInfo "Aucun chemin protege a backuper sous $LiteralPath."
    }
    return $count
}

function Invoke-DeployPreOpGuard {
    <#
    .SYNOPSIS
        Garde pre-op deploy. Verifie que -LiteralPath n'est pas un chemin protege.

    .PARAMETER Operation
        Nom de l'operation en cours (pour le log). Ex: "git clean", "Remove-Item build".

    .PARAMETER LiteralPath
        Chemin (fichier ou repertoire) que l'operation va detruire/recouvrir.

    .PARAMETER Mode
        Block   (defaut) : renvoie Action=Blocked si protege (le caller abandonne ;
                           en CLI standalone, exit 3).
        Backup           : tente un backup, puis renvoie BackedUp (le caller decide).
        Warn             : renvoie Warned + affiche un WARN colore (le caller est sense savoir).

    .PARAMETER RepoRoot
        Working tree de reference.

    .OUTPUTS
        [pscustomobject]@{ Action='Blocked'|'BackedUp'|'Warned'|'Proceeded'; Reason=$string; BackupDir=$string; Copied=$int }

        Copied = nombre de chemins proteges REELLEMENT copies par cet appel (0 hors Mode Backup).
        Le garde le savait deja (console "N chemins proteges copies") mais ne le RENDAIT pas :
        l'appelant ne pouvait pas distinguer "sauvegarde 5" de "sauvegarde 0" avant de detruire,
        et un test ne pouvait l'asserter qu'en relisant un repertoire partage (review #3737).

    .EXAMPLE
        Invoke-DeployPreOpGuard -Operation "Remove-Item build/" -LiteralPath "build" -Mode Block
        # Rend Action=Blocked si build/ est protege (=oui par defaut). Le caller abandonne
        # (le CLI standalone traduit Blocked en exit 3).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Operation,
        [Parameter(Mandatory=$true)][string]$LiteralPath,
        [ValidateSet('Block','Backup','Warn')][string]$Mode = 'Block',
        [string]$RepoRoot
    )

    $result = Test-ProtectedPath -LiteralPath $LiteralPath -RepoRoot $RepoRoot

    if (-not $result.IsProtected) {
        Write-PreOpGuardInfo "$Operation sur $LiteralPath : hors whitelist, procede."
        return [pscustomobject]@{ Action='Proceeded'; Reason='NotProtected'; BackupDir=''; Copied=0 }
    }

    Write-PreOpGuardWarn "PROTEGE detecte : $LiteralPath ($($result.Reason), pattern=$($result.Pattern))"

    switch ($Mode) {
        'Block' {
            Write-PreOpGuardError "REFUSE : $Operation sur '$LiteralPath' menacerait '$($result.ProtectedPath)' (protege)."
            Write-PreOpGuardError "Si l'operation est VOLONTAIRE (ex: rebuild RSM clean build/), repasser -Mode Backup ou -Mode Warn."
            Write-PreOpGuardError "Pour ajouter une exception : definir DEPLOY_PROTECTED_PATHS (env) en retirant le pattern, ou appeler -Mode Backup pour un snapshot prealable."
            # NE PAS exit ici : l'appelant peut catcher via le return et choisir.
            # On laisse le choix au pipeline (le caller fait `if ($r.Action -eq 'Blocked') { exit 3 }`).
            return [pscustomobject]@{ Action='Blocked'; Reason=$result.Reason; BackupDir=''; Copied=0 }
        }
        'Backup' {
            # Un seul stamp pour l'ecriture ET le rendu : l'ancien code appelait
            # Backup-ProtectedPaths (qui faisait SON Get-Date) puis recomposait un
            # second Get-Date — BackupDir designait la racine preop-backup via
            # Split-Path -Parent, jamais le snapshot reel (review #3714).
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $n = Backup-ProtectedPaths -LiteralPath $LiteralPath -RepoRoot $RepoRoot -Stamp $stamp
            $sessionDir = [IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'), '.roo-state-manager', 'preop-backup', $stamp)
            Write-PreOpGuardOk "Backup pre-op termine ($n chemins). Operation $Operation peut proceder."
            return [pscustomobject]@{ Action='BackedUp'; Reason=$result.Reason; BackupDir=$sessionDir; Copied=$n }
        }
        'Warn' {
            Write-PreOpGuardWarn "WARN : $Operation sur '$LiteralPath' menacerait un chemin protege. Procede par demande explicite."
            return [pscustomobject]@{ Action='Warned'; Reason=$result.Reason; BackupDir=''; Copied=0 }
        }
    }
}

# --- Exports (quand ce script est charge comme module) ---
# Export-ModuleMember n'a de sens que dans un .psm1 ; ici on est en .ps1 (dot-source).
# Les fonctions sont automatiquement visibles apres dot-source. On garde le bloc
# sous un try silencieux pour permettre une evolution vers .psm1 sans toucher le test.
try {
    if ($MyInvocation.MyCommand.ModuleName) {
        Export-ModuleMember -Function @(
            'Get-ProtectedPaths',
            'Test-ProtectedPath',
            'Backup-ProtectedPaths',
            'Invoke-DeployPreOpGuard'
        )
    }
} catch {
    # ignore : on n'est pas dans un module
}

# --- Mode standalone : CLI ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    # Appele en standalone : exemple d'usage.
    if ($args.Count -lt 2) {
        Write-Host "Usage: deploy-preop-guard.ps1 <Operation> <LiteralPath> [Mode] [RepoRoot]" -ForegroundColor Yellow
        Write-Host "  Mode = Block|Backup|Warn (default Block)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Exemples:"
        Write-Host "  deploy-preop-guard.ps1 'Remove-Item build' build"
        Write-Host "  deploy-preop-guard.ps1 'git clean -fdx' . Backup"
        exit 2
    }
    $op   = $args[0]
    $path = $args[1]
    $mode = if ($args[2]) { $args[2] } else { 'Block' }
    $root = if ($args[3]) { $args[3] } else { '' }
    $res = Invoke-DeployPreOpGuard -Operation $op -LiteralPath $path -Mode $mode -RepoRoot $root
    Write-Host "Result: Action=$($res.Action) Reason=$($res.Reason) BackupDir=$($res.BackupDir) Copied=$($res.Copied)"
    if ($res.Action -eq 'Blocked') { exit 3 }
    exit 0
}

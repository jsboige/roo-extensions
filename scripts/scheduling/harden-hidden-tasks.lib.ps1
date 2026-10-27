<#
.SYNOPSIS
    Fonctions pures d'eligibilite de harden-hidden-tasks.ps1 (defauts A et B, issue #4118).

.DESCRIPTION
    Extraites du script principal pour etre testables sur des objets d'action
    SYNTHETIQUES (Pester, aucune tache reelle touchee) -- cf. l'acceptation de #4118.

    Defaut A : l'eligibilite etait une comparaison de 3 noms (`powershell.exe`,
    `pwsh.exe`, `cmd.exe`) sur le leaf brut du champ Execute. Trois ratages mesures :
    nom nu sans extension (`pwsh`), chemin quote (leaf termine par `"`), programme
    console hors liste (`python.exe`, `bash.exe`). L'eligibilite veritable est
    « l'action lance un executable du sous-systeme console » (IMAGE_SUBSYSTEM_WINDOWS_CUI
    = 3 du header PE). Chemin non resoluble -> repli sur la liste de noms APRES
    normalisation, et la tache est RAPPORTEE non resolue, jamais sautee en silence.

    Defaut B : la garde de propriete lisait le chemin (`maint-scripts\` = « d'une autre
    lane ») alors que le « proprietaire » depends de la lane qui EXECUTE l'outil :
    sous -Lane Maintenance, `maint-scripts\` est le staging DE Maintenance et les
    taches pointant dans `roo-extensions\` sont les etrangeres.

    PS 5.1 compatible : pas de ternaire, pas d'operateur ?. ; ASCII uniquement
    (le fichier est aussi dot-source par Windows PowerShell 5.1).
#>

# Repli quand le sous-systeme PE ne peut pas etre lu : la liste historique de 3 noms,
# appliquee au leaf NORMALISE (guillemets/espaces retires, variables expandees).
$script:ConsoleHostFallback = @('powershell.exe', 'pwsh.exe', 'cmd.exe')

# Marqueurs de chemin par lane : ce qui est « le staging d'UNE AUTRE lane » vu de -Lane.
# roo-extensions (defaut) exclut maint-scripts\ ; Maintenance exclut roo-extensions\.
$script:LaneForeignMarkers = @{
    'roo-extensions' = @('maint-scripts\')
    'Maintenance'    = @('roo-extensions\')
}

# Repertoire de lanceurs par defaut, par lane.
$script:LaneLauncherDir = @{
    'roo-extensions' = 'C:\ProgramData\claude-hidden-launchers'
    'Maintenance'    = 'C:\ProgramData\maint-hidden-launchers'
}

function Get-NormalizedExecutePath {
    # Execute brut -> forme exploitable : trim espaces ET guillemets d'extremite,
    # puis expansion des variables d'environnement (%SystemRoot%...). Retourne $null
    # si rien d'exploitable subsiste.
    param([string]$Execute)
    if ([string]::IsNullOrWhiteSpace($Execute)) { return $null }
    $s = $Execute.Trim().Trim('"').Trim("'").Trim()
    if (-not $s) { return $null }
    return [System.Environment]::ExpandEnvironmentVariables($s)
}

function Get-NormalizedLeaf {
    # Leaf du chemin NORMALISE (le leaf brut d'un chemin quote se termine par '"' :
    # `Split-Path '"C:\x\python.exe"' -Leaf` rend 'python.exe"' -- ratre par -notin).
    param([string]$Execute)
    $norm = Get-NormalizedExecutePath -Execute $Execute
    if (-not $norm) { return $null }
    return Split-Path $norm -Leaf
}

function Resolve-ExecutePath {
    # Chemin complet de l'executable, ou $null si non resoluble.
    # Absolu -> tel quel (l'existence est jugee par l'appelant via Test-Path, pour
    # distinguer « resolu mais absent » sans lever ici). Nom nu -> PATH via
    # Get-Command -CommandType Application, avec .exe par defaut si sans extension.
    param([string]$Execute)
    $norm = Get-NormalizedExecutePath -Execute $Execute
    if (-not $norm) { return $null }
    # Un caractere illegal dans un chemin (guillemet interne d'une tache citee,
    # forme du defaut C : tete quote + args dans Execute) fait LEVER IsPathRooted
    # comme HasExtension : une entree non resoluble doit rendre $null, pas tuer
    # l'appelant (Get-Command echouerait de toute facon sur cette forme).
    if ($norm.IndexOfAny([System.IO.Path]::GetInvalidPathChars()) -ge 0) { return $null }
    if ([System.IO.Path]::IsPathRooted($norm)) { return $norm }
    $cmd = Get-Command $norm -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    if (-not [System.IO.Path]::HasExtension($norm)) {
        $cmd = Get-Command ($norm + '.exe') -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Test-ConsoleSubsystem {
    # Lit le champ Subsystem du header PE. $true = console (CUI=3), $false = autre
    # (GUI...), $null = illisible (absent, ACL, pas un PE) -- l'appelant replie sur
    # la liste de noms.
    param([string]$Path)
    if (-not $Path) { return $null }
    try { $fs = [System.IO.File]::OpenRead($Path) } catch { return $null }
    try {
        if ($fs.Length -lt 264) { return $null }
        $buf = New-Object byte[] 264
        if ($fs.Read($buf, 0, 264) -lt 264) { return $null }
        $peOff = [BitConverter]::ToInt32($buf, 0x3C)
        if ($peOff -lt 0 -or ($peOff + 94) -gt $fs.Length) { return $null }
        $fs.Position = $peOff
        $sig = New-Object byte[] 4
        if ($fs.Read($sig, 0, 4) -lt 4) { return $null }
        if ($sig[0] -ne 0x50 -or $sig[1] -ne 0x45) { return $null }   # 'PE'\0\0
        # COFF header = 20 octets ; Subsystem a l'offset 68 de l'Optional Header.
        $fs.Position = $peOff + 4 + 20 + 68
        $sub = New-Object byte[] 2
        if ($fs.Read($sub, 0, 2) -lt 2) { return $null }
        return ([BitConverter]::ToUInt16($sub, 0) -eq 3)
    } finally { $fs.Dispose() }
}

function Test-ConsoleExecute {
    # Verdict d'eligibilite "cette action lance-t-elle une console ?" sur le champ
    # Execute seul. Hashtable : Console (bool), Resolved (bool), Method
    # ('subsystem' | 'name-list'), Path, Leaf. Ne leve jamais.
    param([string]$Execute)
    $leaf = Get-NormalizedLeaf -Execute $Execute
    $result = @{ Console = $false; Resolved = $false; Method = $null; Path = $null; Leaf = $leaf }
    $path = Resolve-ExecutePath -Execute $Execute
    if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        $sub = Test-ConsoleSubsystem -Path $path
        if ($null -ne $sub) {
            $result.Path = $path
            $result.Resolved = $true
            $result.Method = 'subsystem'
            $result.Console = $sub
            return $result
        }
    }
    # Non resoluble (ou PE illisible) : repli sur la liste de noms, sur le leaf
    # NORMALISE -- le verdict par liste reste possible, mais Resolved=$false pour
    # que la tache soit RAPPORTEE non resolue plutot que silencieusement classee.
    $result.Method = 'name-list'
    if ($leaf) { $result.Console = ($leaf -in $script:ConsoleHostFallback) }
    return $result
}

function Test-AlreadyHardenedAction {
    # Deja durcie = Execute dont le leaf NORMALISE est wscript.exe (un chemin quote
    # ou a variable d'environnement doit etre reconnu tout autant que la forme nue).
    param($Action)
    if (-not $Action -or -not $Action.Execute) { return $false }
    $leaf = Get-NormalizedLeaf -Execute ([string]$Action.Execute)
    return ($leaf -and $leaf -ieq 'wscript.exe')
}

function Get-VbsRunCommand {
    # Defaut C (harden-hidden-tasks.ps1, mesure ai-01 26-27/10, lanes vllm/Maintenance) :
    # une tache creee par `schtasks /tr "<commande>"` non quote stocke TOUTE la ligne
    # dans le champ Execute. L'ancien assemblage '"{0}" {1}' -f $Execute, $Arguments
    # fabriquait alors un token unique de bout en bout :
    #     "C:\Program Files\PowerShell\7\pwsh.exe -NoProfile -File D:\x.ps1"
    # CreateProcess (appele par WScript.Shell.Run) prenait la ligne ENTIERE pour le
    # chemin de l'executable -> 0x80070002, tache morte en silence (LastTaskResult
    # reste 0 : le lanceur VBS de l'epoque ne propageait pas l'erreur). L'executable
    # doit etre quote SEUL, les arguments restent hors des guillemets.
    #
    # Regles, dans l'ordre :
    #   1. Execute resout (chemin absolu existant, ou nom nu trouve dans le PATH)
    #        -> '"<chemin resolu>" <arguments>'
    #   2. Execute commence par un guillemet (deja quote par l'auteur de la tache)
    #        -> verbatim + arguments
    #   3. un PREFIXE d'Execute resout (chemin a espaces stocke AVEC ses args) :
    #        on ecarte les premiers mots un a un (plus court prefixe resolu d'abord,
    #        la meme strategie que CreateProcess) jusqu'a un candidat existant
    #        -> '"<prefixe resolu>" <reste d'Execute> <arguments>'
    #   4. rien ne resout
    #        -> Execute + arguments TEL QUEL, sans guillemet ajoute : semantique
    #           d'avant durcissement (CreateProcess essaie les prefixes), et
    #           l'echec eventuel est desormais VISIBLE car le lanceur propage
    #           Err.Number (voir le gabarit VBS du script principal).
    #
    # $TestPath est injectable pour les tests (Pester tourne sous pwsh 7 sur des
    # runners linux : les chemins Windows n'y existent pas, la verite du systeme
    # de fichiers n'est pas ce qui est teste ici).
    param(
        [string]$Execute,
        [string]$Arguments,
        [scriptblock]$TestPath = { param($p) Test-Path -LiteralPath $p -PathType Leaf }
    )
    if ([string]::IsNullOrWhiteSpace($Execute)) { return $null }
    $exe = $Execute.Trim()
    $args = [string]$Arguments
    $resolved = Resolve-ExecutePath -Execute $exe
    if ($resolved -and (& $TestPath $resolved)) {
        if ($args) { return '"{0}" {1}' -f $resolved, $args }
        return '"{0}"' -f $resolved
    }
    if ($exe.StartsWith('"')) {
        if ($args) { return '{0} {1}' -f $exe, $args }
        return $exe
    }
    $norm = Get-NormalizedExecutePath -Execute $exe
    if ($norm -and $norm.Contains(' ')) {
        $tokens = $norm -split ' '
        for ($i = 1; $i -lt $tokens.Count; $i++) {
            $candidate = ($tokens[0..($i - 1)] -join ' ')
            $candResolved = Resolve-ExecutePath -Execute $candidate
            if ($candResolved -and (& $TestPath $candResolved)) {
                $rest = ($tokens[$i..($tokens.Count - 1)] -join ' ')
                $line = '"{0}" {1}' -f $candResolved, $rest
                if ($args) { return '{0} {1}' -f $line, $args }
                return $line
            }
        }
    }
    if ($args) { return '{0} {1}' -f $exe, $args }
    return $exe
}

function Test-ForeignDeployerAction {
    # $true = l'action appartient au staging d'une AUTRE lane que -Lane (les TROIS
    # champs sont testes : Execute, Arguments, WorkingDirectory -- mesure 17/09,
    # un seul champ rendrait la garde dependante de la forme de la tache voisine).
    # Le filtre -TaskName reste l'opt-in explicite qui contourne la garde.
    param($Action, [string]$Lane, [string[]]$TaskNameFilter)
    if (-not $Action -or -not $Action.Execute) { return $false }
    if ($TaskNameFilter) { return $false }
    $markers = $script:LaneForeignMarkers[$Lane]
    if (-not $markers) { $markers = $script:LaneForeignMarkers['roo-extensions'] }
    $ownerFields = '{0} {1} {2}' -f $Action.Execute, $Action.Arguments, $Action.WorkingDirectory
    foreach ($m in $markers) {
        if ($ownerFields -like ('*' + $m + '*')) { return $true }
    }
    return $false
}

function Get-HardenDecision {
    # Decision complete pour UNE tache (objet ScheduledTask reelle OU synthetique de
    # meme forme : .TaskName, .State, .Actions[0]{Execute,Arguments,WorkingDirectory},
    # .Principal{LogonType,RunLevel}). Ordre VOLONTAIRE (issue #4118, symptome B2) :
    # 1. deja durcie AVANT la garde de propriete -- une tache durcie ne doit jamais
    #    apparaitre dans « Exclues » ;
    # 2. garde de propriete (suivant la lane qui execute) ;
    # 3. eligibilite console (sous-systeme PE, repli liste de noms) ;
    # 4. Principal Interactive (S4U/Password = session 0, rien a corriger).
    # Hashtable : Decision ('plan'|'hardened'|'foreign'|'no-console'|'no-action'|
    # 'non-interactive'), Unresolved (bool), Method, Path.
    param($Task, [string]$Lane = 'roo-extensions', [string[]]$TaskNameFilter)
    $action = $Task.Actions | Select-Object -First 1
    if (-not $action -or -not $action.Execute) {
        return @{ Decision = 'no-action'; Unresolved = $false; Method = $null; Path = $null }
    }
    if (Test-AlreadyHardenedAction -Action $action) {
        return @{ Decision = 'hardened'; Unresolved = $false; Method = $null; Path = $null }
    }
    if (Test-ForeignDeployerAction -Action $action -Lane $Lane -TaskNameFilter $TaskNameFilter) {
        return @{ Decision = 'foreign'; Unresolved = $false; Method = $null; Path = $null }
    }
    $console = Test-ConsoleExecute -Execute ([string]$action.Execute)
    if (-not $console.Console) {
        return @{ Decision = 'no-console'; Unresolved = (-not $console.Resolved); Method = $console.Method; Path = $console.Path }
    }
    if ($Task.Principal.LogonType -ne 'Interactive') {
        return @{ Decision = 'non-interactive'; Unresolved = $false; Method = $console.Method; Path = $console.Path }
    }
    return @{ Decision = 'plan'; Unresolved = (-not $console.Resolved); Method = $console.Method; Path = $console.Path }
}

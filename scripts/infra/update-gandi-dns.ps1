<#
.SYNOPSIS
    Maintient les enregistrements A de myia.io alignes sur l'IP publique de la box.

.DESCRIPTION
    La flotte entiere resout a travers la zone LiveDNS de myia.io, servie par une IP
    residentielle dynamique. Quand le bail change, les enregistrements deviennent
    perimes et toute la flotte perd la resolution.

    Le script ne touche QUE les rrsets A dont la valeur courante est celle de l'apex.
    L'apex '@' EST la box par definition : il porte donc l'ancienne IP au moment ou
    elle change, ce qui evite tout fichier d'etat. Un enregistrement A pointant
    deliberement ailleurs n'est jamais modifie.

    Mesure du 2026-08-22 : 8 rrsets A suivaient la box (@, *, *.blog, *.imap, *.pop,
    *.smtp, *.webmail, *.www). Le script les decouvre, il ne les code pas en dur --
    un updater limite au seul wildcard en aurait laisse 7 perimes.

.NOTES
    Le PAT Gandi vit dans le trousseau Windows (credential generique
    'Gandi-LiveDNS-PAT'), jamais dans un fichier ni dans une variable d'environnement.
    La tache planifiee tourne en MYIA / Limited / InteractiveToken, comme ses voisines
    sur cette machine : c'est ce qui rend le trousseau utilisateur lisible.

    Sous 'wscript //B' la sortie standard est jetee : le script logue lui-meme, et son
    code de sortie est le seul autre signal. Il sort non-nul des qu'une ecriture echoue.

    Dot-sourcer ce fichier ne fait que definir les fonctions (aucun effet de bord,
    aucune API Windows) : c'est ce qui rend Get-BoxFollowingRrsets testable en CI,
    y compris sur Linux. Voir scripts/testing/unit/update-gandi-dns.Tests.ps1.

.EXAMPLE
    pwsh -File scripts/infra/update-gandi-dns.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$Domain = 'myia.io',
    [string]$CredentialTarget = 'Gandi-LiveDNS-PAT',
    [string]$LogDir,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

# ---------------------------------------------------------------- journalisation
# Declaree ici pour qu'elle EXISTE toujours : sous StrictMode, tester une variable
# jamais affectee leve, y compris dans le 'if' cense s'en proteger.
$script:LogFile = $null

function Initialize-Logging {
    param([string]$Dir)
    if (-not $Dir) {
        $scriptDir = Split-Path $PSCommandPath -Parent
        $repoRoot  = Split-Path (Split-Path $scriptDir -Parent) -Parent
        $Dir = Join-Path $repoRoot 'outputs/gandi-dns'
    }
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    $script:LogFile = Join-Path $Dir ("gandi-dns-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))
}

function Write-Log {
    param([string]$Level, [string]$Message)
    $line = "{0} [{1,-5}] {2}" -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'), $Level, $Message
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value $line -Encoding utf8 }
    Write-Host $line
}

# ---------------------------------------------------------------------- trousseau
function Get-GandiPat {
    <#  Le P/Invoke advapi32 vit ICI et non au niveau du fichier : dot-sourcer le
        script sur Linux (CI) ne doit declencher aucune dependance Windows. #>
    param([string]$Target)

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class GandiCred {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct CREDENTIAL {
    public UInt32 Flags; public UInt32 Type; public IntPtr TargetName; public IntPtr Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public UInt32 CredentialBlobSize; public IntPtr CredentialBlob; public UInt32 Persist;
    public UInt32 AttributeCount; public IntPtr Attributes; public IntPtr TargetAlias; public IntPtr UserName;
  }
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool CredReadW(string target, UInt32 type, UInt32 flags, out IntPtr cred);
  [DllImport("advapi32.dll")] public static extern void CredFree(IntPtr buf);
}
'@ -ErrorAction SilentlyContinue

    $ptr = [IntPtr]::Zero
    if (-not [GandiCred]::CredReadW($Target, 1, 0, [ref]$ptr)) {
        $win32 = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Credential '$Target' introuvable dans le trousseau (Win32=$win32). Le PAT n'a jamais ete range, ou la tache ne tourne pas sous le compte qui le detient."
    }
    $c = [Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type]'GandiCred+CREDENTIAL')
    $bytes = New-Object byte[] $c.CredentialBlobSize
    [Runtime.InteropServices.Marshal]::Copy($c.CredentialBlob, $bytes, 0, $c.CredentialBlobSize)
    [GandiCred]::CredFree($ptr)
    [System.Text.Encoding]::Unicode.GetString($bytes)
}

# -------------------------------------------------------------------- IP publique
function Get-PublicIp {
    <#  Deux sources concordantes au minimum : une seule qui mentirait ferait ecrire
        une IP fausse dans TOUTE la zone.

        Points de terminaison explicitement IPv4. La box a de l'IPv6, et un service
        generique (ifconfig.me, icanhazip.com) repond alors l'adresse v6 -- ecartee
        par le filtre, ce qui ferait echouer la corroboration a chaque passage. #>
    param([string[]]$Sources = @(
        'https://api4.ipify.org',
        'https://ipv4.icanhazip.com',
        'https://checkip.amazonaws.com'
    ))

    $seen = @()
    foreach ($s in $Sources) {
        try {
            $ip = (Invoke-RestMethod -Uri $s -TimeoutSec 10).ToString().Trim()
            if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
                $seen += $ip
            } else {
                # Ne jamais ecarter une source en silence : c'est ainsi qu'un updater
                # cesse de fonctionner sans que rien ne le signale.
                Write-Log 'WARN' "Source IP ecartee ($s) : reponse non-IPv4 ($($ip.Length) caracteres)."
            }
        } catch {
            Write-Log 'WARN' "Source IP indisponible ($s) : $($_.Exception.Message)"
        }
    }

    $distinct = @($seen | Select-Object -Unique)
    if ($distinct.Count -eq 0) { throw "Aucune source d'IP publique n'a repondu." }
    if ($distinct.Count -gt 1) { throw "Sources d'IP publique en desaccord ($($distinct -join ', ')) -- abandon sans ecriture." }
    if ($seen.Count -lt 2)     { throw "Une seule source d'IP publique a repondu -- pas de corroboration, abandon sans ecriture." }
    $distinct[0]
}

# ---------------------------------------------------------------------------- API
$script:ApiBase = 'https://api.gandi.net/v5/livedns'

function Invoke-Gandi {
    param([string]$Method, [string]$Path, $Body)
    $req = @{
        Method     = $Method
        Uri        = "$script:ApiBase$Path"
        Headers    = @{ Authorization = "Bearer $script:Pat" }
        TimeoutSec = 30
    }
    if ($null -ne $Body) {
        $req.Body        = ($Body | ConvertTo-Json -Compress)
        $req.ContentType = 'application/json'
    }
    Invoke-RestMethod @req
}

function Get-BoxFollowingRrsets {
    <#  Selection : rrsets A a valeur UNIQUE egale a $Ip.

        - valeur unique  : un rrset multi-valeurs fait du round-robin ou du failover,
                           l'ecraser avec une seule IP detruirait cette intention ;
        - egalite stricte: un A pointant ailleurs suit autre chose que la box et ne
                           doit jamais bouger. #>
    param($Records, [string]$Ip)
    $matched = @($Records | Where-Object {
        $_.rrset_type -eq 'A' -and @($_.rrset_values).Count -eq 1 -and @($_.rrset_values)[0] -eq $Ip
    })
    # ',' empeche PowerShell de derouler le tableau au retour. Sans lui, un resultat
    # VIDE revient en $null et '$x.Count' leve sous StrictMode -- or le cas vide est
    # precisement le cas du SUCCES dans la contre-epreuve de fin de mise a jour :
    # chaque update reussie aurait ete rapportee comme un echec.
    return ,$matched
}

# --------------------------------------------------------------------------- main
function Invoke-GandiDnsUpdate {
    param([string]$Domain, [string]$CredentialTarget, [switch]$DryRun)

    $exitCode = 0
    Write-Log 'INFO' "Demarrage (domain=$Domain, host=$env:COMPUTERNAME, user=$env:USERNAME, dryRun=$($DryRun.IsPresent))"

    try {
        $script:Pat = Get-GandiPat -Target $CredentialTarget
        $currentIp  = Get-PublicIp
        $records    = @(Invoke-Gandi -Method GET -Path "/domains/$Domain/records")

        $apex = @($records | Where-Object { $_.rrset_name -eq '@' -and $_.rrset_type -eq 'A' })
        if ($apex.Count -eq 0) {
            throw "Pas d'enregistrement A pour l'apex de $Domain -- impossible de determiner l'ancienne IP sans supposer."
        }
        $oldIp = @($apex[0].rrset_values)[0]

        if ($oldIp -eq $currentIp) {
            Write-Log 'INFO' "Rien a faire : apex et IP publique concordent ($currentIp)."
            return 0
        }

        $targets = Get-BoxFollowingRrsets -Records $records -Ip $oldIp
        $names   = ($targets | ForEach-Object { $_.rrset_name }) -join ', '
        Write-Log 'WARN' "IP publique changee : $oldIp -> $currentIp. $($targets.Count) rrset(s) A a mettre a jour : $names"

        foreach ($r in $targets) {
            $name = $r.rrset_name
            if ($DryRun) {
                Write-Log 'INFO' "DRY-RUN: $name A -> $currentIp (ttl=$($r.rrset_ttl))"
                continue
            }
            try {
                $encoded = [System.Uri]::EscapeDataString($name)
                $body    = @{ rrset_values = @($currentIp); rrset_ttl = $r.rrset_ttl }
                Invoke-Gandi -Method PUT -Path "/domains/$Domain/records/$encoded/A" -Body $body | Out-Null
                Write-Log 'INFO' "Ecrit : $name A -> $currentIp (ttl=$($r.rrset_ttl))"
            } catch {
                Write-Log 'ERROR' "Echec sur $name : $($_.Exception.Message)"
                $exitCode = 1
            }
        }

        if (-not $DryRun) {
            # Contre-epreuve : relire la zone plutot que se fier aux codes de retour.
            $after = @(Invoke-Gandi -Method GET -Path "/domains/$Domain/records")
            $stale = Get-BoxFollowingRrsets -Records $after -Ip $oldIp
            if ($stale.Count -gt 0) {
                $staleNames = ($stale | ForEach-Object { $_.rrset_name }) -join ', '
                Write-Log 'ERROR' "Apres ecriture, $($stale.Count) rrset(s) portent encore $oldIp : $staleNames"
                $exitCode = 1
            } else {
                Write-Log 'INFO' "Verifie par relecture : plus aucun rrset A ne porte $oldIp."
            }
        }
    } catch {
        Write-Log 'ERROR' $_.Exception.Message
        $exitCode = 1
    } finally {
        $script:Pat = $null
    }

    return $exitCode
}

# Dot-source (tests unitaires) : on s'arrete apres les definitions de fonctions.
if ($MyInvocation.InvocationName -eq '.') { return }

Initialize-Logging -Dir $LogDir
$code = Invoke-GandiDnsUpdate -Domain $Domain -CredentialTarget $CredentialTarget -DryRun:$DryRun
Write-Log 'INFO' "Fin (exit=$code)"
exit $code

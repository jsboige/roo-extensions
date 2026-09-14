#Requires -Version 5.1
<#
.SYNOPSIS
  Gate de recette de bascule DNS pour l'Epic #3188 (web1 -> VPS-4 2027).

.DESCRIPTION
  Rend executable la recette " reco #1 de web1 " du runbook de provisionnement
  (docs/harness/machine-specific/vps4-2027-provisioning-runbook.md, section 6) :
  AVANT tout changement DNS, chaque domaine doit repondre SUR L'IP CIBLE avec le
  bon contenu ET le bon certificat, la resolution etant forcee par `curl --resolve`
  (le DNS public reste intact pendant toute la recette).

  Le point que ce harnais refuse : un domaine rattrape par un catch-all est un
  ECHEC, pas un succes. Un code HTTP 200 ne suffit donc jamais - la page par
  defaut d'IIS repond 200. C'est exactement le constat de la section 6 (le Default
  Web Site de web1 rattrape argumentum.fr / myia.org, ~15 000 requetes 404 en 5 j).

  Controles par domaine :
  - HTTP :80 et HTTPS :443 repondent ;
  - le HTTPS est verifie SANS -k : l'echec de verification TLS (certificat
    auto-signe, mauvais hote, chaine invalide) rend 000 et FAIL, avec l'erreur
    curl dans le motif d'echec ;
  - le sujet du certificat presente DOIT couvrir le domaine (assertion
    CertExpect, pas un simple affichage) ;
  - le marqueur de contenu attendu est present, aucun marqueur de catch-all ;
  - toutes les requetes passent --resolve pour TOUS les domaines de la table
    (les deux ports) : une redirection vers un domaine de la table reste sur
    l'IP cible, et l'URL finale (%{url_effective}) doit rester dans le perimetre
    de la table.

  Note portabilite : les appels curl utilisent `-o NUL` (poubelle Windows).
  Sur Linux/macOS, remplacer `NUL` par `/dev/null`.

.PARAMETER TargetIp
  IP de la machine cible. Defaut : VPS-4 2027 (51.75.200.22).

.PARAMETER ControlIp
  IP de la machine source, utilisee comme controle positif par -SelfTest.
  Defaut : web1 actuelle (37.187.180.135).

.PARAMETER Domains
  Sous-ensemble de domaines a recetter. Defaut : la famille Argumentum, perimetre
  de la Phase 1. Domaines disponibles : les cles de $script:DomainTable.

.PARAMETER SelfTest
  Verifie que le harnais DISCRIMINE avant de s'en servir. Quatre controles :
  (1) POSITIF live - www.argumentum.games doit PASSER contre ControlIp ;
  (2) NEGATIF live - myia.org doit ECHOUER sur le catch-all contre ControlIp ;
  (3) CERTIFICAT synthetique - un mauvais sujet de cert doit ECHOUER (et un bon
  sujet PASSER) dans la logique de verdict ;
  (4) REDIRECTION synthetique - une URL finale hors table doit ECHOUER.
  Sort 1 si un controle echoue - un harnais qui dit PASS partout ne prouve rien.

.EXAMPLE
  # 1. Le harnais discrimine-t-il ? (a lancer en premier)
  .\test-vps4-cutover-recette.ps1 -SelfTest

.EXAMPLE
  # 2. Recette de la famille Argumentum sur la machine neuve
  .\test-vps4-cutover-recette.ps1

.EXAMPLE
  # 3. Recette des 5 domaines de l'Epic
  .\test-vps4-cutover-recette.ps1 -Domains argumentum.games,www.argumentum.games,argumentum.fr,myia.org,www.myia.org

.NOTES
  Lecture seule : aucune ecriture (hors fichier temporaire local), aucun
  changement DNS, aucun acces distant.
  Epic #3188, Phase 1. Valide sous Windows PowerShell 5.1 et PowerShell 7.
#>
[CmdletBinding()]
param(
  [string]   $TargetIp  = '51.75.200.22',
  [string]   $ControlIp = '37.187.180.135',
  [string[]] $Domains,
  [switch]   $SelfTest
)

$ErrorActionPreference = 'Continue'

# Marqueurs de contenu : ce qui doit etre present, et ce qui trahit un catch-all.
$script:ForbiddenMarkers = @('IIS Windows Server', 'iisstart.png')

# Table des domaines de l'Epic #3188 (section 6 du runbook).
#   Expect     : marqueur de contenu qui doit etre present.
#   CertExpect : fragment que le sujet du certificat presente doit couvrir
#                (suffisamment souple pour survivre a une re-emission Let's
#                Encrypt, assez strict pour attraper un cert etranger).
$script:DomainTable = [ordered]@{
  'www.argumentum.games' = @{ Expect = 'Argumentum'; CertExpect = 'argumentum'; Role = 'prod DNN' }
  'argumentum.games'     = @{ Expect = 'Argumentum'; CertExpect = 'argumentum'; Role = 'prod DNN (apex)' }
  'argumentum.fr'        = @{ Expect = 'Argumentum'; CertExpect = 'argumentum'; Role = 'portail/redirection' }
  'myia.org'             = @{ Expect = 'myia';       CertExpect = 'myia';       Role = 'Phase 2 - vitrine' }
  'www.myia.org'         = @{ Expect = 'myia';       CertExpect = 'myia';       Role = 'Phase 2 - vitrine' }
}

# Perimetre par defaut : la famille Argumentum (Phase 1).
$script:DefaultDomains = @('www.argumentum.games', 'argumentum.games', 'argumentum.fr')

if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
  Write-Error 'curl.exe introuvable - prerequis du harnais.'
  exit 2
}

foreach ($d in $script:DefaultDomains) {
  if (-not $script:DomainTable.Contains($d)) {
    Write-Error "Domaine inconnu de la table : $d"
    exit 2
  }
}

# ---------------------------------------------------------------------------
# Verdict. Fonction separee : c'est ce que les controles synthetiques du
# SelfTest exercent directement (axe cert, axe redirection) - on ne peut pas
# les exercer en live contre ControlIp, ou un nom hors bindings est RESET au
# handshake TLS (IIS/SNI) plutot que servi avec un mauvais certificat.
# ---------------------------------------------------------------------------
function Get-RecetteVerdict {
  param(
    [string]   $Http80,
    [string]   $Https443,
    [string]   $CertSubject,
    [string]   $CertExpect,
    [bool]     $HasExpect,
    [string]   $Expect,
    [string]   $HitForbidden,
    [string]   $FinalUrl,
    [string[]] $AllowedHosts,
    [string]   $FollowErr
  )

  $why = New-Object System.Collections.ArrayList
  if ($Http80   -notmatch '^(200|301|302)$') { [void]$why.Add("http80=$Http80") }
  if ($Https443 -notmatch '^(200|301|302)$') { [void]$why.Add("https443=$Https443") }

  if ($CertSubject -eq 'aucun') {
    # TLS etabli (HTTPS repond) mais sujet illisible ; si le TLS a echoue,
    # https443 l'a deja signale au-dessus.
    if ($Https443 -match '^(200|301|302)$') { [void]$why.Add('certificat illisible alors que HTTPS repond') }
  } elseif ($CertSubject -notmatch [regex]::Escape($CertExpect)) {
    [void]$why.Add("certificat '$CertSubject' ne couvre pas '$CertExpect'")
  }

  if ($HitForbidden) { [void]$why.Add("catch-all ('$HitForbidden')") }
  if (-not $HasExpect) { [void]$why.Add("marqueur '$Expect' absent") }
  if ($FollowErr) { [void]$why.Add("suivi de redirection echoue: $FollowErr") }

  $finalHost = ''
  if ($FinalUrl) {
    try { $finalHost = ([uri]$FinalUrl).Host } catch { $finalHost = $FinalUrl }
  }
  if ($finalHost -and $AllowedHosts -and ($AllowedHosts -notcontains $finalHost)) {
    [void]$why.Add("redirection hors perimetre: $FinalUrl")
  }

  if ($why.Count -eq 0) { return @{ Verdict = 'PASS'; Why = '' } }
  return @{ Verdict = 'FAIL'; Why = ($why -join '; ') }
}

function Test-DomainOnIp {
  param(
    [Parameter(Mandatory)][string] $Domain,
    [Parameter(Mandatory)][string] $Ip,
    [Parameter(Mandatory)][string] $Expect,
    [Parameter(Mandatory)][string] $CertExpect
  )

  $res = [ordered]@{
    Domain   = $Domain
    Http80   = '000'
    Https443 = '000'
    Cert     = 'aucun'
    FinalUrl = ''
    Verdict  = 'FAIL'
    Why      = ''
  }

  # Pinning : TOUS les domaines de la table, les deux ports, dans CHAQUE appel.
  # Une redirection 301/302 vers un autre domaine de la table reste ainsi sur
  # l'IP cible ; un hote hors table resoudrait via le DNS public et serait
  # attrape par le controle %{url_effective}.
  $resolveArgs = @()
  foreach ($d in @($script:DomainTable.Keys)) {
    $resolveArgs += @('--resolve', "${d}:80:${Ip}")
    $resolveArgs += @('--resolve', "${d}:443:${Ip}")
  }
  $argCommon = @('--connect-timeout', '6', '--max-time', '15') + $resolveArgs

  # 1. HTTP :80
  $raw = (& curl.exe -s -o NUL -w '%{http_code}' @argCommon "http://${Domain}/" 2>$null | Out-String).Trim()
  if ($raw) { $res.Http80 = ($raw -split "`r?`n")[0] }

  # 2. HTTPS :443 SANS -k : la verification TLS EST le controle. Un certificat
  #    non fiable ou couvrant un autre nom rend 000 ; %{errormsg} porte la
  #    cause, %{certs} le sujet (build Schannel) quand la verification passe.
  $raw = (& curl.exe -s -o NUL -w '%{http_code}|%{errormsg}|%{certs}' @argCommon "https://${Domain}/" 2>$null | Out-String)
  $parts = $raw -split '\|', 3
  $code  = ''
  if ($parts.Count -ge 1) { $code = $parts[0].Trim() }
  if ($code) { $res.Https443 = $code }
  $tlsErr = ''
  if ($parts.Count -ge 2) { $tlsErr = $parts[1].Trim() }
  if ($res.Https443 -eq '000' -and $tlsErr) { $res.Https443 = "000 ($tlsErr)" }

  $certsBlock = ''
  if ($parts.Count -ge 3) { $certsBlock = $parts[2] }
  $m = [regex]::Match($certsBlock, 'Subject:\s*([^\r\n]+)')
  if ($m.Success) {
    $res.Cert = $m.Groups[1].Value.Trim()
  } elseif ($res.Https443 -match '^(200|301|302)$') {
    # Build OpenSSL : %{certs} rend du PEM (pas de ligne Subject:) ; -v, lui,
    # imprime "subject: CN=...". La verification a deja passe a l'etape 2.
    $verbose = (& curl.exe -v -o NUL @argCommon "https://${Domain}/" 2>&1 | Out-String)
    $m2 = [regex]::Match($verbose, '(?i)subject:\s*([^\r\n]+)')
    if ($m2.Success) { $res.Cert = $m2.Groups[1].Value.Trim() }
  }

  # 3. Contenu : corps de la reponse finale via -L (corps vers un fichier
  #    temporaire, le write-out reste seul sur stdout), URL finale capturee.
  $body = ''
  $followErr = ''
  $tmp = [System.IO.Path]::GetTempFileName()
  try {
    $wu = ''
    if ($res.Https443 -match '^(200|301|302)$') {
      $wu = (& curl.exe -s -L -o $tmp -w '%{url_effective}|%{errormsg}' @argCommon "https://${Domain}/" 2>$null | Out-String).Trim()
    } elseif ($res.Http80 -match '^(200|301|302)$') {
      $wu = (& curl.exe -s -L -o $tmp -w '%{url_effective}|%{errormsg}' @argCommon "http://${Domain}/" 2>$null | Out-String).Trim()
    }
    if (Test-Path $tmp) { $body = [System.IO.File]::ReadAllText($tmp) }
    $wparts = $wu -split '\|', 2
    if ($wparts.Count -ge 1) { $res.FinalUrl = $wparts[0].Trim() }
    if ($wparts.Count -ge 2) { $followErr = $wparts[1].Trim() }
  } finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
  }

  $hitForbidden = ''
  foreach ($f in $script:ForbiddenMarkers) {
    if ($body.IndexOf($f, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hitForbidden = $f; break }
  }
  $hasExpect = ($body.IndexOf($Expect, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)

  # Verdict : un 200 ne suffit pas.
  $v = Get-RecetteVerdict -Http80 $res.Http80 -Https443 $res.Https443 -CertSubject $res.Cert `
    -CertExpect $CertExpect -HasExpect $hasExpect -Expect $Expect -HitForbidden $hitForbidden `
    -FinalUrl $res.FinalUrl -AllowedHosts @($script:DomainTable.Keys) -FollowErr $followErr
  $res.Verdict = $v.Verdict
  $res.Why = $v.Why

  return [pscustomobject]$res
}

function Invoke-Recette {
  param([string]$Ip, [string[]]$DomainList)

  $rows = foreach ($d in $DomainList) {
    $t = $script:DomainTable[$d]
    Test-DomainOnIp -Domain $d -Ip $Ip -Expect $t.Expect -CertExpect $t.CertExpect
  }
  return @($rows)
}

# ---------------------------------------------------------------------------
# Mode SelfTest : prouver la discrimination avant de servir de gate.
# ---------------------------------------------------------------------------
if ($SelfTest) {
  Write-Output "=== SELFTEST - le harnais discrimine-t-il ? (contre $ControlIp) ==="
  $rows = Invoke-Recette -Ip $ControlIp -DomainList @('www.argumentum.games', 'myia.org')
  $rows | Format-Table Domain, Http80, Https443, Cert, Verdict, Why -AutoSize | Out-String | Write-Output

  # @() obligatoire : sous PS 5.1, .Count sur un objet unique rend $null (pas 1),
  # et un objet unique (et non un tableau) n'expose pas .Count de facon fiable.
  $okPositive = @($rows | Where-Object { $_.Domain -eq 'www.argumentum.games' -and $_.Verdict -eq 'PASS' }).Count -eq 1
  $okNegative = @($rows | Where-Object { $_.Domain -eq 'myia.org' -and $_.Verdict -eq 'FAIL' -and $_.Why -match 'catch-all' }).Count -eq 1

  # Controle CERT (synthetique) : le sujet du certificat DOIT entrer dans le
  # verdict - tout passe sauf le sujet, et le sujet ne couvre pas le domaine.
  $synthHosts = @($script:DomainTable.Keys)
  $vCertBad  = Get-RecetteVerdict -Http80 '200' -Https443 '200' -CertSubject 'CN=intrus.example.net' -CertExpect 'argumentum' -HasExpect $true -Expect 'Argumentum' -HitForbidden '' -FinalUrl 'https://www.argumentum.games/' -AllowedHosts $synthHosts -FollowErr ''
  $vCertGood = Get-RecetteVerdict -Http80 '200' -Https443 '200' -CertSubject 'CN=www.argumentum.games' -CertExpect 'argumentum' -HasExpect $true -Expect 'Argumentum' -HitForbidden '' -FinalUrl 'https://www.argumentum.games/' -AllowedHosts $synthHosts -FollowErr ''
  $okCert = ($vCertBad.Verdict -eq 'FAIL' -and $vCertBad.Why -match 'certificat') -and ($vCertGood.Verdict -eq 'PASS')

  # Controle REDIRECTION (synthetique) : URL finale hors table doit ECHOUER.
  $vRedir = Get-RecetteVerdict -Http80 '200' -Https443 '200' -CertSubject 'CN=www.argumentum.games' -CertExpect 'argumentum' -HasExpect $true -Expect 'Argumentum' -HitForbidden '' -FinalUrl 'https://login.microsoftonline.com/' -AllowedHosts $synthHosts -FollowErr ''
  $okRedir = ($vRedir.Verdict -eq 'FAIL' -and $vRedir.Why -match 'hors perimetre')

  Write-Output ("  controle POSITIF (site reel doit PASSER)        : " + $(if ($okPositive) { 'OK' } else { 'ECHEC' }))
  Write-Output ("  controle NEGATIF (catch-all doit ECHOUER)       : " + $(if ($okNegative) { 'OK' } else { 'ECHEC' }))
  Write-Output ("  controle CERTIFICAT (mauvais sujet => ECHEC)    : " + $(if ($okCert) { 'OK' } else { 'ECHEC' }))
  Write-Output ("  controle REDIRECTION (hors perimetre => ECHEC)  : " + $(if ($okRedir) { 'OK' } else { 'ECHEC' }))

  if ($okPositive -and $okNegative -and $okCert -and $okRedir) {
    Write-Output 'RESULTAT: le harnais discrimine dans tous les axes.'
    exit 0
  }
  Write-Output 'RESULTAT: le harnais NE discrimine PAS sur un axe - ne pas s''en servir comme gate.'
  exit 1
}

# ---------------------------------------------------------------------------
# Mode recette
# ---------------------------------------------------------------------------
if (-not $Domains) { $Domains = $script:DefaultDomains }
$unknown = $Domains | Where-Object { -not $script:DomainTable.Contains($_) }
if ($unknown) {
  Write-Error ("Domaine(s) inconnu(s) de la table : " + ($unknown -join ', '))
  exit 2
}

Write-Output "=== Recette de bascule - cible $TargetIp (le DNS public n'est pas touche) ==="
$rows = Invoke-Recette -Ip $TargetIp -DomainList $Domains
$rows | Format-Table Domain, Http80, Https443, Cert, FinalUrl, Verdict, Why -AutoSize | Out-String | Write-Output

$failed = @($rows | Where-Object { $_.Verdict -ne 'PASS' })
Write-Output ("Bilan : " + (@($rows).Count - @($failed).Count) + '/' + @($rows).Count + ' domaine(s) pret(s).')
if (@($failed).Count -gt 0) {
  Write-Output 'RESULTAT: gate de recette ROUGE - ne pas basculer le DNS de ces domaines.'
  exit 1
}
Write-Output 'RESULTAT: gate de recette VERTE pour ce perimetre.'
exit 0

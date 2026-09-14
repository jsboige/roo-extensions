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

.PARAMETER TargetIp
  IP de la machine cible. Defaut : VPS-4 2027 (51.75.200.22).

.PARAMETER ControlIp
  IP de la machine source, utilisee comme controle positif par -SelfTest.
  Defaut : web1 actuelle (37.187.180.135).

.PARAMETER Domains
  Sous-ensemble de domaines a recetter. Defaut : la famille Argumentum, perimetre
  de la Phase 1. Domaines disponibles : les cles de $script:DomainTable.

.PARAMETER SelfTest
  Verifie que le harnais DISCRIMINE avant de s'en servir : contre ControlIp,
  www.argumentum.games doit PASSER (site reel) et myia.org doit ECHOUER sur le
  contenu (catch-all). Sort 1 si le harnais ne discrimine pas - un harnais qui
  dit PASS partout ne prouve rien.

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
  Lecture seule : aucune ecriture, aucun changement DNS, aucun acces distant.
  Epic #3188, Phase 1. Compatible Windows PowerShell 5.1.
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
$script:DomainTable = [ordered]@{
  'www.argumentum.games' = @{ Expect = 'Argumentum'; Role = 'prod DNN' }
  'argumentum.games'     = @{ Expect = 'Argumentum'; Role = 'prod DNN (apex)' }
  'argumentum.fr'        = @{ Expect = 'Argumentum'; Role = 'portail/redirection' }
  'myia.org'             = @{ Expect = 'myia';       Role = 'Phase 2 - vitrine' }
  'www.myia.org'         = @{ Expect = 'myia';       Role = 'Phase 2 - vitrine' }
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

function Test-DomainOnIp {
  param(
    [Parameter(Mandatory)][string] $Domain,
    [Parameter(Mandatory)][string] $Ip,
    [Parameter(Mandatory)][string] $Expect
  )

  $res = [ordered]@{
    Domain = $Domain
    Http80 = '000'
    Https443 = '000'
    Cert = 'aucun'
    Verdict = 'FAIL'
    Why = ''
  }

  $argCommon = @('--connect-timeout', '6', '--max-time', '12', '--resolve')

  # 1. HTTP :80
  $raw = & curl.exe -s -o NUL -w '%{http_code}' @argCommon "${Domain}:80:${Ip}" "http://${Domain}/" 2>$null
  if ($raw) { $res.Http80 = ([string]$raw).Trim() }

  # 2. HTTPS :443
  $raw = & curl.exe -s -k -o NUL -w '%{http_code}' @argCommon "${Domain}:443:${Ip}" "https://${Domain}/" 2>$null
  if ($raw) { $res.Https443 = ([string]$raw).Trim() }

  # 3. Certificat presente sur :443 (sujet + chaine)
  $verbose = (& curl.exe -v -k -o NUL @argCommon "${Domain}:443:${Ip}" "https://${Domain}/" 2>&1 | Out-String)
  $m = [regex]::Match($verbose, 'subject:\s*(.+)')
  if ($m.Success) { $res.Cert = $m.Groups[1].Value.Trim() }

  # 4. Contenu : marqueur attendu present, marqueur de catch-all absent
  $body = ''
  if ($res.Https443 -match '^(200|301|302)$') {
    $body = (& curl.exe -s -k -L @argCommon "${Domain}:443:${Ip}" "https://${Domain}/" 2>$null | Out-String)
  } elseif ($res.Http80 -match '^(200|301|302)$') {
    $body = (& curl.exe -s -L @argCommon "${Domain}:80:${Ip}" "http://${Domain}/" 2>$null | Out-String)
  }

  $hitForbidden = ''
  foreach ($f in $script:ForbiddenMarkers) {
    if ($body.IndexOf($f, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hitForbidden = $f; break }
  }
  $hasExpect = ($body.IndexOf($Expect, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)

  # Verdict : un 200 ne suffit pas.
  $why = New-Object System.Collections.ArrayList
  if ($res.Http80    -notmatch '^(200|301|302)$') { [void]$why.Add("http80=$($res.Http80)") }
  if ($res.Https443  -notmatch '^(200|301|302)$') { [void]$why.Add("https443=$($res.Https443)") }
  if ($hitForbidden)                              { [void]$why.Add("catch-all ('$hitForbidden')") }
  if (-not $hasExpect)                            { [void]$why.Add("marqueur '$Expect' absent") }

  if ($why.Count -eq 0) { $res.Verdict = 'PASS' } else { $res.Why = ($why -join '; ') }

  return [pscustomobject]$res
}

function Invoke-Recette {
  param([string]$Ip, [string[]]$DomainList)

  $rows = foreach ($d in $DomainList) {
    $expect = $script:DomainTable[$d].Expect
    Test-DomainOnIp -Domain $d -Ip $Ip -Expect $expect
  }
  return @($rows)
}

# ---------------------------------------------------------------------------
# Mode SelfTest : prouver la discrimination avant de servir de gate.
# ---------------------------------------------------------------------------
if ($SelfTest) {
  Write-Output "=== SELFTEST - le harnais discrimine-t-il ? (contre $ControlIp) ==="
  $rows = Invoke-Recette -Ip $ControlIp -DomainList @('www.argumentum.games', 'myia.org')
  $rows | Format-Table Domain, Http80, Https443, Verdict, Why -AutoSize | Out-String | Write-Output

  # @() obligatoire : sous PS 5.1, .Count sur un objet unique rend $null (pas 1),
  # et un objet unique (et non un tableau) n'expose pas .Count de facon fiable.
  $okPositive = @($rows | Where-Object { $_.Domain -eq 'www.argumentum.games' -and $_.Verdict -eq 'PASS' }).Count -eq 1
  $okNegative = @($rows | Where-Object { $_.Domain -eq 'myia.org' -and $_.Verdict -eq 'FAIL' -and $_.Why -match 'catch-all' }).Count -eq 1

  Write-Output ("  controle POSITIF (site reel doit PASSER)      : " + $(if ($okPositive) { 'OK' } else { 'ECHEC' }))
  Write-Output ("  controle NEGATIF (catch-all doit ECHOUER)     : " + $(if ($okNegative) { 'OK' } else { 'ECHEC' }))

  if ($okPositive -and $okNegative) {
    Write-Output 'RESULTAT: le harnais discrimine dans les deux sens.'
    exit 0
  }
  Write-Output 'RESULTAT: le harnais NE discrimine PAS - ne pas s''en servir comme gate.'
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
$rows | Format-Table Domain, Http80, Https443, Cert, Verdict, Why -AutoSize | Out-String | Write-Output

$failed = @($rows | Where-Object { $_.Verdict -ne 'PASS' })
Write-Output ("Bilan : " + ($rows.Count - $failed.Count) + '/' + $rows.Count + ' domaine(s) pret(s).')
if ($failed.Count -gt 0) {
  Write-Output 'RESULTAT: gate de recette ROUGE - ne pas basculer le DNS de ces domaines.'
  exit 1
}
Write-Output 'RESULTAT: gate de recette VERTE pour ce perimetre.'
exit 0

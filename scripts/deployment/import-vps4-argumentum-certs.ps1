#Requires -Version 5.1
<#
.SYNOPSIS
  Import des PFX Argumentum + bindings 443 SNI sur VPS-4 2027 (Epic #3188, Phase 1).

.DESCRIPTION
  Execute le pas "certificats + bindings" du runbook de provisionnement
  (docs/harness/machine-specific/vps4-2027-provisioning-runbook.md, sections 6-7) :
  les PFX ont ete emis SUR web1 via win-acme (cle exportable, c.485) car le cert
  prod games est a cle non exportable — la strategie est import AVANT bascule DNS,
  renouvellement wacs CIBLE apres bascule.

  A executer SUR LA CIBLE (51.75.200.22) au prochain creneau admin (RDP).
  Etat mesuré web1 27/09 : 80 ouvert seul, 443 ferme = PFX non installes.

  Regles du runbook respectees : un binding explicite PAR DOMAINE (80 + 443, SNI,
  host header), jamais de binding *:443 sans host name (catch-all interdit).

.PARAMETER PfxDir
  Repertoire contenant les PFX. Defaut : staging web1.

.PARAMETER PasswordFile
  Fichier texte contenant le mot de passe PFX (une ligne). Defaut : pfx-password.txt
  dans PfxDir. Jamais de mot de passe en clair dans ce script ni en argument.

.PARAMETER SiteName
  Nom du site IIS cible. Defaut : Argumentum.

.PARAMETER Plan
  Dry-run : affiche ce qui serait importe/lie sans rien ecrire.

.EXAMPLE
  # Ce que le script fera, sans rien toucher :
  .\import-vps4-argumentum-certs.ps1 -Plan

  # Execution (creneau RDP sur la cible) :
  .\import-vps4-argumentum-certs.ps1 -PfxDir C:\staging-vps4\certs -PasswordFile C:\staging-vps4\pfx-password.txt

  # Recette froide APRES ce script (DNS intact) :
  .\test-vps4-cutover-recette.ps1 -SelfTest
  .\test-vps4-cutover-recette.ps1
#>
[CmdletBinding()]
param(
    [string]$PfxDir = 'C:\myia-web1\Hosting\staging-vps4\certs',
    [string]$PasswordFile,
    [string]$SiteName = 'Argumentum',
    [switch]$Plan
)

$ErrorActionPreference = 'Stop'

# Domaine -> PFX (www.argumentum.games.pfx couvre www + apex : SAN)
$DomainMap = [ordered]@{
    'www.argumentum.games' = 'www.argumentum.games.pfx'
    'argumentum.games'     = 'www.argumentum.games.pfx'
    'argumentum.fr'        = 'argumentum.fr.pfx'
}

if (-not (Test-Path $PfxDir)) {
    throw "PfxDir introuvable : $PfxDir (sur la cible, indiquer le repertoire de transfert)"
}
if (-not $PasswordFile) { $PasswordFile = Join-Path (Split-Path $PfxDir -Parent) 'pfx-password.txt' }
if (-not (Test-Path $PasswordFile)) {
    throw "PasswordFile introuvable : $PasswordFile"
}

Import-Module WebAdministration

$plain = (Get-Content $PasswordFile -Raw).Trim()
if (-not $plain) { throw 'PasswordFile vide' }
$secure = ConvertTo-SecureString -String $plain -AsPlainText -Force
$actions = @()

function Find-ExistingCert {
    param([string]$Domain)
    Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Where-Object {
        $_.NotAfter -gt (Get-Date) -and (
            $_.DnsNameList.Unicode -contains $Domain -or
            $_.Subject -like "CN=$Domain*"
        )
    } | Select-Object -First 1
}

$certByDomain = @{}
foreach ($domain in $DomainMap.Keys) {
    $pfxName = $DomainMap[$domain]
    $pfxPath = Join-Path $PfxDir $pfxName
    if (-not (Test-Path $pfxPath)) { throw "PFX manquant : $pfxPath" }

    $existing = Find-ExistingCert -Domain $domain
    if ($existing) {
        $actions += "[SKIP import] $domain : cert deja present (thumbprint $($existing.Thumbprint), expire $($existing.NotAfter.ToString('yyyy-MM-dd')))"
        $certByDomain[$domain] = $existing
        continue
    }
    if ($Plan) {
        $actions += "[PLAN import] $domain <- $pfxName"
        $certByDomain[$domain] = $null
    } else {
        $imported = Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\My -Password $secure -Exportable
        $actions += "[DONE import] $domain : thumbprint $($imported.Thumbprint), expire $($imported.NotAfter.ToString('yyyy-MM-dd'))"
        $certByDomain[$domain] = $imported
    }
}

Write-Host '--- Etat bindings https avant ---'
Get-WebBinding -Name $SiteName | Where-Object { $_.protocol -eq 'https' } | ForEach-Object { Write-Host "  $($_.bindingInformation)" }
if (-not (Get-WebBinding -Name $SiteName | Where-Object { $_.protocol -eq 'https' })) { Write-Host '  (aucun)' }

foreach ($domain in $DomainMap.Keys) {
    $bindingInfo = "*:443:$domain"
    $already = Get-WebBinding -Name $SiteName | Where-Object { $_.bindingInformation -eq $bindingInfo }
    if ($already) {
        $actions += "[SKIP binding] $domain : *:443:$domain existe deja"
        continue
    }
    if ($Plan) {
        $actions += "[PLAN binding] $domain : *:443:$domain (SNI) + association cert"
        continue
    }
    New-WebBinding -Name $SiteName -Protocol https -Port 443 -HostHeader $domain -SslFlags 1
    $cert = $certByDomain[$domain]
    $sslPath = "IIS:\SslBindings\0.0.0.0!443!$domain"
    if ($cert -and -not (Get-Item $sslPath -ErrorAction SilentlyContinue)) {
        $cert | New-Item $sslPath | Out-Null
    }
    $actions += "[DONE binding] $domain : *:443:$domain (SNI) -> cert $($cert.Thumbprint)"
}

Write-Host ''
Write-Host '--- Actions ---'
$actions | ForEach-Object { Write-Host "  $_" }

Write-Host ''
if ($Plan) {
    Write-Host 'PLAN SEUL - aucune ecriture. Reexecuter sans -Plan pour appliquer.' -ForegroundColor Yellow
} else {
    Write-Host '--- Etat bindings https apres ---'
    Get-WebBinding -Name $SiteName | Where-Object { $_.protocol -eq 'https' } | ForEach-Object { Write-Host "  $($_.bindingInformation)" }
    Write-Host ''
    Write-Host 'Pas suivant : recette froide (DNS intact), depuis scripts/testing/harness :'
    Write-Host '  .\test-vps4-cutover-recette.ps1 -SelfTest   # le harnais discrimine'
    Write-Host '  .\test-vps4-cutover-recette.ps1             # recette famille Argumentum (curl --resolve)'
}

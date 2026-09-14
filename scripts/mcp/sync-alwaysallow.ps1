<#
.SYNOPSIS
    Synchronise les alwaysAllow MCP depuis une configuration de reference

.DESCRIPTION
    Ce script lit la configuration de reference et met a jour le fichier
    mcp_settings.json de l'extension ACTIVE pour auto-approuver tous les outils listes.

    La cible est resolue via Get-ActiveMcpSettingsPath (#3135), pas epinglee sur
    Roo : sur un poste migre vers Zoo, le globalStorage roo-cline survit comme une
    coquille vide et un chemin code en dur reussissait contre une copie inactive
    sans jamais toucher la configuration effectivement chargee (#3639).

.PARAMETER ReferencePath
    Chemin vers le fichier de reference JSON (defaut: roo-config/mcp/reference-alwaysallow.json)

.PARAMETER Backup
    Creer une sauvegarde avant modification (defaut: true)

.PARAMETER DryRun
    Simuler les changements sans modifier les fichiers

.EXAMPLE
    .\sync-alwaysallow.ps1
    .\sync-alwaysallow.ps1 -DryRun
    .\sync-alwaysallow.ps1 -ReferencePath "custom-reference.json"

.NOTES
    Issue #496: Auto-approbation complete des outils Roo
    Issue #3639: resolution de l'extension active + verification post-ecriture

    Codes de sortie:
      0 = succes (ou dry-run)
      1 = reference introuvable ou illisible
      2 = extension active indeterminable (refus explicite, aucune ecriture)
      3 = verification post-ecriture en echec sur la configuration active
#>

param(
    [string]$ReferencePath = "$PSScriptRoot\..\..\roo-config\mcp\reference-alwaysallow.json",
    # #3639: [switch], not [bool]. A [bool] parameter is unreachable from the
    # command line -- `-DryRun` is rejected as a missing argument, and `-DryRun 1`
    # arrives as a String that the binder refuses. The .EXAMPLE above documents
    # `.\sync-alwaysallow.ps1 -DryRun`, which simply failed, and -Backup could not
    # be turned off at all. The sibling roo-config/scripts/Sync-AlwaysAllow.ps1
    # already exposed both as switches; no caller was affected (git grep: none).
    [switch]$Backup = $true,
    [switch]$DryRun
)

# Chemins portables (Path.Combine) : Join-Path multi-args est PS 6.2+ et les
# separateurs en dur ne survivent pas a un runner Linux.
. ([System.IO.Path]::Combine($PSScriptRoot, '..', 'common', 'extension-paths.ps1'))
. ([System.IO.Path]::Combine($PSScriptRoot, '..', 'common', 'alwaysallow-sync.ps1'))

$ErrorActionPreference = "Stop"

# #3639: cible = configuration MCP de l'extension ACTIVE.
$ActiveExtension = Get-ActiveExtension
$SettingsPath    = Get-ActiveMcpSettingsPath

Write-Host "=== Sync AlwaysAllow MCP ===" -ForegroundColor Cyan
Write-Host "Extension active: $ActiveExtension"
Write-Host "Reference: $ReferencePath"
Write-Host "Cible (active): $SettingsPath"
Write-Host "Backup: $Backup"
Write-Host "DryRun: $DryRun"
Write-Host ""

# Verifier que les fichiers existent
if (-not (Test-Path -LiteralPath $ReferencePath)) {
    Write-Error "Fichier de reference non trouve: $ReferencePath"
    exit 1
}

# #3639: refus explicite plutot que devinette. Get-ActiveExtension retombe sur
# RooCode quand aucun candidat n'a de mcp_settings.json ; ecrire la creerait une
# configuration pour une extension absente -- exactement la derive visee ici.
if (-not (Test-Path -LiteralPath $SettingsPath)) {
    Write-Host "REFUSED: extension active indeterminable -- aucune ecriture." -ForegroundColor Red
    Write-Host "  teste Roo: $(Get-McpSettingsPath -Extension RooCode)"
    Write-Host "  teste Zoo: $(Get-McpSettingsPath -Extension ZooCode)"
    Write-Host "  Aucun des deux ne porte de mcp_settings.json."
    exit 2
}

# Charger les configurations
$reference = Get-Content -LiteralPath $ReferencePath -Raw | ConvertFrom-Json
$settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json

# Statistiques
$totalAdded = 0
$totalRemoved = 0
$serversProcessed = 0
$changes = @()
# Liste attendue sur disque apres ecriture, par serveur (pour la verification).
$expected = @{}

# Parcourir chaque serveur dans la reference
foreach ($serverName in $reference.mcpServers.PSObject.Properties.Name) {
    $refTools = @($reference.mcpServers.$serverName.alwaysAllow | Where-Object { $_ -ne $null })

    # Verifier si le serveur existe dans les settings actuels
    if (-not $settings.mcpServers.$serverName) {
        Write-Host "  [SKIP] $serverName - non installe sur cette machine" -ForegroundColor DarkGray
        continue
    }

    $currentTools = @($settings.mcpServers.$serverName.alwaysAllow | Where-Object { $_ -ne $null })

    # Calculer les differences (set, pas ordre -- cf. scripts/common/alwaysallow-sync.ps1)
    $delta = Get-AlwaysAllowDelta -ReferenceTools $refTools -CurrentTools $currentTools

    if ($delta.Added.Count -eq 0 -and $delta.Removed.Count -eq 0) {
        Write-Host "  [OK] $serverName - $($currentTools.Count) outils (aucun changement)" -ForegroundColor Green
        continue
    }

    $serversProcessed++
    $totalAdded += $delta.Added.Count
    $totalRemoved += $delta.Removed.Count

    $changeInfo = @{
        Server = $serverName
        Added = $delta.Added
        Removed = $delta.Removed
        Before = $currentTools.Count
        After = $refTools.Count
    }
    $changes += $changeInfo

    Write-Host "  [$serverName] $($currentTools.Count) -> $($refTools.Count) outils" -ForegroundColor Yellow
    if ($delta.Added.Count -gt 0) {
        Write-Host "    + Ajoutes: $($delta.Added -join ', ')" -ForegroundColor Green
    }
    if ($delta.Removed.Count -gt 0) {
        Write-Host "    - Retires: $($delta.Removed -join ', ')" -ForegroundColor Red
    }

    # Etat attendu de la configuration active une fois ecrite.
    $expected[$serverName] = @($refTools)

    # Appliquer les changements si pas DryRun
    if (-not $DryRun) {
        $settings.mcpServers.$serverName.alwaysAllow = $refTools
    }
}

Write-Host ""
Write-Host "=== Resume ===" -ForegroundColor Cyan
Write-Host "Serveurs modifies: $serversProcessed"
Write-Host "Outils ajoutes: $totalAdded"
Write-Host "Outils retires: $totalRemoved"

if ($DryRun) {
    Write-Host ""
    Write-Host "*** MODE DRYRUN - Aucun changement applique ***" -ForegroundColor Magenta
    exit 0
}

if ($serversProcessed -eq 0) {
    Write-Host ""
    Write-Host "Aucun changement necessaire - configuration deja a jour." -ForegroundColor Green
    exit 0
}

# Backup si demande
if ($Backup) {
    $backupPath = "$SettingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $SettingsPath -Destination $backupPath
    Write-Host "Backup cree: $backupPath" -ForegroundColor DarkGray
}

# Sauvegarder les changements
# FIX #664: Utiliser WriteAllText pour éviter BOM UTF-8 (Set-Content -Encoding UTF8 ajoute BOM en PS 5.1)
$jsonOutput = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($SettingsPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))
Write-Host ""
Write-Host "Settings mis a jour avec succes!" -ForegroundColor Green

# #3639 point 5: relire la configuration EFFECTIVEMENT ACTIVE, depuis le disque.
# Re-resoudre d'abord (la cible a-t-elle bouge pendant l'ecriture ?), puis relire
# le fichier -- l'objet en memoire ne prouve rien sur ce qui est charge.
$activeAfter = Get-ActiveMcpSettingsPath
if (-not [string]::Equals($activeAfter, $SettingsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "ERROR: la cible active a change pendant le sync (avant: $SettingsPath, apres: $activeAfter)" -ForegroundColor Red
    exit 3
}

$verif = Test-AlwaysAllowApplied -SettingsPath $activeAfter -Expected $expected
if (-not $verif.Ok) {
    Write-Host "ERROR: POST-WRITE VERIFICATION FAILED on the ACTIVE configuration ($activeAfter):" -ForegroundColor Red
    foreach ($mismatch in $verif.Mismatches) {
        Write-Host "  $mismatch" -ForegroundColor Red
    }
    exit 3
}
Write-Host "POST-WRITE VERIFICATION OK ($($verif.Checked) serveur(s) relus depuis $activeAfter)" -ForegroundColor Green

Write-Host "Redemarrez VS Code pour appliquer les changements." -ForegroundColor Yellow

<#
.SYNOPSIS
    Initialise la gestion de l'encodage pour la session PowerShell courante.
.DESCRIPTION
    Ce script configure l'encodage de la console et des sorties pour garantir
    un support UTF-8 complet. Il est conçu pour être appelé depuis les profils
    PowerShell (Microsoft.PowerShell_profile.ps1).
.NOTES
    Auteur: Roo Architect
    Date: 2025-10-30
    Version: 1.0
#>

# Configuration de l'encodage de la console en UTF-8 (CodePage 65001)
if ([Console]::OutputEncoding.CodePage -ne 65001) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
}

if ([Console]::InputEncoding.CodePage -ne 65001) {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
}

# Configuration de l'encodage de sortie par défaut selon la version de PowerShell
if ($PSVersionTable.PSVersion.Major -ge 6) {
    # PowerShell Core (6+) utilise UTF-8 sans BOM par défaut, mais on s'assure
    $OutputEncoding = [System.Text.Encoding]::UTF8
} else {
    # Windows PowerShell (5.1) nécessite une configuration explicite
    # Utilisation de UTF-8 avec BOM pour compatibilité maximale avec certains outils Windows
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

# Configuration des préférences
$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"
$VerbosePreference = "SilentlyContinue"
$DebugPreference = "SilentlyContinue"

# Définition des variables d'environnement pour les outils externes si non définies
if (-not $env:PYTHONIOENCODING) { $env:PYTHONIOENCODING = "utf-8" }
if (-not $env:LANG) { $env:LANG = "fr_FR.UTF-8" }
if (-not $env:LC_ALL) { $env:LC_ALL = "fr_FR.UTF-8" }

# Message de confirmation (uniquement si verbose)
Write-Verbose "EncodingManager: Session initialisée en UTF-8 (CP65001)"
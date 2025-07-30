# sync-manager.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Pull', 'Push', 'Status', 'Resolve', 'Configure')]
    [string]$Action,

    [string]$Repository,
    [string]$Message,
    [switch]$Detailed,
    [string]$Strategy
)

Import-Module "$PSScriptRoot\modules\Dashboard.psm1" -Force
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$PSScriptRoot\modules\Core.psm1" -Force
Import-Module "$PSScriptRoot\modules\Configuration.psm1" -Force
Import-Module "$PSScriptRoot\modules\Dashboard.psm1" -Force

try {
    Invoke-SyncManager -SyncAction $Action -Parameters $PSBoundParameters
}
catch {
    # Gestion d'erreur basique pour le moment
    Write-Error "Une erreur critique est survenue: $_"
    exit 1
}
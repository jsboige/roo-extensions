[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ModulePath
)

$nodeModulesPath = Join-Path -Path $ModulePath -ChildPath 'node_modules'
$packageLockPath = Join-Path -Path $ModulePath -ChildPath 'package-lock.json'

if (Test-Path -Path $nodeModulesPath -PathType Container) {
    Write-Host "Suppression de $nodeModulesPath..."
    Remove-Item -Recurse -Force -Path $nodeModulesPath
}

if (Test-Path -Path $packageLockPath -PathType Leaf) {
    Write-Host "Suppression de $packageLockPath..."
    Remove-Item -Force -Path $packageLockPath
}

Write-Host "Nettoyage du cache npm..."
npm cache clean --force

Write-Host "Nettoyage terminé."
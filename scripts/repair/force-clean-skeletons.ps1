[CmdletBinding()]
param()

# Détecter le chemin de stockage Roo
$storagePath = Join-Path $env:APPDATA 'Code\User\globalStorage\rooveterinaryinc.roo-cline'
$skeletonsPath = Join-Path $storagePath '.skeletons'

if (Test-Path -Path $skeletonsPath -PathType Container) {
    Write-Host "Suppression du répertoire des squelettes : $skeletonsPath"
    Remove-Item -Recurse -Force -Path $skeletonsPath
    Write-Host "Répertoire des squelettes supprimé."
} else {
    Write-Host "Le répertoire des squelettes n'a pas été trouvé. Aucune action n'est nécessaire."
}
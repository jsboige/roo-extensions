# Script pour installer les dépendances npm dans tous les sous-projets de mcps/internal/servers

$ErrorActionPreference = "Stop"

try {
    $baseDir = $PSScriptRoot
    $serversPath = Join-Path $baseDir "mcps/internal/servers"

    if (-not (Test-Path $serversPath)) {
        throw "Le répertoire des serveurs n'a pas été trouvé à l'emplacement attendu: $serversPath"
    }

    $serverDirs = Get-ChildItem -Path $serversPath -Directory

    if ($serverDirs.Count -eq 0) {
        Write-Warning "Aucun répertoire de serveur trouvé dans $serversPath."
    } else {
        foreach ($dir in $serverDirs) {
            $packageJsonPath = Join-Path $dir.FullName "package.json"
            if (Test-Path $packageJsonPath) {
                Write-Host "--- Début de l'installation des dépendances pour $($dir.Name) ---"
                Set-Location -Path $dir.FullName
                
                # Exécution de npm install. La sortie sera affichée dans le terminal.
                npm install
                
                Write-Host "--- Fin de l'installation pour $($dir.Name) ---"
            } else {
                Write-Host "--- Projet $($dir.Name) ignoré (pas de package.json) ---"
            }
        }
    }
    
    Write-Host "`nInstallation des dépendances terminée pour tous les projets."

} catch {
    Write-Error "Une erreur est survenue: $_"
    exit 1
} finally {
    # Revenir au répertoire de départ
    Set-Location -Path $baseDir
}
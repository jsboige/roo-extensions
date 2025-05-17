# Script pour forcer le déploiement avec correction d'encodage
param (
    [Parameter(Mandatory=$false)]
    [switch]$Force = $true
)

Write-Host "==========================================================="
Write-Host "   Déploiement forcé des modes avec correction d'encodage"
Write-Host "==========================================================="

# Chemin du script de déploiement
$deployScript = Join-Path $PSScriptRoot "deploy-modes-simple-complex.ps1"

# Vérifier si le script de déploiement existe
if (-not (Test-Path $deployScript)) {
    Write-Host "Erreur : Le script de déploiement $deployScript n'existe pas."
    exit 1
}

# Exécuter le script de déploiement avec l'option -Force
Write-Host "Exécution du script de déploiement avec l'option -Force..."
& $deployScript -Force

# Vérifier le résultat du déploiement
$destinationPath = "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"

Write-Host "Vérification du fichier déployé..."
if (Test-Path $destinationPath) {
    Write-Host "Le fichier a été déployé avec succès à l'emplacement : $destinationPath"
    
    # Vérifier l'encodage du fichier
    $bytes = [System.IO.File]::ReadAllBytes($destinationPath)
    $hasBOM = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    
    if ($hasBOM) {
        Write-Host "Encodage du fichier : UTF-8 with BOM"
    } else {
        Write-Host "Encodage du fichier : UTF-8 without BOM (ou autre encodage sans BOM)"
    }
    
    # Vérifier si le fichier contient du JSON valide
    try {
        $content = Get-Content -Path $destinationPath -Raw
        $json = ConvertFrom-Json $content
        Write-Host "Le fichier contient du JSON valide."
        
        # Vérifier quelques valeurs pour s'assurer que l'encodage est correct
        if ($json.customModes) {
            Write-Host "Nombre de modes personnalisés : $($json.customModes.Count)"
        }
    } catch {
        Write-Host "Erreur lors de la validation du JSON : $_"
    }
} else {
    Write-Host "Erreur : Le fichier n'a pas été déployé à l'emplacement attendu."
}

Write-Host "==========================================================="
Write-Host "   Déploiement terminé"
Write-Host "==========================================================="

Write-Host "Pour activer les modes, redémarrez Visual Studio Code et utilisez la commande 'Roo: Switch Mode'."
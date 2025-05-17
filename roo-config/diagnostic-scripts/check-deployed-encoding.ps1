# Script pour vérifier l'encodage du fichier déployé
$destinationPath = "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"

Write-Host "==========================================================="
Write-Host "   Vérification de l'encodage du fichier déployé"
Write-Host "==========================================================="

if (Test-Path $destinationPath) {
    Write-Host "Le fichier existe à l'emplacement : $destinationPath"
    
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
            
            # Afficher les noms des modes pour vérifier l'encodage des caractères spéciaux
            Write-Host "Noms des modes :"
            foreach ($mode in $json.customModes) {
                Write-Host "- $($mode.name)"
            }
        }
    } catch {
        Write-Host "Erreur lors de la validation du JSON : $_"
    }
} else {
    Write-Host "Le fichier n'existe pas à l'emplacement : $destinationPath"
}

Write-Host "==========================================================="
# Script pour vérifier les modes déployés
param (
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"
)

Write-Host "==========================================================="
Write-Host "   Vérification des modes déployés"
Write-Host "==========================================================="

if (Test-Path $DestinationPath) {
    Write-Host "Le fichier existe à l'emplacement : $DestinationPath"
    
    # Vérifier l'encodage du fichier
    $bytes = [System.IO.File]::ReadAllBytes($DestinationPath)
    $hasBOM = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    
    if ($hasBOM) {
        Write-Host "Encodage du fichier : UTF-8 with BOM"
    } else {
        Write-Host "Encodage du fichier : UTF-8 without BOM (ou autre encodage sans BOM)"
    }
    
    # Vérifier si le fichier contient du JSON valide
    try {
        $content = Get-Content -Path $DestinationPath -Raw
        $json = ConvertFrom-Json $content
        Write-Host "Le fichier contient du JSON valide."
        
        # Vérifier les modes personnalisés
        if ($json.customModes) {
            Write-Host "Nombre de modes personnalisés : $($json.customModes.Count)"
            
            # Afficher les noms et slugs des modes
            Write-Host "Liste des modes :"
            foreach ($mode in $json.customModes) {
                Write-Host "- Slug: $($mode.slug), Nom: $($mode.name)"
            }
            
            # Vérifier si les noms des modes contiennent des caractères mal encodés
            $containsEncodingIssues = $false
            foreach ($mode in $json.customModes) {
                if ($mode.name -match "Ã©|Ã¨|Ã°Å¸|ÃƒÂ°") {
                    $containsEncodingIssues = $true
                    Write-Host "Problème d'encodage détecté dans le nom du mode : $($mode.slug)"
                }
            }
            
            if ($containsEncodingIssues) {
                Write-Host "Des problèmes d'encodage ont été détectés dans les noms des modes."
            } else {
                Write-Host "Aucun problème d'encodage n'a été détecté dans les noms des modes."
            }
        } else {
            Write-Host "Aucun mode personnalisé n'a été trouvé dans le fichier."
        }
    } catch {
        Write-Host "Erreur lors de la validation du JSON : $_"
    }
} else {
    Write-Host "Le fichier n'existe pas à l'emplacement : $DestinationPath"
}

Write-Host "==========================================================="
Write-Host "   Recommandations"
Write-Host "==========================================================="
Write-Host "1. Redémarrez Visual Studio Code"
Write-Host "2. Ouvrez la palette de commandes (Ctrl+Shift+P)"
Write-Host "3. Tapez 'Roo: Switch Mode' et vérifiez si les noms des modes sont correctement affichés"
Write-Host "4. Si les noms des modes ne sont pas correctement affichés, essayez de réinstaller l'extension Roo"
Write-Host "==========================================================="
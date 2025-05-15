# Script de correction d'encodage pour les fichiers de configuration Roo
# Ce script corrige les problèmes d'encodage dans les fichiers de configuration

param (
    [Parameter(Mandatory = $false)]
    [string]$Path = ".",
    
    [Parameter(Mandatory = $false)]
    [switch]$Recursive,
    
    [Parameter(Mandatory = $false)]
    [string[]]$FilePatterns = @("*.json", "*.md", "*.txt"),
    
    [Parameter(Mandatory = $false)]
    [switch]$Backup,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Correction d'encodage pour les fichiers de configuration Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Obtenir la liste des fichiers à analyser
$files = @()
if ($Recursive) {
    $files = Get-ChildItem -Path $Path -Recurse -File -Include $FilePatterns
} else {
    $files = Get-ChildItem -Path $Path -File -Include $FilePatterns
}

Write-ColorOutput "`nTraitement de $($files.Count) fichiers..." "Yellow"

# Traiter chaque fichier
$correctedFiles = 0

foreach ($file in $files) {
    Write-ColorOutput "`nTraitement du fichier: $($file.FullName)" "White"
    
    # Créer une sauvegarde si demandé
    if ($Backup) {
        $backupPath = "$($file.FullName).bak"
        Copy-Item -Path $file.FullName -Destination $backupPath -Force
        Write-ColorOutput "Sauvegarde créée: $backupPath" "Yellow"
    }
    
    try {
        # Lire le contenu du fichier
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $hasBOM = $false
        
        # Vérifier si le fichier a un BOM UTF-8
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $hasBOM = $true
            Write-ColorOutput "Le fichier a un BOM UTF-8" "Yellow"
        }
        
        # Lire le contenu avec l'encodage approprié
        $content = Get-Content -Path $file.FullName -Raw
        
        # Écrire le contenu en UTF-8 sans BOM
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($false))
        
        Write-ColorOutput "Fichier converti en UTF-8 sans BOM" "Green"
        $correctedFiles++
    } catch {
        Write-ColorOutput "Erreur lors du traitement du fichier: $($_.Exception.Message)" "Red"
    }
}

# Afficher le résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Résumé de la correction" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

Write-ColorOutput "`n$correctedFiles fichiers ont été convertis en UTF-8 sans BOM." "Green"

Write-ColorOutput "`nPour plus d'informations sur les problèmes d'encodage, consultez le fichier docs/guide-encodage.md" "White"
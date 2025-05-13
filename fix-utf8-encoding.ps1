# Script pour corriger l'encodage des fichiers en UTF-8 sans BOM
function Fix-FileEncoding {
    param (
        [string]$FilePath
    )

    Write-Host "Correction de l'encodage pour le fichier: $FilePath"

    if (Test-Path -Path $FilePath) {
        try {
            # Lire le contenu du fichier en binaire
            $bytes = [System.IO.File]::ReadAllBytes($FilePath)
            
            # Détecter l'encodage actuel
            $currentEncoding = [System.Text.Encoding]::Default
            $content = $currentEncoding.GetString($bytes)
            
            # Écrire le contenu dans le fichier avec UTF-8 sans BOM
            $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($FilePath, $content, $utf8NoBomEncoding)

            Write-Host "Encodage corrigé avec succès pour: $FilePath" -ForegroundColor Green
        }
        catch {
            Write-Host "Erreur lors de la correction de l'encodage pour: $FilePath" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
    else {
        Write-Host "Le fichier n'existe pas: $FilePath" -ForegroundColor Yellow
    }
}

# Liste des fichiers à corriger
$filesToFix = @(
    ".roomodes",
    "roo-config/README.md",
    "roo-modes/README.md",
    "tests/README.md"
)

# Corriger l'encodage de chaque fichier
foreach ($file in $filesToFix) {
    Fix-FileEncoding -FilePath $file
}

Write-Host "Opération terminée. Vérifiez les fichiers pour vous assurer que l'encodage est correct." -ForegroundColor Cyan
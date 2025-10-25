# Script de correction du type implicite dans compare-config.ts
# Ajoute le type DetectedDifference au paramètre diff

$compareConfigPath = "mcps/internal/servers/roo-state-manager/src/tools/roosync/compare-config.ts"

Write-Host "🔧 Correction du type implicite dans compare-config.ts..." -ForegroundColor Cyan

# Lire le fichier actuel
$content = Get-Content $compareConfigPath -Raw

# Vérifier si le type est déjà explicite
if ($content -match "map\(\(diff: DetectedDifference\)") {
    Write-Host "✅ Le type est déjà explicite" -ForegroundColor Green
    exit 0
}

# Ajouter l'import du type DetectedDifference en haut du fichier
if ($content -notmatch "import.*DetectedDifference") {
    # Trouver la ligne d'import DiffDetector et ajouter le type
    $content = $content -replace "(import.*from '\./\./services/DiffDetector\.js';)", @'
import { DiffDetector, type ComparisonReport, type DetectedDifference } from '../../services/DiffDetector.js';
'@
}

# Corriger le paramètre implicite diff à la ligne 127
$content = $content -replace "\.map\(diff =>", ".map((diff: DetectedDifference) =>"

# Écrire le fichier modifié
Set-Content -Path $compareConfigPath -Value $content -Encoding UTF8

Write-Host "✅ Type explicite ajouté au paramètre diff" -ForegroundColor Green
Write-Host "📝 Fichier modifié: $compareConfigPath" -ForegroundColor Yellow
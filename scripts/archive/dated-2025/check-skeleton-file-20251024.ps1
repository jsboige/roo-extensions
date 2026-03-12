# Script de vérification du fichier skeleton
$filePath = "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\.skeletons\18141742-f376-4053-8e1f-804d79daaf6d.json"

Write-Host "=== VÉRIFICATION FICHIER SKELETON ===" -ForegroundColor Cyan
Write-Host "Fichier: $filePath" -ForegroundColor Yellow
Write-Host ""

# Vérifier existence
if (Test-Path $filePath) {
    Write-Host "✅ Fichier existe" -ForegroundColor Green
    
    # Lire le contenu
    $content = Get-Content $filePath -Raw -Encoding UTF8
    
    # Vérifier si parentTaskId est présent
    if ($content -match '"parentTaskId"') {
        Write-Host "✅ Le champ 'parentTaskId' est PRÉSENT dans le fichier" -ForegroundColor Green
        
        # Extraire la valeur
        if ($content -match '"parentTaskId"\s*:\s*"([^"]+)"') {
            $parentId = $matches[1]
            Write-Host "   Valeur: $parentId" -ForegroundColor Cyan
        }
    } else {
        Write-Host "❌ Le champ 'parentTaskId' est ABSENT du fichier" -ForegroundColor Red
    }
    
    # Afficher les 100 premiers caractères après parsing JSON
    Write-Host ""
    Write-Host "=== DÉBUT DU FICHIER JSON ===" -ForegroundColor Cyan
    try {
        $json = $content | ConvertFrom-Json
        Write-Host "taskId: $($json.taskId)"
        Write-Host "parentTaskId: $($json.parentTaskId)"
        Write-Host "Nombre de clés racine: $($json.PSObject.Properties.Count)"
        Write-Host "Clés: $($json.PSObject.Properties.Name -join ', ')"
    } catch {
        Write-Host "⚠️ Erreur parsing JSON: $_" -ForegroundColor Yellow
        Write-Host "Premiers 500 caractères bruts:"
        Write-Host $content.Substring(0, [Math]::Min(500, $content.Length))
    }
    
    # Informations fichier
    Write-Host ""
    Write-Host "=== MÉTADONNÉES FICHIER ===" -ForegroundColor Cyan
    $fileInfo = Get-Item $filePath
    Write-Host "Taille: $($fileInfo.Length) octets"
    Write-Host "Dernière modification: $($fileInfo.LastWriteTime)"
    
} else {
    Write-Host "❌ Fichier n'existe PAS" -ForegroundColor Red
}
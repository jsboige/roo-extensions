# Extract last 5000 characters from parent task file
$ErrorActionPreference = "Stop"

$parentFile = 'C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\cb7e564f-152f-48e3-8eff-f424d7ebc6bd\api_conversation_history.json'
$outputFile = 'd:\Dev\roo-extensions\outputs\parent-tail.txt'

Write-Host "=== EXTRACTION PARENT TAIL ===`n" -ForegroundColor Cyan

if (Test-Path $parentFile) {
    $fileInfo = Get-Item $parentFile
    $fileSize = $fileInfo.Length
    Write-Host "Fichier: $parentFile" -ForegroundColor Gray
    Write-Host "Taille totale: $fileSize bytes`n" -ForegroundColor Yellow
    
    # Calculer la position de départ (fin - 5000)
    $startPos = [Math]::Max(0, $fileSize - 5000)
    
    $stream = [System.IO.StreamReader]::new($parentFile, [System.Text.Encoding]::UTF8)
    try {
        # Se positionner à startPos
        $stream.BaseStream.Seek($startPos, [System.IO.SeekOrigin]::Begin) | Out-Null
        $stream.DiscardBufferedData()
        
        # Lire jusqu'à la fin
        $buffer = New-Object char[] 5000
        $read = $stream.Read($buffer, 0, 5000)
        $snippet = -join $buffer[0..($read-1)]
        
        # Sauvegarder
        [System.IO.File]::WriteAllText($outputFile, $snippet, [System.Text.Encoding]::UTF8)
        
        Write-Host "✅ Extraction réussie: $read caractères" -ForegroundColor Green
        Write-Host "✅ Sauvegarde dans: $outputFile`n" -ForegroundColor Green
        
        # Afficher les 500 premiers caractères comme preview
        $preview = if ($snippet.Length -gt 500) { $snippet.Substring(0, 500) } else { $snippet }
        Write-Host "=== PREVIEW (500 premiers caractères) ===" -ForegroundColor Cyan
        Write-Host $preview
        Write-Host "`n[...truncated]`n" -ForegroundColor Yellow
        
    } finally {
        $stream.Close()
    }
} else {
    Write-Host "❌ FICHIER NON TROUVÉ: $parentFile" -ForegroundColor Red
    exit 1
}
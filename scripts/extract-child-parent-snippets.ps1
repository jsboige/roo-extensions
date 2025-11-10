# Script pour extraire le début du fichier enfant et la fin du fichier parent
# Sans lire les fichiers en entier (streaming par caractères)

param(
    [Parameter(Mandatory=$true)]
    [string]$ChildTaskId,
    
    [Parameter(Mandatory=$true)]
    [string]$ParentTaskId,
    
    [int]$ChildChars = 5000,
    [int]$ParentChars = 10000
)

$ErrorActionPreference = "Stop"

# Chemins des fichiers
$basePath = "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"
$childFile = Join-Path $basePath "$ChildTaskId\api_conversation_history.json"
$parentFile = Join-Path $basePath "$ParentTaskId\api_conversation_history.json"

Write-Host "=== EXTRACTION CHILD TASK (début) ===" -ForegroundColor Cyan
Write-Host "Fichier: $childFile" -ForegroundColor Gray

if (Test-Path $childFile) {
    $stream = [System.IO.StreamReader]::new($childFile, [System.Text.Encoding]::UTF8)
    try {
        $buffer = New-Object char[] $ChildChars
        $read = $stream.Read($buffer, 0, $ChildChars)
        $snippet = -join $buffer[0..($read-1)]
        Write-Host $snippet
        Write-Host "`n[...truncated at $read chars]`n" -ForegroundColor Yellow
    } finally {
        $stream.Close()
    }
} else {
    Write-Host "FICHIER NON TROUVÉ: $childFile" -ForegroundColor Red
}

Write-Host "`n=== EXTRACTION PARENT TASK (fin) ===" -ForegroundColor Cyan
Write-Host "Fichier: $parentFile" -ForegroundColor Gray

if (Test-Path $parentFile) {
    $fileInfo = Get-Item $parentFile
    $fileSize = $fileInfo.Length
    Write-Host "Taille totale: $fileSize bytes" -ForegroundColor Gray
    
    # Calculer la position de départ (fin - ParentChars)
    $startPos = [Math]::Max(0, $fileSize - $ParentChars)
    
    $stream = [System.IO.StreamReader]::new($parentFile, [System.Text.Encoding]::UTF8)
    try {
        # Se positionner à startPos
        $stream.BaseStream.Seek($startPos, [System.IO.SeekOrigin]::Begin) | Out-Null
        $stream.DiscardBufferedData()
        
        # Lire jusqu'à la fin
        $buffer = New-Object char[] $ParentChars
        $read = $stream.Read($buffer, 0, $ParentChars)
        $snippet = -join $buffer[0..($read-1)]
        Write-Host "`n[...skipped first $startPos chars]" -ForegroundColor Yellow
        Write-Host $snippet
    } finally {
        $stream.Close()
    }
} else {
    Write-Host "FICHIER NON TROUVÉ: $parentFile" -ForegroundColor Red
}
# Script pour créer un fichier JSON propre avec les modes simples/complex
# Ce script crée un nouveau fichier JSON avec les bonnes valeurs et le bon encodage

. "$PSScriptRoot\..\common\extension-paths.ps1"

# Chemin du fichier de destination
$destinationDir = Join-Path (Get-GlobalStoragePath -Extension RooCode) "settings"
$destinationFile = Join-Path -Path $destinationDir -ChildPath "custom_modes.json"

# Vérifier que le répertoire de destination existe
if (-not (Test-Path -Path $destinationDir)) {
    try {
        New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
        Write-Host "Répertoire créé: $destinationDir" -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur lors de la création du répertoire: $destinationDir" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

# Créer l'objet JSON avec les modes
$customModes = @{
    customModes = @(
        @{
            slug = "mode-family-validator"
            name = "Mode Family Validator"
            description = "Système de validation des transitions entre familles de modes"
            version = "1.0.0"
            enabled = $true
            familyDefinitions = @{
                simple = @("code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple")
                complex = @("code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex", "manager")
            }
        },
        @{
            slug = "code-simple"
            family = "simple"
            allowedFamilyTransitions = @("complex")
            name = "💻 Code Simple"
            model = "anthropic/claude-3.5-sonnet"
            roleDefinition = "You are Roo Code (version simple), specialized in minor code modifications, simple bug fixes, code formatting and documentation, and basic feature implementation."
            groups = @("simple")
            customInstructions = "FOCUS AREAS:`n- Modifications de code < 50 lignes`n- Fonctions isolées`n- Bugs simples`n- Patterns standards`n- Documentation basique"
        },
        @{
            slug = "code-complex"
            family = "complex"
            allowedFamilyTransitions = @("complex")
            name = "💻 Code Complex"
            model = "anthropic/claude-3.7-sonnet"
            roleDefinition = "You are Roo, a highly skilled software engineer with extensive knowledge in many programming languages, frameworks, design patterns, and best practices."
            groups = @("complex")
            customInstructions = "FOCUS AREAS:`n- Major refactoring`n- Architecture design`n- Performance optimization`n- Complex algorithms`n- System integration"
        }
    )
}

# Convertir l'objet en JSON
$jsonString = ConvertTo-Json -InputObject $customModes -Depth 100

try {
    # Créer une copie de sauvegarde si le fichier existe déjà
    if (Test-Path -Path $destinationFile) {
        $backupPath = "$destinationFile.backup"
        Copy-Item -Path $destinationFile -Destination $backupPath -Force
        Write-Host "Copie de sauvegarde créée: $backupPath" -ForegroundColor Green
    }

    # Écrire le contenu en UTF-8 sans BOM
    [System.IO.File]::WriteAllText($destinationFile, $jsonString, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Fichier JSON créé avec succès!" -ForegroundColor Green

    # Vérifier l'encodage du fichier
    $bytes = [System.IO.File]::ReadAllBytes($destinationFile)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Host "Le fichier est encodé en UTF-8 avec BOM" -ForegroundColor Yellow
    } else {
        Write-Host "Le fichier est encodé en UTF-8 sans BOM" -ForegroundColor Green
    }
} catch {
    Write-Host "Erreur lors de la création du fichier JSON:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "`nPour activer les modes:" -ForegroundColor Cyan
Write-Host "1. Redémarrez Visual Studio Code" -ForegroundColor White
Write-Host "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" -ForegroundColor White
Write-Host "3. Tapez 'Roo: Switch Mode' et sélectionnez un des modes" -ForegroundColor White
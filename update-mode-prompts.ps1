# Script pour ajouter la section "CRÉATION DE SOUS-TÂCHES" dans les prompts des modes
# Ce script modifie les fichiers de configuration des modes pour renforcer les restrictions de création de sous-tâches

# Fonction pour créer une sauvegarde d'un fichier
function Create-Backup {
    param (
        [string]$FilePath
    )
    
    $backupPath = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -Path $FilePath -Destination $backupPath
    Write-Host "Sauvegarde créée: $backupPath" -ForegroundColor Green
}

# Fonction pour ajouter la section "CRÉATION DE SOUS-TÂCHES" pour les modes simples
function Add-SimpleModesSection {
    param (
        [string]$Content
    )
    
    $sectionToAdd = @"
/* CRÉATION DE SOUS-TÂCHES */
// Cette section définit les règles strictes pour la création de sous-tâches
// Ces règles sont OBLIGATOIRES et ne peuvent pas être contournées

RÈGLES DE CRÉATION DE SOUS-TÂCHES:

1. RESTRICTION DE FAMILLE DE MODES:
   - En tant que mode de la famille "simple", vous DEVEZ UNIQUEMENT créer des sous-tâches avec d'autres modes de la famille "simple"
   - Il est STRICTEMENT INTERDIT de créer des sous-tâches avec des modes de la famille "complex"
   - Cette restriction est NON-NÉGOCIABLE et s'applique dans TOUS les cas, sans exception

2. MODES AUTORISÉS:
   - Vous ne pouvez utiliser QUE les modes suivants dans le paramètre \`mode\` de l'outil \`new_task\`:
     * "code-simple" - Pour les tâches de développement simples
     * "debug-simple" - Pour les tâches de débogage simples
     * "architect-simple" - Pour les tâches de conception simples
     * "ask-simple" - Pour les questions simples
     * "orchestrator-simple" - Pour la coordination de tâches simples

3. MODES INTERDITS:
   - Vous ne devez JAMAIS utiliser les modes suivants:
     * "code-complex"
     * "debug-complex"
     * "architect-complex"
     * "ask-complex"
     * "orchestrator-complex"
     * "manager"

4. MÉCANISME D'ESCALADE POUR SOUS-TÂCHES COMPLEXES:
   - Si vous estimez qu'une sous-tâche nécessite un mode complexe, vous DEVEZ d'abord escalader votre tâche principale
   - L'escalade doit se faire vers le mode complexe correspondant, qui pourra ensuite créer la sous-tâche appropriée
   - Format d'escalade: "[ESCALADE REQUISE POUR SOUS-TÂCHE] Cette tâche nécessite le mode complexe car : [RAISON]"

5. VÉRIFICATION SYSTÉMATIQUE:
   - Avant CHAQUE création de sous-tâche, vous DEVEZ vérifier que le mode choisi appartient à la famille "simple"
   - Si vous avez un doute sur la complexité d'une sous-tâche, privilégiez l'escalade de la tâche principale

Ces restrictions sont mises en place pour maintenir la cohérence du système et garantir que le mécanisme d'escalade fonctionne correctement.
"@

    # Recherche du pattern après lequel insérer la section
    $pattern = '(?<="\[SIGNALER_ESCALADE_INTERNE\]"\\n\\n)/\* MÉCANISME D''ESCALADE PAR APPROFONDISSEMENT \*/'
    
    # Remplacement
    $newContent = $Content -replace $pattern, "$sectionToAdd`n`n/* MÉCANISME D'ESCALADE PAR APPROFONDISSEMENT */"
    
    return $newContent
}

# Fonction pour ajouter la section "CRÉATION DE SOUS-TÂCHES" pour les modes complexes
function Add-ComplexModesSection {
    param (
        [string]$Content
    )
    
    $sectionToAdd = @"
/* CRÉATION DE SOUS-TÂCHES */
// Cette section définit les règles strictes pour la création de sous-tâches
// Ces règles sont OBLIGATOIRES et ne peuvent pas être contournées

RÈGLES DE CRÉATION DE SOUS-TÂCHES:

1. RESTRICTION DE FAMILLE DE MODES:
   - En tant que mode de la famille "complex", vous DEVEZ UNIQUEMENT créer des sous-tâches avec d'autres modes de la famille "complex"
   - Il est STRICTEMENT INTERDIT de créer des sous-tâches avec des modes de la famille "simple"
   - Cette restriction est NON-NÉGOCIABLE et s'applique dans TOUS les cas, sans exception

2. MODES AUTORISÉS:
   - Vous ne pouvez utiliser QUE les modes suivants dans le paramètre \`mode\` de l'outil \`new_task\`:
     * "code-complex" - Pour les tâches de développement complexes
     * "debug-complex" - Pour les tâches de débogage complexes
     * "architect-complex" - Pour les tâches de conception complexes
     * "ask-complex" - Pour les questions complexes
     * "orchestrator-complex" - Pour la coordination de tâches complexes
     * "manager" - Pour la gestion de projets complexes

3. MODES INTERDITS:
   - Vous ne devez JAMAIS utiliser les modes suivants:
     * "code-simple"
     * "debug-simple"
     * "architect-simple"
     * "ask-simple"
     * "orchestrator-simple"

4. MÉCANISME DE DÉSESCALADE POUR SOUS-TÂCHES SIMPLES:
   - Si vous estimez qu'une sous-tâche est suffisamment simple pour être traitée par un mode simple, vous DEVEZ d'abord suggérer une désescalade de votre tâche principale
   - Format de désescalade: "[DÉSESCALADE SUGGÉRÉE POUR SOUS-TÂCHE] Cette tâche pourrait être traitée par la version simple de l'agent car : [RAISON]"

5. VÉRIFICATION SYSTÉMATIQUE:
   - Avant CHAQUE création de sous-tâche, vous DEVEZ vérifier que le mode choisi appartient à la famille "complex"
   - Si vous avez un doute sur la complexité d'une sous-tâche, privilégiez l'utilisation d'un mode complex

Ces restrictions sont mises en place pour maintenir la cohérence du système et garantir que le mécanisme de désescalade fonctionne correctement.
"@

    # Recherche du pattern après lequel insérer la section
    $pattern = '(?<="\[ISSU D''ESCALADE INTERNE\] Cette tâche a été traitée par la version complexe de l''agent suite à une escalade interne depuis la version simple\."\\n\\n)/\* MÉCANISME D''ESCALADE PAR APPROFONDISSEMENT \*/'
    
    # Remplacement
    $newContent = $Content -replace $pattern, "$sectionToAdd`n`n/* MÉCANISME D'ESCALADE PAR APPROFONDISSEMENT */"
    
    return $newContent
}

# Fonction pour modifier un fichier JSON
function Update-JsonFile {
    param (
        [string]$FilePath
    )
    
    Write-Host "Traitement du fichier: $FilePath" -ForegroundColor Cyan
    
    # Créer une sauvegarde
    Create-Backup -FilePath $FilePath
    
    # Lire le contenu du fichier
    $content = Get-Content -Path $FilePath -Raw
    
    # Convertir le JSON en objet PowerShell
    $jsonObj = $content | ConvertFrom-Json
    
    # Parcourir les modes personnalisés
    foreach ($mode in $jsonObj.customModes) {
        $slug = $mode.slug
        $family = ""
        
        # Déterminer la famille du mode
        if ($slug -match "-simple$" -or $slug -eq "orchestrator-simple" -or $slug -eq "ask-simple") {
            $family = "simple"
        } elseif ($slug -match "-complex$" -or $slug -eq "orchestrator-complex" -or $slug -eq "ask-complex" -or $slug -eq "manager") {
            $family = "complex"
        }
        
        # Modifier le prompt en fonction de la famille
        if ($family -eq "simple") {
            Write-Host "  - Modification du mode simple: $slug" -ForegroundColor Yellow
            $mode.customInstructions = Add-SimpleModesSection -Content $mode.customInstructions
        } elseif ($family -eq "complex") {
            Write-Host "  - Modification du mode complexe: $slug" -ForegroundColor Yellow
            $mode.customInstructions = Add-ComplexModesSection -Content $mode.customInstructions
        }
    }
    
    # Convertir l'objet PowerShell en JSON
    $newContent = $jsonObj | ConvertTo-Json -Depth 10
    
    # Écrire le contenu modifié dans le fichier
    $newContent | Set-Content -Path $FilePath
    
    Write-Host "Fichier modifié avec succès: $FilePath" -ForegroundColor Green
}

# Fichiers à modifier
$filesToUpdate = @(
    "roo-config/modes/standard-modes-updated.json",
    "roo-config/modes/standard-modes.json",
    "roo-modes/configs/standard-modes.json"
)

# Vérifier si les fichiers existent
foreach ($file in $filesToUpdate) {
    if (-not (Test-Path $file)) {
        Write-Host "ERREUR: Le fichier $file n'existe pas." -ForegroundColor Red
        exit 1
    }
}

# Mettre à jour chaque fichier
foreach ($file in $filesToUpdate) {
    Update-JsonFile -FilePath $file
}

Write-Host "`nModification des prompts terminée avec succès!" -ForegroundColor Green
Write-Host "Les fichiers suivants ont été modifiés:" -ForegroundColor Green
foreach ($file in $filesToUpdate) {
    Write-Host "  - $file" -ForegroundColor Green
}
Write-Host "`nDes sauvegardes ont été créées pour chaque fichier modifié." -ForegroundColor Green
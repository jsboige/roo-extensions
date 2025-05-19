# Script pour ajouter la section "CREATION DE SOUS-TACHES" dans les prompts des modes
# Ce script modifie les fichiers de configuration des modes pour renforcer les restrictions de creation de sous-taches
# Version 2.0 - Approche plus robuste avec meilleure gestion de l'encodage et des expressions regulieres

# Fonction pour creer une sauvegarde d'un fichier
function Create-Backup {
    param (
        [string]$FilePath
    )
    
    $backupPath = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -Path $FilePath -Destination $backupPath
    Write-Host "Sauvegarde creee: $backupPath" -ForegroundColor Green
}

# Fonction pour obtenir la section a ajouter pour les modes simples
function Get-SimpleModesSection {
    return @"
/* CREATION DE SOUS-TACHES */
// Cette section definit les regles strictes pour la creation de sous-taches
// Ces regles sont OBLIGATOIRES et ne peuvent pas etre contournees

REGLES DE CREATION DE SOUS-TACHES:

1. RESTRICTION DE FAMILLE DE MODES:
   - En tant que mode de la famille "simple", vous DEVEZ UNIQUEMENT creer des sous-taches avec d'autres modes de la famille "simple"
   - Il est STRICTEMENT INTERDIT de creer des sous-taches avec des modes de la famille "complex"
   - Cette restriction est NON-NEGOCIABLE et s'applique dans TOUS les cas, sans exception

2. MODES AUTORISES:
   - Vous ne pouvez utiliser QUE les modes suivants dans le parametre `mode` de l'outil `new_task`:
     * "code-simple" - Pour les taches de developpement simples
     * "debug-simple" - Pour les taches de debogage simples
     * "architect-simple" - Pour les taches de conception simples
     * "ask-simple" - Pour les questions simples
     * "orchestrator-simple" - Pour la coordination de taches simples

3. MODES INTERDITS:
   - Vous ne devez JAMAIS utiliser les modes suivants:
     * "code-complex"
     * "debug-complex"
     * "architect-complex"
     * "ask-complex"
     * "orchestrator-complex"
     * "manager"

4. MECANISME D'ESCALADE POUR SOUS-TACHES COMPLEXES:
   - Si vous estimez qu'une sous-tache necessite un mode complexe, vous DEVEZ d'abord escalader votre tache principale
   - L'escalade doit se faire vers le mode complexe correspondant, qui pourra ensuite creer la sous-tache appropriee
   - Format d'escalade: "[ESCALADE REQUISE POUR SOUS-TACHE] Cette tache necessite le mode complexe car : [RAISON]"

5. VERIFICATION SYSTEMATIQUE:
   - Avant CHAQUE creation de sous-tache, vous DEVEZ verifier que le mode choisi appartient a la famille "simple"
   - Si vous avez un doute sur la complexite d'une sous-tache, privilegiez l'escalade de la tache principale

Ces restrictions sont mises en place pour maintenir la coherence du systeme et garantir que le mecanisme d'escalade fonctionne correctement.
"@
}

# Fonction pour obtenir la section à ajouter pour les modes complexes
function Get-ComplexModesSection {
    return @"
/* CREATION DE SOUS-TACHES */
// Cette section definit les regles strictes pour la creation de sous-taches
// Ces regles sont OBLIGATOIRES et ne peuvent pas etre contournees

REGLES DE CREATION DE SOUS-TACHES:

1. RESTRICTION DE FAMILLE DE MODES:
   - En tant que mode de la famille "complex", vous DEVEZ UNIQUEMENT creer des sous-taches avec d'autres modes de la famille "complex"
   - Il est STRICTEMENT INTERDIT de creer des sous-taches avec des modes de la famille "simple"
   - Cette restriction est NON-NEGOCIABLE et s'applique dans TOUS les cas, sans exception

2. MODES AUTORISES:
   - Vous ne pouvez utiliser QUE les modes suivants dans le parametre `mode` de l'outil `new_task`:
     * "code-complex" - Pour les taches de developpement complexes
     * "debug-complex" - Pour les taches de debogage complexes
     * "architect-complex" - Pour les taches de conception complexes
     * "ask-complex" - Pour les questions complexes
     * "orchestrator-complex" - Pour la coordination de taches complexes
     * "manager" - Pour la gestion de projets complexes

3. MODES INTERDITS:
   - Vous ne devez JAMAIS utiliser les modes suivants:
     * "code-simple"
     * "debug-simple"
     * "architect-simple"
     * "ask-simple"
     * "orchestrator-simple"

4. MECANISME DE DESESCALADE POUR SOUS-TACHES SIMPLES:
   - Si vous estimez qu'une sous-tache est suffisamment simple pour etre traitee par un mode simple, vous DEVEZ d'abord suggerer une desescalade de votre tache principale
   - Format de desescalade: "[DESESCALADE SUGGEREE POUR SOUS-TACHE] Cette tache pourrait etre traitee par la version simple de l'agent car : [RAISON]"

5. VERIFICATION SYSTEMATIQUE:
   - Avant CHAQUE creation de sous-tache, vous DEVEZ verifier que le mode choisi appartient a la famille "complex"
   - Si vous avez un doute sur la complexite d'une sous-tache, privilegiez l'utilisation d'un mode complex

Ces restrictions sont mises en place pour maintenir la coherence du systeme et garantir que le mecanisme de desescalade fonctionne correctement.
"@
}

# Fonction pour trouver l'emplacement d'insertion dans le prompt
function Find-InsertionPoint {
    param (
        [string]$Content,
        [string]$Family
    )

    # Verifier si la section existe deja
    if ($Content -match '/\* CREATION DE SOUS-TACHES \*/') {
        Write-Host "  - La section CREATION DE SOUS-TACHES existe deja" -ForegroundColor Yellow
        return $null
    }

    # Points d'insertion possibles pour les modes simples
    $simpleInsertionPoints = @(
        # Après la section ESCALADE INTERNE
        @{
            Pattern = '\[SIGNALER_ESCALADE_INTERNE\]"(\r?\n)+'
            InsertBefore = '\/\* MECANISME D''ESCALADE PAR APPROFONDISSEMENT \*\/'
            Priority = 1
        },
        # Avant la section MECANISME D'ESCALADE PAR APPROFONDISSEMENT
        @{
            Pattern = '\/\* MECANISME D''ESCALADE PAR APPROFONDISSEMENT \*\/'
            InsertBefore = $null
            Priority = 2
        },
        # Après la section MECANISME D'ESCALADE
        @{
            Pattern = 'Au début de chaque tâche, évaluez sa complexité selon les critères ci-dessus\.'
            InsertBefore = '\/\* ESCALADE INTERNE \*\/'
            Priority = 3
        }
    )

    # Points d'insertion possibles pour les modes complexes
    $complexInsertionPoints = @(
        # Après la notification d'escalade interne
        @{
            Pattern = '\[ISSU D''ESCALADE INTERNE\].*?version simple de l''agent'
            InsertBefore = '\/\* MECANISME D''ESCALADE PAR APPROFONDISSEMENT \*\/'
            Priority = 1
        },
        # Avant la section MECANISME D'ESCALADE PAR APPROFONDISSEMENT
        @{
            Pattern = '\/\* MECANISME D''ESCALADE PAR APPROFONDISSEMENT \*\/'
            InsertBefore = $null
            Priority = 2
        },
        # Après la section de desescalade
        @{
            Pattern = 'MECANISME DE DESESCALADE'
            InsertBefore = '\/\* MECANISME D''ESCALADE PAR APPROFONDISSEMENT \*\/'
            Priority = 3
        }
    )

    $insertionPoints = if ($Family -eq "simple") { $simpleInsertionPoints } else { $complexInsertionPoints }

    foreach ($point in ($insertionPoints | Sort-Object -Property Priority)) {
        if ($Content -match $point.Pattern) {
            $match = [regex]::Match($Content, $point.Pattern)
            $position = $match.Index + $match.Length
            
            # Si nous avons un pattern à insérer avant, trouver sa position
            if ($point.InsertBefore -and $Content -match $point.InsertBefore) {
                $beforeMatch = [regex]::Match($Content, $point.InsertBefore)
                $endPosition = $beforeMatch.Index
                
                # Vérifier que le point d'insertion est avant le pattern InsertBefore
                if ($position -lt $endPosition) {
                    return @{
                        Position = $position
                        BeforePosition = $endPosition
                        Success = $true
                    }
                }
            } else {
                return @{
                    Position = $position
                    BeforePosition = $null
                    Success = $true
                }
            }
        }
    }

    # Si aucun point d'insertion n'a été trouvé
    return @{
        Success = $false
        Position = $null
        BeforePosition = $null
    }
}

# Fonction pour insérer la section dans le prompt
function Insert-Section {
    param (
        [string]$Content,
        [string]$Section,
        [hashtable]$InsertionPoint
    )

    if (-not $InsertionPoint.Success) {
        Write-Host "  - Impossible de trouver un point d'insertion approprié" -ForegroundColor Red
        return $Content
    }

    $position = $InsertionPoint.Position
    $beforePosition = $InsertionPoint.BeforePosition

    if ($beforePosition) {
        # Insérer entre deux sections
        $before = $Content.Substring(0, $position)
        $middle = "`n`n$Section`n`n"
        $after = $Content.Substring($beforePosition)
        return $before + $middle + $after
    } else {
        # Insérer à une position spécifique
        $before = $Content.Substring(0, $position)
        $after = $Content.Substring($position)
        return $before + "`n`n$Section`n`n" + $after
    }
}

# Fonction pour modifier un fichier JSON
function Update-JsonFile {
    param (
        [string]$FilePath,
        [switch]$TestMode
    )
    
    Write-Host "Traitement du fichier: $FilePath" -ForegroundColor Cyan
    
    # Créer une sauvegarde si nous ne sommes pas en mode test
    if (-not $TestMode) {
        Create-Backup -FilePath $FilePath
    }
    
    try {
        # Détecter l'encodage du fichier
        $fileContent = Get-Content -Path $FilePath -Raw
        $encoding = [System.Text.Encoding]::UTF8
        
        # Essayer de détecter le BOM
        $hasBOM = $false
        if ($fileContent.Length -ge 3) {
            $bytes = [System.Text.Encoding]::Default.GetBytes($fileContent.Substring(0, 3))
            if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                $hasBOM = $true
                $encoding = [System.Text.Encoding]::UTF8
                Write-Host "  - Encodage détecté: UTF-8 avec BOM" -ForegroundColor Gray
            } else {
                Write-Host "  - Encodage supposé: UTF-8 sans BOM" -ForegroundColor Gray
            }
        }
        
        # Convertir le JSON en objet PowerShell
        $jsonObj = $fileContent | ConvertFrom-Json
        $modesModified = 0
        
        # Parcourir les modes personnalisés
        foreach ($mode in $jsonObj.customModes) {
            $slug = $mode.slug
            $family = ""
            
            # Déterminer la famille du mode
            if ($slug -match "-simple$" -or $slug -eq "orchestrator-simple" -or $slug -eq "ask-simple") {
                $family = "simple"
            } elseif ($slug -match "-complex$" -or $slug -eq "orchestrator-complex" -or $slug -eq "ask-complex" -or $slug -eq "manager") {
                $family = "complex"
            } else {
                Write-Host "  - Mode non reconnu: $slug (ignoré)" -ForegroundColor Yellow
                continue
            }
            
            # Obtenir la section à ajouter
            $sectionToAdd = if ($family -eq "simple") { 
                Get-SimpleModesSection 
            } else { 
                Get-ComplexModesSection 
            }
            
            # Trouver le point d'insertion
            $insertionPoint = Find-InsertionPoint -Content $mode.customInstructions -Family $family
            
            if ($insertionPoint -and $insertionPoint.Success) {
                Write-Host "  - Modification du mode $family : $slug" -ForegroundColor Yellow
                
                # Insérer la section
                $mode.customInstructions = Insert-Section -Content $mode.customInstructions -Section $sectionToAdd -InsertionPoint $insertionPoint
                $modesModified++
            } else {
                Write-Host "  - Pas de modification pour le mode $slug" -ForegroundColor Yellow
            }
        }
        
        # Si nous sommes en mode test, afficher seulement le nombre de modes qui seraient modifiés
        if ($TestMode) {
            Write-Host "Mode test: $modesModified modes seraient modifiés dans $FilePath" -ForegroundColor Cyan
            return
        }
        
        # Si aucun mode n'a été modifié, ne pas écrire le fichier
        if ($modesModified -eq 0) {
            Write-Host "Aucun mode n'a été modifié dans $FilePath" -ForegroundColor Yellow
            return
        }
        
        # Convertir l'objet PowerShell en JSON avec préservation de l'indentation
        $jsonSettings = New-Object System.Text.Json.JsonSerializerOptions
        $jsonSettings.WriteIndented = $true
        $newContent = [System.Text.Json.JsonSerializer]::Serialize($jsonObj, $jsonSettings)
        
        # Écrire le contenu modifié dans le fichier avec le même encodage
        if ($hasBOM) {
            [System.IO.File]::WriteAllText($FilePath, $newContent, [System.Text.Encoding]::UTF8)
        } else {
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($FilePath, $newContent, $utf8NoBom)
        }
        
        Write-Host "Fichier modifié avec succès: $FilePath ($modesModified modes modifiés)" -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors du traitement du fichier $FilePath :" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
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

# Tester d'abord sur un seul fichier
$testFile = $filesToUpdate[0]
Write-Host "`n=== MODE TEST: Analyse du fichier $testFile ===" -ForegroundColor Magenta
Update-JsonFile -FilePath $testFile -TestMode

# Demander confirmation avant de continuer
$confirmation = Read-Host "`nVoulez-vous appliquer les modifications à tous les fichiers? (O/N)"
if ($confirmation -ne "O" -and $confirmation -ne "o") {
    Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
    exit 0
}

# Mettre à jour chaque fichier
Write-Host "`n=== APPLICATION DES MODIFICATIONS ===" -ForegroundColor Magenta
foreach ($file in $filesToUpdate) {
    Update-JsonFile -FilePath $file
}

Write-Host "`nModification des prompts terminée!" -ForegroundColor Green
Write-Host "Les fichiers suivants ont été traités:" -ForegroundColor Green
foreach ($file in $filesToUpdate) {
    Write-Host "  - $file" -ForegroundColor Green
}
Write-Host "`nDes sauvegardes ont été créées pour chaque fichier modifié." -ForegroundColor Green
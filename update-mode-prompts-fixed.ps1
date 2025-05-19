# Script pour ajouter la section "CREATION DE SOUS-TACHES" dans les prompts des modes
# Ce script modifie les fichiers de configuration des modes pour renforcer les restrictions de creation de sous-taches

# Fonction pour creer une sauvegarde d'un fichier
function Create-Backup {
    param (
        [string]$FilePath
    )
    
    $backupPath = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -Path $FilePath -Destination $backupPath
    Write-Host "Sauvegarde creee: $backupPath" -ForegroundColor Green
}

# Fonction pour ajouter la section "CREATION DE SOUS-TACHES" pour les modes simples
function Add-SimpleModesSection {
    param (
        [string]$Content
    )
    
    $sectionToAdd = @"
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
    
    # Recherche du pattern apres lequel inserer la section
    $pattern = '/\* MECANISME D''ESCALADE PAR APPROFONDISSEMENT \*/'
    
    # Verifier si la section existe deja
    if ($Content -match '/\* CREATION DE SOUS-TACHES \*/') {
        Write-Host "  - La section CREATION DE SOUS-TACHES existe deja" -ForegroundColor Yellow
        return $Content
    }
    
    # Remplacement
    $newContent = $Content -replace $pattern, "$sectionToAdd`n`n/* MECANISME D'ESCALADE PAR APPROFONDISSEMENT */"
    
    return $newContent
}

# Fonction pour ajouter la section "CREATION DE SOUS-TACHES" pour les modes complexes
function Add-ComplexModesSection {
    param (
        [string]$Content
    )
    
    $sectionToAdd = @"
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
    
    # Recherche du pattern apres lequel inserer la section
    $pattern = '/\* MECANISME D''ESCALADE PAR APPROFONDISSEMENT \*/'
    
    # Verifier si la section existe deja
    if ($Content -match '/\* CREATION DE SOUS-TACHES \*/') {
        Write-Host "  - La section CREATION DE SOUS-TACHES existe deja" -ForegroundColor Yellow
        return $Content
    }
    
    # Remplacement
    $newContent = $Content -replace $pattern, "$sectionToAdd`n`n/* MECANISME D'ESCALADE PAR APPROFONDISSEMENT */"
    
    return $newContent
}

# Fonction pour modifier un fichier JSON
function Update-JsonFile {
    param (
        [string]$FilePath
    )
    
    Write-Host "Traitement du fichier: $FilePath" -ForegroundColor Cyan
    
    # Creer une sauvegarde
    Create-Backup -FilePath $FilePath
    
    # Lire le contenu du fichier
    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    
    try {
        # Convertir le JSON en objet PowerShell
        $jsonObj = $content | ConvertFrom-Json
        
        # Parcourir les modes personnalises
        foreach ($mode in $jsonObj.customModes) {
            $slug = $mode.slug
            $family = ""
            
            # Determiner la famille du mode
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
        
        # Ecrire le contenu modifie dans le fichier
        $newContent | Set-Content -Path $FilePath -Encoding UTF8
        
        Write-Host "Fichier modifie avec succes: $FilePath" -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors du traitement du fichier $FilePath :" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Fichiers a modifier
$filesToUpdate = @(
    "roo-config/modes/standard-modes-updated.json",
    "roo-config/modes/standard-modes.json",
    "roo-modes/configs/standard-modes.json"
)

# Verifier si les fichiers existent
foreach ($file in $filesToUpdate) {
    if (-not (Test-Path $file)) {
        Write-Host "ERREUR: Le fichier $file n'existe pas." -ForegroundColor Red
        exit 1
    }
}

# Mettre a jour chaque fichier
foreach ($file in $filesToUpdate) {
    Update-JsonFile -FilePath $file
}

Write-Host "`nModification des prompts terminee avec succes!" -ForegroundColor Green
Write-Host "Les fichiers suivants ont ete modifies:" -ForegroundColor Green
foreach ($file in $filesToUpdate) {
    Write-Host "  - $file" -ForegroundColor Green
}
Write-Host "`nDes sauvegardes ont ete creees pour chaque fichier modifie." -ForegroundColor Green
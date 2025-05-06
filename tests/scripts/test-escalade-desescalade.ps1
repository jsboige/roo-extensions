# Script de test des mécanismes d'escalade et de désescalade
# Ce script vérifie si les mécanismes d'escalade et de désescalade sont correctement configurés et fonctionnels

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

# Fonction pour vérifier si un fichier contient une chaîne spécifique
function Test-FileContainsString {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$SearchString
    )
    
    if (Test-Path -Path $FilePath) {
        $content = Get-Content -Path $FilePath -Raw
        return $content -match [regex]::Escape($SearchString)
    }
    
    return $false
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Test des mécanismes d'escalade et de désescalade" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Partie 1: Vérification des fichiers de configuration
Write-ColorOutput "`n[1/4] Vérification des fichiers de configuration..." "Yellow"

# Vérifier si le fichier .roomodes existe
$roomodesFile = Join-Path -Path $PSScriptRoot -ChildPath ".roomodes"
if (Test-Path -Path $roomodesFile) {
    Write-ColorOutput "Le fichier .roomodes existe." "Green"
    
    # Vérifier si le fichier contient les sections d'escalade et de désescalade
    $escaladeSimpleFound = Test-FileContainsString -FilePath $roomodesFile -SearchString "=== CRITÈRES D'ESCALADE ==="
    $desescaladeComplexFound = Test-FileContainsString -FilePath $roomodesFile -SearchString "=== CRITÈRES DE DÉSESCALADE ==="
    
    if ($escaladeSimpleFound) {
        Write-ColorOutput "Les sections d'escalade sont correctement configurées dans le fichier .roomodes." "Green"
    }
    else {
        Write-ColorOutput "Les sections d'escalade ne sont pas correctement configurées dans le fichier .roomodes." "Red"
    }
    
    if ($desescaladeComplexFound) {
        Write-ColorOutput "Les sections de désescalade sont correctement configurées dans le fichier .roomodes." "Green"
    }
    else {
        Write-ColorOutput "Les sections de désescalade ne sont pas correctement configurées dans le fichier .roomodes." "Red"
    }
}
else {
    Write-ColorOutput "Le fichier .roomodes n'existe pas." "Red"
}

# Vérifier si le fichier criteres-escalade.md existe
$criteresEscaladeFile = Join-Path -Path $PSScriptRoot -ChildPath "criteres-escalade.md"
if (Test-Path -Path $criteresEscaladeFile) {
    Write-ColorOutput "Le fichier criteres-escalade.md existe." "Green"
    
    # Vérifier si le fichier contient les sections attendues
    $criteresEscaladeFound = Test-FileContainsString -FilePath $criteresEscaladeFile -SearchString "# Critères d'Escalade et de Désescalade pour les Modes Roo"
    $formatStandardiseFound = Test-FileContainsString -FilePath $criteresEscaladeFile -SearchString "## 5. Format Standardisé des Messages"
    
    if ($criteresEscaladeFound) {
        Write-ColorOutput "Le fichier criteres-escalade.md contient les critères d'escalade et de désescalade." "Green"
    }
    else {
        Write-ColorOutput "Le fichier criteres-escalade.md ne contient pas les critères d'escalade et de désescalade." "Red"
    }
    
    if ($formatStandardiseFound) {
        Write-ColorOutput "Le fichier criteres-escalade.md contient les formats standardisés des messages." "Green"
    }
    else {
        Write-ColorOutput "Le fichier criteres-escalade.md ne contient pas les formats standardisés des messages." "Red"
    }
}
else {
    Write-ColorOutput "Le fichier criteres-escalade.md n'existe pas." "Red"
}

# Partie 2: Vérification de la configuration des modes
Write-ColorOutput "`n[2/4] Vérification de la configuration des modes..." "Yellow"

# Vérifier si les modes sont correctement configurés dans le fichier .roomodes
if (Test-Path -Path $roomodesFile) {
    try {
        $roomodesContent = Get-Content -Path $roomodesFile -Raw | ConvertFrom-Json
        $simpleModesCount = 0
        $complexModesCount = 0
        $simpleModesWithEscalade = 0
        $complexModesWithDesescalade = 0
        
        # Analyser chaque mode
        foreach ($mode in $roomodesContent.customModes) {
            if ($mode.slug -match "-simple$") {
                $simpleModesCount++
                
                # Vérifier si le mode simple contient les instructions d'escalade
                if ($mode.customInstructions -match "CRITÈRES D'ESCALADE") {
                    $simpleModesWithEscalade++
                }
            }
            elseif ($mode.slug -match "-complex$") {
                $complexModesCount++
                
                # Vérifier si le mode complexe contient les instructions de désescalade
                if ($mode.customInstructions -match "CRITÈRES DE DÉSESCALADE") {
                    $complexModesWithDesescalade++
                }
            }
        }
        
        Write-ColorOutput "Nombre de modes simples trouvés: $simpleModesCount" "Green"
        Write-ColorOutput "Nombre de modes complexes trouvés: $complexModesCount" "Green"
        Write-ColorOutput "Nombre de modes simples avec instructions d'escalade: $simpleModesWithEscalade" "Green"
        Write-ColorOutput "Nombre de modes complexes avec instructions de désescalade: $complexModesWithDesescalade" "Green"
        
        if ($simpleModesCount -eq $simpleModesWithEscalade) {
            Write-ColorOutput "Tous les modes simples sont correctement configurés pour l'escalade." "Green"
        }
        else {
            Write-ColorOutput "Certains modes simples ne sont pas correctement configurés pour l'escalade." "Red"
        }
        
        if ($complexModesCount -eq $complexModesWithDesescalade) {
            Write-ColorOutput "Tous les modes complexes sont correctement configurés pour la désescalade." "Green"
        }
        else {
            Write-ColorOutput "Certains modes complexes ne sont pas correctement configurés pour la désescalade." "Red"
        }
    }
    catch {
        Write-ColorOutput "Erreur lors de l'analyse du fichier .roomodes:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}

# Partie 3: Test des fichiers d'exemple pour l'escalade
Write-ColorOutput "`n[3/4] Test des fichiers d'exemple pour l'escalade..." "Yellow"

# Vérifier si les fichiers de test existent
$testEscaladeCodeFile = Join-Path -Path $PSScriptRoot -ChildPath "test-escalade-code.js"
if (Test-Path -Path $testEscaladeCodeFile) {
    Write-ColorOutput "Le fichier test-escalade-code.js existe." "Green"
    
    # Vérifier si le fichier contient du code complexe
    $fileContent = Get-Content -Path $testEscaladeCodeFile -Raw
    $lineCount = ($fileContent -split "`n").Count
    
    Write-ColorOutput "Nombre de lignes dans le fichier test-escalade-code.js: $lineCount" "Green"
    
    if ($lineCount -gt 50) {
        Write-ColorOutput "Le fichier test-escalade-code.js contient plus de 50 lignes de code, ce qui devrait déclencher une escalade." "Green"
    }
    else {
        Write-ColorOutput "Le fichier test-escalade-code.js contient moins de 50 lignes de code, ce qui pourrait ne pas déclencher une escalade." "Yellow"
    }
}
else {
    Write-ColorOutput "Le fichier test-escalade-code.js n'existe pas." "Yellow"
    
    # Créer un fichier de test pour l'escalade
    Write-ColorOutput "Création d'un fichier de test pour l'escalade..." "Yellow"
    
    $testEscaladeCodeContent = @"
/**
 * Fichier de test pour le mécanisme d'escalade
 * Ce fichier contient une fonction complexe qui devrait déclencher une escalade
 * du mode code-simple vers le mode code-complex
 */

/**
 * Fonction récursive complexe pour calculer les nombres de Fibonacci
 * avec mémoïsation et plusieurs niveaux d'imbrication
 */
function fibonacciComplexe(n, memo = {}) {
    // Cas de base
    if (n <= 0) return 0;
    if (n === 1) return 1;
    
    // Vérifier si le résultat est déjà mémorisé
    if (memo[n] !== undefined) {
        return memo[n];
    }
    
    // Calculer le résultat de manière récursive
    memo[n] = fibonacciComplexe(n - 1, memo) + fibonacciComplexe(n - 2, memo);
    
    return memo[n];
}

/**
 * Fonction pour générer une séquence de Fibonacci avec plusieurs options
 * et structures de contrôle imbriquées
 */
function genererSequenceFibonacci(longueur, options = {}) {
    // Valeurs par défaut pour les options
    const {
        inclureZero = true,
        formatResultat = 'array',
        calculerStats = false,
        limiteValeur = Infinity
    } = options;
    
    // Validation des entrées avec structure conditionnelle complexe
    if (typeof longueur !== 'number' || longueur < 0) {
        throw new Error('La longueur doit être un nombre positif');
    } else if (longueur === 0) {
        return inclureZero ? [0] : [];
    } else if (limiteValeur <= 0) {
        throw new Error('La limite de valeur doit être positive');
    }
    
    // Initialisation des variables
    let sequence = inclureZero ? [0, 1] : [1];
    let stats = calculerStats ? { min: inclureZero ? 0 : 1, max: 1, moyenne: inclureZero ? 0.5 : 1 } : null;
    
    // Génération de la séquence avec structure de boucle et conditions imbriquées
    for (let i = sequence.length; i < (inclureZero ? longueur + 1 : longueur); i++) {
        // Calcul du prochain nombre de Fibonacci
        const nextFib = fibonacciComplexe(i);
        
        // Vérifier si la valeur dépasse la limite
        if (nextFib > limiteValeur) {
            break;
        }
        
        // Ajouter à la séquence
        sequence.push(nextFib);
        
        // Mettre à jour les statistiques si nécessaire
        if (calculerStats) {
            stats.max = Math.max(stats.max, nextFib);
            stats.min = Math.min(stats.min, nextFib);
            stats.moyenne = sequence.reduce((sum, val) => sum + val, 0) / sequence.length;
        }
    }
    
    // Formater le résultat selon l'option spécifiée
    switch (formatResultat) {
        case 'array':
            return calculerStats ? { sequence, stats } : sequence;
        case 'string':
            return calculerStats 
                ? { 
                    sequence: sequence.join(', '), 
                    stats: `Min: ${stats.min}, Max: ${stats.max}, Moyenne: ${stats.moyenne.toFixed(2)}` 
                } 
                : sequence.join(', ');
        case 'object':
            return sequence.reduce((obj, val, idx) => {
                obj[`fib_${idx}`] = val;
                return obj;
            }, {});
        default:
            throw new Error(`Format de résultat non supporté: ${formatResultat}`);
    }
}

// Exemple d'utilisation avec plusieurs paramètres et options
const resultat = genererSequenceFibonacci(15, {
    inclureZero: true,
    formatResultat: 'string',
    calculerStats: true,
    limiteValeur: 1000
});

console.log('Résultat:', resultat);
"@
    
    try {
        Set-Content -Path $testEscaladeCodeFile -Value $testEscaladeCodeContent
        Write-ColorOutput "Le fichier test-escalade-code.js a été créé avec succès." "Green"
    }
    catch {
        Write-ColorOutput "Erreur lors de la création du fichier test-escalade-code.js:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}

# Partie 4: Test des fichiers d'exemple pour la désescalade
Write-ColorOutput "`n[4/4] Test des fichiers d'exemple pour la désescalade..." "Yellow"

# Vérifier si les fichiers de test existent
$testDesescaladeDebugFile = Join-Path -Path $PSScriptRoot -ChildPath "test-desescalade-debug.js"
if (Test-Path -Path $testDesescaladeDebugFile) {
    Write-ColorOutput "Le fichier test-desescalade-debug.js existe." "Green"
    
    # Vérifier si le fichier contient du code simple
    $fileContent = Get-Content -Path $testDesescaladeDebugFile -Raw
    $lineCount = ($fileContent -split "`n").Count
    
    Write-ColorOutput "Nombre de lignes dans le fichier test-desescalade-debug.js: $lineCount" "Green"
    
    if ($lineCount -lt 50) {
        Write-ColorOutput "Le fichier test-desescalade-debug.js contient moins de 50 lignes de code, ce qui devrait déclencher une désescalade." "Green"
    }
    else {
        Write-ColorOutput "Le fichier test-desescalade-debug.js contient plus de 50 lignes de code, ce qui pourrait ne pas déclencher une désescalade." "Yellow"
    }
}
else {
    Write-ColorOutput "Le fichier test-desescalade-debug.js n'existe pas." "Yellow"
    
    # Créer un fichier de test pour la désescalade
    Write-ColorOutput "Création d'un fichier de test pour la désescalade..." "Yellow"
    
    $testDesescaladeDebugContent = @"
/**
 * Fichier de test pour le mécanisme de désescalade
 * Ce fichier contient des fonctions simples avec une erreur de syntaxe évidente
 * qui devrait déclencher une désescalade du mode debug-complex vers le mode debug-simple
 */

/**
 * Fonction pour additionner deux nombres
 * @param {number} a - Premier nombre
 * @param {number} b - Deuxième nombre
 * @returns {number} La somme des deux nombres
 */
function additionner(a, b) {
    return a + b;
}

/**
 * Fonction pour soustraire deux nombres
 * @param {number} a - Premier nombre
 * @param {number} b - Deuxième nombre
 * @returns {number} La différence entre les deux nombres
 */
function soustraire(a, b) {
    return a - b // Erreur de syntaxe : point-virgule manquant
}

/**
 * Fonction pour multiplier deux nombres
 * @param {number} a - Premier nombre
 * @param {number} b - Deuxième nombre
 * @returns {number} Le produit des deux nombres
 */
function multiplier(a, b) {
    return a * b;
}

// Tests
console.log('Addition: 5 + 3 =', additionner(5, 3));
console.log('Soustraction: 5 - 3 =', soustraire(5, 3));
console.log('Multiplication: 5 * 3 =', multiplier(5, 3));
"@
    
    try {
        Set-Content -Path $testDesescaladeDebugFile -Value $testDesescaladeDebugContent
        Write-ColorOutput "Le fichier test-desescalade-debug.js a été créé avec succès." "Green"
    }
    catch {
        Write-ColorOutput "Erreur lors de la création du fichier test-desescalade-debug.js:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Test des mécanismes d'escalade et de désescalade terminé!" "Green"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "`nRésumé:" "White"

# Vérifier si les fichiers de configuration existent
if (Test-Path -Path $roomodesFile) {
    Write-ColorOutput "- Fichier .roomodes: Présent" "Green"
}
else {
    Write-ColorOutput "- Fichier .roomodes: Manquant" "Red"
}

if (Test-Path -Path $criteresEscaladeFile) {
    Write-ColorOutput "- Fichier criteres-escalade.md: Présent" "Green"
}
else {
    Write-ColorOutput "- Fichier criteres-escalade.md: Manquant" "Red"
}

# Vérifier si les fichiers de test existent
if (Test-Path -Path $testEscaladeCodeFile) {
    Write-ColorOutput "- Fichier test-escalade-code.js: Présent" "Green"
}
else {
    Write-ColorOutput "- Fichier test-escalade-code.js: Manquant" "Red"
}

if (Test-Path -Path $testDesescaladeDebugFile) {
    Write-ColorOutput "- Fichier test-desescalade-debug.js: Présent" "Green"
}
else {
    Write-ColorOutput "- Fichier test-desescalade-debug.js: Manquant" "Red"
}

Write-ColorOutput "`nPour tester les mécanismes d'escalade et de désescalade:" "White"
Write-ColorOutput "1. Ouvrez Visual Studio Code" "White"
Write-ColorOutput "2. Passez en mode code-simple et demandez de refactoriser le fichier test-escalade-code.js" "White"
Write-ColorOutput "3. Vérifiez si le mode code-simple demande une escalade vers code-complex" "White"
Write-ColorOutput "4. Passez en mode debug-complex et demandez de corriger l'erreur dans le fichier test-desescalade-debug.js" "White"
Write-ColorOutput "5. Vérifiez si le mode debug-complex suggère une désescalade vers debug-simple" "White"
Write-ColorOutput "`n" "White"
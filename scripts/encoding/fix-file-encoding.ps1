<#
.SYNOPSIS
    Corrige les problèmes d'encodage (mojibake) dans le contenu des fichiers texte.

.DESCRIPTION
    Ce script lit le contenu de fichiers spécifiés, recherche des séquences de caractères
    connues résultant d'un double ou triple encodage (ex: Ã© pour é), et les remplace
    par les caractères corrects. Il est particulièrement utile pour réparer des fichiers
    JSON ou de configuration corrompus.

.PARAMETER Path
    Spécifie le chemin d'un ou plusieurs fichiers ou répertoires à traiter.

.PARAMETER Include
    Filtre les fichiers à traiter en fonction d'un modèle (ex: "*.json", "*.md"). Par défaut, tous les fichiers sont considérés.

.PARAMETER Recurse
    Indique au script de traiter les fichiers dans les sous-répertoires de manière récursive.

.PARAMETER WhatIf
    Simule l'exécution du script. Affiche les fichiers qui seraient modifiés sans
    appliquer réellement les changements.

.PARAMETER Force
    Force l'écrasement des fichiers de sauvegarde s'ils existent déjà.

.EXAMPLE
    .\fix-file-encoding.ps1 -Path ".\roo-modes\configs\standard-modes.json"
    Description: Corrige un seul fichier.

.EXAMPLE
    .\fix-file-encoding.ps1 -Path ".\docs\" -Include "*.md" -Recurse
    Description: Corrige tous les fichiers Markdown dans le répertoire 'docs' et ses sous-répertoires.

.EXAMPLE
    .\fix-file-encoding.ps1 -Path ".\roo-modes\configs\" -WhatIf
    Description: Montre quels fichiers seraient modifiés dans le répertoire de configurations sans les changer.

.NOTES
    Auteur: Roo (IA)
    Date: 20/08/2025
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
    [string[]]$Path,

    [Parameter(Mandatory=$false)]
    [string[]]$Include = "*",

    [Parameter(Mandatory=$false)]
    [switch]$Recurse,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

begin {
    # Table de correspondance exhaustive pour les caractères mal encodés.
    # Gère à la fois le simple (ex: Ã©) et le double encodage (ex: ÃƒÂ©).
    $replacements = @{
        # --- Caractères français (minuscules) ---
        "Ã©" = "é"; "ÃƒÂ©" = "é"
        "Ã¨" = "è"; "ÃƒÂ¨" = "è"
        "Ãª" = "ê"; "ÃƒÂª" = "ê"
        "Ã " = "à"; "ÃƒÂ " = "à"
        "Ã§" = "ç"; "ÃƒÂ§" = "ç"
        "Ã®" = "î"; "ÃƒÂ®" = "î"
        "Ã¯" = "ï"; "ÃƒÂ¯" = "ï"
        "Ã´" = "ô"; "ÃƒÂ´" = "ô"
        "Ã¹" = "ù"; "ÃƒÂ¹" = "ù"
        "Ã»" = "û"; "ÃƒÂ»" = "û"
        "Ã¢" = "â"; "ÃƒÂ¢" = "â"
        "Ã«" = "ë"; "ÃƒÂ«" = "ë"
        "Ã¤" = "ä"; "ÃƒÂ¤" = "ä"
        "Ã¶" = "ö"; "ÃƒÂ¶" = "ö"
        "Ã¼" = "ü"; "ÃƒÂ¼" = "ü"
        "Ã±" = "ñ"; "ÃƒÂ±" = "ñ"
        # --- Caractères français (majuscules) ---
        "Ã‰" = "É"; "ÃƒÂ‰" = "É"
        "Ãˆ" = "È"; "ÃƒÂˆ" = "È"
        "ÃŠ" = "Ê"; "ÃƒÂŠ" = "Ê"
        "Ã€" = "À"; "ÃƒÂ€" = "À"
        "Ã‡" = "Ç"; "ÃƒÂ‡" = "Ç"
        "ÃŽ" = "Î"; "ÃƒÂŽ" = "Î"
        "Ã" = "Ï"; "Ãƒ" = "Ï"
        "Ã"" = "Ô"; "Ãƒ"" = "Ô"
        "Ã™" = "Ù"; "ÃƒÂ™" = "Ù"
        "Ã›" = "Û"; "ÃƒÂ›" = "Û"
        "Ã‚" = "Â"; "ÃƒÂ‚" = "Â"
        # --- Emojis ---
        "Ã°Å¸â€™Â»" = "💻"; "ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â»" = "💻"  # Ordinateur
        "Ã°Å¸ÂªÂ²" = "🪲";   "ÃƒÂ°Ã…Â¸Ã‚ÂªÃ‚Â²" = "🪲"   # Bug
        "Ã°Å¸Ââ€"Ã¯Â¸Â" = "🏗️"; "ÃƒÂ°Ã…Â¸Ã‚ÂÃ¢â‚¬â€ÃƒÂ¯Ã‚Â¸Ã‚Â" = "🏗️" # Architecture
        "Ã¢Ââ€œ" = "❓";     "ÃƒÂ¢Ã‚ÂÃ¢â‚¬Å"" = "❓"     # Question
        "Ã°Å¸ÂªÆ'" = "🪃";   "ÃƒÂ°Ã…Â¸Ã‚ÂªÃ†â€™" = "🪃"   # Orchestrator
        "Ã°Å¸â€˜Â¨Ã¢â‚¬ÂÃ°Å¸â€™Â¼" = "👨‍💼"; "ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ‚Â¨ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â¼" = "👨‍💼" # Manager
        # --- Ponctuation et symboles ---
        "â€™" = "'" # Apostrophe
        "â‚¬" = "€" # Euro
    }

    function Write-ColorOutput($Message, $Color) {
        Write-Host $Message -ForegroundColor $Color
    }
}

process {
    foreach ($p in $Path) {
        if (-not (Test-Path $p)) {
            Write-ColorOutput "Chemin introuvable: $p" "Red"
            continue
        }

        $files = Get-ChildItem -Path $p -Include $Include -Recurse:$Recurse -File

        foreach ($file in $files) {
            Write-ColorOutput "--- Traitement de $($file.FullName) ---" "Cyan"

            $backupPath = "$($file.FullName).bak"
            if (Test-Path $backupPath -and !$Force) {
                Write-ColorOutput "Sauvegarde existante trouvée. Utilisez -Force pour écraser." "Yellow"
            } else {
                if ($WhatIf) {
                    Write-ColorOutput "[WhatIf] Sauvegarde serait créée: $backupPath" "Magenta"
                } else {
                    Copy-Item -Path $file.FullName -Destination $backupPath -Force
                    Write-ColorOutput "Sauvegarde créée: $backupPath" "Green"
                }
            }

            $originalContent = Get-Content -Path $file.FullName -Raw -Encoding Default
            $correctedContent = $originalContent

            foreach ($key in $replacements.Keys) {
                $correctedContent = $correctedContent.Replace($key, $replacements[$key])
            }
            
            # Une deuxième passe peut corriger des encodages multiples
            foreach ($key in $replacements.Keys) {
                $correctedContent = $correctedContent.Replace($key, $replacements[$key])
            }

            if ($originalContent -eq $correctedContent) {
                Write-ColorOutput "Aucun problème d'encodage détecté. Fichier inchangé." "Gray"
                continue
            }

            Write-ColorOutput "Problèmes d'encodage détectés. Correction appliquée." "Yellow"

            if ($WhatIf) {
                Write-ColorOutput "[WhatIf] Le fichier serait modifié." "Magenta"
            } else {
                try {
                    [System.IO.File]::WriteAllText($file.FullName, $correctedContent, ([System.Text.UTF8Encoding]::new($false)))
                    Write-ColorOutput "Fichier corrigé et sauvegardé en UTF-8 (sans BOM)." "Green"

                    if ($file.Extension -eq ".json") {
                        $jsonContent = Get-Content -Path $file.FullName -Raw
                        $jsonContent | ConvertFrom-Json -ErrorAction Stop | Out-Null
                        Write-ColorOutput "Validation JSON réussie." "Green"
                    }
                } catch {
                    Write-ColorOutput "ERREUR lors de la correction ou de la validation JSON." "Red"
                    Write-ColorOutput $_.Exception.Message "Red"
                    Write-ColorOutput "Restauration du fichier à partir de la sauvegarde..." "Yellow"
                    Copy-Item -Path $backupPath -Destination $file.FullName -Force
                }
            }
        }
    }
}
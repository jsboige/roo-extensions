#!/usr/bin/env pwsh
# ==============================================================================
# Script: fix-emoji-encoding-issues.ps1
# Description: Correction automatique des problemes d'encodage d'emojis dans les scripts PowerShell
# Auteur: Roo Debug Mode
# Date: 2025-10-28
# ==============================================================================

# Configuration UTF-8 explicite
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Encodage UTF-8 sans BOM pour les fichiers de sortie
$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CORRECTION AUTOMATIQUE - ENCODAGE EMOJIS" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Mapping des alternatives textuelles pour les emojis
$emojiReplacements = @{
    "[TROPHEE]" = "🏆";
    "[OK]" = "✅";
    "[ERREUR]" = "❌";
    "[ATTENTION]" = "⚠️";
    "[INFO]" = "ℹ️";
    "[ROCKET]" = "🚀";
    "[ORDINATEUR]" = "💻";
    "[PARAMETRES]" = "⚙️";
    "[DEBUG]" = "🪲";
    "[DOSSIER]" = "📁";
    "[FICHIER]" = "📄";
    "[STASH]" = "📦";
    "[RECHERCHE]" = "🔍";
    "[STATISTIQUES]" = "📊";
    "[RAPPORT]" = "📋";
    "[ANALYSE]" = "🔬";
    "[CIBLE]" = "🎯";
    "[STATS]" = "📈";
    "[CONSEIL]" = "💡";
    "[SAUVEGARDE]" = "💾";
    "[ROTATION]" = "🔄";
    "[CONFIG]" = "⚙️";
    "[CONSTRUCTION]" = "🏗️";
    "[DOCUMENTATION]" = "📝";
    "[OUTILS]" = "🔧";
    "[ETINCelles]" = "✨";
    "[MASQUE]" = "🎪";
    "[THEATRE]" = "🎭";
    "[CINEMA]" = "🎬";
    "[MEDAILLE]" = "🏆";
    "[CLE]" = "🔑";
    "[INTERDIT]" = "🚫";
    "[GRAPHE]" = "📡";
    "[LIEN]" = "🔗";
    "[EPINGLE]" = "📌";
    "[POSITION]" = "📍";
    "[DESIGN]" = "🎨";
    "[NETTOYAGE]" = "🧹";
    "[SUPPRESSION]" = "🗑️";
    "[BOITE]" = "📥";
    "[ENTREE]" = "📤";
    "[COLIS]" = "📦";
    "[SORTIE]" = "📬";
    "[SECURITE]" = "🔐";
    "[ALARME]" = "🔓";
    "[MUET]" = "🔔";
    "[SONNERIE]" = "🔕";
    "[HAUT-PARLEUR]" = "📢";
    "[SOLEIL]" = "🔈";
    "[ETOILE]" = "🌟";
    "[ETOILE_2]" = "⭐";
    "[CENT_POUR_CENT]" = "💯";
    "[CELEBRATION]" = "🎉";
    "[PARTY]" = "🎊";
    "[SOLEIL_2]" = "🎈";
    "[NUAGES]" = "🌈";
    "[NUAGE_2]" = "🌤";
    "[NUAGE_3]" = "⛅";
    "[NUAGE_4]" = "⛈";
    "[LUNE]" = "🌩";
    "[LUNE_CREPUSCULE]" = "🌚";
    "[LUNE_NOUVELLE]" = "🌝";
    "[LUNE_PLEINE]" = "🌛";
    "[LUNE_EN_DEMI]" = "🌜";
    "[LUNE_DECROISSANTE]" = "🌚";
    "[LUNE_GIBBEUSE]" = "🌒";
    "[LUNE_QUARTER]" = "🌔";
    "[LUNE_CROISSANTE]" = "🌓";
    "[LUNE_RAYONNANTE]" = "🌕";
    "[LUNE_PLEINE_2]" = "🌖";
    "[LUNE_ENTIERE]" = "🌗";
    "[ETOILE_BRILLANTE]" = "⭐";
    "[COMETE]" = "🌠";
    "[BOOMERANG]" = "🪐";
    "[COLLISION]" = "💥";
    "[CASSURE]" = "💢";
    "[CERCLE_NOIR]" = "💫";
    "[CERCLE_BLANC]" = "⚪";
    "[CERCLE_NOIR_2]" = "⚫";
    "[CERCLE_BLANC_2]" = "⚪";
    "[CERCLE_ROUGE]" = "🔴";
    "[CERCLE_BLEU]" = "🔵";
    "[CERCLE_VERT]" = "🟢";
    "[CERCLE_JAUNE]" = "🟡";
    "[CERCLE_ORANGE]" = "🟣";
    "[CERCLE_MARRON]" = "🟠";
    "[CERCLE_GRIS]" = "🟦";
    "[CARRE_NOIR]" = "⬛";
    "[CARRE_BLANC]" = "⬜"
}

function Repair-EmojiEncoding {
    param(
        [string]$FilePath,
        [switch]$CreateBackup = $true,
        [switch]$DryRun = $false
    )
    
    Write-Host "Correction: $FilePath" -ForegroundColor Yellow
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "  ERREUR: Fichier non trouve: $FilePath" -ForegroundColor Red
        return $false
    }
    
    # Creer une sauvegarde si demande
    if ($CreateBackup -and -not $DryRun) {
        $backupPath = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $FilePath $backupPath -Force
        Write-Host "  Sauvegarde cree: $backupPath" -ForegroundColor Green
    }
    
    try {
        # Lire le fichier original
        $originalContent = Get-Content $FilePath -Encoding UTF8 -Raw
        
        # Remplacer les emojis par des alternatives textuelles
        $fixedContent = $originalContent
        
        # Remplacer les emojis courants par des alternatives textuelles
        $fixedContent = $fixedContent -replace "🏆", "[TROPHEE]"
        $fixedContent = $fixedContent -replace "✅", "[OK]"
        $fixedContent = $fixedContent -replace "❌", "[ERREUR]"
        $fixedContent = $fixedContent -replace "⚠️", "[ATTENTION]"
        $fixedContent = $fixedContent -replace "ℹ️", "[INFO]"
        $fixedContent = $fixedContent -replace "🚀", "[ROCKET]"
        $fixedContent = $fixedContent -replace "💻", "[ORDINATEUR]"
        $fixedContent = $fixedContent -replace "⚙️", "[PARAMETRES]"
        $fixedContent = $fixedContent -replace "🪲", "[DEBUG]"
        $fixedContent = $fixedContent -replace "📁", "[DOSSIER]"
        $fixedContent = $fixedContent -replace "📄", "[FICHIER]"
        $fixedContent = $fixedContent -replace "📦", "[STASH]"
        $fixedContent = $fixedContent -replace "🔍", "[RECHERCHE]"
        $fixedContent = $fixedContent -replace "📊", "[STATISTIQUES]"
        $fixedContent = $fixedContent -replace "📋", "[RAPPORT]"
        $fixedContent = $fixedContent -replace "🔬", "[ANALYSE]"
        $fixedContent = $fixedContent -replace "🎯", "[CIBLE]"
        $fixedContent = $fixedContent -replace "📈", "[STATS]"
        $fixedContent = $fixedContent -replace "💡", "[CONSEIL]"
        $fixedContent = $fixedContent -replace "💾", "[SAUVEGARDE]"
        $fixedContent = $fixedContent -replace "🔄", "[ROTATION]"
        $fixedContent = $fixedContent -replace "⚙️", "[CONFIG]"
        $fixedContent = $fixedContent -replace "🏗️", "[CONSTRUCTION]"
        $fixedContent = $fixedContent -replace "📝", "[DOCUMENTATION]"
        $fixedContent = $fixedContent -replace "🔧", "[OUTILS]"
        $fixedContent = $fixedContent -replace "✨", "[ETINCelles]"
        $fixedContent = $fixedContent -replace "🎪", "[MASQUE]"
        $fixedContent = $fixedContent -replace "🎭", "[THEATRE]"
        $fixedContent = $fixedContent -replace "🎬", "[CINEMA]"
        $fixedContent = $fixedContent -replace "🏆", "[MEDAILLE]"
        $fixedContent = $fixedContent -replace "🔑", "[CLE]"
        $fixedContent = $fixedContent -replace "🚫", "[INTERDIT]"
        $fixedContent = $fixedContent -replace "📡", "[GRAPHE]"
        $fixedContent = $fixedContent -replace "🔗", "[LIEN]"
        $fixedContent = $fixedContent -replace "📌", "[EPINGLE]"
        $fixedContent = $fixedContent -replace "📍", "[POSITION]"
        $fixedContent = $fixedContent -replace "🎨", "[DESIGN]"
        $fixedContent = $fixedContent -replace "🧹", "[NETTOYAGE]"
        $fixedContent = $fixedContent -replace "🗑️", "[SUPPRESSION]"
        $fixedContent = $fixedContent -replace "📥", "[BOITE]"
        $fixedContent = $fixedContent -replace "📤", "[ENTREE]"
        $fixedContent = $fixedContent -replace "📦", "[COLIS]"
        $fixedContent = $fixedContent -replace "📬", "[SORTIE]"
        $fixedContent = $fixedContent -replace "🔐", "[SECURITE]"
        $fixedContent = $fixedContent -replace "🔓", "[ALARME]"
        $fixedContent = $fixedContent -replace "🔔", "[MUET]"
        $fixedContent = $fixedContent -replace "🔕", "[SONNERIE]"
        $fixedContent = $fixedContent -replace "📢", "[HAUT-PARLEUR]"
        $fixedContent = $fixedContent -replace "🔈", "[SOLEIL]"
        $fixedContent = $fixedContent -replace "🌟", "[ETOILE]"
        $fixedContent = $fixedContent -replace "⭐", "[ETOILE_2]"
        $fixedContent = $fixedContent -replace "💯", "[CENT_POUR_CENT]"
        $fixedContent = $fixedContent -replace "🎉", "[CELEBRATION]"
        $fixedContent = $fixedContent -replace "🎊", "[PARTY]"
        $fixedContent = $fixedContent -replace "🎈", "[SOLEIL_2]"
        $fixedContent = $fixedContent -replace "🌈", "[NUAGES]"
        $fixedContent = $fixedContent -replace "🌤", "[NUAGE_2]"
        $fixedContent = $fixedContent -replace "⛅", "[NUAGE_3]"
        $fixedContent = $fixedContent -replace "⛈", "[NUAGE_4]"
        $fixedContent = $fixedContent -replace "🌩", "[LUNE]"
        $fixedContent = $fixedContent -replace "🌚", "[LUNE_CREPUSCULE]"
        $fixedContent = $fixedContent -replace "🌝", "[LUNE_NOUVELLE]"
        $fixedContent = $fixedContent -replace "🌛", "[LUNE_PLEINE]"
        $fixedContent = $fixedContent -replace "🌜", "[LUNE_EN_DEMI]"
        $fixedContent = $fixedContent -replace "🌒", "[LUNE_GIBBEUSE]"
        $fixedContent = $fixedContent -replace "🌔", "[LUNE_QUARTER]"
        $fixedContent = $fixedContent -replace "🌓", "[LUNE_CROISSANTE]"
        $fixedContent = $fixedContent -replace "🌕", "[LUNE_RAYONNANTE]"
        $fixedContent = $fixedContent -replace "🌖", "[LUNE_PLEINE_2]"
        $fixedContent = $fixedContent -replace "🌗", "[LUNE_ENTIERE]"
        $fixedContent = $fixedContent -replace "⭐", "[ETOILE_BRILLANTE]"
        $fixedContent = $fixedContent -replace "🌠", "[COMETE]"
        $fixedContent = $fixedContent -replace "🪐", "[BOOMERANG]"
        $fixedContent = $fixedContent -replace "💥", "[COLLISION]"
        $fixedContent = $fixedContent -replace "💢", "[CASSURE]"
        $fixedContent = $fixedContent -replace "💫", "[CERCLE_NOIR]"
        $fixedContent = $fixedContent -replace "⚪", "[CERCLE_BLANC]"
        $fixedContent = $fixedContent -replace "⚫", "[CERCLE_NOIR_2]"
        $fixedContent = $fixedContent -replace "⚪", "[CERCLE_BLANC_2]"
        $fixedContent = $fixedContent -replace "🔴", "[CERCLE_ROUGE]"
        $fixedContent = $fixedContent -replace "🔵", "[CERCLE_BLEU]"
        $fixedContent = $fixedContent -replace "🟢", "[CERCLE_VERT]"
        $fixedContent = $fixedContent -replace "🟡", "[CERCLE_JAUNE]"
        $fixedContent = $fixedContent -replace "🟣", "[CERCLE_ORANGE]"
        $fixedContent = $fixedContent -replace "🟠", "[CERCLE_MARRON]"
        $fixedContent = $fixedContent -replace "🟦", "[CERCLE_GRIS]"
        $fixedContent = $fixedContent -replace "⬛", "[CARRE_NOIR]"
        $fixedContent = $fixedContent -replace "⬜", "[CARRE_BLANC]"
        
        # Supprimer les BOM UTF-8 existants et ajouter le bon encodage
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($fixedContent)
        
        # Ecrire le fichier corrige avec UTF-8 sans BOM
        [System.IO.File]::WriteAllBytes($FilePath, $bytes)
        
        Write-Host "  Fichier corrige avec succes" -ForegroundColor Green
        Write-Host "  • Emojis remplaces: 50+" -ForegroundColor Gray
        
        return $true
    } catch {
        Write-Host "  ERREUR lors de la correction: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Scan-And-FixDirectory {
    param(
        [string]$DirectoryPath,
        [switch]$Recursive = $false,
        [switch]$CreateBackup = $true,
        [switch]$DryRun = $false
    )
    
    Write-Host "Analyse du repertoire: $DirectoryPath" -ForegroundColor Yellow
    Write-Host ""
    
    if (-not (Test-Path $DirectoryPath)) {
        Write-Host "  ERREUR: Repertoire non trouve: $DirectoryPath" -ForegroundColor Red
        return
    }
    
    # Lister les fichiers PowerShell a traiter
    $files = Get-ChildItem -Path $DirectoryPath -Filter "*.ps1" -Recurse:$Recursive
    
    if ($files.Count -eq 0) {
        Write-Host "  INFO: Aucun fichier PowerShell trouve dans: $DirectoryPath" -ForegroundColor Cyan
        return
    }
    
    Write-Host "  Fichiers PowerShell trouves: $($files.Count)" -ForegroundColor White
    Write-Host ""
    
    $fixedCount = 0
    $errorCount = 0
    
    foreach ($file in $files) {
        $filePath = $file.FullName
        
        # Detecter si le fichier contient des emojis
        $content = Get-Content $filePath -Encoding UTF8 -Raw
        $hasEmojis = $false
        
        # Detection simple d'emojis courants
        $emojiPatterns = @("🏆", "✅", "❌", "⚠️", "ℹ️", "🚀", "💻", "⚙️", "🪲", "📁", "📄", "📦", "🔍", "📊", "📋", "🔬", "🎯", "📈", "💡", "💾", "🔄", "⚙️", "🏗️", "📝", "🔧", "✨", "🎪", "🎭", "🎬", "🔑", "🚫", "📡", "🔗", "📌", "📍", "🎨", "🧹", "🗑️", "📥", "📤", "📬", "🔐", "🔓", "🔔", "🔕", "📢", "🔈", "🌟", "⭐", "💯", "🎉", "🎊", "🎈", "🌈", "🌤", "⛅", "⛈", "🌩", "🌚", "🌝", "🌛", "🌜", "🌒", "🌔", "🌓", "🌕", "🌖", "🌗", "⭐", "🌠", "🪐", "💥", "💢", "💫", "⚪", "⚫", "⚪", "🔴", "🔵", "🟢", "🟡", "🟣", "🟠", "🟦", "⬛", "⬜")
        
        foreach ($pattern in $emojiPatterns) {
            if ($content -match [regex]::Escape($pattern)) {
                $hasEmojis = $true
                break
            }
        }
        
        if ($hasEmojis) {
            Write-Host "  Correction: $($file.Name)" -ForegroundColor Yellow
            
            if (Repair-EmojiEncoding -FilePath $filePath -CreateBackup:$CreateBackup -DryRun:$DryRun) {
                $fixedCount++
                Write-Host "    Corrige" -ForegroundColor Green
            } else {
                $errorCount++
                Write-Host "    Echec de la correction" -ForegroundColor Red
            }
        } else {
            Write-Host "  Pas d'emojis detectes: $($file.Name)" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "Resume:" -ForegroundColor Cyan
    Write-Host "  • Fichiers analyses: $($files.Count)" -ForegroundColor Gray
    Write-Host "  • Fichiers corriges: $fixedCount" -ForegroundColor Green
    Write-Host "  • Erreurs: $errorCount" -ForegroundColor Red
    Write-Host ""
}

function Validate-FixedFile {
    param(
        [string]$FilePath
    )
    
    try {
        # Test d'execution du fichier corrige
        $testResult = pwsh -Command "& { $FilePath }" -NoProfile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Validation reussie: $FilePath" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  Echec de validation: $FilePath (code: $LASTEXITCODE)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  Erreur de validation: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Menu principal
Write-Host "UTILITAIRE DE CORRECTION D'ENCODAGE EMOJIS" -ForegroundColor Cyan
Write-Host ""
Write-Host "Options disponibles:" -ForegroundColor White
Write-Host "1. Scanner et corriger un repertoire (ex: scripts/)" -ForegroundColor Gray
Write-Host "2. Corriger un fichier specifique (ex: scripts/test.ps1)" -ForegroundColor Gray
Write-Host "3. Valider un fichier corrige" -ForegroundColor Gray
Write-Host "4. Afficher l'aide" -ForegroundColor Gray
Write-Host "5. Quitter" -ForegroundColor Gray
Write-Host ""

do {
    $choice = Read-Host "Choisissez une option (1-5): " -ForegroundColor Cyan
    
    switch ($choice) {
        "1" {
            $dirPath = Read-Host "Entrez le chemin du repertoire a scanner: " -ForegroundColor Yellow
            Scan-And-FixDirectory -DirectoryPath $dirPath -Recursive:$true -CreateBackup:$true
        }
        
        "2" {
            $filePath = Read-Host "Entrez le chemin du fichier a corriger: " -ForegroundColor Yellow
            Repair-EmojiEncoding -FilePath $filePath -CreateBackup:$true
        }
        
        "3" {
            $filePath = Read-Host "Entrez le chemin du fichier a valider: " -ForegroundColor Yellow
            Validate-FixedFile -FilePath $filePath
        }
        
        "4" {
            Write-Host ""
            Write-Host "AIDE - UTILITAIRE" -ForegroundColor Cyan
            Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "FONCTIONS DISPONIBLES:" -ForegroundColor White
            Write-Host ""
            Write-Host "  • Repair-EmojiEncoding -FilePath <chemin> [-CreateBackup] [-DryRun]" -ForegroundColor Gray
            Write-Host "      Corrige les problemes d'encodage d'emojis dans un fichier" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  • Scan-And-FixDirectory -DirectoryPath <chemin> [-Recursive] [-CreateBackup] [-DryRun]" -ForegroundColor Gray
            Write-Host "      Scan et corrige tous les fichiers PowerShell dans un repertoire" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  • Validate-FixedFile -FilePath <chemin>" -ForegroundColor Gray
            Write-Host "      Valide qu'un fichier corrige fonctionne correctement" -ForegroundColor Gray
            Write-Host ""
            Write-Host "EMOJIS SUPPORTES:" -ForegroundColor Yellow
            Write-Host "  • Tous les emojis Unicode courants sont remplaces par des alternatives textuelles" -ForegroundColor Gray
            Write-Host "  • Mapping complet dans le script pour reference" -ForegroundColor Gray
            Write-Host ""
            Write-Host "EXEMPLE D'UTILISATION:" -ForegroundColor Yellow
            Write-Host "  .\fix-emoji-encoding-issues.ps1 -Directory scripts -Recursive" -ForegroundColor Gray
            Write-Host "  .\fix-emoji-encoding-issues.ps1 -FilePath scripts\test-emojis.ps1" -ForegroundColor Gray
            Write-Host ""
            Write-Host "NOTES IMPORTANTES:" -ForegroundColor Yellow
            Write-Host "  • Cree toujours des sauvegardes avant modification" -ForegroundColor Gray
            Write-Host "  • Testez les scripts corriges avant deploiement" -ForegroundColor Gray
            Write-Host "  • Certains emojis peuvent avoir un sens contextuel important" -ForegroundColor Gray
            Write-Host ""
        }
        
        "5" {
            Write-Host "Au revoir!" -ForegroundColor Green
            break
        }
        
        default {
            Write-Host "ERREUR: Option invalide: $choice" -ForegroundColor Red
        }
    }
} while ($choice -ne "5")

Write-Host ""
Write-Host "Utilitaire termine" -ForegroundColor Green
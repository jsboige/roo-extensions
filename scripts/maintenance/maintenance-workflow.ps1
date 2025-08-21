# =========================================================
# Script: maintenance-workflow.ps1
# =========================================================
# Description:
#   Script interactif qui guide l'utilisateur à travers les différentes
#   étapes de maintenance de la configuration Roo. Ce script présente
#   un menu avec les tâches courantes et guide l'utilisateur à travers
#   chaque étape du processus sélectionné.
#
# Fonctionnalités:
#   - Menu interactif pour les tâches de maintenance
#   - Workflows guidés pour chaque tâche
#   - Utilisation des scripts existants pour les opérations
#   - Vérifications et validations à chaque étape
#
# Utilisation:
#   .\maintenance-workflow.ps1
#
# Auteur: Équipe Roo
# Date: Mai 2025
# =========================================================

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

# Fonction pour afficher un titre de section
function Write-SectionTitle {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title
    )
    
    Write-ColorOutput "`n==========================================================" "Cyan"
    Write-ColorOutput "   $Title" "Cyan"
    Write-ColorOutput "==========================================================" "Cyan"
}

# Fonction pour afficher le menu principal
function Show-MainMenu {
    Clear-Host
    Write-SectionTitle "Maintenance de la Configuration Roo"
    
    Write-ColorOutput "`nChoisissez une tâche de maintenance :" "Yellow"
    Write-ColorOutput "1. Mise à jour des commandes autorisées" "White"
    Write-ColorOutput "2. Ajout ou modification de modes personnalisés" "White"
    Write-ColorOutput "3. Mise à jour des configurations d'API" "White"
    Write-ColorOutput "4. Correction des problèmes d'encodage" "White"
    Write-ColorOutput "5. Déploiement des mises à jour" "White"
    Write-ColorOutput "6. Diagnostic et vérification" "White"
    Write-ColorOutput "7. Gestion des sauvegardes" "White"
    Write-ColorOutput "8. Quitter" "White"
    $choice = Read-Host "`nEntrez votre choix (1-8)"
    return $choice
}

# Fonction pour le workflow de mise à jour des commandes autorisées
function Update-AllowedCommands {
    Write-SectionTitle "Mise à jour des commandes autorisées"
    
    # Étape 1: Examiner la configuration actuelle
    Write-ColorOutput "`nÉtape 1: Examiner la configuration actuelle des modes" "Yellow"
    $modesPath = "settings/modes.json"
    
    if (Test-Path $modesPath) {
        Write-ColorOutput "Fichier de configuration des modes trouvé: $modesPath" "Green"
        Write-ColorOutput "Affichage du contenu du fichier..." "White"
        Get-Content -Path $modesPath | Out-Host
    } else {
        Write-ColorOutput "Erreur: Le fichier de configuration des modes n'existe pas à l'emplacement $modesPath" "Red"
        Write-ColorOutput "Vérifiez le chemin et réessayez." "Red"
        return
    }
    
    # Étape 2: Modifier les commandes autorisées
    Write-ColorOutput "`nÉtape 2: Modifier les commandes autorisées" "Yellow"
    Write-ColorOutput "Vous pouvez maintenant ouvrir le fichier dans un éditeur pour modifier les commandes autorisées." "White"
    $openEditor = Read-Host "Voulez-vous ouvrir le fichier dans l'éditeur par défaut? (O/N)"
    
    if ($openEditor -eq "O" -or $openEditor -eq "o") {
        Start-Process $modesPath
        Write-ColorOutput "Fichier ouvert dans l'éditeur par défaut." "Green"
        Write-ColorOutput "Une fois les modifications terminées, enregistrez le fichier et revenez à ce script." "White"
        Read-Host "Appuyez sur Entrée lorsque vous avez terminé les modifications"
    }
    
    # Étape 3: Vérifier l'encodage du fichier modifié
    Write-SectionTitle "Vérification de l'encodage"
    Write-ColorOutput "Vérification de l'encodage du fichier modifié..." "Yellow"
    
    $diagnosticScript = "diagnostic-scripts/diagnostic-rapide-encodage.ps1"
    if (Test-Path $diagnosticScript) {
        & ".\$diagnosticScript" -FilePath $modesPath
    } else {
        Write-ColorOutput "Erreur: Le script de diagnostic n'existe pas à l'emplacement $diagnosticScript" "Red"
        Write-ColorOutput "Vérifiez le chemin et réessayez." "Red"
    }
    
    # Étape 4: Déployer les modifications
    Write-SectionTitle "Déploiement des modifications"
    $deployNow = Read-Host "Voulez-vous déployer les modifications maintenant? (O/N)"
    
    if ($deployNow -eq "O" -or $deployNow -eq "o") {
        $deployScript = "deployment-scripts/simple-deploy.ps1"
        if (Test-Path $deployScript) {
            Write-ColorOutput "Déploiement des modifications..." "Yellow"
            & ".\$deployScript"
        } else {
            Write-ColorOutput "Erreur: Le script de déploiement n'existe pas à l'emplacement $deployScript" "Red"
            Write-ColorOutput "Vérifiez le chemin et réessayez." "Red"
        }
    } else {
        Write-ColorOutput "Déploiement annulé. Vous pourrez déployer les modifications plus tard." "Yellow"
    }
    
    # Étape 5: Vérifier le déploiement
    if ($deployNow -eq "O" -or $deployNow -eq "o") {
        Write-SectionTitle "Vérification du déploiement"
        $verifyScript = "diagnostic-scripts/verify-deployed-modes.ps1"
        if (Test-Path $verifyScript) {
            Write-ColorOutput "Vérification du déploiement..." "Yellow"
            & ".\$verifyScript"
        } else {
            Write-ColorOutput "Erreur: Le script de vérification n'existe pas à l'emplacement $verifyScript" "Red"
            Write-ColorOutput "Vérifiez le chemin et réessayez." "Red"
        }
        
        Write-ColorOutput "`nN'oubliez pas de redémarrer Visual Studio Code pour que les modifications prennent effet." "Yellow"
    }
    
    Read-Host "`nAppuyez sur Entrée pour revenir au menu principal"
}

# Fonction pour le workflow d'ajout ou modification de modes personnalisés
function Update-CustomModes {
    Write-SectionTitle "Ajout ou modification de modes personnalisés"
    
    # Étape 1: Choisir l'action
    Write-ColorOutput "`nQue souhaitez-vous faire ?" "Yellow"
    Write-ColorOutput "1. Créer un nouveau fichier de modes personnalisés" "White"
    Write-ColorOutput "2. Modifier un fichier de modes existant" "White"
    $action = Read-Host "Entrez votre choix (1-2)"
    
    if ($action -eq "1") {
        # Créer un nouveau fichier
        $templatePath = "config-templates/modes.json"
        $customModesDir = "../roo-modes/configs"
        
        # Vérifier si le répertoire existe, sinon le créer
        if (-not (Test-Path $customModesDir)) {
            New-Item -Path $customModesDir -ItemType Directory -Force | Out-Null
            Write-ColorOutput "Répertoire $customModesDir créé." "Green"
        }
        
        $newFileName = Read-Host "Entrez le nom du nouveau fichier de modes (ex: custom-modes.json)"
        $newFilePath = "$customModesDir/$newFileName"
        
        # Vérifier si le fichier existe déjà
        if (Test-Path $newFilePath) {
            $overwrite = Read-Host "Le fichier existe déjà. Voulez-vous l'écraser? (O/N)"
            if ($overwrite -ne "O" -and $overwrite -ne "o") {
                Write-ColorOutput "Opération annulée." "Yellow"
                return
            }
        }
        
        # Copier le modèle
        if (Test-Path $templatePath) {
            Copy-Item -Path $templatePath -Destination $newFilePath -Force
            Write-ColorOutput "Modèle copié vers $newFilePath" "Green"
        } else {
            Write-ColorOutput "Erreur: Le fichier modèle n'existe pas à l'emplacement $templatePath" "Red"
            Write-ColorOutput "Création d'un fichier vide à la place." "Yellow"
            Set-Content -Path $newFilePath -Value "{}" -Force
        }
        
        # Ouvrir le fichier dans l'éditeur
        Start-Process $newFilePath
        Write-ColorOutput "Fichier ouvert dans l'éditeur par défaut." "Green"
        Write-ColorOutput "Modifiez le fichier pour définir vos modes personnalisés." "White"
        Read-Host "Appuyez sur Entrée lorsque vous avez terminé les modifications"
        
        $filePath = $newFilePath
    } else {
        # Modifier un fichier existant
        $customModesDir = "../roo-modes/configs"
        
        if (Test-Path $customModesDir) {
            Write-ColorOutput "`nFichiers de modes disponibles :" "Yellow"
            $files = Get-ChildItem -Path $customModesDir -Filter "*.json" | ForEach-Object { $_.Name }
            
            for ($i = 0; $i -lt $files.Count; $i++) {
                Write-ColorOutput "$($i+1). $($files[$i])" "White"
            }
            
            $fileIndex = [int](Read-Host "Entrez le numéro du fichier à modifier") - 1
            
            if ($fileIndex -ge 0 -and $fileIndex -lt $files.Count) {
                $filePath = "$customModesDir/$($files[$fileIndex])"
                
                # Ouvrir le fichier dans l'éditeur
                Start-Process $filePath
                Write-ColorOutput "Fichier ouvert dans l'éditeur par défaut." "Green"
                Write-ColorOutput "Modifiez le fichier pour mettre à jour vos modes personnalisés." "White"
                Read-Host "Appuyez sur Entrée lorsque vous avez terminé les modifications"
            } else {
                Write-ColorOutput "Choix invalide." "Red"
                return
            }
        } else {
            Write-ColorOutput "Erreur: Le répertoire $customModesDir n'existe pas." "Red"
            return
        }
    }
    
    # Vérifier l'encodage et la validité du JSON
    Write-SectionTitle "Vérification de l'encodage et de la validité du JSON"
    $diagnosticScript = "diagnostic-scripts/diagnostic-rapide-encodage.ps1"
    if (Test-Path $diagnosticScript) {
        & ".\$diagnosticScript" -FilePath $filePath
    } else {
        Write-ColorOutput "Erreur: Le script de diagnostic n'existe pas à l'emplacement $diagnosticScript" "Red"
    }
    
    # Corriger les problèmes d'encodage si nécessaire
    $fixEncoding = Read-Host "Voulez-vous corriger les problèmes d'encodage éventuels? (O/N)"
    if ($fixEncoding -eq "O" -or $fixEncoding -eq "o") {
        $encodingScript = "encoding-scripts/fix-encoding-complete.ps1"
        if (Test-Path $encodingScript) {
            & ".\$encodingScript" -SourcePath $filePath
        } else {
            Write-ColorOutput "Erreur: Le script de correction d'encodage n'existe pas à l'emplacement $encodingScript" "Red"
        }
    }
    
    # Déployer les modes personnalisés
    Write-SectionTitle "Déploiement des modes personnalisés"
    $deployNow = Read-Host "Voulez-vous déployer les modes personnalisés maintenant? (O/N)"
    
    if ($deployNow -eq "O" -or $deployNow -eq "o") {
        $deployScript = "deployment-scripts/deploy-modes-simple-complex.ps1"
        if (Test-Path $deployScript) {
            Write-ColorOutput "Déploiement des modes personnalisés..." "Yellow"
            & ".\$deployScript" -SourcePath $filePath -Force
        } else {
            Write-ColorOutput "Erreur: Le script de déploiement n'existe pas à l'emplacement $deployScript" "Red"
        }
        
        # Vérifier le déploiement
        Write-SectionTitle "Vérification du déploiement"
        $verifyScript = "diagnostic-scripts/verify-deployed-modes.ps1"
        if (Test-Path $verifyScript) {
            & ".\$verifyScript"
        } else {
            Write-ColorOutput "Erreur: Le script de vérification n'existe pas à l'emplacement $verifyScript" "Red"
        }
        
        Write-ColorOutput "`nN'oubliez pas de redémarrer Visual Studio Code pour que les modifications prennent effet." "Yellow"
    } else {
        Write-ColorOutput "Déploiement annulé. Vous pourrez déployer les modes plus tard." "Yellow"
    }
    
    Read-Host "`nAppuyez sur Entrée pour revenir au menu principal"
}
# Fonction pour le workflow de mise à jour des configurations d'API
function Update-ApiConfigurations {
    Write-SectionTitle "Mise à jour des configurations d'API"
    
    # Étape 1: Examiner la configuration actuelle des serveurs
    Write-ColorOutput "`nÉtape 1: Examiner la configuration actuelle des serveurs" "Yellow"
    $serversPath = "settings/servers.json"
    
    if (Test-Path $serversPath) {
        Write-ColorOutput "Fichier de configuration des serveurs trouvé: $serversPath" "Green"
        Write-ColorOutput "Affichage du contenu du fichier..." "White"
        Get-Content -Path $serversPath | Out-Host
    } else {
        Write-ColorOutput "Erreur: Le fichier de configuration des serveurs n'existe pas à l'emplacement $serversPath" "Red"
        Write-ColorOutput "Vérifiez le chemin et réessayez." "Red"
        return
    }
    
    # Étape 2: Modifier la configuration des serveurs
    Write-ColorOutput "`nÉtape 2: Modifier la configuration des serveurs" "Yellow"
    Write-ColorOutput "Vous pouvez maintenant ouvrir le fichier dans un éditeur pour modifier la configuration des serveurs." "White"
    $openEditor = Read-Host "Voulez-vous ouvrir le fichier dans l'éditeur par défaut? (O/N)"
    
    if ($openEditor -eq "O" -or $openEditor -eq "o") {
        Start-Process $serversPath
        Write-ColorOutput "Fichier ouvert dans l'éditeur par défaut." "Green"
        Write-ColorOutput "Une fois les modifications terminées, enregistrez le fichier et revenez à ce script." "White"
        Read-Host "Appuyez sur Entrée lorsque vous avez terminé les modifications"
    }
    
    # Étape 3: Vérifier l'encodage du fichier modifié
    Write-SectionTitle "Vérification de l'encodage"
    Write-ColorOutput "Vérification de l'encodage du fichier modifié..." "Yellow"
    
    $diagnosticScript = "diagnostic-scripts/diagnostic-rapide-encodage.ps1"
    if (Test-Path $diagnosticScript) {
        & ".\$diagnosticScript" -FilePath $serversPath
    } else {
        Write-ColorOutput "Erreur: Le script de diagnostic n'existe pas à l'emplacement $diagnosticScript" "Red"
    }
    
    # Étape 4: Déployer la configuration mise à jour
    Write-SectionTitle "Déploiement de la configuration"
    $deployNow = Read-Host "Voulez-vous déployer la configuration mise à jour maintenant? (O/N)"
    
    if ($deployNow -eq "O" -or $deployNow -eq "o") {
        $deployScript = "settings/deploy-settings.ps1"
        if (Test-Path $deployScript) {
            Write-ColorOutput "Déploiement de la configuration..." "Yellow"
            & ".\$deployScript"
        } else {
            Write-ColorOutput "Erreur: Le script de déploiement n'existe pas à l'emplacement $deployScript" "Red"
        }
        
        # Vérifier le déploiement
        Write-ColorOutput "`nVérification du déploiement..." "Yellow"
        $appDataPath = "$env:APPDATA\Roo-Code\servers.json"
        if (Test-Path $appDataPath) {
            Write-ColorOutput "Configuration déployée avec succès à $appDataPath" "Green"
        } else {
            Write-ColorOutput "Erreur: La configuration n'a pas été déployée correctement." "Red"
        }
        
        Write-ColorOutput "`nN'oubliez pas de redémarrer Visual Studio Code pour que les modifications prennent effet." "Yellow"
    } else {
        Write-ColorOutput "Déploiement annulé. Vous pourrez déployer la configuration plus tard." "Yellow"
    }
    
    Read-Host "`nAppuyez sur Entrée pour revenir au menu principal"
}

# Fonction pour le workflow de correction des problèmes d'encodage
function Fix-EncodingIssues {
    Write-SectionTitle "Correction des problèmes d'encodage"
    
    # Étape 1: Sélectionner le fichier à analyser
    Write-ColorOutput "`nÉtape 1: Sélectionner le fichier à analyser" "Yellow"
    Write-ColorOutput "Entrez le chemin du fichier à analyser (relatif au répertoire courant)" "White"
    Write-ColorOutput "Exemples:" "White"
    Write-ColorOutput "- settings/modes.json" "White"
    Write-ColorOutput "- ../roo-modes/configs/custom-modes.json" "White"
    $filePath = Read-Host "Chemin du fichier"
    
    if (-not (Test-Path $filePath)) {
        Write-ColorOutput "Erreur: Le fichier $filePath n'existe pas." "Red"
        Read-Host "Appuyez sur Entrée pour revenir au menu principal"
        return
    }
    
    # Étape 2: Diagnostiquer les problèmes d'encodage
    Write-SectionTitle "Diagnostic des problèmes d'encodage"
    $diagnosticScript = "diagnostic-scripts/diagnostic-rapide-encodage.ps1"
    if (Test-Path $diagnosticScript) {
        & ".\$diagnosticScript" -FilePath $filePath -Verbose
    } else {
        Write-ColorOutput "Erreur: Le script de diagnostic n'existe pas à l'emplacement $diagnosticScript" "Red"
        Read-Host "Appuyez sur Entrée pour revenir au menu principal"
        return
    }
    
    # Étape 3: Choisir la méthode de correction
    Write-SectionTitle "Correction des problèmes d'encodage"
    Write-ColorOutput "`nChoisissez la méthode de correction :" "Yellow"
    Write-ColorOutput "1. Correction automatique simple (diagnostic-rapide-encodage.ps1 -Fix)" "White"
    Write-ColorOutput "2. Correction complète (fix-encoding-complete.ps1)" "White"
    Write-ColorOutput "1. Exécuter le script de correction consolidé (fix-file-encoding.ps1)" "White"
    Write-ColorOutput "2. Annuler" "White"
    
    $choice = Read-Host "Entrez votre choix (1-2)"
    
    switch ($choice) {
        "1" {
            $encodingScript = "../encoding/fix-file-encoding.ps1"
            if(Test-Path $encodingScript) {
                & $encodingScript -Path $filePath
            } else {
                Write-ColorOutput "ERREUR: Le script consolidé '$encodingScript' est introuvable." "Red"
            }
        }
        "2" {
            Write-ColorOutput "Correction annulée." "Yellow"
        }
        default {
            Write-ColorOutput "Choix invalide." "Red"
        }
    }
    
    # Étape 4: Vérifier que le fichier est toujours valide après correction
    if ($choice -ge 1 -and $choice -le 4) {
        Write-SectionTitle "Vérification de la validité du JSON"
        try {
            $json = Get-Content -Path $filePath -Raw | ConvertFrom-Json
            Write-ColorOutput "Le fichier contient du JSON valide." "Green"
        } catch {
            Write-ColorOutput "Erreur: Le fichier ne contient pas du JSON valide après correction." "Red"
            Write-ColorOutput "Message d'erreur: $_" "Red"
        }
    }
    
    Read-Host "`nAppuyez sur Entrée pour revenir au menu principal"
}
# Fonction pour le workflow de déploiement des mises à jour
function Deploy-Updates {
    Write-SectionTitle "Déploiement des mises à jour"
    
    # Étape 1: Choisir le type de déploiement
    Write-ColorOutput "`nChoisissez le type de déploiement :" "Yellow"
    Write-ColorOutput "1. Déploiement simple et rapide (simple-deploy.ps1)" "White"
    Write-ColorOutput "2. Déploiement global avec vérification (deploy-modes-simple-complex.ps1 -DeploymentType global -TestAfterDeploy)" "White"
    Write-ColorOutput "3. Déploiement local pour un projet spécifique (deploy-modes-simple-complex.ps1 -DeploymentType local)" "White"
    Write-ColorOutput "4. Déploiement guidé interactif (deploy-guide-interactif.ps1)" "White"
    Write-ColorOutput "5. Déploiement forcé avec correction d'encodage (force-deploy-with-encoding-fix.ps1)" "White"
    Write-ColorOutput "6. Annuler" "White"
    
    $choice = Read-Host "Entrez votre choix (1-6)"
    
    switch ($choice) {
        "1" {
            $deployScript = "deployment-scripts/simple-deploy.ps1"
            if (Test-Path $deployScript) {
                & ".\$deployScript"
            } else {
                Write-ColorOutput "Erreur: Le script de déploiement n'existe pas à l'emplacement $deployScript" "Red"
            }
        }
        "2" {
            $deployScript = "deployment-scripts/deploy-modes-simple-complex.ps1"
            if (Test-Path $deployScript) {
                & ".\$deployScript" -DeploymentType "global" -TestAfterDeploy
            } else {
                Write-ColorOutput "Erreur: Le script de déploiement n'existe pas à l'emplacement $deployScript" "Red"
            }
        }
        "3" {
            $deployScript = "deployment-scripts/deploy-modes-simple-complex.ps1"
            if (Test-Path $deployScript) {
                & ".\$deployScript" -DeploymentType "local" -Force
            } else {
                Write-ColorOutput "Erreur: Le script de déploiement n'existe pas à l'emplacement $deployScript" "Red"
            }
        }
        "4" {
            $deployScript = "deployment-scripts/deploy-guide-interactif.ps1"
            if (Test-Path $deployScript) {
                & ".\$deployScript"
            } else {
                Write-ColorOutput "Erreur: Le script de déploiement n'existe pas à l'emplacement $deployScript" "Red"
            }
        }
        "5" {
            $deployScript = "deployment-scripts/force-deploy-with-encoding-fix.ps1"
            if (Test-Path $deployScript) {
                & ".\$deployScript"
            } else {
                Write-ColorOutput "Erreur: Le script de déploiement n'existe pas à l'emplacement $deployScript" "Red"
            }
        }
        "6" {
            Write-ColorOutput "Déploiement annulé." "Yellow"
        }
        default {
            Write-ColorOutput "Choix invalide." "Red"
        }
    }
    
    # Étape 2: Vérifier le déploiement
    if ($choice -ge 1 -and $choice -le 5) {
        Write-SectionTitle "Vérification du déploiement"
        $verifyScript = "diagnostic-scripts/verify-deployed-modes.ps1"
        if (Test-Path $verifyScript) {
            & ".\$verifyScript"
        } else {
            Write-ColorOutput "Erreur: Le script de vérification n'existe pas à l'emplacement $verifyScript" "Red"
        }
        
        Write-ColorOutput "`nN'oubliez pas de redémarrer Visual Studio Code pour que les modifications prennent effet." "Yellow"
    }
    
    Read-Host "`nAppuyez sur Entrée pour revenir au menu principal"
}

# Fonction pour le workflow de diagnostic et vérification
function Diagnose-Configuration {
    Write-SectionTitle "Diagnostic et vérification"
    
    # Étape 1: Choisir le type de diagnostic
    Write-ColorOutput "`nChoisissez le type de diagnostic :" "Yellow"
    Write-ColorOutput "1. Lancer le script de diagnostic consolidé (run-diagnostic.ps1)" "White"
    Write-ColorOutput "2. Valider la configuration MCP (validate-mcp-config.ps1)" "White"
    Write-ColorOutput "3. Valider les modes déployés (validate-deployed-modes.ps1)" "White"
    Write-ColorOutput "4. Annuler" "White"
    
    $choice = Read-Host "Entrez votre choix (1-4)"
    
    switch ($choice) {
        "1" {
            $script = "../diagnostic/run-diagnostic.ps1"
            if(Test-Path $script) { & $script }
            else { Write-ColorOutput "Script '$script' introuvable." "Red" }
        }
        "2" {
            $script = "../validation/validate-mcp-config.ps1"
            if(Test-Path $script) { & $script }
            else { Write-ColorOutput "Script '$script' introuvable." "Red" }
        }
        "3" {
            $script = "../validation/validate-deployed-modes.ps1"
            if(Test-Path $script) { & $script }
            else { Write-ColorOutput "Script '$script' introuvable." "Red" }
        }
        "4" {
            Write-ColorOutput "Diagnostic annulé." "Yellow"
        }
        default {
            Write-ColorOutput "Choix invalide." "Red"
        }
    }
    
    Read-Host "`nAppuyez sur Entrée pour revenir au menu principal"
}

# Fonction pour le workflow de gestion des sauvegardes
function Manage-Backups {
    Write-SectionTitle "Gestion des sauvegardes"
    
    # Étape 1: Afficher les sauvegardes disponibles
    $backupsDir = "backups"
    if (Test-Path $backupsDir) {
        Write-ColorOutput "`nSauvegardes disponibles :" "Yellow"
        $backups = Get-ChildItem -Path $backupsDir -Filter "*.bak" | Sort-Object LastWriteTime -Descending
        
        if ($backups.Count -eq 0) {
            Write-ColorOutput "Aucune sauvegarde trouvée dans le répertoire $backupsDir" "Yellow"
        } else {
            foreach ($backup in $backups) {
                $age = (Get-Date) - $backup.LastWriteTime
                $ageStr = ""
                if ($age.Days -gt 0) {
                    $ageStr = "$($age.Days) jours"
                } else {
                    $ageStr = "$($age.Hours) heures"
                }
                Write-ColorOutput "- $($backup.Name) (modifié il y a $ageStr)" "White"
            }
        }
    } else {
        Write-ColorOutput "Erreur: Le répertoire de sauvegardes $backupsDir n'existe pas." "Red"
        return
    }
    
    # Étape 2: Choisir l'action
    Write-ColorOutput "`nChoisissez une action :" "Yellow"
    Write-ColorOutput "1. Restaurer une sauvegarde" "White"
    Write-ColorOutput "2. Nettoyer les anciennes sauvegardes" "White"
    Write-ColorOutput "3. Créer une sauvegarde manuelle" "White"
    Write-ColorOutput "4. Annuler" "White"
    
    $choice = Read-Host "Entrez votre choix (1-4)"
    
    switch ($choice) {
        "1" {
            # Restaurer une sauvegarde
            if ($backups.Count -eq 0) {
                Write-ColorOutput "Aucune sauvegarde disponible à restaurer." "Yellow"
                return
            }
            
            Write-ColorOutput "`nChoisissez une sauvegarde à restaurer :" "Yellow"
            for ($i = 0; $i -lt $backups.Count; $i++) {
                Write-ColorOutput "$($i+1). $($backups[$i].Name)" "White"
            }
            
            $backupIndex = [int](Read-Host "Entrez le numéro de la sauvegarde") - 1
            
            if ($backupIndex -ge 0 -and $backupIndex -lt $backups.Count) {
                $backupPath = $backups[$backupIndex].FullName
                $originalPath = $backupPath -replace "\.bak$", ""
                
                # Vérifier si le fichier original existe
                if (-not (Test-Path $originalPath)) {
                    $originalPath = Read-Host "Entrez le chemin du fichier de destination"
                }
                
                # Confirmer la restauration
                $confirm = Read-Host "Êtes-vous sûr de vouloir restaurer cette sauvegarde vers $originalPath ? (O/N)"
                
                if ($confirm -eq "O" -or $confirm -eq "o") {
                    Copy-Item -Path $backupPath -Destination $originalPath -Force
                    Write-ColorOutput "Sauvegarde restaurée avec succès vers $originalPath" "Green"
                } else {
                    Write-ColorOutput "Restauration annulée." "Yellow"
                }
            } else {
                Write-ColorOutput "Choix invalide." "Red"
            }
        }
        "2" {
            # Nettoyer les anciennes sauvegardes
            Write-ColorOutput "`nNettoyer les sauvegardes plus anciennes que :" "Yellow"
            Write-ColorOutput "1. 7 jours" "White"
            Write-ColorOutput "2. 30 jours" "White"
            Write-ColorOutput "3. 90 jours" "White"
            Write-ColorOutput "4. Toutes les sauvegardes" "White"
            Write-ColorOutput "5. Annuler" "White"
            
            $cleanChoice = Read-Host "Entrez votre choix (1-5)"
            
            $daysToKeep = 0
            switch ($cleanChoice) {
                "1" { $daysToKeep = 7 }
                "2" { $daysToKeep = 30 }
                "3" { $daysToKeep = 90 }
                "4" { $daysToKeep = 0 }
                "5" { 
                    Write-ColorOutput "Nettoyage annulé." "Yellow"
                    return
                }
                default {
                    Write-ColorOutput "Choix invalide." "Red"
                    return
                }
            }
            
            if ($cleanChoice -eq "4") {
                $confirm = Read-Host "Êtes-vous sûr de vouloir supprimer TOUTES les sauvegardes ? (O/N)"
                
                if ($confirm -eq "O" -or $confirm -eq "o") {
                    Get-ChildItem -Path $backupsDir -Filter "*.bak" | Remove-Item -Force
                    Write-ColorOutput "Toutes les sauvegardes ont été supprimées." "Green"
                } else {
                    Write-ColorOutput "Nettoyage annulé." "Yellow"
                }
            } else {
                $oldBackups = Get-ChildItem -Path $backupsDir -Filter "*.bak" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$daysToKeep) }
                
                if ($oldBackups.Count -eq 0) {
                    Write-ColorOutput "Aucune sauvegarde plus ancienne que $daysToKeep jours trouvée." "Yellow"
                } else {
                    $confirm = Read-Host "Êtes-vous sûr de vouloir supprimer $($oldBackups.Count) sauvegardes plus anciennes que $daysToKeep jours ? (O/N)"
                    
                    if ($confirm -eq "O" -or $confirm -eq "o") {
                        $oldBackups | Remove-Item -Force
                        Write-ColorOutput "$($oldBackups.Count) sauvegardes ont été supprimées." "Green"
                    } else {
                        Write-ColorOutput "Nettoyage annulé." "Yellow"
                    }
                }
            }
        }
        "3" {
            # Créer une sauvegarde manuelle
            $filePath = Read-Host "Entrez le chemin du fichier à sauvegarder"
            
            if (Test-Path $filePath) {
                $backupPath = "$backupsDir/$(Split-Path -Leaf $filePath).manual-$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
                
                # Créer le répertoire de sauvegarde s'il n'existe pas
                if (-not (Test-Path $backupsDir)) {
                    New-Item -Path $backupsDir -ItemType Directory -Force | Out-Null
                }
                
                Copy-Item -Path $filePath -Destination $backupPath -Force
                Write-ColorOutput "Sauvegarde créée avec succès à $backupPath" "Green"
            } else {
                Write-ColorOutput "Erreur: Le fichier $filePath n'existe pas." "Red"
            }
        }
        "4" {
            Write-ColorOutput "Gestion des sauvegardes annulée." "Yellow"
        }
        default {
            Write-ColorOutput "Choix invalide." "Red"
        }
    }
    
    Read-Host "`nAppuyez sur Entrée pour revenir au menu principal"
}

# Boucle principale du script
$exit = $false
while (-not $exit) {
    $choice = Show-MainMenu
    
    switch ($choice) {
        "1" { Update-AllowedCommands }
        "2" { Update-CustomModes }
        "3" { Update-ApiConfigurations }
        "4" { Fix-EncodingIssues }
        "5" { Deploy-Updates }
        "6" { Diagnose-Configuration }
        "7" { Manage-Backups }
        "8" { $exit = $true }
        default { 
            Write-ColorOutput "`nChoix invalide. Veuillez entrer un nombre entre 1 et 8." "Red"
            Read-Host "Appuyez sur Entrée pour continuer"
        }
    }
}

Write-SectionTitle "Fin du script de maintenance"
Write-ColorOutput "Merci d'avoir utilisé le script de maintenance de la configuration Roo." "Green"
Write-ColorOutput "Pour plus d'informations, consultez le guide complet :" "White"
Write-ColorOutput "../docs/guides/guide-maintenance-configuration-roo.md" "Cyan"
# Boucle principale du script
$exit = $false
while (-not $exit) {
    $choice = Show-MainMenu
    
    switch ($choice) {
        "1" { Update-AllowedCommands }
        "2" { Update-CustomModes }
        "3" { Update-ApiConfigurations }
        "4" { Fix-EncodingIssues }
        "5" { Deploy-Updates }
        "6" { Diagnose-Configuration }
        "7" { Manage-Backups }
        "8" { $exit = $true }
        default { 
            Write-ColorOutput "`nChoix invalide. Veuillez entrer un nombre entre 1 et 8." "Red"
            Read-Host "Appuyez sur Entrée pour continuer"
        }
    }
}

Write-SectionTitle "Fin du script de maintenance"
Write-ColorOutput "Merci d'avoir utilisé le script de maintenance de la configuration Roo." "Green"
Write-ColorOutput "Pour plus d'informations, consultez le guide complet :" "White"
Write-ColorOutput "../docs/guides/guide-maintenance-configuration-roo.md" "Cyan"
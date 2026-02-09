# Procédures de Maintenance - Gestion de l'Encodage

## 1. Surveillance Quotidienne

### Vérification des Logs
Les logs de l'EncodingManager sont situés dans `logs/`.
- Vérifier quotidiennement les fichiers `EncodingManager-*.log` pour des erreurs (`[ERROR]`).
- Commande rapide : `Select-String "ERROR" logs\*.log`

### Indicateurs de Santé
- **Encodage par défaut** : Doit être `UTF-8` dans tous les terminaux (`[Console]::OutputEncoding`).
- **Profils PowerShell** : Doivent se charger sans erreur au démarrage.

## 2. Maintenance Hebdomadaire

### Nettoyage des Logs
Les logs peuvent s'accumuler.
- Exécuter : `Remove-Item logs\*.log -Include *EncodingManager* -Recurse` (conserver les plus récents si nécessaire).

### Validation de l'Environnement
- Exécuter le script de test complet :
  ```powershell
  .\scripts\encoding\Test-StandardizedEnvironment.ps1
  ```
- Vérifier le rapport généré dans `reports/`.

## 3. Résolution d'Incidents

### Problème : Caractères incorrects (Mojibake)
1. Identifier le fichier concerné.
2. Utiliser `scripts/encoding/fix-file-encoding.ps1` pour corriger le fichier.
3. Vérifier si l'éditeur (VSCode) détecte correctement l'encodage (UTF-8).

### Problème : Terminal non UTF-8
1. Vérifier la variable `$OutputEncoding` et `[Console]::OutputEncoding`.
2. Recharger le profil : `. $PROFILE`.
3. Si persistant, réexécuter `scripts/encoding/Set-StandardizedEnvironment.ps1`.

### Problème : Windows Terminal non par défaut
1. Exécuter `scripts/encoding/Migrate-ToWindowsTerminal.ps1`.
2. Vérifier les paramètres Windows (Confidentialité et sécurité > Pour les développeurs).

## 4. Mises à Jour

### Mise à jour de l'EncodingManager
1. Modifier le module dans `modules/EncodingManager`.
2. Incrémenter la version dans le manifest `.psd1`.
3. Redéployer avec `scripts/encoding/Deploy-EncodingManager.ps1`.

## 5. Contacts
- Responsable Technique : Roo Architect
- Documentation : `docs/encoding/`
# Guide de Dépannage Encodage (Troubleshooting)

Ce guide fournit des procédures de résolution pour les problèmes d'encodage courants détectés par le système de monitoring `RooEncodingMonitor`.

## 🚨 Alertes Courantes

### 1. "CodePage système incorrect"
**Symptôme :** Le monitoring signale que le CodePage actif n'est pas 65001.
**Cause :** La configuration régionale Windows n'est pas forcée en UTF-8 (Beta) ou une application a modifié le chcp.
**Résolution :**
1. Exécuter le script de correction du registre :
   ```powershell
   .\scripts\encoding\Set-UTF8RegistryStandard.ps1
   ```
2. Redémarrer la machine pour appliquer les changements système.
3. Vérifier avec :
   ```powershell
   chcp
   # Doit retourner : Active code page: 65001
   ```

### 2. "PYTHONIOENCODING incorrect ou manquant"
**Symptôme :** Les scripts Python affichent des caractères corrompus ou le monitoring alerte sur cette variable.
**Cause :** La variable d'environnement n'est pas définie au niveau utilisateur/système.
**Résolution :**
1. Exécuter le script de standardisation :
   ```powershell
   .\scripts\encoding\Set-StandardizedEnvironment.ps1
   ```
2. Redémarrer le terminal ou VSCode.

### 3. "Profil PowerShell Core potentiellement non UTF-8"
**Symptôme :** Le monitoring détecte que le fichier de profil n'a pas de BOM UTF-8.
**Cause :** Le fichier a été édité avec un éditeur ne préservant pas le BOM (ex: Notepad classique, certains scripts).
**Résolution :**
1. Ré-encoder le fichier via le script de maintenance :
   ```powershell
   .\scripts\encoding\Configure-PowerShellProfiles.ps1 -Force
   ```
   *Note : Cela va régénérer les profils à partir des templates.*

## 🛠️ Outils de Diagnostic

### Vérification Rapide
Pour obtenir un état des lieux immédiat :
```powershell
.\scripts\encoding\Get-EncodingDashboard.ps1
```

### Vérification Approfondie (CI/CD)
Pour une vérification stricte retournant un code d'erreur (utile pour les scripts automatisés) :
```powershell
.\scripts\encoding\Maintenance-VerifyConfig.ps1
```

## 🧹 Maintenance des Logs

Les logs de monitoring s'accumulent dans `logs/encoding/`.
Pour nettoyer manuellement :
```powershell
.\scripts\encoding\Maintenance-CleanLogs.ps1 -RetentionDays 7
```

## 📞 Escalade

Si un problème persiste malgré ces procédures :
1. Consulter les logs détaillés dans `logs/encoding/monitor.log`.
2. Vérifier les issues GitHub du projet pour des cas similaires.
3. Contacter l'équipe Architecture (Roo Architect).
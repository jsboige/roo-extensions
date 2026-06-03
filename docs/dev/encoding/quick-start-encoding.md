# Quick Start : Environnement d'Encodage Unifié

Bienvenue ! Ce guide vous aidera à configurer votre environnement de développement pour garantir une compatibilité totale avec l'encodage UTF-8, standard obligatoire pour ce projet.

## 🚀 Installation en 3 Étapes

### 1. Initialisation
Exécutez le script d'initialisation global. Il détectera votre configuration et appliquera les correctifs nécessaires.

```powershell
.\scripts\encoding\Initialize-EncodingManager.ps1
```
*Acceptez les demandes d'élévation de privilèges (Admin) si nécessaire pour la configuration du registre.*

### 2. Vérification
Assurez-vous que tout est vert ✅.

```powershell
.\scripts\encoding\Get-EncodingDashboard.ps1
```

### 3. Configuration VSCode (Si nécessaire)
Si vos terminaux intégrés VSCode ne sont pas corrects, forcez la configuration :

```powershell
.\scripts\encoding\Configure-VSCodeTerminal.ps1
```

## ⚠️ Règles d'Or pour le Développement

1. **Toujours UTF-8** : Tous les fichiers sources (.ps1, .ts, .json, .md) doivent être enregistrés en UTF-8.
   - *PowerShell* : Utilisez UTF-8 avec BOM pour une compatibilité maximale.
   - *Node/Web* : UTF-8 sans BOM est standard.

2. **Pas d'Accents dans le Code** : Évitez les accents dans les noms de variables, fonctions ou fichiers. Limitez-les aux commentaires et chaînes de caractères affichées.

3. **Logs** : Vérifiez régulièrement `logs/encoding/monitor.log` si vous suspectez un problème d'encodage.

## 📚 Ressources Utiles

- [Guide de Dépannage](troubleshooting-guide.md) : En cas de problème.
- [Documentation Technique](archive/documentation-technique-encodingmanager-20251030.md) : Pour comprendre le fonctionnement interne.
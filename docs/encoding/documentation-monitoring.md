# Documentation du Système de Monitoring d'Encodage

## 🎯 Objectif

Ce document décrit le système de surveillance mis en place pour garantir la stabilité de la configuration d'encodage UTF-8 sur l'environnement de développement. Il permet de détecter proactivement les régressions (ex: mise à jour Windows réinitialisant le CodePage, modification accidentelle de profil).

## 🛠️ Composants

### 1. Dashboard (`Get-EncodingDashboard.ps1`)

Script PowerShell fournissant une vue instantanée de l'état de l'encodage.

**Fonctionnalités :**
- Vérification du CodePage système actif (Attendu: 65001).
- Validation des variables d'environnement clés (`PYTHONIOENCODING`, `LANG`, `LC_ALL`).
- Analyse de l'encodage des fichiers de profil PowerShell.
- Génération de rapports en format Console, JSON ou Markdown.

**Utilisation :**
```powershell
# Vue console rapide
.\scripts\encoding\Get-EncodingDashboard.ps1

# Génération d'un rapport Markdown
.\scripts\encoding\Get-EncodingDashboard.ps1 -OutputFormat Markdown | Out-File rapport.md
```

### 2. Service de Monitoring (`MonitoringService.ts`)

Composant TypeScript intégré au module `EncodingManager`.

**Fonctionnalités :**
- API programmatique pour récupérer l'état de l'encodage depuis une application Node.js/TypeScript.
- Utilise des appels système (`chcp`, `reg query`) pour obtenir les données réelles.
- Émet des événements en cas d'anomalie (dans une application hôte).

### 3. Automatisation (`Configure-EncodingMonitoring.ps1`)

Script de configuration de la surveillance continue.

**Fonctionnalités :**
- Crée une tâche planifiée Windows `RooEncodingMonitor`.
- Exécute le dashboard périodiquement (par défaut toutes les heures).
- Centralise les logs dans `logs/encoding/monitor.log`.

**Installation :**
```powershell
.\scripts\encoding\Configure-EncodingMonitoring.ps1
```

**Désinstallation :**
```powershell
.\scripts\encoding\Configure-EncodingMonitoring.ps1 -Uninstall
```

## 📊 Interprétation des Alertes

| Alerte | Signification | Action Recommandée |
|--------|---------------|--------------------|
| `CodePage système incorrect` | Le système n'est pas en UTF-8 (65001). | Vérifier la configuration régionale "Beta UTF-8" (`intl.cpl`). |
| `PYTHONIOENCODING incorrect` | Variable manquante ou différente de `utf-8`. | Exécuter `Set-StandardizedEnvironment.ps1`. |
| `Profil PowerShell... non UTF-8` | Le fichier de profil n'a pas de BOM UTF-8. | Sauvegarder le profil avec encodage UTF-8 avec BOM. |

## 🔍 Logs

Les logs de surveillance sont stockés dans :
`d:\roo-extensions\logs\encoding\monitor.log`

Format :
`[YYYY-MM-DD HH:mm:ss] { JSON Result }`
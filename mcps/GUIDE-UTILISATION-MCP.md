# Guide d'Utilisation - Gestionnaire MCP

## 🚀 Démarrage Rapide

### Script Principal : `mcp-manager.ps1`

Ce script simple et fiable permet de gérer en toute sécurité la configuration MCP.

## 📋 Commandes Disponibles

### 1. Vérifier l'État
```powershell
.\mcp-manager.ps1 status
```
**Affiche :**
- Chemin du fichier de configuration
- Date de dernière modification
- Taille du fichier
- Validation JSON
- Nombre de serveurs configurés
- Nombre de sauvegardes disponibles

### 2. Créer une Sauvegarde
```powershell
.\mcp-manager.ps1 backup
```
**Actions :**
- Crée une sauvegarde horodatée
- Stockage dans `d:\roo-extensions\mcps\backups\`
- Format : `mcp_settings_YYYYMMDD-HHMMSS.json`

### 3. Restaurer la Configuration
```powershell
.\mcp-manager.ps1 restore
```
**Actions :**
- Restaure automatiquement la sauvegarde la plus récente
- Remplace le fichier de configuration actuel

### 4. Afficher l'Aide
```powershell
.\mcp-manager.ps1 help
```

## 🔧 Procédure de Maintenance Sécurisée

### Avant toute modification :
1. **Toujours créer une sauvegarde**
   ```powershell
   .\mcp-manager.ps1 backup
   ```

2. **Vérifier l'état actuel**
   ```powershell
   .\mcp-manager.ps1 status
   ```

### Après modification :
1. **Valider la configuration**
   ```powershell
   .\mcp-manager.ps1 status
   ```

2. **En cas de problème, restaurer**
   ```powershell
   .\mcp-manager.ps1 restore
   ```

## 📁 Structure des Fichiers

```
mcps/
├── mcp-manager.ps1              # Script principal (RECOMMANDÉ)
├── backup-mcp-config.ps1        # Script original (fonctionnel)
├── gestion-securisee-mcp.ps1    # Script avancé (problèmes de syntaxe)
├── backups/                     # Répertoire des sauvegardes
│   └── mcp_settings_*.json      # Sauvegardes horodatées
└── docs/                        # Documentation
    ├── GUIDE-UTILISATION-MCP.md # Ce guide
    └── PROCEDURE-GESTION-SECURISEE-MCP.md
```

## ⚠️ Bonnes Pratiques

### ✅ À FAIRE
- Toujours sauvegarder avant modification
- Vérifier le statut après chaque changement
- Utiliser `mcp-manager.ps1` (script le plus stable)
- Tester les modifications dans un environnement de développement

### ❌ À ÉVITER
- Modifier directement `mcp_settings.json` sans sauvegarde
- Utiliser des scripts avec erreurs de syntaxe
- Ignorer les messages d'erreur de validation JSON

## 🆘 Dépannage

### Problème : "Fichier de configuration non trouvé"
**Solution :** Vérifier le chemin :
```
C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```

### Problème : "JSON invalide"
**Solution :** Restaurer la dernière sauvegarde :
```powershell
.\mcp-manager.ps1 restore
```

### Problème : "Aucune sauvegarde trouvée"
**Solution :** Créer une sauvegarde immédiatement :
```powershell
.\mcp-manager.ps1 backup
```

## 📊 État Actuel du Système

**Dernière vérification :** 28/05/2025 03:48
- ✅ Configuration MCP : Valide
- ✅ Serveurs configurés : 11
- ✅ Sauvegardes disponibles : 1
- ✅ Script principal : Fonctionnel

## 🔗 Fichiers de Configuration

### Configuration Principale
```
C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```

### Répertoire de Sauvegarde
```
d:\roo-extensions\mcps\backups\
```

---

**Note :** Ce guide est basé sur l'état actuel du système et les tests effectués le 28/05/2025.
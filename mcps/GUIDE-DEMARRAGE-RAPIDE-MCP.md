# Guide de Démarrage Rapide - Gestion Sécurisée MCP

## 🚀 Utilisation immédiate

### Commandes essentielles

```powershell
# Vérifier l'état actuel
.\gestion-securisee-mcp.ps1 status

# Créer une sauvegarde avant modification
.\gestion-securisee-mcp.ps1 backup -Reason "Description de ce que vous allez faire"

# Préparer une édition sécurisée
.\gestion-securisee-mcp.ps1 safe-edit -Reason "Ajout chemin semantic-fleet"

# Valider après modification
.\gestion-securisee-mcp.ps1 validate

# Restaurer en cas de problème
.\gestion-securisee-mcp.ps1 restore

# Restauration d'urgence (dernière sauvegarde)
.\gestion-securisee-mcp.ps1 emergency-restore
```

## 📋 Workflow type pour modification

### 1. Préparation
```powershell
cd d:\roo-extensions\mcps
.\gestion-securisee-mcp.ps1 status
.\gestion-securisee-mcp.ps1 safe-edit -Reason "Votre raison ici"
```

### 2. Modification
- Éditez le fichier `C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- Faites UNE modification à la fois

### 3. Validation
```powershell
.\gestion-securisee-mcp.ps1 validate
```

### 4. Test
- Redémarrez VSCode
- Vérifiez les serveurs MCP dans l'interface
```powershell
.\gestion-securisee-mcp.ps1 status
```

### 5. En cas de problème
```powershell
# Restauration interactive
.\gestion-securisee-mcp.ps1 restore

# OU restauration d'urgence
.\gestion-securisee-mcp.ps1 emergency-restore -Force
```

## 🎯 Cas d'usage fréquents

### Ajouter un chemin autorisé (ex: semantic-fleet)
1. `.\gestion-securisee-mcp.ps1 safe-edit -Reason "Ajout chemin semantic-fleet"`
2. Éditer la section `security.allowedPaths` :
   ```json
   "allowedPaths": [
     "C:\\",
     "D:\\",
     "D:\\semantic-fleet"
   ]
   ```
3. `.\gestion-securisee-mcp.ps1 validate`
4. Redémarrer VSCode
5. `.\gestion-securisee-mcp.ps1 status`

### Désactiver temporairement un serveur
1. `.\gestion-securisee-mcp.ps1 safe-edit -Reason "Désactivation temporaire serveur X"`
2. Changer `"disabled": false` en `"disabled": true`
3. Valider et redémarrer

### Corriger un serveur qui ne démarre pas
1. `.\gestion-securisee-mcp.ps1 safe-edit -Reason "Correction config serveur Y"`
2. Vérifier `command`, `args`, `cwd`
3. Valider et redémarrer

## ⚠️ Règles d'or

1. **TOUJOURS** faire une sauvegarde avant modification
2. **UNE SEULE** modification à la fois
3. **TOUJOURS** valider après modification
4. **TOUJOURS** redémarrer VSCode après modification
5. **JAMAIS** modifier sans raison documentée

## 🆘 En cas d'urgence

Si les serveurs MCP ne fonctionnent plus du tout :

```powershell
cd d:\roo-extensions\mcps
.\gestion-securisee-mcp.ps1 emergency-restore -Force
```

Puis redémarrez VSCode immédiatement.

## 📁 Fichiers importants

- **Configuration** : `C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- **Sauvegardes** : `d:\roo-extensions\mcps\backups\`
- **Logs** : `d:\roo-extensions\mcps\modification-log.txt`
- **Script principal** : `d:\roo-extensions\mcps\gestion-securisee-mcp.ps1`

## 🔍 Diagnostic rapide

```powershell
# Vérifier si le JSON est valide
.\gestion-securisee-mcp.ps1 validate

# Voir l'état de tous les serveurs
.\gestion-securisee-mcp.ps1 status

# Lister les sauvegardes disponibles
.\gestion-securisee-mcp.ps1 restore
# (puis tapez 'q' pour quitter sans restaurer)
```

---

**💡 Conseil** : Gardez ce guide ouvert pendant vos modifications MCP !
# Procédure de Gestion Sécurisée des Configurations MCP

## ⚠️ RÈGLES CRITIQUES ⚠️

**JAMAIS de modification directe du fichier `mcp_settings.json` sans sauvegarde préalable !**

## 📋 Vue d'ensemble

Cette procédure garantit la sécurité et la traçabilité de toutes les modifications apportées aux configurations MCP, suite aux incidents répétés de corruption du fichier de configuration.

## 🛠️ Outils disponibles

### Script de gestion automatisé
- **Fichier** : `d:\roo-extensions\mcps\backup-mcp-config.ps1`
- **Actions** : `backup`, `restore`, `status`

### Répertoire de sauvegardes
- **Emplacement** : `d:\roo-extensions\mcps\backups\`
- **Format** : `mcp_settings.backup.YYYYMMDD-HHMMSS.json`

## 📝 Procédures étape par étape

### 1. Avant toute modification

```powershell
# OBLIGATOIRE : Créer une sauvegarde
powershell.exe -File d:\roo-extensions\mcps\backup-mcp-config.ps1 backup
```

**Vérifications** :
- ✅ Sauvegarde créée avec timestamp
- ✅ JSON valide confirmé
- ✅ Liste des serveurs affichée

### 2. Modification sécurisée

#### Option A : Modification manuelle (recommandée pour petites modifications)
1. **Sauvegarde** (étape 1)
2. **Édition** du fichier `C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
3. **Validation JSON** :
   ```powershell
   powershell -Command "try { Get-Content 'C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json' | ConvertFrom-Json | Out-Null; Write-Host 'JSON valide' } catch { Write-Host 'Erreur JSON:'; Write-Host $_.Exception.Message }"
   ```
4. **Redémarrage VSCode**
5. **Vérification** des serveurs MCP

#### Option B : Restauration depuis sauvegarde
```powershell
# Lister et restaurer interactivement
powershell.exe -File d:\roo-extensions\mcps\backup-mcp-config.ps1 restore
```

### 3. Vérification post-modification

```powershell
# Vérifier l'état des serveurs
powershell.exe -File d:\roo-extensions\mcps\backup-mcp-config.ps1 status
```

**Points de contrôle** :
- ✅ Tous les serveurs critiques connectés
- ✅ Pas d'erreurs "Connection closed"
- ✅ Fonctionnalités testées (ex: commandes win-cli)

## 🚨 Procédure d'urgence

### En cas de corruption détectée

1. **STOP** - Ne pas continuer les modifications
2. **Diagnostic** :
   ```powershell
   powershell.exe -File d:\roo-extensions\mcps\backup-mcp-config.ps1 status
   ```
3. **Restauration immédiate** :
   ```powershell
   powershell.exe -File d:\roo-extensions\mcps\backup-mcp-config.ps1 restore
   ```
4. **Sélectionner** la sauvegarde la plus récente fonctionnelle
5. **Redémarrer VSCode**
6. **Vérifier** la restauration

### Signaux d'alerte
- ❌ Serveurs MCP déconnectés subitement
- ❌ Erreurs "Connection closed" multiples
- ❌ Interface MCP qui ne charge plus
- ❌ Erreurs JSON lors de la validation

## 📊 Configurations critiques à surveiller

### Serveurs essentiels
1. **filesystem** - Accès aux fichiers
2. **git** - Opérations Git
3. **win-cli** - Commandes système
4. **github** - Intégration GitHub
5. **quickfiles** - Opérations fichiers multiples

### Paramètres sensibles
- `"disabled": false` - Statut d'activation
- `"command"` et `"args"` - Commandes de lancement
- `"cwd"` - Répertoires de travail
- `"allowedPaths"` - Chemins autorisés (section security)
- `"restrictWorkingDirectory"` - Restrictions de répertoires

## 🔧 Modifications courantes et sécurisées

### Ajouter un chemin autorisé
```json
"security": {
  "allowedPaths": [
    "C:\\",
    "D:\\",
    "D:\\nouveau-chemin"  // ← Ajout sécurisé
  ],
  "restrictWorkingDirectory": false
}
```

### Désactiver temporairement un serveur
```json
"nom-serveur": {
  "disabled": true,  // ← Changement sécurisé
  // ... reste de la config
}
```

## 📈 Bonnes pratiques

### Avant modification
- [ ] Sauvegarde créée
- [ ] Raison de la modification documentée
- [ ] Impact évalué

### Pendant modification
- [ ] Une seule modification à la fois
- [ ] Validation JSON après chaque changement
- [ ] Test immédiat de la fonctionnalité modifiée

### Après modification
- [ ] VSCode redémarré
- [ ] Serveurs MCP vérifiés
- [ ] Fonctionnalités testées
- [ ] Nouvelle sauvegarde si tout fonctionne

## 📚 Historique et traçabilité

### Sauvegardes automatiques
- Chaque modification génère une sauvegarde horodatée
- Conservation de toutes les sauvegardes pour traçabilité
- Possibilité de revenir à n'importe quel état antérieur

### Documentation des changements
- Toujours documenter la raison des modifications
- Noter les serveurs affectés
- Enregistrer les tests de validation effectués

## 🎯 Objectifs de cette procédure

1. **Zéro corruption** du fichier de configuration
2. **Traçabilité complète** des modifications
3. **Récupération rapide** en cas de problème
4. **Confiance** dans les opérations de maintenance MCP

---

**Dernière mise à jour** : 28/05/2025 03:40
**Version** : 1.0
**Statut** : Procédure active et obligatoire
# 🚨 GUIDE D'URGENCE - Panne MCPs dans Roo

## SYMPTÔMES DE LA PANNE
- Aucun MCP n'apparaît dans Roo
- Message "No MCP servers currently connected"
- Perte complète des capacités MCP

## CAUSE IDENTIFIÉE
**Corruption du fichier de configuration par BOM UTF-8**
- Fichier: `c:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- Problème: Caractère BOM `﻿` au début du fichier JSON
- Conséquence: Roo ne peut plus parser le JSON

## RÉPARATION D'URGENCE

### Option 1: Script automatique (RECOMMANDÉ)
```powershell
# Diagnostic
.\roo-config\mcp-diagnostic-repair.ps1 -Validate

# Réparation
.\roo-config\mcp-diagnostic-repair.ps1 -Repair

# Sauvegarde préventive
.\roo-config\mcp-diagnostic-repair.ps1 -Backup
```

### Option 2: Réparation manuelle
```powershell
# Supprimer le BOM UTF-8
$filePath = "c:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$content = Get-Content $filePath -Raw
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($filePath, $content, $utf8NoBom)
```

## VALIDATION POST-RÉPARATION

### 1. Vérifier le fichier
```powershell
# Le fichier doit commencer par { et non par ﻿{
Get-Content "c:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" -TotalCount 1
```

### 2. Valider le JSON
```powershell
# Doit afficher le nombre de MCPs sans erreur
Get-Content "c:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" -Raw | ConvertFrom-Json | Select-Object -ExpandProperty mcpServers | Get-Member -MemberType NoteProperty | Measure-Object | Select-Object -ExpandProperty Count
```

### 3. Redémarrer Roo
- Fermer complètement VS Code
- Relancer VS Code
- Vérifier que les MCPs apparaissent dans Roo

## MCPs ESSENTIELS CONFIGURÉS

| MCP | Type | Status | Description |
|-----|------|--------|-------------|
| `quickfiles` | Local | ✅ Actif | Manipulation rapide de fichiers |
| `jinavigator` | Local | ✅ Actif | Navigation web et conversion markdown |
| `searxng` | NPM | ✅ Actif | Recherche web via SearXNG |
| `jupyter` | Local | ✅ Actif | Notebooks Jupyter |
| `win-cli` | NPM | ✅ Actif | Commandes Windows CLI |
| `github-projectsglobal` | Local | ✅ Actif | Gestion projets GitHub |
| `gitglobal` | NPM | ✅ Actif | API GitHub complète |
| `filesystem` | NPM | ✅ Actif | Accès système de fichiers |


## PROBLÈME SEARXNG - MCP ERROR -32000

### Symptômes spécifiques
- Erreur "MCP error -32000: Connection closed" pour searxng
- Le serveur se lance mais n'expose aucun outil
- Logs VSCode montrant un crash au démarrage

### Diagnostic rapide
```powershell
# Test direct du serveur
node "C:\Users\jsboi\AppData\Roaming\npm\node_modules\mcp-searxng\dist\index.js"
```

### Cause : Incompatibilité Windows
- Problème de format de chemin dans la condition de démarrage
- `import.meta.url` vs `process.argv[1]` incompatibles sur Windows

### Réparation
⚠️ **ATTENTION** : Modifiez directement le fichier npm si nécessaire
```javascript
// Dans le fichier index.js du package searxng
const normalizedPath = process.argv[1].replace(/\\/g, '/');
const expectedUrl = `file:///${normalizedPath}`;
if (import.meta.url === expectedUrl) {
    main().catch(console.error);
}
```

### Validation
```bash
# Test fonctionnel via Roo
searxng: searxng_web_search -> doit retourner des résultats
```

## PRÉVENTION

### 1. Sauvegardes automatiques
```powershell
# Créer une tâche planifiée pour sauvegardes quotidiennes
schtasks /create /tn "Backup MCP Settings" /tr "powershell.exe -File 'd:\Dev\roo-extensions\roo-config\mcp-diagnostic-repair.ps1' -Backup" /sc daily /st 09:00
```

### 2. Surveillance
- Vérifier régulièrement l'état des MCPs avec le script de diagnostic
- Ne jamais éditer manuellement le fichier `mcp_settings.json` avec des éditeurs qui ajoutent des BOM

### 3. Bonnes pratiques
- Toujours utiliser UTF-8 sans BOM pour les fichiers JSON
- Créer une sauvegarde avant toute modification
- Tester la connectivité après chaque changement

## CONTACTS D'URGENCE
- Script de diagnostic: `.\roo-config\mcp-diagnostic-repair.ps1`
- Sauvegardes: `c:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\backups\`
- Configuration principale: `c:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`

---
*Guide créé le 26/05/2025 suite à la panne critique des MCPs*

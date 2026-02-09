# GUIDE DE DÉPANNAGE DES SERVEURS MCP

## 📋 TABLE DES MATIÈRES

1. [Problèmes Communs](#problèmes-communs)
2. [Diagnostic Rapide](#diagnostic-rapide)
3. [Solutions Spécifiques](#solutions-spécifiques)
4. [Scripts de Monitoring](#scripts-de-monitoring)
5. [Procédures d'Urgence](#procédures-durgence)
6. [Prévention des Régressions](#prévention-des-régressions)

---

## 🚨 PROBLÈMES COMMUNS

### 1. Serveur MCP ne démarre pas

**Symptômes:**
- Erreur "MCP server not found" dans les logs
- Timeout de connexion
- Port déjà utilisé

**Causes possibles:**
- Fichier build manquant
- Dépendances non installées
- Configuration incorrecte

**Solutions:**
```bash
# 1. Vérifier le build
cd mcps/internal/servers/quickfiles-server
npm run build

# 2. Vérifier les dépendances
npm install

# 3. Tester manuellement
node build/index.js
```

### 2. Stubs détectés dans le code

**Symptômes:**
- Tests anti-régression échouent
- Message "Not implemented" dans les réponses MCP
- Fonctions vides ou retours anticipés

**Causes possibles:**
- Régression lors d'un merge
- Code incomplet committé
- Refactoring manquant

**Solutions:**
```bash
# 1. Exécuter les tests anti-régression
npm run test:anti-regression

# 2. Analyser avec le pre-commit hook
node scripts/pre-commit-hook.js

# 3. Vérifier les outils critiques
grep -r "handleDeleteFiles\|handleEditMultipleFiles" src/
```

### 3. Problèmes de chemins Windows

**Symptômes:**
- Erreurs "ENOENT: no such file or directory"
- Chemins incorrects dans la configuration
- Problèmes avec les slashes (/ vs \)

**Solutions:**
```json
{
  "quickfiles": {
    "command": "node",
    "args": [
      "C:/dev/roo-extensions/mcps/internal/servers/quickfiles-server/build/index.js"
    ],
    "watchPaths": [
      "C:/dev/roo-extensions/mcps/internal/servers/quickfiles-server/build/index.js"
    ]
  }
}
```

---

## 🔍 DIAGNOSTIC RAPIDE

### Script de Monitoring Automatique

Exécuter le diagnostic complet:
```powershell
# Diagnostic complet
.\scripts\mcp-monitor.ps1 -WorkspacePath . -Verbose

# Diagnostic avec correction automatique
.\scripts\mcp-monitor.ps1 -WorkspacePath . -Fix

# Diagnostic d'un serveur spécifique
.\scripts\mcp-monitor.ps1 -WorkspacePath . -ConfigFile "custom-config.json"
```

### Tests de Santé

```bash
# Test QuickFiles MCP
curl http://localhost:3003/status

# Test Jupyter MCP  
curl http://localhost:3001/status

# Test JinaNavigator MCP
curl http://localhost:3002/status
```

### Validation de Configuration

```javascript
// Vérifier la configuration MCP
const config = require('./mcp_settings.json');
console.log('Serveurs configurés:', Object.keys(config.mcpServers || {}));

// Valider les chemins
Object.entries(config.mcpServers || {}).forEach(([name, server]) => {
  console.log(`\n${name}:`);
  console.log('  Command:', server.command);
  console.log('  Args:', server.args);
  console.log('  Transport:', server.transportType);
});
```

---

## 🔧 SOLUTIONS SPÉCIFIQUES

### QuickFiles MCP

#### Problème: Fichiers non trouvés
```bash
# Solution 1: Vérifier les chemins absolus
node -e "
const fs = require('fs');
const path = require('path');
const testPath = 'C:/dev/roo-extensions/test.txt';
console.log('Exists:', fs.existsSync(testPath));
console.log('Absolute:', path.resolve(testPath));
"

# Solution 2: Utiliser les chemins Windows
dir "C:\dev\roo-extensions\test.txt"
```

#### Problème: Permissions refusées
```json
{
  "quickfiles": {
    "alwaysAllow": [
      "read_multiple_files",
      "list_directory_contents", 
      "copy_files",
      "search_in_files",
      "edit_multiple_files",
      "search_and_replace",
      "delete_files",
      "move_files"
    ]
  }
}
```

### Jupyter MCP

#### Problème: Notebook non trouvé
```bash
# Vérifier le chemin du notebook
jupyter notebook list

# Créer un notebook de test
jupyter notebook create --version 4
```

#### Problème: Kernel non démarré
```bash
# Redémarrer le kernel
jupyter kernel restart

# Lister les kernels disponibles
jupyter kernel list
```

### JinaNavigator MCP

#### Problème: Conversion web échoue
```bash
# Tester avec une URL simple
curl -X POST http://localhost:3002 \
  -H "Content-Type: application/json" \
  -d '{"params": {"name": "convert_web_to_markdown", "arguments": {"url": "https://example.com"}}}'
```

---

## 📊 SCRIPTS DE MONITORING

### mcp-monitor.ps1

**Usage:**
```powershell
.\scripts\mcp-monitor.ps1 [paramètres]

# Paramètres disponibles
-WorkspacePath .     # Chemin de l'espace de travail (défaut: .)
-Verbose            # Mode verbeux
-Fix               # Tenter de corriger automatiquement les problèmes
-ConfigFile         # Fichier de configuration alternatif
```

**Fonctionnalités:**
- ✅ Validation de la configuration MCP globale
- ✅ Analyse des serveurs critiques (QuickFiles, Jupyter, JinaNavigator)
- ✅ Vérification des dépendances et builds
- ✅ Tests de santé des serveurs
- ✅ Exécution des tests anti-régression
- ✅ Détection des problèmes de chemins Windows
- ✅ Rapport détaillé avec recommandations

### pre-commit-hook.js

**Usage:**
```bash
# Test avant commit
node scripts/pre-commit-hook.js

# Test avec exécution des tests Jest
node scripts/pre-commit-hook.js --test

# Intégration Git hook
cp scripts/pre-commit-hook.js .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Détections:**
- 🚨 Stubs "Not implemented"
- 🚨 Fonctions vides
- 🚨 Retours anticipés sans logique
- 🚨 Outils critiques manquants
- ✅ Validation des 8 outils MCP critiques

---

## 🚨 PROCÉDURES D'URGENCE

### Régression Critique Détectée

**QUAND:** Immédiatement après détection de stubs dans les outils critiques

**ACTIONS:**
1. **ISOLER LE PROBLÈME**
   ```bash
   # Identifier le commit responsable
   git log --oneline -10
   git show --name-only HEAD
   ```

2. **BLOQUER LES DÉPLOIEMENTS**
   ```bash
   # Annuler les déploiements en cours
   # Notifier l'équipe via Slack/Teams
   ```

3. **ANALYSE D'IMPACT**
   ```bash
   # Exécuter les tests complets
   npm run test:anti-regression
   npm run test:unit
   npm run test:e2e
   ```

4. **CORRECTION IMMÉDIATE**
   ```bash
   # Créer une branche de hotfix
   git checkout -b hotfix/mcp-stubs-$(date +%Y%m%d-%H%M%S)
   
   # Corriger les stubs
   # Implémenter les fonctions manquantes
   ```

5. **VALIDATION**
   ```bash
   # Tests complets avant merge
   npm run test:all
   node scripts/pre-commit-hook.js --test
   ```

### Serveur MCP en Panne

**QUAND:** Timeout de connexion ou erreurs répétées

**ACTIONS:**
1. **DIAGNOSTIC RAPIDE**
   ```powershell
   # Test de santé complet
   .\scripts\mcp-monitor.ps1 -WorkspacePath . -Verbose
   ```

2. **REDÉMARRAGE CONTRÔLÉ**
   ```bash
   # Arrêter proprement
   # Vérifier les processus
   tasklist | findstr node
   
   # Redémarrer
   npm run restart:quickfiles
   npm run restart:jupyter
   npm run restart:jinavigator
   ```

3. **ROLLBACK SI NÉCESSAIRE**
   ```bash
   # Revenir à la version stable
   git log --oneline --grep="stable" -5
   git checkout <commit-hash>
   ```

---

## 🛡️ PRÉVENTION DES RÉGRESSIONS

### Hooks Git Automatisés

**Installation:**
```bash
# 1. Copier le hook pre-commit
cp scripts/pre-commit-hook.js .git/hooks/pre-commit

# 2. Rendre exécutable
chmod +x .git/hooks/pre-commit

# 3. Configurer Husky (optionnel)
npm install --save-dev husky
npx husky add .husky/pre-commit "node scripts/pre-commit-hook.js"
```

### Tests Automatisés

**Intégration CI/CD:**
```yaml
# .github/workflows/mcp-tests.yml
name: MCP Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '18'
      - run: npm ci
      - run: npm run test:anti-regression
      - run: npm run test:unit
```

### Monitoring Continu

**Surveillance des modifications critiques:**
```bash
# Surveillance des fichiers MCP critiques
find mcps/internal/servers -name "*.ts" -exec grep -l "handleDeleteFiles\|handleEditMultipleFiles" {} \;

# Alertes sur les modifications
inotifywait -r -e modify,move,create,delete mcps/internal/servers/quickfiles-server/src/
```

### Validation Continue

**Scripts planifiés:**
```bash
# Validation quotidienne
0 9 * * * .\scripts\mcp-monitor.ps1

# Validation avant chaque commit
git config core.hooksPath .git/hooks
```

---

## 📞 SUPPORT ET CONTACT

### Équipe de Développement

- **Lead MCP:** Contact via Slack #mcp-support
- **Lead Dev:** Email pour les problèmes critiques
- **On-call:** Procédures d'urgence 24/7

### Documentation Complémentaire

- **Guide technique:** `mcps/internal/servers/quickfiles-server/docs/TECHNICAL.md`
- **API Reference:** `mcps/internal/servers/quickfiles-server/docs/USAGE.md`
- **Historique:** `docs/rapports/analyses/`

### Outils de Diagnostic

- **Logs MCP:** Vérifier dans `~/.roo/mcp-logs/`
- **Configuration:** `mcp_settings.json` dans les préférences VS Code
- **Tests:** `npm run test:anti-regression`

---

## 📈 MÉTRIQUES DE PERFORMANCE

### Temps de Réponse

- **Objectif:** < 100ms pour les opérations locales
- **Alerte:** > 500ms nécessite investigation

### Taux de Succès

- **Objectif:** > 99% pour les opérations standards
- **Alerte:** < 95% nécessite action immédiate

### Disponibilité

- **Objectif:** 99.9% uptime mensuel
- **Alerte:** < 99% déclenche procédure d'urgence

---

*Ce document est mis à jour continuellement. Dernière mise à jour: 2025-10-30*
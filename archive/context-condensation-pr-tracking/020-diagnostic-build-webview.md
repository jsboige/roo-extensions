# Diagnostic Complet : Build & Déploiement Webview-UI

**Date** : 2025-10-07  
**Contexte** : L'UI des providers de condensation n'apparaît pas dans VSCode après redémarrage  
**Statut** : ✅ Cause racine identifiée

---

## 🔍 Investigation Systématique

### Phase 1 : Configuration Build Webview-UI

**Fichier analysé** : `webview-ui/vite.config.ts`

```typescript
// Ligne 56
let outDir = "../src/webview-ui/build"
```

**Découverte** :
- ✅ `npm run build` dans `webview-ui/` génère vers `src/webview-ui/build/`
- ✅ Configuration intentionnelle (relatif à `webview-ui/`, donc `../src/webview-ui/build`)
- ✅ `.gitignore` ignore `/build` dans webview-ui/ (ligne 12)

**Conclusion Phase 1** : Le build génère correctement dans `src/webview-ui/build/`

---

### Phase 2 : Chargement Webview dans Extension

**Fichier analysé** : `src/core/webview/ClineProvider.ts`

```typescript
// Lignes 1089-1096 : Mode PRODUCTION
const stylesUri = getUri(webview, this.contextProxy.extensionUri, [
    "webview-ui",  // ❌ Cherche ici
    "build",
    "assets",
    "index.css",
])

const scriptUri = getUri(webview, this.contextProxy.extensionUri, [
    "webview-ui",  // ❌ Cherche ici
    "build", 
    "assets", 
    "index.js"
])
```

**Découverte** :
- ❌ Extension cherche `webview-ui/build/assets/`
- ❌ Mais vite génère dans `src/webview-ui/build/assets/`
- ✅ Décalage de chemin critique identifié

**Conclusion Phase 2** : L'extension attend `webview-ui/build/` mais le build produit `src/webview-ui/build/`

---

### Phase 3 : Build Extension Principale

**Fichier analysé** : `src/esbuild.mjs`

```javascript
// Lignes 50-62 : copyFiles plugin
copyPaths(
    [
        ["../README.md", "README.md"],
        ["../CHANGELOG.md", "CHANGELOG.md"],
        ["../LICENSE", "LICENSE"],
        ["../.env", ".env", { optional: true }],
        ["node_modules/vscode-material-icons/generated", "assets/vscode-material-icons"],
        ["../webview-ui/audio", "webview-ui/audio"],  // ✅ Copie seulement audio
    ],
    srcDir,
    buildDir,
)
```

**Découverte** :
- ❌ `esbuild.mjs` ne copie PAS `src/webview-ui/build/`
- ✅ Il copie seulement `webview-ui/audio/`
- ❌ La copie doit être faite par le script de déploiement

**Fichier analysé** : `src/turbo.json`

```json
// Ligne 6
"bundle": {
    "dependsOn": ["^build", "@roo-code/vscode-webview#build"],
    "outputs": ["dist/**"]
}
```

**Découverte** :
- ✅ `bundle` dépend du build webview-ui
- ✅ Le webview-ui doit être buildé AVANT le bundle

**Conclusion Phase 3** : Le processus de build est correct, mais la copie du webview-ui vers l'emplacement final doit être gérée par le script de déploiement

---

### Phase 4 : Vérification Structure Déployée

**Script exécuté** : `scripts/001-phase4-check-webview-structure.ps1`

#### Résultats SOURCE (c:/dev/roo-code)

| Chemin | Existe | Fichiers |
|--------|--------|----------|
| `webview-ui/build` | ❌ False | - |
| `src/webview-ui/build` | ✅ True | 10+ fichiers |
| `src/webview-ui/build/assets/index.js` | ✅ True | - |
| `src/webview-ui/build/assets/index.css` | ✅ True | - |

#### Résultats EXTENSION DÉPLOYÉE

| Chemin | Existe | Fichiers |
|--------|--------|----------|
| `webview-ui/build` | ✅ True | 10+ fichiers |
| `src/webview-ui/build` | ❌ False | - |
| `webview-ui/build/assets/index.js` | ✅ True | - |
| `webview-ui/build/assets/index.css` | ✅ True | - |

**Découverte CRITIQUE** :
- ✅ Le script `deploy-standalone.ps1` copie bien `src/webview-ui/build` → `webview-ui/build`
- ❌ MAIS les fichiers copiés sont ANCIENS (ne contiennent pas les nouveaux composants)

**Conclusion Phase 4** : Le problème n'est PAS la structure, mais le fait que le webview-ui n'a PAS été re-buildé avant le déploiement

---

## 📋 Diagnostic Final

### Cause Racine Identifiée

Le problème est un **build incomplet** lors du déploiement :

1. ✅ **Configuration correcte** : vite génère dans `src/webview-ui/build/`
2. ✅ **Extension correcte** : cherche dans `webview-ui/build/`
3. ✅ **Déploiement correct** : copie `src/webview-ui/build/` → `webview-ui/build/`
4. ❌ **PROBLÈME** : Le webview-ui n'a PAS été re-buildé avec les nouveaux composants avant déploiement

### Workflow Attendu vs Réel

#### Workflow Attendu ✅
```
1. Modifier code webview-ui (composants condensation)
2. cd webview-ui && npm run build          ← Génère src/webview-ui/build/
3. cd ../src && pnpm run bundle            ← Build extension
4. deploy-standalone.ps1                   ← Copie vers extension
   - Copie src/webview-ui/build/ → webview-ui/build/
```

#### Workflow Réel ❌
```
1. Modifier code webview-ui (composants condensation)
2. ❌ SKIP webview-ui build                ← PAS FAIT !
3. cd ../src && pnpm run bundle            ← Build extension avec ancien webview
4. deploy-standalone.ps1                   ← Copie ANCIENS fichiers
```

---

## 🎯 Solution

### Étape 1 : Re-build Webview-UI

```powershell
cd C:\dev\roo-code\webview-ui
npm run build
```

Cela va :
- Compiler les nouveaux composants React (PresetCard, JsonEditorModal, etc.)
- Générer les fichiers dans `src/webview-ui/build/`
- Inclure TOUTES les modifications UI de condensation

### Étape 2 : Re-bundle Extension

```powershell
cd C:\dev\roo-code\src
pnpm run bundle
```

### Étape 3 : Re-déployer

```powershell
cd C:\dev\roo-extensions\roo-code-customization
.\deploy-standalone.ps1
```

Cela va :
- Copier `src/webview-ui/build/` → extension `webview-ui/build/`
- Avec les NOUVEAUX fichiers incluant l'UI de condensation

### Étape 4 : Vérification

```powershell
# Comparer les dates de dernière modification
$sourceFile = "C:\dev\roo-code\src\webview-ui\build\assets\index.js"
$extFile = "$env:USERPROFILE\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.15\webview-ui\build\assets\index.js"

(Get-Item $sourceFile).LastWriteTime
(Get-Item $extFile).LastWriteTime
```

Les deux dates doivent être identiques et récentes.

---

## ✅ Critères de Succès

Après correction :

1. ✅ `src/webview-ui/build/` contient les nouveaux composants
2. ✅ Extension `webview-ui/build/` est à jour
3. ✅ Dates de modification identiques source vs extension
4. ✅ **ATTENTE CONFIRMATION UTILISATEUR** :
   - Redémarrer VSCode
   - Aller dans Roo Settings → Context
   - Vérifier que l'UI de condensation apparaît

---

## 📝 Recommandations

### Pour l'avenir

1. **Script de build complet** : Créer un script qui fait :
   ```powershell
   # build-all.ps1
   cd webview-ui && npm run build
   cd ../src && pnpm run bundle
   ```

2. **Vérification pré-déploiement** : Ajouter dans `deploy-standalone.ps1` :
   ```powershell
   # Vérifier que src/webview-ui/build est récent
   $buildAge = (Get-Date) - (Get-Item "src/webview-ui/build").LastWriteTime
   if ($buildAge.TotalMinutes -gt 30) {
       Write-Warning "webview-ui/build semble ancien. Pensez à re-builder !"
   }
   ```

3. **Documentation workflow** : Documenter clairement dans README :
   - Quand rebuilder le webview-ui
   - Ordre des commandes de build
   - Vérifications post-déploiement

---

## 🔗 Fichiers Clés

| Fichier | Rôle |
|---------|------|
| `webview-ui/vite.config.ts` | Configure outDir vers `../src/webview-ui/build` |
| `webview-ui/package.json` | Script `build` qui exécute vite |
| `src/core/webview/ClineProvider.ts` | Charge depuis `webview-ui/build` |
| `src/esbuild.mjs` | Build extension (ne copie PAS webview) |
| `deploy-standalone.ps1` | Copie `src/webview-ui/build` → `webview-ui/build` |

---

**Prochaine étape** : Phase 6 - Correction (exécuter les commandes de build)
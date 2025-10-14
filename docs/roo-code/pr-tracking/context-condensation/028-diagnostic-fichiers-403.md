# 🔍 Diagnostic: Fichiers Mermaid et Erreurs 403 Forbidden

**Date:** 2025-01-13  
**Statut:** ✅ DIAGNOSTIC TERMINÉ - ANGLE MORT IDENTIFIÉ

---

## 📋 Contexte

Les logs DevTools montrent des erreurs **403 Forbidden** lors du chargement de chunks dynamiques :
- `chunk-BYCUR9qn.js`
- `mermaid-bundle.js`

**Hypothèse initiale:** Ces fichiers n'étaient pas copiés par le script de déploiement.

---

## 🔬 Méthodologie

Script de diagnostic créé : [`016-verify-missing-chunks.ps1`](scripts/016-verify-missing-chunks.ps1)

### Vérifications effectuées :
1. ✅ Listage des fichiers JS dans le build source
2. ✅ Listage des fichiers JS dans l'extension déployée
3. ✅ Comparaison des deux listes

---

## 📊 Résultats du Diagnostic

### Fichiers JavaScript

```
Source:     284 fichiers JS (15.01 MB)
Déployé:    284 fichiers JS (15.01 MB)
Manquants:  0 fichiers
```

### Fichiers Critiques Vérifiés

| Fichier | Présent dans Build | Présent dans Extension | Taille |
|---------|-------------------|----------------------|--------|
| `chunk-BYCUR9qn.js` | ✅ OUI | ✅ OUI | ~36 KB |
| `mermaid-bundle.js` | ✅ OUI | ✅ OUI | ~2.5 MB |

---

## 🚨 CONCLUSION CRITIQUE

### ❌ L'Hypothèse Initiale Était INCORRECTE

**Les fichiers NE SONT PAS manquants !**

Tous les fichiers JavaScript compilés par Vite sont correctement :
1. Générés dans `src/webview-ui/build/assets/`
2. Copiés dans l'extension `~/.vscode/extensions/rooveterinaryinc.roo-cline-*/dist/webview-ui/build/assets/`

Le script de déploiement [`deploy-standalone.ps1`](../../../../roo-code-customization/deploy-standalone.ps1) fonctionne correctement.

---

## 🎯 LE VRAI ANGLE MORT

Les erreurs **403 Forbidden** ne sont PAS causées par des fichiers manquants, mais par un problème de **permissions d'accès** ou de **Content Security Policy (CSP)**.

### Pistes d'investigation :

#### 1. Content Security Policy (CSP)
Le webview VSCode impose des restrictions CSP strictes. Les chunks dynamiques peuvent être bloqués si :
- Le CSP ne permet pas `'unsafe-eval'` ou `'unsafe-inline'`
- Les sources dynamiques (`blob:`, `data:`) ne sont pas autorisées
- Les chemins relatifs ne correspondent pas au contexte d'exécution

**Fichier à examiner:**
```
src/core/webview/WebviewManager.ts
```

#### 2. Chemin de Base du Webview
Le webview peut avoir un problème avec le `base path` utilisé par Vite :
- Vite génère des chemins relatifs (`./assets/chunk-BYCUR9qn.js`)
- Le webview peut ne pas résoudre correctement ces chemins

**Configuration à vérifier:**
```typescript
// webview-ui/vite.config.ts
export default defineConfig({
  base: './',  // ← Est-ce le bon chemin pour le webview ?
  // ...
})
```

#### 3. Serveur Local du Webview
Le webview VSCode utilise un serveur local (`vscode-webview://`) qui peut :
- Refuser de servir certains types de fichiers
- Ne pas gérer correctement les imports dynamiques
- Bloquer les chunks avec des restrictions de sécurité

---

## 📝 Actions Suivantes

### Priorité 1 : Examiner le CSP
```bash
# Rechercher les configurations CSP dans le code
rg "Content-Security-Policy" src/
```

### Priorité 2 : Vérifier la Configuration Vite
```bash
# Examiner la configuration du build
cat webview-ui/vite.config.ts
```

### Priorité 3 : Analyser les Logs Runtime
- Ouvrir les DevTools du webview
- Rechercher les messages CSP spécifiques
- Vérifier les chemins d'accès complets aux ressources

### Priorité 4 : Tester avec un Build Sans Code Splitting
Temporairement, désactiver le code splitting dans Vite :
```typescript
// vite.config.ts
build: {
  rollupOptions: {
    output: {
      manualChunks: undefined
    }
  }
}
```

---

## 🔗 Références

- Script de diagnostic : [`016-verify-missing-chunks.ps1`](scripts/016-verify-missing-chunks.ps1)
- Build source : `src/webview-ui/build/assets/`
- Extension déployée : `~/.vscode/extensions/rooveterinaryinc.roo-cline-*/dist/webview-ui/build/assets/`
- Premier diagnostic : [`027-diagnostic-angle-mort-runtime.md`](027-diagnostic-angle-mort-runtime.md)

---

## ✅ Leçons Apprises

1. **Ne jamais supposer sans vérifier** : L'hypothèse "fichiers manquants" était plausible mais incorrecte
2. **Les erreurs 403 peuvent avoir plusieurs causes** : Fichiers manquants, CSP, permissions, chemin d'accès
3. **Valider méthodiquement** : Un script de diagnostic automatisé évite les suppositions
4. **Documenter les impasses** : Même une hypothèse incorrecte aide à éliminer des pistes

---

**Prochaine étape:** Créer une sous-tâche pour investiguer le CSP et la configuration Vite du webview.
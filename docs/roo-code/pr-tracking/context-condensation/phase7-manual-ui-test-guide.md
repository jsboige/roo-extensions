# Phase 7.3: Guide de Test Manuel UI

**Date:** 2025-10-06  
**Branch:** feature/context-condensation-providers  
**Commit:** 37de8c308 (après correction BaseProvider)  
**Objectif:** Valider l'interface utilisateur avant soumission PR

---

## ⚠️ Pré-requis

- [x] Build terminé: `pnpm run build` ✅
- [x] Script de déploiement disponible: `C:/dev/roo-extensions/roo-code-customization/deploy-fix.ps1`
- [ ] VSCode fermé (requis pour déploiement)

---

## 📦 Étape 1: Déploiement Temporaire

### A. Fermer VSCode

```powershell
# Fermer TOUS les processus VSCode
Get-Process code* | Stop-Process -Force
```

### B. Exécuter le Déploiement

```powershell
# Depuis PowerShell Administrateur
cd C:/dev/roo-extensions/roo-code-customization
.\deploy-fix.ps1 -Action Deploy
```

**Vérifications:**
- [ ] Message "Succès : Déploiement terminé" affiché
- [ ] Backup créé: `C:/Users/jsboi/.vscode/extensions/rooveterinaryinc.roo-cline-3.25.6/dist_backup`
- [ ] Nouveaux fichiers copiés: `C:/Users/jsboi/.vscode/extensions/rooveterinaryinc.roo-cline-3.25.6/dist`

### C. Relancer VSCode

```powershell
code
```

---

## ✅ Étape 2: Checklist Complète de Test UI

### 2.1 Provider Selection (Settings Panel)

**Objectif:** Vérifier que les 4 providers sont affichés et sélectionnables

**Actions:**
1. [ ] Ouvrir VSCode Settings (Ctrl+,)
2. [ ] Rechercher "roo context condensation"
3. [ ] Naviguer vers section "Context Condensation"
4. [ ] Vérifier dropdown "Provider"

**Validation:**
- [ ] **4 options visibles:**
  - [ ] Native
  - [ ] Lossless
  - [ ] Truncation
  - [ ] Smart
- [ ] **Sélection Native:** UI met à jour, pas de presets
- [ ] **Sélection Lossless:** UI met à jour, pas de presets
- [ ] **Sélection Truncation:** UI met à jour, pas de presets
- [ ] **Sélection Smart:** UI met à jour, **3 presets apparaissent**
- [ ] **Provider par défaut:** Native sélectionné initialement

**Résultat:**
```
Provider Selection: ✅ OK / ❌ FAIL
Notes: _____________________________________________
```

---

### 2.2 Smart Provider - Presets Cards

**Objectif:** Vérifier l'affichage et la sélection des presets

**Pré-requis:** Provider "Smart" sélectionné

**Actions:**
1. [ ] Observer les 3 cards de presets
2. [ ] Lire les descriptions de chaque preset
3. [ ] Cliquer sur "Conservative"
4. [ ] Observer la configuration qui change
5. [ ] Cliquer sur "Balanced"
6. [ ] Observer la configuration qui change
7. [ ] Cliquer sur "Aggressive"
8. [ ] Observer la configuration qui change

**Validation:**

**Card 1: Conservative**
- [ ] Titre: "Conservative"
- [ ] Description visible et claire
- [ ] Paramètres affichés (ex: Summarize Cost, Token Threshold)
- [ ] Clic → Configuration mise à jour

**Card 2: Balanced**
- [ ] Titre: "Balanced"
- [ ] Description visible et claire
- [ ] Paramètres différents de Conservative
- [ ] Clic → Configuration mise à jour

**Card 3: Aggressive**
- [ ] Titre: "Aggressive"
- [ ] Description visible et claire
- [ ] Paramètres plus agressifs
- [ ] Clic → Configuration mise à jour

**Résultat:**
```
Smart Presets: ✅ OK / ❌ FAIL
Notes: _____________________________________________
```

---

### 2.3 Smart Provider - JSON Editor

**Objectif:** Tester l'éditeur JSON avancé

**Pré-requis:** Provider "Smart" sélectionné

**Actions:**
1. [ ] Cliquer sur "Edit JSON Configuration"
2. [ ] Éditeur JSON s'ouvre avec config actuelle
3. [ ] Observer la structure JSON
4. [ ] Modifier `summarizeCost`: `0.05` → `0.10`
5. [ ] Sauvegarder
6. [ ] Vérifier input "Summarize Cost" affiche `0.10`
7. [ ] Rouvrir JSON Editor
8. [ ] Entrer JSON invalide: `{ invalid }`
9. [ ] Observer message d'erreur
10. [ ] Annuler et vérifier retour à état valide

**Validation:**
- [ ] **Ouverture:** Config actuelle chargée correctement
- [ ] **Édition:** Modifications appliquées instantanément
- [ ] **Persistance:** Valeurs sauvegardées après fermeture/réouverture
- [ ] **Validation:** JSON invalide détecté avec message clair
- [ ] **Annulation:** Retour à l'état précédent sans corruption

**Résultat:**
```
JSON Editor: ✅ OK / ❌ FAIL
Notes: _____________________________________________
```

---

### 2.4 Smart Provider - Advanced Settings

**Objectif:** Tester les inputs avancés

**Pré-requis:** Provider "Smart" sélectionné

**Actions:**
1. [ ] Localiser section "Advanced Settings"
2. [ ] Identifier les 3 inputs:
   - [ ] Summarize Cost (number, >0, <1)
   - [ ] Token Threshold (number, >0)
   - [ ] Allow Partial Tool Output (boolean)
3. [ ] Modifier "Summarize Cost": `0.05` → `0.02`
4. [ ] Vérifier config JSON mise à jour
5. [ ] Modifier "Token Threshold": `5000` → `10000`
6. [ ] Essayer valeur invalide: `-100` dans Summarize Cost
7. [ ] Vérifier rejet/message erreur

**Validation:**
- [ ] **Inputs fonctionnels:** Toutes les modifications appliquées
- [ ] **Validation:** Valeurs hors limites rejetées
- [ ] **Synchronisation:** JSON config mis à jour en temps réel
- [ ] **Types:** Number inputs acceptent nombres, boolean = checkbox

**Résultat:**
```
Advanced Settings: ✅ OK / ❌ FAIL
Notes: _____________________________________________
```

---

### 2.5 Persistance (Reload VSCode)

**Objectif:** Vérifier que les settings persistent après reload

**Actions:**
1. [ ] Sélectionner "Smart" provider
2. [ ] Choisir preset "Aggressive"
3. [ ] Modifier "Token Threshold" → `15000`
4. [ ] Recharger VSCode (Ctrl+Shift+P → "Reload Window")
5. [ ] Rouvrir Settings → Context Condensation
6. [ ] Vérifier provider sélectionné
7. [ ] Vérifier preset actif
8. [ ] Vérifier valeur Token Threshold

**Validation:**
- [ ] **Provider:** Smart toujours sélectionné
- [ ] **Preset:** Aggressive toujours actif
- [ ] **Custom Value:** 15000 conservé
- [ ] **Pas de régression:** Aucune valeur réinitialisée

**Résultat:**
```
Persistance: ✅ OK / ❌ FAIL
Notes: _____________________________________________
```

---

### 2.6 Integration Test (Optionnel - Si Temps)

**Objectif:** Observer le provider en action

**Actions:**
1. [ ] Créer une longue conversation de test (>50 messages)
2. [ ] Sélectionner "Lossless" provider
3. [ ] Déclencher condensation (via threshold ou manuel)
4. [ ] Observer logs dans Output > Roo-Code
5. [ ] Vérifier provider utilisé = "Lossless"
6. [ ] Vérifier pas de boucles infinies (max 3 tentatives)

**Validation:**
- [ ] Provider sélectionné utilisé
- [ ] Condensation réussie
- [ ] Logs cohérents
- [ ] Pas de crash ou erreur

**Résultat:**
```
Integration: ✅ OK / ❌ FAIL / ⏭️ SKIPPED
Notes: _____________________________________________
```

---

## 📸 Étape 3: Captures d'Écran (Optionnel)

Si des problèmes sont détectés, capturer:
1. Settings panel avec dropdown providers
2. Smart Provider avec 3 presets
3. JSON Editor ouvert
4. Message d'erreur (si applicable)

**Sauvegarder dans:**
```
C:/dev/roo-extensions/docs/roo-code/pr-tracking/context-condensation/screenshots/
```

---

## 🔄 Étape 4: Rollback

**IMPORTANT:** Toujours effectuer le rollback après les tests!

### A. Fermer VSCode

```powershell
Get-Process code* | Stop-Process -Force
```

### B. Exécuter le Rollback

```powershell
cd C:/dev/roo-extensions/roo-code-customization
.\deploy-fix.ps1 -Action Rollback
```

**Vérifications:**
- [ ] Message "Succès : Restauration terminée"
- [ ] Répertoire `dist_backup` renommé en `dist`
- [ ] Extension originale restaurée

### C. Relancer VSCode

```powershell
code
```

### D. Vérifier Extension Originale

- [ ] Ouvrir Settings > Roo > Context Condensation
- [ ] Vérifier que l'UI est revenue à l'état original (si différente)
- [ ] Confirmer fonctionnement normal

---

## 📝 Étape 5: Documenter les Résultats

**Mettre à jour:** `C:/dev/roo-extensions/docs/roo-code/pr-tracking/context-condensation/phase6-manual-ui-test.md`

**Template:**

```markdown
## Test Date
2025-10-06T[HH:MM]Z

## Environment
- VSCode Version: [vérifier Help > About]
- Extension: feature/context-condensation-providers (SHA 37de8c308)
- Deployment: Temporary via deploy-fix.ps1
- OS: Windows 11

## Test Results

### Provider Selection
✅ Dropdown: 4 providers affichés correctement
✅ Selection: État UI mis à jour
✅ Default: Native comme attendu

### Smart Provider Presets
✅ 3 presets affichés avec descriptions
✅ Selection: Configuration mise à jour
✅ Descriptions: Claires et informatives

### JSON Editor
✅ Ouverture: Config actuelle chargée
✅ Édition: Modifications sauvegardées
✅ Validation: JSON invalide détecté avec message clair

### Advanced Settings
✅ Tous inputs fonctionnels
✅ Modifications persistantes après reload
✅ Validation: Valeurs hors limites rejetées

### Persistance
✅ Provider sélectionné survit reload
✅ Preset actif conservé
✅ Custom values préservées

### Integration (Optionnel)
⏭️ SKIPPED / ✅ OK / ❌ FAIL

## Issues Found
None / [Liste si problèmes]

## Screenshots
None / [Paths si capturés]

## Rollback
✅ Effectué avec succès
✅ Extension originale restaurée

## Conclusion
✅ UI fully functional and ready for PR
```

---

## 🎯 Critères de Succès

**Test PASSÉ si:**
- ✅ Tous les providers affichés et sélectionnables
- ✅ Smart Provider: 3 presets fonctionnels
- ✅ JSON Editor: édition + validation OK
- ✅ Advanced Settings: inputs fonctionnels
- ✅ Persistance après reload VSCode
- ✅ Aucune régression UI observée
- ✅ Rollback effectué avec succès

**Test ÉCHOUÉ si:**
- ❌ Providers manquants ou non sélectionnables
- ❌ Presets non affichés ou non fonctionnels
- ❌ JSON Editor crash ou ne valide pas
- ❌ Settings ne persistent pas
- ❌ Erreurs JavaScript dans console
- ❌ Rollback échoue

---

## 📞 Support

**En cas de problème:**
1. Capturer screenshots
2. Vérifier console DevTools (Help > Toggle Developer Tools)
3. Copier logs Output > Roo-Code
4. Documenter dans `phase6-manual-ui-test.md`
5. Effectuer rollback immédiatement

---

**Durée estimée:** 15-20 minutes (sans Integration Test)  
**Durée avec Integration:** 25-30 minutes

**Prêt à commencer!** 🚀
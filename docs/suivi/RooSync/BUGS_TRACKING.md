# RooSync Bugs Tracking

**Version:** 1.0
**Date de création:** 2026-01-10
**Objectif:** Suivi structuré des bugs identifiés dans RooSync v2.3

---

## 📊 Résumé

| Priorité | Nombre | Statut |
|----------|--------|--------|
| HIGH | 2 | ✅ Tous fixés |
| MEDIUM | 2 | ✅ Tous fixés |
| LOW | 1 | ✅ Fixé |
| **Total** | **5** | ✅ Complet |

---

## 🔴 HIGH Priority

### Bug #289: Erreur parsing JSON baseline - BOM UTF-8

**Issue GitHub:** [jsboige/roo-extensions#289](https://github.com/jsboige/roo-extensions/issues/289)

**Description:**
Erreur lors du parsing JSON des fichiers baseline à cause d'un BOM UTF-8 en tête de fichier.

**Localisation probable:**
- `BaselineService.ts` ou `ConfigSharingService.ts`
- Fonction de lecture/parse des fichiers JSON

**Solution proposée:**
```typescript
// Ajouter stripBom lors de la lecture
import { stripBom } from '...';

const content = fs.readFileSync(filePath, 'utf8');
const cleanContent = stripBom(content);
const data = JSON.parse(cleanContent);
```

**Statut:** ✅ FIXÉ
**Corrigé par:** Roo (myia-po-2023)
**Date:** 2026-01-14
**Commit:** `c42a124`

**Solution appliquée:**
- Nouveau module `encoding-helpers.ts` avec `stripBOM()` et fonctions associées
- Correction de BaselineLoader.ts, NonNominativeBaselineService.ts, ConfigService.ts, InventoryService.ts
- Documentation: `docs/suivi/RooSync/BUG_289_RAPPORT_CORRECTION_BOM_UTF8.md`

---

### Bug #290: roosync_export_baseline - Erreur interne getBaselineServiceConfig

**Issue GitHub:** [jsboige/roo-extensions#290](https://github.com/jsboige/roo-extensions/issues/290)

**Description:**
L'outil `roosync_export_baseline` échoue avec une erreur interne liée à `getBaselineServiceConfig`.

**Localisation:**

- ~~BaselineService.ts (export de la fonction)~~
- **export-baseline.ts** ligne 68-72: configService passé comme objet vide `{}`

**Cause racine:**
Le `configService` était passé comme `{} as any` au lieu d'une instance de `ConfigService`, donc la méthode `getBaselineServiceConfig()` n'existait pas.

**Solution appliquée:**

```typescript
// Avant (BUG):
const baselineService = new BaselineService({} as any, ...);

// Après (FIX):
const configService = new ConfigService();
const baselineService = new BaselineService(configService, ...);
```

**Statut:** ✅ FIXÉ
**Corrigé par:** Claude Code (myia-po-2024)
**Date:** 2026-01-14
**Commit:** `bef5b1a` (mcps/internal submodule)

---

## 🟡 MEDIUM Priority

### Bug #291: roosync_restore_baseline - Erreur Git tag inexistant

**Issue GitHub:** [jsboige/roo-extensions#291](https://github.com/jsboige/roo-extensions/issues/291)

**Description:**
L'outil `roosync_restore_baseline` échoue car le tag Git n'existe pas.

**Localisation:**

- `manage-baseline.ts` fonction `restoreBaseline`

**Solution appliquée:**
Ajout d'une vérification du tag Git avant la restauration avec `git rev-parse --verify` et message d'erreur explicite.

**Statut:** ✅ FIXÉ
**Corrigé par:** Claude Code (myia-po-2024)
**Date:** 2026-01-14
**Commit:** `bef5b1a` (mcps/internal submodule)

---

### Bug #296: roosync_apply_config - Version de configuration requise non documentée

**Issue GitHub:** [jsboige/roo-extensions#296](https://github.com/jsboige/roo-extensions/issues/296)

**Description:**
L'outil `roosync_apply_config` exige une version de configuration mais ce n'est pas documenté.

**Localisation:**

- `ConfigSharingService.ts` ligne 162-163

**Solution appliquée:**
Utiliser "latest" comme valeur par défaut si version non spécifiée, au lieu de lancer une erreur.

**Statut:** ✅ FIXÉ
**Corrigé par:** Claude Code (myia-po-2024)
**Date:** 2026-01-14
**Commit:** `80a5218` (mcps/internal submodule)

---

## 🟢 LOW Priority

### Bug #292: analyze_problems chemins hardcodés

**Issue GitHub:** [jsboige/roo-extensions#292](https://github.com/jsboige/roo-extensions/issues/292)

**Description:**
L'outil `analyze_problems` avait des chemins hardcodés qui ne fonctionnaient pas sur toutes les machines.

**Statut:** ✅ FIXÉ
**Corrigé par:** Roo (myia-ai-01)
**Date:** 2026-01-13
**Commit:** `c897db4`

---

## 🔄 Historique des Corrections

| Date | Bug | Action | Auteur |
|------|-----|--------|--------|
| 2026-01-14 | #289 | Correction BOM UTF-8 parsing JSON | Roo (myia-po-2023) |
| 2026-01-14 | #290 | Correction getBaselineServiceConfig | Claude Code (myia-po-2024) |
| 2026-01-14 | #291 | Correction Git tag vérification | Claude Code (myia-po-2024) |
| 2026-01-14 | #296 | Correction version config default | Claude Code (myia-po-2024) |
| 2026-01-13 | #292 | Correction chemins hardcodés | Roo (myia-ai-01) |

---

## 📋 Checklist de Validation

Pour chaque bug corrigé:

- [ ] Correction implémentée
- [ ] Test unitaire ajouté
- [ ] Test manuel validé
- [ ] Issue GitHub mise à jour
- [ ] Ce fichier de tracking mis à jour

---

## 🔗 Liens Utiles

- [Projet GitHub #67](https://github.com/users/jsboige/projects/67)
- [GUIDE-TECHNIQUE-v2.3.md](../roosync/GUIDE-TECHNIQUE-v2.3.md)
- [PROTOCOLE_SDDD.md](../roosync/PROTOCOLE_SDDD.md)

---

**Dernière mise à jour:** 2026-01-14
**Maintenu par:** Claude Code (myia-po-2023)

# RooSync Bugs Tracking

**Version:** 1.0
**Date de création:** 2026-01-10
**Objectif:** Suivi structuré des bugs identifiés dans RooSync v2.3

---

## 📊 Résumé

| Priorité | Nombre | Statut |
|----------|--------|--------|
| HIGH | 2 | À corriger |
| MEDIUM | 2 | À corriger |
| LOW | 3 | À documenter |
| **Total** | **7** | - |

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

**Statut:** 🔄 TODO
**Assigné à:** Roo (myia-ai-01)
**Estimation:** 30 min

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
- Validation de version dans l'outil apply_config

**Solution proposée:**
1. Ajouter la documentation sur la version requise
2. Ou retirer l'exigence de version si non nécessaire

**Statut:** 🔄 TODO
**Assigné à:** myia-po-2023
**Estimation:** 15 min

---

## 🟢 LOW Priority

### Bug #292: [À définir]

**Description:** À documenter

**Statut:** 🔄 TODO
**Assigné à:** TBD

---

### Bug #293: [À définir]

**Description:** À documenter

**Statut:** 🔄 TODO
**Assigné à:** TBD

---

### Bug #294: [À définir]

**Description:** À documenter

**Statut:** 🔄 TODO
**Assigné à:** TBD

---

## 🔄 Historique des Corrections

| Date | Bug | Action | Auteur |
|------|-----|--------|--------|
| - | - | - | - |

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

**Dernière mise à jour:** 2026-01-10
**Maintenu par:** Claude Code (myia-ai-01)

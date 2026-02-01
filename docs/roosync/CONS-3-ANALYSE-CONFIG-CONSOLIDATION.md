# CONS-3 : Analyse Consolidation Outils Config RooSync

**Version :** 1.0.0
**Date :** 2026-01-30
**Auteur :** Claude Code (myia-po-2026)
**Statut :** PROPOSITION - En attente validation coordinateur

---

## Contexte

Suite aux consolidations CONS-1 (messagerie 7→3), CONS-2 (heartbeat), et CONS-4 (baseline 3→1), cette analyse porte sur les outils de configuration RooSync.

---

## État Actuel : 4 Outils Config

### Inventaire Complet

| # | Outil | Fichier | Fonction | LOC |
|---|-------|---------|----------|-----|
| 1 | `roosync_collect_config` | `collect-config.ts` | Collecte config locale | 57 |
| 2 | `roosync_publish_config` | `publish-config.ts` | Publication vers GDrive | 72 |
| 3 | `roosync_apply_config` | `apply-config.ts` | Application depuis GDrive | 159 |
| 4 | `roosync_compare_config` | `compare-config.ts` | Comparaison multi-machines | 381 |

**Total :** 669 LOC (lignes de code)

### Analyse Fonctionnelle

#### 1. `roosync_collect_config` (57 LOC)

**Fonction :** Collecte la configuration locale (modes Roo, MCPs, profils)

**Paramètres :**
- `targets` : Liste des cibles à collecter (`modes`, `mcp`, `profiles`)
- `dryRun` : Simulation sans création de fichiers

**Output :**
- `packagePath` : Chemin du package temporaire créé
- `totalSize` : Taille totale collectée
- `manifest` : Métadonnées des fichiers

**Service :** `ConfigSharingService.collectConfig()`

---

#### 2. `roosync_publish_config` (72 LOC)

**Fonction :** Publie un package collecté vers le stockage partagé GDrive

**Paramètres :**
- `packagePath` (required) : Chemin du package créé par `collect_config`
- `version` (required) : Version de la configuration (ex: `2.3.0`)
- `description` (required) : Description des changements
- `machineId` (optional) : ID machine (défaut: `ROOSYNC_MACHINE_ID`)

**Output :**
- `version` : Version publiée
- `targetPath` : Chemin dans GDrive
- `machineId` : Machine source

**Service :** `ConfigSharingService.publishConfig()`

**Note SDDD :** Stocke par machineId pour éviter les écrasements

---

#### 3. `roosync_apply_config` (159 LOC)

**Fonction :** Applique une configuration partagée sur la machine locale

**Paramètres :**
- `version` (optional) : Version à appliquer (défaut: `latest`)
- `machineId` (optional) : Machine source
- `targets` (optional) : Filtre des cibles (`modes`, `mcp`, `profiles`, ou `mcp:<nom>`)
- `backup` (optional) : Créer backup avant application (défaut: `true`)
- `dryRun` (optional) : Simulation sans modification

**Output :**
- `filesApplied` : Nombre de fichiers appliqués
- `backupPath` : Chemin du backup créé
- `errors` : Erreurs rencontrées

**Service :** `ConfigSharingService.applyConfig()`

**Fonctionnalités avancées :**
- Validation de version majeure
- Syntaxe granulaire `mcp:<nomServeur>` (#349)
- Gestion des erreurs détaillée

---

#### 4. `roosync_compare_config` (381 LOC)

**Fonction :** Compare configurations entre deux machines

**Paramètres :**
- `source` (optional) : Machine source (défaut: locale)
- `target` (optional) : Machine cible (défaut: première autre machine)
- `force_refresh` (optional) : Forcer collecte même si cache valide
- `granularity` (optional) : Niveau de comparaison (`mcp`, `mode`, `full`)
- `filter` (optional) : Filtre sur les chemins

**Output :**
- `differences[]` : Liste des différences (category, severity, path, description, action)
- `summary` : Compteurs par sévérité (critical, important, warning, info)

**Services :**
- `RooSyncService.getInventory()`
- `RooSyncService.compareRealConfigurations()`
- `GranularDiffDetector.compareGranular()`

**Fonctionnalités avancées :**
- Détection multi-niveaux (config Roo, hardware, software, system)
- Support profils (`profile:dev`)
- Mode granulaire avec filtre
- Cache inventaire (TTL 1h)

---

## Analyse des Dépendances

### Services Partagés

| Service | collect | publish | apply | compare |
|---------|---------|---------|-------|---------|
| `ConfigSharingService` | ✅ | ✅ | ✅ | ❌ |
| `RooSyncService` | ✅ | ✅ | ✅ | ✅ |
| `ConfigService` | ❌ | ❌ | ✅ | ✅ |
| `GranularDiffDetector` | ❌ | ❌ | ❌ | ✅ |

### Patterns de Code

**Communs :**
- Import `getRooSyncService()` (4/4 outils)
- Gestion erreurs `ConfigSharingServiceError` (3/4 outils)
- Schema Zod avec validation (4/4 outils)
- Metadata export pour registry (4/4 outils)

**Spécifiques :**
- `compare-config.ts` : Debug logging dans fichier, support multi-formats inventaire
- `apply-config.ts` : Parsing targets avec syntaxe granulaire `mcp:xxx`

---

## Proposition de Consolidation

### Option A : 2 Outils (Recommandée)

```
┌─────────────────────────────────────────────────────────────┐
│                    AVANT (4 outils)                          │
├─────────────────────────────────────────────────────────────┤
│ collect_config │ publish_config │ apply_config │ compare    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    APRÈS (2 outils)                          │
├─────────────────────────────────────────────────────────────┤
│         roosync_config          │     roosync_compare       │
│   (collect + publish + apply)   │   (compare - inchangé)    │
└─────────────────────────────────────────────────────────────┘
```

**Justification :**
- `compare_config` est fondamentalement différent (lecture seule, multi-machines)
- `collect`, `publish`, `apply` forment un workflow cohérent (cycle de vie config)
- `compare` a 381 LOC avec logique complexe (GranularDiffDetector) - fusion risquée

---

### Outil Proposé : `roosync_config`

**Fusionne :** `collect_config` + `publish_config` + `apply_config`

```typescript
interface RooSyncConfigArgs {
  // Mode opération (required)
  action: 'collect' | 'publish' | 'apply';

  // Commun
  machineId?: string;
  dryRun?: boolean;

  // Pour collect
  targets?: ('modes' | 'mcp' | 'profiles')[];

  // Pour publish (requiert collect préalable OU packagePath)
  packagePath?: string;  // Optionnel si collect + publish en une opération
  version?: string;
  description?: string;

  // Pour apply
  backup?: boolean;
  // targets réutilisé (supporte syntaxe mcp:<nom>)
}
```

**Exemples d'utilisation :**

```typescript
// Collecter config locale
roosync_config({ action: 'collect', targets: ['modes', 'mcp'] })

// Publier un package collecté
roosync_config({
  action: 'publish',
  packagePath: '/path/to/package',
  version: '2.3.0',
  description: 'Sync config'
})

// Collecter ET publier en une opération
roosync_config({
  action: 'publish',
  targets: ['modes', 'mcp'],
  version: '2.3.0',
  description: 'Collecte + publication'
})

// Appliquer config depuis GDrive
roosync_config({
  action: 'apply',
  version: 'latest',
  targets: ['mcp:jupyter'],
  backup: true
})
```

---

### `roosync_compare` : Inchangé

**Rationale :**
- Outil le plus complexe (381 LOC vs 288 LOC pour les 3 autres combinés)
- Fonctionnalité distincte : comparaison multi-machines vs gestion locale
- Dépendances uniques (`GranularDiffDetector`, multi-formats inventaire)
- Risque de régression si modifié

**Amélioration potentielle (optionnelle) :**
- Renommer `roosync_compare_config` → `roosync_compare` (cohérence avec CONS-1/4)
- Nettoyer le debug logging (code temporaire ligne 74-88)

---

## Impact Estimé

### Réduction Code

| Métrique | Avant | Après | Gain |
|----------|-------|-------|------|
| Nombre d'outils | 4 | 2 | -50% |
| LOC total | 669 | ~500 | -25% |
| Fichiers | 4 | 2 | -50% |
| Enregistrements registry | 4 | 2 | -50% |

### Code Éliminé

- Imports dupliqués : ~20 lignes
- Schemas Zod redondants : ~40 lignes
- Metadata exports similaires : ~30 lignes
- Gestion erreurs répétée : ~20 lignes

**Total estimé :** ~110 lignes éliminées (-16%)

---

## Plan de Migration

### Phase 1 : Création (T+1 semaine)

1. Créer `roosync_config.ts` avec API action-based
2. Réutiliser services existants (`ConfigSharingService`)
3. Supporter workflow collect+publish atomique
4. Tests unitaires complets

**Livrable :** `src/tools/roosync/config.ts` fonctionnel

### Phase 2 : Dépréciation (T+2 semaines)

1. Ajouter warnings de dépréciation aux 3 anciens outils
2. Créer aliasing (ancien → nouveau)
3. Mettre à jour documentation

```typescript
// Exemple aliasing
export async function roosyncCollectConfig(args) {
  console.warn('DEPRECATED: Use roosync_config({ action: "collect", ... })');
  return roosyncConfig({ action: 'collect', ...args });
}
```

### Phase 3 : Migration (T+4 semaines)

1. Identifier tous les appels aux anciens outils
2. Migrer scripts et workflows
3. Valider sur les 5 machines

### Phase 4 : Suppression (T+6 semaines)

1. Supprimer fichiers :
   - `collect-config.ts`
   - `publish-config.ts`
   - `apply-config.ts`
2. Nettoyer registry.ts et index.ts
3. Rebuild + tests

---

## Risques et Mitigations

### Risque 1 : Workflow collect + publish atomique

**Problème :** Actuellement, `collect` crée un package temporaire, puis `publish` le lit.

**Mitigation :**
- Si `action: 'publish'` ET `targets` fourni ET pas de `packagePath` :
  1. Appeler `collectConfig()` en interne
  2. Enchaîner avec `publishConfig()`
  3. Nettoyer le package temporaire
- Préserver l'option `packagePath` pour workflow en 2 étapes

### Risque 2 : Syntaxe granulaire `mcp:<nom>`

**Problème :** `apply_config` supporte la syntaxe spéciale `mcp:jupyter`.

**Mitigation :**
- Conserver la fonction `parseTargets()` dans le nouvel outil
- Documenter clairement dans la description MCP

### Risque 3 : Validation version majeure

**Problème :** `apply_config` valide la compatibilité de version.

**Mitigation :**
- Conserver la logique de validation dans l'action `apply`
- Bug #305 déjà géré (version null)

---

## Recommandation

**APPROUVER** la consolidation en 2 outils :
1. `roosync_config` (collect + publish + apply) - **NOUVEAU**
2. `roosync_compare` (compare - renommage optionnel)

**Avantages :**
- API cohérente avec CONS-1/CONS-4 (action-based)
- Workflow atomique collect+publish possible
- Réduction 50% du nombre d'outils
- Maintenance simplifiée
- Préserve la complexité de `compare` isolée

**Timing :** Après stabilisation CONS-1, CONS-2, CONS-4, CONS-7

---

## Annexes

### A. Fichiers Concernés

**Création :**
- `src/tools/roosync/config.ts` (nouvel outil unifié)
- `src/tools/roosync/__tests__/config.test.ts`

**Modification :**
- `src/tools/roosync/index.ts`
- `src/tools/registry.ts`
- `README-ROOSYNC.md`

**Dépréciation puis suppression :**
- `src/tools/roosync/collect-config.ts`
- `src/tools/roosync/publish-config.ts`
- `src/tools/roosync/apply-config.ts`

**Optionnel (renommage) :**
- `src/tools/roosync/compare-config.ts` → `compare.ts`

### B. Interface TypeScript Complète

```typescript
// roosync_config - Outil unifié de gestion de configuration
interface RooSyncConfigArgs {
  /**
   * Action à effectuer
   * - collect: Collecte la configuration locale
   * - publish: Publie vers le stockage partagé
   * - apply: Applique une configuration depuis le stockage
   */
  action: 'collect' | 'publish' | 'apply';

  /**
   * ID de la machine (optionnel)
   * Défaut: ROOSYNC_MACHINE_ID
   */
  machineId?: string;

  /**
   * Mode simulation (optionnel)
   * true = pas de modification de fichiers
   */
  dryRun?: boolean;

  /**
   * Cibles à collecter/appliquer (optionnel)
   * Valeurs: 'modes', 'mcp', 'profiles', ou 'mcp:<nomServeur>'
   * Défaut: ['modes', 'mcp']
   */
  targets?: string[];

  // === Spécifique à 'publish' ===

  /**
   * Chemin du package collecté (optionnel pour publish)
   * Si omis avec targets fourni, fait collect+publish atomique
   */
  packagePath?: string;

  /**
   * Version de la configuration (required pour publish)
   * Format: X.Y.Z (ex: "2.3.0")
   */
  version?: string;

  /**
   * Description des changements (required pour publish)
   */
  description?: string;

  // === Spécifique à 'apply' ===

  /**
   * Créer backup avant application (optionnel)
   * Défaut: true
   */
  backup?: boolean;
}

interface RooSyncConfigResult {
  status: 'success' | 'error';
  message: string;

  // Pour collect
  packagePath?: string;
  totalSize?: number;
  manifest?: {
    version: string;
    timestamp: string;
    author: string;
    files: { path: string; size: number }[];
  };

  // Pour publish
  version?: string;
  targetPath?: string;

  // Pour apply
  filesApplied?: number;
  backupPath?: string;
  errors?: string[];
}
```

---

**Fin de l'analyse CONS-3**

**Prochaine étape :** Validation coordinateur → Création issue GitHub → Implémentation Phase 1

---

**Document préparé par :** Claude Code (myia-po-2026)
**Date :** 2026-01-30 01:30
**Statut :** Prêt pour revue coordinateur

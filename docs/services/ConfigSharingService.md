# ConfigSharingService

**Fichier:** `src/services/ConfigSharingService.ts`
**Lignes:** 921
**Dernière mise à jour:** 2026-02-25

---

## Résumé

Service de partage de configuration entre machines du système RooSync. Gère le cycle complet : collecte des configs locales, publication vers le shared state (GDrive), et application de configs distantes. Supporte le filtrage granulaire par type et serveur MCP.

---

## Méthodes Clés

| Méthode | Paramètres | Retour | Usage |
|---------|------------|--------|-------|
| `collectConfig()` | `options: CollectConfigOptions` | `Promise<CollectConfigResult>` | Collecte la config locale dans un package |
| `publishConfig()` | `options: PublishConfigOptions` | `Promise<PublishConfigResult>` | Publie le package vers le shared state |
| `applyConfig()` | `options: ApplyConfigOptions` | `Promise<ApplyConfigResult>` | Applique une config depuis le shared state |
| `compareWithBaseline()` | `config: any` | `Promise<DiffResult>` | Compare une config avec la baseline |

---

## Types de Configurations Supportées

| Target | Description | Chemin Source |
|--------|-------------|---------------|
| `modes` | Définitions des modes Roo | `{rooExtensions}/roo-modes/*.json` |
| `mcp` | Settings MCP complets | `{mcpSettings}/mcp_settings.json` |
| `mcp:<server>` | Serveur MCP spécifique | Filtré dans `mcp_settings.json` |
| `profiles` | Profils de configuration | `{sharedState}/configuration-profiles.json` |
| `roomodes` | Fichier .roomodes | `{rooExtensions}/.roomodes` |
| `model-configs` | Configs des modèles | `{rooExtensions}/roo-config/model-configs.json` |
| `rules` | Rules globales | `{rooExtensions}/roo-config/rules-global/*.md` |

---

## Structure de Stockage

```
{sharedStatePath}/configs/
├── {machineId}/                    # Configs par machine (CORRECTION SDDD)
│   ├── latest.json                 # Pointeur vers la dernière version
│   ├── v1.0.0-2026-02-25T10-30-00/ # Version horodatée
│   │   ├── manifest.json
│   │   ├── roo-modes/
│   │   ├── mcp-settings/
│   │   └── ...
│   └── v1.0.1-2026-02-26T14-15-00/
└── baseline-v{version}/            # Format legacy (fallback)
```

---

## Dépendances

| Service/Module | Usage |
|----------------|-------|
| `ConfigNormalizationService` | Normalisation des configs avant stockage |
| `ConfigDiffService` | Comparaison avec baseline |
| `JsonMerger` | Fusion des configs JSON |
| `InventoryService` | Résolution des chemins locaux |
| `IConfigService` | Accès au shared state path |
| `IInventoryCollector` | Collecte de l'inventaire machine |

---

## Options des Méthodes

### CollectConfigOptions
```typescript
interface CollectConfigOptions {
  targets: ('modes' | 'mcp' | 'profiles' | 'roomodes' | 'model-configs' | 'rules' | `mcp:${string}`)[];
  description?: string;
}
```

### PublishConfigOptions
```typescript
interface PublishConfigOptions {
  packagePath: string;      // Chemin du package temporaire
  version: string;          // Version sémantique (ex: "1.0.0")
  description?: string;
  machineId?: string;       // Override du machineId (défaut: ROOSYNC_MACHINE_ID)
}
```

### ApplyConfigOptions
```typescript
interface ApplyConfigOptions {
  version?: string;         // Version à appliquer (défaut: "latest")
  machineId?: string;       // Machine source (défaut: machine locale)
  targets?: string[];       // Filtrage des cibles
  dryRun?: boolean;         // Simulation sans écriture
}
```

---

## Patterns Utilisés

- **Service Layer Pattern**: Interface `IConfigSharingService` pour l'abstraction
- **Template Method**: `collectConfig()` délègue à `collectModes()`, `collectMcpSettings()`, etc.
- **Strategy Pattern**: Filtrage conditionnel selon les targets
- **Repository Pattern**: Stockage versionné par machineId

---

## Limitations

1. **Pas de rollback automatique**: En cas d'erreur pendant `applyConfig()`, les fichiers déjà modifiés le restent
2. **Pas de validation schéma**: Les configs ne sont pas validées contre un schéma JSON
3. **Pas de compression**: Les fichiers sont stockés en JSON brut
4. **Concurrency limitée**: Pas de verrouillage pendant l'application

---

## Gestion des Erreurs

```typescript
enum ConfigSharingServiceErrorCode {
  PATH_NOT_AVAILABLE = 'PATH_NOT_AVAILABLE',
  INVENTORY_INCOMPLETE = 'INVENTORY_INCOMPLETE',
  // ...
}
```

Erreurs courantes :
- `INVENTORY_INCOMPLETE`: L'inventaire machine manque des chemins requis
- `PATH_NOT_AVAILABLE`: La version demandée n'existe pas

---

## Exemple d'Appel

### Collecte + Publication

```typescript
import { ConfigSharingService } from './services/ConfigSharingService.js';

const service = new ConfigSharingService(configService, inventoryCollector);

// 1. Collecter la config locale
const collectResult = await service.collectConfig({
  targets: ['modes', 'mcp', 'roomodes'],
  description: 'Config après mise à jour modes'
});

console.log(`Collecté: ${collectResult.filesCount} fichiers, ${collectResult.totalSize} bytes`);

// 2. Publier vers le shared state
const publishResult = await service.publishConfig({
  packagePath: collectResult.packagePath,
  version: '2.3.2',
  description: 'Config-sync v2.3.2',
  machineId: 'myia-po-2024'
});

console.log(`Publié: ${publishResult.path}`);
```

### Application (avec dry-run)

```typescript
// 3. Appliquer une config (simulation)
const dryRunResult = await service.applyConfig({
  version: 'latest',
  machineId: 'myia-ai-01',  // Appliquer la config de ai-01
  targets: ['mcp:roo-state-manager'],  // Uniquement ce serveur
  dryRun: true
});

console.log('Dry-run details:', dryRunResult.dryRunDetails);

// 4. Appliquer pour de vrai
const applyResult = await service.applyConfig({
  version: 'latest',
  targets: ['mcp', 'modes']
});

if (applyResult.success) {
  console.log(`${applyResult.filesApplied} fichiers appliqués`);
} else {
  console.error('Erreurs:', applyResult.errors);
}
```

---

## Tests

- **Localisation:** `src/tools/roosync/__tests__/publish-config.test.ts`, `tests/e2e/roosync/workflow-complete.test.ts`
- **Couverture:** Collecte, publication, application, filtrage MCP, dry-run

---

## Historique des Corrections

| Issue | Date | Description |
|-------|------|-------------|
| #296 | 2026-02 | Défaut `version: 'latest'` si non spécifié |
| #349 | 2026-02 | Filtrage granulaire `mcp:<server>` |
| SDDD | 2026-02 | Stockage par `machineId` au lieu de version globale |
| T2.16 | 2026-02 | Utilisation de `ROOSYNC_MACHINE_ID` au lieu de `COMPUTERNAME` |

# ConfigSharingService

**Fichier:** `src/services/ConfigSharingService.ts`
**Lignes:** 921
**Version:** 1.0.0

---

## Résumé

Service de partage de configuration entre machines via le shared state GDrive. Il collecte les fichiers de config locaux (modes, MCPs, profils, rules), les publie vers GDrive organisés par machineId, et permet d'appliquer une config distante. Supporte l'historique des versions et les comparaisons.

---

## Méthodes clés

| Méthode | Paramètres | Retour | Usage |
|---------|------------|--------|-------|
| `collectConfig` | `options: CollectConfigOptions` | `Promise<CollectConfigResult>` | Collecte la config locale |
| `publishConfig` | `options: PublishConfigOptions` | `Promise<PublishConfigResult>` | Publie vers GDrive |
| `applyConfig` | `options: ApplyConfigOptions` | `Promise<ApplyConfigResult>` | Applique une config distante |
| `collectMcpSettings` | `tempDir, serverNames?` | `Promise<ConfigManifestFile[]>` | Collecte les MCPs |
| `collectModes` | `tempDir` | `Promise<ConfigManifestFile[]>` | Collecte les modes |
| `collectRules` | `tempDir` | `Promise<ConfigManifestFile[]>` | Collecte les rules |

---

## Dépendances

- **ConfigNormalizationService** : Normalisation des configs
- **ConfigDiffService** : Comparaison des configs
- **InventoryService** : Inventaire des machines
- **JsonMerger** : Fusion de JSON
- **fs/path/crypto/os** : Modules Node.js natifs

---

## Patterns

- **Template Method** : collectConfig orchestre les sous-collectes
- **Strategy Pattern** : Targets configurables (modes, mcp, profiles, rules)
- **Versioning by MachineId** : `{machineId}/v{version}-{timestamp}`
- **Latest Pointer** : Fichier `latest.json` pour accès rapide

---

## Limitations

- **N'applique pas** les configs automatiquement (validation requise)
- **Dépend de GDrive** : Shared state path doit être accessible
- **Pas de rollback** automatique si applyConfig échoue partiellement
- **Historique non nettoyé** : Les versions s'accumulent

---

## Exemple d'appel

```typescript
import { ConfigSharingService } from './services/ConfigSharingService.js';

const service = new ConfigSharingService(configService, inventoryCollector);

// 1. Collecter la config locale
const collectResult = await service.collectConfig({
  targets: ['modes', 'mcp', 'profiles', 'rules'],
  description: 'Config avant maintenance'
});

// 2. Publier vers GDrive
const publishResult = await service.publishConfig({
  packagePath: collectResult.packagePath,
  version: '1.2.0',
  description: 'Post-maintenance config',
  machineId: 'myia-po-2025'
});

// 3. Appliquer une config distante (sur une autre machine)
const applyResult = await service.applyConfig({
  version: 'latest',
  machineId: 'myia-ai-01',  // Source
  targets: ['modes', 'mcp']
});
```

---

## Structure de stockage GDrive

```
{SHARED_STATE_PATH}/configs/
├── myia-ai-01/
│   ├── v1.0.0-2026-02-24T10-00-00/
│   │   ├── manifest.json
│   │   ├── modes/
│   │   └── mcp/
│   ├── v1.1.0-2026-02-25T15-30-00/
│   └── latest.json
├── myia-po-2025/
│   └── ...
```

---

## Options de collecte

```typescript
interface CollectConfigOptions {
  targets: Array<'modes' | 'mcp' | 'profiles' | 'roomodes' | 'model-configs' | 'rules' | `mcp:${string}`>;
  description?: string;
}
```

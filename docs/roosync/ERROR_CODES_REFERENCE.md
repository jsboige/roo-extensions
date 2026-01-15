# RooSync Error Codes Reference

## Version: 1.0.0
## Date de création: 2026-01-15
## Dernière mise à jour: 2026-01-15

Ce document référence tous les codes d'erreur du RooSync State Manager, issus de la tâche T2.8 (Amélioration de la gestion des erreurs).

---

## Table des Matières

1. [Architecture des Erreurs](#1-architecture-des-erreurs)
2. [Classes d'Erreur](#2-classes-derreur)
3. [Codes par Service](#3-codes-par-service)
4. [Classification Script vs Système](#4-classification-script-vs-système)
5. [Utilisation](#5-utilisation)

---

## 1. Architecture des Erreurs

### 1.1 Hiérarchie

```
StateManagerError (classe de base)
├── ConfigServiceError
├── IdentityManagerError
├── BaselineLoaderError
├── BaselineServiceError
├── GenericError
├── SynthesisServiceError      (T2.8)
├── TraceSummaryServiceError   (T2.8)
├── PowerShellExecutorError    (T2.8)
├── MessageManagerError        (T2.8)
├── CacheManagerError          (T2.8)
├── InventoryCollectorError    (T2.8)
├── RooStorageDetectorError    (T2.8)
├── ExportConfigManagerError   (T2.8)
└── ConfigSharingServiceError  (T2.8)
```

### 1.2 Structure d'une Erreur

```typescript
{
  name: string;        // Nom de la classe d'erreur
  message: string;     // Message d'erreur lisible
  code: string;        // Code d'erreur unique
  service: string;     // Service source
  category: ErrorCategory; // SCRIPT | SYSTEM | UNKNOWN
  details?: any;       // Contexte additionnel
  cause?: Error;       // Erreur originale
}
```

---

## 2. Classes d'Erreur

### 2.1 StateManagerError (Base)

Classe de base pour toutes les erreurs. Fournit la structure commune.

**Fichier**: `src/types/errors.ts:24`

### 2.2 Erreurs Spécialisées

| Classe | Service | Codes |
| ------ | ------- | ----- |
| ConfigServiceError | ConfigService | 7 |
| IdentityManagerError | IdentityManager | 10 |
| BaselineLoaderError | BaselineLoader | 7 |
| BaselineServiceError | BaselineService | 8 |
| SynthesisServiceError | SynthesisService | 13 |
| TraceSummaryServiceError | TraceSummaryService | 4 |
| PowerShellExecutorError | PowerShellExecutor | 6 |
| MessageManagerError | MessageManager | 7 |
| CacheManagerError | CacheManager | 5 |
| InventoryCollectorError | InventoryCollector | 6 |
| RooStorageDetectorError | RooStorageDetector | 3 |
| ExportConfigManagerError | ExportConfigManager | 4 |
| ConfigSharingServiceError | ConfigSharingService | 3 |
| GenericError | Generic | 6 |

**Total: 14 classes, 89 codes d'erreur**

---

## 3. Codes par Service

### 3.1 ConfigService

| Code | Description |
| ---- | ----------- |
| `CONFIG_NOT_FOUND` | Fichier de configuration introuvable |
| `CONFIG_LOAD_FAILED` | Échec du chargement de la configuration |
| `CONFIG_SAVE_FAILED` | Échec de la sauvegarde de la configuration |
| `CONFIG_INVALID` | Configuration invalide ou corrompue |
| `CONFIG_VERSION_READ_FAILED` | Impossible de lire la version de config |
| `CONFIG_PATH_NOT_FOUND` | Chemin de configuration inexistant |
| `SHARED_STATE_PATH_NOT_FOUND` | Chemin shared-state non trouvé |

### 3.2 IdentityManager

| Code | Description |
| ---- | ----------- |
| `REGISTRY_LOAD_FAILED` | Échec chargement du registre |
| `REGISTRY_SAVE_FAILED` | Échec sauvegarde du registre |
| `COLLECTION_FAILED` | Échec de la collecte d'identité |
| `VALIDATION_FAILED` | Validation de l'identité échouée |
| `IDENTITY_CONFLICT` | Conflit d'identité détecté |
| `IDENTITY_NOT_FOUND` | Identité non trouvée |
| `CLEANUP_FAILED` | Échec du nettoyage |
| `PRESENCE_READ_FAILED` | Impossible de lire la présence |
| `BASELINE_READ_FAILED` | Impossible de lire la baseline |
| `DASHBOARD_READ_FAILED` | Impossible de lire le dashboard |

### 3.3 BaselineLoader

| Code | Description |
| ---- | ----------- |
| `BASELINE_NOT_FOUND` | Fichier baseline introuvable |
| `BASELINE_LOAD_FAILED` | Échec du chargement |
| `BASELINE_INVALID` | Baseline invalide |
| `BASELINE_PARSE_FAILED` | Échec du parsing JSON |
| `BASELINE_TRANSFORM_FAILED` | Échec de la transformation |
| `BASELINE_VALIDATION_FAILED` | Échec de la validation |
| `BASELINE_READ_FAILED` | Échec de la lecture |

### 3.4 BaselineService

| Code | Description |
| ---- | ----------- |
| `BASELINE_NOT_FOUND` | Baseline non trouvée |
| `BASELINE_INVALID` | Baseline invalide |
| `COMPARISON_FAILED` | Échec de la comparaison |
| `DECISION_NOT_FOUND` | Décision non trouvée |
| `DECISION_INVALID_STATUS` | Statut de décision invalide |
| `APPLICATION_FAILED` | Échec de l'application |
| `INVENTORY_COLLECTION_FAILED` | Échec collecte inventaire |
| `ROADMAP_UPDATE_FAILED` | Échec mise à jour roadmap |

### 3.5 SynthesisService (T2.8)

| Code | Description |
| ---- | ----------- |
| `SYNTHESIS_NOT_IMPLEMENTED` | Fonctionnalité non implémentée |
| `LLM_MODEL_REQUIRED` | Modèle LLM requis |
| `MAX_CONCURRENCY_INVALID` | Concurrence max invalide |
| `TASK_FILTER_INVALID` | Filtre de tâche invalide |
| `TASK_ID_REQUIRED` | ID de tâche requis |
| `MAX_DEPTH_INVALID` | Profondeur max invalide |
| `MAX_CONTEXT_SIZE_INVALID` | Taille contexte max invalide |
| `NO_ANALYSIS_TO_CONDENSE` | Aucune analyse à condenser |
| `NO_MODEL_CONFIGURED` | Aucun modèle configuré |
| `DEFAULT_MODEL_REQUIRED` | Modèle par défaut requis |
| `BATCH_SYNTHESIS_FAILED` | Échec synthèse par lot |
| `SYNTHESIS_GENERATION_FAILED` | Échec génération synthèse |
| `CONDENSATION_FAILED` | Échec de la condensation |

### 3.6 TraceSummaryService (T2.8)

| Code | Description |
| ---- | ----------- |
| `ROOT_TASK_REQUIRED` | Tâche racine requise |
| `CHILD_TASKS_INVALID` | Tâches enfants invalides |
| `SUMMARY_GENERATION_FAILED` | Échec génération résumé |
| `EXPORT_FAILED` | Échec de l'export |

### 3.7 PowerShellExecutor (T2.8)

| Code | Description |
| ---- | ----------- |
| `NO_JSON_FOUND` | Aucun JSON dans la sortie |
| `EXECUTION_FAILED` | Échec d'exécution du script |
| `TIMEOUT` | Délai d'exécution dépassé |
| `SCRIPT_NOT_FOUND` | Script PowerShell introuvable |
| `PARSE_FAILED` | Échec du parsing de sortie |
| `CONFIG_MISSING` | Configuration manquante |

### 3.8 MessageManager (T2.8)

| Code | Description |
| ---- | ----------- |
| `MESSAGE_NOT_FOUND` | Message non trouvé |
| `MESSAGE_SEND_FAILED` | Échec d'envoi du message |
| `MESSAGE_READ_FAILED` | Échec de lecture du message |
| `INBOX_READ_FAILED` | Échec lecture boîte de réception |
| `ARCHIVE_FAILED` | Échec de l'archivage |
| `INVALID_RECIPIENT` | Destinataire invalide |
| `INVALID_MESSAGE_FORMAT` | Format de message invalide |

### 3.9 CacheManager (T2.8)

| Code | Description |
| ---- | ----------- |
| `CACHE_READ_FAILED` | Échec lecture du cache |
| `CACHE_WRITE_FAILED` | Échec écriture du cache |
| `CACHE_INVALIDATION_FAILED` | Échec invalidation du cache |
| `CACHE_PERSISTENCE_FAILED` | Échec persistance du cache |
| `CACHE_ENTRY_EXPIRED` | Entrée de cache expirée |

### 3.10 InventoryCollector (T2.8)

| Code | Description |
| ---- | ----------- |
| `SCRIPT_NOT_FOUND` | Script de collecte introuvable |
| `SCRIPT_EXECUTION_FAILED` | Échec exécution du script |
| `INVENTORY_PARSE_FAILED` | Échec parsing inventaire |
| `INVENTORY_SAVE_FAILED` | Échec sauvegarde inventaire |
| `REMOTE_MACHINE_NOT_FOUND` | Machine distante introuvable |
| `SHARED_STATE_NOT_ACCESSIBLE` | Shared-state inaccessible |

### 3.11 RooStorageDetector (T2.8)

| Code | Description |
| ---- | ----------- |
| `NO_STORAGE_FOUND` | Aucun stockage Roo détecté |
| `DETECTION_FAILED` | Échec de la détection |
| `INVALID_PATH` | Chemin de stockage invalide |

### 3.12 ExportConfigManager (T2.8)

| Code | Description |
| ---- | ----------- |
| `CONFIG_PATH_NOT_FOUND` | Chemin config introuvable |
| `CONFIG_LOAD_FAILED` | Échec chargement config |
| `CONFIG_SAVE_FAILED` | Échec sauvegarde config |
| `NO_STORAGE_DETECTED` | Aucun stockage détecté |

### 3.13 ConfigSharingService (T2.8)

| Code | Description |
| ---- | ----------- |
| `INVENTORY_INCOMPLETE` | Inventaire incomplet |
| `COLLECTION_FAILED` | Échec de la collecte |
| `PATH_NOT_AVAILABLE` | Chemin non disponible |

### 3.14 Generic

| Code | Description |
| ---- | ----------- |
| `UNKNOWN_ERROR` | Erreur inconnue |
| `FILE_SYSTEM_ERROR` | Erreur système de fichiers |
| `NETWORK_ERROR` | Erreur réseau |
| `PERMISSION_DENIED` | Permission refusée |
| `TIMEOUT` | Délai dépassé |
| `INVALID_ARGUMENT` | Argument invalide |

---

## 4. Classification Script vs Système

### 4.1 ErrorCategory (T3.7)

```typescript
enum ErrorCategory {
  SCRIPT = 'SCRIPT',   // Bug dans le code (PowerShell ou autre)
  SYSTEM = 'SYSTEM',   // Problème système (fichier, réseau, permissions)
  UNKNOWN = 'UNKNOWN'  // Impossible à déterminer
}
```

### 4.2 Indicateurs Script

Patterns détectés comme erreurs de script (bugs dans le code):

- `syntax error`
- `unexpected token`
- `variable cannot be retrieved`
- `invalid operation`
- `term not recognized`
- `missing closing`
- `cannot convert value`
- `cannot index into null array`

### 4.3 Indicateurs Système

Patterns détectés comme erreurs système (environnement):

- `cannot find path`
- `access denied`
- `timed out`
- `network path not found`
- `file not found`
- `permission denied`
- `disk full`
- `connection refused`

---

## 5. Utilisation

### 5.1 Créer une Erreur

```typescript
import { StateManagerError, MessageManagerErrorCode } from '../../types/errors.js';

throw new StateManagerError(
  'Message non trouvé',
  MessageManagerErrorCode.MESSAGE_NOT_FOUND,
  'MessageManager',
  { messageId: 'msg-123' }
);
```

### 5.2 Utiliser une Classe Spécialisée

```typescript
import { MessageManagerError, MessageManagerErrorCode } from '../../types/errors.js';

throw new MessageManagerError(
  'Message non trouvé',
  MessageManagerErrorCode.MESSAGE_NOT_FOUND,
  { messageId: 'msg-123' }
);
```

### 5.3 Vérifier un Code d'Erreur

```typescript
import { isErrorCode, MessageManagerErrorCode } from '../../types/errors.js';

try {
  // ...
} catch (error) {
  if (isErrorCode(error, MessageManagerErrorCode.MESSAGE_NOT_FOUND)) {
    // Gérer le cas message non trouvé
  }
}
```

### 5.4 Convertir une Erreur Standard

```typescript
import { createErrorFromStandardError } from '../../types/errors.js';

try {
  // ...
} catch (error) {
  throw createErrorFromStandardError(
    error,
    'UNKNOWN_ERROR',
    'MyService',
    'Opération échouée'
  );
}
```

---

## Historique des Modifications

| Date       | Version | Auteur      | Description                    |
| ---------- | ------- | ----------- | ------------------------------ |
| 2026-01-15 | 1.0.0   | Claude Code | Création initiale (T2.8 docs)  |

---

**Document créé par:** Claude Code
**Référence:** T2.8 - Amélioration de la gestion des erreurs
**Fichier source:** `src/types/errors.ts`

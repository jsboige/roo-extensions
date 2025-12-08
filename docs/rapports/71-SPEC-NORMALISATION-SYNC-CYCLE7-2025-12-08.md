# Spécification Technique - Cycle 7 : Normalisation & Synchronisation (SDDD)

**Date** : 2025-12-08
**Auteur** : Roo (Architecte)
**Statut** : Draft
**Référence** : Cycle 7

## 1. Introduction

Ce document définit les spécifications techniques pour l'implémentation de la couche de **Normalisation** et du moteur de **Synchronisation** dans RooSync v2.1. L'objectif est de permettre le partage de configurations entre environnements hétérogènes (Windows/Mac/Linux, chemins différents, secrets locaux) sans fuite de données ni corruption de chemins.

## 2. Architecture de Normalisation

La normalisation est le processus de transformation d'une configuration "brute" (liée à une machine spécifique) en une configuration "canonique" (agnostique de la machine).

### 2.1. `NormalizationService`

Un nouveau service `NormalizationService` sera créé dans `mcps/internal/servers/roo-state-manager/src/services/`.

**Interface :**
```typescript
interface INormalizationService {
  normalize(content: any, type: ConfigType): Promise<any>;
  denormalize(content: any, type: ConfigType, context: MachineContext): Promise<any>;
}

type ConfigType = 'mcp_config' | 'mode_definition' | 'profile_settings';

interface MachineContext {
  os: 'windows' | 'linux' | 'darwin';
  homeDir: string;
  rooRoot: string;
  // ... autres variables contextuelles
}
```

### 2.2. Règles de Transformation

#### A. Chemins de Fichiers (Paths)
Les chemins absolus doivent être convertis en chemins relatifs ou utilisant des variables d'environnement standardisées.

*   **Règle 1 (Home)** : Remplacer le répertoire utilisateur par `%USERPROFILE%` (Windows) ou `$HOME` (Unix).
    *   *Exemple* : `C:\Users\jsboi\Documents` -> `%USERPROFILE%\Documents`
*   **Règle 2 (Roo Root)** : Remplacer la racine de l'extension par `%ROO_ROOT%`.
    *   *Exemple* : `d:\Dev\roo-extensions\mcps` -> `%ROO_ROOT%\mcps`
*   **Règle 3 (Séparateurs)** : Normaliser tous les séparateurs de chemin vers `/` (forward slash) dans la version canonique.

#### B. Secrets et Données Sensibles
Les clés API et autres secrets ne doivent jamais être synchronisés en clair.

*   **Règle 1 (Détection)** : Identifier les champs sensibles par nom (ex: `apiKey`, `token`, `password`) ou par pattern.
*   **Règle 2 (Placeholder)** : Remplacer la valeur par un placeholder `{{SECRET:NOM_DU_CHAMP}}`.
*   **Règle 3 (Dénormalisation)** : Lors de l'application, tenter de restaurer la valeur depuis la configuration locale existante ou laisser le placeholder si aucune valeur n'est trouvée (l'utilisateur devra la remplir).

### 2.3. Intégration dans `ConfigSharingService`

*   **Collecte (`collectConfig`)** :
    1.  Lire le fichier source.
    2.  Appliquer `NormalizationService.normalize()`.
    3.  Calculer le hash sur le contenu normalisé.
    4.  Écrire le contenu normalisé dans le package temporaire.

*   **Application (`applyConfig`)** :
    1.  Lire le fichier normalisé du package.
    2.  Construire le `MachineContext` local.
    3.  Appliquer `NormalizationService.denormalize()`.
    4.  Écrire le fichier dénormalisé sur le disque.

## 3. Workflow de Synchronisation

Le workflow s'appuie sur le `BaselineService` et le `GranularDiffDetector`.

### 3.1. Machine à États de la Décision

Chaque différence détectée devient une `SyncDecision` avec un cycle de vie strict :

1.  **PENDING** : Différence détectée, en attente d'analyse.
2.  **APPROVED** : L'utilisateur (ou une règle auto) a validé l'action à entreprendre.
3.  **REJECTED** : L'utilisateur a refusé la synchronisation (ignore).
4.  **APPLIED** : L'action a été exécutée avec succès.
5.  **FAILED** : L'action a échoué.

### 3.2. Stratégies de Résolution

Pour chaque différence, le système propose une action par défaut :

*   **`sync_to_baseline`** : Écraser la valeur locale par celle de la baseline (Standardisation).
*   **`keep_target`** : Garder la valeur locale et mettre à jour la baseline (Promotion).
*   **`manual_review`** : Demander une intervention humaine (Conflit complexe).

### 3.3. Application Granulaire

L'application ne doit pas écraser tout le fichier, mais cibler uniquement les changements approuvés.
Cela nécessite d'utiliser un moteur de patch JSON (ex: `json-patch` ou implémentation custom) capable de modifier une propriété précise sans toucher au reste (préservant les commentaires si possible, sinon tant pis pour le JSON standard).

## 4. Plan de Tests

### 4.1. Tests Unitaires
*   `NormalizationService` : Tester les regex de chemins sur Windows et Linux. Tester le masquage/démasquage de secrets.
*   `ConfigSharingService` : Mocker `NormalizationService` et vérifier les appels.

### 4.2. Tests d'Intégration
*   Cycle complet : Collecte (Machine A) -> Normalisation -> Publication -> Application (Machine B) -> Dénormalisation.
*   Vérifier que les chemins sont corrects sur la Machine B.

## 5. Livrables Attendus

1.  `NormalizationService.ts` + Tests.
2.  Mise à jour de `ConfigSharingService.ts`.
3.  Mise à jour de `BaselineService.ts` pour supporter l'application réelle.
4.  Documentation utilisateur mise à jour.
# Spécification Technique - Cycle 7 : Normalisation Avancée & Synchronisation Granulaire

**Date** : 2025-12-08
**Auteur** : Roo (Architecte)
**Statut** : Draft
**Référence** : Cycle 7

## 1. Introduction

Ce document spécifie l'architecture technique pour la normalisation des configurations et le processus de synchronisation granulaire dans RooSync. L'objectif est de permettre le partage de configurations entre environnements hétérogènes (Windows/Linux, chemins différents) tout en préservant la sécurité (secrets) et la flexibilité (surcharges locales).

## 2. Normalisation Avancée (`ConfigNormalizationService`)

Le service actuel gère les cas simples. Nous devons l'étendre pour supporter :

### 2.1. Règles de Normalisation

| Type | Règle | Exemple Source | Exemple Normalisé |
| :--- | :--- | :--- | :--- |
| **Chemins Absolus** | Détection intelligente des racines connues (Home, Workspace, Temp) | `C:\Users\Bob\Dev\Project` | `%USERPROFILE%/Dev/Project` |
| **Séparateurs** | Standardisation POSIX | `path\to\file` | `path/to/file` |
| **Secrets** | Détection par clés et valeurs (entropie/patterns) | `"apiKey": "sk-12345"` | `"apiKey": "{{SECRET:apiKey}}"` |
| **Variables Env** | Préservation des variables existantes | `%APPDATA%\Code` | `%APPDATA%/Code` |

### 2.2. Stratégie de Dénormalisation

Lors de l'application sur une machine cible :
1.  Résolution des placeholders standards (`%USERPROFILE%`, `%ROO_ROOT%`).
2.  Adaptation des séparateurs à l'OS cible.
3.  Injection des secrets depuis le coffre-fort local (ou prompt utilisateur si manquant).

## 3. Synchronisation Granulaire (`ConfigSharingService`)

Le workflow de synchronisation évolue pour intégrer le Diff et la Validation.

### 3.1. Workflow Complet

1.  **Collecte Locale** :
    *   Lecture des fichiers bruts.
    *   **Normalisation** (via `ConfigNormalizationService`).
    *   Génération d'un snapshot local normalisé.

2.  **Comparaison (Diff)** :
    *   Téléchargement de la Baseline (version cible).
    *   Comparaison JSON profonde (Deep Diff) entre Snapshot Local et Baseline.
    *   Identification des :
        *   **Ajouts** (nouvelles clés/fichiers).
        *   **Modifications** (valeurs différentes).
        *   **Suppressions** (clés absentes de la Baseline).
        *   **Conflits** (modifications locales vs distantes).

3.  **Rapport de Diff** :
    *   Génération d'un objet `DiffReport` structuré.
    *   Catégorisation par sévérité (Info, Warning, Critical).

4.  **Validation** :
    *   Présentation du `DiffReport` à l'utilisateur (ou auto-validation selon politique).
    *   Sélection des changements à appliquer.

5.  **Application** :
    *   Backup de l'état actuel.
    *   **Dénormalisation** des valeurs validées pour le contexte local.
    *   Écriture atomique des fichiers.

## 4. Structure des Données

### 4.1. DiffReport

```typescript
interface DiffReport {
  timestamp: string;
  sourceVersion: string;
  targetVersion: string;
  changes: ConfigChange[];
  summary: {
    added: number;
    modified: number;
    deleted: number;
    conflicts: number;
  };
}

interface ConfigChange {
  id: string;
  path: string[]; // Chemin JSON (ex: ["mcpServers", "github", "env"])
  type: 'add' | 'modify' | 'delete';
  oldValue?: any;
  newValue?: any;
  severity: 'info' | 'warning' | 'critical';
}
```

## 5. Plan d'Implémentation

### Phase 1 : Normalisation Robuste
*   Améliorer `ConfigNormalizationService` avec support Regex avancé.
*   Ajouter tests unitaires pour cas complexes (chemins mixtes, secrets imbriqués).

### Phase 2 : Moteur de Diff
*   Créer `ConfigDiffService`.
*   Implémenter l'algorithme de Deep Diff.
*   Générer `DiffReport`.

### Phase 3 : Orchestration & CLI
*   Mettre à jour `ConfigSharingService` pour utiliser `ConfigDiffService`.
*   Exposer les commandes via MCP (`roosync_diff`, `roosync_sync`).

## 6. Critères de Succès
*   Une config Windows peut être appliquée sur Linux sans erreur de chemin.
*   Les secrets ne transitent jamais en clair dans la Baseline.
*   L'utilisateur peut voir exactement ce qui va changer avant application.
# Rapport d'Arbitrage des Configurations Roo - 2025-12-10

## 1. Contexte et Objectifs

Ce rapport présente l'analyse des configurations des agents Roo (modes, paramètres, profils) suite à la tentative de centralisation via RooSync. L'objectif est d'identifier les divergences entre les différentes sources de configuration locales et de proposer des arbitrages pour l'unification dans le Shared State.

**Note technique :** L'analyse s'appuie sur une comparaison manuelle des fichiers sources, l'outil d'export automatique de baseline ayant rencontré des problèmes techniques (chemins incorrects dans le script d'inventaire, corrigés durant l'intervention).

## 2. Fichiers Analysés

| Source | Fichier | Description |
|--------|---------|-------------|
| **Roo-Config** | `roo-config/settings/modes.json` | Configuration centrale définissant la liste des modes, leurs outils et modèles par défaut. |
| **Roo-Modes** | `roo-modes/configs/modes.json` | Configuration locale partielle définissant un sous-ensemble de modes. |
| **Roo-Modes** | `roo-modes/configs/standard-modes.json` | Configuration détaillée contenant les `customInstructions` (prompts système) pour tous les modes. |
| **Profiles** | `profiles/qwen3-parameters.json` | Paramètres spécifiques pour les modèles Qwen. |
| **Baseline** | `.shared-state/baseline-analysis.json` | État perçu par RooSync (avant correction des chemins). |

## 3. Analyse des Différences et Conflits

### 3.1. Définition des Modes (`modes.json`)

**Constat :** Il existe une duplication et une incohérence entre `roo-config` et `roo-modes`.

*   **`roo-config/settings/modes.json` (Référence Centrale) :**
    *   Définit **12 modes** complets : `code`, `code-simple`, `code-complex`, `debug-simple`, `debug-complex`, `architect-simple`, `architect-complex`, `ask-simple`, `ask-complex`, `orchestrator-simple`, `orchestrator-complex`, `manager`.
    *   Contient les métadonnées : `slug`, `name`, `description`, `allowedFilePatterns`, `defaultModel`, `tools`.
    *   **Ne contient pas** les `customInstructions`.

*   **`roo-modes/configs/modes.json` (Local/Partiel) :**
    *   Ne définit que **5 modes** : `code`, `code-simple`, `code-complex`, `orchestrator-simple`, `orchestrator-complex`.
    *   Manque les familles `debug`, `architect`, `ask` et le mode `manager`.
    *   Structure identique à `roo-config` mais contenu incomplet.

**Analyse :** Le fichier `roo-modes/configs/modes.json` semble être une version obsolète ou une extraction partielle. Il représente un risque de régression si utilisé comme source de vérité.

### 3.2. Instructions des Modes (`standard-modes.json`)

**Constat :** Les instructions détaillées (le "cerveau" des agents) sont isolées.

*   **`roo-modes/configs/standard-modes.json` :**
    *   Contient les définitions complètes avec `customInstructions` (prompts longs et détaillés) pour l'ensemble des modes (y compris ceux manquants dans `roo-modes/configs/modes.json`).
    *   Utilise une structure différente : racine `customModes` (au lieu de `modes`).
    *   Définit également un mode utilitaire `mode-family-validator`.

**Analyse :** C'est ce fichier qui contient la véritable intelligence des modes. Il est actuellement déconnecté de la configuration structurelle de `roo-config`.

### 3.3. Inventaire RooSync

**Constat :** Le script d'inventaire (`Get-MachineInventory.ps1`) utilisait des chemins absolus (`C:\dev\...`) incorrects pour l'environnement actuel (`D:\Dev\...`).
**Conséquence :** La baseline actuelle dans le Shared State considère les modes comme "absents".
**Correction :** Le script a été corrigé pour utiliser des chemins relatifs dynamiques. La prochaine synchronisation remontera un état correct.

## 4. Options d'Arbitrage

### Option A : Unification dans `roo-config` (Recommandée)
Fusionner toutes les informations dans `roo-config` pour avoir une source unique de vérité.
*   **Action :** Injecter les `customInstructions` de `standard-modes.json` dans `roo-config/settings/modes.json`.
*   **Action :** Supprimer `roo-modes/configs/modes.json` (obsolète).
*   **Action :** Archiver `roo-modes/configs/standard-modes.json` ou le garder comme source de génération.
*   **Avantage :** Simplification radicale, un seul fichier JSON à charger pour l'extension.

### Option B : Séparation Structure / Contenu
Garder la structure dans `roo-config` et les prompts dans `roo-modes`.
*   **Action :** Maintenir `roo-config/settings/modes.json` comme définition de l'architecture (quels modes existent, quels outils).
*   **Action :** Utiliser `roo-modes/configs/standard-modes.json` uniquement pour charger les prompts au runtime.
*   **Avantage :** Séparation des préoccupations (Config vs Intelligence).
*   **Inconvénient :** Complexité de chargement (nécessite de merger deux fichiers au runtime).

## 5. Points nécessitant une décision utilisateur

1.  **Validation de la suppression de `roo-modes/configs/modes.json` :** Ce fichier est-il utilisé par un processus spécifique (ex: tests, déploiement partiel) ou peut-il être supprimé sans risque ?
2.  **Stratégie de fusion :** Préférez-vous l'Option A (Fichier unique consolidé) ou l'Option B (Séparation) ?
3.  **Validation du correctif d'inventaire :** Confirmer que la modification du script `Get-MachineInventory.ps1` (chemins dynamiques) peut être committée et poussée.

## 6. Prochaines étapes techniques

1.  Committer la correction de `scripts/inventory/Get-MachineInventory.ps1`.
2.  Exécuter une nouvelle synchronisation complète (`collect` + `publish`) pour mettre à jour le Shared State avec les vraies données (maintenant que le script fonctionne).
3.  Appliquer la décision d'arbitrage choisie (fusion ou nettoyage).

# Rapport de Mission Phase 4 - Cycle 6 : Analyse Diff & Baseline (SDDD)

**Date** : 2025-12-08
**Auteur** : Roo (Architecte)
**Statut** : Validé
**Référence** : Cycle 6 - Phase 4

## 1. Objectifs de la Phase

Cette phase vise à établir les fondations théoriques et techniques pour la synchronisation des configurations Roo (MCP, Modes) entre différentes machines. L'objectif est de passer d'une gestion ad-hoc à une gestion pilotée par une **Baseline** partagée et un algorithme de **Diff** robuste.

## 2. État des Lieux (Grounding)

### 2.1 Collecte Distribuée
Comme anticipé dans le rapport de la Phase 3 (`68-RAPPORT-PHASE3...`), le répertoire de collecte `.shared-state/configs/` est vide.
*   **Cause** : Problème de détection des chemins de configuration sur les agents distants.
*   **Conséquence** : L'analyse comparative inter-agents est impossible à ce stade.
*   **Décision** : Nous utilisons la **configuration locale de l'Orchestrateur** comme "Candidat Baseline" unique pour définir les standards.

### 2.2 Configuration Locale (Candidat Baseline)
L'analyse de la configuration locale a révélé les points critiques suivants :

#### A. Configuration MCP (`mcp_settings.json`)
*   **Chemins Absolus** : Omniprésents.
    *   Exemple : `D:/Dev/roo-extensions/mcps/internal/servers/...`
    *   Exemple : `C:\\Users\\jsboi\\AppData\\Local\\Programs\\Python\\Python310\\python.exe`
    *   **Problème** : Ces chemins sont spécifiques à la machine et ne peuvent pas être partagés tels quels.
*   **Secrets** : Présents en clair ou via variables d'environnement.
    *   Exemple : `GITHUB_TOKEN`, `GITHUB_ACCOUNTS_JSON`.
    *   **Problème** : Risque de sécurité majeur si partagé.
*   **État** : Mélange de serveurs activés/désactivés (`disabled: true/false`).

#### B. Configuration Modes (`standard-modes-updated.json`)
*   **Structure** : Liste d'objets JSON définissant `slug`, `name`, `roleDefinition`, `customInstructions`.
*   **Contenu** : Instructions longues et complexes (ex: Manager, Code Complex).
*   **Portabilité** : Haute. Pas de dépendance système apparente dans les instructions (sauf références à des outils MCP spécifiques comme `win-cli`).

## 3. Définition de la Baseline

La **Baseline** est la version de référence de la configuration, stockée dans `.shared-state/baseline/`. Elle doit être **agnostique** de l'environnement spécifique.

### 3.1 Structure de la Baseline
```
.shared-state/baseline/
├── mcp/
│   ├── mcp_settings.json       # Configuration MCP normalisée
│   └── overrides/              # Surcharges spécifiques (OS, Machine) - Futur
├── modes/
│   ├── modes.json              # Configuration des modes
│   └── prompts/                # Instructions extraites (pour lisibilité)
└── profiles/
    └── settings.json           # Paramètres globaux VSCode/Roo
```

### 3.2 Règles de Normalisation (Sanitization)

Pour transformer une config locale en Baseline, les règles suivantes s'appliquent :

1.  **Chemins (Paths)** :
    *   Remplacer le chemin du workspace par `{{WORKSPACE_ROOT}}`.
    *   Remplacer le chemin utilisateur par `{{USER_HOME}}`.
    *   Remplacer les chemins d'exécutables standards (node, python) par `{{NODE_BIN}}`, `{{PYTHON_BIN}}`.
2.  **Secrets** :
    *   Remplacer toutes les valeurs sensibles (clés API, tokens) par `{{SECRET:NOM_DU_SECRET}}`.
    *   Exclure les blocs `env` contenant des secrets non gérés.
3.  **Format** :
    *   JSON standardisé, indenté (2 espaces), clés triées alphabétiquement pour minimiser les diffs de formatage.

## 4. Spécification de l'Algorithme Diff

L'algorithme de comparaison (`roosync_granular_diff`) doit détecter les divergences sémantiques entre la Config Locale et la Baseline.

### 4.1 Logique de Comparaison

1.  **Normalisation à la volée** : Avant comparaison, la Config Locale est "nettoyée" (chemins et secrets masqués) pour correspondre au format Baseline.
2.  **Comparaison Structurelle (JSON Deep Compare)** :
    *   **Objets** : Comparaison clé par clé.
    *   **Tableaux (Listes)** :
        *   *Modes* : Identification par `slug`.
        *   *MCPs* : Identification par clé du serveur (ex: `mcpServers.quickfiles`).
        *   *Args* : Comparaison ordonnée stricte.
3.  **Catégorisation des Différences** :
    *   `MISSING` : Présent dans Baseline, absent en Local.
    *   `EXTRA` : Absent dans Baseline, présent en Local.
    *   `MODIFIED` : Valeur différente.
    *   `CONFLICT` : Modification incompatible (ex: type différent).

### 4.2 Règles de Fusion (Merge Strategy)

*   **Priorité Baseline** : En cas de conflit sur une définition standard, la Baseline gagne (sauf override explicite).
*   **Préservation Locale** : Les configurations `EXTRA` locales sont préservées (non supprimées) par défaut, mais signalées.
*   **Mise à jour Intelligente** :
    *   Si un Mode est mis à jour dans la Baseline, la version locale est écrasée.
    *   Si un MCP est mis à jour, ses arguments sont mis à jour mais son état (`disabled`) local est préservé si possible.

## 5. Conclusion et Prochaines Étapes

Cette phase a permis de définir comment transformer des configurations hétérogènes en un standard partagé.

**Prochaines actions (Phase 5 - Implémentation)** :
1.  Implémenter la logique de **Normalisation** dans `ConfigSharingService`.
2.  Implémenter l'algorithme de **Diff Granulaire**.
3.  Créer la première **Baseline** à partir de la configuration locale nettoyée.
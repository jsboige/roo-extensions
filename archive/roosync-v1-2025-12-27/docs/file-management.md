# Rapport sur la Gestion des Fichiers de Synchronisation

Le répertoire de synchronisation, dont le chemin est défini dans votre fichier `RooSync/.env`, est le cœur du système `RooSync`. Il contient quatre fichiers essentiels qui assurent le suivi, la configuration et la création de rapports.

---

## 1. `sync-dashboard.json`

*   **Rôle :** **Tableau de bord de l'état des machines.** Ce fichier est un inventaire de toutes les machines qui ont exécuté le script de synchronisation. Il enregistre le "contexte" de chaque machine (système d'exploitation, version de PowerShell, modules Roo installés, etc.) à chaque exécution.
*   **Gestion par le script :**
    *   **Lecture :** Au début de chaque exécution, le script lit ce fichier.
    *   **Mise à jour :** Il identifie la machine actuelle et met à jour son état avec les informations les plus récentes. Si la machine est nouvelle, une entrée est créée.
    *   **Écriture :** Le fichier est réécrit avec les informations mises à jour.

---

## 2. `sync-report.md`

*   **Rôle :** **Rapport de contexte lisible.** C'est un rapport au format Markdown qui présente de manière claire le dernier contexte d'exécution pour chaque machine. Cela permet de voir rapidement l'état de l'environnement de chaque utilisateur.
*   **Gestion par le script :**
    *   **Lecture et Mise à jour :** Le script recherche une section spécifique délimitée par `<!-- START: RUSH_SYNC_CONTEXT -->` et `<!-- END: RUSH_SYNC_CONTEXT -->`.
    *   **Écriture :** Il remplace le contenu de cette section par les informations les plus fraîches du contexte d'exécution actuel. Si le fichier n'existe pas, il est créé.

---

## 3. `sync-config.ref.json`

*   **Rôle :** **Configuration de Référence.** C'est la "source de vérité" pour la configuration du projet. La configuration locale de chaque machine est comparée à ce fichier pour détecter les dérives.
*   **Gestion par le script :**
    *   **Initialisation :** Si ce fichier n'existe pas lors de la première exécution de l'action `Compare-Config`, la configuration locale de l'utilisateur (`RooSync/.config/sync-config.json`) est copiée pour servir de première référence.
    *   **Lecture :** L'action `Compare-Config` utilise ce fichier comme base pour la comparaison.
    *   **Écriture :** Ce fichier n'est **jamais** modifié automatiquement, sauf lors d'une action explicite de l'utilisateur via l'action `Apply-Decisions` après avoir approuvé un changement dans la `sync-roadmap.md`.

---

## 4. `sync-roadmap.md`

*   **Rôle :** **Feuille de route des décisions.** Ce fichier Markdown sert de journal pour toutes les différences de configuration détectées et de suivi pour leur résolution.
*   **Gestion par le script :**
    *   **Écriture (par `Compare-Config`) :** Chaque fois que l'action `Compare-Config` détecte une différence entre la configuration locale et la configuration de référence, elle ajoute un bloc "DECISION" à ce fichier. Ce bloc contient les détails de la différence, le contexte et une case à cocher pour l'approbation.
    *   **Lecture (par `Apply-Decisions`) :** L'action `Apply-Decisions` lit ce fichier pour trouver les décisions qui ont été manuellement marquées comme "approuvées" (en cochant la case `[x]`).
    *   **Mise à jour (par `Apply-Decisions`) :** Une fois qu'une décision est appliquée (c'est-à-dire que la configuration de référence est mise à jour), le bloc de décision correspondant dans ce fichier est marqué comme "archivé" pour conserver un historique.

---

## 5. Sources de Vérité pour la Configuration de l'Environnement Roo

Pour obtenir un état précis de l'environnement Roo actif, `RooSync` ne scanne pas les répertoires de plugins. Il se base sur des fichiers de configuration spécifiques qui agissent comme une "source de vérité".

### Configuration des MCPs (Model Context Protocol)

*   **Fichier de Configuration Unique :** La liste des serveurs MCP actifs et leur configuration est centralisée dans un seul fichier JSON.
*   **Emplacement :** `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
*   **Logique :** Le script lit ce fichier et considère un MCP comme **actif** si sa propriété `"enabled"` est à `true`.

### Configuration des Modes

La configuration des modes Roo est définie par une agrégation intelligente de deux fichiers, permettant à la fois une configuration globale et des surcharges spécifiques au projet.

1.  **Configuration Globale (Base) :**
    *   **Fichier :** `custom_modes.json`
    *   **Emplacement :** `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`
    *   **Rôle :** Définit l'ensemble des modes de base disponibles pour l'utilisateur sur toutes les instances de VS Code.

2.  **Configuration Locale (Surcharge) :**
    *   **Fichier :** `.roomodes`
    *   **Emplacement :** À la racine du projet (`d:/roo-extensions/.roomodes`).
    *   **Rôle :** Permet de surcharger la configuration globale. Les modes définis ici remplacent ceux ayant le même `slug` dans le fichier global, ou s'ajoutent à la liste s'ils sont nouveaux.

*   **Logique d'Agrégation :**
    1.  Le script lit d'abord tous les modes du fichier global (`custom_modes.json`).
    2.  Ensuite, il lit tous les modes du fichier local (`.roomodes`).
    3.  Il fusionne les deux listes :
        *   Si un mode du fichier local a le même `slug` qu'un mode du fichier global, **la version locale écrase la version globale**.
        *   Les modes uniques à chaque fichier sont conservés.
    4.  Finalement, un mode est considéré comme **actif** dans la liste fusionnée si sa propriété `"enabled"` est à `true` (ou si la propriété n'existe pas, ce qui est traité comme `true`).
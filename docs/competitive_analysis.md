# Analyse Concurrentielle des MCPs GitHub Projects

Ce document analyse les fonctionnalités, les approches techniques et les caractéristiques uniques de plusieurs serveurs MCP (Model Context Protocol) concurrents pour la gestion de projets GitHub.

---

## 1. github/github-mcp-server

*   **URL :** [https://github.com/github/github-mcp-server](https://github.com/github/github-mcp-server)

### Outils Fournis

Ce serveur officiel de GitHub est extrêmement complet et ne se limite pas aux projets. Les outils sont organisés en "toolsets" qui peuvent être activés ou désactivés :
*   `context`: Informations sur l'utilisateur et le contexte.
*   `actions`: Opérations sur les GitHub Actions.
*   `code_security`: Outils liés à la sécurité du code (Code Scanning).
*   `discussions`: Gestion des discussions GitHub.
*   `issues`: Gestion complète des issues.
*   `notifications`: Gestion des notifications.
*   `orgs`: Opérations au niveau de l'organisation.
*   `pull_requests`: Gestion complète des Pull Requests.
*   `repos`: Gestion des dépôts (création, lecture de fichiers, commits, etc.).
*   `secret_protection`: Protection des secrets (Secret Scanning).
*   `users`: Recherche d'utilisateurs.

### Fonctionnalités Uniques

*   **Couverture quasi complète de l'API GitHub :** Va bien au-delà de la simple gestion de projets.
*   **Serveur distant hébergé par GitHub :** Propose une version "officielle" hébergée qui simplifie la configuration (via `api.githubcopilot.com/mcp/`).
*   **"Toolsets" configurables :** Permet d'activer uniquement les groupes de fonctionnalités nécessaires, réduisant la complexité pour le modèle de langage.
*   **Découverte dynamique d'outils :** Une fonctionnalité bêta qui permet au client MCP d'activer des "toolsets" à la volée en fonction de la demande de l'utilisateur.
*   **Mode Lecture Seule :** Une option de démarrage pour empêcher toute modification.

### Approche Technique

*   **Langage :** Écrit en **Go**.
*   **Déploiement :** Principalement via **Docker**, ce qui simplifie grandement l'installation et la gestion des dépendances.
*   **Authentification :** Prend en charge l'OAuth et les Personal Access Tokens (PAT).

---

## 2. kunwarVivek/mcp-github-project-manager

*   **URL :** [https://github.com/kunwarVivek/mcp-github-project-manager](https://github.com/kunwarVivek/mcp-github-project-manager)

### Outils Fournis

Ce serveur est très spécialisé dans la gestion de projet assistée par IA.
*   **Génération de PRD :** `generate_prd`
*   **Analyse de PRD :** `parse_prd`
*   **Gestion de fonctionnalités :** `add_feature`
*   **Analyse de complexité de tâches :** `analyze_task_complexity`
*   **Recommandation de tâches :** `get_next_task`
*   **Décomposition de tâches :** `expand_task`
*   **Amélioration de PRD :** `enhance_prd`
*   **Traçabilité :** `create_traceability_matrix`
*   **Gestion de projet de base :** CRUD pour les projets, les milestones, les sprints, etc.

### Fonctionnalités Uniques

*   **Très orienté IA :** Son principal différenciateur est l'utilisation de l'IA pour générer des exigences (PRD) et les décomposer en tâches concrètes.
*   **Traçabilité complète des exigences :** Suit le cycle de vie complet, des exigences métier aux tâches de développement, en passant par les cas d'utilisation (conforme à la norme IEEE 830).
*   **Support multi-fournisseurs d'IA :** Intègre Anthropic Claude, OpenAI GPT, Google Gemini et Perplexity, avec un système de fallback.
*   **Génération de contexte améliorée :** Peut enrichir les tâches avec un contexte métier, technique et d'implémentation généré par l'IA.

### Approche Technique

*   **Langage :** **TypeScript** (Node.js).
*   **API GitHub :** Utilise l'API **GraphQL** de GitHub.
*   **Architecture :** Suit les principes de la Clean Architecture.
*   **Tests :** Dispose d'une suite de tests E2E très complète qui peut fonctionner avec des API mockées ou réelles.

---

## 3. taylor-lindores-reeves/mcp-github-projects

*   **URL :** [https://github.com/taylor-lindores-reeves/mcp-github-projects](https://github.com/taylor-lindores-reeves/mcp-github-projects)

### Outils Fournis

Les opérations disponibles se concentrent sur les fonctionnalités de base de GitHub Projects V2.
*   Gestion des projets (CRUD).
*   Gestion des champs et des éléments d'un projet.
*   Conversion de "draft issues" en issues réelles.
*   Archivage et désarchivage d'éléments.
*   Lecture et ajout d'issues aux projets.
*   Lecture d'informations sur les dépôts.

### Fonctionnalités Uniques

*   **Simplicité et focus :** Se concentre uniquement sur GitHub Projects V2, ce qui en fait une solution plus légère.
*   **Contrôle d'accès aux dépôts :** Une variable d'environnement `ALLOWED_REPOS` permet de restreindre les opérations d'écriture à une liste de dépôts spécifiques, ce qui est une fonctionnalité de sécurité intéressante.

### Approche Technique

*   **Langage :** **TypeScript**.
*   **Runtime :** Utilise **Bun**.
*   **API GitHub :** Utilise l'API **GraphQL** et génère les types à partir du schéma.
*   **Déploiement :** Peut être installé manuellement ou via Docker.

---

## 4. Arclio/github-projects-mcp

*   **URL :** [https://github.com/Arclio/github-projects-mcp](https://github.com/Arclio/github-projects-mcp)

### Outils Fournis

Similaire au projet précédent, il offre les outils essentiels pour la gestion de projets.
*   `list_projects`: Lister les projets.
*   `get_project_fields`: Obtenir les champs d'un projet.
*   `get_project_items`: Obtenir les éléments d'un projet (avec filtrage).
*   `create_issue`: Créer une issue.
*   `add_issue_to_project`: Ajouter une issue à un projet.
*   `update_project_item_field`: Mettre à jour un champ pour un élément.
*   `create_draft_issue`: Créer une "draft issue".
*   `delete_project_item`: Supprimer un élément d'un projet.

### Fonctionnalités Uniques

*   **Mise en œuvre légère en Python :** Offre une alternative pour les écosystèmes Python.
*   **Filtrage côté serveur :** La fonction `get_project_items` prend en charge le filtrage, ce qui peut être plus efficace que de filtrer côté client.

### Approche Technique

*   **Langage :** **Python**.
*   **Gestion des dépendances :** Utilise **uv**, un gestionnaire de paquets Python moderne et rapide.
*   **API GitHub :** Utilise l'API **GraphQL**.
*   **Installation :** Peut être installé depuis la source ou via le paquet publié sur PyPI.

---

## Analyse des Écarts et Feuille de Route

En comparant nos outils actuels avec ceux des concurrents, plusieurs écarts fonctionnels critiques ont été identifiés. Cette feuille de route propose un ordre d'implémentation pour combler ces manques, en priorisant les fonctionnalités de base (CRUD - Create, Read, Update, Delete) avant les améliorations plus complexes.

- [x] **1. Compléter le CRUD des éléments de projet :** Ajouter un outil `delete_project_item` pour supprimer une carte (issue, note) d'un projet. C'est le manque le plus critique pour la gestion de base.
- [x] **2. Compléter le CRUD des projets :**
    - [x] Ajouter un outil `update_project` pour modifier le titre, la description ou l'état d'un projet existant.
    - [x] Ajouter un outil `delete_project` pour permettre la suppression complète d'un projet.
- [x] **3. Création de contenu natif :** Ajouter un outil `create_issue` qui crée une nouvelle issue dans un dépôt et peut optionnellement l'ajouter directement à un projet. Cela fluidifiera considérablement le flux de travail.
- [x] **4. Gestion des champs de projet :** Implémenter une suite d'outils pour le CRUD des champs de projet (ex: `create_project_field`, `update_project_field`, `delete_project_field`) pour permettre la personnalisation des tableaux (ex: ajouter une colonne "Priorité").
- [x] **5. Fin du cycle de vie des "Drafts" :** Ajouter un outil `convert_draft_to_issue` pour convertir une note en une véritable issue, une fonctionnalité de base des projets GitHub.
- [ ] **6. Archivage :** Ajouter des outils pour `archive_project_item` et `unarchive_project_item` afin de nettoyer la vue du projet sans suppression définitive.
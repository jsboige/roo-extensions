# Refonte de l'Architecture de Découverte de Conversations

**Auteur:** Roo, Architecte IA
**Date:** 2025-07-21
**Statut:** En cours de rédaction

## 1. Contexte et Problème

L'outil `detect_roo_storage` du MCP `roo-state-manager` est confronté à une impasse technique. Son mécanisme de découverte, basé sur un scan intensif du système de fichiers via `glob`, provoque des erreurs fatales et une "explosion de contexte" dans l'environnement du serveur MCP.

**Cause Racine Identifiée :** L'appel à `glob` depuis le processus isolé du MCP est intrinsèquement trop coûteux et instable, indépendamment de la quantité de données retournées.

**Postulat :** Toute solution future doit **impérativement prohiber** le scan dynamique et à grande échelle du système de fichiers depuis le MCP `roo-state-manager`.

## 2. Architectures Alternatives Proposées

Nous déplaçons la responsabilité de la découverte des conversations de l'environnement contraint du MCP vers l'environnement plus robuste de l'extension VS Code. Le MCP ne devient plus qu'un simple consommateur d'une information pré-établie.

Voici trois approches pour atteindre cet objectif :

---

### Option 1 : Fichier d'Index Centralisé (Manifest File)

Cette approche est la plus simple et la plus robuste. L'extension VS Code maintient un fichier d'index (ex: `.roo/conversations.json`) qui contient la liste de tous les chemins de conversations valides.

**Flux de données :**
1.  **Extension (Événement) :** À la création, suppression, ou au démarrage, l'extension met à jour le fichier `conversations.json`.
2.  **MCP (Appel) :** L'outil `detect_roo_storage` est modifié. Au lieu de scanner le disque, il se contente de lire et de parser le fichier `.roo/conversations.json`.

**Diagramme de Flux :**
```mermaid
graph TD
    subgraph Extension VS Code (Environnement Principal)
        A[Création/Suppression Conversation] --> B{Logique de mise à jour};
        B --> C[Écriture dans .roo/conversations.json];
    end

    subgraph MCP roo-state-manager (Processus Isolé)
        D[Appel de detect_roo_storage] --> E{Lire .roo/conversations.json};
        E --> F[Parser JSON et retourner le contenu];
    end

    C -.-> E;
```

**Avantages :**
- **Simplicité extrême :** La modification du MCP est triviale (une lecture de fichier au lieu d'un `glob`).
- **Robustesse maximale :** Élimine 100% des opérations de scan côté MCP. Aucune chance d'échec lié au système de fichiers.
- **Performance :** La lecture d'un unique fichier est quasi-instantanée.
- **Centralisation :** L'état est clairement défini dans un seul fichier manifeste, facile à lire et à déboguer.

**Inconvénients :**
- **Synchronisation :** L'extension doit intercepter **tous** les cas de création/suppression pour maintenir l'index à jour. Un oubli pourrait désynchroniser l'index.

---

### Option 2 : Communication par "Push" via IPC (Inter-Process Communication)

Ici, nous utilisons le canal de communication existant pour que l'extension "pousse" activement la liste des conversations au MCP au démarrage de ce dernier.

**Flux de données :**
1.  **MCP :** Au démarrage, il entre dans un état d'attente.
2.  **Extension :** Détecte le démarrage du MCP, effectue un scan local du disque (robuste car dans le processus principal de l'extension), et envoie le résultat au MCP via un nouvel appel IPC (ex: `initialize_with_conversations`).
3.  **MCP :** Reçoit la liste, la stocke en mémoire et la sert pour tous les appels ultérieurs à `detect_roo_storage`.

**Diagramme de Flux :**
```mermaid
graph TD
    subgraph Extension VS Code (Environnement Principal)
        A[Démarrage du MCP détecté] --> B{Scan local du disque};
        B --> C[Appel IPC: initialize_with_conversations(data)];
    end

    subgraph MCP roo-state-manager (Processus Isolé)
        D[Démarrage] --> E{Attente de l'initialisation};
        F[Appel de detect_roo_storage] --> G{Retourner données en mémoire};
    end

    C --> E;
    E --> G;
```

**Avantages :**
- **Pas de fichier intermédiaire :** Évite la gestion d'un fichier manifeste.
- **État à jour au démarrage :** Le MCP a toujours la liste complète au moment où il commence à accepter des requêtes.

**Inconvénients :**
- **Complexité accrue :** Nécessite de mettre en place un nouveau protocole de communication bi-directionnel et un état d'attente dans le MCP.
- **Fragilité au démarrage :** Le MCP est inutile tant que l'extension ne l'a pas initialisé. Une erreur dans ce "handshake" est problématique.
- **État en mémoire seulement :** Si le MCP redémarre pour une raison quelconque, il perd son état et doit être réinitialisé.

---

### Option 3 : Surveillance de Fichiers (File Watcher)

Cette option est une variante de l'Option 1. L'extension gère toujours un fichier d'index, mais le MCP peut aussi écouter les changements sur ce fichier pour se mettre à jour en temps réel.

**Flux de données :**
1.  Identique à l'Option 1 pour l'écriture par l'extension et la lecture initiale par le MCP.
2.  **MCP (en plus) :** Le MCP place un "watcher" (ex: `fs.watch`) sur le fichier `conversations.json`.
3.  **MCP (Mise à jour) :** Quand le fichier change, le MCP le relit et met à jour son état interne en mémoire.

**Avantages :**
- **Mise à jour en temps réel :** Le MCP peut refléter les changements sans attendre un nouvel appel.

**Inconvénients :**
- **Complexité de gestion du watcher :** Les "file watchers" peuvent être complexes et peu fiables selon le système d'exploitation. Ils peuvent consommer des ressources et générer des événements multiples.
- **Complexité inutile :** Le modèle de requête actuel est "pull" (le client demande l'état quand il en a besoin). Une mise à jour "push" en temps réel n'est pas nécessaire et complexifie l'architecture pour un gain nul dans le cas présent.

## 3. Évaluation et Recommandation

| Critère | Option 1 (Fichier d'Index) | Option 2 (Push IPC) | Option 3 (File Watcher) |
| :--- | :---: | :---: | :---: |
| **Robustesse** | **Excellente** | Moyenne | Faible |
| **Simplicité d'implémentation** | **Excellente** | Faible | Faible |
| **Performance** | **Excellente** | Bonne | Bonne |
| **Couplage** | **Faible** | Élevé | Moyen |

---

### **Recommandation : Option 1 - Fichier d'Index Centralisé**

L'approche du **Fichier d'Index Centralisé est la solution la plus pragmatique, la plus robuste et la plus simple à mettre en œuvre.** Elle résout le problème fondamental avec une complexité minimale et un risque très faible.

Elle transforme le MCP d'un service actif et fragile en un service passif et fiable, ce qui est l'objectif principal de cette refonte. La charge de la découverte est transférée à l'extension, qui est l'endroit logique et le plus sûr pour l'exécuter.

## 4. Prochaines Étapes

1.  **Valider** cette proposition architecturale.
2.  **Planifier l'implémentation :**
    *   Modifier l'extension pour créer et maintenir `.roo/conversations.json`.
    *   Modifier le MCP `roo-state-manager` pour lire ce fichier au lieu de scanner le disque.
3.  **Passer en mode `code`** pour réaliser les modifications.

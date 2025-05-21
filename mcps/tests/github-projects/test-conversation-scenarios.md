# Scénarios de test pour le MCP GitHub Projects

Ce document contient des scénarios de test sous forme de conversations entre un utilisateur et Roo pour valider les fonctionnalités du MCP GitHub Projects.

## Table des matières

1. [Filtrage des éléments par état](#1-filtrage-des-éléments-par-état)
2. [Filtrage des éléments par champ personnalisé](#2-filtrage-des-éléments-par-champ-personnalisé)
3. [Pagination pour les éléments des projets](#3-pagination-pour-les-éléments-des-projets)
4. [Listage des champs d'un projet](#4-listage-des-champs-dun-projet)
5. [Suppression d'éléments d'un projet](#5-suppression-déléments-dun-projet)
6. [Support des champs de type itération](#6-support-des-champs-de-type-itération)
7. [Création d'issues et ajout direct à un projet](#7-création-dissues-et-ajout-direct-à-un-projet)
8. [Mise à jour des paramètres d'un projet](#8-mise-à-jour-des-paramètres-dun-projet)

## 1. Filtrage des éléments par état

### Scénario 1.1: Filtrer les éléments ouverts d'un projet

**Requête de l'utilisateur:**
```
Montre-moi toutes les issues ouvertes dans mon projet "Développement API" sur GitHub.
```

**Réponse attendue de Roo:**
```
Je vais récupérer les issues ouvertes de votre projet "Développement API".

[Utilisation de l'outil github-projects.get_project avec les paramètres:
- owner: "myia-tech"
- project_number: 1
- state: "OPEN"]

Voici les issues ouvertes dans votre projet "Développement API":

1. #42 - Implémenter l'authentification OAuth2
   État: Ouvert
   Assigné à: @dev-lead
   Priorité: Haute

2. #45 - Optimiser les requêtes de la base de données
   État: Ouvert
   Assigné à: @db-specialist
   Priorité: Moyenne

3. #48 - Ajouter la documentation Swagger
   État: Ouvert
   Assigné à: @doc-writer
   Priorité: Basse

Total: 3 issues ouvertes
```

**Outils MCP utilisés:**
- `github-projects.get_project` avec le paramètre `state: "OPEN"`

**Résultats attendus:**
- Affichage correct des éléments filtrés par l'état OPEN
- Informations pertinentes pour chaque élément (numéro, titre, assigné, priorité)

### Scénario 1.2: Filtrer les éléments fermés d'un projet

**Requête de l'utilisateur:**
```
Quelles sont les issues fermées dans mon projet "Développement API" sur GitHub?
```

**Réponse attendue de Roo:**
```
Je vais récupérer les issues fermées de votre projet "Développement API".

[Utilisation de l'outil github-projects.get_project avec les paramètres:
- owner: "myia-tech"
- project_number: 1
- state: "CLOSED"]

Voici les issues fermées dans votre projet "Développement API":

1. #36 - Configurer l'environnement CI/CD
   Fermée le: 15/05/2025
   Fermée par: @devops-engineer

2. #39 - Créer les modèles de données initiaux
   Fermée le: 17/05/2025
   Fermée par: @db-specialist

Total: 2 issues fermées
```

**Outils MCP utilisés:**
- `github-projects.get_project` avec le paramètre `state: "CLOSED"`

**Résultats attendus:**
- Affichage correct des éléments filtrés par l'état CLOSED
- Informations pertinentes pour chaque élément (numéro, titre, date de fermeture, fermée par)

## 2. Filtrage des éléments par champ personnalisé

### Scénario 2.1: Filtrer les éléments par priorité

**Requête de l'utilisateur:**
```
Montre-moi toutes les tâches de haute priorité dans mon projet "Développement API".
```

**Réponse attendue de Roo:**
```
Je vais récupérer les tâches de haute priorité dans votre projet "Développement API".

[Utilisation de l'outil github-projects.get_project avec les paramètres:
- owner: "myia-tech"
- project_number: 1
- filter_field_name: "Priority"
- filter_field_value: "High"]

Voici les tâches de haute priorité dans votre projet "Développement API":

1. #42 - Implémenter l'authentification OAuth2
   État: Ouvert
   Assigné à: @dev-lead
   Date d'échéance: 25/05/2025

2. #51 - Corriger la faille de sécurité XSS
   État: Ouvert
   Assigné à: @security-expert
   Date d'échéance: 20/05/2025

Total: 2 tâches de haute priorité
```

**Outils MCP utilisés:**
- `github-projects.get_project` avec les paramètres `filter_field_name: "Priority"` et `filter_field_value: "High"`

**Résultats attendus:**
- Affichage correct des éléments filtrés par le champ personnalisé "Priority" avec la valeur "High"
- Informations pertinentes pour chaque élément (numéro, titre, état, assigné, date d'échéance)

### Scénario 2.2: Filtrer les éléments par sprint

**Requête de l'utilisateur:**
```
Quelles sont les tâches prévues pour le Sprint 3 dans mon projet "Développement API"?
```

**Réponse attendue de Roo:**
```
Je vais récupérer les tâches du Sprint 3 dans votre projet "Développement API".

[Utilisation de l'outil github-projects.get_project avec les paramètres:
- owner: "myia-tech"
- project_number: 1
- filter_field_name: "Sprint"
- filter_field_value: "Sprint 3"]

Voici les tâches prévues pour le Sprint 3 dans votre projet "Développement API":

1. #48 - Ajouter la documentation Swagger
   État: Ouvert
   Assigné à: @doc-writer
   Priorité: Basse

2. #51 - Corriger la faille de sécurité XSS
   État: Ouvert
   Assigné à: @security-expert
   Priorité: Haute

3. #53 - Implémenter la pagination des résultats
   État: Ouvert
   Assigné à: @backend-dev
   Priorité: Moyenne

Total: 3 tâches pour le Sprint 3
```

**Outils MCP utilisés:**
- `github-projects.get_project` avec les paramètres `filter_field_name: "Sprint"` et `filter_field_value: "Sprint 3"`

**Résultats attendus:**
- Affichage correct des éléments filtrés par le champ personnalisé "Sprint" avec la valeur "Sprint 3"
- Informations pertinentes pour chaque élément (numéro, titre, état, assigné, priorité)

## 3. Pagination pour les éléments des projets

### Scénario 3.1: Afficher la première page d'éléments

**Requête de l'utilisateur:**
```
Montre-moi les 5 premières tâches de mon projet "Refonte du site web".
```

**Réponse attendue de Roo:**
```
Je vais récupérer les 5 premières tâches de votre projet "Refonte du site web".

[Utilisation de l'outil github-projects.get_project avec les paramètres:
- owner: "myia-tech"
- project_number: 2
- limit: 5]

Voici les 5 premières tâches de votre projet "Refonte du site web":

1. #60 - Créer les maquettes de la page d'accueil
   État: Fermé
   Assigné à: @ui-designer

2. #61 - Implémenter la structure HTML de base
   État: Fermé
   Assigné à: @frontend-dev

3. #62 - Créer les styles CSS responsives
   État: En cours
   Assigné à: @frontend-dev

4. #63 - Optimiser les images du site
   État: En cours
   Assigné à: @media-specialist

5. #64 - Implémenter le formulaire de contact
   État: À faire
   Assigné à: @frontend-dev

Il y a d'autres tâches disponibles. Voulez-vous voir la page suivante?
```

**Outils MCP utilisés:**
- `github-projects.get_project` avec le paramètre `limit: 5`

**Résultats attendus:**
- Affichage correct des 5 premiers éléments du projet
- Indication qu'il y a d'autres éléments disponibles
- Informations pertinentes pour chaque élément (numéro, titre, état, assigné)

### Scénario 3.2: Afficher la page suivante d'éléments

**Requête de l'utilisateur:**
```
Oui, montre-moi les 5 tâches suivantes.
```

**Réponse attendue de Roo:**
```
Je vais récupérer les 5 tâches suivantes de votre projet "Refonte du site web".

[Utilisation de l'outil github-projects.get_project avec les paramètres:
- owner: "myia-tech"
- project_number: 2
- limit: 5
- cursor: "Y3Vyc29yOnYyOpK5MjAyNS0wNS0xOVQwODozMDowMCswMjowMM4Aw1Ft"]

Voici les 5 tâches suivantes de votre projet "Refonte du site web":

6. #65 - Intégrer Google Analytics
   État: À faire
   Assigné à: @seo-specialist

7. #66 - Optimiser le SEO on-page
   État: À faire
   Assigné à: @seo-specialist

8. #67 - Tester la compatibilité des navigateurs
   État: À faire
   Assigné à: @qa-tester

9. #68 - Corriger les problèmes d'accessibilité
   État: À faire
   Assigné à: @frontend-dev

10. #69 - Optimiser les performances du site
    État: À faire
    Assigné à: @performance-expert

Il y a d'autres tâches disponibles. Voulez-vous voir la page suivante?
```

**Outils MCP utilisés:**
- `github-projects.get_project` avec les paramètres `limit: 5` et `cursor: "Y3Vyc29yOnYyOpK5MjAyNS0wNS0xOVQwODozMDowMCswMjowMM4Aw1Ft"`

**Résultats attendus:**
- Affichage correct des 5 éléments suivants du projet en utilisant le curseur de pagination
- Indication qu'il y a d'autres éléments disponibles
- Informations pertinentes pour chaque élément (numéro, titre, état, assigné)

## 4. Listage des champs d'un projet

### Scénario 4.1: Lister tous les champs d'un projet

**Requête de l'utilisateur:**
```
Quels sont les champs disponibles dans mon projet "Développement API"?
```

**Réponse attendue de Roo:**
```
Je vais récupérer les champs disponibles dans votre projet "Développement API".

[Utilisation de l'outil github-projects.get_project_fields avec les paramètres:
- owner: "myia-tech"
- project_number: 1]

Voici les champs disponibles dans votre projet "Développement API":

1. Title (TEXT)
   Description: Titre de l'élément

2. Assignees (ASSIGNEES)
   Description: Personnes assignées à l'élément

3. Status (SINGLE_SELECT)
   Options:
   - Todo (Couleur: Gris)
   - In Progress (Couleur: Jaune)
   - Done (Couleur: Vert)
   - Blocked (Couleur: Rouge)

4. Priority (SINGLE_SELECT)
   Options:
   - Low (Couleur: Bleu)
   - Medium (Couleur: Jaune)
   - High (Couleur: Rouge)

5. Sprint (ITERATION)
   Itérations:
   - Sprint 1 (01/05/2025 - 15/05/2025)
   - Sprint 2 (16/05/2025 - 31/05/2025)
   - Sprint 3 (01/06/2025 - 15/06/2025)

6. Story Points (NUMBER)
   Description: Points de complexité

7. Due Date (DATE)
   Description: Date d'échéance
```

**Outils MCP utilisés:**
- `github-projects.get_project_fields`

**Résultats attendus:**
- Affichage correct de tous les champs du projet avec leurs types
- Pour les champs de type SINGLE_SELECT, affichage des options disponibles
- Pour les champs de type ITERATION, affichage des itérations configurées

## 5. Suppression d'éléments d'un projet

### Scénario 5.1: Supprimer un élément d'un projet

**Requête de l'utilisateur:**
```
Supprime la tâche #64 "Implémenter le formulaire de contact" de mon projet "Refonte du site web".
```

**Réponse attendue de Roo:**
```
Je vais supprimer la tâche #64 "Implémenter le formulaire de contact" de votre projet "Refonte du site web".

[Utilisation de l'outil github-projects.delete_project_item avec les paramètres:
- owner: "myia-tech"
- project_number: 2
- item_id: "PVTI_lADOBlfb84AZc0wgzgB1Mg"]

La tâche #64 "Implémenter le formulaire de contact" a été supprimée avec succès de votre projet "Refonte du site web".

⚠️ Attention: Cette suppression est irréversible. L'élément a été retiré du projet, mais l'issue correspondante existe toujours dans le dépôt GitHub.
```

**Outils MCP utilisés:**
- `github-projects.delete_project_item`

**Résultats attendus:**
- Confirmation de la suppression de l'élément du projet
- Avertissement indiquant que la suppression est irréversible
- Clarification que l'issue correspondante existe toujours dans le dépôt GitHub

## 6. Support des champs de type itération

### Scénario 6.1: Mettre à jour le champ d'itération d'un élément

**Requête de l'utilisateur:**
```
Déplace la tâche #51 "Corriger la faille de sécurité XSS" du Sprint 3 au Sprint 2 dans mon projet "Développement API".
```

**Réponse attendue de Roo:**
```
Je vais déplacer la tâche #51 "Corriger la faille de sécurité XSS" du Sprint 3 au Sprint 2.

[Utilisation de l'outil github-projects.get_project_fields avec les paramètres:
- owner: "myia-tech"
- project_number: 1]

[Utilisation de l'outil github-projects.get_project avec les paramètres:
- owner: "myia-tech"
- project_number: 1
- filter_field_name: "Title"
- filter_field_value: "Corriger la faille de sécurité XSS"]

[Utilisation de l'outil github-projects.update_project_item_field avec les paramètres:
- project_id: "PVT_kwDOBlfb84AZc0"
- item_id: "PVTI_lADOBlfb84AZc0wgzgB2Nz"
- field_id: "PVTF_lADOBlfb84AZc0zADOBlfb"
- field_type: "iteration"
- value: "47592c89"]

La tâche #51 "Corriger la faille de sécurité XSS" a été déplacée avec succès du Sprint 3 au Sprint 2 dans votre projet "Développement API".
```

**Outils MCP utilisés:**
- `github-projects.get_project_fields` pour obtenir les champs du projet
- `github-projects.get_project` pour trouver l'élément spécifique
- `github-projects.update_project_item_field` avec `field_type: "iteration"` pour mettre à jour le champ d'itération

**Résultats attendus:**
- Identification correcte du champ d'itération et des valeurs d'itération disponibles
- Mise à jour réussie du champ d'itération de l'élément
- Confirmation du déplacement de l'élément d'une itération à une autre

## 7. Création d'issues et ajout direct à un projet

### Scénario 7.1: Créer une issue et l'ajouter à un projet

**Requête de l'utilisateur:**
```
Crée une nouvelle issue intitulée "Ajouter la fonctionnalité de recherche avancée" dans mon dépôt "api-backend" et ajoute-la à mon projet "Développement API".
```

**Réponse attendue de Roo:**
```
Je vais créer une nouvelle issue et l'ajouter directement à votre projet "Développement API".

[Utilisation de l'outil github-projects.create_issue_and_add_to_project avec les paramètres:
- owner: "myia-tech"
- repo: "api-backend"
- title: "Ajouter la fonctionnalité de recherche avancée"
- body: "Implémenter une fonctionnalité de recherche avancée permettant aux utilisateurs de filtrer les résultats par date, catégorie et mots-clés."
- project_owner: "myia-tech"
- project_number: 1]

J'ai créé avec succès l'issue #72 "Ajouter la fonctionnalité de recherche avancée" dans le dépôt "api-backend" et je l'ai ajoutée à votre projet "Développement API".

Lien vers l'issue: https://github.com/myia-tech/api-backend/issues/72

L'issue a été ajoutée avec les valeurs par défaut pour tous les champs du projet. Voulez-vous que je mette à jour certains champs comme la priorité ou le sprint?
```

**Outils MCP utilisés:**
- `github-projects.create_issue_and_add_to_project`

**Résultats attendus:**
- Création réussie d'une nouvelle issue dans le dépôt spécifié
- Ajout réussi de l'issue au projet spécifié
- Affichage du lien vers l'issue créée
- Proposition de mettre à jour les champs du projet pour l'élément nouvellement ajouté

## 8. Mise à jour des paramètres d'un projet

### Scénario 8.1: Mettre à jour le titre et la description d'un projet

**Requête de l'utilisateur:**
```
Modifie le titre de mon projet "Refonte du site web" en "Refonte du site web corporate" et ajoute la description "Projet de modernisation du site web de l'entreprise avec focus sur l'expérience utilisateur et les performances".
```

**Réponse attendue de Roo:**
```
Je vais mettre à jour le titre et la description de votre projet.

[Utilisation de l'outil github-projects.update_project_settings avec les paramètres:
- owner: "myia-tech"
- project_number: 2
- title: "Refonte du site web corporate"
- description: "Projet de modernisation du site web de l'entreprise avec focus sur l'expérience utilisateur et les performances"]

J'ai mis à jour avec succès les paramètres de votre projet:

- Ancien titre: "Refonte du site web"
- Nouveau titre: "Refonte du site web corporate"
- Nouvelle description: "Projet de modernisation du site web de l'entreprise avec focus sur l'expérience utilisateur et les performances"

Les modifications sont maintenant visibles sur GitHub Projects.
```

**Outils MCP utilisés:**
- `github-projects.update_project_settings`

**Résultats attendus:**
- Mise à jour réussie du titre et de la description du projet
- Confirmation des modifications effectuées
- Affichage des anciennes et nouvelles valeurs

### Scénario 8.2: Modifier la visibilité d'un projet

**Requête de l'utilisateur:**
```
Rends mon projet "Développement API" public pour que toute l'équipe puisse y accéder.
```

**Réponse attendue de Roo:**
```
Je vais modifier la visibilité de votre projet "Développement API" pour le rendre public.

[Utilisation de l'outil github-projects.update_project_settings avec les paramètres:
- owner: "myia-tech"
- project_number: 1
- public: true]

J'ai modifié avec succès la visibilité de votre projet "Développement API":

- Ancienne visibilité: Privé
- Nouvelle visibilité: Public

Le projet est maintenant accessible à tous les membres de l'organisation et au public.

⚠️ Note: Rendre un projet public signifie que toutes les informations qu'il contient seront visibles par n'importe qui sur internet. Assurez-vous que cela correspond bien à votre intention.
```

**Outils MCP utilisés:**
- `github-projects.update_project_settings` avec le paramètre `public: true`

**Résultats attendus:**
- Mise à jour réussie de la visibilité du projet
- Confirmation du changement de visibilité
- Avertissement concernant les implications de rendre un projet public
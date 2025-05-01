# Documentation des Modes Personnalisés Roo

Ce document explique la structure des modes personnalisés Roo, comment les modes simples et complexes fonctionnent ensemble, et comment ajouter ou modifier des modes.

## Structure des Modes Personnalisés

Les modes personnalisés sont définis dans le fichier `.roomodes` à la racine du projet. Ce fichier contient un tableau JSON de définitions de modes, chacune avec les propriétés suivantes :

```json
{
  "slug": "code-simple",
  "name": "💻 Code Simple",
  "model": "anthropic/claude-3.5-sonnet",
  "roleDefinition": "You are Roo Code (version simple), specialized in...",
  "groups": ["read", "edit", "browser", "command", "mcp"],
  "customInstructions": "FOCUS AREAS:\n- Modifications of code < 50 lines\n..."
}
```

### Propriétés des Modes

- **slug** : Identifiant unique du mode, utilisé en interne par Roo
- **name** : Nom affiché dans l'interface utilisateur
- **model** : Modèle de langage à utiliser pour ce mode
- **roleDefinition** : Définition du rôle de l'agent, décrivant sa spécialisation
- **groups** : Groupes d'autorisations définissant les capacités de l'agent
- **customInstructions** : Instructions spécifiques pour guider le comportement de l'agent

### Groupes d'Autorisations

Les groupes d'autorisations déterminent quelles actions un mode peut effectuer :

- **read** : Permet de lire des fichiers et d'explorer le système de fichiers
- **edit** : Permet de modifier des fichiers
- **browser** : Permet d'utiliser le navigateur
- **command** : Permet d'exécuter des commandes système
- **mcp** : Permet d'utiliser le Model Context Protocol

## Architecture à Deux Niveaux (Simple/Complexe)

L'architecture à deux niveaux dédouble chaque profil d'agent en versions "simple" et "complexe" pour optimiser les coûts tout en maintenant la qualité des résultats.

### Modes Simples

Les modes simples sont conçus pour traiter des tâches basiques et bien définies :

- Utilisent des modèles moins coûteux (Claude 3.5 Sonnet)
- Se concentrent sur des tâches spécifiques et isolées
- Ont des instructions optimisées pour réduire la consommation de tokens
- Incluent un mécanisme d'escalade pour les tâches dépassant leurs capacités

### Modes Complexes

Les modes complexes sont conçus pour traiter des tâches avancées et complexes :

- Utilisent des modèles plus puissants (Claude 3.7 Sonnet)
- Peuvent gérer des tâches nécessitant une compréhension approfondie
- Ont accès à plus de contexte et de capacités
- Peuvent décomposer des tâches complexes en sous-tâches

### Mécanisme d'Escalade

Le mécanisme d'escalade permet aux modes simples de transférer une tâche à leur équivalent complexe lorsqu'ils détectent qu'elle dépasse leurs capacités :

1. L'agent simple analyse la demande selon des critères de complexité
2. S'il détecte que la tâche est trop complexe, il signale le besoin d'escalade
3. L'utilisateur peut alors basculer vers le mode complexe correspondant
4. L'agent complexe reprend la tâche avec le contexte déjà établi

Format de signalement d'escalade :
```
[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]
```

## Critères de Décision pour le Routage des Tâches

Le routage des tâches entre modes simples et complexes repose sur plusieurs facteurs :

1. **Complexité linguistique** : Structure et vocabulaire de la demande
2. **Complexité technique** : Difficulté technique de la tâche
3. **Besoin en contexte** : Quantité de contexte nécessaire
4. **Créativité requise** : Niveau d'innovation nécessaire
5. **Criticité** : Importance et impact des erreurs potentielles

### Exemples de Tâches par Niveau de Complexité

#### Agent Code
- **Simple** : Modifications < 50 lignes, bugs simples, formatage
- **Complexe** : Refactoring majeur, conception d'architecture, optimisation

#### Agent Debug
- **Simple** : Erreurs de syntaxe, bugs évidents, problèmes isolés
- **Complexe** : Bugs concurrents, problèmes de performance, bugs système

#### Agent Architect
- **Simple** : Documentation simple, diagrammes basiques, améliorations mineures
- **Complexe** : Conception système, migration complexe, optimisation d'architecture

#### Agent Ask
- **Simple** : Questions factuelles, explications basiques, résumés concis
- **Complexe** : Analyses approfondies, comparaisons détaillées, synthèses complexes

#### Agent Orchestrator
- **Simple** : Décomposition de tâches simples, délégation basique
- **Complexe** : Coordination de tâches interdépendantes, stratégies avancées

## Comment Ajouter ou Modifier des Modes

### Ajouter un Nouveau Mode

Pour ajouter un nouveau mode personnalisé :

1. Ouvrez le fichier `.roomodes` à la racine du projet
2. Ajoutez une nouvelle entrée dans le tableau `customModes` avec les propriétés requises
3. Assurez-vous que le `slug` est unique
4. Définissez le `model` approprié selon la complexité du mode
5. Rédigez une `roleDefinition` claire et concise
6. Attribuez les `groups` d'autorisations nécessaires
7. Rédigez des `customInstructions` détaillées pour guider le comportement

Exemple d'ajout d'un nouveau mode :
```json
{
  "slug": "data-analyst",
  "name": "📊 Data Analyst",
  "model": "anthropic/claude-3.7-sonnet",
  "roleDefinition": "You are Roo Data Analyst, specialized in data analysis, visualization, and insights extraction.",
  "groups": ["read", "edit", "browser", "command", "mcp"],
  "customInstructions": "FOCUS AREAS:\n- Data cleaning and preparation\n- Statistical analysis\n- Data visualization\n- Insights extraction\n- Reporting"
}
```

### Modifier un Mode Existant

Pour modifier un mode existant :

1. Ouvrez le fichier `.roomodes` à la racine du projet
2. Localisez l'entrée correspondant au mode à modifier
3. Mettez à jour les propriétés selon vos besoins
4. Sauvegardez le fichier
5. Redémarrez Roo pour appliquer les modifications

### Bonnes Pratiques

- **Testez vos modifications** : Après avoir modifié ou ajouté un mode, testez-le avec différentes tâches pour vous assurer qu'il fonctionne comme prévu
- **Optimisez les instructions** : Rédigez des instructions claires et concises pour réduire la consommation de tokens
- **Définissez clairement les limites** : Précisez quand un mode doit escalader une tâche vers un mode plus complexe
- **Maintenez la cohérence** : Assurez-vous que les modes simples et complexes d'un même type d'agent ont des instructions cohérentes
- **Documentez les changements** : Tenez à jour la documentation des modes personnalisés

## Dépannage

### Problèmes Courants

- **Mode non disponible** : Vérifiez que le fichier `.roomodes` est correctement formaté et placé au bon endroit
- **Comportement inattendu** : Vérifiez les instructions personnalisées et la définition du rôle
- **Erreurs d'autorisation** : Assurez-vous que les groupes d'autorisations appropriés sont attribués
- **Modèle non disponible** : Vérifiez que vous avez accès au modèle spécifié

### Support

Pour toute question ou problème concernant les modes personnalisés, veuillez consulter la documentation officielle de Roo ou contacter l'équipe de support.
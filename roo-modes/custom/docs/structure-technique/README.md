# Structure Technique des Modes Personnalisés Roo

Ce document explique la structure technique des modes personnalisés Roo, comment ils sont définis et comment ils fonctionnent.

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
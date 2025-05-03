# Scénarios de Test pour les Modes Simples/Complexes

Ce document contient des scénarios de test pour évaluer le comportement des modes Simples et Complexes de Roo.

## Tests pour Agent Code

### Tâches Simples (devrait être traitées par Code Simple)
1. **Correction de bug simple**: Corriger une erreur de syntaxe dans une fonction JavaScript
2. **Ajout de documentation**: Ajouter des commentaires JSDoc à une fonction existante
3. **Petite modification**: Ajouter une validation d'entrée à une fonction (< 10 lignes)
4. **Implémentation basique**: Créer une fonction simple selon une spécification (< 30 lignes)

### Tâches Complexes (devrait déclencher une escalade vers Code Complex)
1. **Refactoring majeur**: Restructurer un module entier pour améliorer la maintenabilité
2. **Optimisation de performance**: Améliorer les performances d'un algorithme critique
3. **Conception d'architecture**: Concevoir une nouvelle architecture pour une fonctionnalité
4. **Intégration système**: Intégrer plusieurs composants dans un système cohérent

## Tests pour Agent Debug

### Tâches Simples (devrait être traitées par Debug Simple)
1. **Erreur de syntaxe**: Identifier et corriger une erreur de syntaxe évidente
2. **Bug isolé**: Résoudre un bug dans une fonction spécifique
3. **Problème de configuration**: Corriger un problème de configuration simple
4. **Validation d'entrée**: Ajouter une validation pour éviter un bug évident

### Tâches Complexes (devrait déclencher une escalade vers Debug Complex)
1. **Bug concurrent**: Diagnostiquer un problème de concurrence dans une application
2. **Problème de performance**: Identifier les goulots d'étranglement dans une application
3. **Bug système**: Résoudre un problème impliquant plusieurs composants système
4. **Bug difficile à reproduire**: Diagnostiquer un bug intermittent

## Tests pour Agent Architect

### Tâches Simples (devrait être traitées par Architect Simple)
1. **Documentation technique**: Créer un README pour un composant spécifique
2. **Diagramme simple**: Créer un diagramme de flux pour un processus simple
3. **Plan d'implémentation**: Planifier l'implémentation d'une fonctionnalité isolée
4. **Amélioration mineure**: Proposer des améliorations pour un composant existant

### Tâches Complexes (devrait déclencher une escalade vers Architect Complex)
1. **Conception système**: Concevoir l'architecture d'un nouveau système
2. **Plan de migration**: Planifier la migration d'une architecture monolithique vers des microservices
3. **Optimisation d'architecture**: Optimiser une architecture distribuée
4. **Conception de sécurité**: Concevoir une architecture sécurisée pour une application critique

## Tests pour Agent Ask

### Tâches Simples (devrait être traitées par Ask Simple)
1. **Question factuelle**: "Qu'est-ce que React?"
2. **Explication basique**: "Expliquez le concept de programmation orientée objet"
3. **Recherche simple**: "Quelles sont les meilleures pratiques pour nommer les variables?"
4. **Résumé concis**: "Résumez les principes SOLID"

### Tâches Complexes (devrait déclencher une escalade vers Ask Complex)
1. **Analyse approfondie**: "Comparez en détail les architectures monolithiques et microservices"
2. **Comparaison détaillée**: "Analysez les avantages et inconvénients de React, Angular et Vue"
3. **Explication avancée**: "Expliquez en détail comment fonctionne le garbage collector en Java"
4. **Synthèse complexe**: "Synthétisez les tendances actuelles en matière de sécurité des applications web"

## Tests pour Agent Orchestrator

### Tâches Simples (devrait être traitées par Orchestrator Simple)
1. **Décomposition simple**: "Créez une page web statique avec un formulaire de contact"
2. **Délégation basique**: "Corrigez un bug dans une fonction et documentez la solution"
3. **Coordination simple**: "Implémentez une fonctionnalité simple et testez-la"
4. **Planification basique**: "Planifiez l'implémentation d'une petite fonctionnalité"

### Tâches Complexes (devrait déclencher une escalade vers Orchestrator Complex)
1. **Projet complet**: "Créez une application web complète avec authentification et base de données"
2. **Coordination complexe**: "Refactorisez une application monolithique en microservices"
3. **Intégration multiple**: "Intégrez plusieurs APIs externes dans une application existante"
4. **Stratégie avancée**: "Développez une stratégie de migration vers le cloud pour une application existante"

## Procédure de Test

Pour chaque scénario:

1. Démarrer avec le mode Simple approprié
2. Soumettre la tâche de test
3. Observer le comportement:
   - Pour les tâches simples: l'agent devrait compléter la tâche
   - Pour les tâches complexes: l'agent devrait signaler le besoin d'escalade
4. Si une escalade est signalée, passer au mode Complexe et continuer
5. Évaluer le résultat final

## Métriques d'Évaluation

Pour chaque test, évaluer:

1. **Précision de la classification**: L'agent a-t-il correctement identifié la complexité de la tâche?
2. **Qualité du résultat**: Le résultat final répond-il aux exigences?
3. **Efficacité**: Combien de temps/tokens ont été nécessaires pour compléter la tâche?
4. **Pertinence de l'escalade**: Si une escalade a eu lieu, était-elle justifiée?

## Tests de Comparaison

Pour comparer les performances entre différents modèles:

1. Exécuter les mêmes tâches simples sur:
   - Claude 3.5 Sonnet (configuration actuelle)
   - Qwen 3 235B-A22B (configuration à tester)
2. Comparer:
   - Qualité des résultats
   - Temps de réponse
   - Consommation de tokens
   - Coût total

## Tests Spécifiques pour les Mécanismes d'Escalade et de Rétrogradation

### Test d'Escalade pour Architect Simple

**Scénario de test** : Concevoir l'architecture complète d'un système de microservices pour une plateforme e-commerce à haute disponibilité

**Description détaillée** : Soumettre au mode Architect Simple la tâche suivante :
```
Concevoir l'architecture complète d'un système de microservices pour une plateforme e-commerce à haute disponibilité capable de gérer des millions d'utilisateurs simultanés. L'architecture doit inclure:
- Une stratégie de déploiement multi-région
- Un système de gestion des pannes et de résilience
- Une architecture de sécurité conforme aux normes PCI-DSS
- Une stratégie de mise à l'échelle automatique
- Un plan de migration depuis le système monolithique existant
```

**Comportement attendu** :
1. Le mode Architect Simple doit identifier que la tâche est trop complexe
2. Il doit signaler le besoin d'escalade avec le format exact : `[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]`
3. Il ne doit pas tenter de concevoir l'architecture lui-même
4. Il ne doit pas demander d'informations supplémentaires

**Critères de réussite** :
- Escalade immédiate sans tentative de résolution partielle
- Format d'escalade correct
- Raison d'escalade pertinente et spécifique

**Procédure de test** :
1. Démarrer avec le mode Architect Simple
2. Soumettre la tâche de test
3. Vérifier que la réponse correspond au comportement attendu
4. Documenter le résultat exact obtenu

### Test de Notification d'Escalade pour Architect Complex

**Scénario de test** : Vérifier la notification d'escalade par Architect Complex après une escalade depuis Architect Simple

**Description détaillée** : Après avoir obtenu une escalade du mode Architect Simple, soumettre la même tâche au mode Architect Complex :
```
Concevoir l'architecture complète d'un système de microservices pour une plateforme e-commerce à haute disponibilité capable de gérer des millions d'utilisateurs simultanés. L'architecture doit inclure:
- Une stratégie de déploiement multi-région
- Un système de gestion des pannes et de résilience
- Une architecture de sécurité conforme aux normes PCI-DSS
- Une stratégie de mise à l'échelle automatique
- Un plan de migration depuis le système monolithique existant
```

**Comportement attendu** :
1. Le mode Architect Complex doit traiter la tâche complètement
2. Il doit fournir une conception d'architecture détaillée
3. À la fin de sa réponse, il doit inclure la notification d'escalade avec le format exact : `[ISSU D'ESCALADE] Cette tâche a été traitée par la version complexe de l'agent suite à une escalade depuis la version simple.`

**Critères de réussite** :
- Traitement complet de la tâche
- Présence de la notification d'escalade à la fin de la réponse
- Format de notification correct

**Procédure de test** :
1. Démarrer avec le mode Architect Complex
2. Soumettre la tâche de test en précisant qu'elle provient d'une escalade
3. Vérifier que la réponse inclut la notification d'escalade à la fin
4. Documenter le résultat exact obtenu

### Test de Rétrogradation pour Code Complex

**Scénario de test** : Vérifier la suggestion de rétrogradation par Code Complex pour une tâche simple

**Description détaillée** : Soumettre au mode Code Complex une tâche simple qui pourrait être traitée par Code Simple :
```
Ajouter une validation d'entrée à la fonction suivante pour s'assurer que le paramètre 'name' n'est pas vide et contient uniquement des lettres et des espaces :

function greetUser(name) {
  return `Hello, ${name}!`;
}
```

**Comportement attendu** :
1. Le mode Code Complex doit identifier que la tâche est suffisamment simple
2. Il doit suggérer une rétrogradation vers Code Simple avec le format exact : `[RÉTROGRADATION SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : [RAISON]`
3. Malgré la suggestion, il doit traiter la tâche normalement

**Critères de réussite** :
- Présence de la suggestion de rétrogradation
- Format de suggestion correct
- Raison de rétrogradation pertinente et spécifique
- Traitement complet de la tâche malgré la suggestion

**Procédure de test** :
1. Démarrer avec le mode Code Complex
2. Soumettre la tâche de test
3. Vérifier que la réponse inclut la suggestion de rétrogradation
4. Vérifier que la tâche est traitée correctement malgré la suggestion
5. Documenter le résultat exact obtenu

### Test de Rétrogradation pour Debug Complex

**Scénario de test** : Vérifier la suggestion de rétrogradation par Debug Complex pour un bug simple

**Description détaillée** : Soumettre au mode Debug Complex un bug simple qui pourrait être traité par Debug Simple :
```
Le code suivant génère une erreur. Pouvez-vous identifier et corriger le problème ?

function calculateTotal(items) {
  let total = 0;
  for (let i = 0; i < items.lenght; i++) {
    total += items[i];
  }
  return total;
}
```

**Comportement attendu** :
1. Le mode Debug Complex doit identifier que le bug est suffisamment simple
2. Il doit suggérer une rétrogradation vers Debug Simple avec le format exact : `[RÉTROGRADATION SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : [RAISON]`
3. Malgré la suggestion, il doit traiter la tâche normalement

**Critères de réussite** :
- Présence de la suggestion de rétrogradation
- Format de suggestion correct
- Raison de rétrogradation pertinente et spécifique
- Traitement complet de la tâche malgré la suggestion

**Procédure de test** :
1. Démarrer avec le mode Debug Complex
2. Soumettre la tâche de test
3. Vérifier que la réponse inclut la suggestion de rétrogradation
4. Vérifier que la tâche est traitée correctement malgré la suggestion
5. Documenter le résultat exact obtenu

### Test de Rétrogradation pour Ask Complex

**Scénario de test** : Vérifier la suggestion de rétrogradation par Ask Complex pour une question simple

**Description détaillée** : Soumettre au mode Ask Complex une question simple qui pourrait être traitée par Ask Simple :
```
Qu'est-ce que le pattern MVC en développement web ?
```

**Comportement attendu** :
1. Le mode Ask Complex doit identifier que la question est suffisamment simple
2. Il doit suggérer une rétrogradation vers Ask Simple avec le format exact : `[RÉTROGRADATION SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : [RAISON]`
3. Malgré la suggestion, il doit traiter la tâche normalement

**Critères de réussite** :
- Présence de la suggestion de rétrogradation
- Format de suggestion correct
- Raison de rétrogradation pertinente et spécifique
- Traitement complet de la tâche malgré la suggestion

**Procédure de test** :
1. Démarrer avec le mode Ask Complex
2. Soumettre la tâche de test
3. Vérifier que la réponse inclut la suggestion de rétrogradation
4. Vérifier que la tâche est traitée correctement malgré la suggestion
5. Documenter le résultat exact obtenu

### Test de Notification d'Escalade pour Architect Complex (Mise à jour)

**Scénario de test** : Vérifier la notification d'escalade par Architect Complex après une escalade depuis Architect Simple avec des critères plus précis
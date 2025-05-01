# Mécanismes d'Escalade et de Rétrogradation pour les Modes Simples/Complexes

## Contexte

Suite aux tests d'escalade des modes simples vers les modes complexes, nous avons identifié une ambiguïté dans le comportement attendu lors de l'escalade et un besoin de clarification pour le mécanisme de rétrogradation. Ce document clarifie les mécanismes d'escalade et de rétrogradation, ainsi que les modifications apportées aux configurations des modes.

## Mécanismes d'Escalade

Lors des tests, nous avons constaté deux comportements possibles d'escalade :

1. **Escalade externe** : Terminer la tâche avec un message d'escalade recommandant un mode plus complexe
2. **Escalade interne** : Changer de mode au sein de la même tâche et continuer le traitement

Cette ambiguïté a conduit à des comportements incohérents, notamment avec le mode Architect Simple qui a tenté de résoudre partiellement une tâche complexe au lieu de l'escalader correctement.

### 1. Escalade Externe (pour les modes simples)

- Les modes simples (code-simple, debug-simple, architect-simple, ask-simple, orchestrator-simple) doivent effectuer une **escalade externe** lorsqu'ils détectent une tâche complexe.
- L'escalade externe signifie que le mode simple doit :
  - Terminer la tâche immédiatement
  - Ne pas tenter de résoudre partiellement la tâche
  - Utiliser le format exact : `[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]`

### 2. Escalade Interne (pour les modes complexes)

- Les modes complexes (notamment orchestrator-complex) peuvent effectuer une **escalade interne** en déléguant des sous-tâches à d'autres modes.
- L'escalade interne doit être documentée dans la réponse finale avec le format : `[DÉLÉGATION] Sous-tâche X déléguée au mode Y pour la raison Z`

### Critères d'Escalade

Les critères d'escalade sont clairement définis. Un mode simple doit escalader toute tâche qui correspond aux critères suivants :

- Tâches nécessitant des modifications de plus de 50 lignes de code
- Tâches impliquant des refactorisations majeures
- Tâches nécessitant une conception d'architecture (systèmes complets, architectures distribuées)
- Tâches impliquant des optimisations de performance
- Tâches nécessitant une analyse approfondie

### Notification d'Escalade par les Modes Complexes

Lorsqu'un mode complexe est utilisé suite à une escalade depuis un mode simple, il doit signaler cette origine à la fin de sa réponse avec le format exact :

```
[ISSU D'ESCALADE] Cette tâche a été traitée par la version complexe de l'agent suite à une escalade depuis la version simple.
```

Cette notification est obligatoire et doit apparaître à la fin de la réponse du mode complexe.

## Mécanisme de Rétrogradation

### 1. Définition de la Rétrogradation

La **rétrogradation** est le processus par lequel un mode complexe suggère l'utilisation d'un mode simple pour traiter une tâche qui ne nécessite pas les capacités avancées du mode complexe. Contrairement à l'escalade qui est obligatoire pour les modes simples, la rétrogradation est une suggestion facultative faite par les modes complexes.

### 2. Critères de Rétrogradation

Un mode complexe doit suggérer une rétrogradation lorsqu'il identifie qu'une tâche est suffisamment simple pour être traitée par la version simple de l'agent. Une tâche est considérée comme simple si :

- Elle nécessite des modifications de moins de 50 lignes de code
- Elle concerne des fonctionnalités isolées
- Elle suit des patterns standards
- Elle ne nécessite pas d'optimisations complexes

### 3. Format de Suggestion de Rétrogradation

Les modes complexes doivent utiliser le format exact suivant pour suggérer une rétrogradation :

```
[RÉTROGRADATION SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : [RAISON]
```

### 4. Moment de l'Évaluation

Les modes complexes doivent évaluer régulièrement la complexité de la tâche en cours. Cette évaluation peut avoir lieu :

- Au début de la tâche, après une analyse initiale
- Pendant le traitement de la tâche, si la complexité s'avère moins importante que prévu
- Lors de la décomposition d'une tâche en sous-tâches, certaines pouvant être simples

### 5. Comportement Après Suggestion

Après avoir suggéré une rétrogradation, le mode complexe doit :

- Continuer à traiter la tâche si l'utilisateur ne répond pas à la suggestion
- Terminer son traitement normalement
- Ne pas refuser de traiter la tâche (contrairement à l'escalade qui est obligatoire)

## Modifications Apportées aux Configurations

### Ajouts dans les Instructions des Modes Simples

1. Section "MÉCANISME D'ESCALADE" pour rendre les instructions plus visibles
2. Précision que l'escalade doit être EXTERNE (terminer la tâche)
3. Instruction explicite de ne pas tenter de résoudre partiellement la tâche
4. Exigence d'utiliser le format exact pour l'escalade

### Ajouts dans les Instructions des Modes Complexes

1. Section "MÉCANISME D'ESCALADE INTERNE" pour clarifier la délégation
2. Instructions pour documenter les délégations avec un format spécifique
3. Section sur le mécanisme de rétrogradation avec les critères et le format à utiliser
4. Instruction d'évaluer régulièrement la complexité de la tâche
5. Exigence de signaler l'origine d'une escalade à la fin de la réponse

## Exemples de Comportements Attendus

### Scénario 1 : Escalade d'une Tâche Complexe

**Comportement attendu du mode Architect Simple :**

```
[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : elle implique la conception d'une architecture complète de microservices avec des stratégies de déploiement multi-région, de gestion des pannes, de sécurité PCI-DSS, de mise à l'échelle et de migration.
```

**Comportement attendu du mode Architect Complex après escalade :**
- Traiter la tâche complètement
- Potentiellement déléguer des sous-tâches spécifiques à d'autres modes
- Documenter les délégations dans la réponse finale
- Terminer sa réponse par : `[ISSU D'ESCALADE] Cette tâche a été traitée par la version complexe de l'agent suite à une escalade depuis la version simple.`

### Scénario 2 : Rétrogradation d'une Tâche Simple

**Comportement attendu du mode Code Complex :**

```
[RÉTROGRADATION SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : elle ne nécessite que la modification d'une fonction isolée avec moins de 20 lignes de code et suit un pattern standard de validation d'entrée.
```

## Problème Identifié et Résolu (Mise à jour)

Suite aux tests d'escalade, nous avons identifié une incohérence majeure entre les fichiers de configuration:

1. Le fichier `.roomodes` contenait des instructions d'escalade détaillées et strictes
2. Le fichier `custom_modes.json` (celui effectivement utilisé par le système) contenait des instructions beaucoup moins précises

Cette incohérence explique pourquoi l'agent Architect Simple n'a pas escaladé correctement la tâche complexe d'architecture de microservices. Les instructions dans `custom_modes.json` étaient trop vagues et ne spécifiaient pas clairement:
- Les critères précis pour identifier une tâche complexe
- L'obligation d'évaluer la complexité au début de chaque tâche
- L'interdiction explicite de tenter une résolution partielle

## Corrections Appliquées

Nous avons synchronisé les deux fichiers en mettant à jour `custom_modes.json` avec les instructions complètes d'escalade pour tous les modes simples:

1. Ajout des critères spécifiques d'escalade pour chaque mode simple
2. Ajout de l'instruction d'évaluer la complexité "au début de chaque tâche"
3. Ajout de l'instruction d'escalader "immédiatement sans demander d'informations supplémentaires et sans tenter de résoudre partiellement la tâche"
4. Ajout des instructions de rétrogradation pour les modes complexes
5. Ajout de l'exigence de notification d'escalade pour les modes complexes

Un script de vérification (`test-escalade-verification.py`) a été créé pour tester rapidement l'efficacité des modifications apportées.

## Conclusion

Ces modifications assurent maintenant un comportement cohérent et prévisible des modes simples et complexes, optimisant ainsi l'utilisation des ressources tout en maintenant la qualité des résultats.

Les corrections apportées résolvent l'incohérence identifiée et établissent un cadre clair pour les mécanismes d'escalade et de rétrogradation, facilitant les tests futurs et l'évaluation des performances des différents modèles.

## Recommandations pour l'avenir

1. Maintenir une synchronisation stricte entre `.roomodes` et `custom_modes.json`
2. Utiliser un processus de validation automatisé pour vérifier la cohérence des instructions d'escalade et de rétrogradation
3. Exécuter régulièrement des tests d'escalade et de rétrogradation pour s'assurer que le comportement reste conforme aux attentes
4. Collecter des métriques sur la fréquence et la pertinence des escalades et rétrogradations pour optimiser les critères
5. Évaluer régulièrement l'efficacité des mécanismes d'escalade et de rétrogradation
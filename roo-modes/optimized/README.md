# Architecture Optimisée des Agents Roo

Ce projet vise à concevoir une nouvelle architecture pour les agents Roo qui optimise les coûts sans perdre en qualité.

## Contexte

Actuellement, tous les agents Roo (orchestrator, code, debug, architect, ask) utilisent Claude Sonnet, un modèle performant mais coûteux. L'objectif est d'utiliser des modèles locaux ou moins coûteux pour certaines tâches ou sous-tâches, tout en conservant Claude Sonnet pour les tâches complexes nécessitant ses capacités avancées.

## Objectifs

1. Concevoir une architecture qui dédouble chaque profil d'agent en versions "simple" et "complexe" :
   - Version "simple" : utilisant des modèles locaux ou moins coûteux pour les tâches basiques
   - Version "complexe" : utilisant Claude Sonnet pour les tâches nécessitant plus de capacités

2. Réviser la logique de création de sous-tâches pour que les agents choisissent intelligemment entre profils simples et complexes selon la nature de la tâche.

3. Optimiser l'arborescence des sous-tâches pour limiter l'usage des tokens dans une conversation donnée.

## Contraintes techniques

- L'outil new_task actuel ne permet pas de spécifier un modèle différent lors de la création d'une sous-tâche
- Le modèle est déterminé implicitement par le mode sélectionné
- Il faudra créer des modes distincts pour chaque niveau de complexité

## Prochaines étapes

1. **Analyse des besoins** : Déterminer les caractéristiques des tâches "simples" vs "complexes" pour chaque type d'agent
   - Quelles tâches peuvent être effectuées par des modèles moins coûteux ?
   - Quelles tâches nécessitent absolument Claude Sonnet ?

2. **Conception de l'architecture** :
   - Schéma conceptuel de la nouvelle architecture
   - Définition des critères de décision pour choisir entre versions simple et complexe
   - Conception du mécanisme de routage des tâches

3. **Révision des prompts** :
   - Adapter les prompts pour les versions "simple" des agents
   - Optimiser les prompts pour réduire la consommation de tokens

4. **Stratégie d'implémentation** :
   - Plan d'implémentation progressive
   - Tests et validation des performances

## Livrables attendus

1. Un schéma conceptuel de la nouvelle architecture
2. Les critères de décision pour choisir entre versions simple et complexe
3. Des recommandations pour la révision des prompts
4. Une stratégie d'implémentation progressive

## Notes pour la reprise de la tâche

Pour poursuivre ce travail, il sera nécessaire de :
1. Recueillir des informations précises sur les modèles disponibles (locaux et en ligne) et leurs performances relatives
2. Comprendre en détail le fonctionnement actuel de l'outil new_task et les interactions entre agents
3. Analyser les types de tâches typiquement effectuées par chaque agent pour déterminer lesquelles peuvent être confiées à des modèles moins coûteux
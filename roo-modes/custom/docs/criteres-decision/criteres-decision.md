# Critères de Décision pour le Routage des Tâches

Ce document détaille les critères permettant de déterminer si une tâche doit être traitée par un agent simple (modèle moins coûteux) ou un agent complexe (Claude Sonnet).

## Principes Généraux

Le routage des tâches repose sur plusieurs facteurs d'évaluation :

1. **Complexité linguistique** : Analyse de la structure et du vocabulaire de la demande
2. **Complexité technique** : Évaluation de la difficulté technique de la tâche
3. **Besoin en contexte** : Quantité de contexte nécessaire pour accomplir la tâche
4. **Créativité requise** : Niveau d'innovation ou de créativité nécessaire
5. **Criticité** : Importance de la tâche et impact des erreurs potentielles

## Métriques d'Évaluation

### 1. Complexité Linguistique

| Métrique | Seuil pour Agent Simple | Seuil pour Agent Complexe |
|----------|-------------------------|---------------------------|
| Longueur de la demande | < 100 mots | ≥ 100 mots |
| Nombre de questions/requêtes | 1-2 | ≥ 3 |
| Présence de termes techniques spécialisés | Faible | Élevée |
| Structure syntaxique | Simple | Complexe (conditions multiples, nuances) |

### 2. Complexité Technique

| Type d'Agent | Tâches pour Agent Simple | Tâches pour Agent Complexe |
|--------------|--------------------------|----------------------------|
| **Code** | Modifications < 50 lignes, Fonctions isolées, Bugs simples | Refactoring majeur, Conception d'architecture, Optimisation |
| **Debug** | Erreurs de syntaxe, Bugs évidents, Problèmes isolés | Bugs concurrents, Problèmes de performance, Bugs système |
| **Architect** | Documentation simple, Diagrammes basiques, Améliorations mineures | Conception système, Migration complexe, Optimisation d'architecture |
| **Ask** | Questions factuelles, Explications basiques | Analyses approfondies, Comparaisons détaillées, Synthèses |

### 3. Besoin en Contexte

| Métrique | Seuil pour Agent Simple | Seuil pour Agent Complexe |
|----------|-------------------------|---------------------------|
| Nombre de fichiers concernés | 1-3 fichiers | > 3 fichiers |
| Taille du contexte nécessaire | < 2000 tokens | ≥ 2000 tokens |
| Dépendances entre composants | Faibles | Élevées |
| Historique des interactions | Court terme | Long terme |

### 4. Créativité Requise

| Niveau | Description | Type d'Agent |
|--------|-------------|--------------|
| **Faible** | Solution directe, approche standard | Simple |
| **Moyen** | Quelques alternatives à considérer | Simple/Complexe (selon d'autres facteurs) |
| **Élevé** | Solutions innovantes, approches non conventionnelles | Complexe |

### 5. Criticité

| Niveau | Description | Type d'Agent |
|--------|-------------|--------------|
| **Faible** | Impact limité, facilement réversible | Simple |
| **Moyen** | Impact modéré, réversible avec effort | Simple/Complexe (selon d'autres facteurs) |
| **Élevé** | Impact majeur, difficile à inverser | Complexe |

## Mots-Clés et Indicateurs

### Indicateurs de Tâches Simples

- "expliquer brièvement"
- "corriger cette erreur"
- "formater ce code"
- "créer un exemple simple"
- "vérifier la syntaxe"
- "documenter cette fonction"
- "résumer ce concept"

### Indicateurs de Tâches Complexes

- "concevoir une architecture pour"
- "optimiser les performances de"
- "analyser en profondeur"
- "refactorer complètement"
- "comparer et contraster"
- "proposer une solution innovante"
- "résoudre ce problème complexe"

## Algorithme de Décision

1. **Évaluation initiale** : Analyser la demande selon les métriques ci-dessus
2. **Calcul du score de complexité** : Attribuer un score à chaque métrique et calculer un score global
3. **Seuil de décision** : Comparer le score global au seuil défini pour chaque type d'agent
4. **Facteurs de priorité** : Certains facteurs peuvent avoir plus de poids selon le contexte
5. **Décision finale** : Router vers l'agent approprié

## Mécanisme d'Escalade

Si un agent simple rencontre des difficultés ou détecte que la tâche est plus complexe que prévu, un mécanisme d'escalade permet de transférer la tâche à un agent complexe :

1. **Détection de complexité** : L'agent simple évalue sa capacité à accomplir la tâche
2. **Signaux d'escalade** : Incertitude élevée, besoin de contexte supplémentaire, solutions multiples
3. **Transfert de contexte** : L'agent simple transmet le contexte et son analyse préliminaire
4. **Reprise par agent complexe** : L'agent complexe continue avec le contexte enrichi

## Exemples Concrets

### Exemple 1 : Tâche Simple pour Code

**Demande** : "Ajoute une validation pour s'assurer que l'email est au bon format dans le formulaire d'inscription."

**Analyse** :
- Complexité linguistique : Faible (demande claire et concise)
- Complexité technique : Faible (modification isolée, pattern connu)
- Besoin en contexte : Faible (1-2 fichiers concernés)
- Créativité requise : Faible (solution standard)
- Criticité : Moyenne (importante mais facilement réversible)

**Décision** : Agent Code Simple

### Exemple 2 : Tâche Complexe pour Architect

**Demande** : "Conçois une nouvelle architecture pour notre système de paiement qui améliore la scalabilité, réduit la latence et s'intègre avec nos microservices existants tout en facilitant la migration progressive depuis notre système monolithique actuel."

**Analyse** :
- Complexité linguistique : Élevée (demande longue avec multiples contraintes)
- Complexité technique : Élevée (conception d'architecture, intégration, migration)
- Besoin en contexte : Élevé (compréhension du système existant et des contraintes)
- Créativité requise : Élevée (solution innovante nécessaire)
- Criticité : Élevée (impact majeur sur le système)

**Décision** : Agent Architect Complexe
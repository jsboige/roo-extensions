# Critères d'Escalade et de Désescalade pour les Modes Roo

Ce document définit les critères quantifiables pour déterminer quand un mode simple doit escalader vers un mode complexe, et quand un mode complexe doit suggérer une désescalade vers un mode simple.

## 1. Mode Code

### Critères d'Escalade (Code Simple → Code Complex)

Un mode Code Simple DOIT escalader vers Code Complex si AU MOINS UN des critères suivants est rempli:

#### 1.1 Taille du Code
- Tâches nécessitant des modifications de plus de 50 lignes de code
- Tâches impliquant plus de 3 fichiers interdépendants
- Fichiers de plus de 200 lignes à analyser en profondeur

#### 1.2 Complexité Structurelle
- Tâches impliquant des refactorisations majeures
- Structures de données complexes ou imbriquées (plus de 3 niveaux)
- Algorithmes avec complexité temporelle supérieure à O(n²)

#### 1.3 Architecture et Performance
- Tâches nécessitant une conception d'architecture
- Tâches impliquant des optimisations de performance
- Systèmes distribués ou asynchrones

#### 1.4 Analyse et Expertise
- Tâches nécessitant une analyse approfondie
- Problèmes impliquant des interactions entre plusieurs systèmes
- Débogages nécessitant une compréhension de systèmes interdépendants

### Critères de Désescalade (Code Complex → Code Simple)

Un mode Code Complex PEUT suggérer une désescalade vers Code Simple si TOUS les critères suivants sont remplis:

#### 1.5 Taille du Code
- Modifications de moins de 50 lignes de code
- Implique moins de 3 fichiers
- Fichiers de moins de 200 lignes à analyser

#### 1.6 Complexité Structurelle
- Fonctions simples et isolées
- Structures de données simples (moins de 3 niveaux d'imbrication)
- Algorithmes avec complexité temporelle O(n) ou O(log n)

#### 1.7 Architecture et Performance
- Ne nécessite pas de conception architecturale
- Ne nécessite pas d'optimisations de performance
- Systèmes séquentiels et synchrones

#### 1.8 Analyse et Expertise
- Ne nécessite pas d'analyse approfondie
- Problèmes isolés à un seul système
- Débogages simples (erreurs de syntaxe, problèmes évidents)

### Exemples de Tâches pour Escalade (Code Simple → Code Complex)

1. **Refactorisation majeure**:
   - "Refactorise cette classe de 300 lignes pour utiliser le pattern Observer"
   - "Convertis cette application monolithique en architecture microservices"

2. **Optimisation de performance**:
   - "Optimise cette fonction récursive qui a une complexité exponentielle"
   - "Améliore les performances de cette requête de base de données qui prend trop de temps"

3. **Conception d'architecture**:
   - "Conçois un système de cache distribué pour cette application"
   - "Implémente un système de messagerie asynchrone entre ces services"

### Exemples de Tâches pour Désescalade (Code Complex → Code Simple)

1. **Modifications mineures**:
   - "Ajoute une validation d'entrée à cette fonction de 20 lignes"
   - "Corrige cette erreur de syntaxe dans ce fichier de configuration"

2. **Fonctionnalités isolées**:
   - "Ajoute un bouton de déconnexion à cette page"
   - "Implémente une fonction simple pour formater des dates"

3. **Documentation et formatage**:
   - "Ajoute des commentaires JSDoc à ces fonctions"
   - "Reformate ce fichier selon les conventions de style du projet"

## 2. Mode Debug

### Critères d'Escalade (Debug Simple → Debug Complex)

Un mode Debug Simple DOIT escalader vers Debug Complex si AU MOINS UN des critères suivants est rempli:

#### 2.1 Taille du Code
- Tâches nécessitant des modifications de plus de 50 lignes de code
- Tâches impliquant plus de 3 fichiers interdépendants
- Fichiers de plus de 200 lignes à analyser en profondeur

#### 2.2 Complexité du Débogage
- Bugs impliquant des problèmes de concurrence
- Problèmes de performance nécessitant du profilage
- Erreurs intermittentes ou difficiles à reproduire

#### 2.3 Architecture et Performance
- Problèmes d'intégration entre plusieurs systèmes
- Problèmes de mémoire ou de fuites de ressources
- Bugs dans des systèmes distribués ou asynchrones

#### 2.4 Analyse et Expertise
- Tâches nécessitant une analyse approfondie
- Problèmes impliquant des interactions entre plusieurs systèmes
- Débogages nécessitant une compréhension de systèmes interdépendants

### Critères de Désescalade (Debug Complex → Debug Simple)

Un mode Debug Complex PEUT suggérer une désescalade vers Debug Simple si TOUS les critères suivants sont remplis:

#### 2.5 Taille du Code
- Modifications de moins de 50 lignes de code
- Implique moins de 3 fichiers
- Fichiers de moins de 200 lignes à analyser

#### 2.6 Complexité du Débogage
- Erreurs de syntaxe évidentes
- Bugs dans un flux d'exécution linéaire
- Problèmes reproductibles de manière constante

#### 2.7 Architecture et Performance
- Ne concerne pas des problèmes de performance
- Ne concerne pas des problèmes d'intégration
- Systèmes séquentiels et synchrones

#### 2.8 Analyse et Expertise
- Ne nécessite pas d'analyse approfondie
- Problèmes isolés à un seul système
- Débogages simples (erreurs de syntaxe, problèmes évidents)

### Exemples de Tâches pour Escalade (Debug Simple → Debug Complex)

1. **Problèmes de concurrence**:
   - "Débogue cette condition de course dans notre système multi-thread"
   - "Résous ce deadlock qui se produit occasionnellement dans notre application"

2. **Problèmes de performance**:
   - "Identifie pourquoi notre application ralentit après plusieurs heures d'exécution"
   - "Trouve la cause de cette fuite de mémoire dans notre service"

3. **Bugs complexes**:
   - "Débogue cette erreur qui se produit uniquement en production"
   - "Résous ce problème d'intégration entre notre API et ce service tiers"

### Exemples de Tâches pour Désescalade (Debug Complex → Debug Simple)

1. **Erreurs de syntaxe**:
   - "Corrige cette erreur de point-virgule manquant à la ligne 42"
   - "Résous cette erreur de parenthèse non fermée dans cette fonction"

2. **Bugs évidents**:
   - "Corrige cette variable non initialisée qui cause une erreur"
   - "Résous ce problème de comparaison (== au lieu de ===) dans cette condition"

3. **Problèmes isolés**:
   - "Débogue pourquoi cette fonction simple retourne toujours null"
   - "Corrige cette validation d'entrée qui accepte des valeurs invalides"

## 3. Mode Architect

### Critères d'Escalade (Architect Simple → Architect Complex)

Un mode Architect Simple DOIT escalader vers Architect Complex si AU MOINS UN des critères suivants est rempli:

#### 3.1 Taille et Portée
- Documentation pour des systèmes de plus de 5 composants interdépendants
- Planification de fonctionnalités impliquant plus de 3 sous-systèmes
- Diagrammes nécessitant plus de 20 éléments ou relations

#### 3.2 Complexité Architecturale
- Tâches impliquant des refactorisations majeures
- Conception de systèmes distribués
- Architecture de microservices avec plus de 3 services

#### 3.3 Architecture et Performance
- Tâches nécessitant une conception d'architecture complète
- Tâches impliquant des optimisations de performance système
- Planification de migrations complexes

#### 3.4 Analyse et Expertise
- Tâches nécessitant une analyse approfondie de systèmes existants
- Évaluations comparatives de multiples technologies
- Recommandations nécessitant une expertise pointue dans un domaine

### Critères de Désescalade (Architect Complex → Architect Simple)

Un mode Architect Complex PEUT suggérer une désescalade vers Architect Simple si TOUS les critères suivants sont remplis:

#### 3.5 Taille et Portée
- Documentation pour des systèmes de moins de 5 composants
- Planification de fonctionnalités isolées (moins de 3 sous-systèmes)
- Diagrammes simples (moins de 20 éléments)

#### 3.6 Complexité Architecturale
- Ne nécessite pas de refactorisations majeures
- Systèmes monolithiques ou simples
- Pas de microservices ou moins de 3 services

#### 3.7 Architecture et Performance
- Ne nécessite pas de conception d'architecture complète
- Ne concerne pas des optimisations de performance système
- Planification de migrations simples

#### 3.8 Analyse et Expertise
- Ne nécessite pas d'analyse approfondie
- Évaluations simples d'une seule technologie
- Recommandations basées sur des connaissances générales

### Exemples de Tâches pour Escalade (Architect Simple → Architect Complex)

1. **Conception de systèmes complexes**:
   - "Conçois une architecture de microservices pour notre application e-commerce"
   - "Élabore une stratégie de migration de notre monolithe vers une architecture distribuée"

2. **Optimisations système**:
   - "Propose une architecture pour améliorer la scalabilité de notre système"
   - "Conçois une solution pour réduire la latence de notre API globale"

3. **Analyses comparatives**:
   - "Compare ces 5 technologies de base de données pour notre cas d'utilisation spécifique"
   - "Évalue les avantages et inconvénients de ces frameworks pour notre projet"

### Exemples de Tâches pour Désescalade (Architect Complex → Architect Simple)

1. **Documentation simple**:
   - "Crée un README pour ce composant isolé"
   - "Documente l'API de cette fonction spécifique"

2. **Diagrammes basiques**:
   - "Crée un diagramme de flux pour ce processus d'authentification"
   - "Dessine un diagramme de composants pour cette fonctionnalité"

3. **Planification de fonctionnalités isolées**:
   - "Planifie l'implémentation de cette fonctionnalité spécifique"
   - "Propose une approche pour ajouter ce nouveau composant"

## 4. Mode Ask

### Critères d'Escalade (Ask Simple → Ask Complex)

Un mode Ask Simple DOIT escalader vers Ask Complex si AU MOINS UN des critères suivants est rempli:

#### 4.1 Complexité de la Question
- Questions nécessitant une analyse comparative de plus de 3 technologies/approches
- Questions impliquant des domaines techniques avancés (cryptographie, IA, etc.)
- Questions nécessitant une synthèse de multiples sources d'information

#### 4.2 Profondeur de l'Analyse
- Questions nécessitant une analyse approfondie
- Questions demandant des recommandations contextuelles
- Questions nécessitant une évaluation critique

#### 4.3 Portée et Interdisciplinarité
- Questions couvrant plusieurs domaines techniques
- Questions impliquant des compromis complexes
- Questions nécessitant une compréhension de systèmes interdépendants

#### 4.4 Spécificité et Expertise
- Questions nécessitant une expertise pointue dans un domaine
- Questions sur des technologies émergentes ou de niche
- Questions nécessitant une connaissance approfondie de bonnes pratiques spécifiques

### Critères de Désescalade (Ask Complex → Ask Simple)

Un mode Ask Complex PEUT suggérer une désescalade vers Ask Simple si TOUS les critères suivants sont remplis:

#### 4.5 Simplicité de la Question
- Questions factuelles simples
- Questions sur des concepts de base
- Questions ne nécessitant pas d'analyse comparative

#### 4.6 Superficialité de l'Analyse
- Questions ne nécessitant pas d'analyse approfondie
- Questions ne demandant pas de recommandations contextuelles
- Questions ne nécessitant pas d'évaluation critique

#### 4.7 Portée Limitée
- Questions portant sur un seul domaine technique
- Questions ne nécessitant pas de compromis complexes
- Questions sur des systèmes isolés

#### 4.8 Généralité
- Questions sur des connaissances générales
- Questions sur des technologies bien établies
- Questions sur des concepts fondamentaux

### Exemples de Tâches pour Escalade (Ask Simple → Ask Complex)

1. **Analyses comparatives**:
   - "Compare les avantages et inconvénients de React, Vue et Angular pour une application d'entreprise"
   - "Analyse les différentes approches de gestion d'état dans les applications front-end"

2. **Questions techniques avancées**:
   - "Explique les implications de sécurité des différentes méthodes d'authentification JWT"
   - "Décris les compromis entre différentes architectures de microservices"

3. **Recommandations contextuelles**:
   - "Quelle base de données serait la plus adaptée pour notre système de trading haute fréquence?"
   - "Comment devrions-nous structurer notre pipeline CI/CD pour un déploiement multi-cloud?"

### Exemples de Tâches pour Désescalade (Ask Complex → Ask Simple)

1. **Questions factuelles**:
   - "Quelle est la différence entre let et const en JavaScript?"
   - "Comment déclarer une variable en Python?"

2. **Concepts de base**:
   - "Qu'est-ce qu'une API REST?"
   - "Explique le concept de programmation orientée objet"

3. **Informations générales**:
   - "Quelles sont les étapes pour installer Node.js?"
   - "Comment créer un repository Git?"

## 5. Format Standardisé des Messages

### Format d'Escalade (Modes Simples)

```
[ESCALADE REQUISE]
Cette tâche nécessite la version complexe de l'agent car:
- [CRITÈRE SPÉCIFIQUE DÉCLENCHÉ]
- [MESURE QUANTITATIVE SI APPLICABLE]
- [IMPACT SUR LA QUALITÉ DU RÉSULTAT]
```

### Format de Désescalade (Modes Complexes)

```
[DÉSESCALADE RECOMMANDÉE]
Cette tâche pourrait être traitée par la version simple de l'agent car:
- [CRITÈRES SPÉCIFIQUES REMPLIS]
- [MESURES QUANTITATIVES SI APPLICABLES]
- [ÉCONOMIE DE RESSOURCES POTENTIELLE]
```

### Format d'Escalade Interne (Modes Simples)

```
[ESCALADE INTERNE]
Cette tâche a été traitée par la version complexe de l'agent car:
- [CRITÈRE SPÉCIFIQUE DÉCLENCHÉ]
- [MESURE QUANTITATIVE SI APPLICABLE]
```

### Format de Notification d'Escalade (Modes Complexes)

```
[ISSU D'ESCALADE]
Cette tâche a été traitée par la version complexe de l'agent suite à une escalade depuis la version simple pour la raison suivante:
- [RAISON DE L'ESCALADE]
```

### Format de Notification d'Escalade Interne (Modes Complexes)

```
[ISSU D'ESCALADE INTERNE]
Cette tâche a été traitée par la version complexe de l'agent suite à une escalade interne depuis la version simple pour la raison suivante:
- [RAISON PROBABLE DE L'ESCALADE]
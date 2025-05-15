# Tests de l'Architecture d'Orchestration à 5 Niveaux

Ce répertoire contient les scripts de test pour valider les mécanismes d'escalade et de désescalade de l'architecture d'orchestration à 5 niveaux (N5). Ces tests sont essentiels pour garantir que les transitions entre les différents niveaux de complexité fonctionnent correctement selon les critères définis.

## Objectif des Tests

L'objectif principal de ces tests est de vérifier que :

1. Les **mécanismes d'escalade** permettent de passer à un niveau de complexité supérieur lorsque certains seuils sont dépassés
2. Les **mécanismes de désescalade** permettent de revenir à un niveau de complexité inférieur lorsque la tâche devient plus simple
3. Les configurations de chaque niveau respectent les critères et formats définis

Ces tests assurent la robustesse et la fiabilité de l'architecture N5 en validant que les transitions entre niveaux se produisent de manière appropriée et cohérente.

## Structure et Fonctionnement

### Fichiers de Test

- **`test-escalade.js`** : Teste les mécanismes d'escalade entre les niveaux de complexité
- **`test-desescalade.js`** : Teste les mécanismes de désescalade entre les niveaux de complexité

### Niveaux Testés

Les tests couvrent les 5 niveaux de complexité de l'architecture :

1. **MICRO** : Niveau le plus bas pour les tâches très simples
2. **MINI** : Niveau pour les tâches simples
3. **MEDIUM** : Niveau intermédiaire pour les tâches de complexité moyenne
4. **LARGE** : Niveau pour les tâches complexes
5. **ORACLE** : Niveau le plus élevé pour les tâches très complexes

### Fonctionnalités Testées

#### Test d'Escalade (`test-escalade.js`)

1. **Validation des seuils d'escalade** :
   - Vérifie la présence et la cohérence des seuils d'escalade entre les niveaux
   - S'assure que les seuils sont progressifs (ex: le seuil du niveau MINI est inférieur à celui du niveau MEDIUM)

2. **Validation des mécanismes d'escalade** :
   - Vérifie la présence des mécanismes d'escalade dans les instructions personnalisées
   - Contrôle les formats d'escalade (`[ESCALADE PAR BRANCHEMENT]`, `[ESCALADE NIVEAU X]`, etc.)
   - Vérifie la présence des critères d'évaluation

3. **Simulation de scénarios d'escalade** :
   - Teste l'escalade basée sur la complexité du code
   - Teste l'escalade basée sur la taille de la conversation
   - Teste l'escalade basée sur le nombre de tokens
   - Vérifie les cas où l'escalade ne devrait pas se produire

#### Test de Désescalade (`test-desescalade.js`)

1. **Validation des mécanismes de désescalade** :
   - Vérifie la présence des mécanismes de désescalade dans les instructions personnalisées
   - Contrôle les formats de désescalade (`[DÉSESCALADE SUGGÉRÉE]`, etc.)
   - Vérifie la présence des critères d'évaluation

2. **Simulation de scénarios de désescalade** :
   - Teste la désescalade basée sur la complexité du code
   - Teste la désescalade basée sur la taille de la conversation
   - Teste la désescalade basée sur le nombre de tokens
   - Vérifie les cas où la désescalade ne devrait pas se produire

## Comment Exécuter les Tests

Pour exécuter les tests, suivez ces étapes :

1. Assurez-vous d'être dans le répertoire racine du projet `roo-modes/n5`

2. Exécutez les tests d'escalade :
   ```bash
   node tests/test-escalade.js
   ```

3. Exécutez les tests de désescalade :
   ```bash
   node tests/test-desescalade.js
   ```

4. Pour exécuter les deux tests à la suite :
   ```bash
   node tests/test-escalade.js && node tests/test-desescalade.js
   ```

## Interprétation des Résultats

Les tests génèrent des résultats détaillés qui sont affichés dans la console et sauvegardés dans des fichiers JSON dans le répertoire `roo-modes/n5/test-results/`.

### Format des Résultats

- **✅ Réussi** : Le test a passé avec succès
- **❌ Échec** : Le test a échoué, avec des détails sur la raison de l'échec
- **⚠️ Avertissement** : Le test a réussi mais avec des avertissements à prendre en compte

### Résumé des Tests

À la fin de l'exécution, un résumé est affiché avec :
- Le nombre total de tests exécutés
- Le nombre de tests réussis
- Le nombre de tests échoués
- Le nombre d'avertissements

### Fichiers de Résultats

Les résultats complets sont sauvegardés dans des fichiers JSON nommés selon le format :
- `escalation-test-results-[TIMESTAMP].json`
- `deescalation-test-results-[TIMESTAMP].json`

Ces fichiers contiennent des informations détaillées sur chaque test, y compris les entrées, les résultats attendus et les résultats réels.

## Dépendances

Les tests utilisent les modules Node.js standards suivants :

- **fs** : Pour les opérations de fichiers
- **path** : Pour la manipulation des chemins de fichiers
- **assert** : Pour les assertions de test

Aucune dépendance externe n'est requise pour exécuter ces tests.

## Structure des Configurations Testées

Les tests s'appuient sur les fichiers de configuration situés dans le répertoire `roo-modes/n5/configs/` :

- `micro-modes.json`
- `mini-modes.json`
- `medium-modes.json`
- `large-modes.json`
- `oracle-modes.json`

Chaque fichier de configuration doit contenir :

1. Des informations sur le niveau de complexité (`complexityLevel`)
2. Des seuils d'escalade (`escalationThresholds`)
3. Des modes personnalisés (`customModes`) avec leurs instructions

## Maintenance et Extension

Pour ajouter de nouveaux tests ou modifier les tests existants :

1. Respectez la structure et le format des tests existants
2. Assurez-vous que les nouveaux tests vérifient des aspects spécifiques des mécanismes d'escalade ou de désescalade
3. Mettez à jour ce README si nécessaire pour refléter les changements

---

Ces tests sont une partie essentielle du système d'assurance qualité pour l'architecture d'orchestration à 5 niveaux, garantissant que les transitions entre niveaux se produisent de manière appropriée et prévisible.
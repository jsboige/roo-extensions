# Campagne de Tests d'Escalade pour Roo

Ce document décrit la campagne de tests mise en place pour évaluer les possibilités d'orchestration avec escalade fonctionnelle entre les modes simples et complexes de Roo.

## Objectifs

1. Valider les procédures d'escalade entre les modes simples et complexes
2. Tester différentes configurations de modèles pour les modes simples
3. Évaluer les performances et la pertinence des escalades
4. Préparer le terrain pour l'architecture à 5 niveaux

## Types d'escalade à tester

1. **Escalade externe** : Passage d'un mode simple à un mode complexe correspondant
2. **Escalade interne** : Traitement d'une tâche complexe sans changer de mode
3. **Escalade par approfondissement** : Création de sous-tâches pour continuer le travail
4. **Escalade par terminaison** : Fin de la tâche avec recommandation de repartir avec un mode plus adapté

## Configurations de test

Trois configurations principales ont été créées pour les tests :

1. **Test Escalade Qwen** : Utilise des modèles Qwen plus légers pour les modes simples
   - code-simple: qwen/qwen3-14b
   - debug-simple: qwen/qwen3-8b
   - architect-simple: qwen/qwen3-14b
   - ask-simple: qwen/qwen3-8b
   - orchestrator-simple: qwen/qwen3-1.7b:free
   - Tous les modes complexes: anthropic/claude-3.7-sonnet

2. **Test Escalade Qwen Avancé** : Utilise des modèles Qwen plus puissants pour les modes simples
   - code-simple: qwen/qwen3-32b
   - debug-simple: qwen/qwen3-30b-a3b
   - architect-simple: qwen/qwen3-32b
   - ask-simple: qwen/qwen3-30b-a3b
   - orchestrator-simple: qwen/qwen3-14b
   - Tous les modes complexes: anthropic/claude-3.7-sonnet

3. **Test Escalade Mixte** : Utilise un mélange de modèles Qwen de différentes tailles selon les besoins spécifiques de chaque mode
   - code-simple: qwen/qwen3-14b
   - debug-simple: qwen/qwen3-1.7b:free
   - architect-simple: qwen/qwen3-32b
   - ask-simple: qwen/qwen3-8b
   - orchestrator-simple: qwen/qwen3-30b-a3b
   - Tous les modes complexes: anthropic/claude-3.7-sonnet

## Instructions d'exécution

### 1. Appliquer une configuration de test

Pour appliquer une configuration de test, exécutez le script PowerShell suivant :

```powershell
.\roo-config\apply-escalation-test-config.ps1 -ConfigName "Test Escalade Qwen"
```

ou

```powershell
.\roo-config\apply-escalation-test-config.ps1 -ConfigName "Test Escalade Qwen Avancé"
```

ou

```powershell
.\roo-config\apply-escalation-test-config.ps1 -ConfigName "Test Escalade Mixte"
```

**Note importante** : Après avoir appliqué une configuration, vous devez redémarrer VSCode pour que les changements prennent effet.

### 2. Générer les sous-tâches de test

Pour générer les sous-tâches de test d'escalade, utilisez le script suivant :

```powershell
.\roo-config\test-escalation-scenarios.ps1 -OutputDir "tests/results"
```

Ce script générera un ensemble de sous-tâches pour chaque scénario de test. Chaque sous-tâche sera sauvegardée dans un fichier Markdown distinct dans le répertoire spécifié.

### 3. Exécuter les sous-tâches de test

Pour chaque sous-tâche générée :

1. Créez une nouvelle tâche dans Roo avec le contenu du fichier de sous-tâche
2. Exécutez la tâche dans le mode spécifié (indiqué dans la sous-tâche)
3. Observez si une escalade se produit et documentez le comportement
4. **Important** : Mentionnez explicitement dans votre rapport de terminaison :
   - S'il y a eu une escalade (oui/non)
   - Le type d'escalade (Externe/Interne/Aucune)
   - Le temps approximatif avant l'escalade
   - Le message d'escalade exact (si applicable)

### 4. Analyser les résultats

Une fois toutes les sous-tâches exécutées, utilisez le script d'analyse pour comparer les résultats :

```powershell
.\roo-config\analyze-test-results.ps1
```

Ce script vous permettra de sélectionner les fichiers de résultats à analyser et générera un rapport comparatif.

## Scénarios de test

Les scénarios suivants sont inclus dans les tests :

1. **Escalade Code Simple vers Complex** : Implémentation d'un système de cache distribué
2. **Escalade Debug Simple vers Complex** : Diagnostic d'un problème de performance complexe
3. **Escalade Architect Simple vers Complex** : Conception d'une architecture microservices
4. **Escalade Ask Simple vers Complex** : Analyse comparative d'architectures
5. **Escalade Orchestrator Simple vers Complex** : Orchestration d'un projet complexe
6. **Escalade Interne Code Simple** : Validation de formulaire avec formats internationaux
7. **Pas d'Escalade Code Simple** : Validation d'email simple

## Analyse des résultats

Après avoir exécuté les tests et généré le rapport comparatif, analysez les résultats pour évaluer :

1. La précision des escalades (les escalades se produisent-elles quand elles devraient ?)
2. La pertinence des escalades (les raisons d'escalade sont-elles appropriées ?)
3. La fluidité des transitions entre modes
4. Les différences de performance entre les configurations de modèles
5. L'impact de l'utilisation d'un mélange de modèles sur les décisions d'escalade
6. Les avantages et inconvénients de chaque configuration

Le rapport comparatif généré par le script d'analyse vous aidera à identifier :

- Les différences de comportement entre les trois configurations
- L'impact de l'utilisation de modèles de différentes tailles sur les décisions d'escalade
- La configuration optimale basée sur les résultats des tests

## Prochaines étapes

1. **Finalisation de l'analyse comparative** : Compléter l'analyse des trois configurations et déterminer la plus efficace

2. **Optimisation des critères d'escalade** : Ajuster les critères d'escalade en fonction des résultats des tests

3. **Implémentation de l'architecture à 5 niveaux** : Une fois l'orchestration à 2 niveaux validée, procéder à l'implémentation de l'architecture complète à 5 niveaux

4. **Tests de désescalade** : Concevoir et exécuter des tests pour valider les mécanismes de désescalade entre les différents niveaux

## Résolution des problèmes courants

### Problème : Les modes ne sont pas mis à jour après l'application d'une configuration

**Solution** : Assurez-vous d'avoir redémarré VSCode après avoir appliqué une configuration.

### Problème : Les escalades ne se produisent pas comme prévu

**Solution** : Vérifiez que les instructions personnalisées des modes contiennent les mécanismes d'escalade appropriés. Vous pouvez consulter le fichier `roo-modes/configs/standard-modes.json` pour voir les instructions actuelles. Assurez-vous également que la configuration a été correctement appliquée et que VSCode a été redémarré.

### Problème : Les sous-tâches ne sont pas générées correctement

**Solution** : Vérifiez que vous avez bien spécifié le nom de la configuration lors de l'exécution du script de génération de sous-tâches. Assurez-vous également que le répertoire de sortie existe et est accessible en écriture.

### Problème : Le rapport comparatif ne reflète pas correctement les résultats

**Solution** : Vérifiez que les rapports de test contiennent bien les informations d'escalade explicites comme demandé. Le script d'analyse extrait ces informations pour générer le rapport comparatif.

### Problème : Erreurs lors de l'exécution des scripts PowerShell

**Solution** : Assurez-vous d'exécuter les scripts depuis la racine du projet (`d:\Dev\roo-extensions`) et que vous avez les permissions nécessaires pour exécuter des scripts PowerShell.
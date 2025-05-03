# Procédure de Test des Modes Simples/Complexes

Ce document explique comment utiliser les outils fournis pour tester les modes Simples/Complexes de Roo et comparer les résultats entre différentes configurations de modèles.

## Préparation

1. Assurez-vous que tous les fichiers suivants sont présents dans votre répertoire de travail:
   - `test-scenarios.md` - Scénarios de test pour chaque type d'agent
   - `test-runner.py` - Script pour exécuter les tests et collecter les résultats
   - `model-configs.json` - Configurations de modèles à tester
   - `apply-config.py` - Script pour appliquer une configuration de modèles

2. Rendez les scripts exécutables (sous Linux/macOS):
   ```bash
   chmod +x test-runner.py apply-config.py
   ```

## Étape 1: Tester la Configuration Actuelle

1. Exécutez les tests avec la configuration actuelle (Claude 3.5 Sonnet pour les modes simples, Claude 3.7 Sonnet pour les modes complexes):

   ```bash
   python test-runner.py --output test-results-current
   ```

2. Pour chaque scénario de test, le script vous demandera d'entrer manuellement les résultats:
   - Tokens utilisés
   - Coût ($)
   - Si une escalade vers le mode complexe a été nécessaire
   - Score de qualité (1-10)
   - Notes éventuelles

3. Les résultats seront sauvegardés dans le répertoire `test-results-current`.

## Étape 2: Tester avec local/qwq32b (Qwen 2 32B)

1. Appliquez la configuration "Test Qwen" pour utiliser local/qwq32b (Qwen 2 32B) hébergé localement via Ollama avec un contexte de 70k tokens pour les modes simples:

   ```bash
   python apply-config.py --list  # Pour voir les configurations disponibles
   python apply-config.py --apply "Test Qwen"
   ```

2. Redémarrez Roo pour appliquer les changements.

3. Exécutez les mêmes tests avec cette nouvelle configuration:

   ```bash
   python test-runner.py --output test-results-qwen
   ```

4. Les résultats seront sauvegardés dans le répertoire `test-results-qwen`.

## Étape 3: Comparer les Résultats

1. Utilisez un outil comme Excel, Google Sheets ou un script Python personnalisé pour comparer les résultats entre les deux configurations:

   - Comparez les taux d'escalade pour chaque type de tâche
   - Comparez la qualité des résultats
   - Comparez le coût et la consommation de tokens
   - Identifiez les scénarios où local/qwq32b (Qwen 2 32B) performe aussi bien que Claude 3.5 Sonnet
   - Identifiez les scénarios où local/qwq32b (Qwen 2 32B) ne performe pas suffisamment bien

2. Créez un rapport de comparaison avec vos conclusions.

## Étape 4: Ajuster les Prompts Système

Si nécessaire, ajustez les prompts système dans le fichier `.roomodes` pour améliorer le comportement des agents:

1. Pour les modes simples, vous pourriez avoir besoin d'ajuster:
   - Les critères d'escalade
   - Les instructions sur les types de tâches à traiter
   - Les limites de complexité

2. Pour les modes complexes, vous pourriez avoir besoin d'ajuster:
   - Les instructions sur la délégation aux modes simples
   - Les critères pour déterminer quand une tâche peut être traitée par un mode simple

3. Pour l'orchestrateur, vous pourriez avoir besoin d'ajuster:
   - Les critères de routage entre modes simples et complexes
   - Les instructions sur la décomposition des tâches

## Étape 5: Tester avec d'Autres Modèles

Pour tester avec d'autres modèles:

1. Modifiez le fichier `model-configs.json` pour ajouter de nouvelles configurations avec d'autres modèles.

2. Appliquez la nouvelle configuration:

   ```bash
   python apply-config.py --apply "Nom de votre nouvelle configuration"
   ```

3. Redémarrez Roo et exécutez les tests:

   ```bash
   python test-runner.py --output test-results-nouveau-modele
   ```

4. Comparez les résultats avec les configurations précédentes.

## Conseils pour l'Évaluation

Lors de l'évaluation des résultats, tenez compte des facteurs suivants:

1. **Précision de la classification**: Les agents identifient-ils correctement la complexité des tâches?
   - Un taux d'escalade trop élevé pour les tâches simples indique que le mode simple est trop conservateur
   - Un taux d'escalade trop faible pour les tâches complexes indique que le mode simple est trop confiant

2. **Qualité des résultats**: Les résultats sont-ils satisfaisants?
   - Pour les tâches simples, les modes simples devraient produire des résultats de qualité comparable aux modes complexes
   - Pour les tâches complexes, les modes complexes devraient produire des résultats significativement meilleurs

3. **Efficacité**: Les modes simples sont-ils plus efficaces?
   - Les modes simples devraient utiliser moins de tokens et coûter moins cher
   - Le temps de réponse des modes simples devrait être plus rapide

4. **Équilibre coût/qualité**: Le compromis entre coût et qualité est-il acceptable?
   - Pour les tâches simples, un modèle moins cher devrait offrir un bon rapport qualité/prix
   - Pour les tâches complexes, le coût supplémentaire d'un modèle plus puissant devrait être justifié par une qualité significativement meilleure

## Exemple de Rapport de Comparaison

Voici un exemple de structure pour votre rapport de comparaison:

```markdown
# Rapport de Comparaison des Modes Simples/Complexes

## Résumé
- Configuration 1: Claude 3.5 Sonnet (simple) / Claude 3.7 Sonnet (complexe)
- Configuration 2: local/qwq32b (Qwen 2 32B) (simple) / Claude 3.7 Sonnet (complexe)
- Nombre de tests: X

## Résultats Globaux
- Taux d'escalade moyen: X% (Config 1) vs Y% (Config 2)
- Score de qualité moyen: X/10 (Config 1) vs Y/10 (Config 2)
- Coût moyen par tâche: $X (Config 1) vs $Y (Config 2)
- Économie potentielle: X%

## Résultats par Type d'Agent
[Tableaux comparatifs pour chaque type d'agent]

## Analyse
[Analyse des résultats et observations]

## Recommandations
[Recommandations pour l'optimisation des modes]
```

## Conclusion

Cette procédure vous permettra de tester systématiquement les modes Simples/Complexes de Roo et de comparer les résultats entre différentes configurations de modèles. En suivant ces étapes, vous pourrez déterminer si local/qwq32b (Qwen 2 32B) est une alternative viable à Claude 3.5 Sonnet pour les modes simples, et identifier les ajustements nécessaires pour optimiser le comportement des agents.
# Guide d'Utilisation pour les Tests d'Escalade et de Rétrogradation

Ce document explique comment utiliser le script `test-escalade-complet.py` pour effectuer un test complet des mécanismes d'escalade et de rétrogradation pour tous les modes (Code, Debug, Architect, Ask, Orchestrator).

## Prérequis

- Python 3.6 ou supérieur
- Accès à l'interface Roo pour soumettre des tâches aux différents modes

## Types de Tests

Le script permet de tester quatre mécanismes différents:

1. **Escalade externe** (modes simples): Vérifier que les modes simples identifient correctement les tâches complexes et recommandent une escalade vers le mode complexe correspondant.
2. **Escalade interne** (modes simples): Vérifier que les modes simples traitent les tâches modérément complexes mais signalent une escalade interne.
3. **Notification d'escalade** (modes complexes): Vérifier que les modes complexes, lorsqu'ils sont utilisés suite à une escalade, incluent la notification d'escalade à la fin de leur réponse.
4. **Rétrogradation** (modes complexes): Vérifier que les modes complexes suggèrent une rétrogradation vers le mode simple correspondant pour les tâches simples.

## Procédure d'Utilisation

1. Exécutez le script avec la commande Python appropriée pour votre système:
   ```
   python test-escalade-complet.py
   ```
   
   Si Python n'est pas dans votre PATH, utilisez le chemin complet vers l'exécutable Python:
   ```
   C:\chemin\vers\python.exe test-escalade-complet.py
   ```
   
   Ou si vous utilisez VS Code, vous pouvez ouvrir le fichier et utiliser le bouton "Run" (▶️) en haut à droite de l'éditeur.

2. Le script vous guidera à travers chaque test:
   - Il affichera la tâche à soumettre au mode correspondant
   - Il vous donnera des instructions sur ce qu'il faut observer
   - Il vous demandera d'entrer les résultats du test

3. Pour chaque test:
   - Copiez la tâche affichée
   - Ouvrez un nouvel agent Roo dans le mode spécifié
   - Soumettez la tâche
   - Observez le comportement de l'agent
   - Revenez au script et répondez aux questions pour évaluer le test

4. Une fois tous les tests terminés, le script générera un rapport détaillé dans le fichier `resultats-tests-escalade.md`.

## Options du Script

- `--output`: Spécifier un nom de fichier différent pour le rapport (par défaut: `resultats-tests-escalade.md`)

Exemple:
```
python test-escalade-complet.py --output mon-rapport.md
```

## Structure du Rapport

Le rapport généré contient:

1. **Tableau récapitulatif**: Un aperçu rapide des résultats de tous les tests
2. **Détails des tests**: Pour chaque test:
   - La tâche soumise
   - Les critères évalués
   - La réponse de l'agent
   - Des notes supplémentaires
3. **Conclusion**: Une analyse globale des résultats avec des recommandations si certains tests ont échoué

## Conseils pour des Tests Efficaces

- Effectuez les tests dans un environnement calme pour pouvoir observer attentivement le comportement des agents
- Prenez des notes détaillées pendant les tests, en particulier si vous observez des comportements inattendus
- Si possible, faites des captures d'écran des réponses des agents pour référence future
- Testez un mode à la fois pour éviter toute confusion
- Assurez-vous que les agents utilisent les versions les plus récentes des configurations

## Après les Tests

Une fois les tests terminés et le rapport généré:

1. Analysez les résultats pour identifier les problèmes éventuels
2. Si nécessaire, mettez à jour les fichiers de configuration (`.roomodes` et `custom_modes.json`)
3. Effectuez les commits comme indiqué dans le fichier `commits-a-effectuer.md`
4. Si des problèmes persistent, envisagez de modifier les instructions des modes ou d'ajuster les critères d'escalade/rétrogradation

## Dépannage

- **Problème**: Le script se bloque pendant l'exécution
  **Solution**: Appuyez sur Ctrl+C pour interrompre le script, puis redémarrez-le. Les tests déjà effectués ne seront pas sauvegardés.

- **Problème**: Les agents ne répondent pas comme prévu
  **Solution**: Vérifiez que vous utilisez la dernière version des configurations et que vous avez correctement soumis la tâche.

- **Problème**: Le rapport n'est pas généré
  **Solution**: Assurez-vous que vous avez les permissions d'écriture dans le répertoire courant.
# Liste des Commits à Effectuer

Voici la liste des commits à effectuer pour mettre à jour le dépôt source avec les modifications apportées aux mécanismes d'escalade et de rétrogradation.

## Commit 1: Documentation complète des mécanismes d'escalade et de rétrogradation

```
docs: documentation complète des mécanismes d'escalade et de rétrogradation

- Mise à jour du fichier mecanismes-escalade.md avec:
  - Explication détaillée des mécanismes d'escalade (externe et interne)
  - Ajout d'une section complète sur le mécanisme de rétrogradation
  - Exemples de formats de messages pour chaque type d'escalade/rétrogradation
  - Critères clairs pour déterminer quand escalader/rétrograder
  - Recommandations pour l'avenir incluant la collecte de métriques

Cette documentation clarifie les comportements attendus des modes simples et complexes
concernant l'escalade et la rétrogradation, assurant une utilisation optimale des ressources.
```

## Commit 2: Ajout de scénarios de test pour l'escalade et la rétrogradation

```
test: ajout de scénarios de test pour l'escalade et la rétrogradation

- Mise à jour du fichier test-scenarios.md avec:
  - Test de notification d'escalade pour Architect Complex
  - Test de rétrogradation pour Code Complex
  - Test de rétrogradation pour Debug Complex
  - Test de rétrogradation pour Ask Complex
  
Ces scénarios de test permettent de vérifier que les mécanismes d'escalade et de rétrogradation
fonctionnent correctement et conformément à la documentation.
```

## Commit 3: Synchronisation des fichiers de configuration (si nécessaire)

```
fix: synchronisation des fichiers de configuration pour l'escalade et la rétrogradation

- Vérification et mise à jour des fichiers .roomodes et custom_modes.json pour assurer:
  - Cohérence des instructions d'escalade pour les modes simples
  - Cohérence des instructions de rétrogradation pour les modes complexes
  - Formats de messages standardisés pour l'escalade et la rétrogradation
  - Critères uniformes pour déterminer quand escalader/rétrograder

Cette synchronisation résout les incohérences précédemment identifiées et assure
un comportement prévisible des modes simples et complexes.
```

## Instructions pour l'exécution des commits

1. Vérifier les modifications apportées aux fichiers:
   ```
   git diff mecanismes-escalade.md
   git diff test-scenarios.md
   ```

2. Ajouter les fichiers modifiés:
   ```
   git add mecanismes-escalade.md test-scenarios.md
   ```

3. Effectuer le premier commit:
   ```
   git commit -m "docs: documentation complète des mécanismes d'escalade et de rétrogradation"
   ```

4. Effectuer le deuxième commit:
   ```
   git add test-scenarios.md
   git commit -m "test: ajout de scénarios de test pour l'escalade et la rétrogradation"
   ```

5. Si des modifications ont été apportées aux fichiers de configuration, effectuer le troisième commit:
   ```
   git add .roomodes custom_modes.json
   git commit -m "fix: synchronisation des fichiers de configuration pour l'escalade et la rétrogradation"
   ```

6. Pousser les modifications vers le dépôt distant:
   ```
   git push origin main
   ```

Note: Assurez-vous d'être sur la branche appropriée avant d'effectuer les commits. Si vous travaillez sur une branche de fonctionnalité, vous devrez peut-être créer une pull request pour fusionner vos modifications dans la branche principale.
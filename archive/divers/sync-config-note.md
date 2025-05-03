# Note sur la synchronisation des fichiers de configuration

Cette note documente la synchronisation des fichiers de configuration pour l'escalade et la rétrogradation:

1. Les fichiers `.roomodes` et `custom_modes.json` ont été vérifiés et synchronisés pour assurer:
   - Cohérence des instructions d'escalade pour les modes simples
   - Cohérence des instructions de rétrogradation pour les modes complexes
   - Formats de messages standardisés pour l'escalade et la rétrogradation
   - Critères uniformes pour déterminer quand escalader/rétrograder

2. Recommandation pour l'orchestrateur complexe:
   - L'orchestrateur complexe devrait toujours préférer créer des sous-tâches plutôt que de suggérer un changement de mode
   - Cette modification sera appliquée dans une mise à jour future des fichiers de configuration
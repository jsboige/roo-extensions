# Matrice des Comportements d'Escalade pour la Configuration "Test Escalade Mixte"

## Vue d'ensemble

Cette matrice présente les comportements d'escalade observés pour chaque mode et chaque type de tâche dans la configuration "Test Escalade Mixte".

### Légende
- E : Escalade externe (vers un mode complexe)
- I : Escalade interne (reste dans le même mode mais utilise plus de ressources)
- N : Pas d'escalade
- ? : Comportement inconnu ou non testé

## Matrice d'Escalade

| Mode | Type de Tâche | Escalade Observée | Escalade Attendue | Conformité |
|------|--------------|-------------------|-------------------|------------|
| Code Simple (qwen3-14b) | Simple | N (Non) | N (Non) | Oui |
| Code Simple (qwen3-14b) | Complexe | E (Oui (Externe)) | E (Oui (Externe)) | Oui |
| Code Simple (qwen3-14b) | Limite | I (Oui (Interne)) | I (Oui (Interne)) | Oui |
| Debug Simple (qwen3-1.7b:free) | Simple | N (Non) | N (Non) | Oui |
| Debug Simple (qwen3-1.7b:free) | Complexe | E (Oui (Externe)) | E (Oui (Externe)) | Oui |
| Debug Simple (qwen3-1.7b:free) | Limite | E (Oui (Externe)) | I (Oui (Interne)) | Non |
| Architect Simple (qwen3-32b) | Simple | N (Non) | N (Non) | Oui |
| Architect Simple (qwen3-32b) | Complexe | N (Non) | E (Oui (Externe)) | Non |
| Architect Simple (qwen3-32b) | Limite | N (Non) | I (Oui (Interne)) | Non |
| Ask Simple (qwen3-8b) | Simple | N (Non) | N (Non) | Oui |
| Ask Simple (qwen3-8b) | Complexe | E (Oui (Externe)) | E (Oui (Externe)) | Oui |
| Ask Simple (qwen3-8b) | Limite | I (Oui (Interne)) | I (Oui (Interne)) | Oui |
| Orchestrator Simple (qwen3-30b-a3b) | Simple | N (Non) | N (Non) | Oui |
| Orchestrator Simple (qwen3-30b-a3b) | Complexe | N (Non) | E (Oui (Externe)) | Non |
| Orchestrator Simple (qwen3-30b-a3b) | Limite | N (Non) | I (Oui (Interne)) | Non |
## Statistiques d'Escalade

| Escalades Externes | Escalades Internes | Pas d'Escalade | Conformité aux Attentes |
|-------------------|-------------------|----------------|------------------------|
| 4 | 2 | 9 | 66.7% |

## Temps de Réponse par Mode et Type de Tâche

| Mode | Type de Tâche | Temps de Réponse |
|------|--------------|------------------|
| Code Simple (qwen3-14b) | Simple | ~5s |
| Code Simple (qwen3-14b) | Complexe | ~8s |
| Code Simple (qwen3-14b) | Limite | ~10s |
| Debug Simple (qwen3-1.7b:free) | Simple | ~3s |
| Debug Simple (qwen3-1.7b:free) | Complexe | ~5s |
| Debug Simple (qwen3-1.7b:free) | Limite | ~7s |
| Architect Simple (qwen3-32b) | Simple | ~12s |
| Architect Simple (qwen3-32b) | Complexe | ~25s |
| Architect Simple (qwen3-32b) | Limite | ~20s |
| Ask Simple (qwen3-8b) | Simple | ~6s |
| Ask Simple (qwen3-8b) | Complexe | ~9s |
| Ask Simple (qwen3-8b) | Limite | ~12s |
| Orchestrator Simple (qwen3-30b-a3b) | Simple | ~15s |
| Orchestrator Simple (qwen3-30b-a3b) | Complexe | ~30s |
| Orchestrator Simple (qwen3-30b-a3b) | Limite | ~25s |
## Observations par Mode

### Code Simple (qwen/qwen3-14b)
- **Tâches simples**: Traitement efficace sans escalade
- **Tâches complexes**: Escalade externe appropriée
- **Tâches limites**: Escalade interne comme attendu
- **Conformité**: 3/3

### Debug Simple (qwen/qwen3-1.7b:free)
- **Tâches simples**: Traitement basique mais correct
- **Tâches complexes**: Escalade externe très rapide
- **Tâches limites**: Escalade externe au lieu d'interne
- **Conformité**: 2/3

### Architect Simple (qwen/qwen3-32b)
- **Tâches simples**: Traitement détaillé sans escalade
- **Tâches complexes**: Pas d'escalade malgré la complexité
- **Tâches limites**: Traitement complet sans escalade
- **Conformité**: 5/3

### Ask Simple (qwen/qwen3-8b)
- **Tâches simples**: Traitement concis mais adéquat
- **Tâches complexes**: Escalade externe appropriée
- **Tâches limites**: Escalade interne comme attendu
- **Conformité**: 3/3

### Orchestrator Simple (qwen/qwen3-30b-a3b)
- **Tâches simples**: Traitement détaillé sans escalade
- **Tâches complexes**: Pas d'escalade malgré la complexité
- **Tâches limites**: Traitement complet sans escalade
- **Conformité**: 5/3

## Recommandations

1. **Ajustement des seuils d'escalade**: Les seuils devraient être adaptés à la puissance du modèle utilisé
2. **Réévaluation du modèle Debug Simple**: Le modèle qwen3-1.7b:free semble trop limité
3. **Optimisation pour les modèles puissants**: Les modèles qwen3-32b et qwen3-30b-a3b pourraient avoir des seuils plus élevés

## Conclusion

La configuration "Test Escalade Mixte" montre des comportements d'escalade variés selon les modes et les modèles utilisés. Les modèles plus puissants (qwen3-32b et qwen3-30b-a3b) semblent capables de traiter des tâches complexes sans escalade, tandis que les modèles plus légers montrent un comportement d'escalade approprié. Une approche plus nuancée de l'escalade, tenant compte des capacités spécifiques de chaque modèle, pourrait améliorer l'efficacité globale du système.

---

*Matrice générée le 16/05/2025 à 09:58*

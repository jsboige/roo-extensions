# Profils de configuration pour les modèles Qwen 3

Ce dossier contient les profils de configuration optimisés pour les modèles Qwen 3, basés sur les recommandations officielles et les meilleures pratiques de la communauté.

## Modèles disponibles

Qwen 3 propose deux types de modèles :

### Modèles denses
- **Qwen3-0.6B** : Modèle léger de 0.6 milliards de paramètres
- **Qwen3-4B** : Modèle de 4 milliards de paramètres
- **Qwen3-14B** : Modèle de 14 milliards de paramètres
- **Qwen3-32B** : Modèle de 32 milliards de paramètres

### Modèles MoE (Mixture-of-Experts)
- **Qwen3-30B-A3B** : Modèle de 30 milliards de paramètres avec 3 milliards de paramètres actifs
- **Qwen3-235B-A22B** : Modèle phare de 235 milliards de paramètres avec 22 milliards de paramètres actifs

## Paramètres optimaux

Le fichier `qwen3-parameters.json` contient les paramètres optimaux pour chaque modèle Qwen 3, notamment :

- **temperature** : Contrôle la créativité/randomisation des réponses
- **top_p** : Filtre les tokens de faible probabilité
- **top_k** : Limite le nombre de tokens considérés
- **min_p** : Seuil minimum de probabilité pour les tokens
- **presence_penalty** : Pénalité pour la répétition de tokens

### Mode "Thinking"

Qwen 3 propose un mode "Thinking" spécial qui améliore les capacités de raisonnement du modèle. Les paramètres recommandés pour ce mode sont :

```json
{
  "temperature": 0.6,
  "top_p": 0.95,
  "top_k": 20,
  "min_p": 0,
  "presence_penalty": 1.5,
  "enable_thinking": true
}
```

## Utilisation avec l'architecture N5

Les modèles Qwen 3 peuvent être utilisés avec l'architecture à 5 niveaux (N5) comme suit :

- **Micro** : Qwen3-0.6B (remplace Claude 3 Haiku)
- **Mini** : Qwen3-4B (remplace Claude 3.5 Sonnet)
- **Medium** : Qwen3-14B (remplace Claude 3.5 Sonnet)
- **Large** : Qwen3-32B ou Qwen3-30B-A3B (remplace Claude 3.7 Sonnet)
- **Oracle** : Qwen3-235B-A22B (remplace Claude 3.7 Opus)

## Intégration dans Roo

Pour utiliser ces profils dans Roo, vous devez modifier le fichier de configuration des modes dans `roo-modes/n5/configs/` et remplacer les modèles Claude par les modèles Qwen 3 correspondants.

Exemple pour le mode "code-micro" :

```json
{
  "slug": "code-micro",
  "name": "💻 Code Micro",
  "model": "Qwen/Qwen3-0.6B-Base",
  "parameters": {
    "temperature": 0.7,
    "top_p": 0.9,
    "top_k": 40,
    "min_p": 0.05
  },
  "family": "n5",
  "allowedFamilyTransitions": ["n5"],
  "complexity": {
    "level": "micro",
    "metrics": {
      "tokens": 0,
      "turns": 0,
      "depth": 0
    }
  }
}
```

## Ressources supplémentaires

- [Documentation officielle de Qwen 3](https://qwenlm.github.io/blog/qwen3/)
- [Guide d'inférence Qwen 3](https://deepwiki.com/QwenLM/Qwen/3-inference-guide)
- [Benchmarks et comparaisons](https://www.analyticsvidhya.com/blog/2025/04/qwen3/)
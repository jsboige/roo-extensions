# Guide complet sur les modes Roo et leur déploiement

## Table des matières

1. [Introduction](#introduction)
2. [Dernières avancées de Roo](#dernières-avancées-de-roo)
3. [Structure de configuration Roo](#structure-de-configuration-roo)
4. [Modes simples et complexes](#modes-simples-et-complexes)
5. [Profils de modèles Qwen 3](#profils-de-modèles-qwen-3)
6. [Mécanismes d'escalade et désescalade](#mécanismes-descalade-et-désescalade)
7. [Déploiement des modes](#déploiement-des-modes)
8. [Utilisation optimisée des MCPs](#utilisation-optimisée-des-mcps)
9. [Bonnes pratiques](#bonnes-pratiques)
10. [Ressources supplémentaires](#ressources-supplémentaires)

## Introduction

Ce document présente un guide complet sur les modes Roo, leur configuration, leur déploiement et leur utilisation. Il se concentre particulièrement sur les modes simples et complexes, qui constituent la base de l'architecture de Roo.

## Dernières avancées de Roo

D'après la dernière release (v3.17.0 du 14 mai 2025), Roo a introduit plusieurs améliorations importantes :

- Ajout d'une section "when to use" aux définitions des modes pour permettre une meilleure orchestration
- Fonctionnalité expérimentale pour condenser intelligemment le contexte des tâches au lieu de le tronquer
- Amélioration de l'outil apply_diff pour déduire intelligemment les numéros de ligne
- Mise à jour des descriptions d'outils et des instructions personnalisées dans les prompts système
- Activation du cache implicite pour Gemini
- Correction de problèmes d'interface utilisateur et amélioration des performances

Ces améliorations renforcent l'efficacité des modes et leur capacité à gérer des tâches complexes.

## Structure de configuration Roo

La configuration de Roo est organisée en deux répertoires principaux :

1. **roo-modes** : Contient les configurations spécifiques aux modes personnalisés
   - `configs/` : Fichiers de configuration des modes
   - `docs/` : Documentation sur les modes
   - `examples/` : Exemples d'utilisation
   - `n5/` : Modes avec architecture à 5 niveaux

2. **roo-config** : Contient les configurations générales et les profils de modèles
   - `settings/` : Configurations générales de Roo
   - `qwen3-profiles/` : Profils pour les modèles Qwen 3

Les configurations des modes peuvent être déployées :
- **Globalement** : Pour toutes les instances de VS Code
  - Emplacement : `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`
- **Localement** : Pour un projet spécifique
  - Emplacement : `.roomodes` à la racine du projet

## Modes simples et complexes

Roo propose deux niveaux de complexité pour ses modes :

### Modes simples

Les modes simples sont conçus pour des tâches légères et bien définies :

- **Modèle** : Claude 3.5 Sonnet ou Qwen3-32B
- **Caractéristiques** :
  - Modifications de code < 50 lignes
  - Fonctionnalités isolées
  - Bugs simples
  - Patterns standards
  - Documentation basique

Les modes simples disponibles sont :
- `code-simple` : Pour les modifications mineures de code
- `debug-simple` : Pour l'identification et la résolution de bugs simples
- `architect-simple` : Pour la documentation technique simple
- `ask-simple` : Pour les questions factuelles et les explications basiques
- `orchestrator-simple` : Pour la coordination de tâches simples

### Modes complexes

Les modes complexes sont conçus pour des tâches plus élaborées et interdépendantes :

- **Modèle** : Claude 3.7 Sonnet ou Qwen3-235B-A22B
- **Caractéristiques** :
  - Refactorisations majeures
  - Conception d'architecture
  - Optimisations de performance
  - Algorithmes complexes
  - Intégration de systèmes

Les modes complexes disponibles sont :
- `code-complex` : Pour les modifications majeures et l'architecture de code
- `debug-complex` : Pour les bugs complexes et l'analyse de performance
- `architect-complex` : Pour la conception de systèmes et l'optimisation d'architecture
- `ask-complex` : Pour les analyses approfondies et les comparaisons détaillées
- `orchestrator-complex` : Pour la coordination de workflows complexes
- `manager` : Pour la décomposition de tâches complexes et la gestion des ressources

### Famille de modes

Les modes sont organisés en familles pour faciliter les transitions :
- **Famille simple** : Tous les modes simples
- **Famille complexe** : Tous les modes complexes et le mode manager

Le système de validation des transitions entre familles (`mode-family-validator`) assure que les transitions se font de manière cohérente.

## Profils de modèles Qwen 3

Les modèles Qwen 3 peuvent être utilisés comme alternatives aux modèles Claude pour les différents niveaux de complexité :

### Modèles denses
- **Qwen3-0.6B** : Modèle léger de 0.6 milliards de paramètres
- **Qwen3-4B** : Modèle de 4 milliards de paramètres
- **Qwen3-14B** : Modèle de 14 milliards de paramètres
- **Qwen3-32B** : Modèle de 32 milliards de paramètres

### Modèles MoE (Mixture-of-Experts)
- **Qwen3-30B-A3B** : Modèle de 30 milliards de paramètres avec 3 milliards de paramètres actifs
- **Qwen3-235B-A22B** : Modèle phare de 235 milliards de paramètres avec 22 milliards de paramètres actifs

### Correspondance avec les niveaux de complexité

- **Simple** : Qwen3-0.6B, Qwen3-4B (remplace Claude 3.5 Sonnet)
- **Complexe** : Qwen3-14B, Qwen3-32B, Qwen3-30B-A3B (remplace Claude 3.7 Sonnet)
- **Très complexe** : Qwen3-235B-A22B (remplace Claude 3.7 Opus)

### Mode "Thinking"

Qwen 3 propose un mode "Thinking" spécial qui améliore les capacités de raisonnement du modèle avec des paramètres optimisés :
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

## Mécanismes d'escalade et désescalade

Les mécanismes d'escalade et de désescalade permettent d'adapter dynamiquement le niveau de complexité des agents Roo en fonction des besoins de la tâche.

### Escalade

L'escalade permet de passer d'un mode simple à un mode complexe lorsqu'une tâche dépasse les capacités du mode simple.

#### Escalade externe

L'escalade externe consiste à terminer la tâche dans le mode simple et à recommander à l'utilisateur de passer au mode complexe correspondant.

**Format standardisé** :
```
[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]
```

#### Escalade interne

L'escalade interne permet de traiter une tâche complexe sans changer de mode, dans certains cas spécifiques.

**Format standardisé au début de la réponse** :
```
[ESCALADE INTERNE] Cette tâche est traitée en mode avancé car : [RAISON SPÉCIFIQUE]
```

**Format standardisé à la fin de la réponse** :
```
[SIGNALER_ESCALADE_INTERNE]
```

#### Critères d'escalade

Une tâche doit être escaladée si elle correspond à l'un des critères suivants :
- Nécessite des modifications de plus de 50 lignes de code
- Implique des refactorisations majeures
- Nécessite une conception d'architecture
- Implique des optimisations de performance
- Nécessite une analyse approfondie
- Implique plusieurs systèmes ou composants interdépendants
- Nécessite une compréhension approfondie de l'architecture globale

### Désescalade

La désescalade permet de passer d'un mode complexe à un mode simple lorsqu'une tâche s'avère plus simple que prévu.

**Format standardisé** :
```
[DÉSESCALADE SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : [RAISON]
```

#### Critères de désescalade

Une tâche est considérée comme simple si elle remplit TOUS les critères suivants :
- Nécessite des modifications de moins de 50 lignes de code
- Concerne des fonctionnalités isolées sans impact sur d'autres systèmes
- Suit des patterns standards bien documentés
- Ne nécessite pas d'optimisations complexes
- Ne requiert pas d'analyse approfondie de l'architecture existante

### Gestion des tokens

Les mécanismes d'escalade et de désescalade incluent également une gestion des tokens pour optimiser les ressources :

- Si la conversation dépasse 50 000 tokens en mode simple :
  ```
  [LIMITE DE TOKENS] Cette conversation a dépassé 50 000 tokens. Je recommande de passer en mode complexe pour continuer.
  ```

- Si la conversation dépasse 100 000 tokens (tous modes) :
  ```
  [LIMITE DE TOKENS CRITIQUE] Cette conversation a dépassé 100 000 tokens. Je recommande de passer en mode orchestration pour diviser la tâche en sous-tâches.
  ```

## Déploiement des modes

### Déploiement des modes simples/complex

Pour déployer les modes simples et complexes, utilisez le script `deploy-modes-enhanced.ps1` :

```powershell
# Déploiement global des modes standard
.\roo-config\deploy-modes-enhanced.ps1 -ConfigFile "roo-modes/configs/standard-modes.json" -DeploymentType global

# Déploiement local des modes standard
.\roo-config\deploy-modes-enhanced.ps1 -ConfigFile "roo-modes/configs/standard-modes.json" -DeploymentType local

# Déploiement forcé (sans confirmation)
.\roo-config\deploy-modes-enhanced.ps1 -ConfigFile "roo-modes/configs/standard-modes.json" -DeploymentType global -Force

# Déploiement avec tests automatiques
.\roo-config\deploy-modes-enhanced.ps1 -ConfigFile "roo-modes/configs/standard-modes.json" -DeploymentType global -TestAfterDeploy
```

### Procédure de déploiement

1. **Ouvrez PowerShell** dans le répertoire racine du projet.
2. **Exécutez le script de déploiement** avec les paramètres appropriés.
3. **Confirmez le remplacement** si le fichier de destination existe déjà (sauf si l'option `-Force` est utilisée).
4. **Vérifiez le résultat** affiché par le script.
5. **Redémarrez Visual Studio Code** pour appliquer les changements.

### Vérification du déploiement

1. Redémarrez Visual Studio Code
2. Ouvrez la palette de commandes (Ctrl+Shift+P)
3. Tapez 'Roo: Switch Mode' et vérifiez que les modes personnalisés sont disponibles
4. Vérifiez spécifiquement que les modes simples et complexes sont disponibles et fonctionnent correctement

## Utilisation optimisée des MCPs

Les Model Context Protocol (MCP) servers permettent d'effectuer des opérations complexes sans validation humaine. Il est recommandé de privilégier systématiquement l'utilisation des MCPs par rapport aux outils standards nécessitant une validation humaine.

### MCPs recommandés

#### quickfiles
Pour les manipulations de fichiers multiples ou volumineux :
```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": ["chemin/fichier1.js", "chemin/fichier2.js"],
  "show_line_numbers": true
}
</arguments>
</use_mcp_tool>
```

#### jinavigator
Pour l'extraction d'informations de pages web :
```xml
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>convert_web_to_markdown</tool_name>
<arguments>
{
  "url": "https://example.com"
}
</arguments>
</use_mcp_tool>
```

#### searxng
Pour effectuer des recherches web :
```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "votre recherche ici"
}
</arguments>
</use_mcp_tool>
```

### Conseils pour économiser les tokens

- Regroupez les opérations similaires en une seule commande MCP
- Utilisez les outils de lecture/écriture multiple plutôt que des opérations individuelles
- Filtrez les données à la source plutôt que de tout lire puis filtrer
- Limitez l'affichage des résultats volumineux en utilisant les paramètres de pagination

## Bonnes pratiques

### Gestion des configurations

- Conservez une copie de sauvegarde de vos configurations personnalisées
- Documentez les modifications apportées aux configurations standard
- Utilisez le contrôle de version pour suivre l'évolution des configurations

### Sécurité

- Ne partagez jamais vos clés d'API ou autres informations sensibles
- Utilisez des variables d'environnement ou un gestionnaire de secrets pour les informations sensibles
- Vérifiez régulièrement les autorisations accordées à Roo

### Déploiement

- Testez les nouvelles configurations dans un environnement isolé avant de les déployer globalement
- Informez les utilisateurs des changements majeurs dans les configurations
- Prévoyez une procédure de restauration en cas de problème

### Utilisation des modes

- Utilisez les modes simples pour les tâches légères et bien définies
- Réservez les modes complexes pour les tâches nécessitant une analyse approfondie
- Utilisez le mode manager pour décomposer les tâches complexes en sous-tâches
- Respectez les mécanismes d'escalade et de désescalade pour optimiser l'utilisation des ressources

## Ressources supplémentaires

- [Documentation officielle de Roo](https://docs.roo.ai/)
- [Documentation des modes personnalisés](../roo-modes/README.md)
- [Documentation des configurations générales](../roo-config/settings/README.md)
- [Guide d'escalade et désescalade](./guide-escalade-desescalade.md)
- [Guide de déploiement des configurations](./guide-deploiement-configurations-roo.md)
- [Documentation des profils Qwen 3](../roo-config/qwen3-profiles/README.md)
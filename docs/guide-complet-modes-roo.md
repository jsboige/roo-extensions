# Guide complet sur les modes Roo et leur déploiement

## Table des matières

1. [Introduction](#introduction)
2. [Dernières avancées de Roo](#dernières-avancées-de-roo)
3. [Structure de configuration Roo](#structure-de-configuration-roo)
4. [Modes simples et complexes](#modes-simples-et-complexes)
5. [Dynamique d'orchestration entre modes](#dynamique-dorchestration-entre-modes)
6. [Profils de modèles Qwen 3](#profils-de-modèles-qwen-3)
7. [Mécanismes d'escalade et désescalade](#mécanismes-descalade-et-désescalade)
8. [Déploiement des modes](#déploiement-des-modes)
9. [Utilisation optimisée des MCPs](#utilisation-optimisée-des-mcps)
10. [Bonnes pratiques](#bonnes-pratiques)
11. [Ressources supplémentaires](#ressources-supplémentaires)

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

Les modes simples sont conçus pour des tâches légères et bien définies, mais aussi pour **orchestrer et finaliser le travail des modes complexes** :

- **Modèle** : Claude 3.5 Sonnet ou Qwen3-32B
- **Taille de contexte** : 2x plus petite que les modes complexes
- **Caractéristiques principales** :
  - Modifications de code < 50 lignes
  - Fonctionnalités isolées
  - Bugs simples
  - Patterns standards
  - Documentation basique
  - **Finalisation de workflows complexes**
  - **Orchestration de tâches multiples**

#### Capacités d'orchestration des modes simples

Les modes simples peuvent **toujours orchestrer et finaliser** le travail des modes complexes :

- **Nettoyage post-développement** : Suppression des fichiers temporaires, logs de debug
- **Commits et versioning** : Création de commits avec messages appropriés
- **Tests et validation** : Exécution des tests unitaires, validation syntaxique
- **Documentation** : Mise à jour des README, génération de release notes
- **Déploiement** : Préparation des packages, validation des configurations

#### Stratégies de basculement des modes simples

À cause de leur taille de contexte réduite, les modes simples doivent :

1. **Privilégier le basculement vers l'orchestrateur simple** (recommandé)
2. **Basculer vers leur version complexe** en dernier recours
3. **Optimiser leur contexte** dès 25 000 tokens
4. **Basculer obligatoirement** à 50 000 tokens

Les modes simples disponibles sont :
- `code-simple` : Modifications mineures de code + finalisation de développements complexes
- `debug-simple` : Bugs simples + validation post-correction complexe
- `architect-simple` : Documentation technique simple + finalisation d'architectures
- `ask-simple` : Questions factuelles + synthèse de recherches complexes
- `orchestrator-simple` : Coordination de tâches simples + décomposition de workflows complexes

### Modes complexes

Les modes complexes sont conçus pour des tâches plus élaborées et interdépendantes, avec une **obligation de déléguer aux modes simples** dès que possible :

- **Modèle** : Claude 3.7 Sonnet ou Qwen3-235B-A22B
- **Taille de contexte** : 2x plus grande que les modes simples
- **Caractéristiques principales** :
  - Refactorisations majeures
  - Conception d'architecture
  - Optimisations de performance
  - Algorithmes complexes
  - Intégration de systèmes
  - **Analyse approfondie et conception**
  - **Délégation systématique vers les modes simples**

#### Stratégies de délégation des modes complexes

Les modes complexes doivent **systématiquement déléguer** aux modes simples :

- **Après la phase d'analyse** : Déléguer l'implémentation des parties standards
- **Après la conception** : Déléguer la création de la documentation
- **Après le développement** : Déléguer les tests, commits, et nettoyage
- **En cours de travail** : Déléguer les tâches répétitives ou standardisées

#### Principe d'efficacité des ressources

Les modes complexes sont des ressources coûteuses qui doivent :

1. **Se concentrer sur leur valeur ajoutée** (analyse, conception, résolution complexe)
2. **Déléguer dès que possible** vers les modes simples
3. **Passer en orchestration** pour les workflows multi-étapes
4. **Éviter les tâches répétitives** ou standardisées

Les modes complexes disponibles sont :
- `code-complex` : Modifications majeures + délégation de l'implémentation standard
- `debug-complex` : Bugs complexes + délégation des tests de validation
- `architect-complex` : Conception de systèmes + délégation de la documentation
- `ask-complex` : Analyses approfondies + délégation de la synthèse
- `orchestrator-complex` : Workflows complexes + délégation des tâches simples
- `manager` : Décomposition complexe + délégation de l'exécution

### Famille de modes

Les modes sont organisés en familles pour faciliter les transitions :
- **Famille simple** : Tous les modes simples
- **Famille complexe** : Tous les modes complexes et le mode manager

Le système de validation des transitions entre familles (`mode-family-validator`) assure que les transitions se font de manière cohérente.

## Dynamique d'orchestration entre modes

L'architecture Roo implémente une orchestration dynamique sophistiquée entre les modes simples et complexes, permettant une utilisation optimale des ressources et une adaptation en temps réel aux besoins des tâches.

### Principes fondamentaux

#### 1. Complémentarité des modes

Les modes simples et complexes ne sont pas en concurrence mais en complémentarité :

- **Modes complexes** : Excellent pour l'analyse, la conception, et les tâches nécessitant une compréhension approfondie
- **Modes simples** : Excellent pour l'exécution, la finalisation, et les tâches répétitives ou standardisées

#### 2. Orchestration bidirectionnelle

L'orchestration fonctionne dans les deux sens :

- **Complexe → Simple** : Délégation des tâches d'exécution et de finalisation
- **Simple → Complexe** : Escalade pour les tâches nécessitant une analyse approfondie

#### 3. Finalisation par les modes simples

Un principe clé : **les modes simples peuvent toujours orchestrer et finaliser le travail des modes complexes**. Cette capacité permet :

- Une utilisation efficace des ressources coûteuses (modes complexes)
- Une finalisation systématique et fiable des tâches
- Une continuité dans l'exécution des workflows

### Workflows d'orchestration typiques

#### Workflow de développement complet

1. **Mode complexe** : Analyse des besoins et conception de l'architecture
2. **Mode complexe** : Implémentation des composants critiques
3. **Mode simple** : Implémentation des composants standards
4. **Mode simple** : Tests unitaires et validation
5. **Mode simple** : Documentation et commits
6. **Mode simple** : Nettoyage et finalisation

#### Workflow de débogage

1. **Mode simple** : Identification et reproduction du bug
2. **Mode complexe** : Analyse approfondie si le bug est complexe
3. **Mode simple** : Implémentation du correctif
4. **Mode simple** : Tests de régression
5. **Mode simple** : Documentation du correctif

#### Workflow de refactorisation

1. **Mode complexe** : Analyse de l'architecture existante
2. **Mode complexe** : Conception de la nouvelle architecture
3. **Mode complexe** : Refactorisation des composants critiques
4. **Mode simple** : Refactorisation des composants standards
5. **Mode simple** : Mise à jour des tests
6. **Mode simple** : Mise à jour de la documentation
7. **Mode simple** : Validation et déploiement

### Critères de basculement vers l'orchestrateur simple

Les modes simples doivent privilégier le basculement vers l'orchestrateur simple dans les cas suivants :

#### Critères de contexte

- **Approche de la limite de tokens** (> 40 000 tokens)
- **Conversation devenant trop longue** (> 15 messages)
- **Accumulation de sous-tâches** multiples

#### Critères de complexité

- **Tâche décomposable** en plusieurs sous-tâches indépendantes
- **Nécessité de coordination** entre plusieurs types de tâches
- **Workflow multi-étapes** nécessitant différents types d'expertise

#### Critères d'efficacité

- **Optimisation des ressources** : Éviter l'escalade inutile vers la complexité
- **Parallélisation possible** : Tâches pouvant être traitées en parallèle
- **Spécialisation requise** : Différentes tâches nécessitant différents modes spécialisés

### Stratégies d'optimisation des ressources

#### Utilisation séquentielle optimisée

1. **Phase d'analyse** : Mode complexe pour la compréhension globale
2. **Phase d'exécution** : Mode simple pour l'implémentation
3. **Phase de finalisation** : Mode simple pour le nettoyage et la documentation

#### Utilisation en cascade

- **Mode complexe** → **Mode simple** → **Mode simple** (spécialisé)
- Chaque mode se concentre sur ses forces spécifiques
- Transmission efficace du contexte entre les modes

#### Utilisation en boucle

- **Mode simple** → **Mode complexe** → **Mode simple**
- Escalade ponctuelle pour résoudre un point complexe
- Retour au mode simple pour continuer l'exécution

### Gestion de la continuité entre modes

#### Transmission du contexte

Pour assurer une transition fluide entre modes :

- **Documentation systématique** de l'état actuel
- **Résumé des décisions** prises par le mode précédent
- **Liste des tâches restantes** avec leur niveau de complexité
- **Identification des dépendances** entre les tâches

#### Formats de transition standardisés

**Transition Complexe → Simple** :
```
[TRANSITION VERS MODE SIMPLE]
Tâches complétées : [LISTE]
Tâches à finaliser : [LISTE]
Contexte nécessaire : [RÉSUMÉ]
Fichiers modifiés : [LISTE]
```

**Transition Simple → Complexe** :
```
[TRANSITION VERS MODE COMPLEXE]
Problème rencontré : [DESCRIPTION]
Analyse requise : [TYPE]
Contexte actuel : [RÉSUMÉ]
Constraintes : [LISTE]
```

**Transition vers Orchestrateur Simple** :
```
[TRANSITION VERS ORCHESTRATEUR SIMPLE]
Tâches identifiées : [LISTE]
Priorités : [ORDRE]
Dépendances : [RELATIONS]
Ressources nécessaires : [TYPES DE MODES]
```

### Métriques et optimisation

#### Indicateurs de performance

- **Temps de résolution** par type de tâche et mode utilisé
- **Taux de réussite** des transitions entre modes
- **Utilisation des tokens** par mode et par type de tâche
- **Nombre de basculements** nécessaires par workflow

#### Optimisation continue

- **Analyse des patterns** de basculement les plus efficaces
- **Identification des goulots d'étranglement** dans les workflows
- **Ajustement des seuils** de basculement selon les retours d'expérience
- **Amélioration des formats** de transition entre modes

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

Les mécanismes d'escalade et de désescalade permettent d'adapter dynamiquement le niveau de complexité des agents Roo en fonction des besoins de la tâche. Ces mécanismes sont au cœur de l'orchestration dynamique entre modes simples et complexes.

### Principe fondamental de l'orchestration dynamique

L'architecture Roo repose sur une orchestration dynamique bidirectionnelle :

1. **Les modes complexes délèguent aux modes simples** dès qu'ils le peuvent
2. **Les modes simples orchestrent les modes complexes** dès qu'ils le doivent
3. **Les modes simples finalisent le travail des modes complexes** (nettoyage, commits, tests, documentation)
4. **Les modes simples basculent vers l'orchestrateur simple** avant d'atteindre leur limite de contexte

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

### Orchestration dynamique entre modes simples et complexes

#### Délégation des modes complexes vers les modes simples

Les modes complexes doivent systématiquement déléguer aux modes simples dès qu'une partie de la tâche peut être traitée de manière simple :

**Cas typiques de délégation** :
- Nettoyage de fichiers temporaires ou intermédiaires
- Exécution de commits Git avec messages standardisés
- Mise à jour de tests unitaires existants
- Génération de documentation basique
- Formatage de code selon les standards du projet
- Validation de syntaxe et correction d'erreurs simples

**Format de délégation** :
```
[DÉLÉGATION VERS MODE SIMPLE] Je délègue la finalisation à un mode simple pour : [TÂCHE SPÉCIFIQUE]
```

#### Orchestration des modes simples vers les modes complexes

Les modes simples doivent orchestrer les modes complexes lorsqu'ils rencontrent des limitations :

**Cas typiques d'orchestration** :
- Analyse d'architecture nécessaire avant modification
- Refactorisation impactant plusieurs composants
- Optimisation de performance nécessitant une analyse approfondie
- Résolution de bugs complexes avec impact système
- Conception de nouvelles fonctionnalités majeures

**Format d'orchestration** :
```
[ORCHESTRATION MODE COMPLEXE] Cette tâche nécessite l'intervention d'un mode complexe pour : [RAISON DÉTAILLÉE]
```

#### Finalisation par les modes simples

Un principe fondamental de l'architecture Roo est que **les modes simples peuvent toujours orchestrer et finaliser le travail des modes complexes**. Cette capacité permet une utilisation optimale des ressources.

**Tâches de finalisation typiques** :
- **Nettoyage post-développement** : Suppression des fichiers temporaires, logs de debug, commentaires de développement
- **Commits et versioning** : Création de commits avec messages appropriés, mise à jour des numéros de version
- **Tests et validation** : Exécution des tests unitaires, validation de la syntaxe, vérification des standards de code
- **Documentation** : Mise à jour des README, génération de release notes, documentation des API
- **Déploiement** : Préparation des packages, validation des configurations de déploiement

**Workflow de finalisation** :
1. Le mode complexe termine son travail principal
2. Il identifie les tâches de finalisation nécessaires
3. Il délègue ces tâches à un mode simple approprié
4. Le mode simple exécute la finalisation et confirme la completion

### Gestion des tokens et basculement vers l'orchestrateur simple

Les modes simples ont une taille de contexte deux fois moindre que les modes complexes, ce qui nécessite une gestion proactive des tokens.

#### Seuils de basculement pour les modes simples

- **25 000 tokens** : Alerte précoce, optimisation du contexte
  ```
  [OPTIMISATION CONTEXTE] Approche de la limite de contexte, optimisation en cours.
  ```

- **40 000 tokens** : Basculement recommandé vers l'orchestrateur simple
  ```
  [BASCULEMENT ORCHESTRATEUR SIMPLE] Limite de contexte approchée, basculement vers l'orchestrateur simple recommandé.
  ```

- **50 000 tokens** : Basculement obligatoire
  ```
  [LIMITE DE TOKENS] Cette conversation a dépassé 50 000 tokens. Basculement obligatoire vers l'orchestrateur simple ou le mode complexe.
  ```

#### Stratégie de basculement privilégiée

Les modes simples doivent **privilégier le basculement vers l'orchestrateur simple** plutôt que vers leur version complexe, car :

1. **Efficacité des ressources** : L'orchestrateur simple peut décomposer la tâche en sous-tâches gérables
2. **Maintien de la simplicité** : Évite l'escalade inutile vers la complexité
3. **Optimisation du workflow** : Permet une meilleure répartition des tâches

**Critères de choix** :
- **Vers orchestrateur simple** : Tâche décomposable en sous-tâches simples
- **Vers mode complexe** : Tâche intrinsèquement complexe nécessitant une analyse approfondie

### Gestion des tokens pour tous les modes

#### Seuils généraux

- **100 000 tokens (tous modes)** : Basculement critique vers l'orchestration
  ```
  [LIMITE DE TOKENS CRITIQUE] Cette conversation a dépassé 100 000 tokens. Je recommande de passer en mode orchestration pour diviser la tâche en sous-tâches.
  ```

#### Escalade par approfondissement

Pour les conversations volumineuses, l'escalade par approfondissement permet de créer des sous-tâches :

- **50 000 tokens avec commandes lourdes** : Suggestion de sous-tâches
- **15 messages de taille moyenne** : Évaluation de la création de sous-tâches

**Format d'escalade par approfondissement** :
```
[ESCALADE PAR APPROFONDISSEMENT] Je suggère de créer une sous-tâche pour continuer ce travail car : [RAISON]
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

### Utilisation des modes et orchestration dynamique

#### Principes généraux
- Utilisez les modes simples pour les tâches légères, la finalisation, et l'orchestration
- Réservez les modes complexes pour l'analyse approfondie et la conception
- Utilisez le mode manager pour décomposer les tâches complexes en sous-tâches
- Respectez les mécanismes d'escalade et de désescalade pour optimiser l'utilisation des ressources

#### Orchestration dynamique
- **Modes complexes** : Déléguez systématiquement aux modes simples dès que possible
- **Modes simples** : Orchestrez les modes complexes quand nécessaire, finalisez toujours leur travail
- **Basculement intelligent** : Privilégiez l'orchestrateur simple avant d'atteindre les limites de contexte
- **Continuité des workflows** : Assurez une transmission claire du contexte entre les modes

#### Optimisation des ressources
- **Séquençage efficace** : Analyse (complexe) → Implémentation (simple) → Finalisation (simple)
- **Délégation proactive** : Les modes complexes délèguent avant d'être surchargés
- **Finalisation systématique** : Les modes simples finalisent toujours le travail des modes complexes
- **Gestion des tokens** : Surveillez les seuils et basculez de manière préventive

#### Workflows recommandés
- **Développement** : Complexe (conception) → Simple (implémentation) → Simple (tests/docs)
- **Débogage** : Simple (identification) → Complexe (analyse) → Simple (correction/validation)
- **Refactorisation** : Complexe (architecture) → Simple (implémentation) → Simple (finalisation)
- **Documentation** : Complexe (analyse) → Simple (rédaction) → Simple (mise en forme)

## Ressources supplémentaires

- [Documentation officielle de Roo](https://docs.roo.ai/)
- [Documentation des modes personnalisés](../roo-modes/README.md)
- [Documentation des configurations générales](../roo-config/settings/README.md)
- [Guide d'escalade et désescalade](./guide-escalade-desescalade.md)
- [Guide de déploiement des configurations](./guide-deploiement-configurations-roo.md)
- [Documentation des profils Qwen 3](../roo-config/qwen3-profiles/README.md)
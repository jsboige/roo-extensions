# Guide de déploiement des modes personnalisés Roo sur d'autres machines

Ce document explique comment déployer les modes personnalisés Roo sur d'autres machines, notamment sur une machine qui héberge des modèles de langage locaux (LLMs) derrière des endpoints dédiés.

## Table des matières

1. [Introduction](#1-introduction)
2. [Prérequis](#2-prérequis)
3. [Déploiement sur une machine avec modèles locaux](#3-déploiement-sur-une-machine-avec-modèles-locaux)
4. [Adaptation pour les endpoints "micro", "mini" et "medium"](#4-adaptation-pour-les-endpoints-micro-mini-et-medium)
5. [Évolution vers 5 niveaux de modes](#5-évolution-vers-5-niveaux-de-modes)
6. [Résolution des problèmes courants](#6-résolution-des-problèmes-courants)
7. [Annexes](#7-annexes)

## 1. Introduction

### 1.1 Contexte et objectifs

Les modes personnalisés Roo permettent d'optimiser l'utilisation des ressources en dirigeant les tâches vers le mode le plus approprié selon leur complexité. Cette configuration a été testée et validée sur une machine de développement, mais elle peut être déployée sur d'autres machines, notamment celles qui hébergent des modèles de langage locaux.

Ce guide a pour objectif de :
- Documenter les étapes nécessaires pour déployer les modes personnalisés sur une machine avec des modèles locaux
- Expliquer comment adapter la configuration pour utiliser des endpoints "micro", "mini" et "medium"
- Proposer une structure pour une future évolution vers 5 niveaux de modes au lieu de 2 (simple/complexe)

### 1.2 Architecture actuelle

L'architecture actuelle des modes personnalisés comprend 5 types de modes (code, debug, architect, ask, orchestrator), chacun disponible en 2 niveaux de complexité (simple et complexe) :

- 💻 Code Simple / 💻 Code Complex
- 🪲 Debug Simple / 🪲 Debug Complex
- 🏗️ Architect Simple / 🏗️ Architect Complex
- ❓ Ask Simple / ❓ Ask Complex
- 🪃 Orchestrator Simple / 🪃 Orchestrator Complex

Chaque mode est associé à un modèle spécifique :
- Modes simples : anthropic/claude-3.5-sonnet
- Modes complexes : anthropic/claude-3.7-sonnet
## 2. Prérequis

### 2.1 Configuration requise

- Visual Studio Code installé
- Extension Roo installée et configurée
- PowerShell 5.1 ou supérieur
- Droits d'accès aux répertoires de configuration de VS Code
- Accès aux endpoints des modèles locaux (si applicable)

### 2.2 Informations nécessaires

Avant de commencer le déploiement, vous devez disposer des informations suivantes :

- URLs des endpoints des modèles locaux
- Clés d'API ou tokens d'authentification (si nécessaire)
- Capacités et limitations de chaque modèle local
- Structure du fichier de configuration Roo sur la machine cible

## 3. Déploiement sur une machine avec modèles locaux

### 3.1 Installation de base

1. Cloner le dépôt contenant les modes personnalisés :
   ```powershell
   git clone <url-du-depot> <chemin-local>
   cd <chemin-local>
   ```

2. Exécuter le script de déploiement standard :
   ```powershell
   .\custom-modes\scripts\deploy.ps1
   ```

   Ce script copie le fichier `.roomodes` vers le fichier global `custom_modes.json` et vérifie que l'installation est correcte.

### 3.2 Configuration pour les modèles locaux

Pour utiliser des modèles locaux au lieu des modèles cloud, vous devez modifier le fichier `.roomodes` avant de le déployer :

1. Ouvrir le fichier `.roomodes` dans un éditeur de texte :
   ```powershell
   code .roomodes
   ```

2. Remplacer les valeurs du champ `model` pour chaque mode par les identifiants de vos modèles locaux.

   Par exemple, si vous avez un modèle local accessible via `http://localhost:8000/v1/chat/completions` :

   ```json
   {
     "slug": "code-simple",
     "name": "💻 Code Simple",
     "model": "local/localhost:8000",
     ...
   }
   ```

3. Enregistrer le fichier et exécuter le script de déploiement :
   ```powershell
   .\custom-modes\scripts\deploy.ps1
   ```

### 3.3 Configuration de l'extension Roo pour les modèles locaux

L'extension Roo doit être configurée pour reconnaître et utiliser vos modèles locaux :

1. Ouvrir les paramètres de VS Code (Ctrl+,)
2. Rechercher "Roo: Model Configs"
3. Cliquer sur "Edit in settings.json"
4. Ajouter une configuration pour chaque modèle local :

   ```json
   "roo.modelConfigs": [
     {
       "id": "local/localhost:8000",
       "displayName": "Local Model",
       "apiType": "openai",
       "apiBase": "http://localhost:8000/v1",
       "apiKey": "sk-your-local-api-key",
       "contextWindow": 16000,
       "maxOutputTokens": 4000
     }
   ]
   ```

5. Enregistrer le fichier et redémarrer VS Code
## 4. Adaptation pour les endpoints "micro", "mini" et "medium"

### 4.1 Configuration des endpoints

Pour une machine qui héberge 3 LLMs derrière des endpoints dédiés "micro", "mini" et "medium", vous devez d'abord configurer ces endpoints dans les paramètres de Roo :

1. Ouvrir les paramètres de VS Code (Ctrl+,)
2. Rechercher "Roo: Model Configs"
3. Cliquer sur "Edit in settings.json"
4. Ajouter une configuration pour chaque endpoint :

   ```json
   "roo.modelConfigs": [
     {
       "id": "local/micro",
       "displayName": "Local Micro Model",
       "apiType": "openai",
       "apiBase": "http://localhost:8001/v1",
       "apiKey": "sk-your-local-api-key",
       "contextWindow": 8000,
       "maxOutputTokens": 2000
     },
     {
       "id": "local/mini",
       "displayName": "Local Mini Model",
       "apiType": "openai",
       "apiBase": "http://localhost:8002/v1",
       "apiKey": "sk-your-local-api-key",
       "contextWindow": 16000,
       "maxOutputTokens": 4000
     },
     {
       "id": "local/medium",
       "displayName": "Local Medium Model",
       "apiType": "openai",
       "apiBase": "http://localhost:8003/v1",
       "apiKey": "sk-your-local-api-key",
       "contextWindow": 32000,
       "maxOutputTokens": 8000
     }
   ]
   ```

### 4.2 Mapping des modes aux endpoints appropriés

Modifiez le fichier `.roomodes` pour associer chaque mode à l'endpoint le plus approprié selon sa complexité :

```json
{
  "customModes": [
    {
      "slug": "code-simple",
      "name": "💻 Code Simple",
      "model": "local/micro",
      ...
    },
    {
      "slug": "code-complex",
      "name": "💻 Code Complex",
      "model": "local/medium",
      ...
    },
    {
      "slug": "debug-simple",
      "name": "🪲 Debug Simple",
      "model": "local/micro",
      ...
    },
    {
      "slug": "debug-complex",
      "name": "🪲 Debug Complex",
      "model": "local/medium",
      ...
    },
    {
      "slug": "architect-simple",
      "name": "🏗️ Architect Simple",
      "model": "local/mini",
      ...
    },
    {
      "slug": "architect-complex",
      "name": "🏗️ Architect Complex",
      "model": "local/medium",
      ...
    },
    {
      "slug": "ask-simple",
      "name": "❓ Ask Simple",
      "model": "local/micro",
      ...
    },
    {
      "slug": "ask-complex",
      "name": "❓ Ask Complex",
      "model": "local/medium",
      ...
    },
    {
      "slug": "orchestrator-simple",
      "name": "🪃 Orchestrator Simple",
      "model": "local/mini",
      ...
    },
    {
      "slug": "orchestrator-complex",
      "name": "🪃 Orchestrator Complex",
      "model": "local/medium",
      ...
    }
  ]
}
```

### 4.3 Adaptation des instructions selon les capacités des modèles

Les modèles locaux peuvent avoir des capacités différentes des modèles cloud. Il est donc important d'adapter les instructions de chaque mode en fonction des capacités du modèle associé :

1. Pour les modes associés à l'endpoint "micro" (capacités limitées) :
   - Simplifier les instructions
   - Réduire la complexité des tâches attendues
   - Ajuster les critères d'escalade pour tenir compte des limitations

2. Pour les modes associés à l'endpoint "mini" (capacités intermédiaires) :
   - Maintenir les instructions actuelles des modes simples
   - Ajuster légèrement les critères d'escalade

3. Pour les modes associés à l'endpoint "medium" (capacités avancées) :
   - Maintenir les instructions actuelles des modes complexes
   - Ajuster légèrement les critères de désescalade

### 4.4 Script de déploiement adapté

Créez un script de déploiement adapté pour les endpoints "micro", "mini" et "medium" dans `custom-modes/scripts/deploy-local-endpoints.ps1`. Ce script devrait :

1. Vérifier l'existence d'un fichier `.roomodes-local` ou le créer à partir du fichier `.roomodes` en adaptant les modèles
2. Copier ce fichier vers le fichier global `custom_modes.json`
3. Vérifier que l'installation est correcte
4. Afficher un résumé des modes installés avec leurs modèles associés

### 4.5 Tests de validation

Après avoir déployé la configuration adaptée, effectuez les tests suivants pour valider le bon fonctionnement :

1. **Test de base :** Vérifiez que chaque mode est accessible via la palette de commandes (Ctrl+Shift+P, "Roo: Switch Mode").

2. **Test d'escalade :** Vérifiez que le mécanisme d'escalade fonctionne correctement en soumettant une tâche complexe à un mode simple.

3. **Test de désescalade :** Vérifiez que le mécanisme de désescalade fonctionne correctement en soumettant une tâche simple à un mode complexe.

4. **Test de performance :** Comparez les performances des différents endpoints pour des tâches similaires.
## 5. Évolution vers 5 niveaux de modes

### 5.1 Structure proposée

Pour évoluer vers 5 niveaux de modes au lieu de 2, nous proposons la structure suivante :

1. **Niveau 1 (Micro) :** Pour les tâches très simples et isolées (< 10 lignes de code, documentation basique, etc.)
   - Modèle associé : local/micro
   - Exemples : code-micro, debug-micro, architect-micro, ask-micro, orchestrator-micro

2. **Niveau 2 (Mini) :** Pour les tâches simples (10-50 lignes de code, documentation standard, etc.)
   - Modèle associé : local/micro ou local/mini selon la complexité
   - Exemples : code-mini, debug-mini, architect-mini, ask-mini, orchestrator-mini

3. **Niveau 3 (Medium) :** Pour les tâches de complexité moyenne (50-200 lignes de code, refactorisation partielle, etc.)
   - Modèle associé : local/mini
   - Exemples : code-medium, debug-medium, architect-medium, ask-medium, orchestrator-medium

4. **Niveau 4 (Major) :** Pour les tâches complexes (200-500 lignes de code, refactorisation majeure, etc.)
   - Modèle associé : local/medium
   - Exemples : code-major, debug-major, architect-major, ask-major, orchestrator-major

5. **Niveau 5 (Mega) :** Pour les tâches très complexes (> 500 lignes de code, conception d'architecture, etc.)
   - Modèle associé : local/medium ou un modèle plus puissant si disponible
   - Exemples : code-mega, debug-mega, architect-mega, ask-mega, orchestrator-mega

### 5.2 Modifications nécessaires au fichier de configuration

Pour implémenter cette structure, vous devez modifier le fichier `.roomodes` comme suit :

```json
{
  "customModes": [
    {
      "slug": "code-micro",
      "name": "💻 Code Micro",
      "model": "local/micro",
      "roleDefinition": "You are Roo Code (version micro), specialized in very simple code modifications, basic formatting, and minimal documentation.",
      "groups": ["read", "edit", "browser", "command", "mcp"],
      "customInstructions": "FOCUS AREAS:\n- Modifications of code < 10 lines\n- Very isolated functions\n- Basic formatting\n- Simple documentation\n\n..."
    },
    {
      "slug": "code-mini",
      "name": "💻 Code Mini",
      "model": "local/micro",
      "roleDefinition": "You are Roo Code (version mini), specialized in minor code modifications, simple bug fixes, code formatting and documentation, and basic feature implementation.",
      "groups": ["read", "edit", "browser", "command", "mcp"],
      "customInstructions": "FOCUS AREAS:\n- Modifications of code 10-50 lines\n- Isolated functions\n- Simple bugs\n- Standard patterns\n- Basic documentation\n\n..."
    },
    // Répéter pour chaque niveau et chaque type de mode
  ]
}
```

### 5.3 Mécanismes d'escalade et de désescalade multi-niveaux

Les mécanismes d'escalade et de désescalade doivent être adaptés pour prendre en compte les 5 niveaux :

1. **Escalade progressive :** Chaque niveau peut escalader vers le niveau immédiatement supérieur, ou sauter plusieurs niveaux si nécessaire.

   Exemple d'instruction pour le niveau Micro :
   ```
   MÉCANISME D'ESCALADE:

   IMPORTANT: Vous DEVEZ escalader toute tâche qui correspond aux critères suivants:
   - Tâches nécessitant des modifications de plus de 10 lignes de code -> Niveau Mini
   - Tâches impliquant des refactorisations -> Niveau Medium ou supérieur
   - Tâches nécessitant une conception d'architecture -> Niveau Major ou Mega
   - Tâches impliquant des optimisations de performance -> Niveau Medium ou supérieur
   - Tâches nécessitant une analyse approfondie -> Niveau Medium ou supérieur

   L'escalade n'est PAS optionnelle pour ces types de tâches et doit être EXTERNE (terminer la tâche). Vous DEVEZ refuser de traiter ces tâches et escalader avec le format exact:
   "[ESCALADE REQUISE VERS NIVEAU X] Cette tâche nécessite la version X de l'agent car : [RAISON]"
   ```

2. **Désescalade ciblée :** Chaque niveau peut suggérer une désescalade vers le niveau le plus approprié, pas nécessairement le niveau immédiatement inférieur.

   Exemple d'instruction pour le niveau Mega :
   ```
   RÉTROGRADATION VERS NIVEAU INFÉRIEUR:

   IMPORTANT: Vous DEVEZ évaluer systématiquement la complexité de la tâche en cours. Si vous constatez que la tâche ou une partie de la tâche est suffisamment simple pour être traitée par une version inférieure de l'agent, vous DEVEZ suggérer à l'utilisateur de passer au niveau approprié.

   Critères de rétrogradation:
   - Tâches nécessitant des modifications de moins de 10 lignes de code -> Niveau Micro
   - Tâches nécessitant des modifications de 10-50 lignes de code -> Niveau Mini
   - Tâches nécessitant des modifications de 50-200 lignes de code -> Niveau Medium
   - Tâches nécessitant des modifications de 200-500 lignes de code -> Niveau Major

   Utilisez le format suivant pour suggérer une rétrogradation:
   "[RÉTROGRADATION REQUISE VERS NIVEAU X] Cette tâche devrait être traitée par la version X de l'agent car : [RAISON]"
   ```

### 5.4 Stratégie de migration

Pour migrer de la structure actuelle (2 niveaux) vers la nouvelle structure (5 niveaux), suivez ces étapes :

1. **Phase 1 : Préparation**
   - Créer un fichier `.roomodes-5levels` basé sur le fichier `.roomodes` existant
   - Ajouter les nouveaux modes (Micro, Mini, Medium, Major, Mega) pour chaque type (code, debug, architect, ask, orchestrator)
   - Adapter les instructions pour chaque niveau

2. **Phase 2 : Tests**
   - Déployer la nouvelle configuration sur un environnement de test
   - Vérifier le bon fonctionnement des mécanismes d'escalade et de désescalade
   - Ajuster les instructions si nécessaire

3. **Phase 3 : Déploiement progressif**
   - Déployer d'abord les niveaux extrêmes (Micro et Mega)
   - Ajouter progressivement les niveaux intermédiaires (Mini, Medium, Major)
   - Former les utilisateurs à la nouvelle structure

4. **Phase 4 : Transition complète**
   - Remplacer complètement l'ancienne structure par la nouvelle
   - Mettre à jour la documentation
   - Recueillir les retours des utilisateurs pour améliorer la configuration

## 6. Résolution des problèmes courants

### 6.1 Problèmes de connexion aux endpoints

Si vous rencontrez des problèmes de connexion aux endpoints locaux :

1. **Vérifier que les endpoints sont actifs :**
   ```powershell
   Invoke-RestMethod -Uri "http://localhost:8001/health" -Method Get
   ```

2. **Vérifier les paramètres de l'API dans la configuration Roo :**
   - Ouvrir les paramètres de VS Code (Ctrl+,)
   - Rechercher "Roo: Model Configs"
   - Vérifier que les URLs et les clés d'API sont correctes

3. **Vérifier les logs des endpoints :**
   - Consulter les logs des serveurs hébergeant les modèles locaux
   - Rechercher des erreurs ou des avertissements liés aux requêtes de Roo

### 6.2 Problèmes de performance

Si vous constatez des problèmes de performance :

1. **Ajuster les paramètres des modèles :**
   - Réduire la taille du contexte (`contextWindow`)
   - Réduire la taille maximale de sortie (`maxOutputTokens`)
   - Ajuster la température ou d'autres paramètres de génération

2. **Optimiser les instructions :**
   - Simplifier les instructions pour les modèles moins puissants
   - Réduire la taille des instructions

3. **Ajuster l'allocation des modes aux endpoints :**
   - Déplacer certains modes vers des endpoints plus ou moins puissants selon les besoins

### 6.3 Problèmes de compatibilité

Si vous rencontrez des problèmes de compatibilité entre les modèles locaux et les instructions :

1. **Adapter les instructions aux capacités des modèles :**
   - Simplifier les instructions pour les modèles moins puissants
   - Ajuster les formats d'entrée/sortie selon les capacités des modèles

2. **Vérifier la compatibilité des API :**
   - S'assurer que les endpoints locaux utilisent une API compatible avec celle attendue par Roo
   - Ajuster les paramètres `apiType` et `apiBase` si nécessaire

3. **Utiliser des adaptateurs si nécessaire :**
   - Développer des adaptateurs pour convertir les requêtes/réponses entre le format attendu par Roo et celui supporté par les endpoints locaux

## 7. Annexes

### 7.1 Exemple de fichier `.roomodes` pour les endpoints locaux

```json
{
  "customModes": [
    {
      "slug": "code-simple",
      "name": "💻 Code Simple",
      "model": "local/micro",
      "roleDefinition": "You are Roo Code (version simple), specialized in minor code modifications, simple bug fixes, code formatting and documentation, and basic feature implementation.",
      "groups": ["read", "edit", "browser", "command", "mcp"],
      "customInstructions": "FOCUS AREAS:\n- Modifications of code < 50 lines\n- Isolated functions\n- Simple bugs\n- Standard patterns\n- Basic documentation\n\n..."
    },
    {
      "slug": "code-complex",
      "name": "💻 Code Complex",
      "model": "local/medium",
      "roleDefinition": "You are Roo, a highly skilled software engineer with extensive knowledge in many programming languages, frameworks, design patterns, and best practices.",
      "groups": ["read", "edit", "browser", "command", "mcp"],
      "customInstructions": "FOCUS AREAS:\n- Major refactoring\n- Architecture design\n- Performance optimization\n- Complex algorithms\n- System integration\n\n..."
    }
  ]
}
```

### 7.2 Exemple de configuration Roo pour les endpoints locaux

```json
"roo.modelConfigs": [
  {
    "id": "local/micro",
    "displayName": "Local Micro Model",
    "apiType": "openai",
    "apiBase": "http://localhost:8001/v1",
    "apiKey": "sk-your-local-api-key",
    "contextWindow": 8000,
    "maxOutputTokens": 2000
  },
  {
    "id": "local/mini",
    "displayName": "Local Mini Model",
    "apiType": "openai",
    "apiBase": "http://localhost:8002/v1",
    "apiKey": "sk-your-local-api-key",
    "contextWindow": 16000,
    "maxOutputTokens": 4000
  },
  {
    "id": "local/medium",
    "displayName": "Local Medium Model",
    "apiType": "openai",
    "apiBase": "http://localhost:8003/v1",
    "apiKey": "sk-your-local-api-key",
    "contextWindow": 32000,
    "maxOutputTokens": 8000
  }
]
```

### 7.3 Ressources supplémentaires

- [Documentation officielle de l'extension Roo](https://marketplace.visualstudio.com/items?itemName=rooveterinaryinc.roo-cline)
- [Documentation sur l'API OpenAI](https://platform.openai.com/docs/api-reference)
- [Guide d'hébergement de modèles locaux](https://github.com/ggerganov/llama.cpp)
- [Optimisation des performances des modèles locaux](https://huggingface.co/docs/transformers/main/en/perf_infer_gpu_one)
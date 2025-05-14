# Rapport sur l'Architecture des Modes Personnalisés Roo

## 1. Introduction et Contexte

L'architecture des modes personnalisés Roo vise à optimiser l'utilisation des ressources en dirigeant les tâches vers le mode le plus approprié selon leur complexité. Actuellement, tous les agents Roo (orchestrator, code, debug, architect, ask) utilisent Claude Sonnet, un modèle performant mais coûteux. L'objectif est d'utiliser des modèles moins coûteux pour certaines tâches tout en conservant Claude Sonnet pour les tâches complexes.

## 2. Architecture à Deux Niveaux (Simple/Complexe)

L'architecture à deux niveaux dédouble chaque profil d'agent en versions "simple" et "complexe" :

### Modes Simples
- Utilisent des modèles moins coûteux (Claude 3.5 Sonnet)
- Se concentrent sur des tâches spécifiques et isolées
- Ont des instructions optimisées pour réduire la consommation de tokens
- Incluent un mécanisme d'escalade pour les tâches dépassant leurs capacités

### Modes Complexes
- Utilisent des modèles plus puissants (Claude 3.7 Sonnet)
- Peuvent gérer des tâches nécessitant une compréhension approfondie
- Ont accès à plus de contexte et de capacités
- Peuvent décomposer des tâches complexes en sous-tâches

### Mécanisme d'Escalade
Le mécanisme d'escalade permet aux modes simples de transférer une tâche à leur équivalent complexe :
1. L'agent simple analyse la demande selon des critères de complexité
2. S'il détecte que la tâche est trop complexe, il signale le besoin d'escalade
3. L'utilisateur peut alors basculer vers le mode complexe correspondant
4. L'agent complexe reprend la tâche avec le contexte déjà établi

Format de signalement d'escalade :
```
[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]
```

## 3. Critères de Décision pour le Routage des Tâches

Le routage des tâches repose sur plusieurs facteurs d'évaluation :

1. **Complexité linguistique** : Analyse de la structure et du vocabulaire de la demande
2. **Complexité technique** : Évaluation de la difficulté technique de la tâche
3. **Besoin en contexte** : Quantité de contexte nécessaire pour accomplir la tâche
4. **Créativité requise** : Niveau d'innovation ou de créativité nécessaire
5. **Criticité** : Importance de la tâche et impact des erreurs potentielles

### Métriques d'Évaluation

#### Complexité Linguistique
- Longueur de la demande : < 100 mots (Simple) vs ≥ 100 mots (Complexe)
- Nombre de questions/requêtes : 1-2 (Simple) vs ≥ 3 (Complexe)
- Présence de termes techniques spécialisés : Faible (Simple) vs Élevée (Complexe)
- Structure syntaxique : Simple vs Complexe (conditions multiples, nuances)

#### Complexité Technique
- **Code** : Modifications < 50 lignes (Simple) vs Refactoring majeur (Complexe)
- **Debug** : Erreurs de syntaxe (Simple) vs Bugs concurrents (Complexe)
- **Architect** : Documentation simple (Simple) vs Conception système (Complexe)
- **Ask** : Questions factuelles (Simple) vs Analyses approfondies (Complexe)

#### Besoin en Contexte
- Nombre de fichiers concernés : 1-3 fichiers (Simple) vs > 3 fichiers (Complexe)
- Taille du contexte nécessaire : < 2000 tokens (Simple) vs ≥ 2000 tokens (Complexe)
- Dépendances entre composants : Faibles (Simple) vs Élevées (Complexe)

## 4. Structure Technique et Implémentation

### Structure des Modes Personnalisés

Les modes personnalisés sont définis dans le fichier `.roomodes` à la racine du projet :

```json
{
  "slug": "code-simple",
  "name": "💻 Code Simple",
  "model": "anthropic/claude-3.5-sonnet",
  "roleDefinition": "You are Roo Code (version simple), specialized in...",
  "groups": ["read", "edit", "browser", "command", "mcp"],
  "customInstructions": "FOCUS AREAS:\n- Modifications of code < 50 lines\n..."
}
```

### Propriétés des Modes
- **slug** : Identifiant unique du mode
- **name** : Nom affiché dans l'interface utilisateur
- **model** : Modèle de langage à utiliser pour ce mode
- **roleDefinition** : Définition du rôle de l'agent
- **groups** : Groupes d'autorisations définissant les capacités de l'agent
- **customInstructions** : Instructions spécifiques pour guider le comportement de l'agent

### Structure des fichiers de configuration
1. **Fichier local** (`.roomodes`) : Situé à la racine du projet
2. **Fichier global** (`custom_modes.json`) : Situé dans le répertoire de configuration global de l'extension Roo
   - Chemin: `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`

## 5. Optimisation des Prompts

### Principes Généraux d'Optimisation
- **Réduction de la Verbosité** : Éliminer les redondances, simplifier les instructions
- **Structuration Efficace** : Hiérarchiser les informations, utiliser des sections clairement délimitées
- **Contextualisation Intelligente** : Charger le contexte à la demande, adapter le niveau de détail au modèle

### Adaptations Spécifiques pour les Versions Simples
Les prompts des versions simples sont optimisés pour être plus concis et directs :

```
Vous êtes Roo Code (version simple), spécialisé dans :
- Modifications de code mineures
- Correction de bugs simples
- Formatage et documentation de code
- Implémentation de fonctionnalités basiques

OUTILS DISPONIBLES :
1. read_file : Lire le contenu d'un fichier
2. write_to_file : Écrire dans un fichier
3. apply_diff : Appliquer des modifications à un fichier
4. search_files : Rechercher dans les fichiers
5. execute_command : Exécuter une commande

Pour les tâches complexes, signalez le besoin d'escalade vers la version complète.
```

### Mécanisme d'Escalade
Chaque prompt simple inclut des instructions pour détecter si une tâche dépasse les capacités du modèle :

```
DÉTECTION DE COMPLEXITÉ :
Si la tâche présente l'une des caractéristiques suivantes, signalez le besoin d'escalade :
- Nécessite l'analyse de plus de 3 fichiers interconnectés
- Implique des concepts avancés (liste spécifique au domaine)
- Requiert une créativité ou innovation significative
- A un impact potentiel élevé sur le système
- Nécessite plus de contexte que disponible

FORMAT DE SIGNALEMENT :
"[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]"
```

## 6. Procédure de Déploiement

### Installation Standard
1. Cloner le dépôt contenant les modes personnalisés
2. Exécuter le script de déploiement :
   ```powershell
   .\custom-modes\scripts\deploy.ps1
   ```
3. Redémarrer VS Code
4. Vérifier que les modes personnalisés apparaissent dans la liste (Ctrl+Shift+P, "Roo: Switch Mode")

### Déploiement sur une Machine avec Modèles Locaux
Pour utiliser des modèles locaux au lieu des modèles cloud :

1. Modifier le fichier `.roomodes` pour utiliser les identifiants des modèles locaux
2. Configurer l'extension Roo pour reconnaître les modèles locaux dans les paramètres VS Code
3. Exécuter le script de déploiement adapté :
   ```powershell
   .\custom-modes\scripts\deploy-local-endpoints.ps1
   ```

Ce script :
- Vérifie l'existence d'un fichier `.roomodes-local` ou le crée à partir du fichier `.roomodes`
- Adapte les modèles pour utiliser les endpoints locaux "micro", "mini" et "medium"
- Copie ce fichier vers le fichier global `custom_modes.json`
- Vérifie que l'installation est correcte
- Affiche un résumé des modes installés avec leurs modèles associés

## 7. Évolution Future vers 5 Niveaux

Une évolution future propose de passer de 2 à 5 niveaux de modes :

1. **Niveau 1 (Micro)** : Tâches très simples (< 10 lignes de code)
2. **Niveau 2 (Mini)** : Tâches simples (10-50 lignes de code)
3. **Niveau 3 (Medium)** : Tâches de complexité moyenne (50-200 lignes de code)
4. **Niveau 4 (Major)** : Tâches complexes (200-500 lignes de code)
5. **Niveau 5 (Mega)** : Tâches très complexes (> 500 lignes de code)

Cette évolution permettrait une granularité plus fine dans l'allocation des ressources et une meilleure adaptation aux capacités des différents modèles.

## 8. Procédure de Nettoyage après Prise en Main

Une fois la prise en main de l'architecture réalisée, il est recommandé de :

1. Supprimer les fichiers temporaires créés pendant le déploiement
   ```powershell
   Remove-Item -Path ".roomodes-local" -ErrorAction SilentlyContinue
   ```

2. Mettre à jour la documentation avec les spécificités de votre environnement

3. Archiver les scripts de déploiement utilisés pour référence future

4. Configurer un système de sauvegarde pour le fichier global `custom_modes.json`

5. Mettre en place un processus de mise à jour régulière des modes personnalisés pour suivre l'évolution des modèles et des besoins

---

Ce rapport a été généré par Roo Architect pour faciliter la compréhension et l'implémentation de l'architecture des modes personnalisés Roo.
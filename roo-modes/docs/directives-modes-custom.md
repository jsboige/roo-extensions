# Directives pour la mise à jour des modes customisés

Ce document présente les directives essentielles à suivre lors de la création et de la mise à jour des modes customisés dans Roo. Ces bonnes pratiques permettent d'optimiser l'efficacité des modes, de gérer efficacement les ressources et d'assurer une expérience utilisateur cohérente.

## Table des matières

1. [Titrage numéroté arborescent pour les sous-tâches](#1-titrage-numéroté-arborescent-pour-les-sous-tâches)
2. [Utilisation de l'éventail des complexités](#2-utilisation-de-léventail-des-complexités)
3. [Gestion des fichiers volumineux](#3-gestion-des-fichiers-volumineux)
4. [Priorité aux MCPs](#4-priorité-aux-mcps)
5. [Nettoyage et commits réguliers](#5-nettoyage-et-commits-réguliers)

## 1. Titrage numéroté arborescent pour les sous-tâches

### 1.1 Principe général

Le système de titrage numéroté arborescent permet de structurer clairement les sous-tâches et de suivre leur progression de manière organisée. Chaque niveau de sous-tâche correspond à un niveau de titre dans la hiérarchie.

### 1.2 Règles d'implémentation

- Utilisez des titres Markdown avec une numérotation hiérarchique pour chaque sous-tâche
- Chaque création de sous-tâche implique de descendre d'un niveau de titre
- Maintenez la cohérence de la numérotation à travers tout le document

### 1.3 Exemples concrets

```markdown
# 1. Tâche principale
## 1.1 Première sous-tâche
### 1.1.1 Sous-tâche de niveau 3
### 1.1.2 Autre sous-tâche de niveau 3
## 1.2 Deuxième sous-tâche
### 1.2.1 Sous-tâche de niveau 3
#### 1.2.1.1 Sous-tâche de niveau 4
```

### 1.4 Avantages

- Facilite la navigation et le suivi de l'avancement
- Permet de comprendre rapidement la structure et la hiérarchie des tâches
- Simplifie la référence à des sections spécifiques dans les communications

## 2. Utilisation de l'éventail des complexités

### 2.1 Principe de base

La plupart des tâches devraient être définies initialement en mode simple, en faisant confiance aux mécanismes d'escalade pour ajuster automatiquement la complexité si nécessaire.

### 2.2 Niveaux de complexité

| Niveau | Utilisation recommandée |
|--------|-------------------------|
| Simple | Tâches de base, modifications mineures, requêtes d'information simples |
| Medium | Tâches intermédiaires nécessitant une analyse modérée |
| Complex | Problèmes complexes, architectures élaborées, débogages avancés |

### 2.3 Exemples d'utilisation par niveau

#### 2.3.1 Mode Simple

- Modifications de texte ou de documentation
- Corrections de bugs simples et isolés
- Requêtes d'information factuelle
- Ajout de fonctionnalités mineures

```json
{
  "name": "🔧 Fix Simple",
  "slug": "fix-simple",
  "description": "Correction de bugs simples et modifications mineures",
  "model": "gpt-4o",
  "temperature": 0.2,
  "complexity": "simple"
}
```

#### 2.3.2 Mode Medium

- Implémentation de fonctionnalités modérément complexes
- Refactoring de code existant
- Analyse de performance basique
- Débogages nécessitant une compréhension modérée du système

```json
{
  "name": "🔧 Fix Medium",
  "slug": "fix-medium",
  "description": "Correction de bugs modérément complexes",
  "model": "gpt-4o",
  "temperature": 0.3,
  "complexity": "medium"
}
```

#### 2.3.3 Mode Complex

- Conception d'architectures complètes
- Débogages de problèmes systémiques
- Optimisations avancées
- Intégrations complexes entre plusieurs systèmes

```json
{
  "name": "🔧 Fix Complex",
  "slug": "fix-complex",
  "description": "Résolution de problèmes complexes nécessitant une analyse approfondie",
  "model": "gpt-4o",
  "temperature": 0.4,
  "complexity": "complex"
}
```

### 2.4 Mécanismes d'escalade

Faites confiance aux mécanismes d'escalade automatique pour ajuster la complexité en fonction des besoins. Le système détectera si une tâche nécessite plus de ressources ou de capacités et passera au niveau supérieur si nécessaire.

## 3. Gestion des fichiers volumineux

### 3.1 Problématique

Les fichiers volumineux peuvent faire sauter la fenêtre de contexte et entraîner des problèmes de performance ou des réponses incomplètes.

### 3.2 Directives de gestion

#### 3.2.1 Éviter l'ouverture complète

- N'ouvrez jamais un fichier volumineux dans son intégralité
- Utilisez les paramètres `start_line` et `end_line` pour lire des sections spécifiques
- Préférez une approche progressive en lisant le fichier par morceaux

```javascript
// À ÉVITER
<read_file>
<path>chemin/vers/fichier-volumineux.js</path>
</read_file>

// RECOMMANDÉ
<read_file>
<path>chemin/vers/fichier-volumineux.js</path>
<start_line>100</start_line>
<end_line>150</end_line>
</read_file>
```

#### 3.2.2 Sous-tâches dédiées

Créez des sous-tâches spécifiques pour traiter les fichiers volumineux :

```markdown
### 2.3.1 Analyse du fichier volumineux

Cette sous-tâche est dédiée à l'analyse du fichier config.json qui contient plus de 5000 lignes.
```

#### 3.2.3 Utilisation future du MCP quickfiles

Le MCP quickfiles offrira bientôt des fonctionnalités avancées pour cartographier les fichiers volumineux :

```javascript
// Exemple futur avec MCP quickfiles
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>map_large_file</tool_name>
<arguments>
{
  "path": "chemin/vers/fichier-volumineux.js",
  "analysis_type": "structure"
}
</arguments>
</use_mcp_tool>
```

## 4. Priorité aux MCPs

### 4.1 Avantages des MCPs

Les Model Context Protocol (MCP) servers offrent des fonctionnalités optimisées qui sont souvent plus efficaces que l'utilisation directe du shell natif.

### 4.2 Problèmes évités

- Approbations de droits répétées
- Redémarrages de sessions
- Limitations de contexte
- Problèmes de performance avec les commandes shell

### 4.3 Exemples d'utilisation

#### 4.3.1 Lister des fichiers avec quickfiles

```javascript
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>list_directory_contents</tool_name>
<arguments>
{
  "paths": [
    {
      "path": "./src",
      "recursive": true,
      "file_pattern": "*.{js,ts}"
    }
  ],
  "sort_by": "modified",
  "sort_order": "desc"
}
</arguments>
</use_mcp_tool>
```

#### 4.3.2 Lire plusieurs fichiers en une seule opération

```javascript
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": [
    {
      "path": "./src/config.js",
      "excerpts": [
        {
          "start": 10,
          "end": 20
        }
      ]
    },
    "./src/utils.js"
  ],
  "show_line_numbers": true
}
</arguments>
</use_mcp_tool>
```

#### 4.3.3 Éditer plusieurs fichiers simultanément

```javascript
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>edit_multiple_files</tool_name>
<arguments>
{
  "files": [
    {
      "path": "./src/config.js",
      "diffs": [
        {
          "search": "const DEBUG = false;",
          "replace": "const DEBUG = true;",
          "start_line": 5
        }
      ]
    },
    {
      "path": "./src/utils.js",
      "diffs": [
        {
          "search": "export function log(message) {",
          "replace": "export function log(message, level = 'info') {"
        }
      ]
    }
  ]
}
</arguments>
</use_mcp_tool>
```

## 5. Nettoyage et commits réguliers

### 5.1 Nettoyage des fichiers temporaires

#### 5.1.1 Identification des fichiers temporaires

- Fichiers avec préfixes ou suffixes temporaires (tmp_, _temp, etc.)
- Fichiers de logs générés automatiquement
- Fichiers de cache ou de build qui peuvent être régénérés

#### 5.1.2 Procédure de nettoyage

```javascript
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>delete_files</tool_name>
<arguments>
{
  "paths": [
    "./tmp/generated-report.md",
    "./logs/debug.log",
    "./build/temp-output.js"
  ]
}
</arguments>
</use_mcp_tool>
```

### 5.2 Commits réguliers

#### 5.2.1 Bonnes pratiques

- Effectuez des commits après chaque étape logique complétée
- Utilisez des messages de commit descriptifs et structurés
- Groupez les modifications liées dans un même commit

#### 5.2.2 Exemple de workflow de commit

```javascript
// Vérifier l'état des modifications
<execute_command>
<command>git status</command>
</execute_command>

// Ajouter les fichiers modifiés
<execute_command>
<command>git add ./src/config.js ./src/utils.js</command>
</execute_command>

// Effectuer le commit avec un message descriptif
<execute_command>
<command>git commit -m "feat: Amélioration du système de logging avec niveaux"</command>
</execute_command>
```

#### 5.2.3 Confirmation pour les pushs

Les pushs vers des dépôts distants peuvent faire l'objet d'une confirmation explicite de l'utilisateur :

```javascript
<ask_followup_question>
<question>Souhaitez-vous que je pousse les modifications vers le dépôt distant ?</question>
<follow_up>
<suggest>Oui, veuillez pousser les modifications vers la branche principale</suggest>
<suggest>Non, je préfère vérifier les changements avant de pousser</suggest>
<suggest>Oui, mais vers une nouvelle branche feature/logging-improvements</suggest>
</follow_up>
</ask_followup_question>
```

---

En suivant ces directives, vous optimiserez l'efficacité et la maintenabilité de vos modes customisés tout en assurant une expérience utilisateur cohérente et performante.
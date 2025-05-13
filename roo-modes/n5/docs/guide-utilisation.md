# Guide d'Utilisation de l'Architecture d'Orchestration à 5 Niveaux

Ce guide explique comment utiliser efficacement l'architecture d'orchestration à 5 niveaux de complexité pour les modes Roo.

## Table des Matières

1. [Introduction](#introduction)
2. [Les 5 Niveaux de Complexité](#les-5-niveaux-de-complexité)
3. [Quand Utiliser Chaque Niveau](#quand-utiliser-chaque-niveau)
4. [Mécanismes d'Escalade](#mécanismes-descalade)
5. [Mécanismes de Désescalade](#mécanismes-de-désescalade)
6. [Utilisation Optimisée des MCPs](#utilisation-optimisée-des-mcps)
7. [Nettoyage des Fichiers Intermédiaires](#nettoyage-des-fichiers-intermédiaires)
8. [Bonnes Pratiques](#bonnes-pratiques)
9. [Résolution des Problèmes Courants](#résolution-des-problèmes-courants)

## Introduction

L'architecture d'orchestration à 5 niveaux est conçue pour optimiser l'utilisation des ressources en adaptant le niveau de complexité au type de tâche à accomplir. Cette approche permet de :

- Réduire la consommation de tokens pour les tâches simples
- Allouer plus de ressources aux tâches complexes
- Faciliter la transition entre différents niveaux de complexité
- Optimiser l'utilisation des MCPs disponibles

## Les 5 Niveaux de Complexité

### Niveau 1 : MICRO

- **Modèle de référence** : Claude 3 Haiku
- **Taille de contexte** : 20 000 tokens
- **Lignes de code** : < 50
- **Messages** : 5-10
- **Tokens** : < 10 000
- **Temps de réflexion** : Minimal

### Niveau 2 : MINI

- **Modèle de référence** : Claude 3 Sonnet
- **Taille de contexte** : 50 000 tokens
- **Lignes de code** : 50-100
- **Messages** : 8-15
- **Tokens** : 10 000-30 000
- **Temps de réflexion** : Limité

### Niveau 3 : MEDIUM

- **Modèle de référence** : Claude 3 Opus
- **Taille de contexte** : 75 000 tokens
- **Lignes de code** : 100-200
- **Messages** : 10-20
- **Tokens** : 30 000-50 000
- **Temps de réflexion** : Modéré

### Niveau 4 : LARGE

- **Modèle de référence** : Qwen 3 235B
- **Taille de contexte** : 100 000 tokens
- **Lignes de code** : 200-500
- **Messages** : 15-25
- **Tokens** : 50 000-100 000
- **Temps de réflexion** : Important

### Niveau 5 : ORACLE

- **Modèle de référence** : GPT-4o
- **Taille de contexte** : 128 000 tokens
- **Lignes de code** : > 500
- **Messages** : > 25
- **Tokens** : > 100 000
- **Temps de réflexion** : Exhaustif

## Quand Utiliser Chaque Niveau

### MICRO
- Tâches très simples et bien définies
- Modifications mineures de code (< 50 lignes)
- Questions factuelles simples
- Formatage de code ou documentation simple
- Corrections de bugs mineurs

### MINI
- Tâches simples mais nécessitant un peu plus de contexte
- Modifications de code modérées (50-100 lignes)
- Explications de concepts simples
- Documentation technique basique
- Débogage de problèmes isolés

### MEDIUM
- Tâches de complexité moyenne
- Modifications de code substantielles (100-200 lignes)
- Explications détaillées de concepts
- Documentation technique complète
- Débogage de problèmes modérément complexes

### LARGE
- Tâches complexes nécessitant une analyse approfondie
- Modifications de code importantes (200-500 lignes)
- Explications approfondies de concepts avancés
- Documentation d'architecture système
- Débogage de problèmes complexes

### ORACLE
- Tâches très complexes nécessitant une expertise avancée
- Modifications de code majeures (> 500 lignes)
- Analyses exhaustives de systèmes complexes
- Documentation d'architecture distribuée
- Débogage de problèmes critiques multi-systèmes

## Mécanismes d'Escalade

L'architecture implémente trois types d'escalade :

### 1. Escalade par Branchement (Priorité Haute)

Utilisée pour créer des sous-tâches spécifiques à traiter à un niveau supérieur.

**Format** : `[ESCALADE PAR BRANCHEMENT] Création de sous-tâche de niveau [NIVEAU] car: [RAISON]`

**Exemple** :
```
[ESCALADE PAR BRANCHEMENT] Création de sous-tâche de niveau LARGE car: Cette partie nécessite une analyse approfondie de l'architecture distribuée qui dépasse les capacités du niveau MEDIUM.
```

### 2. Escalade par Changement de Mode (Priorité Moyenne)

Utilisée pour passer à un mode de niveau supérieur pour toute la tâche.

**Format** : `[ESCALADE NIVEAU [NIVEAU]] Cette tâche nécessite le niveau [NIVEAU] car: [RAISON]`

**Exemple** :
```
[ESCALADE NIVEAU ORACLE] Cette tâche nécessite le niveau ORACLE car: La complexité du système distribué et le nombre de composants interdépendants dépassent les capacités du niveau LARGE.
```

### 3. Escalade par Terminaison (Priorité Basse)

Utilisée pour arrêter la tâche actuelle et la reprendre à un niveau supérieur.

**Format** : `[ESCALADE PAR TERMINAISON] Cette tâche doit être reprise au niveau [NIVEAU] car: [RAISON]`

**Exemple** :
```
[ESCALADE PAR TERMINAISON] Cette tâche doit être reprise au niveau MINI car: La tâche est trop simple pour le niveau MEDIUM et consomme inutilement des ressources.
```

## Mécanismes de Désescalade

La désescalade est implémentée pour optimiser l'utilisation des ressources :

**Format** : `[DÉSESCALADE SUGGÉRÉE] Cette tâche pourrait être traitée par le niveau [NIVEAU] car : [RAISON]`

**Exemple** :
```
[DÉSESCALADE SUGGÉRÉE] Cette tâche pourrait être traitée par le niveau MEDIUM car : La complexité est plus faible que prévu et ne nécessite pas les ressources du niveau LARGE.
```

## Utilisation Optimisée des MCPs

Chaque niveau est configuré pour utiliser de manière optimale les MCPs disponibles :

### Principes Généraux

1. **Priorité aux MCPs** : Privilégiez systématiquement l'utilisation des MCPs par rapport aux outils standards nécessitant une validation humaine.
2. **MCPs Spécifiques** : Utilisez les MCPs les plus adaptés à chaque tâche :
   - **quickfiles** : Pour les manipulations de fichiers multiples ou volumineux
   - **jinavigator** : Pour l'extraction d'informations de pages web
   - **searxng** : Pour effectuer des recherches web

### Utilisation par Niveau

- **MICRO** : Utilisation limitée des MCPs, principalement pour des recherches simples
- **MINI** : Utilisation basique des MCPs pour des tâches spécifiques
- **MEDIUM** : Utilisation régulière des MCPs pour optimiser les tâches courantes
- **LARGE** : Utilisation avancée des MCPs pour des tâches complexes
- **ORACLE** : Utilisation exhaustive des MCPs pour des tâches très complexes

## Nettoyage des Fichiers Intermédiaires

Une attention particulière doit être portée au nettoyage des fichiers intermédiaires :

### Processus de Nettoyage

1. **Identification** : Avant de terminer une tâche, identifiez tous les fichiers intermédiaires créés
2. **Suppression** : Supprimez-les avec les commandes appropriées (rm, Remove-Item, etc.)
3. **Vérification** : Assurez-vous que seuls les fichiers nécessaires au résultat final sont conservés
4. **Documentation** : Documentez les fichiers conservés dans le rapport final

### Types de Fichiers à Nettoyer

- Fichiers temporaires de travail
- Fichiers de logs intermédiaires
- Fichiers de données partielles
- Fichiers de configuration temporaires
- Tout autre fichier qui n'est pas nécessaire au résultat final

## Bonnes Pratiques

1. **Évaluation Initiale** : Évaluez correctement la complexité de la tâche dès le début
2. **Réévaluation Continue** : Réévaluez régulièrement la complexité pendant l'exécution
3. **Documentation** : Documentez clairement les décisions d'escalade/désescalade
4. **Optimisation des Ressources** : Utilisez le niveau le plus bas capable de traiter la tâche
5. **Nettoyage Systématique** : Nettoyez toujours les fichiers intermédiaires
6. **Utilisation des MCPs** : Maximisez l'utilisation des MCPs disponibles

## Résolution des Problèmes Courants

### Problème : Escalade Excessive

**Symptômes** : Trop d'escalades vers des niveaux supérieurs pour des tâches simples.

**Solution** : Réévaluez les critères d'escalade et assurez-vous qu'ils sont bien calibrés.

### Problème : Désescalade Insuffisante

**Symptômes** : Les tâches restent à des niveaux élevés même lorsqu'elles deviennent plus simples.

**Solution** : Implémentez une réévaluation systématique de la complexité à des points clés de la tâche.

### Problème : Fichiers Intermédiaires Non Nettoyés

**Symptômes** : Accumulation de fichiers temporaires et intermédiaires.

**Solution** : Implémentez une liste de vérification de nettoyage à la fin de chaque tâche.

### Problème : Utilisation Sous-Optimale des MCPs

**Symptômes** : Utilisation excessive d'outils standards nécessitant une validation humaine.

**Solution** : Formez les utilisateurs sur les capacités des MCPs disponibles et leur utilisation optimale.
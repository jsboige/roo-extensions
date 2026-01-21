# Guide d'Installation et de Configuration de Roo Scheduler

## Introduction

Roo Scheduler est une extension VS Code qui permet d'automatiser des tâches récurrentes et des flux de travail directement dans votre environnement de développement. Cette extension s'intègre parfaitement avec Roo Code pour vous permettre de planifier et d'exécuter des tâches automatisées selon différents critères temporels ou basés sur l'activité.

## 1. Installation de Roo Scheduler dans VS Code

### Prérequis
- Visual Studio Code installé sur votre ordinateur
- Extension Roo Code déjà installée (Roo Scheduler s'intègre avec Roo Code)

### Étapes d'installation

1. **Ouvrir VS Code**
   - Lancez Visual Studio Code sur votre ordinateur

2. **Accéder au Marketplace des extensions**
   - Cliquez sur l'icône des extensions dans la barre latérale (ou utilisez le raccourci `Ctrl+Shift+X` / `Cmd+Shift+X`)
   - Recherchez "Roo Scheduler" dans la barre de recherche

3. **Installer l'extension**
   - Localisez l'extension "Roo Scheduler" développée par Kyle Hoskins
   - Cliquez sur le bouton "Installer"
   - Attendez que l'installation soit terminée

4. **Redémarrer VS Code (si nécessaire)**
   - Si demandé, redémarrez VS Code pour activer l'extension

5. **Vérifier l'installation**
   - Après le redémarrage, vous devriez voir l'icône de Roo Scheduler dans la barre latérale ou dans le menu de Roo Code

## 2. Création et Configuration d'une Tâche Planifiée Simple

### Accéder à l'interface de Roo Scheduler

1. Cliquez sur l'icône de Roo Scheduler dans la barre latérale ou accédez-y via le menu de Roo Code
2. Cliquez sur le bouton "Create New Schedule" pour créer une nouvelle tâche planifiée

### Configurer une tâche simple

1. **Remplir les informations de base**
   - **Nom** : Donnez un nom descriptif à votre tâche (ex: "Update e2e Tests")
   - **Prompt** : Décrivez ce que la tâche doit faire en langage naturel (ex: "Run the e2e tests and fix any errors that remain")

2. **Définir la fréquence d'exécution**
   - **Every** : Spécifiez l'intervalle d'exécution (1, 2, 3, etc.)
   - **Days** : Choisissez l'unité de temps (minutes, heures, jours)

3. **Options de planification avancées (facultatif)**
   - **Run on certain days of the week** : Cochez cette option pour exécuter la tâche uniquement certains jours de la semaine
   - **Use a specific start date** : Définissez une date et heure précises pour commencer l'exécution
   - **Use an expiration date** : Définissez une date après laquelle la tâche ne s'exécutera plus

4. **Options d'exécution basées sur l'activité (facultatif)**
   - **Only execute if I have activity since the last execution of this schedule** : Cochez cette option pour que la tâche ne s'exécute que si vous avez été actif depuis la dernière exécution

5. **Enregistrer la tâche**
   - Cliquez sur le bouton "Save" ou "Create" pour enregistrer votre tâche planifiée

## 3. Exemple Concret : Planifier une Tâche de Revue de Code

Voici un exemple pratique de configuration d'une tâche de revue de code automatisée avec Roo Scheduler :

### Étape 1 : Créer une nouvelle tâche planifiée
- Cliquez sur "Create New Schedule"

### Étape 2 : Configurer les détails de la tâche
- **Nom** : "Code Review"
- **Prompt** : "Review any unreviewed or unfinished code in the current project. Look for potential bugs, performance issues, and suggest improvements. Focus on files modified in the last 3 days."

### Étape 3 : Définir la fréquence
- **Every** : 1
- **Days** : Day

### Étape 4 : Configurer les options avancées
- Cochez "Run on certain days of the week"
- Sélectionnez "Monday", "Wednesday", et "Friday" pour effectuer des revues de code trois fois par semaine
- Cochez "Only execute if I have activity since the last execution" pour éviter les revues inutiles

### Étape 5 : Enregistrer la tâche
- Cliquez sur "Save" pour créer la tâche planifiée

### Résultat
Roo exécutera automatiquement une revue de code les lundis, mercredis et vendredis, à condition que vous ayez été actif depuis la dernière exécution. Roo analysera le code, identifiera les problèmes potentiels et suggérera des améliorations, en se concentrant sur les fichiers modifiés récemment.

## 4. Gestion et Surveillance des Tâches Planifiées

### Visualiser les tâches planifiées
- Ouvrez l'interface de Roo Scheduler
- Toutes vos tâches planifiées sont listées avec leur statut actuel (Active, Inactive)
- Vous pouvez voir la dernière exécution et la prochaine exécution prévue pour chaque tâche

### Modifier une tâche existante
1. Dans la liste des tâches, cliquez sur l'icône de modification (crayon) à côté de la tâche que vous souhaitez modifier
2. Effectuez vos modifications dans le formulaire
3. Cliquez sur "Save" pour enregistrer les modifications

### Activer/Désactiver une tâche
- Chaque tâche affiche un indicateur de statut (Active/Inactive)
- Vous pouvez activer ou désactiver une tâche en cliquant sur cet indicateur ou via les options de modification

### Supprimer une tâche
- Cliquez sur l'icône de suppression (corbeille) à côté de la tâche que vous souhaitez supprimer
- Confirmez la suppression lorsque demandé

### Surveiller l'exécution des tâches
- Roo Scheduler affiche les informations sur la dernière exécution de chaque tâche
- Vous pouvez voir quand la tâche a été exécutée pour la dernière fois
- Vous pouvez également voir quand la prochaine exécution est prévue

### Comportement d'exécution à noter
- Roo Scheduler n'allumera pas votre ordinateur pour exécuter une tâche
- Les tâches s'exécuteront si l'écran est verrouillé
- Lorsque VS Code "se réveille" (au démarrage de l'ordinateur ou lorsqu'un autre processus en arrière-plan est exécuté), toutes les tâches en attente seront exécutées
- Les intervalles sont calculés différemment selon qu'une date/heure de début est spécifiée ou non

## Conclusion

Roo Scheduler est un outil puissant pour automatiser des tâches récurrentes dans votre flux de travail de développement. En suivant ce guide, vous pouvez facilement installer l'extension, configurer des tâches planifiées, et gérer efficacement vos automatisations.

L'extension offre une grande flexibilité dans la planification des tâches, avec des options pour l'exécution basée sur le temps ou l'activité, et s'intègre parfaitement avec Roo Code pour exécuter des instructions en langage naturel.

Utilisez Roo Scheduler pour automatiser des revues de code, maintenir la documentation à jour, vérifier les dépendances, analyser votre base de code, et bien plus encore, afin d'améliorer votre productivité et la qualité de votre code.
# Guide de déploiement du MCP Quickfiles

Ce document explique comment compiler et déployer les nouvelles fonctionnalités du serveur MCP Quickfiles.

## Prérequis

- Node.js (version 14 ou supérieure)
- NPM (généralement installé avec Node.js)
- TypeScript (`npm install -g typescript`)

## Structure du projet

Le projet MCP Quickfiles est organisé comme suit :

- `src/` : Contient les fichiers source TypeScript
  - `index.ts` : Point d'entrée principal du serveur MCP
- `build/` : Contient les fichiers JavaScript compilés
- `__tests__/` : Contient les tests unitaires et d'intégration
- `tsconfig.json` : Configuration TypeScript
- `package.json` : Configuration du projet et dépendances

## Processus de compilation

Le processus de compilation convertit les fichiers TypeScript (`.ts`) en fichiers JavaScript (`.js`) qui peuvent être exécutés par Node.js. Ce processus est géré par le compilateur TypeScript (`tsc`).

### Étapes de compilation manuelle

1. Nettoyer le répertoire de build existant
2. Compiler les fichiers TypeScript avec `tsc`
3. Vérifier que les fichiers ont été correctement générés
4. Redémarrer le serveur MCP pour appliquer les changements

## Scripts de déploiement

Deux scripts de déploiement sont fournis pour automatiser ce processus :

### Script Batch (Windows)

Le fichier `compile-deploy.bat` est un script batch Windows qui :

1. Nettoie le répertoire de build
2. Compile le code TypeScript
3. Vérifie les fichiers générés
4. Redémarre le serveur MCP

Pour l'utiliser :

```cmd
compile-deploy.bat
```

### Script PowerShell (Windows)

Le fichier `compile-deploy.ps1` est un script PowerShell plus avancé qui offre des options supplémentaires :

```powershell
# Compilation standard avec redémarrage du serveur
.\compile-deploy.ps1

# Compilation sans redémarrer le serveur
.\compile-deploy.ps1 -NoRestart

# Compilation en mode surveillance (recompile automatiquement à chaque modification)
.\compile-deploy.ps1 -WatchMode

# Compilation avec affichage détaillé
.\compile-deploy.ps1 -Verbose
```

Options disponibles :
- `-NoRestart` : Compile le code sans redémarrer le serveur MCP
- `-WatchMode` : Active le mode surveillance qui recompile automatiquement à chaque modification
- `-Verbose` : Affiche des informations supplémentaires pendant le processus de compilation

## Vérification du déploiement

Pour vérifier que les nouvelles fonctionnalités ont été correctement déployées :

1. Exécutez l'un des scripts de déploiement
2. Vérifiez qu'aucune erreur n'est signalée pendant la compilation
3. Connectez-vous au serveur MCP depuis Roo
4. Vérifiez que les nouveaux outils sont disponibles dans la liste des outils MCP

## Résolution des problèmes courants

### Erreur : "Le fichier tsconfig.json n'a pas été trouvé"

Assurez-vous d'exécuter le script depuis le répertoire racine du projet MCP Quickfiles.

### Erreur : "Node.js et NPM sont requis pour exécuter ce script"

Installez Node.js depuis https://nodejs.org/ et assurez-vous qu'il est correctement ajouté à votre PATH.

### Erreur lors de la compilation TypeScript

Vérifiez les erreurs de syntaxe dans les fichiers source TypeScript et corrigez-les avant de relancer la compilation.

### Le serveur MCP ne démarre pas

Vérifiez que le port utilisé par le serveur MCP n'est pas déjà occupé par un autre processus.

## Maintenance continue

Pour maintenir le serveur MCP Quickfiles à jour :

1. Mettez à jour régulièrement les dépendances dans `package.json`
2. Exécutez `npm update` pour installer les dernières versions des dépendances
3. Recompilez et redéployez le serveur après chaque mise à jour

## Nouveaux outils disponibles

Après le déploiement, les outils suivants seront disponibles dans le serveur MCP Quickfiles :

1. `read_multiple_files` : Lit plusieurs fichiers en une seule requête
2. `list_directory_contents` : Liste le contenu des répertoires avec options de filtrage et de tri
3. `delete_files` : Supprime une liste de fichiers
4. `edit_multiple_files` : Édite plusieurs fichiers en appliquant des diffs
5. `extract_markdown_structure` : Analyse les fichiers markdown et extrait les titres
6. `search_in_files` : Recherche des motifs dans plusieurs fichiers
7. `search_and_replace` : Recherche et remplace du texte dans plusieurs fichiers
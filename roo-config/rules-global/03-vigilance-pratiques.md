# Vigilance et Bonnes Pratiques

## Avant de creer

Avant de creer un fichier ou un repertoire, verifier si un equivalent n'existe pas deja et s'il contient deja ce que tu veux creer ou une partie.

## Commits propres

Verifie toujours l'ensemble des fichiers que tu commites :
- Deplacer les fichiers qui doivent etre ranges
- Supprimer les fichiers de log qui n'ont pas a etre commites
- Modifier les chemins dans les scripts qui les ont produit
- En dernier ressort, mettre a jour le gitignore

## Operations destructives

Fais extremement attention avec les operations susceptibles d'effacer des choses ou de revenir en arriere :
- N'oublie pas tes stashs ou ta branche
- Pas de `git reset` ou `git restore` sans validation complete et autorisation de l'utilisateur
- Prends toujours le temps de tout verifier

## Ecriture INTERCOM

Le fichier INTERCOM (`.claude/local/INTERCOM-{MACHINE}.md`) est en **ordre chronologique** (ancien en haut, recent en bas).

**REGLE ABSOLUE : Toujours ajouter les nouveaux messages A LA FIN du fichier.**

Procedure :
1. Lire le fichier entier avec `read_file`
2. Reecrire le fichier complet avec `write_to_file` en ajoutant le nouveau message **APRES** tout le contenu existant
3. Ne JAMAIS inserer en haut, ne JAMAIS supprimer les messages existants

## Submodules Git

Le dossier `mcps/internal/` est un **submodule Git**. Un submodule est normalement en **detached HEAD** (pointe sur un commit specifique, pas une branche).

Regles strictes :
- **Ne JAMAIS faire `git checkout`** dans un submodule sans verification prealable
- **Ne JAMAIS faire `git pull`** dans un submodule (le parent gere la version)
- Le detached HEAD est l'etat NORMAL, ne pas essayer de le "corriger"
- Pour mettre a jour un submodule : `git submodule update --init` depuis le depot parent
- Si le submodule montre des changements : verifier avec `git submodule status` depuis le parent

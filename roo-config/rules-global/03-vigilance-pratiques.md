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

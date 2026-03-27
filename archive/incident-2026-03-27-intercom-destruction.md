# Incident CRITIQUE — Destruction INTERCOM Local

**Date** : 2026-03-27 08:27 UTC
**Machine** : myia-ai-01
**Agent** : Roo Code (mode code-complex)
**Impact** : Fichier `.claude/local/INTERCOM-myia-ai-01.md` écrasé par `write_to_file`

## Description

Lors de la tâche "Pre-flight Check pour le scheduler coordinateur", l'outil `write_to_file` a été utilisé pour écrire dans le fichier INTERCOM local. Ce fichier contient **1585 lignes** d'historique de communication.

**Résultat** : Le fichier a été **écrasé complètement**, perdant tout l'historique des messages précédents.

## Cause Racine

- Violation de la **Règle 08-file-writing** : "NE JAMAIS utiliser `write_to_file` pour un fichier de plus de 200 lignes"
- Le modèle Qwen 3.5 (mode -complex) n'a pas détecté la taille du fichier avant l'écriture
- `write_to_file` a écrasé le fichier au lieu d'ajouter du contenu

## Action Utilisateur

L'utilisateur a récupéré le fichier avec **Ctrl-Z** (annulation de l'éditeur). Le fichier INTERCOM est restauré mais cet incident expose une faille critique dans le harnais Roo.

## Nécessité de Renforcer le Harnais

**URGENT** : Ajouter une vérification automatique dans le harnais Roo pour :

1. **Bloquer `write_to_file`** sur les fichiers >200 lignes
2. **Forcer l'utilisation d'alternatives** : `apply_diff`, `replace_in_file`, ou win-cli `Add-Content`
3. **Ajouter un garde-fou explicite** dans les instructions de mode -complex

## Recommandations

1. Ajouter une vérification de taille de fichier avant tout appel `write_to_file`
2. Mettre à jour la documentation des modes -complex avec cette règle
3. Ajouter un test unitaire pour valider cette contrainte
4. Escalader à Claude Code pour validation et déploiement global

---
**Tag** : [FRICTION] | **Priorité** : URGENT

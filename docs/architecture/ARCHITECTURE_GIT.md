# Architecture de Configuration Git Multi-Profils

Ce document décrit la stratégie mise en place pour gérer plusieurs identités Git (nom et email) sur la même machine, en particulier lors de l'utilisation des outils MCP (Model Context Protocol).

## 1. Contexte et Objectif

L'objectif est de pouvoir utiliser automatiquement une identité Git différente en fonction du projet sur lequel on travaille. Par exemple, une identité pour les projets personnels et une autre pour les projets professionnels ou universitaires.

Le défi principal était d'assurer que les commits effectués via les MCPs Roo utilisent la bonne identité, car l'environnement d'exécution des MCPs est isolé et ne lit pas toujours la configuration Git locale (`.git/config`) ou conditionnelle (`includeIf`).

## 2. Stratégie de Configuration

La stratégie repose sur une configuration manuelle par dépôt via un outil MCP dédié.

1.  **Fichier de configuration global (`~/.gitconfig`)**: Ce fichier contient l'identité Git par défaut (par exemple, "Roo"). Cette identité sera utilisée pour les opérations Git en dehors des dépôts configurés spécifiquement.

2.  **Configuration par dépôt via MCP**: Pour qu'un MCP utilise une identité spécifique pour un projet, il est nécessaire de la configurer explicitement à l'intérieur du dépôt à l'aide de l'outil `git_config` du MCP `git`.

### 2.1. Fichier `.gitconfig` Global

Le fichier `~/.gitconfig` contient une configuration utilisateur par défaut.

```ini
[user]
	email = roo@example.com
	name = Roo
[core]
	editor = code --wait
```

## 3. Utilisation et Compatibilité avec les MCPs Roo

Pour garantir que les MCPs `git` et `github` utilisent la bonne identité pour un projet donné, il faut suivre la procédure suivante :

1.  **Naviguer vers le répertoire du projet**.
2.  **Configurer l'identité pour le dépôt** en utilisant l'outil `git_config` du MCP `git`. Cette opération n'a besoin d'être effectuée qu'une seule fois par dépôt.

    Exemple d'appel de l'outil pour un profil personnel :
    ```json
    {
      "tool": "git_config",
      "repo_path": "C:/Users/MYIA/work/jsboige/test-perso-mcp-2/",
      "name": "user.name",
      "value": "jsboige"
    }
    ```
    ```json
    {
      "tool": "git_config",
      "repo_path": "C:/Users/MYIA/work/jsboige/test-perso-mcp-2/",
      "name": "user.email",
      "value": "jsboige@gmail.com"
    }
    ```
Cette configuration est écrite dans le fichier `.git/config` du dépôt et sera utilisée en priorité par le MCP `git` pour toutes les opérations futures (comme `git_commit`).

## 4. Validation et Tests

La configuration est validée en effectuant les étapes suivantes :
1.  Utiliser `git_config` comme décrit ci-dessus.
2.  Effectuer un commit en utilisant l'outil `git_commit` du MCP.
3.  Vérifier l'auteur du dernier commit en utilisant l'outil `git_log` du MCP. L'auteur doit correspondre à l'identité configurée.

Cette solution est considérée comme complète et fonctionnelle pour tous les cas d'usage prévus avec les MCPs.
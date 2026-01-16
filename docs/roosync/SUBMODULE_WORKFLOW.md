# Submodule Workflow Guide

## Overview

Ce document décrit le workflow correct pour travailler avec les submodules Git dans le projet **roo-extensions**. Les submodules sont des dépôts Git imbriqués dans le dépôt principal, nécessitant une gestion rigoureuse pour éviter les erreurs de synchronisation.

## Submodules existants

Le projet roo-extensions contient les submodules suivants :

| Submodule | Chemin | URL | Branche |
|-----------|--------|-----|---------|
| roo-code | `roo-code` | https://github.com/jsboige/Roo-Code.git | (défaut) |
| win-cli | `mcps/external/win-cli/server` | https://github.com/jsboige/win-cli-mcp-server.git | main |
| mcps/internal | `mcps/internal` | https://github.com/jsboige/jsboige-mcp-servers.git | main |
| modelcontextprotocol-servers | `mcps/forked/modelcontextprotocol-servers` | https://github.com/jsboige/modelcontextprotocol-servers | (défaut) |
| mcp-server-ftp | `mcps/external/mcp-server-ftp` | https://github.com/alxspiker/mcp-server-ftp | (défaut) |
| markitdown | `mcps/external/markitdown/source` | https://github.com/microsoft/markitdown.git | (défaut) |
| playwright | `mcps/external/playwright/source` | https://github.com/microsoft/playwright-mcp.git | (défaut) |
| Office-PowerPoint-MCP-Server | `mcps/external/Office-PowerPoint-MCP-Server` | https://github.com/jsboige/Office-PowerPoint-MCP-Server.git | (défaut) |

## Concepts clés

### Submodule
Un dépôt Git imbriqué dans un autre dépôt. Chaque submodule a son propre historique Git indépendant.

### Detached HEAD
État Git où HEAD pointe sur un commit spécifique plutôt qu'une branche. C'est l'état par défaut des submodules après un `git submodule update`. Il est recommandé de se placer sur une branche (généralement `main`) avant de travailler.

### Référence de submodule
Le dépôt principal ne stocke pas le contenu des submodules, mais seulement une référence (SHA) vers un commit spécifique de chaque submodule.

## Workflow pour travailler dans un submodule

### Étape 1 : Se placer dans le submodule

```bash
cd mcps/internal/servers/roo-state-manager
```

### Étape 2 : Vérifier l'état

```bash
git status
```

**Important :** Si vous êtes en état "Detached HEAD", basculez sur la branche principale :

```bash
git checkout main
```

### Étape 3 : Mettre à jour depuis le distant

```bash
git pull origin main
```

### Étape 4 : Effectuer les modifications

Travaillez normalement dans le submodule comme dans n'importe quel dépôt Git.

### Étape 5 : Commiter les modifications

```bash
git add .
git commit -m "feat: description des modifications"
```

### Étape 6 : Pusher vers le distant

```bash
git push origin main
```

## Workflow pour mettre à jour un submodule dans le repo principal

Une fois les modifications pushées dans le submodule, vous devez mettre à jour la référence dans le dépôt principal.

### Étape 1 : Revenir à la racine du repo principal

```bash
cd /c/dev/roo-extensions
```

### Étape 2 : Vérifier l'état des submodules

```bash
git submodule status
```

Les submodules modifiés apparaîtront avec un `+` devant leur SHA.

### Étape 3 : Ajouter la référence du submodule

```bash
git add mcps/internal/servers/roo-state-manager
```

### Étape 4 : Committer la mise à jour

```bash
git commit -m "chore: Update submodule roo-state-manager to latest commit"
```

### Étape 5 : Pusher vers le distant

```bash
git push origin main
```

## Workflow complet (Submodule + Repo principal)

Voici le workflow complet en une seule séquence :

```bash
# 1. Dans le submodule
cd mcps/internal/servers/roo-state-manager
git checkout main
git pull origin main
# ... effectuer les modifications ...
git add .
git commit -m "feat: description"
git push origin main

# 2. Dans le repo principal
cd /c/dev/roo-extensions
git add mcps/internal/servers/roo-state-manager
git commit -m "chore: Update submodule roo-state-manager"
git push origin main
```

## Commandes utiles

### Vérifier l'état des submodules

```bash
git submodule status
```

**Interprétation :**
- ` ` (espace) : submodule à jour
- `+` : submodule modifié localement (nouveau commit)
- `-` : submodule non initialisé
- `U` : submodule en conflit

### Mettre à jour tous les submodules

```bash
git submodule update --init --recursive
```

### Mettre à jour un submodule spécifique

```bash
git submodule update --remote mcps/internal
```

### Exécuter une commande dans tous les submodules

```bash
git submodule foreach 'git status'
git submodule foreach 'git pull origin main'
```

### Voir les différences dans un submodule

```bash
git diff mcps/internal/servers/roo-state-manager
```

## Erreurs courantes à éviter

### ❌ Erreur 1 : Ne pas cd vers le bon répertoire

**Problème :** Exécuter des commandes git dans le mauvais répertoire.

```bash
# ❌ MAUVAIS - Dans le repo principal
git add .
git commit -m "feat: modification dans le submodule"

# ✅ BON - Dans le submodule
cd mcps/internal/servers/roo-state-manager
git add .
git commit -m "feat: modification"
```

### ❌ Erreur 2 : Oublier de mettre à jour le submodule dans le repo principal

**Problème :** Committer dans le submodule mais oublier de mettre à jour la référence dans le repo principal.

```bash
# ❌ MAUVAIS - Seulement dans le submodule
cd mcps/internal/servers/roo-state-manager
git add . && git commit -m "feat: modification" && git push
# STOP - Il faut aussi mettre à jour le repo principal !

# ✅ BON - Complet
cd mcps/internal/servers/roo-state-manager
git add . && git commit -m "feat: modification" && git push
cd /c/dev/roo-extensions
git add mcps/internal/servers/roo-state-manager
git commit -m "chore: Update submodule" && git push
```

### ❌ Erreur 3 : Travailler en Detached HEAD

**Problème :** Faire des modifications alors que HEAD est détaché.

```bash
# ❌ MAUVAIS - En Detached HEAD
cd mcps/internal/servers/roo-state-manager
git status  # "HEAD detached at abc1234"
git add . && git commit -m "feat: modification"
# Les modifications sont sur un commit orphelin !

# ✅ BON - Sur une branche
cd mcps/internal/servers/roo-state-manager
git checkout main
git add . && git commit -m "feat: modification"
```

### ❌ Erreur 4 : Oublier de puller avant de travailler

**Problème :** Travailler sur une version obsolète du submodule.

```bash
# ❌ MAUVAIS - Sans pull
cd mcps/internal/servers/roo-state-manager
git checkout main
# ... modifications ...
git add . && git commit -m "feat: modification"
git push  # Conflit probable !

# ✅ BON - Avec pull
cd mcps/internal/servers/roo-state-manager
git checkout main
git pull origin main
# ... modifications ...
git add . && git commit -m "feat: modification"
git push
```

### ❌ Erreur 5 : Confondre submodule et répertoire normal

**Problème :** Traiter un submodule comme un répertoire normal.

```bash
# ❌ MAUVAIS - Essayer de modifier directement
cd mcps/internal/servers/roo-state-manager
echo "test" > fichier.txt
cd /c/dev/roo-extensions
git add mcps/internal/servers/roo-state-manager/fichier.txt
# Erreur : le submodule n'est pas suivi comme un répertoire normal

# ✅ BON - Committer dans le submodule
cd mcps/internal/servers/roo-state-manager
echo "test" > fichier.txt
git add fichier.txt
git commit -m "feat: add fichier"
git push
cd /c/dev/roo-extensions
git add mcps/internal/servers/roo-state-manager
git commit -m "chore: Update submodule"
```

## Dépannage

### Problème : "fatal: remote error: upload-pack: not our ref ..."

**Cause :** Le projet principal fait référence à un commit d'un submodule qui n'existe pas sur le dépôt distant.

**Solution :**

```bash
# 1. Se placer sur la branche 'main' du submodule
git -C mcps/internal/servers/roo-state-manager checkout main
git -C mcps/internal/servers/roo-state-manager pull

# 2. Informer le projet principal du changement
git add mcps/internal/servers/roo-state-manager

# 3. Committer la correction
git commit -m "fix(submodule): Align roo-state-manager to latest commit"

# 4. Relancer la mise à jour globale
git submodule update --init --recursive
```

### Problème : Conflit lors du push

**Symptômes :**
- "rejected - fetch first"
- "Updates were rejected"

**Solution :**

```bash
git pull --rebase
```

### Problème : Submodule en conflit

**Symptômes :** Un submodule reste dans un état de conflit après une mise à jour interrompue.

**Solution :**

```bash
# 1. Aller dans le submodule en conflit
cd mcps/internal/servers/roo-state-manager

# 2. Vérifier le statut
git status

# 3. Résoudre les conflits (choisir la version distante)
git checkout --theirs chemin/vers/fichier/en/conflit

# 4. Marquer comme résolu
git add chemin/vers/fichier/en/conflit

# 5. Continuer l'opération
git rebase --continue

# 6. Revenir au repo principal
cd /c/dev/roo-extensions
git submodule update --init --recursive
```

## Bonnes pratiques

### ✅ Toujours vérifier l'état avant de travailler

```bash
git status
git submodule status
```

### ✅ Toujours se placer sur une branche dans un submodule

```bash
cd mcps/internal/servers/roo-state-manager
git checkout main
```

### ✅ Toujours puller avant de modifier

```bash
git pull origin main
```

### ✅ Toujours mettre à jour le repo principal après un commit de submodule

```bash
cd /c/dev/roo-extensions
git add mcps/internal/servers/roo-state-manager
git commit -m "chore: Update submodule"
```

### ✅ Utiliser des messages de commit clairs

```bash
# Dans le submodule
git commit -m "feat: add new feature"

# Dans le repo principal
git commit -m "chore: Update submodule roo-state-manager to abc1234"
```

### ✅ Valider l'état final

```bash
git status
git submodule status
```

## Références

- [Guide de synchronisation des submodules](../guides/guide-synchronisation-submodules.md)
- [Glossaire RooSync](./GLOSSAIRE.md)
- [Troubleshooting RooSync](./TROUBLESHOOTING.md)
- [Documentation Git officielle sur les submodules](https://git-scm.com/book/fr/v2/Utilitaires-Git-Submodules)

---

**Dernière mise à jour :** 2025-01-16  
**Version :** 1.0.0

# Guide de Synchronisation du Dépôt et de ses Sous-modules

Ce guide fournit une procédure fiable pour cloner ou mettre à jour ce dépôt, en particulier pour gérer la complexité de ses nombreux sous-modules Git.

## Prérequis

- Git doit être installé et configuré sur votre machine.

## Procédure de Synchronisation Complète

Cette procédure est la méthode la plus robuste pour obtenir une copie propre et à jour du projet.

**1. Clonez le dépôt principal :**

Si vous n'avez pas encore le projet, commencez par le cloner.

```bash
git clone <URL_DU_DEPOT_PRINCIPAL>
cd <NOM_DU_DEPOT>
```

**2. Mettez à jour le dépôt principal :**

Si vous avez déjà le projet, assurez-vous d'être sur la branche principale et d'avoir les derniers changements.

```bash
git checkout main
git pull --rebase
```

**3. Synchronisez les sous-modules (la commande clé) :**

Cette commande va initialiser, récupérer et mettre à jour tous les sous-modules pour qu'ils correspondent aux versions attendues par le projet principal.

```bash
git submodule update --init --recursive
```

À ce stade, si aucune erreur n'apparaît, votre projet est prêt.

## Dépannage des Erreurs Courantes

Si la commande `git submodule update` échoue, voici comment résoudre les problèmes les plus fréquents.

### Erreur : `fatal: remote error: upload-pack: not our ref ...`

Cette erreur signifie que le projet principal fait référence à un commit d'un sous-module qui n'existe pas sur le dépôt distant de ce dernier.

**Solution :**
Vous devez forcer la mise à jour du sous-module défaillant vers le dernier commit de sa branche `main` et enregistrer ce changement.

Remplacez `chemin/vers/submodule/defectueux` par le chemin indiqué dans le message d'erreur (par exemple, `roo-code` ou `mcps/external/Office-PowerPoint-MCP-Server`).

```bash
# 1. Se placer sur la branche 'main' du submodule et tirer les changements
git -C chemin/vers/submodule/defectueux checkout main
git -C chemin/vers/submodule/defectueux pull

# 2. Informer le projet principal du changement de référence
git add chemin/vers/submodule/defectueux

# 3. Créer un commit pour corriger la référence
git commit -m "fix(submodule): Align [nom_du_submodule] to latest commit"

# 4. Relancer la mise à jour globale qui devrait maintenant réussir
git submodule update --init --recursive
```

### Erreur : Conflit de fusion ou de `rebase` dans un sous-module

Si une mise à jour est interrompue, un sous-module peut rester dans un état de conflit.

**Solution :**
Vous devez résoudre le conflit à l'intérieur du sous-module.

```bash
# 1. Allez dans le répertoire du sous-module en conflit
cd chemin/vers/submodule/en/conflit

# 2. Vérifiez son statut pour voir les fichiers en conflit
git status

# 3. Pour chaque fichier en conflit, choisissez la version à conserver.
# Pour accepter la version distante (la plus courante lors d'un pull) :
git checkout --theirs chemin/relatif/vers/fichier/en/conflit

# 4. Marquez le conflit comme résolu
git add chemin/relatif/vers/fichier/en/conflit

# 5. Continuez ou finalisez l'opération Git qui était en pause
git rebase --continue
# (ou 'git merge --continue', selon l'opération initiale)

# 6. Revenez au répertoire principal et finalisez la synchronisation
cd ../../..
git submodule update --init --recursive
```

## Validation Finale

Après avoir exécuté ces commandes, lancez une dernière fois `git status`. La sortie devrait indiquer : `working tree clean`. Cela confirme que votre projet et tous ses sous-modules sont propres et synchronisés.
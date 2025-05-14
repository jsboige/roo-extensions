# Configuration du sous-dépôt Win-CLI MCP Server

Ce document explique comment le serveur Win-CLI MCP est configuré comme sous-dépôt Git (submodule) dans le projet roo-extensions.

## Structure du sous-dépôt

Le serveur Win-CLI MCP est configuré comme un sous-dépôt Git dans le répertoire suivant :
```
external-mcps/win-cli/server/
```

Ce sous-dépôt est un fork du dépôt original [SimonB97/win-cli-mcp-server](https://github.com/SimonB97/win-cli-mcp-server), hébergé à l'adresse [jsboige/win-cli-mcp-server](https://github.com/jsboige/win-cli-mcp-server).

## Modifications apportées

Le fork contient les modifications suivantes par rapport au dépôt original :

1. Correction d'un bug dans la fonction `mergeConfigs` (fichier `src/utils/config.ts`) pour préserver les configurations de sécurité par défaut lors de la fusion avec des configurations utilisateur partielles.

## Maintenance du sous-dépôt

### Mise à jour depuis le dépôt original

Pour mettre à jour le sous-dépôt avec les dernières modifications du dépôt original, suivez ces étapes :

1. Accédez au répertoire du sous-dépôt :
   ```
   cd external-mcps/win-cli/server
   ```

2. Ajoutez le dépôt original comme remote (si ce n'est pas déjà fait) :
   ```
   git remote add upstream https://github.com/SimonB97/win-cli-mcp-server
   ```

3. Récupérez les dernières modifications du dépôt original :
   ```
   git fetch upstream
   ```

4. Fusionnez les modifications dans votre branche locale :
   ```
   git merge upstream/main
   ```

5. Résolvez les conflits éventuels et commitez les modifications.

6. Poussez les modifications vers votre fork :
   ```
   git push origin main
   ```

### Mise à jour du sous-dépôt dans le projet principal

Après avoir mis à jour le sous-dépôt, vous devez également mettre à jour la référence dans le projet principal :

1. Revenez au répertoire principal :
   ```
   cd ../../..
   ```

2. Commitez la nouvelle référence du sous-dépôt :
   ```
   git add external-mcps/win-cli/server
   git commit -m "chore: mise à jour du sous-dépôt win-cli-mcp-server"
   ```

3. Poussez les modifications vers le dépôt principal :
   ```
   git push
   ```

## Contribution au dépôt original

Pour contribuer vos modifications au dépôt original, suivez ces étapes :

1. Assurez-vous que vos modifications sont commitées et poussées vers votre fork.

2. Créez une Pull Request depuis votre fork vers le dépôt original sur GitHub :
   - Accédez à [votre fork sur GitHub](https://github.com/jsboige/win-cli-mcp-server)
   - Cliquez sur "Pull requests" puis sur "New pull request"
   - Sélectionnez le dépôt original comme base et votre fork comme head
   - Cliquez sur "Create pull request"
   - Fournissez une description détaillée de vos modifications
   - Soumettez la Pull Request

3. Attendez que le mainteneur du dépôt original examine et intègre vos modifications.

## Clonage du projet avec sous-dépôts

Pour cloner le projet principal avec tous ses sous-dépôts, utilisez la commande suivante :

```
git clone --recurse-submodules https://github.com/votre-utilisateur/roo-extensions.git
```

Si vous avez déjà cloné le projet sans les sous-dépôts, vous pouvez les initialiser et les mettre à jour avec :

```
git submodule update --init --recursive
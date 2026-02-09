# Configuration des opérateurs bloqués dans Win-CLI MCP

## Problématique

Le serveur MCP Win-CLI bloque par défaut certains opérateurs dans les shells pour des raisons de sécurité. Ces opérateurs sont :
- `&` (exécution de commandes multiples)
- `|` (redirection de sortie)
- `;` (séparation de commandes)
- `` ` `` (caractère d'échappement PowerShell)

Cette restriction peut limiter l'utilisation de commandes complexes, notamment celles qui utilisent des pipelines ou des commandes multiples.

## Solution

Pour relâcher ces restrictions, vous devez modifier le fichier de configuration du serveur Win-CLI.

### Emplacement du fichier de configuration

Le fichier de configuration se trouve à l'emplacement suivant :
- Windows: `%USERPROFILE%\.win-cli-server\config.json`

Par exemple: `C:\Users\votre-nom\.win-cli-server\config.json`

### Création du fichier de configuration

Si le fichier n'existe pas, vous pouvez le créer avec la commande suivante :

```powershell
# Créer le répertoire si nécessaire
mkdir -Force "$env:USERPROFILE\.win-cli-server"

# Créer le fichier de configuration avec les paramètres par défaut
npx -y @simonb97/server-win-cli --init-config "$env:USERPROFILE\.win-cli-server\config.json"
```

### Modification des opérateurs bloqués

Pour autoriser tous les opérateurs, modifiez le fichier de configuration comme suit :

1. Ouvrez le fichier `%USERPROFILE%\.win-cli-server\config.json`
2. Recherchez les sections `blockedOperators` pour chaque shell (powershell, cmd, gitbash)
3. Remplacez les tableaux d'opérateurs bloqués par des tableaux vides `[]`

Exemple de configuration modifiée :

```json
"shells": {
  "powershell": {
    "enabled": true,
    "command": "powershell.exe",
    "args": [
      "-NoProfile",
      "-NonInteractive",
      "-Command"
    ],
    "blockedOperators": []  // Tableau vide pour autoriser tous les opérateurs
  },
  "cmd": {
    "enabled": true,
    "command": "cmd.exe",
    "args": [
      "/c"
    ],
    "blockedOperators": []  // Tableau vide pour autoriser tous les opérateurs
  },
  "gitbash": {
    "enabled": true,
    "command": "C:\\Program Files\\Git\\bin\\bash.exe",
    "args": [
      "-c"
    ],
    "blockedOperators": []  // Tableau vide pour autoriser tous les opérateurs
  }
}
```

### Application des modifications

Après avoir modifié le fichier de configuration, vous devez redémarrer le serveur Win-CLI pour que les modifications prennent effet.

Si vous utilisez Roo, fermez toutes les sessions Roo actives et redémarrez Roo pour que les modifications soient prises en compte.

## Considérations de sécurité

En autorisant tous les opérateurs, vous augmentez la puissance des commandes qui peuvent être exécutées via Win-CLI, mais vous réduisez également les protections de sécurité. Assurez-vous que :

1. Seuls les utilisateurs de confiance ont accès à Roo et au serveur Win-CLI
2. Les autres restrictions de sécurité (commandes bloquées, arguments bloqués, etc.) sont configurées de manière appropriée
3. Les chemins autorisés (`allowedPaths`) sont correctement définis pour limiter l'accès aux répertoires sensibles

## Références

- [Documentation officielle de Win-CLI MCP](https://github.com/simonb97/server-win-cli)
- [Bonnes pratiques de sécurité pour PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/security/security-features)
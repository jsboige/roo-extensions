# Guide de configuration sécurisée des MCPs

Ce guide fournit des exemples de configurations sécurisées pour les différents serveurs MCP utilisés avec Roo. Il montre comment configurer correctement les serveurs tout en évitant les pièges courants et en protégeant les informations sensibles.

## Structure du fichier de configuration MCP

Le fichier de configuration MCP de Roo est situé à :
- Windows : `C:\Users\<username>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- macOS/Linux : `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

Ce fichier contient un objet JSON avec une propriété `mcpServers` qui contient les configurations de tous les serveurs MCP.

## Exemple de configuration sécurisée

Voici un exemple de configuration sécurisée pour les différents serveurs MCP :

```json
{
  "mcpServers": {
    "git": {
      "command": "git-mcp-server",
      "args": [],
      "env": {
        "MCP_TRANSPORT_TYPE": "stdio",
        "MCP_LOG_LEVEL": "info",
        "GIT_SIGN_COMMITS": "false",
        "GIT_DEFAULT_PATH": "D:\\votre\\chemin\\projet"
      },
      "disabled": false,
      "autoApprove": [],
      "alwaysAllow": [
        "status",
        "add",
        "commit",
        "push",
        "pull",
        "branch_list",
        "branch_create",
        "branch_delete",
        "checkout",
        "init",
        "clone"
      ],
      "transportType": "stdio"
    },
    "github": {
      "command": "cmd",
      "args": [
        "/c",
        "npx",
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "<VOTRE_TOKEN_GITHUB_ICI>"
      },
      "disabled": false,
      "autoApprove": [],
      "alwaysAllow": [
        "search_repositories",
        "get_file_contents",
        "create_repository"
      ],
      "transportType": "stdio"
    },
    "searxng": {
      "command": "cmd",
      "args": [
        "/c",
        "D:\\chemin\\vers\\external-mcps\\searxng\\run-searxng.bat"
      ],
      "env": {
        "SEARXNG_URL": "https://search.example.com/"
      },
      "disabled": false,
      "autoApprove": [],
      "alwaysAllow": [
        "searxng_web_search",
        "web_url_read"
      ],
      "transportType": "stdio"
    },
    "win-cli": {
      "command": "cmd",
      "args": [
        "/c",
        "D:\\chemin\\vers\\external-mcps\\win-cli\\run-win-cli.bat"
      ],
      "disabled": false,
      "autoApprove": [],
      "alwaysAllow": [
        "execute_command",
        "get_command_history",
        "get_current_directory"
      ],
      "transportType": "stdio"
    },
    "filesystem": {
      "command": "cmd",
      "args": [
        "/c",
        "npx",
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "D:\\votre\\chemin\\projet"
      ],
      "disabled": false,
      "autoApprove": [],
      "alwaysAllow": [
        "list_allowed_directories",
        "list_directory",
        "read_file",
        "search_files",
        "create_directory",
        "get_file_info",
        "edit_file"
      ],
      "transportType": "stdio"
    }
  }
}
```

## Points importants à noter

### 1. Noms des serveurs

Utilisez des noms simples et descriptifs pour vos serveurs MCP :
- ✅ `git`, `github`, `searxng`, `win-cli`, `filesystem`
- ❌ `github.com/modelcontextprotocol/servers/tree/main/src/git`, `git-global`

### 2. Chemins

Utilisez des chemins absolus complets et doublez les barres obliques inverses dans les chemins Windows :
- ✅ `D:\\chemin\\vers\\fichier.js`
- ❌ `%APPDATA%\\fichier.js`, `D:\chemin\vers\fichier.js`

### 3. Informations sensibles

Remplacez toutes les informations sensibles par des placeholders dans les exemples de configuration :
- ✅ `"GITHUB_PERSONAL_ACCESS_TOKEN": "<VOTRE_TOKEN_GITHUB_ICI>"`
- ❌ `"GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_1234...ABCD"`

### 4. Commandes et arguments

Utilisez les commandes et arguments appropriés pour chaque serveur MCP :
- Pour les serveurs npm : utilisez `npx -y` pour exécuter le package sans l'installer globalement
- Pour les serveurs avec scripts batch : utilisez le chemin complet vers le script batch

### 5. Variables d'environnement

Utilisez des variables d'environnement pour configurer les serveurs MCP :
- `MCP_TRANSPORT_TYPE`: Type de transport (généralement `stdio`)
- `MCP_LOG_LEVEL`: Niveau de journalisation (`error`, `warn`, `info`, `debug`)
- Autres variables spécifiques à chaque serveur (ex: `GITHUB_PERSONAL_ACCESS_TOKEN`, `SEARXNG_URL`)

## Gestion sécurisée des tokens et informations sensibles

### Méthode 1 : Fichier de configuration séparé

1. Créez un fichier `secrets.json` séparé pour stocker vos tokens et informations sensibles
2. Ajoutez ce fichier à votre `.gitignore` pour éviter de le pousser accidentellement vers un dépôt public
3. Chargez les informations sensibles depuis ce fichier dans votre configuration MCP

### Méthode 2 : Variables d'environnement système

1. Définissez vos tokens et informations sensibles comme variables d'environnement système
2. Référencez ces variables dans votre configuration MCP

### Méthode 3 : Gestionnaire de secrets

1. Utilisez un gestionnaire de secrets comme [Azure Key Vault](https://azure.microsoft.com/fr-fr/services/key-vault/), [AWS Secrets Manager](https://aws.amazon.com/fr/secrets-manager/) ou [HashiCorp Vault](https://www.vaultproject.io/)
2. Récupérez les secrets au moment de l'exécution

## Vérification de la configuration

Pour vérifier que vos serveurs MCP sont correctement configurés, ouvrez Roo et utilisez la commande suivante :

```
Quels serveurs MCP sont actuellement connectés ?
```

Roo devrait lister tous les serveurs MCP configurés et leur état de connexion.
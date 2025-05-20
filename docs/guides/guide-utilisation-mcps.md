# Guide d'utilisation optimale des MCPs dans les modes personnalisés

## Introduction

Ce guide fournit des exemples concrets et des bonnes pratiques pour l'utilisation optimale des serveurs MCP (Model Context Protocol) dans les différents modes personnalisés de Roo. L'utilisation des MCPs permet d'améliorer significativement les performances et l'efficacité des opérations, en particulier pour les tâches impliquant de nombreux fichiers ou des opérations web.

## Serveurs MCP disponibles

### 1. QuickFiles

Le serveur QuickFiles permet de manipuler rapidement plusieurs fichiers en une seule opération, ce qui est beaucoup plus efficace que d'utiliser les outils standards de Roo qui nécessitent une validation pour chaque fichier.

### 2. JinaNavigator

Le serveur JinaNavigator permet de convertir des pages web en Markdown et d'extraire des informations structurées, ce qui est plus efficace que d'utiliser le navigateur pour des tâches où le rendu graphique ou JavaScript n'est pas important.

### 3. SearXNG

Le serveur SearXNG permet d'effectuer des recherches web via SearXNG, offrant une alternative privée et efficace aux recherches web traditionnelles.

### 4. Win-CLI

Le serveur Win-CLI permet d'exécuter des commandes dans le terminal Windows, offrant une alternative plus flexible et puissante aux commandes PowerShell standards.

### 5. Git

Le serveur Git permet d'effectuer des opérations Git, offrant une interface plus cohérente et des fonctionnalités avancées par rapport aux commandes Git standards.

## Utilisation optimale par type d'opération

### Manipulation de fichiers

#### Lecture de plusieurs fichiers

**Avec QuickFiles (recommandé):**

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": ["chemin/vers/fichier1.js", "chemin/vers/fichier2.js"],
  "show_line_numbers": true
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<read_file>
<path>chemin/vers/fichier1.js</path>
</read_file>

<!-- Attendre la réponse de l'utilisateur -->

<read_file>
<path>chemin/vers/fichier2.js</path>
</read_file>

<!-- Attendre la réponse de l'utilisateur -->
```

**Avec PowerShell:**

```xml
<execute_command>
<command>powershell -command "Get-Content -Path 'chemin/vers/fichier1.js', 'chemin/vers/fichier2.js'"</command>
</execute_command>

<!-- Attendre la réponse de l'utilisateur -->
```

#### Lecture d'extraits spécifiques de fichiers

**Avec QuickFiles (recommandé):**

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": [
    {
      "path": "chemin/vers/fichier.js",
      "excerpts": [
        { "start": 10, "end": 20 },
        { "start": 50, "end": 60 }
      ]
    }
  ],
  "show_line_numbers": true
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<read_file>
<path>chemin/vers/fichier.js</path>
<start_line>10</start_line>
<end_line>20</end_line>
</read_file>

<!-- Attendre la réponse de l'utilisateur -->

<read_file>
<path>chemin/vers/fichier.js</path>
<start_line>50</start_line>
<end_line>60</end_line>
</read_file>

<!-- Attendre la réponse de l'utilisateur -->
```

#### Listage de répertoires

**Avec QuickFiles (recommandé):**

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>list_directory_contents</tool_name>
<arguments>
{
  "paths": [
    {
      "path": "chemin/vers/repertoire",
      "recursive": true,
      "file_pattern": "*.js",
      "sort_by": "modified",
      "sort_order": "desc"
    }
  ]
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<list_files>
<path>chemin/vers/repertoire</path>
<recursive>true</recursive>
</list_files>

<!-- Attendre la réponse de l'utilisateur -->
```

**Avec PowerShell:**

```xml
<execute_command>
<command>powershell -command "Get-ChildItem -Path 'chemin/vers/repertoire' -Recurse -Filter '*.js' | Sort-Object LastWriteTime -Descending"</command>
</execute_command>

<!-- Attendre la réponse de l'utilisateur -->
```

#### Édition de plusieurs fichiers

**Avec QuickFiles (recommandé):**

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>edit_multiple_files</tool_name>
<arguments>
{
  "files": [
    {
      "path": "chemin/vers/fichier1.js",
      "diffs": [
        {
          "search": "ancien code",
          "replace": "nouveau code"
        }
      ]
    },
    {
      "path": "chemin/vers/fichier2.js",
      "diffs": [
        {
          "search": "autre ancien code",
          "replace": "autre nouveau code"
        }
      ]
    }
  ]
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<apply_diff>
<path>chemin/vers/fichier1.js</path>
<diff>
<<<<<<< SEARCH
:start_line:1
-------
ancien code
=======
nouveau code
>>>>>>> REPLACE
</diff>
</apply_diff>

<!-- Attendre la réponse de l'utilisateur -->

<apply_diff>
<path>chemin/vers/fichier2.js</path>
<diff>
<<<<<<< SEARCH
:start_line:1
-------
autre ancien code
=======
autre nouveau code
>>>>>>> REPLACE
</diff>
</apply_diff>

<!-- Attendre la réponse de l'utilisateur -->
```

#### Recherche dans les fichiers

**Avec QuickFiles (recommandé):**

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["chemin/vers/repertoire"],
  "pattern": "texte à rechercher",
  "use_regex": true,
  "case_sensitive": false,
  "file_pattern": "*.js",
  "context_lines": 2,
  "recursive": true
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<search_files>
<path>chemin/vers/repertoire</path>
<regex>texte à rechercher</regex>
<file_pattern>*.js</file_pattern>
</search_files>

<!-- Attendre la réponse de l'utilisateur -->
```

**Avec PowerShell:**

```xml
<execute_command>
<command>powershell -command "Get-ChildItem -Path 'chemin/vers/repertoire' -Recurse -Filter '*.js' | Select-String -Pattern 'texte à rechercher' -Context 2,2"</command>
</execute_command>

<!-- Attendre la réponse de l'utilisateur -->
```

### Navigation web

#### Conversion d'une page web en Markdown

**Avec JinaNavigator (recommandé):**

```xml
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>convert_web_to_markdown</tool_name>
<arguments>
{
  "url": "https://example.com"
}
</arguments>
</use_mcp_tool>
```

**Avec le navigateur:**

```xml
<browser_action>
<action>launch</action>
<url>https://example.com</url>
</browser_action>

<!-- Attendre la réponse de l'utilisateur avec une capture d'écran -->

<!-- Analyser manuellement le contenu de la page -->

<browser_action>
<action>close</action>
</browser_action>

<!-- Attendre la réponse de l'utilisateur -->
```

#### Conversion de plusieurs pages web

**Avec JinaNavigator (recommandé):**

```xml
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>multi_convert</tool_name>
<arguments>
{
  "urls": [
    { "url": "https://example.com" },
    { "url": "https://another-example.com" }
  ]
}
</arguments>
</use_mcp_tool>
```

**Avec le navigateur:**

```xml
<browser_action>
<action>launch</action>
<url>https://example.com</url>
</browser_action>

<!-- Attendre la réponse de l'utilisateur avec une capture d'écran -->

<!-- Analyser manuellement le contenu de la page -->

<browser_action>
<action>close</action>
</browser_action>

<!-- Attendre la réponse de l'utilisateur -->

<browser_action>
<action>launch</action>
<url>https://another-example.com</url>
</browser_action>

<!-- Attendre la réponse de l'utilisateur avec une capture d'écran -->

<!-- Analyser manuellement le contenu de la page -->

<browser_action>
<action>close</action>
</browser_action>

<!-- Attendre la réponse de l'utilisateur -->
```

#### Extraction du plan d'une page web

**Avec JinaNavigator (recommandé):**

```xml
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>extract_markdown_outline</tool_name>
<arguments>
{
  "urls": [
    { "url": "https://example.com" }
  ],
  "max_depth": 3
}
</arguments>
</use_mcp_tool>
```

### Recherche web

**Avec SearXNG (recommandé):**

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "votre recherche ici"
}
</arguments>
</use_mcp_tool>
```

**Avec le navigateur:**

```xml
<browser_action>
<action>launch</action>
<url>https://www.google.com</url>
</browser_action>

<!-- Attendre la réponse de l'utilisateur avec une capture d'écran -->

<browser_action>
<action>click</action>
<coordinate>450,300</coordinate>
</browser_action>

<!-- Attendre la réponse de l'utilisateur avec une capture d'écran -->

<browser_action>
<action>type</action>
<text>votre recherche ici</text>
</browser_action>

<!-- Attendre la réponse de l'utilisateur avec une capture d'écran -->

<browser_action>
<action>click</action>
<coordinate>550,300</coordinate>
</browser_action>

<!-- Attendre la réponse de l'utilisateur avec une capture d'écran -->

<browser_action>
<action>close</action>
</browser_action>

<!-- Attendre la réponse de l'utilisateur -->
```

### Commandes système

#### Exécution de commandes PowerShell

**Avec Win-CLI (recommandé):**

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Get-Process | Where-Object { $_.CPU -gt 10 } | Sort-Object CPU -Descending",
  "workingDir": "C:\\Users\\username"
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<execute_command>
<command>powershell -command "Get-Process | Where-Object { $_.CPU -gt 10 } | Sort-Object CPU -Descending"</command>
<cwd>C:\\Users\\username</cwd>
</execute_command>

<!-- Attendre la réponse de l'utilisateur -->
```

#### Exécution de commandes CMD

**Avec Win-CLI (recommandé):**

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "cmd",
  "command": "dir /s /b *.js",
  "workingDir": "C:\\Users\\username\\project"
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<execute_command>
<command>cmd /c dir /s /b *.js</command>
<cwd>C:\\Users\\username\\project</cwd>
</execute_command>

<!-- Attendre la réponse de l'utilisateur -->
```

### Opérations Git

#### Clonage d'un dépôt

**Avec Git MCP (recommandé):**

```xml
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>clone</tool_name>
<arguments>
{
  "url": "https://github.com/username/repo.git",
  "path": "C:\\Users\\username\\projects\\repo"
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<execute_command>
<command>git clone https://github.com/username/repo.git</command>
<cwd>C:\\Users\\username\\projects</cwd>
</execute_command>

<!-- Attendre la réponse de l'utilisateur -->
```

#### Vérification du statut

**Avec Git MCP (recommandé):**

```xml
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>status</tool_name>
<arguments>
{
  "path": "C:\\Users\\username\\projects\\repo"
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<execute_command>
<command>git status</command>
<cwd>C:\\Users\\username\\projects\\repo</cwd>
</execute_command>

<!-- Attendre la réponse de l'utilisateur -->
```

#### Ajout et commit de fichiers

**Avec Git MCP (recommandé):**

```xml
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>bulk_action</tool_name>
<arguments>
{
  "path": "C:\\Users\\username\\projects\\repo",
  "actions": [
    {
      "type": "stage",
      "files": [
        "C:\\Users\\username\\projects\\repo\\file1.js",
        "C:\\Users\\username\\projects\\repo\\file2.js"
      ]
    },
    {
      "type": "commit",
      "message": "Ajout de nouvelles fonctionnalités"
    }
  ]
}
</arguments>
</use_mcp_tool>
```

**Avec les outils standards de Roo:**

```xml
<execute_command>
<command>git add file1.js file2.js</command>
<cwd>C:\\Users\\username\\projects\\repo</cwd>
</execute_command>

<!-- Attendre la réponse de l'utilisateur -->

<execute_command>
<command>git commit -m "Ajout de nouvelles fonctionnalités"</command>
<cwd>C:\\Users\\username\\projects\\repo</cwd>
</execute_command>

<!-- Attendre la réponse de l'utilisateur -->
```

## Tableau comparatif des performances

| Opération | MCP | Outil standard Roo | PowerShell | Avantage MCP |
|-----------|-----|-------------------|------------|--------------|
| Lecture de plusieurs fichiers | Une seule requête | Une requête par fichier | Une seule commande, mais moins structuré | Efficacité, structure, pas de validation utilisateur |
| Lecture d'extraits de fichiers | Une seule requête pour plusieurs extraits | Une requête par extrait | Complexe à implémenter | Efficacité, simplicité |
| Listage de répertoires | Options avancées (tri, filtrage) | Options limitées | Options avancées mais syntaxe complexe | Simplicité, options avancées |
| Édition de plusieurs fichiers | Une seule requête | Une requête par fichier | Complexe à implémenter | Efficacité, pas de validation utilisateur |
| Recherche dans les fichiers | Options avancées (contexte, regex) | Options limitées | Options avancées mais syntaxe complexe | Simplicité, options avancées |
| Conversion de pages web | Conversion directe en Markdown | Nécessite navigation manuelle | Non disponible | Efficacité, automatisation |
| Recherche web | Résultats structurés | Nécessite navigation manuelle | Non disponible | Efficacité, automatisation |
| Commandes système | Options avancées (shell, répertoire) | Options limitées | N/A | Flexibilité |
| Opérations Git | Actions multiples en une requête | Une requête par action | Une commande par action | Efficacité, atomicité |

## Bonnes pratiques

### Quand utiliser les MCPs

- **Utilisez les MCPs** lorsque vous devez effectuer des opérations sur plusieurs fichiers ou pages web
- **Utilisez les MCPs** lorsque vous avez besoin d'options avancées (filtrage, tri, contexte)
- **Utilisez les MCPs** lorsque vous voulez éviter les validations utilisateur multiples
- **Utilisez les MCPs** pour les opérations qui seraient complexes à implémenter avec PowerShell

### Quand utiliser les outils standards de Roo

- **Utilisez les outils standards** pour les opérations simples sur un seul fichier
- **Utilisez les outils standards** lorsque vous avez besoin d'une validation explicite de l'utilisateur
- **Utilisez les outils standards** lorsque le MCP correspondant n'est pas disponible

### Quand utiliser PowerShell

- **Utilisez PowerShell** lorsque vous avez besoin de fonctionnalités spécifiques à PowerShell
- **Utilisez PowerShell** lorsque vous devez interagir avec des commandes système spécifiques
- **Utilisez PowerShell** lorsque les MCPs et les outils standards ne sont pas adaptés

## Gestion du changement d'utilisateur GitHub

Pour gérer le changement d'utilisateur GitHub lors de l'utilisation du MCP Git, vous pouvez utiliser l'une des approches suivantes :

1. **Configuration par projet** : Utilisez la configuration Git spécifique au projet pour définir l'utilisateur et l'email

```xml
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "path": "C:\\Users\\username\\projects\\repo",
  "command": "git config user.name \"Nouveau Nom\"; git config user.email \"nouveau@email.com\""
}
</arguments>
</use_mcp_tool>
```

2. **Utilisation de différentes clés SSH** : Configurez différentes clés SSH pour différents comptes GitHub

```xml
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "path": "C:\\Users\\username\\projects\\repo",
  "command": "git config core.sshCommand \"ssh -i ~/.ssh/id_rsa_autre_compte -F /dev/null\""
}
</arguments>
</use_mcp_tool>
```

3. **Utilisation de tokens d'accès personnels** : Utilisez des tokens d'accès personnels pour l'authentification

```xml
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>clone</tool_name>
<arguments>
{
  "url": "https://username:token@github.com/username/repo.git",
  "path": "C:\\Users\\username\\projects\\repo"
}
</arguments>
</use_mcp_tool>
```

## Conclusion

L'utilisation optimale des MCPs peut considérablement améliorer l'efficacité et les performances des modes personnalisés de Roo. En suivant les bonnes pratiques et en utilisant les exemples fournis dans ce guide, vous pouvez tirer le meilleur parti des serveurs MCP disponibles.
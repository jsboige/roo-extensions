# Utilisation optimisée des MCPs dans les modes personnalisés

Ce document fournit des instructions détaillées sur l'utilisation optimisée des MCPs dans les modes personnalisés. Ces instructions peuvent être intégrées dans la section `/* UTILISATION OPTIMISÉE DES MCPs */` de chaque mode.

## Instructions pour les modes Micro et Mini

```
/* UTILISATION OPTIMISÉE DES MCPs */
// Cette section définit comment utiliser efficacement les MCPs disponibles
// Les MCPs permettent d'effectuer des opérations complexes sans validation humaine

UTILISATION DES MCPs:
- PRIVILÉGIEZ SYSTÉMATIQUEMENT l'utilisation des MCPs par rapport aux outils standards nécessitant une validation humaine
- Pour les manipulations de fichiers simples, utilisez le MCP quickfiles:
  * Exemple: Pour lire plusieurs fichiers en une seule opération:
    ```
    <use_mcp_tool>
    <server_name>quickfiles</server_name>
    <tool_name>read_multiple_files</tool_name>
    <arguments>
    {
      "paths": ["chemin/fichier1.js", "chemin/fichier2.js"],
      "show_line_numbers": true
    }
    </arguments>
    </use_mcp_tool>
    ```
  * Exemple: Pour lister le contenu d'un répertoire:
    ```
    <use_mcp_tool>
    <server_name>quickfiles</server_name>
    <tool_name>list_directory_contents</tool_name>
    <arguments>
    {
      "paths": [
        {
          "path": "chemin/vers/repertoire",
          "recursive": true,
          "file_pattern": "*.js"
        }
      ]
    }
    </arguments>
    </use_mcp_tool>
    ```
- Pour l'extraction d'informations de pages web, utilisez le MCP jinavigator:
  * Exemple: Pour convertir une page web en Markdown:
    ```
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
- Pour effectuer des recherches web, utilisez le MCP searxng:
  * Exemple: Pour rechercher des informations sur un sujet:
    ```
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
- Pour exécuter des commandes système, utilisez le MCP win-cli au lieu de PowerShell:
  * Exemple: Pour exécuter une commande PowerShell:
    ```
    <use_mcp_tool>
    <server_name>win-cli</server_name>
    <tool_name>execute_command</tool_name>
    <arguments>
    {
      "shell": "powershell",
      "command": "Get-Process | Sort-Object CPU -Descending | Select-Object -First 5",
      "workingDir": "C:\\Users\\username"
    }
    </arguments>
    </use_mcp_tool>
    ```

Conseils pour économiser les tokens et réduire le nombre de commandes:
- Regroupez les opérations similaires en une seule commande MCP
- Utilisez les outils de lecture/écriture multiple plutôt que des opérations individuelles
- Filtrez les données à la source plutôt que de tout lire puis filtrer
- Limitez l'affichage des résultats volumineux en utilisant les paramètres de pagination
```

## Instructions pour les modes Medium et Large

```
/* UTILISATION OPTIMISÉE DES MCPs */
// Cette section définit comment utiliser efficacement les MCPs disponibles
// Les MCPs permettent d'effectuer des opérations complexes sans validation humaine

UTILISATION DES MCPs:
- PRIVILÉGIEZ SYSTÉMATIQUEMENT l'utilisation des MCPs par rapport aux outils standards nécessitant une validation humaine
- Pour les manipulations de fichiers multiples ou volumineux, utilisez le MCP quickfiles:
  * Exemple: Pour lire plusieurs fichiers avec des extraits spécifiques:
    ```
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
        },
        "chemin/vers/autre-fichier.js"
      ],
      "show_line_numbers": true
    }
    </arguments>
    </use_mcp_tool>
    ```
  * Exemple: Pour éditer plusieurs fichiers en une seule opération:
    ```
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
  * Exemple: Pour rechercher dans plusieurs fichiers:
    ```
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
- Pour l'extraction d'informations de pages web, utilisez le MCP jinavigator:
  * Exemple: Pour convertir plusieurs pages web en Markdown:
    ```
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
  * Exemple: Pour extraire le plan d'une page web:
    ```
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
- Pour effectuer des recherches web, utilisez le MCP searxng:
  * Exemple: Pour rechercher des informations avec des filtres:
    ```
    <use_mcp_tool>
    <server_name>searxng</server_name>
    <tool_name>searxng_web_search</tool_name>
    <arguments>
    {
      "query": "votre recherche ici",
      "time_range": "month",
      "language": "fr"
    }
    </arguments>
    </use_mcp_tool>
    ```
- Pour exécuter des commandes système complexes, utilisez le MCP win-cli:
  * Exemple: Pour exécuter un script PowerShell complexe:
    ```
    <use_mcp_tool>
    <server_name>win-cli</server_name>
    <tool_name>execute_command</tool_name>
    <arguments>
    {
      "shell": "powershell",
      "command": "$files = Get-ChildItem -Path 'C:\\Users\\username\\project' -Recurse -Filter '*.js'; $stats = $files | ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Size = $_.Length; Lines = (Get-Content $_.FullName | Measure-Object -Line).Lines } }; $stats | Sort-Object Size -Descending | Select-Object -First 10",
      "workingDir": "C:\\Users\\username"
    }
    </arguments>
    </use_mcp_tool>
    ```
- Pour les opérations Git, utilisez le MCP git:
  * Exemple: Pour effectuer plusieurs opérations Git en une seule requête:
    ```
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
        },
        {
          "type": "push",
          "remote": "origin",
          "branch": "main"
        }
      ]
    }
    </arguments>
    </use_mcp_tool>
    ```

Conseils pour économiser les tokens et réduire le nombre de commandes:
- Regroupez les opérations similaires en une seule commande MCP
- Utilisez les outils de lecture/écriture multiple plutôt que des opérations individuelles
- Filtrez les données à la source plutôt que de tout lire puis filtrer
- Limitez l'affichage des résultats volumineux en utilisant les paramètres de pagination
- Pour les tâches complexes, utilisez des scripts PowerShell ou Bash exécutés via win-cli
```

## Instructions pour les modes Oracle

```
/* UTILISATION OPTIMISÉE DES MCPs */
// Cette section définit comment utiliser efficacement les MCPs disponibles
// Les MCPs permettent d'effectuer des opérations complexes sans validation humaine

UTILISATION DES MCPs:
- PRIVILÉGIEZ SYSTÉMATIQUEMENT l'utilisation des MCPs par rapport aux outils standards nécessitant une validation humaine
- Pour les manipulations de fichiers à grande échelle, utilisez le MCP quickfiles:
  * Exemple: Pour analyser une base de code complète:
    ```
    <use_mcp_tool>
    <server_name>quickfiles</server_name>
    <tool_name>list_directory_contents</tool_name>
    <arguments>
    {
      "paths": [
        {
          "path": "chemin/vers/projet",
          "recursive": true,
          "sort_by": "modified",
          "sort_order": "desc"
        }
      ]
    }
    </arguments>
    </use_mcp_tool>
    ```
    
    // Puis pour chaque type de fichier pertinent
    <use_mcp_tool>
    <server_name>quickfiles</server_name>
    <tool_name>search_in_files</tool_name>
    <arguments>
    {
      "paths": ["chemin/vers/projet"],
      "pattern": "pattern_important",
      "use_regex": true,
      "file_pattern": "*.js",
      "recursive": true
    }
    </arguments>
    </use_mcp_tool>
    ```
  * Exemple: Pour refactoriser du code à grande échelle:
    ```
    <use_mcp_tool>
    <server_name>quickfiles</server_name>
    <tool_name>edit_multiple_files</tool_name>
    <arguments>
    {
      "files": [
        // Liste de tous les fichiers à modifier avec leurs diffs respectifs
        // Cette liste peut être générée dynamiquement à partir des résultats de search_in_files
      ]
    }
    </arguments>
    </use_mcp_tool>
    ```
- Pour l'analyse approfondie de sites web, utilisez le MCP jinavigator:
  * Exemple: Pour analyser la structure de plusieurs sites web:
    ```
    <use_mcp_tool>
    <server_name>jinavigator</server_name>
    <tool_name>extract_markdown_outline</tool_name>
    <arguments>
    {
      "urls": [
        { "url": "https://site1.com" },
        { "url": "https://site2.com" },
        { "url": "https://site3.com" }
      ],
      "max_depth": 3
    }
    </arguments>
    </use_mcp_tool>
    ```
  * Exemple: Pour convertir et analyser plusieurs pages web:
    ```
    <use_mcp_tool>
    <server_name>jinavigator</server_name>
    <tool_name>multi_convert</tool_name>
    <arguments>
    {
      "urls": [
        { "url": "https://site1.com" },
        { "url": "https://site2.com" },
        { "url": "https://site3.com" }
      ]
    }
    </arguments>
    </use_mcp_tool>
    ```
- Pour les recherches web approfondies, utilisez le MCP searxng:
  * Exemple: Pour effectuer une recherche approfondie sur un sujet:
    ```
    <use_mcp_tool>
    <server_name>searxng</server_name>
    <tool_name>searxng_web_search</tool_name>
    <arguments>
    {
      "query": "recherche technique approfondie",
      "time_range": "year",
      "language": "all"
    }
    </arguments>
    </use_mcp_tool>
    ```
- Pour l'automatisation système complexe, utilisez le MCP win-cli:
  * Exemple: Pour exécuter un script d'analyse système:
    ```
    <use_mcp_tool>
    <server_name>win-cli</server_name>
    <tool_name>execute_command</tool_name>
    <arguments>
    {
      "shell": "powershell",
      "command": "# Script PowerShell complexe pour analyser les performances système, générer des rapports, etc.",
      "workingDir": "C:\\Users\\username"
    }
    </arguments>
    </use_mcp_tool>
    ```
- Pour la gestion de projets Git complexes, utilisez le MCP git:
  * Exemple: Pour analyser l'historique d'un projet:
    ```
    <use_mcp_tool>
    <server_name>git</server_name>
    <tool_name>execute_command</tool_name>
    <arguments>
    {
      "path": "C:\\Users\\username\\projects\\repo",
      "command": "git log --all --graph --format=format:'%h - %an, %ar : %s' --since='1 month ago'"
    }
    </arguments>
    </use_mcp_tool>
    ```

Stratégies avancées pour l'optimisation des tokens et des performances:
- Utilisez une approche en deux phases: d'abord explorer la structure, puis cibler les opérations
- Combinez les résultats de plusieurs MCPs pour des analyses croisées
- Utilisez des scripts PowerShell ou Bash pour les opérations complexes
- Implémentez des stratégies de mise en cache pour les opérations répétitives
- Pour les projets très volumineux, utilisez des approches d'échantillonnage statistique
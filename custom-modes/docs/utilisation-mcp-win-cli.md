# Utilisation du MCP Win-CLI dans les Modes Personnalisés

Ce document explique comment utiliser efficacement le serveur MCP Win-CLI dans les différents modes personnalisés Roo, en tenant compte des capacités et limitations de chaque mode.

## Introduction

Le serveur MCP Win-CLI permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash) et d'accéder à des ressources système via des URI. Son utilisation varie selon le mode Roo et le niveau de complexité de la tâche.

## Fonctionnalités optimales par mode

### Mode Code

#### Code Simple
- **Fonctionnalités recommandées** :
  - Commandes simples pour lister des fichiers (`dir`, `ls`)
  - Commandes d'affichage de contenu (`type`, `cat`)
  - Accès aux ressources directes (`cli://currentdir`)
  - Exécution de scripts simples

- **Exemple d'utilisation** :
  ```xml
  <use_mcp_tool>
  <server_name>win-cli</server_name>
  <tool_name>execute_command</tool_name>
  <arguments>
  {
    "shell": "powershell",
    "command": "Get-ChildItem -Path . -Recurse -Include *.js | Select-Object FullName"
  }
  </arguments>
  </use_mcp_tool>
  ```

#### Code Complex
- **Fonctionnalités recommandées** :
  - Commandes avancées avec pipes et filtres
  - Exécution de scripts complexes
  - Manipulation de fichiers et répertoires
  - Gestion des processus et services

- **Exemple d'utilisation** :
  ```xml
  <use_mcp_tool>
  <server_name>win-cli</server_name>
  <tool_name>execute_command</tool_name>
  <arguments>
  {
    "shell": "powershell",
    "command": "$files = Get-ChildItem -Path . -Recurse -Include *.js; $stats = $files | ForEach-Object { [PSCustomObject]@{ File = $_.Name; Lines = (Get-Content $_.FullName | Measure-Object -Line).Lines } }; $stats | Sort-Object Lines -Descending | Select-Object -First 5"
  }
  </arguments>
  </use_mcp_tool>
  ```

### Mode Debug

#### Debug Simple
- **Fonctionnalités recommandées** :
  - Vérification des processus en cours
  - Affichage des logs simples
  - Vérification des versions de logiciels
  - Diagnostic réseau de base

- **Exemple d'utilisation** :
  ```xml
  <use_mcp_tool>
  <server_name>win-cli</server_name>
  <tool_name>execute_command</tool_name>
  <arguments>
  {
    "shell": "cmd",
    "command": "netstat -an | findstr LISTENING"
  }
  </arguments>
  </use_mcp_tool>
  ```

#### Debug Complex
- **Fonctionnalités recommandées** :
  - Analyse approfondie des logs
  - Diagnostic réseau avancé
  - Analyse des performances
  - Débogage de processus

- **Exemple d'utilisation** :
  ```xml
  <use_mcp_tool>
  <server_name>win-cli</server_name>
  <tool_name>execute_command</tool_name>
  <arguments>
  {
    "shell": "powershell",
    "command": "Get-EventLog -LogName Application -Newest 50 | Where-Object { $_.EntryType -eq 'Error' } | Select-Object TimeGenerated, Source, Message | Format-Table -AutoSize"
  }
  </arguments>
  </use_mcp_tool>
  ```

### Mode Architect

#### Architect Simple
- **Fonctionnalités recommandées** :
  - Exploration de la structure du projet
  - Génération de documentation simple
  - Analyse des dépendances de base

- **Exemple d'utilisation** :
  ```xml
  <use_mcp_tool>
  <server_name>win-cli</server_name>
  <tool_name>execute_command</tool_name>
  <arguments>
  {
    "shell": "powershell",
    "command": "Get-ChildItem -Directory | ForEach-Object { $dir = $_; $files = Get-ChildItem -Path $dir.FullName -File -Recurse | Measure-Object | Select-Object -ExpandProperty Count; [PSCustomObject]@{ Directory = $dir.Name; Files = $files } } | Format-Table -AutoSize"
  }
  </arguments>
  </use_mcp_tool>
  ```

#### Architect Complex
- **Fonctionnalités recommandées** :
  - Analyse approfondie de la structure du projet
  - Génération de documentation complexe
  - Analyse des dépendances avancée
  - Évaluation des performances

- **Exemple d'utilisation** :
  ```xml
  <use_mcp_tool>
  <server_name>win-cli</server_name>
  <tool_name>execute_command</tool_name>
  <arguments>
  {
    "shell": "powershell",
    "command": "$dirs = Get-ChildItem -Directory -Recurse; $stats = foreach ($dir in $dirs) { $files = Get-ChildItem -Path $dir.FullName -File | Measure-Object | Select-Object -ExpandProperty Count; $size = Get-ChildItem -Path $dir.FullName -File -Recurse | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum; [PSCustomObject]@{ Path = $dir.FullName; Files = $files; Size = [math]::Round($size/1MB, 2) } }; $stats | Sort-Object Size -Descending | Select-Object -First 10 | Format-Table -AutoSize"
  }
  </arguments>
  </use_mcp_tool>
  ```

### Mode Ask

#### Ask Simple
- **Fonctionnalités recommandées** :
  - Récupération d'informations système simples
  - Vérification des versions de logiciels
  - Accès aux ressources directes

- **Exemple d'utilisation** :
  ```xml
  <access_mcp_resource>
  <server_name>win-cli</server_name>
  <uri>cli://currentdir</uri>
  </access_mcp_resource>
  ```

#### Ask Complex
- **Fonctionnalités recommandées** :
  - Recherche d'informations avancées
  - Analyse de données système
  - Génération de rapports

- **Exemple d'utilisation** :
  ```xml
  <use_mcp_tool>
  <server_name>win-cli</server_name>
  <tool_name>execute_command</tool_name>
  <arguments>
  {
    "shell": "powershell",
    "command": "Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer, CsProcessors, CsNumberOfLogicalProcessors, CsNumberOfProcessors, CsTotalPhysicalMemory | ConvertTo-Json"
  }
  </arguments>
  </use_mcp_tool>
  ```

### Mode Orchestrator

#### Orchestrator Simple
- **Fonctionnalités recommandées** :
  - Vérification de l'état du système
  - Exécution de commandes simples pour préparer des sous-tâches
  - Accès aux ressources directes

- **Exemple d'utilisation** :
  ```xml
  <use_mcp_tool>
  <server_name>win-cli</server_name>
  <tool_name>execute_command</tool_name>
  <arguments>
  {
    "shell": "powershell",
    "command": "if (Test-Path 'project') { Write-Host 'Le projet existe déjà' } else { New-Item -ItemType Directory -Path 'project'; Write-Host 'Projet créé' }"
  }
  </arguments>
  </use_mcp_tool>
  ```

#### Orchestrator Complex
- **Fonctionnalités recommandées** :
  - Coordination de tâches complexes
  - Préparation d'environnements
  - Vérification de prérequis
  - Gestion de workflows

- **Exemple d'utilisation** :
  ```xml
  <use_mcp_tool>
  <server_name>win-cli</server_name>
  <tool_name>execute_command</tool_name>
  <arguments>
  {
    "shell": "powershell",
    "command": "$requiredTools = @('node', 'npm', 'git'); $missing = @(); foreach ($tool in $requiredTools) { if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { $missing += $tool } }; if ($missing.Count -gt 0) { Write-Host \"Outils manquants: $($missing -join ', ')\" } else { Write-Host 'Tous les outils requis sont installés' }"
  }
  </arguments>
  </use_mcp_tool>
  ```

## Contournement des limitations

### Commandes complexes

Pour contourner les limitations avec les commandes complexes, utilisez ces stratégies selon le mode :

#### Modes Simples
1. **Divisez les commandes** en plusieurs étapes simples
2. **Utilisez des fichiers temporaires** pour stocker les résultats intermédiaires
3. **Préférez les ressources directes** aux commandes complexes

Exemple pour Mode Code Simple :
```xml
<!-- Au lieu de cette commande complexe -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Get-ChildItem -Recurse | Where-Object { $_.Length -gt 1MB } | Sort-Object Length -Descending | Select-Object FullName, Length"
}
</arguments>
</use_mcp_tool>

<!-- Utilisez cette approche en plusieurs étapes -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Get-ChildItem -Recurse | Export-Csv -Path temp_files.csv -NoTypeInformation"
}
</arguments>
</use_mcp_tool>

<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Import-Csv -Path temp_files.csv | Where-Object { [long]$_.Length -gt 1MB } | Sort-Object Length -Descending | Select-Object FullName, Length | Format-Table -AutoSize"
}
</arguments>
</use_mcp_tool>
```

#### Modes Complexes
1. **Utilisez des scripts PowerShell** plus élaborés
2. **Exploitez les structures de contrôle** (if, foreach, etc.)
3. **Utilisez des variables** pour stocker les résultats intermédiaires

Exemple pour Mode Debug Complex :
```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "$processes = Get-Process; $highCpu = $processes | Where-Object { $_.CPU -gt 10 }; $highMem = $processes | Where-Object { $_.WorkingSet -gt 100MB }; Write-Host 'Processus CPU élevé:'; $highCpu | Format-Table Name, CPU -AutoSize; Write-Host 'Processus mémoire élevée:'; $highMem | Format-Table Name, WorkingSet -AutoSize"
}
</arguments>
</use_mcp_tool>
```

### Commandes interactives

Pour les commandes interactives, adaptez votre approche selon le mode :

#### Modes Simples
- Évitez complètement les commandes interactives
- Utilisez des paramètres pour automatiser les réponses

#### Modes Complexes
- Utilisez des scripts avec des paramètres prédéfinis
- Préparez des fichiers de configuration à l'avance

## Bonnes pratiques générales

1. **Adaptez la complexité** des commandes au mode utilisé
2. **Utilisez les ressources directes** quand c'est possible
3. **Préférez PowerShell** pour les tâches complexes
4. **Divisez les tâches complexes** en sous-tâches simples
5. **Utilisez des fichiers temporaires** pour les résultats intermédiaires
6. **Vérifiez toujours les résultats** avant de procéder à l'étape suivante
7. **Nettoyez les fichiers temporaires** après utilisation

## Conclusion

L'utilisation efficace du MCP Win-CLI dans les modes personnalisés Roo nécessite d'adapter les commandes et les approches en fonction du niveau de complexité du mode. En suivant les recommandations de ce document, vous pourrez tirer le meilleur parti de ce serveur MCP tout en évitant ses limitations connues.
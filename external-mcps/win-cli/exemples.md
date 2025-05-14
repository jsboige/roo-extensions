# Exemples d'utilisation du serveur MCP Win-CLI

Ce document présente des exemples concrets d'utilisation du serveur MCP Win-CLI avec Roo, montrant comment exécuter des commandes dans différents shells et utiliser les fonctionnalités SSH.

## Exécution de commandes de base

### PowerShell

Pour exécuter une commande PowerShell simple :

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Get-Process | Select-Object -First 5"
}
</arguments>
</use_mcp_tool>
```

Cette commande affichera les 5 premiers processus en cours d'exécution sur le système.

### CMD (Command Prompt)

Pour exécuter une commande dans l'invite de commandes Windows :

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "cmd",
  "command": "dir /b"
}
</arguments>
</use_mcp_tool>
```

Cette commande listera les fichiers du répertoire courant au format simple.

### Git Bash

Pour exécuter une commande dans Git Bash :

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "gitbash",
  "command": "ls -la"
}
</arguments>
</use_mcp_tool>
```

Cette commande affichera la liste détaillée des fichiers, y compris les fichiers cachés.

## Exécution dans un répertoire spécifique

Pour exécuter une commande dans un répertoire spécifique :

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Get-ChildItem",
  "workingDir": "C:\\Users\\Public\\Documents"
}
</arguments>
</use_mcp_tool>
```

Cette commande listera les fichiers dans le répertoire `C:\Users\Public\Documents`.

## Utilisation des séparateurs de commande

Pour exécuter plusieurs commandes séparées par `;` :

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Write-Host 'Première commande' ; Write-Host 'Deuxième commande'"
}
</arguments>
</use_mcp_tool>
```

Cette commande exécutera les deux instructions `Write-Host` l'une après l'autre.

## Commandes PowerShell avancées

### Manipulation de fichiers

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "$content = Get-Content -Path 'C:\\temp\\exemple.txt'; Write-Host \"Le fichier contient $($content.Length) lignes\""
}
</arguments>
</use_mcp_tool>
```

Cette commande lit le contenu d'un fichier et affiche le nombre de lignes qu'il contient.

### Requêtes HTTP

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Invoke-WebRequest -Uri 'https://api.github.com/zen' | Select-Object -ExpandProperty Content"
}
</arguments>
</use_mcp_tool>
```

Cette commande effectue une requête HTTP à l'API GitHub et affiche la réponse.

### Traitement JSON

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "$json = '{\"name\":\"John\",\"age\":30}' | ConvertFrom-Json; Write-Host \"Nom: $($json.name), Age: $($json.age)\""
}
</arguments>
</use_mcp_tool>
```

Cette commande traite une chaîne JSON et affiche les valeurs extraites.

## Commandes CMD avancées

### Manipulation de fichiers

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "cmd",
  "command": "type nul > test.txt & echo Hello World > test.txt & type test.txt"
}
</arguments>
</use_mcp_tool>
```

Cette commande crée un fichier, y écrit du texte, puis affiche son contenu.

### Informations système

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "cmd",
  "command": "systeminfo | findstr /B /C:\"OS Name\" /C:\"OS Version\""
}
</arguments>
</use_mcp_tool>
```

Cette commande affiche le nom et la version du système d'exploitation.

## Commandes Git Bash avancées

### Manipulation de fichiers

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "gitbash",
  "command": "echo 'Hello from Git Bash' > test.txt && cat test.txt"
}
</arguments>
</use_mcp_tool>
```

Cette commande crée un fichier, y écrit du texte, puis affiche son contenu.

### Informations système

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "gitbash",
  "command": "uname -a"
}
</arguments>
</use_mcp_tool>
```

Cette commande affiche des informations sur le système d'exploitation.

## Gestion de l'historique des commandes

Pour récupérer l'historique des commandes exécutées :

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>get_command_history</tool_name>
<arguments>
{
  "limit": 5
}
</arguments>
</use_mcp_tool>
```

Cette commande affichera les 5 dernières commandes exécutées.

## Gestion des connexions SSH

### Création d'une connexion SSH

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>create_ssh_connection</tool_name>
<arguments>
{
  "connectionId": "mon-serveur",
  "connectionConfig": {
    "host": "192.168.1.100",
    "port": 22,
    "username": "utilisateur",
    "password": "motdepasse"
  }
}
</arguments>
</use_mcp_tool>
```

Cette commande crée une nouvelle connexion SSH nommée "mon-serveur".

### Lecture des connexions SSH

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>read_ssh_connections</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>
```

Cette commande affiche toutes les connexions SSH configurées.

### Exécution d'une commande via SSH

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>ssh_execute</tool_name>
<arguments>
{
  "connectionId": "mon-serveur",
  "command": "ls -la"
}
</arguments>
</use_mcp_tool>
```

Cette commande exécute `ls -la` sur le serveur distant via SSH.

### Déconnexion SSH

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>ssh_disconnect</tool_name>
<arguments>
{
  "connectionId": "mon-serveur"
}
</arguments>
</use_mcp_tool>
```

Cette commande ferme la connexion SSH avec le serveur "mon-serveur".

## Récupération du répertoire courant

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>get_current_directory</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>
```

Cette commande affiche le répertoire de travail actuel du serveur MCP Win-CLI.

## Workflows complets

### Installation et configuration d'un package npm

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "mkdir projet-test ; cd projet-test ; npm init -y ; npm install express ; echo \"const express = require('express'); const app = express(); app.get('/', (req, res) => res.send('Hello World')); app.listen(3000);\" > index.js ; node index.js",
  "workingDir": "C:\\temp"
}
</arguments>
</use_mcp_tool>
```

Ce workflow complet :
1. Crée un nouveau répertoire
2. Initialise un projet npm
3. Installe Express
4. Crée un fichier index.js avec une application Express simple
5. Démarre l'application

### Analyse de l'utilisation du disque

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "$folders = Get-ChildItem -Directory ; foreach ($folder in $folders) { $size = (Get-ChildItem $folder.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB ; Write-Host \"$($folder.Name): $([math]::Round($size, 2)) MB\" }"
}
</arguments>
</use_mcp_tool>
```

Ce workflow analyse la taille de tous les dossiers dans le répertoire courant et affiche leur taille en mégaoctets.

## Bonnes pratiques et optimisations

### Bonnes pratiques générales

1. **Utilisez le shell approprié** pour chaque tâche :
   - PowerShell pour les tâches d'administration Windows et le traitement de données
   - CMD pour les commandes Windows de base et la compatibilité
   - Git Bash pour les commandes Unix-like et Git

2. **Spécifiez toujours un répertoire de travail** pour éviter les problèmes de chemin relatif

3. **Préférez les commandes idempotentes** qui peuvent être exécutées plusieurs fois sans effets secondaires

4. **Utilisez les séparateurs de commande avec précaution** et conformément à la configuration de sécurité

5. **Vérifiez l'historique des commandes** régulièrement pour suivre les actions effectuées

### Optimisations pour Roo

1. **Utilisez les ressources directes** pour un accès rapide aux informations système :

```xml
<access_mcp_resource>
<server_name>win-cli</server_name>
<uri>cli://currentdir</uri>
</access_mcp_resource>
```

2. **Préférez les commandes simples** aux commandes complexes :

```xml
<!-- À éviter -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Get-Process | Where-Object { $_.CPU -gt 10 } | Sort-Object CPU -Descending | Select-Object -First 5 | Format-Table Name, CPU, WorkingSet"
}
</arguments>
</use_mcp_tool>

<!-- Préférer -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 -Property Name, CPU, WorkingSet"
}
</arguments>
</use_mcp_tool>
```

3. **Divisez les commandes complexes** en plusieurs commandes simples :

```xml
<!-- Étape 1 : Obtenir les processus -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | Export-Csv -Path temp_processes.csv -NoTypeInformation"
}
</arguments>
</use_mcp_tool>

<!-- Étape 2 : Analyser les résultats -->
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Import-Csv -Path temp_processes.csv | Select-Object -First 5 | Format-Table Name, CPU, WorkingSet"
}
</arguments>
</use_mcp_tool>
```

### Contournement des limitations

1. **Pour les commandes avec pipes complexes** :
   - Utilisez des fichiers temporaires pour stocker les résultats intermédiaires
   - Divisez la commande en plusieurs étapes
   - Utilisez des variables PowerShell pour stocker les résultats intermédiaires

2. **Pour les commandes interactives** :
   - Utilisez des paramètres pour automatiser les réponses (ex: `-Confirm:$false` en PowerShell)
   - Préparez des scripts non-interactifs à exécuter
   - Utilisez des fichiers de configuration plutôt que des entrées interactives

3. **Pour les séparateurs de commandes** :
   - Utilisez principalement le séparateur `;` qui est le plus stable
   - Pour les dépendances entre commandes, utilisez des scripts PowerShell avec des structures conditionnelles
   - Exemple :
   
```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "$result = Test-Path 'file.txt'; if ($result) { Write-Host 'Le fichier existe' } else { Write-Host 'Le fichier n\\'existe pas' }"
}
</arguments>
</use_mcp_tool>
```

4. **Pour les sorties volumineuses** :
   - Limitez les résultats avec `Select-Object -First N` en PowerShell
   - Redirigez la sortie vers un fichier puis lisez-le partiellement
   - Utilisez des filtres pour réduire la quantité de données (grep, findstr, Where-Object)
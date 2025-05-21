# Système de Surveillance des Serveurs MCP

Ce répertoire contient un système de surveillance basique pour les serveurs MCP (Model Context Protocol) utilisés par Roo. Le système permet de détecter les problèmes avec les serveurs MCP et d'alerter en cas de dysfonctionnement.

## Contenu du Répertoire

- `monitor-mcp-servers.js` : Script JavaScript qui vérifie l'état des serveurs MCP
- `monitor-mcp-servers.ps1` : Script PowerShell qui exécute le script JavaScript et peut redémarrer les serveurs défaillants
- `logs/` : Répertoire contenant les fichiers de log (créé automatiquement)
- `alerts/` : Répertoire contenant les alertes (créé automatiquement)

## Serveurs MCP Surveillés

Le système surveille les serveurs MCP suivants :

1. **Jupyter MCP** : Serveur pour l'intégration avec Jupyter Notebook
2. **JinaNavigator MCP** : Serveur pour la navigation web et la conversion de pages web
3. **QuickFiles MCP** : Serveur pour la manipulation rapide de fichiers
4. **SearxNG MCP** : Serveur pour les recherches web via SearxNG
5. **Win-CLI MCP** : Serveur pour l'exécution de commandes CLI sous Windows

## Utilisation des Scripts

### Script JavaScript (monitor-mcp-servers.js)

Ce script vérifie l'état des serveurs MCP en :
- Vérifiant si les processus sont en cours d'exécution
- Vérifiant si les serveurs répondent correctement aux requêtes HTTP
- Enregistrant les résultats dans des fichiers de log
- Générant des alertes en cas de problème

Pour exécuter le script directement :

```bash
node mcps/monitoring/monitor-mcp-servers.js
```

### Script PowerShell (monitor-mcp-servers.ps1)

Ce script exécute le script JavaScript et offre des fonctionnalités supplémentaires :
- Redémarrage automatique des serveurs défaillants
- Options de logging avancées
- Possibilité d'envoyer des alertes par email (nécessite une configuration supplémentaire)

Pour exécuter le script :

```powershell
# Exécution simple (surveillance uniquement)
.\mcps\monitoring\monitor-mcp-servers.ps1

# Surveillance avec redémarrage automatique des serveurs défaillants
.\mcps\monitoring\monitor-mcp-servers.ps1 -RestartServers

# Surveillance silencieuse (logs uniquement, pas de sortie console)
.\mcps\monitoring\monitor-mcp-servers.ps1 -LogOnly

# Surveillance avec alertes par email (nécessite configuration)
.\mcps\monitoring\monitor-mcp-servers.ps1 -EmailAlert
```

## Configuration d'une Tâche Planifiée Windows

Pour exécuter régulièrement la surveillance, vous pouvez configurer une tâche planifiée Windows :

1. Ouvrez le Planificateur de tâches Windows
2. Créez une nouvelle tâche
3. Configurez le déclencheur (par exemple, toutes les heures)
4. Ajoutez une action pour exécuter PowerShell avec la commande suivante :
   ```
   powershell.exe -ExecutionPolicy Bypass -File "C:\dev\roo-extensions\mcps\monitoring\monitor-mcp-servers.ps1" -RestartServers
   ```
5. Configurez les conditions et paramètres supplémentaires selon vos besoins

## Interprétation des Alertes

Le système génère plusieurs types d'alertes :

1. **Processus non en cours d'exécution** : Le serveur MCP n'est pas démarré ou a planté
2. **Serveur ne répond pas** : Le processus est en cours d'exécution, mais le serveur ne répond pas aux requêtes HTTP
3. **Erreur lors de la connexion** : Impossible d'établir une connexion avec le serveur
4. **Délai d'attente dépassé** : Le serveur prend trop de temps pour répondre

Les alertes sont enregistrées dans :
- Les fichiers de log standard (`logs/mcp-monitor-YYYY-MM-DD.log`)
- Les fichiers d'alertes spécifiques (`alerts/mcp-alerts-YYYY-MM-DD.log`)
- La sortie console (sauf si l'option `-LogOnly` est utilisée)

## Procédures de Redémarrage des Serveurs MCP

### Redémarrage Automatique

Le script PowerShell peut redémarrer automatiquement les serveurs défaillants avec l'option `-RestartServers`. Il utilise les scripts de démarrage fournis dans la configuration.

### Redémarrage Manuel

Si vous devez redémarrer manuellement les serveurs MCP, voici les procédures pour chaque serveur :

#### Jupyter MCP

```bash
# Arrêter le serveur (si nécessaire)
taskkill /F /IM node.exe /FI "WINDOWTITLE eq *jupyter-mcp-server*"

# Démarrer le serveur
cd C:\dev\roo-extensions\mcps\mcp-servers\scripts\mcp-starters
start-jupyter-mcp.bat
```

#### JinaNavigator MCP

```bash
# Arrêter le serveur (si nécessaire)
taskkill /F /IM node.exe /FI "WINDOWTITLE eq *jinavigator-server*"

# Démarrer le serveur
cd C:\dev\roo-extensions\mcps\mcp-servers\scripts\mcp-starters
start-jinavigator-mcp.bat
```

#### QuickFiles MCP

```bash
# Arrêter le serveur (si nécessaire)
taskkill /F /IM node.exe /FI "WINDOWTITLE eq *quickfiles-server*"

# Démarrer le serveur
cd C:\dev\roo-extensions\mcps\mcp-servers\scripts\mcp-starters
start-quickfiles-mcp.bat
```

#### SearxNG MCP

```bash
# Arrêter le serveur (si nécessaire)
taskkill /F /IM node.exe /FI "WINDOWTITLE eq *searxng-server*"

# Démarrer le serveur
cd C:\dev\roo-extensions\mcps\mcp-servers\scripts\mcp-starters
start-searxng-mcp.bat
```

#### Win-CLI MCP

```bash
# Arrêter le serveur (si nécessaire)
taskkill /F /IM node.exe /FI "WINDOWTITLE eq *server-win-cli*"

# Démarrer le serveur
cd C:\dev\roo-extensions
npx -y @simonb97/server-win-cli
```

## Personnalisation

### Ajout de Nouveaux Serveurs MCP

Pour ajouter un nouveau serveur MCP à surveiller, modifiez le tableau `MCP_SERVERS` dans le fichier `monitor-mcp-servers.js` :

```javascript
{
  name: 'Nouveau Serveur MCP',
  processName: 'node',  // Nom du processus
  processArgs: 'nouveau-server/dist/index.js',  // Arguments pour identifier le processus
  port: 3010,  // Port utilisé par le serveur
  endpoint: 'http://localhost:3010/',  // Point de terminaison pour vérifier la réponse
  startScript: path.join(__dirname, '../mcp-servers/scripts/mcp-starters/start-nouveau-mcp.bat')  // Script de démarrage
}
```

### Configuration des Alertes par Email

Pour activer les alertes par email, modifiez la fonction `Send-EmailAlert` dans le script PowerShell en décommentant et configurant les paramètres SMTP.

## Dépannage

### Le script JavaScript ne détecte pas correctement les processus

Vérifiez que les valeurs `processName` et `processArgs` correspondent aux processus réels. Vous pouvez utiliser `tasklist` (Windows) ou `ps aux` (Linux/macOS) pour voir les processus en cours d'exécution.

### Le script PowerShell ne redémarre pas les serveurs

Vérifiez que les chemins des scripts de démarrage sont corrects et que les scripts sont exécutables. Assurez-vous également que PowerShell a les permissions nécessaires pour exécuter les scripts.

### Les alertes par email ne fonctionnent pas

Vérifiez la configuration SMTP dans la fonction `Send-EmailAlert` du script PowerShell. Assurez-vous que les informations d'identification sont correctes et que le serveur SMTP est accessible.

## Limitations Connues

- La détection des processus peut ne pas être fiable si plusieurs instances du même serveur sont en cours d'exécution
- La vérification HTTP simple peut ne pas détecter tous les problèmes de fonctionnalité
- Le redémarrage automatique peut ne pas fonctionner correctement si les serveurs ont des dépendances complexes

## Améliorations Futures

- Ajout de tests de fonctionnalité plus avancés pour chaque serveur MCP
- Interface web pour visualiser l'état des serveurs
- Intégration avec des systèmes de surveillance plus robustes (Prometheus, Grafana, etc.)
- Support pour les notifications via Slack, Teams, etc.
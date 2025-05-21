# Résolution des problèmes du MCP Docker

<!-- START_SECTION: introduction -->
## Introduction

Ce document fournit des solutions aux problèmes courants rencontrés lors de l'utilisation du MCP Docker avec Roo. Si vous rencontrez des difficultés, consultez les sections ci-dessous pour trouver des solutions.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: installation_issues -->
## Problèmes d'installation

### L'image Docker ne se construit pas

**Symptôme**: Erreur lors de la construction de l'image Docker avec le script `build-mcp-server-docker.ps1`.

**Solutions possibles**:

1. **Vérifiez que Docker est en cours d'exécution**:
   ```powershell
   docker info
   ```
   Si cette commande échoue, démarrez Docker Desktop ou le service Docker.

2. **Vérifiez l'espace disque disponible**:
   ```powershell
   Get-PSDrive C
   ```
   Assurez-vous d'avoir au moins 1 Go d'espace libre.

3. **Problèmes de réseau**:
   - Vérifiez votre connexion Internet
   - Si vous êtes derrière un proxy, configurez Docker pour utiliser ce proxy:
     ```powershell
     $env:HTTP_PROXY="http://proxy.example.com:8080"
     $env:HTTPS_PROXY="http://proxy.example.com:8080"
     ```

4. **Erreurs de clonage du dépôt**:
   - Clonez manuellement le dépôt:
     ```powershell
     git clone https://github.com/ckreiling/mcp-server-docker.git
     cd mcp-server-docker
     ```
   - Vérifiez que Git est correctement installé:
     ```powershell
     git --version
     ```

5. **Construisez l'image manuellement**:
   ```powershell
   cd mcp-server-docker
   docker build -t mcp-server:local .
   ```
   Cette approche peut fournir des messages d'erreur plus détaillés.
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: configuration_issues -->
## Problèmes de configuration

### Le serveur MCP ne démarre pas

**Symptôme**: Le serveur MCP Docker n'apparaît pas comme connecté dans Roo.

**Solutions possibles**:

1. **Vérifiez la configuration MCP**:
   - Assurez-vous que le fichier de configuration MCP contient l'entrée correcte pour le MCP Docker
   - Vérifiez que le chemin vers le socket Docker est correct

2. **Vérifiez que l'image existe**:
   ```powershell
   docker images | grep mcp-server
   ```
   Si l'image n'existe pas, reconstruisez-la.

3. **Testez le démarrage manuel du serveur MCP**:
   ```powershell
   docker run -i --rm -v /var/run/docker.sock:/var/run/docker.sock mcp-server:local
   ```
   Vérifiez s'il y a des erreurs dans la sortie.

4. **Problèmes de permissions du socket Docker**:
   - Sur Linux, vérifiez les permissions du socket Docker:
     ```bash
     ls -la /var/run/docker.sock
     ```
   - Ajustez les permissions si nécessaire:
     ```bash
     sudo chmod 666 /var/run/docker.sock
     ```

5. **Redémarrez VS Code**:
   - Fermez et redémarrez VS Code pour recharger la configuration MCP
<!-- END_SECTION: configuration_issues -->

<!-- START_SECTION: connection_issues -->
## Problèmes de connexion

### Erreur de connexion au socket Docker

**Symptôme**: Le serveur MCP démarre mais ne peut pas se connecter au socket Docker.

**Solutions possibles**:

1. **Vérifiez que Docker est en cours d'exécution**:
   ```powershell
   docker info
   ```

2. **Vérifiez le montage du socket Docker**:
   - Assurez-vous que le socket Docker est correctement monté dans le conteneur
   - Sur Windows avec Docker Desktop, vérifiez que le socket est accessible via WSL2

3. **Problèmes de permissions**:
   - Sur Linux, ajustez les permissions du socket Docker:
     ```bash
     sudo chmod 666 /var/run/docker.sock
     ```
   - Sur Windows, exécutez Docker Desktop en tant qu'administrateur

4. **Utilisez un chemin absolu pour le socket Docker**:
   - Modifiez la configuration pour utiliser le chemin absolu complet vers le socket Docker
<!-- END_SECTION: connection_issues -->

<!-- START_SECTION: tool_execution_issues -->
## Problèmes d'exécution des outils

### Les commandes Docker échouent

**Symptôme**: Les outils du MCP Docker échouent avec des erreurs.

**Solutions possibles**:

1. **Vérifiez les logs du conteneur MCP**:
   ```powershell
   docker logs $(docker ps -q --filter "ancestor=mcp-server:local")
   ```

2. **Vérifiez les permissions**:
   - Assurez-vous que le conteneur MCP a les permissions nécessaires pour exécuter les commandes Docker

3. **Problèmes de syntaxe JSON**:
   - Vérifiez que les arguments JSON passés aux outils sont correctement formatés
   - Utilisez un validateur JSON pour vérifier la syntaxe

4. **Erreurs spécifiques aux commandes**:
   - Pour `docker_run`: Vérifiez que l'image existe et que les ports ne sont pas déjà utilisés
   - Pour `docker_rm`: Assurez-vous que le conteneur n'est pas en cours d'exécution ou utilisez `force: true`
   - Pour `docker_network_create`: Vérifiez que le nom du réseau n'est pas déjà utilisé
<!-- END_SECTION: tool_execution_issues -->

<!-- START_SECTION: common_errors -->
## Erreurs courantes

### Erreur: "Error response from daemon: conflict"

**Symptôme**: Erreur lors de la création d'un conteneur, d'un volume ou d'un réseau avec un nom déjà utilisé.

**Solutions**:
- Utilisez un nom différent
- Supprimez l'objet existant avant de le recréer
- Utilisez l'option `force: true` si disponible

### Erreur: "Error response from daemon: pull access denied"

**Symptôme**: Erreur lors du téléchargement d'une image depuis un registre privé.

**Solutions**:
- Connectez-vous au registre Docker:
  ```powershell
  docker login <registry-url>
  ```
- Vérifiez que vous avez les permissions nécessaires pour accéder à l'image

### Erreur: "Error response from daemon: port is already allocated"

**Symptôme**: Erreur lors du démarrage d'un conteneur car le port est déjà utilisé.

**Solutions**:
- Utilisez un port différent
- Arrêtez le service qui utilise déjà ce port
- Vérifiez les ports utilisés:
  ```powershell
  netstat -ano | findstr :<port>
  ```

### Erreur: "Error response from daemon: OCI runtime create failed"

**Symptôme**: Erreur lors du démarrage d'un conteneur due à des problèmes de configuration.

**Solutions**:
- Vérifiez les options de configuration du conteneur
- Vérifiez les volumes et montages
- Vérifiez les variables d'environnement
<!-- END_SECTION: common_errors -->

<!-- START_SECTION: performance_issues -->
## Problèmes de performance

### Le MCP Docker est lent

**Symptôme**: Les commandes Docker prennent beaucoup de temps à s'exécuter via le MCP.

**Solutions possibles**:

1. **Vérifiez les ressources allouées à Docker**:
   - Sur Windows/Mac, augmentez les ressources allouées à Docker Desktop (CPU, mémoire)

2. **Optimisez les images Docker**:
   - Utilisez des images plus légères basées sur Alpine Linux
   - Nettoyez régulièrement les images et conteneurs inutilisés:
     ```powershell
     docker system prune -a
     ```

3. **Réduisez la verbosité des logs**:
   - Configurez le niveau de log du MCP Docker pour réduire la quantité de données à traiter

4. **Utilisez des volumes pour améliorer les performances d'I/O**:
   - Montez des volumes Docker pour les opérations intensives en I/O
<!-- END_SECTION: performance_issues -->

<!-- START_SECTION: security_issues -->
## Problèmes de sécurité

### Vulnérabilités dans les images Docker

**Symptôme**: Des vulnérabilités sont détectées dans les images Docker utilisées.

**Solutions**:
- Mettez à jour régulièrement vos images Docker:
  ```powershell
  docker pull <image>:<tag>
  ```
- Utilisez des outils d'analyse de sécurité comme Trivy:
  ```powershell
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image <image>:<tag>
  ```
- Utilisez des images officielles et maintenez-les à jour

### Problèmes de permissions

**Symptôme**: Erreurs liées aux permissions lors de l'exécution de commandes Docker.

**Solutions**:
- Vérifiez que l'utilisateur a les permissions nécessaires pour accéder au socket Docker
- Sur Linux, ajoutez l'utilisateur au groupe Docker:
  ```bash
  sudo usermod -aG docker $USER
  ```
- Utilisez des utilisateurs non-root dans vos conteneurs
<!-- END_SECTION: security_issues -->

<!-- START_SECTION: advanced_troubleshooting -->
## Dépannage avancé

### Déboguer le conteneur MCP Docker

Pour déboguer le conteneur MCP Docker:

1. **Démarrez le conteneur en mode interactif**:
   ```powershell
   docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock mcp-server:local /bin/sh
   ```

2. **Vérifiez l'accès au socket Docker**:
   ```bash
   ls -la /var/run/docker.sock
   docker ps
   ```

3. **Examinez les logs du conteneur**:
   ```powershell
   docker logs $(docker ps -q --filter "ancestor=mcp-server:local") --tail 100
   ```

4. **Inspectez le conteneur**:
   ```powershell
   docker inspect $(docker ps -q --filter "ancestor=mcp-server:local")
   ```

### Déboguer les communications MCP

Pour déboguer les communications entre Roo et le MCP Docker:

1. **Activez le mode de débogage dans Roo**:
   - Consultez la documentation de Roo pour activer le mode de débogage

2. **Examinez les logs de Roo**:
   - Consultez les logs de VS Code pour voir les communications avec le MCP

3. **Testez la communication directement**:
   - Utilisez un client MCP de test pour vérifier la communication avec le serveur MCP Docker
<!-- END_SECTION: advanced_troubleshooting -->

<!-- START_SECTION: getting_help -->
## Obtenir de l'aide

Si vous ne parvenez pas à résoudre votre problème avec les solutions ci-dessus:

1. **Consultez la documentation officielle**:
   - [Documentation Docker](https://docs.docker.com/)
   - [Spécification MCP](https://github.com/modelcontextprotocol/mcp)

2. **Communauté et forums**:
   - [Forum de la communauté Roo](https://community.roo.ai)
   - [Docker Community Forums](https://forums.docker.com/)

3. **Signaler un bug**:
   - Ouvrez une issue sur le dépôt GitHub du MCP Docker
   - Incluez des informations détaillées sur le problème, les étapes pour le reproduire et les logs pertinents
<!-- END_SECTION: getting_help -->
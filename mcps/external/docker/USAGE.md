# Utilisation du MCP Docker

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille comment utiliser le MCP Docker avec Roo. Le MCP Docker permet à Roo d'interagir avec Docker pour gérer des conteneurs, des images, des volumes et des réseaux directement depuis l'interface de conversation.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: available_tools -->
## Outils disponibles

Le MCP Docker expose les outils suivants:

| Outil | Description |
|-------|-------------|
| `docker_run` | Exécute un conteneur Docker |
| `docker_ps` | Liste les conteneurs en cours d'exécution |
| `docker_stop` | Arrête un conteneur en cours d'exécution |
| `docker_rm` | Supprime un conteneur |
| `docker_images` | Liste les images Docker disponibles |
| `docker_pull` | Télécharge une image depuis un registre |
| `docker_build` | Construit une image à partir d'un Dockerfile |
| `docker_rmi` | Supprime une image |
| `docker_volume_ls` | Liste les volumes Docker |
| `docker_volume_create` | Crée un volume Docker |
| `docker_volume_rm` | Supprime un volume Docker |
| `docker_network_ls` | Liste les réseaux Docker |
| `docker_network_create` | Crée un réseau Docker |
| `docker_network_rm` | Supprime un réseau Docker |
| `docker_logs` | Affiche les logs d'un conteneur |
| `docker_exec` | Exécute une commande dans un conteneur en cours d'exécution |
| `docker_inspect` | Affiche des informations détaillées sur un objet Docker |
| `docker_compose_up` | Démarre des services définis dans un fichier docker-compose.yml |
| `docker_compose_down` | Arrête des services définis dans un fichier docker-compose.yml |
<!-- END_SECTION: available_tools -->

<!-- START_SECTION: basic_usage -->
## Utilisation de base

### Exécuter un conteneur

Pour exécuter un conteneur Docker:

```
Outil: docker_run
Arguments:
{
  "image": "nginx:latest",
  "detach": true,
  "ports": ["8080:80"],
  "name": "mon-nginx"
}
```

### Lister les conteneurs en cours d'exécution

Pour lister les conteneurs en cours d'exécution:

```
Outil: docker_ps
Arguments:
{
  "all": false
}
```

Pour lister tous les conteneurs (y compris ceux qui sont arrêtés):

```
Outil: docker_ps
Arguments:
{
  "all": true
}
```

### Arrêter un conteneur

Pour arrêter un conteneur en cours d'exécution:

```
Outil: docker_stop
Arguments:
{
  "container": "mon-nginx"
}
```

### Supprimer un conteneur

Pour supprimer un conteneur:

```
Outil: docker_rm
Arguments:
{
  "container": "mon-nginx",
  "force": true
}
```
<!-- END_SECTION: basic_usage -->

<!-- START_SECTION: image_management -->
## Gestion des images

### Lister les images

Pour lister les images Docker disponibles:

```
Outil: docker_images
Arguments: {}
```

### Télécharger une image

Pour télécharger une image depuis un registre:

```
Outil: docker_pull
Arguments:
{
  "image": "postgres:13"
}
```

### Construire une image

Pour construire une image à partir d'un Dockerfile:

```
Outil: docker_build
Arguments:
{
  "path": "/chemin/vers/dockerfile",
  "tag": "mon-app:latest"
}
```

### Supprimer une image

Pour supprimer une image:

```
Outil: docker_rmi
Arguments:
{
  "image": "mon-app:latest",
  "force": false
}
```
<!-- END_SECTION: image_management -->

<!-- START_SECTION: volume_management -->
## Gestion des volumes

### Lister les volumes

Pour lister les volumes Docker:

```
Outil: docker_volume_ls
Arguments: {}
```

### Créer un volume

Pour créer un volume Docker:

```
Outil: docker_volume_create
Arguments:
{
  "name": "mon-volume"
}
```

### Supprimer un volume

Pour supprimer un volume Docker:

```
Outil: docker_volume_rm
Arguments:
{
  "volume": "mon-volume"
}
```
<!-- END_SECTION: volume_management -->

<!-- START_SECTION: network_management -->
## Gestion des réseaux

### Lister les réseaux

Pour lister les réseaux Docker:

```
Outil: docker_network_ls
Arguments: {}
```

### Créer un réseau

Pour créer un réseau Docker:

```
Outil: docker_network_create
Arguments:
{
  "name": "mon-reseau",
  "driver": "bridge"
}
```

### Supprimer un réseau

Pour supprimer un réseau Docker:

```
Outil: docker_network_rm
Arguments:
{
  "network": "mon-reseau"
}
```
<!-- END_SECTION: network_management -->

<!-- START_SECTION: container_interaction -->
## Interaction avec les conteneurs

### Afficher les logs d'un conteneur

Pour afficher les logs d'un conteneur:

```
Outil: docker_logs
Arguments:
{
  "container": "mon-nginx",
  "tail": 100,
  "follow": false
}
```

### Exécuter une commande dans un conteneur

Pour exécuter une commande dans un conteneur en cours d'exécution:

```
Outil: docker_exec
Arguments:
{
  "container": "mon-nginx",
  "command": ["ls", "-la"],
  "interactive": false
}
```

### Inspecter un objet Docker

Pour afficher des informations détaillées sur un objet Docker:

```
Outil: docker_inspect
Arguments:
{
  "object": "mon-nginx",
  "type": "container"
}
```
<!-- END_SECTION: container_interaction -->

<!-- START_SECTION: docker_compose -->
## Docker Compose

### Démarrer des services

Pour démarrer des services définis dans un fichier docker-compose.yml:

```
Outil: docker_compose_up
Arguments:
{
  "path": "/chemin/vers/docker-compose.yml",
  "detach": true,
  "services": ["web", "db"]
}
```

### Arrêter des services

Pour arrêter des services définis dans un fichier docker-compose.yml:

```
Outil: docker_compose_down
Arguments:
{
  "path": "/chemin/vers/docker-compose.yml",
  "removeVolumes": false,
  "removeImages": "none"
}
```
<!-- END_SECTION: docker_compose -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

### Déploiement d'une application web

Voici un exemple de déploiement d'une application web avec une base de données:

1. Créer un réseau pour l'application:

```
Outil: docker_network_create
Arguments:
{
  "name": "app-network",
  "driver": "bridge"
}
```

2. Créer un volume pour la base de données:

```
Outil: docker_volume_create
Arguments:
{
  "name": "db-data"
}
```

3. Démarrer la base de données:

```
Outil: docker_run
Arguments:
{
  "image": "postgres:13",
  "detach": true,
  "name": "app-db",
  "env": ["POSTGRES_PASSWORD=secret", "POSTGRES_DB=app"],
  "volumes": ["db-data:/var/lib/postgresql/data"],
  "network": "app-network"
}
```

4. Démarrer l'application web:

```
Outil: docker_run
Arguments:
{
  "image": "mon-app:latest",
  "detach": true,
  "name": "app-web",
  "ports": ["8080:80"],
  "env": ["DB_HOST=app-db", "DB_PASSWORD=secret"],
  "network": "app-network"
}
```

### Surveillance des conteneurs

Pour surveiller l'état des conteneurs:

1. Lister les conteneurs en cours d'exécution:

```
Outil: docker_ps
Arguments: {
  "all": false
}
```

2. Vérifier les logs d'un conteneur spécifique:

```
Outil: docker_logs
Arguments: {
  "container": "app-web",
  "tail": 50
}
```

3. Inspecter les détails d'un conteneur:

```
Outil: docker_inspect
Arguments: {
  "object": "app-web",
  "type": "container"
}
```
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: best_practices -->
## Bonnes pratiques

### Nommage des conteneurs

Toujours nommer vos conteneurs pour faciliter leur identification et leur gestion:

```
Outil: docker_run
Arguments:
{
  "image": "nginx:latest",
  "name": "projet-nginx-prod",
  "detach": true
}
```

### Utilisation des tags spécifiques

Évitez d'utiliser le tag `latest` en production, préférez des tags spécifiques pour garantir la reproductibilité:

```
Outil: docker_pull
Arguments:
{
  "image": "node:16.14.2-alpine"
}
```

### Nettoyage régulier

Nettoyez régulièrement les conteneurs et images inutilisés pour économiser de l'espace disque:

```
Outil: docker_ps
Arguments:
{
  "all": true,
  "filter": "status=exited"
}
```

Puis supprimez les conteneurs arrêtés:

```
Outil: docker_rm
Arguments:
{
  "container": "ID_DU_CONTENEUR"
}
```

### Utilisation des volumes pour les données persistantes

Utilisez toujours des volumes pour les données qui doivent persister au-delà de la durée de vie du conteneur:

```
Outil: docker_run
Arguments:
{
  "image": "mysql:8",
  "volumes": ["mysql-data:/var/lib/mysql"],
  "detach": true
}
```
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: advanced_usage -->
## Utilisation avancée

### Limiter les ressources des conteneurs

Pour limiter les ressources utilisées par un conteneur:

```
Outil: docker_run
Arguments:
{
  "image": "nginx:latest",
  "name": "nginx-limited",
  "memory": "512m",
  "cpus": "0.5",
  "detach": true
}
```

### Utilisation des healthchecks

Pour configurer un healthcheck pour un conteneur:

```
Outil: docker_run
Arguments:
{
  "image": "postgres:13",
  "name": "db-with-health",
  "healthcheck": {
    "test": ["CMD", "pg_isready", "-U", "postgres"],
    "interval": "5s",
    "timeout": "3s",
    "retries": 5
  },
  "detach": true
}
```

### Utilisation des secrets Docker

Pour utiliser des secrets Docker avec un conteneur:

```
Outil: docker_run
Arguments:
{
  "image": "mon-app:latest",
  "name": "app-with-secrets",
  "secrets": ["app_secret"],
  "detach": true
}
```
<!-- END_SECTION: advanced_usage -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

### Conteneur qui ne démarre pas

Si un conteneur ne démarre pas:

1. Vérifiez les logs du conteneur:

```
Outil: docker_logs
Arguments:
{
  "container": "nom-du-conteneur"
}
```

2. Inspectez l'état du conteneur:

```
Outil: docker_inspect
Arguments:
{
  "object": "nom-du-conteneur",
  "type": "container"
}
```

### Problèmes de réseau

Si les conteneurs ne peuvent pas communiquer entre eux:

1. Vérifiez que les conteneurs sont sur le même réseau:

```
Outil: docker_inspect
Arguments:
{
  "object": "nom-du-conteneur",
  "type": "container",
  "format": "{{json .NetworkSettings.Networks}}"
}
```

2. Vérifiez l'état du réseau:

```
Outil: docker_network_ls
Arguments: {}
```

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: integration_with_roo -->
## Intégration avec Roo

Le MCP Docker s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Démarre un conteneur nginx sur le port 8080"
- "Montre-moi les conteneurs en cours d'exécution"
- "Arrête le conteneur mon-nginx"
- "Télécharge l'image postgres:13"
- "Crée un volume pour les données de ma base de données"
- "Montre-moi les logs du conteneur app-web"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP Docker.
<!-- END_SECTION: integration_with_roo -->

<!-- START_SECTION: performance_optimization -->
## Optimisation des performances

### Utilisation d'images légères

Préférez les images basées sur Alpine Linux pour réduire la taille et améliorer les performances:

```
Outil: docker_pull
Arguments:
{
  "image": "node:16-alpine"
}
```

### Multi-stage builds

Utilisez des builds multi-étapes pour réduire la taille finale de vos images:

```
# Exemple de Dockerfile multi-étapes
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
```

### Mise en cache des couches Docker

Organisez votre Dockerfile pour maximiser l'utilisation du cache:

```
# Bon exemple
COPY package*.json ./
RUN npm install
COPY . .

# Plutôt que
COPY . .
RUN npm install
```
<!-- END_SECTION: performance_optimization -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

### Utilisation d'utilisateurs non-root

Exécutez vos conteneurs avec des utilisateurs non-root:

```
Outil: docker_run
Arguments:
{
  "image": "mon-app:latest",
  "user": "1000:1000",
  "detach": true
}
```

### Limitation des capacités

Limitez les capacités de vos conteneurs:

```
Outil: docker_run
Arguments:
{
  "image": "mon-app:latest",
  "cap_drop": ["ALL"],
  "cap_add": ["NET_BIND_SERVICE"],
  "detach": true
}
```

### Analyse de sécurité des images

Analysez régulièrement vos images pour détecter les vulnérabilités:

```
Outil: docker_exec
Arguments:
{
  "container": "trivy",
  "command": ["trivy", "image", "mon-app:latest"]
}
```
<!-- END_SECTION: security_considerations -->
# Système de Surveillance Quotidienne Roo Extensions

## Vue d'ensemble

Le système de surveillance quotidienne Roo Extensions est un système automatisé complet qui assure la santé et la performance optimale de l'environnement de développement. Il combine plusieurs outils de diagnostic et de maintenance pour fournir une surveillance proactive.

## Architecture du système

### Composants principaux

1. **Script de surveillance principal** : `roo-config/daily-monitoring.ps1`
2. **Configuration Roo Scheduler** : `.roo/schedules.json`
3. **Scripts de maintenance existants** :
   - `roo-config/maintenance-routine.ps1`
   - `roo-config/mcp-diagnostic-repair.ps1`
4. **Système de logging** : `logs/daily-monitoring/`

### Fonctionnalités de surveillance

#### 1. Diagnostic Git
- Vérification du statut du dépôt
- Contrôle des branches et remotes
- Détection des conflits ou problèmes
- Validation de l'intégrité du dépôt

#### 2. Diagnostic MCP (Model Context Protocol)
- Validation de l'encodage des fichiers de configuration
- Vérification de la syntaxe JSON des paramètres MCP
- Test de l'état des serveurs MCP configurés
- Détection des problèmes de chemin ou de configuration

#### 3. Validation des configurations
- Vérification de la syntaxe JSON des fichiers critiques :
  - `roo-config/settings/settings.json`
  - `roo-config/settings/servers.json`
  - `roo-config/settings/modes.json`
  - `.roo/schedules.json`
- Détection des fichiers manquants ou corrompus
- Calcul du taux de validation global

#### 4. Nettoyage et maintenance
- Exécution du script de maintenance automatique
- Nettoyage des fichiers temporaires et de sauvegarde
- Suppression des logs anciens (> 30 jours)
- Optimisation de l'espace disque

#### 5. Vérification d'intégrité système
- Contrôle de l'espace disque disponible
- Test de connectivité réseau (GitHub, API GitHub)
- Vérification des ressources système
- Alertes en cas de problèmes critiques

#### 6. Génération de rapports
- Rapport de santé détaillé au format JSON
- Logs structurés avec horodatage
- Recommandations d'action automatiques
- Historique des exécutions

## Configuration

### Planification automatique

La surveillance est configurée pour s'exécuter quotidiennement à 8h00 via Roo Scheduler :

```json
{
  "name": "Surveillance Quotidienne Roo",
  "mode": "code",
  "scheduleType": "time",
  "timeInterval": "1",
  "timeUnit": "day",
  "startHour": "08",
  "startMinute": "00",
  "active": true
}
```

### Paramètres du script

Le script `daily-monitoring.ps1` accepte les paramètres suivants :

- `-Verbose` : Active l'affichage détaillé
- `-LogLevel` : Niveau de logging (INFO, WARNING, ERROR)

## Utilisation

### Exécution manuelle

```powershell
# Exécution standard
& "roo-config/daily-monitoring.ps1"

# Exécution avec sortie détaillée
& "roo-config/daily-monitoring.ps1" -Verbose

# Exécution avec niveau de log spécifique
& "roo-config/daily-monitoring.ps1" -LogLevel "DEBUG"
```

### Exécution automatique

La surveillance s'exécute automatiquement chaque jour à 8h00 via Roo Scheduler. Aucune intervention manuelle n'est requise.

## Système de logging

### Structure des logs

```
logs/daily-monitoring/
├── monitoring-YYYYMMDD.log          # Log quotidien structuré
└── health-report-YYYYMMDD-HHMMSS.json  # Rapport de santé détaillé
```

### Format des logs

Chaque entrée de log contient :
- `timestamp` : Horodatage précis
- `execution_id` : Identifiant unique d'exécution
- `level` : Niveau de log (INFO, SUCCESS, WARNING, ERROR)
- `component` : Composant source (GIT, MCP, CONFIG, CLEANUP, INTEGRITY)
- `message` : Message descriptif
- `data` : Données additionnelles (optionnel)

### Exemple d'entrée de log

```json
{
  "timestamp": "2025-05-26 15:29:52.255",
  "execution_id": "367ee698-fbf1-4dd9-9a92-278b817558ba",
  "level": "SUCCESS",
  "component": "MCP",
  "message": "MCPs en bon état",
  "data": {}
}
```

## Rapports de santé

### Structure du rapport

Le rapport de santé généré contient :

```json
{
  "execution_info": {
    "execution_id": "...",
    "start_time": "...",
    "end_time": "...",
    "duration_seconds": 10.55
  },
  "overall_status": "SUCCESS|WARNING|ERROR",
  "total_issues": 0,
  "components": {
    "git": {...},
    "mcp": {...},
    "configuration": {...},
    "cleanup": {...},
    "integrity": {...}
  },
  "summary": {
    "git_health": "SUCCESS",
    "mcp_health": "SUCCESS",
    "config_health": "SUCCESS",
    "cleanup_status": "SUCCESS",
    "integrity_status": "SUCCESS"
  },
  "recommendations": [...]
}
```

### Interprétation des statuts

- **SUCCESS** : Composant en parfait état
- **WARNING** : Problèmes mineurs détectés, surveillance recommandée
- **ERROR** : Problèmes critiques nécessitant une intervention

## Gestion des erreurs et recommandations

### Types d'erreurs courantes

1. **Problèmes Git** :
   - Conflits de fusion
   - Branches désynchronisées
   - Problèmes de connectivité

2. **Problèmes MCP** :
   - Encodage BOM incorrect
   - Syntaxe JSON invalide
   - Chemins de serveurs introuvables

3. **Problèmes de configuration** :
   - Fichiers JSON corrompus
   - Fichiers de configuration manquants
   - Paramètres invalides

4. **Problèmes système** :
   - Espace disque insuffisant
   - Connectivité réseau défaillante
   - Ressources système limitées

### Actions recommandées automatiques

Le système génère automatiquement des recommandations basées sur les problèmes détectés :

- **Problèmes Git** : "Vérifier et résoudre les problèmes Git détectés"
- **Problèmes MCP** : "Exécuter la réparation MCP avec: roo-config/mcp-diagnostic-repair.ps1 -Repair"
- **Problèmes de configuration** : "Vérifier et corriger les fichiers de configuration"
- **Problèmes d'intégrité** : "Vérifier l'espace disque et la connectivité réseau"

## Maintenance et optimisation

### Rotation des logs

- Les logs sont automatiquement organisés par date
- Les anciens logs (> 30 jours) sont supprimés automatiquement
- Les rapports de santé sont conservés pour l'historique

### Performance

- Durée d'exécution typique : 10-15 secondes
- Utilisation mémoire minimale
- Impact système négligeable
- Exécution en arrière-plan

### Surveillance de la surveillance

Le système s'auto-surveille et génère des métriques sur :
- Temps d'exécution
- Taux de succès
- Fréquence des erreurs
- Performance des composants

## Intégration avec l'écosystème Roo

### Compatibilité

- Compatible avec tous les modes Roo
- Intégration native avec Roo Scheduler
- Utilisation des outils de diagnostic existants
- Respect de l'architecture modulaire

### Extensibilité

Le système est conçu pour être facilement extensible :
- Ajout de nouveaux composants de surveillance
- Intégration de nouveaux scripts de maintenance
- Personnalisation des seuils d'alerte
- Extension des rapports de santé

## Dépannage

### Problèmes courants

1. **Script ne s'exécute pas** :
   - Vérifier les permissions PowerShell
   - Contrôler la configuration Roo Scheduler
   - Vérifier les chemins de fichiers

2. **Logs non générés** :
   - Vérifier l'existence du répertoire `logs/daily-monitoring/`
   - Contrôler les permissions d'écriture
   - Vérifier l'espace disque disponible

3. **Rapports incomplets** :
   - Vérifier la connectivité réseau
   - Contrôler l'état des scripts de maintenance
   - Vérifier les dépendances PowerShell

### Diagnostic manuel

```powershell
# Test des composants individuels
& "roo-config/mcp-diagnostic-repair.ps1" -Validate
& "roo-config/maintenance-routine.ps1"

# Vérification des logs
Get-Content "logs/daily-monitoring/monitoring-$(Get-Date -Format 'yyyyMMdd').log" | ConvertFrom-Json

# Test de connectivité
Test-NetConnection github.com -Port 443
Test-NetConnection api.github.com -Port 443
```

## Conclusion

Le système de surveillance quotidienne Roo Extensions fournit une solution complète et automatisée pour maintenir la santé de l'environnement de développement. Avec ses capacités de diagnostic avancées, son système de logging détaillé et ses recommandations automatiques, il assure une surveillance proactive et une maintenance préventive efficace.

La surveillance quotidienne contribue à :
- Prévenir les problèmes avant qu'ils ne deviennent critiques
- Maintenir des performances optimales
- Assurer la fiabilité du système
- Fournir une visibilité complète sur l'état de l'environnement
- Automatiser les tâches de maintenance répétitives

Ce système représente une approche moderne et intelligente de la surveillance d'infrastructure de développement, parfaitement intégrée à l'écosystème Roo Extensions.
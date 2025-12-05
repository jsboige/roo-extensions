# Guide de Dépannage - Roo Extensions Phase 3D

**Date**: 2025-12-04  
**Version**: 3D Final  
**Statut**: Production Ready

---

## 🔍 Problèmes Courants

### 1. Serveurs MCP ne démarrent pas

**Symptômes**:
- Erreur "serveur MCP non démarré"
- Timeout de connexion

**Solutions**:
`powershell
# Vérifier l'état des processus
Get-Process -Name "*node*" | Where-Object { .CommandLine -like "*mcp*" }

# Redémarrer les services MCP
.\scripts\monitoring\restart-all-mcps.ps1

# Vérifier les configurations
.\scripts\monitoring\validate-mcp-configs.ps1
`

### 2. Performance dégradée

**Symptômes**:
- Temps de réponse > 5 secondes
- Utilisation CPU > 90%
- Mémoire disponible < 1GB

**Solutions**:
`powershell
# Optimisation automatique
.\scripts\monitoring\performance-optimizer.ps1 -Optimize

# Nettoyage système
.\scripts\monitoring\system-cleanup.ps1

# Analyse des goulots d'étranglement
.\scripts\monitoring\bottleneck-analysis.ps1
`

### 3. Synchronisation RooSync échoue

**Symptômes**:
- Erreur de synchronisation
- Conflits de fichiers
- Timeout réseau

**Solutions**:
`powershell
# Diagnostic de synchronisation
.\scripts\roosync\diagnose-sync-issues.ps1

# Réinitialisation forcée
.\scripts\roosync\force-resync.ps1

# Validation de configuration
.\scripts\roosync\validate-config.ps1
`

---

## 🛠️ Outils de Diagnostic

### Scripts de Diagnostic
- .\scripts\monitoring\system-health-check.ps1 - Santé système complète
- .\scripts\monitoring\mcp-diagnostic.ps1 - Diagnostic MCP détaillé
- .\scripts\roosync\sync-validator.ps1 - Validation synchronisation

### Logs Importants
- logs\advanced-monitoring-*.log - Monitoring système
- logs\mcp-*.log - Logs des serveurs MCP
- logs\roosync-*.log - Logs de synchronisation

---

## 📊 Métriques et Monitoring

### Indicateurs Clés
- **Disponibilité MCP**: > 95%
- **Temps de réponse**: < 2 secondes
- **Utilisation CPU**: < 80%
- **Mémoire disponible**: > 2GB

### Tableau de Bord
- URL: http://localhost:8080
- Métriques temps réel
- Alertes configurables
- Actions correctives

---

## 🚞 Procédures de Récupération

### Récupération Complète
`powershell
# Arrêt de tous les services
.\scripts\emergency\stop-all-services.ps1

# Nettoyage complet
.\scripts\emergency\full-cleanup.ps1

# Redémarrage contrôlé
.\scripts\emergency\controlled-restart.ps1
`

### Récupération Partielle
`powershell
# Redémarrage MCPs uniquement
.\scripts\monitoring\restart-mcps.ps1

# Reconstruction configuration
.\scripts\roosync\rebuild-config.ps1

# Validation post-récupération
.\scripts\monitoring\post-recovery-validation.ps1
`

---

## 📞 Support Avancé

### Collecte d'Informations
`powershell
# Rapport de diagnostic complet
.\scripts\support\generate-diagnostic-report.ps1

# Export des logs récents
.\scripts\support\export-recent-logs.ps1 -Days 7

# Capture d'état système
.\scripts\support\capture-system-state.ps1
`

### Contact Support
- Logs: logs\support\
- Rapports: eports\support\
- Configuration: oo-config\support\

---

**Dernière mise à jour**: 2025-12-04 22:54:50  
**Version**: 3D Final

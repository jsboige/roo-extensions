# Guide de Démarrage Rapide - Roo Extensions Phase 3D

**Date**: 2025-12-04  
**Version**: 3D Final  
**Statut**: Production Ready

---

## 🚀 Installation Rapide

### Prérequis
- Windows 10/11 ou Windows Server 2019+
- PowerShell 5.1 ou supérieur
- Node.js 18+ (pour les MCPs)
- Git 2.40+

### Installation
1. Cloner le dépôt:
   `powershell
   git clone <repository-url>
   cd roo-extensions
   `

2. Exécuter le script d'installation:
   `powershell
   .\scripts\setup\install-all.ps1
   `

3. Configurer l'environnement:
   `powershell
   .\roo-config\setup-environment.ps1
   `

---

## 🔧 Utilisation Quotidienne

### Monitoring du Système
`powershell
# Démarrer le monitoring complet
.\scripts\monitoring\advanced-monitoring.ps1 -Continuous

# Tableau de bord web
.\scripts\monitoring\dashboard-generator.ps1 -Serve -Port 8080
`

### Synchronisation RooSync
`powershell
# Synchroniser avec la baseline
.\scripts\roosync\roosync_update_baseline.ps1

# Exporter la configuration
.\scripts\roosync\roosync_export_baseline.ps1
`

### Gestion des MCPs
`powershell
# Vérifier l'état des serveurs MCP
.\scripts\monitoring\monitor-mcp-servers.ps1

# Redémarrer un serveur MCP
.\scripts\monitoring\restart-mcp-server.ps1 -ServerName "roo-state-manager"
`

---

## 📊 Tableau de Bord

Accédez au tableau de bord web:
- **URL**: http://localhost:8080
- **Rafraîchissement**: Automatique toutes les 30 secondes
- **Fonctionnalités**: Métriques temps réel, alertes, contrôles

---

## 🚨 Alertes et Dépannage

### Types d'Alertes
- **CPU**: Utilisation > 80%
- **Mémoire**: Disponible < 2GB
- **Disque**: Espace libre < 10%
- **MCP**: Serveur non répondant

### Actions Correctives
1. **CPU élevé**: Redémarrer les processus non critiques
2. **Mémoire faible**: Nettoyer les fichiers temporaires
3. **MCP down**: Utiliser le script de récupération automatique

---

## 📞 Support

### Documentation Complète
- Guide technique: docs\technical-guide.md
- Références API: docs\api-reference.md
- Dépannage: docs\troubleshooting.md

### Rapports et Logs
- Logs système: logs\
- Rapports: eports\
- Configuration: oo-config\

---

**Dernière mise à jour**: 2025-12-04 22:54:50  
**Version**: 3D Final

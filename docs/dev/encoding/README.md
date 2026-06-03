# Documentation Architecture d'Encodage Unifiée

Ce répertoire contient l'ensemble de la documentation technique, fonctionnelle et opérationnelle relative au projet d'unification de l'encodage UTF-8.

## 📚 Index de la Documentation

### Architecture & Spécifications
- Architecture Complète : Vue d'ensemble détaillée de l'architecture cible.
- Architecture Unifiée : Principes directeurs et standards.
- Spécifications Techniques Composants : Détails techniques par composant.
- Feuille de Route Implémentation : Planning et phases du projet.

### Guides Opérationnels
- [Quick Start Encoding](quick-start-encoding.md) : Guide de démarrage rapide pour les nouveaux utilisateurs.
- [Procédures de Maintenance](maintenance-procedures.md) : Tâches récurrentes et vérifications.
- [Guide de Dépannage (Troubleshooting)](troubleshooting-guide.md) : Résolution des problèmes courants.
- [Guide de Rollback Phase 1](archive/guide-rollback-phase1.md) : Procédures de retour arrière.

### Documentation Technique Détaillée
- [EncodingManager](archive/documentation-technique-encodingmanager-20251030.md) : Documentation du module PowerShell central.
- [Variables d'Environnement](archive/documentation-variables-environnement-20251030.md) : Configuration des variables système et utilisateur.
- [Profils PowerShell](archive/documentation-profiles-powershell-20251030.md) : Gestion des profils $PROFILE.
- [VSCode UTF-8](archive/documentation-vscode-utf8.md) : Configuration de l'éditeur et du terminal intégré.
- Modifications Registre : Clés de registre impactées.
- Activation UTF-8 : Mécanismes d'activation globale.
- [Monitoring](archive/documentation-monitoring.md) : Surveillance de la conformité.

### Rapports & Suivi
- [Matrice de Traçabilité Environnement](archive/matrice-tracabilite-environnement-20251030.md) : Suivi des exigences environnementales.
- Matrice de Traçabilité Corrections : Suivi des correctifs appliqués.
- Rapport Diagnostic OS : État initial du système.
- Procédures Validation Diagnostic : Méthodologie de test.

## 🚀 Scripts Principaux

Les scripts d'administration se trouvent dans `scripts/encoding/` :

- `Initialize-EncodingManager.ps1` : Installation et configuration initiale.
- `Test-EncodingIntegration.ps1` : Validation complète de l'environnement.
- `Maintenance-VerifyConfig.ps1` : Vérification de routine.
- `Set-StandardizedEnvironment.ps1` : Application des variables d'environnement.

## 📞 Support

Pour toute question ou problème non couvert par cette documentation, veuillez vous référer au [Guide de Dépannage](troubleshooting-guide.md) ou contacter l'équipe d'architecture.
# Roo Extensions

Ce dépôt contient des extensions pour Roo, notamment des modes personnalisés optimisés pour différents modèles de langage.

## Architecture à Deux Niveaux (Simple/Complexe)

Le projet implémente une architecture innovante qui dédouble chaque profil d'agent Roo en deux versions :

- **Version Simple** : Utilise des modèles moins coûteux (comme Claude 3.5 Sonnet) pour les tâches basiques
  - Modifications de code mineures
  - Bugs simples
  - Documentation basique
  - Questions factuelles
  - Tâches bien définies

- **Version Complexe** : Utilise des modèles plus avancés (comme Claude 3.7 Sonnet) pour les tâches nécessitant des capacités supérieures
  - Refactoring majeur
  - Conception d'architecture
  - Optimisation de performance
  - Analyses approfondies
  - Problèmes complexes

Cette approche permet d'optimiser les coûts d'utilisation tout en maintenant la qualité des résultats, en dirigeant chaque tâche vers le modèle le plus approprié selon sa complexité.

## Installation et Utilisation

### Prérequis

- Roo installé et configuré
- Accès aux modèles Claude 3.5 Sonnet et Claude 3.7 Sonnet

### Installation

1. Clonez ce dépôt :
   ```bash
   git clone https://github.com/votre-utilisateur/roo-extensions.git
   ```

2. Utilisez le script de déploiement automatisé pour installer les modes personnalisés :
   ```powershell
   .\roo-modes\scripts\deploy-roo-modes.ps1 -DeploymentType both
   ```
   
   Ou copiez manuellement le fichier `.roomodes` dans le répertoire approprié de votre installation Roo :
   ```bash
   cp .roomodes [chemin-vers-votre-dossier-roo-settings]
   ```

3. Redémarrez Roo pour appliquer les nouveaux modes.

Pour plus de détails, consultez le [Guide d'installation et de configuration des modes personnalisés](roo-modes/docs/implementation/guide-installation-modes-personnalises.md).

### Utilisation

Les modes personnalisés apparaîtront dans l'interface de Roo et peuvent être sélectionnés comme n'importe quel autre mode.

- Pour les tâches simples, sélectionnez la version "Simple" du mode approprié
- Pour les tâches complexes, sélectionnez la version "Complexe"
- L'Orchestrateur peut également router automatiquement les tâches vers le mode approprié

## Structure du Projet

- `.roomodes` : Configuration des modes personnalisés
- `roo-modes/` : Répertoire principal pour les modes personnalisés
  - `configs/` : Configurations des modes
  - `docs/` : Documentation conceptuelle et guides
    - `implementation/` : Guides d'implémentation et de déploiement
      - `guide-installation-modes-personnalises.md` : Guide complet d'installation et de configuration
  - `examples/` : Exemples de configurations
  - `scripts/` : Scripts de déploiement
    - `deploy-roo-modes.ps1` : Script automatisé pour le déploiement des modes personnalisés
  - `tests/` : Tests pour les modes personnalisés
- `custom-modes/` : [OBSOLÈTE] Redirigé vers roo-modes
- `optimized-agents/` : [OBSOLÈTE] Redirigé vers roo-modes
- `roo-config/` : [OBSOLÈTE] Redirigé vers roo-modes
- `scheduler/` : Extensions et configurations pour Roo Scheduler
<<<<<<< HEAD
- `external-mcps/` : Configuration et documentation pour les MCPs externes
=======
- `external-mcps/` : Configuration et documentation pour les MCPs externes
>>>>>>> 6bb8c4a8d5ed77761b5c2552312f55a719a7082b

## Modes Disponibles

| Mode | Version Simple | Version Complexe |
|------|----------------|------------------|
| Code | Modifications mineures, bugs simples | Refactoring, architecture, optimisation |
| Debug | Erreurs de syntaxe, bugs évidents | Bugs concurrents, performance, problèmes système |
| Architect | Documentation simple, diagrammes basiques | Conception système, migrations complexes |
| Ask | Questions factuelles, explications basiques | Analyses approfondies, synthèses complexes |
| Orchestrator | Tâches simples, délégation basique | Tâches complexes, coordination avancée |

## Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Forkez le dépôt
2. Créez une branche pour votre fonctionnalité
3. Soumettez une pull request

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.
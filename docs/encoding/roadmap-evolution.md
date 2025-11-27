# Roadmap Évolution : Architecture d'Encodage

Ce document trace les pistes d'amélioration futures pour l'architecture d'encodage unifiée, au-delà de la Phase 4 actuelle.

## 🔮 Court Terme (Q1 2026)

### 1. Intégration Native RooSync
- **Objectif** : Synchroniser l'état de l'encodage entre plusieurs machines via RooSync.
- **Action** : Étendre le schéma de données RooSync pour inclure les métriques d'encodage (`EncodingStatus`).
- **Bénéfice** : Visibilité centralisée de la conformité du parc de développement.

### 2. Support Étendu des Langages
- **Objectif** : Ajouter des validateurs spécifiques pour d'autres langages.
- **Cibles** :
  - **Rust** : Vérification de l'encodage des sources (`.rs`) et configuration Cargo.
  - **Go** : Vérification des sources (`.go`).
- **Action** : Créer des modules de validation pluggables dans `EncodingManager`.

## 🔭 Moyen Terme (Q2-Q3 2026)

### 3. Auto-Guérison (Self-Healing) Avancée
- **Objectif** : Corriger automatiquement les dérives de configuration sans intervention humaine.
- **Action** : Transformer les alertes du `MonitoringService` en déclencheurs d'actions correctives (ex: réappliquer le profil PowerShell si modifié).
- **Risque** : Nécessite une gestion fine des conflits pour ne pas écraser des configurations utilisateur légitimes.

### 4. Extension VSCode Dédiée
- **Objectif** : Offrir une interface graphique dans VSCode pour gérer l'encodage.
- **Action** : Développer une extension VSCode qui encapsule les scripts PowerShell et affiche le dashboard en temps réel dans la barre d'état.

## 🚀 Long Terme

### 5. Standardisation OS
- **Objectif** : S'affranchir des configurations spécifiques Windows.
- **Action** : Explorer les conteneurs de développement (DevContainers) pré-configurés en UTF-8 natif (Linux) pour isoler complètement l'environnement de développement du système hôte Windows.
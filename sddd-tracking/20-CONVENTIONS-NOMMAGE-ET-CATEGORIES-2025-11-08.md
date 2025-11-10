# 📝 Conventions de Nommage et Catégories pour Dossiers de Suivi
**Date** : 7 novembre 2025  
**Version** : 1.0  
**Auteur** : Assistant Roo (Mode Architect)

---

## 🎯 Objectif

Établir des conventions cohérentes et standardisées pour tous les dossiers de suivi du projet roo-extensions, afin de garantir :
- La **lisibilité** et la **compréhension** immédiate
- La **navigation** intuitive et efficace
- La **maintenance** simplifiée
- L'**évolutivité** pour futures machines et projets

---

## 📋 Catégories Principales de Documents

### 📊 Rapports Opérationnels
Documents qui décrivent l'état, les performances, les incidents et les activités opérationnelles.

**Types** :
- `daily` : Rapports quotidiens
- `weekly` : Rapports hebdomadaires  
- `monthly` : Rapports mensuels
- `quarterly` : Rapports trimestriels
- `annual` : Rapports annuels
- `special` : Rapports d'incidents ou d'événements exceptionnels
- `synthesis` : Synthèses et analyses

### 🔧 Rapports Techniques
Documents qui décrivent les aspects techniques, configurations, tests et validations.

**Types** :
- `analysis` : Analyses techniques et d'architecture
- `validation` : Tests de conformité et validation
- `optimization` : Rapports d'optimisation et performance
- `configuration` : Rapports de configuration et déploiement
- `troubleshooting` : Dépannage et résolution de problèmes
- `audit` : Audits complets et inventaires

### 📚 Documentation
Documents qui décrivent le système, les processus et les guides d'utilisation.

**Types** :
- `guide` : Guides d'utilisation (utilisateurs, administrateurs)
- `architecture` : Documentation technique et architecture
- `conventions` : Conventions et standards
- `process` : Description des processus et workflows
- `migration` : Guides de migration et transition

### 🧪 Scripts et Outils
Scripts, outils et utilitaires pour l'automatisation et la maintenance.

**Types** :
- `automation` : Scripts d'automatisation
- `monitoring` : Scripts de surveillance
- `maintenance` : Scripts de maintenance
- `deployment` : Scripts de déploiement
- `backup` : Scripts de sauvegarde
- `analysis` : Outils d'analyse

---

## 🏷️ Conventions de Nommage

### Format des Dates
**Standard** : `YYYY-MM-DD` (ISO 8601)
**Exemples** :
- `2025-11-07`
- `2025-12-25`

### Format des Fichiers

#### 📊 Rapports Opérationnels
**Format** : `YYYY-MM-DD-TYPE-TITLE.md`
**Exemples** :
- `2025-11-07-daily-operations.md`
- `2025-11-07-weekly-performance.md`
- `2025-11-07-monthly-synthesis.md`
- `2025-11-07-special-incident-critique.md`
- `2025-11-07-quarterly-review.md`
- `2025-11-07-annual-report.md`

#### 🔧 Rapports Techniques
**Format** : `YYYY-MM-DD-TECHNICAL-TYPE-SUBJECT.md`
**Exemples** :
- `2025-11-07-technical-analysis-architecture.md`
- `2025-11-07-technical-validation-tests.md`
- `2025-11-07-technical-optimization-performance.md`
- `2025-11-07-technical-configuration-deployment.md`
- `2025-11-07-technical-troubleshooting-jupyter.md`

#### 📚 Documentation
**Format** : `YYYY-MM-DD-DOC-TYPE-SUBJECT.md`
**Exemples** :
- `2025-11-07-doc-guide-user-onboarding.md`
- `2025-11-07-doc-architecture-system-design.md`
- `2025-11-07-doc-conventions-naming-standards.md`
- `2025-11-07-doc-process-workflow-escalation.md`

#### 🧪 Scripts et Outils
**Format** : `ACTION-TARGET-DESCRIPTION.ps1`
**Exemples** :
- `monitor-daily-system-checks.ps1`
- `deploy-environment-staging.ps1`
- `backup-database-incremental.ps1`
- `analyze-performance-bottlenecks.ps1`

### 🗂️ Conventions de Répertoires

#### Structure par Machine
```
tracking/machines/[MACHINE-NAME]/
├── reports/                    # Rapports opérationnels
│   ├── daily/               # Quotidiens
│   ├── weekly/              # Hebdomadaires
│   ├── monthly/              # Mensuels
│   ├── special/              # Incidents
│   └── synthesis/           # Synthèses
├── scripts/                   # Scripts d'automatisation
│   ├── monitoring/           # Surveillance
│   ├── maintenance/          # Maintenance
│   └── deployment/          # Déploiement
├── synthesis/                  # Analyses et synthèses
│   ├── performance/         # Analyses de performance
│   ├── troubleshooting/      # Dépannage
│   └── trends/             # Analyses de tendances
└── archive/                   # Archives historiques
    ├── 2025/               # Par année
    ├── 2024/               # Archives précédentes
    └── legacy/              # Archives anciennes
```

#### Structure par Type
```
tracking/
├── reports/                    # Tous les rapports centralisés
│   ├── operational/          # Rapports opérationnels
│   ├── technical/            # Rapports techniques
│   └── synthesis/            # Synthèses globales
├── documentation/              # Documentation système
├── scripts/                   # Scripts et outils
└── archive/                   # Archives historiques
```

---

## 🏷️ Règles de Priorité

### 🚨 Niveau d'Urgence
1. **Critique** : Incident majeur, sécurité, perte de données
2. **Haute** : Impact significatif sur les opérations
3. **Moyenne** : Problème courant, dégradation modérée
4. **Basse** : Amélioration, optimisation, documentation

### 📊 Périodicité de Traitement
1. **Immédiat** : Traiter dans l'heure
2. **Quotidien** : Traiter avant la fin de journée
3. **Hebdomadaire** : Traiter avant la fin de semaine
4. **Mensuel** : Traiter avant la fin de mois
5. **Trimestriel** : Traiter avant la fin de trimestre

---

## 🔄 Règles d'Évolution

### 🖥️ Ajout de Nouvelles Machines
1. Créer le répertoire `tracking/machines/[MACHINE-NAME]/`
2. Copier les modèles de scripts et de rapports
3. Adapter les conventions de nommage si nécessaire
4. Mettre à jour l'index principal

### 📈 Extension des Catégories
1. Proposer de nouveaux types de documents en fonction des besoins
2. Ajouter les formats correspondants dans les conventions
3. Créer les modèles associés
4. Documenter les nouvelles conventions

### 🗂️ Archivage
1. Déplacer les documents de plus d'un an vers `archive/[YYYY]/`
2. Conserver les documents de l'année en cours dans les répertoires actifs
3. Créer un index des archives par année

---

## 📋 Checklist de Qualité

### ✅ Validation de Document
- [ ] Le titre est clair et descriptif
- [ ] La date est correcte et au format ISO
- [ ] Le type correspond à la catégorie
- [ ] Le contenu est structuré logiquement
- [ ] Les références internes sont valides

### ✅ Validation de Conformité
- [ ] Le fichier suit les conventions de nommage
- [ ] Le répertoire respecte la structure hiérarchique
- [ ] Les liens relatifs fonctionnent
- [ ] L'archivage respecte les règles

### ✅ Validation d'Accessibilité
- [ ] Le document est accessible depuis l'index principal
- [ ] Le chemin est relatif et fonctionne sur tous les systèmes
- [ ] Les caractères spéciaux sont évités dans les noms
- [ ] La taille du fichier est raisonnable

---

## 🎯 Recommandations d'Usage

### 👤 Pour les Utilisateurs
1. **Commencer par l'INDEX** : Toujours utiliser le point d'entrée principal
2. **Utiliser la recherche** : Les noms de fichiers sont standardisés pour faciliter la recherche
3. **Suivre les dates** : Les documents sont organisés chronologiquement
4. **Consulter les synthèses** : Pour une vue d'ensemble rapide

### 🔧 Pour les Administrateurs
1. **Appliquer les conventions** : Respecter scrupuleusement les formats établis
2. **Maintenir l'index** : Mettre à jour les liens lors d'ajouts/suppressions
3. **Archiver régulièrement** : Déplacer les anciens documents vers les archives
4. **Documenter les changements** : Conserver un historique des modifications

### 🧪 Pour les Développeurs
1. **Utiliser les modèles** : Partir des modèles existants pour garantir la cohérence
2. **Valider avant commit** : Utiliser la checklist de qualité
3. **Automatiser quand possible** : Réutiliser les scripts existants
4. **Centraliser les connaissances** : Documenter les apprentissages dans les synthèses

---

*Document créé le 7 novembre 2025*
*Version 1.0 - Prêt pour implémentation*
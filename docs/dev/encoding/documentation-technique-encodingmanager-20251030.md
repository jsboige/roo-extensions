# Documentation Technique : EncodingManager

**Date**: 2025-11-26
**Version**: 1.1.0
**Auteur**: Roo Architect
**Statut**: Déployé

## 1. Vue d'ensemble

EncodingManager est le composant central de l'architecture d'encodage unifiée de Roo Extensions. Il assure la gestion cohérente de l'encodage UTF-8 à travers les différents environnements (PowerShell, Node.js, VSCode).

### Objectifs
- Garantir l'utilisation de UTF-8 (CodePage 65001) par défaut.
- Fournir des outils de validation et de conversion d'encodage.
- Surveiller et corriger automatiquement les dérives de configuration.

## 2. Architecture

Le module est structuré en plusieurs composants clés :

### 2.1 Core (TypeScript/Node.js)
- **EncodingManager.ts** : Point d'entrée principal. Orchestre la configuration, la validation et le monitoring.
- **ConfigurationManager.ts** : Gère le chargement et la sauvegarde de la configuration (`encoding-config.json`).
- **UnicodeValidator.ts** : Valide les chaînes de caractères et les fichiers pour s'assurer qu'ils sont conformes à UTF-8.
- **MonitoringService.ts** : Surveille l'état de l'encodage système et détecte les anomalies.

### 2.2 Intégration (PowerShell)
- **Deploy-EncodingManager.ps1** : Script d'installation et de déploiement automatisé.
- **Configure-Monitoring.ps1** : Script d'activation et de configuration du monitoring.

### Structure des fichiers
```
modules/EncodingManager/
├── src/
│   ├── core/
│   │   ├── EncodingManager.ts       # Classe principale
│   │   └── ConfigurationManager.ts  # Gestion configuration
│   ├── validation/
│   │   └── UnicodeValidator.ts      # Validation UTF-8
│   └── monitoring/
│       └── MonitoringService.ts     # Service de surveillance
├── tests/                           # Tests unitaires (Jest)
├── dist/                            # Code compilé (JS/d.ts)
├── encoding-config.json             # Fichier de configuration
└── package.json                     # Définition du package NPM
```

## 3. Installation et Utilisation

### Prérequis
- Node.js 16+
- PowerShell 7+ (recommandé)

### Installation
Exécuter le script de déploiement :
```powershell
.\scripts\encoding\Deploy-EncodingManager.ps1
```

### Utilisation Programmatique (TypeScript)
```typescript
import { EncodingManager } from '@roo/encoding-manager';

const manager = new EncodingManager();

// Conversion
const result = manager.convert(inputString, 'utf-8');
if (result.success) {
    console.log(result.data);
}

// Validation
const isValid = manager.validate(inputString);
```

### Configuration
Le fichier `encoding-config.json` permet de personnaliser le comportement :
```json
{
    "defaultEncoding": "utf-8",
    "validationMode": "strict",
    "fallbackEncoding": "windows-1252",
    "monitoringEnabled": true,
    "logLevel": "info"
}
```

## 4. Monitoring

Le service de monitoring vérifie périodiquement (par défaut toutes les minutes) :
- La page de code système (doit être 65001).
- L'encodage des processus actifs.

Les anomalies sont signalées via des événements émis par `MonitoringService`.

## 5. Tests

Les tests unitaires sont exécutés avec Jest :
```bash
npm test
```
Couverture actuelle : 100% des scénarios critiques.
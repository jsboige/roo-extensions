# Documentation Technique : EncodingManager

**Date**: 2025-11-26
**Version**: 1.0.0
**Auteur**: Roo Architect
**Statut**: Déployé

## 1. Vue d'ensemble

EncodingManager est le composant central de l'architecture d'encodage unifiée de Roo Extensions. Il assure la gestion cohérente de l'encodage UTF-8 à travers les différents environnements (PowerShell, Node.js, VSCode).

### Objectifs
- Garantir l'utilisation de UTF-8 (CodePage 65001) par défaut.
- Fournir des outils de validation et de conversion d'encodage.
- Surveiller et corriger automatiquement les dérives de configuration.

## 2. Architecture

Le module est structuré en deux parties principales :
1.  **Core (TypeScript/Node.js)** : Logique métier, validation, conversion.
2.  **Intégration (PowerShell)** : Scripts de démarrage, configuration de l'environnement, monitoring.

### Structure des fichiers
```
modules/EncodingManager/
├── src/
│   ├── core/
│   │   └── EncodingManager.ts       # Classe principale
│   └── validation/
│       └── UnicodeValidator.ts      # Validation UTF-8
├── dist/                            # Code compilé (JS/d.ts)
├── package.json                     # Dépendances et scripts
└── tsconfig.json                    # Configuration TypeScript

scripts/encoding/
├── Initialize-EncodingManager.ps1   # Script d'initialisation de session
├── Register-EncodingManager.ps1     # Script d'installation/enregistrement
└── Configure-EncodingMonitoring.ps1 # Configuration de la tâche planifiée
```

## 3. API TypeScript

### EncodingManager
```typescript
interface EncodingConfig {
    defaultEncoding: string;      // 'utf-8'
    validationMode: 'strict' | 'lax';
    fallbackEncoding: string;
}

class EncodingManager {
    constructor(config?: Partial<EncodingConfig>);
    convert(input: string, targetEncoding?: string): EncodingResult;
    validate(input: string): boolean;
    getConfig(): EncodingConfig;
}
```

### UnicodeValidator
```typescript
class UnicodeValidator {
    isValidUTF8(input: Buffer | string): boolean;
    hasBOM(input: Buffer): boolean;
}
```

## 4. Intégration PowerShell

### Initialisation
Le script `Initialize-EncodingManager.ps1` est appelé par les profils PowerShell. Il effectue les actions suivantes :
1.  Définit `[Console]::OutputEncoding` et `[Console]::InputEncoding` sur UTF-8.
2.  Définit `$OutputEncoding` sur UTF-8.
3.  Configure les variables d'environnement (`PYTHONIOENCODING`, `LANG`, `LC_ALL`).

### Monitoring
Le script `Configure-EncodingMonitoring.ps1` crée une tâche planifiée Windows (`RooEncodingMonitor`) qui :
- S'exécute au démarrage de session et toutes les heures.
- Vérifie que `[Console]::OutputEncoding.CodePage` est égal à 65001.
- Signale une erreur en cas de dérive.

## 5. Guide de Dépannage

### Problème : Caractères incorrects dans la console
**Solution** :
1.  Vérifier que la police du terminal supporte les caractères (ex: Cascadia Code).
2.  Exécuter `[Console]::OutputEncoding.CodePage` dans PowerShell. Le résultat doit être `65001`.
3.  Si ce n'est pas le cas, exécuter `. scripts/encoding/Initialize-EncodingManager.ps1`.

### Problème : Erreur "EncodingManager introuvable"
**Solution** :
1.  Vérifier que le module est compilé : `Test-Path modules/EncodingManager/dist`.
2.  Si non, exécuter `scripts/encoding/Register-EncodingManager.ps1`.

## 6. Maintenance

### Compilation
Pour recompiler le module après modification des sources TypeScript :
```powershell
cd modules/EncodingManager
npm run build
```

### Tests
Pour exécuter les tests d'intégration :
```powershell
pwsh -File tests/encoding/Test-EncodingManagerIntegration.ps1
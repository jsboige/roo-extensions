# Outils de déploiement et correction d'encodage pour Roo

Ce répertoire contient un ensemble d'outils pour déployer les modes Roo (simple et complex) sur Windows et résoudre les problèmes d'encodage courants.

## Problématique

Le déploiement des modes Roo sur Windows peut rencontrer des problèmes d'encodage, notamment pour les caractères accentués et les emojis. Ces problèmes peuvent rendre les fichiers JSON invalides et empêcher le chargement correct des modes dans Visual Studio Code.

## Structure des outils

### Organisation des dossiers

- **`encoding-scripts/`** - Scripts de correction d'encodage
- **`deployment-scripts/`** - Scripts de déploiement des modes
- **`diagnostic-scripts/`** - Scripts de diagnostic et vérification
- **`config-templates/`** - Modèles de fichiers de configuration
- **`docs/`** - Documentation supplémentaire
- **`modes/`** - Fichiers de modes standards
- **`qwen3-profiles/`** - Profils pour le modèle Qwen3
- **`scheduler/`** - Configuration du planificateur
- **`settings/`** - Paramètres de configuration
- **`backups/`** - Fichiers de sauvegarde

### Scripts de déploiement

- **`deployment-scripts/simple-deploy.ps1`** - Script simplifié pour déployer les modes avec l'option force
- **`deployment-scripts/deploy-modes-simple-complex.ps1`** - Script principal de déploiement avec gestion améliorée de l'encodage
- **`deployment-scripts/deploy-modes-enhanced.ps1`** - Version améliorée du script de déploiement
- **`deployment-scripts/force-deploy-with-encoding-fix.ps1`** - Script qui force le déploiement avec correction d'encodage
- **`deployment-scripts/create-clean-modes.ps1`** - Script pour créer des modes propres

### Scripts de correction d'encodage

- **`encoding-scripts/fix-encoding-simple.ps1`** - Correction simple des problèmes d'encodage courants
- **`encoding-scripts/fix-encoding-complete.ps1`** - Correction complète des caractères mal encodés et des emojis
- **`encoding-scripts/fix-encoding-advanced.ps1`** - Correction avancée avec plus d'options
- **`encoding-scripts/fix-encoding-direct.ps1`** - Correction directe des caractères problématiques
- **`encoding-scripts/fix-encoding-regex.ps1`** - Correction utilisant des expressions régulières
- **`encoding-scripts/fix-encoding-final.ps1`** - Version finale et optimisée de la correction d'encodage
- **`encoding-scripts/fix-source-encoding.ps1`** - Correction de l'encodage des fichiers source

### Scripts de vérification

- **`diagnostic-scripts/check-deployed-encoding.ps1`** - Vérifie l'encodage du fichier déployé
- **`diagnostic-scripts/verify-deployed-modes.ps1`** - Vérifie les modes déployés et leur encodage
- **`diagnostic-scripts/encoding-diagnostic.ps1`** - Diagnostic complet des problèmes d'encodage
- **`diagnostic-scripts/diagnostic-rapide-encodage.ps1`** - Outil de diagnostic rapide avec correction automatique

### Outils interactifs

- **`deployment-scripts/deploy-guide-interactif.ps1`** - Guide interactif pour le déploiement des modes

## Guide d'utilisation rapide

### Déploiement simple

Pour un déploiement rapide des modes simple et complex:

```powershell
.\deployment-scripts\simple-deploy.ps1
```

### Diagnostic et correction d'encodage

Pour diagnostiquer les problèmes d'encodage dans un fichier:

```powershell
.\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json"
```

Pour corriger automatiquement les problèmes:

```powershell
.\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json" -Fix
```

### Déploiement guidé

Pour un déploiement guidé avec vérification d'encodage:

```powershell
.\deployment-scripts\deploy-guide-interactif.ps1
```

## Workflow recommandé

1. **Vérifier l'encodage** du fichier source avec `diagnostic-scripts\check-deployed-encoding.ps1`
2. **Corriger l'encodage** si nécessaire avec `encoding-scripts\fix-encoding-complete.ps1` ou `encoding-scripts\fix-encoding-final.ps1`
3. **Déployer les modes** avec `deployment-scripts\deploy-modes-simple-complex.ps1` ou `deployment-scripts\simple-deploy.ps1`
4. **Vérifier le déploiement** avec `diagnostic-scripts\verify-deployed-modes.ps1`
5. **Redémarrer Visual Studio Code** et activer les modes

## Documentation complète

Pour une documentation complète sur les problèmes d'encodage et leur résolution:

- [Guide d'encodage pour Windows](../docs/guides/guide-encodage-windows.md)
- [Rapport final de déploiement](../docs/rapports/rapport-final-deploiement-modes-windows.md)
- [Guide d'import/export](docs/guide-import-export.md)

## Dépannage

Si vous rencontrez des problèmes lors du déploiement:

1. Exécutez `diagnostic-scripts\diagnostic-rapide-encodage.ps1` pour identifier les problèmes
2. Utilisez `encoding-scripts\fix-encoding-complete.ps1` pour corriger les problèmes d'encodage
3. Forcez le déploiement avec `deployment-scripts\force-deploy-with-encoding-fix.ps1`
4. Vérifiez le résultat avec `diagnostic-scripts\verify-deployed-modes.ps1`

Si les problèmes persistent, consultez le [rapport final de déploiement](../docs/rapports/rapport-final-deploiement-modes-windows.md) pour des solutions plus avancées.

## Contribution

Ces outils sont en constante amélioration. Si vous rencontrez des problèmes non couverts ou si vous avez des suggestions d'amélioration, n'hésitez pas à contribuer ou à signaler les problèmes.

---

Développé pour faciliter le déploiement des modes Roo sur Windows et résoudre les problèmes d'encodage courants.

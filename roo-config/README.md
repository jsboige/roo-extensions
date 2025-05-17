# Outils de configuration et déploiement pour Roo

Ce répertoire contient un ensemble complet d'outils pour configurer, déployer et maintenir les modes Roo, ainsi que pour résoudre les problèmes d'encodage courants sur Windows.

## Rôle dans le projet Roo Extensions

Le composant `roo-config` est un élément central du projet Roo Extensions qui fournit :

1. **Outils de déploiement** : Scripts pour déployer les modes Roo (simples et complexes) sur différentes plateformes
2. **Outils de correction d'encodage** : Scripts pour résoudre les problèmes d'encodage courants, notamment pour les caractères accentués et les emojis
3. **Outils de diagnostic** : Scripts pour vérifier l'encodage et la validité des fichiers de configuration
4. **Modèles de configuration** : Fichiers de configuration de référence pour les modes, les modèles et les serveurs
5. **Profils pour différents modèles** : Configurations optimisées pour différents modèles de langage, comme Qwen3

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
- **`settings/`** - Paramètres de configuration

### Scripts de déploiement

- **`deployment-scripts/simple-deploy.ps1`** - Script simplifié pour déployer les modes avec l'option force
- **`deployment-scripts/deploy-modes-simple-complex.ps1`** - Script principal de déploiement avec gestion améliorée de l'encodage
- **`deployment-scripts/deploy-modes-enhanced.ps1`** - Version améliorée du script de déploiement
- **`deployment-scripts/force-deploy-with-encoding-fix.ps1`** - Script qui force le déploiement avec correction d'encodage
- **`deployment-scripts/create-clean-modes.ps1`** - Script pour créer des modes propres
- **`deployment-scripts/deploy-guide-interactif.ps1`** - Guide interactif pour le déploiement des modes

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

## Intégration avec les autres composants

### Intégration avec roo-modes

Les outils de déploiement de `roo-config` sont conçus pour déployer les modes personnalisés définis dans le répertoire [roo-modes](../roo-modes/README.md). Ils prennent en charge l'architecture à 5 niveaux (n5) et les autres modes personnalisés.

### Intégration avec les MCPs

Les fichiers de configuration dans `roo-config/settings/` incluent la configuration des serveurs MCP. Pour plus d'informations sur les MCPs, consultez le [README des MCPs](../mcps/README.md).

## Documentation complète

Pour une documentation complète sur les problèmes d'encodage et leur résolution:

- [Guide d'encodage pour Windows](../docs/guides/guide-encodage-windows.md)
- [Guide d'encodage général](../docs/guides/guide-encodage.md)
- [Guide d'import/export](docs/guide-import-export.md)
- [Guide de déploiement des configurations Roo](../docs/guides/guide-deploiement-configurations-roo.md)
- [Guide de maintenance de la configuration Roo](../docs/guides/guide-maintenance-configuration-roo.md)

## Dépannage

Si vous rencontrez des problèmes lors du déploiement:

1. Exécutez `diagnostic-scripts\diagnostic-rapide-encodage.ps1` pour identifier les problèmes
2. Utilisez `encoding-scripts\fix-encoding-complete.ps1` pour corriger les problèmes d'encodage
3. Forcez le déploiement avec `deployment-scripts\force-deploy-with-encoding-fix.ps1`
4. Vérifiez le résultat avec `diagnostic-scripts\verify-deployed-modes.ps1`

Si les problèmes persistent, consultez la documentation complète pour des solutions plus avancées.

## Contribution

Ces outils sont en constante amélioration. Si vous rencontrez des problèmes non couverts ou si vous avez des suggestions d'amélioration, n'hésitez pas à contribuer ou à signaler les problèmes.

## Ressources supplémentaires

- [README principal du projet](../README.md)
- [Documentation des modes Roo](../roo-modes/README.md)
- [Documentation des MCPs](../mcps/README.md)
- [Documentation générale du projet](../docs/README.md)

---

Développé pour faciliter le déploiement des modes Roo sur Windows et résoudre les problèmes d'encodage courants.

# Outils de configuration et déploiement pour Roo

Ce répertoire contient un ensemble complet d'outils pour configurer, déployer et maintenir les modes Roo, ainsi que pour résoudre les problèmes d'encodage courants sur Windows.

## Rôle dans le projet Roo Extensions

Le composant `roo-config` est un élément central du projet Roo Extensions qui fournit :

1. **Outils de déploiement** : Scripts pour déployer les modes Roo sur différentes plateformes
2. **Outils de correction d'encodage** : Scripts pour résoudre les problèmes d'encodage courants
3. **Outils de diagnostic** : Scripts pour vérifier l'encodage et la validité des fichiers de configuration
4. **Modèles de configuration** : Fichiers de configuration de référence pour les modes, les modèles et les serveurs
5. **Workflow de maintenance** : Script interactif pour guider les utilisateurs dans les tâches de maintenance

## Structure des outils

### Organisation des dossiers

- **`encoding-scripts/`** - [Scripts de correction d'encodage](encoding-scripts/README.md) pour les caractères accentués et les emojis
- **`deployment-scripts/`** - [Scripts de déploiement des modes](deployment-scripts/README.md) (simples et complexes)
- **`diagnostic-scripts/`** - [Scripts de diagnostic et vérification](diagnostic-scripts/README.md) pour l'encodage et la validité des fichiers
- **`config-templates/`** - [Modèles de fichiers de configuration](config-templates/README.md) pour les modes, modèles et serveurs
- **`docs/`** - [Documentation supplémentaire](docs/README.md) et guides d'utilisation
- **`backups/`** - [Fichiers de sauvegarde](backups/README.md) créés automatiquement par les scripts
- **`modes/`** - Fichiers de modes standards
- **`qwen3-profiles/`** - [Profils optimisés](qwen3-profiles/README.md) pour le modèle Qwen3
- **`settings/`** - [Paramètres de configuration](settings/README.md) et scripts de déploiement associés
- **`scheduler/`** - Guides d'installation et de configuration du planificateur Roo

### Script de workflow interactif

Le script `maintenance-workflow.ps1` à la racine du répertoire est un outil interactif qui guide l'utilisateur à travers les différentes étapes de maintenance de la configuration Roo. Il propose un menu avec les tâches courantes :

- Mise à jour des commandes autorisées
- Ajout ou modification de modes personnalisés
- Mise à jour des configurations d'API
- Correction des problèmes d'encodage
- Déploiement des mises à jour
- Diagnostic et vérification
- Gestion des sauvegardes

Pour l'utiliser, exécutez simplement :
```powershell
.\maintenance-workflow.ps1
```

## Principales fonctionnalités

### Déploiement des modes

Les scripts de déploiement permettent d'installer les modes Roo de différentes manières :
- Déploiement global (pour toutes les instances de VS Code)
- Déploiement local (pour un projet spécifique)
- Déploiement avec correction automatique d'encodage
- Déploiement interactif guidé

Exemple de déploiement simple :
```powershell
.\deployment-scripts\simple-deploy.ps1
```

### Correction des problèmes d'encodage

Les scripts de correction d'encodage résolvent les problèmes courants avec les caractères accentués et les emojis dans les fichiers JSON :
- Détection automatique des problèmes d'encodage
- Correction des séquences de caractères mal encodés
- Réenregistrement des fichiers en UTF-8 sans BOM
- Vérification de la validité du JSON après correction

Exemple de correction d'encodage :
```powershell
.\encoding-scripts\fix-encoding-complete.ps1 -FilePath "chemin\vers\fichier.json"
```

### Diagnostic et vérification

Les scripts de diagnostic permettent de :
- Analyser l'encodage des fichiers JSON
- Détecter les problèmes d'encodage courants
- Vérifier la validité des fichiers JSON
- Vérifier le déploiement des modes

Exemple de diagnostic rapide :
```powershell
.\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json"
```

### Configuration des modèles

Les profils pour différents modèles de langage permettent d'optimiser les performances :
- Profils pour les modèles Qwen3 (0.6B à 235B)
- Paramètres optimaux pour chaque modèle
- Intégration avec l'architecture à 5 niveaux (N5)

## Guide d'utilisation rapide

### Workflow recommandé

1. **Utiliser le script de workflow interactif** pour être guidé à travers les tâches courantes :
   ```powershell
   .\maintenance-workflow.ps1
   ```

2. **Vérifier l'encodage** du fichier source :
   ```powershell
   .\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json"
   ```

3. **Corriger l'encodage** si nécessaire :
   ```powershell
   .\encoding-scripts\fix-encoding-complete.ps1 -FilePath "chemin\vers\fichier.json"
   ```

4. **Déployer les modes** :
   ```powershell
   .\deployment-scripts\deploy-modes-simple-complex.ps1
   ```

5. **Vérifier le déploiement** :
   ```powershell
   .\diagnostic-scripts\verify-deployed-modes.ps1
   ```

6. **Redémarrer Visual Studio Code** et activer les modes

## Intégration avec les autres composants

### Intégration avec roo-modes

Les outils de déploiement de `roo-config` sont conçus pour déployer les modes personnalisés définis dans le répertoire [roo-modes](../roo-modes/README.md). Ils prennent en charge l'architecture à 5 niveaux (n5) et les autres modes personnalisés.

### Intégration avec les MCPs

Les fichiers de configuration dans `roo-config/settings/` incluent la configuration des serveurs MCP. Pour plus d'informations sur les MCPs, consultez le [README des MCPs](../mcps/README.md).

## Documentation complète

Pour une documentation complète sur les différents aspects du projet :

- [Guide d'import/export](docs/guide-import-export.md)
- [Guide d'installation du planificateur Roo](scheduler/Guide_Installation_Roo_Scheduler.md)
- [Guide d'édition des configurations du planificateur](scheduler/Guide_Edition_Directe_Configurations_Roo_Scheduler.md)
- [Documentation des modes Roo](../roo-modes/README.md)
- [Documentation des MCPs](../mcps/README.md)
- [Documentation générale du projet](../docs/README.md)

## Dépannage

Si vous rencontrez des problèmes lors du déploiement :

1. Utilisez le script de workflow interactif pour un diagnostic guidé :
   ```powershell
   .\maintenance-workflow.ps1
   ```
   Puis sélectionnez l'option "Diagnostic et vérification"

2. Exécutez le diagnostic rapide d'encodage :
   ```powershell
   .\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json"
   ```

3. Corrigez les problèmes d'encodage :
   ```powershell
   .\encoding-scripts\fix-encoding-complete.ps1 -FilePath "chemin\vers\fichier.json"
   ```

4. Forcez le déploiement avec correction d'encodage :
   ```powershell
   .\deployment-scripts\force-deploy-with-encoding-fix.ps1
   ```

5. Vérifiez le résultat :
   ```powershell
   .\diagnostic-scripts\verify-deployed-modes.ps1
   ```

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

# Guide de déploiement des configurations Roo

Ce guide détaille les procédures de déploiement pour les différentes configurations de Roo, suite à la restructuration des répertoires.

## Vue d'ensemble

Suite à la restructuration, Roo utilise désormais deux types de configurations distincts :

1. **Configurations des modes personnalisés** (répertoire `roo-modes`)
2. **Configurations générales** (répertoire `roo-settings`)

Chaque type de configuration dispose de son propre script de déploiement et de ses propres emplacements de destination.

## Prérequis

- PowerShell 5.1 ou supérieur
- Accès en écriture aux répertoires de destination
- Visual Studio Code avec l'extension Roo installée

## Déploiement des modes personnalisés

### Emplacements de déploiement

Les modes personnalisés peuvent être déployés à deux emplacements différents :

1. **Global** (pour toutes les instances de VS Code) :
   - `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`

2. **Local** (uniquement pour le projet courant) :
   - `.roomodes` à la racine du projet

### Procédure de déploiement

1. **Ouvrez PowerShell** dans le répertoire racine du projet.

2. **Exécutez le script de déploiement** avec les paramètres appropriés :

   ```powershell
   .\roo-modes\deploy-modes.ps1 [-ConfigFile <chemin>] [-DeploymentType <global|local>] [-Force]
   ```

   Paramètres :
   - `-ConfigFile` : Chemin du fichier de configuration à déployer (relatif au répertoire `roo-modes/`)
     - Par défaut : `modes/standard-modes.json`
   - `-DeploymentType` : Type de déploiement (`global` ou `local`)
     - Par défaut : `global`
   - `-Force` : Force le remplacement du fichier de destination sans demander de confirmation

3. **Confirmez le remplacement** si le fichier de destination existe déjà (sauf si l'option `-Force` est utilisée).

4. **Vérifiez le résultat** affiché par le script.

5. **Redémarrez Visual Studio Code** pour appliquer les changements.

### Exemples de commandes

```powershell
# Déploiement global de la configuration standard
.\roo-modes\deploy-modes.ps1

# Déploiement local de la configuration standard
.\roo-modes\deploy-modes.ps1 -DeploymentType local

# Déploiement global d'une configuration personnalisée
.\roo-modes\deploy-modes.ps1 -ConfigFile modes/ma-config.json

# Déploiement local d'une configuration personnalisée sans confirmation
.\roo-modes\deploy-modes.ps1 -ConfigFile modes/ma-config.json -DeploymentType local -Force
```

## Déploiement des configurations générales

### Emplacements de déploiement

Les configurations générales sont déployées à un emplacement spécifique selon le système d'exploitation :

- **Windows** : `%APPDATA%\roo\config.json`
- **macOS** : `~/Library/Application Support/roo/config.json`
- **Linux** : `~/.config/roo/config.json`

### Procédure de déploiement

1. **Ouvrez PowerShell** dans le répertoire racine du projet.

2. **Exécutez le script de déploiement** avec les paramètres appropriés :

   ```powershell
   .\roo-settings\deploy-settings.ps1 [-ConfigFile <chemin>] [-Force]
   ```

   Paramètres :
   - `-ConfigFile` : Chemin du fichier de configuration à déployer (relatif au répertoire `roo-settings/`)
     - Par défaut : `settings.json`
   - `-Force` : Force le remplacement du fichier de destination sans demander de confirmation

3. **Confirmez le remplacement** si le fichier de destination existe déjà (sauf si l'option `-Force` est utilisée).

4. **Vérifiez le résultat** affiché par le script.

5. **Ajoutez manuellement les informations sensibles** (clés d'API, etc.) au fichier de configuration déployé.

6. **Redémarrez Visual Studio Code** pour appliquer les changements.

### Exemples de commandes

```powershell
# Déploiement de la configuration générale standard
.\roo-settings\deploy-settings.ps1

# Déploiement d'une configuration personnalisée sans confirmation
.\roo-settings\deploy-settings.ps1 -ConfigFile ma-config.json -Force
```

## Scénarios de déploiement courants

### 1. Configuration initiale sur une nouvelle machine

Pour configurer Roo sur une nouvelle machine, vous devez déployer à la fois les modes personnalisés et la configuration générale :

```powershell
# Déployer les modes personnalisés globalement
.\roo-modes\deploy-modes.ps1

# Déployer la configuration générale
.\roo-settings\deploy-settings.ps1
```

Ensuite, ajoutez manuellement vos clés d'API et autres informations sensibles au fichier de configuration générale.

### 2. Configuration d'un projet partagé

Pour configurer un projet partagé avec une équipe, déployez les modes personnalisés localement :

```powershell
# Déployer les modes personnalisés localement
.\roo-modes\deploy-modes.ps1 -DeploymentType local
```

Chaque membre de l'équipe devra déployer sa propre configuration générale avec ses clés d'API.

### 3. Mise à jour des configurations

Pour mettre à jour les configurations après des modifications :

```powershell
# Mettre à jour les modes personnalisés
.\roo-modes\deploy-modes.ps1 [-DeploymentType <global|local>]

# Mettre à jour la configuration générale
.\roo-settings\deploy-settings.ps1
```

## Dépannage

### Problèmes courants et solutions

1. **Le script ne trouve pas le fichier de configuration**
   - Vérifiez que le chemin relatif est correct
   - Assurez-vous d'exécuter le script depuis le répertoire racine du projet

2. **Erreur d'accès refusé lors du déploiement**
   - Exécutez PowerShell en tant qu'administrateur
   - Vérifiez que vous avez les droits d'écriture sur le répertoire de destination

3. **Les modes personnalisés ne sont pas disponibles après le déploiement**
   - Assurez-vous d'avoir redémarré Visual Studio Code
   - Vérifiez que le fichier a été correctement déployé à l'emplacement attendu
   - Vérifiez que l'extension Roo est activée dans VS Code

4. **Les paramètres ne sont pas appliqués après le déploiement**
   - Vérifiez que le fichier JSON est valide (pas d'erreurs de syntaxe)
   - Assurez-vous d'avoir redémarré Visual Studio Code
   - Vérifiez les logs de VS Code pour détecter d'éventuelles erreurs

## Bonnes pratiques

1. **Gestion des configurations**
   - Conservez une copie de sauvegarde de vos configurations personnalisées
   - Documentez les modifications apportées aux configurations standard
   - Utilisez le contrôle de version pour suivre l'évolution des configurations

2. **Sécurité**
   - Ne partagez jamais vos clés d'API ou autres informations sensibles
   - Utilisez des variables d'environnement ou un gestionnaire de secrets pour les informations sensibles
   - Vérifiez régulièrement les autorisations accordées à Roo

3. **Déploiement**
   - Testez les nouvelles configurations dans un environnement isolé avant de les déployer globalement
   - Informez les utilisateurs des changements majeurs dans les configurations
   - Prévoyez une procédure de restauration en cas de problème

## Conclusion

Ce guide vous a présenté les procédures de déploiement pour les différentes configurations de Roo. En suivant ces instructions, vous pourrez configurer Roo selon vos besoins et maintenir vos configurations à jour.

Pour plus d'informations sur les configurations spécifiques, consultez :
- [Documentation des modes personnalisés](./roo-modes/README.md)
- [Documentation des configurations générales](./roo-settings/README.md)
- [Documentation de la structure globale](./documentation-structure-configuration-roo.md)
# Intégration du projet Demo roo-code

Ce document explique comment ce sous-dossier s'intègre dans le dépôt principal et fournit des instructions pour l'installation et l'utilisation dans ce nouveau contexte.

## Structure du projet

Le projet "Demo roo-code" est conçu pour être intégré comme un sous-dossier dans un dépôt Git existant. Il est organisé en plusieurs sections thématiques:

- **01-decouverte**: Introduction aux fonctionnalités de base
- **02-orchestration-taches**: Démonstrations d'orchestration de tâches complexes
- **03-assistant-pro**: Exemples d'utilisation professionnelle
- **04-creation-contenu**: Outils et exemples de création de contenu
- **05-projets-avances**: Projets et fonctionnalités avancées

## Dépendances avec le dépôt principal

Ce sous-dossier est maintenant intégré au dépôt principal et utilise certaines ressources communes. Points importants à noter:

1. Ne pas modifier les noms des dossiers principaux (01-decouverte, 02-orchestration-taches, etc.) pour maintenir la cohérence des chemins relatifs dans les scripts.
2. Respecter la structure des répertoires `workspace` et `ressources` dans chaque démo pour assurer le bon fonctionnement des scripts de préparation et de nettoyage.
3. Les scripts de préparation et de nettoyage ont été déplacés dans le répertoire `scripts/demo-scripts/` du dépôt principal.
4. Les références aux MCPs utilisent désormais l'organisation `mcps/internal/` et `mcps/external/` du dépôt principal.

## Installation et configuration

> **Note**: Pour une installation complète et détaillée de l'environnement Roo, consultez le [guide d'installation complet](./guide_installation.md) qui couvre l'installation de VSCode, Python, Node.js, la configuration des clés API, des profils de modèles, et l'installation des MCPs.

### Prérequis

- PowerShell 5.1+ ou Bash pour les scripts de maintenance
- Navigateur web moderne pour les démos interactives
- Python et Node.js pour l'utilisation des MCPs (voir le [guide d'installation](./guide_installation.md))

### Installation rapide

1. Clonez le dépôt principal qui contient ce sous-dossier:
   ```bash
   git clone <URL_DU_DEPOT_PRINCIPAL>
   cd <NOM_DU_DEPOT_PRINCIPAL>
   ```

2. Créez un fichier `.env` dans le répertoire du sous-dossier (si nécessaire) en vous basant sur le modèle fourni:
   ```bash
   cd chemin/vers/demo-roo-code
   cp .env.example .env
   ```

3. Modifiez le fichier `.env` pour configurer vos clés API et autres paramètres sensibles (voir le [guide d'installation](./guide_installation.md) pour plus de détails).

## Utilisation

### Préparation des espaces de travail

Pour préparer les espaces de travail avant une démonstration:

- Sous Windows:
  ```powershell
  # Depuis la racine du dépôt principal
  .\scripts\demo-scripts\prepare-workspaces.ps1
  ```

- Sous Linux/macOS:
  ```bash
  # Depuis la racine du dépôt principal
  ./scripts/demo-scripts/prepare-workspaces.sh
  ```

### Nettoyage des espaces de travail

Pour nettoyer les espaces de travail après une démonstration:

- Sous Windows:
  ```powershell
  # Depuis la racine du dépôt principal
  .\scripts\demo-scripts\clean-workspaces.ps1
  ```

- Sous Linux/macOS:
  ```bash
  # Depuis la racine du dépôt principal
  ./scripts/demo-scripts/clean-workspaces.sh
  ```

## Bonnes pratiques d'intégration

1. **Chemins relatifs**: Tous les scripts et références ont été mis à jour pour utiliser des chemins relatifs adaptés à la nouvelle structure du dépôt principal.

2. **Fichiers sensibles**: Les règles du fichier `.gitignore` de la démo ont été fusionnées avec celles du dépôt principal pour assurer une cohérence globale.

3. **Isolation des workspaces**: Les répertoires `workspace` sont conçus pour être des zones de travail temporaires. Leur contenu est ignoré par Git (à l'exception des fichiers README.md).

4. **Références aux MCPs**: Les exemples et la documentation font désormais référence à l'organisation des MCPs du dépôt principal (`mcps/internal/` et `mcps/external/`).

5. **Modifications et contributions**: Si vous souhaitez modifier ou contribuer à ce projet, assurez-vous de tester vos changements dans le contexte du dépôt principal.

## Résolution des problèmes courants

### Les scripts ne trouvent pas les répertoires workspace

Si les scripts ne parviennent pas à localiser les répertoires workspace, vérifiez que:
- Vous exécutez les scripts depuis la racine du dépôt principal
- La structure des répertoires n'a pas été modifiée
- Les noms des dossiers de démo suivent le format attendu (`demo-X-nom`)
- Le chemin vers le répertoire `demo-roo-code` est correct dans les scripts

### Conflits de fichiers avec le dépôt principal

En cas de conflits avec des fichiers du dépôt principal:
1. Vérifiez les règles dans le fichier `.gitignore`
2. Renommez les fichiers en conflit dans ce sous-dossier en ajoutant un préfixe spécifique
3. Mettez à jour les références à ces fichiers dans les scripts et la documentation

## Section de dépannage

### Problèmes d'encodage des caractères spéciaux

Si vous rencontrez des problèmes d'affichage des caractères spéciaux, notamment dans WSL sur Windows:

1. Utilisez l'option `--no-colors` avec les scripts bash:
   ```bash
   ./clean-workspaces.sh --no-colors
   ```

2. Vérifiez l'encodage de vos fichiers. Tous les fichiers devraient être encodés en UTF-8:
   ```bash
   # Sur Linux/macOS
   file -i nom_du_fichier
   
   # Sur Windows PowerShell
   Get-Content nom_du_fichier | Out-File -Encoding utf8 nom_du_fichier_fixed
   ```

3. Pour les dossiers avec des caractères accentués, utilisez les scripts PowerShell sur Windows plutôt que les scripts bash dans WSL.

### Problèmes de compatibilité des scripts

1. **Erreurs de permission sur les scripts bash**:
   ```bash
   chmod +x *.sh
   ```

2. **Problèmes de fins de ligne**:
   Si vous obtenez des erreurs du type "bad interpreter", convertissez les fins de ligne:
   ```bash
   # Installation de dos2unix si nécessaire
   sudo apt-get install dos2unix
   
   # Conversion des fins de ligne
   dos2unix *.sh
   ```

3. **Chemins Windows dans WSL**:
   Si vous utilisez des chemins Windows dans WSL, convertissez-les:
   ```bash
   WSLPATH=$(wslpath "C:\chemin\windows")
   ```

### Problèmes de sécurité et clés API

1. **Protection des clés API**:
   - Vérifiez que le fichier `.env` est bien dans `.gitignore`
   - Utilisez toujours des clés factices dans les exemples et la documentation
   - Ne commettez jamais de fichiers contenant des clés réelles

2. **Vérification de la sécurité**:
   ```bash
   # Vérifier si des fichiers sensibles sont suivis par Git
   git ls-files | grep -i ".env"
   
   # Vérifier les fichiers modifiés avant un commit
   git status
   ```

### Liens cassés dans la documentation

Si vous trouvez des liens cassés dans la documentation:

1. Utilisez des chemins relatifs pour les liens internes
2. Vérifiez que les fichiers référencés existent
3. Mettez à jour les liens vers des ressources externes si nécessaire
4. Pour les démos manquantes, pointez vers les sections existantes les plus pertinentes

### Problèmes spécifiques à Windows

1. **Exécution des scripts PowerShell**:
   Si vous ne pouvez pas exécuter les scripts PowerShell en raison de restrictions de sécurité:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

2. **Chemins trop longs**:
   Windows peut avoir des problèmes avec les chemins dépassant 260 caractères. Activez la prise en charge des chemins longs:
   ```powershell
   # Nécessite des droits administrateur
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
   ```
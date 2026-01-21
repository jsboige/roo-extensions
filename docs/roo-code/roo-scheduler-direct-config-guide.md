# Guide d'Édition Directe des Configurations de Roo Scheduler

## Introduction

Ce guide explique comment localiser, extraire, modifier et sauvegarder les configurations de Roo Scheduler directement dans le système de fichiers, sans passer par l'interface utilisateur de VS Code. Cette approche peut être utile pour les administrateurs système, les développeurs avancés ou pour automatiser la configuration de Roo Scheduler sur plusieurs postes de travail.

## 1. Localisation des Fichiers de Configuration

Les configurations de Roo Scheduler sont stockées à deux endroits principaux, selon le système d'exploitation:

### Windows
```
%APPDATA%\Code\User\globalStorage\kyle-hoskins.roo-scheduler\
```
ou
```
C:\Users\[username]\AppData\Roaming\Code\User\globalStorage\kyle-hoskins.roo-scheduler\
```

### macOS
```
~/Library/Application Support/Code/User/globalStorage/kyle-hoskins.roo-scheduler/
```

### Linux
```
~/.config/Code/User/globalStorage/kyle-hoskins.roo-scheduler/
```

### VS Code Insiders
Si vous utilisez VS Code Insiders, remplacez `Code` par `Code - Insiders` dans les chemins ci-dessus.

## 2. Structure des Fichiers de Configuration

Dans le dossier `kyle-hoskins.roo-scheduler`, vous trouverez généralement les fichiers suivants:

- `schedules.json`: Contient les métadonnées des tâches planifiées
- `state.json`: Stocke l'état d'exécution des tâches (dernière exécution, prochaine exécution prévue, etc.)

Cependant, les détails sensibles des configurations (comme les prompts) sont stockés dans le système de "secrets" de VS Code pour des raisons de sécurité.

## 3. Extraction et Décodage des Secrets

Les prompts et autres informations sensibles sont stockés dans le système de secrets de VS Code. Voici comment y accéder:

### 3.1 Localisation des Secrets

#### Windows
Les secrets sont stockés dans le Gestionnaire d'informations d'identification Windows:
1. Ouvrez le Panneau de configuration
2. Accédez à "Comptes d'utilisateurs" > "Gestionnaire d'informations d'identification"
3. Recherchez les entrées commençant par `vscode-roo-scheduler`

#### macOS
Les secrets sont stockés dans le Trousseau d'accès:
1. Ouvrez l'application "Trousseau d'accès"
2. Recherchez les éléments commençant par `vscode-roo-scheduler`

#### Linux
Les secrets sont généralement stockés via `libsecret` ou dans un fichier chiffré:
1. Utilisez l'outil `secret-tool` pour lister les secrets:
   ```bash
   secret-tool search service vscode-roo-scheduler
   ```

### 3.2 Extraction des Secrets

Pour extraire les secrets de manière programmatique, vous pouvez utiliser les méthodes suivantes:

#### Windows (PowerShell)
```powershell
# Nécessite le module CredentialManager
# Install-Module -Name CredentialManager (à exécuter une seule fois)
$cred = Get-StoredCredential -Target "vscode-roo-scheduler-[ID]"
$secret = $cred.GetNetworkCredential().Password
```

#### macOS (Terminal)
```bash
security find-generic-password -s "vscode-roo-scheduler-[ID]" -w
```

#### Linux (Terminal)
```bash
secret-tool lookup service vscode-roo-scheduler account [ID]
```

### 3.3 Décodage des Secrets

Les secrets sont généralement stockés au format JSON encodé en base64. Pour les décoder:

```javascript
// JavaScript
const decodedSecret = JSON.parse(Buffer.from(secret, 'base64').toString('utf-8'));
```

```python
# Python
import base64
import json
decoded_secret = json.loads(base64.b64decode(secret).decode('utf-8'))
```

## 4. Exemple Complet: Modification d'une Configuration Existante

Voici un exemple complet pour extraire, modifier et sauvegarder une configuration de tâche planifiée:

### 4.1 Extraction de la Configuration

1. Localisez le fichier `schedules.json` dans le dossier de l'extension
2. Ouvrez ce fichier pour identifier l'ID de la tâche que vous souhaitez modifier
3. Extrayez le secret correspondant à cette tâche à l'aide des méthodes décrites ci-dessus

### 4.2 Modification de la Configuration

Supposons que nous avons extrait la configuration suivante:

```json
{
  "id": "task-123456",
  "name": "Code Review",
  "prompt": "Review any unreviewed code in the current project",
  "schedule": {
    "interval": 1,
    "unit": "day",
    "daysOfWeek": [1, 3, 5],
    "startDate": "2025-01-01T09:00:00Z",
    "expirationDate": null,
    "requireActivity": true
  },
  "isActive": true,
  "lastExecution": "2025-01-04T09:00:00Z",
  "nextExecution": "2025-01-06T09:00:00Z"
}
```

Pour modifier cette configuration:

1. Modifiez les valeurs selon vos besoins, par exemple:
   ```json
   {
     "id": "task-123456",
     "name": "Enhanced Code Review",
     "prompt": "Review any unreviewed code in the current project. Focus on security issues and performance optimizations.",
     "schedule": {
       "interval": 1,
       "unit": "day",
       "daysOfWeek": [1, 2, 3, 4, 5],
       "startDate": "2025-01-01T09:00:00Z",
       "expirationDate": null,
       "requireActivity": true
     },
     "isActive": true,
     "lastExecution": "2025-01-04T09:00:00Z",
     "nextExecution": "2025-01-06T09:00:00Z"
   }
   ```

2. Encodez la configuration modifiée en base64:
   ```javascript
   // JavaScript
   const encodedConfig = Buffer.from(JSON.stringify(modifiedConfig)).toString('base64');
   ```
   ```python
   # Python
   import base64
   import json
   encoded_config = base64.b64encode(json.dumps(modified_config).encode('utf-8')).decode('utf-8')
   ```

### 4.3 Sauvegarde de la Configuration Modifiée

#### Windows (PowerShell)
```powershell
# Nécessite le module CredentialManager
$password = ConvertTo-SecureString $encodedConfig -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("vscode-roo-scheduler-[ID]", $password)
New-StoredCredential -Target "vscode-roo-scheduler-[ID]" -Credential $credential -Persist LocalMachine
```

#### macOS (Terminal)
```bash
security add-generic-password -U -a "vscode-roo-scheduler-[ID]" -s "vscode-roo-scheduler-[ID]" -w "$encodedConfig"
```

#### Linux (Terminal)
```bash
echo -n "$encodedConfig" | secret-tool store --label="VS Code Roo Scheduler" service vscode-roo-scheduler account [ID]
```

### 4.4 Mise à Jour du Fichier schedules.json

Vous devrez également mettre à jour le fichier `schedules.json` pour refléter les modifications des métadonnées (comme le nom de la tâche):

1. Ouvrez le fichier `schedules.json`
2. Localisez l'entrée correspondant à l'ID de la tâche modifiée
3. Mettez à jour les champs nécessaires (généralement `name`, `isActive`, etc.)
4. Sauvegardez le fichier

## 5. Ajout d'une Nouvelle Configuration

Pour ajouter une nouvelle configuration sans passer par l'interface utilisateur:

1. Générez un nouvel ID unique (par exemple, un UUID)
2. Créez un objet de configuration complet comme dans l'exemple ci-dessus
3. Encodez cette configuration en base64
4. Stockez-la dans le système de secrets avec l'ID généré
5. Ajoutez une entrée correspondante dans le fichier `schedules.json`

Exemple d'entrée à ajouter dans `schedules.json`:
```json
{
  "schedules": [
    // Configurations existantes...
    {
      "id": "nouveau-id-unique",
      "name": "Nouvelle Tâche Automatisée",
      "isActive": true,
      "lastExecution": null,
      "nextExecution": "2025-01-06T12:00:00Z"
    }
  ]
}
```

## 6. Risques et Précautions

### 6.1 Risques Potentiels

- **Corruption des données**: Une modification incorrecte peut rendre les configurations inutilisables
- **Incompatibilité de version**: Les modifications manuelles peuvent ne pas être compatibles avec les futures mises à jour de l'extension
- **Perte de données**: Sans sauvegarde appropriée, vous risquez de perdre vos configurations

### 6.2 Précautions à Prendre

- **Sauvegardez toujours les fichiers originaux** avant de les modifier
- **Testez vos modifications** sur une installation non critique avant de les appliquer en production
- **Documentez toutes les modifications** que vous effectuez pour faciliter le dépannage
- **Vérifiez la structure des données** pour vous assurer qu'elle correspond au format attendu
- **Redémarrez VS Code** après avoir modifié les configurations pour qu'elles soient prises en compte

### 6.3 Bonnes Pratiques

- Utilisez des scripts automatisés pour effectuer des modifications en masse
- Validez le format JSON avant de sauvegarder les modifications
- Maintenez un historique des modifications apportées
- Utilisez l'interface utilisateur pour les modifications simples et réservez l'édition directe pour les cas complexes ou l'automatisation

## Conclusion

L'édition directe des configurations de Roo Scheduler offre une flexibilité et des possibilités d'automatisation que l'interface utilisateur ne permet pas. Cependant, cette approche nécessite une compréhension approfondie du système de stockage de VS Code et comporte des risques inhérents.

En suivant ce guide et en prenant les précautions nécessaires, vous pouvez modifier efficacement les configurations de Roo Scheduler pour répondre à des besoins spécifiques ou pour automatiser le déploiement de configurations sur plusieurs postes de travail.
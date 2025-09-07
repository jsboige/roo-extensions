# Documentation des Scripts de Réparation

Ce répertoire contient des scripts conçus pour diagnostiquer et réparer des problèmes spécifiques dans l'environnement Roo.

## repair-conversation-bom.ps1

### Objectif

Ce script PowerShell a pour but de détecter et de supprimer le **BOM (Byte Order Mark) UTF-8** des fichiers d'historique de conversation (`api_conversation_history.json`). La présence d'un BOM rend ces fichiers JSON invalides pour le parseur de Node.js, ce qui peut empêcher le MCP `roo-state-manager` de démarrer correctement.

### Contexte

Le BOM est un caractère invisible (`U+FEFF`) qui peut être ajouté par certains éditeurs de texte ou lors d'opérations de fichiers, notamment sous Windows. Ce problème a été identifié comme une cause majeure d'instabilité du `roo-state-manager` après la restauration de certains fichiers de conversation.

### Utilisation

Le script peut être exécuté de deux manières : en mode diagnostic (simulation) ou en mode réparation.

#### Mode Diagnostic (`-WhatIf`)

Ce mode permet de lister tous les fichiers qui sont corrompus par un BOM sans les modifier. C'est l'option recommandée pour une première analyse.

```powershell
# Exécuter depuis la racine du projet
./scripts/repair/repair-conversation-bom.ps1 -WhatIf
```

**Exemple de sortie :**
```
[WHAT IF]: Opération « Réparation de BOM » en cours sur la cible « d:\dev\roo-extensions\.roo\tasks\task-123\api_conversation_history.json ».
[WHAT IF]: Opération « Réparation de BOM » en cours sur la cible « d:\dev\roo-extensions\.roo\tasks\task-456\api_conversation_history.json ».
...
[DIAGNOSTIC]: 2501 fichiers sur 3334 (75.01%) sont corrompus par un BOM UTF-8.
```

#### Mode Réparation

Ce mode scanne et répare activement tous les fichiers corrompus en supprimant le BOM.

```powershell
# Exécuter depuis la racine du projet
./scripts/repair/repair-conversation-bom.ps1
```

**Exemple de sortie :**
```
[INFO] Scan du répertoire : d:\dev\roo-extensions\.roo\tasks
[INFO] 3334 fichiers 'api_conversation_history.json' trouvés.
[FIX] Suppression du BOM pour le fichier : d:\dev\roo-extensions\.roo\tasks\task-123\api_conversation_history.json
[FIX] Suppression du BOM pour le fichier : d:\dev\roo-extensions\.roo\tasks\task-456\api_conversation_history.json
...
[SUCCESS]: Réparation terminée. 2501 fichiers ont été corrigés.
```

### Recommandation

Il est conseillé d'exécuter ce script en mode diagnostic après toute opération de restauration de fichiers ou si le `roo-state-manager` signale des erreurs de parsing JSON inattendues.
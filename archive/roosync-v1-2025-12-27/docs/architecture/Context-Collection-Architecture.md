# Architecture de Collecte de Contexte - RUSH-SYNC

**Projet :** roo-extensions  
**Framework :** SDDD (Semantic-Documentation-Driven-Design)  
**Date :** 01 août 2025  
**Version :** 1.1
**Statut :** Implémenté le 2025-08-01

---

## 1. Objectif

Ce document définit l'architecture pour la collecte d'informations contextuelles enrichies sur l'environnement local. L'objectif est d'améliorer les capacités de diagnostic, de reporting et de synchronisation intelligente de RUSH-SYNC en intégrant des données précises sur la machine, l'IDE et la configuration dans les fichiers d'état partagés (`sync-dashboard.json`, `sync-report.md`).

---

## 2. Sources de Données

| Donnée | Source | Commande PowerShell | Sélection de Propriétés / Logique |
|---|---|---|---|
| **Informations Machine** | WMI / CIM | `Get-ComputerInfo` | `OsName`, `CsName`, `CsManufacturer`, `CsModel` |
| **Environnement Roo** | Système de fichiers | `Get-ChildItem` | Lister le contenu de `d:/roo-extensions/mcps`, `d:/roo-extensions/roo-modes`, `d:/roo-extensions-profiles` |
| **Environnement PowerShell**| Variable Automatique | `$PSVersionTable` | `PSVersion`, `PSEdition`, `BuildVersion` |
| **Encodage par Défaut** | .NET | `[System.Text.Encoding]::Default` | `EncodingName` |

---

## 3. Conception Technique

### 3.1. Nouvelle Fonction : Get-LocalContext

Une nouvelle fonction `Get-LocalContext` sera ajoutée au module `modules/Core.psm1`. Elle sera responsable de collecter, d'agréger et de formater toutes les données contextuelles en un seul objet PowerShell.

**Signature de la fonction :**
```powershell
function Get-LocalContext {
    [CmdletBinding()]
    param()

    # Logique d'implémentation...
}
```

**Logique d'implémentation :**
1.  Initialiser un objet `PSCustomObject`.
2.  Exécuter `Get-ComputerInfo` et sélectionner les propriétés pertinentes.
3.  Lister les répertoires de l'environnement Roo et stocker les noms des MCPs, modes et profils.
4.  Capturer les données de `$PSVersionTable`.
5.  Récupérer le nom de l'encodage par défaut.
6.  Assembler toutes les données dans l'objet `PSCustomObject`.
7.  Retourner l'objet.

### 3.2. Évolution des Structures de Données

#### `sync-dashboard.json`

Le `sync-dashboard.json` sera enrichi avec une nouvelle section `localContext` au niveau de chaque `machineState`.

```json
{
  // ... autres propriétés
  "machineStates": [
    {
      "machineName": "DEV-MACHINE-01",
      // ... autres propriétés
      "lastContext": {
        "timestamp": "2025-08-01T18:00:00Z",
        "computerInfo": {
          "osName": "Microsoft Windows 11 Pro",
          "computerName": "DEV-MACHINE-01",
          "manufacturer": "Dell Inc.",
          "model": "XPS 15 9530"
        },
        "rooEnvironment": {
          "mcps": ["filesystem", "searxng", "quickfiles"],
          "modes": ["code", "architect", "debug"],
          "profiles": ["default", "dev"]
        },
        "powershell": {
          "version": "7.4.1",
          "edition": "Core"
        },
        "defaultEncoding": "utf-8"
      }
    }
  ]
}
```

#### `sync-report.md`

Le rapport `sync-report.md` intégrera ces informations pour un diagnostic rapide.

```markdown
## 🖥️ Contexte de l'Exécution

| Catégorie | Information |
|---|---|
| **OS** | Microsoft Windows 11 Pro |
| **Machine** | DEV-MACHINE-01 (Dell Inc. XPS 15 9530) |
| **PowerShell** | 7.4.1 (Core) |
| **Encodage** | utf-8 |

### Environnement Roo

#### MCPs Installés
- filesystem
- searxng
- quickfiles

#### Modes Disponibles
- code
- architect
- debug
```

---

## 4. Justification des Choix

*   **Centralisation dans `Get-LocalContext`** : Simplifie la maintenance et garantit une collecte de données cohérente.
*   **Enrichissement du `sync-dashboard.json`** : Permet une vue centralisée et historique des contextes d'exécution.
*   **Rapport `sync-report.md` amélioré** : Fournit un contexte immédiat pour le débogage et la compréhension des rapports de synchronisation.

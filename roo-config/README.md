# Configuration et deploiement des modes Roo

Ce repertoire centralise la configuration, le deploiement et la documentation des modes personnalises pour Roo (extension VS Code). Il couvre les architectures de modes (N2 simple/complex, N5 cinq niveaux), les mecanismes d'escalade/desescalade, les profils de modeles, les scripts de deploiement et le systeme de planification.

## Table des matieres

1. [Vue d'ensemble](#1-vue-densemble)
2. [Architecture des modes](#2-architecture-des-modes)
3. [Deploiement des modes](#3-deploiement-des-modes)
4. [Escalade et desescalade](#4-escalade-et-desescalade)
5. [Configuration des modeles](#5-configuration-des-modeles)
6. [Verrouillage de famille (family lock)](#6-verrouillage-de-famille-family-lock)
7. [Import et export de configuration](#7-import-et-export-de-configuration)
8. [Tests et validation](#8-tests-et-validation)
9. [Structure des dossiers](#9-structure-des-dossiers)
10. [Scheduler (planificateur)](#10-scheduler-planificateur)
11. [Troubleshooting](#11-troubleshooting)
12. [Bonnes pratiques pour les prompts](#12-bonnes-pratiques-pour-les-prompts)

---

## 1. Vue d'ensemble

### Role dans le projet Roo Extensions

Le composant `roo-config` fournit :

- **Definitions de modes** : Fichiers JSON decrivant le comportement, les capacites et les instructions systeme de chaque mode Roo.
- **Scripts de deploiement** : Deploiement global (toutes instances VS Code) ou local (projet specifique).
- **Correction d'encodage** : Scripts pour resoudre les problemes UTF-8/BOM courants sur Windows.
- **Profils de modeles** : Association flexible des modeles LLM aux modes via `model-configs.json`.
- **Diagnostic** : Verification d'encodage, de validite JSON et de deploiement.
- **Planificateur** : Systeme d'orchestration quotidienne automatisee.

### Qu'est-ce qu'un mode Roo

Un mode Roo est une configuration qui definit le comportement d'un agent : son role (`roleDefinition`), ses instructions systeme (`customInstructions`), les groupes d'outils accessibles (`groups`) et optionnellement le modele LLM a utiliser. Chaque mode est identifie par un `slug` unique (ex: `code-simple`, `architect-complex`, `code-medium`).

---

## 2. Architecture des modes

Le projet propose deux architectures coexistantes pour organiser les modes.

### 2.1 Architecture N2 (Simple/Complex)

Architecture en production. Elle organise chaque type de mode en deux niveaux :

| Famille | Modes | Usage | Modele type |
|---------|-------|-------|-------------|
| **Simple** | `code-simple`, `debug-simple`, `architect-simple`, `ask-simple`, `orchestrator-simple` | Taches courantes, modifications < 50 lignes, bugs isoles | Qwen 3 32B, GLM 4.7-Air |
| **Complex** | `code-complex`, `debug-complex`, `architect-complex`, `ask-complex`, `orchestrator-complex`, `manager` | Refactoring majeur, architecture, optimisation | Claude 3.7 Sonnet, GLM 4.7 |

Les modes simples peuvent orchestrer des workflows complexes via la creation de sous-taches (`new_task`) ou le changement de mode (`switch_mode`).

**Fichier de reference** : `modes/standard-modes.json` (architecture N5 avec 25 modes, incluant les 10 modes N2 comme sous-ensemble).

### 2.2 Architecture N5 (5 niveaux)

Architecture avancee offrant une granularite plus fine. Cinq niveaux de complexite :

| Niveau | Nom | Lignes de code | Tokens | Modele de reference |
|--------|-----|----------------|--------|---------------------|
| 1 | **MICRO** | < 10 | < 10 000 | Qwen 3 4B (local) |
| 2 | **MINI** | 10-50 | 10k-25k | Qwen 3 8B (local) |
| 3 | **MEDIUM** | 50-200 | 25k-50k | Qwen 3 32B (local) |
| 4 | **LARGE** | 200-500 | 50k-100k | Qwen 235B (cloud) |
| 5 | **ORACLE** | > 500 | > 100k | Claude Sonnet (cloud) |

Chaque niveau propose 5 types de modes : `code`, `debug`, `architect`, `ask`, `orchestrator`, soit 25 modes au total.

### 2.3 Correspondance entre architectures

Les deux architectures coexistent. Correspondance approximative :

| N2 | N5 |
|----|----|
| Simple | MINI / MEDIUM |
| Complex | LARGE / ORACLE |
| (pas d'equivalent) | MICRO |

### 2.4 Types de modes

| Type | Description |
|------|-------------|
| **Code** | Developpement, du bug simple a la conception de systemes |
| **Debug** | Debogage, de l'erreur de syntaxe aux problemes systemiques |
| **Architect** | Conception d'architecture, des suggestions a la conception distribuee |
| **Ask** | Reponses aux questions, des reponses courtes aux syntheses |
| **Orchestrator** | Orchestration de taches, de la delegation simple a la coordination complexe |
| **Manager** | Decomposition de taches complexes en sous-taches (N2 complex uniquement) |

---

## 3. Deploiement des modes

### 3.1 Workflow recommande

```powershell
# 1. Deployer les parametres globaux (settings.json, submodules Git)
.\settings\deploy-settings.ps1

# 2. Deployer les modes
.\scripts\Deploy-Modes.ps1

# 3. Verifier le deploiement
.\scripts\deploy.ps1 -Verify   # ou un diagnostic
```

Apres deploiement, **redemarrer VS Code** pour que les modes prennent effet.

### 3.2 Methodes de deploiement

#### Deploiement global

Installe les modes pour tous les projets de l'utilisateur. Le fichier est copie vers :
```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json
```

#### Deploiement local

Cree un fichier `.roomodes` a la racine du projet en cours. Ce fichier est prioritaire sur la configuration globale.

#### Deploiement via Git

Pour deployer sur plusieurs machines :
1. Cloner/mettre a jour le depot `roo-extensions`
2. Executer le script de deploiement sur chaque machine
3. Le script gere l'encodage UTF-8 et la sauvegarde automatique

### 3.3 Deploiement avec profils

Les modeles sont geres via des profils plutot que directement dans les modes :

```powershell
# Deploiement avec un profil specifique
.\deployment-scripts\deploy-modes-simple-complex.ps1
```

### 3.4 Encodage UTF-8

**Regle critique** : Les fichiers JSON de modes doivent etre en UTF-8 **sans BOM**. L'utilisation de `ConvertFrom-Json`/`ConvertTo-Json` en PowerShell peut alterer la structure et l'encodage. La solution recommandee est de traiter le JSON comme du texte brut :

```powershell
$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($destinationFile, $jsonContent, $utf8NoBomEncoding)
```

Les scripts de correction d'encodage sont disponibles dans `encoding-scripts/`.

---

## 4. Escalade et desescalade

### 4.1 Principe

Les mecanismes d'escalade et desescalade permettent d'adapter dynamiquement le niveau de complexite :
- **Escalade** : passage a un niveau superieur quand la tache depasse les capacites du mode actuel
- **Desescalade** : passage a un niveau inferieur quand la tache est plus simple que prevu

### 4.2 Types d'escalade (par priorite)

#### Escalade par branchement (haute priorite)
Creation de sous-taches traitees a un niveau superieur, sans quitter le mode actuel.
```
[ESCALADE PAR BRANCHEMENT] Creation de sous-tache de niveau LARGE car: [RAISON]
```

#### Escalade par changement de mode (moyenne priorite)
Passage complet a un mode de niveau superieur pour toute la tache.
```
[ESCALADE NIVEAU ORACLE] Cette tache necessite le niveau ORACLE car: [RAISON]
```
```xml
<switch_mode>
<mode_slug>code-large</mode_slug>
<reason>Cette tache necessite le niveau LARGE car: [RAISON]</reason>
</switch_mode>
```

#### Escalade par terminaison (basse priorite)
Arret de la tache actuelle pour reprise a un niveau superieur.
```
[ESCALADE PAR TERMINAISON] Cette tache doit etre reprise au niveau LARGE car: [RAISON]
```

### 4.3 Criteres d'escalade (N2)

Une tache doit etre escaladee si elle correspond a au moins un de ces criteres :
- Modifications de plus de 50 lignes de code
- Refactorisations majeures
- Conception d'architecture
- Optimisations de performance
- Analyse approfondie
- Systemes ou composants interdependants

### 4.4 Desescalade

Format standard :
```
[DESESCALADE SUGGEREE] Cette tache pourrait etre traitee par le niveau MINI car: [RAISON]
```

Criteres : la tache remplit TOUS les criteres suivants :
- Modifications < 50 lignes
- Fonctionnalites isolees
- Patterns standards
- Pas d'optimisations complexes
- Pas d'analyse architecturale approfondie

### 4.5 Gestion des tokens

- Depassement de 50 000 tokens en mode simple : recommander le mode complex
- Depassement de 100 000 tokens : recommander le mode orchestration pour diviser la tache

### 4.6 Escalade interne

Lorsque la tache est a la limite, le mode simple peut traiter en interne :
```
[ESCALADE INTERNE] Cette tache est traitee en mode avance car: [RAISON]
```
Signaler en fin de reponse : `[SIGNALER_ESCALADE_INTERNE]`

---

## 5. Configuration des modeles

### 5.1 Fichier model-configs.json

Le fichier `model-configs.json` definit des profils qui associent des modeles LLM aux modes. Cela permet de changer de provider sans modifier la definition des modes.

Structure :
```json
{
  "profiles": [
    {
      "name": "Configuration actuelle",
      "description": "Qwen 3 32B (simple) + Claude 3.7 Sonnet (complex)",
      "modeOverrides": {
        "code-simple": "qwen/qwen3-32b",
        "code-complex": "anthropic/claude-3.7-sonnet",
        ...
      }
    }
  ]
}
```

### 5.2 Profils disponibles

| Profil | Simple | Complex |
|--------|--------|---------|
| Configuration actuelle | Qwen 3 32B | Claude 3.7 Sonnet |
| Configuration SDDD | GLM 4.7 Air (z.ai) | GLM 4.7 (z.ai) |
| Configuration Gemini | Qwen 3 32B | Gemini 2.5 Pro |

### 5.3 Modeles locaux

Pour utiliser des modeles locaux (LLM heberges localement), configurer les endpoints dans `roo.modelConfigs` de VS Code :

```json
{
  "id": "local/micro",
  "displayName": "Local Micro Model",
  "apiType": "openai",
  "apiBase": "http://localhost:8001/v1",
  "apiKey": "sk-your-local-api-key",
  "contextWindow": 8000,
  "maxOutputTokens": 2000
}
```

Puis associer les modes aux endpoints dans le fichier `.roomodes` ou via un profil.

---

## 6. Verrouillage de famille (family lock)

### 6.1 Problematique

Sans verrouillage, les modes simples/complexes peuvent basculer vers les modes standard de Roo, rompant la coherence du systeme.

### 6.2 Solution

Le systeme de verrouillage repose sur :

1. **mode-family-validator** : un pseudo-mode qui definit les familles et leurs membres
2. **Metadonnees de famille** : chaque mode porte `family` et `allowedFamilyTransitions`
3. **Instructions renforcees** : les instructions systeme interdisent les transitions hors famille

```json
{
  "slug": "mode-family-validator",
  "familyDefinitions": {
    "simple": ["code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple"],
    "complex": ["code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex", "manager"]
  }
}
```

```json
{
  "slug": "code-simple",
  "family": "simple",
  "allowedFamilyTransitions": ["simple"]
}
```

### 6.3 Regle de transition

Un mode ne peut transitionner (via `switch_mode`) que vers un mode de la meme famille. Les instructions systeme de chaque mode listent explicitement les modes cibles autorises.

---

## 7. Import et export de configuration

### 7.1 Emplacements des fichiers

| OS | Chemin |
|----|--------|
| Windows | `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\` |
| macOS | `~/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/` |
| Linux | `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/` |

Fichier principal : `custom_modes.json`

### 7.2 Export/Import manuel

**Export** : copier `custom_modes.json` vers un emplacement partage (depot Git, Google Drive).

**Import** : copier le fichier vers le repertoire cible, puis redemarrer VS Code.

### 7.3 Synchronisation multi-machines

La methode recommandee est d'utiliser le depot Git `roo-extensions` :
1. Les definitions de modes sont versionnees dans `roo-config/modes/`
2. Chaque machine execute le script de deploiement
3. Les profils de modeles sont adaptes par machine si necessaire

---

## 8. Tests et validation

### 8.1 Tests d'escalade et desescalade

Scripts de test JavaScript dans `tests/` :
- `test-escalade.js` : valide les seuils et mecanismes d'escalade
- `test-desescalade.js` : valide les mecanismes de desescalade

Execution :
```powershell
node tests/test-escalade.js
node tests/test-desescalade.js
```

### 8.2 Ce que les tests verifient

- Presence des mecanismes d'escalade/desescalade dans les instructions personnalisees
- Coherence des seuils entre niveaux (progressifs)
- Formats standardises des messages d'escalade
- Simulation de scenarios (complexite de code, taille de conversation, nombre de tokens)

### 8.3 Resultats

Les resultats sont sauvegardes en JSON dans `tests/results/` :
- `escalation-test-results-[TIMESTAMP].json`
- `deescalation-test-results-[TIMESTAMP].json`
- `transition-test-results-[TIMESTAMP].json`

### 8.4 Test apres deploiement

Verification manuelle recommandee :
1. Redemarrer VS Code
2. Ouvrir la palette de commandes (Ctrl+Shift+P)
3. Taper "Roo: Switch Mode"
4. Verifier que les modes personnalises apparaissent
5. Tester un mode simple avec une tache complexe pour valider l'escalade

---

## 9. Structure des dossiers

```
roo-config/
|-- README.md                       # Ce fichier
|-- model-configs.json              # Profils de modeles (association mode->LLM)
|-- escalation-test-config.json     # Configuration de test d'escalade
|-- sync-config.ref.json            # Reference de configuration sync
|
|-- modes/                          # Definitions des modes
|   |-- standard-modes.json         # Modes N5 (25 modes, incluant N2)
|   |-- n2-standard-modes.json      # Modes N2 uniquement (10 modes)
|   |-- generated-profile-modes.json # Modes generes par profil
|   +-- pilot-simple-complex.roomodes # Pilote modes simple/complex
|
|-- scripts/                        # Scripts de deploiement et maintenance
|   |-- Deploy-Modes.ps1            # Deploiement des modes
|   |-- deploy.ps1                  # Deploiement general
|   |-- verify-remote-access.ps1    # Verification acces distant
|   |-- update-mcp-optimizations.ps1 # MAJ optimisations MCP
|   +-- Invoke-ClaudeEscalation.ps1 # Escalade via Claude
|
|-- settings/                       # Parametres de configuration VS Code
|   +-- deploy-settings.ps1         # Deploiement des settings globaux
|
|-- encoding-scripts/               # Correction d'encodage UTF-8
|-- deployment-scripts/             # Scripts de deploiement additionnels
|-- diagnostic-scripts/             # Diagnostic encodage et validite JSON
|-- config-templates/               # Modeles de fichiers de configuration
|-- config-backups/                 # Sauvegardes automatiques
|-- examples/                       # Exemples de configuration
|-- tests/                          # Tests d'escalade et desescalade
|-- scheduler/                      # Planificateur d'orchestration quotidienne
|-- docs/                           # Documentation interne supplementaire
|-- guides/                         # Guides d'utilisation
|-- specifications/                 # Specifications techniques
|-- sddd/                           # Methodologie SDDD
+-- documentation-archive/          # Archives de documentation
```

---

## 10. Scheduler (planificateur)

Le sous-repertoire `scheduler/` contient un systeme d'orchestration quotidienne automatisee :

- `config.json` : Configuration du planificateur
- `daily-orchestration.json` : Definition des taches quotidiennes
- `daily-orchestration-log.json` : Journal d'execution
- `orchestration-engine.ps1` : Moteur d'orchestration (script PowerShell)

Le planificateur gere l'execution programmee des taches Roo (synchronisation, deploiement, tests) selon un calendrier configurable.

Pour la documentation detaillee, consulter `scheduler/README.md`.

---

## 11. Troubleshooting

### Les modes ne s'affichent pas dans VS Code

1. **Verifier le JSON** : Le fichier doit etre un JSON valide
   ```powershell
   Get-Content "custom_modes.json" | ConvertFrom-Json
   ```
2. **Verifier l'encodage** : UTF-8 sans BOM obligatoire
   ```powershell
   $bytes = [System.IO.File]::ReadAllBytes("custom_modes.json")
   if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
       Write-Host "BOM detecte - a corriger"
   }
   ```
3. **Verifier l'emplacement** : Le fichier doit etre dans le bon repertoire (global ou local `.roomodes`)
4. **Redemarrer VS Code** apres tout deploiement

### Perte de familyDefinitions apres deploiement

Cause : `ConvertFrom-Json`/`ConvertTo-Json` altere la structure. Solution : utiliser la copie en texte brut avec encodage UTF-8 explicite (voir section 3.4).

### Les mecanismes d'escalade ne fonctionnent pas

1. Verifier que `mode-family-validator` est present dans la configuration
2. Verifier que chaque mode a les proprietes `family` et `allowedFamilyTransitions`
3. Verifier que les `customInstructions` contiennent les sections d'escalade/desescalade
4. Redemarrer VS Code

### Problemes de transition entre modes

- Le mode cible doit appartenir a la meme famille que le mode actuel (family lock)
- Utiliser le format correct pour `switch_mode`
- Verifier que le mode cible existe dans la configuration deployee

### Conflits de slugs entre modes

Extraire et comparer les slugs :
```powershell
$config = Get-Content "custom_modes.json" | ConvertFrom-Json
$config.customModes | Select-Object slug | Sort-Object slug
```

### Erreurs de deploiement

- Executer PowerShell avec les droits suffisants
- Verifier que le repertoire de destination existe
- Utiliser l'option `-Force` pour ecraser les fichiers existants

---

## 12. Bonnes pratiques pour les prompts

### Principes generaux

1. **Reduction de la verbosite** : Eliminer les redondances, simplifier les instructions
2. **Structuration efficace** : Hierarchiser du general au specifique, sections clairement delimitees
3. **Contextualisation intelligente** : Adapter le niveau de detail au modele, charger le contexte a la demande
4. **Priorite aux MCPs** : Privilegier les MCP (quickfiles, jinavigator, searxng) par rapport aux outils standards necessitant validation humaine

### Gestion des fichiers volumineux

- Ne jamais ouvrir un fichier volumineux dans son integralite
- Utiliser `start_line`/`end_line` pour lire des sections specifiques
- Creer des sous-taches dediees pour traiter les fichiers volumineux

### Nettoyage des fichiers intermediaires

A la fin de chaque tache, identifier et supprimer les fichiers temporaires crees. Documenter les fichiers conserves dans le rapport final.

### Commits reguliers

- Commits apres chaque etape logique completee
- Messages descriptifs : `type(scope): description`
- Types : `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

---

## References

- [README principal du projet](../README.md)
- [Documentation des MCPs](../mcps/README.md)
- [Planificateur Roo](scheduler/README.md)

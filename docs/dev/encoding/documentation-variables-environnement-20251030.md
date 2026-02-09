# Documentation des Variables d'Environnement Standardisées UTF-8

**Date**: 2025-10-30
**Version**: 1.0
**Statut**: Validé
**ID**: DOC-ENV-001

## 1. Introduction

Ce document définit les standards pour la configuration des variables d'environnement sur les systèmes Windows 11 Pro français afin de garantir un support UTF-8 complet et cohérent. Cette standardisation est critique pour éviter les problèmes d'encodage dans les scripts, les logs et les échanges de données.

## 2. Principes Directeurs

1.  **UTF-8 par défaut**: Toutes les variables liées à la locale et à l'encodage doivent forcer UTF-8.
2.  **Hiérarchie stricte**: Machine > User > Processus. Les conflits doivent être résolus en faveur de la configuration Machine pour les paramètres système, et User pour les préférences utilisateur.
3.  **Persistance**: Les variables critiques doivent être persistantes (registre) et survivre aux redémarrages.
4.  **Compatibilité**: La configuration doit maintenir la compatibilité avec les outils existants (PowerShell, Node.js, Python, Git).

## 3. Variables Standardisées

### 3.1 Variables de Locale et Encodage (Processus)

Ces variables contrôlent comment les applications interprètent et génèrent du texte.

| Variable | Valeur Standard | Description | Impact |
| :--- | :--- | :--- | :--- |
| `LANG` | `fr-FR.UTF-8` | Langue et encodage par défaut | Définit la locale principale pour les outils GNU/Linux portés et certains runtimes. |
| `LC_ALL` | `fr_FR.UTF-8` | Surcharge toutes les catégories LC_* | Force la locale pour tous les aspects (tri, temps, numérique, etc.). |
| `PYTHONIOENCODING` | `utf-8` | Encodage E/S Python | Garantit que Python lit/écrit en UTF-8 sur stdin/stdout/stderr. |
| `NODE_OPTIONS` | `--max-old-space-size=4096` | Options globales Node.js | Augmente la mémoire pour les gros traitements (ne concerne pas directement l'encodage mais standardisé ici). |
| `JAVA_TOOL_OPTIONS` | `-Dfile.encoding=UTF-8` | Options globales Java | Force l'encodage de fichier par défaut pour la JVM. |

### 3.2 Variables Système Critiques (Machine)

Ces variables définissent l'environnement de base du système.

| Variable | Valeur Standard | Description |
| :--- | :--- | :--- |
| `COMSPEC` | `C:\Windows\system32\cmd.exe` | Interpréteur de commande par défaut. |
| `TEMP` / `TMP` | `C:\Windows\Temp` | Répertoires temporaires système. |
| `SystemRoot` | `C:\Windows` | Racine du système Windows. |

### 3.3 Variables Utilisateur (User)

Ces variables sont spécifiques au profil utilisateur.

| Variable | Valeur Standard | Description |
| :--- | :--- | :--- |
| `HOME` | `%USERPROFILE%` | Répertoire personnel (standard Unix/Linux). |
| `EDITOR` | `code --wait` | Éditeur de texte par défaut (VS Code). |
| `VISUAL` | `code --wait` | Éditeur visuel par défaut. |

## 4. Configuration Git

Git nécessite une configuration spécifique pour gérer correctement les chemins et les fichiers UTF-8 sous Windows.

| Variable | Valeur | Description |
| :--- | :--- | :--- |
| `GIT_CONFIG_CORE_QUOTE_PATH` | `false` | Affiche les caractères non-ASCII tels quels dans les chemins (ne les échappe pas). |
| `GIT_CONFIG_CORE_PRECOMPOSE_UNICODE` | `true` | Normalise les caractères Unicode (NFC) pour la compatibilité macOS/Linux. |
| `GIT_CONFIG_CORE_AUTOCRLF` | `false` | Désactive la conversion automatique CRLF (préférer LF en fin de ligne). |

## 5. Procédures

### 5.1 Validation de l'Environnement

Utiliser le script `Test-StandardizedEnvironment.ps1` pour vérifier la conformité.

```powershell
.\scripts\encoding\Test-StandardizedEnvironment.ps1 -Detailed
```

### 5.2 Application des Standards

Utiliser le script `Set-StandardizedEnvironment.ps1` pour appliquer la configuration.

```powershell
# Mode simulation (recommandé d'abord)
.\scripts\encoding\Set-StandardizedEnvironment.ps1 -ValidateOnly

# Application des changements
.\scripts\encoding\Set-StandardizedEnvironment.ps1 -Force
```

### 5.3 Dépannage

**Symptôme**: Caractères accentués s'affichent mal dans la console.
**Solution**: Vérifier que la page de code active est 65001 (`chcp`). Le script de validation le vérifie.

**Symptôme**: Python erreur `UnicodeEncodeError`.
**Solution**: Vérifier `PYTHONIOENCODING=utf-8`.

**Symptôme**: Chemins de fichiers tronqués ou illisibles dans Git.
**Solution**: Vérifier `GIT_CONFIG_CORE_QUOTE_PATH=false`.

## 6. Références

- [Windows Console Code Pages](https://learn.microsoft.com/en-us/windows/console/console-code-pages)
- [Python Command Line and Environment](https://docs.python.org/3/using/cmdline.html#envvar-PYTHONIOENCODING)
- [Node.js Environment Variables](https://nodejs.org/api/cli.html#environment-variables)
- [Git Configuration](https://git-scm.com/docs/git-config)
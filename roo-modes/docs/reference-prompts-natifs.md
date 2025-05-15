# Référence aux prompts et configurations natives de Roo

Ce document explique comment accéder aux prompts et configurations natives de Roo, comment les comparer avec vos modes personnalisés, et comment suivre les changements récents dans les prompts système par défaut.

## Table des matières

1. [Accès aux prompts et configurations natives](#1-accès-aux-prompts-et-configurations-natives)
   - [Accès via le dépôt GitHub officiel](#11-accès-via-le-dépôt-github-officiel)
   - [Accès via les fichiers locaux](#12-accès-via-les-fichiers-locaux)
2. [Fichiers sources de référence](#2-fichiers-sources-de-référence)
   - [Structure du dépôt Roo](#21-structure-du-dépôt-roo)
   - [Fichiers clés pour les prompts système](#22-fichiers-clés-pour-les-prompts-système)
3. [Comparaison et fusion avec les modes personnalisés](#3-comparaison-et-fusion-avec-les-modes-personnalisés)
   - [Analyse des différences](#31-analyse-des-différences)
   - [Techniques de fusion](#32-techniques-de-fusion)
   - [Outils recommandés](#33-outils-recommandés)
4. [Changements récents dans les prompts système](#4-changements-récents-dans-les-prompts-système)
   - [Évolutions majeures](#41-évolutions-majeures)
   - [Bonnes pratiques actuelles](#42-bonnes-pratiques-actuelles)
5. [Exemples pratiques](#5-exemples-pratiques)
   - [Extraction d'un prompt natif](#51-extraction-dun-prompt-natif)
   - [Fusion avec un prompt personnalisé](#52-fusion-avec-un-prompt-personnalisé)

## 1. Accès aux prompts et configurations natives

### 1.1 Accès via le dépôt GitHub officiel

Le moyen le plus direct et fiable d'accéder aux prompts et configurations natives de Roo est de consulter le dépôt GitHub officiel :

```
https://github.com/RooVetGit/Roo-Code
```

Ce dépôt contient le code source de Roo, y compris tous les prompts système par défaut et les configurations natives. Pour accéder aux prompts système :

1. Clonez le dépôt localement :
   ```bash
   git clone https://github.com/RooVetGit/Roo-Code.git
   cd Roo-Code
   ```

2. Naviguez vers le répertoire des prompts système :
   ```bash
   cd src/prompts
   ```

3. Consultez les fichiers de prompts pour chaque mode :
   ```bash
   ls -la
   ```

### 1.2 Accès via les fichiers locaux

Si vous avez déjà installé l'extension Roo dans VS Code, vous pouvez accéder aux prompts natifs directement depuis votre système de fichiers local :

**Windows** :
```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\
```

**macOS** :
```
~/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/
```

**Linux** :
```
~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/
```

Dans ce répertoire, vous trouverez :
- `settings/` : Contient les configurations globales
- `modes/` : Contient les définitions des modes par défaut
- `system_prompts/` : Contient les prompts système natifs

## 2. Fichiers sources de référence

### 2.1 Structure du dépôt Roo

Le dépôt GitHub de Roo est organisé comme suit :

```
Roo-Code/
├── src/
│   ├── prompts/                 # Prompts système par défaut
│   │   ├── architect.md         # Prompt du mode Architect
│   │   ├── ask.md               # Prompt du mode Ask
│   │   ├── code.md              # Prompt du mode Code
│   │   ├── debug.md             # Prompt du mode Debug
│   │   ├── orchestrator.md      # Prompt du mode Orchestrator
│   │   └── manager.md           # Prompt du mode Manager
│   ├── modes/                   # Définitions des modes
│   │   └── default-modes.json   # Configuration des modes par défaut
│   └── config/                  # Configurations globales
│       └── default-config.json  # Configuration globale par défaut
└── docs/                        # Documentation
    └── prompts/                 # Documentation sur les prompts
        └── prompt-guidelines.md # Directives pour les prompts
```

### 2.2 Fichiers clés pour les prompts système

Les fichiers les plus importants pour comprendre les prompts natifs sont :

1. **`src/prompts/`** : Ce répertoire contient tous les prompts système par défaut pour chaque mode. Ces fichiers sont la référence officielle pour comprendre comment les modes natifs sont conçus.

2. **`src/modes/default-modes.json`** : Ce fichier définit la configuration des modes par défaut, y compris les associations entre les modes et leurs prompts système.

3. **`docs/prompts/prompt-guidelines.md`** : Ce document contient les directives officielles pour la création et la maintenance des prompts système.

4. **`src/config/default-config.json`** : Ce fichier contient la configuration globale par défaut, y compris les paramètres qui affectent le comportement des prompts système.

## 3. Comparaison et fusion avec les modes personnalisés

### 3.1 Analyse des différences

Pour comparer efficacement les prompts natifs avec vos prompts personnalisés :

1. **Extraction des prompts** : Extrayez le prompt natif du dépôt GitHub ou des fichiers locaux.

2. **Comparaison structurelle** : Utilisez un outil de diff pour comparer la structure et le contenu des prompts.
   ```bash
   diff -u chemin/vers/prompt-natif.md chemin/vers/prompt-personnalise.md > differences.diff
   ```

3. **Analyse des sections** : Identifiez les sections qui diffèrent et déterminez si ces différences sont intentionnelles ou si elles devraient être synchronisées avec le prompt natif.

### 3.2 Techniques de fusion

Pour fusionner efficacement les prompts natifs avec vos prompts personnalisés :

1. **Approche par sections** : Divisez les prompts en sections logiques et fusionnez-les section par section.

2. **Conservation des personnalisations** : Identifiez et conservez les personnalisations importantes tout en intégrant les améliorations des prompts natifs.

3. **Utilisation de marqueurs de commentaires** : Utilisez des marqueurs de commentaires pour identifier les sections personnalisées :
   ```
   <!-- DÉBUT PERSONNALISATION -->
   Votre contenu personnalisé ici
   <!-- FIN PERSONNALISATION -->
   ```

4. **Script de fusion automatisée** : Créez un script PowerShell pour automatiser la fusion des prompts :
   ```powershell
   .\roo-modes\scripts\merge-prompts.ps1 -NativePrompt "chemin/vers/prompt-natif.md" -CustomPrompt "chemin/vers/prompt-personnalise.md" -OutputPath "chemin/vers/prompt-fusionne.md"
   ```

### 3.3 Outils recommandés

Pour faciliter la comparaison et la fusion des prompts :

1. **VS Code** : Utilisez l'extension "Compare" pour comparer visuellement les fichiers.

2. **Beyond Compare** : Un outil puissant pour comparer et fusionner des fichiers texte.

3. **Git** : Utilisez les fonctionnalités de diff et de merge de Git :
   ```bash
   git diff --no-index chemin/vers/prompt-natif.md chemin/vers/prompt-personnalise.md
   ```

4. **Meld** : Un outil visuel de diff et merge qui facilite la fusion de fichiers.

## 4. Changements récents dans les prompts système

### 4.1 Évolutions majeures

Les prompts système de Roo ont connu plusieurs évolutions majeures récentes :

1. **Structuration en sections** : Les prompts sont désormais organisés en sections clairement définies (CAPABILITIES, RULES, OBJECTIVE, etc.).

2. **Mécanismes d'escalade et de désescalade** : Introduction de mécanismes permettant de passer d'un niveau de complexité à un autre en fonction des besoins.

3. **Intégration des MCPs** : Support amélioré pour les Model Context Protocol servers qui étendent les capacités de Roo.

4. **Gestion des tokens** : Mécanismes avancés pour gérer efficacement les limites de tokens et optimiser les conversations longues.

5. **Directives de sécurité renforcées** : Ajout de règles plus strictes pour la manipulation de fichiers sensibles et l'exécution de commandes.

### 4.2 Bonnes pratiques actuelles

Les bonnes pratiques actuelles pour les prompts système de Roo incluent :

1. **Structure standardisée** : Utilisation d'une structure cohérente avec des sections clairement définies.

2. **Instructions explicites** : Formulation claire et explicite des instructions pour éviter les ambiguïtés.

3. **Exemples concrets** : Inclusion d'exemples pour illustrer les comportements attendus.

4. **Gestion des erreurs** : Instructions spécifiques sur la gestion des erreurs et des cas limites.

5. **Optimisation des tokens** : Techniques pour minimiser l'utilisation de tokens tout en maintenant la clarté des instructions.

## 5. Exemples pratiques

### 5.1 Extraction d'un prompt natif

Voici comment extraire un prompt natif du dépôt GitHub de Roo :

```powershell
# Cloner le dépôt Roo
git clone https://github.com/RooVetGit/Roo-Code.git temp-roo-code

# Extraire le prompt du mode Code
$codePrompt = Get-Content -Path "temp-roo-code/src/prompts/code.md" -Raw

# Sauvegarder le prompt dans un fichier local pour référence
$codePrompt | Out-File -FilePath "roo-modes/references/native-code-prompt.md" -Encoding utf8

# Nettoyer
Remove-Item -Recurse -Force temp-roo-code
```

### 5.2 Fusion avec un prompt personnalisé

Voici un exemple de script PowerShell pour fusionner un prompt natif avec un prompt personnalisé :

```powershell
function Merge-Prompts {
    param (
        [string]$NativePromptPath,
        [string]$CustomPromptPath,
        [string]$OutputPath
    )

    # Lire les prompts
    $nativePrompt = Get-Content -Path $NativePromptPath -Raw
    $customPrompt = Get-Content -Path $CustomPromptPath -Raw

    # Extraire les sections (exemple simplifié)
    $nativeSections = Extract-Sections $nativePrompt
    $customSections = Extract-Sections $customPrompt

    # Fusionner les sections
    $mergedSections = @{}
    foreach ($key in $nativeSections.Keys) {
        if ($customSections.ContainsKey($key)) {
            # Si la section existe dans le prompt personnalisé, utiliser celle-ci
            $mergedSections[$key] = $customSections[$key]
        } else {
            # Sinon, utiliser la section native
            $mergedSections[$key] = $nativeSections[$key]
        }
    }

    # Ajouter les sections personnalisées qui n'existent pas dans le prompt natif
    foreach ($key in $customSections.Keys) {
        if (-not $nativeSections.ContainsKey($key)) {
            $mergedSections[$key] = $customSections[$key]
        }
    }

    # Reconstruire le prompt fusionné
    $mergedPrompt = Build-Prompt $mergedSections

    # Sauvegarder le résultat
    $mergedPrompt | Out-File -FilePath $OutputPath -Encoding utf8
}

# Exemple d'utilisation
Merge-Prompts -NativePromptPath "native-code-prompt.md" -CustomPromptPath "custom-code-prompt.md" -OutputPath "merged-code-prompt.md"
```

---

En suivant ce guide, vous pourrez accéder aux prompts et configurations natives de Roo, les comparer avec vos modes personnalisés, et rester informé des changements récents dans les prompts système par défaut. Cela vous permettra de maintenir vos modes personnalisés à jour tout en préservant vos personnalisations spécifiques.
<!-- START_SECTION: metadata -->
---
title: "Guide de recherche dans la documentation MCP"
description: "Comment rechercher efficacement dans la documentation des serveurs MCP"
tags: #documentation #mcp #search #guide
date_created: "2025-05-14"
date_updated: "2025-05-14"
version: "1.0.0"
author: "Équipe MCP"
---
<!-- END_SECTION: metadata -->

# Guide de recherche dans la documentation MCP

<!-- START_SECTION: introduction -->
## Introduction

Ce guide explique comment rechercher efficacement des informations dans la documentation des serveurs MCP (Model Context Protocol). La documentation est organisée de manière à faciliter la recherche d'informations spécifiques grâce à une structure cohérente, des balises de métadonnées et un système de tags.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: search_methods -->
## Méthodes de recherche

### 1. Recherche par structure de fichiers

La documentation est organisée selon une structure hiérarchique claire :

```
mcps/
├── INDEX.md                  # Point d'entrée principal
├── README.md                 # Présentation générale
├── INSTALLATION.md           # Guide d'installation global
├── TROUBLESHOOTING.md        # Guide de dépannage global
├── SEARCH.md                 # Ce document
├── mcp-servers/              # MCPs internes
│   └── ...
└── external/            # MCPs externes
    └── ...
```

Pour trouver des informations :
1. Commencez par [INDEX.md](./INDEX.md) qui offre une vue d'ensemble de toute la documentation
2. Naviguez vers la section pertinente (MCPs internes ou externes)
3. Accédez au serveur MCP spécifique qui vous intéresse
4. Consultez le document approprié (README, INSTALLATION, CONFIGURATION, USAGE, TROUBLESHOOTING)

### 2. Recherche par tags

Tous les fichiers de documentation incluent des tags dans leurs métadonnées. Ces tags permettent de regrouper les documents par thème ou fonctionnalité.

#### Tags principaux

- **#installation** - Documents liés à l'installation des MCPs
- **#configuration** - Documents liés à la configuration des MCPs
- **#usage** - Documents liés à l'utilisation des MCPs
- **#troubleshooting** - Documents liés au dépannage des MCPs
- **#quickfiles** - Documents liés au MCP QuickFiles
- **#jinavigator** - Documents liés au MCP JinaNavigator
- **#jupyter** - Documents liés au MCP Jupyter
- **#docker** - Documents liés au MCP Docker
- **#filesystem** - Documents liés au MCP Filesystem
- **#git** - Documents liés au MCP Git
- **#github** - Documents liés au MCP GitHub
- **#searxng** - Documents liés au MCP SearXNG
- **#win-cli** - Documents liés au MCP Win-CLI

#### Recherche par tag avec grep

Pour rechercher tous les documents avec un tag spécifique :

```bash
# Sur Linux/macOS
grep -r "#installation" --include="*.md" ./mcps/

# Sur Windows (PowerShell)
Get-ChildItem -Path ./mcps/ -Filter *.md -Recurse | Select-String -Pattern "#installation"
```

### 3. Recherche par sections

Chaque document est divisé en sections clairement identifiées par des balises HTML commentées :

```markdown
<!-- START_SECTION: section_name -->
Contenu de la section
<!-- END_SECTION: section_name -->
```

Pour rechercher une section spécifique :

```bash
# Sur Linux/macOS
grep -r "START_SECTION: installation" --include="*.md" ./mcps/

# Sur Windows (PowerShell)
Get-ChildItem -Path ./mcps/ -Filter *.md -Recurse | Select-String -Pattern "START_SECTION: installation"
```

### 4. Recherche par mots-clés

Pour rechercher des mots-clés spécifiques dans toute la documentation :

```bash
# Sur Linux/macOS
grep -r "jupyter notebook" --include="*.md" ./mcps/

# Sur Windows (PowerShell)
Get-ChildItem -Path ./mcps/ -Filter *.md -Recurse | Select-String -Pattern "jupyter notebook"
```

### 5. Recherche avec des outils externes

Vous pouvez également utiliser des outils externes pour rechercher dans la documentation :

- **VSCode** : Utilisez la fonction de recherche globale (Ctrl+Shift+F) pour rechercher dans tous les fichiers
- **GitHub** : Si la documentation est hébergée sur GitHub, utilisez la fonction de recherche de GitHub
- **Outils de documentation** : Des outils comme MkDocs, Docusaurus ou GitBook peuvent être utilisés pour générer une documentation consultable
<!-- END_SECTION: search_methods -->

<!-- START_SECTION: search_examples -->
## Exemples de recherche

### Exemple 1 : Trouver des informations sur l'installation de QuickFiles

1. **Par structure** : Naviguez vers `mcps/mcp-servers/servers/quickfiles-server/INSTALLATION.md`
2. **Par tag** : Recherchez `#installation #quickfiles`
3. **Par section** : Recherchez `START_SECTION: installation` dans les fichiers liés à QuickFiles
4. **Par mot-clé** : Recherchez `"quickfiles installation"` dans toute la documentation

### Exemple 2 : Résoudre un problème avec Jupyter MCP

1. **Par structure** : Naviguez vers `mcps/mcp-servers/servers/jupyter-mcp-server/TROUBLESHOOTING.md`
2. **Par tag** : Recherchez `#troubleshooting #jupyter`
3. **Par section** : Recherchez `START_SECTION: jupyter_issues` dans les fichiers de dépannage
4. **Par mot-clé** : Recherchez `"jupyter error"` ou `"jupyter problem"` dans toute la documentation

### Exemple 3 : Trouver des exemples d'utilisation de Git MCP

1. **Par structure** : Naviguez vers `mcps/external/git/USAGE.md`
2. **Par tag** : Recherchez `#usage #git`
3. **Par section** : Recherchez `START_SECTION: examples` dans les fichiers liés à Git
4. **Par mot-clé** : Recherchez `"git example"` ou `"git usage"` dans toute la documentation
<!-- END_SECTION: search_examples -->

<!-- START_SECTION: advanced_search -->
## Recherche avancée

### Recherche combinée

Vous pouvez combiner plusieurs méthodes de recherche pour affiner vos résultats :

```bash
# Rechercher des problèmes de configuration dans les MCPs internes
grep -r "#configuration" --include="*.md" ./mcps/mcp-servers/ | grep "problem"

# Rechercher des exemples d'utilisation de Docker
grep -r "#docker #usage" --include="*.md" ./mcps/ | grep "example"
```

### Recherche avec contexte

Pour afficher le contexte autour des résultats de recherche :

```bash
# Afficher 3 lignes avant et après chaque correspondance
grep -r "jupyter notebook" --include="*.md" -A 3 -B 3 ./mcps/
```

### Recherche avec expressions régulières

Pour des recherches plus complexes, utilisez des expressions régulières :

```bash
# Rechercher toutes les URLs dans la documentation
grep -r -E "https?://[^\s]+" --include="*.md" ./mcps/

# Rechercher tous les exemples de code JSON
grep -r -A 10 -B 2 "```json" --include="*.md" ./mcps/
```
<!-- END_SECTION: advanced_search -->

<!-- START_SECTION: search_tools -->
## Outils de recherche recommandés

### Outils en ligne de commande

- **grep** : Outil standard disponible sur Linux/macOS
- **findstr** : Alternative à grep sur Windows
- **ripgrep (rg)** : Version moderne et rapide de grep
- **ag (The Silver Searcher)** : Alternative rapide à grep

### Éditeurs de texte et IDEs

- **Visual Studio Code** : Recherche puissante avec support des expressions régulières
- **Sublime Text** : Recherche rapide dans de multiples fichiers
- **Vim/Neovim** : Recherche avancée avec plugins comme fzf.vim
- **Emacs** : Recherche puissante avec des outils comme helm ou ivy

### Outils de documentation

- **MkDocs** : Générateur de documentation avec fonction de recherche intégrée
- **Docusaurus** : Outil de documentation avec recherche Algolia
- **GitBook** : Plateforme de documentation avec recherche avancée
- **Sphinx** : Générateur de documentation avec recherche intégrée
<!-- END_SECTION: search_tools -->

<!-- START_SECTION: best_practices -->
## Bonnes pratiques de recherche

1. **Commencez par l'index** : Utilisez [INDEX.md](./INDEX.md) comme point de départ pour naviguer dans la documentation

2. **Utilisez des mots-clés spécifiques** : Plus vos termes de recherche sont spécifiques, meilleurs seront les résultats

3. **Combinez les tags** : Utilisez plusieurs tags pour affiner votre recherche (par exemple, `#installation #jupyter`)

4. **Consultez les sections pertinentes** : Chaque document est divisé en sections logiques pour faciliter la navigation

5. **Utilisez la recherche contextuelle** : Affichez quelques lignes avant et après les résultats pour mieux comprendre le contexte

6. **Explorez les liens connexes** : Chaque document contient des liens vers des documents connexes qui peuvent être pertinents

7. **Vérifiez les métadonnées** : Les métadonnées en haut de chaque document contiennent des informations utiles comme la date de mise à jour
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: navigation -->
## Navigation

- [Retour à l'index](./INDEX.md)
- [Accueil](./README.md)
- [Installation](./INSTALLATION.md)
- [Dépannage](./TROUBLESHOOTING.md)
<!-- END_SECTION: navigation -->
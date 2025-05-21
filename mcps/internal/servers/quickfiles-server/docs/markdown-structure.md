# Fonctionnalités d'extraction de structure markdown

Ce document décrit les nouvelles fonctionnalités d'extraction de structure markdown ajoutées au MCP Quickfiles.

## Nouvel outil : `extract_markdown_structure`

Cet outil permet d'analyser les fichiers markdown et d'extraire les titres avec leurs numéros de ligne. Il est particulièrement utile pour générer des tables des matières, comprendre la structure d'un document markdown ou naviguer dans de grands fichiers markdown.

### Paramètres

- `paths` (obligatoire) : Tableau des chemins de fichiers markdown à analyser
- `max_depth` (optionnel, défaut: 6) : Profondeur maximale des titres à extraire (1=h1, 2=h1+h2, etc.)
- `include_context` (optionnel, défaut: false) : Inclure du contexte autour des titres
- `context_lines` (optionnel, défaut: 2) : Nombre de lignes de contexte à inclure avant et après chaque titre

### Exemple d'utilisation

```javascript
const result = await client.callTool('extract_markdown_structure', {
  paths: ['chemin/vers/fichier.md'],
  max_depth: 3,
  include_context: true,
  context_lines: 2
});
```

### Format de sortie

La sortie est formatée en texte markdown et contient :

- Le chemin du fichier analysé
- La liste des titres trouvés avec leurs numéros de ligne
- Le contexte autour de chaque titre (si demandé)
- Des statistiques sur la répartition des niveaux de titres

Exemple de sortie :

```
## Fichier: chemin/vers/fichier.md
5 titres trouvés:

- [Ligne 1] Titre principal
  - [Ligne 5] Section 1
    - [Ligne 9] Sous-section 1.1
  - [Ligne 13] Section 2
  - [Ligne 21] Section 3

Répartition des titres:
- h1: 1
- h2: 3
- h3: 1
```

## Extension de l'outil `list_directory_contents`

L'outil `list_directory_contents` a été étendu pour inclure des informations sur la structure des documents markdown. Pour chaque fichier markdown listé, des informations sur le nombre de titres par niveau sont affichées.

### Format de sortie étendu

Dans la sortie de `list_directory_contents`, les fichiers markdown incluent maintenant des informations sur leur structure :

```
📄 document.md - 15.2 KB (250 lignes) [h1: 1, h2: 5, h3: 10] - Modifié: 2025-05-15 11:30:00
```

Cette information permet de voir rapidement la complexité et la structure des documents markdown sans avoir à les ouvrir.

## Implémentation technique

Les fonctionnalités d'extraction de structure markdown sont implémentées dans la classe `QuickFilesServer` :

- La méthode `extractMarkdownHeadings` analyse le contenu markdown et extrait les titres
- La méthode `handleExtractMarkdownStructure` gère les requêtes pour l'outil `extract_markdown_structure`
- L'outil `list_directory_contents` a été modifié pour inclure des informations sur la structure markdown

Les titres sont détectés selon les formats suivants :
- Format ATX : `# Titre h1`, `## Titre h2`, etc.
- Format Setext : `Titre h1` suivi de `=======` ou `Titre h2` suivi de `-------`

## Tests

Un script de test est fourni pour vérifier le bon fonctionnement des nouvelles fonctionnalités :

```bash
# Sous Windows
test-markdown-structure.bat

# Sous Linux/macOS
npx ts-node ./__tests__/test-markdown-structure.js
```

Ce script crée un fichier markdown de test, exécute les deux outils et affiche les résultats.
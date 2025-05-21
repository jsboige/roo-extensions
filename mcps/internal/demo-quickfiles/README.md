# Démonstration du MCP QuickFiles

Ce dossier contient une démonstration pratique du MCP (Model Context Protocol) QuickFiles, qui permet d'interagir avec le système de fichiers de manière efficace et puissante.

## Présentation du MCP QuickFiles

Le MCP QuickFiles est un serveur qui fournit des outils pour manipuler des fichiers et des répertoires. Il offre les fonctionnalités suivantes :

1. **read_multiple_files** : Lecture de plusieurs fichiers en une seule requête
2. **list_directory_contents** : Listage du contenu des répertoires
3. **edit_multiple_files** : Modification de plusieurs fichiers en une seule opération
4. **delete_files** : Suppression de fichiers

## Structure de la démonstration

Cette démonstration comprend plusieurs scripts :

- `demo-setup.js` : Script de configuration qui crée les fichiers et répertoires nécessaires pour la démonstration
- `demo-quickfiles-mcp.js` : Démonstration complète qui simule les appels au MCP QuickFiles
- `demo-roo-quickfiles.js` : Script qui montre comment utiliser le MCP QuickFiles avec l'API Roo (version commentée)
- `demo-mcp-direct.js` : Script qui utilise directement l'API MCP pour interagir avec le serveur QuickFiles

## Prérequis

- Node.js (version 14 ou supérieure)
- Serveur MCP QuickFiles en cours d'exécution

## Utilisation

### 1. Démarrer le serveur MCP QuickFiles

Si le serveur n'est pas déjà en cours d'exécution, vous pouvez le démarrer avec la commande suivante :

```bash
node start-quickfiles-mcp.js
```

### 2. Configurer l'environnement de démonstration

Exécutez le script de configuration pour créer les fichiers et répertoires nécessaires :

```bash
node demo-quickfiles/demo-setup.js
```

### 3. Exécuter la démonstration

Vous pouvez exécuter la démonstration complète avec :

```bash
node demo-quickfiles/demo-quickfiles-mcp.js
```

## Fonctionnalités démontrées

### 1. read_multiple_files

Cette fonctionnalité permet de lire plusieurs fichiers en une seule requête. Elle offre les options suivantes :

- Lecture de plusieurs fichiers à la fois
- Limitation du nombre de lignes par fichier
- Extraction d'extraits spécifiques de fichiers
- Affichage des numéros de ligne

Exemple d'utilisation :

```javascript
const result = await useMcpTool({
  server_name: "quickfiles",
  tool_name: "read_multiple_files",
  arguments: {
    paths: [
      "./chemin/vers/fichier1.txt",
      "./chemin/vers/fichier2.txt"
    ],
    show_line_numbers: true,
    max_lines_per_file: 100
  }
});
```

### 2. list_directory_contents

Cette fonctionnalité permet de lister le contenu d'un ou plusieurs répertoires. Elle offre les options suivantes :

- Listage récursif ou non récursif
- Filtrage par motif de fichier (ex: *.txt)
- Tri par nom, taille, date de modification ou type
- Limitation du nombre de lignes dans la sortie

Exemple d'utilisation :

```javascript
const result = await useMcpTool({
  server_name: "quickfiles",
  tool_name: "list_directory_contents",
  arguments: {
    paths: [
      { 
        path: "./chemin/vers/repertoire", 
        recursive: true,
        file_pattern: "*.js"
      }
    ],
    sort_by: "name",
    sort_order: "asc"
  }
});
```

### 3. edit_multiple_files

Cette fonctionnalité permet de modifier plusieurs fichiers en une seule opération. Elle permet d'appliquer plusieurs modifications (diffs) à chaque fichier.

Exemple d'utilisation :

```javascript
const result = await useMcpTool({
  server_name: "quickfiles",
  tool_name: "edit_multiple_files",
  arguments: {
    files: [
      {
        path: "./chemin/vers/fichier1.txt",
        diffs: [
          {
            search: "texte à rechercher",
            replace: "texte de remplacement"
          }
        ]
      }
    ]
  }
});
```

### 4. delete_files

Cette fonctionnalité permet de supprimer plusieurs fichiers en une seule opération.

Exemple d'utilisation :

```javascript
const result = await useMcpTool({
  server_name: "quickfiles",
  tool_name: "delete_files",
  arguments: {
    paths: [
      "./chemin/vers/fichier1.txt",
      "./chemin/vers/fichier2.txt"
    ]
  }
});
```

## Avantages du MCP QuickFiles

- **Performance** : Opérations en lot qui réduisent le nombre d'appels nécessaires
- **Flexibilité** : Options avancées pour chaque opération
- **Simplicité** : Interface unifiée pour toutes les opérations sur les fichiers
- **Sécurité** : Contrôle d'accès aux fichiers et répertoires

## Conclusion

Le MCP QuickFiles est un outil puissant pour manipuler des fichiers et des répertoires de manière efficace. Cette démonstration montre comment utiliser ses principales fonctionnalités et comment l'intégrer dans vos applications.
# MCPs Internes pour Roo

Ce répertoire contient les serveurs MCP (Model Context Protocol) développés en interne dans le cadre du projet Roo Extensions. Ces serveurs MCP correspondent au sous-module jsboige-mcp-servers qui est intégré dans ce dépôt.

## Qu'est-ce qu'un MCP ?

Le Model Context Protocol (MCP) est un protocole qui permet à Roo d'interagir avec des services externes pour étendre ses capacités. Les serveurs MCP fournissent des outils et des ressources supplémentaires que Roo peut utiliser pour accomplir diverses tâches.

## MCPs Internes Disponibles

### QuickFiles

QuickFiles est un serveur MCP qui permet des opérations avancées sur les fichiers, avec une attention particulière à la performance et à la gestion de fichiers multiples.

**Fonctionnalités principales :**
- Lecture de plusieurs fichiers en une seule requête
- Listage de répertoires avec options avancées (récursif, filtrage, tri)
- Recherche et remplacement dans les fichiers
- Édition de fichiers multiples en une seule opération
- Extraction de structure Markdown

**Utilisation typique :**
```javascript
// Exemple d'utilisation avec Roo
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": ["chemin/vers/fichier1.txt", "chemin/vers/fichier2.txt"],
  "show_line_numbers": true
}
</arguments>
</use_mcp_tool>
```

### JinaNavigator

JinaNavigator est un serveur MCP qui permet la conversion de pages web en Markdown et l'extraction de contenu structuré à partir de pages web.

**Fonctionnalités principales :**
- Conversion de pages web en Markdown
- Extraction de plans hiérarchiques à partir de pages web
- Accès aux ressources web via URI au format jina://url
- Conversion de plusieurs pages web en une seule requête

**Utilisation typique :**
```javascript
// Exemple d'utilisation avec Roo
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>convert_web_to_markdown</tool_name>
<arguments>
{
  "url": "https://example.com"
}
</arguments>
</use_mcp_tool>
```

### Jupyter

Jupyter est un serveur MCP qui permet l'interaction avec des notebooks Jupyter, facilitant l'analyse de données et l'exécution de code Python.

**Fonctionnalités principales :**
- Création, lecture et modification de notebooks Jupyter
- Exécution de cellules de code
- Gestion des kernels (démarrage, arrêt, redémarrage)
- Exécution de notebooks complets

**Utilisation typique :**
```javascript
// Exemple d'utilisation avec Roo
<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>read_notebook</tool_name>
<arguments>
{
  "path": "chemin/vers/notebook.ipynb"
}
</arguments>
</use_mcp_tool>
```

## Installation et Configuration

### Prérequis

- Node.js (v14 ou supérieur)
- npm (v6 ou supérieur)
- Roo installé et configuré

### Installation

1. Assurez-vous que le sous-module jsboige-mcp-servers est correctement initialisé :
   ```bash
   git submodule update --init --recursive
   ```

2. Installez les dépendances :
   ```bash
   cd mcps/internal
   npm install
   ```

3. Configurez les serveurs MCP dans Roo :
   - Ouvrez VS Code avec l'extension Roo
   - Accédez aux paramètres de Roo (via l'icône de menu ⋮)
   - Allez dans la section "MCP Servers"
   - Ajoutez les configurations pour les serveurs MCP internes
   - Sauvegardez les paramètres
   - Redémarrez VS Code

### Configuration des serveurs MCP

#### QuickFiles

```json
{
  "name": "quickfiles",
  "command": "node path/to/mcps/internal/servers/quickfiles-server/build/index.js"
}
```

#### JinaNavigator

```json
{
  "name": "jinavigator",
  "command": "node path/to/mcps/internal/servers/jinavigator-server/dist/index.js"
}
```

#### Jupyter

```json
{
  "name": "jupyter",
  "command": "node path/to/mcps/internal/servers/jupyter-mcp-server/dist/index.js"
}
```

## Structure du répertoire

```
mcps/internal/
├── config/                 # Configurations pour les serveurs MCP
├── demo-quickfiles/        # Démos pour QuickFiles
├── docs/                   # Documentation des serveurs MCP
├── examples/               # Exemples d'utilisation
├── mcps/                   # Implémentations des serveurs MCP
├── scripts/                # Scripts utilitaires
├── servers/                # Code source des serveurs MCP
│   ├── quickfiles-server/  # Serveur QuickFiles
│   ├── jinavigator-server/ # Serveur JinaNavigator
│   └── jupyter-mcp-server/ # Serveur Jupyter
├── test-dirs/              # Répertoires pour les tests
└── tests/                  # Tests pour les serveurs MCP
```

## Tests

Les tests pour les serveurs MCP internes sont disponibles dans le répertoire `tests/`. Pour exécuter les tests :

```bash
cd mcps/internal
npm test
```

Des tests spécifiques pour chaque serveur MCP sont également disponibles dans le répertoire `tests/mcp/` du projet principal.

## Développement

Si vous souhaitez contribuer au développement des serveurs MCP internes, veuillez suivre ces directives :

1. Créez une branche pour vos modifications
2. Implémentez vos modifications
3. Ajoutez des tests pour vos modifications
4. Exécutez les tests pour vous assurer que tout fonctionne correctement
5. Soumettez une pull request

## Ressources supplémentaires

- [Documentation des MCPs externes](../external/README.md)
- [Guide d'utilisation des MCPs](../../docs/guides/guide-utilisation-mcps.md)
- [Rapport d'état des MCPs](../../docs/rapport-etat-mcps.md)
- [Rapport d'intégration des MCP servers](../../docs/rapports/rapport-integration-mcp-servers.md)
- [Rapport de test MCP](../../tests/mcp/rapport-test-mcp.md)
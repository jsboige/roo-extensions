# Analyse des Modes Utilisant MCP GitHub-Projects

**Date** : 2026-01-24
**Tâche** : T86 - Identifier les modes utilisant MCP github-projects
**Priorité** : 1

---

## Résumé Exécutif

**Résultat principal** : **Aucun mode Roo personnalisé n'utilise actuellement MCP github-projects**.

Le MCP `github-projects` est configuré et opérationnel dans le système, mais il n'est **pas intégré dans les instructions des modes personnalisés**. Les modes utilisent d'autres MCPs (quickfiles, jinavigator, searxng, win-cli, git) mais pas github-projects.

---

## 1. Méthodologie de Recherche

### 1.1 Recherche dans les fichiers de modes

**Dossiers explorés** :
- `.roomodes/` - Non trouvé
- `.roo/modes/` - Non trouvé
- `roo-modes/` - Analysé

**Recherches effectuées** :
- Recherche sémantique : "github-projects MCP usage modes"
- Recherche regex : `github-projects` dans `*.json`
- Recherche regex : `github-projects` dans `*.md`

### 1.2 Configuration MCP analysée

**Fichier** : [`roo-config/settings/servers.json`](../../roo-config/settings/servers.json:5)

```json
{
  "name": "github-projects",
  "type": "stdio",
  "command": "node ./mcps/internal/servers/github-projects-mcp/dist/index.js",
  "enabled": true,
  "autoStart": true,
  "description": "Serveur MCP pour interagir avec GitHub Projects",
  "workingDirectory": "./mcps/internal/servers/github-projects-mcp",
  "envFile": ".env"
}
```

**Statut** : ✅ Configuré et activé

---

## 2. Résultats de l'Analyse

### 2.1 Modes analysés

**Fichiers de configuration de modes** :
- `roo-modes/configs/standard-modes.json`
- `roo-modes/configs/standard-modes-fixed.json`
- `roo-modes/configs/vscode-custom-modes.json`
- `roo-modes/configs/refactored-modes.json`
- `roo-modes/configs/n2/n2-custom-instructions.json`
- `roo-modes/configs/n5/n5-custom-instructions.json`
- `roo-modes/configs/n5/levels/*.json`
- `roo-modes/n5/configs/*.json`
- `roo-modes/n5/scripts/n5-modes-complete.json`

**Résultat** : Aucune référence à `github-projects` dans ces fichiers.

### 2.2 MCPs utilisés dans les modes

D'après l'analyse des fichiers de modes, les MCPs suivants sont **explicitement mentionnés** dans les instructions :

| MCP | Utilisation | Documentation |
|------|-------------|---------------|
| **quickfiles** | Manipulations de fichiers multiples | ✅ Documenté |
| **jinavigator** | Extraction d'informations web | ✅ Documenté |
| **searxng** | Recherches web | ✅ Documenté |
| **win-cli** | Commandes système Windows | ✅ Documenté |
| **git** | Opérations Git | ✅ Documenté |
| **roo-state-manager** | Gestion d'état Roo | ✅ Documenté |
| **github-projects** | Projets GitHub | ❌ Non documenté |

### 2.3 Documentation existante sur github-projects

**Fichiers trouvés** :

1. **Tests et documentation technique** :
   - [`mcps/tests/github-projects/README.md`](../../mcps/tests/github-projects/README.md)
   - [`mcps/tests/github-projects/analyse-technique.md`](../../mcps/tests/github-projects/analyse-technique.md)
   - [`mcps/tests/github-projects/rapport-final.md`](../../mcps/tests/github-projects/rapport-final.md)

2. **Documentation RooSync** :
   - [`docs/roosync/guides/GLOSSAIRE.md`](../../docs/roosync/guides/GLOSSAIRE.md:112) - Outils principaux
   - [`docs/roosync/PROTOCOLE_SDDD.md`](../../docs/roosync/PROTOCOLE_SDDD.md:206) - Exemples d'appels

3. **Spécifications** :
   - [`roo-config/specifications/mcp-integrations-priority.md`](../../roo-config/specifications/mcp-integrations-priority.md:987) - Roadmap Phase 2.2+

---

## 3. Outils MCP GitHub-Projects Disponibles

D'après la documentation trouvée, le MCP `github-projects` expose les outils suivants :

### 3.1 Gestion de Projets

| Outil | Description | Équivalent gh CLI |
|--------|-------------|-------------------|
| `list_projects` | Lister les projets d'un utilisateur/org | `gh project list` |
| `create_project` | Créer un nouveau projet | `gh project create` |
| `get_project` | Récupérer les détails d'un projet | `gh project view` |
| `update_project` | Modifier titre/description/état | `gh project edit` |
| `delete_project` | Supprimer un projet | `gh project delete` |
| `archive_project` | Archiver un projet | `gh project close` |
| `unarchive_project` | Ré-ouvrir un projet | `gh project reopen` |

### 3.2 Gestion d'Items

| Outil | Description | Équivalent gh CLI |
|--------|-------------|-------------------|
| `get_project_items` | Obtenir les items d'un projet | `gh project item-list` |
| `add_item_to_project` | Ajouter un item (issue/PR/note) | `gh project item-add` |
| `delete_project_item` | Supprimer un item | `gh project item-delete` |
| `archive_project_item` | Archiver un item | `gh project item-archive` |
| `unarchive_project_item` | Désarchiver un item | `gh project item-unarchive` |

### 3.3 Gestion de Champs

| Outil | Description | Équivalent gh CLI |
|--------|-------------|-------------------|
| `create_project_field` | Créer un nouveau champ | `gh project field-create` |
| `update_project_field` | Renommer un champ | `gh project field-edit` |
| `delete_project_field` | Supprimer un champ | `gh project field-delete` |
| `update_project_item_field` | Mettre à jour la valeur d'un champ | `gh project item-edit` |

### 3.4 Gestion d'Issues

| Outil | Description | Équivalent gh CLI |
|--------|-------------|-------------------|
| `create_issue` | Créer une issue et l'ajouter à un projet | `gh issue create --project` |
| `update_issue_state` | Modifier l'état d'une issue | `gh issue close` / `gh issue reopen` |
| `list_repository_issues` | Lister les issues d'un dépôt | `gh issue list` |
| `get_repository_issue` | Récupérer les détails d'une issue | `gh issue view` |
| `delete_repository_issues` | Supprimer plusieurs issues | `gh issue delete` |

### 3.5 Workflows

| Outil | Description | Équivalent gh CLI |
|--------|-------------|-------------------|
| `list_repository_workflows` | Lister les workflows d'un dépôt | `gh workflow list` |
| `get_workflow_runs` | Récupérer les exécutions d'un workflow | `gh run list` |
| `get_workflow_run_status` | Obtenir le statut d'une exécution | `gh run view` |
| `get_workflow_run_jobs` | Récupérer les jobs d'une exécution | `gh run view --log` |

### 3.6 Recherche

| Outil | Description | Équivalent gh CLI |
|--------|-------------|-------------------|
| `search_repositories` | Rechercher des dépôts | `gh search repos` |
| `list_repositories` | Lister les dépôts d'un utilisateur/org | `gh repo list` |

---

## 4. Analyse de la Migration vers gh CLI

### 4.1 État actuel

- **MCP github-projects** : Configuré mais **non utilisé** dans les modes
- **gh CLI** : Disponible sur le système, utilisé pour certaines opérations

### 4.2 Avantages de la migration vers gh CLI

| Aspect | MCP github-projects | gh CLI |
|--------|---------------------|---------|
| **Maintenance** | Code TypeScript à maintenir | Maintenu par GitHub |
| **Mises à jour** | Manuelles | Automatiques |
| **Performance** | Via Node.js | Natif Go |
| **Dépendances** | Node.js, npm | Binaire unique |
| **Authentification** | GITHUB_TOKEN | gh auth login |
| **Complexité** | 57 outils MCP | Commandes unifiées |

### 4.3 Complexité de la migration

**Niveau de complexité** : **FAIBLE**

**Raison** : Aucun mode n'utilise actuellement MCP github-projects, donc la migration consiste principalement à :

1. **Documenter les équivalences** gh CLI pour les outils MCP
2. **Créer des exemples d'utilisation** gh CLI dans la documentation
3. **Mettre à jour les spécifications** si nécessaire
4. **Désactiver le MCP** dans la configuration (optionnel)

**Aucun code de mode à modifier** car aucun mode ne référence github-projects.

---

## 5. Recommandations

### 5.1 Immédiat (Phase 1)

1. **Créer un guide de migration** gh CLI
   - Documenter les équivalences MCP → gh CLI
   - Fournir des exemples concrets
   - Inclure les patterns d'usage courants

2. **Mettre à jour la documentation RooSync**
   - Remplacer les exemples MCP github-projects par gh CLI
   - Mettre à jour [`docs/roosync/PROTOCOLE_SDDD.md`](../../docs/roosync/PROTOCOLE_SDDD.md)

3. **Archiver la documentation MCP github-projects**
   - Déplacer vers `archive/` ou `docs/archive/`
   - Conserver pour référence historique

### 5.2 Court terme (Phase 2)

1. **Désactiver le MCP github-projects**
   - Mettre `"enabled": false` dans [`roo-config/settings/servers.json`](../../roo-config/settings/servers.json:5)
   - Ou supprimer complètement la configuration

2. **Mettre à jour les spécifications**
   - [`roo-config/specifications/mcp-integrations-priority.md`](../../roo-config/specifications/mcp-integrations-priority.md:987)
   - Marquer github-projects comme "migré vers gh CLI"

### 5.3 Long terme (Phase 3)

1. **Supprimer le code MCP github-projects**
   - `mcps/internal/servers/github-projects-mcp/`
   - Tests associés

2. **Nettoyer les dépendances**
   - Supprimer du `package.json` racine si applicable

---

## 6. Annexes

### 6.1 Fichiers de modes analysés

**Liste complète des fichiers JSON analysés** :
- `roo-modes/configs/modes.json`
- `roo-modes/configs/refactored-modes.json`
- `roo-modes/configs/standard-modes.json`
- `roo-modes/configs/standard-modes-fixed.json`
- `roo-modes/configs/vscode-custom-modes.json`
- `roo-modes/configs/n2/n2-custom-instructions.json`
- `roo-modes/configs/n2/n2-family-definitions.json`
- `roo-modes/configs/n5/n5-custom-instructions.json`
- `roo-modes/configs/n5/n5-family-definitions.json`
- `roo-modes/configs/n5/levels/large-level-config.json`
- `roo-modes/configs/n5/levels/medium-level-config.json`
- `roo-modes/configs/n5/levels/medium-fixed-level-config.json`
- `roo-modes/configs/n5/levels/micro-level-config.json`
- `roo-modes/configs/n5/levels/mini-level-config.json`
- `roo-modes/configs/n5/levels/mini-fixed-level-config.json`
- `roo-modes/configs/n5/levels/oracle-level-config.json`
- `roo-modes/configs/n5/levels/oracle-fixed-level-config.json`
- `roo-modes/configs/native/native-custom-instructions.json`
- `roo-modes/n5/configs/architect-large-optimized-v2.json`
- `roo-modes/n5/configs/architect-large-optimized.json`
- `roo-modes/n5/configs/architect-large-original.json`
- `roo-modes/n5/configs/architect-large.json`
- `roo-modes/n5/configs/architect-medium.json`
- `roo-modes/n5/configs/ask-large.json`
- `roo-modes/n5/configs/ask-medium.json`
- `roo-modes/n5/configs/debug-large.json`
- `roo-modes/n5/configs/debug-medium.json`
- `roo-modes/n5/configs/orchestrator-large.json`
- `roo-modes/n5/configs/orchestrator-medium.json`
- `roo-modes/n5/configs/custom-n5-modes.json`
- `roo-modes/n5/configs/n5-modes-roo-compatible-local.json`
- `roo-modes/n5/configs/n5-modes-roo-compatible-modified.json`
- `roo-modes/n5/scripts/n5-modes-complete.json`
- `roo-modes/custom/examples/n5-code-large-optimized.json`
- `roo-modes/examples/config.json`
- `roo-modes/examples/modes.json`
- `roo-modes/examples/servers.json`
- `roo-modes/examples/anonymized-custom-modes.json`

### 6.2 Documentation MCPs analysée

**Fichiers de documentation** :
- `roo-modes/docs/guide-integration-modes-custom.md`
- `roo-modes/custom/docs/optimisation/utilisation-optimisee-mcps.md`
- `roo-modes/n5/docs/guide-migration-roo-compatible.md`
- `roo-modes/docs/reference-prompts-natifs.md`

### 6.3 Références

- **Issue GitHub** : #368 (Migration gh CLI vs MCP github-projects)
- **Spécifications** : [`roo-config/specifications/mcp-integrations-priority.md`](../../roo-config/specifications/mcp-integrations-priority.md)
- **Tests MCP** : [`mcps/tests/github-projects/`](../../mcps/tests/github-projects/)

---

## Conclusion

**Aucun mode Roo personnalisé n'utilise MCP github-projects**. Le MCP est configuré mais pas intégré dans les instructions des modes. La migration vers gh CLI est donc **très simple** et consiste principalement à :

1. Documenter les équivalences gh CLI
2. Mettre à jour la documentation existante
3. Désactiver/supprimer le MCP

**Complexité de la migration** : FAIBLE
**Impact sur les modes** : AUCUN (aucun mode n'utilise github-projects)

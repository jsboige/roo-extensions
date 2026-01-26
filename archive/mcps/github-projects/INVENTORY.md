# INVENTORY - MCP github-projects

**Date:** 2026-01-25
**Tâche:** T91 - Suppression du code MCP github-projects
**Statut:** Préparation à la suppression

---

## 1. Résumé

Ce document inventorie tous les fichiers et dépendances du MCP github-projects qui doivent être supprimés. Le MCP github-projects a été désactivé dans `servers.json` et remplacé par l'utilisation de l'outil `gh` CLI.

---

## 2. Structure du Répertoire

### 2.1 Répertoire Principal
**Chemin:** `mcps/internal/servers/github-projects-mcp/`

### 2.2 Fichiers de Configuration
| Fichier | Taille | Description |
|---------|--------|-------------|
| `.env` | 0.63 KB | Variables d'environnement (contient des secrets) |
| `.env.example` | 0.24 KB | Exemple de configuration |
| `.gitignore` | 0.06 KB | Fichiers ignorés par Git |
| `package.json` | 1.21 KB | Dépendances et scripts npm |
| `package-lock.json` | 202.57 KB | Lockfile npm |
| `pnpm-lock.yaml` | 116.08 KB | Lockfile pnpm |
| `tsconfig.json` | 0.55 KB | Configuration TypeScript |
| `jest.config.cjs` | 0.50 KB | Configuration Jest |

### 2.3 Fichiers de Documentation
| Fichier | Taille | Description |
|---------|--------|-------------|
| `README.md` | 8.72 KB | Documentation principale |
| `README-Configuration-Flexible.md` | 4.43 KB | Guide de configuration |
| `RAPPORT-CONFIGURATION.md` | 4.63 KB | Rapport de configuration |
| `USAGE_GUIDE.md` | 14.16 KB | Guide d'utilisation |

### 2.4 Fichiers de Logs
| Fichier | Taille | Description |
|---------|--------|-------------|
| `debug.log` | 0.65 KB | Logs de debug |
| `github-projects-mcp-combined.log` | 385.90 KB | Logs combinés |
| `github-projects-mcp-error.log` | 134.36 KB | Logs d'erreurs |

### 2.5 Scripts
| Fichier | Taille | Description |
|---------|--------|-------------|
| `run-github-projects.bat` | 0.09 KB | Script de démarrage Windows |

---

## 3. Code Source (src/)

### 3.1 Fichiers Principaux
| Fichier | Taille | Lignes | Description |
|---------|--------|--------|-------------|
| `src/index.ts` | 4.07 KB | 127 | Point d'entrée du MCP |
| `src/logger.ts` | 2.19 KB | 71 | Configuration Winston |
| `src/security.ts` | 1.64 KB | 36 | Gestion de sécurité |
| `src/resources.ts` | 21.79 KB | 647 | Gestion des ressources GitHub |
| `src/github-actions.ts` | 40.76 KB | 1231 | Intégration GitHub Actions |
| `src/tools.ts` | 56.34 KB | 1306 | Définition des outils MCP |

### 3.2 Sous-répertoires

#### src/tools/
| Fichier | Taille | Lignes | Description |
|---------|--------|--------|-------------|
| `src/tools/GithubProjectsTool.js` | 11.08 KB | 296 | Classe principale des outils |

#### src/types/
| Fichier | Taille | Lignes | Description |
|---------|--------|--------|-------------|
| `src/types/global.d.ts` | 0.18 KB | 8 | Déclarations globales |
| `src/types/workflows.ts` | 2.85 KB | 112 | Types pour workflows |

#### src/utils/
| Fichier | Taille | Lignes | Description |
|---------|--------|--------|-------------|
| `src/utils/errorHandlers.ts` | 1.24 KB | 47 | Gestionnaires d'erreurs |
| `src/utils/github.ts` | 7.49 KB | 242 | Utilitaires GitHub |

---

## 4. Code Compilé (dist/)

### 4.1 Fichiers JavaScript Compilés
| Fichier | Taille | Lignes | Description |
|---------|--------|--------|-------------|
| `dist/index.js` | 4.00 KB | 97 | Point d'entrée compilé |
| `dist/logger.js` | 2.23 KB | 56 | Logger compilé |
| `dist/security.js` | 1.61 KB | 34 | Sécurité compilée |
| `dist/resources.js` | 23.37 KB | 530 | Ressources compilées |
| `dist/github-actions.js` | 37.79 KB | 1025 | GitHub Actions compilé |
| `dist/tools.js` | 55.56 KB | 1117 | Outils compilés |

### 4.2 Sous-répertoires dist/

#### dist/utils/
| Fichier | Taille | Lignes | Description |
|---------|--------|--------|-------------|
| `dist/utils/errorHandlers.js` | 1.17 KB | 44 | Gestionnaires d'erreurs |
| `dist/utils/github.js` | 7.38 KB | 222 | Utilitaires GitHub |

#### dist/types/
| Fichier | Taille | Lignes | Description |
|---------|--------|--------|-------------|
| `dist/types/workflows.js` | 0.07 KB | 3 | Types workflows |

---

## 5. Tests (tests/)

| Fichier | Taille | Lignes | Description |
|---------|--------|--------|-------------|
| `tests/.env` | 0.45 KB | 11 | Variables d'environnement de test |
| `tests/GithubProjectsTool.test.ts` | 31.05 KB | 728 | Tests unitaires |

---

## 6. Dépendances

### 6.1 Dépendances de Production
| Package | Version | Usage |
|---------|---------|-------|
| `@modelcontextprotocol/sdk` | ^1.14.0 | SDK MCP |
| `@octokit/rest` | ^19.0.7 | Client GitHub REST API |
| `dotenv` | ^16.6.1 | Gestion des variables d'environnement |
| `eventsource` | ^4.0.0 | Support EventSource |
| `reconnecting-eventsource` | ^1.6.4 | Reconnexion automatique |
| `winston` | ^3.17.0 | Logging |

### 6.2 Dépendances de Développement
| Package | Version | Usage |
|---------|---------|-------|
| `@types/connect` | ^3.4.38 | Types TypeScript |
| `@types/jest` | ^29.5.0 | Types Jest |
| `@types/mime` | ^3.0.4 | Types MIME |
| `@types/node` | ^18.15.11 | Types Node.js |
| `@types/range-parser` | ^1.2.7 | Types range-parser |
| `axios` | ^1.10.0 | Client HTTP |
| `cross-env` | ^7.0.3 | Variables d'environnement cross-platform |
| `jest` | ^29.5.0 | Framework de tests |
| `ts-jest` | ^29.1.0 | Préprocesseur TypeScript pour Jest |
| `ts-node` | ^10.9.1 | Exécution TypeScript |
| `typescript` | ^5.8.3 | Compilateur TypeScript |

---

## 7. node_modules/

Le répertoire `node_modules/` contient toutes les dépendances npm/pnpm installées. Il sera supprimé avec le reste du répertoire.

**Taille estimée:** Plusieurs centaines de MB (non comptabilisé dans l'inventaire)

---

## 8. Récapitulatif de Suppression

### 8.1 Répertoires à Supprimer
1. `mcps/internal/servers/github-projects-mcp/` (répertoire complet)

### 8.2 Nombre Total de Fichiers
- **Fichiers de configuration:** 8
- **Fichiers de documentation:** 4
- **Fichiers de logs:** 3
- **Scripts:** 1
- **Code source (src/):** 11 fichiers
- **Code compilé (dist/):** 9 fichiers
- **Tests:** 2 fichiers
- **node_modules:** ~1000+ fichiers

**Total estimé:** ~1000+ fichiers

### 8.3 Taille Totale Estimée
- **Code source et config:** ~50 KB
- **Code compilé:** ~130 KB
- **Tests:** ~32 KB
- **Documentation:** ~32 KB
- **Logs:** ~520 KB
- **node_modules:** ~200-500 MB

**Total estimé:** ~200-500 MB

---

## 9. Notes Importantes

1. **Aucune dépendance dans package.json racine:** Le MCP github-projects-mcp est un package indépendant avec son propre package.json. Aucun nettoyage de dépendances n'est nécessaire dans le package.json racine.

2. **Déjà désactivé:** Le MCP a déjà été désactivé dans `roo-config/settings/servers.json` lors de la tâche T90.

3. **Documentation archivée:** La documentation a déjà été déplacée vers `archive/mcps/github-projects/` lors de la tâche T90.

4. **Guide de migration:** Un guide de migration vers `gh` CLI a été créé dans `docs/suivi/github-projects-migration/GUIDE_MIGRATION.md` lors de la tâche T87.

---

## 10. Prochaines Étapes

1. ✅ Inventaire complet réalisé (ce document)
2. ⏳ Suppression du répertoire `mcps/internal/servers/github-projects-mcp/`
3. ⏳ Rapport dans l'INTERCOM
4. ⏳ Validation de la suppression

---

**Document généré automatiquement pour la tâche T91**

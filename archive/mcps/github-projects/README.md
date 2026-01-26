# Archive MCP github-projects

## Contexte

Cette archive contient la documentation et les scripts du MCP `github-projects-mcp` qui a été désactivé suite à la migration vers l'outil `gh` CLI.

## Raison de l'archivage

- **Tâches précédentes**: T86, T87, T88 et T89 ont identifié qu'aucun mode Roo personnalisé n'utilise ce MCP
- **Migration**: Un guide de migration vers `gh` CLI a été créé dans [`docs/suivi/github-projects-migration/GUIDE_MIGRATION.md`](../../docs/suivi/github-projects-migration/GUIDE_MIGRATION.md)
- **Désactivation**: Le MCP a été désactivé dans [`roo-config/settings/servers.json`](../../roo-config/settings/servers.json)

## Structure de l'archive

```
archive/mcps/github-projects/
├── README.md                    # Ce fichier
├── docs/                        # Documentation archivée
│   ├── 2025-08-31_synthese-reparation-GithubProjectsTool.md
│   ├── DEBUG-RAPPORT-TYPEERROR.md
│   ├── DEBUGGING_GUIDE.md
│   ├── mission_report.md
│   ├── plan-implementation.md
│   ├── specifications-phases-ulterieures.md
│   ├── synthesis-recommendation.md
│   └── workflow-monitoring-feature.md
└── scripts/                     # Scripts de diagnostic (vide - scripts non trouvés)
```

## Contenu de la documentation

### Documentation technique
- `plan-implementation.md` - Plan d'implémentation initial
- `specifications-phases-ulterieures.md` - Spécifications des phases ultérieures
- `synthesis-recommendation.md` - Synthèse et recommandations

### Rapports et diagnostics
- `2025-08-31_synthese-reparation-GithubProjectsTool.md` - Synthèse de réparation
- `DEBUG-RAPPORT-TYPEERROR.md` - Rapport de debug TypeError
- `DEBUGGING_GUIDE.md` - Guide de débogage
- `mission_report.md` - Rapport de mission

### Fonctionnalités
- `workflow-monitoring-feature.md` - Documentation de la fonctionnalité de monitoring des workflows

## Migration vers gh CLI

Pour les fonctionnalités précédemment fournies par ce MCP, utilisez l'outil `gh` CLI. Référez-vous au guide de migration:
- [`docs/suivi/github-projects-migration/GUIDE_MIGRATION.md`](../../docs/suivi/github-projects-migration/GUIDE_MIGRATION.md)

## Date d'archivage

24 janvier 2026

## Tâche associée

T90 - Archiver la documentation MCP github-projects

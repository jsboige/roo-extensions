# Archive Documentation Obsolète

**Dernière mise à jour :** 2026-03-28
**Action :** Archivage des docs marqués "obsolete" ou "deprecated"

---

## Fichiers archivés

Les fichiers suivants ont été déplacés vers ce dossier car ils contiennent de la documentation obsolète, historique ou marquée comme dépréciée.

### Architecture

| Fichier | Raison | Date d'archivage |
|---------|--------|------------------|
| `roosync-v1-vs-v2-gap-analysis.md` | Gap analysis historique v1 vs v2 (2025-10-14) - corrigé depuis | 2026-03-14 |
| `roosync-temporal-messages-architecture.md` | Marqué "deprecated" - architecture temporelle obsolète | 2026-03-14 |

### Audit

*Note : Les audits ont été déplacés vers `docs/audit/archive/` pour meilleure organisation (2026-03-14).*

| Fichier                    | Destination               | Date de déplacement |
|----------------------------|---------------------------|---------------------|
| `INVESTIGATION_SUMMARY_572.md` | `docs/audit/archive/` | 2026-03-14 |
| `VSCODE_LOGS_AUDIT_2026-03-06.md` | `docs/audit/archive/` | 2026-03-14 |

### Deployment

| Fichier | Raison | Date d'archivage |
|---------|--------|------------------|
| `DEPLOY-ALWAYSALLOW.md` | Marqué "deprecated" - documentation déploiement alwaysAllow | 2026-03-14 |

### Dev

| Fichier | Raison | Date d'archivage |
|---------|--------|------------------|
| `roo-state-manager-indexing-checkpoints.md` | Fix checkpoints indexing - marqué deprecated | 2026-03-14 |

### Guides

| Fichier | Raison | Date d'archivage |
|---------|--------|------------------|
| `ENVIRONMENT-SETUP-SYNTHESIS.md` | Guide v2.1 obsolète pour Synthesis | 2026-03-14 |

### Roo Code

| Fichier | Raison | Date d'archivage |
|---------|--------|------------------|
| `003-backward-compatibility-strategy.md` | ADR backward compatibility - marqué deprecated | 2026-03-14 |

### RooSync (ajout 2026-03-28)

| Fichier | Raison | Date d'archivage |
|---------|--------|------------------|
| `DASHBOARD-HIERARCHIQUE-v1.0.md` | Dashboard Phase 1 (#546) superseded by `ROOSYNC_DASHBOARDS.md` (#675, 3-type system) | 2026-03-28 |

### Rapports ponctuels (ajout 2026-03-28)

| Fichier | Raison | Date d'archivage |
|---------|--------|------------------|
| `coverage-audit-492.md` | Audit couverture tests #492 (2026-02-21), snapshot historique | 2026-03-28 |
| `sk-agent-phase5-validation-report-po-2026.md` | Rapport validation sk-agent po-2026 (2026-03-20), ponctuel | 2026-03-28 |
| `sk-agent-phase5-validation-report.md` | Rapport validation sk-agent ai-01 (2026-03-20), ponctuel | 2026-03-28 |

---

## Fichiers NON archivés (v2.1 = référence historique)

Les fichiers suivants contiennent des références à v2.1 mais sont toujours pertinents :

- `docs/roosync/GUIDE-TECHNIQUE-v2.3.md` - Guide actuel v2.3, mentionne v2.1 pour contexte historique
- `docs/roosync/ARCHITECTURE_ROOSYNC.md` - Architecture actuelle, compare v2.1 vs v3.0
- `docs/roosync/GESTION_MULTI_AGENT.md` - Gestion multi-agent, référence historique v2.1
- `docs/roosync/README.md` - README principal, mentionne historique des versions
- `docs/roosync/guides/GLOSSAIRE.md` - Glossaire, définitions historiques
- `docs/INDEX.md` - Index principal, références historiques

---

## Actions futures

- [ ] Revoir périodiquement si des documents archivés peuvent etre supprimes definitivement
- [ ] Mettre a jour les references croisees dans la documentation active
- [x] ~~Consolider les audits dans `docs/audit/archive/`~~ **TERMINE 2026-03-14**
- [x] ~~Archiver DASHBOARD-HIERARCHIQUE-v1.0.md et rapports ponctuels~~ **TERMINE 2026-03-28 (issue #656 P0)**

---

**Issue liée :** #656 - IDLE-IMPROVEMENT

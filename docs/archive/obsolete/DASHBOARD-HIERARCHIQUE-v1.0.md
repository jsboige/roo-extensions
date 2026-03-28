# Dashboard Hiérarchique RooSync - Phase 1

**Issue:** #546
**Version:** 1.0.0
**Date:** 2026-03-03
**Auteur:** myia-web1:claude-code

---

## Vue d'ensemble

Le dashboard hiérarchique est un fichier markdown partagé sur GDrive qui permet aux agents de communiquer leur état, leurs notes et leurs besoins de manière libre et structurée. Il remplace le fichier `SUIVI_ACTIF.md` (supprimé) et s'intègre avec les autres fichiers RooSync.

---

## Architecture

### Fichiers

| Fichier | Emplacement | Usage |
|---------|-------------|-------|
| **`DASHBOARD.md`** | `$ROOSYNC_SHARED_PATH/DASHBOARD.md` | Dashboard hiérarchique principal |
| `sync-dashboard.json` | `$ROOSYNC_SHARED_PATH/sync-dashboard.json` | Status structuré (JSON) |
| `sync-roadmap.md` | `$ROOSYNC_SHARED_PATH/sync-roadmap.md` | Workflow décisions |
| `dashboards/DASHBOARD.md` | `$ROOSYNC_SHARED_PATH/dashboards/DASHBOARD.md` | Comparaison MCP (technique) |

### Structure de DASHBOARD.md

```markdown
# RooSync Dashboard
**Dernière mise à jour:** {timestamp} par {machine}:{workspace}

## État Global
- Résumé global (coordinateur)
- Points de vigilance

## Machines
### {machine-id}
#### {workspace}
- État, dernière action, notes libres

## Notes Inter-Agents
Communication entre agents (mentions @machine)

## Décisions en Attente
Intégration sync-roadmap.md

## Métriques
GitHub Project, machines online, etc.
```

---

## Outil MCP

### `roosync_dashboard`

Met à jour une section du dashboard hiérarchique.

**Paramètres:**
- `section` (requis): `machine` | `global` | `intercom` | `decisions` | `metrics`
- `content` (requis): Contenu markdown à insérer
- `machine` (optionnel): ID machine (requis si section=machine)
- `workspace` (optionnel): Workspace (défaut: roo-extensions)
- `mode` (optionnel): `replace` | `append` | `prepend` (défaut: replace)

**Exemples:**

```javascript
// Mettre à jour les notes de sa machine
roosync_dashboard({
  section: "machine",
  content: "- En cours: #546 Dashboard GDrive\n- ✅ Scheduler réparé",
  machine: "myia-web1"
})

// Ajouter une note inter-agent
roosync_dashboard({
  section: "intercom",
  content: "[2026-03-03] @myia-web1 → @myia-ai-01: Besoin validation #546",
  mode: "append"
})

// Mettre à jour l'état global (coordinateur)
roosync_dashboard({
  section: "global",
  content: "- **Statut:** 🟢 Opérationnel\n- **Priorité:** #546 Dashboard"
})
```

---

## Workflow Recommandé

### Mise à jour automatique (sync-tour)

Intégrer dans le skill `sync-tour`:

```yaml
Étape 9 - Reporting Dashboard:
  roosync_dashboard({
    section: "machine",
    content: "État: {{status}}\nDernière action: {{action}}\nNotes: {{notes}}",
    mode: "replace"
  })
```

### Mise à jour manuelle

Quand un agent effectue une action significative:
1. Mettre à jour sa section machine avec `mode: append`
2. Si besoin de coordination, ajouter une note inter-agent
3. Pour les décisions affectant tout le monde, mettre à jour l'état global

---

## Intégration avec sync-roadmap.md

La section "Décisions en Attente" du dashboard remplace le fichier séparé `sync-roadmap.md`. Les outils de décision (`roosync_decision`, `roosync_approve_decision`, etc.) mettent à jour cette section automatiquement (Phase 2).

---

## Migration depuis SUIVI_ACTIF.md

| Avant | Après |
|-------|-------|
| `docs/suivi/RooSync/SUIVI_ACTIF.md` | `$ROOSYNC_SHARED_PATH/DASHBOARD.md` |
| Rapports quotidiens | Mises à jour continues par agents |
| Centré sur coordinateur | Chaque agent gère sa section |
| Format rigide | Markdown libre |

---

## Tests

### Tester l'outil

```bash
# Depuis n'importe quelle machine avec roo-state-manager actif
roosync_dashboard({
  section: "machine",
  content: "- Test: mise à jour dashboard",
  mode: "append"
})
```

### Vérifier le résultat

```bash
# Lire le fichier sur GDrive
cat "$ROOSYNC_SHARED_PATH/DASHBOARD.md"
```

---

## Phase 2 - Enrichissements (Planifié)

- [ ] Auto-update dans `roosync_send` (activité récente)
- [ ] Auto-update dans `roosync_decision` (décisions en attente)
- [ ] Métriques GitHub Project via `gh api graphql`
- [ ] Migration `sync-dashboard.json` → dashboard hiérarchique
- [ ] Archivage `dashboards/DASHBOARD.md` (remplacé)

---

## Références

- Issue #546: https://github.com/jsboige/roo-extensions/issues/546
- Fichier template: `$ROOSYNC_SHARED_PATH/DASHBOARD.md`
- Outil MCP: `roosync_dashboard`
- Documentation RooSync: `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`

---

**Généré:** 2026-03-03
**Statut:** Phase 1 complétée, en attente de validation coordinateur

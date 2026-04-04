# INTERCOM - Dashboard RooSync (Canal Principal)

**Canal principal :** Dashboard RooSync `workspace`. Fichier local `.claude/local/INTERCOM-{MACHINE}.md` = FALLBACK DEPRECATED (#745).

---

## Lecture / Écriture

**Lire (OBLIGATOIRE en début de cycle) :**

```
roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 10)
```

**⚠️ Si contenu trop volumineux** (réponse contient "written to file:") : lire le fichier retourné avec `read_file`. (#984)

**Écrire :**

```
roosync_dashboard(action: "append", type: "workspace",
  tags: ["{TYPE}", "{roo-scheduler|roo-meta|claude-interactive|claude-scheduled}"],
  content: "Message...")
```

**FALLBACK (si MCP échoue) :** Ouvrir `.claude/local/INTERCOM-{MACHINE}.md`, ajouter à la FIN (ordre chronologique). Préférer `apply_diff` ou `Add-Content` (pas `write_to_file`).

---

## Format

```markdown
## [YYYY-MM-DD HH:MM:SS] sender → receiver [TYPE]
### Titre optionnel
Contenu...
---
```

| Champ     | Valeurs                               |
|-----------|---------------------------------------|
| `sender`  | `roo`, `claude-code`, `system`        |
| `receiver` | `roo`, `claude-code`, `all`          |

## Types de Messages

| Type              | Usage                                    |
|-------------------|------------------------------------------|
| `DONE`            | Tâche terminée                           |
| `TASK`            | Demander une tâche                       |
| `INFO`            | Update de statut                         |
| `WARN` / `ERROR`  | Avertissement / erreur bloquante         |
| `ASK` / `REPLY`   | Question / réponse                       |
| `ACK`             | Accuser réception d'un message           |
| `PROPOSAL`        | Claude propose une tâche → traiter comme `[TASK]` |
| `SUGGESTION`      | Suggestion non obligatoire               |
| `IDLE`            | Fin de cycle scheduler sans tâche GitHub |
| `PATROL`          | Health check lecture seule               |
| `FRICTION-FOUND`  | Friction détectée en veille active       |
| `COORDINATION`    | Message coordinateur → exécutants        |

---

## Règles d'Engagement

### Début de cycle (Étape 1)

1. **[PROPOSAL] de Claude** → Traiter comme `[TASK]` prioritaire
2. **[ASK] de Claude sans [REPLY]** → Répondre AVANT la tâche principale

### Fin de cycle [IDLE]

Enrichir le message de fin avec une suggestion pour Claude :

```
## [{DATE}] roo -> claude-code [IDLE]
- Git: OK | Build: OK | Tests: OK | Tâches: 0
- [SUGGESTION] {suggestion pour Claude}
---
```

### Quand contacter Claude (OBLIGATOIRE)

- Avant de créer une GitHub issue
- Si bloqué > 30 minutes
- Si décision architecturale requise
- Fin de tâche CONS/consolidation (demander vérification)

### Quand contacter Claude (RECOMMANDÉ)

- Information importante découverte pendant investigation
- Conflit potentiel avec travail d'une autre machine
- Test qui échoue de façon inexpliquée

---

## META-INTERCOM — DEPRECATED

Utiliser le dashboard `workspace` pour tous les rapports meta-analyste :

```
roosync_dashboard(action: "append", type: "workspace",
  tags: ["META-ANALYSIS", "roo-meta"], content: "Rapport...")
```

---

## Bonnes Pratiques

1. **Concis** — Claude lit beaucoup de messages
2. **Structuré** — Sections markdown, Issue #, commit hash, fichiers
3. **Proactif** — Proposer des solutions, pas juste signaler les problèmes

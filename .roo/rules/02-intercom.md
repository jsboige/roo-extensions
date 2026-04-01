# Règles INTERCOM - Dashboard RooSync (Canal Principal)

## Protocole INTERCOM

**Le dashboard RooSync `workspace` est le canal de communication principal** entre Roo et Claude Code sur la même machine.

Le fichier INTERCOM local (`.claude/local/INTERCOM-{MACHINE}.md`) est un **FALLBACK** uniquement en cas d'échec du MCP.

### Dashboard RooSync (Méthode OBLIGATOIRE)

```
roosync_dashboard(
  action: "read",
  type: "workspace",
  section: "intercom"
)
```

**Lecture des messages récents :**
```
roosync_dashboard(
  action: "read",
  type: "workspace",
  section: "intercom",
  intercomLimit: 10
)
```

**Écriture d'un message :**
```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["{DONE|TASK|INFO|WARN|ERROR}", "{roo-scheduler|roo-meta|claude-interactive|claude-scheduled}"],
  content: "Contenu du message..."
)
```

**Avantages du dashboard :**
- Pas d'approbation fichier (appel MCP direct)
- Accessible cross-machine via GDrive
- Auto-condensation automatique
- Tags structurés pour identifier l'auteur

### Fichier INTERCOM (FALLBACK DEPRECATED)

**⚠️ DEPRECATED depuis #745 Phase 2. Utiliser uniquement si le MCP `roosync_dashboard` échoue.**

Le fichier INTERCOM local (`.claude/local/INTERCOM-{MACHINE}.md`) est un **FALLBACK** uniquement en cas d'échec du MCP.

**Procédure fallback (si MCP échoue) :**
1. **Lire** le fichier pour trouver le dernier séparateur `---`
2. **Ajouter** le nouveau message à la fin (ordre chronologique)
3. **Préférer** `apply_diff` ou `Add-Content` plutôt que `write_to_file` (échec fréquent sur >500 lignes)

> **Ordre chronologique critique** : Toujours ajouter à la FIN du fichier. Jamais insérer au début.

---

## Format des Messages

```markdown
## [YYYY-MM-DD HH:MM:SS] sender → receiver [TYPE]

### Titre optionnel

Contenu du message...

---
```

### Champs

| Champ | Valeurs |
|-------|---------|
| `sender` | `roo`, `claude-code`, `system` |
| `receiver` | `roo`, `claude-code`, `all` |
| `TYPE` | `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`, `PROPOSAL`, `SUGGESTION` |

---

## Types de Messages

| Type | Quand l'utiliser |
|------|------------------|
| `INFO` | Information générale, update de statut |
| `TASK` | Demander une tâche à l'autre agent |
| `DONE` | Signaler qu'une tâche est terminée |
| `WARN` | Avertissement (non bloquant) |
| `ERROR` | Erreur bloquante, besoin d'aide |
| `ASK` | Poser une question |
| `REPLY` | Répondre à un ASK |
| `ACK` | Accuser réception d'un message de Claude |
| `PROPOSAL` | Claude propose une tâche à Roo — traiter comme `[TASK]` |
| `SUGGESTION` | Suggestion de Claude, non obligatoire |
| `PATROL` | Patrouille scheduler (health check lecture seule) |
| `FRICTION-FOUND` | Friction détectée pendant veille active (outil HS, doc introuvable, incohérence) |
| `COORDINATION` | Message de coordination du coordinateur vers les exécutants |
| `IDLE` | Fin de cycle scheduler sans tâche GitHub trouvée |

---

## Règles d'Engagement — Dialogue Bidirectionnel (#657)

### Lecture du dashboard en début de cycle (Étape 1)

Après avoir lu l'INTERCOM, chercher :

1. **[PROPOSAL] de Claude** → Traiter comme une `[TASK]` prioritaire (si validée par rapport aux critères habituels)
2. **[ASK] de Claude sans [REPLY]** → Répondre avant de commencer la tâche principale

### Fin de cycle [IDLE]

Si le rapport de fin de cycle est `[IDLE]` (aucune tâche GitHub trouvée) :

**Enrichir le message de fin** avec une suggestion pour Claude :

```markdown
## [{DATE}] roo -> claude-code [IDLE]
- Git: OK | Build: OK | Tests: OK
- Tâches: 0 (aucune issue GitHub assignée)
- [SUGGESTION] Claude, pendant ton idle : issues sans assignation dans #67 méritent une revue.
---
```

### Quand Contacter Claude

### OBLIGATOIRE

- **Avant de créer une GitHub issue** (validation utilisateur via Claude)
- **Si bloqué > 30 minutes** sur un problème
- **Si décision architecturale** requise
- **Fin de tâche CONS/consolidation** (demander vérification)

### RECOMMANDÉ

- Information importante découverte pendant investigation
- Conflit potentiel avec travail d'une autre machine
- Test qui échoue de façon inexpliquée

---

## Exemples

### Signaler une tâche terminée

```markdown
## [2026-02-01 22:30:00] roo → claude-code [DONE]

### CONS-3 Implémenté

**Résultat :**
- Config tools consolidés : 4 → 2
- Tests passent : 1661/1661
- Commit : abc1234

**À vérifier :** Le nombre d'outils dans roosyncTools est bien passé de 29 à 27.

---
```

### Demander de l'aide

```markdown
## [2026-02-01 23:00:00] roo → claude-code [ASK]

### Blocage sur test roosync_summarize

**Problème :**
Le test `roosync-summarize.test.ts` échoue avec :
```
Cannot read properties of undefined (reading 'filter')
```

**Tentatives :**
1. Vérifié les mocks - OK
2. Ajouté logs - le result.success est false
3. Tracé l'erreur jusqu'à generate-trace-summary.tool.ts:155

**Question :** Dois-je investiguer plus ou c'est un bug connu ?

---
```

### Signaler une erreur

```markdown
## [2026-02-01 23:30:00] roo → claude-code [ERROR]

### Tests échouent après merge

**Situation :**
- `git pull` effectué
- 4 tests échouent maintenant
- Erreur : StateManagerError dans roosync-summarize

**Impact :** Bloqué sur ma tâche actuelle

**Besoin :** Décision - continuer sans ces tests ou investiguer ?

---
```

---

## META-INTERCOM — DEPRECATED

**Les fichiers META-INTERCOM (`.claude/local/META-INTERCOM-{MACHINE}.md`) sont DEPRECATED.**

Utiliser le dashboard `workspace` pour tous les rapports meta-analyste :

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["META-ANALYSIS", "roo-meta"],
  content: "Rapport meta-analyste..."
)
```

Les fichiers existants sont conservés en lecture seule comme archive historique.

---

### En Début de Session

**METHODE OBLIGATOIRE (Dashboard RooSync) :**
1. `roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 10)`
2. Identifier les `TASK` non complétées et `ASK` sans `REPLY`

**FALLBACK fichier local (si MCP échoue) :** Ouvrir `.claude/local/INTERCOM-{MACHINE}.md` et appliquer les mêmes critères.

---

## Bonnes Pratiques

1. **Soyez concis** - Claude lit beaucoup de messages
2. **Structurez** - Utilisez des sections markdown
3. **Donnez le contexte** - Issue #, commit hash, fichiers concernés
4. **Proposez des solutions** - Ne pas juste signaler les problèmes

---

*INTERCOM est critique pour la coordination. Toujours lire en début de session.*

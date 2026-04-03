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

**⚠️ CRITIQUE : Gestion de la redirection vers fichier (#984)**

Quand le contenu du dashboard est trop volumineux, le MCP retourne un message du type :
```
Content too large, written to file: /path/to/file
```

**Dans ce cas, l'agent DOIT lire le fichier retourné :**

1. **Détecter** que la réponse contient un chemin fichier (pattern "written to file:")
2. **Lire** ce fichier avec `read_file` ou `Read`
3. **Traiter** le contenu comme si l'outil l'avait retourné directement

**Exemple de procédure complète :**

```python
# Étape 1 : Appel dashboard avec intercomLimit pour éviter overflow
result = roosync_dashboard(
  action="read",
  type="workspace",
  section="intercom",
  intercomLimit=10  # Limite à 10 messages récents
)

# Étape 2 : Vérifier si le contenu a été redirigé
if result.get("message") and "written to file:" in result["message"]:
    # Extraire le chemin du fichier
    file_path = result["message"].split("written to file: ")[1]
    # Lire le fichier
    actual_content = read_file(file_path)
    # Traiter actual_content...
else:
    # Traiter result["content"] directement
    content = result.get("content", "")
```

**Pourquoi c'est critique :** Sans cette lecture en 2 temps, les messages INTERCOM importants (WARN, ERROR, TASK, WAKE-CLAUDE) sont ignorés, ce qui rompt la coordination cross-machine.

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

### Fichier INTERCOM (FALLBACK uniquement)

**⚠️ DEPRECATED - EMERGENCY FALLBACK ONLY**

**Utiliser SEULEMENT si le MCP `roosync_dashboard` est complètement indisponible.**

Fichier : `.claude/local/INTERCOM-{MACHINE}.md` (ex: `INTERCOM-myia-ai-01.md`)

**Procédure minimale (si MCP échoue) :**
1. **Lire** les dernières lignes avec `read_file` pour trouver le dernier `---`
2. **Append** le nouveau message avec `apply_diff` ou `Add-Content` (win-cli)
3. **Dernier recours** : `write_to_file` (ancien contenu + nouveau message)

**RÈGLES CRITIQUES :**
- **Ordre chronologique** : TOUJOURS ajouter à la FIN du fichier (ancien en haut, récent en bas)
- **NE JAMAIS** insérer au début ou supprimer/modifier les messages existants
- **NE JAMAIS** écraser le fichier avec seulement le nouveau message

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
2. **SI redirection vers fichier** (message contient "written to file:") : lire ce fichier avec `read_file`
3. Lire les messages récents (< 24h)
4. Identifier les `TASK` non complétées
5. Identifier les `ASK` sans `REPLY`

**FALLBACK fichier local (si MCP échoue) :**
1. Ouvrir `.claude/local/INTERCOM-{MACHINE}.md`
2. Mêmes étapes 3-4 ci-dessus

### Format de Recherche (fallback fichier uniquement)

```bash
# Trouver les messages non-résolus dans le fichier local
grep -E "^\#\# \[.*\] .* → roo \[TASK\]" .claude/local/INTERCOM-*.md
```

---

## Bonnes Pratiques

1. **Soyez concis** - Claude lit beaucoup de messages
2. **Structurez** - Utilisez des sections markdown
3. **Donnez le contexte** - Issue #, commit hash, fichiers concernés
4. **Proposez des solutions** - Ne pas juste signaler les problèmes

---

*INTERCOM est critique pour la coordination. Toujours lire en début de session.*

# Règles INTERCOM - Communication Locale

## Protocole INTERCOM

INTERCOM est le canal de communication **locale** entre Roo et Claude Code sur la même machine.

### Fichier

```
.claude/local/INTERCOM-{MACHINE}.md
```

Exemples :
- `.claude/local/INTERCOM-myia-ai-01.md`
- `.claude/local/INTERCOM-myia-po-2025.md`

---

## REGLE CRITIQUE : Ordre d'Ecriture

**TOUJOURS ajouter les nouveaux messages A LA FIN du fichier.**

Le fichier INTERCOM est en **ordre chronologique** : ancien en haut, recent en bas.

### Procedure d'ecriture OBLIGATOIRE

**METHODE OBLIGATOIRE (Dashboard RooSync — Phase 2 migration #745) :**

Utiliser `roosync_dashboard` pour TOUTE communication INTERCOM. Le fichier local est un FALLBACK uniquement.

**Avantages du dashboard :**
- Pas d'approbation fichier (appel MCP direct)
- Accessible cross-machine via GDrive
- Auto-condensation automatique
- Tags structurés pour identifier l'auteur

**Écriture :**
```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["{DONE|TASK|INFO|WARN|ERROR}", "{roo-scheduler|roo-meta|claude-interactive|claude-scheduled}"],
  content: "Contenu du message..."
)
```

**Lecture :**
```
roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 10)
```

**FALLBACK fichier local (si MCP échoue) :** Écrire dans `.claude/local/INTERCOM-{MACHINE}.md` avec apply_diff.

**METHODE ALTERNATIVE 1 (apply_diff - append a la fin) :**

1. **Lire** les 20 dernieres lignes du fichier avec `read_file` (pour trouver le dernier `---`)
2. **Preparer** le nouveau message
3. **Utiliser `apply_diff`** pour ajouter le message APRES le dernier separateur `---`

Exemple :
```
apply_diff(
  path: ".claude/local/INTERCOM-{MACHINE}.md",
  diff: "<<<<<<< SEARCH\n[dernier separateur --- du fichier]\n======= REPLACE\n[dernier separateur ---]\n\n## [DATE] roo -> claude-code [DONE]\n### Titre\nContenu...\n\n---\n>>>>>>> REPLACE"
)
```

**METHODE ALTERNATIVE (win-cli Add-Content) :**

Si `apply_diff` echoue, utiliser win-cli :
```
execute_command(shell="powershell", command="Add-Content -Path '.claude/local/INTERCOM-{MACHINE}.md' -Value @'\n\n## [DATE] roo -> claude-code [DONE]\n### Titre\nContenu...\n\n---\n'@")
```

**METHODE DE DERNIER RECOURS (write_to_file) :**

Si les deux methodes ci-dessus echouent :
1. **Lire** le fichier ENTIER avec `read_file`
2. **Reecrire** avec `write_to_file` (ancien contenu + nouveau message)

> **⚠️ ATTENTION :** `write_to_file` sur un fichier de >500 lignes ECHOUE frequemment avec Qwen 3.5 car le modele n'arrive pas a generer le parametre `content` en entier. Le message d'erreur est : "Roo tried to use write_to_file without value for required parameter 'content'". **Privilegier TOUJOURS `apply_diff` ou `Add-Content`.**

### INTERDIT

- **NE JAMAIS** inserer un message au debut du fichier (avant les messages existants)
- **NE JAMAIS** supprimer ou modifier les messages existants
- **NE JAMAIS** ecrire UNIQUEMENT le nouveau message (ecrasement du fichier)

### Pourquoi

L'ordre chronologique est essentiel pour que Claude Code et Roo puissent lire les messages recents en fin de fichier. Inserer en haut casse cet ordre et rend le fichier illisible.

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

---

## Règles d'Engagement — Dialogue Bidirectionnel (#657)

### Lecture INTERCOM en début de cycle (Étape 1)

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

## META-INTERCOM - Coordination Cross-Machines

### Fichier

```
.claude/local/META-INTERCOM-{MACHINE}.md
```

Exemples :
- `.claude/local/META-INTERCOM-myia-ai-01.md`
- `.claude/local/META-INTERCOM-myia-po-2023.md`

### Distinction INTERCOM vs META-INTERCOM

| Canal | Portée | Usage |
|-------|--------|-------|
| **INTERCOM** | Locale (même machine, même workspace) | Communication Roo ↔ Claude Code opérationnel |
| **META-INTERCOM** | Cross-machines | Rapports meta-analyst, frictions système, coordination globale |

### Quand écrire dans META-INTERCOM

1. **Rapports meta-analyst** (cycle 72h)
   - Analyse des traces scheduler (Roo + Claude)
   - Métriques de succès/échec par mode
   - Recommandations d'escalade

2. **Frictions système découvertes**
   - Problèmes d'infrastructure (services down, configs drift)
   - Patterns d'erreur récurrents
   - Propositions d'amélioration du harnais

3. **Coordination cross-machines**
   - Information qui concerne plusieurs machines
   - Décisions architecturales locales avec impact global
   - Demandes de consultation d'autres meta-analysts

### Format

Même structure que INTERCOM :

```markdown
## [YYYY-MM-DD HH:MM:SS] sender → receiver [TYPE]

### Titre optionnel

Contenu du message...

---
```

**Types courants :** `META-ANALYSIS`, `FRICTION-FOUND`, `CONSULT`, `RECOMMENDATION`

### Qui lit META-INTERCOM

- **Meta-analyst Roo** (cycle 72h)
- **Meta-analyst Claude** (cycle 72h)
- **Coordinateur** (myia-ai-01) pour suivi des frictions

### Règle d'écriture

**Même règle que INTERCOM** : TOUJOURS ajouter à la fin du fichier (ordre chronologique).

---

## Règles de Lecture

### En Début de Session

**METHODE OBLIGATOIRE (Dashboard) :**
1. `roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 10)`
2. Lire les messages récents (< 24h)
3. Identifier les `TASK` non complétées
4. Identifier les `ASK` sans `REPLY`

**FALLBACK fichier local (si MCP échoue) :**
1. Ouvrir `.claude/local/INTERCOM-{MACHINE}.md`
2. Mêmes étapes 2-4 ci-dessus

### Format de Recherche (fallback fichier)

```bash
# Trouver les messages non-résolus (fallback fichier local uniquement)
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

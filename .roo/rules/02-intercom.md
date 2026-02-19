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

1. **Lire** le fichier ENTIER avec `read_file`
2. **Preparer** le nouveau message
3. **Reecrire** le fichier COMPLET avec `write_to_file` en ajoutant le message **APRES** tout le contenu existant

### INTERDIT

- **NE JAMAIS** inserer un message au debut du fichier (avant les messages existants)
- **NE JAMAIS** supprimer ou modifier les messages existants
- **NE JAMAIS** ecrire UNIQUEMENT le nouveau message (ecrasement du fichier)
- **NE JAMAIS** utiliser `replace_in_file` pour inserer en haut

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
| `TYPE` | `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY` |

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

---

## Quand Contacter Claude

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

## Règles de Lecture

### En Début de Session

1. Ouvrir `.claude/local/INTERCOM-{MACHINE}.md`
2. Lire les messages récents (< 24h)
3. Identifier les `TASK` non complétées
4. Identifier les `ASK` sans `REPLY`

### Format de Recherche

```bash
# Trouver les messages non-résolus
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

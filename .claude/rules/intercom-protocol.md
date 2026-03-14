# Règles INTERCOM - Communication Locale (Claude Code)

**Version:** 1.0.0
**Créé:** 2026-03-13
**Issue:** #669 - [META-ANALYSIS] Ajouter règle écriture INTERCOM pour Claude

---

## Protocole INTERCOM

INTERCOM est le canal de communication **locale** entre Roo et Claude Code sur la même machine et dans le même workspace.

**⚠️ DISTINCTION CRITIQUE :**
- **INTERCOM** = Communication locale (même machine, même workspace)
- **RooSync** = Communication inter-machine et inter-workspace

### Fichier

```
.claude/local/INTERCOM-{MACHINE}.md
```

Exemples :
- `.claude/local/INTERCOM-myia-ai-01.md`
- `.claude/local/INTERCOM-myia-po-2026.md`

---

## REGLE CRITIQUE : Ordre d'Ecriture

**TOUJOURS ajouter les nouveaux messages A LA FIN du fichier.**

Le fichier INTERCOM est en **ordre chronologique** : ancien en haut, recent en bas.

### Pourquoi c'est critique

L'ordre chronologique est essentiel pour que Claude Code et Roo puissent lire les messages recents en fin de fichier. Inserer en haut casse cet ordre et rend le fichier illisible.

**Risques si la règle n'est pas respectée :**
- Insertion au début du fichier → Casse l'ordre chronologique
- Écriture sans lecture préalable → Écrasement du fichier (perte de données)

---

## Procédure d'écriture OBLIGATOIRE pour Claude Code

### Méthode PREFEREE (Edit tool - append à la fin)

Claude Code utilise l'outil `Edit` avec `replace_all: false` pour ajouter du contenu à la fin.

**Étapes :**

1. **Lire** le fichier pour comprendre sa structure et trouver le dernier séparateur `---`
2. **Préparer** le nouveau message avec le format standard
3. **Utiliser `Edit`** avec `old_string` = dernier contenu existant, `new_string` = contenu + nouveau message

**Exemple :**

```typescript
// Ancien contenu du fichier (extrait)
---  // <-- DERNIER SEPARATEUR

// Nouveau message à ajouter
## [2026-03-13 14:30:00] claude-code -> roo [DONE]
### Tâche terminée
Détails...

---
```

### Format des Messages

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

## INTERDIT

- **NE JAMAIS** insérer un message au début du fichier (avant les messages existants)
- **NE JAMAIS** supprimer ou modifier les messages existants
- **NE JAMAIS** écrire UNIQUEMENT le nouveau message (écrasement du fichier avec `Write` sans lecture préalable)

---

## Lecture de l'INTERCOM (Début de Session)

**OBLIGATION :** Au début de chaque session Claude Code, vérifier l'INTERCOM local.

1. Lire le fichier `.claude/local/INTERCOM-{MACHINE}.md`
2. Chercher les messages récents (< 24h) avec les tags : `[DONE]`, `[WAKE-CLAUDE]`, `[PATROL]`, `[FRICTION-FOUND]`, `[ERROR]`, `[WARN]`, `[ASK]`
3. Identifier les `TASK` non complétées
4. Identifier les `ASK` sans `REPLY`

### Priorité des messages

| Tag | Action | Priorité |
|-----|--------|----------|
| `[WAKE-CLAUDE]` | Traiter les messages RooSync indiqués | **IMMÉDIATE** |
| `[FRICTION-FOUND]` | Noter le friction pour contexte | Haute |
| `[ERROR]` | Investiger le problème | Haute |
| `[ASK]` | Répondre si possible | Moyenne |
| `[DONE]` | Analyser les résultats | Normale |

---

## Règles de Bonnes Pratiques

1. **Soyez concis** - Les messages doivent être lisibles rapidement
2. **Structurez** - Utilisez des sections markdown
3. **Donnez le contexte** - Issue #, commit hash, fichiers concernés
4. **Proposez des solutions** - Ne pas juste signaler les problèmes
5. **Horodatage précis** - Toujours inclure la date et heure complète

---

## Exemples

### Signaler une tâche terminée

```markdown
## [2026-03-13 14:30:00] claude-code -> roo [DONE]

### Issue #669 implémentée

**Action :** Ajouté règle INTERCOM écriture dans `.claude/rules/intercom-protocol.md`

**Résultat :**
- Règle ordre chronologique documentée
- Format des messages standardisé
- Procédure d'écriture avec Edit tool

**Commit :** abc1234

---
```

### Signaler un blocage

```markdown
## [2026-03-13 15:00:00] claude-code -> roo [ASK]

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

---

## Références Croisées

- Roo equivalent : `.roo/rules/02-intercom.md`
- Issue #669 : [META-ANALYSIS] Ajouter règle écriture INTERCOM pour Claude
- Meta-analysis report : `docs/cross-analysis-harnesses-2026-03-13.md` (REC-003)

---

**Dernière mise à jour :** 2026-03-13

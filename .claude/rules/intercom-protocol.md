# Regles Communication Locale et Dashboard (Claude Code)

**Version:** 2.1.0
**Cree:** 2026-03-13
**MAJ:** 2026-03-29
**Issues:** #669, #745, #835, #836, #984

---

## Protocole Dashboard (PRINCIPAL)

**Depuis la migration #745 Phase 2, le canal principal est le dashboard RooSync.**

### Hierarchie des canaux

| Canal | Type dashboard | Usage | Priorite |
|-------|---------------|-------|----------|
| **Dashboard workspace** | `workspace` | **Coordination cross-machine** — rapporter progression, bilans | **#1 PRINCIPAL** |
| **Dashboard machine** | `machine` | Hardware, MCPs, services par machine | #2 Infra |
| **Fichier INTERCOM local** | N/A | **DEPRECATED** — fallback si MCP echoue | #3 Fallback |

### REGLE CRITIQUE (#836)

**Tout agent DOIT rapporter sur le dashboard `workspace`.** Le type `workspace+machine` a ete SUPPRIME.

Le dashboard `workspace` est le hub central visible par TOUTES les machines. Seuls 3 types de dashboards existent : `global`, `machine`, `workspace`.

### Fichier INTERCOM local (DEPRECATED)

**Les fichiers `.claude/local/INTERCOM-{MACHINE}.md` sont DEPRECATED depuis #745 Phase 2.**

Ils ne doivent etre utilises QUE si le MCP dashboard echoue (GDrive offline, MCP crash).

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

## Procedure d'ecriture OBLIGATOIRE pour Claude Code

### 1. Rapporter sur le dashboard WORKSPACE (cross-machine) — OBLIGATOIRE (#836)

**Toute action significative DOIT etre rapportee sur le dashboard `workspace`** pour etre visible par toutes les machines.

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["{DONE|PROGRESS|BLOCKED|INFO}", "claude-interactive"],
  content: "Bilan ou progression..."
)
```

### 2. Communication locale via dashboard workspace

Pour les messages locaux (meme machine) ou cross-machine :

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["{INFO|TASK|DONE|WARN|ERROR|ASK|REPLY}", "claude-interactive"],
  content: "Contenu du message..."
)
```

### 3. Lecture

**METHODE OBLIGATOIRE avec paramètre `intercomLimit` :**

```
roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 10)
```

**⚠️ CRITIQUE : Gestion de la redirection vers fichier (#984)**

Quand le contenu du dashboard est trop volumineux, le MCP retourne un message du type :
```
Content too large, written to file: /path/to/file
```

**Dans ce cas, l'agent DOIT lire le fichier retourné :**

1. **Détecter** que la réponse contient un chemin fichier (pattern "written to file:")
2. **Lire** ce fichier avec l'outil `Read`
3. **Traiter** le contenu comme si l'outil l'avait retourné directement

**Exemple de procédure complète :**

```typescript
// Étape 1 : Appel dashboard avec intercomLimit pour éviter overflow
const result = roosync_dashboard(
  action: "read",
  type: "workspace",
  section: "intercom",
  intercomLimit: 10  // Limite à 10 messages récents
);

// Étape 2 : Vérifier si le contenu a été redirigé
if (result.message && result.message.includes("written to file:")) {
  const filePath = result.message.match(/written to file: (.+)/)[1];
  const actualContent = Read(filePath);
  // Traiter actualContent...
} else {
  // Traiter result.content directement
}
```

**Pourquoi c'est critique :** Sans cette lecture en 2 temps, les messages INTERCOM importants (WARN, ERROR, TASK, WAKE-CLAUDE) sont ignorés, ce qui rompt la coordination cross-machine.

### Avantages du dashboard vs fichier local

- **Pas d'approbation utilisateur** (MCP tool, pas ecriture fichier)
- **Visible cross-machine** via GDrive (workspace dashboard)
- Auto-condensation a 500 messages
- Tags structures identifiant l'auteur (`claude-interactive`, `claude-scheduled`, `roo-scheduler`, `roo-meta`)
- Archives JSON horodatees

### FALLBACK fichier local (DEPRECATED)

Seulement si le MCP dashboard echoue (GDrive offline, MCP crash), utiliser le fichier `.claude/local/INTERCOM-{MACHINE}.md` via Edit tool.

### Méthode ALTERNATIVE (Edit tool - append à la fin)

Claude Code utilise l'outil `Edit` avec `replace_all: false` pour ajouter du contenu à la fin du fichier local.

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
| `ACK` | Accuser réception d'un [DONE] ou [IDLE] de Roo |
| `PROPOSAL` | Proposer une tâche à Roo (proactif, pas bloquant) |
| `SUGGESTION` | Suggérer une direction sans s'engager |

---

## Règles d'Engagement — Dialogue Bidirectionnel (#657)

L'INTERCOM est un **canal de conversation**, pas un journal unilatéral. Claude doit réagir aux messages de Roo.

### 1. Début de Session — Répondre à Roo

Quand Claude Code lit l'INTERCOM au début d'une session :

1. **Identifier le dernier message de Roo** (tag `[DONE]`, `[IDLE]`, `[PARTIEL]`)
2. **Si [DONE] ou [IDLE] sans [ACK] de Claude dans les 2 derniers messages** :
   - Écrire `[ACK]` pour confirmer réception du rapport de Roo
   - Si Roo était **IDLE** : ajouter `[PROPOSAL]` avec 1-2 tâches suggérées (issue GitHub, consolidation, investigation)
3. **Si [ASK] sans [REPLY]** : répondre obligatoirement avant de commencer son propre travail

### 2. Fin de Session — Proposer à Roo

Quand Claude Code termine une session :

- Si la dernière activité connue de Roo était `[IDLE]` : écrire `[PROPOSAL]` avec 1-3 suggestions de tâches
- Si Roo est actif : écrire `[INFO]` sur ce que Claude a fait (coordination)

### 3. Format des Nouveaux Types

```markdown
## [YYYY-MM-DD HH:MM:SS] claude-code -> roo [ACK]
Reçu ton rapport. Build OK, tests passent. Continue.
---

## [YYYY-MM-DD HH:MM:SS] claude-code -> roo [PROPOSAL]
### Proposition : Issue #XXX
Tu es idle. Veux-tu investiguer le bug #XXX ?
**Description :** Timeout sur la recherche sémantique Qdrant.
**Complexité estimée :** -simple (lecture + rapport)
---

## [YYYY-MM-DD HH:MM:SS] claude-code -> roo [SUGGESTION]
### Pendant que je travaille sur #YYY
Si tu as un créneau : le nettoyage INTERCOM (>500 lignes) serait utile.
---
```

### 4. Règle Anti-Silence

**NE JAMAIS laisser 2 cycles consécutifs de Roo [IDLE] sans [PROPOSAL] de Claude.**

Si Roo est idle et Claude n'a pas proposé de travail lors des 2 dernières sessions → priorité absolue de proposer une tâche.

---

## INTERDIT

- **NE JAMAIS** insérer un message au début du fichier (avant les messages existants)
- **NE JAMAIS** supprimer ou modifier les messages existants
- **NE JAMAIS** écrire UNIQUEMENT le nouveau message (écrasement du fichier avec `Write` sans lecture préalable)

---

## Lecture en Debut de Session

**OBLIGATION :** Au debut de chaque session Claude Code, lire les dashboards.

**METHODE OBLIGATOIRE (Dashboard) :**
1. `roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 10)`
2. **SI redirection vers fichier** (message contient "written to file:") : lire ce fichier avec `Read`
3. Chercher les messages récents (< 24h) avec les tags : `[DONE]`, `[WAKE-CLAUDE]`, `[PATROL]`, `[FRICTION-FOUND]`, `[ERROR]`, `[WARN]`, `[ASK]`
4. Identifier les `TASK` non complétées
5. Identifier les `ASK` sans `REPLY`

**FALLBACK fichier local (si MCP echoue) :**
1. Lire le fichier `.claude/local/INTERCOM-{MACHINE}.md`
2. Memes etapes 3-5 ci-dessus

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
- Meta-analysis report : `docs/archive/harness-reports/cross-analysis-harnesses-2026-03-13.md` (REC-003)

---

**Dernière mise à jour :** 2026-03-13

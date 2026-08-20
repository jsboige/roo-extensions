# SDDD — Grounding conversationnel

**Version:** 5.0.0 (slim — tables déportées 2026-08-05)
**Issues :** #2218 (bookend généralisé) · #636 (filtres) · #881 (detailLevel) · #1785 (JSONL)

> Le protocole général (triple grounding, bookend, `workspace` explicite, scepticisme) est dans
> `~/.claude/rules/sddd-protocol.md`. Ce fichier ne porte que ce qui est **propre à ce dépôt**.

---

## Les trois sources, avec les outils d'ici

1. **Sémantique** — `codebase_search` + `roosync_search(action: "semantic")`
2. **Conversationnel** — `conversation_browser`
3. **Technique** — `Read` / `Grep` / `Glob` / `git` (**le code est la vérité**)

Ne jamais conclure sur une seule source.

## Les quatre invariants

- **`conversation_browser` : `list` d'abord.** Sans IDs, `view` / `tree` / `summarize` sont impossibles.
- **Ne pas confondre les deux paramètres de détail** — ce sont deux vocabulaires disjoints :
  `view` prend **`detail_level`** (`skeleton` / `summary` / `full`) ; `summarize` prend
  **`detailLevel`** (`Summary` / `NoTools` / `NoResults` / `Messages` / `UserOnly` / `Full`).
  Passer `detailLevel` à `view` est désormais rejeté explicitement (#3174) au lieu d'être ignoré.
- **`detailLevel: "Full"` = JAMAIS** (explosion de contexte). Préférer `Summary`, ou `NoTools`
  pour garder les outils résumés (`NoTools` est l'alias de la stratégie *Compact*, #881).
  ⚠️ Ne pas écrire `Compact` : la stratégie existe, mais **le schéma de l'outil ne l'expose pas**.
  Toujours `smart_truncation: true` au-delà de 10K chars.
- **`codebase_search` : `workspace` toujours explicite**, requêtes **en anglais** (vocabulaire du code).
  L'auto-détection pointe vers le répertoire du serveur MCP, pas vers le tien.
- **Ne JAMAIS lire un JSONL de session directement** (#1785) — passer par `conversation_browser`.

## Bookend (tâche > 50 LOC ou > 3 fichiers)

`codebase_search` en **DÉBUT** (la tâche a-t-elle déjà été faite ? quelle doc existe ?) et en **FIN**
(le travail est-il indexé ? la doc trouvée au début est-elle devenue obsolète ?).

`Grep` trouve des chaînes exactes ; `codebase_search` trouve des **concepts** et de la documentation
dont on ignore les mots. Les deux, pas l'un ou l'autre.

---

**Tables de paramètres (actions, `detailLevel`, filtres `roosync_search`, multi-pass, workflow complet) :**
[`docs/harness/reference/sddd-grounding-detailed.md`](../../docs/harness/reference/sddd-grounding-detailed.md)

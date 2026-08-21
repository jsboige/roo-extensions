# Wake-Claude Routing

**Version:** 2.0.0 (slim — détail déporté 2026-08-05)
**Issue :** #2431 (durabilité) ; routing vérifié-correct #2186

---

## Quoi

Une machine réveille l'agent Claude d'une autre en postant un tag sur le dashboard `workspace`
partagé (GDrive). Chaque machine fait tourner un **listener** qui spawn `claude -p` quand un tag la cible.

## Contrat de routing (NE PAS MODIFIER — #2186 vérifié-correct)

Le tag doit être en **début de ligne** ou dans un **header markdown** (`#`/`##`/`###`), hors bloc de
code, dans la section Intercom d'un dashboard `workspace-*.md`.

| Forme | Cible |
|-------|-------|
| `[WAKE-CLAUDE] myia-po-2023` | machine entière (tous workspaces) |
| `[WAKE-CLAUDE] myia-po-2023:IISManagement` | machine **+ workspace** précis (#2240) |
| `[WAKE-CLAUDE] → myia-po-2026:Embeddings` | flèche optionnelle tolérée |
| `[WAKE-CLAUDE] myia-po-2023:IISManagement model=haiku` | suffixe `model=X` optionnel (#2561) |
| `[WAKE-HERMES]` | `myia-po-2026:hermes-agent` (#2244) |
| `[WAKE-NANOCLAW]` | `myia-ai-01:nanoclaw` (#2244) |
| `[WAKE-VIBE]` | `myia-po-2025:CoursIA` (#3202) — spawn = `start-vibe-worker.ps1`, pas `spawn-claude.ps1` |

**Modèle** : précédence `model=X` (par-WAKE) > `$env:WAKE_DEFAULT_MODEL` (machine) > `sonnet` (défaut).
Downshift à `model=haiku` quand la tâche est triviale.

**Toute modification des fonctions de routing est hors-scope.** La cause des réveils manqués n'a
jamais été le routing — elle était mécanique (tâche tuée à 72 h, heartbeat menteur), corrigée par #2431.

## Ce qu'un agent doit savoir sans ouvrir la doc

- **Ré-installer la tâche listener exige l'élévation → `[INTERACTIVE-ONLY]`.** Ni un worker cron, ni
  un `[WAKE-CLAUDE]` ne peuvent le faire (on ne peut pas WAKE pour réparer le WAKE). C'est
  l'utilisateur, ou le Claude interactif de la machine concernée.
- **Un listener vivant pingue son heartbeat toutes les 5 min.** Seuil de mort côté coordinateur =
  **2 h** de silence. Ne pas resserrer : la coordination flotte tourne sur des crons 2 h+, un seuil
  plus court ne produirait que du bruit.
- **Juger la vie d'un listener sur les heartbeats, pas sur le bloc status du dashboard.**

---

**Architecture, durabilité #2431, liveness, installation élevée, détection fleet #2928 :**
[`docs/harness/reference/wake-claude-listener.md`](../../docs/harness/reference/wake-claude-listener.md)

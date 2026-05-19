# Bots Directory — Hermes & NanoClaw

> **Note relocalisation (2026-05-19)** : Ancien `.claude/rules/bots-directory.md`. Déplacé hors des rules auto-chargées car annuaire factuel (pas une règle de comportement).

**Version:** 1.0.0
**Issue :** #2243
**MAJ:** 2026-05-18

---

## Hermes (po-2026:hermes-agent)

- **Rôle** : Cron intercom review, fleet ping, patrol erreurs, PR review fallback
- **Host** : myia-po-2026
- **Scheduler** : Roo Hermes scheduler, cron `0,30 * * * *` (every 30 min at :00/:30)
- **Identité GitHub** : TBD
- **Contacter** :
  - Dashboard : `roosync_dashboard(action: "append", type: "workspace", tags: ["BOT-MENTION", "hermes"], content: "...")`
  - Inbox direct : `roosync_messages(action: "send", to: "myia-po-2026:hermes-agent", ...)`
- **Cas d'usage** :
  - Escalade review PR si CODEOWNERS bloque
  - Ping fleet status
  - Patrol erreurs récurrentes
- **Ne PAS contacter pour** : Tâches code (use workers), décisions architecturales (use coord/user)

## NanoClaw (ai-01:nanoclaw)

- **Rôle** : Cron review-pr, identité review CODEOWNERS, dashboard listener auxiliaire
- **Host** : myia-ai-01
- **Scheduler** : Roo NanoClaw scheduler, cron `15,45 * * * *` (every 30 min at :15/:45)
- **Identité GitHub** : TBD
- **Contacter** :
  - Dashboard : `roosync_dashboard(action: "append", type: "workspace", tags: ["BOT-MENTION", "nanoclaw"], content: "...")`
  - Inbox direct : `roosync_messages(action: "send", to: "myia-ai-01:nanoclaw", ...)`
- **Cas d'usage** :
  - Review PR du coord ai-01 (workaround CODEOWNERS self-merge protocol)
  - Co-hébergé OpenWebUI + sk-agent HTTP
- **Ne PAS contacter pour** : Modifier code prod (use workers PR pattern)

## Wake-on-Demand

Pour réveil immédiat hors cron tick (mécanisme listener #2244) :
- `[WAKE-HERMES]` en header markdown sur cluster-coord → trigger Hermes
- `[WAKE-NANOCLAW]` en header markdown sur cluster-coord → trigger NanoClaw

## Intercom Coverage

Les 2 bots couvrent **chaque quart d'heure** :

| Minute | Bot |
|--------|-----|
| :00 | Hermes |
| :15 | NanoClaw |
| :30 | Hermes |
| :45 | NanoClaw |

## Références

- Epic parent : #2245
- Wake-Claude routing : #2240
- Bots inbox standardisé : #2241
- Bots active polling : #2242
- Wake-on-tag listener : #2244

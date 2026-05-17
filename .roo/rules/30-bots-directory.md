# Répertoire Bots — Hermes & NanoClaw

**Version:** 1.0.0
**Issue :** #2243
**MAJ:** 2026-05-18

---

## Hermes (myia-po-2026)

- **Rôle** : Cron intercom review, fleet ping, patrol erreurs, PR review fallback
- **Host** : myia-po-2026
- **Scheduler** : Cron `0,30 * * * *` (toutes les 30 min à :00/:30)
- **Contacter** : Dashboard `tags: ["BOT-MENTION", "hermes"]` ou inbox `to: "myia-po-2026:hermes-agent"`
- **Cas d'usage** : Escalade review PR, ping fleet status, patrol erreurs
- **Ne PAS contacter pour** : Tâches code (use workers), décisions architecturales (use coord)

## NanoClaw (myia-ai-01)

- **Rôle** : Cron review-pr, identité review CODEOWNERS, dashboard listener auxiliaire
- **Host** : myia-ai-01
- **Scheduler** : Cron `15,45 * * * *` (toutes les 30 min à :15/:45)
- **Contacter** : Dashboard `tags: ["BOT-MENTION", "nanoclaw"]` ou inbox `to: "myia-ai-01:nanoclaw"`
- **Cas d'usage** : Review PR coord ai-01 (workaround CODEOWNERS), co-hébergé OpenWebUI + sk-agent
- **Ne PAS contacter pour** : Modifier code prod (use workers PR pattern)

## Coverage Intercom

| Minute | Bot |
|--------|-----|
| :00 | Hermes |
| :15 | NanoClaw |
| :30 | Hermes |
| :45 | NanoClaw |

## Wake-on-Demand (mécanisme listener #2244)

- `[WAKE-HERMES]` → trigger Hermes immédiat
- `[WAKE-NANOCLAW]` → trigger NanoClaw immédiat

## Références

Epic parent : #2245 | Wake routing : #2240 | Inbox : #2241 | Polling : #2242 | Listener : #2244

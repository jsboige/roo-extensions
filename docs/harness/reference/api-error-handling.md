# API Error Handling — Circuit Breaker

**Version:** 1.0.0 (port Claude de `.roo/rules/29-api-error-handling.md`, #2368)
**Issues :** #1783 (502 retry death spiral) · #3170 (429 Fair Usage — le retry aggrave)
**MAJ :** 2026-10-02

---

## Regle Absolue — Max 5 retries

**Si 5+ erreurs consecutives (502, 503, 504, timeout, connexion refusee) sur le meme appel, ARRETER IMMEDIATEMENT.**

Le harness Claude Code gere ses propres retries API ; cette regle vise les boucles de relance pilotees par l'AGENT (outil qui echoue, sub-agent re-spawne, batch re-execute). Apres le breaker :

1. **STOP** : ne pas relancer
2. **LOG** : poster `[ERROR] API circuit breaker: X consecutive failures` sur le dashboard
3. **TERMINATE** : bilan d'echec clair — pas de changement de modele en cours de tache, pas de retry en silence

## Les deux 429 ne se traitent pas pareil (#3170)

**Lire le corps de la reponse avant de decider** — le code 429 seul ne dit pas quelle limite est franchie, et le prefixe du message nomme le handler, pas la limite.

| | Quota / rate limit ordinaire | **Fair Usage / account-level** |
|---|---|---|
| Corps HTTP | `rate limit`, `quota`, `retry-after` | `Fair Usage`, `account`, `request frequency`, souvent `not your usage limit` |
| Retry | legitime (backoff) | **AGGRAVE** — chaque retry nourrit la fenetre qui declenche la limite |
| Action | attendre, reessayer | **breaker immediat** : STOP, LOG, TERMINATE |

| Autres erreurs | Action |
|---|---|
| 400 / 401 / 403 | erreur de requete — corriger, jamais retry |

**Mesures fondatrices :** 48 retries consecutifs sur un 429 Fair Usage en une seule session (po-2025, 2026-08-19, #3170) ; 17+ retries pendant 2 h sans aucun output (po-2026, 2026-04-27, #1783).

**Verification :** apres un breaker, la session/tache suivante reprend normalement. Si 3 sessions consecutives se terminent en breaker → poster `[CRITICAL]` et attendre l'intervention.

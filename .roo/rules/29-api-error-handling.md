# API Error Handling — Circuit Breaker

**Version:** 1.1.0
**Issues :** #1783 (502 retry death spiral) · #3170 (429 Fair Usage — le retry aggrave)
**MAJ:** 2026-08-19

---

## Regle Absolue — Max 5 retries

**Si 5+ erreurs consecutives (502, 503, 504, timeout) sur le meme appel API, ARRETER IMMEDIATEMENT.**

Ne pas re essayer indefiniment. Le retry automatique de Roo Code n'a pas de circuit breaker interne — c'est au modele de l'arreter.

## Comportement apres 5 erreurs consecutives

1. **STOP** : Ne pas lancer un nouveau retry
2. **LOG** : Poster `[ERROR] API circuit breaker: X consecutive failures` sur le dashboard
3. **TERMINATE** : Terminer la tache avec un bilan d'echec clair
4. **NE PAS** : Continuer a retry, changer de modele en cours de task, ou ignorer l'erreur

## Types d'erreurs concernees

| Erreur | Action |
|--------|--------|
| 502 Bad Gateway | Circuit breaker |
| 503 Service Unavailable | Circuit breaker |
| 504 Gateway Timeout | Circuit breaker |
| Connection refused | Circuit breaker |
| 429 **Fair Usage / account-level** | **Circuit breaker** — le retry AGGRAVE (voir ci-dessous) |
| 429 quota / rate limit ordinaire | Attendre (retry avec backoff) — PAS un circuit breaker |
| 400/401/403 | Erreur de requete — ne PAS retry, corriger |

## Les deux 429 ne se traitent pas pareil (#3170)

**Tous les 429 ne sont pas des limites de debit.** Un 429 dit "trop de requetes" ; il ne dit pas
*quelle* limite a ete franchie. Deux cas, deux traitements opposes :

| | Quota / rate limit ordinaire | **Fair Usage / account-level** |
|---|---|---|
| Porte sur | ta consommation, une fenetre de temps | le **compte**, et la **frequence** des requetes |
| Le corps HTTP contient | `rate limit`, `quota`, `tokens per minute`, un `retry-after` | `Fair Usage`, `account`, `usage pattern`, `request frequency`, souvent **`not your usage limit`** |
| Retry | legitime, avec backoff | **AGGRAVE** — chaque retry est une requete de plus dans la fenetre qui declenche la limite |
| Action | attendre, reessayer | **circuit breaker immediat** : STOP, LOG, TERMINATE |

**Lire le corps de la reponse avant de decider.** Le code seul (429) ne suffit pas, et le prefixe
du message nomme le handler, pas la limite (`OpenAI completion error: 429` apparait sur n'importe
quel provider OpenAI-compatible).

**Mesure a l'appui (#3170, po-2025, 2026-08-19)** : 48 retries consecutifs sur un 429 Fair Usage
dans une seule session. Aucun n'a abouti — la limite portant sur la frequence, la boucle de retry
etait elle-meme la cause de sa propre prolongation. La regle telle qu'ecrite avant ce correctif
exemptait explicitement les 429 du circuit breaker : ce n'etait pas un defaut de conformite de
l'agent, c'etait un trou dans la regle.

## Pourquoi

Incident 2026-04-27 (po-2026) : meta-analyst task a fait 17+ retries consecutifs pendant 2+ heures avec zero output, gaspillant des credits sans produire de resultat. Le modele qwen3.6-35b n'avait pas de guidance pour arreter les retries.

## Verification

Apres un circuit breaker, la prochaine session/tache peut reprendre normalement. Si l'API est toujours down apres 3 sessions consecutives avec circuit breaker → poster `[CRITICAL]` et attendre intervention.

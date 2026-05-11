# API Error Handling — Circuit Breaker

**Version:** 1.0.0
**Issue :** #1783 (502 retry death spiral)
**MAJ:** 2026-05-11

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
| 429 Rate Limited | Attendre (retry avec backoff) — PAS un circuit breaker |
| 400/401/403 | Erreur de requete — ne PAS retry, corriger |

## Pourquoi

Incident 2026-04-27 (po-2026) : meta-analyst task a fait 17+ retries consecutifs pendant 2+ heures avec zero output, gaspillant des credits sans produire de resultat. Le modele qwen3.6-35b n'avait pas de guidance pour arreter les retries.

## Verification

Apres un circuit breaker, la prochaine session/tache peut reprendre normalement. Si l'API est toujours down apres 3 sessions consecutives avec circuit breaker → poster `[CRITICAL]` et attendre intervention.

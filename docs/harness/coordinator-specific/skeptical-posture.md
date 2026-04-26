# Posture Coordinateur Ferme (depuis #1463)

**Version:** 1.0.0 (extrait de CLAUDE.md, issue #1727)
**MAJ:** 2026-04-25

---

Le coordinateur interactif (ai-01) applique le **Protocole de Scepticisme Raisonnable v3.1** :

## Avant d'agir sur un rapport critique (audit 4 questions)

| Question | Reponse requise |
|---|---|
| Qui a touche ce code dans les 30 derniers jours ? | `git log` + liste commits |
| La doc/MEMORY dit-elle deja quelque chose ? | Grep explicite |
| Est-ce une issue deja ouverte/fermee ? | `gh issue list --search` |
| Y a-t-il un test qui aurait du detecter ? | Si oui, pourquoi n'a-t-il pas tourne ? |

**Sans ces 4 reponses : pas de dispatch, pas de PR, pas de refonte.**

## Signaux entropiques a reconnaitre

- Une issue "documentee ad nauseam" (>=3 fois) qui revient → **ne pas investiguer, fermer avec contexte**
- Un rapport "outil X casse" qui propose une reecriture → **exiger d'abord le commit rogue**
- Un meta-analyste qui rapporte "harmonisation theorique" → **rejeter, scope real problems only**
- Un PR qui touche `.env` / `mcp_settings.json` / `.claude/rules/` merge par un scheduled agent → **re-review obligatoire 24h**

## Paradoxe 7000+ tests

Le repo a 7000+ tests unitaires mais la plupart des outils fonctionnent a peine. C'est la signature de la **vibecoding** : les agents modifient des fichiers critiques sans lire l'historique ni faire tourner les tests. **Le coordinateur ne doit jamais normaliser cette derive.**

## Scepticisme PR Review (issue #1471)

**PROBLEME :** sk-agent PR reviews se contentent de valider le diff sans tracer l'integration end-to-end. Resultat : BLOCKER-3 (bug workspace-loss dans dispatch) passe au travers de PR #124 review.

**PROTOCOL :** Pour toute PR >50 LOC, le coordinateur DOIT exiger le template d'integration tracing (context tracing) :

1. **Context tracing obligatoire** : Entry point → Validation → Consumers → Side effects → Context preservation
2. **Chasse aux patterns silencieux** : `.catch(() => {})`, fire-and-forget sans log, defaults qui masquent des bugs
3. **Verification E2E** : "Est-ce qu'un test exerce ce flow complet ?"
4. **Detection dual-definition** : meme schema/type duplique (tool-definitions vs handler source)
5. **Questions sceptiques** : "Ce schema accepte ces fields, est-ce que le dispatch en aval les traite correctement ?"

**Template complet** : [`pr-review-policy.md`](pr-review-policy.md) section 2.

**Impact attendu** : Reviews plus longues (5-10 min vs 1-2 min) mais **beaucoup** plus utiles. Catch de bugs d'integration AVANT merge, pas apres.

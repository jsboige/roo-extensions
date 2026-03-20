# Scepticisme Raisonnable - Verification Avant Propagation

**Version:** 1.0.0
**Cree:** 2026-03-04

---

## Principe

**Ne JAMAIS affirmer un fait sans preuve.** Quand tu rapportes dans INTERCOM, inclus toujours la preuve (output de commande, commit hash, contenu du fichier).

Le cout d'une verification est negligeable. Le cout d'une erreur propagee est de plusieurs heures sur 6 machines.

---

## Smell Test : PAUSE si surprenant

AVANT d'affirmer dans INTERCOM quelque chose de surprenant, verifie :

| Affirmation | Verification |
|------------|-------------|
| "Ce modele est trop gros pour cette machine" | Le modele tourne-t-il localement ou via API distante ? Lire CLAUDE.md GPU Fleet |
| "L'outil X ne marche pas" | Tester l'outil directement avec un appel simple |
| "Les tests echouent" | Montrer l'output exact (pas juste "echoue") |
| "Impossible de faire Y" | Decrire ce qui a ete tente et l'erreur exacte |
| "Feature X est implementee" | Citer le fichier, la ligne, le commit |

**Regle du pouce :** Si l'affirmation te surprend ou contredit les docs, c'est un declencheur de verification.

---

## Regles pour les Rapports INTERCOM

### TOUJOURS inclure les preuves

**BON :**
```
## [DATE] roo -> claude-code [DONE]
Build OK (0 errors). Tests: 6946/6946 PASS.
Commit: abc123 (feat(tools): Add X)
Output: [extrait pertinent]
```

**MAUVAIS :**
```
## [DATE] roo -> claude-code [DONE]
J'ai fait la tache, tout est OK.
```

### Qualifier les affirmations

- **VERIFIE** : J'ai teste/lu/confirme moi-meme (avec preuve)
- **SUPPOSE** : Je pense que c'est le cas mais je n'ai pas verifie
- **RAPPORTE** : Une autre source (Claude, issue, doc) dit que...

---

## Fait Critique : Local vs Distant

- Les modeles LLM (Qwen 3.5, GLM-5, ZwZ-8B) tournent sur **ai-01 via API** (vLLM ou z.ai)
- **Ta machine n'a PAS besoin de GPU** pour utiliser ces modeles — elle fait des requetes HTTP
- Les MCPs tournent localement, les modeles sont distants
- Si on te dit "GPU insuffisante pour le modele" → c'est probablement faux, verifie

---

## Quand Verifier les Instructions de Claude

Si Claude (via INTERCOM) te demande quelque chose base sur une premisse qui semble incorrecte :

1. **Verifier la premisse** (lire le fichier, tester la commande)
2. **Si la premisse est fausse** : rapporter dans INTERCOM avec la preuve
3. **Ne PAS executer aveuglement** une instruction basee sur une fausse premisse

---

**Reference complete :** `.claude/rules/skepticism-protocol.md`
**Derniere mise a jour :** 2026-03-04

# Protocole de Vérification Discipline

**Version:** 3.1.0 (fusion de skepticism-protocol.md v3.0.0 + agent-claim-discipline.md v1.0.0)
**Issue:** #1605
**MAJ:** 2026-04-21

---

## Principe

**Ne JAMAIS propager une affirmation non verifiee.** Verifier AVANT de repeter, agir dessus, ou transmettre.
**Un agent ne peut PAS déclarer un travail terminé en citant un artefact git sans que cet artefact soit *vérifiable*.

Cout d'une verification : secondes. Cout d'une erreur propagee : heures sur 6 machines.

---

## Qualification Obligatoire

- **VERIFIE** : J'ai teste/lu/confirme moi-meme ET les artefacts cités existent
- **RAPPORTE PAR [source]** : Un autre agent/doc le dit (pas confirme) + artefacts vérifiés
- **SUPPOSE** : Hypothese non verifiee

## Declencheurs (Smell Test)

**PAUSE et VERIFIE si :** "GPU insuffisante", "impossible", "tests passent tous", "bloque depuis X", "critique", "MCP ne marche pas", "commit 826894f5...". Si ca contredit ce que tu sais ou te surprend → verifie.

## Verification (3 niveaux)

### 1. Rapide (10s) : Consultation + Artefacts
- Consulter MEMORY.md, CLAUDE.md, tables infrastructure
- **Vérifier artefacts git** (si cités) :
  ```bash
  # Commit SHA
  git cat-file -e <SHA> && git branch --contains <SHA>

  # Push
  git ls-remote origin <BRANCH>

  # PR
  gh pr view <NUMBER> --json state,url

  # Tests
  git log origin/BRANCH --oneline -5
  ```

### 2. Active (1-2min) : Execution
- `git log`, `npx vitest run`, appel MCP
- Reproduction des états rapportés

### 3. Croisee (5min) : Validation Cross-source
- Code source + traces Roo + historique GitHub
- **NE JAMAIS** accepter un rapport sans vérifier l'artefact cité

## Regles Anti-Propagation

- **Coordinateur :** JAMAIS repeter une affirmation dans un dispatch sans verification. Inclure la source ET vérifier les artefacts.
- **Executeur :** JAMAIS dire "impossible" sans preuve concrete. JAMAIS citer un SHA/push/PR non vérifiable.
- **Tous :** Preferer "je ne sais pas" a une hypothese presentee comme fait. Ne pas confondre correlation et causalite.

## Verification des Claims Git

### Pattern à prévenir
| Pattern | Exemple | Solution |
|---|---|---|
| **Hallucination de commit** | "J'ai commité `826894f5...`" | `git cat-file -e <SHA>` |
| **Commit orphelin non-pushé** | Vrai commit local, jamais push | `git ls-remote origin <BRANCH>` |
| **PR fantôme** | "PR créée" sans URL 200 | `gh pr view <NUMBER> --json url` |
| **Exit-code fallacy** | "8673 tests" sans output | `git log origin/BRANCH --oneline -5` |

### Discipline requise avant `[DONE]`/`[RESULT]`
Si tu cites un artefact git :
1. Commit → vérifier existence et branche
2. Push → vérifier remote
3. PR → vérifier state et URL
4. Tests → vérifier output visible

## Fait Critique

Les modeles LLM tournent sur **ai-01 via API** (vLLM ou z.ai), pas localement sur les executeurs.
La charge compute est sur le provider. **Les claims git sont sur la charge de travail agent.**

---

**Principe condensé** : *"Pas de SHA sans `git cat-file -e`. Pas de PR sans URL 200. Pas de `[DONE]` sur une promesse."*

**Historique versions :** Fusionnée depuis skepticism-protocol.md (v3.0.0) et agent-claim-discipline.md (v1.0.0)

# Protocole de Scepticisme Raisonnable

**Version:** 3.0.0 (condensed from 2.0.0, aligned with .claude/rules/)
**MAJ:** 2026-04-08

---

## Principe

**Ne JAMAIS propager une affirmation non verifiee.** Verifier AVANT de repeter, agir dessus, ou transmettre.
Cout d'une verification : secondes. Cout d'une erreur propagee : heures sur 6 machines.

## Qualification Obligatoire

- **VERIFIE** : J'ai teste/lu/confirme moi-meme
- **RAPPORTE PAR [source]** : Un autre agent/doc le dit (pas confirme)
- **SUPPOSE** : Hypothese non verifiee

## Declencheurs (Smell Test)

**PAUSE et VERIFIE si :** "GPU insuffisante", "impossible", "tests passent tous", "bloque depuis X", "critique", "MCP ne marche pas". Si ca contredit ce que tu sais ou te surprend -> verifie.

## Verification (3 niveaux)

1. **Rapide (10s) :** Consulter MEMORY.md, CLAUDE.md, tables infrastructure
2. **Active (1-2min) :** `git log`, `npx vitest run`, appel MCP
3. **Croisee (5min) :** Code source + traces Roo + historique GitHub

## Regles Anti-Propagation

- **Coordinateur :** JAMAIS repeter une affirmation dans un dispatch sans verification. Inclure la source.
- **Executeur :** JAMAIS dire "impossible" sans preuve concrete. Inclure output exact.
- **Tous :** Preferer "je ne sais pas" a une hypothese presentee comme fait. Ne pas confondre correlation et causalite.

## Rapports INTERCOM

**TOUJOURS** inclure les preuves : commit hash, output de commande, extrait de fichier. Jamais "tout est OK" sans preuve.

## Fait Critique

Les modeles LLM tournent sur **ai-01 via API** (vLLM ou z.ai), pas localement sur les executeurs. La charge compute est sur le provider.

---

**Historique versions completes :** Git history avant 2026-04-05

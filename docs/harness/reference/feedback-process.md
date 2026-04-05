# Processus de Feedback et Amelioration Continue

Extrait de CLAUDE.md le 2026-02-19. Processus d'evolution des workflows (commands/skills/agents).

---

## Principe

Evolution prudente et collective pour eviter le feature creep.

## Workflow de proposition

1. **Identification** (n'importe quel agent Claude)
   - Reperer un probleme/friction dans le workflow actuel
   - Documenter l'experience concrete
   - Proposer une amelioration specifique et minimaliste

2. **Consultation collective** (via RooSync)
   - Message `to: "all"` avec sujet `[FEEDBACK] Amelioration proposee: <titre>`
   - Contexte, proposition concrete, risques de feature creep
   - Demander avis critique (24-48h)

3. **Collecte des retours**
   - Focus : "Est-ce vraiment necessaire?" et "Risques?"
   - Les agents servent de garde-fou contre le feature creep

4. **Decision finale** (coordinateur myia-ai-01)
   - Synthetiser, decider : APPROUVER / REJETER / MODIFIER
   - Si approuve : creer issue GitHub
   - Documenter la decision dans le thread RooSync

## Criteres d'approbation

- Resout un probleme reel (pas theorique)
- Solution minimale et ciblee
- Pas de complexite excessive
- Consensus ou majorite des agents
- Rejet si : feature creep, complexite, probleme theorique

## Documentation

- Issue GitHub avec label `workflow-improvement`
- MAJ du fichier concerne (.claude/commands/, skills/, agents/)

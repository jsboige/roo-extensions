> ## ARCHIVED — superseded 2026-06-18
>
> **Status:** DEPRECATED. Kept here verbatim for traceability.
> **Canonical now:** [`.claude/rules/friction-protocol.md`](../../.claude/rules/friction-protocol.md) (slim, auto-loaded) → points to [`docs/harness/reference/friction-protocol-detailed.md`](../harness/reference/friction-protocol-detailed.md) for the full procedure.
> **Coordinator decision:** ai-01 dispatch 2026-06-18 (deep-queue R1) — slim rule is canonical; this big v1.0 was a name-collision duplicate (two files named `friction-protocol.md`) pointing at the deprecated INTERCOM channel.
>
> ### Why archived (proof of obsolescence)
> - Points at **INTERCOM** as the "friction locale" channel (3 hits: `INTERCOM`, `roosync_send`). INTERCOM is **deprecated** — `intercom-protocol.md` v3.4.0 made Dashboard workspace the principal channel. The `[FRICTION-FOUND]` INTERCOM template below is therefore obsolete.
> - **Name collision:** this file and the slim rule `.claude/rules/friction-protocol.md` shared the basename `friction-protocol.md`, causing ambiguity about which was canonical. The slim rule (auto-loaded every session) wins by design.
> - All still-valid content (Quand/Comment Signaler, Traitement, Critères d'Approbation) is already covered by the canonical slim rule + `friction-protocol-detailed.md` (which correctly uses Dashboard as PRINCIPAL).
>
> ### What was merged (no information loss)
> - **Nothing needed merging.** The only content unique to this v1.0 was the INTERCOM `[FRICTION-FOUND]` template (lines 45-64), which is obsolete post-INTERCOM-deprecation. The "Workflow Complet" and "Traitement" sections are already in `-detailed.md`. Verified: `grep -c "INTERCOM" friction-protocol-v1-deprecated.md` = 3 (all obsolete channel refs).
> - The one inbound reference (`sddd-conversational-grounding.md:316`, which described this file as containing "roosync_send + INTERCOM templates") was migrated to point at `friction-protocol-detailed.md` with a corrected Dashboard-based description.
>
> ### Archived by
> myia-web1 (GLM-5.2) / claude-interactive cycle 12 — consolidation per CLAUDE.md rule (3 steps: ANALYZE → MERGE → ARCHIVE with proof) + no-deletion-without-proof (archive ≠ delete, content preserved verbatim). Coordinator scope-approval: ai-01 dispatch 2026-06-18.

---

# Protocole de Friction - Claude Code

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #712 (basé sur .roo/rules/17-friction-protocol.md)

---

## Principe

**Tout agent Claude Code rencontrant une friction ou un problème avec les outils/workflows DOIT le signaler au collectif.**

Les skills évoluent par friction RÉELLE, pas par anticipation théorique.

---

## Quand Signaler

Signaler une friction quand :
- Un outil MCP ne fonctionne pas (timeout, réponse vide, erreur inattendue)
- Le bookend SDDD (`codebase_search`) ne retourne rien d'utile
- Un skill/command ne suit pas le protocole documenté
- Une doc est introuvable malgré le triple grounding
- La configuration ne correspond pas à la documentation
- Un pattern d'erreur se répète > 2 fois dans la même session

---

## Comment Signaler

### Via RooSync (friction système — à diffuser à toutes les machines)

```
roosync_send(
  action: "send",
  to: "all",
  subject: "[FRICTION] Description courte du problème",
  body: "## Problème\n[Description]\n\n## Contexte\n[Quelle tâche, quel outil, quel résultat]\n\n## Impact\n[Ce qui est bloqué ou dégradé]\n\n## Suggestion\n[Amélioration proposée si applicable]",
  tags: ["friction"]
)
```

### Via INTERCOM (friction locale — pour Roo sur la même machine)

```markdown
## [YYYY-MM-DD HH:MM:SS] claude-code -> roo [FRICTION-FOUND]

### Problème
[Description]

### Contexte
- Tâche : ...
- Outil : ...
- Résultat attendu : ...
- Résultat obtenu : ...

### Impact
[Ce qui est bloqué]

### Suggestion
[Proposition d'amélioration]

---
```

### Via GitHub Issue (friction à corriger — nécessite approbation)

Créer une issue avec :
- Title: `[FRICTION] Description`
- Label: `friction` + catégorie + `needs-approval`
- Body: Template complet (problème, contexte, impact, suggestion)

**Note :** Les issues HARNESS nécessitent aussi le label `harness-change`.

---

## Traitement des Frictions

1. **Le collectif reçoit le message** (toutes machines ou agents concernés)
2. **Les agents avec expérience similaire répondent** avec leur contexte
3. **Le coordinateur (myia-ai-01) synthétise** et décide l'amélioration
4. **Si approuvé :** Modifier le skill/rule/tool concerné (incrémental)
5. **Documenter la décision** dans le thread RooSync ou l'issue GitHub

---

## Critères d'Approbation

Une amélioration est approuvée si :
- Résout un problème RÉEL (pas théorique)
- Solution minimale et ciblée
- Pas de complexité excessive
- Consensus ou majorité des agents
- **Rejet si :** feature creep, complexité, problème théorique

---

## Documentation

- **Issue GitHub** avec label `workflow-improvement` ou `friction`
- **MAJ du fichier concerné** (`.claude/commands/`, `skills/`, `agents/`, `rules/`)
- **Commit** avec référence à l'issue ou au message RooSync

---

## Workflow Complet

```
1. Identification → Repérer problème/friction
2. Signalement → RooSync [FRICTION] to:all + INTERCOM [FRICTION-FOUND]
3. Consultation collective → 24-48h pour avis
4. Décision finale → Coordinateur synthétise
5. Documentation → Issue + MAJ fichiers + Commit
```

---

## Références

- [`docs/harness/reference/feedback-process.md`](./feedback-process.md) — Processus d'amélioration continue
- [`.claude/rules/sddd-conversational-grounding.md`](sddd-conversational-grounding.md) — Section "Protocole de Friction"
- [`.claude/commands/executor.md`](../../../.claude/commands/executor.md) — Section "Protocole de friction (OBLIGATOIRE)"
- Équivalent Roo : `.roo/rules/17-friction-protocol.md`
